extends Control

## Mapa grande (tecla Tab). La foto del mundo desde arriba en tono pergamino,
## con niebla en lo que todavia no se recorrio, los nombres de los lugares,
## los portales, las zonas peligrosas y el personaje. Rueda: zoom (hacia el
## mouse) · Arrastrar: mover · Clic derecho: volver al personaje.
## Abierto desde un portal (open_travel) sirve para elegir a donde viajar.

const PORTAL_ICON := preload("res://assets/icons/game-icons/lorc/magic-portal.svg")
const SKULL_ICON := preload("res://assets/icons/game-icons/lorc/skull-crossed-bones.svg")
const MAP_TINT := Color(0.93, 0.82, 0.62)
const FOG_TINT := Color(0.36, 0.28, 0.18)
const PAPER := Color(0.16, 0.12, 0.08)
const INK := Color(0.22, 0.13, 0.06)
const LABEL_COLOR := Color(0.98, 0.9, 0.7)
const PORTAL_COLOR := Color(0.45, 0.78, 1.0)
const DANGER_COLOR := Color(0.85, 0.25, 0.18)
const PLAYER_COLOR := Color(1.0, 0.86, 0.35)
const ZOOM_MIN: float = 1.0
const ZOOM_MAX: float = 6.0
const ICON_SIZE: float = 26.0
const PICK_RADIUS: float = 18.0

var _panel: PanelContainer
var _title: Label
var _hint: Label
var _view: Control
var _zoom: float = 3.0
var _center: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_moved: float = 0.0
var _travel_from: String = ""
var _hover_portal: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_panels")
	add_to_group("world_map_panel")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		_panel.set("offset_" + side, 40.0 if side in ["left", "top"] else -40.0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	var header := HBoxContainer.new()
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint = Label.new()
	_hint.theme_type_variation = &"DimLabel"
	header.add_child(_title)
	header.add_child(_hint)
	box.add_child(header)

	_view = Control.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_map)
	_view.gui_input.connect(_on_view_input)
	box.add_child(_view)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		if visible:
			close()
		elif not _other_panel_open():
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_travel_from = ""
	_show()


## Abierto desde un portal: los portales descubiertos se pueden elegir.
func open_travel(from_portal: String) -> void:
	_travel_from = from_portal
	_show()


func _show() -> void:
	var player: Node3D = _player()
	if player:
		_center = Vector2(player.global_position.x, player.global_position.z)
	visible = true
	_title.text = "VIAJAR POR LOS PORTALES" if not _travel_from.is_empty() else "MAPA DEL MUNDO"
	_hint.text = ("Clic en un portal: viajar · " if not _travel_from.is_empty() else "") \
			+ "Rueda: zoom · Arrastrar: mover · Clic derecho: centrar · Tab: cerrar"
	world_map.get_map_texture()
	sfx.play("page")
	_update_pause()


func close() -> void:
	visible = false
	_dragging = false
	sfx.play("page")
	_update_pause()


func _process(_delta: float) -> void:
	if visible:
		_view.queue_redraw()


# --- Coordenadas -----------------------------------------------------------

func _scale() -> float:
	return minf(_view.size.x, _view.size.y) / world_map.WORLD_SIZE * _zoom


func _to_view(world_xz: Vector2) -> Vector2:
	return (world_xz - _center) * _scale() + _view.size / 2.0


func _to_world(view_pos: Vector2) -> Vector2:
	return (view_pos - _view.size / 2.0) / _scale() + _center


func _clamp_center() -> void:
	var half: float = world_map.WORLD_SIZE / 2.0
	var visible_half: Vector2 = _view.size / 2.0 / _scale()
	_center.x = clampf(_center.x, -half + minf(visible_half.x, half), half - minf(visible_half.x, half))
	_center.y = clampf(_center.y, -half + minf(visible_half.y, half), half - minf(visible_half.y, half))


# --- Dibujo ----------------------------------------------------------------

func _draw_map() -> void:
	_clamp_center()
	_view.draw_rect(Rect2(Vector2.ZERO, _view.size), PAPER)
	var world: Rect2 = world_map.world_rect()
	var rect := Rect2(_to_view(world.position), world.size * _scale())
	var texture: Texture2D = world_map.get_map_texture()
	if texture:
		_view.draw_texture_rect(texture, rect, false, MAP_TINT)
	else:
		_view.draw_rect(rect, Color(0.42, 0.36, 0.24))
	_view.draw_texture_rect(world_map.get_fog_texture(), rect, false, FOG_TINT)
	_view.draw_rect(rect, Color(INK, 0.9), false, 3.0)

	var font: Font = get_theme_default_font()
	_hover_portal = null
	var mouse: Vector2 = _view.get_local_mouse_position()

	for zone in get_tree().get_nodes_in_group("enemy_zones"):
		var xz := Vector2(zone.global_position.x, zone.global_position.z)
		if world_map.is_explored(xz):
			var pos: Vector2 = _to_view(xz)
			_icon(SKULL_ICON, pos, DANGER_COLOR, 20.0)
			_text(font, pos + Vector2(0, 22), "Nv %d" % zone.level, 13, Color(1.0, 0.6, 0.5))

	for npc in get_tree().get_nodes_in_group("npcs"):
		var icon: Texture2D = npc.get("map_icon")
		if icon == null:
			continue
		var xz := Vector2(npc.global_position.x, npc.global_position.z)
		if world_map.is_explored(xz):
			_icon(icon, _to_view(xz), npc.map_icon_color, 20.0)

	for portal in get_tree().get_nodes_in_group("portals"):
		if not portal.is_discovered():
			continue
		var pos: Vector2 = _to_view(Vector2(portal.global_position.x, portal.global_position.z))
		var hovered: bool = not _travel_from.is_empty() and portal.portal_id != _travel_from and pos.distance_to(mouse) <= PICK_RADIUS
		if hovered:
			_hover_portal = portal
		var size: float = ICON_SIZE * (1.35 if hovered else 1.0)
		if portal.portal_id == _travel_from:
			_view.draw_arc(pos, size * 0.75, 0.0, TAU, 32, Color(PLAYER_COLOR, 0.9), 2.0)
		_icon(PORTAL_ICON, pos, PORTAL_COLOR.lightened(0.3) if hovered else PORTAL_COLOR, size)
		if hovered or _zoom >= 2.5:
			_text(font, pos + Vector2(0, size * 0.75 + 10), portal.display_name, 14, PORTAL_COLOR.lightened(0.4))

	for marker in get_tree().get_nodes_in_group("map_labels"):
		var xz := Vector2(marker.global_position.x, marker.global_position.z)
		if world_map.is_explored(xz):
			_text(font, _to_view(xz) + Vector2(0, -26), marker.get_meta("map_label", ""), 18 if _zoom < 3.0 else 22, LABEL_COLOR)

	_draw_player()
	_draw_compass(font)


func _draw_player() -> void:
	var player: Node3D = _player()
	if player == null:
		return
	var pos: Vector2 = _to_view(Vector2(player.global_position.x, player.global_position.z))
	var facing3: Vector3 = player.global_basis.z
	var dir := Vector2(facing3.x, facing3.z).normalized()
	var side := Vector2(-dir.y, dir.x)
	var arrow := PackedVector2Array([pos + dir * 12.0, pos - dir * 7.0 + side * 7.0, pos - dir * 3.0, pos - dir * 7.0 - side * 7.0])
	_view.draw_colored_polygon(arrow, PLAYER_COLOR)
	_view.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0, 0, 0, 0.9), 1.5)


func _draw_compass(font: Font) -> void:
	var pos := Vector2(_view.size.x - 46, 46)
	_view.draw_circle(pos, 22.0, Color(PAPER, 0.85))
	_view.draw_arc(pos, 22.0, 0.0, TAU, 32, Color(0.7, 0.56, 0.32), 2.0)
	_view.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -18), pos + Vector2(6, 0), pos + Vector2(-6, 0)]), Color(0.85, 0.3, 0.2))
	_view.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, 18), pos + Vector2(6, 0), pos + Vector2(-6, 0)]), Color(0.85, 0.8, 0.7))
	_text(font, pos + Vector2(0, -28), "N", 14, LABEL_COLOR)


func _icon(texture: Texture2D, center: Vector2, color: Color, size: float) -> void:
	var rect := Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size))
	# Sombra para que se lea sobre cualquier fondo.
	_view.draw_texture_rect(texture, Rect2(rect.position + Vector2(1.5, 1.5), rect.size), false, Color(0, 0, 0, 0.75))
	_view.draw_texture_rect(texture, rect, false, color)


func _text(font: Font, center: Vector2, text: String, font_size: int, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := center - Vector2(width / 2.0, -font_size * 0.35)
	_view.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.85))
	_view.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# --- Entrada ---------------------------------------------------------------

func _on_view_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_zoom_at(button.position, 1.2 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2)
			MOUSE_BUTTON_LEFT:
				if button.pressed:
					_dragging = true
					_drag_moved = 0.0
				else:
					_dragging = false
					if _drag_moved < 6.0 and _hover_portal:
						_travel(_hover_portal)
			MOUSE_BUTTON_RIGHT:
				if button.pressed:
					var player: Node3D = _player()
					if player:
						_center = Vector2(player.global_position.x, player.global_position.z)
		_view.accept_event()
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		_drag_moved += motion.relative.length()
		_center -= motion.relative / _scale()
		_view.accept_event()


func _zoom_at(view_pos: Vector2, factor: float) -> void:
	var before: Vector2 = _to_world(view_pos)
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	_center += before - _to_world(view_pos)


func _travel(portal: Node3D) -> void:
	var player: Node3D = _player()
	close()
	if player and player.has_method("teleport_to"):
		player.teleport_to(portal.arrival_point())


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player")


func _other_panel_open() -> bool:
	return get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel != self and panel.visible)


func _update_pause() -> void:
	get_tree().paused = get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel.visible)
