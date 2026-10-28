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

## Peso de cada rareza (normal, magico, raro, unico).
const RARITY_WEIGHTS := [60.0, 28.0, 10.0, 2.0]
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
}

const UNIQUE_WEAPON_NAMES := ["Colmillo del Crepúsculo", "Lamento de Hierro", "Mordida del Invierno", "Segadora Carmesí"]
const UNIQUE_SHIELD_NAMES := ["Muralla de Ceniza", "Égida del Ocaso", "Bastión Silencioso"]


## Lo que suelta un enemigo: lista de {item, quantity}.
static func roll_enemy_drops(data: EnemyData, level: int) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	if randf() < 0.7:
		var amount: int = roundi(randi_range(data.gold_min, data.gold_max) * (1.0 + 0.2 * (level - 1)))
		drops.append({"item": GOLD, "quantity": maxi(1, amount)})
	if randf() < 0.15:
		drops.append({"item": POTION, "quantity": 1})
	# Los enemigos con mas experiencia (elites) sueltan equipo mas seguido.
	var item_chance: float = clampf(0.12 + data.xp_reward / 200.0, 0.0, 0.6)
	if randf() < item_chance:
		drops.append({"item": generate_item(level), "quantity": 1})
	return drops


## Crea un item aleatorio de nivel item_level a partir de un item base.
static func generate_item(item_level: int, forced_rarity: int = -1) -> Itemdata:
	var item: Itemdata = load(BASE_ITEMS.pick_random()).duplicate()
	var rarity: int = forced_rarity if forced_rarity >= 0 else _roll_rarity()
	item.rarity = rarity

	var mult: float = BASE_STAT_MULT[rarity]
	item.min_damage = roundi(item.min_damage * mult)
	item.max_damage = roundi(item.max_damage * mult)
	item.defense = roundi(item.defense * mult)

	var bonuses: Dictionary = {}
	var keys: Array = AFFIXES.keys()
	keys.shuffle()
	var count: int = randi_range(BONUS_COUNT[rarity].x, BONUS_COUNT[rarity].y)
	var strength: float = 1.5 if rarity == Itemdata.Rarity.UNIQUE else 1.0
	for i in count:
		var key: String = keys[i]
		var affix: Array = AFFIXES[key]
		var growth: float = affix[2] * (item_level - 1)
		var value: float = randf_range(affix[0] + growth, affix[1] + growth) * strength
		bonuses[key] = snappedf(value, 0.1) if key == "regeneracion" else float(maxi(1, roundi(value)))
	item.bonuses = bonuses

	if rarity == Itemdata.Rarity.UNIQUE:
		var names: Array = UNIQUE_WEAPON_NAMES if item.item_type == Itemdata.ItemType.MELEE_WEAPON else UNIQUE_SHIELD_NAMES
		item.unique_name = names.pick_random()
	elif count > 0:
		item.suffix = AFFIXES[keys[0]][3]
	item.value = roundi(item.value * VALUE_MULT[rarity] * (1.0 + 0.1 * (item_level - 1)))
	return item


static func _roll_rarity() -> int:
	var total: float = 0.0
	for w in RARITY_WEIGHTS:
		total += w
	var roll: float = randf() * total
	for i in RARITY_WEIGHTS.size():
		roll -= RARITY_WEIGHTS[i]
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
