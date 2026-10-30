extends PanelContainer

## Panel del herrero. Se abre junto con el inventario: el item se pone en el
## yunque, y con una gema agarrada se hace clic en una ranura vacia para
## engarzarla. Los botones abren una ranura nueva o sacan las gemas. Al
## cerrar, lo que quedo en el yunque vuelve al inventario.

const AnvilSlot := preload("res://ui/anvil_slot.gd")
const SOCKET_SIZE: float = 54.0
const EMPTY_COLOR := Color(0.75, 0.7, 0.6, 0.55)
const LOCKED_COLOR := Color(0.3, 0.28, 0.25, 0.9)

var smith: Node3D = null
var _sockets: HBoxContainer
var _open_button: Button
var _remove_button: Button
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
	title.text = "HERRERO"
	title.theme_type_variation = &"HeaderLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint := Label.new()
	hint.text = "Esc: cerrar"
	hint.theme_type_variation = &"DimLabel"
	header.add_child(title)
	header.add_child(hint)
	box.add_child(header)

	var info := Label.new()
	info.text = "Poné en el yunque un arma, un escudo o una ballesta."
	info.theme_type_variation = &"DimLabel"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)

	box.add_child(AnvilSlot.new())

	_sockets = HBoxContainer.new()
	_sockets.alignment = BoxContainer.ALIGNMENT_CENTER
	_sockets.add_theme_constant_override("separation", 10)
	box.add_child(_sockets)

	var socket_help := Label.new()
	socket_help.text = "Con una gema agarrada, clic en una ranura vacía para engarzarla."
	socket_help.theme_type_variation = &"DimLabel"
	socket_help.add_theme_font_size_override("font_size", 13)
	socket_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(socket_help)

	_open_button = Button.new()
	_open_button.pressed.connect(_on_open_socket)
	box.add_child(_open_button)
	_remove_button = Button.new()
	_remove_button.pressed.connect(_on_remove_gems)
	box.add_child(_remove_button)

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
	inventory_data.anvil_changed.connect(_refresh)
	inventory_data.held_changed.connect(_refresh)
	item_icons.icon_ready.connect(func(_key: String) -> void: _refresh())
	_connect_smiths.call_deferred()


func _connect_smiths() -> void:
	for npc in get_tree().get_nodes_in_group("blacksmiths"):
		if not npc.interacted.is_connected(open_for):
			npc.interacted.connect(open_for)


func _process(delta: float) -> void:
	# Si se cerro el inventario (tecla I), el herrero tambien se cierra.
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


func open_for(new_smith: Node3D) -> void:
	smith = new_smith
	visible = true
	inventory_data.anvil_changed.emit()
	sfx.play("page")
	var inventory: Control = get_tree().get_first_node_in_group("inventory_panel")
	if inventory and not inventory.visible:
		inventory.open_inventory()
	_update_pause()


func close() -> void:
	visible = false
	inventory_data.clear_anvil()
	sfx.play("page")
	var inventory: Control = get_tree().get_first_node_in_group("inventory_panel")
	if inventory and inventory.visible:
		inventory.close_inventory()
	_update_pause()


func _update_pause() -> void:
	get_tree().paused = get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel.visible)


func _refresh() -> void:
	if not visible:
		return
	var item: Itemdata = inventory_data.anvil.item_data if inventory_data.anvil else null
	_build_sockets(item)

	var max_sockets: int = Gems.max_sockets(item) if item else 0
	_open_button.visible = item != null and item.sockets < max_sockets
	if _open_button.visible:
		var price: int = Gems.socket_price(item)
		_open_button.text = "Abrir una ranura · %d oro" % price
		_open_button.disabled = player_stats.gold < price
	_remove_button.visible = item != null and not item.gems.is_empty()
	if _remove_button.visible:
		var price: int = Gems.remove_price(item)
		_remove_button.text = "Sacar las gemas · %d oro" % price
		_remove_button.disabled = player_stats.gold < price
	_gold_label.text = "%d de oro" % player_stats.gold


# Una casilla por ranura posible: con su gema, vacia o todavia cerrada.
func _build_sockets(item: Itemdata) -> void:
	for child in _sockets.get_children():
		child.queue_free()
	var shown: int = maxi(Gems.max_sockets(item), item.sockets) if item else 3
	for i in maxi(shown, 1):
		var socket := PanelContainer.new()
		socket.theme_type_variation = &"SlotPanel"
		socket.custom_minimum_size = Vector2(SOCKET_SIZE, SOCKET_SIZE)
		_sockets.add_child(socket)
		var open: bool = item != null and i < item.sockets
		if not open:
			socket.self_modulate = LOCKED_COLOR
			socket.tooltip_text = "Ranura cerrada" if item else ""
			continue
		if i < item.gems.size():
			var gem: Itemdata = Gems.from_id(item.gems[i])
			if gem:
				var icon := TextureRect.new()
				icon.texture = item_icons.get_icon(gem)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				socket.add_child(icon)
				var bonus: Array = Gems.bonus_of(gem.gem_kind, gem.gem_tier, item.has_damage())
				socket.tooltip_text = "%s: %s" % [gem.name, Itemdata.bonus_text(bonus[0], bonus[1])]
		else:
			socket.self_modulate = EMPTY_COLOR
			var held: Slotdata = inventory_data.held
			if held and held.item_data.item_type == Itemdata.ItemType.GEM:
				socket.tooltip_text = "Clic: engarzar · %d oro" % Gems.insert_price(held.item_data)
			else:
				socket.tooltip_text = "Ranura vacía"
			socket.gui_input.connect(_on_socket_input)


func _on_socket_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	var held: Slotdata = inventory_data.held
	if held == null or smith == null:
		return
	var error: String = smith.insert_gem(held)
	if error.is_empty():
		sfx.play("coins", -4.0)
		sfx.play("gem_socket")
	else:
		_show_error(error)


func _on_open_socket() -> void:
	if smith == null:
		return
	var error: String = smith.open_socket()
	if error.is_empty():
		sfx.play("coins", -4.0)
		sfx.play("anvil")
	else:
		_show_error(error)


func _on_remove_gems() -> void:
	if smith == null:
		return
	var error: String = smith.remove_gems()
	if error.is_empty():
		sfx.play("coins", -4.0)
		sfx.play("anvil", -3.0)
		sfx.play("gem_socket")
	else:
		_show_error(error)


func _show_error(text: String) -> void:
	_message.text = text
	_message_time = 2.0
	sfx.play("stuck")
