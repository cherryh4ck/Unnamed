extends Node

## Autoload que guarda y carga la partida. Hay SLOT_COUNT ranuras, una por
## personaje: la primera es user://partida.json y las demas van al lado
## (partida_2.json...). Al lado tambien quedan el perfil (perfil.cfg: ultima
## ranura usada y dificultades desbloqueadas) y el baul compartido por todos
## los personajes (baul.json; los de modo extremo usan baul_extremo.json).
## Al abrir el juego se carga sola la ultima partida, antes de que se arme la
## escena: asi la UI y el jugador arrancan leyendo el estado ya cargado.
## F5 guarda y F9 vuelve a la ultima partida guardada. Ademas se guarda sola
## cada AUTOSAVE_INTERVAL segundos, al viajar por un portal (loading_screen) y
## al cerrar la ventana. Los personajes nuevos se arman desde la pantalla de
## titulo o el menu del juego (ui/game_menu.gd).
## Modo extremo: una sola vida. Al morir la partida queda marcada como caida
## ("fallen"), ya no se puede cargar y se vuelve al titulo.

signal saved
## Murio el personaje de modo extremo (el HUD lo muestra).
signal fell

const SAVE_PATH := "user://partida.json"
const SAVE_VERSION: int = 1
const AUTOSAVE_INTERVAL: float = 60.0
const SLOT_COUNT: int = 5
## Segundos entre la muerte en modo extremo y la vuelta al titulo.
const FALL_DELAY: float = 5.0
const NOTICE_FONT := preload("res://assets/fonts/ebgaramond/EBGaramond-Italic[wght].ttf")
## Campos que la generacion de botin cambia respecto del item base
## (ver Loot.generate_item e ItemSets.generate_piece).
const ITEM_FIELDS := ["rarity", "min_damage", "max_damage", "defense", "suffix", "unique_name", "bonuses", "set_id", "value", "sockets", "gems",
		"required_level", "required_attributes", "special", "special_value", "lore"]

## Archivo de la partida activa. Los tests ponen otro antes de _ready para no
## pisar la del jugador; las demas ranuras, el perfil y el baul salen de ahi
## (con el nombre de ese archivo adelante: ver _side_path).
var save_path: String = SAVE_PATH
## Ranura de la partida activa (0 = la primera).
var slot: int = 0
## Modo extremo (una sola vida). Se elige al crear el personaje.
var hardcore: bool = false
## Dificultad mas alta que se puede elegir para un personaje nuevo (perfil).
var unlocked_difficulty: int = 0
## Donde estaba el jugador al guardar (Movement lo usa al arrancar). INF = sin dato.
var player_position: Vector3 = Vector3.INF
## Items puestos a mano en el mapa que ya se juntaron (no vuelven a aparecer).
var collected_pickups: Array[String] = []
var _autosave_timer: float = 0.0
var _notice: Label
var _notice_tween: Tween
var _primary_path: String = ""
## true cuando lo que hay en memoria ya no se debe guardar (se borro la
## ranura activa o el personaje de modo extremo cayo).
var _discarded: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_primary_path = ""
	_ensure_primary()
	_load_profile()
	# Con otro archivo (pruebas) se arranca siempre por el primero.
	if _primary_path != SAVE_PATH:
		slot = 0
	if not _is_alive(slot):
		var alive: Array = range(SLOT_COUNT).filter(_is_alive)
		if not alive.is_empty():
			slot = alive[0]
	save_path = slot_path(slot)
	if not load_saved() and FileAccess.file_exists(save_path):
		# Partida caida o dañada: no se pisa.
		_discarded = true
	player_stats.died.connect(_on_player_died)


func _process(delta: float) -> void:
	# En pausa (titulo, menus) no corre: no hay nada nuevo que guardar.
	if get_tree().paused:
		return
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		autosave()


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


## Hay una partida que se puede seguir en la ranura activa.
func has_save() -> bool:
	return FileAccess.file_exists(save_path) and not _discarded


# --- Ranuras y perfil --------------------------------------------------------

func slot_path(index: int) -> String:
	if index == 0:
		return _primary_path
	return "%s_%d.json" % [_primary_path.get_basename(), index + 1]


## Resumen de una ranura para los menus: {} si esta vacia; si no, clase,
## nivel, dificultad, dia, si es de modo extremo y si cayo.
func slot_summary(index: int) -> Dictionary:
	var path: String = slot_path(index)
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return {"broken": true}
	var player_data: Dictionary = data.get("player", {})
	return {
		"class": str(player_data.get("class", PlayerClasses.DEFAULT)),
		"level": int(player_data.get("level", 1)),
		"difficulty": clampi(int(data.get("difficulty", 0)), 0, difficulty.LEVELS.size() - 1),
		"day": int(data.get("world", {}).get("day", 1)),
		"hardcore": bool(data.get("hardcore", false)),
		"fallen": bool(data.get("fallen", false)),
	}


## Texto de una linea para mostrar una ranura ("Mago nivel 7 · Veterano · Día 3").
func describe_slot(summary: Dictionary) -> String:
	if summary.is_empty():
		return "Vacío"
	if summary.has("broken"):
		return "Partida dañada"
	var text: String = "%s nivel %d · %s · Día %d" % [PlayerClasses.name_of(summary["class"]), summary.level,
			difficulty.get_level_name(summary.difficulty), summary.day]
	if summary.hardcore:
		text += " · Extremo"
	if summary.fallen:
		text += " · Caído"
	return text


func _is_alive(index: int) -> bool:
	var summary: Dictionary = slot_summary(index)
	return not summary.is_empty() and not summary.has("broken") and not summary.fallen


func free_slot() -> int:
	for i in SLOT_COUNT:
		if not FileAccess.file_exists(slot_path(i)):
			return i
	return -1


func _use_slot(index: int) -> void:
	slot = index
	save_path = slot_path(index)
	_save_profile()


## Juega con otro personaje (desde el titulo): rearma la escena con su partida.
func load_slot(index: int) -> void:
	if index != slot and has_save():
		save()
	_use_slot(index)
	get_tree().paused = false
	var summary: Dictionary = slot_summary(index)
	if await loading_screen.reload_scene("CARGANDO", PlayerClasses.name_of(summary.get("class", "")), load_saved):
		_announce("%s nivel %d" % [PlayerClasses.name_of(player_stats.class_id), player_stats.level])


## Borra el personaje de una ranura (si es el activo, lo que queda en memoria
## ya no se guarda hasta cargar o crear otro).
func delete_slot(index: int) -> void:
	var path: String = slot_path(index)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if index == slot:
		_discarded = true


## Marca una dificultad como desbloqueada (y las de antes) en el perfil.
func unlock_difficulty(index: int) -> void:
	index = clampi(index, 0, difficulty.LEVELS.size() - 1)
	if index > unlocked_difficulty:
		unlocked_difficulty = index
		_save_profile()


# Las pruebas pueden guardar antes de _ready: la primera partida es la que
# este configurada en ese momento.
func _ensure_primary() -> void:
	if _primary_path.is_empty():
		_primary_path = save_path


func _profile_path() -> String:
	return _side_path("perfil.cfg")


# Archivo al lado de la partida. Con otro archivo que el de siempre (pruebas)
# lleva su nombre adelante, asi nunca toca el perfil ni el baul del jugador.
func _side_path(file_name: String) -> String:
	if _primary_path == SAVE_PATH:
		return SAVE_PATH.get_base_dir().path_join(file_name)
	return "%s_%s" % [_primary_path.get_basename(), file_name]


func _load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(_profile_path()) != OK:
		return
	slot = clampi(int(config.get_value("perfil", "ultima_ranura", 0)), 0, SLOT_COUNT - 1)
	unlocked_difficulty = clampi(int(config.get_value("perfil", "dificultad_maxima", 0)), 0, difficulty.LEVELS.size() - 1)


func _save_profile() -> void:
	_ensure_primary()
	var config := ConfigFile.new()
	config.set_value("perfil", "ultima_ranura", slot)
	config.set_value("perfil", "dificultad_maxima", unlocked_difficulty)
	config.save(_profile_path())


# --- Baul compartido ---------------------------------------------------------

func _stash_path() -> String:
	return _side_path("baul_extremo.json" if hardcore else "baul.json")


# Lo que hay en el baul compartido. Si todavia no existe (partidas de antes),
# se usa el baul que traia la partida.
func _read_stash(data: Dictionary) -> Array:
	if FileAccess.file_exists(_stash_path()):
		var stash: Variant = JSON.parse_string(FileAccess.get_file_as_string(_stash_path()))
		if stash is Array:
			return stash
	return data.get("stash", [])


func _write_stash() -> void:
	var file := FileAccess.open(_stash_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_grid_to_array(inventory_data.stash, false), "\t", false))


## F5: guarda y lo avisa en pantalla.
func quick_save() -> void:
	_announce("Partida guardada" if save() else "No se pudo guardar")


## Guardado automatico: como save(), pero muerto no guarda (se esperaria a
## reaparecer) y lo avisa con un cartel chico abajo a la derecha.
func autosave() -> bool:
	if player_stats.dead:
		return false
	var ok: bool = save()
	if ok:
		_show_saving_notice()
	return ok


## Guarda la partida. Devuelve false si no se pudo escribir el archivo.
func save() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		player_position = player.global_position
	return _write()


func _write(fallen: bool = false) -> bool:
	_autosave_timer = 0.0
	if _discarded:
		return false
	_ensure_primary()
	var player_data := {
		"class": player_stats.class_id,
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
		"hardcore": hardcore,
		"fallen": fallen,
		"bestiary": bestiary.to_save(),
		"player": player_data,
		"inventory": _grid_to_array(inventory_data.backpack, true),
		"inventory_overflow": inventory_data.overflow.map(_slot_to_dict),
		"equipment": _slots_to_array(inventory_data.equipment),
		"belt": Array(inventory_data.belt),
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
	file.close()
	_write_stash()
	saved.emit()
	return true


## Lee la partida guardada y la aplica a los autoloads. Devuelve false si no
## habia partida o no se pudo leer (en ese caso no cambia nada).
func load_saved() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("La partida guardada no se pudo leer: %s" % save_path)
		return false
	if data.get("fallen", false):
		return false

	_discarded = false
	hardcore = bool(data.get("hardcore", false))
	difficulty.set_level(int(data.get("difficulty", 0)))
	# Lo que ya se jugo queda desbloqueado (partidas de antes del perfil).
	unlock_difficulty(difficulty.current)
	bestiary.from_save(data.get("bestiary", {}))
	# Primero el equipo: cambia la vida maxima.
	inventory_data.reset()
	inventory_data.shop_mode = false
	_array_to_grid(data.get("inventory", []), inventory_data.backpack)
	_array_to_grid(data.get("inventory_overflow", []), inventory_data.backpack)
	_array_to_grid(_read_stash(data), inventory_data.stash)
	_array_to_slots(data.get("equipment", []), inventory_data.equipment)
	# Las partidas de antes del cinturon arrancan con el de siempre.
	inventory_data.load_belt(data.get("belt", inventory_data.DEFAULT_BELT))

	var player_data: Dictionary = data.get("player", {})
	# Las partidas de antes de las clases eran de guerrero.
	var class_id: String = str(player_data.get("class", PlayerClasses.DEFAULT))
	player_stats.class_id = class_id if PlayerClasses.is_valid(class_id) else PlayerClasses.DEFAULT
	skill_book.set_class(player_stats.class_id)
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
	if hardcore:
		_announce("En modo extremo no hay vuelta atrás")
		return
	if not has_save():
		_announce("No hay partida guardada")
		return
	get_tree().paused = false
	# La partida se lee ya con la pantalla tapada.
	if await loading_screen.reload_scene("CARGANDO", "Partida guardada", load_saved):
		_announce("Partida cargada")
	else:
		_announce("No se pudo leer la partida")


## Personaje nuevo con la clase y la dificultad elegidas, en la primera
## ranura libre: nivel 1 con el equipo de su clase y el mapa como al
## principio. Antes se guarda el personaje actual. Devuelve false si no hay
## ranura libre (los menus lo avisan antes).
func new_game(difficulty_level: int, class_id: String = PlayerClasses.DEFAULT, extreme: bool = false) -> bool:
	var target: int = free_slot()
	if target == -1:
		_announce("No hay lugar para otro personaje")
		return false
	if has_save():
		save()
	_use_slot(target)
	get_tree().paused = false
	await loading_screen.reload_scene("PERSONAJE NUEVO", PlayerClasses.name_of(class_id),
			_start_new_game.bind(difficulty_level, class_id, extreme))
	_announce("%s · %s%s" % [PlayerClasses.name_of(player_stats.class_id), difficulty.get_level_name(), " · Extremo" if hardcore else ""])
	return true


# Arma el estado de la partida nueva (con la pantalla de carga ya tapando).
func _start_new_game(difficulty_level: int, class_id: String, extreme: bool) -> bool:
	_discarded = false
	hardcore = extreme
	difficulty.set_level(difficulty_level)
	inventory_data.reset()
	# El baul es de todos los personajes (el de modo extremo, aparte).
	_array_to_grid(_read_stash({}), inventory_data.stash)
	bestiary.reset()
	player_stats.reset(class_id)
	skill_book.set_class(player_stats.class_id)
	skill_book.reset()
	_give_starting_gear()
	world_time.set_time(9.0, 1)
	weather.reset()
	collected_pickups.clear()
	world_map.reset()
	world_map.forget_map()
	player_position = Vector3.INF
	# Se escribe antes de rearmar la escena (sin posicion: arranca en el
	# inicio del mapa), asi el menu nuevo ya encuentra la partida.
	_write()
	return true


# Equipo inicial de la clase (equipado) y unas pociones.
func _give_starting_gear() -> void:
	for path in PlayerClasses.get_info(player_stats.class_id).items:
		var item: Itemdata = load(path)
		var slot := Slotdata.new()
		slot.item_data = item
		inventory_data.equipment[inventory_data.equip_index_for(item)] = slot
	inventory_data.add_item(Loot.POTION, PlayerClasses.START_POTIONS)
	player_stats.health = player_stats.get_max_health()


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


## Pasa el personaje a la dificultad siguiente (ya desbloqueada): conserva
## todo y los enemigos se vuelven mas fuertes.
func advance_difficulty() -> void:
	var next: int = difficulty.current + 1
	if next >= difficulty.LEVELS.size() or next > unlocked_difficulty:
		return
	get_tree().paused = false
	var prepare := func() -> bool:
		difficulty.set_level(next)
		bestiary.regions_cleared.clear()
		return save()
	if await loading_screen.reload_scene("NUEVA DIFICULTAD", difficulty.get_level_name(next), prepare):
		_announce("Dificultad %s" % difficulty.get_level_name())


# Modo extremo: la partida queda marcada como caida y despues de un rato se
# vuelve al titulo con el ultimo personaje vivo (o ninguno).
func _on_player_died() -> void:
	if not hardcore or _discarded:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		player_position = player.global_position
	_write(true)
	_discarded = true
	fell.emit()
	await get_tree().create_timer(FALL_DELAY, false).timeout
	var prepare := func() -> bool:
		var alive: Array = range(SLOT_COUNT).filter(_is_alive)
		if not alive.is_empty():
			_use_slot(alive[0])
			load_saved()
		TitleScreen.show_on_next_load = true
		return true
	loading_screen.reload_scene("MODO EXTREMO", "Caíste en combate", prepare)


func _show_saving_notice() -> void:
	if _notice == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_notice = Label.new()
		_notice.text = "Guardando…"
		_notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		_notice.offset_left = -200
		_notice.offset_top = -44
		_notice.offset_right = -18
		_notice.offset_bottom = -14
		_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_notice.add_theme_font_override("font", NOTICE_FONT)
		_notice.add_theme_font_size_override("font_size", 17)
		_notice.add_theme_color_override("font_color", Color(0.95, 0.8, 0.48))
		_notice.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_notice.add_theme_constant_override("outline_size", 5)
		layer.add_child(_notice)
	if _notice_tween:
		_notice_tween.kill()
	_notice.modulate.a = 0.0
	_notice_tween = create_tween()
	_notice_tween.tween_property(_notice, "modulate:a", 1.0, 0.25)
	_notice_tween.tween_interval(1.4)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.6)


func _announce(text: String) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		floating_text.spawn(player.global_position + Vector3.UP * 450.0, text, Color(1.0, 0.85, 0.35), 18)
		sfx.play("page")
