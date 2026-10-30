extends Resource

class_name EnemyData

## Tipo de enemigo: modelo, animaciones y stats base (a nivel 1).
## Cada tipo es un .tres en enemies/types/.

@export var name: String = "Enemigo"

@export_group("Modelo")
@export var model: PackedScene
@export var model_scale: float = 1.0
## Cuanto se sube el modelo para que los pies apoyen en el piso (a escala 1).
@export var model_offset_y: float = 290.0
## Color que multiplica la textura (blanco = sin cambio). Sirve para variantes.
@export var tint: Color = Color.WHITE
@export var collision_radius: float = 60.0

@export_group("Animaciones")
@export var idle_animation: String = ""
@export var walk_animations: Array[String] = []
@export var attack_animations: Array[String] = []
## Velocidad de la animacion de caminar (para bichos que solo traen una lenta).
@export var walk_animation_speed: float = 1.0
@export var death_animation: String = ""
## Si es true, la animacion de muerte se reproduce al reves (sirve cuando el
## modelo solo tiene una animacion de "levantarse del suelo").
@export var death_reversed: bool = false
## Animacion al aparecer (ej: salir del suelo). Mientras dura, el enemigo no se mueve.
@export var spawn_animation: String = ""
@export var spawn_animation_speed: float = 1.0

@export_group("Stats")
@export var max_health: float = 60.0
@export var min_damage: int = 5
@export var max_damage: int = 9
@export var defense: int = 0
@export var speed: float = 260.0
## Segundos entre ataques.
@export var attack_cooldown: float = 1.6
@export var attack_range: float = 230.0
@export var detection_range: float = 1200.0
## Parte del daño del ataque que es de otro tipo (ej: el zombi envenena).
@export var attack_damage_type: Damage.Type = Damage.Type.PHYSICAL
@export_range(0.0, 1.0) var attack_conversion: float = 0.0
## Ataca de lejos: en el momento del golpe tira una flecha hacia donde esta el
## jugador (se puede esquivar moviendose) en vez de pegar cuerpo a cuerpo.
@export var shoots: bool = false
@export var projectile_speed: float = 1800.0

@export_group("Resistencias")
## En %. Negativo = debilidad (recibe mas daño). El fisico se reduce con la defensa.
@export_range(-100, 75) var resist_magic: float = 0.0
@export_range(-100, 75) var resist_poison: float = 0.0
@export_range(-100, 75) var resist_fire: float = 0.0

@export_group("Sonidos")
## Nombres de scripts/audio/sfx.gd ("" = sin sonido).
@export var aggro_sound: String = ""
@export var attack_sound: String = ""
@export var death_sound: String = ""

@export_group("Recompensas")
@export var xp_reward: int = 20
@export var gold_min: int = 2
@export var gold_max: int = 10


func get_resistances() -> Dictionary:
	return {
		Damage.Type.MAGIC: resist_magic,
		Damage.Type.POISON: resist_poison,
		Damage.Type.FIRE: resist_fire,
	}
