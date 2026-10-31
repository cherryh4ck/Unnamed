class_name GroundSurface

## Que hay en el piso en un punto del mundo (pasto, tierra o piedra) y el
## sonido de pasos que le toca. Lo lee del canal azul del mapa del pasto que
## pinta world/build_world.gd (0 pasto, 0.5 tierra, 1 piedra; se importa sin
## comprimir, asi se puede leer tambien en el juego exportado). Los pasos son
## de Kenney (Impact Sounds, CC0).

enum Kind { GRASS, DIRT, STONE }

const MASK := "res://world/terrain/grass_mask.png"
## Mismo tamaño de mundo que world/build_world.gd.
const WORLD_SIZE: float = 20000.0
const STEPS := {
	Kind.GRASS: "res://sounds/ambient/footsteps/pasto_%d.ogg",
	Kind.DIRT: "res://sounds/ambient/footsteps/tierra_%d.ogg",
	Kind.STONE: "res://sounds/ambient/footsteps/piedra_%d.ogg",
}
const STEP_COUNT: int = 5
## Volumen de cada piso (los de piedra suenan mas fuerte que el pasto).
const VOLUMES := {Kind.GRASS: -4.0, Kind.DIRT: -6.0, Kind.STONE: -10.0}

static var _mask: Image
static var _steps: Dictionary = {}
static var _last: int = -1


## Tipo de piso en la posicion (x, z) del mundo.
static func at(position: Vector3) -> Kind:
	if _mask == null:
		_mask = _load(MASK)
	if _mask == null:
		return Kind.GRASS
	var u: float = clampf(position.x / WORLD_SIZE + 0.5, 0.0, 0.999)
	var v: float = clampf(position.z / WORLD_SIZE + 0.5, 0.0, 0.999)
	var kind: float = _mask.get_pixel(int(u * _mask.get_width()), int(v * _mask.get_height())).b
	if kind > 0.75:
		return Kind.STONE
	if kind > 0.25:
		return Kind.DIRT
	return Kind.GRASS


## Un sonido de paso para el piso del punto (sin repetir el anterior) y su volumen.
static func footstep(position: Vector3) -> Array:
	var kind: Kind = at(position)
	if not _steps.has(kind):
		var list: Array[AudioStream] = []
		for i in STEP_COUNT:
			var path: String = STEPS[kind] % (i + 1)
			if ResourceLoader.exists(path):
				list.append(load(path))
		_steps[kind] = list
	var list: Array = _steps[kind]
	if list.is_empty():
		return [null, 0.0]
	var index: int = randi() % list.size()
	if list.size() > 1 and index == _last:
		index = (index + 1) % list.size()
	_last = index
	return [list[index], VOLUMES[kind]]


static func _load(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var image: Image = (load(path) as Texture2D).get_image()
	if image and image.is_compressed():
		image.decompress()
	return image
