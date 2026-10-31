extends PanelContainer

## Panel del inventario (tecla I). Arriba el equipo alrededor del personaje
## (arma, escudo y las partes de la armadura); abajo la grilla. El item
## agarrado sigue al mouse; soltarlo fuera del panel lo tira al piso y cerrar
## el panel lo devuelve. Con el mouse sobre un consumible, W, E, R o T lo
## ponen en esa ranura del cinturon.

const InventoryGrid := preload("res://inventory/inventory_grid.gd")
const EquipmentSlot := preload("res://inventory/equipment_slot.gd")
const CELL: int = InventoryGrid.CELL
## Lugar de cada slot de equipo, en casillas: [indice, posicion, tamaño,
## nombre, dibujo del lugar vacio]. El personaje va al medio. Los slots no
## tienen la forma del item (el icono se achica): asi el panel entra en la
## pantalla de 648 de alto.
const EQUIP_LAYOUT := [
	[inventory_data.HELMET_EQUIP, Vector2(0.0, 0.0), Vector2(2.0, 1.6), "Casco", preload("res://assets/icons/game-icons/lorc/visored-helm.svg")],
	[inventory_data.AMULET_EQUIP, Vector2(0.5, 1.8), Vector2(1.0, 1.0), "Amuleto", preload("res://assets/icons/game-icons/lorc/gem-pendant.svg")],
	[inventory_data.CHEST_EQUIP, Vector2(0.0, 3.0), Vector2(2.0, 2.0), "Armadura", preload("res://assets/icons/game-icons/lorc/breastplate.svg")],
	[inventory_data.MELEE_EQUIP, Vector2(2.2, 0.0), Vector2(2.6, 3.2), "Arma", preload("res://assets/icons/game-icons/lorc/broadsword.svg")],
	[inventory_data.GLOVES_EQUIP, Vector2(2.7, 3.4), Vector2(1.6, 1.6), "Guantes", preload("res://assets/icons/game-icons/delapouite/gauntlet.svg")],
	[inventory_data.SPECIAL_EQUIP, Vector2(9.2, 0.0), Vector2(2.6, 3.2), "Escudo o ballesta", preload("res://assets/icons/game-icons/lorc/checked-shield.svg")],
	[inventory_data.BELT_EQUIP, Vector2(9.3, 3.6), Vector2(2.4, 1.2), "Cinturón", preload("res://assets/icons/game-icons/delapouite/belt-armor.svg")],
	[inventory_data.RING_EQUIP, Vector2(12.0, 0.0), Vector2(1.0, 1.0), "Anillo", preload("res://assets/icons/game-icons/delapouite/ring.svg")],
	[inventory_data.RING2_EQUIP, Vector2(13.2, 0.0), Vector2(1.0, 1.0), "Anillo", preload("res://assets/icons/game-icons/delapouite/ring.svg")],
	[inventory_data.LEGS_EQUIP, Vector2(12.1, 1.2), Vector2(2.0, 1.8), "Grebas", preload("res://assets/icons/game-icons/delapouite/leg-armor.svg")],
	[inventory_data.BOOTS_EQUIP, Vector2(12.1, 3.2), Vector2(2.0, 1.8), "Botas", preload("res://assets/icons/game-icons/lorc/boots.svg")],
]
const HERO_POS := Vector2(5.0, 0.0)
const HERO_CELLS := Vector2(4.0, 5.0)
const EQUIP_AREA := Vector2(14.2, 5.0)
## Capa de render que solo ve la camara del personaje del inventario.
const HERO_LAYER: int = 1 << 10
const BELT_KEYS := ["W", "E", "R", "T"]

var item_grid: Control
var _message: Label
var _overflow_label: Label
var _gold_label: Label
var _held_view: TextureRect
var _hero_camera: Camera3D
var _message_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_panels")
	add_to_group("inventory_panel")
	_build()
	inventory_data.equip_rejected.connect(_on_equip_rejected)
	inventory_data.held_changed.connect(_on_held_changed)
	inventory_data.equipment_changed.connect(func(_index: int) -> void: _tag_hero.call_deferred())
	item_icons.icon_ready.connect(func(_key: String) -> void: _on_held_changed())
	player_stats.gold_changed.connect(_on_gold_changed)
	_on_gold_changed(player_stats.gold)
	inventory_data.overflow_changed.connect(_on_overflow_changed)
	_on_overflow_changed()


func _build() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "INVENTARIO"
	title.theme_type_variation = &"HeaderLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sort := Button.new()
	sort.text = "Ordenar"
	sort.tooltip_text = "Junta lo repetido y acomoda la mochila: equipo, gemas y consumibles."
	sort.focus_mode = Control.FOCUS_NONE
	sort.pressed.connect(_on_sort_pressed)
	var hint := Label.new()
	hint.text = "   I: cerrar"
	hint.theme_type_variation = &"DimLabel"
	header.add_child(title)
	header.add_child(sort)
	header.add_child(hint)
	box.add_child(header)

	var equipment := Control.new()
	equipment.custom_minimum_size = EQUIP_AREA * CELL
	equipment.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	equipment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(equipment)
	for entry in EQUIP_LAYOUT:
		var slot := EquipmentSlot.new()
		equipment.add_child(slot)
		slot.setup(entry[0], entry[2], entry[3], entry[4])
		slot.position = entry[1] * CELL
	var hero: Control = _build_hero_view()
	equipment.add_child(hero)
	hero.position = HERO_POS * CELL
	hero.size = HERO_CELLS * CELL

	item_grid = InventoryGrid.new()
	item_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(item_grid)

	var footer := HBoxContainer.new()
	_message = Label.new()
	_message.add_theme_color_override("font_color", Color(0.95, 0.3, 0.25))
	_message.add_theme_font_size_override("font_size", 14)
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_message)
	var coin := TextureRect.new()
	coin.texture = preload("res://item/items/gold.tres").texture
	coin.custom_minimum_size = Vector2(24, 24)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	footer.add_child(coin)
	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_gold_label.add_theme_font_size_override("font_size", 18)
	footer.add_child(_gold_label)
	box.add_child(footer)

	_overflow_label = Label.new()
	_overflow_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3))
	_overflow_label.add_theme_font_size_override("font_size", 13)
	_overflow_label.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_overflow_label)

	var help := Label.new()
	help.text = "Clic: agarrar · Doble clic: equipar o usar · Clic der.: tirar · F: juntar lo de alrededor · W E R T: al cinturón"
	help.theme_type_variation = &"DimLabel"
	help.add_theme_font_size_override("font_size", 12)
	box.add_child(help)

	# El item agarrado: va arriba de todo y no recibe clics.
	_held_view = TextureRect.new()
	_held_view.top_level = true
	_held_view.z_index = 100
	_held_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_held_view.modulate = Color(1, 1, 1, 0.9)
	_held_view.visible = false
	add_child(_held_view)

	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN


# El personaje entre los dos slots: una camara propia que solo ve la capa
# HERO_LAYER (el modelo del jugador y su arma), con fondo transparente.
func _build_hero_view() -> Control:
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"SlotPanel"
	frame.custom_minimum_size = HERO_CELLS * CELL
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(container)
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	container.add_child(viewport)
	_hero_camera = Camera3D.new()
	_hero_camera.cull_mask = HERO_LAYER
	_hero_camera.fov = 32.0
	_hero_camera.far = 6000.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.56, 0.5)
	environment.ambient_light_energy = 0.8
	_hero_camera.environment = environment
	viewport.add_child(_hero_camera)
	return frame


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message.text = ""
	if _held_view.visible:
		_held_view.global_position = get_global_mouse_position() - _held_view.size / 2.0
	if visible:
		_update_hero_camera()


func _update_hero_camera() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var forward: Vector3 = player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.BACK
	var center: Vector3 = player.get_node("Player").bone_position("hip") + Vector3.UP * 20.0
	_hero_camera.global_position = center + forward * 950.0 + Vector3.UP * 110.0
	_hero_camera.look_at(center, Vector3.UP)


# Suma la capa del inventario a todo lo que se dibuja del personaje (el arma
# equipada se crea de nuevo al cambiar de equipo). El caballo no: montado, su
# cabeza tapa al jinete.
func _tag_hero() -> void:
	# Al recargar la escena puede llegar tarde, con este inventario ya afuera.
	if not is_inside_tree():
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	for node in player.get_node("Player").find_children("*", "VisualInstance3D", true, false):
		(node as VisualInstance3D).layers |= HERO_LAYER


func _on_held_changed() -> void:
	var held: Slotdata = inventory_data.held
	_held_view.visible = held != null
	if held == null:
		return
	var icon: Texture2D = item_icons.get_icon(held.item_data)
	_held_view.texture = icon
	_held_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if icon == held.item_data.texture \
			else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_held_view.size = Vector2(held.item_data.get_footprint() * CELL)
	_held_view.global_position = get_global_mouse_position() - _held_view.size / 2.0


func _on_overflow_changed() -> void:
	var waiting: Array[Slotdata] = inventory_data.overflow
	_overflow_label.visible = not waiting.is_empty()
	var names := PackedStringArray()
	for slot in waiting:
		names.append(slot.item_data.get_display_name())
	_overflow_label.text = "%d objeto%s sin lugar: entran solos cuando liberes espacio (vendé o tirá algo)" \
			% [waiting.size(), "" if waiting.size() == 1 else "s"]
	_overflow_label.tooltip_text = "\n".join(names)


func _on_gold_changed(amount: int) -> void:
	_gold_label.text = "%d de oro" % amount


func _on_equip_rejected(message: String) -> void:
	sfx.play("stuck")
	_show_message(message)


func _show_message(message: String, color: Color = Color(0.95, 0.3, 0.25)) -> void:
	_message.text = message
	_message.add_theme_color_override("font_color", color)
	_message_timer = 2.5


func _on_sort_pressed() -> void:
	inventory_data.return_held()
	if inventory_data.sort_backpack():
		sfx.play("page")
	else:
		sfx.play("stuck")
		_show_message("Ordenado no entra todo: hacé un poco de lugar primero")


# W, E, R o T con el mouse sobre un consumible de la mochila: va a esa ranura
# del cinturon. Devuelve false si el mouse no esta sobre un item.
func _assign_belt(index: int) -> bool:
	var local: Vector2 = item_grid.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, item_grid.size).has_point(local):
		return false
	var slot_index: int = inventory_data.backpack.slot_at(Vector2i((local / CELL).floor()))
	if slot_index < 0:
		return false
	var item: Itemdata = inventory_data.backpack.slots[slot_index].item_data
	if not inventory_data.set_belt(index, item):
		sfx.play("stuck", -6.0)
		_show_message("Eso no va en el cinturón")
		return true
	sfx.play_item(item)
	_show_message("%s: tecla %s" % [item.get_display_name(), BELT_KEYS[index]], Color(0.6, 0.9, 1.0))
	return true


func _belt_action(event: InputEvent) -> int:
	for i in inventory_data.BELT_SIZE:
		if event.is_action_pressed("belt_%d" % (i + 1)):
			return i
	return -1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()
	elif visible and _belt_action(event) >= 0 and _assign_belt(_belt_action(event)):
		get_viewport().set_input_as_handled()
	elif visible and inventory_data.held != null and event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Clic fuera de cualquier panel con un item agarrado: cae al piso.
		inventory_data.drop_held()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close_inventory()
	else:
		open_inventory()


func open_inventory() -> void:
	visible = true
	_tag_hero()
	sfx.play("page")
	_update_pause()


func close_inventory() -> void:
	visible = false
	inventory_data.return_held()
	sfx.play("page")
	_update_pause()


# El juego queda en pausa mientras haya algun panel abierto (inventario o personaje).
func _update_pause() -> void:
	get_tree().paused = get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel.visible)
