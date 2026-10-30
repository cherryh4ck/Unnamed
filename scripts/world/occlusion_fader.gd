extends Node

## Desvanece las piezas altas (arboles, casas, muros) que quedan entre la
## camara y el jugador, como en los ARPG con camara desde arriba. Las piezas
## se anotan solas en el grupo "occluders" (ver scripts/world/prop.gd).

## Solo se revisan las piezas a esta distancia del jugador.
const CHECK_RADIUS: float = 2200.0
const FADED: float = 0.72
const SPEED: float = 6.0
## Puntos del jugador que tienen que verse (pies, pecho, cabeza).
const BODY_HEIGHTS := [60.0, 220.0, 380.0]
## Lo que queda casi pegado a la camara tambien se desvanece (tapa media pantalla).
const NEAR_CAMERA: float = 350.0

var _faded: Dictionary = {}


func _process(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var camera: Camera3D = get_viewport().get_camera_3d()
	if player == null or camera == null:
		return
	var eye: Vector3 = camera.global_position
	var targets: Dictionary = {}
	for prop in get_tree().get_nodes_in_group("occluders"):
		var bounds: AABB = prop.world_bounds
		if Vector2(bounds.get_center().x - player.global_position.x, bounds.get_center().z - player.global_position.z).length() > CHECK_RADIUS:
			continue
		if bounds.grow(NEAR_CAMERA).has_point(eye):
			targets[prop] = true
			continue
		for height in BODY_HEIGHTS:
			if bounds.intersects_segment(eye, player.global_position + Vector3.UP * height):
				targets[prop] = true
				break

	for prop in targets:
		if not _faded.has(prop):
			_faded[prop] = 0.0
	for prop in _faded.keys():
		if not is_instance_valid(prop):
			_faded.erase(prop)
			continue
		var goal: float = FADED if targets.has(prop) else 0.0
		var value: float = move_toward(_faded[prop], goal, SPEED * delta)
		_faded[prop] = value
		for mesh in prop.meshes:
			if is_instance_valid(mesh):
				mesh.transparency = value
		if value <= 0.0 and goal <= 0.0:
			_faded.erase(prop)
