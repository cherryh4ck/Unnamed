extends Node3D

## Animaciones del jugador: idle, pasos al caminar, ataque y muerte.
## Los nombres son del AnimationPlayer del modelo; se pueden cambiar
## desde el inspector si alguna no es la correcta.

@export var idle_animation: String = "85_BT2_0"
@export var walk_animations: Array[String] = ["85_BT2_2", "85_BT2_1"]
@export var attack_animations: Array[String] = ["85_BT2_15", "85_BT2_16"]
@export var death_animation: String = "85_BT2_9"

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var character: CharacterBody3D = get_parent()
@onready var combat: Node = character.get_node("Combat")

var walk_step_index: int = 0
var attack_index: int = 0
var was_moving: bool = false
var attacking: bool = false
var rotation_speed: float = 8.0


func _ready() -> void:
	_set_loop(idle_animation, Animation.LOOP_LINEAR)
	for anim_name in walk_animations + attack_animations + [death_animation]:
		_set_loop(anim_name, Animation.LOOP_NONE)

	anim_player.animation_finished.connect(_on_animation_finished)
	combat.attack_started.connect(_on_attack_started)
	player_stats.died.connect(_on_died)
	player_stats.respawned.connect(_on_respawned)
	anim_player.play(idle_animation)


func _set_loop(anim_name: String, mode: Animation.LoopMode) -> void:
	var anim: Animation = anim_player.get_animation(anim_name)
	if anim:
		anim.loop_mode = mode


func _process(delta: float) -> void:
	if player_stats.dead:
		return
	var moving: bool = character.is_moving()

	if moving and not was_moving:
		# Recién arranca a caminar (si estaba atacando, se corta el ataque).
		attacking = false
		walk_step_index = 0
		_play_current_step()
	elif not moving and was_moving and not attacking:
		# Recién se detuvo.
		anim_player.play(idle_animation)

	_face_movement_direction(delta)
	was_moving = moving


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name in attack_animations:
		attacking = false
		if character.is_moving():
			_play_current_step()
		else:
			anim_player.play(idle_animation)
	# Si la que termino es un paso de caminar Y todavia me estoy moviendo,
	# paso al siguiente pie.
	elif anim_name in walk_animations and character.is_moving() and not attacking:
		walk_step_index = (walk_step_index + 1) % walk_animations.size()
		_play_current_step()


func _play_current_step() -> void:
	anim_player.play(walk_animations[walk_step_index])


# La animacion de ataque se estira para durar lo mismo que el intervalo
# entre golpes (armas lentas = animacion mas lenta).
func _on_attack_started(interval: float) -> void:
	attacking = true
	var anim_name: String = attack_animations[attack_index]
	attack_index = (attack_index + 1) % attack_animations.size()
	var anim: Animation = anim_player.get_animation(anim_name)
	if anim == null:
		return
	anim_player.play(anim_name, 0.05, anim.length / interval)
	anim_player.seek(0.0, true)


func _on_died() -> void:
	attacking = false
	anim_player.play(death_animation, 0.1)


func _on_respawned() -> void:
	was_moving = false
	anim_player.play(idle_animation)


func _face_movement_direction(delta: float) -> void:
	var direction: Vector3 = character.velocity
	direction.y = 0.0
	if direction.length() < 0.01:
		return

	var target_angle = atan2(direction.x, direction.z)
	character.rotation.y = lerp_angle(character.rotation.y, target_angle, rotation_speed * delta)
