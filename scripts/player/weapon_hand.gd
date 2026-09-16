extends Node3D

## Hace que el personaje empuñe el arma equipada.
## El mango se apoya en el hueso indicado (por nombre, ej: bone22);
## la hoja apunta siempre hacia arriba siguiendo al hueso animado en cada frame.

@export var bone_name: String = "bone22"    # nombre del hueso (mano/brazo)
@export var weapon_scale: float = 0.98     # tamano del arma respecto al modelo
@export var grip_offset: Vector3 = Vector3.ZERO
@export var grip_rotation_deg: Vector3 = Vector3.ZERO

var _skeleton: Skeleton3D
var _weapon_root: Node3D
var _grip_model: Vector3

var _bone_index: int = -1


func _ready() -> void:
	# Esperamos un frame para que el glb del personaje termine de instanciarse.
	await get_tree().process_frame
	var search_root: Node = get_parent()
	if search_root == null:
		search_root = self
	_skeleton = _find_skeleton(search_root)
	_bone_index = _find_bone_by_name(bone_name)
	inventory_data.equipment_changed.connect(_on_equipment_changed)
	set_process(true)
	_refresh()


func _process(_delta: float) -> void:
	if _weapon_root == null or _skeleton == null or _bone_index < 0:
		return
	var hand: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(_bone_index)

	# Hoja del arma: el modelo se extiende sobre su +X local.
	# Alineamos ese +X con la direccion hacia donde mira el personaje
	# (su +Z global, pues rotation.y = atan2(mov.x, mov.z) en player_1.gd),
	# proyectado en el plano horizontal, para que la espada apunte hacia
	# adelante y no cruce al personaje.
	var forward: Vector3 = get_parent().global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var z_axis: Vector3 = forward.cross(Vector3.UP).normalized()
	var y_axis: Vector3 = z_axis.cross(forward).normalized()
	var align: Basis = Basis(forward, y_axis, z_axis)
	var tune: Basis = Basis(Vector3(1, 0, 0), deg_to_rad(grip_rotation_deg.x)) \
			* Basis(Vector3(0, 1, 0), deg_to_rad(grip_rotation_deg.y)) \
			* Basis(Vector3(0, 0, 1), deg_to_rad(grip_rotation_deg.z))
	var scaled_rot: Basis = (align * tune).scaled(Vector3(weapon_scale, weapon_scale, weapon_scale))
	var pos: Vector3 = hand.origin + grip_offset - scaled_rot * _grip_model
	_weapon_root.global_transform = Transform3D(scaled_rot, pos)


func _on_equipment_changed(_equip_index: int) -> void:
	_refresh()


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		if child is Node3D:
			var found: Skeleton3D = _find_skeleton(child)
			if found:
				return found
	return null


func _find_bone_by_name(name_str: String) -> int:
	if _skeleton == null:
		return -1
	for i in _skeleton.get_bone_count():
		if _skeleton.get_bone_name(i) == name_str:
			return i
	return -1


func _refresh() -> void:
	_clear()
	var item: Itemdata = _equipped_weapon()
	if item == null or item.model_3d == null:
		return

	_weapon_root = item.model_3d.instantiate()
	add_child(_weapon_root)

	# Punto del mango en el modelo: extremo -x al centro en y/z.
	var aabb: AABB = _local_aabb(_weapon_root)
	_grip_model = Vector3(aabb.position.x, aabb.get_center().y, aabb.get_center().z)


func _equipped_weapon() -> Itemdata:
	for equip_index in [inventory_data.MELEE_EQUIP, inventory_data.SPECIAL_EQUIP]:
		var slot: Slotdata = inventory_data.equipment[equip_index]
		if slot and slot.item_data and slot.item_data.model_3d:
			return slot.item_data
	return null


func _clear() -> void:
	if _weapon_root and is_instance_valid(_weapon_root):
		_weapon_root.queue_free()
	_weapon_root = null


func _local_aabb(node: Node3D) -> AABB:
	var world_xf: Transform3D = node.global_transform
	var corners: Array[Vector3] = []
	_collect_local(node, world_xf, corners)
	if corners.is_empty():
		return AABB(Vector3.ZERO, Vector3.ZERO)
	var min_p: Vector3 = corners[0]
	var max_p: Vector3 = corners[0]
	for c in corners:
		min_p = min_p.min(c)
		max_p = max_p.max(c)
	return AABB(min_p, max_p - min_p)


func _collect_local(node: Node3D, world_xf: Transform3D, corners: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var local: AABB = (node as MeshInstance3D).get_aabb()
		var node_xf: Transform3D = (node as MeshInstance3D).global_transform
		var local_xf: Transform3D = world_xf.affine_inverse() * node_xf
		for i in 8:
			corners.append(local_xf * Vector3(
				local.position.x + (local.size.x if i & 1 else 0.0),
				local.position.y + (local.size.y if i & 2 else 0.0),
				local.position.z + (local.size.z if i & 4 else 0.0)))
	for child in node.get_children():
		if child is Node3D:
			_collect_local(child as Node3D, world_xf, corners)
