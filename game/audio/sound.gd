extends Node
## Son du jeu (autoload « Sound ») : trois volumes (général, musique et ambiance, effets), bruitages,
## ambiance de zone et musique d'humeur avec fondus enchaînés.
##
## Bruitages et ambiances : synthétisés par tools/audio/sfx.py (assets/audio/sfx, assets/audio/ambience).
## Musique : fournie par toi dans assets/audio/music (voir LISEZMOI.md). Humeur selon la zone :
##   « calme » (village, zones simples), « tension » (zones dangereuses), « boss » (combat de boss),
##   « titre » (écran titre). Un fichier au nom d'une zone (ex. rive_paisible.ogg) passe avant l'humeur.

const SFX_DIR := "res://assets/audio/sfx/%s.wav"
const AMB_DIR := "res://assets/audio/ambience/%s.wav"
const MUSIC_DIR := "res://assets/audio/music/"
const MUSIC_EXT := ["ogg", "mp3", "wav"]
const FADE := 2.0

## Type de zone -> humeur musicale
const MOOD := {"town": "calme", "camp": "calme", "wilderness": "calme", "water": "calme", "passage": "calme",
	"danger": "tension", "ruins": "tension", "boss": "boss"}
## Zone -> ambiance (sinon selon le type)
const AMBIENCE := {"village_aube": "village", "sentier_lisiere": "foret", "rive_paisible": "rive",
	"foret_ancienne": "foret_profonde"}
const AMBIENCE_BY_TYPE := {"town": "village", "camp": "village", "wilderness": "foret", "water": "rive"}

var _players := {}                                 # nom du bruitage -> son lecteur
var _cache := {}
var _last_play := {}
var _music: Array[AudioStreamPlayer] = []          # deux lecteurs pour les fondus
var _music_on := 0
var _music_key := ""
var _amb: Array[AudioStreamPlayer] = []
var _amb_on := 0
var _amb_key := ""
var _mood_stack: Array = []                        # humeurs temporaires (combat de boss)
var _zone_mood := "calme"
var _zone_id := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Musique", "Effets"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Musique"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
		var a := AudioStreamPlayer.new()
		a.bus = "Musique"
		a.volume_db = -80.0
		add_child(a)
		_amb.append(a)
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.settings_changed.connect(apply_volumes)
		gs.item_gained.connect(func(_id, _q): play("loot", -3.0, 0.05, 0.12))
		gs.quest_changed.connect(_on_quest.bind(gs))
	apply_volumes()
	# un clic discret sur chaque bouton de l'interface
	get_tree().node_added.connect(func(n):
		if n is BaseButton and not n.has_meta("silent"):
			(n as BaseButton).pressed.connect(func(): play("ui_click", -9.0)))


func _on_quest(qid: String, gs: Node) -> void:
	var st: String = gs.quest_state(qid)
	if st == "active":
		play("quest_accept")
	elif st == "complete":
		play("quest_done")


func apply_volumes() -> void:
	var gs := get_node_or_null("/root/GameState")
	var s: Dictionary = gs.settings if gs else {}
	for pair in [["Master", "vol_master"], ["Musique", "vol_music"], ["Effets", "vol_sfx"]]:
		var i := AudioServer.get_bus_index(pair[0])
		var v := clampf(float(s.get(pair[1], 0.6 if pair[1] == "vol_music" else 0.8)), 0.0, 1.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)


# --------------------------------------------------------------------------- bruitages
func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## Joue un bruitage. `pitch_var` : variation aléatoire de hauteur (évite la répétition mécanique).
## `min_gap` : deux mêmes sons ne se chevauchent pas plus souvent que ça (pas, impacts en série).
func play(name: String, volume_db := 0.0, pitch_var := 0.06, min_gap := 0.03) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(name, -10.0)) < min_gap:
		return
	var p: AudioStreamPlayer = _players.get(name)
	if p == null:
		var st := _stream(SFX_DIR % name)
		if st == null:
			return
		# un lecteur par bruitage, son flux ne change jamais (changer le flux d'un lecteur qui joue
		# encore fait planter le moteur) ; plusieurs voix à la fois pour les sons rapprochés
		p = AudioStreamPlayer.new()
		p.bus = "Effets"
		p.stream = st
		p.max_polyphony = 4
		add_child(p)
		_players[name] = p
	_last_play[name] = now
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


# --------------------------------------------------------------------------- zone : ambiance + musique
func enter_zone(zone_id: String, zone_type: String, mood := "") -> void:
	_zone_id = zone_id
	_zone_mood = mood if mood != "" else MOOD.get(zone_type, "calme")
	_mood_stack.clear()
	set_ambience(AMBIENCE.get(zone_id, AMBIENCE_BY_TYPE.get(zone_type, "")))
	_update_music()


func title_screen() -> void:
	_zone_id = ""
	_zone_mood = "titre"
	_mood_stack.clear()
	set_ambience("")
	_update_music()


## Humeur temporaire par-dessus celle de la zone (ex. « boss » pendant un combat de boss).
func push_mood(m: String) -> void:
	_mood_stack.append(m)
	_update_music()


func pop_mood(m: String) -> void:
	var i := _mood_stack.rfind(m)
	if i >= 0:
		_mood_stack.remove_at(i)
	_update_music()


func current_mood() -> String:
	return _mood_stack[-1] if not _mood_stack.is_empty() else _zone_mood


func _music_file(key: String) -> String:
	for ext in MUSIC_EXT:
		var p: String = MUSIC_DIR + key + "." + str(ext)
		if ResourceLoader.exists(p):
			return p
	return ""


func _update_music() -> void:
	var mood := current_mood()
	var path := ""
	if mood != "boss" and mood != "titre" and _zone_id != "":
		path = _music_file(_zone_id)                 # un thème propre à la zone passe avant l'humeur
	if path == "":
		path = _music_file(mood)
	if path == _music_key:
		return
	_music_key = path
	_crossfade(_music, path, true)


func set_ambience(key: String) -> void:
	var path := (AMB_DIR % key) if key != "" else ""
	if path == _amb_key:
		return
	_amb_key = path
	_crossfade(_amb, path, false)


func _crossfade(pair: Array[AudioStreamPlayer], path: String, is_music: bool) -> void:
	var cur_i := _music_on if is_music else _amb_on
	var old := pair[cur_i]
	var nxt := pair[1 - cur_i]
	if is_music:
		_music_on = 1 - cur_i
	else:
		_amb_on = 1 - cur_i
	var tw := create_tween().set_parallel()
	tw.tween_property(old, "volume_db", -80.0, FADE).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(old.stop)
	if path == "":
		return
	var st: AudioStream = load(path)
	if st == null:
		return
	_set_loop(st)
	nxt.stream = st
	nxt.volume_db = -80.0
	nxt.play()
	var target := -4.0 if is_music else -8.0         # l'ambiance reste en fond, sous la musique
	create_tween().tween_property(nxt, "volume_db", target, FADE).set_trans(Tween.TRANS_SINE)


func _set_loop(st: AudioStream) -> void:
	if st is AudioStreamWAV:
		var w := st as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	elif st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
