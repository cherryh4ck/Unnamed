extends Node3D

## Region de enemigos, como en Sacred: mientras el jugador anda por la zona,
## los enemigos aparecen en grupos alrededor suyo, fuera de lo que ve la
## camara, y desaparecen cuando el jugador se aleja (ver enemi.gd). Asi solo
## existen los que estan cerca y el resto del mapa no cuesta nada.

## Distancia al jugador a la que aparecen los grupos (afuera de la pantalla).
const SPAWN_MIN_DISTANCE := 1900.0
const SPAWN_MAX_DISTANCE := 3000.0
## Intentos por tanda para encontrar un lugar valido.
const SPAWN_TRIES := 10
## Separacion entre los integrantes de un grupo.
const PACK_SPREAD := 170.0
## Un punto vale si el piso caminable mas cercano esta a menos de esto.
const NAVMESH_TOLERANCE := 60.0
## Probabilidad de que un grupo venga con un campeon al frente (de noche, el doble).
const CHAMPION_CHANCE := 0.1
## Radio en el que se cuentan los enemigos que ya hay cerca del jugador
## (de cualquier zona, asi en los bordes entre zonas no se suman).
const NEARBY_RANGE := 4500.0

@export var enemy_scene: PackedScene
@export var spawn_interval := 3.0
## Cuantos enemigos puede haber a la vez cerca del jugador en esta zona.
@export var max_enemies := 10
## Nivel de los enemigos de esta zona (escala vida, daño y experiencia).
@export var level := 1
## Tipos que pueden aparecer. Si se deja vacio usa esqueleto, zombi y guerrero.
@export var enemy_types: Array[EnemyData] = []
## Peso de cada tipo (mismo orden que enemy_types). Vacio = todos igual de probables.
@export var type_weights: Array[float] = []
## Tamaño de la zona (si no es cero reemplaza la caja de la escena; lo usa
## world/build_world.gd para que cada zona tenga su propia caja).
@export var zone_size := Vector3.ZERO

@onready var zone_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var timer: Timer = $Timer

var enemies_alive := 0
var _player: Node3D

func _ready():
	# El mapa grande marca las zonas peligrosas ya exploradas.
	add_to_group("enemy_zones")
	if zone_size != Vector3.ZERO:
		var box := BoxShape3D.new()
		box.size = zone_size
		zone_shape.shape = box
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
	# De noche aparecen mas enemigos, mas seguido y un nivel mas fuertes.
	var night: bool = world_time.is_night()
	timer.wait_time = spawn_interval * (0.6 if night else 1.0)
	var limit: int = roundi(max_enemies * (1.5 if night else 1.0))
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	# Lejos de la zona no se hace nada.
	if not _contains(_player.global_position, SPAWN_MAX_DISTANCE):
		return
	var nearby: int = _enemies_near_player()
	if nearby >= limit:
		return

	var spot = _find_spot()
	if spot == null:
		return
	var data: EnemyData = _pick_type()
	var with_champion: bool = randf() < CHAMPION_CHANCE * (2.0 if night else 1.0)
	var count: int = mini(randi_range(data.pack_size.x, data.pack_size.y) + (1 if with_champion else 0), limit - nearby)
	for i in count:
		var offset := Vector3.ZERO
		if i > 0:
			var angle: float = TAU * i / count + randf_range(-0.4, 0.4)
			offset = Vector3(cos(angle), 0.0, sin(angle)) * PACK_SPREAD * randf_range(0.8, 1.3)
		var point = _on_navmesh(spot + offset)
		if point == null:
			point = spot
		_spawn_one(data, point, night, with_champion and i == 0)

func _spawn_one(data: EnemyData, point: Vector3, night: bool, champion: bool = false) -> void:
	var enemy = enemy_scene.instantiate()
	enemy.data = data
	enemy.champion = champion
	enemy.level = level + (1 if night else 0)
	enemy.despawns = true
	enemy.position = point
	enemy.rotation.y = randf() * TAU
	get_parent().add_child(enemy)

	enemies_alive += 1
	enemy.tree_exited.connect(func(): enemies_alive -= 1)

func _enemies_near_player() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(_player.global_position) < NEARBY_RANGE:
			count += 1
	return count

## Un punto alrededor del jugador, dentro de la zona, sobre piso caminable y
## que la camara no este viendo. null si no encontro ninguno.
func _find_spot():
	var camera: Camera3D = get_viewport().get_camera_3d()
	for i in SPAWN_TRIES:
		var angle: float = randf() * TAU
		var distance: float = randf_range(SPAWN_MIN_DISTANCE, SPAWN_MAX_DISTANCE)
		var candidate: Vector3 = _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		if not _contains(candidate, 0.0):
			continue
		var point = _on_navmesh(candidate)
		if point == null:
			continue
		if camera and (camera.is_position_in_frustum(point) or camera.is_position_in_frustum(point + Vector3.UP * 400.0)):
			continue
		return point
	return null

## Si el punto esta dentro de la caja de la zona (agrandada en margin).
func _contains(point: Vector3, margin: float) -> bool:
	var local: Vector3 = zone_shape.global_transform.affine_inverse() * point
	var half: Vector3 = zone_shape.shape.size / 2.0
	return absf(local.x) <= half.x + margin and absf(local.z) <= half.z + margin

## El punto apoyado en el piso caminable, o null si cae fuera (agua, rocas...).
func _on_navmesh(point: Vector3):
	var map: RID = get_world_3d().navigation_map
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, point)
	var flat := Vector2(closest.x - point.x, closest.z - point.z)
	if flat.length() > NAVMESH_TOLERANCE:
		return null
	return closest

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
