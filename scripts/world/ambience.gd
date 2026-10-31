extends Node3D

## Ambiente del lugar donde anda el jugador:
## - Sonidos de fondo segun la zona y la hora: pajaros de dia (mas en el
##   bosque y las praderas), cuervos en el cementerio y viento en las ruinas.
##   Se funden de a poco al cambiar de zona o de hora; con lluvia los pajaros
##   se callan. La musica (music.gd), la lluvia (weather_fx.gd) y los grillos
##   de la noche (day_night.gd) van aparte.
## - Sonidos sueltos alrededor del jugador: buhos de noche y graznidos de
##   cuervo de dia, desde un costado al azar.
## - Luces de noche (night_light.gd): el renderizador Mobile ilumina cada
##   objeto con pocas luces a la vez y el piso es uno solo, asi que solo las
##   mas cercanas al jugador prenden su luz de verdad; las demas quedan con el
##   brillo y las llamas.

const BIRDS := "res://sounds/ambient/nature/birds_day.ogg"
const CROWS := "res://sounds/ambient/nature/crows.ogg"
const WIND := "res://sounds/ambient/weather/wind_loop.ogg"
const OWL := "res://sounds/ambient/nature/owl.ogg"
const CAW := "res://sounds/ambient/nature/crow_caw.ogg"

## Volumen (0 a 1) de cada sonido de fondo por zona (las de music.zone_at).
## Pajaros y cuervos suenan de dia; el viento siempre.
const LOOPS := {
	"aldea": {"birds": 0.45, "crows": 0.0, "wind": 0.0},
	"bosque": {"birds": 1.0, "crows": 0.0, "wind": 0.12},
	"pradera": {"birds": 0.75, "crows": 0.0, "wind": 0.2},
	"cementerio": {"birds": 0.0, "crows": 0.7, "wind": 0.3},
	"ruinas": {"birds": 0.12, "crows": 0.25, "wind": 0.65},
}
## Volumen maximo de cada sonido de fondo (dB, con el volumen 1).
const LOOP_DB := {"birds": -9.0, "crows": -12.0, "wind": -14.0}
## Sonidos sueltos: en que zonas, si de dia o de noche, y cada cuantos segundos.
const ONE_SHOTS := [
	{"path": OWL, "zones": ["bosque", "pradera", "cementerio", "aldea"], "night": true, "every": Vector2(14.0, 34.0), "db": -8.0},
	{"path": CAW, "zones": ["cementerio", "ruinas", "bosque"], "night": false, "every": Vector2(9.0, 24.0), "db": -10.0},
]
## Cuanto tarda un sonido de fondo en fundirse del todo (segundos).
const FADE_TIME: float = 4.0
## Distancia del jugador a la que suenan los sueltos.
const ONE_SHOT_DISTANCE := Vector2(900.0, 1700.0)

## Luces de noche con la luz prendida a la vez, y hasta donde cuentan.
const MAX_LIGHTS: int = 5
const LIGHT_RANGE: float = 3200.0
const CHECK_INTERVAL: float = 0.3

## Zona actual (para las pruebas y el depurado).
var zone: String = ""

var _loops: Dictionary = {}
var _levels: Dictionary = {}
var _timers: Array[float] = []
var _check: float = 0.0


func _ready() -> void:
	for key in ["birds", "crows", "wind"]:
		var path: String = {"birds": BIRDS, "crows": CROWS, "wind": WIND}[key]
		var player := AudioStreamPlayer.new()
		player.bus = &"Ambiente"
		player.volume_db = -80.0
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			player.stream = stream
		add_child(player)
		_loops[key] = player
		_levels[key] = 0.0
	for shot in ONE_SHOTS:
		_timers.append(randf_range(shot.every.x, shot.every.y) * 0.5)


func _process(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_check -= delta
	if _check <= 0.0:
		_check = CHECK_INTERVAL
		zone = music.zone_at(player.global_position)
		_limit_lights(player.global_position)
	_update_loops(delta)
	_update_one_shots(delta, player.global_position)


## Volumen que le toca a cada sonido de fondo ahora (0 a 1).
func target_levels() -> Dictionary:
	var levels: Dictionary = LOOPS.get(zone, LOOPS.pradera)
	var daylight: float = clampf(world_time.get_daylight() * 1.5, 0.0, 1.0)
	# Al amanecer cantan mas.
	var dawn: float = 1.0 + 0.3 * (smoothstep(5.5, 6.5, world_time.hour) - smoothstep(7.5, 9.0, world_time.hour))
	var quiet: float = 1.0 - weather.rain
	return {
		"birds": levels.birds * daylight * dawn * quiet,
		"crows": levels.crows * daylight * quiet,
		"wind": levels.wind,
	}


func _update_loops(delta: float) -> void:
	var targets: Dictionary = target_levels()
	for key in _loops:
		var player: AudioStreamPlayer = _loops[key]
		if player.stream == null:
			continue
		_levels[key] = move_toward(_levels[key], targets[key], delta / FADE_TIME)
		var level: float = _levels[key]
		if level < 0.01:
			if player.playing:
				player.stop()
			continue
		player.volume_db = linear_to_db(level) + LOOP_DB[key]
		if not player.playing:
			# Cada vez desde otro lugar del loop: no se nota la repeticion.
			player.play(randf() * player.stream.get_length())


func _update_one_shots(delta: float, around: Vector3) -> void:
	var night: bool = world_time.is_night()
	for i in ONE_SHOTS.size():
		_timers[i] -= delta
		if _timers[i] > 0.0:
			continue
		var shot: Dictionary = ONE_SHOTS[i]
		_timers[i] = randf_range(shot.every.x, shot.every.y)
		if shot.night != night or zone not in shot.zones or weather.rain > 0.4:
			continue
		play_one_shot(shot.path, around, shot.db)


## Un sonido suelto desde un costado al azar del punto (lo usan las pruebas).
func play_one_shot(path: String, around: Vector3, volume_db: float) -> AudioStreamPlayer3D:
	if not ResourceLoader.exists(path):
		return null
	var angle: float = randf() * TAU
	var distance: float = randf_range(ONE_SHOT_DISTANCE.x, ONE_SHOT_DISTANCE.y)
	var player := AudioStreamPlayer3D.new()
	player.bus = &"Ambiente"
	player.stream = load(path)
	player.volume_db = volume_db
	player.unit_size = sfx.UNIT_SIZE_3D
	player.max_distance = sfx.MAX_DISTANCE_3D
	player.pitch_scale = randf_range(0.92, 1.06)
	add_child(player)
	player.global_position = around + Vector3(cos(angle) * distance, 300.0, sin(angle) * distance)
	player.finished.connect(player.queue_free)
	player.play()
	return player


# Prende la luz de las MAX_LIGHTS luces de noche mas cercanas al jugador.
func _limit_lights(around: Vector3) -> void:
	var near: Array = []
	for light in get_tree().get_nodes_in_group("night_lights"):
		var distance: float = light.global_position.distance_to(around)
		if distance < LIGHT_RANGE and light.is_lit_hour():
			near.append([distance, light])
		else:
			light.allowed = false
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in near.size():
		near[i][1].allowed = i < MAX_LIGHTS
