extends Node

## Autoload con el inventario: una grilla de GRID_SIZE casillas donde cada item
## ocupa su tamaño (Itemdata.grid_size), como en los ARPG clasicos, mas los
## dos slots de equipo. La UI (inventory/inventory.gd) solo dibuja lo que hay aca.
##
## slots: los items guardados (sin huecos), cada uno con su casilla de arriba a
## la izquierda en Slotdata.grid_pos. held: el item agarrado con el mouse; sale
## de la grilla hasta que se suelta en otro lugar (o vuelve si se cancela).
## overflow: lo que no entro al cargar una partida (por ejemplo, de antes de la
## grilla). Se guarda con la partida y entra solo apenas se libera lugar.

signal inventory_changed(slot_index: int)
signal picked_up(item: Itemdata, quantity: int)
signal equipment_changed(equip_index: int)
signal equip_rejected(message: String)
signal item_dropped(item: Itemdata, quantity: int)
signal sell_requested(slot_index: int)
signal held_changed
signal overflow_changed

const GRID_SIZE := Vector2i(14, 7)

const MELEE_EQUIP: int = 0
const SPECIAL_EQUIP: int = 1
const EQUIP_COUNT: int = 2

var slots: Array[Slotdata] = []
var equipment: Array[Slotdata] = []
## Item agarrado con el mouse (null = ninguno).
var held: Slotdata = null
## Items esperando lugar en la grilla.
var overflow: Array[Slotdata] = []
## Con la tienda abierta, el clic derecho vende en vez de tirar.
var shop_mode: bool = false

# De donde salio el item agarrado, para devolverlo si se cancela.
var _held_from: Vector2i = Vector2i(-1, -1)
var _held_from_equip: int = -1


func _init() -> void:
	reset()


func reset() -> void:
	slots.clear()
	equipment.clear()
	for i in EQUIP_COUNT:
		equipment.append(null)
	held = null
	overflow.clear()
	_held_from = Vector2i(-1, -1)
	_held_from_equip = -1


# --- Grilla ----------------------------------------------------------------

static func footprint(item: Itemdata) -> Vector2i:
	return item.get_footprint()


func rect_of(slot: Slotdata) -> Rect2i:
	return Rect2i(slot.grid_pos, footprint(slot.item_data))


## Indices de los items que tapa un item puesto en pos (sin contar ignore).
func overlapping(item: Itemdata, pos: Vector2i, ignore: Slotdata = null) -> Array[int]:
	var area := Rect2i(pos, footprint(item))
	var result: Array[int] = []
	for i in slots.size():
		if slots[i] != ignore and rect_of(slots[i]).intersects(area):
			result.append(i)
	return result


func fits_in_grid(item: Itemdata, pos: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, GRID_SIZE).encloses(Rect2i(pos, footprint(item)))


func can_place(item: Itemdata, pos: Vector2i, ignore: Slotdata = null) -> bool:
	return fits_in_grid(item, pos) and overlapping(item, pos, ignore).is_empty()


## Primer lugar libre (de arriba a abajo, de izquierda a derecha) o (-1, -1).
func find_free_position(item: Itemdata) -> Vector2i:
	var size: Vector2i = footprint(item)
	for y in GRID_SIZE.y - size.y + 1:
		for x in GRID_SIZE.x - size.x + 1:
			if can_place(item, Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Indice del item que ocupa la casilla, o -1.
func slot_at(cell: Vector2i) -> int:
	for i in slots.size():
		if rect_of(slots[i]).has_point(cell):
			return i
	return -1


func count_free_cells() -> int:
	var used: int = 0
	for slot in slots:
		used += footprint(slot.item_data).x * footprint(slot.item_data).y
	return GRID_SIZE.x * GRID_SIZE.y - used


func _insert(slot: Slotdata, pos: Vector2i) -> void:
	slot.grid_pos = pos
	slots.append(slot)


# --- Agregar y sacar -------------------------------------------------------

func add_item(item: Itemdata, quantity: int = 1) -> bool:
	if item == null or quantity <= 0:
		return false

	var remaining: int = quantity
	# Primero completo los stacks existentes que tengan el mismo item.
	if item.stackable:
		for slot in slots:
			if slot.item_data == item and slot.quantity < Slotdata.MAX_STACK_SIZE:
				var added: int = mini(Slotdata.MAX_STACK_SIZE - slot.quantity, remaining)
				slot.quantity += added
				remaining -= added
				if remaining <= 0:
					break

	# Despues busco lugar libre en la grilla.
	while remaining > 0:
		var pos: Vector2i = find_free_position(item)
		if pos.x < 0:
			break
		var slot := Slotdata.new()
		slot.item_data = item
		slot.quantity = mini(remaining, Slotdata.MAX_STACK_SIZE)
		remaining -= slot.quantity
		_insert(slot, pos)

	inventory_changed.emit(-1)
	picked_up.emit(item, quantity - remaining)
	return remaining <= 0


## Pone un stack cargado de la partida: en su posicion si esta libre, si no
## en el primer lugar libre. Devuelve false si no entro.
func restore_slot(slot: Slotdata, pos: Vector2i) -> bool:
	if slot == null or slot.item_data == null:
		return false
	if pos.x < 0 or not can_place(slot.item_data, pos):
		pos = find_free_position(slot.item_data)
		if pos.x < 0:
			return false
	_insert(slot, pos)
	return true


## Guarda un stack que no entro en la grilla hasta que haya lugar.
func park(slot: Slotdata) -> void:
	overflow.append(slot)
	overflow_changed.emit()


## Mete en la grilla lo que estaba esperando, si ahora entra.
func retry_overflow() -> void:
	if overflow.is_empty():
		return
	var placed: bool = false
	for i in range(overflow.size() - 1, -1, -1):
		var pos: Vector2i = find_free_position(overflow[i].item_data)
		if pos.x >= 0:
			_insert(overflow[i], pos)
			overflow.remove_at(i)
			placed = true
	if placed:
		inventory_changed.emit(-1)
		overflow_changed.emit()


func count_item(item: Itemdata) -> int:
	if item == null:
		return 0
	var total: int = 0
	for slot in slots:
		if slot.item_data == item:
			total += slot.quantity
	return total


func remove_item(item: Itemdata, quantity: int = 1) -> bool:
	if item == null or quantity <= 0:
		return false
	var remaining: int = quantity
	for i in range(slots.size() - 1, -1, -1):
		var slot: Slotdata = slots[i]
		if slot.item_data == item:
			var removed: int = mini(slot.quantity, remaining)
			slot.quantity -= removed
			remaining -= removed
			if slot.quantity <= 0:
				slots.remove_at(i)
			if remaining <= 0:
				break
	inventory_changed.emit(-1)
	retry_overflow()
	return remaining <= 0


func remove_slot(index: int) -> Slotdata:
	if index < 0 or index >= slots.size():
		return null
	var slot: Slotdata = slots[index]
	slots.remove_at(index)
	inventory_changed.emit(-1)
	retry_overflow()
	return slot


## Saca el item del inventario y avisa para que aparezca en el piso.
func drop_slot(index: int) -> void:
	var slot: Slotdata = remove_slot(index)
	if slot and slot.item_data:
		item_dropped.emit(slot.item_data, slot.quantity)


# --- Agarrar con el mouse --------------------------------------------------

func pick_up(index: int) -> void:
	if held != null or index < 0 or index >= slots.size():
		return
	held = slots[index]
	_held_from = held.grid_pos
	_held_from_equip = -1
	slots.remove_at(index)
	inventory_changed.emit(-1)
	held_changed.emit()


## Suelta el item agarrado con su esquina en pos. Si tapa un solo item, lo
## cambia por ese (queda agarrado el otro); si es el mismo item apilable, los
## junta. Devuelve false si no se pudo.
func place_held(pos: Vector2i) -> bool:
	if held == null or not fits_in_grid(held.item_data, pos):
		return false
	var under: Array[int] = overlapping(held.item_data, pos)
	if under.size() > 1:
		return false
	if under.is_empty():
		_insert(held, pos)
		held = null
	else:
		var other: Slotdata = slots[under[0]]
		if other.item_data == held.item_data and held.item_data.stackable:
			var added: int = mini(Slotdata.MAX_STACK_SIZE - other.quantity, held.quantity)
			other.quantity += added
			held.quantity -= added
			if held.quantity <= 0:
				held = null
		else:
			slots.remove_at(under[0])
			_insert(held, pos)
			held = other
			_held_from = other.grid_pos
			_held_from_equip = -1
	inventory_changed.emit(-1)
	held_changed.emit()
	return true


## Devuelve el item agarrado a donde estaba (o al primer lugar libre). Si no
## entra en ningun lado, cae al piso.
func return_held() -> void:
	if held == null:
		return
	var slot: Slotdata = held
	held = null
	if _held_from_equip >= 0 and equipment[_held_from_equip] == null:
		equipment[_held_from_equip] = slot
		equipment_changed.emit(_held_from_equip)
	elif not restore_slot(slot, _held_from):
		item_dropped.emit(slot.item_data, slot.quantity)
	_held_from_equip = -1
	inventory_changed.emit(-1)
	held_changed.emit()
	retry_overflow()


## Tira al piso el item agarrado.
func drop_held() -> void:
	if held == null:
		return
	var slot: Slotdata = held
	held = null
	_held_from_equip = -1
	held_changed.emit()
	item_dropped.emit(slot.item_data, slot.quantity)
	retry_overflow()


# --- Equipo ----------------------------------------------------------------

func equip_index_for(item: Itemdata) -> int:
	match item.item_type:
		Itemdata.ItemType.MELEE_WEAPON:
			return MELEE_EQUIP
		Itemdata.ItemType.SPECIAL:
			return SPECIAL_EQUIP
		_:
			return -1


## Doble clic: equipa el item de la grilla. Lo que estaba equipado vuelve a
## la grilla (en el mismo lugar si entra).
func equip_from_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var slot: Slotdata = slots[slot_index]
	var equip_index: int = equip_index_for(slot.item_data)
	if equip_index == -1:
		return false  # este item no es equipable (pociones, oro, etc.)
	if not _combo_allowed(slot.item_data, equip_index):
		equip_rejected.emit("Muy pesado para combinarlo con lo que llevás")
		return false

	var previous: Slotdata = equipment[equip_index]
	slots.remove_at(slot_index)
	if previous and not restore_slot(previous, slot.grid_pos):
		_insert(slot, slot.grid_pos)
		equip_rejected.emit("No hay lugar en el inventario")
		return false
	equipment[equip_index] = slot
	inventory_changed.emit(-1)
	equipment_changed.emit(equip_index)
	retry_overflow()
	return true


## Clic en un slot de equipo: con un item agarrado lo equipa (y queda agarrado
## lo que habia); sin nada, agarra lo equipado.
func on_equipment_clicked(equip_index: int) -> void:
	if held == null:
		if equipment[equip_index] == null:
			return
		held = equipment[equip_index]
		equipment[equip_index] = null
		_held_from = Vector2i(-1, -1)
		_held_from_equip = equip_index
		equipment_changed.emit(equip_index)
		held_changed.emit()
		return

	if equip_index_for(held.item_data) != equip_index:
		equip_rejected.emit("Eso no va en este lugar")
		return
	if not _combo_allowed(held.item_data, equip_index):
		equip_rejected.emit("Muy pesado para combinarlo con lo que llevás")
		return
	var previous: Slotdata = equipment[equip_index]
	equipment[equip_index] = held
	held = previous
	_held_from = Vector2i(-1, -1)
	_held_from_equip = -1
	equipment_changed.emit(equip_index)
	held_changed.emit()


func is_heavy_load() -> bool:
	for equip_index in [MELEE_EQUIP, SPECIAL_EQUIP]:
		var item: Itemdata = get_equipped(equip_index)
		if item and item.weight_class == Itemdata.WeightClass.HEAVY:
			return true
	return false


func get_equipped(equip_index: int) -> Itemdata:
	var slot: Slotdata = equipment[equip_index]
	return slot.item_data if slot else null


# Combina el item nuevo con lo ya equipado en el otro slot y valida la regla
# de peso: un item pesado solo se combina con uno ligero (ej: espada larga +
# escudo ligero, o escudo pesado + espada ligera).
func _combo_allowed(item: Itemdata, equip_index: int) -> bool:
	var other_index: int = SPECIAL_EQUIP if equip_index == MELEE_EQUIP else MELEE_EQUIP
	var other: Itemdata = get_equipped(other_index)
	if other == null:
		return true
	if item.weight_class == Itemdata.WeightClass.HEAVY:
		return other.weight_class == Itemdata.WeightClass.LIGHT
	if other.weight_class == Itemdata.WeightClass.HEAVY:
		return item.weight_class == Itemdata.WeightClass.LIGHT
	return true


## Desequipa a la grilla. Devuelve false si no hay lugar.
func unequip(equip_index: int) -> bool:
	if equip_index < 0 or equip_index >= equipment.size():
		return false
	var slot: Slotdata = equipment[equip_index]
	if slot == null:
		return false
	var pos: Vector2i = find_free_position(slot.item_data)
	if pos.x < 0:
		equip_rejected.emit("No hay lugar en el inventario")
		return false
	equipment[equip_index] = null
	_insert(slot, pos)
	inventory_changed.emit(-1)
	equipment_changed.emit(equip_index)
	return true
