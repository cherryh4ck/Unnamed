extends Node3D

## Montura (tecla M): aparece un caballo debajo del jugador, que se mueve mas
## rapido y suena a cascos. Se puede pelear montado. No se puede montar con
## enemigos cerca y al morir se desmonta.
## Modelo: caballo de Quaternius (CC0, ver CREDITS.md) con sus animaciones de
## quieto, paso y galope.

## Velocidad de movimiento montado respecto de a pie.
const SPEED_MULT: float = 1.7
## Cuanto sube el jinete para quedar sentado sobre el lomo (el clip de montar
## de 0 A.D. deja la cadera a la altura del piso).
const RIDER_LIFT: float = 345.0
## Para montar no tiene que haber enemigos a esta distancia.
const SAFE_DISTANCE: float = 700.0
## Pasos mas seguidos y graves: cascos.
const STEP_INTERVAL: float = 0.2
const STEP_PITCH: float = 0.7
const GALLOP_SPEED: float = 11.0
const HORSE_SCENE := preload("res://assets/animals/horse/qt_horse.glb")
## El modelo mide ~4.5 de alto: a esta escala queda como el jinete lo necesita.
const HORSE_SCALE: float = 108.0
const COAT_TINT := Color(0.72, 0.6, 0.5)

var mounted: bool = false
## Cuanto esta elevado el jinete ahora.
var lift: float = 0.0

@onready var character: CharacterBody3D = get_parent()
@onready var rider: Node3D = character.get_node("Player")

var _horse: Node3D
var _animation: AnimationPlayer
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
	_play("Gallop" if _stride > 0.5 else "Idle")
	# El jinete rebota con el galope.
	var bob: float = absf(sin(_gallop_time)) * 10.0 * _stride
	_set_lift(RIDER_LIFT + bob)


func _play(anim_name: String) -> void:
	if _animation and _animation.current_animation != anim_name:
		_animation.play(anim_name, 0.25)


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


# --- Caballo ---------------------------------------------------------------
# Mira hacia +Z, igual que el modelo del jugador.

func _build_horse() -> void:
	_horse = HORSE_SCENE.instantiate()
	_horse.name = "Horse"
	_horse.visible = false
	_horse.scale = Vector3.ONE * HORSE_SCALE
	add_child(_horse)
	for mesh in _horse.find_children("*", "MeshInstance3D", true, false):
		# Capa 2: la camara del retrato del HUD no lo dibuja (si no, el cuello
		# del caballo tapa la cara del jinete).
		mesh.layers = 2
		for i in mesh.get_surface_override_material_count():
			var base: Material = mesh.get_active_material(i)
			if base is BaseMaterial3D:
				var tinted: BaseMaterial3D = base.duplicate()
				tinted.albedo_color = tinted.albedo_color * COAT_TINT
				mesh.set_surface_override_material(i, tinted)
	_animation = _horse.find_child("AnimationPlayer", true, false)
	if _animation:
		for anim_name in ["Idle", "Walk", "Gallop"]:
			if _animation.has_animation(anim_name):
				_animation.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		_animation.play("Idle")
