extends CharacterBody3D

@export var speed := 60.0
@export var detection_range := 40.0
@export var attack_range := 3
@export var damage := 10
@export var attack_cooldown := 1.0

var player: Node3D
var can_attack := true
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	
	if player == null:
		print("NO ENCUENTRO AL JUGADOR")
		return
	print("distancia: ", global_position.distance_to(player.global_position))
	
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var move_dir := Vector3.ZERO

	if player != null:
		var to_player = player.global_position - global_position
		to_player.y = 0.0  # ignorar diferencia de altura
		var dist = to_player.length()

		if dist <= attack_range:
			_face(to_player)
			_attack()
		elif dist <= detection_range:
			move_dir = to_player.normalized()
			_face(move_dir)

	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	move_and_slide()

func _face(dir: Vector3):
	if dir.length() > 0.01:
		look_at(global_position + dir, Vector3.UP)

func _attack():
	if not can_attack:
		return
	can_attack = false
	if player.has_method("take_damage"):
		player.take_damage(damage)
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
