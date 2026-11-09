extends "res://game/interactable.gd"
## Ressource récoltable (Entry « resource », template data/templates/resources/<id>.json).
## Toucher la ressource lance la récolte (la zone gère la barre et l'interruption) ; elle a un stock
## (spawn.stock) et repousse après spawn.cooldown_seconds une fois épuisée.
## Sans le niveau de métier requis, elle reste visible et affiche le prérequis.

@export var max_stock := 1
@export var respawn_seconds := 90.0

var stock := 1
var res: Dictionary = {}


func _ready() -> void:
	super()
	stock = max_stock
	var gs := _gs()
	res = gs.tpl("resources", template_id) if gs else {}


func profession() -> String:
	var pr = res.get("profession_required")
	return pr.get("profession_id", "") if pr is Dictionary else ""


func gather_time() -> float:
	return float(res.get("gather_time_seconds", 3))


## "" si on peut récolter maintenant, sinon la raison.
func can_gather() -> String:
	if stock <= 0:
		return "épuisé, repousse bientôt"
	var pr = res.get("profession_required")
	var gs := _gs()
	if pr is Dictionary and gs:
		var need := int(pr.get("min_level", 1))
		if gs.prof_level(pr.profession_id) < need:
			return "%s niv. %d requis" % [gs.PROF_NAMES.get(pr.profession_id, pr.profession_id), need]
	return ""


## Fin de récolte : tirage pondéré dans `yields`, stock consommé. Renvoie [[item_id, qté]].
func harvest() -> Array:
	var ys: Array = res.get("yields", [])
	var total := 0.0
	for y in ys:
		total += float(y.get("weight", 1))
	var r := randf() * total
	var out := []
	for y in ys:
		r -= float(y.get("weight", 1))
		if r <= 0.0:
			out.append([y.item_id, randi_range(int(y.quantity_min), int(y.quantity_max))])
			break
	stock -= 1
	if stock <= 0:
		_deplete()
	return out


func _deplete() -> void:
	if sprite:
		create_tween().tween_property(sprite, "modulate", Color(0.6, 0.55, 0.65, 0.45), 0.4)
	get_tree().create_timer(respawn_seconds).timeout.connect(func():
		if not is_inside_tree():
			return
		stock = max_stock
		if sprite:
			create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.8))


func interact() -> Dictionary:
	var d := super()
	var why := can_gather()
	d.extra = ("Stock : %d/%d" % [stock, max_stock]) if why == "" else why[0].to_upper() + why.substr(1)
	return d
