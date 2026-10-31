class_name Effects

## Efectos visuales sueltos (particulas, destellos, marcas en el piso).
## Se crean por codigo con las texturas de fx/textures/ (Kenney Particle Pack,
## CC0) para no depender de escenas extra. Tamaños en unidades del mundo: el
## personaje mide ~400.

const FLAME := preload("res://fx/textures/flame_strip.png")
const FIRE := preload("res://fx/textures/fire_strip.png")
const SMOKE := preload("res://fx/textures/smoke_strip.png")
const SPARK := preload("res://fx/textures/spark_strip.png")
const MAGIC := preload("res://fx/textures/magic_strip.png")
const SOFT := preload("res://fx/textures/circle_05.png")
const GLOW := preload("res://fx/textures/light_01.png")
const FLARE := preload("res://fx/textures/flare_01.png")
const RING := preload("res://fx/textures/circle_02.png")
const SIGIL := preload("res://fx/textures/symbol_02.png")
const TWIRL := preload("res://fx/textures/twirl_02.png")
const SLASH := preload("res://fx/textures/slash_02.png")
const STAR := preload("res://fx/textures/star_04.png")
const SCORCHES := [preload("res://fx/textures/scorch_01.png"), preload("res://fx/textures/scorch_02.png")]
## Cuadros de las tiras animadas (flame_strip, smoke_strip, ...).
const STRIP_FRAMES: int = 4

static var _materials: Dictionary = {}
## Marcas de golpes en el piso que siguen a la vista (las mas viejas se borran).
static var _marks: Array[Node] = []
const MAX_MARKS: int = 40
## Color de la sangre segun EnemyData.Body (los huesos no sangran: polvo).
const BODY_COLORS := [Color(0.42, 0.02, 0.02), Color(0.86, 0.82, 0.7), Color(0.32, 0.55, 0.1), Color(0.16, 0.06, 0.04)]
static var _hit_stop_until: float = 0.0


## Agrega un nodo 3D al padre ya ubicado en la posicion global indicada.
## La posicion se pone ANTES de entrar al arbol: si se agrega primero y se mueve
## despues, las particulas del primer cuadro salen desde el origen del mundo
## (quedaban chispas sueltas en el centro del mapa).
static func add_at(parent: Node, node: Node3D, position: Vector3) -> void:
	var parent_3d := parent as Node3D
	node.position = parent_3d.global_transform.affine_inverse() * position if parent_3d else position
	parent.add_child(node)


# --- Efectos que usa el juego ---------------------------------------------

## Columna de estrellas doradas y un circulo en el piso al subir de nivel.
static func level_up(parent: Node, position: Vector3) -> void:
	var gold := Color(1.0, 0.82, 0.35)
	aura(parent, position, gold)
	var stars: CPUParticles3D = particles(STAR, true, 1, 40, 1.4, 60.0)
	stars.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	stars.emission_ring_axis = Vector3.UP
	stars.emission_ring_radius = 90.0
	stars.emission_ring_inner_radius = 0.0
	stars.emission_ring_height = 10.0
	stars.direction = Vector3.UP
	stars.spread = 8.0
	stars.initial_velocity_min = 300.0
	stars.initial_velocity_max = 520.0
	stars.gravity = Vector3.ZERO
	stars.damping_min = 120.0
	stars.damping_max = 180.0
	stars.color_ramp = ramp([Color(1, 1, 0.85), gold, Color(gold, 0.0)])
	emit_once(parent, stars, position + Vector3.UP * 30.0, 0.6)
	flash(parent, position + Vector3.UP * 250.0, gold, 1.6, 900.0, 0.8)


## Mejora o curacion: chispas magicas que suben en anillo y un sigilo que gira
## en el piso, del color indicado.
static func aura(parent: Node, position: Vector3, color: Color) -> void:
	var wisps: CPUParticles3D = particles(MAGIC, true, STRIP_FRAMES, 46, 1.3, 110.0)
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	wisps.emission_ring_axis = Vector3.UP
	wisps.emission_ring_radius = 150.0
	wisps.emission_ring_inner_radius = 110.0
	wisps.emission_ring_height = 10.0
	wisps.direction = Vector3.UP
	wisps.spread = 10.0
	wisps.initial_velocity_min = 160.0
	wisps.initial_velocity_max = 300.0
	wisps.gravity = Vector3(0, 60.0, 0)
	wisps.angle_min = -180.0
	wisps.angle_max = 180.0
	wisps.scale_amount_curve = curve([Vector2(0, 0.4), Vector2(0.3, 1.0), Vector2(1, 0.2)])
	wisps.color_ramp = ramp([Color(color.lightened(0.5), 0.0), color.lightened(0.3), Color(color, 0.0)])
	emit_once(parent, wisps, position + Vector3.UP * 20.0, 0.5)
	ground_glow(parent, position, SIGIL, color, 420.0, 1.2, 1.5)


## Explosion corta de chispas (impactos de habilidades).
static func burst(parent: Node, position: Vector3, color: Color, amount: int = 40, radius: float = 60.0) -> void:
	var sparks: CPUParticles3D = particles(SPARK, true, STRIP_FRAMES, amount, 0.55, 70.0)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = radius * 0.5
	sparks.spread = 180.0
	sparks.initial_velocity_min = 350.0
	sparks.initial_velocity_max = 800.0
	sparks.damping_min = 600.0
	sparks.damping_max = 900.0
	sparks.gravity = Vector3(0, -900.0, 0)
	sparks.angle_min = -180.0
	sparks.angle_max = 180.0
	sparks.scale_amount_curve = curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	sparks.color_ramp = ramp([Color(1, 1, 1), color.lightened(0.2), Color(color, 0.0)])
	emit_once(parent, sparks, position, 1.0)
	var core: CPUParticles3D = particles(FLARE, true, 1, 3, 0.18, 260.0)
	core.spread = 0.0
	core.initial_velocity_min = 0.0
	core.initial_velocity_max = 0.0
	core.gravity = Vector3.ZERO
	core.angle_max = 180.0
	core.color_ramp = ramp([Color(1, 1, 1), Color(color, 0.0)])
	emit_once(parent, core, position, 1.0)
	flash(parent, position, color, 1.2, 700.0, 0.25)


## Onda que se expande a ras del piso hasta el radio indicado (area de efecto),
## con polvo que se levanta en el borde.
static func ring(parent: Node, position: Vector3, color: Color, radius: float) -> void:
	shockwave(parent, position, color, radius, 0.4)
	var dust: CPUParticles3D = particles(SMOKE, false, STRIP_FRAMES, 30, 0.9, 170.0)
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	dust.emission_ring_axis = Vector3.UP
	dust.emission_ring_radius = radius * 0.85
	dust.emission_ring_inner_radius = radius * 0.6
	dust.emission_ring_height = 5.0
	dust.direction = Vector3.UP
	dust.spread = 40.0
	dust.initial_velocity_min = 60.0
	dust.initial_velocity_max = 140.0
	dust.gravity = Vector3(0, 40.0, 0)
	dust.angle_min = -180.0
	dust.angle_max = 180.0
	dust.scale_amount_curve = curve([Vector2(0, 0.5), Vector2(1, 1.4)])
	dust.color_ramp = ramp([Color(0.55, 0.5, 0.42, 0.0), Color(0.5, 0.45, 0.38, 0.45), Color(0.45, 0.4, 0.34, 0.0)])
	emit_once(parent, dust, position + Vector3.UP * 30.0, 0.9)


## Llamas sobre un personaje que se esta quemando. Queda como hijo del
## personaje y se prende o apaga con emitting.
static func burning(parent: Node3D, height: float, radius: float) -> CPUParticles3D:
	var flames: CPUParticles3D = particles(FLAME, true, STRIP_FRAMES, 30, 0.55, 120.0)
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = radius
	flames.direction = Vector3.UP
	flames.spread = 12.0
	flames.initial_velocity_min = 80.0
	flames.initial_velocity_max = 170.0
	flames.gravity = Vector3(0, 160.0, 0)
	flames.scale_amount_curve = curve([Vector2(0, 0.6), Vector2(0.25, 1.0), Vector2(1, 0.15)])
	flames.color_ramp = fire_ramp()
	add_at(parent, flames, parent.global_position + Vector3.UP * height)
	return flames


## Burbujas verdes que suben de un personaje envenenado. Igual que burning():
## queda como hijo y se prende o apaga con emitting.
static func poisoned(parent: Node3D, height: float, radius: float) -> CPUParticles3D:
	var bubbles: CPUParticles3D = particles(SOFT, true, 1, 14, 1.1, 34.0)
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = radius
	bubbles.direction = Vector3.UP
	bubbles.spread = 25.0
	bubbles.initial_velocity_min = 50.0
	bubbles.initial_velocity_max = 110.0
	bubbles.gravity = Vector3.ZERO
	bubbles.scale_amount_min = 0.6
	bubbles.scale_amount_max = 1.4
	var green: Color = Damage.COLORS[Damage.Type.POISON]
	bubbles.color_ramp = ramp([Color(green, 0.0), Color(green, 0.8), Color(green.darkened(0.4), 0.0)])
	add_at(parent, bubbles, parent.global_position + Vector3.UP * height)
	return bubbles


## Explosion de fuego: destello, bola de llamas, humo, brasas, onda en el
## piso y una quemadura que se borra de a poco.
static func fire_explosion(parent: Node, position: Vector3, radius: float) -> void:
	var ground := Vector3(position.x, 0.0, position.z)
	var fire: CPUParticles3D = particles(FIRE, true, STRIP_FRAMES, 34, 0.55, 220.0)
	fire.explosiveness = 0.95
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 50.0
	fire.spread = 180.0
	fire.initial_velocity_min = radius * 1.2
	fire.initial_velocity_max = radius * 2.4
	fire.damping_min = radius * 3.0
	fire.damping_max = radius * 4.5
	fire.gravity = Vector3(0, 250.0, 0)
	fire.angle_min = -180.0
	fire.angle_max = 180.0
	fire.scale_amount_min = 0.9
	fire.scale_amount_max = 1.6
	fire.scale_amount_curve = curve([Vector2(0, 0.5), Vector2(0.2, 1.0), Vector2(1, 0.3)])
	fire.color_ramp = fire_ramp()
	emit_once(parent, fire, position, 1.0)

	var smoke: CPUParticles3D = particles(SMOKE, false, STRIP_FRAMES, 16, 1.6, 260.0)
	smoke.explosiveness = 0.8
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 70.0
	smoke.spread = 180.0
	smoke.initial_velocity_min = radius * 0.4
	smoke.initial_velocity_max = radius * 0.9
	smoke.damping_min = radius * 0.6
	smoke.damping_max = radius * 0.9
	smoke.gravity = Vector3(0, 120.0, 0)
	smoke.angle_min = -180.0
	smoke.angle_max = 180.0
	smoke.scale_amount_curve = curve([Vector2(0, 0.5), Vector2(1, 1.6)])
	smoke.color_ramp = ramp([Color(0.2, 0.17, 0.15, 0.0), Color(0.16, 0.14, 0.13, 0.55), Color(0.12, 0.11, 0.1, 0.0)])
	emit_once(parent, smoke, position + Vector3.UP * 30.0, 0.8)

	var embers: CPUParticles3D = particles(SPARK, true, STRIP_FRAMES, 40, 1.0, 40.0)
	embers.explosiveness = 0.95
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 40.0
	embers.spread = 180.0
	embers.initial_velocity_min = 500.0
	embers.initial_velocity_max = 1100.0
	embers.damping_min = 300.0
	embers.damping_max = 500.0
	embers.gravity = Vector3(0, -1300.0, 0)
	embers.scale_amount_curve = curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	embers.color_ramp = ramp([Color(1, 0.95, 0.7), Color(1, 0.55, 0.15), Color(0.8, 0.2, 0.05, 0.0)])
	emit_once(parent, embers, position, 1.0)

	flash(parent, position + Vector3.UP * 80.0, Color(1.0, 0.6, 0.25), 2.6, radius * 3.0, 0.45)
	shockwave(parent, ground, Color(1.0, 0.5, 0.18, 0.6), radius, 0.35)
	scorch(parent, ground, radius * 0.75)


## Golpe fuerte: destello, chispas y una grieta oscura en el piso.
static func heavy_impact(parent: Node, position: Vector3, color: Color) -> void:
	burst(parent, position + Vector3.UP * 200.0, color, 45, 60.0)
	shockwave(parent, Vector3(position.x, 0.0, position.z), color, 260.0, 0.3)
	scorch(parent, Vector3(position.x, 0.0, position.z), 140.0, Color(0.05, 0.04, 0.03, 0.7), 3.0)


## Nube de polvo a ras del piso (montar, caer, frenar).
static func dust_puff(parent: Node, position: Vector3, radius: float) -> void:
	var dust: CPUParticles3D = particles(SMOKE, false, STRIP_FRAMES, 18, 1.0, 180.0)
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	dust.emission_ring_axis = Vector3.UP
	dust.emission_ring_radius = radius
	dust.emission_ring_inner_radius = radius * 0.3
	dust.emission_ring_height = 5.0
	dust.direction = Vector3.UP
	dust.spread = 60.0
	dust.initial_velocity_min = 60.0
	dust.initial_velocity_max = 150.0
	dust.gravity = Vector3(0, 30.0, 0)
	dust.angle_min = -180.0
	dust.angle_max = 180.0
	dust.scale_amount_curve = curve([Vector2(0, 0.5), Vector2(1, 1.3)])
	dust.color_ramp = ramp([Color(0.6, 0.52, 0.4, 0.0), Color(0.55, 0.48, 0.38, 0.5), Color(0.5, 0.44, 0.35, 0.0)])
	emit_once(parent, dust, position, 0.9)


## Corte en circulo alrededor del personaje (Torbellino).
static func whirl(parent: Node3D, color: Color, radius: float) -> void:
	for i in 2:
		var mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(radius * 2.0, radius * 2.0)
		plane.material = _flat_material(SLASH if i == 0 else TWIRL, color, true)
		mesh.mesh = plane
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_at(parent, mesh, parent.global_position + Vector3.UP * (180.0 + i * 40.0))
		mesh.rotation.y = randf() * TAU
		var tween := mesh.create_tween().set_parallel(true)
		tween.tween_property(mesh, "rotation:y", mesh.rotation.y - TAU * (1.3 + i * 0.4), 0.38)
		tween.tween_property(plane.material, "albedo_color:a", 0.0, 0.38).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(mesh.queue_free)


# --- Piezas ----------------------------------------------------------------

## Luz que se prende fuerte y se apaga sola. Sin caida por distancia (el
## mundo esta en unidades grandes, ~225 por metro, y con caida no llegaba a
## iluminar nada): se apaga suave hasta light_range, asi que energy va baja.
static func flash(parent: Node, position: Vector3, color: Color, energy: float, light_range: float, duration: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 0.0
	add_at(parent, light, position)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(light.queue_free)


## Anillo plano en el piso que se agranda hasta radius y se desvanece.
static func shockwave(parent: Node, position: Vector3, color: Color, radius: float, duration: float) -> void:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	plane.material = _flat_material(RING, color, true)
	mesh.mesh = plane
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.scale = Vector3.ONE * radius * 0.15
	add_at(parent, mesh, position + Vector3.UP * 12.0)
	var tween := mesh.create_tween().set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3.ONE * radius * 1.1, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(plane.material, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mesh.queue_free)


## Textura que brilla en el piso (sigilo, circulo), gira un poco y se apaga.
static func ground_glow(parent: Node, position: Vector3, texture: Texture2D, color: Color, size: float, duration: float, turns: float = 0.0) -> void:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.material = _flat_material(texture, color, true)
	mesh.mesh = plane
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Se desvanece con el alfa del material: GeometryInstance3D.transparency
	# no hace nada con el renderizador Mobile.
	var alpha: float = color.a
	plane.material.albedo_color.a = 0.0
	add_at(parent, mesh, position + Vector3.UP * 10.0)
	var tween := mesh.create_tween()
	tween.tween_property(plane.material, "albedo_color:a", alpha, duration * 0.2)
	tween.tween_property(plane.material, "albedo_color:a", 0.0, duration * 0.8).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mesh, "rotation:y", TAU * turns, duration * 0.8)
	tween.tween_callback(mesh.queue_free)


## Mancha de quemado en el piso (Decal) que se borra despues de un rato.
static func scorch(parent: Node, position: Vector3, radius: float, color: Color = Color(0.03, 0.02, 0.02, 0.85), duration: float = 6.0) -> void:
	var decal := Decal.new()
	decal.texture_albedo = SCORCHES.pick_random()
	decal.size = Vector3(radius * 2.0, 160.0, radius * 2.0)
	decal.modulate = color
	decal.upper_fade = 0.0
	decal.lower_fade = 0.0
	add_at(parent, decal, position + Vector3.UP * 40.0)
	decal.rotation.y = randf() * TAU
	var tween := decal.create_tween()
	tween.tween_interval(duration * 0.6)
	tween.tween_property(decal, "modulate:a", 0.0, duration * 0.4)
	tween.tween_callback(decal.queue_free)


## Pausa de impacto: el tiempo casi se frena un instante (golpes criticos).
static func hit_stop(node: Node, duration: float = 0.06) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _hit_stop_until:
		return
	_hit_stop_until = now + duration
	var timer: SceneTreeTimer = node.get_tree().create_timer(duration, true, false, true)
	Engine.time_scale = 0.08
	await timer.timeout
	Engine.time_scale = 1.0


## Golpe en un cuerpo: gotas (o astillas de hueso) que saltan y, si no es un
## esqueleto, una mancha en el piso que se borra despues de un rato.
## big = al morir (mas gotas y un charco).
static func body_hit(parent: Node, position: Vector3, body: int, size: float, big: bool = false) -> void:
	var color: Color = BODY_COLORS[body]
	var bone: bool = body == EnemyData.Body.BONE
	var drops: CPUParticles3D = particles(SOFT, false, 1, 28 if big else 12, 0.55, 30.0 if bone else 24.0)
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	drops.emission_sphere_radius = size * 0.3
	drops.direction = Vector3.UP
	drops.spread = 70.0
	drops.initial_velocity_min = 250.0
	drops.initial_velocity_max = 650.0
	drops.gravity = Vector3(0, -2400.0, 0)
	drops.scale_amount_curve = curve([Vector2(0, 1.0), Vector2(1, 0.4)])
	drops.color_ramp = ramp([Color(color, 1.0), Color(color, 0.9), Color(color, 0.0)])
	emit_once(parent, drops, position, 1.0)
	var ground := Vector3(position.x, 0.0, position.z)
	if bone:
		# Polvo de hueso en vez de sangre.
		var dust: CPUParticles3D = particles(SMOKE, false, STRIP_FRAMES, 8 if big else 4, 0.8, 120.0)
		dust.spread = 180.0
		dust.initial_velocity_min = 20.0
		dust.initial_velocity_max = 80.0
		dust.gravity = Vector3(0, 30.0, 0)
		dust.color_ramp = ramp([Color(0.8, 0.76, 0.66, 0.0), Color(0.78, 0.74, 0.64, 0.4), Color(0.7, 0.66, 0.58, 0.0)])
		emit_once(parent, dust, position, 0.9)
		return
	var radius: float = size * (1.6 if big else 0.8) * randf_range(0.8, 1.2)
	var mark := Decal.new()
	mark.texture_albedo = SCORCHES.pick_random()
	mark.size = Vector3(radius * 2.0, 160.0, radius * 2.0)
	mark.modulate = Color(color, 0.85)
	mark.upper_fade = 0.0
	mark.lower_fade = 0.0
	add_at(parent, mark, ground + Vector3.UP * 40.0 + Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5)) * size)
	mark.rotation.y = randf() * TAU
	var tween := mark.create_tween()
	tween.tween_interval(10.0)
	tween.tween_property(mark, "modulate:a", 0.0, 4.0)
	tween.tween_callback(mark.queue_free)
	_marks.append(mark)
	while _marks.size() > MAX_MARKS:
		var old: Node = _marks.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	_marks = _marks.filter(func(node: Node) -> bool: return is_instance_valid(node))


## Particulas de un solo disparo que se borran solas al terminar.
static func emit_once(parent: Node, system: CPUParticles3D, position: Vector3, explosiveness: float = 0.85) -> void:
	system.one_shot = true
	system.explosiveness = explosiveness
	add_at(parent, system, position)
	system.emitting = true
	system.finished.connect(system.queue_free)


## Sistema de particulas con billboards texturados. frames > 1 = tira animada
## (cada particula toma un cuadro al azar). additive = brilla (fuego, magia);
## si no, se mezcla (humo, polvo).
static func particles(texture: Texture2D, additive: bool, frames: int, amount: int, lifetime: float, size: float) -> CPUParticles3D:
	var system := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = particle_material(texture, additive, frames)
	system.mesh = quad
	system.amount = amount
	system.lifetime = lifetime
	system.local_coords = false
	if frames > 1:
		system.anim_offset_max = 1.0
	return system


static func particle_material(texture: Texture2D, additive: bool, frames: int = 1) -> StandardMaterial3D:
	var key: String = "p|%s|%s|%d" % [texture.resource_path, additive, frames]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if frames > 1:
		material.particles_anim_h_frames = frames
		material.particles_anim_v_frames = 1
		material.particles_anim_loop = false
	_materials[key] = material
	return material


# Material de un plano en el piso (no billboard). Uno por efecto: la
# transparencia se anima en el nodo, el color va en el material.
static func _flat_material(texture: Texture2D, color: Color, additive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = texture
	material.albedo_color = color
	return material


static func fire_ramp() -> Gradient:
	return ramp([Color(1.0, 0.95, 0.75, 0.0), Color(1.0, 0.8, 0.35), Color(1.0, 0.42, 0.08), Color(0.6, 0.12, 0.03, 0.0)])


## Degradado con los colores repartidos parejo.
static func ramp(colors: Array) -> Gradient:
	var offsets := PackedFloat32Array()
	var packed := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / float(colors.size() - 1))
		packed.append(colors[i])
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = packed
	return gradient


## Curva por puntos (x de 0 a 1). Los valores pueden pasar de 1.
static func curve(points: Array) -> Curve:
	var result := Curve.new()
	for point in points:
		result.max_value = maxf(result.max_value, point.y)
	for point in points:
		result.add_point(point)
	return result
