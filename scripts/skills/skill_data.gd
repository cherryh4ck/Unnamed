extends Resource

class_name SkillData

## Habilidad del jugador. No usan mana: cada una tiene un tiempo de recarga
## que se acorta con Concentracion. Cada habilidad es un .tres en skills/.

enum Kind {
	STRIKE,      # golpe fuerte a un enemigo (camina hasta el si esta lejos)
	WHIRLWIND,   # daño a todos los enemigos alrededor
	PROJECTILE,  # proyectil hacia el mouse que explota en area
	BUFF,        # mejora temporal del personaje
}

@export var name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var kind: Kind = Kind.STRIKE
@export var unlock_level: int = 1
## Segundos de recarga con Concentracion 0.
@export var base_cooldown: float = 5.0

@export_group("Daño")
@export var damage_multiplier: float = 1.0
@export var radius: float = 0.0
## Distancia maxima del proyectil.
@export var max_range: float = 0.0

@export_group("Mejora temporal")
@export var buff_duration: float = 0.0
@export var buff_damage_multiplier: float = 1.0
@export var buff_attack_speed_multiplier: float = 1.0
@export var buff_defense: int = 0

@export_group("Presentacion")
@export var sound: String = ""
@export var animation: String = ""
@export var animation_speed: float = 1.0
@export var effect_color: Color = Color.WHITE


func get_cooldown() -> float:
	return base_cooldown * player_stats.get_cooldown_multiplier()


func get_tooltip() -> String:
	var lines := PackedStringArray([name, description])
	lines.append("Recarga: %.1f s" % get_cooldown())
	if player_stats.level < unlock_level:
		lines.append("Se aprende en el nivel %d" % unlock_level)
	return "\n".join(lines)
