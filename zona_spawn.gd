extends Node3D

@export var enemy_scene: PackedScene
@export var spawn_interval := 3.0
@export var max_enemies := 10
## Nivel de los enemigos de esta zona (escala vida, daño y experiencia).
@export var level := 1
## Tipos que pueden aparecer. Si se deja vacio usa esqueleto, zombi y guerrero.
@export var enemy_types: Array[EnemyData] = []
## Peso de cada tipo (mismo orden que enemy_types). Vacio = todos igual de probables.
@export var type_weights: Array[float] = []

@onready var zone_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var timer: Timer = $Timer

var enemies_alive := 0

func _ready():
	if enemy_types.is_empty():
		enemy_types = [
			load("res://enemies/types/esqueleto.tres"),
			load("res://enemies/types/zombie.tres"),
			load("res://enemies/types/esqueleto_guerrero.tres"),
		]
		type_weights = [5.0, 3.0, 1.0]
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
	enemy.data = _pick_type()
	enemy.level = level
	# Convierte el punto local de la caja a posición global (respeta escala y rotación)
	enemy.position = zone_shape.global_transform * local_point
	get_parent().add_child(enemy)

	enemies_alive += 1
	enemy.tree_exited.connect(func(): enemies_alive -= 1)

func _pick_type() -> EnemyData:
	if type_weights.size() != enemy_types.size():
		return enemy_types.pick_random()
	var total := 0.0
	for w in type_weights:
		total += w
	var roll := randf() * total
	for i in enemy_types.size():
		roll -= type_weights[i]
		if roll <= 0.0:
			return enemy_types[i]
	return enemy_types.back()
