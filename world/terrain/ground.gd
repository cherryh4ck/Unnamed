extends MeshInstance3D

## Piso del mundo: carga los mapas de mezcla que pinta world/build_world.gd
## (se guardan como PNG aparte para no meterlos dentro de la escena).

const SPLAT_A := "res://world/terrain/splat_a.png"
const SPLAT_B := "res://world/terrain/splat_b.png"


func _ready() -> void:
	var material := mesh.surface_get_material(0) as ShaderMaterial
	if material == null:
		return
	if ResourceLoader.exists(SPLAT_A):
		material.set_shader_parameter("splat_a", load(SPLAT_A))
	if ResourceLoader.exists(SPLAT_B):
		material.set_shader_parameter("splat_b", load(SPLAT_B))
