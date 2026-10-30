extends SceneTree

## Arma el mundo (world/mundo.tscn) con los assets libres de assets/:
## piso con mapas de mezcla (caminos, adoquines, bosque, musgo, piedra), las
## piezas de cada zona con su colision, las zonas de enemigos, los portales,
## los nombres de cada lugar para el mapa y la navegacion horneada.
## Es deterministico (semilla fija): correrlo de nuevo da el mismo mundo.
##
##   godot --headless --path . --script res://world/build_world.gd

const OUT_SCENE := "res://world/mundo.tscn"
const OUT_NAV := "res://world/mundo_nav.res"
const SPLAT_A := "res://world/terrain/splat_a.png"
const SPLAT_B := "res://world/terrain/splat_b.png"
const SEED: int = 20261029

const SIZE: float = 20000.0
const HALF: float = SIZE / 2.0
## Hasta donde se puede caminar (mas alla hay bosque cerrado y paredes invisibles).
const WALK_LIMIT: float = 9200.0
const SPLAT_RES: int = 1024
const PATH_WIDTH: float = 230.0

const PROP_SCRIPT := preload("res://scripts/world/prop.gd")
const ZONE_SCENE := "res://zona_spawn.tscn"
const PORTAL_SCENE := "res://world/portal.tscn"
const ENEMY_SCENE := "res://enemi.tscn"

const N := "res://assets/nature/"
const P := "res://assets/props/"
const G := "res://assets/props/graveyard/"
const V := "res://assets/props/village/"

# Modelos: ruta, escala (unidades del mundo por unidad del modelo), radio de
# colision relativo al ancho del modelo (0 = sin colision), estilo, tinte.
const BROADLEAF := [N + "qt_tree_01/qt_tree_01.glb", N + "qt_tree_02/qt_tree_02.glb"]
const PINES := [N + "qt_pine_01/qt_pine_01.glb", N + "qt_pine_02/qt_pine_02.glb"]
const DEAD_TREES := [N + "qt_dead_tree_01/qt_dead_tree_01.glb", N + "qt_dead_tree_02/qt_dead_tree_02.glb"]
const TWISTED := N + "qt_twisted_tree_01/qt_twisted_tree_01.glb"
const ROCK_SET := N + "rock_moss_set_01/rock_moss_set_01_1k.gltf"
const ROCK_PIECES := ["rock_moss_set_01_rock01", "rock_moss_set_01_rock02", "rock_moss_set_01_rock03", "rock_moss_set_01_rock04", "rock_moss_set_01_rock05", "rock_moss_set_01_rock06"]
const BOULDERS := [N + "rock_07/rock_07_1k.gltf", N + "rock_09/rock_09_1k.gltf"]
const FERN := N + "fern_02/fern_02_1k.gltf"
const FERN_PIECES := ["fern_02_a", "fern_02_b", "fern_02_c", "fern_02_d"]
const SHRUB := N + "shrub_02/shrub_02_1k.gltf"
const SHRUB_PIECES := ["shrub_02_a", "shrub_02_b", "shrub_02_c", "shrub_02_d"]
const STUMP := N + "tree_stump_01/tree_stump_01_1k.gltf"
const FORT := P + "modular_fort_01/modular_fort_01_1k.gltf"
const GRAVESTONES := ["gravestone-bevel", "gravestone-broken", "gravestone-cross", "gravestone-cross-large", "gravestone-decorative", "gravestone-round", "gravestone-wide", "gravestone-roof"]

const FOLIAGE_TINT := Color(0.78, 0.82, 0.74)
const VILLAGE_TINT := Color(0.86, 0.82, 0.78)

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _root: Node3D
var _props: Node3D
## Puntos ocupados (x, z, radio) para no encimar piezas.
var _occupied: Array[Vector3] = []
var _scene_cache: Dictionary = {}

## Caminos de tierra: listas de puntos (x, z).
var _paths: Array = [
	[Vector2(0, -200), Vector2(-1500, -500), Vector2(-3000, -900), Vector2(-4300, -1300), Vector2(-5600, -2000)],
	[Vector2(0, -200), Vector2(1500, -900), Vector2(2800, -1900), Vector2(3800, -3000), Vector2(4900, -3900)],
	[Vector2(0, -200), Vector2(200, -1800), Vector2(500, -3500), Vector2(-200, -5200), Vector2(-500, -6400), Vector2(0, -7300)],
	[Vector2(-4300, -1300), Vector2(-4000, -3400), Vector2(-3000, -5200), Vector2(-1600, -6300), Vector2(-500, -6400)],
	[Vector2(0, -200), Vector2(400, 1500), Vector2(-300, 3200), Vector2(600, 5200)],
]

## Zonas: centro (x, z) y radio.
const VILLAGE := Vector3(0, -200, 1500)
const FOREST := Vector3(-6200, -2700, 3300)
const GRAVEYARD := Vector3(5600, -4800, 2100)
const RUINS := Vector3(0, -7800, 1900)


func _initialize() -> void:
	# Que el guardado del jugador no se toque mientras se arma el mundo.
	root.get_node("save_game").save_path = "user://build_world_descartable.json"
	_rng.seed = SEED
	_noise.seed = SEED
	_noise.frequency = 0.0009
	_noise.fractal_octaves = 3

	_root = Node3D.new()
	_root.name = "Mundo"
	root.add_child(_root)
	_build_ground()
	_props = _node("Props", _root)
	_build_village()
	_build_forest()
	_build_graveyard()
	_build_ruins()
	_build_meadows()
	_build_border()
	_build_zones()
	_build_portals()
	_build_labels()
	_paint_splats()
	# Los duenos se ponen ahora, antes de que corran los _ready: lo que las
	# piezas crean al cargar (llamas, piedras del portal) no se guarda.
	_set_owner(_root, _root)


# La navegacion se hornea en el primer cuadro: recien ahi la escena esta
# adentro del arbol.
func _process(_delta: float) -> bool:
	_bake_navigation()
	_save()
	return true


# --- Piso ------------------------------------------------------------------

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Suelo"
	_root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE, 40.0, SIZE)
	shape.shape = box
	shape.position.y = -20.0
	body.add_child(shape)

	var mesh := MeshInstance3D.new()
	mesh.name = "Piso"
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	plane.subdivide_width = 16
	plane.subdivide_depth = 16
	var material := ShaderMaterial.new()
	material.shader = load("res://world/terrain/terrain.gdshader")
	for layer in ["grass", "dirt", "cobble", "forest", "moss", "rocky"]:
		material.set_shader_parameter(layer + "_albedo", load("res://assets/terrain/%s_albedo.jpg" % layer))
		material.set_shader_parameter(layer + "_normal", load("res://assets/terrain/%s_normal.jpg" % layer))
	material.set_shader_parameter("world_size", SIZE)
	plane.material = material
	mesh.mesh = plane
	mesh.layers = 1 | PROP_SCRIPT.MAP_LAYER
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.set_script(load("res://world/terrain/ground.gd"))
	body.add_child(mesh)

	# Paredes invisibles en el borde.
	for side in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var wall := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(200.0 if side.x != 0 else SIZE, 1200.0, 200.0 if side.z != 0 else SIZE)
		wall.shape = wall_box
		wall.position = side * (WALK_LIMIT + 400.0) + Vector3.UP * 600.0
		body.add_child(wall)


# --- Zonas -----------------------------------------------------------------

func _build_village() -> void:
	var village := _node("Aldea", _props)
	# Fogata en la plaza, pozo, puesto del comerciante y un carro.
	_prop(village, P + "stone_fire_pit/stone_fire_pit_1k.gltf", Vector3(380, 0, 220), 0.0, 300.0, 0.45, {"is_fire": true, "fire_height": 80.0})
	_prop(village, V + "qt_well/qt_well.glb", Vector3(-250, 0, 520), 0.4, 300.0, 0.45, {"style": PROP_SCRIPT.Style.TINT, "tint": VILLAGE_TINT})
	_prop(village, V + "qt_market_stand/qt_market_stand.glb", Vector3(-980, 0, -330), PI * 0.55, 380.0, 0.4, {"style": PROP_SCRIPT.Style.TINT, "tint": VILLAGE_TINT})
	_prop(village, V + "qt_cart/qt_cart.glb", Vector3(-1150, 0, 250), 2.4, 380.0, 0.4, {"style": PROP_SCRIPT.Style.TINT, "tint": VILLAGE_TINT})
	var houses := [
		[V + "qt_house_02/qt_house_02.glb", Vector3(-1350, 0, -1150), 0.6, 300.0],
		[V + "qt_house_03/qt_house_03.glb", Vector3(1000, 0, -1250), -0.5, 300.0],
		[V + "qt_house_02/qt_house_02.glb", Vector3(1500, 0, 350), -1.4, 300.0],
		[V + "qt_house_03/qt_house_03.glb", Vector3(-1600, 0, 950), 2.1, 300.0],
		[V + "qt_house_01/qt_house_01.glb", Vector3(1150, 0, 1150), -2.4, 380.0],
	]
	for house in houses:
		_prop(village, house[0], house[1], house[2], house[3], 0.42, {"style": PROP_SCRIPT.Style.TINT, "tint": VILLAGE_TINT, "fade_when_occluding": true}, true)
	# Barriles y cajones al lado de las casas y del puesto.
	for center in [Vector3(-800, 0, -650), Vector3(-1000, 0, -1450), Vector3(1350, 0, -900), Vector3(1250, 0, 650), Vector3(-1300, 0, 600)]:
		for i in _rng.randi_range(2, 4):
			var pos: Vector3 = center + Vector3(_rng.randf_range(-170, 170), 0, _rng.randf_range(-170, 170))
			if _rng.randf() < 0.55:
				_prop(village, P + "wine_barrel_01/wine_barrel_01_1k.gltf", pos, _rng.randf() * TAU, 260.0, 0.5)
			else:
				_prop(village, P + "wooden_crate_01/wooden_crate_01_1k.gltf", pos, _rng.randf() * TAU, 280.0, 0.45)
	_prop(village, P + "wooden_bucket_01/wooden_bucket_01_1k.gltf", Vector3(-120, 0, 600), 0.0, 270.0, 0.0)
	# Faroles alrededor de la plaza.
	for angle in [0.4, 1.9, 3.4, 4.9]:
		var pos := Vector3(cos(angle) * 850.0, 0, -200 + sin(angle) * 850.0)
		_prop(village, G + "lightpost-single.glb", pos, angle, 420.0, 0.25, {"style": PROP_SCRIPT.Style.IRON})
	# Muralla con portón hacia las ruinas (norte).
	_fort_piece(village, "modular_fort_01_wall_thin_gate_01", Vector3(-130, 0, -1900), PI * 0.5, 100.0)
	_fort_piece(village, "modular_fort_01_wall_thin_straight_04", Vector3(-871, 0, -1900), PI * 0.5, 100.0)
	_fort_piece(village, "modular_fort_01_wall_thin_straight_03", Vector3(611, 0, -1900), PI * 0.5, 100.0)
	_fort_piece(village, "modular_fort_01_wall_thick_end_01", Vector3(-1350, 0, -1900), PI * 0.5, 100.0)
	_fort_piece(village, "modular_fort_01_wall_thick_end_02", Vector3(1350, 0, -1900), -PI * 0.5, 100.0)
	# Arbustos en el borde de la aldea.
	_scatter(village, VILLAGE, 1300.0, 1900.0, 18, _shrub)


func _build_forest() -> void:
	var forest := _node("Bosque", _props)
	_scatter(forest, FOREST, 0.0, FOREST.z, 230, _forest_tree)
	_scatter(forest, FOREST, 0.0, FOREST.z, 130, _fern)
	_scatter(forest, FOREST, 0.0, FOREST.z, 55, _shrub)
	_scatter(forest, FOREST, 0.0, FOREST.z, 35, _rock)
	_scatter(forest, FOREST, 0.0, FOREST.z, 22, _stump)


func _build_graveyard() -> void:
	var yard := _node("Cementerio", _props)
	var center := Vector3(GRAVEYARD.x, 0, GRAVEYARD.y)
	# Reja de hierro alrededor (cuadrado con huecos para entrar).
	var half: float = 1300.0
	var step: float = 300.0
	for side in 4:
		var t: float = -half
		while t < half:
			var gap: bool = absf(t + step / 2.0) < 400.0 and side != 1
			if not gap and _rng.randf() > 0.12:
				var local := Vector3(t + step / 2.0, 0, -half) if side % 2 == 0 else Vector3(-half, 0, t + step / 2.0)
				if side >= 2:
					local = -local
				var angle: float = 0.0 if side % 2 == 0 else PI * 0.5
				var piece: String = "iron-fence-damaged" if _rng.randf() < 0.25 else "iron-fence"
				_prop(yard, G + piece + ".glb", center + local, angle, 300.0, 1.0, {"style": PROP_SCRIPT.Style.IRON}, true)
			t += step
	# Tumbas en filas, algo desordenadas.
	for row in range(-4, 5):
		for col in range(-5, 6):
			if _rng.randf() < 0.3:
				continue
			var pos: Vector3 = center + Vector3(col * 210.0 + _rng.randf_range(-40, 40), 0, row * 260.0 + _rng.randf_range(-40, 40))
			if pos.distance_to(center) < 260.0:
				continue
			var stone: String = GRAVESTONES[_rng.randi() % GRAVESTONES.size()]
			_prop(yard, G + stone + ".glb", pos, _rng.randf_range(-0.25, 0.25), _rng.randf_range(280.0, 340.0), 0.35, {"style": PROP_SCRIPT.Style.STONE, "tint": Color(0.9, 0.9, 0.92)})
			if _rng.randf() < 0.35:
				_prop(yard, G + "grave.glb", pos + Vector3(0, 0, 170), 0.0, 280.0, 0.0, {"style": PROP_SCRIPT.Style.STONE, "tint": Color(0.7, 0.66, 0.6)})
	# Criptas, obeliscos, columnas, braseros y arboles secos.
	_prop(yard, G + "crypt-small.glb", center + Vector3(0, 0, -150), 0.0, 400.0, 0.5, {"style": PROP_SCRIPT.Style.STONE, "fade_when_occluding": true}, true)
	_prop(yard, G + "crypt.glb", center + Vector3(-900, 0, 700), 0.7, 420.0, 0.5, {"style": PROP_SCRIPT.Style.STONE, "fade_when_occluding": true}, true)
	_prop(yard, G + "crypt.glb", center + Vector3(850, 0, 800), -0.9, 420.0, 0.5, {"style": PROP_SCRIPT.Style.STONE, "fade_when_occluding": true}, true)
	for offset in [Vector3(-400, 0, 300), Vector3(420, 0, 300)]:
		_prop(yard, G + "pillar-obelisk.glb", center + offset, 0.0, 400.0, 0.4, {"style": PROP_SCRIPT.Style.STONE})
	for offset in [Vector3(-1150, 0, -1150), Vector3(1150, 0, -1150), Vector3(-1150, 0, 1150), Vector3(1150, 0, 1150)]:
		_prop(yard, G + "column-large.glb", center + offset, 0.0, 420.0, 0.45, {"style": PROP_SCRIPT.Style.STONE})
	for offset in [Vector3(-250, 0, -150), Vector3(250, 0, -150)]:
		_prop(yard, G + "fire-basket.glb", center + offset, 0.0, 420.0, 0.4, {"style": PROP_SCRIPT.Style.IRON, "is_fire": true, "fire_height": 40.0})
	for offset in [Vector3(-1350, 0, 0), Vector3(1350, 0, 400)]:
		_prop(yard, G + "lightpost-double.glb", center + offset, PI * 0.5, 420.0, 0.2, {"style": PROP_SCRIPT.Style.IRON})
	_scatter(_node("CementerioArboles", yard), Vector3(GRAVEYARD.x, GRAVEYARD.y, 1500.0), 1500.0, 2300.0, 22, _dead_tree)
	_scatter(yard, Vector3(GRAVEYARD.x, GRAVEYARD.y, 1300.0), 300.0, 1250.0, 10, _dead_tree)


func _build_ruins() -> void:
	var ruins := _node("Ruinas", _props)
	var c := Vector3(RUINS.x, 0, RUINS.y)
	# Torre redonda, muros gruesos rotos y una puerta en arco.
	_fort_piece(ruins, "modular_fort_01_tower_round", c + Vector3(700, 0, -650), 0.3, 80.0)
	_fort_piece(ruins, "modular_fort_01_wall_thick_straight_01", c + Vector3(-900, 0, -500), 0.0, 90.0)
	_fort_piece(ruins, "modular_fort_01_wall_thick_corner_01", c + Vector3(-1000, 0, -1150), 0.0, 90.0)
	_fort_piece(ruins, "modular_fort_01_wall_thick_end_02", c + Vector3(-300, 0, -1200), PI * 0.5, 90.0)
	_fort_piece(ruins, "modular_fort_01_wall_thin_gate_01", c + Vector3(-150, 0, 700), PI * 0.5, 95.0)
	_fort_piece(ruins, "modular_fort_01_wall_thin_straight_03", c + Vector3(-860, 0, 700), PI * 0.5, 95.0)
	_fort_piece(ruins, "modular_fort_01_wall_thick_end_01", c + Vector3(1000, 0, 400), -0.4, 90.0)
	_fort_piece(ruins, "modular_fort_01_wall_stairs_straight_01", c + Vector3(1300, 0, -100), PI, 90.0)
	_prop(ruins, P + "gothic_statue/gothic_statue_1k.gltf", c + Vector3(0, 230, -150), PI, 270.0, 0.35, {"style": PROP_SCRIPT.Style.STONE, "tint": Color(0.85, 0.84, 0.8)})
	_scatter(ruins, Vector3(RUINS.x, RUINS.y, RUINS.z), 200.0, RUINS.z, 30, _rock)
	_scatter(ruins, Vector3(RUINS.x, RUINS.y, RUINS.z), 600.0, RUINS.z + 400.0, 18, _dead_tree)
	_scatter(ruins, Vector3(RUINS.x, RUINS.y, RUINS.z), 300.0, RUINS.z, 20, _shrub)


func _build_meadows() -> void:
	var meadows := _node("Praderas", _props)
	var world := Vector3(0, 0, WALK_LIMIT)
	_scatter(meadows, world, 0.0, WALK_LIMIT, 150, _meadow_tree, true)
	_scatter(meadows, world, 0.0, WALK_LIMIT, 90, _rock, true)
	_scatter(meadows, world, 0.0, WALK_LIMIT, 110, _shrub, true)
	_scatter(meadows, world, 0.0, WALK_LIMIT, 60, _fern, true)


# Bosque cerrado en el borde: tapa el fin del mundo.
func _build_border() -> void:
	var border := _node("Borde", _props)
	var t: float = -HALF
	while t < HALF:
		for depth in [WALK_LIMIT + 250.0, WALK_LIMIT + 650.0]:
			for pos in [Vector3(t, 0, -depth), Vector3(t, 0, depth), Vector3(-depth, 0, t), Vector3(depth, 0, t)]:
				pos += Vector3(_rng.randf_range(-120, 120), 0, _rng.randf_range(-120, 120))
				var path: String = PINES[_rng.randi() % 2] if _rng.randf() < 0.6 else BROADLEAF[_rng.randi() % 2]
				_prop(border, path, pos, _rng.randf() * TAU, _rng.randf_range(140.0, 185.0), 0.0, {"style": PROP_SCRIPT.Style.TINT, "tint": FOLIAGE_TINT * 0.85})
		t += 480.0


# --- Generadores de cada tipo de pieza ------------------------------------

func _forest_tree(parent: Node3D, pos: Vector3) -> void:
	var roll: float = _rng.randf()
	if roll < 0.08:
		_prop(parent, TWISTED, pos, _rng.randf() * TAU, _rng.randf_range(34.0, 42.0), 0.0, {"style": PROP_SCRIPT.Style.TINT, "tint": FOLIAGE_TINT, "fade_when_occluding": true}, false, 55.0)
	elif roll < 0.55:
		_prop(parent, PINES[_rng.randi() % 2], pos, _rng.randf() * TAU, _rng.randf_range(78.0, 100.0), 0.0, {"style": PROP_SCRIPT.Style.TINT, "tint": FOLIAGE_TINT, "fade_when_occluding": true}, false, 40.0)
	else:
		_prop(parent, BROADLEAF[_rng.randi() % 2], pos, _rng.randf() * TAU, _rng.randf_range(75.0, 98.0), 0.0, {"style": PROP_SCRIPT.Style.TINT, "tint": FOLIAGE_TINT, "fade_when_occluding": true}, false, 40.0)


func _meadow_tree(parent: Node3D, pos: Vector3) -> void:
	_prop(parent, BROADLEAF[_rng.randi() % 2] if _rng.randf() < 0.7 else PINES[_rng.randi() % 2], pos, _rng.randf() * TAU,
			_rng.randf_range(78.0, 100.0), 0.0, {"style": PROP_SCRIPT.Style.TINT, "tint": FOLIAGE_TINT, "fade_when_occluding": true}, false, 40.0)


func _dead_tree(parent: Node3D, pos: Vector3) -> void:
	_prop(parent, DEAD_TREES[_rng.randi() % 2], pos, _rng.randf() * TAU, _rng.randf_range(44.0, 56.0), 0.0,
			{"style": PROP_SCRIPT.Style.TINT, "tint": Color(0.7, 0.66, 0.62), "fade_when_occluding": true}, false, 40.0)


func _rock(parent: Node3D, pos: Vector3) -> void:
	if _rng.randf() < 0.7:
		var piece: String = ROCK_PIECES[_rng.randi() % ROCK_PIECES.size()]
		_prop(parent, ROCK_SET, pos + Vector3.UP * 30.0, _rng.randf() * TAU, _rng.randf_range(90.0, 170.0), 0.38, {"keep_only": piece})
	else:
		_prop(parent, BOULDERS[_rng.randi() % 2], pos, _rng.randf() * TAU, _rng.randf_range(900.0, 1500.0), 0.4)


func _fern(parent: Node3D, pos: Vector3) -> void:
	_prop(parent, FERN, pos, _rng.randf() * TAU, _rng.randf_range(260.0, 360.0), 0.0, {"keep_only": FERN_PIECES[_rng.randi() % 4]})


func _shrub(parent: Node3D, pos: Vector3) -> void:
	_prop(parent, SHRUB, pos, _rng.randf() * TAU, _rng.randf_range(200.0, 280.0), 0.0, {"keep_only": SHRUB_PIECES[_rng.randi() % 4]})


func _stump(parent: Node3D, pos: Vector3) -> void:
	_prop(parent, STUMP, pos, _rng.randf() * TAU, _rng.randf_range(220.0, 280.0), 0.35)


# --- Enemigos, portales y nombres -----------------------------------------

func _build_zones() -> void:
	var zones := _node("ZonasEnemigos", _root)
	var skeleton := "res://enemies/types/esqueleto.tres"
	var zombie := "res://enemies/types/zombie.tres"
	var warrior := "res://enemies/types/esqueleto_guerrero.tres"
	_zone(zones, "Bosque1", Vector3(-5300, 0, -2100), Vector3(1500, 1, 1500), 2, [skeleton, zombie], [5.0, 3.0], 7)
	_zone(zones, "Bosque2", Vector3(-7300, 0, -3700), Vector3(1600, 1, 1600), 3, [skeleton, zombie, warrior], [5.0, 3.0, 1.0], 8)
	_zone(zones, "Pradera", Vector3(3200, 0, 3600), Vector3(2200, 1, 1800), 1, [skeleton], [1.0], 5)
	_zone(zones, "Cementerio", Vector3(GRAVEYARD.x, 0, GRAVEYARD.y), Vector3(2200, 1, 2200), 4, [zombie, skeleton, warrior], [4.0, 3.0, 1.5], 10)
	_zone(zones, "Ruinas", Vector3(RUINS.x, 0, RUINS.y), Vector3(2200, 1, 2000), 6, [warrior, skeleton, zombie], [4.0, 2.0, 1.0], 10)


func _zone(parent: Node3D, zone_name: String, pos: Vector3, size: Vector3, level: int, types: Array, weights: Array, max_enemies: int) -> void:
	var zone: Node3D = load(ZONE_SCENE).instantiate()
	zone.name = zone_name
	zone.transform = Transform3D(Basis.IDENTITY, pos)
	zone.enemy_scene = load(ENEMY_SCENE)
	zone.level = level
	zone.max_enemies = max_enemies
	zone.zone_size = size
	var typed_types: Array[EnemyData] = []
	for path in types:
		typed_types.append(load(path))
	zone.enemy_types = typed_types
	var typed_weights: Array[float] = []
	typed_weights.assign(weights)
	zone.type_weights = typed_weights
	parent.add_child(zone)


func _build_portals() -> void:
	var portals := _node("Portales", _root)
	_portal(portals, "aldea", "Aldea del Vado", Vector3(650, 0, 750))
	_portal(portals, "bosque", "Bosque Umbrío", Vector3(-4400, 0, -1550))
	_portal(portals, "cementerio", "Camposanto Hundido", Vector3(3900, 0, -3100))
	_portal(portals, "ruinas", "Ruinas de Kael", Vector3(-700, 0, -6300))


func _portal(parent: Node3D, id: String, display_name: String, pos: Vector3) -> void:
	var portal: Node3D = load(PORTAL_SCENE).instantiate()
	portal.name = "Portal_" + id
	portal.portal_id = id
	portal.display_name = display_name
	portal.transform = Transform3D(Basis.IDENTITY, pos)
	parent.add_child(portal)
	_occupied.append(Vector3(pos.x, pos.z, 420.0))


func _build_labels() -> void:
	var labels := _node("NombresDelMapa", _root)
	for entry in [["Aldea del Vado", Vector2(VILLAGE.x, VILLAGE.y)], ["Bosque Umbrío", Vector2(FOREST.x, FOREST.y)],
			["Camposanto Hundido", Vector2(GRAVEYARD.x, GRAVEYARD.y)], ["Ruinas de Kael", Vector2(RUINS.x, RUINS.y)],
			["Prados del Sur", Vector2(1500, 4500)]]:
		var marker := Marker3D.new()
		marker.name = entry[0].replace(" ", "")
		marker.position = Vector3(entry[1].x, 0, entry[1].y)
		marker.set_meta("map_label", entry[0])
		marker.add_to_group("map_labels", true)
		labels.add_child(marker)


# --- Colocacion ------------------------------------------------------------

func _node(node_name: String, parent: Node) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	parent.add_child(node)
	return node


## Reparte count piezas al azar dentro del anillo [inner, outer] de la zona
## (x, z = centro). Evita caminos, la aldea y lo ya ocupado. square = en vez de
## circulo, todo el cuadrado del mundo.
func _scatter(parent: Node3D, zone: Vector3, inner: float, outer: float, count: int, maker: Callable, square: bool = false) -> void:
	var placed: int = 0
	var tries: int = 0
	var center := Vector2(zone.x, zone.y)
	while placed < count and tries < count * 30:
		tries += 1
		var point: Vector2
		if square:
			point = Vector2(_rng.randf_range(-outer, outer), _rng.randf_range(-outer, outer))
			if _in_any_zone(point):
				continue
		else:
			var angle: float = _rng.randf() * TAU
			var dist: float = sqrt(_rng.randf_range(inner * inner, outer * outer))
			point = center + Vector2(cos(angle), sin(angle)) * dist
			# Bordes de la zona irregulares.
			if dist > outer * (0.75 + 0.25 * _noise.get_noise_2dv(point * 3.0)):
				continue
		if absf(point.x) > WALK_LIMIT - 100.0 or absf(point.y) > WALK_LIMIT - 100.0:
			continue
		if _distance_to_paths(point) < PATH_WIDTH + 140.0:
			continue
		if zone != VILLAGE and point.distance_to(Vector2(VILLAGE.x, VILLAGE.y)) < 900.0:
			continue
		if not _is_free(point, 160.0):
			continue
		maker.call(parent, Vector3(point.x, 0, point.y))
		placed += 1


func _in_any_zone(point: Vector2) -> bool:
	for zone in [VILLAGE, FOREST, GRAVEYARD, RUINS]:
		if point.distance_to(Vector2(zone.x, zone.y)) < zone.z + 300.0:
			return true
	return false


func _is_free(point: Vector2, radius: float) -> bool:
	for other in _occupied:
		if point.distance_to(Vector2(other.x, other.y)) < radius + other.z:
			return false
	return true


## Crea una pieza: un nodo con prop.gd, el modelo como hijo y, si collider > 0,
## una colision cilindrica de radio collider * ancho (o una caja si box = true).
## trunk_radius > 0 = colision fija de ese radio (troncos de arboles).
func _prop(parent: Node3D, path: String, pos: Vector3, angle: float, scale: float, collider: float,
		options: Dictionary = {}, box: bool = false, trunk_radius: float = 0.0) -> Node3D:
	var prop := Node3D.new()
	prop.set_script(PROP_SCRIPT)
	prop.name = path.get_file().get_basename().replace(".", "_")
	for key in options:
		prop.set(key, options[key])
	prop.transform = Transform3D(Basis(Vector3.UP, angle).scaled(Vector3.ONE * scale), pos)
	parent.add_child(prop, true)
	var model: Node3D = _scene(path).instantiate()
	prop.add_child(model)

	var bounds: AABB = _model_bounds(model, options.get("keep_only", ""))
	var footprint: float = maxf(bounds.size.x, bounds.size.z) * scale
	_occupied.append(Vector3(pos.x, pos.z, maxf(footprint * 0.45, 60.0)))

	if collider <= 0.0 and trunk_radius <= 0.0:
		return prop
	var body := StaticBody3D.new()
	body.name = "Colision"
	prop.add_child(body)
	var shape := CollisionShape3D.new()
	if box:
		var box_shape := BoxShape3D.new()
		box_shape.size = bounds.size * 0.92
		shape.shape = box_shape
		shape.position = bounds.get_center()
	else:
		var cylinder := CylinderShape3D.new()
		var radius: float = trunk_radius / scale if trunk_radius > 0.0 else maxf(bounds.size.x, bounds.size.z) * collider
		cylinder.radius = radius
		cylinder.height = maxf(bounds.size.y, 300.0 / scale)
		shape.shape = cylinder
		shape.position = Vector3(bounds.get_center().x if trunk_radius <= 0.0 else 0.0, cylinder.height / 2.0 + bounds.position.y, bounds.get_center().z if trunk_radius <= 0.0 else 0.0)
	body.add_child(shape)
	return prop


## Pieza del fuerte modular (todas vienen en el mismo archivo, en el origen).
## Los portones llevan colision solo en los costados, para pasar por el arco.
func _fort_piece(parent: Node3D, piece: String, pos: Vector3, angle: float, scale: float) -> void:
	var is_gate: bool = piece.contains("gate")
	var prop: Node3D = _prop(parent, FORT, pos, angle, scale, 0.0 if is_gate else 1.0, {"keep_only": piece, "fade_when_occluding": true}, true)
	if not is_gate:
		return
	var bounds: AABB = _model_bounds(prop.get_child(0), piece)
	var body := StaticBody3D.new()
	body.name = "Colision"
	prop.add_child(body)
	for side in [0.0, 0.7]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(bounds.size.x, bounds.size.y, bounds.size.z * 0.3)
		shape.shape = box
		shape.position = Vector3(bounds.get_center().x, bounds.size.y / 2.0, bounds.position.z + bounds.size.z * (side + 0.15))
		body.add_child(shape)


func _scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]


# Caja del modelo en sus coordenadas (solo la malla keep_only si se indica).
func _model_bounds(model: Node3D, keep_only: String) -> AABB:
	var bounds := AABB()
	var first: bool = true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if not keep_only.is_empty() and mesh.name != keep_only:
			continue
		var local: Transform3D = model.transform * _relative_transform(mesh, model)
		var box: AABB = local * (mesh as MeshInstance3D).get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var current: Node = node
	while current != ancestor and current is Node3D:
		xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf


# --- Mapas de mezcla del piso ----------------------------------------------

func _paint_splats() -> void:
	var a := Image.create(SPLAT_RES, SPLAT_RES, false, Image.FORMAT_RGBA8)
	var b := Image.create(SPLAT_RES, SPLAT_RES, false, Image.FORMAT_RGBA8)
	var detail := FastNoiseLite.new()
	detail.seed = SEED + 1
	detail.frequency = 0.004
	var tone := FastNoiseLite.new()
	tone.seed = SEED + 2
	tone.frequency = 0.00035
	tone.fractal_octaves = 4
	var px: float = SIZE / SPLAT_RES
	for y in SPLAT_RES:
		for x in SPLAT_RES:
			var p := Vector2((x + 0.5) * px - HALF, (y + 0.5) * px - HALF)
			var wobble: float = detail.get_noise_2dv(p)
			var path_dist: float = _distance_to_paths(p) + wobble * 70.0
			var dirt: float = 1.0 - smoothstep(PATH_WIDTH * 0.45, PATH_WIDTH, path_dist)
			var plaza: float = _area(p, Vector2(0, -200), 820.0, wobble) + _area(p, Vector2(RUINS.x, RUINS.y), 650.0, wobble)
			var forest: float = _area(p, Vector2(FOREST.x, FOREST.y), FOREST.z * 1.05, wobble * 3.0)
			var moss: float = _area(p, Vector2(GRAVEYARD.x, GRAVEYARD.y), GRAVEYARD.z, wobble * 2.0)
			var rocky: float = _area(p, Vector2(RUINS.x, RUINS.y), RUINS.z * 1.1, wobble * 2.0)
			# Manchas de piedra sueltas por el mundo.
			rocky = maxf(rocky, smoothstep(0.62, 0.72, detail.get_noise_2dv(p * 0.35 + Vector2(900, 400)) * 0.5 + 0.5))
			var plaza_weight: float = clampf(plaza, 0.0, 1.0)
			# El camino se pierde al entrar a la plaza.
			dirt *= 1.0 - plaza_weight * 0.8
			a.set_pixel(x, y, Color(dirt, plaza_weight, forest, moss))
			b.set_pixel(x, y, Color(rocky * (1.0 - plaza_weight), tone.get_noise_2dv(p) * 0.5 + 0.5, 0.0, 1.0))
	# El piso los carga al abrir (world/terrain/ground.gd).
	a.save_png(ProjectSettings.globalize_path(SPLAT_A))
	b.save_png(ProjectSettings.globalize_path(SPLAT_B))


func _area(p: Vector2, center: Vector2, radius: float, wobble: float) -> float:
	var d: float = p.distance_to(center) + wobble * radius * 0.12
	return 1.0 - smoothstep(radius * 0.8, radius, d)


func _distance_to_paths(p: Vector2) -> float:
	var best: float = INF
	for path in _paths:
		for i in path.size() - 1:
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1])
			best = minf(best, p.distance_to(closest))
	return best


# --- Navegacion -------------------------------------------------------------

func _bake_navigation() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.cell_size = 20.0
	nav_mesh.cell_height = 5.0
	nav_mesh.agent_height = 300.0
	nav_mesh.agent_radius = 60.0
	nav_mesh.agent_max_climb = 25.0
	nav_mesh.agent_max_slope = 40.0
	nav_mesh.region_min_size = 4.0
	nav_mesh.region_merge_size = 40.0
	nav_mesh.edge_max_length = 0.0
	nav_mesh.edge_max_error = 1.5
	nav_mesh.detail_sample_distance = 6.0
	nav_mesh.detail_sample_max_error = 1.0
	nav_mesh.filter_baking_aabb = AABB(Vector3(-WALK_LIMIT, -100.0, -WALK_LIMIT), Vector3(WALK_LIMIT * 2.0, 600.0, WALK_LIMIT * 2.0))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source, _root)
	var start: int = Time.get_ticks_msec()
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)
	print("navegacion: %d poligonos en %d ms" % [nav_mesh.get_polygon_count(), Time.get_ticks_msec() - start])
	ResourceSaver.save(nav_mesh, OUT_NAV)
	var region := NavigationRegion3D.new()
	region.name = "Navegacion"
	region.navigation_mesh = load(OUT_NAV)
	_root.add_child(region)
	_root.move_child(region, 1)
	region.owner = _root


# --- Guardar ---------------------------------------------------------------

func _save() -> void:
	var packed := PackedScene.new()
	var error: Error = packed.pack(_root)
	if error != OK:
		push_error("No se pudo empaquetar el mundo: %s" % error_string(error))
		return
	error = ResourceSaver.save(packed, OUT_SCENE)
	print("mundo guardado: %s (%d piezas)" % [error_string(error), _props.find_children("*", "Node3D", true, false).filter(func(n): return n.get_script() == PROP_SCRIPT).size()])


func _set_owner(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		# Lo de adentro de los modelos importados no se guarda: viene del archivo.
		if child.scene_file_path.is_empty():
			_set_owner(child, owner_node)
