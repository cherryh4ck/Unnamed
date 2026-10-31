extends Node3D

## Luz que se prende de noche (faroles, linternas, antorchas): una luz calida
## que titila, un brillo sobre la fuente y, en las antorchas, llamas. Se
## prende al atardecer y se apaga al amanecer (world_time). De las cercanas al
## jugador, scripts/world/ambience.gd deja prendida la luz solo de algunas: el
## renderizador Mobile ilumina cada objeto con pocas luces a la vez.

## Horas en que se prende y se apaga (un poco antes de que oscurezca).
const ON_HOUR: float = 19.0
const OFF_HOUR: float = 6.5
## Cuanto tarda en prenderse o apagarse del todo, en segundos.
const FADE_TIME: float = 2.0

@export var energy: float = 1.2
@export var light_range: float = 1000.0
@export var color: Color = Color(1.0, 0.66, 0.34)
## Antorcha: con llamas y titila mas.
@export var flames: bool = false
@export var glow_size: float = 110.0

## Lo decide ambience.gd: si la luz de verdad (OmniLight) puede estar prendida.
var allowed: bool = true

var _light: OmniLight3D
var _glow: MeshInstance3D
var _glow_material: StandardMaterial3D
var _flames: CPUParticles3D
var _amount: float = 0.0
# Cuanto de la OmniLight se ve (se funde al entrar o salir de las permitidas).
var _allow: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	add_to_group("night_lights")
	_time = randf() * 10.0
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.omni_range = light_range
	# Sin caida por distancia: el mundo esta en unidades grandes (~225 por
	# metro) y con la caida normal la luz no llegaba al piso; asi se apaga
	# suave hasta light_range.
	_light.omni_attenuation = 0.0
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	_glow_material = StandardMaterial3D.new()
	_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glow_material.albedo_texture = Effects.GLOW
	_glow_material.albedo_color = Color(color, 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(glow_size, glow_size)
	quad.material = _glow_material
	_glow = MeshInstance3D.new()
	_glow.mesh = quad
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.visible = false
	add_child(_glow)
	if flames:
		_flames = Effects.burning(self, 0.0, 10.0)
		_flames.amount = 14
		_flames.scale_amount_min = 0.35
		_flames.scale_amount_max = 0.5
		_flames.initial_velocity_min = 40.0
		_flames.initial_velocity_max = 90.0
		_flames.emitting = false
	_amount = 1.0 if is_lit_hour() else 0.0


func is_lit_hour() -> bool:
	return world_time.hour >= ON_HOUR or world_time.hour < OFF_HOUR


func _process(delta: float) -> void:
	_time += delta
	var goal: float = 1.0 if is_lit_hour() else 0.0
	_amount = move_toward(_amount, goal, delta / FADE_TIME)
	var on: bool = _amount > 0.01
	_allow = move_toward(_allow, 1.0 if allowed else 0.0, delta / FADE_TIME)
	_glow.visible = on
	_light.visible = on and _allow > 0.01
	if _flames:
		_flames.emitting = _amount > 0.5
	if not on:
		return
	# Las llamas titilan mas que los faroles.
	var depth: float = 1.0 if flames else 0.4
	var flicker: float = 1.0 + depth * (0.1 * sin(_time * 13.0) + 0.06 * sin(_time * 29.0 + 1.3) - 0.08)
	_light.light_energy = energy * _amount * _allow * flicker
	_glow_material.albedo_color.a = 0.5 * _amount * flicker
