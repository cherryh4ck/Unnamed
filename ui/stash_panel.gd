extends PanelContainer

## Panel del baul de la aldea. Se abre junto con el inventario: los items se
## pasan agarrandolos y soltandolos en la otra grilla, o con clic derecho.
## Lo guardado aca queda en la partida aunque se vacie la mochila.

const InventoryGrid := preload("res://inventory/inventory_grid.gd")

var stash: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_panels")

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "BAÚL"
	title.theme_type_variation = &"HeaderLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint := Label.new()
	hint.text = "Esc: cerrar"
	hint.theme_type_variation = &"DimLabel"
	header.add_child(title)
	header.add_child(hint)
	box.add_child(header)

	var grid := InventoryGrid.new()
	grid.grid = inventory_data.stash
	box.add_child(grid)

	var help := Label.new()
	help.text = "Agarrá y soltá entre el baúl y el inventario · Clic derecho: pasar al otro lado"
	help.theme_type_variation = &"DimLabel"
	help.add_theme_font_size_override("font_size", 12)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = grid.custom_minimum_size.x
	box.add_child(help)

	set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_connect_stashes.call_deferred()


func _connect_stashes() -> void:
	for node in get_tree().get_nodes_in_group("stashes"):
		if not node.interacted.is_connected(open_for):
			node.interacted.connect(open_for)


func _process(_delta: float) -> void:
	# Si se cerro el inventario (tecla I), el baul tambien se cierra.
	if visible:
		var inventory: Control = get_tree().get_first_node_in_group("inventory_panel")
		if inventory and not inventory.visible:
			close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open_for(new_stash: Node3D) -> void:
	stash = new_stash
	visible = true
	inventory_data.stash_open = true
	sfx.play("page")
	var inventory: Control = get_tree().get_first_node_in_group("inventory_panel")
	if inventory and not inventory.visible:
		inventory.open_inventory()
	_update_pause()


func close() -> void:
	visible = false
	inventory_data.stash_open = false
	if stash:
		stash.close_lid()
	sfx.play("page")
	var inventory: Control = get_tree().get_first_node_in_group("inventory_panel")
	if inventory and inventory.visible:
		inventory.close_inventory()
	_update_pause()


func _update_pause() -> void:
	get_tree().paused = get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel.visible)
