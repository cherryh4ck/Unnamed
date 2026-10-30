extends StaticBody3D

## NPC de la aldea: tiene nombre arriba de la cabeza, mira al jugador cuando
## se acerca y al hacerle clic el jugador camina hasta el y llama a interact().
## Cada oficio (comerciante, herrero) extiende este script y su panel se
## conecta a interacted segun el grupo del NPC.

signal interacted(npc: Node3D)

@export var display_name: String = "Aldeano"
@export var idle_animation: String = ""
## Icono en el mapa grande (Tab). Sin icono no aparece.
@export var map_icon: Texture2D
@export var map_icon_color: Color = Color(1.0, 0.84, 0.35)

@onready var anim_player: AnimationPlayer = find_child("AnimationPlayer", true, false)


func _ready() -> void:
	add_to_group("npcs")
	if anim_player and anim_player.has_animation(idle_animation):
		anim_player.get_animation(idle_animation).loop_mode = Animation.LOOP_LINEAR
		anim_player.play(idle_animation)
	$NameLabel.text = display_name


func _process(delta: float) -> void:
	# Mira al jugador cuando esta cerca.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < 900.0:
		var dir: Vector3 = player.global_position - global_position
		dir.y = 0.0
		if dir.length() > 1.0:
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 4.0 * delta)


func get_display_name() -> String:
	return display_name


func interact() -> void:
	interacted.emit(self)
