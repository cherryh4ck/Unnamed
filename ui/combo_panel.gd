extends PanelContainer

## Panel para armar el combo (tecla K): hasta 3 habilidades aprendidas que
## se ejecutan una detras de otra con la tecla 6.

const ICON_SIZE: int = 24

var _pickers: Array[OptionButton] = []
var _cooldown_label: Label
var _locked_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_panels")
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	custom_minimum_size = Vector2(380, 0)
	offset_left = -190.0
	offset_right = 190.0
	offset_top = 110.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_END

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "COMBO"
	title.theme_type_variation = &"HeaderLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint := Label.new()
	hint.text = "K: cerrar"
	hint.theme_type_variation = &"DimLabel"
	header.add_child(title)
	header.add_child(hint)
	box.add_child(header)

	var info := Label.new()
	info.text = "Elegí hasta 3 habilidades. Con la tecla 6 se usan una detrás de otra. El combo tiene su propia recarga y no gasta la de cada habilidad."
	info.theme_type_variation = &"DimLabel"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 350
	box.add_child(info)

	for i in skill_book.COMBO_MAX_SKILLS:
		var row := HBoxContainer.new()
		var number := Label.new()
		number.text = "%d." % (i + 1)
		number.custom_minimum_size.x = 24
		var picker := OptionButton.new()
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.add_theme_constant_override("icon_max_width", ICON_SIZE)
		picker.get_popup().add_theme_constant_override("icon_max_width", ICON_SIZE)
		picker.item_selected.connect(_on_picker_changed.unbind(1))
		row.add_child(number)
		row.add_child(picker)
		box.add_child(row)
		_pickers.append(picker)

	_cooldown_label = Label.new()
	box.add_child(_cooldown_label)
	_locked_label = Label.new()
	_locked_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.4))
	_locked_label.text = "Los combos se aprenden en el nivel %d." % skill_book.COMBO_UNLOCK_LEVEL
	box.add_child(_locked_label)

	var clear := Button.new()
	clear.text = "Limpiar combo"
	clear.pressed.connect(func() -> void:
		skill_book.set_combo([])
		sfx.play("click")
		_refresh())
	box.add_child(clear)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_combo"):
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
	_refresh()
	sfx.play("page")
	_update_pause()


func close() -> void:
	visible = false
	sfx.play("page")
	_update_pause()


func _update_pause() -> void:
	get_tree().paused = get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel.visible)


# Los ids de las opciones son indice de habilidad + 1 (0 = ninguna), porque
# OptionButton toma -1 como "usar el indice" y chocaria con la habilidad 0.
# Rearma las listas con las habilidades aprendidas y marca el combo actual.
func _refresh() -> void:
	var unlocked: bool = skill_book.is_combo_unlocked()
	_locked_label.visible = not unlocked
	for i in _pickers.size():
		var picker: OptionButton = _pickers[i]
		picker.clear()
		picker.add_item("—", 0)
		for index in skill_book.skills.size():
			if skill_book.is_unlocked(index):
				var skill: SkillData = skill_book.get_skill(index)
				picker.add_icon_item(skill.icon, skill.name, index + 1)
		var current: int = skill_book.combo[i] + 1 if i < skill_book.combo.size() else 0
		picker.select(maxi(picker.get_item_index(current), 0))
		picker.disabled = not unlocked
	_update_cooldown_label()


func _on_picker_changed() -> void:
	var indices: Array[int] = []
	for picker in _pickers:
		var id: int = picker.get_selected_id()
		if id > 0:
			indices.append(id - 1)
	skill_book.set_combo(indices)
	sfx.play("click")
	_update_cooldown_label()


func _update_cooldown_label() -> void:
	if skill_book.combo.is_empty():
		_cooldown_label.text = "Sin combo armado."
	else:
		_cooldown_label.text = "Recarga del combo: %.1f s" % skill_book.get_combo_cooldown()
