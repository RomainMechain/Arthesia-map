extends Node2D
## Point d'interaction issu d'une Entry (PNJ, boutique, marché, atelier).
## Les données viennent des JSON via data/build/<zone>.build.json (remplies par le constructeur).

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

const INTERACT_RADIUS := 26.0

var _anim_t := 0.0
@onready var sprite: Sprite2D = get_node_or_null("Sprite")
@onready var name_label: Label = $Nom
@onready var marker: Label = $Marqueur


func _ready() -> void:
	add_to_group("interactables")
	name_label.visible = false
	_anim_t = randf() * 4.0
	_refresh_marker()


func _process(delta: float) -> void:
	if sprite:
		_anim_t += delta * 3.0
		sprite.frame = int(_anim_t) % sprite.hframes


func set_highlight(on: bool) -> void:
	name_label.visible = on


func available_quests() -> Array:
	# V1 : seules les quêtes permanentes sont proposées ; les conditionnelles
	# attendent le ConditionEvaluator (état joueur pas encore implémenté).
	return quests.filter(func(q): return q.spawn.mode != "conditional")


func locked_hints() -> Array:
	return quests.filter(func(q): return q.spawn.mode == "conditional" and q.spawn.get("hint"))


func _refresh_marker() -> void:
	if not available_quests().is_empty():
		marker.text = "!"
		marker.modulate = Color("ffe08a")
	elif not locked_hints().is_empty():
		marker.text = "?"
		marker.modulate = Color(1, 1, 1, 0.55)
	else:
		marker.text = ""


func interact() -> Dictionary:
	var line := ""
	if not dialogues.is_empty():
		line = dialogues[randi() % dialogues.size()]
	var q := available_quests()
	var extra := ""
	if not q.is_empty():
		extra = "Quête : " + ", ".join(q.map(func(x): return x.name))
	elif not locked_hints().is_empty():
		extra = locked_hints()[0].spawn.hint
	elif info != "":
		extra = info
	return {"name": display_name, "role": role, "text": line, "extra": extra}
