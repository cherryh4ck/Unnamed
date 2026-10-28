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


func _strike(skill: SkillData, target: Node3D) -> void:
	await get_tree().create_timer(0.25, false).timeout
	if not is_instance_valid(target) or target.dead or player_stats.dead:
		return
	var hit: Dictionary = player_stats.roll_damage()
	target.take_damage(hit.amount * skill.damage_multiplier, hit.crit)
	sfx.play_at("hit", target.global_position, 3.0)
	Effects.burst(character.get_parent(), target.global_position + Vector3.UP * 200.0, skill.effect_color, 45)


func _whirlwind(skill: SkillData) -> void:
	Effects.ring(character.get_parent(), character.global_position, skill.effect_color, skill.radius)
	await get_tree().create_timer(0.2, false).timeout
	if player_stats.dead:
		return
	var hit_any: bool = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = enemy.global_position - character.global_position
		offset.y = 0.0
		if offset.length() <= skill.radius + enemy.data.collision_radius:
			var hit: Dictionary = player_stats.roll_damage()
			enemy.take_damage(hit.amount * skill.damage_multiplier, hit.crit)
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
	ball.max_range = skill.max_range
	ball.radius = skill.radius
	ball.damage_multiplier = skill.damage_multiplier
	ball.color = skill.effect_color
	character.get_parent().add_child(ball)
	ball.global_position = character.global_position + Vector3.UP * 220.0 + direction * 80.0


func _buff(skill: SkillData) -> void:
	player_stats.add_buff(skill.name, {
		"name": skill.name,
		"icon": skill.icon,
		"duration": skill.buff_duration,
		"damage_mult": skill.buff_damage_multiplier,
		"attack_speed_mult": skill.buff_attack_speed_multiplier,
		"defense": skill.buff_defense,
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
	var hit: Dictionary = player_stats.roll_damage()
	if player_stats.is_ranged():
		_shoot_bolt(to_target.normalized(), hit)
		return
	if to_target.length() > character.attack_range * REACH_TOLERANCE:
		return
	target.take_damage(hit.amount, hit.crit)
	sfx.play_at("hit", target.global_position)


func _shoot_bolt(direction: Vector3, hit: Dictionary) -> void:
	var bolt: Node3D = BOLT.new()
	bolt.direction = direction
	bolt.damage = hit.amount
	bolt.crit = hit.crit
	bolt.max_range = character.ranged_attack_range + 400.0
	character.get_parent().add_child(bolt)
	bolt.global_position = character.global_position + Vector3.UP * 230.0 + direction * 60.0
	sfx.play_at("bow_shoot", character.global_position)
