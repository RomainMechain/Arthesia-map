extends Node
## Apparitions rares : environ toutes les 15 à 25 min passées dans une zone de combat, une bête de la
## zone se lève « marquée par l'aube » (game/mob.gd, make_marked). Bandeau d'annonce et repère doré
## sur la mini-carte ; si personne ne la trouve en 5 min, elle s'évanouit. Le temps passé dans la zone
## est gardé dans la sauvegarde (profile.rare_t / rare_next).

const MIN_WAIT := 900.0
const MAX_WAIT := 1500.0
const LIFETIME := 300.0
const MIN_DIST := 220.0                     # elle n'apparaît jamais sous le nez du joueur

var zone: Node
var current: Node2D = null
var _life := 0.0


func _gs() -> Node:
	return get_node_or_null("/root/GameState")


func _process(delta: float) -> void:
	var gs := _gs()
	if gs == null or zone == null:
		return
	var zid: String = zone.zone_id
	if is_instance_valid(current):
		if current.is_alive() and not current.provoked:
			_life += delta
			if _life >= LIFETIME:
				_vanish()
		return
	current = null
	var t: float = float(gs.profile.rare_t.get(zid, 0.0)) + delta
	gs.profile.rare_t[zid] = t
	if not gs.profile.rare_next.has(zid):
		gs.profile.rare_next[zid] = randf_range(MIN_WAIT, MAX_WAIT)
	if t >= float(gs.profile.rare_next[zid]):
		if spawn():
			gs.profile.rare_t[zid] = 0.0
			gs.profile.rare_next[zid] = randf_range(MIN_WAIT, MAX_WAIT)


## Fait se lever une créature marquée maintenant (utilisé aussi par les tests). Faux si impossible.
func spawn() -> bool:
	if is_instance_valid(current):
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var cands := get_tree().get_nodes_in_group("mobs").filter(func(m):
		return m.is_alive() and not m.marked and m.fighter.role == "normal" and not m.provoked \
			and (player == null or m.global_position.distance_to(player.global_position) > MIN_DIST))
	if cands.is_empty():
		return false
	var src: Node2D = cands[randi() % cands.size()]
	var m: Node2D = src.duplicate()
	m.name = "marque_%s" % src.name
	src.get_parent().add_child(m)
	m.global_position = src.global_position + Vector2(randf_range(-12, 12), randf_range(-8, 8))
	m.make_marked()
	current = m
	_life = 0.0
	var gs := _gs()
	if zone.has_method("toast"):
		zone.toast("Une bête marquée par l'aube rôde…", 4.0)
	Sfx.play("discovery")
	if gs:
		gs.notice.emit("Une créature marquée par l'aube rôde : %s." % m.tpl.get("name", ""))
	return true


func _vanish() -> void:
	var m := current
	current = null
	if not is_instance_valid(m):
		return
	m.remove_from_group("mobs")
	var gs := _gs()
	if gs:
		gs.notice.emit("La créature marquée s'est évanouie dans l'aube.")
	var tw := m.create_tween()
	tw.tween_property(m, "modulate:a", 0.0, 1.2)
	tw.tween_callback(m.queue_free)
