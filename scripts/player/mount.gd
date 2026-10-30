extends Node3D

## Montura (tecla M): aparece un caballo debajo del jugador, que se mueve mas
## rapido y suena a cascos. Se puede pelear montado. No se puede montar con
## enemigos cerca y al morir se desmonta.
## El caballo es provisorio: esta armado con cajas hasta que haya un modelo.

## Velocidad de movimiento montado respecto de a pie.
const SPEED_MULT: float = 1.7
## Cuanto sube el jinete para quedar sentado sobre el lomo.
const RIDER_LIFT: float = 165.0
## Para montar no tiene que haber enemigos a esta distancia.
const SAFE_DISTANCE: float = 700.0
## Pasos mas seguidos y graves: cascos.
const STEP_INTERVAL: float = 0.2
const STEP_PITCH: float = 0.7
const GALLOP_SPEED: float = 11.0
const COAT_COLOR := Color(0.42, 0.27, 0.16)
const DARK_COLOR := Color(0.12, 0.08, 0.06)
const SADDLE_COLOR := Color(0.3, 0.17, 0.09)
const BLANKET_COLOR := Color(0.45, 0.1, 0.08)

var mounted: bool = false
## Cuanto esta elevado el jinete ahora (lo usa el retrato del HUD).
var lift: float = 0.0

@onready var character: CharacterBody3D = get_parent()
@onready var rider: Node3D = character.get_node("Player")

var _horse: Node3D
## Torso, cuello y cabeza: rebotan al galopar (las patas van aparte).
var _body: Node3D
var _legs: Array[Node3D] = []
var _rider_base_y: float
var _base_speed: float
var _base_step_interval: float
var _gallop_time: float = 0.0
## 0 = quieto, 1 = galope completo (suaviza el arranque y la frenada).
var _stride: float = 0.0


func _ready() -> void:
	_rider_base_y = rider.position.y
	_base_speed = character.speed
	_base_step_interval = character.intervalo_pasos
	_build_horse()
	player_stats.died.connect(dismount)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mount"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if mounted:
		dismount()
	else:
		mount()


func mount() -> void:
	if mounted or player_stats.dead:
		return
	if _enemy_nearby():
		floating_text.spawn(character.global_position + Vector3.UP * 450.0, "Hay enemigos cerca", Color(0.7, 0.7, 0.7), 16)
		sfx.play("stuck", -6.0)
		return
	mounted = true
	_horse.visible = true
	character.speed = _base_speed * SPEED_MULT
	character.intervalo_pasos = STEP_INTERVAL
	character.reproductor_pasos.pitch_scale = STEP_PITCH
	_set_lift(RIDER_LIFT)
	_puff()


func dismount() -> void:
	if not mounted:
		return
	mounted = false
	_horse.visible = false
	character.speed = _base_speed
	character.intervalo_pasos = _base_step_interval
	character.reproductor_pasos.pitch_scale = 1.0
	_stride = 0.0
	_set_lift(0.0)
	_puff()


func _process(delta: float) -> void:
	if not mounted:
		return
	_stride = move_toward(_stride, 1.0 if character.is_moving() else 0.0, delta * 5.0)
	_gallop_time += delta * GALLOP_SPEED * _stride
	# Trote: las patas en diagonal se mueven juntas.
	for i in _legs.size():
		var phase: float = 0.0 if i == 0 or i == 3 else PI
		_legs[i].rotation.x = sin(_gallop_time + phase) * 0.55 * _stride
	var bob: float = absf(sin(_gallop_time)) * 14.0 * _stride
	_body.position.y = bob
	_set_lift(RIDER_LIFT + bob)


func _set_lift(value: float) -> void:
	lift = value
	rider.position.y = _rider_base_y + lift


func _enemy_nearby() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(character.global_position) < SAFE_DISTANCE:
			return true
	return false


func _puff() -> void:
	Effects.dust_puff(character.get_parent(), character.global_position + Vector3.UP * 20.0, 140.0)
	sfx.play("portal", -12.0)


# --- Caballo provisorio ----------------------------------------------------
# Mira hacia +Z, igual que el modelo del jugador.

func _build_horse() -> void:
	_horse = Node3D.new()
	_horse.name = "Horse"
	_horse.visible = false
	add_child(_horse)
	var coat := _material(COAT_COLOR)
	var dark := _material(DARK_COLOR)

	_body = Node3D.new()
	_horse.add_child(_body)
	_box(_body, Vector3(130, 120, 400), Vector3(0, 255, 0), coat)                     # torso
	_box(_body, Vector3(72, 200, 95), Vector3(0, 365, 240), coat, 35.0)                # cuello
	_box(_body, Vector3(18, 170, 30), Vector3(0, 385, 205), dark, 35.0)                # crin
	_box(_body, Vector3(62, 66, 165), Vector3(0, 440, 330), coat, 25.0)                # cabeza
	for x in [-18.0, 18.0]:
		_box(_body, Vector3(14, 34, 12), Vector3(x, 482, 292), coat)                      # orejas
	_box(_body, Vector3(26, 150, 28), Vector3(0, 245, -230), dark, 25.0)               # cola
	_box(_body, Vector3(146, 70, 140), Vector3(0, 290, -15), _material(BLANKET_COLOR)) # manta
	_box(_body, Vector3(150, 26, 130), Vector3(0, 326, -15), _material(SADDLE_COLOR))  # montura

	# Atras izquierda, adelante izquierda, atras derecha, adelante derecha.
	for x in [-42.0, 42.0]:
		for z in [-150.0, 150.0]:
			var hip := Node3D.new()
			hip.position = Vector3(x, 200, z)
			_horse.add_child(hip)
			_box(hip, Vector3(32, 185, 32), Vector3(0, -92, 0), coat)
			_box(hip, Vector3(36, 22, 38), Vector3(0, -190, 0), dark)                   # casco
			_legs.append(hip)


func _box(parent: Node3D, size: Vector3, offset: Vector3, material: Material, tilt_deg: float = 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	instance.rotation.x = deg_to_rad(tilt_deg)
	# Capa 2: la camara del retrato del HUD no la dibuja (si no, el cuello
	# del caballo tapa la cara del jinete).
	instance.layers = 2
	parent.add_child(instance)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
