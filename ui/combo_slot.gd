extends PanelContainer

## Casilla del combo en la barra de habilidades (tecla 6): muestra los iconos
## de las habilidades del combo, su recarga y si todavia esta bloqueado.

signal pressed

const SLOT_SIZE := Vector2(54, 54)

var _icons: HBoxContainer
var _cooldown_overlay: ColorRect
var _cooldown_label: Label
var _center_label: Label
var _was_cooling: bool = false


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	theme_type_variation = &"SlotPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_update_tooltip)

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	_icons = HBoxContainer.new()
	_icons.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icons.alignment = BoxContainer.ALIGNMENT_CENTER
	_icons.add_theme_constant_override("separation", 0)
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_icons)

	_cooldown_overlay = ColorRect.new()
	_cooldown_overlay.color = Color(0, 0, 0, 0.7)
	_cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_overlay.anchor_right = 1.0
	holder.add_child(_cooldown_overlay)

	_cooldown_label = _make_label(holder, 20, Color(1, 0.95, 0.8))
	_center_label = _make_label(holder, 13, Color(0.85, 0.75, 0.55))
	var key_label: Label = _make_label(holder, 13, Color(1, 0.9, 0.6))
	key_label.text = "6"
	key_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	key_label.position = Vector2(2, -2)

	skill_book.combo_changed.connect(_rebuild_icons)
	_rebuild_icons()


func _make_label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 5)
	parent.add_child(label)
	return label


func _rebuild_icons() -> void:
	for child in _icons.get_children():
		child.queue_free()
	var count: int = skill_book.combo.size()
	for index in skill_book.combo:
		var icon := TextureRect.new()
		icon.texture = skill_book.get_skill(index).icon
		icon.custom_minimum_size = Vector2(SLOT_SIZE.x / maxf(count, 1.0) - 2.0, 0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icons.add_child(icon)


func _update_tooltip() -> void:
	var lines := PackedStringArray(["Combo (tecla 6)"])
	if not skill_book.is_combo_unlocked():
		lines.append("Se aprende en el nivel %d" % skill_book.COMBO_UNLOCK_LEVEL)
	elif skill_book.combo.is_empty():
		lines.append("Armalo con la tecla K")
	else:
		for index in skill_book.combo:
			lines.append("· " + skill_book.get_skill(index).name)
		lines.append("Recarga: %.1f s" % skill_book.get_combo_cooldown())
	tooltip_text = "\n".join(lines)


func _process(_delta: float) -> void:
	var unlocked: bool = skill_book.is_combo_unlocked()
	_icons.modulate = Color.WHITE if unlocked else Color(0.3, 0.3, 0.3)
	if not unlocked:
		_center_label.text = "Nv %d" % skill_book.COMBO_UNLOCK_LEVEL
	elif skill_book.combo.is_empty():
		_center_label.text = "K"
	else:
		_center_label.text = ""

	var left: float = skill_book.get_combo_cooldown_left() if unlocked else 0.0
	_cooldown_overlay.anchor_bottom = skill_book.get_combo_cooldown_ratio() if left > 0.0 else 0.0
	_cooldown_overlay.offset_bottom = 0.0
	_cooldown_label.text = str(ceili(left)) if left > 0.0 else ""

	if _was_cooling and left <= 0.0:
		modulate = Color(1.8, 1.7, 1.3)
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.35)
	_was_cooling = left > 0.0


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()
