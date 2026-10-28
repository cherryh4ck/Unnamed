extends Node

## Autoload con los datos del personaje: vida, atributos y stats derivados.
## El combate, el HUD y la pantalla de personaje leen todos de aca,
## igual que el inventario usa inventory_data.

signal health_changed(current: float, maximum: float)
signal stats_changed
signal died
signal respawned

const BASE_HEALTH: float = 80.0
const HEALTH_PER_VITALITY: float = 4.0
const HEALTH_PER_LEVEL: float = 10.0
const REGEN_PER_VITALITY: float = 0.05  # vida por segundo

const UNARMED_MIN_DAMAGE: int = 2
const UNARMED_MAX_DAMAGE: int = 4
const UNARMED_ATTACK_SPEED: float = 1.2
const BASE_CRIT_CHANCE: float = 5.0
const CRIT_MULTIPLIER: float = 2.0

var level: int = 1
var attributes: Dictionary = {
	"fuerza": 10,        # +2% daño por punto
	"destreza": 10,      # +1% velocidad de ataque y +0.2% critico por punto
	"vitalidad": 10,     # +4 vida maxima, +0.5 defensa y regeneracion
	"concentracion": 10, # acelera la recarga de las habilidades
}
var health: float = 0.0
var dead: bool = false


func _ready() -> void:
	health = get_max_health()
	inventory_data.equipment_changed.connect(_on_equipment_changed)


func _process(delta: float) -> void:
	if dead or health >= get_max_health():
		return
	heal(get_health_regen() * delta)


# --- Stats derivados -------------------------------------------------------

func get_max_health() -> float:
	return BASE_HEALTH + attributes.vitalidad * HEALTH_PER_VITALITY + (level - 1) * HEALTH_PER_LEVEL


func get_health_regen() -> float:
	return attributes.vitalidad * REGEN_PER_VITALITY


func get_weapon() -> Itemdata:
	var weapon: Itemdata = inventory_data.get_equipped(inventory_data.MELEE_EQUIP)
	return weapon if weapon and weapon.has_damage() else null


func get_damage_multiplier() -> float:
	return 1.0 + attributes.fuerza * 0.02


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
	return base * (1.0 + attributes.destreza * 0.01)


func get_crit_chance() -> float:
	return BASE_CRIT_CHANCE + attributes.destreza * 0.2


func get_defense() -> int:
	var total: float = attributes.vitalidad * 0.5
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
	return 100.0 / (100.0 + attributes.concentracion * 3.0)


# --- Combate ---------------------------------------------------------------

## Tira el daño de un golpe basico. Devuelve {amount, crit}.
func roll_damage() -> Dictionary:
	var amount: float = randi_range(get_min_damage(), get_max_damage())
	var crit: bool = randf() * 100.0 < get_crit_chance()
	if crit:
		amount *= CRIT_MULTIPLIER
	return {"amount": roundi(amount), "crit": crit}


## Aplica un golpe recibido. Devuelve {blocked, amount} con el daño final.
func take_damage(amount: float) -> Dictionary:
	if dead:
		return {"blocked": false, "amount": 0.0}
	if randf() * 100.0 < get_block_chance():
		return {"blocked": true, "amount": 0.0}

	var final_amount: float = amount * 100.0 / (100.0 + get_defense())
	health = maxf(health - final_amount, 0.0)
	health_changed.emit(health, get_max_health())
	if health <= 0.0:
		dead = true
		died.emit()
	return {"blocked": false, "amount": final_amount}


func heal(amount: float) -> void:
	if dead:
		return
	health = minf(health + amount, get_max_health())
	health_changed.emit(health, get_max_health())


func respawn() -> void:
	dead = false
	health = get_max_health()
	health_changed.emit(health, get_max_health())
	respawned.emit()


func _on_equipment_changed(_equip_index: int) -> void:
	stats_changed.emit()
