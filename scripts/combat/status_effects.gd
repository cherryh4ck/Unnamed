class_name StatusEffects
extends RefCounted

## Veneno y quemadura activos sobre un personaje (jugador o enemigo).
## Cada Damage.TICK segundos tick() devuelve el daño que toca; quien lo usa lo
## resta de su vida. Un veneno nuevo suma al pendiente y reinicia la duracion.

var poison_left: float = 0.0
var poison_time: float = 0.0
var burn_left: float = 0.0
var burn_time: float = 0.0
var _tick_timer: float = 0.0


func add_poison(amount: float) -> void:
	if amount <= 0.0:
		return
	poison_left += amount
	poison_time = Damage.POISON_DURATION


func add_burn(amount: float) -> void:
	if amount <= 0.0:
		return
	burn_left += amount
	burn_time = Damage.BURN_DURATION


func is_poisoned() -> bool:
	return poison_left > 0.01


func is_burning() -> bool:
	return burn_left > 0.01


func clear() -> void:
	poison_left = 0.0
	poison_time = 0.0
	burn_left = 0.0
	burn_time = 0.0
	_tick_timer = 0.0


## Avanza el tiempo. Devuelve {Damage.Type: daño} de este tick (vacio si no toca).
func tick(delta: float) -> Dictionary:
	if not is_poisoned() and not is_burning():
		_tick_timer = 0.0
		return {}
	_tick_timer += delta
	if _tick_timer < Damage.TICK:
		return {}
	_tick_timer -= Damage.TICK

	var result := {}
	if is_poisoned():
		var amount: float = poison_left * Damage.TICK / maxf(poison_time, Damage.TICK)
		poison_left -= amount
		poison_time -= Damage.TICK
		if poison_time <= 0.001:
			poison_left = 0.0
		result[Damage.Type.POISON] = amount
	if is_burning():
		var amount: float = burn_left * Damage.TICK / maxf(burn_time, Damage.TICK)
		burn_left -= amount
		burn_time -= Damage.TICK
		if burn_time <= 0.001:
			burn_left = 0.0
		result[Damage.Type.FIRE] = amount
	return result
