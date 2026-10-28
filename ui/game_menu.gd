extends PanelContainer

## Menu del juego (Esc sin otro panel abierto): continuar, guardar, cargar,
## partida nueva con eleccion de dificultad y salir. Si se abre el juego sin
## partida guardada arranca directo en la eleccion de dificultad.

var _main_box: VBoxContainer
var _difficulty_box: VBoxContainer
var _difficulty_label: Label
var _load_button: Button
var _back_button: Button
var _warning: Label
## Primera partida: hay que elegir dificultad (no se puede volver con Esc).
var _choosing_first: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_panels")
	custom_minimum_size = Vector2(460, 0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var root := VBoxContainer.new()
	add_child(root)
	_main_box = _build_main()
	_difficulty_box = _build_difficulty()
	root.add_child(_main_box)
	root.add_child(_difficulty_box)
	# Los textos con autoajuste cambian de alto al acomodarse: se recentra.
	minimum_size_changed.connect(_recenter)

	if not save_game.has_save():
		_choosing_first = true
		# Unos frames sin pausa para que el HUD de atras termine de dibujarse.
		await get_tree().create_timer(0.1).timeout
		open_difficulty()


func _build_main() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_header("MENÚ", "Esc: volver al juego"))

	_difficulty_label = Label.new()
	box.add_child(_difficulty_label)

	_add_button(box, "Continuar", close)
	_add_button(box, "Guardar partida (F5)", func() -> void:
		close()
		save_game.quick_save())
	_load_button = _add_button(box, "Cargar última partida (F9)", func() -> void:
		close()
		save_game.reload_last_save())
	_add_button(box, "Partida nueva", open_difficulty)
	_add_button(box, "Salir del juego", func() -> void:
		save_game.save()
		get_tree().quit())

	var keys := Label.new()
	keys.text = "I inventario · C personaje · K combo · M montura · Q poción"
	keys.theme_type_variation = &"DimLabel"
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(keys)

	# Atribucion que pide la licencia CC-BY de las texturas (ver CREDITS.md).
	var credits := Label.new()
	credits.text = "Interfaz: RPG GUI construction kit de Matjaž Lamut (CC-BY 3.0)"
	credits.theme_type_variation = &"DimLabel"
	credits.add_theme_font_size_override("font_size", 11)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(credits)
	return box


func _build_difficulty() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_header("PARTIDA NUEVA", ""))

	var info := Label.new()
	info.text = "Elegí la dificultad. Queda fija para toda la partida."
	info.theme_type_variation = &"DimLabel"
	box.add_child(info)

	_warning = Label.new()
	_warning.text = "Se reemplaza la partida guardada."
	_warning.add_theme_color_override("font_color", Color(0.95, 0.35, 0.3))
	box.add_child(_warning)

	for i in difficulty.LEVELS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var button := _add_button(row, difficulty.get_level_name(i), _on_difficulty_chosen.bind(i))
		button.custom_minimum_size = Vector2(120, 40)
		button.add_theme_color_override("font_color", difficulty.get_color(i))
		button.add_theme_color_override("font_hover_color", difficulty.get_color(i).lightened(0.3))
		var description := Label.new()
		description.text = difficulty.LEVELS[i].description
		description.theme_type_variation = &"DimLabel"
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(description)
		box.add_child(row)

	_back_button = _add_button(box, "Volver", _show_main)
	return box


func _header(title_text: String, hint_text: String) -> HBoxContainer:
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = title_text
	title.theme_type_variation = &"HeaderLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint := Label.new()
	hint.text = hint_text
	hint.theme_type_variation = &"DimLabel"
	header.add_child(title)
	header.add_child(hint)
	return header


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		if not _choosing_first:
			if _difficulty_box.visible:
				_show_main()
			else:
				close()
		get_viewport().set_input_as_handled()
	elif not _any_panel_open():
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	_show_main()
	visible = true
	sfx.play("page")
	_update_pause()


func open_difficulty() -> void:
	_main_box.visible = false
	_difficulty_box.visible = true
	_warning.visible = save_game.has_save()
	_back_button.visible = not _choosing_first
	if not visible:
		visible = true
		_update_pause()
	_recenter.call_deferred()


func close() -> void:
	visible = false
	sfx.play("page")
	_update_pause()


func _show_main() -> void:
	_main_box.visible = true
	_difficulty_box.visible = false
	_difficulty_label.text = "Dificultad: %s" % difficulty.get_level_name()
	_difficulty_label.add_theme_color_override("font_color", difficulty.get_color())
	_load_button.disabled = not save_game.has_save()
	_recenter.call_deferred()


# El panel cambia de alto entre las dos vistas: se vuelve a centrar con su
# tamaño minimo.
func _recenter() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _on_difficulty_chosen(index: int) -> void:
	_choosing_first = false
	close()
	save_game.new_game(index)


func _any_panel_open() -> bool:
	return get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel.visible)


func _update_pause() -> void:
	get_tree().paused = _any_panel_open()
