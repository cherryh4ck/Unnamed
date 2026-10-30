extends PanelContainer

## Slot de equipo del inventario (arma o especial). Clic con un item agarrado:
## lo equipa y queda agarrado lo que habia. Clic sin nada: agarra lo equipado.
## Con un item agarrado encima se marca verde si va ahi y rojo si no.

const CELL: int = 40
const FIT_COLOR := Color(0.35, 0.85, 0.35, 0.22)
const BLOCKED_COLOR := Color(0.9, 0.25, 0.2, 0.25)

var equip_index: int = -1

var _icon: TextureRect
var _type_label: Label
var _hover: bool = false


func setup(index: int, cells: Vector2i, type_name: String) -> void:
	equip_index = index
	theme_type_variation = &"SlotPanel"
	custom_minimum_size = Vector2(cells * CELL)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_type_label = Label.new()
	_type_label.text = type_name
	_type_label.theme_type_variation = &"DimLabel"
	_type_label.add_theme_font_size_override("font_size", 12)
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_type_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_type_label)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_icon)

	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())
	inventory_data.equipment_changed.connect(update.unbind(1))
	inventory_data.held_changed.connect(queue_redraw)
	item_icons.icon_ready.connect(update.unbind(1))
	update()


func update() -> void:
	var item: Itemdata = inventory_data.get_equipped(equip_index)
	tooltip_text = " " if item else ""
	_type_label.visible = item == null
	_icon.visible = item != null
	if item:
		var icon: Texture2D = item_icons.get_icon(item)
		_icon.texture = icon
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if icon == item.texture \
				else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		self_modulate = Color.WHITE.lerp(item.get_rarity_color(), 0.3) if item.rarity != Itemdata.Rarity.NORMAL else Color.WHITE
	else:
		self_modulate = Color.WHITE
	queue_redraw()


func _draw() -> void:
	var held: Slotdata = inventory_data.held
	if not _hover or held == null:
		return
	var fits: bool = inventory_data.equip_index_for(held.item_data) == equip_index
	var color: Color = FIT_COLOR if fits else BLOCKED_COLOR
	var rect := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_rect(rect, color)
	draw_rect(rect, Color(color, 0.9), false, 2.0)


func _make_custom_tooltip(_for_text: String) -> Object:
	var item: Itemdata = inventory_data.get_equipped(equip_index)
	if item == null or inventory_data.held != null:
		return null
	return ItemTooltip.build(item, 1, "Clic: agarrar")


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		var moving: Slotdata = inventory_data.held if inventory_data.held else inventory_data.equipment[equip_index]
		inventory_data.on_equipment_clicked(equip_index)
		if moving:
			sfx.play_item(moving.item_data)
		accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and inventory_data.held == null:
		# Clic derecho: desequipa directo a la grilla.
		if inventory_data.unequip(equip_index):
			sfx.play("drag_weapon")
		accept_event()
