extends CharacterBody3D

signal died

@export var speed := 100.0
@export var detection_range := 500.0
@export var attack_range := 8.0
@export var damage := 10
@export var attack_cooldown := 1.0
@export var attack_hit_delay := 0.3
@export var max_health := 50.0

var player: Node3D
var can_attack := true
var dead := false
var current_health: float
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	current_health = max_health
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if dead or player == null:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var move_dir := Vector3.ZERO
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if dist <= attack_range:
		_face(to_player)
		_attack()
	elif dist <= detection_range:
		move_dir = to_player.normalized()
		_face(move_dir)

	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	move_and_slide()


func _face(dir: Vector3) -> void:
	if dir.length() > 0.01:
		rotation.y = atan2(dir.x, dir.z)


func _attack() -> void:
	if not can_attack:
		return
	can_attack = false

	await get_tree().create_timer(attack_hit_delay).timeout
	if not dead and player != null:
		if global_position.distance_to(player.global_position) <= attack_range * 1.5:
			_damage_player()

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func _damage_player() -> void:
	if player.has_method("take_damage"):
		player.take_damage(damage)


func take_damage(amount: float) -> void:
	if dead:
		return
	current_health = max(current_health - amount, 0.0)
	if current_health <= 0.0:
		_die()


func _die() -> void:
	dead = true
	velocity = Vector3.ZERO
	collision_layer = 0
	died.emit()
	queue_free()
