extends Resource

class_name Itemdata

# Los valores nuevos van siempre al final para no romper los .tres existentes
# (Godot guarda el enum como numero).
enum ItemType { GENERIC, MELEE_WEAPON, SPECIAL, POTION, GOLD }
enum WeightClass { LIGHT, MEDIUM, HEAVY }
enum Rarity { NORMAL, MAGIC, RARE, UNIQUE }

const WEIGHT_NAMES := ["ligero", "medio", "pesado"]
const RARITY_NAMES := ["Normal", "Mágico", "Raro", "Único"]
const RARITY_COLORS := [
	Color(0.9, 0.88, 0.82),
	Color(0.45, 0.62, 1.0),
	Color(1.0, 0.85, 0.3),
	Color(0.95, 0.55, 0.15),
]
## Bonificaciones posibles: clave -> texto con %s para el valor.
const BONUS_TEXT := {
	"fuerza": "+%s Fuerza",
	"destreza": "+%s Destreza",
	"vitalidad": "+%s Vitalidad",
	"concentracion": "+%s Concentración",
	"vida": "+%s Vida máxima",
	"defensa": "+%s Defensa",
	"daño_pct": "+%s%% Daño",
	"velocidad_pct": "+%s%% Velocidad de ataque",
	"critico": "+%s%% Crítico",
	"regeneracion": "+%s Vida por segundo",
}

@export var name: String = ""
@export_multiline var description: String = ""
@export var stackable: bool = false
@export var item_type: ItemType = ItemType.GENERIC
@export var texture: Texture2D
@export var model_3d: PackedScene

@export_group("Combate")
## Un item pesado solo se puede combinar con uno ligero en el otro slot.
@export var weight_class: WeightClass = WeightClass.MEDIUM
@export var min_damage: int = 0
@export var max_damage: int = 0
## Ataques por segundo.
@export var attack_speed: float = 1.0
@export var defense: int = 0
## Probabilidad de bloquear un golpe, en %.
@export_range(0, 75) var block_chance: int = 0

@export_group("Rareza")
@export var rarity: Rarity = Rarity.NORMAL
## Agregado al nombre base en items magicos/raros (ej: "del Oso").
@export var suffix: String = ""
## Nombre propio de los items unicos (reemplaza al nombre base).
@export var unique_name: String = ""
## clave de BONUS_TEXT -> valor.
@export var bonuses: Dictionary = {}

@export_group("Comercio")
## Precio base en oro (para el comerciante, mas adelante).
@export var value: int = 0


func get_display_name() -> String:
	if not unique_name.is_empty():
		return unique_name
	if name.is_empty():
		return "objeto desconocido"
	if not suffix.is_empty():
		return "%s %s" % [name, suffix]
	return name


func get_rarity_color() -> Color:
	return RARITY_COLORS[rarity]


func get_bonus(key: String) -> float:
	return bonuses.get(key, 0.0)


func get_bonus_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for key in bonuses:
		var value: float = bonuses[key]
		var text: String = str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
		lines.append(BONUS_TEXT.get(key, key + " %s") % text)
	return lines


## Ej: "Arma mágica", "Escudo raro" (para el tooltip).
func get_type_line() -> String:
	const FEMININE := ["", "mágica", "rara", "única"]
	const MASCULINE := ["", "mágico", "raro", "único"]
	match item_type:
		ItemType.MELEE_WEAPON:
			return ("Arma " + FEMININE[rarity]).strip_edges()
		ItemType.SPECIAL:
			if has_damage():
				return ("Arma a distancia " + FEMININE[rarity]).strip_edges()
			return ("Escudo " + MASCULINE[rarity]).strip_edges()
		ItemType.POTION:
			return "Poción"
		ItemType.GOLD:
			return "Oro"
	return "Objeto"


func is_equipment() -> bool:
	return item_type == ItemType.MELEE_WEAPON or item_type == ItemType.SPECIAL


func has_damage() -> bool:
	return max_damage > 0


## Lineas de stats para mostrar en el inventario / tooltip.
func get_stats_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if has_damage():
		lines.append("Daño: %d - %d" % [min_damage, max_damage])
		lines.append("Velocidad: %.2f golpes/s" % attack_speed)
	if defense > 0:
		lines.append("Defensa: %d" % defense)
	if block_chance > 0:
		lines.append("Bloqueo: %d%%" % block_chance)
	if is_equipment():
		lines.append("Peso: %s" % WEIGHT_NAMES[weight_class])
	return lines
