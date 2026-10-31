extends Resource

class_name Itemdata

# Los valores nuevos van siempre al final para no romper los .tres existentes
# (Godot guarda el enum como numero).
enum ItemType { GENERIC, MELEE_WEAPON, SPECIAL, POTION, GOLD, GEM,
	HELMET, CHEST, GLOVES, LEGS, BOOTS, BELT, RING, AMULET, SCROLL }
enum WeightClass { LIGHT, MEDIUM, HEAVY }
enum Rarity { NORMAL, MAGIC, RARE, UNIQUE, SET }

const WEIGHT_NAMES := ["ligero", "medio", "pesado"]
## Partes de la armadura (van en sus propios slots, ver inventory_data.gd).
const ARMOR_TYPES := [ItemType.HELMET, ItemType.CHEST, ItemType.GLOVES, ItemType.LEGS,
		ItemType.BOOTS, ItemType.BELT, ItemType.RING, ItemType.AMULET]
## Nombre de cada parte y su genero/numero para el adjetivo de rareza
## (m = masculino, f = femenino, mp / fp = plural).
const ARMOR_NAMES := {
	ItemType.HELMET: ["Casco", "m"], ItemType.CHEST: ["Armadura", "f"], ItemType.GLOVES: ["Guantes", "mp"],
	ItemType.LEGS: ["Grebas", "fp"], ItemType.BOOTS: ["Botas", "fp"], ItemType.BELT: ["Cinturón", "m"],
	ItemType.RING: ["Anillo", "m"], ItemType.AMULET: ["Amuleto", "m"],
}
const RARITY_ADJECTIVES := {
	"m": ["", "mágico", "raro", "único", "de set"],
	"f": ["", "mágica", "rara", "única", "de set"],
	"mp": ["", "mágicos", "raros", "únicos", "de set"],
	"fp": ["", "mágicas", "raras", "únicas", "de set"],
}
## Efectos especiales de los unicos: clave -> texto con %s para el valor.
const SPECIAL_TEXT := {
	"robo_vida": "Roba el %s%% del daño como vida",
	"vida_golpe": "+%s de vida por cada golpe",
	"cadena": "%s%% de soltar un rayo que salta a otro enemigo",
	"espinas": "Devuelve el %s%% del daño cuerpo a cuerpo",
	"aura_fuego": "Aura de fuego: %s de daño por segundo alrededor",
}
const SPECIAL_COLOR := Color(1.0, 0.62, 0.25)
const ATTRIBUTE_NAMES := {"fuerza": "Fuerza", "destreza": "Destreza", "vitalidad": "Vitalidad", "concentracion": "Concentración"}
const RARITY_NAMES := ["Normal", "Mágico", "Raro", "Único", "De set"]
const RARITY_COLORS := [
	Color(0.9, 0.88, 0.82),
	Color(0.45, 0.62, 1.0),
	Color(1.0, 0.85, 0.3),
	Color(0.95, 0.55, 0.15),
	Color(0.35, 0.9, 0.35),
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
	"daño_magia": "+%s Daño mágico",
	"daño_veneno": "+%s Daño de veneno",
	"daño_fuego": "+%s Daño de fuego",
	"res_magia": "+%s%% Resistencia a la magia",
	"res_veneno": "+%s%% Resistencia al veneno",
	"res_fuego": "+%s%% Resistencia al fuego",
}
const BONUS_COLOR := Color(0.5, 0.68, 1.0)

@export var name: String = ""
@export_multiline var description: String = ""
@export var stackable: bool = false
@export var item_type: ItemType = ItemType.GENERIC
@export var texture: Texture2D
@export var model_3d: PackedScene
## Armaduras del torso: textura que se le pone al cuerpo del personaje al
## llevarla puesta (mismo mapa UV que todos los cuerpos de 0 A.D.).
@export var body_texture: Texture2D
## Casillas que ocupa en el inventario (ancho x alto).
@export var grid_size: Vector2i = Vector2i(1, 1)

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
## Id del set al que pertenece (ver scripts/items/item_sets.gd). Vacio = ninguno.
@export var set_id: String = ""
## Ruta del .tres base de un item generado (para guardar la partida).
@export var base_path: String = ""

@export_group("Gemas")
## Ranuras abiertas (armas, escudos y ballestas). Ver scripts/items/gems.gd.
@export var sockets: int = 0
## Gemas engarzadas, como "tipo:calidad" (ej: "rubi:2").
@export var gems: PackedStringArray = []
## Si el item es una gema: su tipo (clave de Gems.KINDS) y calidad (0 a 2).
@export var gem_kind: String = ""
@export var gem_tier: int = 0

@export_group("Requisitos")
## Nivel minimo para equiparlo (0 = sin requisito).
@export var required_level: int = 0
## Atributo -> valor minimo (ej: {"fuerza": 14}).
@export var required_attributes: Dictionary = {}

@export_group("Unicos")
## Efecto especial (clave de SPECIAL_TEXT) y cuanto da.
@export var special: String = ""
@export var special_value: float = 0.0
## Frase de historia que se ve en el tooltip.
@export_multiline var lore: String = ""

@export_group("Consumibles")
## Que hace al usarlo: "" = cura vida (pocion comun), "antidoto",
## "res_fuego", "regeneracion" o "retorno" (ver player_stats.use_consumable).
@export var use_effect: String = ""

@export_group("Comercio")
## Precio base en oro (para el comerciante, mas adelante).
@export var value: int = 0


func get_display_name() -> String:
	if not unique_name.is_empty():
		return unique_name
	if name.is_empty():
		return "Objeto desconocido"
	# Siempre con mayuscula inicial (tambien los items de partidas viejas).
	var base: String = name.left(1).to_upper() + name.substr(1)
	if not suffix.is_empty():
		return "%s %s" % [base, suffix]
	return base


## Casillas que ocupa en la grilla (al menos 1x1).
func get_footprint() -> Vector2i:
	return Vector2i(maxi(grid_size.x, 1), maxi(grid_size.y, 1))


func get_rarity_color() -> Color:
	if item_type == ItemType.GEM:
		return Gems.color_of(gem_kind).lightened(0.25)
	return RARITY_COLORS[rarity]


## Bonificacion del item mas la de las gemas engarzadas.
func get_bonus(key: String) -> float:
	var total: float = bonuses.get(key, 0.0)
	if not gems.is_empty():
		total += Gems.socket_bonuses(self).get(key, 0.0)
	return total


func get_bonus_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for key in bonuses:
		lines.append(bonus_text(key, bonuses[key]))
	return lines


static func bonus_text(key: String, value: float) -> String:
	var text: String = str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
	return BONUS_TEXT.get(key, key + " %s") % text


## Las bonificaciones de daño y resistencia elemental van con el color de su tipo.
static func bonus_color(key: String) -> Color:
	for type in Damage.ELEMENTS:
		if key == Damage.damage_key(type) or key == Damage.resist_key(type):
			return Damage.COLORS[type]
	return BONUS_COLOR


## Ej: "Arma mágica", "Escudo raro" (para el tooltip).
func get_type_line() -> String:
	const FEMININE := ["", "mágica", "rara", "única", "de set"]
	const MASCULINE := ["", "mágico", "raro", "único", "de set"]
	if ARMOR_NAMES.has(item_type):
		var entry: Array = ARMOR_NAMES[item_type]
		return ("%s %s" % [entry[0], RARITY_ADJECTIVES[entry[1]][rarity]]).strip_edges()
	match item_type:
		ItemType.MELEE_WEAPON:
			return ("Arma " + FEMININE[rarity]).strip_edges()
		ItemType.SPECIAL:
			if has_damage():
				return ("Arma a distancia " + FEMININE[rarity]).strip_edges()
			return ("Escudo " + MASCULINE[rarity]).strip_edges()
		ItemType.POTION:
			return "Poción"
		ItemType.SCROLL:
			return "Pergamino"
		ItemType.GOLD:
			return "Oro"
		ItemType.GEM:
			return "Gema"
	return "Objeto"


func is_equipment() -> bool:
	return item_type == ItemType.MELEE_WEAPON or item_type == ItemType.SPECIAL or is_armor()


## Tipo de pieza para los unicos: "arma", "escudo", "casco", "armadura",
## "guantes", "grebas", "botas", "cinturon", "anillo" o "amuleto".
func get_slot_kind() -> String:
	match item_type:
		ItemType.MELEE_WEAPON:
			return "arma"
		ItemType.SPECIAL:
			return "arma" if has_damage() else "escudo"
		ItemType.HELMET:
			return "casco"
		ItemType.CHEST:
			return "armadura"
		ItemType.GLOVES:
			return "guantes"
		ItemType.LEGS:
			return "grebas"
		ItemType.BOOTS:
			return "botas"
		ItemType.BELT:
			return "cinturon"
		ItemType.RING:
			return "anillo"
		ItemType.AMULET:
			return "amuleto"
	return ""


## Casco, armadura, guantes, grebas, botas, cinturon, anillos y amuleto.
func is_armor() -> bool:
	return item_type in ARMOR_TYPES


## Pociones y pergaminos (se usan desde el inventario o el cinturon).
func is_consumable() -> bool:
	return item_type == ItemType.POTION or item_type == ItemType.SCROLL


## La pocion comun de vida (la de la tecla Q).
func is_health_potion() -> bool:
	return item_type == ItemType.POTION and use_effect.is_empty()


## Texto del efecto especial de un unico ("" si no tiene).
func get_special_text() -> String:
	if special.is_empty() or not SPECIAL_TEXT.has(special):
		return ""
	var value: String = str(roundi(special_value)) if is_equal_approx(special_value, roundf(special_value)) else "%.1f" % special_value
	return SPECIAL_TEXT[special] % value


## Lineas de requisitos: [texto, se cumple]. El personaje se busca en el
## arbol (y no por el nombre del autoload) para que los scripts de prueba
## puedan usar esta clase antes de que existan los autoloads.
func get_requirement_lines() -> Array:
	var lines: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	var stats: Node = tree.root.get_node_or_null("player_stats") if tree else null
	if required_level > 0:
		lines.append(["Requiere nivel %d" % required_level, stats == null or stats.level >= required_level])
	for key in required_attributes:
		var needed: int = int(required_attributes[key])
		lines.append(["Requiere %s %d" % [ATTRIBUTE_NAMES.get(key, key), needed], stats == null or stats.get_attribute(key) >= needed])
	return lines


## Si el personaje cumple los requisitos para equiparlo.
func meets_requirements() -> bool:
	for line in get_requirement_lines():
		if not line[1]:
			return false
	return true


func has_damage() -> bool:
	return max_damage > 0


## Las armas del slot especial que hacen daño (ballestas) atacan a distancia.
func is_ranged() -> bool:
	return item_type == ItemType.SPECIAL and has_damage()


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
	# El peso solo cuenta para combinar el arma con el escudo.
	if item_type == ItemType.MELEE_WEAPON or item_type == ItemType.SPECIAL:
		lines.append("Peso: %s" % WEIGHT_NAMES[weight_class])
	return lines


## Lo que da una gema segun donde se engarce (para el tooltip).
func get_gem_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if item_type != ItemType.GEM or not Gems.KINDS.has(gem_kind):
		return lines
	var weapon: Array = Gems.bonus_of(gem_kind, gem_tier, true)
	var shield: Array = Gems.bonus_of(gem_kind, gem_tier, false)
	lines.append("En armas y ballestas: " + bonus_text(weapon[0], weapon[1]))
	lines.append("En escudos y armaduras: " + bonus_text(shield[0], shield[1]))
	return lines
