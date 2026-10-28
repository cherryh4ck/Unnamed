extends Resource

class_name Itemdata

# Los valores nuevos van siempre al final para no romper los .tres existentes
# (Godot guarda el enum como numero).
enum ItemType { GENERIC, MELEE_WEAPON, SPECIAL, POTION, GOLD }
enum WeightClass { LIGHT, MEDIUM, HEAVY }

const WEIGHT_NAMES := ["ligero", "medio", "pesado"]

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

@export_group("Comercio")
## Precio base en oro (para el comerciante, mas adelante).
@export var value: int = 0


func get_display_name() -> String:
	if name.is_empty():
		return "objeto desconocido"
	return name


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
