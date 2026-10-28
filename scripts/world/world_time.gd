extends Node

## Autoload con la hora del mundo. Un dia completo dura DAY_LENGTH segundos
## reales. La parte visual (sol, cielo) la maneja scripts/world/day_night.gd;
## los spawners preguntan is_night() para hacer mas fuertes a los enemigos.

signal night_started
signal day_started

## Segundos reales que dura un dia completo (24 horas del juego).
const DAY_LENGTH: float = 600.0
const DAWN_HOUR: float = 6.0
const DUSK_HOUR: float = 20.0

## Hora actual en [0, 24).
var hour: float = 9.0
var day: int = 1
var _was_night: bool = false


func _ready() -> void:
	_was_night = is_night()


func _process(delta: float) -> void:
	hour += delta * 24.0 / DAY_LENGTH
	if hour >= 24.0:
		hour -= 24.0
		day += 1
	var night: bool = is_night()
	if night != _was_night:
		_was_night = night
		if night:
			night_started.emit()
		else:
			day_started.emit()


func is_night() -> bool:
	return hour < DAWN_HOUR or hour >= DUSK_HOUR


## Hora con formato "HH:MM".
func get_clock_text() -> String:
	var minutes: int = int(hour * 60.0) % 60
	return "%02d:%02d" % [int(hour), minutes]


## Cuanta luz de sol hay (0 de noche, 1 al mediodia).
func get_daylight() -> float:
	if is_night():
		return 0.0
	var t: float = (hour - DAWN_HOUR) / (DUSK_HOUR - DAWN_HOUR)
	return clampf(sin(t * PI) * 2.5, 0.0, 1.0)


## Pone una hora puntual (para cargar partida o probar).
func set_time(new_hour: float, new_day: int = day) -> void:
	hour = fposmod(new_hour, 24.0)
	day = new_day
	_was_night = is_night()
