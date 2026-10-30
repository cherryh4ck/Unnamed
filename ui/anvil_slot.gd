extends PanelContainer

## Yunque del panel del herrero: el lugar donde se pone el item a trabajar
## (inventory_data.anvil). Clic con un arma, escudo o ballesta agarrado: lo
## pone (y queda agarrado lo que habia). Clic sin nada: lo agarra.

const CELL: int = 40
const CELLS := Vector2i(3, 4)
const FIT_COLOR := Color(0.35, 0.85, 0.35, 0.22)
const BLOCKED_COLOR := Color(0.9, 0.25, 0.2, 0.25)

var _icon: TextureRect
var _hint: Label
var _hover: bool = false


func _ready() -> void:
	theme_type_variation = &"SlotPanel"
	custom_minimum_size = Vector2(CELLS * CELL)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_hint = Label.new()
	_hint.text = "YUNQUE"
	_hint.theme_type_variation = &"DimLabel"
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_hint)
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
	inventory_data.anvil_changed.connect(update)
	inventory_data.held_changed.connect(queue_redraw)
	item_icons.icon_ready.connect(update.unbind(1))
	update()


func update() -> void:
	var item: Itemdata = inventory_data.anvil.item_data if inventory_data.anvil else null
	tooltip_text = " " if item else ""
	_hint.visible = item == null
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
	var color: Color = FIT_COLOR if held.item_data.is_equipment() else BLOCKED_COLOR
	var rect := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_rect(rect, color)
	draw_rect(rect, Color(color, 0.9), false, 2.0)


func _make_custom_tooltip(_for_text: String) -> Object:
	if inventory_data.anvil == null or inventory_data.held != null:
		return null
	return ItemTooltip.build(inventory_data.anvil.item_data, 1, "Clic: agarrar")


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var moving: Slotdata = inventory_data.held if inventory_data.held else inventory_data.anvil
	if inventory_data.on_anvil_clicked():
		if moving:
			sfx.play_item(moving.item_data)
	elif inventory_data.held:
		sfx.play("stuck", -6.0)
	accept_event()
