extends CharacterBody3D

## Enemigo generico. El tipo (modelo, animaciones, stats) sale de un EnemyData;
## el nivel escala los stats. Estados:
## SPAWNING: animacion de aparicion (salir del suelo); no se mueve ni ataca.
## IDLE/WANDER: da vueltas cerca de donde aparecio.
## CHASE/ATTACK: persigue y pega al jugador cuando lo ve o cuando recibe un golpe.
## Lo sigue mientras no se le escape lejos; si lo pierde, se queda por ahi
## (no vuelve corriendo a curarse). Fuera de combate se cura de a poco.
## Se mueve por la navegacion y esquiva a los otros enemigos (avoidance);
## cerca del jugador va derecho hacia su lado, asi entre varios lo rodean.
## Los que crea una zona (zona_spawn.gd) desaparecen cuando el jugador se aleja.

signal died

enum State { SPAWNING, IDLE, WANDER, CHASE, ATTACK, DEAD }

const DEFAULT_DATA: EnemyData = preload("res://enemies/types/esqueleto.tres")
const BOLT := preload("res://scripts/skills/bolt.gd")
const GRAVITY: float = 2000.0
const WANDER_RADIUS: float = 350.0
## Si el jugador se le escapa mas lejos que esto durante LOSE_TIME segundos,
## deja de perseguirlo.
const LOSE_RANGE: float = 2600.0
const LOSE_TIME: float = 3.0
## Fuera de combate, despues de REGEN_DELAY segundos, recupera esta parte de
## la vida por segundo.
const REGEN_DELAY: float = 10.0
const REGEN_RATE: float = 0.02
## Mas cerca que esto del jugador va derecho en vez de seguir el camino.
const DIRECT_RANGE: float = 550.0
## Cuantas veces su velocidad gana o pierde por segundo (arranque y frenada).
const ACCELERATION: float = 8.0
## Si en este tiempo casi no avanzo queriendo moverse, esta trabado.
const STUCK_CHECK: float = 0.6
## Capa de fisica de los enemigos: chocan con el mundo y el jugador, pero no
## entre ellos (se esquivan con la navegacion en vez de empujarse).
const ENEMY_LAYER: int = 1 << 4
## Radio en el que un enemigo golpeado alerta a sus compañeros.
const PACK_ALERT_RANGE: float = 700.0
const REPATH_DISTANCE: float = 40.0
const CORPSE_TIME: float = 5.0
## Distancia al jugador a partir de la cual desaparece (si no esta peleando
## y la camara no lo ve). Cada cuanto se revisa, en segundos.
const DESPAWN_RANGE: float = 4500.0
const DESPAWN_CHECK: float = 1.0

@export var data: EnemyData
@export var level: int = 1
## Lo pone la zona que lo crea: se va solo cuando el jugador se aleja.
var despawns: bool = false

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var model_root: Node3D = $Model
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var player: Node3D
var state: State = State.IDLE
var dead: bool = false
var max_health: float
var current_health: float
var home_position: Vector3

var _state_timer: float = 0.0
var _attack_timer: float = 0.0
var _last_nav_target: Vector3 = Vector3.INF
var _anim_player: AnimationPlayer
var _walk_step: int = 0
var _attack_index: int = 0
var _attacking: bool = false
var _meshes: Array[MeshInstance3D] = []
var _overlay: StandardMaterial3D
var _highlighted: bool = false
var _flash_time: float = 0.0
## Veneno y quemadura que tiene encima.
var status := StatusEffects.new()
var _burn_fx: CPUParticles3D
var _poison_fx: CPUParticles3D
var _status_pulse: float = 0.0
## Daño por tiempo acumulado que todavia no llego a 1 (para el numero flotante).
var _dot_shown: Dictionary = {}
var _despawn_timer: float = DESPAWN_CHECK
## Segundos que lleva el jugador fuera de LOSE_RANGE mientras lo persigue.
var _lose_timer: float = 0.0
## Segundos desde la ultima vez que peleo (para curarse).
var _calm_time: float = REGEN_DELAY
## Destrabarse: paso al costado y un rato siguiendo solo el camino.
var _stuck_timer: float = 0.0
var _stuck_from: Vector3
var _sidestep_timer: float = 0.0
var _sidestep_dir := Vector3.ZERO
var _path_only_timer: float = 0.0
## Lugar alrededor del jugador al que va antes de ponerse a pegar, y cuanto
## lleva buscandolo ya en rango (no da vueltas para siempre).
var _slot := Vector3.INF
var _slot_time: float = 0.0


func _ready() -> void:
	if data == null:
		data = DEFAULT_DATA
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	home_position = global_position

	# La dificultad suma niveles y multiplica la vida (ver scripts/system/difficulty.gd).
	level += int(difficulty.get_value("enemy_levels"))
	max_health = data.max_health * _level_scale(0.3) * difficulty.get_value("enemy_health")
	current_health = max_health
	_setup_collision()
	_setup_navigation()
	_setup_model()
	if not _start_spawn_animation():
		_enter_idle()


# Escalado por nivel: +X% por cada nivel arriba de 1.
func _level_scale(per_level: float) -> float:
	return 1.0 + per_level * (level - 1)


func get_display_name() -> String:
	return "%s (nivel %d)" % [data.name, level]


func get_xp_reward() -> int:
	return roundi(data.xp_reward * _level_scale(0.25) * difficulty.get_value("xp"))


func _setup_collision() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = data.collision_radius
	capsule.height = 360.0 * data.model_scale
	collision_shape.shape = capsule
	collision_shape.position.y = capsule.height / 2.0


# Avoidance: cada enemigo es un circulo que los demas esquivan.
func _setup_navigation() -> void:
	collision_layer = ENEMY_LAYER
	collision_mask = 1
	nav_agent.radius = data.collision_radius * data.model_scale
	nav_agent.max_speed = data.speed * 1.3
	nav_agent.neighbor_distance = 1000.0
	nav_agent.max_neighbors = 10
	nav_agent.time_horizon_agents = 1.0
	nav_agent.avoidance_enabled = true
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	_stuck_from = global_position


func _setup_model() -> void:
	if data.model == null:
		return
	var model: Node3D = data.model.instantiate()
	model_root.add_child(model)
	model_root.scale = Vector3.ONE * data.model_scale
	model_root.position.y = data.model_offset_y * data.model_scale

	# Overlay aditivo por instancia: negro = sin efecto; se usa para el
	# brillo al pasar el mouse y el destello rojo al recibir un golpe.
	_overlay = StandardMaterial3D.new()
	_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.albedo_color = Color.BLACK
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mesh)
		mesh.material_overlay = _overlay
		if data.tint != Color.WHITE:
			_apply_tint(mesh)

	_anim_player = model.find_child("AnimationPlayer", true, false)
	if _anim_player:
		_set_loop(data.idle_animation, Animation.LOOP_LINEAR)
		for anim_name in data.walk_animations + data.attack_animations + [data.death_animation]:
			_set_loop(anim_name, Animation.LOOP_NONE)
		_anim_player.animation_finished.connect(_on_animation_finished)


func _start_spawn_animation() -> bool:
	if _anim_player == null or not _anim_player.has_animation(data.spawn_animation):
		return false
	state = State.SPAWNING
	_set_loop(data.spawn_animation, Animation.LOOP_NONE)
	_anim_player.play(data.spawn_animation, 0.0, data.spawn_animation_speed)
	return true


func _apply_tint(mesh: MeshInstance3D) -> void:
	for i in mesh.get_surface_override_material_count():
		var base: Material = mesh.get_active_material(i)
		if base is BaseMaterial3D:
			var tinted: BaseMaterial3D = base.duplicate()
			tinted.albedo_color = tinted.albedo_color * data.tint
			mesh.set_surface_override_material(i, tinted)


func _set_loop(anim_name: String, mode: Animation.LoopMode) -> void:
	if _anim_player and _anim_player.has_animation(anim_name):
		_anim_player.get_animation(anim_name).loop_mode = mode


func _play(anim_name: String, speed_scale: float = 1.0) -> void:
	if _anim_player and _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name, 0.1, speed_scale)


# --- Bucle principal -------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		return
	if despawns:
		_despawn_timer -= delta
		if _despawn_timer <= 0.0:
			_despawn_timer = DESPAWN_CHECK
			if _far_from_player():
				queue_free()
				return
	_update_flash(delta)
	_update_status(delta)
	if dead:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_state_timer -= delta
	_calm_time += delta

	var player_alive: bool = is_instance_valid(player) and not player_stats.dead
	var to_player: Vector3 = (player.global_position - global_position) if player_alive else Vector3.ZERO
	to_player.y = 0.0
	var dist: float = to_player.length()

	var move_dir := Vector3.ZERO
	var move_speed: float = data.speed

	match state:
		State.SPAWNING:
			pass
		State.IDLE:
			if player_alive and dist <= data.detection_range:
				_enter_chase()
			elif _state_timer <= 0.0:
				_enter_wander()
		State.WANDER:
			if player_alive and dist <= data.detection_range:
				_enter_chase()
			elif _state_timer <= 0.0 or nav_agent.is_navigation_finished():
				_enter_idle()
			else:
				move_dir = _nav_direction()
				move_speed = data.speed * 0.4
		State.CHASE:
			_calm_time = 0.0
			if not player_alive or _lost_player(dist, delta):
				_give_up()
			elif dist <= data.attack_range and _at_slot(delta):
				state = State.ATTACK
				_slot_time = 0.0
			else:
				move_dir = _chase_direction(to_player, dist, delta)
		State.ATTACK:
			_calm_time = 0.0
			if not player_alive:
				_give_up()
			elif dist > LOSE_RANGE or (dist > data.attack_range * 1.15 and not _attacking):
				_attacking = false
				state = State.CHASE
			else:
				_face(to_player, delta)
				if _attack_timer <= 0.0:
					_attack()

	if _calm_time >= REGEN_DELAY and current_health < max_health and state != State.SPAWNING:
		heal(max_health * REGEN_RATE * delta)
	_check_stuck(move_dir != Vector3.ZERO, delta)
	_move(move_dir * move_speed, delta)
	_update_walk_animation(move_dir != Vector3.ZERO)


# La velocidad deseada pasa por el avoidance; el resultado llega en
# _on_velocity_computed, que es el que mueve el cuerpo.
func _move(desired: Vector3, delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() > data.speed * 0.3:
		_face(flat, delta)
	elif desired != Vector3.ZERO:
		_face(desired, delta)
	nav_agent.velocity = Vector3(desired.x, 0.0, desired.z)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if dead:
		return
	var goal := Vector3(safe_velocity.x, 0.0, safe_velocity.z)
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(goal, data.speed * ACCELERATION * get_physics_process_delta_time())
	velocity.x = flat.x
	velocity.z = flat.z
	move_and_slide()


# Lejos sigue el camino de la navegacion; cerca va derecho a su lugar
# alrededor del jugador (ver _surround_goal).
func _chase_direction(to_player: Vector3, dist: float, delta: float) -> Vector3:
	var goal: Vector3 = _surround_goal(to_player)
	_slot = goal
	if _sidestep_timer > 0.0:
		_sidestep_timer -= delta
		return _sidestep_dir
	_path_only_timer -= delta
	if dist < DIRECT_RANGE and _path_only_timer <= 0.0:
		var direct: Vector3 = goal - global_position
		direct.y = 0.0
		return direct.normalized() if direct.length() > 1.0 else Vector3.ZERO
	_set_nav_target(goal)
	return _nav_direction()


# Ya en rango: pega si llego a su lugar o si hace rato que lo busca.
func _at_slot(delta: float) -> bool:
	_slot_time += delta
	if _slot == Vector3.INF or _slot_time > 1.2:
		return true
	return Vector2(_slot.x - global_position.x, _slot.z - global_position.z).length() < 90.0


# Lugar alrededor del jugador donde ponerse a pegar: arranca por el lado del
# que viene y se corre si ahi ya esta pegando otro. Asi entre varios lo
# rodean en vez de hacer fila.
func _surround_goal(to_player: Vector3) -> Vector3:
	var ring: float = data.attack_range * 0.75
	var base_angle: float = atan2(-to_player.x, -to_player.z)
	var spacing: float = 2.0 * asin(clampf(nav_agent.radius * 1.2 / ring, 0.05, 0.95))
	var taken: Array[float] = []
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or other.state != State.ATTACK:
			continue
		var offset: Vector3 = other.global_position - player.global_position
		if offset.length() < data.attack_range * 2.0:
			taken.append(atan2(offset.x, offset.z))
	# El hueco libre mas cercano: prueba alternando a un lado y al otro.
	var angle: float = base_angle
	var step: float = spacing * 0.5
	for k in ceili(TAU / step):
		var candidate: float = base_angle + step * ceili(k / 2.0) * (1.0 if k % 2 == 1 else -1.0)
		var free: bool = true
		for other_angle in taken:
			if absf(wrapf(candidate - other_angle, -PI, PI)) < spacing:
				free = false
				break
		if free:
			angle = candidate
			break
	return player.global_position + Vector3(sin(angle), 0.0, cos(angle)) * ring


# Si casi no avanzo queriendo moverse: un paso al costado y un rato siguiendo
# solo el camino (por si iba derecho contra una roca o una cerca).
func _check_stuck(wants_move: bool, delta: float) -> void:
	if not wants_move or _sidestep_timer > 0.0:
		_stuck_timer = 0.0
		_stuck_from = global_position
		return
	_stuck_timer += delta
	if _stuck_timer < STUCK_CHECK:
		return
	var moved: float = Vector2(global_position.x - _stuck_from.x, global_position.z - _stuck_from.z).length()
	if moved < data.speed * STUCK_CHECK * 0.2:
		var forward := Vector3(velocity.x, 0.0, velocity.z)
		if forward.length() < 1.0:
			forward = global_transform.basis.z
		_sidestep_dir = forward.normalized().rotated(Vector3.UP, PI / 2.0 * (1.0 if randf() < 0.5 else -1.0))
		_sidestep_timer = 0.45
		_path_only_timer = 2.0
		_last_nav_target = Vector3.INF
	_stuck_timer = 0.0
	_stuck_from = global_position


func _lost_player(dist: float, delta: float) -> bool:
	if dist <= LOSE_RANGE:
		_lose_timer = 0.0
		return false
	_lose_timer += delta
	return _lose_timer >= LOSE_TIME


# Lo perdio: se queda dando vueltas por donde esta.
func _give_up() -> void:
	home_position = global_position
	_attacking = false
	_lose_timer = 0.0
	_last_nav_target = Vector3.INF
	_enter_idle()


# Lejos del jugador, sin pelear y fuera de camara: ya no hace falta.
func _far_from_player() -> bool:
	if state == State.CHASE or state == State.ATTACK or not is_instance_valid(player):
		return false
	if global_position.distance_to(player.global_position) < DESPAWN_RANGE:
		return false
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera == null or not camera.is_position_in_frustum(global_position + Vector3.UP * 200.0)


func _enter_idle() -> void:
	state = State.IDLE
	_state_timer = randf_range(2.0, 5.0)


func _enter_wander() -> void:
	state = State.WANDER
	_state_timer = 6.0
	var angle: float = randf() * TAU
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(100.0, WANDER_RADIUS)
	# Sobre el piso caminable, asi no se queda empujando contra algo.
	_set_nav_target(NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, home_position + offset))


func _enter_chase() -> void:
	if state == State.CHASE or state == State.ATTACK or state == State.DEAD:
		return
	_lose_timer = 0.0
	if not data.aggro_sound.is_empty():
		sfx.play_at(data.aggro_sound, global_position, -4.0)
	state = State.CHASE
	_last_nav_target = Vector3.INF


func _set_nav_target(target: Vector3) -> void:
	if target.distance_to(_last_nav_target) > REPATH_DISTANCE:
		_last_nav_target = target
		nav_agent.target_position = target


func _nav_direction() -> Vector3:
	if nav_agent.is_navigation_finished():
		return Vector3.ZERO
	var dir: Vector3 = nav_agent.get_next_path_position() - global_position
	dir.y = 0.0
	return dir.normalized() if dir.length() > 1.0 else Vector3.ZERO


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 10.0 * delta)


# --- Ataque ----------------------------------------------------------------

func _attack() -> void:
	_attack_timer = data.attack_cooldown
	_attacking = true
	var hit_delay: float = 0.4
	if not data.attack_animations.is_empty():
		var anim_name: String = data.attack_animations[_attack_index]
		_attack_index = (_attack_index + 1) % data.attack_animations.size()
		if _anim_player and _anim_player.has_animation(anim_name):
			# Si la animacion es mas larga que el cooldown, se acelera.
			var length: float = _anim_player.get_animation(anim_name).length
			var speed_scale: float = maxf(1.0, length / data.attack_cooldown)
			_play(anim_name, speed_scale)
			_anim_player.seek(0.0, true)
			hit_delay = length * 0.45 / speed_scale
	if not data.attack_sound.is_empty():
		sfx.play_at(data.attack_sound, global_position, -3.0)

	await get_tree().create_timer(hit_delay, false).timeout
	if dead or not is_instance_valid(player) or player_stats.dead:
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var damage: float = randi_range(data.min_damage, data.max_damage) * _level_scale(0.2) * difficulty.get_value("enemy_damage")
	var parts: Dictionary = Damage.split(damage, data.attack_damage_type, data.attack_conversion)
	if data.shoots:
		_shoot(to_player.normalized(), parts)
	elif to_player.length() <= data.attack_range * 1.3 and player.has_method("take_hit"):
		player.take_hit(parts)


# Flecha hacia donde esta el jugador ahora: si se mueve, la esquiva.
func _shoot(direction: Vector3, parts: Dictionary) -> void:
	var bolt: Node3D = BOLT.new()
	bolt.direction = direction
	bolt.speed = data.projectile_speed
	bolt.max_range = data.attack_range + 600.0
	bolt.hit = {"parts": parts}
	bolt.hits_player = true
	Effects.add_at(get_parent(), bolt, global_position + Vector3.UP * 230.0 * data.model_scale + direction * 60.0)
	sfx.play_at("bow_shoot", global_position, -4.0)


# --- Animaciones de movimiento --------------------------------------------

func _update_walk_animation(moving: bool) -> void:
	if _anim_player == null or _attacking or state == State.SPAWNING:
		return
	var current: String = _anim_player.current_animation
	if moving and not current in data.walk_animations:
		_walk_step = 0
		if not data.walk_animations.is_empty():
			_play(data.walk_animations[0], data.walk_animation_speed)
	elif not moving and current != data.idle_animation:
		_play(data.idle_animation)


func _on_animation_finished(anim_name: StringName) -> void:
	if dead:
		return
	if state == State.SPAWNING and anim_name == data.spawn_animation:
		_enter_idle()
		_play(data.idle_animation)
	elif anim_name in data.attack_animations:
		_attacking = false
		_play(data.idle_animation)
	elif anim_name in data.walk_animations and not data.walk_animations.is_empty():
		_walk_step = (_walk_step + 1) % data.walk_animations.size()
		_play(data.walk_animations[_walk_step], data.walk_animation_speed)


# --- Daño, resaltado y muerte ---------------------------------------------

## Recibe un golpe: {parts: {Damage.Type: cantidad}, crit}. La defensa y las
## resistencias del tipo de enemigo reducen cada parte; el veneno y parte del
## fuego quedan pegando por tiempo.
func take_hit(hit: Dictionary) -> void:
	if dead:
		return
	var result: Dictionary = Damage.mitigate(hit.parts, data.defense, data.get_resistances())
	var was_poisoned: bool = status.is_poisoned()
	status.add_poison(result.poison)
	status.add_burn(result.burn)

	var head := global_position + Vector3.UP * 420.0 * data.model_scale
	if result.direct > 0.0:
		var amount: float = maxf(1.0, result.direct)
		var color: Color = Damage.COLORS[result.type]
		if hit.get("crit", false):
			var crit_color: Color = Color(1.0, 0.85, 0.2) if result.type == Damage.Type.PHYSICAL else color.lightened(0.25)
			floating_text.spawn(head, "%d!" % roundi(amount), crit_color, 30, 1.6)
		else:
			floating_text.spawn(head, str(roundi(amount)), color, 22)
		current_health = maxf(current_health - amount, 0.0)
		_flash_time = 0.12
	elif result.poison > 0.0 and not was_poisoned:
		floating_text.spawn(head, "Envenenado", Damage.COLORS[Damage.Type.POISON], 18)

	if current_health <= 0.0:
		_die()
		return
	_calm_time = 0.0
	_enter_chase()
	_alert_pack()


## Golpe fisico simple (compatibilidad con codigo que todavia pasa un numero).
func take_damage(amount: float, crit: bool = false) -> void:
	take_hit({"parts": {Damage.Type.PHYSICAL: amount}, "crit": crit})


# Veneno y quemadura: restan vida de a poco y se ven en el modelo
# (tinte verde pulsante y llamitas).
func _update_status(delta: float) -> void:
	var ticks: Dictionary = status.tick(delta)
	for type in ticks:
		current_health = maxf(current_health - ticks[type], 0.0)
		_dot_shown[type] = _dot_shown.get(type, 0.0) + ticks[type]
		if _dot_shown[type] >= 1.0:
			var head := global_position + Vector3.UP * 380.0 * data.model_scale
			floating_text.spawn(head, str(floori(_dot_shown[type])), Damage.COLORS[type], 16)
			_dot_shown[type] -= floorf(_dot_shown[type])
	if current_health <= 0.0 and not ticks.is_empty():
		_die()
		return

	if status.is_burning() and _burn_fx == null:
		_burn_fx = Effects.burning(self, 160.0 * data.model_scale, data.collision_radius)
	if _burn_fx:
		_burn_fx.emitting = status.is_burning()
	if status.is_poisoned() and _poison_fx == null:
		_poison_fx = Effects.poisoned(self, 200.0 * data.model_scale, data.collision_radius)
	if _poison_fx:
		_poison_fx.emitting = status.is_poisoned()
	if status.is_poisoned():
		_status_pulse += delta * 5.0
		_refresh_overlay()
	elif _status_pulse > 0.0:
		_status_pulse = 0.0
		_refresh_overlay()


func heal(amount: float) -> void:
	current_health = minf(current_health + amount, max_health)


# Cuando le pegan a uno, los cercanos que esten tranquilos tambien atacan.
func _alert_pack() -> void:
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self and not other.dead and other.state in [State.IDLE, State.WANDER]:
			if other.global_position.distance_to(global_position) <= PACK_ALERT_RANGE:
				other._enter_chase()


func _drop_loot() -> void:
	for drop in Loot.roll_enemy_drops(data, level, difficulty.get_value("gold"), difficulty.get_value("magic_find")):
		Loot.spawn_pickup(get_parent(), global_position, drop.item, drop.quantity)


func set_highlighted(on: bool) -> void:
	_highlighted = on
	_refresh_overlay()


func _update_flash(delta: float) -> void:
	if _flash_time <= 0.0:
		return
	_flash_time -= delta
	_refresh_overlay()


func _refresh_overlay() -> void:
	if _overlay == null:
		return
	if _flash_time > 0.0:
		_overlay.albedo_color = Color(0.45, 0.06, 0.03)
	elif status.is_poisoned():
		var glow: float = 0.5 + 0.5 * sin(_status_pulse)
		_overlay.albedo_color = Color(0.02, 0.1 + 0.12 * glow, 0.0) + (Color(0.14, 0.12, 0.1) if _highlighted else Color.BLACK)
	elif _highlighted:
		_overlay.albedo_color = Color(0.14, 0.12, 0.1)
	else:
		_overlay.albedo_color = Color.BLACK


func _die() -> void:
	dead = true
	state = State.DEAD
	if not data.death_sound.is_empty():
		sfx.play_at(data.death_sound, global_position)
	velocity = Vector3.ZERO
	nav_agent.avoidance_enabled = false
	collision_layer = 0
	collision_mask = 0
	remove_from_group("enemies")
	_highlighted = false
	_flash_time = 0.0
	status.clear()
	if _burn_fx:
		_burn_fx.emitting = false
	if _poison_fx:
		_poison_fx.emitting = false
	_refresh_overlay()
	_attacking = false
	var xp: int = get_xp_reward()
	player_stats.add_xp(xp)
	floating_text.spawn(global_position + Vector3.UP * 300.0, "+%d exp" % xp, Color(0.75, 0.65, 1.0), 18)
	_drop_loot.call_deferred()
	if _anim_player and _anim_player.has_animation(data.death_animation):
		if data.death_reversed:
			_anim_player.play_backwards(data.death_animation, 0.1)
		else:
			_anim_player.play(data.death_animation, 0.1)
	died.emit()

	# El cuerpo queda unos segundos y despues se hunde en el piso.
	await get_tree().create_timer(CORPSE_TIME, false).timeout
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 300.0, 1.5)
	tween.tween_callback(queue_free)
