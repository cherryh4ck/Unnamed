extends Control

## Minimapa circular. Gira igual que la camara (arriba en el minimapa es
## "hacia adelante" en pantalla) y muestra la foto del mundo desde arriba
## (world_map) con la niebla de lo no explorado, al jugador, a los enemigos,
## los portales y los items del piso. Sin foto (sin GPU) dibuja el area
## caminable sacada de los NavigationRegion3D.

## Radio del mundo (en unidades) que entra en el minimapa.
@export var world_radius: float = 2200.0

const BACKGROUND := Color(0.07, 0.055, 0.04, 0.88)
const GROUND := Color(0.28, 0.24, 0.17, 0.9)
const FRAME := Color(0.6, 0.47, 0.26)
const ENEMY := Color(0.9, 0.2, 0.15)
const PLAYER := Color(1.0, 0.92, 0.6)
const GOLD := Color(1.0, 0.85, 0.35)
const PORTAL := Color(0.45, 0.78, 1.0)
const MAP_TINT := Color(0.9, 0.82, 0.66)
const FOG_TINT := Color(0.2, 0.16, 0.11)

var player: Node3D
var _mask: Control
var _content: Control
var _frame: Control
## Poligonos del navmesh en coordenadas del mundo (XZ).
var _ground_polygons: Array[PackedVector2Array] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player = get_tree().get_first_node_in_group("player")

	# El circulo de la mascara recorta todo lo que dibuja el contenido.
	_mask = Control.new()
	_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_mask.draw.connect(func() -> void: _mask.draw_circle(size / 2.0, _radius(), BACKGROUND))
	add_child(_mask)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.draw.connect(_draw_content)
	_mask.add_child(_content)

	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)

	_collect_ground.call_deferred()


func _process(_delta: float) -> void:
	_content.queue_redraw()
	_frame.queue_redraw()


func _radius() -> float:
	return minf(size.x, size.y) / 2.0 - 3.0


func _collect_ground() -> void:
	_ground_polygons.clear()
	for region in get_tree().current_scene.find_children("*", "NavigationRegion3D", true, false):
		var nav_mesh: NavigationMesh = region.navigation_mesh
		if nav_mesh == null:
			continue
		var vertices: PackedVector3Array = nav_mesh.get_vertices()
		for i in nav_mesh.get_polygon_count():
			var polygon := PackedVector2Array()
			for index in nav_mesh.get_polygon(i):
				var world: Vector3 = region.global_transform * vertices[index]
				polygon.append(Vector2(world.x, world.z))
			_ground_polygons.append(polygon)


# Ejes de la camara proyectados al piso: "derecha" y "adelante" en pantalla.
func _camera_axes() -> Array[Vector2]:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return [Vector2.RIGHT, Vector2.UP]
	var right: Vector3 = camera.global_basis.x
	var forward: Vector3 = -camera.global_basis.z
	var r := Vector2(right.x, right.z).normalized()
	var f := Vector2(forward.x, forward.z).normalized()
	return [r, f]


func _to_map(world_xz: Vector2, origin: Vector2, axes: Array[Vector2]) -> Vector2:
	var rel: Vector2 = world_xz - origin
	var scale: float = _radius() / world_radius
	return size / 2.0 + Vector2(rel.dot(axes[0]), -rel.dot(axes[1])) * scale


func _draw_content() -> void:
	if player == null:
		return
	var origin := Vector2(player.global_position.x, player.global_position.z)
	var axes: Array[Vector2] = _camera_axes()

	var texture: Texture2D = world_map.get_map_texture()
	if texture:
		# La foto cubre world_rect: se dibuja con la misma rotacion y escala
		# que el resto del minimapa.
		var world: Rect2 = world_map.world_rect()
		var px: Vector2 = world.size / Vector2(texture.get_size())
		var corner: Vector2 = _to_map(world.position, origin, axes)
		var x_axis: Vector2 = _to_map(world.position + Vector2(px.x, 0.0), origin, axes) - corner
		var y_axis: Vector2 = _to_map(world.position + Vector2(0.0, px.y), origin, axes) - corner
		_content.draw_set_transform_matrix(Transform2D(x_axis, y_axis, corner))
		_content.draw_texture(texture, Vector2.ZERO, MAP_TINT)
		_content.draw_texture_rect(world_map.get_fog_texture(), Rect2(Vector2.ZERO, texture.get_size()), false, FOG_TINT)
		_content.draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		for polygon in _ground_polygons:
			var points := PackedVector2Array()
			for point in polygon:
				points.append(_to_map(point, origin, axes))
			_content.draw_colored_polygon(points, GROUND)

	var max_dist: float = _radius() + 4.0
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if pickup.item_data == null:
			continue
		var pos: Vector2 = _to_map(Vector2(pickup.global_position.x, pickup.global_position.z), origin, axes)
		if pos.distance_to(size / 2.0) > max_dist:
			continue
		var is_gold: bool = pickup.item_data.item_type == Itemdata.ItemType.GOLD
		var color: Color = GOLD if is_gold else pickup.item_data.get_rarity_color()
		_content.draw_rect(Rect2(pos - Vector2(2, 2), Vector2(4, 4)), color)

	for portal in get_tree().get_nodes_in_group("portals"):
		if not portal.is_discovered():
			continue
		var pos: Vector2 = _to_map(Vector2(portal.global_position.x, portal.global_position.z), origin, axes)
		if pos.distance_to(size / 2.0) <= max_dist:
			_content.draw_circle(pos, 5.5, Color(0, 0, 0, 0.6))
			_content.draw_arc(pos, 4.0, 0.0, TAU, 16, PORTAL, 2.0)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var pos: Vector2 = _to_map(Vector2(enemy.global_position.x, enemy.global_position.z), origin, axes)
		if pos.distance_to(size / 2.0) > max_dist:
			continue
		# Los elite (mas experiencia) se ven mas grandes; los campeones, dorados.
		var dot_radius: float = 4.5 if enemy.data.xp_reward >= 50 else 3.0
		if enemy.champion:
			dot_radius = 5.5
		_content.draw_circle(pos, dot_radius + 1.0, Color(0, 0, 0, 0.6))
		_content.draw_circle(pos, dot_radius, enemy.CHAMPION_COLOR if enemy.champion else ENEMY)

	_draw_player_arrow(axes)


func _draw_player_arrow(axes: Array[Vector2]) -> void:
	var facing3: Vector3 = player.global_basis.z
	var facing := Vector2(facing3.x, facing3.z)
	var dir := Vector2(facing.dot(axes[0]), -facing.dot(axes[1])).normalized()
	var side := Vector2(-dir.y, dir.x)
	var center: Vector2 = size / 2.0
	var arrow := PackedVector2Array([
		center + dir * 8.0,
		center - dir * 5.0 + side * 5.0,
		center - dir * 2.0,
		center - dir * 5.0 - side * 5.0,
	])
	_content.draw_colored_polygon(arrow, PLAYER)
	_content.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0, 0, 0, 0.8), 1.0)


func _draw_frame() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = _radius()
	_frame.draw_arc(center, radius, 0.0, TAU, 64, Color(0, 0, 0, 0.6), 5.0)
	_frame.draw_arc(center, radius, 0.0, TAU, 64, FRAME, 2.5)

	# Marca del norte (-Z del mundo) en el borde.
	var axes: Array[Vector2] = _camera_axes()
	var north := Vector2(0, -1)
	var dir := Vector2(north.dot(axes[0]), -north.dot(axes[1])).normalized()
	var pos: Vector2 = center + dir * radius
	_frame.draw_circle(pos, 9.0, Color(0.1, 0.08, 0.05))
	_frame.draw_arc(pos, 9.0, 0.0, TAU, 24, FRAME, 1.5)
	var font: Font = get_theme_default_font()
	_frame.draw_string(font, pos + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.88, 0.55))
