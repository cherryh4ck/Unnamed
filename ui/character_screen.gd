extends PanelContainer

## Pantalla de personaje (tecla C): nivel, experiencia, atributos con puntos
## para repartir, los stats de combate que resultan de ellos y del equipo, y
## los efectos especiales y sets que estan activos.

const ATTRIBUTES := {
	"fuerza": ["Fuerza", "+2% de daño por punto."],
	"destreza": ["Destreza", "+1% de velocidad de ataque y +0.2% de crítico por punto."],
	"vitalidad": ["Vitalidad", "+4 de vida máxima, +0.5 de defensa y más regeneración."],
	"concentracion": ["Concentración", "Las habilidades se recargan más rápido y el daño mágico, de veneno y de fuego sube un 1,5% por punto."],
}
const DERIVED := ["Vida", "Daño", "Daño por segundo", "Daño mágico", "Daño de veneno", "Daño de fuego", "Velocidad de ataque", "Crítico",
		"Defensa", "Res. a la magia", "Res. al veneno", "Res. al fuego", "Bloqueo", "Regeneración", "Recarga de habilidades"]
## Filas que van con el color de su tipo de daño.
const DERIVED_TYPES := {
	"Daño mágico": Damage.Type.MAGIC, "Daño de veneno": Damage.Type.POISON, "Daño de fuego": Damage.Type.FIRE,
	"Res. a la magia": Damage.Type.MAGIC, "Res. al veneno": Damage.Type.POISON, "Res. al fuego": Damage.Type.FIRE,
}

@onready var level_label: Label = %LevelLabel
@onready var xp_bar: ProgressBar = %XPBar
@onready var xp_label: Label = %XPLabel
@onready var points_label: Label = %PointsLabel
@onready var attribute_list: VBoxContainer = %AttributeList
@onready var derived_grid: GridContainer = %DerivedGrid

var _value_labels: Dictionary = {}
var _plus_buttons: Dictionary = {}
var _derived_labels: Dictionary = {}
var _derived_names: Dictionary = {}
var _effects_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_panels")

	for key in ATTRIBUTES:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = ATTRIBUTES[key][0]
		name_label.tooltip_text = ATTRIBUTES[key][1]
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value_label := Label.new()
		value_label.custom_minimum_size.x = 40
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(30, 26)
		plus.tooltip_text = ATTRIBUTES[key][1]
		plus.pressed.connect(_on_plus_pressed.bind(key))
		row.add_child(name_label)
		row.add_child(value_label)
		row.add_child(plus)
		attribute_list.add_child(row)
		_value_labels[key] = value_label
		_plus_buttons[key] = plus

	for stat_name in DERIVED:
		var name_label := Label.new()
		name_label.text = stat_name
		name_label.theme_type_variation = &"DimLabel"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value_label := Label.new()
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", 14)
		if DERIVED_TYPES.has(stat_name):
			value_label.add_theme_color_override("font_color", Damage.COLORS[DERIVED_TYPES[stat_name]])
		derived_grid.add_child(name_label)
		derived_grid.add_child(value_label)
		_derived_labels[stat_name] = value_label
		_derived_names[stat_name] = name_label

	derived_grid.add_theme_constant_override("v_separation", 0)
	_derived_labels["Daño por segundo"].tooltip_text = "Promedio del ataque básico, con los críticos y el daño elemental del equipo."
	_derived_labels["Daño por segundo"].mouse_filter = Control.MOUSE_FILTER_PASS
	_effects_label = Label.new()
	_effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effects_label.custom_minimum_size.x = 300.0
	_effects_label.add_theme_font_size_override("font_size", 13)
	_effects_label.add_theme_color_override("font_color", Itemdata.SPECIAL_COLOR)
	derived_grid.add_sibling(_effects_label)
	inventory_data.equipment_changed.connect(refresh.unbind(1))
	player_stats.stats_changed.connect(refresh)
	player_stats.xp_changed.connect(refresh.unbind(2))
	player_stats.health_changed.connect(refresh.unbind(2))
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_character"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	refresh()
	sfx.play("page")
	_update_pause()


func close() -> void:
	visible = false
	sfx.play("page")
	_update_pause()


# El juego queda en pausa mientras haya algun panel abierto (inventario o personaje).
func _update_pause() -> void:
	get_tree().paused = get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel.visible)


func refresh() -> void:
	if not is_node_ready():
		return
	level_label.text = "%s · Nivel %d" % [PlayerClasses.name_of(player_stats.class_id), player_stats.level]
	var needed: int = player_stats.xp_for_next_level()
	xp_bar.max_value = needed
	xp_bar.value = player_stats.xp
	xp_label.text = "%d / %d exp" % [player_stats.xp, needed]

	var points: int = player_stats.unspent_points
	points_label.text = "Puntos: %d" % points if points > 0 else ""
	for key in ATTRIBUTES:
		var bonus: int = roundi(player_stats.get_equipment_bonus(key))
		_value_labels[key].text = str(player_stats.get_attribute(key))
		_value_labels[key].modulate = Color(0.55, 0.75, 1.0) if bonus > 0 else Color.WHITE
		_value_labels[key].tooltip_text = "Base %d + equipo %d" % [player_stats.attributes[key], bonus] if bonus > 0 else ""
		_plus_buttons[key].visible = points > 0

	_derived_labels["Vida"].text = "%d / %d" % [ceili(player_stats.health), roundi(player_stats.get_max_health())]
	_derived_labels["Daño"].text = "%d - %d" % [player_stats.get_min_damage(), player_stats.get_max_damage()]
	_derived_labels["Daño por segundo"].text = "%.1f" % player_stats.get_dps()
	_derived_labels["Velocidad de ataque"].text = "%.2f /s" % player_stats.get_attack_speed()
	_derived_labels["Crítico"].text = "%.1f%%" % player_stats.get_crit_chance()
	_derived_labels["Defensa"].text = "%d (-%d%% físico)" % [player_stats.get_defense(), roundi(player_stats.get_resistance(Damage.Type.PHYSICAL))]
	for stat_name in DERIVED_TYPES:
		var type: int = DERIVED_TYPES[stat_name]
		if stat_name.begins_with("Daño"):
			# Solo se muestran si el equipo da ese daño (asi la hoja entra en
			# la pantalla junto con los efectos del equipo).
			var amount: float = player_stats.get_elemental_damage(type)
			_derived_labels[stat_name].text = "+%d" % roundi(amount)
			_derived_labels[stat_name].visible = amount > 0.0
			_derived_names[stat_name].visible = amount > 0.0
		else:
			_derived_labels[stat_name].text = "%d%%" % roundi(player_stats.get_resistance(type))
	_derived_labels["Bloqueo"].text = "%d%%" % roundi(player_stats.get_block_chance())
	_derived_labels["Regeneración"].text = "%.1f /s" % player_stats.get_health_regen()
	_derived_labels["Recarga de habilidades"].text = "-%d%%" % roundi((1.0 - player_stats.get_cooldown_multiplier()) * 100.0)
	_refresh_effects()


# Efectos de los unicos puestos (sumados) y los sets con al menos dos piezas.
func _refresh_effects() -> void:
	var lines := PackedStringArray()
	for key in Itemdata.SPECIAL_TEXT:
		var value: float = player_stats.get_special(key)
		if value > 0.0:
			var text: String = str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
			lines.append("• " + Itemdata.SPECIAL_TEXT[key] % text)
	var equipped: Array[Itemdata] = inventory_data.get_equipped_items()
	for set_id in ItemSets.SETS:
		var have: int = ItemSets.count_equipped(set_id, equipped)
		if have >= 2:
			lines.append("• %s: %d de %d piezas" % [ItemSets.SETS[set_id].name, have, ItemSets.SETS[set_id].pieces.size()])
	_effects_label.visible = not lines.is_empty()
	_effects_label.text = "Efectos del equipo\n" + "\n".join(lines)


func _on_plus_pressed(attribute: String) -> void:
	if player_stats.spend_point(attribute):
		sfx.play("click")
