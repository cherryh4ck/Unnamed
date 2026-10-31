class_name ItemTooltip

## Arma el contenido del tooltip de un item: nombre con el color de su rareza,
## tipo, stats, requisitos (en rojo si no se cumplen), bonificaciones (en
## azul), efecto especial e historia de los unicos, ranuras con sus gemas,
## bonos del set, descripcion, valor y la comparacion con lo equipado.
## Lo usan los slots del inventario desde _make_custom_tooltip.

const WIDTH: float = 240.0
const STAT_COLOR := Color(0.92, 0.9, 0.85)
const DIM_COLOR := Color(0.6, 0.56, 0.48)
const SET_COLOR := Color(0.35, 0.9, 0.35)
const SET_OFF_COLOR := Color(0.4, 0.45, 0.4)
const MISSING_COLOR := Color(0.95, 0.3, 0.25)
const LORE_COLOR := Color(0.82, 0.72, 0.52)
const BETTER_COLOR := Color(0.4, 0.9, 0.4)
const WORSE_COLOR := Color(0.95, 0.38, 0.32)


## compare: agrega como cambia la cosa respecto de lo equipado en ese lugar
## (no tiene sentido en el tooltip de lo que ya esta puesto).
static func build(item: Itemdata, quantity: int = 1, hint: String = "", compare: bool = true) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = WIDTH
	box.add_theme_constant_override("separation", 2)

	var title: String = item.get_display_name()
	if quantity > 1:
		title += " x%d" % quantity
	_add(box, title, item.get_rarity_color(), 18)
	_add(box, item.get_type_line(), DIM_COLOR, 13)

	var stats: PackedStringArray = item.get_stats_lines()
	if not stats.is_empty():
		_add_separator(box)
		for line in stats:
			_add(box, line, STAT_COLOR, 15)

	var requirements: Array = item.get_requirement_lines()
	if not requirements.is_empty():
		for line in requirements:
			_add(box, line[0], DIM_COLOR if line[1] else MISSING_COLOR, 13)

	var gem_lines: PackedStringArray = item.get_gem_lines()
	if not gem_lines.is_empty():
		_add_separator(box)
		for line in gem_lines:
			_add(box, line, Itemdata.BONUS_COLOR, 14)

	if not item.bonuses.is_empty():
		_add_separator(box)
		for key in item.bonuses:
			_add(box, Itemdata.bonus_text(key, item.bonuses[key]), Itemdata.bonus_color(key), 15)

	var special: String = item.get_special_text()
	if not special.is_empty():
		var label: Label = _add(box, special, Itemdata.SPECIAL_COLOR, 15)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if item.sockets > 0:
		_add_sockets(box, item)

	if not item.set_id.is_empty():
		_add_set_info(box, item)

	if not item.lore.is_empty():
		_add_separator(box)
		var lore: Label = _add(box, "«%s»" % item.lore, LORE_COLOR, 13)
		lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if not item.description.is_empty():
		_add_separator(box)
		var desc: Label = _add(box, item.description, DIM_COLOR, 13)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if compare and item.is_equipment():
		_add_comparison(box, item)

	if item.value > 0 or not hint.is_empty():
		_add_separator(box)
	if item.value > 0:
		_add(box, "Valor: %d oro" % (item.value * quantity), Color(1.0, 0.85, 0.35), 13)
	if not hint.is_empty():
		_add(box, hint, DIM_COLOR, 12)
	return box


# Una linea por ranura: la gema con lo que da, o vacia.
static func _add_sockets(box: VBoxContainer, item: Itemdata) -> void:
	_add_separator(box)
	_add(box, "Ranuras (%d/%d)" % [item.gems.size(), item.sockets], DIM_COLOR, 13)
	for i in item.sockets:
		if i >= item.gems.size():
			_add(box, "  ◇ Vacía", DIM_COLOR, 14)
			continue
		var gem: Itemdata = Gems.from_id(item.gems[i])
		if gem == null:
			continue
		var bonus: Array = Gems.bonus_of(gem.gem_kind, gem.gem_tier, item.has_damage())
		_add(box, "  ◆ %s: %s" % [gem.name, Itemdata.bonus_text(bonus[0], bonus[1])], Gems.color_of(gem.gem_kind).lightened(0.3), 14)


# Nombre del set, piezas (las equipadas en verde) y los bonos por cantidad
# de piezas (en verde los que ya estan activos).
static func _add_set_info(box: VBoxContainer, item: Itemdata) -> void:
	var set_info: Dictionary = ItemSets.get_set(item.set_id)
	if set_info.is_empty():
		return
	var equipped: Array[Itemdata] = inventory_data.get_equipped_items()
	var equipped_names: Array = []
	for other in equipped:
		if other.set_id == item.set_id:
			equipped_names.append(other.unique_name)
	var have: int = ItemSets.count_equipped(item.set_id, equipped)

	_add_separator(box)
	_add(box, "%s (%d/%d)" % [set_info.name, have, set_info.pieces.size()], SET_COLOR, 15)
	for piece_name in set_info.pieces.values():
		_add(box, "  " + piece_name, SET_COLOR if piece_name in equipped_names else SET_OFF_COLOR, 13)
	for pieces in set_info.tiers:
		var active: bool = have >= pieces
		_add(box, "Con %d piezas:" % pieces, SET_COLOR if active else SET_OFF_COLOR, 13)
		var tier: Dictionary = set_info.tiers[pieces]
		for key in tier:
			_add(box, "  " + Itemdata.bonus_text(key, tier[key]), SET_COLOR if active else SET_OFF_COLOR, 14)


# Cuanto se gana o se pierde respecto de lo que esta equipado en ese lugar
# (verde mejor, rojo peor). Los anillos se comparan con el primero.
static func _add_comparison(box: VBoxContainer, item: Itemdata) -> void:
	var equip_index: int = inventory_data.equip_index_for(item)
	if item.item_type == Itemdata.ItemType.RING:
		equip_index = inventory_data.RING_EQUIP
	if equip_index < 0:
		return
	var current: Itemdata = inventory_data.get_equipped(equip_index)
	if current == item:
		return
	_add_separator(box)
	if current == null:
		_add(box, "No tenés nada equipado ahí", DIM_COLOR, 13)
		return
	_add(box, "Comparado con lo equipado:", DIM_COLOR, 13)
	var lines: Array = []
	if item.has_damage() or current.has_damage():
		var damage: float = (item.min_damage + item.max_damage - current.min_damage - current.max_damage) / 2.0
		lines.append([damage, "%s%s Daño medio" % ["+" if damage >= 0.0 else "-", _number(absf(damage))]])
		var speed: float = item.attack_speed - current.attack_speed
		if absf(speed) > 0.005:
			lines.append([speed, "%s%.2f golpes/s" % ["+" if speed >= 0.0 else "-", absf(speed)]])
	# La defensa base y la de las bonificaciones van juntas.
	var defense: float = item.defense + item.get_bonus("defensa") - current.defense - current.get_bonus("defensa")
	if absf(defense) >= 0.5:
		lines.append([defense, "%s%d Defensa" % ["+" if defense >= 0.0 else "-", absi(roundi(defense))]])
	if item.block_chance != current.block_chance:
		var block: float = item.block_chance - current.block_chance
		lines.append([block, "%s%d%% Bloqueo" % ["+" if block >= 0.0 else "-", absi(roundi(block))]])
	var keys: Array = item.bonuses.keys()
	for key in current.bonuses:
		if not key in keys:
			keys.append(key)
	keys.erase("defensa")
	for key in keys:
		var difference: float = item.get_bonus(key) - current.get_bonus(key)
		if absf(difference) < 0.05:
			continue
		var text: String = Itemdata.bonus_text(key, absf(difference))
		if difference < 0.0:
			text = "-" + text.trim_prefix("+")
		lines.append([difference, text])
	if lines.is_empty():
		_add(box, "  Igual que lo equipado", DIM_COLOR, 13)
	for line in lines:
		_add(box, "  " + line[1], BETTER_COLOR if line[0] > 0.0 else WORSE_COLOR, 14)


static func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


static func _add(box: VBoxContainer, text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = WIDTH
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	box.add_child(label)
	return label


static func _add_separator(box: VBoxContainer) -> void:
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 6)
	box.add_child(separator)
