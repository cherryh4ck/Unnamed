extends Node

## Autoload con lo que el jugador conoce del mundo: que partes ya recorrio
## (la niebla del mapa), que portales descubrio y la "foto" del mundo desde
## arriba que usan el mapa grande y el minimapa. Se guarda con la partida.
##
## La niebla es una imagen LA8: el alfa es lo que falta explorar (255 =
## nunca visto). Se dibuja tal cual encima de la foto, sin pasos extra.

signal portal_discovered(id: String, display_name: String)

## El mundo es un cuadrado de WORLD_SIZE centrado en el origen (ver world/build_world.gd).
const WORLD_SIZE: float = 20000.0
const FOG_RES: int = 256
const REVEAL_RADIUS: float = 1500.0
const UPDATE_INTERVAL: float = 0.2
const MAP_RES: int = 2048
const MAP_LAYER: int = 1 << 15

var discovered_portals: Array[String] = []
var _portal_names: Dictionary = {}
var _fog: Image
var _fog_texture: ImageTexture
var _fog_dirty: bool = true
var _timer: float = 0.0
var _map_texture: Texture2D
var _capturing: bool = false


func _ready() -> void:
	reset()


## Partida nueva: todo sin explorar y sin portales.
func reset() -> void:
	# Blanco: el color de lo no explorado lo pone quien dibuja (tono pergamino).
	_fog = Image.create(FOG_RES, FOG_RES, false, Image.FORMAT_LA8)
	_fog.fill(Color(1, 1, 1, 1))
	_fog_dirty = true
	discovered_portals.clear()


# Los tests guardan la partida antes de que corra _ready.
func _ensure_fog() -> void:
	if _fog == null:
		reset()


func world_rect() -> Rect2:
	return Rect2(-WORLD_SIZE / 2.0, -WORLD_SIZE / 2.0, WORLD_SIZE, WORLD_SIZE)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = UPDATE_INTERVAL
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		reveal(Vector2(player.global_position.x, player.global_position.z), REVEAL_RADIUS)


# --- Niebla -----------------------------------------------------------------

func _to_fog(world_xz: Vector2) -> Vector2:
	return (world_xz + Vector2.ONE * WORLD_SIZE / 2.0) / WORLD_SIZE * FOG_RES


## Destapa un circulo del mapa con el borde difuso.
func reveal(world_xz: Vector2, radius: float) -> void:
	_ensure_fog()
	var center: Vector2 = _to_fog(world_xz)
	var r: float = radius / WORLD_SIZE * FOG_RES
	var changed: bool = false
	for y in range(maxi(0, floori(center.y - r)), mini(FOG_RES, ceili(center.y + r) + 1)):
		for x in range(maxi(0, floori(center.x - r)), mini(FOG_RES, ceili(center.x + r) + 1)):
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(center) / r
			if d >= 1.0:
				continue
			var hidden: float = smoothstep(0.6, 1.0, d)
			var current: Color = _fog.get_pixel(x, y)
			if hidden < current.a - 0.01:
				current.a = hidden
				_fog.set_pixel(x, y, current)
				changed = true
	if changed:
		_fog_dirty = true


func is_explored(world_xz: Vector2) -> bool:
	_ensure_fog()
	var p: Vector2 = _to_fog(world_xz)
	if p.x < 0 or p.y < 0 or p.x >= FOG_RES or p.y >= FOG_RES:
		return false
	return _fog.get_pixel(int(p.x), int(p.y)).a < 0.5


## Textura de la niebla (se actualiza sola cuando cambio).
func get_fog_texture() -> ImageTexture:
	_ensure_fog()
	if _fog_texture == null:
		_fog_texture = ImageTexture.create_from_image(_fog)
		_fog_dirty = false
	elif _fog_dirty:
		_fog_texture.update(_fog)
		_fog_dirty = false
	return _fog_texture


# --- Portales ---------------------------------------------------------------

func is_portal_discovered(id: String) -> bool:
	return id in discovered_portals


func discover_portal(id: String, display_name: String) -> void:
	_portal_names[id] = display_name
	if id.is_empty() or id in discovered_portals:
		return
	discovered_portals.append(id)
	portal_discovered.emit(id, display_name)


## Portal descubierto mas cercano a un punto (para reaparecer al morir), o null.
func nearest_portal(world_pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_dist: float = INF
	for portal in get_tree().get_nodes_in_group("portals"):
		if not is_portal_discovered(portal.portal_id):
			continue
		var dist: float = portal.global_position.distance_to(world_pos)
		if dist < best_dist:
			best = portal
			best_dist = dist
	return best


# --- Foto del mundo ---------------------------------------------------------

## Foto del mundo desde arriba (solo lo que esta en MAP_LAYER: piso y piezas),
## sin luces. null hasta que se saca (la primera vez que se pide).
func get_map_texture() -> Texture2D:
	if _map_texture == null and not _capturing:
		_capture()
	return _map_texture


func _capture() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or not _can_render():
		return
	_capturing = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(MAP_RES, MAP_RES)
	viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_4X
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = WORLD_SIZE
	camera.cull_mask = MAP_LAYER
	camera.near = 10.0
	camera.far = 20000.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.07, 0.05)
	camera.environment = environment
	# Mirando hacia abajo con el norte (-Z) arriba de la imagen.
	camera.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0.0, 8000.0, 0.0))
	viewport.add_child(camera)
	scene.add_child(viewport)
	# Se pide desde el dibujo del minimapa: la posicion de la camara llega al
	# servidor de render recien en el cuadro siguiente. Antes de eso sacaria
	# la foto desde el origen.
	await get_tree().process_frame
	await get_tree().process_frame
	# Si en el medio se recargo la escena (partida nueva), el viewport ya no
	# esta: se saca la foto la proxima vez que se pida.
	if not is_instance_valid(viewport):
		_capturing = false
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if not is_instance_valid(viewport):
		_capturing = false
		return
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	_capturing = false
	if image == null or image.is_empty():
		return
	image.generate_mipmaps()
	_map_texture = ImageTexture.create_from_image(image)


## Al cambiar de escena (partida nueva o cargada) la foto se vuelve a sacar.
func forget_map() -> void:
	_map_texture = null


func _can_render() -> bool:
	return DisplayServer.get_name() != "headless"


# --- Guardar ----------------------------------------------------------------

func to_save() -> Dictionary:
	_ensure_fog()
	return {
		"fog": Marshalls.raw_to_base64(_fog.save_png_to_buffer()),
		"portals": discovered_portals.duplicate(),
	}


func from_save(data: Dictionary) -> void:
	reset()
	discovered_portals.assign(data.get("portals", []))
	var encoded: String = data.get("fog", "")
	if encoded.is_empty():
		return
	var image := Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(encoded)) == OK and image.get_width() == FOG_RES:
		image.convert(Image.FORMAT_LA8)
		_fog = image
		_fog_dirty = true
