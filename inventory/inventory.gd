extends PanelContainer

const Slot := preload("res://inventory/slot.tscn")
const EquipmentSlot := preload("res://inventory/equipment_slot.tscn")

@onready var equipment_bar: HBoxContainer = $MarginContainer/VBoxContainer/EquipmentBar
@onready var item_grid: GridContainer = $MarginContainer/VBoxContainer/ItemGrid
@onready var error_message_label: Label = $MarginContainer/VBoxContainer/Footer/ErrorMessage

var _message_timer: float = 0.0
var _gold_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_panels")
	add_to_group("inventory_panel")

	for i in inventory_data.SLOT_COUNT:
		var slot: Control = Slot.instantiate()
		item_grid.add_child(slot)
		slot.setup(inventory_data, i)

	for equip_index in 2:
		var equip_slot: Control = EquipmentSlot.instantiate()
		equipment_bar.add_child(equip_slot)
		equip_slot.setup(equip_index)

	inventory_data.equip_rejected.connect(_on_equip_rejected)
	_build_gold_row()


# Contador de oro en el pie del inventario (moneda + cantidad).
func _build_gold_row() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	var coin := TextureRect.new()
	coin.texture = preload("res://item/items/gold.tres").texture
	coin.custom_minimum_size = Vector2(24, 24)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_gold_label.add_theme_font_size_override("font_size", 18)
	row.add_child(coin)
	row.add_child(_gold_label)
	$MarginContainer/VBoxContainer/Footer.add_child(row)
	_on_gold_changed(player_stats.gold)
	# Metodo y no lambda: asi la conexion se corta sola si se rearma la escena (F9).
	player_stats.gold_changed.connect(_on_gold_changed)


func _on_gold_changed(amount: int) -> void:
	_gold_label.text = "%d de oro" % amount


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			error_message_label.visible = false


func _on_equip_rejected(message: String) -> void:
	sfx.play("stuck")
	error_message_label.text = message
	error_message_label.visible = true
	_message_timer = 2.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close_inventory()
	else:
		open_inventory()


func open_inventory() -> void:
	visible = true
	sfx.play("page")
	_update_pause()


func close_inventory() -> void:
	visible = false
	inventory_data.selected_slot = -1
	sfx.play("page")
	_update_pause()


# El juego queda en pausa mientras haya algun panel abierto (inventario o personaje).
func _update_pause() -> void:
	get_tree().paused = get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel.visible)
