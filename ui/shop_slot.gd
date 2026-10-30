extends PanelContainer

## Casilla de la tienda: icono del item, cantidad y precio. Clic = comprar.

signal pressed(index: int)

var index: int = -1
var item: Itemdata
var quantity: int = 1


func setup(slot_index: int, slot_item: Itemdata, slot_quantity: int, price: int, affordable: bool) -> void:
	index = slot_index
	item = slot_item
	quantity = slot_quantity
	custom_minimum_size = Vector2(64, 64)
	theme_type_variation = &"SlotPanel"
	tooltip_text = " "
	if item.rarity != Itemdata.Rarity.NORMAL:
		self_modulate = Color.WHITE.lerp(item.get_rarity_color(), 0.25)

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var icon := TextureRect.new()
	icon.texture = item_icons.get_icon(item)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if icon.texture == item.texture 			else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_bottom = -12.0
	holder.add_child(icon)

	var price_label := Label.new()
	price_label.text = str(price)
	price_label.add_theme_font_size_override("font_size", 12)
	price_label.add_theme_constant_override("outline_size", 4)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35) if affordable else Color(0.85, 0.35, 0.3))
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	price_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(price_label)

	if quantity > 1:
		var qty := Label.new()
		qty.text = "x%d" % quantity
		qty.add_theme_font_size_override("font_size", 12)
		qty.add_theme_constant_override("outline_size", 4)
		qty.position = Vector2(2, -2)
		qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(qty)


func _make_custom_tooltip(_for_text: String) -> Object:
	return ItemTooltip.build(item, 1, "Clic: comprar")


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(index)
		accept_event()
