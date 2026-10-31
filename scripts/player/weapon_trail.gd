extends MeshInstance3D

## Estela del arma mientras el jugador pega cuerpo a cuerpo: una cinta entre
## la mitad y la punta de la hoja que se va borrando. Va como hijo del modelo
## del jugador (player_1.gd) pero se dibuja en coordenadas del mundo.

## Segundos que dura cada tramo de la estela.
const LIFETIME: float = 0.16
const COLOR := Color(1.0, 0.95, 0.85, 0.28)
## Desde que parte de la hoja arranca la estela (0 = mango, 1 = punta).
const BLADE_START: float = 0.5

var _samples: Array = []
var _strip := ImmediateMesh.new()
var _weapon: Node = null
var _length: float = 0.0

@onready var _player: Node3D = get_parent()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _strip
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material_override = material


func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if _player.attacking and not player_stats.is_ranged():
		var blade: Array = _blade()
		if not blade.is_empty():
			_samples.append([blade[0], blade[1], now])
	while not _samples.is_empty() and now - _samples[0][2] > LIFETIME:
		_samples.pop_front()
	_strip.clear_surfaces()
	if _samples.size() < 2:
		return
	_strip.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for sample in _samples:
		var fade: float = 1.0 - (now - sample[2]) / LIFETIME
		_strip.surface_set_color(Color(COLOR, COLOR.a * fade * 0.3))
		_strip.surface_add_vertex(sample[0])
		_strip.surface_set_color(Color(COLOR, COLOR.a * fade))
		_strip.surface_add_vertex(sample[1])
	_strip.surface_end()


# Mitad y punta de la hoja del arma en la mano derecha. Las armas de 0 A.D.
# apuntan por el eje Y del hueso; el largo sale del tamaño del modelo.
func _blade() -> Array:
	var skeleton: Skeleton3D = _player.skeleton
	if skeleton == null:
		return []
	var hand: Node3D = skeleton.get_node_or_null("Equipo_prop-weapon_R")
	if hand == null or hand.get_child_count() == 0:
		return []
	if _weapon != hand.get_child(0):
		_weapon = hand.get_child(0)
		_length = _weapon_length(hand)
	if _length <= 0.0:
		return []
	var t: Transform3D = hand.global_transform
	return [t * Vector3(0.0, _length * BLADE_START, 0.0), t * Vector3(0.0, _length, 0.0)]


func _weapon_length(hand: Node3D) -> float:
	var to_hand: Transform3D = hand.global_transform.affine_inverse()
	var tip: float = 0.0
	for mesh in hand.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = to_hand * mesh.global_transform * (mesh as MeshInstance3D).get_aabb()
		tip = maxf(tip, box.end.y)
	return tip
