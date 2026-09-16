extends Area3D

@export var item_data: Itemdata

@onready var fallback_mesh: MeshInstance3D = $MeshInstance3D
@onready var model_holder: Node3D = $ModelHolder
@onready var sound: AudioStreamPlayer = $AudioStreamPlayer

var _bounds: AABB


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if item_data and item_data.model_3d:
		_setup_model_3d()


func _process(delta: float) -> void:
	if fallback_mesh.visible:
		fallback_mesh.rotate_y(delta * 2.0)
	if model_holder.visible:
		model_holder.rotate_y(delta * 2.0)


func _setup_model_3d() -> void:
	var model_root: Node3D = item_data.model_3d.instantiate()
	model_holder.add_child(model_root)

	# El modelo descansa sobre el suelo: lo aterrizamos en el origen del pickup
	# (sin el offset vertical de la esfera) y lo agrandamos para identificarlo.
	model_holder.position = Vector3.ZERO

	_bounds = AABB()
	_collect_bounds(model_root)
	var center: Vector3 = _bounds.get_center()
	var size: Vector3 = _bounds.size
	var max_dim: float = maxf(size.x, maxf(size.y, size.z))
	var target_dim: float = 230.0
	if max_dim > 0.0:
		model_holder.scale = Vector3.ONE * (target_dim / max_dim)

	var scaled_min: Vector3 = _bounds.position * model_holder.scale.x
	model_root.position = Vector3(-center.x * model_holder.scale.x, -scaled_min.y, -center.z * model_holder.scale.x)

	fallback_mesh.visible = false
	model_holder.visible = true


func _collect_bounds(node: Node3D) -> void:
	_bounds = AABB(node.global_transform.origin, Vector3.ONE * -1.0)
	_collect_bounds_in(node, node.global_transform)


func _collect_bounds_in(node: Node3D, world_xf: Transform3D) -> void:
	if node is MeshInstance3D:
		var mesh_bounds: AABB = (node as MeshInstance3D).get_aabb()
		var node_xf: Transform3D = (node as Node3D).global_transform
		var local_xf: Transform3D = world_xf.affine_inverse() * node_xf
		for i in 8:
			var corner: Vector3 = local_xf * Vector3(
				mesh_bounds.position.x + (mesh_bounds.size.x if i & 1 else 0.0),
				mesh_bounds.position.y + (mesh_bounds.size.y if i & 2 else 0.0),
				mesh_bounds.position.z + (mesh_bounds.size.z if i & 4 else 0.0))
			if _bounds.size.x < 0.0:
				_bounds = AABB(corner, Vector3.ZERO)
			else:
				_bounds = _bounds.expand(corner)
	for child in node.get_children():
		_collect_bounds_in(child as Node3D, world_xf)


func get_item() -> void:
	if item_data == null:
		return

	if not inventory_data.add_item(item_data, 1):
		print("Inventario lleno: no cabe ", item_data.name)
		return

	print("Recogiste: ", item_data.name, " | stacks en inventario: ", inventory_data.count_item(item_data))

	if sound and sound.stream:
		set_deferred("monitoring", false)
		fallback_mesh.visible = false
		model_holder.visible = false
		sound.play()
		await sound.finished
	queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		await get_item()
