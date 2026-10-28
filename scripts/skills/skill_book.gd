extends Node

## Autoload con las habilidades del jugador: cuales tiene aprendidas
## (segun el nivel) y cuanto le falta a cada una para recargarse.
## La ejecucion de cada habilidad esta en scripts/player/combat.gd.

signal skill_unlocked(index: int)
signal skill_used(index: int)

const SKILL_PATHS := [
	"res://skills/golpe_brutal.tres",
	"res://skills/torbellino.tres",
	"res://skills/bola_de_fuego.tres",
	"res://skills/furia.tres",
	"res://skills/piel_de_piedra.tres",
]

var skills: Array[SkillData] = []
var _cooldown_left: Array[float] = []
var _cooldown_total: Array[float] = []


func _ready() -> void:
	for path in SKILL_PATHS:
		skills.append(load(path))
		_cooldown_left.append(0.0)
		_cooldown_total.append(1.0)
	player_stats.leveled_up.connect(_on_leveled_up)


func _process(delta: float) -> void:
	for i in _cooldown_left.size():
		_cooldown_left[i] = maxf(_cooldown_left[i] - delta, 0.0)


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


func _on_leveled_up(new_level: int) -> void:
	for i in skills.size():
		if skills[i].unlock_level == new_level:
			skill_unlocked.emit(i)
