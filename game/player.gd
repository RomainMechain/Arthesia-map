extends CharacterBody2D
## Joueur : déplacement (clavier ZQSD/flèches ou toucher), 8 directions, attaque à mains nues,
## compétences de la barre. Combat « action libre » (docs/combat_v1.md) : chaque coup part vers le
## regard, avec une aide à la visée vers la bête la plus proche dans le cône.
## Les règles (dégâts, recharges, mana) viennent de CombatRules / Fighter, l'état de GameState.

signal defeated

const SPEED := 80.0
const ARRIVE_DIST := 3.0
const BODY_RADIUS := 5.0
## mains nues : petit arc devant soi (l'arme équipée le remplacera)
const FIST_AREA := {"shape": "arc", "range": 22, "angle": 100}
const DIRS := ["S", "SE", "E", "NE", "N"]
# colonnes de la planche player_8dir.png
const F_IDLE := 0
const F_WALK := 2
const F_ATTACK := 6
const F_HURT := 9
const F_KO := 10

@onready var sprite: Sprite2D = $Sprite
@onready var camera: Camera2D = $Camera2D

var fighter: Fighter
var facing := Vector2.DOWN
var speed_mult := 1.0              # < 1 dans l'eau des hauts-fonds
var _target: Variant = null   # Vector2 ou null
var _anim_t := 0.0
var _act := ""                # "", "attack", "hurt", "ko"
var _act_t := 0.0
var _mat: ShaderMaterial
## Équipement visible : un calque par emplacement, teinté selon la matière (game/equip_look.gd)
const EQUIP_SLOTS := ["boots", "chest", "gloves", "head", "weapon"]
var _layers := {}
var _motes: CPUParticles2D
var _step_t := 0.0


func _ready() -> void:
	_add_keys("ui_up", [KEY_W, KEY_Z])
	_add_keys("ui_down", [KEY_S])
	_add_keys("ui_left", [KEY_A, KEY_Q])
	_add_keys("ui_right", [KEY_D])
	add_to_group("player")
	var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	fighter = gs.fighter if gs else Fighter.new()
	if fighter.base.is_empty():
		fighter.setup(CombatRules.BASE_STATS, 1)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://game/fx/flash.gdshader")
	sprite.material = _mat
	fighter.hp_changed.connect(_on_hp_changed)
	_build_layers()
	if gs:
		gs.profile_changed.connect(refresh_equipment)
	refresh_equipment()


func _exit_tree() -> void:
	if fighter and fighter.hp_changed.is_connected(_on_hp_changed):
		fighter.hp_changed.disconnect(_on_hp_changed)
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.profile_changed.is_connected(refresh_equipment):
		gs.profile_changed.disconnect(refresh_equipment)


# --------------------------------------------------------------------------- équipement visible
func _build_layers() -> void:
	var shader: Shader = load("res://game/fx/equip_tint.gdshader")
	for slot in EQUIP_SLOTS:
		var l := Sprite2D.new()
		l.name = "Equip_" + slot
		l.centered = false
		l.hframes = 12
		l.vframes = 5
		l.offset = sprite.offset - (Vector2(8, 6) if slot == "weapon" else Vector2.ZERO)
		l.position = sprite.position
		var m := ShaderMaterial.new()
		m.shader = shader
		l.material = m
		l.visible = false
		add_child(l)
		_layers[slot] = l
	_motes = CPUParticles2D.new()                   # légendaire : quelques grains de lumière
	_motes.name = "Lueur"
	_motes.emitting = false
	_motes.amount = 6
	_motes.lifetime = 1.2
	_motes.position = Vector2(0, -12)
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = Vector2(7, 9)
	_motes.direction = Vector2(0, -1)
	_motes.spread = 25.0
	_motes.gravity = Vector2.ZERO
	_motes.initial_velocity_min = 4.0
	_motes.initial_velocity_max = 9.0
	_motes.scale_amount_min = 1.0
	_motes.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.92, 0.6, 0.9))
	g.set_color(1, Color(1.0, 0.92, 0.6, 0.0))
	_motes.color_ramp = g
	add_child(_motes)
	_sync_layers()


## Relit l'équipement porté : forme, matière, lueur de rareté.
func refresh_equipment() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null or _layers.is_empty():
		return
	var legendary := false
	for slot in EQUIP_SLOTS:
		var l: Sprite2D = _layers[slot]
		var id: String = gs.equipped(slot)
		var t: Dictionary = gs.tpl("items", id) if id != "" else {}
		var tex: Texture2D = EquipLook.texture(EquipLook.shape(slot, t)) if not t.is_empty() else null
		l.visible = tex != null
		if tex == null:
			continue
		l.texture = tex
		var r: Array = EquipLook.ramp(id, t, UISkin.item_icon(id))
		var m := l.material as ShaderMaterial
		m.set_shader_parameter("light", r[0])
		m.set_shader_parameter("mid", r[1])
		m.set_shader_parameter("dark", r[2])
		var rank: String = gs.item_rank(id)
		var ri := CraftRules.rank_index(rank)
		var g := 0.0 if ri < 2 else (0.55 if ri == 2 else 0.8)
		m.set_shader_parameter("glow", g if slot == "weapon" else 0.0)      # contour : l'arme seulement
		m.set_shader_parameter("shine", 0.0 if slot == "weapon" else g)
		m.set_shader_parameter("pulse", 1.0 if ri >= 3 else 0.0)
		m.set_shader_parameter("glow_color", Color(CraftRules.RANK_COLORS[rank]))
		legendary = legendary or ri >= 4
	_motes.emitting = legendary
	_sync_layers()


func _sync_layers() -> void:
	if _layers.is_empty():
		return
	for slot in _layers:
		var l: Sprite2D = _layers[slot]
		if l.texture == null:
			continue
		l.frame_coords = sprite.frame_coords
		l.flip_h = sprite.flip_h
		l.position = sprite.position                     # les gestes des compétences
		l.scale = sprite.scale
		l.modulate.a = sprite.modulate.a
	# dos tourné (haut, haut-côté) : l'arme passe derrière le corps
	var w: Sprite2D = _layers.weapon
	var behind := sprite.frame_coords.y >= 3 and sprite.frame_coords.x < 10
	if behind != (w.get_index() < sprite.get_index()):
		move_child(w, sprite.get_index())          # juste avant ou juste après le corps


func is_down() -> bool:
	return _act == "ko"


func move_to(world_pos: Vector2) -> void:
	if not is_down():
		_target = world_pos


func stop() -> void:
	_target = null


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if not is_down():
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if dir != Vector2.ZERO:
			_target = null
		elif _target != null:
			var to: Vector2 = _target - global_position
			if to.length() > ARRIVE_DIST:
				dir = to.normalized()
			else:
				_target = null
	var spd := SPEED * (0.35 if _act == "attack" else 1.0) * speed_mult     # on s'engage dans son coup
	velocity = dir * spd
	move_and_slide()
	if dir != Vector2.ZERO and get_real_velocity().length() > SPEED * 0.3:   # pas : discrets
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.31 / maxf(speed_mult, 0.5)
			Sfx.play("step_water" if speed_mult < 1.0 else "step", -9.0, 0.12)
	else:
		_step_t = 0.0
	if _target != null and get_real_velocity().length() < SPEED * 0.15 and get_slide_collision_count() > 0:
		_target = null
	if dir != Vector2.ZERO and _act != "attack":
		facing = dir.normalized()
	_animate(delta, dir != Vector2.ZERO)
	_patience(delta, dir != Vector2.ZERO)
	queue_redraw()


## Portée de l'arme, dessinée discrètement au sol quand une bête hostile approche.
func _draw() -> void:
	if is_down():
		return
	var near := false
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.provoked and m.is_alive() and m.global_position.distance_to(global_position) < 72.0:
			near = true
			break
	if not near:
		return
	var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	var area: Dictionary = gs.weapon_area() if gs else FIST_AREA
	var o := Vector2(0, -4)
	var col := Color("fff4d6", 0.28)
	if area.get("shape") == "line":
		var L := float(area.get("range", 40))
		draw_line(o, o + facing * L, col, 1.0)
		return
	var r := float(area.get("range", 22))
	var half := deg_to_rad(float(area.get("angle", 100)) / 2.0)
	var a := facing.angle()
	draw_arc(o, r, a - half, a + half, 14, col, 1.0)
	draw_line(o + Vector2.from_angle(a - half) * (r - 4), o + Vector2.from_angle(a - half) * r, col, 1.0)
	draw_line(o + Vector2.from_angle(a + half) * (r - 4), o + Vector2.from_angle(a + half) * r, col, 1.0)


# --------------------------------------------------------------------------- combat
func _zone() -> Node:
	return get_tree().get_first_node_in_group("zone")


func _mob_positions() -> Array:
	return get_tree().get_nodes_in_group("mobs").filter(func(m): return m.is_alive() and not m.submerged).map(func(m): return m.global_position)


func _aim(aim: Vector2, area: Dictionary) -> Vector2:
	var d := aim.normalized() if aim != Vector2.ZERO else facing
	return CombatRules.assisted_dir(global_position, d, _mob_positions(), CombatRules.area_reach(area))


## Attaque de base (un tap = un coup). `aim` : direction voulue (souris) ou ZERO = regard.
func attack(aim := Vector2.ZERO) -> bool:
	if is_down() or not fighter.ready("basic"):
		return false
	var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	var area: Dictionary = gs.weapon_area() if gs else FIST_AREA
	var weapon: String = gs.equipped("weapon") if gs else ""
	var d := _aim(aim, area)
	facing = d
	fighter.start_cooldown("basic", fighter.attack_cooldown())
	_start_act("attack", 0.24)
	_strike(area, d, func(): return fighter.basic_attack_raw(), {"weapon": weapon})
	return true


## Compétence de l'emplacement `slot` (0-3). Renvoie "" si lancée, sinon la raison du refus.
func cast(slot: int, aim := Vector2.ZERO) -> String:
	var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	if gs == null or is_down():
		return "indisponible"
	var sid: String = gs.profile.bar[slot]
	if sid == "":
		return "emplacement vide"
	var sk: Dictionary = gs.tpl("skills", sid)
	if not fighter.ready(sid):
		return "pas encore prête"
	if fighter.mana < float(sk.get("mana_cost", 0)):
		return "pas assez de mana"
	fighter.mana -= float(sk.get("mana_cost", 0))
	fighter.start_cooldown(sid, float(sk.get("cooldown_seconds", 6)))
	var area: Dictionary = CombatRules.area_of(sk)
	var d := _aim(aim, area)
	facing = d
	_start_act("attack", 0.28)
	var z := _zone()
	var own_fx := SkillFx.has(sid)                       # animation propre (game/combat/skill_fx.gd)
	if own_fx:
		SkillFx.play(sid, self, z, area, d, _targets(area, d))
	var delay := SkillFx.impact_delay(sid)               # le coup porte avec l'animation
	for e in sk.get("effects", []):
		match e.type:
			"damage":
				var raw_fn := func(): return float(e.get("base", 0)) + float(e.get("power", 0)) * fighter.skill_stat(sk.get("damage_type", "physical"))
				var opts := {"skill": sk, "no_fx": own_fx, "debuffs": sk.get("effects", []).filter(func(x): return x.type == "debuff")}
				if delay > 0.0:
					get_tree().create_timer(delay).timeout.connect(func():
						if is_instance_valid(self) and not is_down():
							_strike(area, facing if facing != Vector2.ZERO else d, raw_fn, opts))
				else:
					_strike(area, d, raw_fn, opts)
			"heal":
				var amount := fighter.heal(float(e.get("base", 0)) + float(e.get("power", 0)) * fighter.stat("sag"))
				if z:
					z.float_text(global_position + Vector2(0, -22), "+%d" % roundi(amount), Color("a8c84e"))
					if not own_fx:
						z.show_strike(global_position, {"shape": "self"}, d, Color("a8c84e"))
			"shield":
				var st := "atk" if sk.get("damage_type") == "physical" else "sag"
				var amount := float(e.get("base", 0)) + float(e.get("amount_power", 0)) * fighter.stat(st)
				fighter.shield = maxf(fighter.shield, amount)
				fighter.shield_expires_at = Fighter.now() + float(e.get("duration_seconds", 10))
			"buff":
				if e.get("target", "self") == "self":
					fighter.add_effect(sid, sk.get("name", sid), e.stat, float(e.get("duration_seconds", 10)), float(e.get("amount_percent", 0)))
	return ""


## Bêtes dans la zone du coup (une ligne ne touche que la première).
func _targets(area: Dictionary, d: Vector2) -> Array:
	var origin := global_position + Vector2(0, -4)
	var hits := []
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.is_alive() and not m.submerged and CombatRules.in_area(area, origin, d, m.global_position + Vector2(0, -4), m.body_radius):
			hits.append(m)
	if area.get("shape") == "line" and hits.size() > 1:
		hits.sort_custom(func(a, b): return (a.global_position - origin).dot(d) < (b.global_position - origin).dot(d))
		hits = [hits[0]]
	return hits


## Résout un coup sur toutes les bêtes dans la zone (une ligne ne touche que la première).
func _strike(area: Dictionary, d: Vector2, raw_fn: Callable, opts: Dictionary) -> Array:
	var z := _zone()
	if not opts.get("no_fx", false):
		Sfx.play("swing_heavy" if opts.has("skill") else "swing", -8.0)
	if z and not opts.get("no_fx", false):
		z.show_strike(global_position + Vector2(0, -8), area, d,
			Color("ffe08a") if opts.has("skill") else Color("fff4d6"), UISkin.item_icon(opts.get("weapon", "")) if opts.get("weapon", "") != "" else null)
	var hits := _targets(area, d)
	for m in hits:
		var r: Dictionary = m.fighter.take_hit(raw_fn.call(), fighter)
		if opts.has("skill"):
			m.interrupt_if(opts.skill)
			for db in opts.get("debuffs", []):
				m.fighter.add_effect(opts.skill.id, opts.skill.get("name", ""), db.stat, float(db.get("duration_seconds", 8)), -absf(float(db.get("amount_percent", 10))))
		if z:
			z.report_hit(m, r, self)
	return hits


## Appelé par la zone quand on encaisse un coup.
func react(r: Dictionary, from: Vector2) -> void:
	var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	if r.dodged:
		if gs and gs.has_skill("instinct_de_traqueuse") and _passive_ready("instinct", 0.8):
			SkillFx.passive("instinct_de_traqueuse", self, _zone())
		return
	_flash()
	if float(r.get("absorbed", 0.0)) > 0.0:
		SkillFx.glance(self, _zone(), from)                # le coup glisse sur la carapace / les facettes
	elif gs and gs.has_skill("peau_d_ambre") and _passive_ready("ambre", 0.6):
		SkillFx.passive("peau_d_ambre", self, _zone(), {"from": from})
	if gs and gs.has_skill("matin_d_halvard") and fighter.alive() and fighter.hp < fighter.max_hp() * 0.25 \
			and _passive_ready("halvard", 90.0):              # tenir encore un instant (une fois toutes les 90 s)
		var sk: Dictionary = gs.tpl("skills", "matin_d_halvard")
		for e in sk.get("effects", []):
			if e.get("type") == "shield":
				fighter.shield = maxf(fighter.shield, float(e.get("base", 0)) + float(e.get("amount_power", 0)) * fighter.stat("sag"))
				fighter.shield_expires_at = Fighter.now() + float(e.get("duration_seconds", 10))
		SkillFx.passive("matin_d_halvard", self, _zone())
	if gs and gs.settings.get("vibrate", true) and OS.has_feature("mobile"):
		Input.vibrate_handheld(35)
	if not fighter.alive():
		if _act == "ko":
			return                                     # déjà à terre : la défaite n'est déclenchée qu'une fois
		_start_act("ko", 999.0)
		_target = null
		defeated.emit()
		return
	if _act != "attack":
		_start_act("hurt", 0.18)
	var push := (global_position - from).normalized() * 3.0
	move_and_collide(push)


func revive() -> void:
	_act = ""
	_act_t = 0.0


func _on_hp_changed(_hp: float, _max: float) -> void:
	pass


func _flash() -> void:
	_mat.set_shader_parameter("flash", 1.0)
	for l in _layers.values():
		(l.material as ShaderMaterial).set_shader_parameter("flash", 1.0)
		var lm := l.material as ShaderMaterial
		create_tween().tween_method(func(v): lm.set_shader_parameter("flash", v), 1.0, 0.0, 0.14)
	var tw := create_tween()
	tw.tween_method(func(v): _mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.14)


# --------------------------------------------------------------------------- passives
var _passive_at := {}
var _still_t := 0.0


func _passive_ready(key: String, gap: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_passive_at.get(key, -999.0)) < gap:
		return false
	_passive_at[key] = now
	return true


## Patience du pêcheur : immobile, hors combat, des ronds dans l'eau à ses pieds.
func _patience(delta: float, moving: bool) -> void:
	var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	if moving or gs == null or not gs.has_skill("patience_du_pecheur") or Fighter.now() - fighter.last_combat_at < 5.0:
		_still_t = 0.0
		return
	_still_t += delta
	if _still_t > 3.0:
		_still_t = 0.4
		SkillFx.passive("patience_du_pecheur", self, _zone())


# --------------------------------------------------------------------------- poses (compétences)
var _sprite_pos = null                # position de repos du sprite (les calques d'équipement suivent)
var _pose_tw: Tween
var _shake_tw: Tween


## Geste : le sprite glisse de `off` et se déforme (`sc`) en `t_in`, puis revient en `t_out`
## (0 : il reste, un autre geste prendra le relais). Visuel seulement : le corps ne bouge pas.
func pose(off: Vector2, sc: Vector2, t_in: float, t_out: float) -> void:
	if sprite == null:
		return
	if _sprite_pos == null:
		_sprite_pos = sprite.position
	if _pose_tw:
		_pose_tw.kill()
	_pose_tw = create_tween().set_parallel(true)
	_pose_tw.tween_property(sprite, "position", (_sprite_pos as Vector2) + off.round(), t_in)
	_pose_tw.tween_property(sprite, "scale", sc, t_in)
	if t_out > 0.0:
		_pose_tw.chain().tween_property(sprite, "position", _sprite_pos, t_out)
		_pose_tw.parallel().tween_property(sprite, "scale", Vector2.ONE, t_out)


## Petite secousse de la caméra.
func shake(amount: float, seconds: float) -> void:
	if camera == null:
		return
	if _shake_tw:
		_shake_tw.kill()
	_shake_tw = create_tween()
	_shake_tw.tween_method(func(k: float):
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * amount * (1.0 - k), 0.0, 1.0, seconds)
	_shake_tw.tween_callback(func(): camera.offset = Vector2.ZERO)


# --------------------------------------------------------------------------- animation
func _start_act(kind: String, seconds: float) -> void:
	_act = kind
	_act_t = seconds
	_anim_t = 0.0


func _dir_row() -> Array:
	var a := wrapf(rad_to_deg(facing.angle()), -180.0, 180.0)   # 0 = droite, 90 = bas
	var sector := wrapi(int(round(a / 45.0)), 0, 8)              # 0 E, 1 SE, 2 S, 3 SO, 4 O, 5 NO, 6 N, 7 NE
	var table := [[2, false], [1, false], [0, false], [1, true], [2, true], [3, true], [4, false], [3, false]]
	return table[sector]


func _animate(delta: float, moving: bool) -> void:
	if sprite.vframes < 5:                               # ancienne planche (4 images de face)
		_anim_t += delta * (8.0 if moving else 3.0)
		sprite.frame = int(_anim_t) % sprite.hframes
		return
	var rf: Array = _dir_row()
	sprite.flip_h = rf[1]
	var col := F_IDLE
	_anim_t += delta
	if _act != "":
		_act_t -= delta
		match _act:
			"attack":
				col = F_ATTACK + mini(int(_anim_t / 0.08), 2)
			"hurt":
				col = F_HURT
			"ko":
				col = F_KO + (1 if _anim_t > 0.35 else 0)
				sprite.flip_h = false
				sprite.frame_coords = Vector2i(col, 0)
				_sync_layers()
				return
		if _act_t <= 0.0:
			_act = ""
	elif moving:
		col = F_WALK + int(_anim_t * 8.0) % 4
	else:
		col = F_IDLE + (1 if fmod(_anim_t, 1.6) > 0.8 else 0)
	sprite.frame_coords = Vector2i(col, rf[0])
	_sync_layers()


func _add_keys(action: StringName, keys: Array) -> void:
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)
