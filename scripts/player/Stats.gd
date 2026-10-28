extends Node

## Labels provisorios de vida y nivel (los datos viven en el autoload player_stats).

@onready var label_vida = $Control/Vida
@onready var label_nivel = $Control/Nivel

func _ready() -> void:
	player_stats.health_changed.connect(_refresh.unbind(2))
	player_stats.stats_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	label_vida.text = "Vida: %d/%d" % [ceili(player_stats.health), roundi(player_stats.get_max_health())]
	label_nivel.text = "Nivel: " + str(player_stats.level)
