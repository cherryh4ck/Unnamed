extends OmniLight3D

## Luz de fuego que titila (fogatas, braseros).

var _base: float
var _time: float = 0.0


func _ready() -> void:
	_base = light_energy
	_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta
	light_energy = _base * (0.85 + 0.1 * sin(_time * 13.0) + 0.06 * sin(_time * 29.0 + 1.3))
