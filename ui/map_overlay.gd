extends Control

## Mapa translucido encima del juego (tecla N): un recuadro en el centro con
## el mapa alrededor del jugador, girado como la camara (igual que el
## minimapa), los portales, los personajes de la aldea y los enemigos cerca.
## No pausa ni toma el mouse: se puede seguir peleando con el mapa abierto.

const PORTAL_ICON := preload("res://assets/icons/game-icons/lorc/magic-portal.svg")
const MAP_TINT := Color(1.25, 1.15, 0.95, 0.68)
const FOG_TINT := Color(0.05, 0.04, 0.03, 0.6)
const FRAME := Color(0.7, 0.56, 0.32, 0.55)
const PORTAL_COLOR := Color(0.45, 0.78, 1.0, 0.9)
const ENEMY_COLOR := Color(0.95, 0.25, 0.18, 0.9)
const CHAMPION_COLOR := Color(1.0, 0.82, 0.3, 0.95)
const PLAYER_COLOR := Color(1.0, 0.86, 0.35)
## Unidades del mundo que entran en el alto del recuadro.
const WORLD_SPAN: float = 9000.0
## Parte de la pantalla que ocupa el recuadro.
const AREA := Vector2(0.62, 0.66)

var _view: Control


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view = Control.new()
	_view.anchor_left = (1.0 - AREA.x) / 2.0
	_view.anchor_right = 1.0 - _view.anchor_left
	_view.anchor_top = (1.0 - AREA.y) / 2.0 - 0.04
	_view.anchor_bottom = _view.anchor_top + AREA.y
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_map)
	add_child(_view)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_overlay_map"):
		visible = not visible
		sfx.play("page", -8.0)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		_view.queue_redraw()


# Ejes de la camara proyectados al piso: "derecha" y "adelante" en pantalla.
func _camera_axes() -> Array[Vector2]:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return [Vector2.RIGHT, Vector2.UP]
	var right: Vector3 = camera.global_basis.x
	var forward: Vector3 = -camera.global_basis.z
	return [Vector2(right.x, right.z).normalized(), Vector2(forward.x, forward.z).normalized()]


func _to_view(world_xz: Vector2, origin: Vector2, axes: Array[Vector2]) -> Vector2:
	var rel: Vector2 = world_xz - origin
	var scale: float = _view.size.y / WORLD_SPAN
	return _view.size / 2.0 + Vector2(rel.dot(axes[0]), -rel.dot(axes[1])) * scale


func _draw_map() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var origin := Vector2(player.global_position.x, player.global_position.z)
	var axes: Array[Vector2] = _camera_axes()

	var texture: Texture2D = world_map.get_map_texture()
	if texture:
		var world: Rect2 = world_map.world_rect()
		var px: Vector2 = world.size / Vector2(texture.get_size())
		var corner: Vector2 = _to_view(world.position, origin, axes)
		var x_axis: Vector2 = _to_view(world.position + Vector2(px.x, 0.0), origin, axes) - corner
		var y_axis: Vector2 = _to_view(world.position + Vector2(0.0, px.y), origin, axes) - corner
		_view.draw_set_transform_matrix(Transform2D(x_axis, y_axis, corner))
		_view.draw_texture(texture, Vector2.ZERO, MAP_TINT)
		_view.draw_texture_rect(world_map.get_fog_texture(), Rect2(Vector2.ZERO, texture.get_size()), false, FOG_TINT)
		_view.draw_set_transform_matrix(Transform2D.IDENTITY)

	var bounds := Rect2(Vector2.ZERO, _view.size).grow(-6.0)
	for npc in get_tree().get_nodes_in_group("npcs"):
		var pos: Vector2 = _to_view(Vector2(npc.global_position.x, npc.global_position.z), origin, axes)
		if not bounds.has_point(pos):
			continue
		if npc.is_in_group("portals"):
			if npc.is_discovered():
				_icon(PORTAL_ICON, pos, PORTAL_COLOR, 24.0)
		elif npc.get("map_icon") != null:
			_icon(npc.map_icon, pos, Color(npc.map_icon_color, 0.9), 18.0)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var pos: Vector2 = _to_view(Vector2(enemy.global_position.x, enemy.global_position.z), origin, axes)
		if bounds.has_point(pos):
			var champion: bool = enemy.get("champion") == true
			_view.draw_circle(pos, 5.0 if champion else 3.5, CHAMPION_COLOR if champion else ENEMY_COLOR)

	# El jugador: flecha hacia donde mira.
	var center: Vector2 = _view.size / 2.0
	var facing3: Vector3 = player.global_basis.z
	var facing := Vector2(facing3.x, facing3.z)
	var dir := Vector2(facing.dot(axes[0]), -facing.dot(axes[1])).normalized()
	var side := Vector2(-dir.y, dir.x)
	var arrow := PackedVector2Array([center + dir * 11.0, center - dir * 6.0 + side * 6.0, center - dir * 2.5, center - dir * 6.0 - side * 6.0])
	_view.draw_colored_polygon(arrow, PLAYER_COLOR)
	_view.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0, 0, 0, 0.9), 1.5)
	_view.draw_rect(Rect2(Vector2.ZERO, _view.size), FRAME, false, 2.0)


func _icon(texture: Texture2D, center: Vector2, color: Color, size: float) -> void:
	var rect := Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size))
	_view.draw_texture_rect(texture, Rect2(rect.position + Vector2(1.5, 1.5), rect.size), false, Color(0, 0, 0, 0.6))
	_view.draw_texture_rect(texture, rect, false, color)
