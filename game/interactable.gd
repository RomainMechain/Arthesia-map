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


func _process(delta: float) -> void:
	_anim_t += delta * 3.0
	if sprite and sprite.hframes > 1:
		sprite.frame = int(_anim_t) % sprite.hframes
	if _icon and _icon.visible:
		_icon.position = Vector2(0, _icon_y + roundf(sin(_anim_t * 0.9) * 1.5))


func set_highlight(on: bool) -> void:
	name_label.visible = on


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
