extends PanelContainer

## Pantalla de personaje (tecla C): nivel, experiencia, atributos con puntos
## para repartir y los stats de combate que resultan de ellos y del equipo.

const ATTRIBUTES := {
	"fuerza": ["Fuerza", "+2% de daño por punto."],
	"destreza": ["Destreza", "+1% de velocidad de ataque y +0.2% de crítico por punto."],
	"vitalidad": ["Vitalidad", "+4 de vida máxima, +0.5 de defensa y más regeneración."],
	"concentracion": ["Concentración", "Las habilidades se recargan más rápido y el daño mágico, de veneno y de fuego sube un 1,5% por punto."],
}
const DERIVED := ["Vida", "Daño", "Daño mágico", "Daño de veneno", "Daño de fuego", "Velocidad de ataque", "Crítico",
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

	derived_grid.add_theme_constant_override("v_separation", 0)
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
	_derived_labels["Velocidad de ataque"].text = "%.2f /s" % player_stats.get_attack_speed()
	_derived_labels["Crítico"].text = "%.1f%%" % player_stats.get_crit_chance()
	_derived_labels["Defensa"].text = "%d (-%d%% físico)" % [player_stats.get_defense(), roundi(player_stats.get_resistance(Damage.Type.PHYSICAL))]
	for stat_name in DERIVED_TYPES:
		var type: int = DERIVED_TYPES[stat_name]
		if stat_name.begins_with("Daño"):
			var amount: float = player_stats.get_elemental_damage(type)
			_derived_labels[stat_name].text = "+%d" % roundi(amount) if amount > 0.0 else "—"
		else:
			_derived_labels[stat_name].text = "%d%%" % roundi(player_stats.get_resistance(type))
	_derived_labels["Bloqueo"].text = "%d%%" % roundi(player_stats.get_block_chance())
	_derived_labels["Regeneración"].text = "%.1f /s" % player_stats.get_health_regen()
	_derived_labels["Recarga de habilidades"].text = "-%d%%" % roundi((1.0 - player_stats.get_cooldown_multiplier()) * 100.0)


func _on_plus_pressed(attribute: String) -> void:
	if player_stats.spend_point(attribute):
		sfx.play("click")
