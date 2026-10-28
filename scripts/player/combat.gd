extends Node

## Ataque basico del jugador. Movement.gd lo llama cuando el objetivo
## esta en rango; aca se controla el ritmo de golpes y se aplica el daño.

signal attack_started(interval: float)

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


func _deliver_hit(target: Node3D, delay: float) -> void:
	# process_always = false: si se pausa el juego, el golpe tambien espera.
	await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(target) or target.dead or player_stats.dead:
		return
	var to_target: Vector3 = target.global_position - character.global_position
	to_target.y = 0.0
	if to_target.length() > character.attack_range * REACH_TOLERANCE:
		return
	var hit: Dictionary = player_stats.roll_damage()
	target.take_damage(hit.amount, hit.crit)
	sfx.play_at("hit", target.global_position)
