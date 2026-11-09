extends Node2D
## Bête issue d'une Entry « monster » (template data/templates/monsters/<id>.json).
## Tempérament (déduit de la description, docs/combat_v1.md) :
##   calm      : fuit le joueur, ne riposte que si on la frappe (lapin, oiseau) ;
##   predator  : attaque quand on entre dans son rayon (loup) ;
##   skittish  : approche, mord, puis s'enfuit un moment (renardeau).
## IA de combat (combat_engine.monster_tick) : parmi les coups prêts, tirage pondéré par `weight`.
## Un coup avec telegraph_seconds > 0 s'annonce au sol ; sortir de la zone l'évite.

@export var entry_id := ""
@export var template_type := "monster"
@export var template_id := ""
@export var display_name := ""
@export var role := ""
@export var leash := 48.0
@export var temper := "calm"
@export var respawn_seconds := 45.0
## Rayon où une bête prédatrice (ou sentinelle, ou nageuse) repère le joueur
@export var aggro := 64.0

const AGGRO_RADIUS := 64.0
const NOTICE_DIST := 56.0
const GIVE_UP_DIST := 150.0         # le joueur s'éloigne trop : la bête abandonne
const MAX_CHASE_FROM_HOME := 120.0  # elle ne quitte pas son territoire
const SPEED := 22.0

var fighter := Fighter.new()
var tpl: Dictionary = {}
var body_radius := 6.0
var state := "wander"               # wander, flee, alert, chase, windup, recover, return, dead, dive
var provoked := false
## Nageuse sous l'eau : invisible et intouchable pendant la plongée
var submerged := false

var _home := Vector2.ZERO
var _goal := Vector2.ZERO
var _wait := 0.0
var _t := 0.0
var _anim_t := 0.0
var _pending: Dictionary = {}       # coup annoncé : {move, dir, origin, node}
var _player: Node2D
var _mat: ShaderMaterial
var _bar_t := 0.0
var _alert: Sprite2D
var _alert_t := 0.0
var _alert_until := 0.0
const ALERT_PAUSE := 0.4            # temps d'arrêt avant la charge : le joueur voit venir le coup
@onready var sprite: Sprite2D = get_node_or_null("Sprite")
@onready var name_label: Label = get_node_or_null("Nom")


func _ready() -> void:
	add_to_group("mobs")
	var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	tpl = gs.tpl("monsters", template_id) if gs else {}
	fighter.id = template_id
	fighter.display_name = tpl.get("name", display_name)
	fighter.role = tpl.get("role", "normal")
	var st: Dictionary = tpl.get("stats", {"hp": 100, "atk": 10, "def": 5, "agi": 5, "int": 5, "sag": 5}).duplicate()
	st.hp = float(st.hp) * CombatRules.ACTION_MONSTER_HP          # couche action : combats plus courts
	fighter.setup(st, int(tpl.get("level", 1)))
	_home = position
	_goal = position
	_wait = randf_range(0.0, 2.5)
	_player = get_tree().get_first_node_in_group("player")
	if sprite:
		body_radius = maxf(5.0, sprite.texture.get_width() / float(sprite.hframes) * 0.3)
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://game/fx/flash.gdshader")
		sprite.material = _mat
	if name_label:
		name_label.text = "%s  niv. %d" % [fighter.display_name, fighter.level]
		name_label.visible = false
	var m := get_node_or_null("Marqueur")
	if m:
		m.visible = false
	_alert = Sprite2D.new()                        # « ! » rouge : la bête t'a pris pour cible
	_alert.texture = UISkin.tex("marker_alert")
	_alert.position = Vector2(0, (sprite.offset.y if sprite else -16.0) - 8.0)
	_alert.visible = false
	add_child(_alert)


func is_alive() -> bool:
	return state != "dead"


func _zone() -> Node:
	return get_tree().get_first_node_in_group("zone")


func _player_ok() -> bool:
	return is_instance_valid(_player) and not _player.is_down()


func _process(delta: float) -> void:
	if state == "dead":
		return
	_t += delta
	fighter.tick(delta)
	var to_p := (_player.global_position - global_position) if is_instance_valid(_player) else Vector2.INF
	var dist := to_p.length()
	if name_label:
		name_label.visible = dist < 40.0 and not provoked           # en combat : le cadre de cible du HUD
	_bar_t = maxf(0.0, _bar_t - delta)
	if _alert_t > 0.0:
		_alert_t -= delta
		var k := clampf(1.0 - _alert_t / 0.9, 0.0, 1.0)
		_alert.scale = Vector2.ONE * (1.0 + 0.4 * maxf(0.0, 1.0 - k * 5.0))   # petit « pop »
		_alert.position.y = (sprite.offset.y if sprite else -16.0) - 8.0 - roundf(minf(k * 12.0, 2.0))
		_alert.visible = _alert_t > 0.0

	# déclencheurs d'engagement
	if not provoked and _player_ok():
		if temper in ["predator", "sentinel", "swimmer"] and dist < aggro:
			_engage()
		elif temper == "skittish" and dist < NOTICE_DIST:
			_engage()
	if provoked and (not _player_ok() or dist > GIVE_UP_DIST or position.distance_to(_home) > MAX_CHASE_FROM_HOME):
		_disengage()

	var moving := false
	match state:
		"wander":
			if temper == "calm" and _player_ok() and dist < NOTICE_DIST:
				state = "flee"
				_goal = _clamp_home(position - to_p.normalized() * leash * 0.8)
			moving = _wander(delta)
		"flee":
			moving = _walk_to(_goal, SPEED * 2.4, delta)
			if not moving or dist > NOTICE_DIST * 1.4:
				state = "chase" if provoked else "wander"
				_wait = 0.5
		"alert":
			if sprite and absf(to_p.x) > 1.0:
				sprite.flip_h = to_p.x < 0.0
			if _t >= _alert_until:
				state = "chase"
				var zd := _zone()
				if zd:                                     # elle se lance : un peu de poussière
					zd.burst(global_position, Color("d4a265"), 6, 16.0, false, Vector2(4, 1))
		"chase":
			moving = _chase(to_p, dist, delta)
		"windup", "dive":
			if _t >= _pending.resolve_at:
				_resolve_pending()
		"recover":
			if _t >= _pending.get("recover_at", 0.0):
				_pending = {}
				if temper == "skittish":
					state = "flee"
					_goal = _clamp_home(position - to_p.normalized() * 40.0)
				else:
					state = "chase"
		"return":
			moving = _walk_to(_home, SPEED * 2.2, delta)
			if not moving:
				fighter.hp = fighter.max_hp()
				fighter.effects.clear()
				state = "wander"
				queue_redraw()
	_animate(delta, moving)


## Engagement : « ! » rouge au-dessus de la bête, court arrêt (elle te fixe), puis la charge.
## `pause` plus courte quand on vient de la frapper (elle riposte).
func _engage(pause := ALERT_PAUSE) -> void:
	if provoked or state == "dead":
		return
	provoked = true
	_alert_t = 0.9
	var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	if gs:
		gs.show_hint("aggro")
	_alert.visible = true
	if state in ["wander", "flee"]:
		state = "alert"
		_alert_until = _t + pause
	# premier coup après le temps d'arrêt et un court temps de réaction
	for mv in tpl.get("moveset", []):
		if fighter.ready(mv.id):
			fighter.start_cooldown(mv.id, pause + (randf_range(0.4, 0.9) if mv.get("weight", 1) > 1 else float(mv.cooldown_seconds) * 0.5))


func _disengage() -> void:
	provoked = false
	submerged = false
	if sprite:
		sprite.modulate.a = 1.0
	_alert_t = 0.0
	_alert.visible = false
	_cancel_pending()
	state = "return"


func _chase(to_p: Vector2, dist: float, delta: float) -> bool:
	if not _player_ok():
		return false
	var mv := _pick_move()
	var reach := CombatRules.area_reach(CombatRules.area_of(mv if not mv.is_empty() else {})) * 0.75 + 4.0
	if temper == "swimmer":
		reach = 90.0                                  # elle file sous l'eau jusqu'à toi
	if temper == "sentinel" and dist > reach:
		return false                                  # le héron ne quitte pas son poste
	if dist > reach:
		return _walk_to(_player.global_position - to_p.normalized() * (reach * 0.6), SPEED * 2.3, delta)
	if sprite and absf(to_p.x) > 1.0:
		sprite.flip_h = to_p.x < 0.0
	if not mv.is_empty():
		_start_move(mv, to_p.normalized())
	return false


func _pick_move() -> Dictionary:
	var ready := (tpl.get("moveset", []) as Array).filter(func(m): return fighter.ready(m.id))
	if ready.is_empty():
		return {}
	var total := 0.0
	for m in ready:
		total += float(m.get("weight", 1))
	var r := randf() * total
	for m in ready:
		r -= float(m.get("weight", 1))
		if r <= 0.0:
			return m
	return ready[-1]


func _start_move(mv: Dictionary, d: Vector2) -> void:
	if temper == "swimmer":
		_dive(mv)
		return
	fighter.start_cooldown(mv.id, float(mv.cooldown_seconds))
	var tele := float(mv.get("telegraph_seconds", 0.0))
	_pending = {"move": mv, "dir": d, "origin": global_position + Vector2(0, -4), "resolve_at": _t + tele}
	if tele > 0.0:
		var z := _zone()
		if z:
			_pending.node = z.show_telegraph(global_position, CombatRules.area_of(mv), d, tele)
		var gs2 := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
		if gs2:
			gs2.show_hint("telegraph")
		state = "windup"
	else:
		_resolve_pending()


## Anguille : elle plonge (intouchable), des rides annoncent où elle va ressurgir, puis elle mord
## dans ce cercle. Sortir des rides évite la morsure ; on la frappe quand elle est en surface.
func _dive(mv: Dictionary) -> void:
	fighter.start_cooldown(mv.id, float(mv.cooldown_seconds))
	var target: Vector2 = _player.global_position if _player_ok() else global_position
	var local: Vector2 = _clamp_home(get_parent().to_local(target) if get_parent() else target)
	var emerge: Vector2 = (get_parent().to_global(local) if get_parent() else local)
	var tele := maxf(0.75, float(mv.get("telegraph_seconds", 0.0)))
	var area := CombatRules.area_of(mv)
	if area.get("shape") != "circle":
		area = {"shape": "circle", "radius": 16}
	submerged = true
	if sprite:
		create_tween().tween_property(sprite, "modulate:a", 0.0, 0.18)
	_pending = {"move": mv, "dir": Vector2.RIGHT, "origin": emerge, "resolve_at": _t + tele, "area": area, "emerge": local}
	var z := _zone()
	if z:
		_pending.node = z.show_telegraph(emerge + Vector2(0, 4), area, Vector2.RIGHT, tele)
		z.burst(global_position, Color("d4f4ec"), 6, 16.0, false, Vector2(4, 1))
	state = "dive"


func _resolve_pending() -> void:
	var mv: Dictionary = _pending.move
	if state == "dive":                             # elle ressurgit dans les rides
		position = _pending.emerge
		submerged = false
		if sprite:
			sprite.modulate.a = 1.0
		var zz := _zone()
		if zz:
			zz.burst(global_position, Color("d4f4ec"), 10, 30.0, true, Vector2(6, 1))
	if _pending.has("node") and is_instance_valid(_pending.node):
		_pending.node.queue_free()
	var z := _zone()
	var area: Dictionary = _pending.get("area", CombatRules.area_of(mv))
	if z:
		z.show_strike(global_position + Vector2(0, -6), area, _pending.dir, Color("f5b84a"))
	if _player_ok() and CombatRules.in_area(area, _pending.origin, _pending.dir,
			_player.global_position + Vector2(0, -4), _player.BODY_RADIUS):
		var raw := fighter.move_raw(mv) * CombatRules.ACTION_MONSTER_DAMAGE
		if float(mv.get("telegraph_seconds", 0.0)) > 0.0:
			raw *= CombatRules.ACTION_TELEGRAPH_POWER
		var r: Dictionary = _player.fighter.take_hit(raw, fighter)
		if z:
			z.report_hit(_player, r, self)
	elif float(mv.get("telegraph_seconds", 0.0)) > 0.0 and z and _player_ok():
		z.float_text(_player.global_position + Vector2(0, -26), "Évité !", Color("ece2cf"))
	_pending.recover_at = _t + (1.4 if temper == "swimmer" else 0.45)   # l'anguille reste en surface : c'est le moment de frapper
	state = "recover"


func _cancel_pending() -> void:
	if _pending.has("node") and is_instance_valid(_pending.node):
		_pending.node.queue_free()
	_pending = {}


## Une compétence de dégâts interrompt un coup annoncé dont la parade est « interruption ».
func interrupt_if(skill: Dictionary) -> void:
	if state == "windup" and _pending.move.get("avoidable_by") == "interruption":
		_cancel_pending()
		state = "chase"
		var z := _zone()
		if z:
			z.float_text(global_position + Vector2(0, -30), "Interrompu !", Color("ffe08a"))


## Appelé par la zone quand un coup du joueur nous touche.
func react(r: Dictionary, from: Vector2) -> void:
	_bar_t = 4.0
	queue_redraw()
	if not r.dodged:
		_flash()
		position += (global_position - from).normalized() * 3.0
	if not fighter.alive():
		_die()
		return
	_engage(0.15)


func _die() -> void:
	_cancel_pending()
	_alert.visible = false
	state = "dead"
	provoked = false
	remove_from_group("mobs")
	var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	if gs:
		gs.on_kill(template_id, fighter.level, fighter.role)
	var z := _zone()
	if z:
		z.drop_loot(global_position + Vector2(0, -6), _roll_loot())
	# la lumière de l'aube les quitte : figé blanc, puis grains dorés qui montent
	if _mat:
		_mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func():
		var zz := _zone()
		if zz and sprite:
			var w := sprite.texture.get_width() / float(sprite.hframes)
			zz.burst(global_position + Vector2(0, -sprite.texture.get_height() / 2.0), Color("ffe08a"), 18, 22.0, true,
				Vector2(w * 0.35, sprite.texture.get_height() * 0.3)))
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		visible = false
		if _mat:
			_mat.set_shader_parameter("flash", 0.0))
	get_tree().create_timer(respawn_seconds).timeout.connect(_respawn)


func _roll_loot() -> Array:
	var out := []
	var weighted := []
	for l in tpl.get("loot_table", []):
		if l.has("chance"):
			if randf() < float(l.chance) * CombatRules.ACTION_RARE_LOOT:
				out.append([l.item_id, randi_range(int(l.quantity_min), int(l.quantity_max))])
		else:
			weighted.append(l)
	if not weighted.is_empty():                       # toujours au moins un objet (butin garanti)
		var total := 0.0
		for l in weighted:
			total += float(l.get("weight", 1))
		var r := randf() * total
		for l in weighted:
			r -= float(l.get("weight", 1))
			if r <= 0.0:
				out.append([l.item_id, randi_range(int(l.quantity_min), int(l.quantity_max))])
				break
	return out


func _respawn() -> void:
	if not is_inside_tree():
		return
	submerged = false
	if sprite:
		sprite.modulate.a = 1.0
	position = _home
	fighter.setup(fighter.base, fighter.level)
	fighter.effects.clear()
	state = "wander"
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	add_to_group("mobs")
	queue_redraw()


# --------------------------------------------------------------------------- déplacement
func _wander(delta: float) -> bool:
	if temper == "sentinel":                      # le héron reste planté là, il surveille le lac
		return false
	if _wait > 0.0:
		_wait -= delta
		return false
	if not _walk_to(_goal, SPEED, delta):
		_wait = randf_range(1.2, 3.5)
		_goal = _clamp_home(_home + Vector2.from_angle(randf() * TAU) * randf() * leash)
		return false
	return true


func _walk_to(p: Vector2, spd: float, delta: float) -> bool:
	var d := p - position
	if d.length() < 1.5:
		return false
	position += d.normalized() * minf(spd * delta, d.length())
	if sprite and absf(d.x) > 0.5:
		sprite.flip_h = d.x < 0.0
	return true


func _clamp_home(p: Vector2) -> Vector2:
	return _home + (p - _home).limit_length(leash)


# --------------------------------------------------------------------------- rendu
func _animate(delta: float, moving: bool) -> void:
	if not sprite:
		return
	_anim_t += delta * (9.0 if moving else 2.5)
	if state == "windup":
		sprite.frame = 1                                # en arrêt, ramassé : il prépare son coup
		sprite.position.x = sin(_t * 40.0) * 0.6
		return
	sprite.position.x = 0.0
	# planche : 0-1 repos (1 = clignement, oreille, note figée), 2-5 cycle de déplacement
	sprite.frame = 2 + int(_anim_t) % 4 if moving else (1 if int(_anim_t) % 5 == 4 else 0)


func _flash() -> void:
	if not _mat:
		return
	_mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(func(v): _mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.14)


func _draw() -> void:
	# barre de PV au-dessus des bêtes blessées
	if state == "dead" or fighter.hp >= fighter.max_hp() or not sprite:
		return
	var w := 16.0
	var y := -sprite.texture.get_height() - 4.0
	draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 4), Color("2a1a2e"))
	draw_rect(Rect2(-w / 2, y, w, 2), Color("4a3450"))
	draw_rect(Rect2(-w / 2, y, w * fighter.hp / fighter.max_hp(), 2), Color("e05a48"))
