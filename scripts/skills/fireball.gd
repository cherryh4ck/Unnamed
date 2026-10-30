extends Node3D

## Proyectil de la Bola de Fuego. Vuela en linea recta a la altura del pecho
## y explota al tocar un enemigo o al llegar a su distancia maxima, dañando a
## todos los enemigos dentro del radio. Se ve como un nucleo brillante con
## llamas que giran, una estela de fuego, humo y brasas, y una luz que titila.
## Al explotar la estela no desaparece de golpe: deja de emitir y se apaga.

const HIT_RADIUS: float = 60.0
## Tiempo que queda el nodo despues de explotar para que la estela se apague.
const LINGER: float = 1.2

var direction: Vector3 = Vector3.FORWARD
var speed: float = 1500.0
## Distancia que recorre antes de explotar (0 = la de la habilidad).
var travel: float = 0.0
## Habilidad que la lanzo (alcance, radio, multiplicador y tipo de daño).
var skill: SkillData
var color: Color = Color(1, 0.5, 0.12)

var _traveled: float = 0.0
var _exploded: bool = false
var _time: float = 0.0
var _core: Array[CPUParticles3D] = []
var _trails: Array[CPUParticles3D] = []
var _light: OmniLight3D


func _ready() -> void:
	# Nucleo: brillo y llamas en coordenadas locales (viajan con la bola).
	var glow: CPUParticles3D = Effects.particles(Effects.GLOW, true, 1, 3, 0.2, 190.0)
	glow.local_coords = true
	_still(glow)
	glow.color_ramp = Effects.ramp([Color(1.0, 0.7, 0.35, 0.75), Color(1.0, 0.45, 0.12, 0.35)])
	_core.append(glow)

	var flames: CPUParticles3D = Effects.particles(Effects.FLAME, true, Effects.STRIP_FRAMES, 26, 0.28, 150.0)
	flames.local_coords = true
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 22.0
	flames.spread = 180.0
	flames.initial_velocity_min = 30.0
	flames.initial_velocity_max = 90.0
	flames.gravity = Vector3.ZERO
	flames.angle_min = -180.0
	flames.angle_max = 180.0
	flames.angular_velocity_min = -240.0
	flames.angular_velocity_max = 240.0
	flames.scale_amount_curve = Effects.curve([Vector2(0, 0.6), Vector2(0.3, 1.0), Vector2(1, 0.3)])
	flames.color_ramp = Effects.fire_ramp()
	_core.append(flames)

	# Estela en el mundo (local_coords = false): queda atras al avanzar.
	var trail: CPUParticles3D = Effects.particles(Effects.FIRE, true, Effects.STRIP_FRAMES, 70, 0.42, 140.0)
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 28.0
	trail.direction = -direction
	trail.spread = 18.0
	trail.initial_velocity_min = 80.0
	trail.initial_velocity_max = 220.0
	trail.gravity = Vector3(0, 180.0, 0)
	trail.angle_min = -180.0
	trail.angle_max = 180.0
	trail.scale_amount_curve = Effects.curve([Vector2(0, 1.0), Vector2(1, 0.15)])
	trail.color_ramp = Effects.fire_ramp()
	_trails.append(trail)

	var smoke: CPUParticles3D = Effects.particles(Effects.SMOKE, false, Effects.STRIP_FRAMES, 28, 1.1, 150.0)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 30.0
	smoke.direction = Vector3.UP
	smoke.spread = 40.0
	smoke.initial_velocity_min = 30.0
	smoke.initial_velocity_max = 80.0
	smoke.gravity = Vector3(0, 60.0, 0)
	smoke.angle_min = -180.0
	smoke.angle_max = 180.0
	smoke.scale_amount_curve = Effects.curve([Vector2(0, 0.4), Vector2(1, 1.5)])
	smoke.color_ramp = Effects.ramp([Color(0.3, 0.26, 0.22, 0.0), Color(0.3, 0.26, 0.22, 0.0), Color(0.26, 0.23, 0.2, 0.22), Color(0.2, 0.18, 0.16, 0.0)])
	_trails.append(smoke)

	var embers: CPUParticles3D = Effects.particles(Effects.SPARK, true, Effects.STRIP_FRAMES, 24, 0.7, 34.0)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 30.0
	embers.spread = 180.0
	embers.initial_velocity_min = 60.0
	embers.initial_velocity_max = 200.0
	embers.gravity = Vector3(0, -700.0, 0)
	embers.color_ramp = Effects.ramp([Color(1, 0.9, 0.6), Color(1, 0.5, 0.12), Color(0.7, 0.15, 0.03, 0.0)])
	_trails.append(embers)

	for system in _core + _trails:
		add_child(system)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.25)
	_light.light_energy = 5.0
	_light.omni_range = 700.0
	_light.omni_attenuation = 1.3
	add_child(_light)


# Particula que nace quieta en el centro (para los brillos del nucleo).
func _still(system: CPUParticles3D) -> void:
	system.spread = 0.0
	system.initial_velocity_min = 0.0
	system.initial_velocity_max = 0.0
	system.gravity = Vector3.ZERO
	system.angle_min = -180.0
	system.angle_max = 180.0


func _process(delta: float) -> void:
	_time += delta
	if not _exploded:
		# Titila como fuego de verdad.
		_light.light_energy = 4.5 + sin(_time * 31.0) * 0.6 + sin(_time * 17.0) * 0.5


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	var step: float = speed * delta
	global_position += direction * step
	_traveled += step

	# Con travel fijo (el meteoro que cae) no explota en el aire al pasar
	# sobre un enemigo: llega al piso.
	if travel <= 0.0:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var offset: Vector3 = enemy.global_position - global_position
			offset.y = 0.0
			if offset.length() <= HIT_RADIUS + enemy.data.collision_radius:
				_explode()
				return
	if _traveled >= (travel if travel > 0.0 else skill.max_range):
		_explode()


func _explode() -> void:
	_exploded = true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() <= skill.radius:
			enemy.take_hit(player_stats.roll_skill(skill))
	sfx.play_at("hit", global_position, 2.0, 0.15)
	Effects.fire_explosion(get_parent(), global_position, skill.radius)

	# El nucleo desaparece; la estela deja de salir y se apaga sola.
	for system in _core:
		system.visible = false
		system.emitting = false
	for system in _trails:
		system.emitting = false
	_light.visible = false
	get_tree().create_timer(LINGER, false).timeout.connect(queue_free)
