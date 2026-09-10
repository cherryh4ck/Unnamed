extends Node3D

@export var player: NodePath
@export var distancia: float = 1300.0
@export var angulo_grados: float = 35.0
@export var velocity: float = 5.0

var player_node: Node3D

func _ready():
	player_node = get_node(player)
	$Camera3D.projection = Camera3D.PROJECTION_PERSPECTIVE
	$Camera3D.fov = 80
	_actualizar_offset()
	$Camera3D.look_at(global_position, Vector3.UP)

func _actualizar_offset():
	var rad = deg_to_rad(angulo_grados)
	var horizontal_total = distancia * cos(rad)
	var y = distancia * sin(rad)
	var x = horizontal_total / sqrt(2)
	var z = horizontal_total / sqrt(2)
	$Camera3D.position = Vector3(x, y, z)

func _process(delta):
	if player_node:
		var objective = player_node.global_position
		global_position = global_position.lerp(objective, velocity * delta)
