extends CanvasLayer

## Autoload de textos flotantes (numeros de daño, "Bloqueo", oro).
## Siguen una posicion del mundo 3D pero se dibujan en 2D, asi tienen
## siempre el mismo tamaño en pantalla sin importar el zoom de la camara.

const DURATION: float = 0.9
const RISE_PIXELS: float = 70.0


class FloatingItem:
	var label: Label
	var world_pos: Vector3
	var time: float = 0.0
	var drift: float = 0.0
	var pop: float = 1.0


var _items: Array[FloatingItem] = []


func _ready() -> void:
	layer = 5


func spawn(world_pos: Vector3, text: String, color: Color, font_size: int = 22, pop: float = 1.0) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size / 2.0

	var item := FloatingItem.new()
	item.label = label
	item.world_pos = world_pos
	item.drift = randf_range(-25.0, 25.0)
	item.pop = pop
	_items.append(item)
	_place(item, get_viewport().get_camera_3d())


func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	for i in range(_items.size() - 1, -1, -1):
		var item: FloatingItem = _items[i]
		item.time += delta
		if item.time >= DURATION or camera == null:
			item.label.queue_free()
			_items.remove_at(i)
			continue
		_place(item, camera)


func _place(item: FloatingItem, camera: Camera3D) -> void:
	if camera == null or camera.is_position_behind(item.world_pos):
		item.label.visible = false
		return
	var t: float = item.time / DURATION
	var screen: Vector2 = camera.unproject_position(item.world_pos)
	item.label.visible = true
	item.label.position = screen - item.label.size / 2.0 + Vector2(item.drift * t, -RISE_PIXELS * t)
	# Los criticos arrancan mas grandes y se achican rapido.
	var s: float = lerpf(item.pop, 1.0, minf(t * 4.0, 1.0))
	item.label.scale = Vector2(s, s)
	item.label.modulate.a = 1.0 - clampf((t - 0.6) / 0.4, 0.0, 1.0)
