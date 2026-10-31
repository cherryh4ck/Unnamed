extends Control

## Grilla de items: la mochila (inventory_data.backpack) o el baul
## (inventory_data.stash), segun grid. Cada item ocupa su forma. Clic: agarrar
## o soltar (si lo que se suelta tapa un solo item, se cambian) · Doble clic:
## equipar o beber (en el baul, pasar a la mochila) · Clic derecho: con el baul
## abierto pasa el item a la otra grilla; si no, vende con la tienda abierta o
## tira; con algo agarrado, cancela.

const GridItem := preload("res://inventory/grid_item.gd")
const CELL: int = 40
## Si el segundo clic de un doble clic llega con el item recien agarrado,
## se devuelve y se hace la accion del doble clic.
const DOUBLE_CLICK_GRACE: float = 0.5
const FIT_COLOR := Color(0.35, 0.85, 0.35, 0.28)
const SWAP_COLOR := Color(0.95, 0.8, 0.3, 0.28)
const BLOCKED_COLOR := Color(0.9, 0.25, 0.2, 0.3)

## Grilla que se muestra (se elige antes de agregarla al arbol).
var grid: ItemGrid = inventory_data.backpack

var _items: Array[Control] = []
var _picked_at: float = -10.0


func _ready() -> void:
	custom_minimum_size = Vector2(grid.size * CELL)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if grid == inventory_data.stash:
		inventory_data.stash_changed.connect(rebuild)
	else:
		inventory_data.inventory_changed.connect(_on_inventory_changed)
	inventory_data.held_changed.connect(queue_redraw)
	item_icons.icon_ready.connect(_on_icon_ready)
	# Al subir de nivel o de atributos cambia que se puede equipar (fondo rojo).
	player_stats.stats_changed.connect(func() -> void:
		for item in _items:
			item.queue_redraw())
	rebuild()


func rebuild() -> void:
	for item in _items:
		item.queue_free()
	_items.clear()
	for i in grid.slots.size():
		var view := GridItem.new()
		add_child(view)
		view.setup(i, grid.slots[i], CELL)
		_items.append(view)
	queue_redraw()


func _on_inventory_changed(_slot_index: int) -> void:
	rebuild()


func _on_icon_ready(_key: String) -> void:
	for item in _items:
		item.refresh_icon()


func _process(_delta: float) -> void:
	if inventory_data.held != null and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var style: StyleBox = get_theme_stylebox("panel", &"SlotPanel")
	for y in grid.size.y:
		for x in grid.size.x:
			draw_style_box(style, Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL)))

	# Donde caeria el item agarrado: verde si entra, dorado si se cambia por otro.
	var held: Slotdata = inventory_data.held
	if held == null or not Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
		return
	var pos: Vector2i = _target_position(held.item_data)
	var color: Color = BLOCKED_COLOR
	if grid.fits_in_grid(held.item_data, pos):
		var under: int = grid.overlapping(held.item_data, pos).size()
		color = FIT_COLOR if under == 0 else (SWAP_COLOR if under == 1 else BLOCKED_COLOR)
	var rect := Rect2(Vector2(pos * CELL), Vector2(held.item_data.get_footprint() * CELL))
	draw_rect(rect, color)
	draw_rect(rect, Color(color, 0.9), false, 2.0)


## Casilla de la esquina del item agarrado para que quede centrado en el mouse.
func _target_position(item: Itemdata) -> Vector2i:
	var footprint: Vector2i = item.get_footprint()
	var corner: Vector2 = get_local_mouse_position() / CELL - Vector2(footprint) / 2.0
	var pos := Vector2i(roundi(corner.x), roundi(corner.y))
	return pos.clamp(Vector2i.ZERO, grid.size - footprint)


func _cell_under_mouse() -> Vector2i:
	var local: Vector2 = get_local_mouse_position()
	return Vector2i(floori(local.x / CELL), floori(local.y / CELL))


func _other_grid() -> ItemGrid:
	return inventory_data.backpack if grid == inventory_data.stash else inventory_data.stash


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	match mouse_event.button_index:
		MOUSE_BUTTON_LEFT:
			if mouse_event.double_click and inventory_data.held != null and now - _picked_at < DOUBLE_CLICK_GRACE:
				inventory_data.return_held()
				_double_click(grid.slot_at(_cell_under_mouse()))
			elif inventory_data.held != null:
				var item: Itemdata = inventory_data.held.item_data
				if inventory_data.place_held(_target_position(item), grid):
					sfx.play_item(item)
				else:
					sfx.play("stuck", -6.0)
			else:
				var index: int = grid.slot_at(_cell_under_mouse())
				if index >= 0:
					sfx.play_item(grid.slots[index].item_data)
					inventory_data.pick_up(index, grid)
					_picked_at = now
			accept_event()
		MOUSE_BUTTON_RIGHT:
			if inventory_data.held != null:
				inventory_data.return_held()
			else:
				var index: int = grid.slot_at(_cell_under_mouse())
				if index >= 0:
					if inventory_data.stash_open:
						_move_to_other_grid(index)
					elif inventory_data.shop_mode:
						inventory_data.sell_requested.emit(index)
					else:
						inventory_data.drop_slot(index, grid)
			accept_event()


func _double_click(index: int) -> void:
	if index < 0:
		return
	if grid == inventory_data.stash:
		_move_to_other_grid(index)
		return
	var item: Itemdata = grid.slots[index].item_data
	if item.is_consumable():
		player_stats.try_consume(item)
	elif inventory_data.equip_from_slot(index):
		sfx.play_item(item)


func _move_to_other_grid(index: int) -> void:
	var item: Itemdata = grid.slots[index].item_data
	if inventory_data.transfer(index, grid, _other_grid()):
		sfx.play_item(item)
	else:
		sfx.play("stuck", -6.0)
		inventory_data.equip_rejected.emit("No hay lugar en el " + ("inventario" if grid == inventory_data.stash else "baúl"))
