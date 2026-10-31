extends Node

## Desvanece las piezas altas (arboles, casas, muros, rocas) que quedan entre
## la camara y el jugador, como en Sacred. Tambien las que tapan a los
## enemigos que lo estan peleando cerca y a un cofre sin abrir cercano. Las
## piezas se anotan solas en el grupo "occluders" (ver scripts/world/prop.gd).
## Con el renderizador Mobile GeometryInstance3D.transparency no hace nada,
## asi que mientras una pieza esta desvanecida usa copias transparentes de sus
## materiales, y una copia que solo tira la sombra (la sombra no se borra).
## Las copias se arman la primera vez y se guardan para la proxima.

## Solo se revisan las piezas a esta distancia del jugador.
const CHECK_RADIUS: float = 2200.0
const FADED: float = 0.85
const SPEED: float = 6.0
## Puntos del jugador que tienen que verse (pies, pecho, cabeza), cada uno en
## el centro y a los costados segun la camara (asi cuenta todo el cuerpo).
const BODY_HEIGHTS := [60.0, 220.0, 380.0]
const BODY_HALF_WIDTH: float = 80.0
## Enemigos peleando a esta distancia del jugador tambien se dejan ver.
const FIGHT_RADIUS: float = 1000.0
const FIGHT_HEIGHT: float = 200.0
## Lo que queda casi pegado a la camara tambien se desvanece (tapa media pantalla).
const NEAR_CAMERA: float = 350.0
## Los cofres sin abrir a esta distancia del jugador tambien se dejan ver.
const CHEST_RADIUS: float = 1300.0
const CHEST_HEIGHT: float = 70.0
## Tamaño de las celdas de la grilla con la que se buscan las piezas cercanas.
const CELL: float = 1000.0


## Una pieza desvanecida: cuanto, sus materiales transparentes y como dejarla
## como estaba.
class Fade:
	var value: float = 0.0
	var materials: Array[BaseMaterial3D] = []
	var alphas: Array[float] = []
	## [malla, superficie (-1 = material_override), material original, copia]
	var swaps: Array = []
	## [malla, cast_shadow original, copia que tira la sombra]
	var shadows: Array = []


var _faded: Dictionary = {}
## Pieza -> Fade ya armado (se reusa en vez de copiar los materiales otra vez).
var _cache: Dictionary = {}
var _grid: Dictionary = {}
var _grid_count: int = -1


func _process(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var camera: Camera3D = get_viewport().get_camera_3d()
	if player == null or camera == null:
		return
	var eye: Vector3 = camera.global_position
	var side: Vector3 = camera.global_transform.basis.x * BODY_HALF_WIDTH
	var points: Array[Vector3] = []
	for height in BODY_HEIGHTS:
		var point: Vector3 = player.global_position + Vector3.UP * height
		points.append_array([point, point + side, point - side])
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.state >= enemy.State.CHASE and enemy.global_position.distance_to(player.global_position) < FIGHT_RADIUS:
			points.append(enemy.global_position + Vector3.UP * FIGHT_HEIGHT)
	for chest in get_tree().get_nodes_in_group("chests"):
		if not chest.opened and chest.global_position.distance_to(player.global_position) < CHEST_RADIUS:
			points.append(chest.global_position + Vector3.UP * CHEST_HEIGHT)

	var targets: Dictionary = {}
	for prop in _nearby(player.global_position):
		var bounds: AABB = prop.world_bounds
		if bounds.grow(NEAR_CAMERA).has_point(eye):
			targets[prop] = true
			continue
		for point in points:
			if bounds.intersects_segment(eye, point):
				targets[prop] = true
				break

	for prop in targets:
		if not _faded.has(prop):
			_faded[prop] = _begin(prop)
	for prop in _faded.keys():
		var fade: Fade = _faded[prop]
		if not is_instance_valid(prop):
			_faded.erase(prop)
			_cache.erase(prop)
			continue
		var goal: float = FADED if targets.has(prop) else 0.0
		fade.value = move_toward(fade.value, goal, SPEED * delta)
		for i in fade.materials.size():
			fade.materials[i].albedo_color.a = fade.alphas[i] * (1.0 - fade.value)
		if fade.value <= 0.0 and goal <= 0.0:
			_end(fade)
			_faded.erase(prop)


# Las piezas no se mueven: se reparten una vez en una grilla y despues solo
# se miran las celdas alrededor del jugador.
func _nearby(center: Vector3) -> Array:
	var occluders: Array[Node] = get_tree().get_nodes_in_group("occluders")
	if occluders.size() != _grid_count:
		_grid.clear()
		_grid_count = occluders.size()
		for prop in occluders:
			var key := Vector2i(floori(prop.world_bounds.get_center().x / CELL), floori(prop.world_bounds.get_center().z / CELL))
			if not _grid.has(key):
				_grid[key] = []
			_grid[key].append(prop)
	var result: Array = []
	var reach: int = ceili(CHECK_RADIUS / CELL)
	var here := Vector2i(floori(center.x / CELL), floori(center.z / CELL))
	for x in range(here.x - reach, here.x + reach + 1):
		for z in range(here.y - reach, here.y + reach + 1):
			for prop in _grid.get(Vector2i(x, z), []):
				if is_instance_valid(prop):
					result.append(prop)
	return result


# Pone las copias transparentes de los materiales y prende la copia que tira
# la sombra.
func _begin(prop: Node) -> Fade:
	if not _cache.has(prop):
		_cache[prop] = _prepare(prop)
	var fade: Fade = _cache[prop]
	for swap in fade.swaps:
		var mesh: MeshInstance3D = swap[0]
		if swap[1] < 0:
			mesh.material_override = swap[3]
		else:
			mesh.set_surface_override_material(swap[1], swap[3])
	for entry in fade.shadows:
		entry[0].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		entry[2].visible = true
	return fade


# Arma (una sola vez por pieza) las copias de los materiales y de la sombra.
func _prepare(prop: Node) -> Fade:
	var fade := Fade.new()
	for node in prop.meshes:
		var mesh := node as MeshInstance3D
		if not is_instance_valid(mesh):
			continue
		if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			var shadow := MeshInstance3D.new()
			shadow.mesh = mesh.mesh
			shadow.material_override = mesh.material_override
			for i in mesh.get_surface_override_material_count():
				shadow.set_surface_override_material(i, mesh.get_surface_override_material(i))
			shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			shadow.visible = false
			mesh.add_child(shadow)
			fade.shadows.append([mesh, mesh.cast_shadow, shadow])
		if mesh.material_override is BaseMaterial3D:
			fade.swaps.append([mesh, -1, mesh.material_override, _transparent_copy(mesh.material_override, fade)])
			continue
		for i in mesh.get_surface_override_material_count():
			var active: Material = mesh.get_active_material(i)
			if active is BaseMaterial3D:
				fade.swaps.append([mesh, i, mesh.get_surface_override_material(i), _transparent_copy(active, fade)])
	return fade


func _transparent_copy(base: BaseMaterial3D, fade: Fade) -> BaseMaterial3D:
	var copy: BaseMaterial3D = base.duplicate()
	copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	copy.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	fade.materials.append(copy)
	fade.alphas.append(base.albedo_color.a)
	return copy


# Deja la pieza como estaba.
func _end(fade: Fade) -> void:
	for swap in fade.swaps:
		var mesh: MeshInstance3D = swap[0]
		if not is_instance_valid(mesh):
			continue
		if swap[1] < 0:
			mesh.material_override = swap[2]
		else:
			mesh.set_surface_override_material(swap[1], swap[2])
	for entry in fade.shadows:
		if is_instance_valid(entry[0]):
			entry[0].cast_shadow = entry[1]
			entry[2].visible = false
