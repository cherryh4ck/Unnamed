extends Node3D

## Lo que se ve y se escucha del clima (autoload weather): lluvia que sigue al
## jugador, niebla en el Environment, relampagos con trueno en las tormentas,
## y los sonidos de lluvia y viento. El cielo y el sol los oscurece
## day_night.gd con weather.overcast.

@export var environment_path: NodePath

const RAIN_SOUND := "res://sounds/ambient/weather/rain_light.ogg"
const HEAVY_RAIN_SOUND := "res://sounds/ambient/weather/rain_heavy.ogg"
const WIND_SOUND := "res://sounds/ambient/weather/wind_loop.ogg"
const THUNDER_SOUNDS := [
	"res://sounds/ambient/weather/thunder1.ogg",
	"res://sounds/ambient/weather/thunder2.ogg",
	"res://sounds/ambient/weather/thunder3.ogg",
	"res://sounds/ambient/weather/thunder4.ogg",
]
## Altura sobre el jugador desde donde cae la lluvia y lado del area.
const RAIN_HEIGHT: float = 1500.0
const RAIN_AREA: float = 2600.0
const RAIN_AMOUNT: int = 3500
## Niebla mas densa (en el mundo se mide en unidades grandes: ~400 = una persona).
const MAX_FOG_DENSITY: float = 0.00026
const FOG_COLOR := Color(0.62, 0.66, 0.7)

@onready var world_environment: WorldEnvironment = get_node_or_null(environment_path)

var _rain: GPUParticles3D
var _rain_player: AudioStreamPlayer
var _heavy_rain_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer
var _flash: DirectionalLight3D
var _thunder: Array[AudioStream] = []
var _next_lightning: float = 8.0


func _ready() -> void:
	_rain = _make_rain()
	add_child(_rain)
	_rain_player = _loop_player(RAIN_SOUND)
	_heavy_rain_player = _loop_player(HEAVY_RAIN_SOUND)
	_wind_player = _loop_player(WIND_SOUND)
	for path in THUNDER_SOUNDS:
		if ResourceLoader.exists(path):
			_thunder.append(load(path))
	# Luz del relampago: apagada salvo durante el destello.
	_flash = DirectionalLight3D.new()
	_flash.rotation_degrees = Vector3(-70.0, 30.0, 0.0)
	_flash.light_color = Color(0.8, 0.85, 1.0)
	_flash.light_energy = 0.0
	_flash.visible = false
	add_child(_flash)


func _process(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		_rain.global_position = player.global_position + Vector3.UP * RAIN_HEIGHT
	_rain.amount_ratio = weather.rain
	_rain.emitting = weather.rain > 0.01

	if world_environment and world_environment.environment:
		var environment: Environment = world_environment.environment
		var density: float = MAX_FOG_DENSITY * (weather.fog + weather.rain * 0.25)
		environment.fog_enabled = density > 0.000005
		environment.fog_density = density
		var light: float = lerpf(0.25, 1.0, world_time.get_daylight())
		environment.fog_light_color = FOG_COLOR * light
		environment.fog_sky_affect = 0.5

	# Llovizna con la lluvia suave; en la tormenta entra la fuerte.
	var heavy: float = clampf((weather.rain - 0.5) * 2.0, 0.0, 1.0)
	_set_loop_volume(_rain_player, weather.rain * (1.0 - heavy * 0.7))
	_set_loop_volume(_heavy_rain_player, weather.rain * heavy)
	_set_loop_volume(_wind_player, maxf(weather.fog * 0.6, weather.rain * weather.overcast * 0.8))

	if weather.state == weather.State.STORM and weather.rain > 0.7:
		_next_lightning -= delta
		if _next_lightning <= 0.0:
			_next_lightning = randf_range(7.0, 18.0)
			_lightning()


func _make_rain() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = RAIN_AMOUNT
	particles.lifetime = 0.7
	particles.preprocess = 0.7
	particles.visibility_aabb = AABB(Vector3(-RAIN_AREA, -RAIN_HEIGHT - 200.0, -RAIN_AREA), Vector3(RAIN_AREA * 2.0, RAIN_HEIGHT + 400.0, RAIN_AREA * 2.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(RAIN_AREA, 40.0, RAIN_AREA)
	process.direction = Vector3(0.12, -1.0, 0.06)
	process.spread = 2.0
	process.initial_velocity_min = 2300.0
	process.initial_velocity_max = 2700.0
	process.gravity = Vector3.ZERO
	process.particle_flag_align_y = true
	particles.process_material = process

	var drop := QuadMesh.new()
	drop.size = Vector2(3.5, 150.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.78, 0.84, 0.92, 0.32)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.billboard_keep_scale = true
	material.disable_receive_shadows = true
	drop.material = material
	particles.draw_pass_1 = drop
	return particles


func _loop_player(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"Ambiente"
	player.volume_db = -80.0
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		player.stream = stream
	add_child(player)
	return player


func _set_loop_volume(player: AudioStreamPlayer, amount: float) -> void:
	if player.stream == null:
		return
	if amount < 0.02:
		if player.playing:
			player.stop()
		return
	player.volume_db = linear_to_db(amount) - 4.0
	if not player.playing:
		player.play()


# Destello doble y, segun la distancia (al azar), el trueno un rato despues.
func _lightning() -> void:
	_flash.visible = true
	var tween := create_tween()
	tween.tween_property(_flash, "light_energy", 2.2, 0.05)
	tween.tween_property(_flash, "light_energy", 0.3, 0.08)
	tween.tween_property(_flash, "light_energy", 1.6, 0.05)
	tween.tween_property(_flash, "light_energy", 0.0, 0.35)
	tween.tween_callback(func() -> void: _flash.visible = false)
	if _thunder.is_empty():
		return
	await get_tree().create_timer(randf_range(0.3, 2.0), false).timeout
	var player := AudioStreamPlayer.new()
	player.bus = &"Ambiente"
	player.stream = _thunder.pick_random()
	player.volume_db = randf_range(-6.0, 0.0)
	player.pitch_scale = randf_range(0.85, 1.05)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
