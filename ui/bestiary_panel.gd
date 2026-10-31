extends Control

## Bestiario (tecla B): los tipos de enemigo con lo que se sabe de cada uno.
## Los que todavia no se vieron aparecen como "???" con la silueta en negro.
## Del elegido muestra el modelo girando, cuantos se derrotaron, el nivel mas
## alto visto, donde vive, como ataca y sus resistencias (con debilidades).
## Abajo, las regiones liberadas en la dificultad actual (un campeon
## derrotado en cada una completa la dificultad). Pausa el juego.

const GOLD := Color(0.95, 0.8, 0.48)
const TEXT := Color(0.88, 0.82, 0.68)
const DIM := Color(0.6, 0.55, 0.46)
const WEAK := Color(1.0, 0.5, 0.35)
const STRONG := Color(0.55, 0.8, 1.0)
const BODY_NAMES := ["Carne y hueso", "Hueso", "Insecto", "No-muerto"]
const RESIST_NAMES := {Damage.Type.MAGIC: "Magia", Damage.Type.POISON: "Veneno", Damage.Type.FIRE: "Fuego"}
const PORTRAIT_SIZE := Vector2i(300, 300)

var _list: VBoxContainer
var _count_label: Label
var _name_label: Label
var _details: RichTextLabel
var _regions_label: RichTextLabel
var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _selected: EnemyData
var _buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_panels")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 500)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "BESTIARIO"
	title.theme_type_variation = &"HeaderLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_count_label = Label.new()
	_count_label.theme_type_variation = &"DimLabel"
	header.add_child(_count_label)
	box.add_child(header)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(230, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	var portrait_frame := PanelContainer.new()
	portrait_frame.theme_type_variation = &"SlotPanel"
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(portrait_frame)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(PORTRAIT_SIZE)
	container.stretch = true
	portrait_frame.add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.size = PORTRAIT_SIZE
	container.add_child(_viewport)
	_build_stage()

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	body.add_child(info)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 26)
	_name_label.add_theme_color_override("font_color", GOLD)
	info.add_child(_name_label)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = true
	_details.scroll_active = false
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_theme_color_override("default_color", TEXT)
	info.add_child(_details)

	_regions_label = RichTextLabel.new()
	_regions_label.bbcode_enabled = true
	_regions_label.fit_content = true
	_regions_label.scroll_active = false
	_regions_label.add_theme_color_override("default_color", DIM)
	box.add_child(_regions_label)

	var hint := Label.new()
	hint.text = "Clic en un enemigo para verlo · B o Esc: cerrar"
	hint.theme_type_variation = &"DimLabel"
	hint.add_theme_font_size_override("font_size", 13)
	box.add_child(hint)

	bestiary.changed.connect(func() -> void:
		if visible:
			_refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_bestiary"):
		if visible:
			close()
		elif not _other_panel_open():
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	sfx.play("page")
	_refresh()
	_update_pause()


func close() -> void:
	visible = false
	sfx.play("page")
	_clear_model()
	_update_pause()


func _process(delta: float) -> void:
	if visible and _pivot:
		_pivot.rotate_y(delta * 0.6)


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	_buttons.clear()
	var types: Array[EnemyData] = bestiary.get_types()
	var known: int = 0
	for data in types:
		var entry: Dictionary = bestiary.get_entry(data.name)
		if not entry.is_empty():
			known += 1
		var button := Button.new()
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = ("%s  ·  %d" % [data.name, entry.kills]) if not entry.is_empty() else "???"
		button.custom_minimum_size = Vector2(0, 34)
		button.modulate = Color.WHITE if not entry.is_empty() else Color(0.6, 0.6, 0.6)
		button.pressed.connect(_select.bind(data))
		_list.add_child(button)
		_buttons[data] = button
	_count_label.text = "%d de %d descubiertos" % [known, types.size()]
	_refresh_regions()
	if _selected == null or not _buttons.has(_selected):
		_selected = types[0] if not types.is_empty() else null
	if _selected:
		_select(_selected)


func _select(data: EnemyData) -> void:
	_selected = data
	for other in _buttons:
		_buttons[other].set_pressed_no_signal(other == data)
	var entry: Dictionary = bestiary.get_entry(data.name)
	_show_model(data, not entry.is_empty())
	if entry.is_empty():
		_name_label.text = "???"
		_details.text = "[color=#%s]Todavía no te cruzaste con esta criatura.[/color]\n\n%s" % [DIM.to_html(false), _where_text(data)]
		return
	_name_label.text = data.name
	var lines: PackedStringArray = []
	lines.append("Derrotados: [color=#%s]%d[/color]%s" % [GOLD.to_html(false), entry.kills,
			("  (campeones: %d)" % entry.champions) if entry.champions > 0 else ""])
	lines.append("Nivel más alto visto: %d" % entry.max_level)
	lines.append("Cuerpo: %s" % BODY_NAMES[data.body])
	lines.append("Ataque: %s" % ("a distancia" if data.shoots else "cuerpo a cuerpo") + _conversion_text(data))
	lines.append("Daño base: %d – %d · Vida base: %d" % [data.min_damage, data.max_damage, roundi(data.max_health)])
	lines.append(_where_text(data))
	lines.append("")
	lines.append(_resist_text(data))
	_details.text = "\n".join(lines)


func _conversion_text(data: EnemyData) -> String:
	if data.attack_conversion <= 0.0:
		return ""
	return " (con %s)" % RESIST_NAMES.get(data.attack_damage_type, "magia").to_lower()


# Zonas del mapa donde aparece (las regiones se nombran sin el numero).
func _where_text(data: EnemyData) -> String:
	var regions: PackedStringArray = []
	for zone in get_tree().get_nodes_in_group("enemy_zones"):
		if data in zone.enemy_types:
			var region: String = zone.name.rstrip("0123456789")
			if region not in regions:
				regions.append(region)
	if regions.is_empty():
		return "Dónde: en ningún lugar conocido"
	return "Dónde: %s" % ", ".join(regions)


func _resist_text(data: EnemyData) -> String:
	var parts: PackedStringArray = []
	var weak: PackedStringArray = []
	var strong: PackedStringArray = []
	var resistances: Dictionary = data.get_resistances()
	for type in resistances:
		var value: float = resistances[type]
		var type_name: String = RESIST_NAMES[type]
		var color: Color = WEAK if value < 0.0 else (STRONG if value > 0.0 else DIM)
		parts.append("%s [color=#%s]%+d%%[/color]" % [type_name, color.to_html(false), roundi(value)])
		if value < 0.0:
			weak.append(type_name.to_lower())
		elif value >= 25.0:
			strong.append(type_name.to_lower())
	var text: String = "Resistencias: %s · Físico: defensa %d" % [", ".join(parts), data.defense]
	if not weak.is_empty():
		text += "\n[color=#%s]Débil a: %s[/color]" % [WEAK.to_html(false), ", ".join(weak)]
	if not strong.is_empty():
		text += "\n[color=#%s]Resiste: %s[/color]" % [STRONG.to_html(false), ", ".join(strong)]
	return text


func _refresh_regions() -> void:
	var parts: PackedStringArray = []
	for region in bestiary.REGIONS:
		var done: bool = region in bestiary.regions_cleared
		parts.append("[color=#%s]%s[/color]" % [(GOLD if done else DIM).to_html(false), region])
	var text: String = "Regiones liberadas en %s (%d de %d): %s" % [difficulty.get_level_name(),
			bestiary.regions_cleared.size(), bestiary.REGIONS.size(), "  ·  ".join(parts)]
	if bestiary.regions_cleared.size() >= bestiary.REGIONS.size():
		text += "
[color=#%s]¡Dificultad completada![/color]" % GOLD.to_html(false)
	else:
		text += "
Derrotá a un campeón en cada región para completar la dificultad."
	_regions_label.text = text


# --- Retrato 3D --------------------------------------------------------------

func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.7, 0.62)
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.1
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.6, 0.75, 1.0)
	_viewport.add_child(rim)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.far = 20000.0
	_viewport.add_child(_camera)


func _clear_model() -> void:
	if _pivot:
		_pivot.queue_free()
		_pivot = null


func _show_model(data: EnemyData, known: bool) -> void:
	_clear_model()
	if data.model == null:
		return
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	var model: Node3D = data.model.instantiate()
	model.scale = Vector3.ONE * data.model_scale
	model.position.y = data.model_offset_y * data.model_scale
	_pivot.add_child(model)
	var meshes: Array = model.find_children("*", "MeshInstance3D", true, false)
	var silhouette := StandardMaterial3D.new()
	silhouette.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	silhouette.albedo_color = Color(0.03, 0.025, 0.02)
	for mesh in meshes:
		if not known:
			mesh.material_override = silhouette
		elif data.tint != Color.WHITE:
			_tint(mesh, data.tint)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if player and not data.idle_animation.is_empty() and player.has_animation(data.idle_animation):
		player.play(data.idle_animation)
	_frame.call_deferred(meshes)


# Igual que enemi.gd: copia los materiales con el color multiplicado.
func _tint(mesh: MeshInstance3D, tint: Color) -> void:
	for i in mesh.get_surface_override_material_count():
		var base: Material = mesh.get_active_material(i)
		if base is BaseMaterial3D:
			var tinted: BaseMaterial3D = base.duplicate()
			tinted.albedo_color = tinted.albedo_color * tint
			mesh.set_surface_override_material(i, tinted)


# La camara encuadra la caja de todas las mallas (de frente, un poco desde arriba).
func _frame(meshes: Array) -> void:
	if _pivot == null:
		return
	var box := AABB()
	var first: bool = true
	for mesh in meshes:
		if not is_instance_valid(mesh):
			continue
		var global_box: AABB = mesh.global_transform * mesh.get_aabb()
		box = global_box if first else box.merge(global_box)
		first = false
	if first:
		return
	var center: Vector3 = box.get_center()
	var radius: float = maxf(box.size.y, maxf(box.size.x, box.size.z)) * 0.6
	var distance: float = radius / tan(deg_to_rad(_camera.fov * 0.5))
	_camera.position = center + Vector3(0.0, radius * 0.35, distance)
	_camera.look_at(center, Vector3.UP)


func _other_panel_open() -> bool:
	return get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel != self and panel.visible)


func _update_pause() -> void:
	get_tree().paused = get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel.visible)
