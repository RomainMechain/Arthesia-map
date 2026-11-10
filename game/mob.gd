extends Node2D
## Bête issue d'une Entry « monster » (template data/templates/monsters/<id>.json).
## Tempérament (déduit de la description, docs/combat_v1.md) :
##   calm      : fuit le joueur, ne riposte que si on la frappe (lapin, oiseau) ;
##   predator  : attaque quand on entre dans son rayon (loup) ;
##   skittish  : approche, mord, puis s'enfuit un moment (renardeau) ;
##   sentinel  : immobile à son poste (héron) ; swimmer : plonge et ressurgit (anguille) ;
##   charger   : fonce en ligne droite sur ses coups « charge » (sanglier) ;
##   ambusher  : presque invisible dans la lumière tant qu'on n'est pas tout près (lynx) ;
##   guardian  : lent, ne quitte pas son chemin (ours) ;
##   dormant   : passe pour un arbre mort jusqu'à ce qu'on l'approche (Veilleur d'écorce).
## `spawn_condition` : la bête n'apparaît qu'une fois la condition remplie (ex. 40 sangliers abattus).
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
## Condition d'apparition (data/zones : spawn.condition) ; vide = toujours là
@export var spawn_condition: Dictionary = {}

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
var _boss_music := false
## Créature marquée par l'aube (apparition rare, game/rare_spawner.gd) : plus forte, dorée, ne revient pas
var marked := false
var _glow_t := 0.0
var dormant := false                # endormie (Veilleur) : un arbre mort, jusqu'au réveil
var _waiting := false               # pas encore apparue (condition non remplie)
var _seen := false                  # déjà notée au bestiaire (cette vie de la scène)
var _cond_t := 0.0

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
	var old_alert := get_node_or_null("Alerte")
	if old_alert:                                  # copie d'une bête (créature marquée) : on repart de zéro
		old_alert.free()
	_alert = Sprite2D.new()                        # « ! » rouge : la bête t'a pris pour cible
	_alert.name = "Alerte"
	_alert.texture = UISkin.tex("marker_alert")
	_alert.position = Vector2(0, (sprite.offset.y if sprite else -16.0) - 8.0)
	_alert.visible = false
	add_child(_alert)
	if temper == "dormant":
		dormant = true
	if not spawn_condition.is_empty() and not marked:
		_waiting = true
		visible = false
		remove_from_group("mobs")


## Devient une créature marquée par l'aube : PV ×2,5, attaque ×1,4, défense ×1,2, un niveau de plus,
## rang « élite » (plus d'XP), plus grande, un halo doré et des grains de lumière. Elle chasse.
func make_marked() -> void:
	marked = true
	var st: Dictionary = fighter.base.duplicate()
	st.hp = float(st.get("hp", 50)) * 2.5
	st.atk = float(st.get("atk", 10)) * 1.4
	st.def = float(st.get("def", 5)) * 1.2
	fighter.role = "elite"
	fighter.setup(st, fighter.level + 1)
	fighter.display_name = "%s (aube figée)" % tpl.get("name", display_name)
	if name_label:
		name_label.text = "%s  niv. %d" % [fighter.display_name, fighter.level]
	if temper == "calm" or temper == "skittish":
		temper = "predator"
	aggro = maxf(aggro, 70.0)
	leash = maxf(leash, 64.0)
	scale = Vector2(1.2, 1.2)
	var p := CPUParticles2D.new()
	p.name = "LueurMarque"
	p.amount = 10
	p.lifetime = 1.4
	p.position = Vector2(0, -10)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(9, 7)
	p.direction = Vector2(0, -1)
	p.spread = 30.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 11.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.55, 1.0))
	g.set_color(1, Color(1.0, 0.9, 0.55, 0.0))
	p.color_ramp = g
	add_child(p)


func is_alive() -> bool:
	return state != "dead"


func _zone() -> Node:
	return get_tree().get_first_node_in_group("zone")


func _player_ok() -> bool:
	return is_instance_valid(_player) and not _player.is_down()


func _process(delta: float) -> void:
	if state == "dead":
		return
	if _waiting:                                     # apparition conditionnelle : vérifiée toutes les 2 s
		_cond_t -= delta
		if _cond_t <= 0.0:
			_cond_t = 2.0
			var gsw := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
			if gsw and gsw.eval_condition(spawn_condition):
				_waiting = false
				visible = true
				add_to_group("mobs")
				modulate.a = 0.0
				create_tween().tween_property(self, "modulate:a", 1.0, 1.5)
		return
	_t += delta
	fighter.tick(delta)
	var to_p := (_player.global_position - global_position) if is_instance_valid(_player) else Vector2.INF
	var dist := to_p.length()
	if name_label:
		name_label.visible = dist < 40.0 and not provoked           # en combat : le cadre de cible du HUD
	if dist < 90.0 and not _seen and not dormant and not submerged and (temper != "ambusher" or provoked):  # bestiaire : croisée
		_seen = true
		var gss := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
		if gss:
			gss.see_monster(template_id)
	_bar_t = maxf(0.0, _bar_t - delta)
	if _alert_t > 0.0:
		_alert_t -= delta
		var k := clampf(1.0 - _alert_t / 0.9, 0.0, 1.0)
		_alert.scale = Vector2.ONE * (1.0 + 0.4 * maxf(0.0, 1.0 - k * 5.0))   # petit « pop »
		_alert.position.y = (sprite.offset.y if sprite else -16.0) - 8.0 - roundf(minf(k * 12.0, 2.0))
		_alert.visible = _alert_t > 0.0

	if dormant:                                      # un chêne mort parmi d'autres… jusqu'à ce qu'on approche
		if _player_ok() and dist < aggro:
			_wake()
		elif sprite:
			sprite.frame = 1 if fmod(_t, 7.0) > 6.6 else 0
			return
	if temper == "ambusher" and sprite:              # le lynx se fond dans la lumière
		var target_a := 1.0 if provoked or dist < aggro * 1.15 else 0.16
		sprite.modulate.a = move_toward(sprite.modulate.a, target_a, delta * (4.0 if target_a > 0.5 else 0.8))
	# déclencheurs d'engagement
	if not provoked and _player_ok():
		if temper in ["predator", "sentinel", "swimmer", "charger", "ambusher", "guardian"] and dist < aggro:
			_engage(0.15 if temper == "ambusher" else ALERT_PAUSE)
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
	Sfx.play("alert", -4.0)
	if fighter.role == "boss" and not _boss_music:
		_boss_music = true
		Sfx.push_mood("boss")
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


## Le Veilleur se réveille : l'écorce craque, les lignes cyan s'allument, il se déplie.
func _wake() -> void:
	dormant = false
	temper = "predator"
	Sfx.play("telegraph")
	var z := _zone()
	if z:
		z.burst(global_position + Vector2(0, -20), Color("948672"), 16, 30.0, true, Vector2(10, 14))
		z.burst(global_position + Vector2(0, -24), Color("5ae8e0"), 8, 18.0, true, Vector2(4, 8))
	var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	if gs:
		gs.notice.emit("Le chêne mort se déplie dans un craquement de bois sec…")
	_engage(0.9)


## Vitesse selon le tempérament (l'ours gardien est lent).
func _speed_k() -> float:
	return 0.6 if temper == "guardian" else 1.0


func _end_boss_music() -> void:
	if _boss_music:
		_boss_music = false
		Sfx.pop_mood("boss")


func _disengage() -> void:
	_end_boss_music()
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
		return _walk_to(_player.global_position - to_p.normalized() * (reach * 0.6), SPEED * 2.3 * _speed_k(), delta)
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
		Sfx.play("telegraph", -5.0)
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
	Sfx.play("dive", -4.0)
	if sprite:                                        # rides seules, à demi effacées
		sprite.modulate.a = 0.75
	_pending = {"move": mv, "dir": Vector2.RIGHT, "origin": emerge, "resolve_at": _t + tele, "area": area, "emerge": local}
	var z := _zone()
	if z:
		_pending.node = z.show_telegraph(emerge + Vector2(0, 4), area, Vector2.RIGHT, tele)
		z.burst(global_position, Color("d4f4ec"), 6, 16.0, false, Vector2(4, 1))
	state = "dive"


func _resolve_pending() -> void:
	var mv: Dictionary = _pending.move
	if state == "dive":                             # elle ressurgit dans les rides
		Sfx.play("splash")
		position = _pending.emerge
		submerged = false
		if sprite:
			sprite.modulate.a = 1.0
		var zz := _zone()
		if zz:
			zz.burst(global_position, Color("d4f4ec"), 10, 30.0, true, Vector2(6, 1))
	if _pending.has("node") and is_instance_valid(_pending.node):
		_pending.node.queue_free()
	if mv.get("charge", false) and state != "dive":
		var reach := float(CombatRules.area_of(mv).get("range", 60)) * 0.85
		var to: Vector2 = global_position + _pending.dir * reach
		var local_to: Vector2 = get_parent().to_local(to) if get_parent() else to
		local_to = _home + (local_to - _home).limit_length(leash * 2.5)
		create_tween().tween_property(self, "position", local_to, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		Sfx.play("swing_heavy", -2.0)
		var zc := _zone()
		if zc:
			zc.burst(global_position, Color("d4a265"), 8, 20.0, false, Vector2(5, 1))
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
		Sfx.play("dodge", -7.0)
	_pending.strike_until = _t + (0.45 if temper == "swimmer" else 0.22)
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
	if dormant:
		_wake()
		return
	_engage(0.15)


func _die() -> void:
	_end_boss_music()
	Sfx.play("mob_death")
	_cancel_pending()
	_alert.visible = false
	state = "dead"
	provoked = false
	remove_from_group("mobs")
	var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	if gs:
		gs.on_kill(template_id, fighter.level, fighter.role)
		if marked:
			gs.on_marked_kill()
	var z := _zone()
	if z:
		var loot := _roll_loot()
		if marked:                                   # l'éclat d'aube figée, et le butin en double
			loot = loot + _roll_loot()
			loot.append(["eclat_d_aube_fige", 1])
		z.drop_loot(global_position + Vector2(0, -6), loot)
		if gs:
			for l in loot:
				gs.see_loot(template_id, str(l[0]))
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
	if marked:                                       # une créature marquée ne revient pas
		get_tree().create_timer(1.0).timeout.connect(queue_free)
		return
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
	if marked and state != "dead":
		_glow_t += delta
		var k := 0.5 + 0.5 * sin(_glow_t * 3.0)
		sprite.self_modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.86, 0.45), 0.25 + 0.35 * k)
		queue_redraw()
	_anim_t += delta * (9.0 if moving else 2.5)
	# planche : 0-1 repos (1 = clignement, oreille, note figée), 2-5 déplacement, 6 élan, 7 frappe
	var has_attack := sprite.hframes >= 8
	if state == "windup":
		sprite.frame = 6 if has_attack else 1          # ramassé : il prépare son coup
		sprite.position.x = sin(_t * 40.0) * 0.6
		return
	if state == "dive":
		sprite.frame = 6 if has_attack else 0          # sous l'eau : on ne voit que des rides
		return
	sprite.position.x = 0.0
	if state == "recover" and has_attack and _t < float(_pending.get("strike_until", 0.0)):
		sprite.frame = 7                                # la frappe, tenue un instant
		return
	sprite.frame = 2 + int(_anim_t) % 4 if moving else (1 if int(_anim_t) % 5 == 4 else 0)


func _flash() -> void:
	if not _mat:
		return
	_mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(func(v): _mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.14)


func _draw() -> void:
	if marked and state != "dead":                   # halo d'aube au sol, qui respire
		var k := 0.5 + 0.5 * sin(_glow_t * 3.0)
		draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.45))
		for i in 3:
			draw_circle(Vector2.ZERO, 16.0 + i * 5.0 + k * 3.0, Color(1.0, 0.85, 0.4, (0.34 - i * 0.09) * (0.6 + 0.4 * k)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# barre de PV au-dessus des bêtes blessées
	if state == "dead" or fighter.hp >= fighter.max_hp() or not sprite:
		return
	var w := 16.0
	var y := -sprite.texture.get_height() - 4.0
	draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 4), Color("2a1a2e"))
	draw_rect(Rect2(-w / 2, y, w, 2), Color("4a3450"))
	draw_rect(Rect2(-w / 2, y, w * fighter.hp / fighter.max_hp(), 2), Color("e05a48"))
