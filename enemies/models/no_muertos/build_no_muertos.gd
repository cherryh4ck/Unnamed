extends SceneTree

## Genera los recursos de los no-muertos sobre el esqueleto de 0 A.D.:
## - huesos.res: la malla del esqueleto (craneo, columna, costillas, pelvis y
##   extremidades) armada con figuras simples y pegada a los huesos del rig,
##   asi usa las mismas animaciones que los personajes.
## - huesos_skin.tres: el skin que ata esa malla al Skeleton3D.
## - animaciones.res: clips extra (levantarse del suelo, quieto y caminar de
##   zombi con los brazos hacia adelante).
## Correr: godot --headless --path . --script res://enemies/models/no_muertos/build_no_muertos.gd

const RIG := "res://assets/characters/oad/oad_anim_library.glb"
const OUT := "res://enemies/models/no_muertos/"
const TRACK_PREFIX := "Armature/Skeleton3D:"

const BONE_COLOR := Color(0.8, 0.74, 0.6)
const DIRT := Color(0.42, 0.34, 0.24)
const DARK := Color(0.03, 0.02, 0.02)
const TEETH := Color(0.86, 0.8, 0.62)

var sk: Skeleton3D
var noise := FastNoiseLite.new()
var bones := Surface.new()
var eyes := Surface.new()


## Vertices de una superficie; cada vertice va pegado a un solo hueso.
class Surface:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var bone_ids := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()

	func add(p: Vector3, n: Vector3, c: Color, bone: int) -> void:
		verts.append(p)
		normals.append(n.normalized())
		colors.append(c)
		bone_ids.append_array([bone, 0, 0, 0])
		weights.append_array([1.0, 0.0, 0.0, 0.0])

	func arrays() -> Array:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = verts
		a[Mesh.ARRAY_NORMAL] = normals
		a[Mesh.ARRAY_COLOR] = colors
		a[Mesh.ARRAY_BONES] = bone_ids
		a[Mesh.ARRAY_WEIGHTS] = weights
		a[Mesh.ARRAY_INDEX] = indices
		return a


func _initialize() -> void:
	root.get_node("save_game").save_path = "user://build_no_muertos_descartable.json"
	noise.seed = 7
	noise.frequency = 0.9
	var rig: Node3D = load(RIG).instantiate()
	sk = rig.find_child("Skeleton3D", true, false)

	_build_skeleton_mesh()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bones.arrays())
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, eyes.arrays())
	mesh.surface_set_material(0, _bone_material())
	mesh.surface_set_material(1, _eye_material(Color(0.35, 0.95, 1.0)))
	mesh.surface_set_name(0, "huesos")
	mesh.surface_set_name(1, "ojos")
	_save(mesh, OUT + "huesos.res")

	var skin := Skin.new()
	for i in sk.get_bone_count():
		skin.add_named_bind(sk.get_bone_name(i), sk.get_bone_global_rest(i).affine_inverse())
	_save(skin, OUT + "huesos_skin.tres")

	var player: AnimationPlayer = rig.find_child("AnimationPlayer", true, false)
	_save(_build_animations(player), OUT + "animaciones.res")
	print("huesos: %d vertices, %d triangulos" % [bones.verts.size() + eyes.verts.size(), (bones.indices.size() + eyes.indices.size()) / 3])
	rig.free()
	quit()


func _save(resource: Resource, path: String) -> void:
	var err := ResourceSaver.save(resource, path)
	print("guardado ", path, " -> ", error_string(err))


func _bone_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	return mat


func _eye_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	return mat


# --- Piezas -----------------------------------------------------------------

func _bone(bone_name: String) -> int:
	var id := sk.find_bone(bone_name)
	assert(id >= 0, "no existe el hueso " + bone_name)
	return id


func _rest(bone_name: String) -> Vector3:
	return sk.get_bone_global_rest(_bone(bone_name)).origin


## Color de hueso con manchas de tierra y vejez.
func _tint(p: Vector3, base: Color) -> Color:
	if base == DARK:
		return base
	var grain: float = noise.get_noise_3dv(p * 45.0)
	var stain: float = maxf(noise.get_noise_3dv(p * 9.0 + Vector3(5, 5, 5)), 0.0)
	var c: Color = (base * (0.8 + 0.35 * grain)).lerp(DIRT, minf(stain * 2.2, 0.8))
	c.a = 1.0
	return c


## Elipsoide con radios r, orientado con basis.
func ellipsoid(s: Surface, center: Vector3, r: Vector3, bone: int, base: Color = BONE_COLOR,
		basis: Basis = Basis.IDENTITY, rings: int = 6, segs: int = 10) -> void:
	var start := s.verts.size()
	for i in rings + 1:
		var phi: float = PI * i / rings
		for j in segs + 1:
			var theta: float = TAU * j / segs
			var unit := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var p: Vector3 = center + basis * (unit * r)
			s.add(p, basis * (unit / r), _tint(p, base), bone)
	for i in rings:
		for j in segs:
			var a := start + i * (segs + 1) + j
			var b := a + segs + 1
			s.indices.append_array([a, b, a + 1, a + 1, b, b + 1])


## Tubo que sigue una linea de puntos; el radio puede cambiar en cada punto.
func tube(s: Surface, points: Array, radii: Array, bone: int, base: Color = BONE_COLOR, segs: int = 6) -> void:
	var start := s.verts.size()
	var count := points.size()
	var normal := Vector3.ZERO
	for k in count:
		var p: Vector3 = points[k]
		var tangent: Vector3 = (points[mini(k + 1, count - 1)] - points[maxi(k - 1, 0)]).normalized()
		if normal == Vector3.ZERO:
			normal = tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT).normalized()
		normal = (normal - tangent * normal.dot(tangent)).normalized()
		var binormal := tangent.cross(normal)
		var r: float = radii[mini(k, radii.size() - 1)]
		for j in segs + 1:
			var a: float = TAU * j / segs
			var dir: Vector3 = normal * cos(a) + binormal * sin(a)
			var q: Vector3 = p + dir * r
			s.add(q, dir, _tint(q, base), bone)
	for k in count - 1:
		for j in segs:
			var a := start + k * (segs + 1) + j
			var b := a + segs + 1
			s.indices.append_array([a, b, a + 1, a + 1, b, b + 1])


## Hueso largo: cana fina y cabezas mas gruesas en las puntas.
func long_bone(s: Surface, a: Vector3, b: Vector3, r: float, bone: int, knob_a: float = 1.8, knob_b: float = 1.6) -> void:
	var mid1 := a.lerp(b, 0.15)
	var mid2 := a.lerp(b, 0.85)
	tube(s, [a, mid1, a.lerp(b, 0.5), mid2, b], [r * 1.3, r, r * 0.85, r, r * 1.3], bone)
	var axis := (b - a).normalized()
	var basis := _basis_along(axis)
	ellipsoid(s, a, Vector3(r * knob_a, r * knob_a * 1.1, r * knob_a), bone, BONE_COLOR, basis, 5, 8)
	ellipsoid(s, b, Vector3(r * knob_b * 1.15, r * knob_b, r * knob_b), bone, BONE_COLOR, basis, 5, 8)


## Base cuyo eje Y apunta en la direccion dada.
func _basis_along(axis: Vector3) -> Basis:
	var x := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(axis).normalized()
	return Basis(x, axis, z)


# --- Esqueleto -------------------------------------------------------------

func _build_skeleton_mesh() -> void:
	_skull()
	_spine()
	_ribcage()
	_pelvis()
	for side in [1.0, -1.0]:
		var sfx: String = "_L" if side > 0.0 else "_R"
		_arm(side, sfx)
		_leg(side, sfx)


func _skull() -> void:
	var head := _bone("head")
	# Craneo, cara y pomulos.
	ellipsoid(bones, Vector3(0, 1.705, -0.02), Vector3(0.071, 0.083, 0.094), head, BONE_COLOR, Basis.IDENTITY, 8, 12)
	ellipsoid(bones, Vector3(0, 1.645, 0.042), Vector3(0.05, 0.046, 0.047), head)
	ellipsoid(bones, Vector3(0, 1.704, 0.06), Vector3(0.06, 0.016, 0.03), head)
	for x in [0.05, -0.05]:
		ellipsoid(bones, Vector3(x, 1.66, 0.045), Vector3(0.019, 0.017, 0.03), head)
	# Cuencas de los ojos (inclinadas, como el ceño fruncido) y nariz.
	for side in [1.0, -1.0]:
		ellipsoid(bones, Vector3(side * 0.03, 1.681, 0.072), Vector3(0.026, 0.023, 0.013), head, DARK, Basis(Vector3.BACK, side * 0.3))
		ellipsoid(eyes, Vector3(side * 0.03, 1.679, 0.083), Vector3(0.008, 0.007, 0.005), head, Color.WHITE)
	for side in [1.0, -1.0]:
		ellipsoid(bones, Vector3(side * 0.006, 1.65, 0.087), Vector3(0.007, 0.017, 0.006), head, DARK, Basis(Vector3.BACK, side * -0.35))
	# Dientes apretados, con las separaciones marcadas, y mandibula.
	ellipsoid(bones, Vector3(0, 1.607, 0.068), Vector3(0.034, 0.018, 0.018), head, TEETH)
	ellipsoid(bones, Vector3(0, 1.607, 0.08), Vector3(0.028, 0.0022, 0.006), head, DARK)
	for k in 7:
		var a: float = (k - 3) * 0.32
		ellipsoid(bones, Vector3(sin(a) * 0.03, 1.607, 0.069 + cos(a) * 0.016), Vector3(0.0018, 0.015, 0.003), head, DARK, Basis(Vector3.UP, a), 3, 4)
	tube(bones, [Vector3(0.056, 1.655, -0.012), Vector3(0.052, 1.592, 0.008), Vector3(0.04, 1.581, 0.048),
			Vector3(0, 1.576, 0.072), Vector3(-0.04, 1.581, 0.048), Vector3(-0.052, 1.592, 0.008),
			Vector3(-0.056, 1.655, -0.012)], [0.01, 0.014, 0.014, 0.015, 0.014, 0.014, 0.01], head)


func _spine() -> void:
	# Cuello.
	var neck := _bone("neck")
	for k in 3:
		var y: float = 1.52 + k * 0.022
		ellipsoid(bones, Vector3(0, y, -0.04 + k * 0.006), Vector3(0.019, 0.009, 0.017), neck)
	# Lumbares y dorsales: discos con la apofisis hacia atras.
	var segments := [["spine", 0.99, 1.07, -0.055, -0.055, 3], ["spine1", 1.07, 1.18, -0.055, -0.065, 3], ["chest", 1.19, 1.5, -0.068, -0.055, 9]]
	for seg in segments:
		var bone := _bone(seg[0])
		for k in seg[5]:
			var t: float = (k + 0.5) / seg[5]
			var y: float = lerpf(seg[1], seg[2], t)
			var z: float = lerpf(seg[3], seg[4], t)
			ellipsoid(bones, Vector3(0, y, z), Vector3(0.024, 0.011, 0.02), bone, BONE_COLOR, Basis.IDENTITY, 4, 8)
			ellipsoid(bones, Vector3(0, y - 0.004, z - 0.026), Vector3(0.007, 0.009, 0.017), bone, BONE_COLOR, Basis.IDENTITY, 3, 6)


func _ribcage() -> void:
	var chest := _bone("chest")
	# Siete pares de costillas: salen de la columna, rodean el pecho y bajan
	# hacia el esternon; las de abajo quedan sueltas.
	for i in 7:
		var t: float = i / 6.0
		var y_back: float = lerpf(1.45, 1.235, t)
		var half_width: float = 0.085 + 0.065 * sin(PI * (0.15 + 0.7 * t))
		var half_depth: float = 0.075 + 0.025 * sin(PI * t)
		var end_angle: float = 2.85 if i < 5 else 2.45 - (i - 5) * 0.25
		for side in [1.0, -1.0]:
			var pts := []
			var steps := 12
			for k in steps + 1:
				var a: float = lerpf(0.32, end_angle, float(k) / steps)
				var y: float = y_back - 0.075 * (a / PI) + 0.025 * sin(a)
				pts.append(Vector3(side * half_width * sin(a), y, 0.012 - half_depth * cos(a)))
			tube(bones, pts, [0.009], chest, BONE_COLOR, 5)
	# Esternon.
	ellipsoid(bones, Vector3(0, 1.36, 0.093), Vector3(0.017, 0.085, 0.009), chest, BONE_COLOR, Basis(Vector3.RIGHT, -0.18))


func _pelvis() -> void:
	var hip := _bone("hip")
	for side in [1.0, -1.0]:
		var wing := Basis(Vector3.UP, side * 0.55) * Basis(Vector3.FORWARD, side * -0.35)
		ellipsoid(bones, Vector3(side * 0.08, 0.975, -0.015), Vector3(0.058, 0.048, 0.016), hip, BONE_COLOR, wing)
		tube(bones, [Vector3(side * 0.085, 0.94, 0.0), Vector3(side * 0.07, 0.885, 0.03), Vector3(side * 0.025, 0.87, 0.06)], [0.016, 0.013, 0.012], hip)
		ellipsoid(bones, Vector3(side * 0.05, 0.875, -0.025), Vector3(0.018, 0.024, 0.02), hip)
	ellipsoid(bones, Vector3(0, 0.955, -0.055), Vector3(0.034, 0.052, 0.018), hip, BONE_COLOR, Basis(Vector3.RIGHT, 0.35))


func _arm(side: float, sfx: String) -> void:
	var shoulder := _bone("shoulder" + sfx)
	var arm := _bone("arm" + sfx)
	var forearm := _bone("forearm" + sfx)
	var hand := _bone("hand" + sfx)
	var finger := _bone("finger" + sfx)
	var p_arm := _rest("arm" + sfx)
	var p_fore := _rest("forearm" + sfx)
	var p_hand := _rest("hand" + sfx)
	var p_finger := _rest("finger" + sfx)

	# Clavicula y omoplato.
	tube(bones, [Vector3(side * 0.02, 1.465, 0.075), Vector3(side * 0.08, 1.475, 0.05), Vector3(side * 0.15, 1.47, -0.005), p_arm + Vector3(-side * 0.01, 0.03, 0.0)],
			[0.011, 0.01, 0.01, 0.012], shoulder)
	ellipsoid(bones, Vector3(side * 0.1, 1.39, -0.1), Vector3(0.05, 0.065, 0.011), shoulder, BONE_COLOR, Basis(Vector3.UP, side * 0.35))
	# Humero, radio y cubito.
	long_bone(bones, p_arm, p_fore, 0.017, arm, 1.6, 1.5)
	var axis := (p_hand - p_fore).normalized()
	var across := axis.cross(Vector3.RIGHT).normalized() * 0.011
	for off in [across, -across]:
		long_bone(bones, p_fore + off * 0.8, p_hand + off, 0.0095, forearm, 1.6, 1.5)
	# Mano: carpo, metacarpos y dedos curvados hacia adentro.
	ellipsoid(bones, p_hand + Vector3(0, -0.012, 0), Vector3(0.016, 0.02, 0.026), hand)
	var down := (p_finger - p_hand).normalized()
	for k in 4:
		var z: float = -0.024 + k * 0.016
		var base := p_hand + Vector3(0, -0.02, z)
		var knuckle := p_finger + Vector3(0, 0.0, z * 1.2)
		tube(bones, [base, knuckle], [0.005, 0.006], hand, BONE_COLOR, 4)
		var tip := knuckle + down * 0.04 + Vector3(-side * 0.022, 0, 0)
		tube(bones, [knuckle, knuckle + down * 0.025 + Vector3(-side * 0.006, 0, 0), tip], [0.0055, 0.005, 0.004], finger, BONE_COLOR, 4)
	tube(bones, [p_hand + Vector3(-side * 0.008, -0.01, 0.03), p_hand + Vector3(-side * 0.02, -0.05, 0.055), p_hand + Vector3(-side * 0.03, -0.075, 0.055)], [0.007, 0.006, 0.005], hand, BONE_COLOR, 4)


func _leg(side: float, sfx: String) -> void:
	var thigh := _bone("thigh" + sfx)
	var leg := _bone("leg" + sfx)
	var foot := _bone("foot" + sfx)
	var p_leg := _rest("leg" + sfx)
	var p_foot := _rest("foot" + sfx)

	# Femur con cabeza y trocanter, rotula, tibia y perone.
	var hip_joint := Vector3(side * 0.088, 0.93, 0.005)
	long_bone(bones, hip_joint, p_leg + Vector3(0, 0.02, 0), 0.02, thigh, 1.5, 1.6)
	ellipsoid(bones, Vector3(side * 0.125, 0.915, -0.005), Vector3(0.02, 0.026, 0.02), thigh)
	ellipsoid(bones, p_leg + Vector3(0, 0.0, 0.035), Vector3(0.019, 0.022, 0.012), leg)
	long_bone(bones, p_leg + Vector3(0, -0.02, 0.0), p_foot + Vector3(0, 0.015, 0.0), 0.018, leg, 1.7, 1.2)
	long_bone(bones, p_leg + Vector3(side * 0.028, -0.04, -0.015), p_foot + Vector3(side * 0.024, 0.015, -0.005), 0.007, leg, 1.5, 1.6)
	# Pie: talon, tarso, metatarsos y dedos.
	var ground: float = 0.012
	ellipsoid(bones, p_foot + Vector3(0, -0.02, -0.02), Vector3(0.022, 0.026, 0.04), foot)
	for k in 5:
		var x: float = p_foot.x + side * (-0.026 + k * 0.014)
		var start := Vector3(x * 0.98 + side * 0.006, 0.032, p_foot.z + 0.03)
		var ball := Vector3(x + side * 0.004 * k, ground + 0.004, p_foot.z + 0.15 - k * 0.008)
		tube(bones, [start, ball], [0.007, 0.006], foot, BONE_COLOR, 4)
		tube(bones, [ball, ball + Vector3(0, -0.002, 0.045 - k * 0.005)], [0.006, 0.0045], foot, BONE_COLOR, 4)


# --- Animaciones -----------------------------------------------------------

func _build_animations(player: AnimationPlayer) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	lib.add_animation("levantarse", _reversed(player.get_animation("death_b")))
	lib.add_animation("zombi_quieto", _zombie(player.get_animation("idle_merchant"), 0.0))
	lib.add_animation("zombi_caminar", _zombie(player.get_animation("walk_merchant"), 1.0))
	return lib


## La muerte al reves: de estar tirado en el piso a pararse.
func _reversed(source: Animation) -> Animation:
	var anim := Animation.new()
	anim.length = source.length
	for t in source.get_track_count():
		var track := anim.add_track(source.track_get_type(t))
		anim.track_set_path(track, source.track_get_path(t))
		anim.track_set_interpolation_type(track, source.track_get_interpolation_type(t))
		for k in source.track_get_key_count(t):
			anim.track_insert_key(track, source.length - source.track_get_key_time(t, k), source.track_get_key_value(t, k))
	return anim


## Copia del clip con los brazos estirados hacia adelante, la espalda encorvada
## y la cabeza caida hacia un costado. swing: cuanto se balancean los brazos.
func _zombie(source: Animation, swing: float) -> Animation:
	var anim: Animation = source.duplicate(true)
	anim.loop_mode = Animation.LOOP_LINEAR
	var forward := {
		"arm_L": Vector3(0.18, -0.22, 1.0),
		"arm_R": Vector3(-0.14, -0.08, 1.0),
	}
	for bone_name: String in forward:
		var phase: float = 0.0 if bone_name == "arm_L" else PI
		_set_track(anim, bone_name, func(t: float) -> Quaternion:
			var sway := swing * 0.12 * sin(TAU * t / anim.length + phase)
			var dir: Vector3 = forward[bone_name].normalized().rotated(Vector3.RIGHT, sway)
			return _aim_local(bone_name, dir))
		var fore: String = "fore" + bone_name
		_set_track(anim, fore, func(_t: float) -> Quaternion: return sk.get_bone_rest(_bone(fore)).basis.get_rotation_quaternion())
	_rotate_track(anim, "chest", Vector3.RIGHT, 0.25)
	_rotate_track(anim, "neck", Vector3.RIGHT, 0.15)
	_rotate_track(anim, "head", Vector3.BACK, 0.3)
	return anim


## Rotacion local del hueso para que apunte (en el espacio del esqueleto en
## reposo) hacia dir, girando lo minimo desde la pose de reposo.
func _aim_local(bone_name: String, dir: Vector3) -> Quaternion:
	var id := _bone(bone_name)
	var parent_basis: Basis = sk.get_bone_global_rest(sk.get_bone_parent(id)).basis.orthonormalized()
	var global_basis: Basis = sk.get_bone_global_rest(id).basis.orthonormalized()
	var child := _bone("fore" + bone_name)
	var along: Vector3 = (global_basis * sk.get_bone_rest(child).origin).normalized()
	var turn := Quaternion(along, dir.normalized())
	var local: Basis = parent_basis.inverse() * Basis(turn) * global_basis
	return local.get_rotation_quaternion()


func _track(anim: Animation, bone_name: String) -> int:
	var path := NodePath(TRACK_PREFIX + bone_name)
	var track := anim.find_track(path, Animation.TYPE_ROTATION_3D)
	if track < 0:
		track = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, path)
	return track


## Reemplaza las claves de rotacion del hueso por las que da value(t).
func _set_track(anim: Animation, bone_name: String, value: Callable) -> void:
	var track := _track(anim, bone_name)
	while anim.track_get_key_count(track) > 0:
		anim.track_remove_key(track, 0)
	var steps := 12
	for k in steps + 1:
		var t: float = anim.length * k / steps
		anim.rotation_track_insert_key(track, t, value.call(t))


## Suma una rotacion (eje en el espacio del esqueleto) a las claves del hueso.
func _rotate_track(anim: Animation, bone_name: String, axis: Vector3, angle: float) -> void:
	var id := _bone(bone_name)
	var parent_basis: Basis = sk.get_bone_global_rest(sk.get_bone_parent(id)).basis.orthonormalized()
	var extra := Quaternion((parent_basis.inverse() * axis).normalized(), angle)
	var track := _track(anim, bone_name)
	if anim.track_get_key_count(track) == 0:
		anim.rotation_track_insert_key(track, 0.0, sk.get_bone_rest(id).basis.get_rotation_quaternion())
	for k in anim.track_get_key_count(track):
		var q: Quaternion = anim.track_get_key_value(track, k)
		anim.track_set_key_value(track, k, extra * q)
