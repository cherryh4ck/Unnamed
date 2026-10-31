extends Node3D

## Camara que sigue al jugador desde arriba en diagonal. La rueda acerca y
## aleja de a poco y sin saltos; manteniendo el boton del medio se gira
## alrededor del jugador (doble clic del medio la deja como estaba).
## shake() la sacude un instante (golpes fuertes).

const ZOOM_MIN: float = 400.0
const ZOOM_MAX: float = 1650.0
const ZOOM_DEFAULT: float = 850.0
## Cuanto se acerca o aleja por cada paso de la rueda.
const ZOOM_STEP: float = 1.15
## Que tan rapido llega al zoom y al giro pedidos (mas = mas rapido).
const SMOOTH: float = 9.0
## Grados de giro por pixel de mouse con el boton del medio apretado.
const ROTATE_SPEED: float = 0.3

@export var player: NodePath
@export var distancia: float = 1200.0
@export var angulo_grados: float = 55.0
@export var velocity: float = 5.0

var player_node: Node3D
var distancia_objetivo: float = ZOOM_DEFAULT
var _yaw_base: float = 0.0
var _yaw_target: float = 0.0
var _rotating: bool = false
var _shake_left: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0

@onready var _camera: Camera3D = $Camera3D


func _ready():
	player_node = get_node(player)
	global_position = player_node.global_position
	distancia = distancia_objetivo
	_yaw_base = rotation.y
	_yaw_target = _yaw_base
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 80
	_actualizar_offset()
	_camera.look_at(global_position, Vector3.UP)
	# Distancia de dibujo de las opciones graficas; el sol tambien las toma.
	_apply_options()
	options.changed.connect(_apply_options)
	options.apply_graphics()


func _apply_options() -> void:
	_camera.far = options.view_distance()

## Se pone de una sobre el jugador (al viajar o reaparecer).
func snap() -> void:
	if player_node:
		global_position = player_node.global_position


## Sacude la camara: strength en pixeles de pantalla, durante duration segundos.
func shake(strength: float, duration: float) -> void:
	if strength >= _shake_strength * (_shake_left / maxf(_shake_duration, 0.001)):
		_shake_strength = strength
		_shake_duration = duration
		_shake_left = duration


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distancia_objetivo = maxf(distancia_objetivo / ZOOM_STEP, ZOOM_MIN)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distancia_objetivo = minf(distancia_objetivo * ZOOM_STEP, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_rotating = event.pressed and not event.double_click
			if event.pressed and event.double_click:
				_yaw_target = _yaw_base
	elif event is InputEventMouseMotion and _rotating:
		_yaw_target -= deg_to_rad(event.relative.x * ROTATE_SPEED)

func _actualizar_offset():
	var rad = deg_to_rad(angulo_grados)
	var horizontal_total = distancia * cos(rad)
	var y = distancia * sin(rad)
	var x = horizontal_total / sqrt(2)
	var z = horizontal_total / sqrt(2)
	_camera.position = Vector3(x, y, z)

func _process(delta):
	if player_node:
		var objective = player_node.global_position
		global_position = global_position.lerp(objective, velocity * delta)
	var smooth: float = 1.0 - exp(-SMOOTH * delta)
	if not is_equal_approx(distancia, distancia_objetivo):
		distancia = lerpf(distancia, distancia_objetivo, smooth)
		if absf(distancia - distancia_objetivo) < 0.5:
			distancia = distancia_objetivo
		_actualizar_offset()
	rotation.y = lerp_angle(rotation.y, _yaw_target, smooth)
	_update_shake(delta)


func _update_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	var amount: float = _shake_strength * (_shake_left / _shake_duration)
	# Desplazamiento en pantalla (h_offset/v_offset), sin mover la camara.
	var pixels_to_units: float = distancia / 900.0
	_camera.h_offset = randf_range(-1.0, 1.0) * amount * pixels_to_units
	_camera.v_offset = randf_range(-1.0, 1.0) * amount * pixels_to_units
	if _shake_left <= 0.0:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
