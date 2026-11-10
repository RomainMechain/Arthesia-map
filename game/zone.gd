extends Node2D
## Racine d'une zone construite par tools/godot/build_zone.gd.
## Entrées : PC  -> ZQSD/flèches bouger, clic gauche attaquer vers la souris, 1-4 compétences, F soin,
##                  E ou Entrée parler, clic droit aller à, Tab Carnet.
##           mobile -> toucher le sol pour aller, toucher un PNJ proche pour parler,
##                  boutons d'attaque et de compétences du HUD.
## Affiche aussi les retours de combat (chiffres, traces, télégraphes, butin).

@export var zone_id := ""
@export var zone_name := ""
@export var floor_id := "floor_1"
@export var zone_type := "town"
## Hauts-fonds praticables : polygones (px) où le joueur est ralenti et fait des éclaboussures
@export var slow_polys: Array = []
## Image de la mini-carte (1 px par tuile), générée par tools/zone/compile_zone.py
@export var minimap_path := ""
## Humeur musicale imposée par la zone (« tension »…) ; vide = selon le type de zone
@export var music_mood := ""

var _splash_t := 0.0
var rare_spawner: Node = null
var _defeat_pending := false

const TAP_RADIUS := 16.0

var player: CharacterBody2D
var hud: CanvasLayer
var _nearest: Node2D = null
var _pending: Node2D = null
var _ui: CanvasLayer
var _dialog: Control                 # game/ui/dialog_box.gd
var _dialog_it: Node2D
var _welcome := false                # l'accueil d'Yvenne est en cours (l'accueil avance à la fermeture)
var _toast: Label
var _toast_t := 0.0
var _fx: Node2D
var _ground: Node2D
var _gather: Node2D = null          # ressource en cours de récolte
var _gather_t := 0.0
var _gather_hit := 0.0
var _gather_bar: Node2D


func _ready() -> void:
	add_to_group("zone")
	player = get_tree().get_first_node_in_group("player")
	_fx = get_node_or_null("Effets")
	_ground = get_node_or_null("DecorSol")
	_build_ui()
	var gs := _game_state()
	for ex in find_children("*", "Area2D", true, false):
		if ex.has_signal("exit_reached"):
			ex.exit_reached.connect(_on_exit)
			# on revient d'une zone voisine : apparaître devant la sortie qui y mène
			if gs and gs.arrival_from != "" and ex.target_zone == gs.arrival_from:
				player.global_position = ex.arrival
	if gs:
		gs.arrival_from = ""
		gs.floor_id = floor_id
		gs.enter_zone(zone_id, zone_type)
		Sfx.enter_zone(zone_id, zone_type, music_mood)
	if zone_type in ["wilderness", "water", "danger", "ruins"]:   # apparitions rares : zones de combat
		rare_spawner = (load("res://game/rare_spawner.gd") as GDScript).new()
		rare_spawner.name = "ApparitionsRares"
		rare_spawner.zone = self
		add_child(rare_spawner)
		gs.notice.connect(_on_notice)
		gs.quest_changed.connect(_on_quest_changed)
		gs.title_unlocked.connect(_on_title)
		gs.leveled_up.connect(_on_level)
		gs.profile_changed.connect(_refresh_markers)
	player.defeated.connect(_on_defeated)
	player.get_node("Camera2D").reset_smoothing.call_deferred()
	hud = (load("res://game/ui/hud.gd") as GDScript).new()
	hud.name = "HUD"
	add_child(hud)
	var amb: Node = (load("res://game/fx/ambience.gd") as GDScript).new()   # aube éternelle
	amb.name = "AmbianceAube"
	add_child(amb)
	amb.setup(self, player, zone_type)
	_refresh_markers()
	toast(zone_name, 2.5)


func _exit_tree() -> void:
	var gs := _game_state()
	if gs:
		for pair in [[gs.notice, _on_notice], [gs.quest_changed, _on_quest_changed], [gs.profile_changed, _refresh_markers],
				[gs.title_unlocked, _on_title], [gs.leveled_up, _on_level]]:
			if (pair[0] as Signal).is_connected(pair[1]):
				(pair[0] as Signal).disconnect(pair[1])


func _game_state() -> Node:
	return (get_node_or_null("/root/GameState") if is_inside_tree() else null)


func _process(delta: float) -> void:
	if _dialog.visible and is_instance_valid(_dialog_it) \
			and _dialog_it.global_position.distance_to(player.global_position) > 72.0:
		_dialog.close()                                    # on s'est éloigné : la conversation s'arrête
	var best: Node2D = null
	var best_d := INF
	for it in get_tree().get_nodes_in_group("interactables"):
		var d: float = it.global_position.distance_to(player.global_position)
		if d < it.INTERACT_RADIUS and d < best_d:
			best = it
			best_d = d
	if best != _nearest:
		if _nearest:
			_nearest.set_highlight(false)
		if best:
			best.set_highlight(true)
			var gs0 := _game_state()
			if gs0:
				if best.has_method("harvest"):
					gs0.show_hint("resource")
				elif best.marker and best.marker.text == "!" and best.marker.modulate.a > 0.5:
					gs0.show_hint("quest")
		_nearest = best
	if _nearest and _nearest.get("_prompt"):         # l'invite disparaît pendant la conversation
		_nearest._prompt.visible = not _dialog.visible
	if _pending and _pending == _nearest:
		player.stop()
		_open(_pending)
		_pending = null
	if _gather:
		_update_gather(delta)
	_update_water(delta)
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast_box.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
		_toast_box.visible = _toast_t > 0.0


func _world(screen: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen


func _mouse_aim() -> Vector2:
	return get_global_mouse_position() - (player.global_position + Vector2(0, -8))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.physical_keycode
		if k >= KEY_1 and k <= KEY_4:
			_cast(k - KEY_1, _mouse_aim())
			get_viewport().set_input_as_handled()
			return
		if k == KEY_E:
			_talk_or_close()
			get_viewport().set_input_as_handled()
			return
		if k == KEY_F or k == KEY_5:
			hud.use_potion()
			get_viewport().set_input_as_handled()
			return
		if k == KEY_ESCAPE:
			if _dialog.visible:
				_dialog.close()
				get_viewport().set_input_as_handled()
				return
			hud.toggle_menu()
			get_viewport().set_input_as_handled()
			return
		if k == KEY_M:
			hud.toggle_map()
			get_viewport().set_input_as_handled()
			return
		if k == KEY_TAB:
			hud.toggle_carnet()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_accept"):
		if _dialog.visible or _nearest:
			_talk_or_close()
		else:
			player.attack()                                     # clavier seul : frappe vers le regard
		get_viewport().set_input_as_handled()
		return

	# --- souris (PC) : clic gauche = attaque vers la souris (ou parler si on clique un PNJ)
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return                                                  # souris émulée depuis le toucher : ignorée
	if event is InputEventMouseButton and event.pressed:
		if _dialog.visible:
			return                                          # la boîte gère ses clics ; ailleurs, rien

		var world := _world(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			var it := _interactable_at(world)
			if it and it == _nearest:
				_open(it)
			elif it:
				_pending = it
				player.move_to(it.global_position)
			else:
				player.attack(_mouse_aim())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			player.move_to(world)
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		player.move_to(_world(event.position))
		return

	# --- toucher (mobile) : déplacement, PNJ
	var pressed: bool = event is InputEventScreenTouch and event.pressed
	if not (pressed or event is InputEventScreenDrag):
		return
	if hud and hud.blocks(event.position):
		return
	if _dialog.visible:
		return                                              # la boîte gère ses touchers
	var w := _world(event.position)
	if pressed:
		_pending = _interactable_at(w)
		if _pending and _pending == _nearest:
			_open(_pending)
			_pending = null
			return
	player.move_to(w)


func _cast(slot: int, aim := Vector2.ZERO) -> void:
	var why: String = player.cast(slot, aim)
	if why != "" and why != "emplacement vide" and hud:
		hud.flash_slot(slot, why)


func _talk_or_close() -> void:
	if _dialog.visible:
		_dialog.advance()
	elif _nearest:
		_open(_nearest)


func _interactable_at(world: Vector2) -> Node2D:
	for it in get_tree().get_nodes_in_group("interactables"):
		if (it.global_position + Vector2(0, -10)).distance_to(world) < TAP_RADIUS:
			return it
	return null


func _open(it: Node2D) -> void:
	if it.has_method("harvest"):                   # ressource : on récolte au lieu de parler
		_start_gather(it)
		return
	var gs := _game_state()
	_dialog_it = it
	_welcome = gs != null and it.entry_id == "npc_yvenne" and gs.tutorial_step() == 0
	if gs and not _welcome:
		gs.tutorial_check("talk:" + it.entry_id)
	player.stop()
	_dialog.open(it, gs.YVENNE_WELCOME.duplicate() if _welcome else [])


func _on_dialog_closed() -> void:
	var gs := _game_state()
	if _welcome and gs and _dialog_it:              # fin de l'accueil : l'objectif suivant s'ouvre
		_welcome = false
		gs.tutorial_check("talk:" + _dialog_it.entry_id)
	_refresh_markers()


## Raccourci (tests, et touche d'action) : joue l'action principale de la conversation en cours.
func do_dialog_action() -> void:
	_dialog.primary()


func _on_dialog_action(act: Dictionary) -> void:
	var gs := _game_state()
	if gs == null:
		return
	match act.kind:
		"accept":
			gs.accept_quest(act.quest_id)
		"turn_in":
			gs.turn_in_quest(act.quest_id)
		"shop":
			hud.open_shop(act.shop_id)
		"workshop":
			hud.open_workshop(act.workshop_id)
		"ferry":
			Sfx.play("oars")
			var to := Vector2(act.to[0], act.to[1])
			player.stop()
			gs.fade_do(func():
				player.global_position = to
				player.get_node("Camera2D").reset_smoothing())
		"discovery":
			gs.add_note(act.note, act.title, act.text)
	_refresh_markers()


# --------------------------------------------------------------------------- récolte
func _start_gather(it: Node2D) -> void:
	if _gather:
		return
	var why: String = it.can_gather()
	if why != "":
		if hud:
			hud.feed("%s : %s" % [it.display_name, why])
		return
	var gs := _game_state()
	player.stop()
	player.facing = (it.global_position - player.global_position).normalized()
	_gather = it
	_gather_t = 0.0
	_gather_hit = gs.fighter.last_combat_at if gs else 0.0
	if not _gather_bar:
		_gather_bar = (load("res://game/ui/gather_bar.gd") as GDScript).new()
		player.add_child(_gather_bar)
	_gather_bar.icon = it.get_node("Sprite").texture if it.has_node("Sprite") else null
	_gather_bar.progress = 0.0
	_gather_bar.visible = true


func _update_gather(delta: float) -> void:
	var gs := _game_state()
	var hit: bool = gs != null and gs.fighter.last_combat_at > _gather_hit
	if not is_instance_valid(_gather) or player.velocity.length() > 1.0 or hit or player.is_down():
		_stop_gather("Récolte interrompue")
		return
	_gather_t += delta
	if fmod(_gather_t, 0.7) < delta:              # geste de cueillette
		player._start_act("attack", 0.2)
		Sfx.play("splash" if _gather.profession() == "peche" else "gather", -6.0, 0.1)
	_gather_bar.progress = _gather_t / _gather.gather_time()
	if _gather_t < _gather.gather_time():
		return
	var it := _gather
	var items: Array = it.harvest()
	var y := 0
	for p in items:
		if gs:
			gs.add_item(p[0], p[1])
		float_text(player.global_position + Vector2(0, -30 - y * 10), "+%d %s" % [p[1], gs.item_name(p[0]) if gs else p[0]], Color("a8c84e"))
		y += 1
	Sfx.play("fish" if it.profession() == "peche" else "gather_done")
	if gs:
		gs.on_gather(it.template_id, it.profession(), int(it.res.get("level", 1)))
	_stop_gather("")


func _stop_gather(msg: String) -> void:
	_gather = null
	if _gather_bar:
		_gather_bar.visible = false
	if msg != "" and hud:
		hud.feed(msg)


## Position monde d'une cible de guidage : entrée (PNJ, ressource), sortie, ou « mobs » (bête la plus proche).
func find_target(name: String):
	if name == "mobs":
		var best = null
		var bd := INF
		for m in get_tree().get_nodes_in_group("mobs"):
			var d: float = m.global_position.distance_to(player.global_position)
			if m.is_alive() and not m.submerged and d < bd:
				bd = d
				best = m.global_position + Vector2(0, -10)
		return best
	if name.begins_with("mob:") or name.begins_with("res:"):   # suivi de quête : la plus proche
		var want := name.substr(4)
		var best2 = null
		var bd2 := INF
		var group := "mobs" if name.begins_with("mob:") else "interactables"
		for m in get_tree().get_nodes_in_group(group):
			if m.get("template_id") != want:
				continue
			if group == "mobs" and (not m.is_alive() or m.submerged):
				continue
			var d2: float = m.global_position.distance_to(player.global_position)
			if group == "interactables" and m.has_method("can_gather") and m.can_gather() != "":
				d2 += 5000.0                                # épuisée : seulement s'il n'y en a pas d'autre
			if d2 < bd2:
				bd2 = d2
				best2 = m.global_position + Vector2(0, -10)
		return best2
	var ex := get_node_or_null("Sorties/" + name)
	if ex and ex.get_child_count() > 0:
		return ex.global_position + (ex.get_child(0) as Node2D).position
	var n := find_child(name, true, false)
	if n is Node2D:
		return (n as Node2D).global_position + Vector2(0, -12)
	return null


func is_gathering() -> bool:
	return _gather != null


func _update_water(delta: float) -> void:
	var inside := false
	for poly in slow_polys:
		var pts := PackedVector2Array()
		for v in poly:
			pts.append(Vector2(v[0], v[1]))
		if Geometry2D.is_point_in_polygon(player.global_position, pts):
			inside = true
			break
	player.speed_mult = 0.65 if inside else 1.0
	_splash_t -= delta
	if inside and player.velocity.length() > 5.0 and _splash_t <= 0.0:
		_splash_t = 0.28
		burst(player.global_position + Vector2(0, -1), Color("d4f4ec"), 5, 18.0, false, Vector2(3, 1))


func _on_quest_changed(_q: String) -> void:
	_refresh_markers()


func _refresh_markers() -> void:
	for it in get_tree().get_nodes_in_group("interactables"):
		if it.has_method("refresh_marker"):
			it.refresh_marker()


func _on_exit(target: String, label: String) -> void:
	var gs := _game_state()
	if gs and not gs.zone_unlocked(target):                # zone verrouillée : son indice
		var ex_node := get_node_or_null("Sorties")
		for ex in (ex_node.get_children() if ex_node else []):
			if ex.get("target_zone") == target and ex.get("secret"):
				return                                     # sortie cachée : rien ne la trahit
		var hint: String = gs.zone_info(target).get("hint", "")
		toast(label + " — verrouillée", 2.5)
		if hud and hint != "":
			hud.feed(hint)
		return
	if gs and gs.has_zone(target):
		if not gs.is_travelling():
			player.stop()
			_dialog.close()
			gs.travel(zone_id, target)
	else:
		toast("→ %s (zone à venir)" % label, 2.0)


## Défaite : retour au village après un temps à terre. Pas d'`await` sur la zone elle-même : la
## reprendre alors qu'elle vient d'être détruite (changement de scène) faisait planter le moteur.
func _on_defeated() -> void:
	if _defeat_pending:
		return
	_defeat_pending = true
	var gs := _game_state()
	if gs:
		get_tree().create_timer(1.4).timeout.connect(gs.defeat, CONNECT_ONE_SHOT)


## Nouveau titre : bandeau doré et gerbe de lumière autour du joueur.
func _on_title(_tid: String) -> void:
	burst(player.global_position + Vector2(0, -12), Color("ffe08a"), 26, 50.0)   # la carte : hud.reward


## Niveau supérieur : une gerbe de lumière dorée autour du joueur (la carte : hud.reward).
func _on_level(_level: int) -> void:
	burst(player.global_position + Vector2(0, -12), Color("fff4d6"), 34, 60.0)


func _on_notice(text: String) -> void:
	if hud:
		hud.feed(text)


# --------------------------------------------------------------------------- retours de combat
func report_hit(target: Node2D, r: Dictionary, from: Node2D) -> void:
	var by_player: bool = from == player
	var pos := target.global_position + Vector2(0, -24)
	if r.dodged:
		Sfx.play("dodge", -7.0)
	elif target == player:
		Sfx.play("hurt")
	else:
		Sfx.play("crit" if r.critical else "hit", 2.0)
	if r.dodged:
		float_text(pos, "Esquivé", Color("c4b59c"))
	else:
		var col := Color("fff4d6") if by_player else Color("e05a48")
		if r.critical:
			col = Color("ffe08a")
		float_text(pos, str(roundi(r.final_damage)) + ("!" if r.critical else ""), col, r.critical)
		spark(target.global_position + Vector2(randf_range(-3, 3), -10 + randf_range(-3, 3)), r.critical,
			Color("fff4d6") if by_player else Color("f0a090"))
		if r.critical:
			burst(target.global_position + Vector2(0, -10), Color("ffe08a"), 10, 40.0)
		if r.critical or (by_player and r.final_damage >= target.fighter.max_hp() * 0.2):
			hitstop()
	target.react(r, from.global_position)
	if by_player and hud:
		hud.set_target(target)


func float_text(pos: Vector2, text: String, color: Color, big := false) -> void:
	if not _fx:
		return
	var l: Label = load("res://game/combat/float_text.gd").make(text, color, big)
	l.position = pos
	_fx.add_child(l)


func show_strike(origin: Vector2, area: Dictionary, d: Vector2, color: Color, weapon: Texture2D = null) -> void:
	if not _fx:
		return
	var n: Node2D = (load("res://game/combat/strike_fx.gd") as GDScript).new()
	n.area = area
	n.weapon = weapon
	n.dir = d
	n.color = color
	n.life = 0.28 if area.get("shape") == "line" else 0.16
	n.position = origin
	_fx.add_child(n)


func show_telegraph(origin: Vector2, area: Dictionary, d: Vector2, seconds: float) -> Node2D:
	var n: Node2D = (load("res://game/combat/telegraph.gd") as GDScript).new()
	n.area = area
	n.dir = d
	n.duration = seconds
	n.position = origin + Vector2(0, -4)
	(_ground if _ground else self).add_child(n)
	return n


func drop_loot(pos: Vector2, items: Array) -> void:
	for it in items:
		var o: Node2D = (load("res://game/combat/loot_orb.gd") as GDScript).new()
		o.item_id = it[0]
		o.qty = it[1]
		o.target = player
		o.position = pos
		(_fx if _fx else self).add_child(o)


func spark(pos: Vector2, crit := false, color := Color("fff4d6")) -> void:
	if not _fx:
		return
	var n: Node2D = (load("res://game/combat/hit_spark.gd") as GDScript).new()
	n.position = pos
	n.crit = crit
	n.color = color
	_fx.add_child(n)


## Gerbe de particules d'un seul coup (lumière, grains, poussière). `rise` : vers le haut ou retombant.
func burst(pos: Vector2, color: Color, amount := 12, speed := 30.0, rise := true, spread_rect := Vector2.ZERO) -> void:
	if not _fx:
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = amount
	p.lifetime = 0.7 if rise else 0.45
	p.direction = Vector2(0, -1)
	p.spread = 70.0 if rise else 180.0
	p.gravity = Vector2(0, -25) if rise else Vector2(0, 60)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.color = color
	if spread_rect != Vector2.ZERO:
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = spread_rect
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	p.color_ramp = g
	p.scale_amount_min = 2.0                      # grains de 2 px : lisibles à l'échelle du jeu
	p.scale_amount_max = 2.0
	p.z_index = 24
	_fx.add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)


## Gel d'image à l'impact. Le retour à la vitesse normale est confié à GameState (jamais détruit) :
## une attente sur la zone elle-même reprenait parfois après sa destruction (changement de scène).
func hitstop() -> void:
	var gs := _game_state()
	if gs == null:
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(0.05, true, false, true).timeout.connect(gs.restore_time_scale, CONNECT_ONE_SHOT)


# --------------------------------------------------------------------------- UI
## Bandeau de laiton au centre-haut (nom de zone, annonces de passage).
func toast(text: String, seconds: float) -> void:
	_toast.text = text
	_toast_t = seconds
	_toast_box.modulate.a = 1.0
	_toast_box.visible = true


var _toast_box: PanelContainer


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UISkin.theme()
	_ui.add_child(root)

	# bandeau de zone
	_toast_box = PanelContainer.new()
	_toast_box.add_theme_stylebox_override("panel", UISkin.box("frame_dark", 8, 7))
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.anchor_left = 0.5
	_toast_box.anchor_right = 0.5
	_toast_box.offset_top = 62                    # sous le suivi des quêtes
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast = UISkin.shadowed(Label.new(), UISkin.GOLD, 20)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_box.add_child(_toast)
	root.add_child(_toast_box)
	_toast_box.visible = false

	# dialogue : conversation en pages, puis choix (game/ui/dialog_box.gd)
	_dialog = (load("res://game/ui/dialog_box.gd") as GDScript).new()
	_dialog.action.connect(_on_dialog_action)
	_dialog.closed.connect(_on_dialog_closed)
	root.add_child(_dialog)