class_name Damage

## Tipos de daño. Un golpe es un diccionario {Type: cantidad} y cada tipo se
## reduce distinto al recibirlo:
## - Fisico: con la defensa (armadura).
## - Magico: con la resistencia a la magia.
## - Fuego: con la resistencia al fuego; ademas deja al objetivo ardiendo un rato.
## - Veneno: con la resistencia al veneno; no pega de golpe, se resta de a poco.

enum Type { PHYSICAL, MAGIC, POISON, FIRE }

const NAMES := ["Físico", "Mágico", "Veneno", "Fuego"]
## Clave de cada tipo en las bonificaciones de los items ("daño_" + clave y "res_" + clave).
const KEYS := ["fisico", "magia", "veneno", "fuego"]
const COLORS := [
	Color(0.92, 0.9, 0.85),
	Color(0.7, 0.58, 1.0),
	Color(0.52, 0.9, 0.3),
	Color(1.0, 0.55, 0.18),
]
## Tipos que tienen resistencia propia (el fisico se reduce con la defensa).
const ELEMENTS := [Type.MAGIC, Type.POISON, Type.FIRE]
## Resistencia maxima, en %. Puede ser negativa (debilidad).
const RESIST_CAP: float = 75.0
## El veneno se resta durante estos segundos.
const POISON_DURATION: float = 4.0
## Parte del daño de fuego que vuelve a pegar como quemadura, en estos segundos.
const BURN_SHARE: float = 0.35
const BURN_DURATION: float = 3.0
## Cada cuanto pegan el veneno y la quemadura.
const TICK: float = 0.5


static func damage_key(type: int) -> String:
	return "daño_" + KEYS[type]


static func resist_key(type: int) -> String:
	return "res_" + KEYS[type]


## Golpe de un solo tipo. Con conversion > 0, esa parte pasa a convert_to
## (ej: la Bola de Fuego convierte todo el daño fisico en fuego).
static func split(amount: float, convert_to: int = Type.PHYSICAL, conversion: float = 0.0) -> Dictionary:
	if convert_to == Type.PHYSICAL or conversion <= 0.0:
		return {Type.PHYSICAL: amount}
	var parts := {convert_to: amount * clampf(conversion, 0.0, 1.0)}
	if conversion < 1.0:
		parts[Type.PHYSICAL] = amount * (1.0 - conversion)
	return parts


static func total(parts: Dictionary) -> float:
	var sum: float = 0.0
	for type in parts:
		sum += parts[type]
	return sum


## El tipo con mas daño del golpe (para el color del numero).
static func main_type(parts: Dictionary) -> int:
	var best: int = Type.PHYSICAL
	var best_amount: float = -1.0
	for type in parts:
		if parts[type] > best_amount:
			best = type
			best_amount = parts[type]
	return best


static func resist_multiplier(resist: float) -> float:
	return 1.0 - minf(resist, RESIST_CAP) / 100.0


static func armor_multiplier(defense: float) -> float:
	return 100.0 / (100.0 + maxf(defense, 0.0))


## Aplica defensa y resistencias (resists: Type -> %). Devuelve:
## direct: daño que entra ya; type: tipo principal de ese daño;
## poison y burn: daño que queda pendiente por tiempo.
static func mitigate(parts: Dictionary, defense: float, resists: Dictionary) -> Dictionary:
	var result := {"direct": 0.0, "poison": 0.0, "burn": 0.0, "type": Type.PHYSICAL}
	var direct_parts := {}
	for type in parts:
		var amount: float = parts[type]
		if amount <= 0.0:
			continue
		match type:
			Type.PHYSICAL:
				direct_parts[type] = amount * armor_multiplier(defense)
			Type.MAGIC:
				direct_parts[type] = amount * resist_multiplier(resists.get(type, 0.0))
			Type.FIRE:
				var fire: float = amount * resist_multiplier(resists.get(type, 0.0))
				direct_parts[type] = fire
				result.burn += fire * BURN_SHARE
			Type.POISON:
				result.poison += amount * resist_multiplier(resists.get(type, 0.0))
	result.direct = total(direct_parts)
	if not direct_parts.is_empty():
		result.type = main_type(direct_parts)
	return result
