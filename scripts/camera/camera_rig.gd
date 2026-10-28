extends Node3D

const zoom = [400.0, 850.0, 1650.0]

@export var player: NodePath
@export var distancia: float = 1200.0
@export var angulo_grados: float = 55.0
@export var velocity: float = 5.0
@export var velocidad_zoom: float = 2000.0

var player_node: Node3D
var modo_actual: int = 1
var distancia_objetivo: float = 1200.0

func _ready():
	player_node = get_node(player)
	global_position = player_node.global_position
	distancia_objetivo = zoom[modo_actual]
	distancia = distancia_objetivo
	$Camera3D.projection = Camera3D.PROJECTION_PERSPECTIVE
	$Camera3D.fov = 80
	_actualizar_offset()
	$Camera3D.look_at(global_position, Vector3.UP)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			modo_actual = max(modo_actual - 1, 0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			modo_actual = min(modo_actual + 1, zoom.size() - 1)
		distancia_objetivo = zoom[modo_actual]

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
	if not is_equal_approx(distancia, distancia_objetivo):
		distancia = move_toward(distancia, distancia_objetivo, velocidad_zoom * delta)
		_actualizar_offset()
