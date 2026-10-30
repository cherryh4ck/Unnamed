extends Node

## Autoload que arma los iconos del inventario sacandole una foto al modelo 3D
## de cada item, en un SubViewport aparte. Asi el icono coincide siempre con
## el modelo que se ve en el piso y en la mano, y ocupa la forma del item en la
## grilla. Se renderiza una vez por modelo y tamaño; mientras tanto (o si el
## item no tiene modelo, o sin GPU como en los tests) se usa su textura 2D.

signal icon_ready(key: String)

## Pixeles por casilla del render (despues se muestra mas chico, con mipmaps).
const PIXELS_PER_CELL: int = 96
## Margen alrededor del modelo, en proporcion del lado mas largo.
const MARGIN: float = 0.08
## Leve giro para que se vea el volumen y no una silueta plana.
const TILT_LONG_DEG: float = 24.0
const TILT_SIDE_DEG: float = -12.0

var _cache: Dictionary = {}
var _queue: Array[Itemdata] = []
var _pending: Dictionary = {}
var _busy: bool = false
var _viewport: SubViewport
var _camera: Camera3D
var _stage: Node3D


func _ready() -> void:
	# El inventario pausa el juego y los iconos se piden con el abierto.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _can_render():
		return
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.58, 0.52)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)

	# Luz principal calida de arriba a la izquierda y un contraluz frio.
	_viewport.add_child(_light(Vector3(-50.0, -35.0, 0.0), Color(1.0, 0.93, 0.82), 1.7))
	_viewport.add_child(_light(Vector3(25.0, 150.0, 0.0), Color(0.6, 0.7, 1.0), 0.7))

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.position = Vector3(0.0, 0.0, 2000.0)
	_camera.near = 1.0
	_camera.far = 4000.0
	_viewport.add_child(_camera)

	_stage = Node3D.new()
	_viewport.add_child(_stage)


## Icono para mostrar. Si el render todavia no esta, devuelve la textura 2D y
## avisa con icon_ready(key_for(item)) cuando lo tenga.
func get_icon(item: Itemdata) -> Texture2D:
	if item == null:
		return null
	if item.model_3d == null or _viewport == null:
		return item.texture
	var key: String = key_for(item)
	if _cache.has(key):
		return _cache[key]
	if not _pending.has(key):
		_pending[key] = true
		_queue.append(item)
		_render_queue()
	return item.texture


func key_for(item: Itemdata) -> String:
	var model_path: String = item.model_3d.resource_path if item.model_3d else ""
	return "%s|%s" % [model_path, item.get_footprint()]


func _can_render() -> bool:
	return DisplayServer.get_name() != "headless"


func _light(rotation_deg: Vector3, color: Color, energy: float) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = rotation_deg
	light.light_color = color
	light.light_energy = energy
	return light


func _render_queue() -> void:
	if _busy:
		return
	_busy = true
	while not _queue.is_empty():
		var item: Itemdata = _queue.pop_front()
		var key: String = key_for(item)
		var texture: Texture2D = await _render(item)
		_pending.erase(key)
		if texture:
			_cache[key] = texture
			icon_ready.emit(key)
	_busy = false


func _render(item: Itemdata) -> Texture2D:
	var cells: Vector2i = item.get_footprint()
	_viewport.size = cells * PIXELS_PER_CELL
	var model: Node3D = item.model_3d.instantiate()
	_stage.add_child(model)
	_frame(model, Vector2(cells))

	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_stage.remove_child(model)
	model.queue_free()
	if image == null or image.is_empty():
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# Gira el modelo para que su lado mas largo siga el lado mas largo de la
# forma del item en la grilla, lo centra y ajusta la camara para que entre.
func _frame(model: Node3D, cells: Vector2) -> void:
	model.transform = Transform3D.IDENTITY
	var bounds: AABB = _bounds_of(model)
	var size: Vector3 = bounds.size
	var axes: Array[int] = [0, 1, 2]
	axes.sort_custom(func(a: int, b: int) -> bool: return size[a] > size[b])

	# Columna i de la base = hacia donde va el eje i del modelo en pantalla.
	var tall: bool = cells.y >= cells.x
	var long_dir: Vector3 = Vector3.UP if tall else Vector3.RIGHT
	var side_dir: Vector3 = Vector3.RIGHT if tall else Vector3.UP
	var columns: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	columns[axes[0]] = long_dir
	columns[axes[1]] = side_dir
	columns[axes[2]] = Vector3.BACK
	var basis := Basis(columns[0], columns[1], columns[2])
	if basis.determinant() < 0.0:
		columns[axes[2]] = Vector3.FORWARD
		basis = Basis(columns[0], columns[1], columns[2])
	basis = Basis(long_dir, deg_to_rad(TILT_LONG_DEG)) * Basis(side_dir, deg_to_rad(TILT_SIDE_DEG)) * basis

	var placed := Transform3D(basis, Vector3.ZERO)
	var view_bounds: AABB = placed * bounds
	placed.origin = -view_bounds.get_center()
	model.transform = placed

	var aspect: float = cells.x / cells.y
	var needed_height: float = maxf(view_bounds.size.y, view_bounds.size.x / aspect)
	_camera.size = needed_height * (1.0 + MARGIN * 2.0)


func _bounds_of(model: Node3D) -> AABB:
	var bounds := AABB()
	var first: bool = true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var local: Transform3D = model.global_transform.affine_inverse() * (mesh as Node3D).global_transform
		var mesh_bounds: AABB = local * (mesh as MeshInstance3D).get_aabb()
		bounds = mesh_bounds if first else bounds.merge(mesh_bounds)
		first = false
	return bounds
