extends Node

## Autoload: bestiario del personaje y avance de la dificultad.
## - Bestiario: por cada tipo de enemigo (enemies/types/*.tres) anota si se
##   vio, cuantos se mataron, cuantos campeones y el nivel mas alto visto.
## - Regiones: derrotar a un campeon en cada region (Bosque, Pradera,
##   Cementerio y Ruinas) completa la dificultad y desbloquea la siguiente
##   (save_game lo guarda en el perfil).
## Escucha a los enemigos desde afuera (senal died de enemi.gd), asi que no
## hace falta tocarlos; los carteles los muestra el HUD con las senales.
## Se guarda con la partida (to_save / from_save).

signal changed
signal region_cleared(region: String)
signal difficulty_completed(index: int)

const TYPES_DIR := "res://enemies/types"
## Region (nombre de la zona sin numeros) -> como se nombra en los avisos.
const REGIONS := {"Bosque": "el Bosque", "Pradera": "la Pradera", "Cementerio": "el Cementerio", "Ruinas": "las Ruinas"}
## A esta distancia del jugador un enemigo cuenta como visto.
const SEEN_RANGE: float = 1600.0

## Nombre del tipo -> {"seen", "kills", "champions", "max_level"}.
var entries: Dictionary = {}
## Regiones con un campeon derrotado en la dificultad actual.
var regions_cleared: Array[String] = []

var _types: Array[EnemyData] = []
var _seen_timer: float = 0.0


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for file in ResourceLoader.list_directory(TYPES_DIR):
		if file.ends_with(".tres"):
			var data: Resource = load(TYPES_DIR.path_join(file))
			if data is EnemyData:
				_types.append(data)
	_types.sort_custom(func(a: EnemyData, b: EnemyData) -> bool: return a.xp_reward < b.xp_reward)


## Todos los tipos de enemigo, del mas debil al mas fuerte.
func get_types() -> Array[EnemyData]:
	return _types


func get_entry(type_name: String) -> Dictionary:
	return entries.get(type_name, {})


func is_known(type_name: String) -> bool:
	return entries.has(type_name)


func reset() -> void:
	entries.clear()
	regions_cleared.clear()
	changed.emit()


func to_save() -> Dictionary:
	return {"entries": entries, "regions": regions_cleared}


func from_save(data: Dictionary) -> void:
	entries.clear()
	var saved: Dictionary = data.get("entries", {})
	for type_name in saved:
		var entry: Dictionary = saved[type_name]
		entries[type_name] = {
			"seen": true,
			"kills": int(entry.get("kills", 0)),
			"champions": int(entry.get("champions", 0)),
			"max_level": int(entry.get("max_level", 1)),
		}
	regions_cleared.assign(data.get("regions", []))
	changed.emit()


func _process(delta: float) -> void:
	_seen_timer -= delta
	if _seen_timer > 0.0:
		return
	_seen_timer = 0.5
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.get("data") is EnemyData and enemy.global_position.distance_to(player.global_position) <= SEEN_RANGE:
			_note(enemy)


# Los enemigos se conectan al entrar al arbol (antes de su _ready).
func _on_node_added(node: Node) -> void:
	if node is CharacterBody3D and node.has_signal("died") and "data" in node and "champion" in node:
		node.died.connect(_on_enemy_died.bind(node), CONNECT_ONE_SHOT)


func _note(enemy: Node) -> Dictionary:
	var type_name: String = enemy.data.name
	if not entries.has(type_name):
		entries[type_name] = {"seen": true, "kills": 0, "champions": 0, "max_level": 1}
		changed.emit()
	var entry: Dictionary = entries[type_name]
	entry.max_level = maxi(entry.max_level, int(enemy.level))
	return entry


func _on_enemy_died(enemy: Node) -> void:
	if not is_instance_valid(enemy) or not enemy.data is EnemyData:
		return
	var entry: Dictionary = _note(enemy)
	entry.kills += 1
	if enemy.champion:
		entry.champions += 1
		_clear_region(region_at(enemy.global_position))
	changed.emit()


## Region del mapa en un punto ("" fuera de las regiones con enemigos).
func region_at(position: Vector3) -> String:
	for zone in get_tree().get_nodes_in_group("enemy_zones"):
		var size: Vector3 = zone.get("zone_size")
		if size == Vector3.ZERO:
			continue
		var local: Vector3 = position - zone.global_position
		if absf(local.x) <= size.x / 2.0 and absf(local.z) <= size.z / 2.0:
			var region: String = zone.name.rstrip("0123456789")
			if REGIONS.has(region):
				return region
	return ""


func _clear_region(region: String) -> void:
	if region.is_empty() or region in regions_cleared:
		return
	regions_cleared.append(region)
	region_cleared.emit(region)
	if regions_cleared.size() == REGIONS.size():
		save_game.unlock_difficulty(difficulty.current + 1)
		difficulty_completed.emit(difficulty.current)
