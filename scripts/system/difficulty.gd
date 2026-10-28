extends Node

## Autoload con la dificultad de la partida. Se elige al empezar una partida
## nueva y queda fija (se guarda con la partida). Los enemigos leen de aca
## cuantos niveles de mas tienen y cuanta vida, daño, experiencia y botin dan.

## enemy_levels: niveles que se suman a cada enemigo (sube vida, daño,
## experiencia y el nivel de los items que suelta).
## magic_find: chance extra de soltar equipo y de que sea de mejor rareza.
const LEVELS := [
	{
		"name": "Normal", "color": Color(0.85, 0.8, 0.7),
		"description": "La experiencia pensada para empezar.",
		"enemy_levels": 0, "enemy_health": 1.0, "enemy_damage": 1.0,
		"xp": 1.0, "gold": 1.0, "magic_find": 0.0,
	},
	{
		"name": "Veterano", "color": Color(0.45, 0.62, 1.0),
		"description": "Enemigos 2 niveles más fuertes. Más experiencia, oro y botín.",
		"enemy_levels": 2, "enemy_health": 1.1, "enemy_damage": 1.1,
		"xp": 1.15, "gold": 1.25, "magic_find": 0.3,
	},
	{
		"name": "Heroico", "color": Color(1.0, 0.85, 0.3),
		"description": "Enemigos 4 niveles más fuertes y mucho más duros. Botín mucho mejor.",
		"enemy_levels": 4, "enemy_health": 1.25, "enemy_damage": 1.2,
		"xp": 1.3, "gold": 1.5, "magic_find": 0.6,
	},
	{
		"name": "Leyenda", "color": Color(0.95, 0.55, 0.15),
		"description": "Enemigos 7 niveles más fuertes. Solo para quien ya domina el combate.",
		"enemy_levels": 7, "enemy_health": 1.5, "enemy_damage": 1.4,
		"xp": 1.5, "gold": 2.0, "magic_find": 1.0,
	},
]

var current: int = 0


func set_level(index: int) -> void:
	current = clampi(index, 0, LEVELS.size() - 1)


func get_level_name(index: int = current) -> String:
	return LEVELS[index].name


func get_color(index: int = current) -> Color:
	return LEVELS[index].color


func get_value(key: String) -> float:
	return LEVELS[current][key]
