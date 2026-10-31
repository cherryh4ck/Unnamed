extends StaticBody3D

## Barril o cajon que se rompe a golpes. Va en el cuerpo de colision de la
## pieza (scripts/world/prop.gd); al romperse se va la pieza entera.
## - Clic: el jugador camina hasta el (esta en el grupo "npcs", como los
##   cofres) y le pega con el arma.
## - Tambien se rompe si el jugador lo alcanza pegandole a otra cosa (un golpe
##   cuerpo a cuerpo que pasa por al lado).
## Suelta a veces oro, una pocion o, muy de vez en cuando, equipo. Queda
## anotado en save_game como los cofres abiertos: no vuelve en la partida.

const SOUNDS := ["res://sounds/interact/break/madera_1.ogg", "res://sounds/interact/break/madera_2.ogg",
	"res://sounds/interact/break/madera_3.ogg", "res://sounds/interact/break/madera_4.ogg", "res://sounds/interact/break/madera_5.ogg"]
const PLANK_SOUNDS := ["res://sounds/interact/break/tabla_1.ogg", "res://sounds/interact/break/tabla_2.ogg", "res://sounds/interact/break/tabla_3.ogg"]
const WOOD := Color(0.42, 0.29, 0.17)
## Un golpe cuerpo a cuerpo rompe lo que este a esta distancia del jugador y
## mas o menos adelante suyo.
const SWING_REACH: float = 300.0
## Probabilidades de lo que suelta.
const GOLD_CHANCE: float = 0.45
const POTION_CHANCE: float = 0.12
const ITEM_CHANCE: float = 0.04

## Nivel del botin (el de la zona donde esta).
@export var level: int = 1
@export var display_name: String = "Barril"

## Lo miran los golpes del jugador (combat.gd no le pega a lo que ya murio).
var dead: bool = false


func _ready() -> void:
	if save_game.is_collected(self):
		get_parent().queue_free.call_deferred()
		return
	add_to_group("npcs")
	add_to_group("breakables")
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_node("Combat"):
		player.get_node("Combat").attack_started.connect(_on_player_attack)


func get_display_name() -> String:
	return display_name


## Clic: le pega con el arma (con ballesta o sin poder atacar todavia, lo
## patea igual).
func interact() -> void:
	if dead:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var combat: Node = player.get_node_or_null("Combat") if player else null
	var delay: float = 0.2
	if combat and not player_stats.is_ranged() and combat.try_attack(self):
		# El golpe lo rompe con take_hit; esto es por si quedo apenas lejos.
		delay = 0.6
	await get_tree().create_timer(delay, false).timeout
	break_apart()


## Golpe del jugador (lo llama combat.gd como a un enemigo).
func take_hit(_hit: Dictionary) -> void:
	break_apart()


# Pegandole a otra cosa cerca: si queda al alcance y adelante, se rompe.
func _on_player_attack(interval: float) -> void:
	if dead or player_stats.is_ranged():
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var offset: Vector3 = global_position - player.global_position
	offset.y = 0.0
	if offset.length() > SWING_REACH:
		return
	if offset.length() > 80.0 and offset.normalized().dot(player.global_transform.basis.z) < 0.3:
		return
	await get_tree().create_timer(interval * 0.45, false).timeout
	break_apart()


func break_apart() -> void:
	if dead:
		return
	dead = true
	save_game.mark_collected(self)
	remove_from_group("npcs")
	remove_from_group("breakables")
	var piece: Node3D = get_parent()
	var center: Vector3 = piece.world_bounds.get_center() if piece.get("world_bounds") != null else global_position + Vector3.UP * 80.0
	sfx_at(SOUNDS.pick_random(), center, -2.0)
	sfx_at(PLANK_SOUNDS.pick_random(), center, -6.0)
	_splinters(center)
	Effects.dust_puff(piece.get_parent(), Vector3(center.x, piece.global_position.y, center.z), 110.0)
	for drop in _roll_drops():
		Loot.spawn_pickup(piece.get_parent(), Vector3(center.x, piece.global_position.y, center.z), drop.item, drop.quantity)
	piece.queue_free()


func _roll_drops() -> Array:
	var drops: Array = []
	var gold_mult: float = difficulty.get_value("gold")
	if randf() < GOLD_CHANCE:
		drops.append({"item": Loot.GOLD, "quantity": maxi(1, roundi(randi_range(3, 12) * (1.0 + 0.2 * (level - 1)) * gold_mult))})
	if randf() < POTION_CHANCE:
		drops.append({"item": Loot.POTION, "quantity": 1})
	if randf() < ITEM_CHANCE:
		drops.append({"item": Loot.generate_item(level, -1, difficulty.get_value("magic_find")), "quantity": 1})
	return drops


# Astillas de madera que saltan y caen.
func _splinters(center: Vector3) -> void:
	var chips := CPUParticles3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10, 4, 34)
	var material := StandardMaterial3D.new()
	material.albedo_color = WOOD
	material.vertex_color_use_as_albedo = true
	box.material = material
	chips.mesh = box
	chips.amount = 22
	chips.lifetime = 1.3
	chips.one_shot = true
	chips.explosiveness = 0.95
	chips.local_coords = false
	chips.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	chips.emission_sphere_radius = 40.0
	chips.direction = Vector3.UP
	chips.spread = 70.0
	chips.initial_velocity_min = 260.0
	chips.initial_velocity_max = 520.0
	chips.gravity = Vector3(0, -1800.0, 0)
	chips.angular_velocity_min = -720.0
	chips.angular_velocity_max = 720.0
	chips.particle_flag_rotate_y = true
	chips.scale_amount_min = 0.6
	chips.scale_amount_max = 1.4
	chips.color = Color.WHITE
	chips.color_ramp = Effects.ramp([Color(1, 1, 1, 1), Color(0.8, 0.8, 0.8, 1), Color(0.6, 0.6, 0.6, 1)])
	var scene: Node = get_tree().current_scene
	scene.add_child(chips)
	chips.global_position = center
	chips.emitting = true
	get_tree().create_timer(2.0, false).timeout.connect(chips.queue_free)


func sfx_at(path: String, position: Vector3, volume_db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer3D.new()
	player.bus = &"Efectos"
	player.stream = load(path)
	player.volume_db = volume_db
	player.unit_size = sfx.UNIT_SIZE_3D
	player.max_distance = sfx.MAX_DISTANCE_3D
	player.pitch_scale = randf_range(0.9, 1.1)
	get_tree().current_scene.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()
