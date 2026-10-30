class_name Effects

## Efectos visuales sueltos (particulas de un solo disparo).
## Se crean por codigo para no depender de escenas extra.


## Chispas doradas que suben alrededor del personaje al subir de nivel.
static func level_up(parent: Node, position: Vector3) -> void:
	aura(parent, position, Color(1.0, 0.82, 0.3))


## Chispas que suben en anillo alrededor de un personaje (mejoras, nivel).
static func aura(parent: Node, position: Vector3, color: Color) -> void:
	var particles: CPUParticles3D = _burst(color, 70, 1.6)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particles.emission_ring_axis = Vector3.UP
	particles.emission_ring_radius = 130.0
	particles.emission_ring_inner_radius = 100.0
	particles.emission_ring_height = 10.0
	particles.direction = Vector3.UP
	particles.spread = 12.0
	particles.initial_velocity_min = 220.0
	particles.initial_velocity_max = 420.0
	particles.gravity = Vector3(0, -120.0, 0)
	_spawn(parent, particles, position + Vector3.UP * 20.0)


## Explosion corta de chispas (impactos de habilidades).
static func burst(parent: Node, position: Vector3, color: Color, amount: int = 40, radius: float = 60.0) -> void:
	var particles: CPUParticles3D = _burst(color, amount, 0.7)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 200.0
	particles.initial_velocity_max = 500.0
	particles.gravity = Vector3(0, -600.0, 0)
	_spawn(parent, particles, position)


## Onda que se expande a ras del piso hasta el radio indicado (area de efecto).
static func ring(parent: Node, position: Vector3, color: Color, radius: float) -> void:
	var particles: CPUParticles3D = _burst(color, 90, 0.45)
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particles.emission_ring_axis = Vector3.UP
	particles.emission_ring_radius = 30.0
	particles.emission_ring_inner_radius = 0.0
	particles.emission_ring_height = 5.0
	particles.direction = Vector3.RIGHT
	particles.spread = 180.0
	particles.flatness = 1.0
	particles.initial_velocity_min = radius / 0.45
	particles.initial_velocity_max = radius / 0.45
	particles.damping_min = 0.0
	particles.damping_max = 0.0
	particles.gravity = Vector3.ZERO
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 2.5
	_spawn(parent, particles, position + Vector3.UP * 40.0)


static func _burst(color: Color, amount: int, lifetime: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.amount = amount
	particles.lifetime = lifetime

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = soft_dot()
	var quad := QuadMesh.new()
	quad.size = Vector2(26, 26)
	quad.material = material
	particles.mesh = quad

	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	particles.color_ramp = ramp
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	return particles


# Punto redondo con borde difuso (para que las particulas no sean cuadrados).
static func soft_dot() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 32
	texture.height = 32
	return texture


## Agrega un nodo 3D al padre ya ubicado en la posicion global indicada.
## La posicion se pone ANTES de entrar al arbol: si se agrega primero y se mueve
## despues, las particulas del primer cuadro salen desde el origen del mundo
## (quedaban chispas sueltas en el centro del mapa).
static func add_at(parent: Node, node: Node3D, position: Vector3) -> void:
	var parent_3d := parent as Node3D
	node.position = parent_3d.global_transform.affine_inverse() * position if parent_3d else position
	parent.add_child(node)


static func _spawn(parent: Node, particles: CPUParticles3D, position: Vector3) -> void:
	add_at(parent, particles, position)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
