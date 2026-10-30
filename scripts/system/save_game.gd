extends Node

## Autoload que guarda y carga la partida (user://partida.json).
## Al abrir el juego se carga sola la ultima partida, antes de que se arme la
## escena: asi la UI y el jugador arrancan leyendo el estado ya cargado.
## F5 guarda y F9 vuelve a la ultima partida guardada. Ademas se guarda sola
## cada AUTOSAVE_INTERVAL segundos y al cerrar la ventana. La partida nueva
## (con su dificultad) se arma desde el menu del juego (ui/game_menu.gd).

signal saved

const SAVE_PATH := "user://partida.json"
const SAVE_VERSION: int = 1
const AUTOSAVE_INTERVAL: float = 60.0
## Campos que la generacion de botin cambia respecto del item base
## (ver Loot.generate_item e ItemSets.generate_piece).
const ITEM_FIELDS := ["rarity", "min_damage", "max_damage", "defense", "suffix", "unique_name", "bonuses", "set_id", "value", "sockets", "gems"]

## Archivo de la partida (los tests usan otro para no pisar la del jugador).
var save_path: String = SAVE_PATH
## Donde estaba el jugador al guardar (Movement lo usa al arrancar). INF = sin dato.
var player_position: Vector3 = Vector3.INF
## Items puestos a mano en el mapa que ya se juntaron (no vuelven a aparecer).
var collected_pickups: Array[String] = []
var _autosave_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_saved()


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		quick_save()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		reload_last_save()
		get_viewport().set_input_as_handled()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## F5: guarda y lo avisa en pantalla.
func quick_save() -> void:
	_announce("Partida guardada" if save() else "No se pudo guardar")


## Guarda la partida. Devuelve false si no se pudo escribir el archivo.
func save() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		player_position = player.global_position
	return _write()


func _write() -> bool:
	_autosave_timer = 0.0
	var player_data := {
		"level": player_stats.level,
		"xp": player_stats.xp,
		"unspent_points": player_stats.unspent_points,
		"gold": player_stats.gold,
		"attributes": player_stats.attributes,
		"health": player_stats.health,
	}
	if player_position != Vector3.INF:
		player_data["position"] = [player_position.x, player_position.y, player_position.z]
	var data := {
		"version": SAVE_VERSION,
		"difficulty": difficulty.current,
		"player": player_data,
		"inventory": _grid_to_array(inventory_data.backpack, true),
		"inventory_overflow": inventory_data.overflow.map(_slot_to_dict),
		"stash": _grid_to_array(inventory_data.stash, false),
		"equipment": _slots_to_array(inventory_data.equipment),
		"combo": skill_book.combo,
		"world": {"day": world_time.day, "hour": world_time.hour},
		"weather": weather.to_save(),
		"collected_pickups": collected_pickups,
		"world_map": world_map.to_save(),
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo guardar la partida: %s" % error_string(FileAccess.get_open_error()))
		return false
	# Sin ordenar las claves: las bonificaciones conservan su orden en el tooltip.
	file.store_string(JSON.stringify(data, "\t", false))
	saved.emit()
	return true


## Lee la partida guardada y la aplica a los autoloads. Devuelve false si no
## habia partida o no se pudo leer (en ese caso no cambia nada).
func load_saved() -> bool:
	if not has_save():
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("La partida guardada no se pudo leer: %s" % save_path)
		return false

	difficulty.set_level(int(data.get("difficulty", 0)))
	# Primero el equipo: cambia la vida maxima.
	inventory_data.reset()
	inventory_data.shop_mode = false
	_array_to_grid(data.get("inventory", []), inventory_data.backpack)
	_array_to_grid(data.get("inventory_overflow", []), inventory_data.backpack)
	_array_to_grid(data.get("stash", []), inventory_data.stash)
	_array_to_slots(data.get("equipment", []), inventory_data.equipment)

	var player_data: Dictionary = data.get("player", {})
	player_stats.level = int(player_data.get("level", 1))
	player_stats.xp = int(player_data.get("xp", 0))
	player_stats.unspent_points = int(player_data.get("unspent_points", 0))
	player_stats.gold = int(player_data.get("gold", 0))
	var attributes: Dictionary = player_data.get("attributes", {})
	for key in player_stats.attributes:
		player_stats.attributes[key] = int(attributes.get(key, player_stats.attributes[key]))
	player_stats.buffs.clear()
	player_stats.dead = false
	var health: float = float(player_data.get("health", 0.0))
	player_stats.health = health if health > 0.0 else player_stats.get_max_health()
	player_stats.health = minf(player_stats.health, player_stats.get_max_health())
	var position: Array = player_data.get("position", [])
	player_position = Vector3(position[0], position[1], position[2]) if position.size() == 3 else Vector3.INF

	skill_book.set_combo(data.get("combo", []))
	var world: Dictionary = data.get("world", {})
	world_time.set_time(float(world.get("hour", world_time.hour)), int(world.get("day", world_time.day)))
	weather.from_save(data.get("weather", {}))
	collected_pickups.assign(data.get("collected_pickups", []))
	world_map.from_save(data.get("world_map", {}))
	world_map.forget_map()

	inventory_data.inventory_changed.emit(-1)
	inventory_data.stash_changed.emit()
	for i in inventory_data.EQUIP_COUNT:
		inventory_data.equipment_changed.emit(i)
	player_stats.gold_changed.emit(player_stats.gold)
	player_stats.xp_changed.emit(player_stats.xp, player_stats.xp_for_next_level())
	player_stats.health_changed.emit(player_stats.health, player_stats.get_max_health())
	player_stats.buffs_changed.emit()
	player_stats.stats_changed.emit()
	return true


## F9: vuelve a la ultima partida guardada (rearma la escena con ese estado).
func reload_last_save() -> void:
	if not load_saved():
		_announce("No hay partida guardada")
		return
	get_tree().paused = false
	get_tree().reload_current_scene()
	await get_tree().create_timer(0.2).timeout
	_announce("Partida cargada")


## Partida nueva con la dificultad elegida: personaje de nivel 1, inventario
## vacio y el mapa como al principio. Reemplaza la partida guardada.
func new_game(difficulty_level: int) -> void:
	difficulty.set_level(difficulty_level)
	inventory_data.reset()
	inventory_data.shop_mode = false
	player_stats.reset()
	skill_book.reset()
	world_time.set_time(9.0, 1)
	weather.reset()
	collected_pickups.clear()
	world_map.reset()
	world_map.forget_map()
	player_position = Vector3.INF
	# Se escribe antes de rearmar la escena (sin posicion: arranca en el
	# inicio del mapa), asi el menu nuevo ya encuentra la partida.
	_write()
	get_tree().paused = false
	get_tree().reload_current_scene()
	await get_tree().create_timer(0.2).timeout
	_announce("Partida nueva: %s" % difficulty.get_level_name())


# --- Items puestos en el mapa ----------------------------------------------

func is_collected(pickup: Node) -> bool:
	var key: String = _pickup_key(pickup)
	return not key.is_empty() and key in collected_pickups


func mark_collected(pickup: Node) -> void:
	var key: String = _pickup_key(pickup)
	if not key.is_empty() and key not in collected_pickups:
		collected_pickups.append(key)


# Solo los items que son parte de la escena tienen clave; lo que sueltan los
# enemigos o tira el jugador se crea en el momento y no tiene dueño.
func _pickup_key(pickup: Node) -> String:
	if pickup.owner == null or pickup.owner.scene_file_path.is_empty():
		return ""
	return "%s:%s" % [pickup.owner.scene_file_path, pickup.owner.get_path_to(pickup)]


# --- Items -----------------------------------------------------------------

func _slots_to_array(slots: Array[Slotdata]) -> Array:
	var result: Array = []
	for slot in slots:
		if slot == null or slot.item_data == null:
			result.append(null)
		else:
			result.append(_slot_to_dict(slot))
	return result


# Cada grilla se guarda con la posicion de cada item. Con la mochila van
# tambien el item agarrado con el mouse y el del yunque, sin posicion (al
# cargar se acomodan en el primer lugar libre).
func _grid_to_array(grid: ItemGrid, with_loose: bool) -> Array:
	var result: Array = []
	for slot in grid.slots:
		var entry: Dictionary = _slot_to_dict(slot)
		entry["pos"] = [slot.grid_pos.x, slot.grid_pos.y]
		result.append(entry)
	if with_loose:
		for loose in [inventory_data.held, inventory_data.anvil]:
			if loose:
				result.append(_slot_to_dict(loose))
	return result


# Partidas viejas (casillas sin posicion, con huecos) entran en orden.
func _array_to_grid(data: Array, grid: ItemGrid) -> void:
	for entry in data:
		if not entry is Dictionary:
			continue
		var item: Itemdata = _item_from_dict(entry.get("item", {}))
		if item == null:
			continue
		var slot := Slotdata.new()
		slot.item_data = item
		slot.quantity = int(entry.get("quantity", 1))
		var pos: Array = entry.get("pos", [])
		var grid_pos := Vector2i(int(pos[0]), int(pos[1])) if pos.size() == 2 else Vector2i(-1, -1)
		# Lo que no entra queda esperando lugar en la mochila (no se pierde).
		if not grid.restore_slot(slot, grid_pos) and not inventory_data.restore_slot(slot, Vector2i(-1, -1)):
			inventory_data.park(slot)


func _slot_to_dict(slot: Slotdata) -> Dictionary:
	return {"item": _item_to_dict(slot.item_data), "quantity": slot.quantity}


func _array_to_slots(data: Array, slots: Array[Slotdata]) -> void:
	for i in mini(data.size(), slots.size()):
		if not data[i] is Dictionary:
			continue
		var item: Itemdata = _item_from_dict(data[i].get("item", {}))
		if item == null:
			continue
		var slot := Slotdata.new()
		slot.item_data = item
		slot.quantity = int(data[i].get("quantity", 1))
		slots[i] = slot


static func _item_to_dict(item: Itemdata) -> Dictionary:
	# Items del juego tal cual (pociones, los .tres puestos en el mapa).
	if item.base_path.is_empty():
		return {"path": item.resource_path}
	# Items generados: el item base mas lo que cambio al generarlo.
	var data := {"base": item.base_path}
	for field in ITEM_FIELDS:
		data[field] = item.get(field)
	return data


static func _item_from_dict(data: Dictionary) -> Itemdata:
	var path: String = data.get("base", data.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Item guardado desconocido: %s" % str(data))
		return null
	if not data.has("base"):
		return load(path)
	var item: Itemdata = load(path).duplicate()
	item.base_path = path
	for field in ITEM_FIELDS:
		if data.has(field):
			item.set(field, type_convert(data[field], typeof(item.get(field))))
	return item


func _announce(text: String) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		floating_text.spawn(player.global_position + Vector3.UP * 450.0, text, Color(1.0, 0.85, 0.35), 18)
		sfx.play("page")
