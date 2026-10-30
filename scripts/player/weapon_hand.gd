extends Node3D

## Muestra lo equipado en el modelo del jugador: el arma (o la ballesta, que
## es con lo que se ataca) en la mano derecha y el escudo en el brazo
## izquierdo. Los personajes de 0 A.D. traen huesos para eso; los modelos de
## las armas (item/models/) estan hechos para ir pegados a esos huesos tal cual.

const HAND_BONE := "prop-weapon_R"
const SHIELD_BONE := "prop-shield"

var _hand: BoneAttachment3D
var _shield: BoneAttachment3D


func _ready() -> void:
	# El modelo lo arma player_1.gd en su _ready (que corre despues de este).
	await get_tree().process_frame
	var skeleton: Skeleton3D = get_parent().find_child("Skeleton3D", true, false)
	if skeleton == null:
		return
	_hand = _attachment(skeleton, HAND_BONE)
	_shield = _attachment(skeleton, SHIELD_BONE)
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


func _show(attachment: BoneAttachment3D, item: Itemdata) -> void:
	for child in attachment.get_children():
		child.queue_free()
	if item and item.model_3d:
		attachment.add_child(item.model_3d.instantiate())
