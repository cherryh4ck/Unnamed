extends SceneTree

## Arma las gemas: un modelo tallado por tipo y calidad (item/gems/models/) y
## su item (item/items/gems/). La geometria se genera aca, no viene de afuera:
## una mesa arriba, la corona hasta el filo y el pabellon que termina en punta.
## La astillada sale irregular y opaca; la perfecta, con mas facetas y brillo.
##
##   godot --headless --path . --script res://item/gems/build_gems.gd

const GEMS := preload("res://scripts/items/gems.gd")
const ITEM_SCRIPT := preload("res://item/item_data.gd")
const GEM_TYPE: int = 5  # Itemdata.ItemType.GEM

## Facetas alrededor por calidad.
const SEGMENTS := [6, 8, 12]
const DESCRIPTION := "Se engarza en una ranura de un arma, un escudo o una ballesta. El herrero de la aldea la pone y la saca."


func _initialize() -> void:
	# Que el guardado del jugador no se toque.
	root.get_node("save_game").save_path = "user://build_gems_descartable.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GEMS.MODELS_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GEMS.ITEMS_DIR))
	for kind in GEMS.KIND_ORDER:
		for tier in GEMS.TIER_COUNT:
			var model_path: String = GEMS.model_path_for(kind, tier)
			_check(ResourceSaver.save(_model(kind, tier), model_path), model_path)
			var item_path: String = GEMS.path_for(kind, tier)
			_check(ResourceSaver.save(_item(kind, tier, model_path), item_path), item_path)
	print("gemas listas")
	quit()


func _check(error: int, path: String) -> void:
	if error != OK:
		push_error("No se pudo guardar %s: %s" % [path, error_string(error)])


func _item(kind: String, tier: int, model_path: String) -> Resource:
	# Si ya existe se reusa el recurso para que conserve su uid.
	var item_path: String = GEMS.path_for(kind, tier)
	var item: Resource = load(item_path) if ResourceLoader.exists(item_path) else ITEM_SCRIPT.new()
	item.name = GEMS.display_name(kind, tier)
	item.description = DESCRIPTION
	item.stackable = true
	item.item_type = GEM_TYPE
	item.model_3d = load(model_path)
	item.grid_size = Vector2i(1, 1)
	item.gem_kind = kind
	item.gem_tier = tier
	item.value = GEMS.TIER_VALUE[tier]
	return item


func _model(kind: String, tier: int) -> PackedScene:
	var root := Node3D.new()
	root.name = "Gema"
	var mesh := MeshInstance3D.new()
	mesh.name = "Talla"
	mesh.mesh = _cut(SEGMENTS[tier], tier == 0, hash(kind))
	mesh.material_override = _material(GEMS.color_of(kind), tier)
	root.add_child(mesh)
	mesh.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


# Talla brillante simplificada, con caras planas. chipped = radios y alturas
# al azar (semilla fija por tipo) para que parezca un pedazo roto.
func _cut(segments: int, chipped: bool, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var table_y: float = 0.32
	var culet_y: float = -0.72
	var girdle: Array[Vector3] = []
	var table: Array[Vector3] = []
	for i in segments:
		var angle: float = TAU * i / segments
		var radius: float = rng.randf_range(0.7, 1.05) if chipped else 1.0
		var top: float = rng.randf_range(0.55, 0.8) if chipped else 0.62
		girdle.append(Vector3(cos(angle) * radius, rng.randf_range(-0.06, 0.06) if chipped else 0.0, sin(angle) * radius))
		var table_angle: float = angle + (PI / segments)
		table.append(Vector3(cos(table_angle) * radius * top, table_y + (rng.randf_range(-0.08, 0.04) if chipped else 0.0), sin(table_angle) * radius * top))
	var table_center := Vector3(0.0, table_y, 0.0)
	var culet := Vector3(rng.randf_range(-0.12, 0.12) if chipped else 0.0, culet_y * (rng.randf_range(0.7, 0.9) if chipped else 1.0), 0.0)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0.0, -0.1, 0.0)
	for i in segments:
		var next: int = (i + 1) % segments
		# Mesa.
		_facet(st, center, table_center, table[i], table[next])
		# Corona: un rombo entre dos puntos de la mesa y uno del filo, y un
		# triangulo entre dos puntos del filo y uno de la mesa.
		_facet(st, center, table[i], table[next], girdle[next])
		_facet(st, center, girdle[i], table[i], girdle[next])
		# Pabellon.
		_facet(st, center, girdle[i], girdle[next], culet)
	return st.commit()


# Un triangulo con normal plana, mirando hacia afuera del centro. Godot toma
# como frente el orden horario, o sea la normal (c - a) x (b - a).
func _facet(st: SurfaceTool, center: Vector3, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.dot((a + b + c) / 3.0 - center) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	st.set_normal(normal.normalized())
	for vertex in [a, b, c]:
		st.add_vertex(vertex)


func _material(color: Color, tier: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var shine: Array[float] = [0.45, 0.12, 0.04]
	material.albedo_color = color.darkened(0.25 if tier == 0 else 0.0)
	material.metallic = 0.35
	material.metallic_specular = 0.9
	material.roughness = shine[tier]
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = [0.08, 0.22, 0.45][tier]
	material.rim_enabled = true
	material.rim = 0.4
	material.rim_tint = 0.6
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
