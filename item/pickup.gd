extends Area3D

## Item tirado en el piso. El oro y las pociones se juntan al pasar por encima;
## el equipo se junta haciendo clic (el personaje camina hasta el item).

## Capa de fisica de los items en el piso (para que el clic los encuentre
## sin chocar con otras areas como las zonas de spawn).
const PICKUP_LAYER: int = 4
const SPRITE_PIXEL_SIZE: float = 4.5

@export var item_data: Itemdata
@export var quantity: int = 1

@onready var fallback_mesh: MeshInstance3D = $MeshInstance3D
@onready var model_holder: Node3D = $ModelHolder
@onready var name_label: Label3D = $NameLabel

var auto_pickup: bool = true
## Si el jugador tiro el item, no se vuelve a juntar solo hasta que se aleje.
var _suspended: bool = false
var _bounds: AABB
var _sprite: Sprite3D
var _picked: bool = false
var _bob_time: float = 0.0


func _ready() -> void:
	# Los items del mapa que ya se juntaron no vuelven al cargar la partida.
	if save_game.is_collected(self):
		queue_free()
		return
	add_to_group("pickups")
	collision_layer = PICKUP_LAYER
	body_entered.connect(_on_body_entered)
	if item_data == null:
		return
	auto_pickup = not item_data.is_equipment()
	if item_data.model_3d:
		_setup_model_3d()
	elif item_data.texture:
		_setup_sprite()
	_setup_label()
	_bob_time = randf() * TAU


func _process(delta: float) -> void:
	if fallback_mesh.visible:
		fallback_mesh.rotate_y(delta * 2.0)
	if model_holder.visible:
		model_holder.rotate_y(delta * 2.0)
	if _sprite:
		_bob_time += delta * 3.0
		_sprite.position.y = 110.0 + sin(_bob_time) * 12.0


func suspend_auto_pickup() -> void:
	_suspended = true
	body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			_suspended = false)


## Animacion de "salto" desde donde murio el enemigo hasta su lugar en el piso.
func pop_from(start: Vector3) -> void:
	var target: Vector3 = global_position
	global_position = start
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:x", target.x, 0.45)
	tween.tween_property(self, "global_position:z", target.z, 0.45)
	var up := create_tween()
	up.tween_property(self, "global_position:y", target.y + 160.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	up.tween_property(self, "global_position:y", target.y, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _setup_sprite() -> void:
	_sprite = Sprite3D.new()
	_sprite.texture = item_data.texture
	_sprite.pixel_size = SPRITE_PIXEL_SIZE
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.position.y = 110.0
	add_child(_sprite)
	fallback_mesh.visible = false


func _setup_label() -> void:
	var text: String = item_data.get_display_name()
	if item_data.item_type == Itemdata.ItemType.GOLD:
		text = "%d de oro" % quantity
	elif quantity > 1:
		text = "%s x%d" % [text, quantity]
	name_label.text = text
	name_label.modulate = item_data.get_rarity_color()
	if item_data.item_type == Itemdata.ItemType.GOLD:
		name_label.modulate = Color(1.0, 0.85, 0.35)


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


## Intenta guardar el item. Devuelve true si se junto.
func get_item() -> bool:
	if item_data == null or _picked:
		return false
	var head: Vector3 = global_position + Vector3.UP * 250.0

	if item_data.item_type == Itemdata.ItemType.GOLD:
		_picked = true
		save_game.mark_collected(self)
		player_stats.add_gold(quantity)
		floating_text.spawn(head, "+%d oro" % quantity, Color(1.0, 0.85, 0.35), 18)
		sfx.play("pickup_gold")
		queue_free()
		return true

	if not inventory_data.add_item(item_data, quantity):
		floating_text.spawn(head, "Inventario lleno", Color(1.0, 0.35, 0.3), 18)
		sfx.play("stuck")
		return false

	_picked = true
	save_game.mark_collected(self)
	floating_text.spawn(head, item_data.get_display_name(), item_data.get_rarity_color(), 18)
	sfx.play(_pickup_sound())
	queue_free()
	return true


func _pickup_sound() -> String:
	match item_data.item_type:
		Itemdata.ItemType.GOLD:
			return "pickup_gold"
		Itemdata.ItemType.POTION:
			return "pickup_potion"
		Itemdata.ItemType.GEM:
			return "pickup_magic"
	if item_data.rarity != Itemdata.Rarity.NORMAL:
		return "pickup_magic"
	return "drag_weapon"


func _on_body_entered(body: Node3D) -> void:
	# Solo el jugador junta items (los enemigos tambien son CharacterBody3D).
	if auto_pickup and not _suspended and body.is_in_group("player"):
		get_item()
