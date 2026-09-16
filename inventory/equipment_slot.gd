extends PanelContainer

var equip_index: int = -1

@onready var type_label: Label = $MarginContainer/Control/TypeLabel
@onready var texture_rect: TextureRect = $MarginContainer/Control/TextureRect

var _type_name: String = ""


func setup(index: int) -> void:
	equip_index = index
	_type_name = "MELEE" if index == inventory_data.MELEE_EQUIP else "ESPECIAL"
	type_label.text = _type_name
	inventory_data.equipment_changed.connect(update)
	update()


func update(_equip_index: int = -1) -> void:
	if _equip_index != -1 and _equip_index != equip_index:
		return
	var equip_slot: Slotdata = inventory_data.equipment[equip_index] \
			if equip_index >= 0 and equip_index < inventory_data.equipment.size() else null
	if equip_slot and equip_slot.item_data:
		texture_rect.texture = equip_slot.item_data.texture
		texture_rect.visible = true
		type_label.visible = false
	else:
		texture_rect.texture = null
		texture_rect.visible = false
		type_label.visible = true


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		inventory_data.on_equipment_clicked(equip_index)
		accept_event()
