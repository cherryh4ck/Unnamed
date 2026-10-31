extends Node

## Autoload de sonidos. Centraliza las rutas para que el resto del juego
## pida sonidos por nombre: sfx.play("click") o sfx.play_at("hit", pos).
## Si un nombre tiene varias rutas, elige una al azar (sin repetir la anterior).

const SOUNDS := {
	"hit": ["res://sounds/hit/punch_hit.wav", "res://sounds/hit/punch_hit2.wav"],
	"hit_flesh": ["res://sounds/combat/flesh1.ogg", "res://sounds/combat/flesh2.ogg", "res://sounds/combat/flesh3.ogg"],
	"hit_bone": ["res://sounds/combat/bone1.ogg", "res://sounds/combat/bone2.ogg", "res://sounds/combat/bone3.ogg"],
	"hit_insect": ["res://sounds/combat/insect1.ogg", "res://sounds/combat/insect2.ogg", "res://sounds/combat/insect3.ogg"],
	"block": ["res://sounds/combat/block1.ogg", "res://sounds/combat/block2.ogg", "res://sounds/combat/block3.ogg"],
	"lifeleech": ["res://sounds/hit/lifeleech.wav"],
	"click": ["res://sounds/ui/click.wav"],
	"page": ["res://sounds/ui/pasar_pag1.wav", "res://sounds/ui/pasar_pag2.wav"],
	"levelup": ["res://sounds/ui/levelup.wav"],
	"new_skill": ["res://sounds/ui/new_skill.wav"],
	"new_spell": ["res://sounds/ui/new_spell_learned.wav"],
	"drag_weapon": ["res://sounds/ui/items_drag/weapon.wav"],
	"drag_potion": ["res://sounds/ui/items_drag/potion.wav"],
	"drag_ring": ["res://sounds/ui/items_drag/ring.wav"],
	"pickup_gold": ["res://sounds/interact/gold/take.wav"],
	"pickup_potion": ["res://sounds/interact/potions/take1.wav", "res://sounds/interact/potions/take2.wav"],
	"pickup_magic": ["res://sounds/interact/magic_find.wav"],
	"fireball": ["res://sounds/spells/fireball.wav"],
	"damage_boost": ["res://sounds/spells/damage_boost.wav"],
	"resistance": ["res://sounds/spells/resistance.wav"],
	"fire_resistance": ["res://sounds/spells/fire_resistance_spell.wav"],
	"spikes": ["res://sounds/spells/spikes.wav"],
	"stuck": ["res://sounds/spells/stuck.wav"],
	"success": ["res://sounds/spells/success.wav"],
	"throw": ["res://sounds/spells/throw.wav"],
	"unknown_spell": ["res://sounds/spells/unknown_spell.wav", "res://sounds/spells/unknown_spell2.wav"],
	"bow_shoot": ["res://sounds/weapons/bow_shoot.wav"],
	"portal": ["res://sounds/ambient/portal.wav"],
	"chest_open": ["res://sounds/interact/chest/open.ogg"],
	"anvil": ["res://sounds/interact/smith/anvil1.ogg", "res://sounds/interact/smith/anvil2.ogg"],
	"coins": ["res://sounds/interact/smith/coins.ogg"],
	"wolf_growl": ["res://sounds/creatures/wolf/growl1.ogg", "res://sounds/creatures/wolf/growl2.ogg", "res://sounds/creatures/wolf/howl.ogg"],
	"wolf_attack": ["res://sounds/creatures/wolf/attack01.ogg", "res://sounds/creatures/wolf/attack03.ogg", "res://sounds/creatures/wolf/attack05.ogg", "res://sounds/creatures/wolf/attack07.ogg", "res://sounds/creatures/wolf/bite1.ogg", "res://sounds/creatures/wolf/bite2.ogg"],
	"wolf_death": ["res://sounds/creatures/wolf/growl2.ogg"],
	"spider_chitter": ["res://sounds/creatures/spider/chitter01.ogg", "res://sounds/creatures/spider/chitter02.ogg", "res://sounds/creatures/spider/chitter04.ogg"],
	"spider_attack": ["res://sounds/creatures/spider/hiss.ogg", "res://sounds/creatures/spider/chirp.ogg"],
	"gem_socket": ["res://sounds/interact/gems/gem1.ogg", "res://sounds/interact/gems/gem3.ogg", "res://sounds/interact/gems/gem5.ogg"],
}

# El mundo usa unidades grandes (el personaje mide ~400), asi que la
# atenuacion 3D se escala para que se escuche a distancia de camara.
const UNIT_SIZE_3D: float = 900.0
const MAX_DISTANCE_3D: float = 9000.0
const POOL_SIZE: int = 12

var _streams: Dictionary = {}
var _last_index: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next_player: int = 0


func _ready() -> void:
	# Los sonidos de UI tienen que sonar aunque el juego este en pausa (inventario).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound_name in SOUNDS:
		var list: Array[AudioStream] = []
		for path in SOUNDS[sound_name]:
			if ResourceLoader.exists(path):
				list.append(load(path))
		_streams[sound_name] = list
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"Efectos"
		add_child(player)
		_pool.append(player)


## Sonido sin posicion (UI, mensajes, efectos del propio jugador).
func play(sound_name: String, volume_db: float = 0.0, pitch_variation: float = 0.05) -> void:
	var stream: AudioStream = _pick(sound_name)
	if stream == null:
		return
	var player: AudioStreamPlayer = _pool[_next_player]
	_next_player = (_next_player + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	player.play()


## Sonido de "agarrar" un item en el inventario segun su tipo.
func play_item(item: Itemdata) -> void:
	if item == null:
		return
	if item.is_equipment():
		play("drag_weapon")
	elif item.item_type == Itemdata.ItemType.POTION:
		play("drag_potion")
	else:
		play("drag_ring")


## Sonido posicional en el mundo (golpes, hechizos).
func play_at(sound_name: String, position: Vector3, volume_db: float = 0.0, pitch_variation: float = 0.08) -> void:
	var stream: AudioStream = _pick(sound_name)
	var scene: Node = get_tree().current_scene
	if stream == null or scene == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.bus = &"Efectos"
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = UNIT_SIZE_3D
	player.max_distance = MAX_DISTANCE_3D
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	scene.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()


func _pick(sound_name: String) -> AudioStream:
	var list: Array = _streams.get(sound_name, [])
	if list.is_empty():
		push_warning("sfx: sonido desconocido '%s'" % sound_name)
		return null
	var index: int = randi() % list.size()
	if list.size() > 1 and index == _last_index.get(sound_name, -1):
		index = (index + 1) % list.size()
	_last_index[sound_name] = index
	return list[index]
