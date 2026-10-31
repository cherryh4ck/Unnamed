extends StaticBody3D

## Santuario: un obelisco con un anillo que brilla en el piso. Al tocarlo da
## una bendicion por un rato (mas daño, experiencia, velocidad de ataque,
## regeneracion o proteccion) y despues tarda en volver a cargarse. Esta en
## el grupo "npcs" (el clic hace caminar al jugador hasta el) y tiene icono en
## el mapa grande. Lo arma world/build_world.gd con el modelo como hijo.

enum Blessing { STRENGTH, WISDOM, SWIFTNESS, LIFE, PROTECTION }

const BLESSINGS := {
	Blessing.STRENGTH: {"name": "Bendición de fuerza", "color": Color(1.0, 0.45, 0.3),
		"icon": "res://assets/icons/game-icons/lorc/fist.svg", "damage_mult": 1.25},
	Blessing.WISDOM: {"name": "Bendición de sabiduría", "color": Color(0.55, 0.62, 1.0),
		"icon": "res://assets/icons/game-icons/lorc/scroll-unfurled.svg", "xp_mult": 1.5},
	Blessing.SWIFTNESS: {"name": "Bendición de celeridad", "color": Color(0.45, 1.0, 0.85),
		"icon": "res://assets/icons/game-icons/lorc/whirlwind.svg", "attack_speed_mult": 1.25},
	Blessing.LIFE: {"name": "Bendición de vida", "color": Color(0.45, 1.0, 0.45),
		"icon": "res://assets/icons/game-icons/delapouite/health-potion.svg", "regen": 4.0},
	Blessing.PROTECTION: {"name": "Bendición de protección", "color": Color(0.95, 0.82, 0.4),
		"icon": "res://assets/icons/game-icons/lorc/checked-shield.svg", "defense": 20.0, "resist": 15.0},
}
## Cuanto dura la bendicion y cuanto tarda en recargarse (segundos de juego).
const DURATION: float = 120.0
const RECHARGE: float = 300.0
const MAP_ICON := preload("res://assets/icons/game-icons/lorc/magic-swirl.svg")
const SOUND := "res://sounds/interact/shrine/blessing.ogg"
const BELL := "res://sounds/interact/shrine/bong.ogg"
const SIGIL_SIZE: float = 620.0

@export var blessing: Blessing = Blessing.STRENGTH

## Para el mapa grande (ui/world_map_panel.gd).
var map_icon: Texture2D = MAP_ICON
var map_icon_color: Color = Color.WHITE

var _recharge: float = 0.0
var _sigil: MeshInstance3D
var _sigil_material: StandardMaterial3D
var _orb_material: StandardMaterial3D
var _motes: CPUParticles3D
var _shine: float = 1.0


func _ready() -> void:
	add_to_group("npcs")
	add_to_group("shrines")
	map_icon_color = get_info().color
	_build_visuals()


func get_info() -> Dictionary:
	return BLESSINGS[blessing]


func get_display_name() -> String:
	return "Santuario (%s)" % get_info().name.to_lower()


func is_charged() -> bool:
	return _recharge <= 0.0


func interact() -> void:
	var info: Dictionary = get_info()
	var head: Vector3 = global_position + Vector3.UP * 520.0
	if not is_charged():
		floating_text.spawn(head, "El santuario se está recargando (%d s)" % ceili(_recharge), Color(0.7, 0.7, 0.7), 16)
		return
	var buff: Dictionary = info.duplicate()
	buff.erase("color")
	buff["icon"] = load(info.icon)
	buff["duration"] = DURATION
	player_stats.add_buff("santuario_%d" % blessing, buff)
	_recharge = RECHARGE
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		Effects.aura(player.get_parent(), player.global_position, info.color)
		floating_text.spawn(player.global_position + Vector3.UP * 450.0, info.name, info.color, 24, 1.8)
	Effects.shockwave(get_parent(), global_position, info.color, 600.0, 0.9)
	_play(SOUND, -2.0)
	_play(BELL, -6.0)


func _process(delta: float) -> void:
	if _recharge > 0.0:
		_recharge = maxf(_recharge - delta, 0.0)
		if _recharge <= 0.0:
			_play(BELL, -10.0)
	# Cargado brilla y suelta chispas; recargando queda apagado.
	_shine = move_toward(_shine, 1.0 if is_charged() else 0.15, delta * 0.8)
	var pulse: float = 0.85 + 0.15 * sin(Time.get_ticks_msec() / 1000.0 * 2.2)
	_sigil_material.albedo_color.a = 0.75 * _shine * pulse
	_orb_material.albedo_color.a = 0.9 * _shine * pulse
	_motes.emitting = is_charged()
	_sigil.rotation.y += delta * 0.25


func _build_visuals() -> void:
	var color: Color = get_info().color
	_sigil_material = _glow_material(Effects.RING, color, false)
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIGIL_SIZE, SIGIL_SIZE)
	plane.material = _sigil_material
	_sigil = MeshInstance3D.new()
	_sigil.mesh = plane
	_sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sigil.position.y = 12.0
	add_child(_sigil)
	_orb_material = _glow_material(Effects.GLOW, color, true)
	var quad := QuadMesh.new()
	quad.size = Vector2(170, 170)
	quad.material = _orb_material
	var orb := MeshInstance3D.new()
	orb.mesh = quad
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.position.y = 470.0
	add_child(orb)
	_motes = Effects.particles(Effects.SOFT, true, 1, 18, 2.2, 26.0)
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_motes.emission_ring_axis = Vector3.UP
	_motes.emission_ring_radius = SIGIL_SIZE * 0.26
	_motes.emission_ring_inner_radius = SIGIL_SIZE * 0.18
	_motes.emission_ring_height = 1.0
	_motes.direction = Vector3.UP
	_motes.spread = 10.0
	_motes.gravity = Vector3.ZERO
	_motes.initial_velocity_min = 70.0
	_motes.initial_velocity_max = 140.0
	_motes.color_ramp = Effects.ramp([Color(color, 0.0), Color(color, 0.9), Color(color.lightened(0.4), 0.0)])
	_motes.position.y = 20.0
	add_child(_motes)


static func _glow_material(texture: Texture2D, color: Color, billboard: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = texture
	material.albedo_color = Color(color, 0.75)
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return material


func _play(path: String, volume_db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer3D.new()
	player.bus = &"Efectos"
	player.stream = load(path)
	player.volume_db = volume_db
	player.unit_size = sfx.UNIT_SIZE_3D
	player.max_distance = sfx.MAX_DISTANCE_3D
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
