extends StaticBody3D

## Cofre del mundo. Al hacerle clic el jugador camina hasta el (esta en el
## grupo "npcs", ver Movement._handle_click), se abre la tapa y suelta botin
## segun el nivel de la zona. Se abre una sola vez por partida: queda anotado
## en save_game como los items del mapa ya juntados.

const LID_NODE := "treasure_chest_lid"
const LOCK_NODE := "treasure_chest_lock"
const OPEN_ANGLE: float = deg_to_rad(-105.0)

## Nivel del botin (el de la zona donde esta).
@export var level: int = 1
## 0 = cofre comun, 1 = cofre bueno (mas items y gemas).
@export_range(0, 1) var quality: int = 0

var opened: bool = false
var _lid: Node3D
var _lock: Node3D
var _lid_rest: Transform3D
# El candado relativo a la tapa cerrada (cuelga de ella y se mueve con ella).
var _lock_on_lid: Transform3D
var _lid_tween: Tween
var _lid_amount: float = 0.0


func _ready() -> void:
	add_to_group("npcs")
	add_to_group("chests")
	_lid = find_child(LID_NODE, true, false)
	_lock = find_child(LOCK_NODE, true, false)
	if _lid:
		_lid_rest = _lid.transform
	if _lid and _lock:
		_lock_on_lid = _lid_rest.affine_inverse() * _lock.transform
	if _was_opened():
		opened = true
		_set_lid(1.0)


func get_display_name() -> String:
	return "Cofre"


func interact() -> void:
	var head: Vector3 = global_position + Vector3.UP * 260.0
	if opened:
		floating_text.spawn(head, "Vacío", Color(0.7, 0.7, 0.7), 16)
		return
	opened = true
	save_game.mark_collected(self)
	_animate_lid(true)
	sfx.play_at("chest_open", global_position)
	await get_tree().create_timer(0.35, false).timeout
	var front: Vector3 = global_position + global_transform.basis.z * 90.0
	for drop in Loot.roll_chest_drops(level, quality, difficulty.get_value("gold"), difficulty.get_value("magic_find")):
		Loot.spawn_pickup(get_parent(), front, drop.item, drop.quantity)


func _was_opened() -> bool:
	return save_game.is_collected(self)


func _animate_lid(open: bool) -> void:
	if _lid == null:
		return
	if _lid_tween:
		_lid_tween.kill()
	var from: float = _lid_amount
	_lid_tween = create_tween()
	_lid_tween.tween_method(_set_lid, from, 1.0 if open else 0.0, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)


# 0 = cerrada, 1 = abierta.
func _set_lid(amount: float) -> void:
	_lid_amount = amount
	if _lid == null:
		return
	_lid.transform = _lid_rest * Transform3D(Basis(Vector3.RIGHT, OPEN_ANGLE * amount), Vector3.ZERO)
	if _lock:
		_lock.transform = _lid.transform * _lock_on_lid
