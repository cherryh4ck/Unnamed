extends Node3D

## Pasto que se mueve con el viento y se aparta cuando pasa el jugador. Se
## arma en parcelas alrededor del jugador con MultiMesh (matas de hojas
## chicas, del color del pasto del piso) y las que quedan lejos se borran.
## Donde va y cuanto lo dice world/terrain/grass_mask.png, que pinta
## world/build_world.gd: nada en caminos, plazas ni piedra, poco en el bosque,
## y nada debajo de casas, rocas o arboles. El movimiento lo hace el shader
## (world/terrain/grass.gdshader); aca solo se le pasa donde esta el jugador
## y cuanto viento hay segun el clima.

const MASK := "res://world/terrain/grass_mask.png"
const SPLAT_B := "res://world/terrain/splat_b.png"
const GRASS_TEXTURE := "res://assets/terrain/grass_albedo.jpg"
const SHADER := preload("res://world/terrain/grass.gdshader")
## Mismo tamaño de mundo que world/build_world.gd.
const WORLD_SIZE: float = 20000.0
## Lado de cada parcela.
const CHUNK: float = 1000.0
## Hasta donde hay pasto alrededor del punto que mira la camara, y desde
## donde las parcelas muestran la mitad de las matas.
const VIEW_RADIUS: float = 3300.0
const NEAR_RADIUS: float = 2100.0
## La camara mira hacia el norte (-z): el centro de lo que se ve queda
## adelante del jugador.
const VIEW_OFFSET := Vector3(0.0, 0.0, -500.0)
## Distancia media entre matas antes de aplicar la densidad del mapa.
const SPACING: float = 33.0
const BLADES: int = 9
const MAX_BUILDS_PER_FRAME: int = 2
const UPDATE_INTERVAL: float = 0.25

var _mask: Image
var _material: ShaderMaterial
var _mesh: ArrayMesh
## Parcelas armadas: Vector2i -> MultiMeshInstance3D.
var _chunks: Dictionary = {}
var _pending: Array[Vector2i] = []
var _timer: float = 0.0


func _ready() -> void:
	if not ResourceLoader.exists(MASK):
		set_process(false)
		return
	_mask = (load(MASK) as Texture2D).get_image()
	if _mask.is_compressed():
		_mask.decompress()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("grass_albedo", load(GRASS_TEXTURE))
	if ResourceLoader.exists(SPLAT_B):
		_material.set_shader_parameter("splat_b", load(SPLAT_B))
	_material.set_shader_parameter("world_size", WORLD_SIZE)
	_mesh = _make_clump()


func _process(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_material.set_shader_parameter("player_position", player.global_position)
	# Con nubes, lluvia o tormenta sopla mas fuerte.
	_material.set_shader_parameter("wind_strength", 0.7 + weather.overcast * 0.4 + weather.rain * 0.9)
	_timer -= delta
	if _timer <= 0.0:
		_timer = UPDATE_INTERVAL
		_refresh(player.global_position + VIEW_OFFSET)
	for i in mini(MAX_BUILDS_PER_FRAME, _pending.size()):
		var key: Vector2i = _pending.pop_front()
		if not _chunks.has(key):
			_chunks[key] = _build_chunk(key)


## Cuantas matas hay armadas en total (para las pruebas y el rendimiento).
func get_instance_count() -> int:
	var total: int = 0
	for chunk in _chunks.values():
		total += chunk.multimesh.visible_instance_count if chunk.multimesh.visible_instance_count >= 0 else chunk.multimesh.instance_count
	return total


# Arma las parcelas que faltan (las mas cercanas primero), borra las lejanas y
# a las de mas lejos les deja la mitad de las matas.
func _refresh(focus: Vector3) -> void:
	var center := Vector2i(floori(focus.x / CHUNK), floori(focus.z / CHUNK))
	var reach: int = ceili(VIEW_RADIUS / CHUNK) + 1
	var wanted: Array = []
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var key := center + Vector2i(dx, dz)
			var distance: float = _chunk_distance(key, focus)
			if distance < VIEW_RADIUS:
				wanted.append([distance, key])
	wanted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_pending.clear()
	for entry in wanted:
		if not _chunks.has(entry[1]):
			_pending.append(entry[1])
	for key in _chunks.keys():
		var distance: float = _chunk_distance(key, focus)
		var chunk: MultiMeshInstance3D = _chunks[key]
		if distance > VIEW_RADIUS + CHUNK * 0.5:
			chunk.queue_free()
			_chunks.erase(key)
			continue
		# Las matas estan en orden al azar: la primera mitad es una muestra pareja.
		var count: int = chunk.multimesh.instance_count
		chunk.multimesh.visible_instance_count = count if distance < NEAR_RADIUS else count / 2


# Distancia del punto al rectangulo de la parcela (0 si esta adentro).
func _chunk_distance(key: Vector2i, point: Vector3) -> float:
	var x: float = clampf(point.x, key.x * CHUNK, (key.x + 1) * CHUNK)
	var z: float = clampf(point.z, key.y * CHUNK, (key.y + 1) * CHUNK)
	return Vector2(point.x - x, point.z - z).length()


func _build_chunk(key: Vector2i) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var origin := Vector2(key.x * CHUNK, key.y * CHUNK)
	var transforms: Array[Transform3D] = []
	var customs: Array[Color] = []
	var tries: int = roundi((CHUNK / SPACING) * (CHUNK / SPACING))
	for i in tries:
		var local := Vector2(rng.randf() * CHUNK, rng.randf() * CHUNK)
		var roll: float = rng.randf()
		var angle: float = rng.randf() * TAU
		var height: float = rng.randf_range(0.75, 1.15)
		var width: float = rng.randf_range(0.85, 1.15)
		var shade: float = rng.randf()
		var info: Color = sample_mask(origin + local)
		if roll >= info.r:
			continue
		var basis := Basis(Vector3.UP, angle).scaled(Vector3(width, height, width))
		transforms.append(Transform3D(basis, Vector3(local.x, 0.0, local.y)))
		customs.append(Color(info.g, shade, 0.0, 0.0))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_custom_data(i, customs[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "Pasto_%d_%d" % [key.x, key.y]
	instance.multimesh = multimesh
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	instance.global_position = Vector3(origin.x, 0.0, origin.y)
	return instance


## Densidad (r, de 0 a 1) y sequedad (g) del pasto en el punto (x, z) del mundo.
func sample_mask(point: Vector2) -> Color:
	var u: float = clampf(point.x / WORLD_SIZE + 0.5, 0.0, 0.9999)
	var v: float = clampf(point.y / WORLD_SIZE + 0.5, 0.0, 0.9999)
	return _mask.get_pixel(int(u * _mask.get_width()), int(v * _mask.get_height()))


# Una mata: hojas finas en tres tramos (se doblan mas en la punta), apenas
# abiertas hacia afuera. UV.y va de 0 (base) a 1 (punta) para el shader.
func _make_clump() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in BLADES:
		var spot: float = rng.randf() * TAU
		var base := Vector3(cos(spot), 0.0, sin(spot)) * rng.randf_range(0.0, 22.0)
		var facing: float = rng.randf() * TAU
		var side := Vector3(cos(facing), 0.0, sin(facing)) * rng.randf_range(2.8, 4.2)
		var lean := Vector3(cos(spot), 0.0, sin(spot)) * rng.randf_range(4.0, 13.0)
		var height: float = rng.randf_range(28.0, 52.0)
		var mid: Vector3 = base + lean * 0.35 + Vector3.UP * height * 0.55
		var top: Vector3 = base + lean + Vector3.UP * height
		var quad := [
			[base - side, 0.0], [base + side, 0.0], [mid - side * 0.65, 0.55],
			[mid - side * 0.65, 0.55], [base + side, 0.0], [mid + side * 0.65, 0.55],
			[mid - side * 0.65, 0.55], [mid + side * 0.65, 0.55], [top, 1.0],
		]
		for vertex in quad:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(0.5, vertex[1]))
			surface.add_vertex(vertex[0])
	return surface.commit()
