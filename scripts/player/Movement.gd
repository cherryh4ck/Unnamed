extends CharacterBody3D

signal hovered_enemy_changed(enemy: Node3D)

@export var ClickReference: NodePath = NodePath("../ClickReference")
@onready var click_reference: Node3D = get_node_or_null(ClickReference)
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var combat: Node = $Combat

var speed: float = 700.0
## Distancia (centro a centro, en el plano) desde la que el jugador le pega a un enemigo.
@export var attack_range: float = 260.0
## Segundos hasta reaparecer despues de morir.
@export var respawn_delay: float = 4.0

## Mientras se mantiene apretado el clic, cada cuanto se actualiza el destino.
const HOLD_REPATH_INTERVAL: float = 0.1
## Cuanto se tiene que mover el enemigo para recalcular el camino hacia el.
const CHASE_REPATH_DISTANCE: float = 40.0
## Distancia en la que se busca un enemigo para el Golpe Brutal si no hay ninguno marcado.
const SKILL_AUTO_TARGET_RANGE: float = 700.0
const SKILL_COUNT: int = 5
## Distancia a la que se junta un item clickeado.
const PICKUP_REACH: float = 170.0
## Capa de fisica de los items en el piso (ver item/pickup.gd).
const PICKUP_MASK: int = 4

var target_enemy: Node3D = null
var hovered_enemy: Node3D = null
## Habilidad de golpe esperando a que el objetivo quede en rango (-1 = ninguna).
var pending_skill: int = -1
## Item del piso al que se esta caminando para juntarlo.
var target_pickup: Node3D = null
var spawn_position: Vector3

var _moving: bool = false
var _holding_move: bool = false
var _hold_timer: float = 0.0
var _last_chase_target: Vector3 = Vector3.INF

var sonidos_pasos: Array[AudioStream] = []
var reproductor_pasos: AudioStreamPlayer3D
var intervalo_pasos: float = 0.4
var tiempo_paso: float = 0.4
var ultimo_paso: int = -1

func _ready() -> void:
	spawn_position = global_position
	if click_reference:
		click_reference.hide()

	for i in range(1, 8):
		var ruta = "res://sounds/ambient/footsteps/footstep%d.wav" % i
		if ResourceLoader.exists(ruta):
			sonidos_pasos.append(load(ruta))

	reproductor_pasos = AudioStreamPlayer3D.new()
	reproductor_pasos.volume_db = 12.0
	add_child(reproductor_pasos)

	player_stats.died.connect(_on_died)
	player_stats.leveled_up.connect(_on_leveled_up)
	inventory_data.item_dropped.connect(_on_item_dropped)
	player_stats.potion_used.connect(_on_potion_used)


func is_moving() -> bool:
	return _moving


func _physics_process(delta: float) -> void:
	_moving = false
	if player_stats.dead:
		velocity = Vector3.ZERO
		return

	_update_hover()
	_update_hold(delta)

	if _update_attack_target(delta):
		return
	_update_target_pickup()

	if nav_agent.is_navigation_finished():
		if click_reference:
			click_reference.hide()
		tiempo_paso = intervalo_pasos
		return

	move_to_point(speed)
	_moving = true

	tiempo_paso += delta
	if tiempo_paso >= intervalo_pasos:
		tiempo_paso = 0.0
		reproducir_paso()


func reproducir_paso() -> void:
	if sonidos_pasos.is_empty():
		return

	var indice = randi() % sonidos_pasos.size()
	if sonidos_pasos.size() > 1 and indice == ultimo_paso:
		indice = (indice + 1) % sonidos_pasos.size()
	ultimo_paso = indice

	reproductor_pasos.stream = sonidos_pasos[indice]
	reproductor_pasos.play()


func move_to_point(move_speed: float) -> void:
	var target_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(target_pos)

	velocity = direction * move_speed
	move_and_slide()


func stop_moving() -> void:
	nav_agent.target_position = global_position
	velocity = Vector3.ZERO


# Si hay un enemigo marcado: lo persigue y, cuando esta en rango, le pega.
# Devuelve true si este frame el jugador esta atacando (quieto).
func _update_attack_target(delta: float) -> bool:
	if target_enemy == null:
		return false
	if not is_instance_valid(target_enemy) or target_enemy.dead:
		target_enemy = null
		stop_moving()
		return false

	var to_target: Vector3 = target_enemy.global_position - global_position
	to_target.y = 0.0
	if to_target.length() <= attack_range:
		stop_moving()
		_face(to_target, delta)
		if pending_skill >= 0:
			combat.use_skill(pending_skill, target_enemy.global_position, target_enemy)
			pending_skill = -1
		else:
			combat.try_attack(target_enemy)
		return true

	if target_enemy.global_position.distance_to(_last_chase_target) > CHASE_REPATH_DISTANCE:
		_last_chase_target = target_enemy.global_position
		nav_agent.target_position = target_enemy.global_position
	return false


func _update_target_pickup() -> void:
	if target_pickup == null:
		return
	if not is_instance_valid(target_pickup):
		target_pickup = null
		return
	var offset: Vector3 = target_pickup.global_position - global_position
	offset.y = 0.0
	if offset.length() <= PICKUP_REACH:
		target_pickup.get_item()
		target_pickup = null
		stop_moving()


func _face(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.01:
		return
	var target_angle: float = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 12.0 * delta)


func _unhandled_input(event: InputEvent) -> void:
	if player_stats.dead:
		return
	if event.is_action_pressed("leftMouse"):
		_handle_click()
	elif event.is_action_released("leftMouse"):
		_holding_move = false
	elif event.is_action_pressed("use_potion"):
		drink_potion()
		get_viewport().set_input_as_handled()
	else:
		for i in SKILL_COUNT:
			if event.is_action_pressed("skill_%d" % (i + 1)):
				use_skill(i)
				get_viewport().set_input_as_handled()
				return


func _handle_click() -> void:
	var pickup_hit: Dictionary = _raycast_mouse(PICKUP_MASK, true)
	if not pickup_hit.is_empty():
		target_pickup = pickup_hit.collider
		target_enemy = null
		pending_skill = -1
		_holding_move = false
		_move_to(target_pickup.global_position)
		return

	var result: Dictionary = _raycast_mouse()
	if result.is_empty():
		return
	target_pickup = null

	var enemy: Node3D = _enemy_from_collider(result.collider)
	pending_skill = -1
	if enemy:
		target_enemy = enemy
		_last_chase_target = Vector3.INF
		_holding_move = false
		if click_reference:
			click_reference.hide()
		return

	target_enemy = null
	_holding_move = true
	_hold_timer = 0.0
	_move_to(result.position)


# Mantener el clic apretado sigue moviendo al personaje hacia el mouse.
func _update_hold(delta: float) -> void:
	if not _holding_move:
		return
	if not Input.is_action_pressed("leftMouse"):
		_holding_move = false
		return
	_hold_timer += delta
	if _hold_timer < HOLD_REPATH_INTERVAL:
		return
	_hold_timer = 0.0
	var result: Dictionary = _raycast_mouse()
	if not result.is_empty() and _enemy_from_collider(result.collider) == null:
		_move_to(result.position)


## Intenta usar la habilidad del slot (teclas 1-5 o clic en la barra).
func use_skill(index: int) -> void:
	var skill: SkillData = skill_book.get_skill(index)
	if skill == null or player_stats.dead:
		return
	var head: Vector3 = global_position + Vector3.UP * 450.0
	if not skill_book.is_unlocked(index):
		floating_text.spawn(head, "Se aprende en el nivel %d" % skill.unlock_level, Color(0.7, 0.7, 0.7), 16)
		return
	if not skill_book.is_ready(index):
		floating_text.spawn(head, "Recargando...", Color(0.7, 0.7, 0.7), 16)
		return

	if skill.kind == SkillData.Kind.STRIKE:
		var enemy: Node3D = _skill_target()
		if enemy == null:
			floating_text.spawn(head, "Sin objetivo", Color(0.7, 0.7, 0.7), 16)
			return
		# Camina hasta el enemigo; el golpe sale al quedar en rango.
		target_enemy = enemy
		_last_chase_target = Vector3.INF
		pending_skill = index
		return

	var aim: Vector3 = global_position + global_transform.basis.z * 500.0
	if is_instance_valid(hovered_enemy):
		aim = hovered_enemy.global_position
	else:
		var result: Dictionary = _raycast_mouse()
		if not result.is_empty():
			aim = result.position
	combat.use_skill(index, aim, hovered_enemy)


func _skill_target() -> Node3D:
	if is_instance_valid(hovered_enemy) and not hovered_enemy.dead:
		return hovered_enemy
	if is_instance_valid(target_enemy) and not target_enemy.dead:
		return target_enemy
	var best: Node3D = null
	var best_dist: float = SKILL_AUTO_TARGET_RANGE
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < best_dist:
			best = enemy
			best_dist = dist
	return best


func _move_to(point: Vector3) -> void:
	if click_reference:
		click_reference.global_position = point
		click_reference.show()
	nav_agent.target_position = point


func _update_hover() -> void:
	var enemy: Node3D = null
	var result: Dictionary = _raycast_mouse()
	if not result.is_empty():
		enemy = _enemy_from_collider(result.collider)
	if enemy == hovered_enemy:
		return
	if is_instance_valid(hovered_enemy) and hovered_enemy.has_method("set_highlighted"):
		hovered_enemy.set_highlighted(false)
	hovered_enemy = enemy
	if hovered_enemy and hovered_enemy.has_method("set_highlighted"):
		hovered_enemy.set_highlighted(true)
	hovered_enemy_changed.emit(hovered_enemy)


func _enemy_from_collider(collider: Object) -> Node3D:
	if collider is Node3D and collider.is_in_group("enemies") and not collider.dead:
		return collider
	return null


func _raycast_mouse(mask: int = 0xFFFFFFFF, areas_only: bool = false) -> Dictionary:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_length: float = 5000.0
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * ray_length
	var ray_query := PhysicsRayQueryParameters3D.create(from, to, mask)
	ray_query.exclude = [get_rid()]
	if areas_only:
		ray_query.collide_with_areas = true
		ray_query.collide_with_bodies = false
	return get_world_3d().direct_space_state.intersect_ray(ray_query)


## Lo llaman los enemigos al pegarle al jugador.
func take_damage(amount: float) -> void:
	var result: Dictionary = player_stats.take_damage(amount)
	var head: Vector3 = global_position + Vector3.UP * 420.0
	if result.blocked:
		floating_text.spawn(head, "Bloqueo", Color(0.65, 0.8, 1.0), 20)
		return
	floating_text.spawn(head, str(maxi(1, roundi(result.amount))), Color(1.0, 0.3, 0.25), 22)
	sfx.play_at("hit", global_position, -4.0)


func drink_potion() -> void:
	var reason: String = player_stats.use_potion()
	if not reason.is_empty():
		floating_text.spawn(global_position + Vector3.UP * 450.0, reason, Color(0.7, 0.7, 0.7), 16)


func _on_potion_used(amount: float) -> void:
	sfx.play("lifeleech")
	floating_text.spawn(global_position + Vector3.UP * 420.0, "+%d" % roundi(amount), Color(0.4, 1.0, 0.45), 22)
	Effects.aura(get_parent(), global_position, Color(0.4, 1.0, 0.45))


func _on_item_dropped(item: Itemdata, quantity: int) -> void:
	var pickup: Node3D = Loot.spawn_pickup(get_parent(), global_position, item, quantity)
	pickup.suspend_auto_pickup()
	sfx.play("drag_weapon" if item.is_equipment() else "drag_potion")


func _on_leveled_up(_new_level: int) -> void:
	sfx.play("levelup")
	Effects.level_up(get_parent(), global_position)


func _on_died() -> void:
	target_enemy = null
	pending_skill = -1
	_holding_move = false
	stop_moving()
	if click_reference:
		click_reference.hide()
	await get_tree().create_timer(respawn_delay, false).timeout
	global_position = spawn_position
	stop_moving()
	player_stats.respawn()
