class_name ItemGrid
extends RefCounted

## Una grilla de casillas donde cada item ocupa su tamaño (Itemdata.grid_size),
## como en los ARPG clasicos. La usan la mochila y el baul de la aldea
## (inventory_data.backpack y inventory_data.stash).
##
## slots: los items guardados (sin huecos), cada uno con su casilla de arriba a
## la izquierda en Slotdata.grid_pos.

var size: Vector2i
var slots: Array[Slotdata] = []


func _init(grid_size: Vector2i) -> void:
	size = grid_size


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
	return Rect2i(Vector2i.ZERO, size).encloses(Rect2i(pos, footprint(item)))


func can_place(item: Itemdata, pos: Vector2i, ignore: Slotdata = null) -> bool:
	return fits_in_grid(item, pos) and overlapping(item, pos, ignore).is_empty()


## Primer lugar libre (de arriba a abajo, de izquierda a derecha) o (-1, -1).
func find_free_position(item: Itemdata) -> Vector2i:
	var item_size: Vector2i = footprint(item)
	for y in size.y - item_size.y + 1:
		for x in size.x - item_size.x + 1:
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
	return size.x * size.y - used


func insert(slot: Slotdata, pos: Vector2i) -> void:
	slot.grid_pos = pos
	slots.append(slot)


## Pone un stack: en su posicion si esta libre, si no en el primer lugar
## libre. Devuelve false si no entro.
func restore_slot(slot: Slotdata, pos: Vector2i) -> bool:
	if slot == null or slot.item_data == null:
		return false
	if pos.x < 0 or not can_place(slot.item_data, pos):
		pos = find_free_position(slot.item_data)
		if pos.x < 0:
			return false
	insert(slot, pos)
	return true


## Guarda quantity del item: primero completa los stacks iguales, despues
## busca lugar libre. Devuelve cuantos no entraron.
func add_item(item: Itemdata, quantity: int) -> int:
	var remaining: int = quantity
	if item.stackable:
		for slot in slots:
			if slot.item_data == item and slot.quantity < Slotdata.MAX_STACK_SIZE:
				var added: int = mini(Slotdata.MAX_STACK_SIZE - slot.quantity, remaining)
				slot.quantity += added
				remaining -= added
				if remaining <= 0:
					return 0
	while remaining > 0:
		var pos: Vector2i = find_free_position(item)
		if pos.x < 0:
			break
		var slot := Slotdata.new()
		slot.item_data = item
		slot.quantity = mini(remaining, Slotdata.MAX_STACK_SIZE)
		remaining -= slot.quantity
		insert(slot, pos)
	return remaining
