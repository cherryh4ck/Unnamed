class_name Loot

## Generacion de botin: que suelta un enemigo al morir y como se arma un
## item aleatorio (rareza, bonificaciones y nombre).

# La escena del pickup se carga recien al usarla: pickup.gd usa autoloads y
# precargarla aca la compilaria antes de que existan.
const PICKUP_SCENE_PATH := "res://item/pickup.tscn"
const GOLD := preload("res://item/items/gold.tres")
const POTION := preload("res://item/items/potion_of_health.tres")

## Items base que pueden aparecer como botin.
const BASE_ITEMS := [
	"res://item/items/espada_ligera.tres",
	"res://item/items/long_sword.tres",
	"res://item/items/hacha_grande.tres",
	"res://item/items/escudo_ligero.tres",
	"res://item/items/escudo_mid.tres",
	"res://item/items/escudo_pesado.tres",
	"res://item/items/ballesta_de_madera.tres",
	"res://item/items/ballesta_pesada.tres",
]

## Probabilidad de que un enemigo suelte una gema (los elite, un poco mas).
const GEM_CHANCE: float = 0.05

## Peso de cada rareza (normal, magico, raro, unico, set).
const RARITY_WEIGHTS := [60.0, 28.0, 10.0, 2.0, 3.0]
## Cantidad de bonificaciones por rareza.
const BONUS_COUNT := [Vector2i(0, 0), Vector2i(1, 2), Vector2i(3, 4), Vector2i(4, 4)]
## Mejora de daño/defensa base por rareza.
const BASE_STAT_MULT := [1.0, 1.1, 1.2, 1.35]
const VALUE_MULT := [1.0, 2.0, 4.0, 8.0]

## clave -> [minimo, maximo a nivel 1, crecimiento por nivel, sufijo del nombre].
const AFFIXES := {
	"fuerza": [1, 3, 0.5, "del Toro"],
	"destreza": [1, 3, 0.5, "del Halcón"],
	"vitalidad": [1, 3, 0.5, "del Oso"],
	"concentracion": [1, 3, 0.5, "del Sabio"],
	"vida": [5, 15, 3.0, "de la Vida"],
	"defensa": [3, 8, 1.5, "de Hierro"],
	"daño_pct": [5, 15, 1.0, "de la Furia"],
	"velocidad_pct": [4, 10, 0.5, "del Viento"],
	"critico": [1, 4, 0.3, "de la Precisión"],
	"regeneracion": [0.3, 1.0, 0.15, "de la Sanación"],
	"daño_magia": [2, 5, 1.0, "del Arcano"],
	"daño_veneno": [3, 7, 1.4, "de la Víbora"],
	"daño_fuego": [2, 5, 1.0, "de las Llamas"],
	"res_magia": [5, 12, 0.8, "del Hechicero"],
	"res_veneno": [5, 12, 0.8, "de la Serpiente"],
	"res_fuego": [5, 12, 0.8, "de la Salamandra"],
}
## Bonificaciones que solo salen en items que pegan (armas y ballestas).
const WEAPON_ONLY_AFFIXES := ["daño_magia", "daño_veneno", "daño_fuego"]
## Los unicos que pegan traen siempre uno de estos, mas fuerte.
const UNIQUE_ELEMENTS := ["daño_magia", "daño_veneno", "daño_fuego"]

const UNIQUE_WEAPON_NAMES := ["Colmillo del Crepúsculo", "Lamento de Hierro", "Mordida del Invierno", "Segadora Carmesí"]
const UNIQUE_SHIELD_NAMES := ["Muralla de Ceniza", "Égida del Ocaso", "Bastión Silencioso"]


## Lo que suelta un enemigo: lista de {item, quantity}. gold_mult y
## magic_find vienen de la dificultad.
static func roll_enemy_drops(data: EnemyData, level: int, gold_mult: float = 1.0, magic_find: float = 0.0) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	if randf() < 0.7:
		var amount: int = roundi(randi_range(data.gold_min, data.gold_max) * (1.0 + 0.2 * (level - 1)) * gold_mult)
		drops.append({"item": GOLD, "quantity": maxi(1, amount)})
	if randf() < 0.15:
		drops.append({"item": POTION, "quantity": 1})
	# Los enemigos con mas experiencia (elites) sueltan equipo mas seguido.
	var item_chance: float = clampf((0.12 + data.xp_reward / 200.0) * (1.0 + magic_find), 0.0, 0.6)
	if randf() < item_chance:
		drops.append({"item": generate_item(level, -1, magic_find), "quantity": 1})
	if randf() < GEM_CHANCE * (1.0 + data.xp_reward / 100.0) * (1.0 + magic_find):
		var gem: Itemdata = Gems.roll_gem(level)
		if gem:
			drops.append({"item": gem, "quantity": 1})
	return drops


## Lo que hay en un cofre del mundo: siempre oro, a veces pociones, uno o dos
## items con mas chance de ser buenos y, a veces, una gema. quality 1 = cofre
## bueno (mas items y gemas).
static func roll_chest_drops(level: int, quality: int, gold_mult: float = 1.0, magic_find: float = 0.0) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	var gold: int = roundi(randi_range(15, 40) * (1.0 + 0.25 * (level - 1)) * (1.0 + quality) * gold_mult)
	drops.append({"item": GOLD, "quantity": gold})
	if randf() < 0.5:
		drops.append({"item": POTION, "quantity": randi_range(1, 2)})
	for i in 1 + quality:
		drops.append({"item": generate_item(level, -1, magic_find + 0.5 * (quality + 1)), "quantity": 1})
	if randf() < 0.25 + 0.2 * quality:
		var gem: Itemdata = Gems.roll_gem(level + 2 * quality)
		if gem:
			drops.append({"item": gem, "quantity": 1})
	return drops


## Crea un item aleatorio de nivel item_level a partir de un item base.
static func generate_item(item_level: int, forced_rarity: int = -1, magic_find: float = 0.0) -> Itemdata:
	var rarity: int = forced_rarity if forced_rarity >= 0 else _roll_rarity(magic_find)
	if rarity == Itemdata.Rarity.SET:
		return ItemSets.generate_piece(item_level)
	var base_path: String = BASE_ITEMS.pick_random()
	var item: Itemdata = load(base_path).duplicate()
	item.base_path = base_path
	item.rarity = rarity

	var mult: float = BASE_STAT_MULT[rarity]
	item.min_damage = roundi(item.min_damage * mult)
	item.max_damage = roundi(item.max_damage * mult)
	item.defense = roundi(item.defense * mult)

	var bonuses: Dictionary = {}
	var keys: Array = AFFIXES.keys().filter(func(key: String) -> bool:
		return item.has_damage() or key not in WEAPON_ONLY_AFFIXES)
	keys.shuffle()
	var count: int = randi_range(BONUS_COUNT[rarity].x, BONUS_COUNT[rarity].y)
	var strength: float = 1.5 if rarity == Itemdata.Rarity.UNIQUE else 1.0
	if rarity == Itemdata.Rarity.UNIQUE and item.has_damage():
		var element: String = UNIQUE_ELEMENTS.pick_random()
		keys.erase(element)
		bonuses[element] = _roll_affix(element, item_level, 2.0)
	for i in count:
		var key: String = keys[i]
		bonuses[key] = _roll_affix(key, item_level, strength)
	item.bonuses = bonuses

	if rarity == Itemdata.Rarity.UNIQUE:
		var names: Array = UNIQUE_WEAPON_NAMES if item.item_type == Itemdata.ItemType.MELEE_WEAPON else UNIQUE_SHIELD_NAMES
		item.unique_name = names.pick_random()
	elif count > 0:
		item.suffix = AFFIXES[keys[0]][3]
	item.value = roundi(item.value * VALUE_MULT[rarity] * (1.0 + 0.1 * (item_level - 1)))
	item.sockets = Gems.roll_sockets(rarity)
	item.gems = PackedStringArray()
	return item


static func _roll_affix(key: String, item_level: int, strength: float) -> float:
	var affix: Array = AFFIXES[key]
	var growth: float = affix[2] * (item_level - 1)
	var value: float = randf_range(affix[0] + growth, affix[1] + growth) * strength
	return snappedf(value, 0.1) if key == "regeneracion" else float(maxi(1, roundi(value)))


## magic_find multiplica el peso de todas las rarezas mejores que normal.
static func _roll_rarity(magic_find: float = 0.0) -> int:
	var weights: Array[float] = []
	var total: float = 0.0
	for i in RARITY_WEIGHTS.size():
		weights.append(RARITY_WEIGHTS[i] * (1.0 if i == 0 else 1.0 + magic_find))
		total += weights[i]
	var roll: float = randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return 0


## Deja un item en el piso. Con "pop" salta un poco antes de caer.
static func spawn_pickup(parent: Node, position: Vector3, item: Itemdata, quantity: int = 1, pop: bool = true) -> Node3D:
	var pickup: Node3D = load(PICKUP_SCENE_PATH).instantiate()
	pickup.item_data = item
	pickup.quantity = quantity
	parent.add_child(pickup)
	var offset := Vector3(randf_range(-120.0, 120.0), 0.0, randf_range(-120.0, 120.0))
	var ground: Vector3 = Vector3(position.x, 5.0, position.z) + offset
	pickup.global_position = ground
	if pop:
		pickup.pop_from(Vector3(position.x, 5.0, position.z))
	return pickup
