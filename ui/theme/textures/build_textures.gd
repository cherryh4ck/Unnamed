extends SceneTree

## Arma las texturas de la interfaz (ui/theme/game_theme.tres) a partir del
## "RPG GUI construction kit v1.0" de Matjaž Lamut, CC-BY 3.0 (ver CREDITS.md).
## Las piezas originales estan en source/ (con .gdignore: Godot no las importa).
## Uso: godot --headless --path . --script res://ui/theme/textures/build_textures.gd

const SOURCE_DIR := "res://ui/theme/textures/source/"
const OUT_DIR := "res://ui/theme/textures/"

## Piezas del atlas rpg_gui_v1.png (x, y, ancho, alto).
const THICK_FRAME := {
	"tl": Rect2i(860, 193, 20, 20), "tr": Rect2i(978, 193, 20, 20),
	"bl": Rect2i(860, 294, 20, 20), "br": Rect2i(978, 294, 20, 20),
	"top": Rect2i(893, 193, 73, 9), "bottom": Rect2i(893, 305, 73, 9),
	"left": Rect2i(860, 227, 9, 55), "right": Rect2i(989, 227, 9, 55),
}
const THIN_FRAME := {
	"tl": Rect2i(869, 402, 15, 15), "tr": Rect2i(982, 402, 15, 15),
	"bl": Rect2i(869, 498, 15, 15), "br": Rect2i(982, 498, 15, 15),
	"top": Rect2i(899, 402, 74, 4), "bottom": Rect2i(899, 509, 74, 4),
	"left": Rect2i(869, 428, 4, 59), "right": Rect2i(993, 428, 4, 59),
}
const SLOT := Rect2i(121, 454, 74, 74)
const SMALL_SLOT := Rect2i(42, 491, 38, 38)
## Tablones (sin las puntas de flecha): el primero y el gastado del final.
const PLANK := Rect2i(41, 128, 231, 52)
const WORN_PLANK := Rect2i(41, 362, 231, 52)
## Columnas de los costados del tablon que tapan las puntas: se rehacen
## repitiendo hacia abajo las filas limpias de arriba.
const PLANK_SIDE: int = 8
const PLANK_CLEAN_ROWS := Vector2i(6, 9)

var _atlas: Image
var _wood: Image


func _initialize() -> void:
	_atlas = Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "rpg_gui_v1.png"))
	_atlas.convert(Image.FORMAT_RGBA8)
	_wood = _half_size(Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "wood_background.png")))

	_save(_framed(THICK_FRAME, _tinted(_wood, Color(0.44, 0.39, 0.32)), 2), "panel")
	_save(_framed(THIN_FRAME, _tinted(_wood, Color(0.3, 0.27, 0.22), 0.96), 1), "tooltip")
	_save(_darken_inside(_atlas.get_region(SLOT), 5, 0.4), "slot")
	_save(_darken_inside(_atlas.get_region(SMALL_SLOT), 4, 0.3), "bar_bg")

	# Tablones oscurecidos para que el texto claro se lea encima.
	var plank := _fixed_plank(PLANK)
	_save(_tinted(plank, Color(0.68, 0.63, 0.56)), "button_normal")
	_save(_tinted(plank, Color(0.95, 0.88, 0.76)), "button_hover")
	_save(_tinted(plank, Color(0.5, 0.47, 0.42)), "button_pressed")
	_save(_tinted(_desaturated(_fixed_plank(WORN_PLANK)), Color(0.45, 0.44, 0.42)), "button_disabled")

	_save(_bar_fill(Color(0.72, 0.1, 0.07)), "fill_health")
	_save(_bar_fill(Color(0.78, 0.6, 0.18)), "fill_xp")
	_save(_bar_fill(Color(0.52, 0.07, 0.05)), "fill_enemy")
	_save(_bar_fill(Color(0.22, 0.62, 0.12)), "fill_poison")
	quit()


func _save(img: Image, file_name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name + ".png"))
	print("%s.png %dx%d" % [file_name, img.get_width(), img.get_height()])


# Marco de 9 partes con relleno: el centro (todo menos las esquinas) mide
# exactamente lo que el relleno, asi el StyleBoxTexture lo repite sin cortes.
func _framed(parts: Dictionary, fill: Image, inset: int) -> Image:
	var corner: int = parts.tl.size.x
	var bar: int = parts.top.size.y
	var size := fill.get_size() + Vector2i(corner, corner) * 2
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in range(inset, size.y - inset):
		for x in range(inset, size.x - inset):
			img.set_pixel(x, y, fill.get_pixel(posmod(x - corner, fill.get_width()), posmod(y - corner, fill.get_height())))

	# Los bordes se arman repitiendo un tramo de 16 px de cada barra (16
	# divide al ancho del relleno: la repeticion empalma).
	var step: int = 16
	for x in range(corner, size.x - corner, step):
		img.blend_rect(_atlas, Rect2i(parts.top.position + Vector2i(20, 0), Vector2i(step, bar)), Vector2i(x, 0))
		img.blend_rect(_atlas, Rect2i(parts.bottom.position + Vector2i(20, 0), Vector2i(step, bar)), Vector2i(x, size.y - bar))
	for y in range(corner, size.y - corner, step):
		img.blend_rect(_atlas, Rect2i(parts.left.position + Vector2i(0, 20), Vector2i(bar, step)), Vector2i(0, y))
		img.blend_rect(_atlas, Rect2i(parts.right.position + Vector2i(0, 20), Vector2i(bar, step)), Vector2i(size.x - bar, y))
	img.blend_rect(_atlas, parts.tl, Vector2i.ZERO)
	img.blend_rect(_atlas, parts.tr, Vector2i(size.x - corner, 0))
	img.blend_rect(_atlas, parts.bl, Vector2i(0, size.y - corner))
	img.blend_rect(_atlas, parts.br, Vector2i(size.x - corner, size.y - corner))
	return img


func _fixed_plank(rect: Rect2i) -> Image:
	var img := _atlas.get_region(rect)
	var w := img.get_width()
	for y in range(PLANK_CLEAN_ROWS.y, img.get_height() - PLANK_CLEAN_ROWS.y):
		var src_y: int = PLANK_CLEAN_ROWS.x + (y - PLANK_CLEAN_ROWS.y) % (PLANK_CLEAN_ROWS.y - PLANK_CLEAN_ROWS.x)
		for x in PLANK_SIDE:
			img.set_pixel(x, y, img.get_pixel(x, src_y))
			img.set_pixel(w - 1 - x, y, img.get_pixel(w - 1 - x, src_y))
	return img


# Oscurece el interior (deja el borde de bronce como esta).
func _darken_inside(img: Image, border: int, factor: float) -> Image:
	for y in range(border, img.get_height() - border):
		for x in range(border, img.get_width() - border):
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * factor, c.g * factor, c.b * factor, c.a))
	return img


func _tinted(src: Image, tint: Color, alpha: float = 1.0) -> Image:
	var img := src.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(minf(c.r * tint.r, 1.0), minf(c.g * tint.g, 1.0), minf(c.b * tint.b, 1.0), c.a * alpha))
	return img


func _desaturated(src: Image) -> Image:
	var img := src.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var v: float = c.get_luminance()
			img.set_pixel(x, y, Color(v, v, v, c.a).lerp(c, 0.25))
	return img


# Reduce a la mitad promediando de a 2x2: la textura sigue empalmando.
func _half_size(src: Image) -> Image:
	src.convert(Image.FORMAT_RGBA8)
	var img := Image.create(src.get_width() / 2, src.get_height() / 2, false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := (src.get_pixel(x * 2, y * 2) + src.get_pixel(x * 2 + 1, y * 2)
					+ src.get_pixel(x * 2, y * 2 + 1) + src.get_pixel(x * 2 + 1, y * 2 + 1)) / 4.0
			img.set_pixel(x, y, c)
	return img


# Relleno de barra: color con brillo arriba, sombra abajo y la veta de la
# madera apenas marcada. Tiene 3 px transparentes alrededor para no tapar
# el borde de bronce del fondo.
func _bar_fill(color: Color) -> Image:
	var pad: int = 3
	var size := Vector2i(48, 20)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in range(pad, size.y - pad):
		var t: float = float(y - pad) / float(size.y - pad * 2 - 1)
		var shade: float = lerpf(1.35, 0.7, t)
		for x in range(pad, size.x - pad):
			var grain: float = _wood.get_pixel(x * 3 % _wood.get_width(), y * 5 % _wood.get_height()).get_luminance()
			var k: float = shade * (0.85 + grain * 0.4)
			img.set_pixel(x, y, Color(minf(color.r * k, 1.0), minf(color.g * k, 1.0), minf(color.b * k, 1.0)))
	return img
