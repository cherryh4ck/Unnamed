class_name ItemEffects

## Efectos especiales de los items unicos (los dispara player_stats): rayo
## que salta a otro enemigo, espinas que devuelven el golpe y aura de fuego.
## Reciben el arbol de la escena en vez de usar autoloads.

## El rayo salta al enemigo mas cercano a esta distancia del golpeado, con
## esta parte del daño del golpe.
const CHAIN_RANGE: float = 650.0
const CHAIN_SHARE: float = 0.5
const CHAIN_COLOR := Color(0.55, 0.75, 1.0)
const THORNS_COLOR := Color(0.85, 0.75, 0.55)
const FIRE_COLOR := Color(1.0, 0.5, 0.15)


static func chain_lightning(tree: SceneTree, from: Node3D, damage: float) -> void:
	if not is_instance_valid(from) or damage <= 0.0:
		return
	var best: Node3D = null
	var best_dist: float = CHAIN_RANGE
	for enemy in tree.get_nodes_in_group("enemies"):
		if enemy == from or enemy.dead:
			continue
		var dist: float = enemy.global_position.distance_to(from.global_position)
		if dist < best_dist:
			best = enemy
			best_dist = dist
	if best == null:
		return
	_lightning(tree.current_scene, from.global_position + Vector3.UP * 200.0, best.global_position + Vector3.UP * 200.0)
	best.take_hit({"parts": {Damage.Type.MAGIC: damage}})


## Espinas: el enemigo que pego cuerpo a cuerpo recibe parte del golpe.
static func thorns(attacker: Node3D, damage: float) -> void:
	if not is_instance_valid(attacker) or attacker.dead or damage <= 0.0:
		return
	Effects.burst(attacker.get_parent(), attacker.global_position + Vector3.UP * 180.0, THORNS_COLOR, 14, 50.0)
	attacker.take_hit({"parts": {Damage.Type.PHYSICAL: damage}})


## Aura de fuego: quema a los enemigos alrededor del personaje.
static func fire_aura(tree: SceneTree, radius: float, damage: float) -> void:
	var player: Node3D = tree.get_first_node_in_group("player")
	if player == null or damage <= 0.0:
		return
	for enemy in tree.get_nodes_in_group("enemies"):
		if not enemy.dead and enemy.global_position.distance_to(player.global_position) <= radius + enemy.body_radius():
			enemy.take_hit({"parts": {Damage.Type.FIRE: damage}})


# Relampago entre dos puntos: tramos finos con un poco de zigzag que se
# apagan solos.
static func _lightning(parent: Node, from: Vector3, to: Vector3) -> void:
	if parent == null:
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = CHAIN_COLOR
	var points: Array[Vector3] = [from]
	var steps: int = 5
	for i in range(1, steps):
		var jitter := Vector3(randf_range(-40.0, 40.0), randf_range(-30.0, 30.0), randf_range(-40.0, 40.0))
		points.append(from.lerp(to, float(i) / steps) + jitter)
	points.append(to)
	var holder := Node3D.new()
	Effects.add_at(parent, holder, from)
	for i in points.size() - 1:
		var length: float = points[i].distance_to(points[i + 1])
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(14.0, 14.0, length)
		box.material = material
		piece.mesh = box
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(piece)
		piece.global_position = (points[i] + points[i + 1]) / 2.0
		piece.look_at(points[i + 1], Vector3.UP if absf((points[i + 1] - points[i]).normalized().y) < 0.95 else Vector3.RIGHT)
	Effects.burst(parent, to, CHAIN_COLOR, 18, 60.0)
	var tween := holder.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(holder.queue_free)
