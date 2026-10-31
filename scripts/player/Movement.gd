extends CharacterBody3D

signal hovered_enemy_changed(enemy: Node3D)

@export var ClickReference: NodePath = NodePath("../ClickReference")
@onready var click_reference: Node3D = get_node_or_null(ClickReference)
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var combat: Node = $Combat
@onready var mount: Node3D = $Mount

var speed: float = 700.0
## Distancia (centro a centro, en el plano) desde la que el jugador le pega a un enemigo.
@export var attack_range: float = 260.0
## Distancia de ataque con una ballesta equipada.
@export var ranged_attack_range: float = 1300.0
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
## Distancia a la que se habla con un NPC.
const NPC_REACH: float = 300.0
## Capa de fisica de los items en el piso (ver item/pickup.gd).
const PICKUP_MASK: int = 4
## Arranque y frenada (unidades por segundo al cuadrado): llega a correr del
## todo en un decimo de segundo, sin saltos bruscos.
const ACCELERATION: float = 7000.0
## Al acercarse al destino frena de a poco en esta distancia.
const ARRIVE_DISTANCE: float = 110.0

var target_enemy: Node3D = null
var hovered_enemy: Node3D = null
## Habilidad de golpe esperando a que el objetivo quede en rango (-1 = ninguna).
var pending_skill: int = -1
## Combo con golpes esperando a que el objetivo quede en rango.
var pending_combo: bool = false
## Item del piso al que se esta caminando para juntarlo.
var target_pickup: Node3D = null
## NPC al que se esta caminando para hablarle.
var target_npc: Node3D = null
var spawn_position: Vector3

var _moving: bool = false
var _holding_move: bool = false
var _hold_timer: float = 0.0
var _last_chase_target: Vector3 = Vector3.INF
## Daño por tiempo acumulado que todavia no llego a 1 (para el numero flotante).
var _dot_shown: Dictionary = {}

var sonidos_pasos: Array[AudioStream] = []
var reproductor_pasos: AudioStreamPlayer3D
var intervalo_pasos: float = 0.4
var tiempo_paso: float = 0.4
var ultimo_paso: int = -1

func _ready() -> void:
	spawn_position = global_position
	# Con una partida cargada arranca donde estaba al guardar (al morir
	# reaparece igual en el inicio del mapa).
	if save_game.player_position != Vector3.INF:
		global_position = save_game.player_position
	if click_reference:
		click_reference.hide()

	for i in range(1, 8):
		var ruta = "res://sounds/ambient/footsteps/footstep%d.wav" % i
		if ResourceLoader.exists(ruta):
			sonidos_pasos.append(load(ruta))

	reproductor_pasos = AudioStreamPlayer3D.new()
	reproductor_pasos.unit_size = sfx.UNIT_SIZE_3D
	reproductor_pasos.max_distance = sfx.MAX_DISTANCE_3D
	reproductor_pasos.volume_db = -8.0
	reproductor_pasos.bus = &"Efectos"
	add_child(reproductor_pasos)

	player_stats.died.connect(_on_died)
	player_stats.leveled_up.connect(_on_leveled_up)
	inventory_data.item_dropped.connect(_on_item_dropped)
	player_stats.potion_used.connect(_on_potion_used)
	player_stats.dot_damaged.connect(_on_dot_damaged)
	nav_agent.path_changed.connect(_on_path_changed)


func is_moving() -> bool:
	return _moving


## Velocidad en el plano (la usa la animacion de correr para no patinar).
func ground_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


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
	_update_target_npc()

	if nav_agent.is_navigation_finished():
		if click_reference:
			click_reference.hide()
		tiempo_paso = intervalo_pasos
		_brake(delta)
		return

	move_to_point(speed, delta)
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


# Sigue el camino acelerando y girando de a poco (la velocidad se va
# acomodando hacia la direccion nueva en vez de cambiar de golpe), y frena al
# llegar si es un destino en el piso.
func move_to_point(move_speed: float, delta: float) -> void:
	var direction: Vector3 = global_position.direction_to(nav_agent.get_next_path_position())
	var goal_speed: float = move_speed
	if target_enemy == null and target_npc == null and target_pickup == null and not _holding_move:
		var final: Vector3 = nav_agent.get_final_position()
		var remaining: float = Vector2(final.x - global_position.x, final.z - global_position.z).length()
		goal_speed *= clampf(remaining / ARRIVE_DISTANCE, 0.35, 1.0)
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3(direction.x, 0.0, direction.z) * goal_speed, ACCELERATION * delta)
	velocity = Vector3(flat.x, direction.y * goal_speed, flat.z)
	move_and_slide()


# Sin destino: termina de frenar en vez de pararse en seco.
func _brake(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < 1.0:
		velocity = Vector3.ZERO
		return
	flat = flat.move_toward(Vector3.ZERO, ACCELERATION * delta)
	velocity = Vector3(flat.x, 0.0, flat.z)
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
	# El Golpe Brutal siempre necesita estar cuerpo a cuerpo.
	var reach: float = attack_range if pending_skill >= 0 or pending_combo else get_attack_range()
	if to_target.length() <= reach:
		stop_moving()
		_face(to_target, delta)
		if pending_skill >= 0:
			combat.use_skill(pending_skill, target_enemy.global_position, target_enemy)
			pending_skill = -1
		elif pending_combo:
			combat.use_combo(target_enemy.global_position, target_enemy)
			pending_combo = false
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


func get_attack_range() -> float:
	return ranged_attack_range if player_stats.is_ranged() else attack_range


func _update_target_npc() -> void:
	if target_npc == null:
		return
	if not is_instance_valid(target_npc):
		target_npc = null
		return
	var offset: Vector3 = target_npc.global_position - global_position
	offset.y = 0.0
	if offset.length() <= NPC_REACH:
		var npc: Node3D = target_npc
		target_npc = null
		stop_moving()
		npc.interact()


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
	elif event.is_action_pressed("skill_combo"):
		use_combo()
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
	target_npc = null

	if result.collider is Node and result.collider.is_in_group("npcs"):
		target_npc = result.collider
		target_enemy = null
		pending_skill = -1
		pending_combo = false
		_holding_move = false
		_move_to(target_npc.global_position)
		return

	var enemy: Node3D = _enemy_from_collider(result.collider)
	pending_skill = -1
	pending_combo = false
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
	_move_to_ground(result.position)


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
		_move_to_ground(result.position)


## Intenta usar la habilidad del slot (teclas 1-5 o clic en la barra).
func use_skill(index: int) -> void:
	var skill: SkillData = skill_book.get_skill(index)
	if skill == null or player_stats.dead:
		return
	if not skill_book.is_unlocked(index):
		_reject("Se aprende en el nivel %d" % skill.unlock_level)
		return
	if not skill_book.is_ready(index):
		_reject("Recargando...")
		return

	if skill.kind == SkillData.Kind.STRIKE:
		var enemy: Node3D = _skill_target()
		if enemy == null:
			_reject("Sin objetivo")
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


## Usa el combo armado (tecla 6 o clic en la barra).
func use_combo() -> void:
	if player_stats.dead:
		return
	if not skill_book.is_combo_unlocked():
		_reject("Los combos se aprenden en el nivel %d" % skill_book.COMBO_UNLOCK_LEVEL)
		return
	if skill_book.combo.is_empty():
		_reject("Armá un combo con la tecla K")
		return
	if not skill_book.is_combo_ready():
		_reject("Recargando...")
		return
	var enemy: Node3D = _skill_target()
	if skill_book.combo_has_strike():
		if enemy == null:
			_reject("Sin objetivo")
			return
		# Camina hasta el enemigo; el combo arranca al quedar cuerpo a cuerpo.
		target_enemy = enemy
		_last_chase_target = Vector3.INF
		pending_combo = true
		return
	var aim: Vector3 = global_position + global_transform.basis.z * 500.0
	if enemy:
		aim = enemy.global_position
	else:
		var result: Dictionary = _raycast_mouse()
		if not result.is_empty():
			aim = result.position
	combat.use_combo(aim, enemy)


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


# Clic en el piso (o en una roca, un arbol, el agua): va al punto caminable
# mas cercano. Si ni asi se puede llegar (otra isla), la marca se corre a
# donde de verdad termina el camino (ver _on_path_changed).
func _move_to_ground(point: Vector3) -> void:
	_move_to(NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, point))


func _on_path_changed() -> void:
	if click_reference and click_reference.visible and target_enemy == null:
		click_reference.global_position = nav_agent.get_final_position()


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


## Lo llaman los enemigos al pegarle al jugador ({Damage.Type: cantidad}).
func take_hit(parts: Dictionary) -> void:
	var result: Dictionary = player_stats.take_hit(parts)
	var head: Vector3 = global_position + Vector3.UP * 420.0
	if result.blocked:
		floating_text.spawn(head, "Bloqueo", Color(0.65, 0.8, 1.0), 20)
		return
	if result.amount > 0.0:
		# Rojo el fisico; los demas tipos con su color.
		var color: Color = Color(1.0, 0.3, 0.25) if result.type == Damage.Type.PHYSICAL else Damage.COLORS[result.type]
		floating_text.spawn(head, str(maxi(1, roundi(result.amount))), color, 22)
	sfx.play_at("hit", global_position, -4.0)


func _on_dot_damaged(amount: float, type: int) -> void:
	_dot_shown[type] = _dot_shown.get(type, 0.0) + amount
	if _dot_shown[type] >= 1.0:
		floating_text.spawn(global_position + Vector3.UP * 380.0, str(floori(_dot_shown[type])), Damage.COLORS[type], 16)
		_dot_shown[type] -= floorf(_dot_shown[type])


func drink_potion() -> void:
	var reason: String = player_stats.use_potion()
	if not reason.is_empty():
		_reject(reason)


## Texto gris sobre el personaje + sonido de "no se puede".
func _reject(reason: String) -> void:
	floating_text.spawn(global_position + Vector3.UP * 450.0, reason, Color(0.7, 0.7, 0.7), 16)
	sfx.play("stuck", -6.0)


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
	_clear_targets()
	stop_moving()
	if click_reference:
		click_reference.hide()
	await get_tree().create_timer(respawn_delay, false).timeout
	# Reaparece en el portal descubierto mas cercano (o en el inicio).
	var portal: Node3D = world_map.nearest_portal(global_position)
	_place_at(portal.arrival_point() if portal else spawn_position)
	player_stats.respawn()
	sfx.play_at("portal", global_position)
	Effects.aura(get_parent(), global_position, Color(0.55, 0.75, 1.0))


## Viaje por portal: aparece en el punto indicado con un destello.
func teleport_to(point: Vector3) -> void:
	_clear_targets()
	Effects.aura(get_parent(), global_position, Color(0.45, 0.75, 1.0))
	_place_at(point)
	sfx.play_at("portal", global_position)
	Effects.aura(get_parent(), global_position, Color(0.45, 0.75, 1.0))


func _clear_targets() -> void:
	target_enemy = null
	target_pickup = null
	target_npc = null
	pending_skill = -1
	pending_combo = false
	_holding_move = false


func _place_at(point: Vector3) -> void:
	global_position = point
	velocity = Vector3.ZERO
	stop_moving()
	if click_reference:
		click_reference.hide()
	# La camara salta con el jugador en vez de cruzar el mapa.
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera and camera.get_parent().has_method("snap"):
		camera.get_parent().snap()
