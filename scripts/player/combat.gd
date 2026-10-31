extends Node

## Ataque basico y habilidades del jugador. Movement.gd lo llama cuando el
## objetivo esta en rango; aca se controla el ritmo de golpes y se aplica el daño.

signal attack_started(interval: float)
signal skill_animation(anim_name: String, speed: float)

const FIREBALL := preload("res://scripts/skills/fireball.gd")
const BOLT := preload("res://scripts/skills/bolt.gd")
## Tras usar una habilidad, el ataque basico espera al menos este tiempo.
const SKILL_LOCKOUT: float = 0.5
## Pausa entre las habilidades de un combo.
const COMBO_STEP_DELAY: float = 0.55

## Momento del impacto dentro del intervalo de ataque (0 = inicio, 1 = fin).
const HIT_MOMENT: float = 0.45
## Margen extra de alcance al momento del impacto (el enemigo se puede alejar un poco).
const REACH_TOLERANCE: float = 1.3
## Color del rayo arcano del ataque basico del mago.
const ARCANE_COLOR := Color(0.55, 0.65, 1.0)
## Altura desde la que caen la lluvia de virotes y el meteoro.
const RAIN_HEIGHT: float = 1400.0

@onready var character: CharacterBody3D = get_parent()

var _cooldown: float = 0.0


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func can_attack() -> bool:
	return _cooldown <= 0.0 and not player_stats.dead


func try_attack(target: Node3D) -> bool:
	if not can_attack():
		return false
	var interval: float = 1.0 / player_stats.get_attack_speed()
	_cooldown = interval
	attack_started.emit(interval)
	_deliver_hit(target, interval * HIT_MOMENT)
	return true


## Usa la habilidad del slot indicado. aim_point es el punto del mouse en el
## piso y target el enemigo marcado (puede ser null segun la habilidad).
func use_skill(index: int, aim_point: Vector3, target: Node3D) -> bool:
	var skill: SkillData = skill_book.get_skill(index)
	if skill == null or not skill_book.is_ready(index) or player_stats.dead:
		return false
	skill_book.start_cooldown(index)
	_perform(skill, aim_point, target)
	return true


## Ejecuta el combo armado: sus habilidades una detras de otra, con su propia
## recarga (no gasta la recarga de cada habilidad por separado).
func use_combo(aim_point: Vector3, target: Node3D) -> bool:
	if not skill_book.is_combo_ready() or player_stats.dead:
		return false
	skill_book.start_combo_cooldown()
	_run_combo(skill_book.combo.duplicate(), aim_point, target)
	return true


func _run_combo(indices: Array, aim_point: Vector3, target: Node3D) -> void:
	for i in indices.size():
		if player_stats.dead:
			return
		var skill: SkillData = skill_book.get_skill(indices[i])
		# Si el objetivo murio a mitad del combo, los golpes se saltean.
		var target_ok: bool = is_instance_valid(target) and not target.dead
		if skill.kind != SkillData.Kind.STRIKE or target_ok:
			var aim: Vector3 = target.global_position if target_ok else aim_point
			_perform(skill, aim, target if target_ok else null)
		if i < indices.size() - 1:
			await get_tree().create_timer(COMBO_STEP_DELAY, false).timeout


func _perform(skill: SkillData, aim_point: Vector3, target: Node3D) -> void:
	_cooldown = maxf(_cooldown, SKILL_LOCKOUT)
	skill_animation.emit(skill.animation, skill.animation_speed)
	if not skill.sound.is_empty():
		sfx.play_at(skill.sound, character.global_position)
	match skill.kind:
		SkillData.Kind.STRIKE:
			_strike(skill, target)
		SkillData.Kind.WHIRLWIND:
			_whirlwind(skill)
		SkillData.Kind.PROJECTILE:
			_fireball(skill, aim_point)
		SkillData.Kind.BUFF:
			_buff(skill)
		SkillData.Kind.VOLLEY:
			_volley(skill, aim_point)
		SkillData.Kind.RAIN:
			_rain(skill, aim_point)


func _strike(skill: SkillData, target: Node3D) -> void:
	await get_tree().create_timer(0.25, false).timeout
	if not is_instance_valid(target) or target.dead or player_stats.dead:
		return
	target.take_hit(_roll_skill_hit(skill))
	sfx.play_at("hit", target.global_position, 3.0)
	Effects.heavy_impact(character.get_parent(), target.global_position, skill.effect_color)


func _whirlwind(skill: SkillData) -> void:
	Effects.ring(character.get_parent(), character.global_position, skill.effect_color, skill.radius)
	if skill.spin:
		Effects.whirl(character, skill.effect_color, skill.radius * 0.8)
	else:
		Effects.shockwave(character.get_parent(), character.global_position, skill.effect_color, skill.radius, 0.45)
		if skill.damage_type == Damage.Type.FIRE:
			Effects.fire_explosion(character.get_parent(), character.global_position, skill.radius * 0.6)
		else:
			Effects.dust_puff(character.get_parent(), character.global_position, skill.radius * 0.7)
	await get_tree().create_timer(0.2, false).timeout
	if player_stats.dead:
		return
	var hit_any: bool = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = enemy.global_position - character.global_position
		offset.y = 0.0
		if offset.length() <= skill.radius + enemy.body_radius():
			enemy.take_hit(_roll_skill_hit(skill))
			hit_any = true
	if hit_any:
		sfx.play_at("hit", character.global_position, 2.0)


func _fireball(skill: SkillData, aim_point: Vector3) -> void:
	var direction: Vector3 = aim_point - character.global_position
	direction.y = 0.0
	if direction.length() < 1.0:
		direction = character.global_transform.basis.z
	direction = direction.normalized()
	character.rotation.y = atan2(direction.x, direction.z)
	await get_tree().create_timer(0.2, false).timeout
	if player_stats.dead:
		return
	var ball: Node3D = FIREBALL.new()
	ball.direction = direction
	ball.skill = skill
	ball.color = skill.effect_color
	Effects.add_at(character.get_parent(), ball, character.global_position + Vector3.UP * 220.0 + direction * 80.0)


# Virotes (o rayos) en abanico hacia el mouse; cada uno daña al primero que toca.
func _volley(skill: SkillData, aim_point: Vector3) -> void:
	var direction: Vector3 = aim_point - character.global_position
	direction.y = 0.0
	if direction.length() < 1.0:
		direction = character.global_transform.basis.z
	direction = direction.normalized()
	character.rotation.y = atan2(direction.x, direction.z)
	await get_tree().create_timer(0.15, false).timeout
	if player_stats.dead:
		return
	var count: int = maxi(skill.count, 1)
	for i in count:
		var offset: float = 0.0 if count == 1 else lerpf(-skill.spread_deg, skill.spread_deg, float(i) / (count - 1)) / 2.0
		var bolt: Node3D = _make_bolt(direction.rotated(Vector3.UP, deg_to_rad(offset)), _roll_skill_hit(skill), skill.max_range)
		if skill.damage_type != Damage.Type.PHYSICAL:
			bolt.glow = skill.effect_color
		Effects.add_at(character.get_parent(), bolt, character.global_position + Vector3.UP * 230.0 + bolt.direction * 60.0)
	if not skill.spell:
		sfx.play_at("bow_shoot", character.global_position)


# Se marca el lugar, y al rato cae: virotes o un meteoro, con daño en area.
func _rain(skill: SkillData, aim_point: Vector3) -> void:
	var center := Vector3(aim_point.x, 0.0, aim_point.z)
	var parent: Node = character.get_parent()
	Effects.ring(parent, center, skill.effect_color, skill.radius)
	Effects.ground_glow(parent, center + Vector3.UP * 4.0, Effects.GLOW, skill.effect_color, skill.radius * 2.0, skill.delay + 0.3)
	if skill.damage_type == Damage.Type.FIRE:
		# Meteoro: la bola de fuego cae desde arriba y explota al tocar el piso.
		var ball: Node3D = FIREBALL.new()
		ball.direction = (Vector3.DOWN * RAIN_HEIGHT + Vector3(-300.0, 0.0, -200.0)).normalized()
		ball.skill = skill
		ball.color = skill.effect_color
		ball.travel = RAIN_HEIGHT / absf(ball.direction.y)
		ball.speed = ball.travel / maxf(skill.delay, 0.1)
		Effects.add_at(parent, ball, center - ball.direction * ball.travel)
		return
	# Lluvia de virotes: caen de a poco en el area y el daño entra todo junto.
	for i in maxi(skill.count, 1):
		var spot: Vector2 = Vector2.from_angle(randf() * TAU) * sqrt(randf()) * skill.radius
		var bolt: Node3D = _make_bolt(Vector3(0.12, -1.0, 0.08).normalized(), {}, RAIN_HEIGHT * 1.02)
		bolt.harmless = true
		bolt.speed = RAIN_HEIGHT / maxf(skill.delay, 0.1)
		Effects.add_at(parent, bolt, center + Vector3(spot.x, 0.0, spot.y) - bolt.direction * RAIN_HEIGHT)
	await get_tree().create_timer(skill.delay, false).timeout
	if player_stats.dead:
		return
	Effects.dust_puff(parent, center, skill.radius * 0.6)
	var hit_any: bool = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = enemy.global_position - center
		offset.y = 0.0
		if not enemy.dead and offset.length() <= skill.radius + enemy.body_radius():
			enemy.take_hit(_roll_skill_hit(skill))
			hit_any = true
	if hit_any:
		sfx.play_at("hit", center, 2.0)


func _make_bolt(direction: Vector3, hit: Dictionary, max_range: float) -> Node3D:
	var bolt: Node3D = BOLT.new()
	bolt.direction = direction
	bolt.hit = hit
	bolt.max_range = max_range if max_range > 0.0 else character.ranged_attack_range + 400.0
	return bolt


## Tirada de daño de una habilidad: hechizo o golpe con el arma.
func _roll_skill_hit(skill: SkillData) -> Dictionary:
	return player_stats.roll_skill(skill)


func _buff(skill: SkillData) -> void:
	player_stats.add_buff(skill.name, {
		"name": skill.name,
		"icon": skill.icon,
		"duration": skill.buff_duration,
		"damage_mult": skill.buff_damage_multiplier,
		"attack_speed_mult": skill.buff_attack_speed_multiplier,
		"defense": skill.buff_defense,
		"resist": skill.buff_resistance,
	})
	Effects.aura(character.get_parent(), character.global_position, skill.effect_color)
	floating_text.spawn(character.global_position + Vector3.UP * 450.0, skill.name, skill.effect_color, 22)


func _deliver_hit(target: Node3D, delay: float) -> void:
	# process_always = false: si se pausa el juego, el golpe tambien espera.
	await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(target) or target.dead or player_stats.dead:
		return
	var to_target: Vector3 = target.global_position - character.global_position
	to_target.y = 0.0
	var hit: Dictionary = player_stats.roll_basic_attack()
	if player_stats.is_ranged():
		_shoot_bolt(to_target.normalized(), hit)
		return
	if to_target.length() > character.attack_range * REACH_TOLERANCE + character.extra_reach(target):
		return
	target.take_hit(hit)
	sfx.play_at("hit", target.global_position)


func _shoot_bolt(direction: Vector3, hit: Dictionary) -> void:
	var bolt: Node3D = _make_bolt(direction, hit, 0.0)
	var spell: bool = player_stats.uses_spell_attack()
	if spell:
		bolt.glow = ARCANE_COLOR
	Effects.add_at(character.get_parent(), bolt, character.global_position + Vector3.UP * 230.0 + direction * 60.0)
	sfx.play_at("unknown_spell" if spell else "bow_shoot", character.global_position, -6.0 if spell else 0.0)
