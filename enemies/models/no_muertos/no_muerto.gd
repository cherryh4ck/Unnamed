extends Node3D

## Modelo de no-muerto armado sobre un personaje de 0 A.D.: le suma al
## AnimationPlayer los clips propios (levantarse del suelo, quieto y caminar
## de zombi) como "no_muerto/<clip>". Los genera build_no_muertos.gd.

const ANIMATIONS: AnimationLibrary = preload("res://enemies/models/no_muertos/animaciones.res")


func _ready() -> void:
	var player: AnimationPlayer = find_child("AnimationPlayer", true, false)
	if player and not player.has_animation_library("no_muerto"):
		player.add_animation_library("no_muerto", ANIMATIONS)
