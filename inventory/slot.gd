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
	# Con texto no vacio Godot muestra el tooltip (lo arma _make_custom_tooltip).
	tooltip_text = " " if slot_data and slot_data.item_data else ""
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
	elif slot_data and slot_data.item_data and slot_data.item_data.rarity != Itemdata.Rarity.NORMAL:
		# Tinte suave del color de la rareza en el fondo del slot.
		modulate = Color.WHITE.lerp(slot_data.item_data.get_rarity_color(), 0.18)
	else:
		modulate = Color.WHITE


func _make_custom_tooltip(_for_text: String) -> Object:
	var slot_data: Slotdata = inventory.slots[slot_index]
	if slot_data == null or slot_data.item_data == null:
		return null
	var right_click: String = "tirar"
	if inventory.shop_mode:
		right_click = "vender (%d oro)" % (maxi(1, slot_data.item_data.value / 4) * slot_data.quantity)
	var hint: String = "Clic derecho: " + right_click
	if slot_data.item_data.is_equipment():
		hint = "Doble clic: equipar · Clic derecho: " + right_click
	elif slot_data.item_data.item_type == Itemdata.ItemType.POTION:
		hint = "Doble clic o Q: beber · Clic derecho: " + right_click
	return ItemTooltip.build(slot_data.item_data, slot_data.quantity, hint)


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return

	match mouse_event.button_index:
		MOUSE_BUTTON_LEFT:
			var slot_data: Slotdata = inventory.slots[slot_index]
			if mouse_event.double_click and slot_data and slot_data.item_data:
				if slot_data.item_data.item_type == Itemdata.ItemType.POTION:
					var player: Node = get_tree().get_first_node_in_group("player")
					if player:
						player.drink_potion()
				elif inventory.equip_from_slot(slot_index):
					sfx.play_item(slot_data.item_data)
			else:
				# Suena el item que se agarra (o el que se suelta en este slot).
				var moving: Slotdata = inventory.slots[inventory.selected_slot] if inventory.selected_slot >= 0 else slot_data
				if moving and moving.item_data:
					sfx.play_item(moving.item_data)
				inventory.on_slot_clicked(slot_index)
			accept_event()
		MOUSE_BUTTON_RIGHT:
			if inventory.slots[slot_index]:
				if inventory.shop_mode:
					inventory.sell_requested.emit(slot_index)
				else:
					inventory.drop_slot(slot_index)
				accept_event()


func _on_mouse_entered() -> void:
	inventory.set_hovered(slot_index)


func _on_mouse_exited() -> void:
	if inventory.hovered_slot == slot_index:
		inventory.set_hovered(-1)
