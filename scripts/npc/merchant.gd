extends StaticBody3D

## Comerciante: NPC que vende items y compra los del jugador.
## Al hacerle clic el jugador camina hasta el y se abre la tienda (ui/shop_panel.gd).

signal interacted(merchant: Node3D)

## Cantidad de items de equipo a la venta (ademas de las pociones).
const STOCK_ITEMS: int = 10
const STOCK_POTIONS: int = 5
const MAX_STOCK: int = 16
## Los items que el jugador vende quedan a la venta por este multiplicador del valor.
const BUYBACK_MARKUP: float = 1.0

@export var display_name: String = "Comerciante"
@export var idle_animation: String = "82_BT3_0"

@onready var anim_player: AnimationPlayer = find_child("AnimationPlayer", true, false)

## Stock actual: lista de {item, quantity}.
var stock: Array[Dictionary] = []
var _stock_day: int = -1
var _stock_level: int = -1


func _ready() -> void:
	add_to_group("npcs")
	if anim_player and anim_player.has_animation(idle_animation):
		anim_player.get_animation(idle_animation).loop_mode = Animation.LOOP_LINEAR
		anim_player.play(idle_animation)
	$NameLabel.text = display_name


func _process(delta: float) -> void:
	# Mira al jugador cuando esta cerca.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < 900.0:
		var dir: Vector3 = player.global_position - global_position
		dir.y = 0.0
		if dir.length() > 1.0:
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 4.0 * delta)


func get_display_name() -> String:
	return display_name


func interact() -> void:
	_refresh_stock_if_needed()
	interacted.emit(self)


## El stock se renueva cada dia del juego o cuando el jugador sube de nivel.
func _refresh_stock_if_needed() -> void:
	if _stock_day == world_time.day and _stock_level == player_stats.level:
		return
	_stock_day = world_time.day
	_stock_level = player_stats.level
	stock.clear()
	stock.append({"item": Loot.POTION, "quantity": STOCK_POTIONS})
	for i in STOCK_ITEMS:
		# El comerciante no vende unicos ni piezas de set.
		var rarity: int = [0, 0, 0, 1, 1, 2].pick_random()
		stock.append({"item": Loot.generate_item(player_stats.level, rarity), "quantity": 1})


static func buy_price(item: Itemdata) -> int:
	return maxi(1, item.value)


static func sell_price(item: Itemdata) -> int:
	return maxi(1, item.value / 4)


## Compra la entrada index del stock. Devuelve un texto de error o "" si salio bien.
func buy(index: int) -> String:
	if index < 0 or index >= stock.size():
		return "No está a la venta"
	var entry: Dictionary = stock[index]
	var price: int = buy_price(entry.item)
	if player_stats.gold < price:
		return "No te alcanza el oro"
	if not inventory_data.add_item(entry.item, 1):
		return "Inventario lleno"
	player_stats.add_gold(-price)
	entry.quantity -= 1
	if entry.quantity <= 0:
		stock.remove_at(index)
	return ""


## Vende el item del slot del inventario. Devuelve el oro ganado (0 si no pudo).
func sell(slot_index: int) -> int:
	var slot: Slotdata = inventory_data.slots[slot_index]
	if slot == null or slot.item_data == null:
		return 0
	var item: Itemdata = slot.item_data
	var gained: int = sell_price(item) * slot.quantity
	inventory_data.remove_slot(slot_index)
	player_stats.add_gold(gained)
	# Lo vendido queda a la venta (recompra), salvo el oro y las pociones repetidas.
	if item.item_type != Itemdata.ItemType.POTION and stock.size() < MAX_STOCK:
		stock.append({"item": item, "quantity": slot.quantity})
	return gained
