extends "res://scripts/world/chest.gd"

## Baul personal de la aldea: el mismo cofre, pero al hacerle clic abre el
## panel del baul (ui/stash_panel.gd) con la grilla inventory_data.stash. La
## tapa se cierra cuando se cierra el panel.

signal interacted(stash: Node3D)

@export var map_icon: Texture2D
@export var map_icon_color: Color = Color(0.85, 0.65, 0.4)


func _ready() -> void:
	super()
	remove_from_group("chests")
	add_to_group("stashes")
	# El panel pausa el juego: la tapa se tiene que mover igual.
	process_mode = Node.PROCESS_MODE_ALWAYS


func get_display_name() -> String:
	return "Baúl"


func interact() -> void:
	if not opened:
		opened = true
		_animate_lid(true)
		sfx.play_at("chest_open", global_position)
	interacted.emit(self)


func close_lid() -> void:
	if opened:
		opened = false
		_animate_lid(false)


# El baul se puede abrir siempre.
func _was_opened() -> bool:
	return false
