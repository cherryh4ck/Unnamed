extends Control

## Carteles sobre los enemigos: nombre, nivel y barra de vida. Se ven en el
## que esta bajo el mouse, en el marcado, en los que recibieron un golpe hace
## poco y en los campeones; mientras se mantiene Alt, en todos los que se ven.

## Segundos que sigue el cartel despues de un golpe.
const SHOW_AFTER_HIT: float = 4.0
const MAX_DISTANCE: float = 3200.0
## Cuanto mas arriba de la cabeza va el cartel (en unidades del mundo).
const ABOVE_HEAD: float = 60.0
const BAR_SIZE := Vector2(96, 7)
const NAME_COLOR := Color(0.92, 0.86, 0.76)
const POINTED_COLOR := Color(1.0, 0.97, 0.9)
const FONT_SIZE: int = 14


class Plate:
	var box := VBoxContainer.new()
	var label := Label.new()
	var bar := ProgressBar.new()


var _plates: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var shown: Dictionary = {}
	if camera and player:
		var show_all: bool = Input.is_physical_key_pressed(KEY_ALT)
		var now: float = Time.get_ticks_msec() / 1000.0
		var screen_rect: Rect2 = get_viewport_rect()
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var pointed: bool = enemy == player.hovered_enemy or enemy == player.target_enemy
			if not (pointed or show_all or enemy.champion or now - enemy.last_hit_at < SHOW_AFTER_HIT):
				continue
			if enemy.global_position.distance_to(player.global_position) > MAX_DISTANCE:
				continue
			var head: Vector3 = enemy.global_position + Vector3.UP * (enemy.head_height() + ABOVE_HEAD)
			if camera.is_position_behind(head):
				continue
			# Si se le ven los pies pero la cabeza queda fuera de la pantalla,
			# el cartel se queda pegado al borde de arriba.
			var feet: Vector2 = camera.unproject_position(enemy.global_position)
			if not screen_rect.has_point(feet):
				continue
			var screen: Vector2 = camera.unproject_position(head)
			shown[enemy] = true
			if not _plates.has(enemy):
				_plates[enemy] = _make_plate()
			var plate: Plate = _plates[enemy]
			_fill(plate, enemy, pointed)
			var top_left: Vector2 = screen - Vector2(plate.box.size.x / 2.0, plate.box.size.y)
			plate.box.position = top_left.clamp(Vector2(4, 4), screen_rect.size - plate.box.size - Vector2(4, 4)).round()
	for enemy in _plates.keys():
		if not shown.has(enemy):
			_plates[enemy].box.queue_free()
			_plates.erase(enemy)


func _make_plate() -> Plate:
	var plate := Plate.new()
	plate.box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.box.add_theme_constant_override("separation", 1)
	plate.label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.label.add_theme_font_size_override("font_size", FONT_SIZE)
	plate.label.add_theme_constant_override("outline_size", 4)
	plate.label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.bar.theme_type_variation = &"EnemyBar"
	plate.bar.custom_minimum_size = BAR_SIZE
	plate.bar.show_percentage = false
	plate.bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.box.add_child(plate.label)
	plate.box.add_child(plate.bar)
	add_child(plate.box)
	return plate


func _fill(plate: Plate, enemy: Node3D, pointed: bool) -> void:
	var text: String = "%s · Nv %d" % [enemy.get_title(), enemy.level]
	if plate.label.text != text:
		plate.label.text = text
		plate.box.reset_size()
	var color: Color = POINTED_COLOR if pointed else NAME_COLOR
	if enemy.champion:
		color = enemy.CHAMPION_COLOR.lightened(0.2) if pointed else enemy.CHAMPION_COLOR
	plate.label.add_theme_color_override("font_color", color)
	plate.bar.max_value = enemy.max_health
	plate.bar.value = enemy.current_health
