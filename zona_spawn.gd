extends Node3D

@export var enemy_scene: PackedScene
@export var spawn_interval := 3.0
@export var max_enemies := 10

@onready var zone_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var timer: Timer = $Timer

var enemies_alive := 0

func _ready():
	timer.wait_time = spawn_interval
	timer.timeout.connect(_spawn_enemy)
	timer.start()

func _spawn_enemy():
	if enemies_alive >= max_enemies:
		return

	var size: Vector3 = zone_shape.shape.size
	var local_point = Vector3(
		randf_range(-size.x / 2.0, size.x / 2.0),
		0.0,
		randf_range(-size.z / 2.0, size.z / 2.0)
	)

	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	# Convierte el punto local de la caja a posición global (respeta escala y rotación)
	enemy.global_position = zone_shape.global_transform * local_point

	enemies_alive += 1
	enemy.tree_exited.connect(func(): enemies_alive -= 1)
