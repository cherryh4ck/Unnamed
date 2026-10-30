class_name ItemSets

## Sets de items (rareza verde). Cada pieza tiene sus propias bonificaciones
## y, con todas las piezas equipadas, se suma el bonus del set.
## Hoy hay dos slots de equipo, asi que los sets son de dos piezas.

const SETS := {
	"centinela": {
		"name": "Vigilia del Centinela",
		"pieces": {
			"res://item/items/espada_ligera.tres": "Hoja del Centinela",
			"res://item/items/escudo_pesado.tres": "Muro del Centinela",
		},
		"piece_bonuses": {"defensa": 6.0, "vitalidad": 3.0},
		"set_bonus": {"defensa": 25.0, "vida": 40.0, "res_magia": 20.0, "res_fuego": 20.0},
	},
	"berserker": {
		"name": "Furia del Berserker",
		"pieces": {
			"res://item/items/hacha_grande.tres": "Hacha del Berserker",
			"res://item/items/escudo_ligero.tres": "Rodela del Berserker",
		},
		"piece_bonuses": {"fuerza": 4.0, "daño_pct": 6.0},
		"set_bonus": {"daño_pct": 25.0, "velocidad_pct": 10.0, "daño_fuego": 10.0},
	},
	"cazador": {
		"name": "Ojo del Cazador",
		"pieces": {
			"res://item/items/ballesta_de_madera.tres": "Ballesta del Cazador",
			"res://item/items/espada_ligera.tres": "Daga del Cazador",
		},
		"piece_bonuses": {"destreza": 4.0, "critico": 2.0},
		"set_bonus": {"critico": 10.0, "velocidad_pct": 15.0, "daño_veneno": 12.0},
	},
}


static func get_set(set_id: String) -> Dictionary:
	return SETS.get(set_id, {})


## Ids de los sets que tienen todas sus piezas equipadas.
static func active_sets(equipped: Array) -> Array[String]:
	var result: Array[String] = []
	for set_id in SETS:
		var needed: int = SETS[set_id].pieces.size()
		var have: int = 0
		for item in equipped:
			if item and item.set_id == set_id:
				have += 1
		if have >= needed:
			result.append(set_id)
	return result


## Suma del bonus de los sets completos para una clave (ej: "defensa").
static func active_bonus(key: String, equipped: Array) -> float:
	var total: float = 0.0
	for set_id in active_sets(equipped):
		total += SETS[set_id].set_bonus.get(key, 0.0)
	return total


## Crea una pieza de set al azar (o de un set puntual) de nivel item_level.
static func generate_piece(item_level: int, set_id: String = "") -> Itemdata:
	if set_id.is_empty():
		set_id = SETS.keys().pick_random()
	var set_info: Dictionary = SETS[set_id]
	var base_path: String = set_info.pieces.keys().pick_random()
	var item: Itemdata = load(base_path).duplicate()
	item.base_path = base_path
	item.rarity = Itemdata.Rarity.SET
	item.set_id = set_id
	item.unique_name = set_info.pieces[base_path]
	item.min_damage = roundi(item.min_damage * 1.25)
	item.max_damage = roundi(item.max_damage * 1.25)
	item.defense = roundi(item.defense * 1.25)
	var bonuses: Dictionary = {}
	for key in set_info.piece_bonuses:
		bonuses[key] = float(roundi(set_info.piece_bonuses[key] * (1.0 + 0.15 * (item_level - 1))))
	item.bonuses = bonuses
	item.value = roundi(item.value * 6.0 * (1.0 + 0.1 * (item_level - 1)))
	return item
