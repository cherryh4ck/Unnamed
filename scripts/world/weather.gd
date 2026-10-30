extends Node

## Autoload con el clima: despejado, nublado, lluvia, tormenta o niebla. Cada
## tanto (en horas del juego) cambia a otro estado al azar y los valores
## (overcast, rain, fog) van de a poco hacia los del estado nuevo, asi la
## lluvia empieza y termina suave. Lo visual y el sonido estan en
## scripts/world/weather_fx.gd; el cielo y el sol los oscurece day_night.gd.

signal changed(state: int)

enum State { CLEAR, CLOUDY, RAIN, STORM, FOG }

const STATE_NAMES := ["Despejado", "Nublado", "Lluvia", "Tormenta", "Niebla"]
## Valores de cada estado: [nubes, lluvia, niebla], de 0 a 1.
const TARGETS := [
	[0.0, 0.0, 0.0],
	[0.55, 0.0, 0.1],
	[0.8, 0.6, 0.25],
	[1.0, 1.0, 0.35],
	[0.45, 0.0, 1.0],
]
## Probabilidad relativa de cada estado al cambiar.
const WEIGHTS := [5.0, 3.0, 2.0, 0.8, 1.2]
## Cuanto dura un estado, en horas del juego.
const MIN_HOURS: float = 2.0
const MAX_HOURS: float = 6.0
## Velocidad de la transicion (por segundo real).
const BLEND_SPEED: float = 0.04

var state: int = State.CLEAR
var overcast: float = 0.0
var rain: float = 0.0
var fog: float = 0.0
## Horas del juego que faltan para el proximo cambio.
var hours_left: float = 4.0
var _last_hour: float = -1.0


func _process(delta: float) -> void:
	var hour: float = world_time.hour
	# Los saltos de hora (cargar partida, dormir) no gastan el clima actual.
	var passed: float = fposmod(hour - _last_hour, 24.0)
	if _last_hour >= 0.0 and passed < 0.5:
		hours_left -= passed
	_last_hour = hour
	if hours_left <= 0.0:
		set_state(_roll_state())

	var target: Array = TARGETS[state]
	var step: float = BLEND_SPEED * delta
	overcast = move_toward(overcast, target[0], step)
	rain = move_toward(rain, target[1], step)
	fog = move_toward(fog, target[2], step)


## Cambia el estado (los valores llegan de a poco). instant = sin transicion.
func set_state(new_state: int, instant: bool = false) -> void:
	state = clampi(new_state, 0, State.size() - 1)
	hours_left = randf_range(MIN_HOURS, MAX_HOURS)
	if instant:
		var target: Array = TARGETS[state]
		overcast = target[0]
		rain = target[1]
		fog = target[2]
	changed.emit(state)


func get_state_name() -> String:
	return STATE_NAMES[state]


## Partida nueva: arranca despejado.
func reset() -> void:
	set_state(State.CLEAR, true)
	hours_left = randf_range(MIN_HOURS, MAX_HOURS)


func to_save() -> Dictionary:
	return {"state": state, "hours_left": hours_left}


func from_save(data: Dictionary) -> void:
	set_state(int(data.get("state", State.CLEAR)), true)
	hours_left = float(data.get("hours_left", hours_left))


func _roll_state() -> int:
	# Que no repita el mismo estado dos veces seguidas.
	var total: float = 0.0
	for i in WEIGHTS.size():
		if i != state:
			total += WEIGHTS[i]
	var roll: float = randf() * total
	for i in WEIGHTS.size():
		if i == state:
			continue
		roll -= WEIGHTS[i]
		if roll <= 0.0:
			return i
	return State.CLEAR
