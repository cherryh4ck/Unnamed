extends Node3D

## Proyectil de la Bola de Fuego. Vuela en linea recta a la altura del pecho
## y explota al tocar un enemigo o al llegar a su distancia maxima,
## dañando a todos los enemigos dentro del radio.

const SPEED: float = 1500.0
const HIT_RADIUS: float = 60.0

var direction: Vector3 = Vector3.FORWARD
## Habilidad que la lanzo (alcance, radio, multiplicador y tipo de daño).
var skill: SkillData
var color: Color = Color(1, 0.5, 0.12)

var _traveled: float = 0.0
var _exploded: bool = false


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.85, 0.5)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	var sphere := SphereMesh.new()
	sphere.radius = 45.0
	sphere.height = 90.0
	sphere.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = 500.0
	add_child(light)

	# Estela: las particulas quedan en el mundo (local_coords = false).
	var trail := CPUParticles3D.new()
	trail.local_coords = false
	trail.amount = 50
	trail.lifetime = 0.45
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 20.0
	trail.spread = 180.0
	trail.initial_velocity_min = 20.0
	trail.initial_velocity_max = 60.0
	trail.gravity = Vector3(0, 80.0, 0)
	trail.scale_amount_min = 1.0
	trail.scale_amount_max = 2.2
	var particle_mesh := QuadMesh.new()
	particle_mesh.size = Vector2(30, 30)
	var particle_material := StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	particle_material.vertex_color_use_as_albedo = true
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material.albedo_texture = Effects.soft_dot()
	particle_mesh.material = particle_material
	trail.mesh = particle_mesh
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.8, 0.3))
	ramp.set_color(1, Color(color, 0.0))
	trail.color_ramp = ramp
	add_child(trail)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	var step: float = SPEED * delta
	global_position += direction * step
	_traveled += step

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() <= HIT_RADIUS + enemy.data.collision_radius:
			_explode()
			return
	if _traveled >= skill.max_range:
		_explode()


func _explode() -> void:
	_exploded = true
	var ground := Vector3(global_position.x, global_position.y - 150.0, global_position.z)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() <= skill.radius:
			enemy.take_hit(player_stats.roll_hit(skill.damage_multiplier, skill.damage_type, skill.damage_conversion))
	sfx.play_at("hit", global_position, 2.0, 0.15)
	Effects.burst(get_parent(), global_position, color, 70, 80.0)
	Effects.ring(get_parent(), ground, color, skill.radius)
	queue_free()
