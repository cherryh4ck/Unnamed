extends Node
@export var vida: int = 100
@export var max_vida: int = 100
@export var nivel: int = 1
@export var exp: int = 0
@export var exp_level: int = 25

@onready var label_vida = $Control/Vida
@onready var label_nivel = $Control/Nivel

func _ready() -> void:
	label_vida.text = "Vida: " + str(vida) + "/" + str(max_vida)
	label_nivel.text = "Nivel: " + str(nivel)

func _process(delta: float) -> void:
	label_vida.text = "Vida: " + str(vida) + "/" + str(max_vida)
	label_nivel.text = "Nivel: " + str(nivel)
