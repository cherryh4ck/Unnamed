extends PanelContainer

var inventory
var slot_index: int = -1

@onready var texture_rect: TextureRect = $MarginContainer/Control/TextureRect
@onready var quantity_label: Label = $MarginContainer/Control/QuantityLabel


func setup(inv, index: int) -> void:
	inventory = inv
	slot_index = index
	inventory.inventory_changed.connect(update)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	update()


func update(changed_slot: int = -1) -> void:
	if changed_slot != -1 and changed_slot != slot_index:
		return

	var slot_data: Slotdata = inventory.slots[slot_index] if slot_index < inventory.slots.size() else null
	if slot_data and slot_data.item_data:
		texture_rect.texture = slot_data.item_data.texture
		texture_rect.visible = true
		if slot_data.quantity > 1:
			quantity_label.text = "x%d" % slot_data.quantity
			quantity_label.visible = true
		else:
			quantity_label.visible = false
	else:
		texture_rect.texture = null
		texture_rect.visible = false
		quantity_label.visible = false

	if slot_index == inventory.selected_slot:
		modulate = Color(1.35, 1.35, 0.85)
	else:
		modulate = Color.WHITE


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return

	match mouse_event.button_index:
		MOUSE_BUTTON_LEFT:
			var slot_data: Slotdata = inventory.slots[slot_index]
			if mouse_event.double_click and slot_data and slot_data.item_data:
				inventory.equip_from_slot(slot_index)
			else:
				inventory.on_slot_clicked(slot_index)
			accept_event()
		MOUSE_BUTTON_RIGHT:
			if inventory.slots[slot_index]:
				inventory.remove_slot(slot_index)
				accept_event()


func _on_mouse_entered() -> void:
	inventory.set_hovered(slot_index)


func _on_mouse_exited() -> void:
	if inventory.hovered_slot == slot_index:
		inventory.set_hovered(-1)
