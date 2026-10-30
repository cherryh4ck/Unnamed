extends PanelContainer

## Tienda del comerciante. Se abre junto con el inventario: clic en un item
## de la tienda lo compra, clic derecho en el inventario vende.

const ShopSlot := preload("res://ui/shop_slot.gd")

var merchant: Node3D = null
var _grid: GridContainer
var _gold_label: Label
var _message: Label
var _message_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_panels")
	set_anchors_preset(Control.PRESET_CENTER_LEFT)
	offset_left = 20.0
	offset_right = 360.0
	offset_top = -270.0
	offset_bottom = 250.0
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "COMERCIANTE"
	title.theme_type_variation = &"HeaderLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint := Label.new()
	hint.text = "Esc: cerrar"
	hint.theme_type_variation = &"DimLabel"
	header.add_child(title)
	header.add_child(hint)
	box.add_child(header)

	var info := Label.new()
	info.text = "Clic en un item para comprarlo.\nClic derecho en tu inventario para vender."
	info.theme_type_variation = &"DimLabel"
	box.add_child(info)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	_message = Label.new()
	_message.add_theme_color_override("font_color", Color(0.95, 0.35, 0.3))
	box.add_child(_message)

	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_gold_label.add_theme_font_size_override("font_size", 18)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_gold_label)

	player_stats.gold_changed.connect(func(_amount: int) -> void: _refresh())
	inventory_data.sell_requested.connect(_on_sell_requested)
	_connect_merchants.call_deferred()


func _connect_merchants() -> void:
	for npc in get_tree().get_nodes_in_group("merchants"):
		if not npc.interacted.is_connected(open_for):
			npc.interacted.connect(open_for)


func _process(delta: float) -> void:
	# Si se cerro el inventario (tecla I), la tienda tambien se cierra.
	if visible:
		var inventory: Control = get_tree().get_first_node_in_group("inventory_panel")
		if inventory and not inventory.visible:
			close()
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open_for(new_merchant: Node3D) -> void:
	merchant = new_merchant
	visible = true
	inventory_data.shop_mode = true
	_refresh()
	sfx.play("page")
	var inventory: Control = get_tree().get_first_node_in_group("inventory_panel")
	if inventory and not inventory.visible:
		inventory.open_inventory()
	_update_pause()


func close() -> void:
	visible = false
	inventory_data.shop_mode = false
	sfx.play("page")
	var inventory: Control = get_tree().get_first_node_in_group("inventory_panel")
	if inventory and inventory.visible:
		inventory.close_inventory()
	_update_pause()


func _update_pause() -> void:
	get_tree().paused = get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel.visible)


func _refresh() -> void:
	if not visible or merchant == null:
		return
	for child in _grid.get_children():
		child.queue_free()
	for i in merchant.stock.size():
		var entry: Dictionary = merchant.stock[i]
		var price: int = merchant.buy_price(entry.item)
		var slot := ShopSlot.new()
		_grid.add_child(slot)
		slot.setup(i, entry.item, entry.quantity, price, player_stats.gold >= price)
		slot.pressed.connect(_on_buy)
	_gold_label.text = "%d de oro" % player_stats.gold


func _on_buy(index: int) -> void:
	var item: Itemdata = merchant.stock[index].item
	var error: String = merchant.buy(index)
	if error.is_empty():
		sfx.play("pickup_gold")
		sfx.play_item(item)
	else:
		_show_error(error)
	_refresh()


func _on_sell_requested(slot_index: int) -> void:
	if merchant == null:
		return
	var gained: int = merchant.sell(slot_index)
	if gained > 0:
		sfx.play("pickup_gold")
	_refresh()


func _show_error(text: String) -> void:
	_message.text = text
	_message_time = 2.0
	sfx.play("stuck")
