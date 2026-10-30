extends Node

## Autoload con las habilidades del jugador: cuales tiene aprendidas
## (segun el nivel) y cuanto le falta a cada una para recargarse.
## La ejecucion de cada habilidad esta en scripts/player/combat.gd.

signal skill_unlocked(index: int)
signal skill_used(index: int)
signal combo_changed
signal combo_unlocked

## Nivel a partir del cual se pueden armar combos.
const COMBO_UNLOCK_LEVEL: int = 4
const COMBO_MAX_SKILLS: int = 3
## La recarga del combo es la suma de las recargas de sus habilidades por este factor.
const COMBO_COOLDOWN_FACTOR: float = 0.75

var skills: Array[SkillData] = []
var _cooldown_left: Array[float] = []
var _cooldown_total: Array[float] = []
## Indices de las habilidades del combo, en orden de ejecucion.
var combo: Array[int] = []
var _combo_left: float = 0.0
var _combo_total: float = 1.0


func _ready() -> void:
	set_class(player_stats.class_id)
	player_stats.leveled_up.connect(_on_leveled_up)


## Carga las habilidades de la clase (ver scripts/player/player_classes.gd).
func set_class(class_id: String) -> void:
	skills.clear()
	_cooldown_left.clear()
	_cooldown_total.clear()
	for path in PlayerClasses.get_info(class_id).skills:
		skills.append(load(path))
		_cooldown_left.append(0.0)
		_cooldown_total.append(1.0)


## Partida nueva: sin combo y con todo recargado.
func reset() -> void:
	combo = []
	_combo_left = 0.0
	for i in _cooldown_left.size():
		_cooldown_left[i] = 0.0


func _process(delta: float) -> void:
	for i in _cooldown_left.size():
		_cooldown_left[i] = maxf(_cooldown_left[i] - delta, 0.0)
	_combo_left = maxf(_combo_left - delta, 0.0)


func get_skill(index: int) -> SkillData:
	return skills[index] if index >= 0 and index < skills.size() else null


func is_unlocked(index: int) -> bool:
	var skill: SkillData = get_skill(index)
	return skill != null and player_stats.level >= skill.unlock_level


func is_ready(index: int) -> bool:
	return is_unlocked(index) and _cooldown_left[index] <= 0.0


func start_cooldown(index: int) -> void:
	var total: float = skills[index].get_cooldown()
	_cooldown_total[index] = total
	_cooldown_left[index] = total
	skill_used.emit(index)


func get_cooldown_left(index: int) -> float:
	return _cooldown_left[index]


## 1 = recien usada, 0 = lista.
func get_cooldown_ratio(index: int) -> float:
	return _cooldown_left[index] / maxf(_cooldown_total[index], 0.01)


# --- Combo ---------------------------------------------------------------

func is_combo_unlocked() -> bool:
	return player_stats.level >= COMBO_UNLOCK_LEVEL


func set_combo(indices: Array) -> void:
	combo = []
	for index in indices:
		if is_unlocked(int(index)) and combo.size() < COMBO_MAX_SKILLS:
			combo.append(int(index))
	combo_changed.emit()


func get_combo_cooldown() -> float:
	var total: float = 0.0
	for index in combo:
		total += skills[index].get_cooldown()
	return total * COMBO_COOLDOWN_FACTOR


func is_combo_ready() -> bool:
	return is_combo_unlocked() and not combo.is_empty() and _combo_left <= 0.0


func start_combo_cooldown() -> void:
	_combo_total = maxf(get_combo_cooldown(), 0.01)
	_combo_left = _combo_total


func get_combo_cooldown_left() -> float:
	return _combo_left


func get_combo_cooldown_ratio() -> float:
	return _combo_left / _combo_total


func combo_has_strike() -> bool:
	for index in combo:
		if skills[index].kind == SkillData.Kind.STRIKE:
			return true
	return false


func _on_leveled_up(new_level: int) -> void:
	for i in skills.size():
		if skills[i].unlock_level == new_level:
			skill_unlocked.emit(i)
	if new_level == COMBO_UNLOCK_LEVEL:
		combo_unlocked.emit()
