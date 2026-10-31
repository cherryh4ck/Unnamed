extends Node3D

## Pieza del mundo armada por world/build_world.gd: un modelo importado (hijo)
## con su colision. Al cargar:
## - deja solo la malla keep_only si el archivo trae varias (sets de rocas,
##   piezas del fuerte),
## - ajusta los materiales segun style para que todo combine,
## - la suma a la capa del mapa (la "foto" desde arriba del mapa grande),
## - si es alta (o viene marcada), se anota para desvanecerse cuando tapa al
##   jugador,
## - si es un fuego (fogata, brasero), le agrega llamas y luz.

enum Style { NONE, STONE, IRON, TINT }

const MAP_LAYER: int = 1 << 15
## Las piezas mas altas que esto (un poco mas de la mitad del jugador) se
## desvanecen al taparlo aunque no vengan marcadas: rocas grandes, estatuas...
const AUTO_FADE_HEIGHT: float = 230.0
# Bloques de piedra del fuerte: lapidas y criptas parecen de piedra tallada.
const STONE_ALBEDO := preload("res://assets/props/modular_fort_01/textures/modular_fort_01_wall_diff_1k.jpg")
const STONE_NORMAL := preload("res://assets/props/modular_fort_01/textures/modular_fort_01_wall_nor_gl_1k.jpg")

@export var style: Style = Style.NONE
## Multiplica el color de los materiales (Style.TINT y tambien STONE).
@export var tint: Color = Color.WHITE
## Nombre de la unica malla a mostrar ("" = todas).
@export var keep_only: String = ""
@export var fade_when_occluding: bool = false
@export var is_fire: bool = false
## Altura de las llamas (en unidades del mundo, relativa a la pieza).
@export var fire_height: float = 60.0

static var _materials: Dictionary = {}

## Caja de la pieza en el mundo (la usa el que desvanece lo que tapa al jugador).
var world_bounds: AABB
var meshes: Array[GeometryInstance3D] = []


func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not keep_only.is_empty() and mesh.name != keep_only:
			mesh.queue_free()
			continue
		mesh.layers |= MAP_LAYER
		_restyle(mesh)
		meshes.append(mesh)
	world_bounds = _compute_bounds()
	if fade_when_occluding or world_bounds.size.y > AUTO_FADE_HEIGHT:
		add_to_group("occluders")
	if is_fire:
		_add_fire()


func _restyle(mesh: MeshInstance3D) -> void:
	match style:
		Style.STONE:
			mesh.material_override = _stone_material(tint)
		Style.IRON:
			mesh.material_override = _iron_material()
		Style.TINT:
			for i in mesh.get_surface_override_material_count():
				var base: Material = mesh.get_active_material(i)
				if base is BaseMaterial3D:
					mesh.set_surface_override_material(i, _tinted(base, tint))


static func _stone_material(color: Color) -> StandardMaterial3D:
	var key: String = "stone|%s" % color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_texture = STONE_ALBEDO
		material.albedo_color = Color(0.78, 0.76, 0.72) * color
		material.normal_enabled = true
		material.normal_texture = STONE_NORMAL
		material.roughness = 0.95
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE / 420.0
		_materials[key] = material
	return _materials[key]


static func _iron_material() -> StandardMaterial3D:
	if not _materials.has("iron"):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.13, 0.13, 0.14)
		material.metallic = 0.75
		material.roughness = 0.5
		_materials["iron"] = material
	return _materials["iron"]


static func _tinted(base: BaseMaterial3D, color: Color) -> BaseMaterial3D:
	var key: String = "tint|%d|%s" % [base.get_instance_id(), color.to_html()]
	if not _materials.has(key):
		var material: BaseMaterial3D = base.duplicate()
		material.albedo_color = material.albedo_color * color
		_materials[key] = material
	return _materials[key]


func _compute_bounds() -> AABB:
	var bounds := AABB(global_position, Vector3.ZERO)
	var first: bool = true
	for mesh in meshes:
		var box: AABB = mesh.global_transform * (mesh as MeshInstance3D).get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _add_fire() -> void:
	var top := Vector3(global_position.x, world_bounds.end.y + fire_height * 0.2, global_position.z)
	var flames: CPUParticles3D = Effects.burning(self, top.y - global_position.y, 40.0 * scale.x / 280.0 + 20.0)
	flames.amount = 40
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 3.5
	light.omni_range = 1400.0
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	Effects.add_at(self, light, top + Vector3.UP * 120.0)
	light.set_script(preload("res://scripts/world/flicker_light.gd"))
