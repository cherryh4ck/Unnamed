class_name PlayerClasses

## Clases del personaje. Se elige una al empezar una partida nueva (pantalla
## de titulo o menu del juego) y queda fija: cambia los atributos iniciales,
## las cinco habilidades (skills/) y el equipo con el que se arranca.
## El mago no depende del arma: sus hechizos y su ataque basico (un rayo
## arcano a distancia) se calculan con el nivel y la Concentracion.
##
## model: personaje de 0 A.D. (assets/characters/oad/, CC BY-SA 3.0).
## anims: clips del modelo para cada cosa que hace el jugador. "skills" usa
## las claves de SkillData.animation; cada entrada es [clip, desde] donde
## desde es la fraccion del clip donde arranca (los de 0 A.D. son largos y
## empiezan preparando el golpe). Los clips "oad/..." salen de la biblioteca
## compartida (assets/characters/oad/oad_anim_library.glb). run_speed: metros
## por segundo que avanza el clip de correr (para que los pies no patinen).

const DEFAULT := "guerrero"
const ORDER := ["guerrero", "cazadora", "mago"]
## Pociones con las que arranca cualquier clase.
const START_POTIONS: int = 3

const CLASSES := {
	"guerrero": {
		"name": "Guerrero",
		"description": "Pelea cuerpo a cuerpo con espada y escudo. Aguanta mucho castigo y sus golpes tiran abajo a cualquiera.",
		"color": Color(0.9, 0.5, 0.32),
		"icon": "res://assets/icons/game-icons/lorc/broadsword.svg",
		"attributes": {"fuerza": 14, "destreza": 10, "vitalidad": 14, "concentracion": 6},
		"skills": [
			"res://skills/golpe_brutal.tres",
			"res://skills/torbellino.tres",
			"res://skills/sacudida.tres",
			"res://skills/furia.tres",
			"res://skills/piel_de_piedra.tres",
		],
		"items": ["res://item/items/espada_ligera.tres", "res://item/items/escudo_ligero.tres"],
		"model": "res://assets/characters/oad/characters/warrior.glb",
		"anims": {
			"idle": "idle", "run": "run", "run_speed": 2.3, "death": "death",
			"attacks": ["attack_1h_a", "attack_1h_b", "attack_1h_c"], "attack_from": 0.0,
			"ride_idle": "ride_idle", "ride_move": "ride_gallop",
			"skills": {"golpe": ["attack_2h", 0.1], "giro": ["attack_1h_c", 0.0], "disparo": ["attack_1h_b", 0.0],
				"hechizo": ["cheer", 0.0], "grito": ["cheer", 0.0]},
		},
	},
	"cazadora": {
		"name": "Cazadora",
		"description": "Ataca desde lejos con la ballesta: virotes certeros, envenenados o en ráfaga. Rápida y precisa, pero frágil de cerca.",
		"color": Color(0.55, 0.8, 0.4),
		"icon": "res://assets/icons/game-icons/carl-olsen/crossbow.svg",
		"attributes": {"fuerza": 9, "destreza": 15, "vitalidad": 10, "concentracion": 10},
		"skills": [
			"res://skills/disparo_certero.tres",
			"res://skills/virote_venenoso.tres",
			"res://skills/abanico_de_virotes.tres",
			"res://skills/ojo_de_halcon.tres",
			"res://skills/lluvia_de_virotes.tres",
		],
		"items": ["res://item/items/ballesta_de_madera.tres"],
		"model": "res://assets/characters/oad/characters/hunter.glb",
		"anims": {
			"idle": "idle_crossbow", "run": "run_crossbow", "run_speed": 2.9, "death": "death",
			"attacks": ["shoot_crossbow"], "attack_from": 0.55,
			"ride_idle": "ride_idle", "ride_move": "ride_gallop",
			"skills": {"golpe": ["shoot_crossbow", 0.55], "giro": ["shoot_crossbow", 0.55], "disparo": ["shoot_crossbow", 0.55],
				"hechizo": ["oad/cheer", 0.0], "grito": ["oad/cheer", 0.0]},
		},
	},
	"mago": {
		"name": "Mago",
		"description": "Domina el fuego y la magia arcana. Sus hechizos crecen con la Concentración; sin arma, ataca a distancia con rayos arcanos.",
		"color": Color(0.55, 0.6, 1.0),
		"icon": "res://assets/icons/game-icons/lorc/wizard-staff.svg",
		"attributes": {"fuerza": 6, "destreza": 9, "vitalidad": 9, "concentracion": 18},
		"skills": [
			"res://skills/rayo_arcano.tres",
			"res://skills/bola_de_fuego.tres",
			"res://skills/anillo_de_llamas.tres",
			"res://skills/escudo_arcano.tres",
			"res://skills/meteoro.tres",
		],
		"items": [],
		"model": "res://assets/characters/oad/characters/priest.glb",
		"anims": {
			"idle": "idle", "run": "oad/run_blacksmith", "run_speed": 2.3, "death": "death",
			"attacks": ["attack_staff"], "attack_from": 0.0,
			"ride_idle": "ride_idle", "ride_move": "ride_gallop",
			"skills": {"golpe": ["attack_staff", 0.0], "giro": ["cast_heal", 0.35], "disparo": ["attack_staff", 0.0],
				"hechizo": ["cast_heal", 0.35], "grito": ["pray", 0.0]},
		},
	},
}


static func get_info(id: String) -> Dictionary:
	return CLASSES.get(id, CLASSES[DEFAULT])


static func name_of(id: String) -> String:
	return get_info(id).name


static func is_valid(id: String) -> bool:
	return CLASSES.has(id)
