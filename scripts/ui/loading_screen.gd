extends CanvasLayer

## Autoload: pantalla de carga con el destino y un consejo. Se usa al viajar
## por un portal (travel), al cargar una partida y al empezar una nueva
## (reload_scene). Se funde a negro, hace el cambio por debajo y vuelve.
## El mundo es una sola escena, asi que al viajar no hay nada que cargar: la
## pantalla tapa el salto y le da a la camara, la navegacion y los enemigos
## unos cuadros para acomodarse.

const TITLE_FONT := preload("res://assets/fonts/cinzel/Cinzel[wght].ttf")
const TEXT_FONT := preload("res://assets/fonts/ebgaramond/EBGaramond-Italic[wght].ttf")
const GOLD := Color(0.95, 0.8, 0.48)
const DIM := Color(0.62, 0.56, 0.46)
const BACKGROUND := Color(0.035, 0.028, 0.02)
const FADE: float = 0.3
## Lo minimo que se ve la pantalla, para que se alcance a leer el consejo.
const MIN_TIME: float = 1.6

const TIPS := [
	"Los portales que descubrís quedan en el mapa: hacé clic en uno para viajar a cualquier otro.",
	"Si caés en combate, reaparecés en el portal descubierto más cercano.",
	"Con Tab abrís el mapa del mundo. Lo que todavía no recorriste queda tapado por la niebla.",
	"Mantené Alt para ver el nombre y la vida de todos los enemigos en pantalla.",
	"El color del nivel de un enemigo avisa el peligro: gris es fácil y rojo, muy peligroso.",
	"Pelear contra enemigos de más nivel da más experiencia; los de menos nivel dan menos.",
	"Los campeones tienen aura dorada, el triple de vida y siempre sueltan equipo. De noche aparecen el doble de seguido.",
	"De noche aparecen más enemigos, más seguido y un nivel más fuertes.",
	"Con M montás el caballo para cruzar el mapa más rápido.",
	"En la herrería de la aldea podés engarzar gemas en las ranuras del equipo.",
	"El baúl de la aldea guarda lo que no te entra en la mochila.",
	"Con K armás un combo de habilidades, y con 6 lo lanzás entero.",
	"Q toma una poción de vida. Conviene llevar siempre unas cuantas.",
	"F5 guarda la partida y F9 vuelve a la última guardada. Además se guarda sola cada minuto y al viajar.",
	"Mantené el botón del medio del mouse para girar la cámara; con doble clic vuelve a su lugar.",
	"Hay cuatro tipos de daño: físico, mágico, veneno y fuego. Cada enemigo resiste distinto.",
	"Un escudo puede parar un golpe entero. Cuanto mejor el escudo, más seguido bloquea.",
	"Los golpes críticos frenan el tiempo un instante y sacuden la cámara.",
	"Cada cofre del mapa se abre una sola vez: buscalos en las ruinas y en el cementerio.",
	"Con C abrís la hoja del personaje, donde se reparten los puntos de atributo al subir de nivel.",
	"Las piezas de un mismo set dan bonos extra cuantas más tengas puestas.",
	"Las opciones de Pantalla tienen sombras, distancia de dibujo y límite de FPS para que el juego ande mejor en tu PC.",
]

## true mientras se ve la pantalla (para no encimar dos viajes).
var busy: bool = false

var _root: Control
var _caption: Label
var _title: Label
var _tip: Label
var _bar: ProgressBar
var _tip_order: Array = []


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


# Mientras se ve no pasa ninguna tecla ni clic al juego (ni el Esc del menu).
func _input(_event: InputEvent) -> void:
	if busy:
		get_viewport().set_input_as_handled()


## Viaje por portal: funde a negro, llama a action (el salto del jugador) y
## guarda la partida antes de volver.
func travel(destination: String, action: Callable) -> void:
	if busy:
		action.call()
		return
	var was_paused: bool = get_tree().paused
	await _open("VIAJANDO A", destination)
	get_tree().paused = true
	var start: int = Time.get_ticks_msec()
	action.call()
	await _fill_bar(start)
	# Unos cuadros andando antes de destapar: la camara y la transparencia se
	# ponen al dia en el lugar nuevo.
	get_tree().paused = was_paused
	for i in 3:
		await get_tree().process_frame
	await _close()
	# Se guarda ya destapado, para que se vea el aviso de guardado.
	save_game.autosave()


## Carga o partida nueva: tapa la pantalla, llama a prepare (arma el estado
## de la partida; si devuelve false no se rearma nada), rearma la escena con
## reload_current_scene y espera a que la nueva este lista.
func reload_scene(caption: String, title: String, prepare: Callable) -> bool:
	if busy:
		return false
	await _open(caption, title)
	if not prepare.call():
		await _close()
		return false
	var start: int = Time.get_ticks_msec()
	_bar.value = 0.3
	var old_scene: Node = get_tree().current_scene
	get_tree().reload_current_scene()
	while get_tree().current_scene == null or get_tree().current_scene == old_scene:
		await get_tree().process_frame
	# Unos cuadros para que la navegacion y el HUD terminen de armarse.
	for i in 3:
		await get_tree().process_frame
	await _fill_bar(start)
	await _close()
	return true


func _open(caption: String, title: String) -> void:
	busy = true
	_caption.text = caption
	_title.text = title
	_tip.text = _next_tip()
	_bar.value = 0.0
	_root.modulate.a = 0.0
	visible = true
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, FADE)
	await tween.finished


# La barra avanza hasta completar MIN_TIME desde start.
func _fill_bar(start: int) -> void:
	var left: float = maxf(MIN_TIME - (Time.get_ticks_msec() - start) / 1000.0, 0.15)
	var tween := create_tween()
	tween.tween_property(_bar, "value", 1.0, left).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _close() -> void:
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, FADE)
	await tween.finished
	visible = false
	busy = false


# Los consejos salen en orden mezclado y no se repiten hasta pasar todos.
func _next_tip() -> String:
	if _tip_order.is_empty():
		_tip_order = range(TIPS.size())
		_tip_order.shuffle()
	return TIPS[_tip_order.pop_back()]


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	# Resplandor calido detras del texto, como una vela en lo oscuro.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.2, 0.13, 0.06, 0.9))
	gradient.set_color(1, Color(0.2, 0.13, 0.06, 0.0))
	var glow := GradientTexture2D.new()
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	var glow_rect := TextureRect.new()
	glow_rect.texture = glow
	glow_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow_rect.set_anchors_preset(Control.PRESET_CENTER)
	glow_rect.size = Vector2(1100, 620)
	glow_rect.position = -glow_rect.size / 2.0
	glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(glow_rect)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.custom_minimum_size = Vector2(680, 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	_root.add_child(column)

	_caption = _label(_font(TITLE_FONT, 500), 15, DIM)
	column.add_child(_caption)
	_title = _label(_font(TITLE_FONT, 700), 46, GOLD)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_title.add_theme_constant_override("shadow_offset_y", 3)
	column.add_child(_title)

	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.45)
	rule.custom_minimum_size = Vector2(320, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(rule)

	_tip = _label(_font(TEXT_FONT, 450), 20, Color(0.88, 0.82, 0.68))
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(680, 90)
	_tip.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	column.add_child(_tip)

	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(420, 14)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_bar)


func _label(font: Font, size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _font(base: Font, weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = base
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font
