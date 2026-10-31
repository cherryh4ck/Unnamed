extends Node3D

## Virote de ballesta: vuela recto y daña al primer enemigo que toca. Con
## glow es un virote con magia (o el rayo arcano del mago): brilla con ese
## color y deja una estela. harmless = solo se ve (la lluvia de virotes hace el
## daño aparte). hits_player = la tiro un enemigo (los bandidos arqueros): daña
## al jugador y no a los enemigos.

const HIT_RADIUS: float = 40.0
## Ancho del jugador para las flechas enemigas.
const PLAYER_RADIUS: float = 60.0

var direction: Vector3 = Vector3.FORWARD
var speed: float = 2600.0
var max_range: float = 1700.0
## Golpe que lleva: {parts, crit} (ver player_stats.roll_hit).
var hit: Dictionary = {}
var glow: Color = Color.TRANSPARENT
var harmless: bool = false
var hits_player: bool = false

var _traveled: float = 0.0


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.32, 0.18)
	var shaft := BoxMesh.new()
	shaft.size = Vector3(10.0, 10.0, 130.0)
	shaft.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = shaft
	add_child(mesh)

	var tip_material := StandardMaterial3D.new()
	tip_material.albedo_color = Color(0.75, 0.75, 0.8)
	tip_material.metallic = 0.8
	var tip := BoxMesh.new()
	tip.size = Vector3(18.0, 18.0, 20.0)
	tip.material = tip_material
	var tip_mesh := MeshInstance3D.new()
	tip_mesh.mesh = tip
	tip_mesh.position.z = 74.0
	add_child(tip_mesh)

	if glow.a > 0.0:
		var light := StandardMaterial3D.new()
		light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		light.albedo_color = glow.lightened(0.3)
		light.emission_enabled = true
		light.emission = glow
		light.emission_energy_multiplier = 3.0
		material.albedo_color = glow.darkened(0.2)
		tip.material = light
		var trail: CPUParticles3D = Effects.particles(Effects.GLOW, true, 1, 18, 0.35, 70.0)
		trail.color_ramp = Effects.ramp([Color(glow, 0.8), Color(glow, 0.0)])
		trail.gravity = Vector3.ZERO
		trail.position.z = 40.0
		add_child(trail)

	# El virote mira hacia donde vuela (+Z local). Cayendo derecho, look_at
	# necesita otro "arriba".
	var up: Vector3 = Vector3.UP if absf(direction.y) < 0.95 else Vector3.FORWARD
	look_at(global_position - direction, up)


func _physics_process(delta: float) -> void:
	var step: float = speed * delta
	global_position += direction * step
	_traveled += step
	if not harmless:
		var target: Node3D = _touching()
		if target:
			if hits_player:
				target.take_hit(hit.parts)
			else:
				target.take_hit(hit)
				sfx.play_at("hit", global_position, -2.0)
			queue_free()
			return
	if _traveled >= max_range:
		queue_free()


# El primero al que esta tocando: un enemigo, o el jugador si la tiro un enemigo.
func _touching() -> Node3D:
	if hits_player and player_stats.dead:
		return null
	for target in get_tree().get_nodes_in_group("player" if hits_player else "enemies"):
		var radius: float = PLAYER_RADIUS if hits_player else target.body_radius()
		var offset: Vector3 = target.global_position - global_position
		offset.y = 0.0
		if offset.length() <= HIT_RADIUS + radius:
			return target
	return null
