extends Node2D
## Point d'interaction issu d'une Entry (PNJ, boutique, marché, atelier, ressource).
## Les données viennent des JSON via data/build/<zone>.build.json (remplies par le constructeur).
## Quêtes : l'état vient de GameState (proposer -> en cours -> à rendre -> rendue).
## Marqueur : « ! » quête à prendre, « … » en cours, « ? » à rendre, « ! » pâle = verrouillée (indice).

@export var entry_id := ""
@export var template_type := ""
@export var template_id := ""
@export var display_name := ""
@export var role := ""
@export var dialogues: PackedStringArray = []
## [{entry_id, quest_id, name, spawn}] — quêtes proposées par ce PNJ
@export var quests: Array = []
## Ligne d'information affichée sous le texte (récolte, combat à venir...)
@export var info := ""
## Données propres à la carte : traversée {to}, découverte {note, title}
@export var data: Dictionary = {}
var _prompt: Label

const INTERACT_RADIUS := 26.0

var _anim_t := 0.0
var _icon: Sprite2D
var _icon_y := -40.0
@onready var sprite: Sprite2D = get_node_or_null("Sprite")
@onready var name_label: Label = $Nom
@onready var marker: Label = $Marqueur


func _ready() -> void:
	add_to_group("interactables")
	name_label.visible = false
	_anim_t = randf() * 4.0
	# marqueur dessiné (le Label reste la source du texte, invisible)
	_icon = Sprite2D.new()
	_icon.name = "MarqueurIcone"
	_icon_y = name_label.position.y - 7.0               # au-dessus du nom (qui s'affiche à l'approche)
	add_child(_icon)
	marker.visible = false
	refresh_marker()
	_life_setup()


func _process(delta: float) -> void:
	_anim_t += delta * 3.0
	if _living:
		_live(delta)
	elif sprite and sprite.hframes > 1:
		sprite.frame = int(_anim_t) % sprite.hframes
	if _icon and _icon.visible:
		_icon.position = Vector2(0, _icon_y + roundf(sin(_anim_t * 0.9) * 1.5))

# --------------------------------------------------------------------------- PNJ vivants
## data/npc_life.json : petits déplacements autour de leur place, se tourner vers le joueur,
## phrases lancées en passant, répliques qui changent une fois leur quête rendue.
## Planche 4×3 : lignes face / dos / profil (retourné pour la gauche), colonnes repos 0-1, marche 2-3.
const WALK_SPEED := 11.0
const NOTICE := 44.0                  # se tourne vers toi
const BARK_DIST := 58.0
static var _life_db: Dictionary = {}
static var _bark_at := -100.0         # dernière phrase lancée (tous PNJ confondus) : pas de cacophonie
var life: Dictionary = {}
var _living := false
var _home := Vector2.ZERO
var _goal := Vector2.ZERO
var _walking := false
var _idle_t := 0.0
var _row := 0
var _bark_box: PanelContainer
var _bark_label: Label
var _bark_until := 0.0
var _bark_ready := 0.0
var _was_near := false


static func life_db() -> Dictionary:
	if _life_db.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/npc_life.json"))
		_life_db = d if d is Dictionary else {"_": {}}
	return _life_db


func _life_setup() -> void:
	if not (template_type in ["npc", "shop"]) or sprite == null or sprite.vframes < 3:
		return
	var db := life_db()
	life = db.get(template_id, db.get("thessaly", {}) if template_type == "shop" else {})
	_living = true
	_home = position
	_goal = position
	_idle_t = randf_range(1.0, 6.0)
	_bark_ready = randf_range(2.0, 8.0)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _talking_to_me() -> bool:
	var z := get_tree().get_first_node_in_group("zone")
	return z != null and z.get("_dialog") != null and z._dialog.visible and z.get("_dialog_it") == self


func _live(delta: float) -> void:
	var p := _player()
	var to_p: Vector2 = (p.global_position - global_position) if p else Vector2(9999, 9999)
	var near: bool = to_p.length() < NOTICE
	var talking := _talking_to_me()
	var moving := false
	if near or talking:
		_walking = false
		_face(to_p)
	elif _walking:
		var step := _goal - position
		if step.length() < 0.6:
			_walking = false
			position = _goal
			_idle_t = randf_range(3.0, 8.0)
		else:
			var d := step.normalized()
			position += d * minf(WALK_SPEED * delta, step.length())
			_face(d)
			moving = true
	else:
		_idle_t -= delta
		if _idle_t <= 0.0:
			_pick_goal()
	# image : repos (lent) ou marche
	var col: int = (2 + int(_anim_t * 2.0) % 2) if moving else (int(_anim_t * 0.5) % 2)
	sprite.frame = _row * 4 + col
	# phrases en passant
	_bark_ready -= delta
	var in_range: bool = to_p.length() < BARK_DIST
	if in_range and not _was_near and not talking and _bark_ready <= 0.0:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _bark_at > 5.0:
			_bark_at = now
			_bark_ready = randf_range(35.0, 60.0)
			bark(_bark_line())
	_was_near = in_range
	if _bark_box and _bark_box.visible:
		var now2 := Time.get_ticks_msec() / 1000.0
		if now2 > _bark_until or talking:
			_bark_box.visible = false
		else:
			_bark_box.modulate.a = clampf((_bark_until - now2) / 0.4, 0.0, 1.0)


## Se tourner : face, dos ou profil (retourné vers la gauche).
func _face(d: Vector2) -> void:
	if d.length() < 0.01:
		return
	if absf(d.x) > absf(d.y) * 1.2:
		_row = 2
		sprite.flip_h = d.x < 0.0
	else:
		_row = 0 if d.y > 0.0 else 1
		sprite.flip_h = false


func _pick_goal() -> void:
	var w: Array = life.get("wander", [0, 0])
	if w.size() < 2 or (float(w[0]) <= 0.0 and float(w[1]) <= 0.0):
		_idle_t = randf_range(4.0, 9.0)
		_row = 0 if randf() < 0.6 else 2                     # immobile : regarde ailleurs, de temps en temps
		sprite.flip_h = randf() < 0.5
		return
	var g := (_home + Vector2(randf_range(-1, 1) * float(w[0]), randf_range(-1, 1) * float(w[1]))).round()
	if _blocked(g):
		_idle_t = randf_range(1.0, 3.0)
		return
	_goal = g
	_walking = true


## Un mur, un tronc, de l'eau profonde entre ici et là ? (rayon physique, sans notre corps ni le joueur)
func _blocked(to: Vector2) -> bool:
	if not is_inside_tree():
		return true
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + (to - position))
	var ex: Array[RID] = []
	var own := get_node_or_null("Collision")
	if own is CollisionObject2D:
		ex.append((own as CollisionObject2D).get_rid())
	var p := _player()
	if p is CollisionObject2D:
		ex.append((p as CollisionObject2D).get_rid())
	q.exclude = ex
	return not space.intersect_ray(q).is_empty()


## La phrase lancée en passant : une quête à rendre ou à prendre d'abord, sinon une des siennes.
func _bark_line() -> String:
	var states := quests.map(func(q): return _state(q))
	if "complete" in states:
		return ["Alors, c'est fait ?", "Tu as ce qu'il me faut ?", "Reviens me voir, Marqué !"][randi() % 3]
	if not available_quests().is_empty() and randf() < 0.6:
		return ["Hé, Marqué ! J'aurais besoin d'aide.", "Tu aurais un moment ?", "Approche, j'ai quelque chose à te demander."][randi() % 3]
	var b: Array = life.get("barks", [])
	return str(b[randi() % b.size()]) if not b.is_empty() else ""


## Bulle au-dessus de la tête, quelques secondes.
func bark(text: String) -> void:
	if text == "":
		return
	if _bark_box == null:
		_bark_box = PanelContainer.new()
		_bark_box.add_theme_stylebox_override("panel", UISkin.box("parchment", 8, 3))
		_bark_box.z_index = 40
		_bark_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bark_label = UISkin.ink(Label.new(), Color("4f3324"))
		_bark_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bark_box.add_child(_bark_label)
		add_child(_bark_box)
	_bark_label.text = text
	_bark_label.custom_minimum_size = Vector2(clampf(text.length() * 4.2, 40.0, 120.0), 0)
	_bark_box.visible = true
	_bark_box.modulate.a = 1.0
	_bark_box.reset_size()
	_bark_until = Time.get_ticks_msec() / 1000.0 + 2.5 + text.length() * 0.04
	_place_bark()
	await get_tree().process_frame                      # taille exacte connue après une image
	if is_instance_valid(_bark_box):
		_bark_box.reset_size()
	_place_bark()


func _place_bark() -> void:
	if is_instance_valid(_bark_box):
		_bark_box.position = Vector2(roundf(-_bark_box.size.x / 2.0), roundf(_icon_y - 6.0 - _bark_box.size.y))


## Le dialogue du moment : celui d'après la dernière quête rendue (data/npc_life.json), sinon l'ordinaire.
func current_dialogues() -> Array:
	return _dialogue_set()[1]


func dialogue_key() -> String:
	return _dialogue_set()[0]


func _dialogue_set() -> Array:
	var key := "base"
	var lines: Array = Array(dialogues)
	var gs := _gs()
	var after: Dictionary = life_db().get(template_id, {}).get("after", {})
	if gs:
		for qid in after:
			if gs.quest_state(qid) == "turned_in":
				key = qid
				lines = after[qid]
	return [key, lines]


func set_highlight(on: bool) -> void:
	name_label.visible = on
	if get("leash") != null:                     # bête : seulement son nom
		return
	if on and _prompt == null:
		_prompt = UISkin.shadowed(Label.new(), Color("ffe08a"))
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.size = Vector2(80, 12)
		_prompt.position = name_label.position + Vector2(name_label.size.x / 2.0 - 40.0, 10)
		_prompt.z_index = 30
		add_child(_prompt)
	if _prompt:
		_prompt.text = ("Toucher · " if OS.has_feature("mobile") else "E · ") + _verb()
		_prompt.visible = on


## L'action qu'on fera en interagissant (affichée sous le nom).
func _verb() -> String:
	if has_method("harvest"):
		return "Récolter"
	match template_type:
		"shop":
			return "Commerce"
		"workshop":
			return "Fabriquer"
		"ferry":
			return "Traverser"
		"discovery":
			return "Examiner"
		"player_market":
			return "Consulter"
	return "Parler"


func _gs() -> Node:
	return (get_node_or_null("/root/GameState") if is_inside_tree() else null)


func _state(q: Dictionary) -> String:
	var gs := _gs()
	return gs.quest_state(q.quest_id) if gs else ""


func _unlocked(q: Dictionary) -> bool:
	if q.spawn.mode != "conditional":
		return true
	var gs := _gs()
	return gs != null and gs.eval_condition(q.spawn.get("condition"))


## Quêtes qu'on peut prendre maintenant.
func available_quests() -> Array:
	return quests.filter(func(q): return _unlocked(q) and _state(q) == "")


func locked_hints() -> Array:
	return quests.filter(func(q): return not _unlocked(q) and q.spawn.get("hint"))


func refresh_marker() -> void:
	if marker == null:
		return
	var states := quests.map(func(q): return _state(q))
	marker.modulate = Color("ffe08a")
	if "complete" in states:
		marker.text = "?"
	elif not available_quests().is_empty():
		marker.text = "!"
	elif "active" in states:
		marker.text = "…"
		marker.modulate = Color(1, 1, 1, 0.7)
	elif not locked_hints().is_empty():
		marker.text = "!"
		marker.modulate = Color(1, 1, 1, 0.4)
	else:
		marker.text = ""
	if _icon:
		var kind: String = {"?": "marker_turnin", "!": "marker_quest", "…": "marker_active"}.get(marker.text, "")
		if marker.text == "!" and marker.modulate.a < 0.5:
			kind = "marker_locked"
		_icon.visible = kind != ""
		if kind != "":
			_icon.texture = UISkin.tex(kind)


func interact() -> Dictionary:
	var line := ""
	if not dialogues.is_empty():
		line = dialogues[randi() % dialogues.size()]
	var gs := _gs()
	var extra := ""
	var extra_text := ""
	var action := {}
	var done := quests.filter(func(q): return _state(q) == "complete")
	var offer := available_quests()
	var active := quests.filter(func(q): return _state(q) == "active")
	if not done.is_empty():
		var q: Dictionary = done[0]
		extra = "Quête terminée : %s" % q.name
		action = {"label": "Rendre la quête", "kind": "turn_in", "quest_id": q.quest_id}
	elif not offer.is_empty():
		var q: Dictionary = offer[0]
		var t: Dictionary = gs.tpl("quests", q.quest_id) if gs else {}
		line = t.get("description", line)
		extra = "Quête : %s" % q.name
		if gs:
			extra += "  —  " + ", ".join(PackedStringArray(gs.quest_progress_text(q.quest_id) if gs.quest_state(q.quest_id) != "" else _objectives_preview(t)))
		action = {"label": "Accepter", "kind": "accept", "quest_id": q.quest_id}
	elif not active.is_empty():
		var q: Dictionary = active[0]
		extra = "En cours : %s  —  %s" % [q.name, ", ".join(PackedStringArray(gs.quest_progress_text(q.quest_id)))]
	elif not locked_hints().is_empty():
		extra = locked_hints()[0].spawn.hint
	elif info != "":
		extra = info
	if action.is_empty() and template_type == "shop":
		action = {"label": " Commerce ", "kind": "shop", "shop_id": template_id}
	if action.is_empty() and template_type == "workshop":
		action = {"label": " Fabriquer ", "kind": "workshop", "workshop_id": template_id}
	if template_type == "ferry":
		action = {"label": " Traverser ", "kind": "ferry", "to": data.get("to", [0, 0])}
	if template_type == "discovery":
		var noted: bool = gs != null and gs.profile.get("notes", {}).has(data.get("note", ""))
		extra_text = "Déjà consigné dans ton Carnet (Quêtes › Notes)." if noted else "Une découverte : note-la dans ton Carnet."
		if not noted:
			action = {"label": " Noter ", "kind": "discovery", "note": data.get("note", ""), "title": data.get("title", ""), "text": line}
		extra = extra_text
	return {"name": display_name, "role": role, "text": line, "extra": extra, "action": action}


func _objectives_preview(t: Dictionary) -> Array:
	var gs := _gs()
	var out := []
	for o in t.get("objectives", []):
		var what: String = gs.tpl("monsters", o.monster_id).get("name", o.monster_id) if o.has("monster_id") \
			else gs.item_name(o.get("item_id", "?"))
		out.append("%s × %d" % [what, int(o.get("count", 1))])
	return out
