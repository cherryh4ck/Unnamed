extends VBoxContainer

## Opciones (volumenes, pantalla y graficos), ligadas al autoload options. Lo
## usan la pantalla de titulo y el menu del juego. Tres pestanas (Sonido,
## Pantalla y Graficos) de cuatro filas, para que el panel no crezca de alto.

const VOLUMES := [["Master", "Volumen general"], ["Musica", "Música"], ["Efectos", "Efectos y golpes"], ["Ambiente", "Ambiente"]]
const TRACK := Color(0.12, 0.09, 0.06)
const FILL := Color(0.7, 0.5, 0.22)
const BORDER := Color(0.45, 0.34, 0.18)
const TEXT := Color(0.88, 0.82, 0.68)
const HIGHLIGHT := Color(1.0, 0.9, 0.62)

var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _tab_buttons: Array[Button] = []
var _tabs: Array[VBoxContainer] = []


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	add_child(tab_row)
	var group := ButtonGroup.new()

	var sound := _new_tab(tab_row, group, "Sonido")
	for entry in VOLUMES:
		_add_volume_row(sound, entry[0], entry[1])

	var screen := _new_tab(tab_row, group, "Pantalla")
	_add_toggle(screen, "Pantalla completa", options.fullscreen, options.set_fullscreen)
	_add_toggle(screen, "Sincronización vertical", options.vsync, options.set_vsync)
	_add_choice(screen, "Límite de FPS", options.FPS_NAMES, "fps_limit")
	_add_toggle(screen, "Mostrar FPS", options.show_fps, func(on: bool) -> void: options.set_graphics("show_fps", on))

	var graphics := _new_tab(tab_row, group, "Gráficos")
	_add_choice(graphics, "Sombras", options.SHADOW_NAMES, "shadows")
	_add_choice(graphics, "Distancia de dibujo", options.DISTANCE_NAMES, "draw_distance")
	_add_choice(graphics, "Resolución 3D", options.SCALE_NAMES, "render_scale")
	_add_choice(graphics, "Antialiasing", options.MSAA_NAMES, "antialiasing")
	_show_tab(0)


func _new_tab(tab_row: HBoxContainer, group: ButtonGroup, title: String) -> VBoxContainer:
	var index: int = _tabs.size()
	var button := Button.new()
	button.text = title
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(120, 34)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(func() -> void:
		_show_tab(index)
		sfx.play("click"))
	tab_row.add_child(button)
	_tab_buttons.append(button)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	_tabs.append(box)
	return box


func _show_tab(index: int) -> void:
	for i in _tabs.size():
		_tabs[i].visible = i == index
		_tab_buttons[i].set_pressed_no_signal(i == index)
		# El tema dibuja igual el boton apretado: las otras se oscurecen.
		_tab_buttons[i].modulate = Color.WHITE if i == index else Color(0.55, 0.55, 0.55)


func _add_volume_row(box: VBoxContainer, bus_name: String, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 190
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = options.volumes.get(bus_name, 1.0)
	slider.custom_minimum_size = Vector2(220, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 46
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.theme_type_variation = &"DimLabel"
	row.add_child(value_label)
	box.add_child(row)

	_sliders[bus_name] = slider
	_value_labels[bus_name] = value_label
	_show_value(bus_name)
	slider.value_changed.connect(func(value: float) -> void:
		options.set_volume(bus_name, value)
		_show_value(bus_name))
	# Al soltar suena un golpe de prueba con el volumen nuevo.
	slider.drag_ended.connect(func(_changed: bool) -> void: sfx.play("click"))


func _show_value(bus_name: String) -> void:
	_value_labels[bus_name].text = "%d%%" % roundi(options.volumes.get(bus_name, 1.0) * 100.0)


func _add_toggle(box: VBoxContainer, title: String, value: bool, setter: Callable) -> void:
	var check := CheckButton.new()
	check.text = title
	check.button_pressed = value
	check.focus_mode = Control.FOCUS_ALL
	check.add_theme_color_override("font_color", TEXT)
	check.add_theme_color_override("font_hover_color", HIGHLIGHT)
	check.add_theme_color_override("font_focus_color", HIGHLIGHT)
	check.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.55))
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		check.add_theme_stylebox_override(style, empty)
	# Interruptor propio: el de Godot apagado casi no se ve sobre la madera.
	check.add_theme_icon_override("checked", _switch(true))
	check.add_theme_icon_override("unchecked", _switch(false))
	check.toggled.connect(func(on: bool) -> void:
		setter.call(on)
		sfx.play("click"))
	box.add_child(check)


# Fila con flechas para elegir entre valores fijos; key es la variable de
# options que guarda el indice. Clic en el valor tambien pasa al siguiente.
func _add_choice(box: VBoxContainer, title: String, names: Array, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 190
	row.add_child(label)

	var value := _flat_button()
	var refresh := func() -> void: value.text = names[int(options.get(key))]
	var step := func(direction: int) -> void:
		options.set_graphics(key, wrapi(int(options.get(key)) + direction, 0, names.size()))
		refresh.call()
		sfx.play("click")
	row.add_child(_arrow(true, step.bind(-1)))
	value.focus_mode = Control.FOCUS_NONE
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_color_override("font_color", HIGHLIGHT)
	value.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.8))
	value.add_theme_color_override("font_pressed_color", HIGHLIGHT)
	value.pressed.connect(step.bind(1))
	row.add_child(value)
	row.add_child(_arrow(false, step.bind(1)))
	refresh.call()
	box.add_child(row)


func _arrow(left: bool, action: Callable) -> Button:
	var arrow := _flat_button()
	arrow.icon = _triangle(left)
	arrow.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.custom_minimum_size = Vector2(28, 24)
	arrow.focus_mode = Control.FOCUS_ALL
	arrow.add_theme_color_override("icon_normal_color", FILL)
	arrow.add_theme_color_override("icon_hover_color", HIGHLIGHT)
	arrow.add_theme_color_override("icon_focus_color", HIGHLIGHT)
	arrow.add_theme_color_override("icon_pressed_color", HIGHLIGHT)
	arrow.pressed.connect(action)
	return arrow


# Boton sin fondo ni margenes del tema (las filas quedan del alto del texto).
func _flat_button() -> Button:
	var button := Button.new()
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(style, empty)
	return button


func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = TRACK
	track.border_color = BORDER
	track.set_border_width_all(1)
	track.set_corner_radius_all(2)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := track.duplicate()
	fill.bg_color = FILL
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob(Color(0.95, 0.82, 0.5))
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", _knob(Color(1.0, 0.92, 0.7)))


# Interruptor tipo pildora: dorado y perilla a la derecha si esta prendido.
static func _switch(on: bool) -> ImageTexture:
	var size := Vector2i(40, 20)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var track: Color = FILL if on else TRACK.lightened(0.08)
	var knob_x: float = size.x - 10.0 if on else 10.0
	for y in size.y:
		for x in size.x:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx: float = clampf(p.x, 10.0, size.x - 10.0)
			var d_track: float = p.distance_to(Vector2(cx, 10.0))
			var d_knob: float = p.distance_to(Vector2(knob_x, 10.0))
			var c := Color(0, 0, 0, 0)
			if d_track <= 9.5:
				c = BORDER if d_track > 8.3 else track
			if d_knob <= 7.0:
				c = Color(0.95, 0.85, 0.6) if on else Color(0.55, 0.5, 0.42)
			image.set_pixel(x, y, c)
	return ImageTexture.create_from_image(image)


# Triangulo blanco (el color lo pone el boton) que apunta a un costado.
static func _triangle(left: bool) -> ImageTexture:
	var size := Vector2i(10, 14)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var px: float = (size.x - 0.5 - x) if left else (x + 0.5)
			var half: float = size.y / 2.0 * (1.0 - px / size.x)
			var dy: float = absf(y + 0.5 - size.y / 2.0)
			image.set_pixel(x, y, Color(1, 1, 1, clampf(half - dy + 0.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


# Perilla redonda dorada con borde oscuro.
static func _knob(color: Color) -> ImageTexture:
	var size: int = 18
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) / 2.0
	for y in size:
		for x in size:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= size / 2.0 - 0.5:
				var edge: float = clampf((size / 2.0 - 0.5 - d), 0.0, 1.0)
				var c: Color = color if d < size / 2.0 - 2.5 else Color(0.18, 0.12, 0.06)
				image.set_pixel(x, y, Color(c, edge))
	return ImageTexture.create_from_image(image)
