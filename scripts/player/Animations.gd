extends Node3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var character: CharacterBody3D = get_parent()
@onready var nav_agent: NavigationAgent3D = character.get_node("NavigationAgent3D")

var walk_animations: Array[String] = ["85_BT2_2", "85_BT2_1"]
var walk_step_index: int = 0
var was_moving: bool = false
var rotation_speed: float = 8.0


func _ready() -> void:
	var idle_anim: Animation = anim_player.get_animation("85_BT2_0")
	idle_anim.loop_mode = Animation.LOOP_LINEAR

	for anim_name in walk_animations:
		var walk_anim: Animation = anim_player.get_animation(anim_name)
		if walk_anim:
			walk_anim.loop_mode = Animation.LOOP_NONE

	anim_player.animation_finished.connect(_on_animation_finished)
	anim_player.play("85_BT2_0")


func _process(delta: float) -> void:
	var moving: bool = not nav_agent.is_navigation_finished()

	if moving and not was_moving:
		# Recién arranca a caminar.
		walk_step_index = 0
		_play_current_step()
	elif not moving and was_moving:
		# Recién se detuvo.
		anim_player.play("85_BT2_0")

	_face_movement_direction(delta)
	was_moving = moving


func _on_animation_finished(anim_name: StringName) -> void:
	print("termino: ", anim_name)
	# Si la que termino es un paso de caminar Y todavia me estoy moviendo,
	# paso al siguiente pie.
	if anim_name in walk_animations and not nav_agent.is_navigation_finished():
		walk_step_index = (walk_step_index + 1) % walk_animations.size()
		_play_current_step()


func _play_current_step() -> void:
	print("reproduciendo paso: ", walk_animations[walk_step_index])
	anim_player.play(walk_animations[walk_step_index])


func _face_movement_direction(delta: float) -> void:
	var direction: Vector3 = character.velocity
	direction.y = 0.0
	if direction.length() < 0.01:
		return

	var target_angle = atan2(direction.x, direction.z)
	character.rotation.y = lerp_angle(character.rotation.y, target_angle, rotation_speed * delta)
