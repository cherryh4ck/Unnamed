class_name Gems

## Gemas y ranuras. Las gemas se engarzan en las ranuras de armas, escudos y
## ballestas (lo hace el herrero, ver scripts/npc/blacksmith.gd). Cada gema da
## una bonificacion distinta segun donde se ponga: en lo que pega, daño; en un
## escudo, resistencia. Hay tres calidades; cada una es un .tres en
## item/items/gems/ (lo arma item/gems/build_gems.gd) y en el item se guarda
## como "tipo:calidad" en Itemdata.gems.

const ITEMS_DIR := "res://item/items/gems/"
const MODELS_DIR := "res://item/gems/models/"

## tipo -> nombre, color, si el nombre es femenino, bonificacion en armas y
## en escudos ([clave de Itemdata.BONUS_TEXT, valor con la calidad mas baja]).
const KINDS := {
	"rubi": {"name": "Rubí", "color": Color(0.95, 0.18, 0.2), "feminine": false,
		"weapon": ["daño_fuego", 3.0], "shield": ["res_fuego", 6.0]},
	"esmeralda": {"name": "Esmeralda", "color": Color(0.2, 0.85, 0.35), "feminine": true,
		"weapon": ["daño_veneno", 4.0], "shield": ["res_veneno", 6.0]},
	"zafiro": {"name": "Zafiro", "color": Color(0.25, 0.45, 1.0), "feminine": false,
		"weapon": ["daño_magia", 3.0], "shield": ["res_magia", 6.0]},
	"topacio": {"name": "Topacio", "color": Color(1.0, 0.78, 0.2), "feminine": false,
		"weapon": ["critico", 1.5], "shield": ["defensa", 5.0]},
	"amatista": {"name": "Amatista", "color": Color(0.72, 0.35, 0.95), "feminine": true,
		"weapon": ["daño_pct", 4.0], "shield": ["vida", 10.0]},
}
const KIND_ORDER := ["rubi", "esmeralda", "zafiro", "topacio", "amatista"]

## Calidades: astillada, comun y perfecta.
const TIER_COUNT: int = 3
const TIER_MULT := [1.0, 2.0, 3.5]
const TIER_VALUE := [40, 120, 400]
const TIER_SUFFIX_M := ["astillado", "", "perfecto"]
const TIER_SUFFIX_F := ["astillada", "", "perfecta"]

## Ranuras que se pueden abrir segun la rareza (normal, magico, raro, unico, set):
## cuanto mejor el item, menos lugar para gemas.
const MAX_SOCKETS := [3, 2, 1, 1, 1]
## Ranuras con las que puede salir un item del botin (minimo, maximo) y la
## probabilidad de que tenga alguna.
const DROP_SOCKET_CHANCE := [0.3, 0.2, 0.1, 0.0, 0.0]


static func path_for(kind: String, tier: int) -> String:
	return "%s%s_%d.tres" % [ITEMS_DIR, kind, tier]


static func model_path_for(kind: String, tier: int) -> String:
	return "%s%s_%d.tscn" % [MODELS_DIR, kind, tier]


static func id_of(gem: Itemdata) -> String:
	return "%s:%d" % [gem.gem_kind, gem.gem_tier]


## La gema (el .tres compartido) de un id "tipo:calidad", o null.
static func from_id(id: String) -> Itemdata:
	var parts: PackedStringArray = id.split(":")
	if parts.size() != 2 or not KINDS.has(parts[0]):
		return null
	var path: String = path_for(parts[0], clampi(int(parts[1]), 0, TIER_COUNT - 1))
	return load(path) if ResourceLoader.exists(path) else null


static func display_name(kind: String, tier: int) -> String:
	var info: Dictionary = KINDS[kind]
	var suffix: String = (TIER_SUFFIX_F if info.feminine else TIER_SUFFIX_M)[tier]
	return ("%s %s" % [info.name, suffix]).strip_edges()


static func color_of(kind: String) -> Color:
	return KINDS[kind].color if KINDS.has(kind) else Color.WHITE


## [clave, valor] que da la gema puesta en un item que pega (for_weapon) o en un escudo.
static func bonus_of(kind: String, tier: int, for_weapon: bool) -> Array:
	var base: Array = KINDS[kind]["weapon" if for_weapon else "shield"]
	var value: float = base[1] * TIER_MULT[tier]
	if base[0] != "critico":
		value = roundf(value)
	return [base[0], value]


## Todas las bonificaciones de las gemas engarzadas en el item (clave -> valor).
static func socket_bonuses(item: Itemdata) -> Dictionary:
	var total: Dictionary = {}
	for id in item.gems:
		var parts: PackedStringArray = id.split(":")
		if parts.size() != 2 or not KINDS.has(parts[0]):
			continue
		var bonus: Array = bonus_of(parts[0], clampi(int(parts[1]), 0, TIER_COUNT - 1), item.has_damage())
		total[bonus[0]] = total.get(bonus[0], 0.0) + bonus[1]
	return total


static func max_sockets(item: Itemdata) -> int:
	return MAX_SOCKETS[item.rarity] if item.is_equipment() else 0


# --- Precios del herrero ---------------------------------------------------

## Abrir la siguiente ranura: mas caro cuanto mejor el item y cuantas mas tenga.
static func socket_price(item: Itemdata) -> int:
	return roundi(maxf(60.0, item.value * 0.5) * (item.sockets + 1))


## Engarzar una gema.
static func insert_price(gem: Itemdata) -> int:
	return maxi(10, gem.value / 8)


## Sacar todas las gemas (vuelven al inventario).
static func remove_price(item: Itemdata) -> int:
	var total: int = 0
	for id in item.gems:
		var gem: Itemdata = from_id(id)
		if gem:
			total += maxi(15, gem.value / 4)
	return total


# --- Botin ---------------------------------------------------------------

## Gema aleatoria: la calidad sube con el nivel de la zona.
static func roll_gem(level: int) -> Itemdata:
	var kind: String = KIND_ORDER.pick_random()
	var roll: float = randf() + level * 0.03
	var tier: int = 2 if roll > 1.35 else (1 if roll > 0.85 else 0)
	return from_id("%s:%d" % [kind, tier])


## Ranuras vacias con las que sale un item generado.
static func roll_sockets(rarity: int) -> int:
	if randf() >= DROP_SOCKET_CHANCE[rarity]:
		return 0
	return randi_range(1, MAX_SOCKETS[rarity])
