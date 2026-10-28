class_name ItemTooltip

## Arma el contenido del tooltip de un item: nombre con el color de su rareza,
## tipo, stats, bonificaciones (en azul), descripcion y valor.
## Lo usan los slots del inventario desde _make_custom_tooltip.

const WIDTH: float = 240.0
const STAT_COLOR := Color(0.92, 0.9, 0.85)
const BONUS_COLOR := Color(0.5, 0.68, 1.0)
const DIM_COLOR := Color(0.6, 0.56, 0.48)


static func build(item: Itemdata, quantity: int = 1, hint: String = "") -> Control:
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

	var bonuses: PackedStringArray = item.get_bonus_lines()
	if not bonuses.is_empty():
		_add_separator(box)
		for line in bonuses:
			_add(box, line, BONUS_COLOR, 15)

	if not item.description.is_empty():
		_add_separator(box)
		var desc: Label = _add(box, item.description, DIM_COLOR, 13)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if item.value > 0 or not hint.is_empty():
		_add_separator(box)
	if item.value > 0:
		_add(box, "Valor: %d oro" % (item.value * quantity), Color(1.0, 0.85, 0.35), 13)
	if not hint.is_empty():
		_add(box, hint, DIM_COLOR, 12)
	return box


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
