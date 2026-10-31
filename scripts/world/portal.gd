extends StaticBody3D

## Portal: un anillo de piedras con un circulo que brilla en el piso.
## Se descubre al pasar cerca (queda en el mapa y pasa a ser punto de
## reaparicion); haciendo clic se abre el mapa para viajar a otro portal ya
## descubierto. Esta en el grupo "npcs": el jugador camina hasta el y llama a
## interact(), igual que con el comerciante.

const PROP_SCRIPT := preload("res://scripts/world/prop.gd")
const STONE := "res://assets/props/graveyard/pillar-obelisk.glb"
const DISCOVER_RADIUS: float = 520.0
const RING_RADIUS: float = 270.0
const STONE_COUNT: int = 6
const COLOR := Color(0.45, 0.75, 1.0)
const DORMANT_COLOR := Color(0.28, 0.32, 0.4)

@export var portal_id: String = ""
@export var display_name: String = "Portal"

var _sigil: MeshInstance3D
var _sigil_material: StandardMaterial3D
var _wisps: CPUParticles3D
var _light: OmniLight3D
var _label: Label3D
var _check_timer: float = 0.0


func _ready() -> void:
	add_to_group("portals")
	add_to_group("npcs")
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 190.0
	cylinder.height = 80.0
	shape.shape = cylinder
	shape.position.y = 40.0
	add_child(shape)

	for i in STONE_COUNT:
		var angle: float = TAU * i / STONE_COUNT
		var stone := Node3D.new()
		stone.set_script(PROP_SCRIPT)
		stone.style = PROP_SCRIPT.Style.STONE
		stone.tint = Color(0.75, 0.76, 0.8)
		stone.transform = Transform3D(Basis(Vector3.UP, -angle + PI * 0.5).scaled(Vector3.ONE * (380.0 + 40.0 * (i % 2))),
				Vector3(cos(angle), 0.0, sin(angle)) * RING_RADIUS)
		stone.add_child(load(STONE).instantiate())
		add_child(stone)

	_sigil_material = StandardMaterial3D.new()
	_sigil_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sigil_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sigil_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_sigil_material.albedo_texture = Effects.SIGIL
	_sigil = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(RING_RADIUS * 2.1, RING_RADIUS * 2.1)
	plane.material = _sigil_material
	_sigil.mesh = plane
	_sigil.position.y = 8.0
	_sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sigil)

	_wisps = Effects.particles(Effects.MAGIC, true, Effects.STRIP_FRAMES, 26, 1.6, 90.0)
	_wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_wisps.emission_ring_axis = Vector3.UP
	_wisps.emission_ring_radius = RING_RADIUS * 0.7
	_wisps.emission_ring_inner_radius = RING_RADIUS * 0.2
	_wisps.emission_ring_height = 5.0
	_wisps.direction = Vector3.UP
	_wisps.spread = 8.0
	_wisps.initial_velocity_min = 90.0
	_wisps.initial_velocity_max = 170.0
	_wisps.gravity = Vector3.ZERO
	_wisps.angle_min = -180.0
	_wisps.angle_max = 180.0
	_wisps.color_ramp = Effects.ramp([Color(COLOR, 0.0), COLOR.lightened(0.3), Color(COLOR, 0.0)])
	_wisps.position.y = 20.0
	add_child(_wisps)

	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.omni_range = 900.0
	# Sin caida por distancia: con la escala del mundo no llegaba al piso.
	_light.omni_attenuation = 0.0
	_light.position.y = 160.0
	add_child(_light)

	_label = Label3D.new()
	_label.text = display_name
	_label.position.y = 560.0
	_label.layers = 2
	_label.pixel_size = 0.0016
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.font_size = 26
	_label.outline_size = 8
	_label.modulate = COLOR.lightened(0.35)
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	add_child(_label)

	_refresh()
	world_map.portal_discovered.connect(func(_id: String, _name: String) -> void: _refresh())


func is_discovered() -> bool:
	return world_map.is_portal_discovered(portal_id)


## Donde aparece el jugador al llegar (al lado del anillo, fuera de la colision).
func arrival_point() -> Vector3:
	return global_position + Vector3(0.0, 0.0, RING_RADIUS + 120.0)


func _refresh() -> void:
	var active: bool = is_discovered()
	_sigil_material.albedo_color = COLOR if active else DORMANT_COLOR
	_wisps.emitting = active
	_light.light_energy = 1.0 if active else 0.0
	_label.visible = active


func _process(delta: float) -> void:
	_sigil.rotate_y(delta * (0.35 if is_discovered() else 0.08))
	_check_timer -= delta
	if _check_timer > 0.0 or is_discovered():
		return
	_check_timer = 0.25
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and player.global_position.distance_to(global_position) <= DISCOVER_RADIUS:
		world_map.discover_portal(portal_id, display_name)
		sfx.play_at("portal", global_position)
		Effects.aura(get_parent(), global_position, COLOR)


## Clic en el portal: abre el mapa para elegir a donde viajar.
func interact() -> void:
	if not is_discovered():
		world_map.discover_portal(portal_id, display_name)
	var panel: Node = get_tree().get_first_node_in_group("world_map_panel")
	if panel:
		panel.open_travel(portal_id)
