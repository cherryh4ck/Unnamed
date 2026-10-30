extends "res://scripts/npc/npc.gd"

## Herrero: trabaja el item que el jugador pone en el yunque
## (inventory_data.anvil). Abre ranuras, engarza gemas y las saca. Los
## precios y lo que da cada gema estan en scripts/items/gems.gd; el panel es
## ui/smith_panel.gd.


func _ready() -> void:
	super()
	add_to_group("blacksmiths")


## Abre una ranura mas en el item del yunque. Devuelve un texto de error o "".
func open_socket() -> String:
	var item: Itemdata = _anvil_item()
	if item == null:
		return "Poné algo en el yunque"
	if item.sockets >= Gems.max_sockets(item):
		return "No le entran más ranuras"
	var price: int = Gems.socket_price(item)
	if player_stats.gold < price:
		return "No te alcanza el oro"
	player_stats.add_gold(-price)
	_own_anvil_item().sockets += 1
	inventory_data.anvil_changed.emit()
	return ""


## Engarza una gema del stack agarrado en la primera ranura vacia.
func insert_gem(gem_slot: Slotdata) -> String:
	var item: Itemdata = _anvil_item()
	if item == null:
		return "Poné algo en el yunque"
	if gem_slot == null or gem_slot.item_data.item_type != Itemdata.ItemType.GEM:
		return "Eso no es una gema"
	if item.gems.size() >= item.sockets:
		return "No tiene ranuras libres"
	var price: int = Gems.insert_price(gem_slot.item_data)
	if player_stats.gold < price:
		return "No te alcanza el oro"
	player_stats.add_gold(-price)
	var owned: Itemdata = _own_anvil_item()
	var gems: PackedStringArray = owned.gems.duplicate()
	gems.append(Gems.id_of(gem_slot.item_data))
	owned.gems = gems
	gem_slot.quantity -= 1
	if gem_slot.quantity <= 0 and inventory_data.held == gem_slot:
		inventory_data.held = null
	inventory_data.held_changed.emit()
	inventory_data.anvil_changed.emit()
	player_stats.stats_changed.emit()
	return ""


## Saca todas las gemas: vuelven al inventario (o esperan lugar si no entran).
func remove_gems() -> String:
	var item: Itemdata = _anvil_item()
	if item == null:
		return "Poné algo en el yunque"
	if item.gems.is_empty():
		return "No tiene gemas"
	var price: int = Gems.remove_price(item)
	if player_stats.gold < price:
		return "No te alcanza el oro"
	player_stats.add_gold(-price)
	var owned: Itemdata = _own_anvil_item()
	for id in owned.gems:
		var gem: Itemdata = Gems.from_id(id)
		if gem and not inventory_data.add_item(gem, 1):
			var slot := Slotdata.new()
			slot.item_data = gem
			inventory_data.park(slot)
	owned.gems = PackedStringArray()
	inventory_data.anvil_changed.emit()
	return ""


func _anvil_item() -> Itemdata:
	return inventory_data.anvil.item_data if inventory_data.anvil else null


# Los items puestos a mano en el mapa son el .tres compartido: antes de
# cambiarlo se hace una copia propia que se guarda como item generado.
func _own_anvil_item() -> Itemdata:
	var slot: Slotdata = inventory_data.anvil
	if slot.item_data.base_path.is_empty():
		var copy: Itemdata = slot.item_data.duplicate()
		copy.base_path = slot.item_data.resource_path
		slot.item_data = copy
	return slot.item_data
