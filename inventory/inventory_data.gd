extends Node

signal inventory_changed(slot_index: int)
signal hovered_changed(slot_index: int)
signal picked_up(item: Itemdata, quantity: int)
signal equipment_changed(equip_index: int)
signal equip_rejected(message: String)

const SLOT_COUNT: int = 24

const MELEE_EQUIP: int = 0
const SPECIAL_EQUIP: int = 1
const EQUIP_COUNT: int = 2

const HEAVY_MELEE: String = "espada larga"
const LIGHT_MELEE: String = "espada ligera"
const LIGHT_SPECIAL: String = "escudo ligero"
const HEAVY_SPECIAL: String = "escudo pesado"

var slots: Array[Slotdata] = []
var equipment: Array[Slotdata] = []
var selected_slot: int = -1
var hovered_slot: int = -1


func _init() -> void:
	reset()


func reset() -> void:
	slots.clear()
	for i in SLOT_COUNT:
		slots.append(null)
	equipment.clear()
	for i in EQUIP_COUNT:
		equipment.append(null)
	selected_slot = -1
	hovered_slot = -1


func _equip_index_for(item: Itemdata) -> int:
	match item.item_type:
		Itemdata.ItemType.MELEE_WEAPON:
			return MELEE_EQUIP
		Itemdata.ItemType.SPECIAL:
			return SPECIAL_EQUIP
		_:
			return -1


func equip_from_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var slot: Slotdata = slots[slot_index]
	if slot == null or slot.item_data == null:
		return false

	var equip_index: int = _equip_index_for(slot.item_data)
	if equip_index == -1:
		return false  # este item no es equipable (pociones, oro, etc.)

	if not _combo_allowed(slot.item_data, equip_index):
		equip_rejected.emit("muy pesado para equipar")
		return false

	var previous: Slotdata = equipment[equip_index]
	equipment[equip_index] = slot
	slots[slot_index] = previous  # si había algo equipado, vuelve al inventario

	inventory_changed.emit(slot_index)
	equipment_changed.emit(equip_index)
	return true


func is_heavy_load() -> bool:
	for equip_index in [MELEE_EQUIP, SPECIAL_EQUIP]:
		var slot: Slotdata = equipment[equip_index]
		if slot and slot.item_data:
			if slot.item_data.name == HEAVY_MELEE or slot.item_data.name == HEAVY_SPECIAL:
				return true
	return false


# Combina el item nuevo con lo ya equipado en el otro slot y valida las reglas:
# - espada larga (HEAVY_MELEE) solo se combina con escudo ligero (LIGHT_SPECIAL).
# - escudo pesado (HEAVY_SPECIAL) solo se combina con espada ligera (LIGHT_MELEE).
func _combo_allowed(item: Itemdata, equip_index: int) -> bool:
	var other_index: int = SPECIAL_EQUIP if equip_index == MELEE_EQUIP else MELEE_EQUIP
	var other_slot: Slotdata = equipment[other_index]
	var other_name: String = other_slot.item_data.name if other_slot and other_slot.item_data else ""

	if item.name == HEAVY_MELEE:
		return other_name == "" or other_name == LIGHT_SPECIAL
	if item.name == HEAVY_SPECIAL:
		return other_name == "" or other_name == LIGHT_MELEE
	if other_slot and other_slot.item_data:
		if other_slot.item_data.name == HEAVY_MELEE:
			return item.name == LIGHT_SPECIAL
		if other_slot.item_data.name == HEAVY_SPECIAL:
			return item.name == LIGHT_MELEE
	return true


func unequip(equip_index: int) -> bool:
	if equip_index < 0 or equip_index >= equipment.size():
		return false
	var slot: Slotdata = equipment[equip_index]
	if slot == null:
		return false

	for i in slots.size():
		if slots[i] == null:
			slots[i] = slot
			equipment[equip_index] = null
			inventory_changed.emit(i)
			equipment_changed.emit(equip_index)
			return true
	return false  # inventario lleno, no hay donde devolver el item


func on_equipment_clicked(equip_index: int) -> void:
	unequip(equip_index)


func count_item(item: Itemdata) -> int:
	if item == null:
		return 0
	var total: int = 0
	for slot in slots:
		if slot and slot.item_data == item:
			total += slot.quantity
	return total


func count_free_slots() -> int:
	var free: int = 0
	for slot in slots:
		if slot == null:
			free += 1
	return free


func add_item(item: Itemdata, quantity: int = 1) -> bool:
	if item == null or quantity <= 0:
		return false

	var remaining: int = quantity

	# Primero completo los stacks existentes que tengan el mismo item.
	if item.stackable:
		for i in slots.size():
			var slot: Slotdata = slots[i]
			if slot and slot.item_data == item and slot.quantity < Slotdata.MAX_STACK_SIZE:
				var space: int = Slotdata.MAX_STACK_SIZE - slot.quantity
				var added: int = mini(space, remaining)
				slot.quantity += added
				remaining -= added
				inventory_changed.emit(i)
				if remaining <= 0:
					picked_up.emit(item, quantity)
					return true

	# Despues lleno los huecos vacios.
	for i in slots.size():
		if slots[i] == null:
			var slot := Slotdata.new()
			slot.item_data = item
			slot.quantity = mini(remaining, Slotdata.MAX_STACK_SIZE)
			slots[i] = slot
			remaining -= slot.quantity
			inventory_changed.emit(i)
			if remaining <= 0:
				picked_up.emit(item, quantity)
				return true

	# No entra todo.
	picked_up.emit(item, quantity - remaining)
	return false


func remove_item(item: Itemdata, quantity: int = 1) -> bool:
	if item == null or quantity <= 0:
		return false

	var remaining: int = quantity
	for i in slots.size():
		var slot: Slotdata = slots[i]
		if slot and slot.item_data == item:
			var removed: int = mini(slot.quantity, remaining)
			slot.quantity -= removed
			remaining -= removed
			if slot.quantity <= 0:
				slots[i] = null
			inventory_changed.emit(i)
			if remaining <= 0:
				return true
	return false


func remove_slot(index: int) -> Slotdata:
	if index < 0 or index >= slots.size():
		return null
	var slot: Slotdata = slots[index]
	slots[index] = null
	if selected_slot == index:
		selected_slot = -1
	inventory_changed.emit(-1)
	return slot


func on_slot_clicked(index: int) -> void:
	if selected_slot == -1:
		selected_slot = index
		inventory_changed.emit(-1)
	elif selected_slot == index:
		selected_slot = -1
		inventory_changed.emit(-1)
	else:
		_swap_or_merge(selected_slot, index)
		selected_slot = -1
		inventory_changed.emit(-1)


func set_hovered(index: int) -> void:
	hovered_slot = index
	hovered_changed.emit(index)


func _swap_or_merge(from_index: int, to_index: int) -> void:
	var from_slot: Slotdata = slots[from_index]
	var to_slot: Slotdata = slots[to_index]

	# Si son el mismo item apilable, fusiono el stack del origen en el destino.
	if from_slot and to_slot and from_slot.item_data == to_slot.item_data \
			and from_slot.item_data.stackable:
		var added: int = mini(Slotdata.MAX_STACK_SIZE - to_slot.quantity, from_slot.quantity)
		to_slot.quantity += added
		from_slot.quantity -= added
		if from_slot.quantity <= 0:
			slots[from_index] = null
		return

	slots[from_index] = to_slot
	slots[to_index] = from_slot
