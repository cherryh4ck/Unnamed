extends Node

## Autoload con las opciones del jugador (volumen, pantalla). Se guardan
## aparte de la partida, en user://opciones.cfg, y se aplican al abrir.
## Los sonidos van por buses: "Efectos" (golpes, hechizos, interfaz, pasos),
## "Ambiente" (grillos, lluvia, viento) y "Musica"; todos pasan por "Master"
## (volumen general).

signal changed

const PATH := "user://opciones.cfg"
const BUSES := ["Efectos", "Ambiente", "Musica"]

## Volumen lineal de 0 a 1 por bus ("Master" = general).
var volumes: Dictionary = {"Master": 0.8, "Efectos": 1.0, "Ambiente": 0.8, "Musica": 0.6}
var fullscreen: bool = false
var vsync: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	_load()
	apply()


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


func apply() -> void:
	for bus_name in volumes:
		_apply_volume(bus_name)
	_apply_window()


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


func _save() -> void:
	var config := ConfigFile.new()
	for bus_name in volumes:
		config.set_value("volumen", bus_name, volumes[bus_name])
	config.set_value("pantalla", "completa", fullscreen)
	config.set_value("pantalla", "vsync", vsync)
	config.save(PATH)
