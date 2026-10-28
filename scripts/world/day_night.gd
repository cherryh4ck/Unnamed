extends Node

## Parte visual del ciclo dia/noche: mueve el sol (de noche una luna azulada),
## cambia los colores del cielo y el volumen del ambiente segun world_time.

@export var sun_path: NodePath
@export var environment_path: NodePath
## Sonido de ambiente nocturno (grillos): sube de noche y baja de dia.
@export var ambience_path: NodePath

const SUN_MAX_ELEVATION: float = 65.0
const MOON_ELEVATION: float = 45.0

const DAY_SKY_TOP := Color(0.38, 0.55, 0.78)
const DAY_SKY_HORIZON := Color(0.68, 0.72, 0.78)
const DUSK_SKY_TOP := Color(0.32, 0.27, 0.42)
const DUSK_SKY_HORIZON := Color(0.95, 0.55, 0.3)
const NIGHT_SKY_TOP := Color(0.02, 0.03, 0.08)
const NIGHT_SKY_HORIZON := Color(0.06, 0.08, 0.16)

const SUN_COLOR := Color(1.0, 0.96, 0.88)
const DUSK_SUN_COLOR := Color(1.0, 0.62, 0.35)
const MOON_COLOR := Color(0.55, 0.65, 1.0)

@onready var sun: DirectionalLight3D = get_node_or_null(sun_path)
@onready var world_environment: WorldEnvironment = get_node_or_null(environment_path)
@onready var ambience: AudioStreamPlayer = get_node_or_null(ambience_path)

var _sky: ProceduralSkyMaterial


func _ready() -> void:
	if world_environment and world_environment.environment and world_environment.environment.sky:
		_sky = world_environment.environment.sky.sky_material as ProceduralSkyMaterial
	_apply()


func _process(_delta: float) -> void:
	_apply()


func _apply() -> void:
	var daylight: float = world_time.get_daylight()
	# Cerca del horizonte (amanecer/atardecer) los colores tiran a naranja.
	var dusk: float = clampf(1.0 - daylight * 1.6, 0.0, 1.0) if not world_time.is_night() else 0.0

	if sun:
		if world_time.is_night():
			var night_t: float = fposmod(world_time.hour - world_time.DUSK_HOUR, 24.0) / (24.0 - world_time.DUSK_HOUR + world_time.DAWN_HOUR)
			sun.rotation_degrees = Vector3(-MOON_ELEVATION * maxf(sin(night_t * PI), 0.2), night_t * 180.0 - 90.0, 0.0)
			sun.light_color = MOON_COLOR
			sun.light_energy = 0.25
		else:
			var day_t: float = (world_time.hour - world_time.DAWN_HOUR) / (world_time.DUSK_HOUR - world_time.DAWN_HOUR)
			var elevation: float = maxf(sin(day_t * PI) * SUN_MAX_ELEVATION, 5.0)
			sun.rotation_degrees = Vector3(-elevation, day_t * 180.0 - 90.0, 0.0)
			sun.light_color = SUN_COLOR.lerp(DUSK_SUN_COLOR, dusk)
			sun.light_energy = lerpf(0.3, 0.7, daylight)

	if _sky:
		var top: Color = NIGHT_SKY_TOP.lerp(DAY_SKY_TOP, daylight)
		var horizon: Color = NIGHT_SKY_HORIZON.lerp(DAY_SKY_HORIZON, daylight)
		_sky.sky_top_color = top.lerp(DUSK_SKY_TOP, dusk * 0.6)
		_sky.sky_horizon_color = horizon.lerp(DUSK_SKY_HORIZON, dusk * 0.7)
		_sky.ground_horizon_color = _sky.sky_horizon_color
	if world_environment and world_environment.environment:
		world_environment.environment.ambient_light_energy = lerpf(0.35, 0.7, daylight)

	if ambience:
		ambience.volume_db = lerpf(-8.0, -22.0, daylight)
