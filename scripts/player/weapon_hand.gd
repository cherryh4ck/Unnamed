extends Node3D

## Muestra lo equipado en el modelo del jugador: el arma (o la ballesta, que
## es con lo que se ataca) en la mano derecha, el escudo en el brazo
## izquierdo, el casco en la cabeza y el peto como textura del cuerpo. Los
## personajes de 0 A.D. traen huesos para eso; los modelos de las armas
## (item/models/) y de los cascos (assets/characters/oad/props/) estan hechos
## para ir pegados a esos huesos tal cual. Sin casco se ve el tocado de tela
## de la clase (pañuelo o capucha; el casco de metal del guerrero no, asi se
## nota cuando se pone uno) y sin peto, su ropa.
## Tambien prende las llamas del aura de fuego de los unicos.

const HAND_BONE := "prop-weapon_R"
const SHIELD_BONE := "prop-shield"
const HELMET_BONE := "prop-helmet"
## Llamitas en el piso alrededor del personaje mientras tiene aura de fuego.
const AURA_RADIUS: float = 260.0

var _hand: BoneAttachment3D
var _shield: BoneAttachment3D
var _helmet: BoneAttachment3D
## Lo que el modelo de la clase trae en la cabeza (se esconde con un casco).
var _class_headgear: Array[Node3D] = []
var _body: MeshInstance3D
var _body_material: Material
var _aura: CPUParticles3D


func _ready() -> void:
	# El modelo lo arma player_1.gd en su _ready (que corre despues de este).
	await get_tree().process_frame
	var skeleton: Skeleton3D = get_parent().find_child("Skeleton3D", true, false)
	if skeleton == null:
		return
	_hand = _attachment(skeleton, HAND_BONE)
	_shield = _attachment(skeleton, SHIELD_BONE)
	_helmet = _attachment(skeleton, HELMET_BONE)
	for child in skeleton.get_children():
		if child is BoneAttachment3D and child.bone_name == HELMET_BONE and child != _helmet:
			_class_headgear.append(child)
	_body = skeleton.get_node_or_null("Body") as MeshInstance3D
	if _body:
		_body_material = _body.get_active_material(0)
	inventory_data.equipment_changed.connect(_on_equipment_changed)
	_refresh()


func _attachment(skeleton: Skeleton3D, bone: String) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = "Equipo_" + bone
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	return attachment


func _on_equipment_changed(_equip_index: int) -> void:
	_refresh()


func _refresh() -> void:
	var melee: Itemdata = inventory_data.get_equipped(inventory_data.MELEE_EQUIP)
	var special: Itemdata = inventory_data.get_equipped(inventory_data.SPECIAL_EQUIP)
	var in_hand: Itemdata = special if special and special.is_ranged() else melee
	var on_arm: Itemdata = special if special and not special.is_ranged() else null
	_show(_hand, in_hand)
	_show(_shield, on_arm)

	var helmet: Itemdata = inventory_data.get_equipped(inventory_data.HELMET_EQUIP)
	var has_helmet: bool = helmet != null and helmet.model_3d != null
	_show(_helmet, helmet if has_helmet else null)
	for headgear in _class_headgear:
		for mesh in headgear.get_children():
			mesh.visible = not has_helmet and mesh.name != "Helmet"

	if _body:
		var chest: Itemdata = inventory_data.get_equipped(inventory_data.CHEST_EQUIP)
		_body.set_surface_override_material(0, _armor_material(chest.body_texture) if chest and chest.body_texture else null)
	_refresh_aura()


func _show(attachment: BoneAttachment3D, item: Itemdata) -> void:
	for child in attachment.get_children():
		child.queue_free()
	if item and item.model_3d:
		attachment.add_child(item.model_3d.instantiate())


# El material del cuerpo de la clase con la textura de la armadura (el mismo
# mapa UV sirve para todos los cuerpos de 0 A.D.).
func _armor_material(texture: Texture2D) -> Material:
	var material: Material = _body_material.duplicate() if _body_material else StandardMaterial3D.new()
	if material is StandardMaterial3D:
		(material as StandardMaterial3D).albedo_texture = texture
	return material


func _refresh_aura() -> void:
	var burning: bool = player_stats.get_special("aura_fuego") > 0.0
	if burning and _aura == null:
		_aura = Effects.particles(Effects.FLAME, true, Effects.STRIP_FRAMES, 18, 0.7, 70.0)
		_aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		_aura.emission_ring_axis = Vector3.UP
		_aura.emission_ring_radius = AURA_RADIUS
		_aura.emission_ring_inner_radius = AURA_RADIUS * 0.8
		_aura.emission_ring_height = 0.0
		_aura.direction = Vector3.UP
		_aura.spread = 10.0
		_aura.initial_velocity_min = 40.0
		_aura.initial_velocity_max = 90.0
		_aura.gravity = Vector3(0.0, 60.0, 0.0)
		_aura.scale_amount_curve = Effects.curve([Vector2(0, 0.5), Vector2(0.3, 1.0), Vector2(1, 0.1)])
		_aura.color_ramp = Effects.fire_ramp()
		_aura.position.y = 20.0
		# Sigue al personaje pero las llamas quedan donde salieron.
		get_parent().get_parent().add_child(_aura)
	if _aura:
		_aura.emitting = burning
