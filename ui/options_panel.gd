extends VBoxContainer

## Opciones (volumenes y pantalla), ligadas al autoload options. Lo usan la
## pantalla de titulo y el menu del juego.

const VOLUMES := [["Master", "Volumen general"], ["Efectos", "Efectos y golpes"], ["Ambiente", "Ambiente"]]
const TRACK := Color(0.12, 0.09, 0.06)
const FILL := Color(0.7, 0.5, 0.22)
const BORDER := Color(0.45, 0.34, 0.18)

var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	for entry in VOLUMES:
		_add_volume_row(entry[0], entry[1])
	_add_toggle("Pantalla completa", options.fullscreen, options.set_fullscreen)
	_add_toggle("Sincronización vertical", options.vsync, options.set_vsync)


func _add_volume_row(bus_name: String, title: String) -> void:
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
	add_child(row)

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


func _add_toggle(title: String, value: bool, setter: Callable) -> void:
	var check := CheckButton.new()
	check.text = title
	check.button_pressed = value
	check.focus_mode = Control.FOCUS_ALL
	check.add_theme_color_override("font_color", Color(0.88, 0.82, 0.68))
	check.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.62))
	check.add_theme_color_override("font_focus_color", Color(1.0, 0.9, 0.62))
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
	add_child(check)


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
