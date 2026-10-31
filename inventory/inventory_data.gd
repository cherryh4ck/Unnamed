extends Node

## Autoload con el inventario: la mochila (backpack), una grilla de GRID_SIZE
## casillas donde cada item ocupa su tamaño (ver inventory/item_grid.gd), los
## slots de equipo (arma, escudo o ballesta y las partes de la armadura) y el
## baul de la aldea (stash, otra grilla igual). La UI
## (inventory/inventory.gd, ui/stash_panel.gd) solo dibuja lo que hay aca.
##
## held: el item agarrado con el mouse; sale de su grilla hasta que se suelta
## en otro lugar (o vuelve si se cancela). overflow: lo que no entro al cargar
## una partida (por ejemplo, de antes de la grilla). Se guarda con la partida y
## entra solo apenas se libera lugar. anvil: el item puesto en el yunque del
## herrero (ui/smith_panel.gd); vuelve a la mochila al cerrar el panel.
## belt: el cinturon de consumibles del HUD (teclas W, E, R y T); cada ranura
## guarda que consumible usa, y la cantidad sale de la mochila.

signal inventory_changed(slot_index: int)
signal stash_changed
signal picked_up(item: Itemdata, quantity: int)
signal equipment_changed(equip_index: int)
signal equip_rejected(message: String)
signal item_dropped(item: Itemdata, quantity: int)
signal sell_requested(slot_index: int)
signal held_changed
signal overflow_changed
signal anvil_changed
signal belt_changed

const GRID_SIZE := Vector2i(14, 7)
const STASH_SIZE := Vector2i(12, 10)

const MELEE_EQUIP: int = 0
const SPECIAL_EQUIP: int = 1
const HELMET_EQUIP: int = 2
const CHEST_EQUIP: int = 3
const GLOVES_EQUIP: int = 4
const LEGS_EQUIP: int = 5
const BOOTS_EQUIP: int = 6
const BELT_EQUIP: int = 7
const RING_EQUIP: int = 8
const RING2_EQUIP: int = 9
const AMULET_EQUIP: int = 10
## Las partidas de antes de la armadura guardaban solo los dos primeros.
const EQUIP_COUNT: int = 11
## Orden de las categorias al ordenar la mochila (ver sort_backpack).
const SORT_ORDER := [Itemdata.ItemType.MELEE_WEAPON, Itemdata.ItemType.SPECIAL, Itemdata.ItemType.HELMET,
		Itemdata.ItemType.CHEST, Itemdata.ItemType.GLOVES, Itemdata.ItemType.LEGS, Itemdata.ItemType.BOOTS,
		Itemdata.ItemType.BELT, Itemdata.ItemType.RING, Itemdata.ItemType.AMULET, Itemdata.ItemType.GEM,
		Itemdata.ItemType.POTION, Itemdata.ItemType.SCROLL, Itemdata.ItemType.GOLD, Itemdata.ItemType.GENERIC]
## Ranuras del cinturon y lo que llevan al empezar (la pocion de vida va en la Q).
const BELT_SIZE: int = 4
const DEFAULT_BELT := ["res://item/items/antidoto.tres", "res://item/items/pocion_fuego.tres",
		"res://item/items/pocion_regeneracion.tres", "res://item/items/pergamino_retorno.tres"]

var backpack := ItemGrid.new(GRID_SIZE)
var stash := ItemGrid.new(STASH_SIZE)
## Los items de la mochila.
var slots: Array[Slotdata]:
	get:
		return backpack.slots
var equipment: Array[Slotdata] = []
## Item agarrado con el mouse (null = ninguno).
var held: Slotdata = null
## Items esperando lugar en la mochila.
var overflow: Array[Slotdata] = []
## Con la tienda abierta, el clic derecho vende en vez de tirar.
var shop_mode: bool = false
## Con el baul abierto, el clic derecho pasa el item de una grilla a la otra.
var stash_open: bool = false
## Item en el yunque del herrero (null = vacio).
var anvil: Slotdata = null
## Consumible de cada ranura del cinturon (ruta del .tres, "" = vacia).
var belt: PackedStringArray = PackedStringArray(DEFAULT_BELT)

# De donde salio el item agarrado, para devolverlo si se cancela.
var _held_from: Vector2i = Vector2i(-1, -1)
var _held_from_grid: ItemGrid = null
var _held_from_equip: int = -1


func _init() -> void:
	reset()


func reset() -> void:
	backpack.slots.clear()
	stash.slots.clear()
	equipment.clear()
	for i in EQUIP_COUNT:
		equipment.append(null)
	held = null
	anvil = null
	overflow.clear()
	shop_mode = false
	stash_open = false
	belt = PackedStringArray(DEFAULT_BELT)
	_held_from = Vector2i(-1, -1)
	_held_from_grid = null
	_held_from_equip = -1


## Avisa que cambio una grilla (la mochila o el baul).
func notify_changed(grid: ItemGrid) -> void:
	if grid == stash:
		stash_changed.emit()
	else:
		inventory_changed.emit(-1)


# --- Agregar y sacar -------------------------------------------------------

func add_item(item: Itemdata, quantity: int = 1) -> bool:
	if item == null or quantity <= 0:
		return false
	var remaining: int = backpack.add_item(item, quantity)
	inventory_changed.emit(-1)
	picked_up.emit(item, quantity - remaining)
	return remaining <= 0


## Pone un stack cargado de la partida en la mochila: en su posicion si esta
## libre, si no en el primer lugar libre. Devuelve false si no entro.
func restore_slot(slot: Slotdata, pos: Vector2i) -> bool:
	return backpack.restore_slot(slot, pos)


## Guarda un stack que no entro en la mochila hasta que haya lugar.
func park(slot: Slotdata) -> void:
	overflow.append(slot)
	overflow_changed.emit()


## Mete en la mochila lo que estaba esperando, si ahora entra.
func retry_overflow() -> void:
	if overflow.is_empty():
		return
	var placed: bool = false
	for i in range(overflow.size() - 1, -1, -1):
		var pos: Vector2i = backpack.find_free_position(overflow[i].item_data)
		if pos.x >= 0:
			backpack.insert(overflow[i], pos)
			overflow.remove_at(i)
			placed = true
	if placed:
		inventory_changed.emit(-1)
		overflow_changed.emit()


func count_item(item: Itemdata) -> int:
	if item == null:
		return 0
	var total: int = 0
	for slot in backpack.slots:
		if slot.item_data == item:
			total += slot.quantity
	return total


func remove_item(item: Itemdata, quantity: int = 1) -> bool:
	if item == null or quantity <= 0:
		return false
	var remaining: int = quantity
	for i in range(backpack.slots.size() - 1, -1, -1):
		var slot: Slotdata = backpack.slots[i]
		if slot.item_data == item:
			var removed: int = mini(slot.quantity, remaining)
			slot.quantity -= removed
			remaining -= removed
			if slot.quantity <= 0:
				backpack.slots.remove_at(i)
			if remaining <= 0:
				break
	inventory_changed.emit(-1)
	retry_overflow()
	return remaining <= 0


func remove_slot(index: int, grid: ItemGrid = backpack) -> Slotdata:
	if index < 0 or index >= grid.slots.size():
		return null
	var slot: Slotdata = grid.slots[index]
	grid.slots.remove_at(index)
	notify_changed(grid)
	if grid == backpack:
		retry_overflow()
	return slot


## Saca el item del inventario y avisa para que aparezca en el piso.
func drop_slot(index: int, grid: ItemGrid = backpack) -> void:
	var slot: Slotdata = remove_slot(index, grid)
	if slot and slot.item_data:
		item_dropped.emit(slot.item_data, slot.quantity)


## Pasa el item de una grilla a la otra (mochila <-> baul), en el primer
## lugar libre. Devuelve false si no entra.
func transfer(index: int, from: ItemGrid, to: ItemGrid) -> bool:
	if index < 0 or index >= from.slots.size():
		return false
	var slot: Slotdata = from.slots[index]
	var pos: Vector2i = to.find_free_position(slot.item_data)
	if pos.x < 0:
		return false
	from.slots.remove_at(index)
	to.insert(slot, pos)
	notify_changed(from)
	notify_changed(to)
	retry_overflow()
	return true


# --- Agarrar con el mouse --------------------------------------------------

func pick_up(index: int, grid: ItemGrid = backpack) -> void:
	if held != null or index < 0 or index >= grid.slots.size():
		return
	held = grid.slots[index]
	_held_from = held.grid_pos
	_held_from_grid = grid
	_held_from_equip = -1
	grid.slots.remove_at(index)
	notify_changed(grid)
	held_changed.emit()


## Suelta el item agarrado con su esquina en pos. Si tapa un solo item, lo
## cambia por ese (queda agarrado el otro); si es el mismo item apilable, los
## junta. Devuelve false si no se pudo.
func place_held(pos: Vector2i, grid: ItemGrid = backpack) -> bool:
	if held == null or not grid.fits_in_grid(held.item_data, pos):
		return false
	var under: Array[int] = grid.overlapping(held.item_data, pos)
	if under.size() > 1:
		return false
	if under.is_empty():
		grid.insert(held, pos)
		held = null
	else:
		var other: Slotdata = grid.slots[under[0]]
		if other.item_data == held.item_data and held.item_data.stackable:
			var added: int = mini(Slotdata.MAX_STACK_SIZE - other.quantity, held.quantity)
			other.quantity += added
			held.quantity -= added
			if held.quantity <= 0:
				held = null
		else:
			grid.slots.remove_at(under[0])
			grid.insert(held, pos)
			held = other
			_held_from = other.grid_pos
			_held_from_grid = grid
			_held_from_equip = -1
	notify_changed(grid)
	held_changed.emit()
	return true


## Devuelve el item agarrado a donde estaba (o al primer lugar libre de la
## mochila). Si no entra en ningun lado, cae al piso.
func return_held() -> void:
	if held == null:
		return
	var slot: Slotdata = held
	var grid: ItemGrid = _held_from_grid if _held_from_grid else backpack
	held = null
	if _held_from_equip >= 0 and equipment[_held_from_equip] == null:
		equipment[_held_from_equip] = slot
		equipment_changed.emit(_held_from_equip)
	elif grid.restore_slot(slot, _held_from):
		notify_changed(grid)
	elif grid != backpack and backpack.restore_slot(slot, Vector2i(-1, -1)):
		notify_changed(backpack)
	else:
		item_dropped.emit(slot.item_data, slot.quantity)
	_held_from_equip = -1
	_held_from_grid = null
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
	_held_from_grid = null
	held_changed.emit()
	item_dropped.emit(slot.item_data, slot.quantity)
	retry_overflow()


# --- Yunque del herrero ---------------------------------------------------

## Clic en el yunque: con un arma, escudo o ballesta agarrado lo pone (y queda
## agarrado lo que habia); sin nada, agarra lo que esta en el yunque.
## Devuelve false si lo agarrado no se puede trabajar.
func on_anvil_clicked() -> bool:
	if held == null:
		if anvil == null:
			return false
		held = anvil
		anvil = null
		_held_from = Vector2i(-1, -1)
		_held_from_grid = null
		_held_from_equip = -1
		anvil_changed.emit()
		held_changed.emit()
		return true
	if not held.item_data.is_equipment():
		return false
	var previous: Slotdata = anvil
	anvil = held
	held = previous
	_held_from = Vector2i(-1, -1)
	_held_from_grid = null
	_held_from_equip = -1
	anvil_changed.emit()
	held_changed.emit()
	return true


## Saca el item del yunque a la grilla (o a la lista de espera si no entra).
func clear_anvil() -> void:
	if anvil == null:
		return
	var slot: Slotdata = anvil
	anvil = null
	if restore_slot(slot, Vector2i(-1, -1)):
		inventory_changed.emit(-1)
	else:
		park(slot)
	anvil_changed.emit()


# --- Cinturon --------------------------------------------------------------

## Consumible de la ranura index del cinturon (null si esta vacia).
func belt_item(index: int) -> Itemdata:
	if index < 0 or index >= belt.size() or belt[index].is_empty() or not ResourceLoader.exists(belt[index]):
		return null
	return load(belt[index])


## Pone un consumible en la ranura (si ya estaba en otra, se cambian de lugar).
## Solo van consumibles del juego (no generados), menos la pocion de vida.
func set_belt(index: int, item: Itemdata) -> bool:
	if index < 0 or index >= BELT_SIZE or item == null or not item.is_consumable() 			or item.is_health_potion() or item.resource_path.is_empty():
		return false
	var previous: int = belt.find(item.resource_path)
	if previous >= 0:
		belt[previous] = belt[index]
	belt[index] = item.resource_path
	belt_changed.emit()
	return true


## Carga el cinturon de una partida (las de antes no lo tenian).
func load_belt(paths: Array) -> void:
	belt = PackedStringArray(DEFAULT_BELT)
	for i in mini(paths.size(), BELT_SIZE):
		var path: String = str(paths[i])
		belt[i] = path if path.is_empty() or ResourceLoader.exists(path) else ""
	belt_changed.emit()


# --- Ordenar ---------------------------------------------------------------

## Reacomoda la mochila: junta los stacks iguales y pone primero el equipo
## (por tipo, lo mas grande y mejor primero), despues gemas y consumibles.
## Si con el orden nuevo algo no entrara, la deja como estaba.
func sort_backpack() -> bool:
	# Se trabaja con copias: si no entra todo, la mochila queda intacta.
	var merged: Array[Slotdata] = []
	for original in backpack.slots:
		var slot: Slotdata = original.duplicate()
		var joined: bool = false
		if slot.item_data.stackable:
			for other in merged:
				if other.item_data == slot.item_data and other.quantity < Slotdata.MAX_STACK_SIZE:
					var moved: int = mini(Slotdata.MAX_STACK_SIZE - other.quantity, slot.quantity)
					other.quantity += moved
					slot.quantity -= moved
					if slot.quantity <= 0:
						joined = true
						break
		if not joined:
			merged.append(slot)
	merged.sort_custom(_sorts_before)
	var trial := ItemGrid.new(GRID_SIZE)
	for slot in merged:
		var pos: Vector2i = trial.find_free_position(slot.item_data)
		if pos.x < 0:
			return false
		trial.insert(slot, pos)
	backpack.slots = trial.slots
	inventory_changed.emit(-1)
	return true


func _sorts_before(a: Slotdata, b: Slotdata) -> bool:
	var order_a: int = SORT_ORDER.find(a.item_data.item_type)
	var order_b: int = SORT_ORDER.find(b.item_data.item_type)
	if order_a != order_b:
		return order_a < order_b
	var area_a: int = a.item_data.get_footprint().x * a.item_data.get_footprint().y
	var area_b: int = b.item_data.get_footprint().x * b.item_data.get_footprint().y
	if area_a != area_b:
		return area_a > area_b
	if a.item_data.rarity != b.item_data.rarity:
		return a.item_data.rarity > b.item_data.rarity
	return a.item_data.get_display_name() < b.item_data.get_display_name()


# --- Equipo ----------------------------------------------------------------

## Slot de equipo donde va el item (-1 si no se equipa). Los anillos van al
## primer anillo libre.
func equip_index_for(item: Itemdata) -> int:
	match item.item_type:
		Itemdata.ItemType.MELEE_WEAPON:
			return MELEE_EQUIP
		Itemdata.ItemType.SPECIAL:
			return SPECIAL_EQUIP
		Itemdata.ItemType.HELMET:
			return HELMET_EQUIP
		Itemdata.ItemType.CHEST:
			return CHEST_EQUIP
		Itemdata.ItemType.GLOVES:
			return GLOVES_EQUIP
		Itemdata.ItemType.LEGS:
			return LEGS_EQUIP
		Itemdata.ItemType.BOOTS:
			return BOOTS_EQUIP
		Itemdata.ItemType.BELT:
			return BELT_EQUIP
		Itemdata.ItemType.RING:
			if equipment[RING_EQUIP] != null and equipment[RING2_EQUIP] == null:
				return RING2_EQUIP
			return RING_EQUIP
		Itemdata.ItemType.AMULET:
			return AMULET_EQUIP
		_:
			return -1


## Si el item puede ir en ese slot (un anillo entra en cualquiera de los dos).
func fits_slot(item: Itemdata, equip_index: int) -> bool:
	if item.item_type == Itemdata.ItemType.RING:
		return equip_index == RING_EQUIP or equip_index == RING2_EQUIP
	return equip_index_for(item) == equip_index


## Todo lo equipado (sin los slots vacios).
func get_equipped_items() -> Array[Itemdata]:
	var result: Array[Itemdata] = []
	for slot in equipment:
		if slot and slot.item_data:
			result.append(slot.item_data)
	return result


# Motivo por el que no se puede equipar ("" si se puede): nivel o atributos.
func _requirement_problem(item: Itemdata) -> String:
	for line in item.get_requirement_lines():
		if not line[1]:
			return line[0]
	return ""


## Doble clic: equipa el item de la grilla. Lo que estaba equipado vuelve a
## la grilla (en el mismo lugar si entra).
func equip_from_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= backpack.slots.size():
		return false
	var slot: Slotdata = backpack.slots[slot_index]
	var equip_index: int = equip_index_for(slot.item_data)
	if equip_index == -1:
		return false  # este item no es equipable (pociones, oro, etc.)
	var problem: String = _requirement_problem(slot.item_data)
	if not problem.is_empty():
		equip_rejected.emit(problem)
		return false
	if not _combo_allowed(slot.item_data, equip_index):
		equip_rejected.emit("Muy pesado para combinarlo con lo que llevás")
		return false

	var previous: Slotdata = equipment[equip_index]
	backpack.slots.remove_at(slot_index)
	if previous and not backpack.restore_slot(previous, slot.grid_pos):
		backpack.insert(slot, slot.grid_pos)
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
		_held_from_grid = null
		_held_from_equip = equip_index
		equipment_changed.emit(equip_index)
		held_changed.emit()
		return

	if not fits_slot(held.item_data, equip_index):
		equip_rejected.emit("Eso no va en este lugar")
		return
	var problem: String = _requirement_problem(held.item_data)
	if not problem.is_empty():
		equip_rejected.emit(problem)
		return
	if not _combo_allowed(held.item_data, equip_index):
		equip_rejected.emit("Muy pesado para combinarlo con lo que llevás")
		return
	var previous: Slotdata = equipment[equip_index]
	equipment[equip_index] = held
	held = previous
	_held_from = Vector2i(-1, -1)
	_held_from_grid = null
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
# escudo ligero, o escudo pesado + espada ligera). La armadura no cuenta.
func _combo_allowed(item: Itemdata, equip_index: int) -> bool:
	if equip_index != MELEE_EQUIP and equip_index != SPECIAL_EQUIP:
		return true
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
	var pos: Vector2i = backpack.find_free_position(slot.item_data)
	if pos.x < 0:
		equip_rejected.emit("No hay lugar en el inventario")
		return false
	equipment[equip_index] = null
	backpack.insert(slot, pos)
	inventory_changed.emit(-1)
	equipment_changed.emit(equip_index)
	return true
