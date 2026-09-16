extends PanelContainer

const Slot := preload("res://inventory/slot.tscn")
const EquipmentSlot := preload("res://inventory/equipment_slot.tscn")

@onready var equipment_bar: HBoxContainer = $MarginContainer/VBoxContainer/EquipmentBar
@onready var item_grid: GridContainer = $MarginContainer/VBoxContainer/ItemGrid
@onready var item_name_label: Label = $MarginContainer/VBoxContainer/Footer/ItemName
@onready var item_desc_label: Label = $MarginContainer/VBoxContainer/Footer/ItemDescription
@onready var error_message_label: Label = $MarginContainer/VBoxContainer/Footer/ErrorMessage

var _message_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	for i in inventory_data.SLOT_COUNT:
		var slot: Control = Slot.instantiate()
		item_grid.add_child(slot)
		slot.setup(inventory_data, i)

	for equip_index in 2:
		var equip_slot: Control = EquipmentSlot.instantiate()
		equipment_bar.add_child(equip_slot)
		equip_slot.setup(equip_index)

	inventory_data.hovered_changed.connect(_on_hovered_changed)
	inventory_data.equip_rejected.connect(_on_equip_rejected)


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			error_message_label.visible = false


func _on_equip_rejected(message: String) -> void:
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
	get_tree().paused = true


func close_inventory() -> void:
	visible = false
	inventory_data.selected_slot = -1
	get_tree().paused = false


func _on_hovered_changed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= inventory_data.slots.size():
		item_name_label.text = ""
		item_desc_label.text = ""
		return

	var slot_data: Slotdata = inventory_data.slots[slot_index]
	if slot_data and slot_data.item_data:
		item_name_label.text = slot_data.item_data.get_display_name()
		item_desc_label.text = slot_data.item_data.description
	else:
		item_name_label.text = ""
		item_desc_label.text = ""
