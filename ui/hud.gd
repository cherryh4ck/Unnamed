extends CanvasLayer

## HUD: barra inferior (retrato, vida, experiencia, habilidades), marco del
## enemigo apuntado arriba y mensajes grandes en el centro de la pantalla.

const SkillSlot := preload("res://ui/skill_slot.gd")
const Nameplates := preload("res://ui/nameplates.gd")
const ComboSlot := preload("res://ui/combo_slot.gd")
const POTION := preload("res://item/items/potion_of_health.tres")

## La camara del retrato mira a este punto sobre el hueso de la cabeza.
const PORTRAIT_HEAD_OFFSET: float = 8.0
const PORTRAIT_DISTANCE: float = 300.0
const LOW_HEALTH_RATIO: float = 0.25
## Relleno verde de la barra de vida mientras el personaje esta envenenado.
const POISON_FILL := preload("res://ui/theme/textures/fill_poison.png")

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var xp_bar: ProgressBar = %XPBar
@onready var level_label: Label = %LevelBadge
@onready var portrait_camera: Camera3D = %PortraitCamera
@onready var skill_bar: HBoxContainer = %SkillBar
@onready var buff_bar: HBoxContainer = %BuffBar
@onready var target_frame: PanelContainer = %TargetFrame
@onready var target_name: Label = %TargetName
@onready var target_bar: ProgressBar = %TargetBar
@onready var message_label: Label = %Message
@onready var clock_label: Label = %Clock

var player: CharacterBody3D
var _message_time: float = 0.0
var _respawn_countdown: float = -1.0
var _pulse: float = 0.0
var _buff_labels: Dictionary = {}
var _potion_count: Label
var _potion_icon: TextureRect
## Ranuras del cinturon: [panel, icono, cantidad] por cada una.
var _belt_slots: Array = []
var _poison_style: StyleBoxTexture
var _poisoned_look: bool = false


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	player_stats.health_changed.connect(_on_health_changed)
	player_stats.xp_changed.connect(_on_xp_changed)
	player_stats.leveled_up.connect(_on_leveled_up)
	player_stats.died.connect(_on_died)
	player_stats.respawned.connect(_on_respawned)
	world_time.night_started.connect(func() -> void:
		show_message("Cae la noche: los muertos se vuelven más fuertes", Color(0.6, 0.7, 1.0), 3.5))
	world_time.day_started.connect(func() -> void:
		show_message("Amanece", Color(1.0, 0.85, 0.5), 2.5))
	world_map.portal_discovered.connect(_on_portal_discovered)
	_on_health_changed(player_stats.health, player_stats.get_max_health())
	_on_xp_changed(player_stats.xp, player_stats.xp_for_next_level())
	level_label.text = str(player_stats.level)
	message_label.visible = false
	target_frame.visible = false
	# Carteles de nombre y vida sobre los enemigos (debajo del resto del HUD).
	var plates := Nameplates.new()
	plates.name = "Carteles"
	target_frame.get_parent().add_child(plates)
	target_frame.get_parent().move_child(plates, 0)

	for i in skill_book.skills.size():
		var slot := SkillSlot.new()
		skill_bar.add_child(slot)
		slot.setup(i)
		slot.pressed.connect(_on_skill_slot_pressed)
	skill_book.skill_unlocked.connect(_on_skill_unlocked)
	var combo_slot := ComboSlot.new()
	skill_bar.add_child(combo_slot)
	combo_slot.pressed.connect(func() -> void:
		if player:
			player.use_combo())
	skill_book.combo_unlocked.connect(_on_combo_unlocked)
	_build_potion_slot()
	_build_belt()
	inventory_data.inventory_changed.connect(_update_potion_count.unbind(1))
	inventory_data.inventory_changed.connect(_update_belt.unbind(1))
	inventory_data.belt_changed.connect(_update_belt)
	_update_potion_count()
	_update_belt()
	player_stats.buffs_changed.connect(_rebuild_buffs)
	_poison_style = health_bar.get_theme_stylebox("fill").duplicate()
	_poison_style.texture = POISON_FILL


func _process(delta: float) -> void:
	_update_portrait()
	_update_target()
	_update_message(delta)
	_update_low_health(delta)
	_update_buffs()
	_update_clock()


## Muestra un texto grande en el centro durante unos segundos.
func show_message(text: String, color: Color = Color(1.0, 0.86, 0.45), duration: float = 2.5) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	message_label.visible = true
	message_label.modulate.a = 1.0
	_message_time = duration


# --- Retrato ---------------------------------------------------------------

func _update_portrait() -> void:
	if player == null:
		return
	var head: Vector3 = player.get_node("Player").bone_position("head") + Vector3.UP * PORTRAIT_HEAD_OFFSET
	var forward: Vector3 = player.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	portrait_camera.global_position = head + forward.normalized() * PORTRAIT_DISTANCE + Vector3.UP * 15.0
	portrait_camera.look_at(head, Vector3.UP)


# --- Marco del enemigo -----------------------------------------------------

func _update_target() -> void:
	var enemy: Node3D = null
	if player:
		if is_instance_valid(player.hovered_enemy) and not player.hovered_enemy.dead:
			enemy = player.hovered_enemy
		elif is_instance_valid(player.target_enemy) and not player.target_enemy.dead:
			enemy = player.target_enemy
	target_frame.visible = enemy != null
	if enemy:
		target_name.text = enemy.get_display_name()
		target_name.add_theme_color_override("font_color", enemy.CHAMPION_COLOR if enemy.champion else enemy.level_color())
		target_bar.max_value = enemy.max_health
		target_bar.value = enemy.current_health


func _update_clock() -> void:
	var night: bool = world_time.is_night()
	var sky: String = "" if weather.state == weather.State.CLEAR else " · " + weather.get_state_name()
	clock_label.text = "Día %d · %s%s%s" % [world_time.day, world_time.get_clock_text(), " · Noche" if night else "", sky]
	clock_label.add_theme_color_override("font_color", Color(0.6, 0.72, 1.0) if night else Color(1.0, 0.88, 0.55))


# --- Barras ----------------------------------------------------------------

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [ceili(current), roundi(maximum)]


func _on_xp_changed(current: int, needed: int) -> void:
	xp_bar.max_value = needed
	xp_bar.value = current
	xp_bar.tooltip_text = "Experiencia: %d / %d" % [current, needed]


# La barra de vida se pone verde con veneno, titila naranja mientras se quema
# y late en rojo cuando queda poca vida.
func _update_low_health(delta: float) -> void:
	var poisoned: bool = player_stats.status.is_poisoned() and not player_stats.dead
	if poisoned != _poisoned_look:
		_poisoned_look = poisoned
		if poisoned:
			health_bar.add_theme_stylebox_override("fill", _poison_style)
		else:
			health_bar.remove_theme_stylebox_override("fill")
	_pulse += delta * 6.0
	var glow: float = 0.5 + 0.5 * sin(_pulse)
	if player_stats.status.is_burning() and not player_stats.dead:
		health_bar.modulate = Color(1.0 + glow * 0.5, 1.0 + glow * 0.25, 1.0 - glow * 0.2)
		return
	var ratio: float = health_bar.value / maxf(health_bar.max_value, 1.0)
	if ratio > LOW_HEALTH_RATIO or player_stats.dead:
		health_bar.modulate = Color.WHITE
		return
	health_bar.modulate = Color(1.0 + glow * 0.6, 1.0 - glow * 0.3, 1.0 - glow * 0.3)


# --- Habilidades y mejoras temporales ---------------------------------------

func _on_skill_slot_pressed(index: int) -> void:
	if player:
		player.use_skill(index)


func _on_skill_unlocked(index: int) -> void:
	var skill: SkillData = skill_book.get_skill(index)
	sfx.play("new_spell" if skill.kind == SkillData.Kind.PROJECTILE else "new_skill")
	# Espera a que termine el mensaje de nivel para no taparlo.
	await get_tree().create_timer(1.6, false).timeout
	show_message("Nueva habilidad: %s (tecla %d)" % [skill.name, index + 1], Color(0.6, 0.9, 1.0), 3.0)


# Casilla de pociones al final de la barra: icono, cantidad y tecla Q.
func _build_potion_slot() -> void:
	var separator := VSeparator.new()
	skill_bar.add_child(separator)
	var slot := PanelContainer.new()
	slot.theme_type_variation = &"SlotPanel"
	slot.custom_minimum_size = SkillSlot.SLOT_SIZE
	slot.tooltip_text = "Poción de vida (Q)
Restaura el %d%% de la vida máxima." % roundi(player_stats.POTION_HEAL_PERCENT * 100.0)
	slot.gui_input.connect(func(event: InputEvent) -> void:
		var mouse_event := event as InputEventMouseButton
		if mouse_event and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and player:
			player.drink_potion())
	skill_bar.add_child(slot)

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(holder)
	_potion_icon = TextureRect.new()
	_potion_icon.texture = POTION.texture
	_potion_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_potion_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_potion_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_potion_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_potion_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_potion_icon)

	_potion_count = Label.new()
	_potion_count.add_theme_font_size_override("font_size", 15)
	_potion_count.add_theme_constant_override("outline_size", 5)
	_potion_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_potion_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_potion_count.set_anchors_preset(Control.PRESET_FULL_RECT)
	_potion_count.offset_right = -2.0
	_potion_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_potion_count)

	var key := Label.new()
	key.text = "Q"
	key.position = Vector2(2, -2)
	key.add_theme_font_size_override("font_size", 13)
	key.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	key.add_theme_constant_override("outline_size", 5)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(key)


func _update_potion_count() -> void:
	var count: int = player_stats.count_potions()
	_potion_count.text = str(count)
	_potion_icon.modulate = Color.WHITE if count > 0 else Color(0.3, 0.3, 0.3)


# Cinturon: cuatro ranuras mas chicas despues de la Q, con los otros
# consumibles (teclas W, E, R y T). Se cambian desde el inventario.
func _build_belt() -> void:
	const KEYS := ["W", "E", "R", "T"]
	for i in inventory_data.BELT_SIZE:
		var slot := PanelContainer.new()
		slot.theme_type_variation = &"SlotPanel"
		slot.custom_minimum_size = SkillSlot.SLOT_SIZE * 0.82
		slot.size_flags_vertical = Control.SIZE_SHRINK_END
		slot.gui_input.connect(func(event: InputEvent) -> void:
			var mouse_event := event as InputEventMouseButton
			if mouse_event and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and player:
				player.use_belt(i))
		skill_bar.add_child(slot)
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(holder)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(icon)
		var count := Label.new()
		count.add_theme_font_size_override("font_size", 13)
		count.add_theme_constant_override("outline_size", 5)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.set_anchors_preset(Control.PRESET_FULL_RECT)
		count.offset_right = -2.0
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(count)
		var key := Label.new()
		key.text = KEYS[i]
		key.position = Vector2(2, -2)
		key.add_theme_font_size_override("font_size", 12)
		key.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
		key.add_theme_constant_override("outline_size", 5)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(key)
		_belt_slots.append([slot, icon, count])


func _update_belt() -> void:
	const KEYS := ["W", "E", "R", "T"]
	for i in _belt_slots.size():
		var item: Itemdata = inventory_data.belt_item(i)
		var parts: Array = _belt_slots[i]
		parts[1].texture = item.texture if item else null
		var amount: int = inventory_data.count_item(item) if item else 0
		parts[2].text = str(amount) if item else ""
		parts[1].modulate = Color.WHITE if amount > 0 else Color(0.3, 0.3, 0.3)
		if item:
			parts[0].tooltip_text = "%s (%s)\n%s" % [item.get_display_name(), KEYS[i], item.description]
		else:
			parts[0].tooltip_text = "Cinturón (%s): vacío. En el inventario, apretá %s con el mouse sobre un consumible." % [KEYS[i], KEYS[i]]


func _on_portal_discovered(_id: String, display_name: String) -> void:
	show_message("Portal descubierto: %s\nClic en un portal para viajar" % display_name, Color(0.55, 0.82, 1.0), 3.5)


func _on_combo_unlocked() -> void:
	sfx.play("new_skill")
	await get_tree().create_timer(4.0, false).timeout
	show_message("¡Combos! Armalos con la tecla K", Color(0.6, 0.9, 1.0), 3.0)


func _rebuild_buffs() -> void:
	for child in buff_bar.get_children():
		child.queue_free()
	_buff_labels.clear()
	for id in player_stats.buffs:
		var buff: Dictionary = player_stats.buffs[id]
		var box := PanelContainer.new()
		box.theme_type_variation = &"SlotPanel"
		box.tooltip_text = buff.name
		var icon := TextureRect.new()
		icon.texture = buff.get("icon")
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var time_label := Label.new()
		time_label.add_theme_font_size_override("font_size", 13)
		time_label.add_theme_constant_override("outline_size", 5)
		time_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		time_label.size_flags_vertical = Control.SIZE_SHRINK_END
		time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(time_label)
		buff_bar.add_child(box)
		_buff_labels[id] = time_label
	_update_buffs()


func _update_buffs() -> void:
	for id in _buff_labels:
		if player_stats.buffs.has(id):
			_buff_labels[id].text = str(ceili(player_stats.buffs[id].time_left))


# --- Mensajes --------------------------------------------------------------

func _on_leveled_up(new_level: int) -> void:
	level_label.text = str(new_level)
	show_message("¡Nivel %d!" % new_level)


func _on_died() -> void:
	_respawn_countdown = player.respawn_delay if player else 4.0


func _on_respawned() -> void:
	_respawn_countdown = -1.0
	message_label.visible = false


func _update_message(delta: float) -> void:
	if _respawn_countdown >= 0.0:
		_respawn_countdown = maxf(_respawn_countdown - delta, 0.0)
		message_label.text = "Has muerto\nReaparecés en %d..." % ceili(_respawn_countdown)
		message_label.add_theme_color_override("font_color", Color(0.85, 0.15, 0.1))
		message_label.visible = true
		message_label.modulate.a = 1.0
		return
	if _message_time <= 0.0:
		return
	_message_time -= delta
	message_label.modulate.a = clampf(_message_time / 0.6, 0.0, 1.0)
	if _message_time <= 0.0:
		message_label.visible = false
