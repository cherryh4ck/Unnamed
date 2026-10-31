class_name UniqueItems

## Items unicos (rareza naranja): nombre propio, un efecto especial (ver
## Itemdata.SPECIAL_TEXT) y una frase de historia. kind es el tipo de pieza
## (Itemdata.get_slot_kind); value es el rango del efecto a nivel 1 y
## per_level lo que sube por nivel del item.

const UNIQUES := [
	{"name": "Colmillo del Crepúsculo", "kind": "arma", "special": "robo_vida", "value": [4, 6], "per_level": 0.1,
		"lore": "Forjado con el diente de una bestia que nunca vio el sol."},
	{"name": "Lamento de Hierro", "kind": "arma", "special": "cadena", "value": [15, 22], "per_level": 0.3,
		"lore": "Cada golpe suena como un trueno a lo lejos."},
	{"name": "Mordida del Invierno", "kind": "arma", "special": "vida_golpe", "value": [3, 5], "per_level": 0.5,
		"lore": "El herrero que la hizo no volvió a sentir calor."},
	{"name": "Segadora Carmesí", "kind": "arma", "special": "robo_vida", "value": [5, 8], "per_level": 0.1,
		"lore": "Bebe primero; pregunta después."},
	{"name": "Muralla de Ceniza", "kind": "escudo", "special": "espinas", "value": [20, 30], "per_level": 0.5,
		"lore": "Sobrevivió al incendio de Kael. Su dueño, no."},
	{"name": "Égida del Ocaso", "kind": "escudo", "special": "aura_fuego", "value": [5, 8], "per_level": 1.2,
		"lore": "Al atardecer todavía arde por dentro."},
	{"name": "Bastión Silencioso", "kind": "escudo", "special": "espinas", "value": [25, 35], "per_level": 0.5,
		"lore": "Nadie que lo golpeó contó cómo fue."},
	{"name": "Corona del Rey Ahogado", "kind": "casco", "special": "vida_golpe", "value": [2, 4], "per_level": 0.4,
		"lore": "Todavía gotea, aunque nadie sabe de dónde."},
	{"name": "Piel del Dragón Viejo", "kind": "armadura", "special": "aura_fuego", "value": [6, 9], "per_level": 1.4,
		"lore": "Escamas que no terminan de enfriarse."},
	{"name": "Cota del Penitente", "kind": "armadura", "special": "espinas", "value": [25, 40], "per_level": 0.6,
		"lore": "Cada anillo, una promesa rota."},
	{"name": "Manos del Verdugo", "kind": "guantes", "special": "robo_vida", "value": [3, 5], "per_level": 0.1,
		"lore": "Nunca tiemblan."},
	{"name": "Grebas del Centinela Caído", "kind": "grebas", "special": "espinas", "value": [15, 25], "per_level": 0.4,
		"lore": "Las encontraron de pie, sin nadie adentro."},
	{"name": "Pasos de Ceniza", "kind": "botas", "special": "aura_fuego", "value": [4, 7], "per_level": 1.0,
		"lore": "Dejan el pasto chamuscado a cada paso."},
	{"name": "Faja del Glotón", "kind": "cinturon", "special": "vida_golpe", "value": [3, 5], "per_level": 0.5,
		"lore": "Nunca alcanza."},
	{"name": "Sello de la Tormenta", "kind": "anillo", "special": "cadena", "value": [12, 20], "per_level": 0.3,
		"lore": "Zumba cuando se acerca la lluvia."},
	{"name": "Ojo de la Bruja", "kind": "amuleto", "special": "robo_vida", "value": [3, 6], "per_level": 0.1,
		"lore": "Mira siempre hacia el cementerio."},
]


## Un unico al azar para ese tipo de pieza (o {} si no hay ninguno).
static func pick(kind: String) -> Dictionary:
	var options: Array = UNIQUES.filter(func(entry: Dictionary) -> bool: return entry.kind == kind)
	return options.pick_random() if not options.is_empty() else {}


## Convierte el item en ese unico: nombre, efecto (segun el nivel) e historia.
static func apply(item: Itemdata, entry: Dictionary, item_level: int) -> void:
	item.unique_name = entry.name
	item.special = entry.special
	var value: float = randf_range(entry.value[0], entry.value[1]) + entry.per_level * (item_level - 1)
	item.special_value = float(roundi(value))
	item.lore = entry.lore
