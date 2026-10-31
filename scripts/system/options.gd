extends Node

## Autoload con las opciones del jugador (volumen, pantalla y graficos). Se
## guardan aparte de la partida, en user://opciones.cfg, y se aplican al abrir.
## Las sombras van al sol (grupo "sun") y la distancia de dibujo a la camara
## del juego (camera_rig.gd la lee con view_distance()).
## Los sonidos van por buses: "Efectos" (golpes, hechizos, interfaz, pasos),
## "Ambiente" (grillos, lluvia, viento) y "Musica"; todos pasan por "Master"
## (volumen general).

signal changed

const PATH := "user://opciones.cfg"
const BUSES := ["Efectos", "Ambiente", "Musica"]

## Cada opcion grafica es un indice en su lista; los nombres van al menu.
const SHADOW_NAMES := ["Apagadas", "Bajas", "Medias", "Altas"]
const SHADOW_ATLAS := [1024, 1024, 2048, 4096]
const SHADOW_FILTER := [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM]
const DISTANCE_NAMES := ["Corta", "Normal", "Lejana"]
const DISTANCES := [3000.0, 4000.0, 6500.0]
const FPS_NAMES := ["Sin límite", "30", "60", "120", "144"]
const FPS_LIMITS := [0, 30, 60, 120, 144]
const SCALE_NAMES := ["50 %", "70 %", "85 %", "100 %"]
const SCALES := [0.5, 0.7, 0.85, 1.0]
const MSAA_NAMES := ["No", "2x", "4x"]
const MSAA := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]

## Volumen lineal de 0 a 1 por bus ("Master" = general).
var volumes: Dictionary = {"Master": 0.8, "Efectos": 1.0, "Ambiente": 0.8, "Musica": 0.6}
var fullscreen: bool = false
var vsync: bool = true
var shadows: int = 2
var draw_distance: int = 1
var fps_limit: int = 0
var render_scale: int = 3
var antialiasing: int = 0
var show_fps: bool = false

var _fps_label: Label
var _fps_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	_load()
	_build_fps_counter()
	apply()


func _process(delta: float) -> void:
	_fps_timer -= delta
	if _fps_label.visible and _fps_timer <= 0.0:
		_fps_timer = 0.25
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func set_volume(bus_name: String, value: float) -> void:
	volumes[bus_name] = clampf(value, 0.0, 1.0)
	_apply_volume(bus_name)
	_save()
	changed.emit()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	_save()
	changed.emit()


func set_vsync(on: bool) -> void:
	vsync = on
	_apply_window()
	_save()
	changed.emit()


## Opcion grafica por nombre de variable (shadows, draw_distance, fps_limit,
## render_scale, antialiasing, show_fps); la usa el menu de opciones.
func set_graphics(key: String, value: Variant) -> void:
	set(key, value)
	apply_graphics()
	_save()
	changed.emit()


## Distancia de dibujo de la camara del juego.
func view_distance() -> float:
	return DISTANCES[draw_distance]


func apply() -> void:
	for bus_name in volumes:
		_apply_volume(bus_name)
	_apply_window()
	apply_graphics()


## Aplica los graficos al viewport principal y al sol de la escena actual
## (la escena lo llama al arrancar, por si se cargo despues de las opciones).
func apply_graphics() -> void:
	_fps_label.visible = show_fps
	for sun in get_tree().get_nodes_in_group("sun"):
		sun.shadow_enabled = shadows > 0
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS[shadows], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(SHADOW_FILTER[shadows])
	Engine.max_fps = FPS_LIMITS[fps_limit]
	var root: Viewport = get_tree().root
	root.msaa_3d = MSAA[antialiasing]
	root.scaling_3d_scale = SCALES[render_scale]
	# FSR 1 reescala mejor que el bilineal cuando se dibuja a menos resolucion.
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if render_scale < SCALES.size() - 1 else Viewport.SCALING_3D_MODE_BILINEAR


func _apply_volume(bus_name: String) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var value: float = volumes[bus_name]
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var want_fullscreen: bool = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen != want_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for bus_name in volumes:
		volumes[bus_name] = float(config.get_value("volumen", bus_name, volumes[bus_name]))
	fullscreen = bool(config.get_value("pantalla", "completa", fullscreen))
	vsync = bool(config.get_value("pantalla", "vsync", vsync))
	shadows = clampi(int(config.get_value("graficos", "sombras", shadows)), 0, SHADOW_NAMES.size() - 1)
	draw_distance = clampi(int(config.get_value("graficos", "distancia", draw_distance)), 0, DISTANCES.size() - 1)
	fps_limit = clampi(int(config.get_value("graficos", "fps", fps_limit)), 0, FPS_LIMITS.size() - 1)
	render_scale = clampi(int(config.get_value("graficos", "resolucion", render_scale)), 0, SCALES.size() - 1)
	antialiasing = clampi(int(config.get_value("graficos", "antialiasing", antialiasing)), 0, MSAA.size() - 1)
	show_fps = bool(config.get_value("graficos", "mostrar_fps", show_fps))


func _save() -> void:
	var config := ConfigFile.new()
	for bus_name in volumes:
		config.set_value("volumen", bus_name, volumes[bus_name])
	config.set_value("pantalla", "completa", fullscreen)
	config.set_value("pantalla", "vsync", vsync)
	config.set_value("graficos", "sombras", shadows)
	config.set_value("graficos", "distancia", draw_distance)
	config.set_value("graficos", "fps", fps_limit)
	config.set_value("graficos", "resolucion", render_scale)
	config.set_value("graficos", "antialiasing", antialiasing)
	config.set_value("graficos", "mostrar_fps", show_fps)
	config.save(PATH)


# Contador chico arriba a la izquierda (a la derecha esta el minimapa),
# encima de todo y tambien en el titulo.
func _build_fps_counter() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.position = Vector2(8, 4)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.add_theme_font_size_override("font_size", 13)
	_fps_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.7))
	_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_fps_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_fps_label)
