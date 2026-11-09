extends Control
## Fenêtre de récompense : niveau supérieur, titre, compétence, objet fabriqué. Une carte de parchemin
## qui jaillit au centre, derrière elle des rayons d'aube qui tournent lentement. File d'attente : les
## récompenses simultanées (niveau + compétence débloquée) s'enchaînent. Le jeu ne se met pas en pause.

const STAT_NAMES := {"hp": "Points de vie", "atk": "Attaque", "def": "Défense", "agi": "Agilité",
	"int": "Intelligence", "sag": "Sagesse"}
const INK := Color("4f3324")
const INK_SOFT := Color("7a5030")
const ACCENT := Color("a83a40")
const GOOD := Color("4a8040")
const GOLD := Color("f5b84a")
const AUTO_CLOSE := 12.0

var _gs: Node
var _queue: Array = []
var _rays: Control
var _card: PanelContainer
var _body: VBoxContainer
var _t := 0.0
var _shown := 0.0
var _ray_color := GOLD


func _ready() -> void:
	_gs = (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.1, 0.18, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_rays = Control.new()
	_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_rays)
	add_child(_rays)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UISkin.box("book", 11, 10))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.custom_minimum_size = Vector2(236, 0)
	add_child(_card)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	_body.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(_body)
	gui_input.connect(func(e: InputEvent):
		if _shown > 0.4 and ((e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)):
			_next())
	if _gs:
		_gs.leveled_up.connect(_on_level)
		_gs.title_unlocked.connect(_on_title)
		_gs.skill_unlocked.connect(_on_skill)
		_gs.craft_done.connect(_on_craft)


func _exit_tree() -> void:
	if _gs:
		for pair in [[_gs.leveled_up, _on_level], [_gs.title_unlocked, _on_title], [_gs.skill_unlocked, _on_skill],
				[_gs.craft_done, _on_craft]]:
			if (pair[0] as Signal).is_connected(pair[1]):
				(pair[0] as Signal).disconnect(pair[1])


# --------------------------------------------------------------------------- contenus
func _on_level(level: int) -> void:
	var lines := [["+%d points de caractéristique à répartir" % CombatRules.POINTS_PER_LEVEL, GOOD],
		["Points de vie et mana au maximum", INK_SOFT]]
	push({"heading": "Niveau supérieur", "title": "Niveau %d" % level, "title_size": 20,
		"badge": str(level), "lines": lines,
		"hint": "Carnet › Personnage pour placer tes points.", "color": GOLD, "sound": "level_up"})


func _on_title(tid: String) -> void:
	var t: Dictionary = _gs.tpl("titles", tid)
	var lines := []
	for e in t.get("effects", []):
		if e.get("type") == "stat_bonus_percent":
			lines.append(["+%d %% %s" % [int(e.amount_percent), STAT_NAMES.get(e.stat, e.stat)], GOOD])
		elif e.get("type") == "stat_bonus":
			lines.append(["+%d %s" % [int(e.amount), STAT_NAMES.get(e.stat, e.stat)], GOOD])
	push({"heading": "Nouveau titre", "title": t.get("name", tid), "icon": UISkin.tex("marker_quest"),
		"desc": t.get("description", ""), "lines": lines, "hint": "Porte-le depuis Carnet › Équipement.",
		"color": GOLD, "sound": "unlock"})


func _on_skill(sid: String) -> void:
	var sk: Dictionary = _gs.tpl("skills", sid)
	var lines := []
	if sk.get("kind") == "active":
		lines.append(["%d mana  ·  recharge %s s" % [int(sk.get("mana_cost", 0)),
			str(sk.get("cooldown_seconds", 0)).replace(".", ",")], INK_SOFT])
		var slot: int = (_gs.profile.bar as Array).find(sid)
		lines.append(["Placée sur la barre (touche %d)" % (slot + 1), GOOD] if slot >= 0
			else ["Barre pleine : place-la depuis Carnet › Compétences", ACCENT])
	else:
		lines.append(["Compétence passive : toujours active", GOOD])
	push({"heading": "Nouvelle compétence", "title": sk.get("name", sid), "icon": UISkin.icon(sid),
		"desc": sk.get("description", ""), "lines": lines, "color": Color("8fd8d0"), "sound": "unlock"})


func _on_craft(item_id: String, discovered: bool) -> void:
	var t: Dictionary = _gs.tpl("items", item_id)
	var rank: String = _gs.item_rank(item_id)
	var rc := Color(CraftRules.RANK_COLORS[rank])
	var base_name: String = _gs.tpl("items", item_id.get_slice("~", 0)).get("name", t.get("name", item_id))
	var lines := [["Rang %s" % CraftRules.RANK_NAMES[rank], rc.darkened(0.35) if rank != "commun" else INK_SOFT]]
	if t.has("equipment"):
		var parts := PackedStringArray()
		for k in t.equipment.get("stat_bonuses", {}):
			parts.append("+%s %s" % [str(snappedf(float(t.equipment.stat_bonuses[k]), 0.1)).trim_suffix(".0").replace(".", ","), STAT_NAMES.get(k, k)])
		lines.append([", ".join(parts) + "  ·  niv. %d" % int(t.equipment.get("level_required", 1)), GOOD])
	elif t.has("consumable"):
		lines.append([("Rend %d PV" if t.consumable.effect_type == "heal" else "Rend %d mana") % int(t.consumable.amount), GOOD])
	var lc: Dictionary = _gs.last_craft
	if not lc.is_empty():
		var pn: String = _gs.PROF_NAMES.get(lc.prof, lc.prof)
		lines.append(["+%d XP %s  ·  niveau %d%s" % [roundi(lc.xp), pn, int(lc.level), " !" if lc.level_up else ""],
			ACCENT if lc.level_up else INK_SOFT])
	push({"heading": "Nouvelle recette !" if discovered else "Objet fabriqué", "title": base_name,
		"title_color": rc.darkened(0.45) if rank != "commun" else INK, "icon": UISkin.item_icon(item_id),
		"desc": t.get("description", ""), "lines": lines,
		"color": rc if rank != "commun" else (GOLD if discovered else Color("ece2cf")), "sound": "craft_done"})


# --------------------------------------------------------------------------- file et affichage
func push(entry: Dictionary) -> void:
	_queue.append(entry)
	if not visible:
		_next()


func busy() -> bool:
	return visible


func _next() -> void:
	if _queue.is_empty():
		visible = false
		return
	_show(_queue.pop_front())


func _show(e: Dictionary) -> void:
	if e.has("sound"):
		Sfx.play(e.sound)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_ray_color = e.get("color", GOLD)
	_label(e.get("heading", "").to_upper(), ACCENT)
	if e.get("icon") != null or e.has("badge"):
		# cadre 42×42 à taille réelle, icône 16 px doublée (32) au centre, ou gros chiffre (niveau)
		var holder := CenterContainer.new()
		_body.add_child(holder)
		var frame := Control.new()
		frame.custom_minimum_size = Vector2(42, 42)
		holder.add_child(frame)
		var slot := TextureRect.new()
		slot.texture = UISkin.tex("slot_big")
		slot.size = Vector2(42, 42)
		frame.add_child(slot)
		if e.has("badge"):
			var b := UISkin.shadowed(Label.new(), Color("ffe08a"), 20)
			b.text = e.badge
			b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			b.position = Vector2(0, 0)
			b.size = Vector2(42, 40)
			frame.add_child(b)
		elif e.icon != null:
			var ic := TextureRect.new()
			ic.texture = e.icon
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_SCALE
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ic.position = Vector2(5, 5)
			ic.size = Vector2(32, 32)
			frame.add_child(ic)
	var tl := _label(e.get("title", ""), e.get("title_color", INK), int(e.get("title_size", 20)))
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if e.get("desc", "") != "":
		var d := _label(e.desc, INK_SOFT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l in e.get("lines", []):
		var ll := _label(l[0], l[1])
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if e.get("hint", "") != "":
		_label(e.hint, Color("a8743f"))
	var btn := Button.new()
	btn.text = "  Continuer  "
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_next)
	_body.add_child(btn)
	visible = true
	_shown = 0.0
	modulate.a = 0.0
	_card.reset_size()
	_pop.call_deferred()                           # une image plus tard : la carte connaît sa taille


## La carte jaillit : petite, puis un peu trop grande, puis à sa taille.
func _pop() -> void:
	if not is_inside_tree() or not visible:
		return
	_card.reset_size()
	var vp := get_viewport_rect().size
	_card.position = ((vp - _card.size) / 2.0).round()
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2(0.6, 0.6)
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _label(text: String, col: Color, size := 10) -> Label:
	var l := UISkin.ink(Label.new(), col, size)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(214, 0)
	_body.add_child(l)
	return l


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_shown += delta
	_rays.queue_redraw()
	if _shown > AUTO_CLOSE:
		_next()


func _input(event: InputEvent) -> void:
	if not visible or _shown < 0.4:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_KP_ENTER]:
		_next()
		get_viewport().set_input_as_handled()


## Rayons d'aube derrière la carte : fins triangles qui tournent, en paliers d'opacité (pixel).
func _draw_rays() -> void:
	var c := get_viewport_rect().size / 2.0
	var n := 14
	var a0 := _t * 0.25
	for i in n:
		var a := a0 + i * TAU / n
		var w := 0.09
		var r := 220.0
		var pts := PackedVector2Array([c, c + Vector2.from_angle(a - w) * r, c + Vector2.from_angle(a + w) * r])
		_rays.draw_colored_polygon(pts, Color(_ray_color, 0.16 if i % 2 == 0 else 0.08))
	var k := minf(1.0, _shown / 0.3)
	if k > 0.05:                                    # jamais de cercle de rayon nul (triangulation)
		_rays.draw_circle(c, 70.0 * k, Color(_ray_color, 0.12))
