class_name ItemSets

## Sets de items (rareza verde). Cada pieza tiene sus propias bonificaciones
## y el set da bonos escalonados: con 2 piezas puestas uno, con mas piezas
## otros que se suman (tiers: cantidad de piezas -> bonos).
## Las piezas pueden ser armas, escudos o partes de la armadura.

const I := "res://item/items/"

const SETS := {
	"centinela": {
		"name": "Vigilia del Centinela",
		"pieces": {
			I + "espada_ligera.tres": "Hoja del Centinela",
			I + "escudo_pesado.tres": "Muro del Centinela",
			I + "yelmo_hierro.tres": "Yelmo del Centinela",
			I + "cota_malla.tres": "Cota del Centinela",
			I + "grebas_hierro.tres": "Grebas del Centinela",
			I + "botas_hierro.tres": "Botas del Centinela",
		},
		"piece_bonuses": {"defensa": 6.0, "vitalidad": 3.0},
		"tiers": {
			2: {"defensa": 15.0},
			4: {"vida": 40.0, "res_magia": 15.0},
			6: {"defensa": 40.0, "res_fuego": 20.0, "vitalidad": 10.0},
		},
	},
	"berserker": {
		"name": "Furia del Berserker",
		"pieces": {
			I + "hacha_grande.tres": "Hacha del Berserker",
			I + "escudo_ligero.tres": "Rodela del Berserker",
			I + "armadura_cuero.tres": "Pellejo del Berserker",
			I + "guantes_cuero.tres": "Puños del Berserker",
			I + "botas_cuero.tres": "Botas del Berserker",
		},
		"piece_bonuses": {"fuerza": 4.0, "daño_pct": 6.0},
		"tiers": {
			2: {"daño_pct": 10.0},
			3: {"fuerza": 6.0, "vida": 25.0},
			5: {"daño_pct": 25.0, "velocidad_pct": 10.0, "daño_fuego": 10.0},
		},
	},
	"cazador": {
		"name": "Ojo del Cazador",
		"pieces": {
			I + "ballesta_de_madera.tres": "Ballesta del Cazador",
			I + "espada_ligera.tres": "Daga del Cazador",
			I + "capucha_cuero.tres": "Capucha del Cazador",
			I + "jubon_acolchado.tres": "Jubón del Cazador",
			I + "perneras_cuero.tres": "Perneras del Cazador",
			I + "cinturon_cuero.tres": "Cinto del Cazador",
		},
		"piece_bonuses": {"destreza": 4.0, "critico": 2.0},
		"tiers": {
			2: {"destreza": 5.0},
			4: {"critico": 6.0, "res_veneno": 15.0},
			6: {"critico": 10.0, "velocidad_pct": 15.0, "daño_veneno": 12.0},
		},
	},
	"arcano": {
		"name": "Vestiduras del Arcano",
		"pieces": {
			I + "capucha_lino.tres": "Capucha del Arcano",
			I + "jubon_acolchado.tres": "Túnica del Arcano",
			I + "anillo_gema.tres": "Sello del Arcano",
			I + "collar_cuentas.tres": "Rosario del Arcano",
			I + "cinturon_tachonado.tres": "Faja del Arcano",
		},
		"piece_bonuses": {"concentracion": 4.0, "res_magia": 5.0},
		"tiers": {
			2: {"concentracion": 6.0},
			3: {"daño_magia": 8.0, "vida": 20.0},
			5: {"daño_magia": 20.0, "res_magia": 20.0, "concentracion": 10.0},
		},
	},
}


static func get_set(set_id: String) -> Dictionary:
	return SETS.get(set_id, {})


## Cuantas piezas del set hay entre los items equipados.
static func count_equipped(set_id: String, equipped: Array) -> int:
	var have: int = 0
	for item in equipped:
		if item and item.set_id == set_id:
			have += 1
	return have


## Suma de los bonos de set activos para una clave (ej: "defensa").
static func active_bonus(key: String, equipped: Array) -> float:
	var total: float = 0.0
	for set_id in SETS:
		var have: int = count_equipped(set_id, equipped)
		if have < 2:
			continue
		var tiers: Dictionary = SETS[set_id].tiers
		for pieces in tiers:
			if have >= pieces:
				total += tiers[pieces].get(key, 0.0)
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
	item.defense = roundi(item.defense * 1.25 * (1.0 + 0.06 * (item_level - 1)))
	var bonuses: Dictionary = {}
	for key in set_info.piece_bonuses:
		bonuses[key] = float(roundi(set_info.piece_bonuses[key] * (1.0 + 0.15 * (item_level - 1))))
	item.bonuses = bonuses
	item.value = roundi(item.value * 6.0 * (1.0 + 0.1 * (item_level - 1)))
	return item
