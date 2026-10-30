extends Node

## Autoload con los datos del personaje: vida, atributos y stats derivados.
## El combate, el HUD y la pantalla de personaje leen todos de aca,
## igual que el inventario usa inventory_data.

signal health_changed(current: float, maximum: float)
signal xp_changed(current: int, needed: int)
signal leveled_up(new_level: int)
signal stats_changed
signal buffs_changed
signal gold_changed(amount: int)
signal potion_used(amount: float)
signal died
signal respawned
## Daño de veneno o quemadura que acaba de restar (para el texto flotante).
signal dot_damaged(amount: float, type: int)

const BASE_HEALTH: float = 80.0
const HEALTH_PER_VITALITY: float = 4.0
const HEALTH_PER_LEVEL: float = 10.0
const REGEN_PER_VITALITY: float = 0.05  # vida por segundo

const UNARMED_MIN_DAMAGE: int = 2
const UNARMED_MAX_DAMAGE: int = 4
const UNARMED_ATTACK_SPEED: float = 1.2
const BASE_CRIT_CHANCE: float = 5.0
const CRIT_MULTIPLIER: float = 2.0
const ATTRIBUTE_POINTS_PER_LEVEL: int = 5
## Una pocion cura este porcentaje de la vida maxima mas una cantidad fija.
const POTION_HEAL_PERCENT: float = 0.35
const POTION_HEAL_FLAT: float = 20.0
const POTION_COOLDOWN: float = 0.6
## Cada punto de Concentracion sube el daño magico, de veneno y de fuego.
const ELEMENTAL_PER_CONCENTRATION: float = 0.015

var level: int = 1
var xp: int = 0
var unspent_points: int = 0
var gold: int = 0
var attributes: Dictionary = {
	"fuerza": 10,        # +2% daño por punto
	"destreza": 10,      # +1% velocidad de ataque y +0.2% critico por punto
	"vitalidad": 10,     # +4 vida maxima, +0.5 defensa y regeneracion
	"concentracion": 10, # acelera la recarga y sube el daño elemental
}
var health: float = 0.0
var dead: bool = false
## Mejoras temporales activas: id -> {name, icon, duration, time_left,
## damage_mult, attack_speed_mult, defense, resist}.
var buffs: Dictionary = {}
## Veneno y quemadura que tiene encima el personaje.
var status := StatusEffects.new()
var _potion_timer: float = 0.0
var _base_attributes: Dictionary


func _ready() -> void:
	_base_attributes = attributes.duplicate()
	health = get_max_health()
	inventory_data.equipment_changed.connect(_on_equipment_changed)


## Vuelve al personaje recien creado (partida nueva).
func reset() -> void:
	level = 1
	xp = 0
	unspent_points = 0
	gold = 0
	attributes = _base_attributes.duplicate()
	buffs.clear()
	status.clear()
	dead = false
	_potion_timer = 0.0
	health = get_max_health()


func _process(delta: float) -> void:
	_tick_buffs(delta)
	_potion_timer = maxf(_potion_timer - delta, 0.0)
	if dead:
		return
	_tick_status(delta)
	# Envenenado no se regenera vida.
	if dead or health >= get_max_health() or status.is_poisoned():
		return
	heal(get_health_regen() * delta)


func _tick_status(delta: float) -> void:
	var ticks: Dictionary = status.tick(delta)
	for type in ticks:
		_lose_health(ticks[type])
		dot_damaged.emit(ticks[type], type)


# --- Oro y pociones --------------------------------------------------------

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func count_potions() -> int:
	var total: int = 0
	for slot in inventory_data.slots:
		if slot and slot.item_data and slot.item_data.item_type == Itemdata.ItemType.POTION:
			total += slot.quantity
	return total


## Bebe una pocion del inventario. Devuelve un texto con el motivo si no pudo
## (vacio si la bebio).
func use_potion() -> String:
	if dead:
		return "Estás muerto"
	if _potion_timer > 0.0:
		return ""
	if health >= get_max_health():
		return "Vida al máximo"
	for slot in inventory_data.slots:
		if slot and slot.item_data and slot.item_data.item_type == Itemdata.ItemType.POTION:
			inventory_data.remove_item(slot.item_data, 1)
			var amount: float = minf(get_max_health() * POTION_HEAL_PERCENT + POTION_HEAL_FLAT, get_max_health() - health)
			heal(amount)
			_potion_timer = POTION_COOLDOWN
			potion_used.emit(amount)
			return ""
	return "No tenés pociones"


# --- Mejoras temporales ----------------------------------------------------

func add_buff(id: String, buff: Dictionary) -> void:
	buff["time_left"] = buff.get("duration", 5.0)
	buffs[id] = buff
	buffs_changed.emit()
	stats_changed.emit()


func _tick_buffs(delta: float) -> void:
	if buffs.is_empty():
		return
	var expired: Array = []
	for id in buffs:
		buffs[id].time_left -= delta
		if buffs[id].time_left <= 0.0:
			expired.append(id)
	if expired.is_empty():
		return
	for id in expired:
		buffs.erase(id)
	buffs_changed.emit()
	stats_changed.emit()


func _buff_product(key: String) -> float:
	var result: float = 1.0
	for buff in buffs.values():
		result *= buff.get(key, 1.0)
	return result


func _buff_sum(key: String) -> float:
	var result: float = 0.0
	for buff in buffs.values():
		result += buff.get(key, 0.0)
	return result


# --- Experiencia y atributos ----------------------------------------------

func xp_for_next_level() -> int:
	return roundi(80.0 * pow(level, 1.6))


func add_xp(amount: int) -> void:
	if dead or amount <= 0:
		return
	xp += amount
	while xp >= xp_for_next_level():
		xp -= xp_for_next_level()
		level += 1
		unspent_points += ATTRIBUTE_POINTS_PER_LEVEL
		# Subir de nivel cura por completo.
		health = get_max_health()
		health_changed.emit(health, get_max_health())
		leveled_up.emit(level)
		stats_changed.emit()
	xp_changed.emit(xp, xp_for_next_level())


func spend_point(attribute: String) -> bool:
	if unspent_points <= 0 or not attributes.has(attribute):
		return false
	var old_max: float = get_max_health()
	attributes[attribute] += 1
	unspent_points -= 1
	# La vida que se gana al subir vitalidad se suma tambien a la actual.
	health += get_max_health() - old_max
	health_changed.emit(health, get_max_health())
	stats_changed.emit()
	return true


# --- Stats derivados -------------------------------------------------------

## Atributo base + lo que suma el equipo.
func get_attribute(key: String) -> int:
	return attributes[key] + roundi(get_equipment_bonus(key))


func get_equipment_bonus(key: String) -> float:
	var total: float = 0.0
	var equipped: Array = []
	for equip_index in [inventory_data.MELEE_EQUIP, inventory_data.SPECIAL_EQUIP]:
		var item: Itemdata = inventory_data.get_equipped(equip_index)
		if item:
			total += item.get_bonus(key)
			equipped.append(item)
	return total + ItemSets.active_bonus(key, equipped)


func get_max_health() -> float:
	return BASE_HEALTH + get_attribute("vitalidad") * HEALTH_PER_VITALITY 			+ (level - 1) * HEALTH_PER_LEVEL + get_equipment_bonus("vida")


func get_health_regen() -> float:
	return get_attribute("vitalidad") * REGEN_PER_VITALITY + get_equipment_bonus("regeneracion")


## Arma con la que se ataca: si hay una ballesta equipada tiene prioridad
## (ataque a distancia); si no, el arma cuerpo a cuerpo.
func get_weapon() -> Itemdata:
	var special: Itemdata = inventory_data.get_equipped(inventory_data.SPECIAL_EQUIP)
	if special and special.is_ranged():
		return special
	var weapon: Itemdata = inventory_data.get_equipped(inventory_data.MELEE_EQUIP)
	return weapon if weapon and weapon.has_damage() else null


func is_ranged() -> bool:
	var weapon: Itemdata = get_weapon()
	return weapon != null and weapon.is_ranged()


func get_damage_multiplier() -> float:
	return (1.0 + get_attribute("fuerza") * 0.02 + get_equipment_bonus("daño_pct") / 100.0) 			* _buff_product("damage_mult")


## Multiplicador del daño magico, de veneno y de fuego (Concentracion en vez de Fuerza).
func get_elemental_multiplier() -> float:
	return (1.0 + get_attribute("concentracion") * ELEMENTAL_PER_CONCENTRATION 			+ get_equipment_bonus("daño_pct") / 100.0) * _buff_product("damage_mult")


## Daño extra de un tipo que suma el equipo en cada golpe (sin la variacion de la tirada).
func get_elemental_damage(type: int) -> float:
	if type == Damage.Type.PHYSICAL:
		return 0.0
	return get_equipment_bonus(Damage.damage_key(type)) * get_elemental_multiplier()


## Resistencia a magia, veneno o fuego, en % (con tope). Para el fisico
## devuelve cuanto reduce la defensa.
func get_resistance(type: int) -> float:
	if type == Damage.Type.PHYSICAL:
		return (1.0 - Damage.armor_multiplier(get_defense())) * 100.0
	return minf(get_equipment_bonus(Damage.resist_key(type)) + _buff_sum("resist"), Damage.RESIST_CAP)


func get_min_damage() -> int:
	var weapon: Itemdata = get_weapon()
	var base: int = weapon.min_damage if weapon else UNARMED_MIN_DAMAGE
	return maxi(1, roundi(base * get_damage_multiplier()))


func get_max_damage() -> int:
	var weapon: Itemdata = get_weapon()
	var base: int = weapon.max_damage if weapon else UNARMED_MAX_DAMAGE
	return maxi(get_min_damage(), roundi(base * get_damage_multiplier()))


## Ataques por segundo.
func get_attack_speed() -> float:
	var weapon: Itemdata = get_weapon()
	var base: float = weapon.attack_speed if weapon else UNARMED_ATTACK_SPEED
	return base * (1.0 + get_attribute("destreza") * 0.01 + get_equipment_bonus("velocidad_pct") / 100.0) 			* _buff_product("attack_speed_mult")


func get_crit_chance() -> float:
	return BASE_CRIT_CHANCE + get_attribute("destreza") * 0.2 + get_equipment_bonus("critico")


func get_defense() -> int:
	var total: float = get_attribute("vitalidad") * 0.5 + _buff_sum("defense") + get_equipment_bonus("defensa")
	for equip_index in [inventory_data.MELEE_EQUIP, inventory_data.SPECIAL_EQUIP]:
		var item: Itemdata = inventory_data.get_equipped(equip_index)
		if item:
			total += item.defense
	return roundi(total)


func get_block_chance() -> float:
	var shield: Itemdata = inventory_data.get_equipped(inventory_data.SPECIAL_EQUIP)
	return shield.block_chance if shield else 0.0


## Multiplicador del tiempo de recarga de habilidades (menos es mejor).
func get_cooldown_multiplier() -> float:
	return 100.0 / (100.0 + get_attribute("concentracion") * 3.0)


# --- Combate ---------------------------------------------------------------

## Tira el daño de un golpe: el fisico del arma mas el elemental del equipo,
## todo por multiplier (el de la habilidad). conversion pasa esa parte del
## fisico a convert_to. Devuelve {parts: {Damage.Type: cantidad}, crit}.
func roll_hit(multiplier: float = 1.0, convert_to: int = Damage.Type.PHYSICAL, conversion: float = 0.0) -> Dictionary:
	var crit: bool = randf() * 100.0 < get_crit_chance()
	var scale: float = multiplier * (CRIT_MULTIPLIER if crit else 1.0)
	var physical: float = randi_range(get_min_damage(), get_max_damage()) * scale
	var parts: Dictionary = Damage.split(physical, convert_to, conversion)
	for type in Damage.ELEMENTS:
		var extra: float = get_elemental_damage(type)
		if extra > 0.0:
			parts[type] = parts.get(type, 0.0) + extra * randf_range(0.8, 1.2) * scale
	return {"parts": parts, "crit": crit}


func get_resistances() -> Dictionary:
	var resists := {}
	for type in Damage.ELEMENTS:
		resists[type] = get_resistance(type)
	return resists


## Aplica un golpe recibido ({Damage.Type: cantidad}). Devuelve {blocked,
## amount, type} con el daño que entro de una (el veneno se resta despues).
func take_hit(parts: Dictionary) -> Dictionary:
	if dead:
		return {"blocked": false, "amount": 0.0, "type": Damage.Type.PHYSICAL}
	if randf() * 100.0 < get_block_chance():
		return {"blocked": true, "amount": 0.0, "type": Damage.Type.PHYSICAL}

	var result: Dictionary = Damage.mitigate(parts, get_defense(), get_resistances())
	status.add_poison(result.poison)
	status.add_burn(result.burn)
	_lose_health(result.direct)
	return {"blocked": false, "amount": result.direct, "type": result.type}


func _lose_health(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, get_max_health())
	if health <= 0.0:
		dead = true
		buffs.clear()
		status.clear()
		buffs_changed.emit()
		died.emit()


func heal(amount: float) -> void:
	if dead:
		return
	health = minf(health + amount, get_max_health())
	health_changed.emit(health, get_max_health())


func respawn() -> void:
	dead = false
	status.clear()
	health = get_max_health()
	health_changed.emit(health, get_max_health())
	respawned.emit()


func _on_equipment_changed(_equip_index: int) -> void:
	health = minf(health, get_max_health())
	health_changed.emit(health, get_max_health())
	stats_changed.emit()
