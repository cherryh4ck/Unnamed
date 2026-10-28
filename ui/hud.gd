extends CanvasLayer

## HUD: barra inferior (retrato, vida, experiencia, habilidades), marco del
## enemigo apuntado arriba y mensajes grandes en el centro de la pantalla.

const SkillSlot := preload("res://ui/skill_slot.gd")

## Altura de la cabeza del personaje (para la camara del retrato).
const PORTRAIT_HEAD_HEIGHT: float = 325.0
const PORTRAIT_DISTANCE: float = 300.0
const LOW_HEALTH_RATIO: float = 0.25

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

var player: CharacterBody3D
var _message_time: float = 0.0
var _respawn_countdown: float = -1.0
var _pulse: float = 0.0
var _buff_labels: Dictionary = {}


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	player_stats.health_changed.connect(_on_health_changed)
	player_stats.xp_changed.connect(_on_xp_changed)
	player_stats.leveled_up.connect(_on_leveled_up)
	player_stats.died.connect(_on_died)
	player_stats.respawned.connect(_on_respawned)
	_on_health_changed(player_stats.health, player_stats.get_max_health())
	_on_xp_changed(player_stats.xp, player_stats.xp_for_next_level())
	level_label.text = str(player_stats.level)
	message_label.visible = false
	target_frame.visible = false

	for i in skill_book.skills.size():
		var slot := SkillSlot.new()
		skill_bar.add_child(slot)
		slot.setup(i)
		slot.pressed.connect(_on_skill_slot_pressed)
	skill_book.skill_unlocked.connect(_on_skill_unlocked)
	player_stats.buffs_changed.connect(_rebuild_buffs)


func _process(delta: float) -> void:
	_update_portrait()
	_update_target()
	_update_message(delta)
	_update_low_health(delta)
	_update_buffs()


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
	var head: Vector3 = player.global_position + Vector3.UP * PORTRAIT_HEAD_HEIGHT
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
		target_bar.max_value = enemy.max_health
		target_bar.value = enemy.current_health


# --- Barras ----------------------------------------------------------------

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [ceili(current), roundi(maximum)]


func _on_xp_changed(current: int, needed: int) -> void:
	xp_bar.max_value = needed
	xp_bar.value = current
	xp_bar.tooltip_text = "Experiencia: %d / %d" % [current, needed]


# La barra de vida late en rojo cuando queda poca vida.
func _update_low_health(delta: float) -> void:
	var ratio: float = health_bar.value / maxf(health_bar.max_value, 1.0)
	if ratio > LOW_HEALTH_RATIO or player_stats.dead:
		health_bar.modulate = Color.WHITE
		return
	_pulse += delta * 6.0
	var glow: float = 0.5 + 0.5 * sin(_pulse)
	health_bar.modulate = Color(1.0 + glow * 0.6, 1.0 - glow * 0.3, 1.0 - glow * 0.3)


# --- Habilidades y mejoras temporales ---------------------------------------

func _on_skill_slot_pressed(index: int) -> void:
	if player:
		player.use_skill(index)


func _on_skill_unlocked(index: int) -> void:
	var skill: SkillData = skill_book.get_skill(index)
	sfx.play("new_skill")
	# Espera a que termine el mensaje de nivel para no taparlo.
	await get_tree().create_timer(1.6, false).timeout
	show_message("Nueva habilidad: %s (tecla %d)" % [skill.name, index + 1], Color(0.6, 0.9, 1.0), 3.0)


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
