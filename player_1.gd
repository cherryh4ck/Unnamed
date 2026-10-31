extends Node3D

## Modelo y animaciones del jugador. El modelo es el de su clase (un
## personaje de 0 A.D., ver scripts/player/player_classes.gd) y se arma al
## cargar la escena; las armas y escudos equipados los pone weapon_hand.gd.
## Animaciones: quieto, correr (sincronizado con la velocidad), ataque,
## habilidades (SkillData.animation es una clave que cada clase traduce a un
## clip), montado y muerte.

const LIBRARY := preload("res://assets/characters/oad/oad_anim_library.glb")
## Los personajes de 0 A.D. miden 1,8 m; a esta escala quedan del alto del mundo.
const MODEL_SCALE: float = 225.0
## Lo que traen en las manos se reemplaza por lo que tiene equipado.
const HELD_PROPS := ["WeaponR", "WeaponL", "WeaponBow", "Shield", "ShieldRim", "ShieldBoss"]
const BLEND: float = 0.15
const WeaponTrail := preload("res://scripts/player/weapon_trail.gd")
## Chispas del escudo al bloquear un golpe.
const BLOCK_COLOR := Color(1.0, 0.88, 0.55)

@onready var character: CharacterBody3D = get_parent()
@onready var combat: Node = character.get_node("Combat")
@onready var mount: Node3D = character.get_node("Mount")

var model: Node3D
var anim_player: AnimationPlayer
var skeleton: Skeleton3D
var anims: Dictionary = {}
var attack_index: int = 0
## Animacion de ataque o habilidad en curso (para saber cuando termina).
var action_animation: String = ""
var attacking: bool = false
var rotation_speed: float = 14.0


func _ready() -> void:
	_build_model()
	anim_player.animation_finished.connect(_on_animation_finished)
	combat.attack_started.connect(_on_attack_started)
	combat.skill_animation.connect(_on_skill_animation)
	player_stats.died.connect(_on_died)
	player_stats.respawned.connect(_on_respawned)
	var trail := WeaponTrail.new()
	trail.name = "Estela"
	add_child(trail)
	_play_base()


func _build_model() -> void:
	var info: Dictionary = PlayerClasses.get_info(player_stats.class_id)
	anims = info.anims
	model = load(info.model).instantiate()
	model.name = "Modelo"
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)
	move_child(model, 0)
	for prop_name in HELD_PROPS:
		var prop: Node = model.find_child(prop_name, true, false)
		if prop:
			prop.queue_free()
	anim_player = model.find_child("AnimationPlayer", true, false)
	skeleton = model.find_child("Skeleton3D", true, false)
	# Clips de los otros personajes (mismo esqueleto): "oad/<clip>".
	var library_scene: Node = LIBRARY.instantiate()
	var library_player: AnimationPlayer = library_scene.find_child("AnimationPlayer", true, false)
	anim_player.add_animation_library("oad", library_player.get_animation_library(""))
	library_scene.free()
	for anim_name in [anims.idle, anims.run, anims.ride_idle, anims.ride_move]:
		_set_loop(anim_name, Animation.LOOP_LINEAR)


## Posicion global de un hueso del modelo. El retrato del HUD sigue la cabeza
## ("head") y la vista del inventario la cadera ("hip"), asi encuadran bien
## a pie, montado (el clip de montar baja al jinete) o en el suelo.
func bone_position(bone: String) -> Vector3:
	if skeleton == null:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


func _set_loop(anim_name: String, mode: Animation.LoopMode) -> void:
	if anim_player.has_animation(anim_name):
		anim_player.get_animation(anim_name).loop_mode = mode


func _process(delta: float) -> void:
	if player_stats.dead:
		return
	# Arrancar a caminar corta el ataque (salvo montado: se pelea a caballo).
	if attacking and character.is_moving() and not mount.mounted:
		attacking = false
	if not attacking:
		_play_base()
	_face_movement_direction(delta)


# Quieto, corriendo o montado, segun lo que este haciendo.
func _play_base() -> void:
	var moving: bool = character.is_moving()
	var anim_name: String = anims.idle
	var speed: float = 1.0
	if mount.mounted:
		anim_name = anims.ride_move if moving else anims.ride_idle
	elif moving:
		anim_name = anims.run
		# Al arrancar y frenar las piernas van al ritmo de la velocidad real.
		speed = maxf(character.ground_speed(), character.speed * 0.5) / (anims.run_speed * MODEL_SCALE)
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name, BLEND)
	anim_player.speed_scale = speed


func _on_animation_finished(anim_name: StringName) -> void:
	if attacking and anim_name == action_animation:
		attacking = false
		_play_base()


# La animacion de ataque se estira para durar lo mismo que el intervalo
# entre golpes (armas lentas = animacion mas lenta).
func _on_attack_started(interval: float) -> void:
	var list: Array = anims.attacks
	var anim_name: String = list[attack_index % list.size()]
	attack_index += 1
	_play_action(anim_name, anims.attack_from, interval)


func _on_skill_animation(key: String, speed: float) -> void:
	var entry: Array = anims.skills.get(key, [key, 0.0])
	var anim: Animation = anim_player.get_animation(entry[0]) if anim_player.has_animation(entry[0]) else null
	if anim:
		_play_action(entry[0], entry[1], anim.length * (1.0 - entry[1]) / speed)


# Reproduce el clip desde la fraccion from para que dure duration segundos.
func _play_action(anim_name: String, from: float, duration: float) -> void:
	if not anim_player.has_animation(anim_name):
		return
	var anim: Animation = anim_player.get_animation(anim_name)
	attacking = true
	action_animation = anim_name
	anim.loop_mode = Animation.LOOP_NONE
	anim_player.play(anim_name, 0.05)
	anim_player.speed_scale = maxf(anim.length * (1.0 - from) / maxf(duration, 0.05), 0.2)
	anim_player.seek(anim.length * from, true)


## Bloqueo con el escudo: chispas, ruido metalico y el escudo da un salto.
func play_block() -> void:
	var at: Vector3 = bone_position("prop-shield")
	Effects.burst(character.get_parent(), at, BLOCK_COLOR, 16, 30.0)
	sfx.play_at("block", at, -2.0)
	var holder: Node = skeleton.get_node_or_null("Equipo_prop-shield") if skeleton else null
	if holder == null or holder.get_child_count() == 0:
		return
	var shield: Node3D = holder.get_child(0)
	if not shield.has_meta("base_scale"):
		shield.set_meta("base_scale", shield.scale)
	var base: Vector3 = shield.get_meta("base_scale")
	var tween := shield.create_tween()
	tween.tween_property(shield, "scale", base * 1.18, 0.05)
	tween.tween_property(shield, "scale", base, 0.14)


func _on_died() -> void:
	attacking = false
	anim_player.speed_scale = 1.0
	anim_player.play(anims.death, 0.1)


func _on_respawned() -> void:
	attacking = false
	_play_base()


func _face_movement_direction(delta: float) -> void:
	var direction: Vector3 = character.velocity
	direction.y = 0.0
	if direction.length() < 0.01:
		return

	var target_angle = atan2(direction.x, direction.z)
	character.rotation.y = lerp_angle(character.rotation.y, target_angle, rotation_speed * delta)
