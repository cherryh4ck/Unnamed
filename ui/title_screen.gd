class_name TitleScreen
extends CanvasLayer

## Pantalla de titulo al abrir el juego. El mundo ya esta cargado atras (con
## la partida guardada) y una camara lo recorre despacio mientras el juego
## esta en pausa. Menu con mouse o teclado: Continuar, Partida nueva (con la
## dificultad), Opciones, Creditos y Salir. Al entrar, la camara baja hasta
## la del juego y aparece el HUD.

const OptionsPanel := preload("res://ui/options_panel.gd")
const FLAME := preload("res://fx/textures/flame_strip.png")
const SOFT := preload("res://fx/textures/circle_05.png")
const TITLE_FONT := preload("res://assets/fonts/cinzel/Cinzel[wght].ttf")

const GOLD := Color(0.95, 0.8, 0.48)
const PARCHMENT := Color(0.86, 0.79, 0.64)
const DIM := Color(0.62, 0.56, 0.46)
## Recorrido de la camara: alrededor de la plaza de la aldea.
const ORBIT_CENTER := Vector3(0, 120, -200)
const ORBIT_RADIUS: float = 2500.0
const ORBIT_HEIGHT: float = 1500.0
## Capa 2: nombres de los items y de los NPC (se dibujan siempre encima).
const LABELS_LAYER: int = 2
const ORBIT_SPEED: float = 0.035
const ENTER_TIME: float = 1.4

## Se muestra una sola vez por sesion (no al cargar con F9 ni en partida
## nueva). El menu del juego la vuelve a pedir con "Menú principal".
static var show_on_next_load: bool = true

var _root: Control
var _pages: Dictionary = {}
var _camera: Camera3D
var _angle: float = 0.6
var _leaving: bool = false
var _title_font: FontVariation
var _item_font: FontVariation


func _ready() -> void:
	if not show_on_next_load:
		queue_free()
		return
	show_on_next_load = false
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("title_screen")
	_title_font = _variation(600)
	_item_font = _variation(500)
	_build()
	_set_hud_visible(false)
	get_tree().paused = true
	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.far = 30000.0
	_camera.cull_mask = 0xFFFFF & ~LABELS_LAYER
	get_tree().current_scene.add_child.call_deferred(_camera)
	_start_camera.call_deferred()
	_show_page("main")


func _start_camera() -> void:
	_camera.current = true
	_update_camera(0.0)


func _variation(weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = TITLE_FONT
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font


func _process(delta: float) -> void:
	if not _leaving and _camera and _camera.is_inside_tree():
		_update_camera(delta)


func _update_camera(delta: float) -> void:
	_angle += delta * ORBIT_SPEED
	_camera.global_position = ORBIT_CENTER + Vector3(cos(_angle) * ORBIT_RADIUS, ORBIT_HEIGHT, sin(_angle) * ORBIT_RADIUS)
	_camera.look_at(ORBIT_CENTER, Vector3.UP)


# Nada del juego responde a teclas mientras esta el titulo (inventario, mapa,
# guardado rapido): todo lo que la interfaz no uso se descarta aca.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _pages.main.visible:
		_show_page("main")
	get_viewport().set_input_as_handled()


# --- Armado ----------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Viñeta oscura a la izquierda (donde va el texto) y abajo.
	_root.add_child(_gradient_rect(Vector2(0, 0), Vector2(1, 0), [Color(0.02, 0.015, 0.01, 0.92), Color(0.02, 0.015, 0.01, 0.55), Color(0, 0, 0, 0)], [0.0, 0.38, 0.7]))
	_root.add_child(_gradient_rect(Vector2(0, 1), Vector2(0, 0), [Color(0, 0, 0, 0.75), Color(0, 0, 0, 0)], [0.0, 0.35]))
	_root.add_child(_embers())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	column.offset_left = 96
	column.offset_right = 640
	column.offset_top = 48
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(column)

	var title := Label.new()
	title.text = str(ProjectSettings.get_setting("application/config/name", "Unnamed")).to_upper()
	title.add_theme_font_override("font", _title_font)
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_constant_override("shadow_outline_size", 8)
	column.add_child(title)

	var tagline := Label.new()
	tagline.text = "Un ARPG de código libre"
	tagline.add_theme_font_override("font", _item_font)
	tagline.add_theme_font_size_override("font_size", 15)
	tagline.add_theme_color_override("font_color", DIM)
	column.add_child(tagline)

	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.45)
	rule.custom_minimum_size = Vector2(300, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var rule_box := MarginContainer.new()
	rule_box.add_theme_constant_override("margin_top", 12)
	rule_box.add_theme_constant_override("margin_bottom", 18)
	rule_box.add_child(rule)
	column.add_child(rule_box)

	var pages := Control.new()
	pages.custom_minimum_size = Vector2(520, 420)
	column.add_child(pages)
	_pages.main = _build_main()
	_pages.new = _build_new_game()
	_pages.options = _build_options()
	_pages.credits = _build_credits()
	for page in _pages.values():
		page.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		pages.add_child(page)

	var hint := Label.new()
	hint.text = "Mouse o flechas para elegir · Enter: aceptar · Esc: volver"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(DIM, 0.8))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 96
	hint.offset_top = -48
	hint.offset_bottom = -26
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(hint)


func _build_main() -> VBoxContainer:
	var page := _page()
	if save_game.has_save():
		var item := _item(page, "Continuar", _enter_game)
		var detail := Label.new()
		detail.text = "Nivel %d · %s · Día %d" % [player_stats.level, difficulty.get_level_name(), world_time.day]
		detail.add_theme_font_size_override("font_size", 14)
		detail.add_theme_color_override("font_color", difficulty.get_color().lerp(DIM, 0.35))
		var detail_box := MarginContainer.new()
		detail_box.add_theme_constant_override("margin_left", 34)
		detail_box.add_theme_constant_override("margin_bottom", 6)
		detail_box.add_child(detail)
		page.add_child(detail_box)
		item.set_meta("first", true)
	_item(page, "Partida nueva", _show_page.bind("new"))
	_item(page, "Opciones", _show_page.bind("options"))
	_item(page, "Créditos", _show_page.bind("credits"))
	_item(page, "Salir", func() -> void: get_tree().quit())
	return page


func _build_new_game() -> VBoxContainer:
	var page := _page()
	page.add_child(_header("Partida nueva"))
	var info := _text("Elegí la dificultad. Queda fija para toda la partida.", 15, DIM)
	page.add_child(info)
	if save_game.has_save():
		page.add_child(_text("Se reemplaza la partida guardada.", 15, Color(0.95, 0.42, 0.32)))
	for i in difficulty.LEVELS.size():
		var item := _item(page, difficulty.get_level_name(i), _start_new_game.bind(i), difficulty.get_color(i), 40.0)
		if i == 0:
			item.set_meta("first", true)
		var description := _text(difficulty.LEVELS[i].description, 13, DIM)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var box := MarginContainer.new()
		box.add_theme_constant_override("margin_left", 34)
		box.add_theme_constant_override("margin_bottom", 4)
		box.add_child(description)
		page.add_child(box)
	_item(page, "Volver", _show_page.bind("main"))
	return page


func _build_options() -> VBoxContainer:
	var page := _page()
	page.add_child(_header("Opciones"))
	var panel := OptionsPanel.new()
	panel.custom_minimum_size.x = 500
	page.add_child(panel)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	page.add_child(spacer)
	_item(page, "Volver", _show_page.bind("main")).set_meta("first", true)
	return page


func _build_credits() -> VBoxContainer:
	var page := _page()
	page.add_child(_header("Créditos"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.custom_minimum_size.x = 480
	text.add_theme_color_override("default_color", PARCHMENT)
	text.add_theme_font_size_override("normal_font_size", 15)
	text.add_theme_font_override("bold_font", _item_font)
	text.add_theme_font_size_override("bold_font_size", 15)
	text.text = _credits_text()
	scroll.add_child(text)
	page.add_child(scroll)
	_item(page, "Volver", _show_page.bind("main")).set_meta("first", true)
	return page


func _credits_text() -> String:
	var gold: String = GOLD.to_html(false)
	var lines := PackedStringArray([
		"[color=#%s][b]Interfaz[/b][/color]" % gold,
		"RPG GUI construction kit — Matjaž Lamut (CC-BY 3.0)",
		"",
		"[color=#%s][b]Íconos[/b][/color]" % gold,
		"game-icons.net — Lorc, Delapouite, Sbed y Carl Olsen (CC BY 3.0)",
		"",
		"[color=#%s][b]Mundo y efectos (CC0)[/b][/color]" % gold,
		"Poly Haven — Rob Tuytel, Rico Cilliers, James Ray Cock, Jenelle van Heerden, Kless Gyzen, Sebastian Platen, Benny Weimer",
		"ambientCG · Kenney (Graveyard Kit, Particle Pack, RPG Audio, Interface Sounds) · Quaternius",
		"",
		"Herrería de la aldea («Forge») — Don Carson (CC-BY 3.0)",
		"",
		"[color=#%s][b]Música (CC0)[/b][/color]" % gold,
		"RandomMind · Cleyton Kauffman · isaiah658 · Emma_MA",
		"",
		"[color=#%s][b]Sonidos (CC0 y dominio público)[/b][/color]" % gold,
		"Ylmir · stephan (pdsounds.org) · Luke.RUSTLTD · VishwaJai · themightyglider",
		"",
		"[color=#%s][b]Fuentes (SIL OFL)[/b][/color]" % gold,
		"Cinzel — Natanael Gama · EB Garamond — Georg Duffner, Octavio Pardo",
		"",
		"[color=#%s]El detalle de cada pieza está en CREDITS.md.[/color]" % DIM.to_html(false),
	])
	return "\n".join(lines)


func _page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 2)
	page.visible = false
	return page


func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_override("font", _title_font)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _text(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.custom_minimum_size.x = 460
	return label


## Opcion del menu: texto grande que al elegirla (mouse o teclado) se corre
## un poco a la derecha y muestra una llamita a la izquierda.
func _item(page: VBoxContainer, text: String, action: Callable, color: Color = PARCHMENT, height: float = 46.0) -> Button:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(460, height)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(holder)

	var marker := TextureRect.new()
	var flame := AtlasTexture.new()
	flame.atlas = FLAME
	flame.region = Rect2(0, 0, 256, 256)
	marker.texture = flame
	marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marker.size = Vector2(26, 30)
	marker.position = Vector2(-4, (height - 34.0) / 2.0)
	marker.modulate = Color(1.0, 0.62, 0.25, 0.0)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	marker.material = glow
	holder.add_child(marker)

	var button := Button.new()
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.position = Vector2(24, 0)
	button.size = Vector2(420, height)
	button.add_theme_font_override("font", _item_font)
	button.add_theme_font_size_override("font_size", 27)
	button.add_theme_color_override("font_color", color.darkened(0.12))
	button.add_theme_color_override("font_hover_color", color.lightened(0.25))
	button.add_theme_color_override("font_focus_color", color.lightened(0.25))
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	button.add_theme_constant_override("outline_size", 6)
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(style, empty)
	holder.add_child(button)

	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(_on_item_focus.bind(button, marker, true))
	button.focus_exited.connect(_on_item_focus.bind(button, marker, false))
	button.pressed.connect(func() -> void:
		sfx.play("page")
		action.call())
	return button


func _on_item_focus(button: Button, marker: TextureRect, on: bool) -> void:
	if on:
		sfx.play("click", -14.0)
	var tween := button.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position:x", 38.0 if on else 24.0, 0.18)
	tween.tween_property(marker, "modulate:a", 1.0 if on else 0.0, 0.18)
	marker.set_meta("lit", on)


func _show_page(page_name: String) -> void:
	for key in _pages:
		_pages[key].visible = key == page_name
	# El foco va a la primera opcion marcada (o la primera que haya).
	var page: Control = _pages[page_name]
	var buttons: Array = page.find_children("*", "Button", true, false)
	var first: Control = null
	for button in buttons:
		if button.has_meta("first"):
			first = button
			break
	if first == null and not buttons.is_empty():
		first = buttons[0]
	if first:
		first.grab_focus.call_deferred()


func _gradient_rect(from: Vector2, to: Vector2, colors: Array, offsets: Array) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = from
	texture.fill_to = to
	texture.width = 256
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


# Chispas de fogata que suben despacio por la pantalla.
func _embers() -> Control:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var particles := CPUParticles2D.new()
	particles.amount = 46
	particles.lifetime = 7.0
	particles.preprocess = 7.0
	particles.texture = SOFT
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(900, 10)
	particles.position = Vector2(640, 760)
	particles.direction = Vector2(0, -1)
	particles.spread = 25.0
	particles.gravity = Vector2(0, -12)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 110.0
	particles.scale_amount_min = 0.03
	particles.scale_amount_max = 0.09
	particles.color_ramp = Effects.ramp([Color(1.0, 0.6, 0.2, 0.0), Color(1.0, 0.62, 0.25, 0.8), Color(1.0, 0.45, 0.15, 0.0)])
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = material
	holder.add_child(particles)
	holder.resized.connect(func() -> void:
		particles.position = Vector2(holder.size.x / 2.0, holder.size.y + 20.0)
		particles.emission_rect_extents = Vector2(holder.size.x / 2.0, 10))
	return holder


# --- Salir del titulo ------------------------------------------------------

## Continuar: la camara baja hasta la del juego y aparece el HUD.
func _enter_game() -> void:
	if _leaving:
		return
	_leaving = true
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var game_camera: Camera3D = _game_camera()
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_root, "modulate:a", 0.0, ENTER_TIME * 0.6)
	if game_camera:
		tween.tween_property(_camera, "global_transform", game_camera.global_transform, ENTER_TIME)
		tween.tween_property(_camera, "fov", game_camera.fov, ENTER_TIME)
	tween.chain().tween_callback(_finish)


func _finish() -> void:
	var game_camera: Camera3D = _game_camera()
	if game_camera:
		game_camera.current = true
	_camera.queue_free()
	get_tree().paused = false
	_set_hud_visible(true)
	queue_free()


func _start_new_game(level: int) -> void:
	get_tree().paused = false
	# La escena se vuelve a armar con la partida nueva (sin titulo).
	save_game.new_game(level)


func _game_camera() -> Camera3D:
	var rig: Node = get_tree().current_scene.get_node_or_null("CameraRig")
	return rig.get_node_or_null("Camera3D") if rig else null


func _set_hud_visible(on: bool) -> void:
	var hud: CanvasLayer = get_tree().current_scene.get_node_or_null("HUD")
	if hud:
		hud.visible = on
