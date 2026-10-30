extends Node

## Autoload de musica: un tema por zona del mapa, otro cuando hay enemigos
## persiguiendo al jugador y otro en la pantalla de titulo. Al cambiar de
## tema se funden los dos (dos reproductores que se alternan). Va por el bus
## "Musica" (volumen en Opciones). Los temas estan en sounds/music/ y sus
## autores en CREDITS.md.

const WORLD := preload("res://world/build_world.gd")

const TRACKS := {
	"titulo": "res://sounds/music/titulo.ogg",
	"aldea": "res://sounds/music/aldea.ogg",
	"bosque": "res://sounds/music/bosque.ogg",
	"cementerio": "res://sounds/music/cementerio.ogg",
	"ruinas": "res://sounds/music/ruinas.ogg",
	"pradera": "res://sounds/music/pradera.ogg",
	"combate": "res://sounds/music/combate.ogg",
}
## Zonas del mapa (centro x, z y radio, los mismos que usa el mundo).
const ZONES := {
	"aldea": WORLD.VILLAGE,
	"bosque": WORLD.FOREST,
	"cementerio": WORLD.GRAVEYARD,
	"ruinas": WORLD.RUINS,
}
const FADE_TIME: float = 2.5
const VOLUME_DB: float = -6.0
## Distancia a la que un enemigo persiguiendo cuenta como combate.
const COMBAT_RANGE: float = 1800.0
## Segundos sin combate antes de volver al tema de la zona.
const COMBAT_COOLDOWN: float = 5.0
const CHECK_INTERVAL: float = 0.5

var current: String = ""
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _combat_left: float = 0.0
var _check_timer: float = 0.0
var _positions: Dictionary = {}


func _ready() -> void:
	# Sigue sonando con el juego en pausa (inventario, titulo, menu).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Musica"
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)


func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_INTERVAL
	_combat_left = maxf(_combat_left - CHECK_INTERVAL, 0.0)
	var wanted: String = _wanted_track()
	if wanted != current:
		play(wanted)


## Cambia al tema name fundiendolo con el anterior ("" = silencio).
func play(track: String) -> void:
	if track == current:
		return
	var old: AudioStreamPlayer = _players[_active]
	if not current.is_empty():
		_positions[current] = old.get_playback_position()
	current = track
	_fade(old, -80.0, true)
	if track.is_empty() or not TRACKS.has(track) or not ResourceLoader.exists(TRACKS[track]):
		return
	_active = 1 - _active
	var player: AudioStreamPlayer = _players[_active]
	var stream: AudioStream = load(TRACKS[track])
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	player.stream = stream
	player.volume_db = -40.0
	# Al volver a un tema de zona sigue desde donde iba (el de combate arranca de cero).
	player.play(_positions.get(track, 0.0) if track != "combate" else 0.0)
	_fade(player, VOLUME_DB, false)


func _fade(player: AudioStreamPlayer, target_db: float, stop_after: bool) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db, FADE_TIME).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tween.tween_callback(func() -> void:
			if player != _players[_active] or current.is_empty():
				player.stop())


func _wanted_track() -> String:
	var tree := get_tree()
	if tree.get_first_node_in_group("title_screen"):
		return "titulo"
	var player: Node3D = tree.get_first_node_in_group("player")
	if player == null:
		return current
	if _in_combat(player):
		_combat_left = COMBAT_COOLDOWN
	if _combat_left > 0.0:
		return "combate"
	return zone_at(player.global_position)


func _in_combat(player: Node3D) -> bool:
	if player_stats.dead:
		return false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead:
			continue
		var chasing: bool = enemy.state == enemy.State.CHASE or enemy.state == enemy.State.ATTACK
		if chasing and enemy.global_position.distance_to(player.global_position) < COMBAT_RANGE:
			return true
	return false


## Nombre del tema de la zona donde esta pos (fuera de las zonas, la pradera).
static func zone_at(pos: Vector3) -> String:
	for zone_name in ZONES:
		var zone: Vector3 = ZONES[zone_name]
		if Vector2(pos.x, pos.z).distance_to(Vector2(zone.x, zone.y)) < zone.z + 200.0:
			return zone_name
	return "pradera"
