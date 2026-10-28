extends PanelContainer

## Casilla de la barra de habilidades: icono, tecla, recarga (se oscurece y
## muestra los segundos) y candado con el nivel necesario.

signal pressed(index: int)

const SLOT_SIZE := Vector2(54, 54)

var index: int = -1
var _icon: TextureRect
var _cooldown_overlay: ColorRect
var _cooldown_label: Label
var _lock_label: Label
var _was_cooling: bool = false


func setup(slot_index: int) -> void:
	index = slot_index
	var skill: SkillData = skill_book.get_skill(index)
	custom_minimum_size = SLOT_SIZE
	theme_type_variation = &"SlotPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: tooltip_text = skill.get_tooltip())

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	_icon = TextureRect.new()
	_icon.texture = skill.icon
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_icon)

	_cooldown_overlay = ColorRect.new()
	_cooldown_overlay.color = Color(0, 0, 0, 0.7)
	_cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_overlay.anchor_right = 1.0
	holder.add_child(_cooldown_overlay)

	_cooldown_label = _make_label(holder, 20, Color(1, 0.95, 0.8))
	_cooldown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_lock_label = _make_label(holder, 13, Color(0.85, 0.75, 0.55))
	_lock_label.text = "Nv %d" % skill.unlock_level
	_lock_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var key_label: Label = _make_label(holder, 13, Color(1, 0.9, 0.6))
	key_label.text = str(index + 1)
	key_label.position = Vector2(2, -2)


func _make_label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 5)
	parent.add_child(label)
	return label


func _process(_delta: float) -> void:
	var unlocked: bool = skill_book.is_unlocked(index)
	_icon.modulate = Color.WHITE if unlocked else Color(0.28, 0.28, 0.28)
	_lock_label.visible = not unlocked

	var left: float = skill_book.get_cooldown_left(index) if unlocked else 0.0
	# La parte oscura baja a medida que la habilidad se recarga.
	_cooldown_overlay.anchor_bottom = skill_book.get_cooldown_ratio(index) if left > 0.0 else 0.0
	_cooldown_overlay.offset_bottom = 0.0
	_cooldown_label.text = str(ceili(left)) if left > 0.0 else ""

	# Destello corto cuando vuelve a estar lista.
	if _was_cooling and left <= 0.0:
		modulate = Color(1.8, 1.7, 1.3)
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.35)
	_was_cooling = left > 0.0


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(index)
		accept_event()
