extends Node3D

## Virote de ballesta: vuela recto y daña al primer enemigo que toca.

const SPEED: float = 2600.0
const HIT_RADIUS: float = 40.0

var direction: Vector3 = Vector3.FORWARD
var max_range: float = 1700.0
var damage: float = 1.0
var crit: bool = false

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

	# El virote mira hacia donde vuela (+Z local).
	look_at(global_position - direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	var step: float = SPEED * delta
	global_position += direction * step
	_traveled += step
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() <= HIT_RADIUS + enemy.data.collision_radius:
			enemy.take_damage(damage, crit)
			sfx.play_at("hit", global_position, -2.0)
			queue_free()
			return
	if _traveled >= max_range:
		queue_free()
