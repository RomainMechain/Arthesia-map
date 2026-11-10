extends CanvasLayer
## HUD de combat, habillage « laiton d'aube » (UISkin). Tout est ancré aux bords de l'écran : avec
## l'étirement « expand », la largeur grandit sur les téléphones allongés et les coins suivent.
##   haut-gauche  : médaillon solaire (niveau), PV, mana, XP, effets
##   haut-centre  : plaque de la dernière bête frappée
##   haut-droite  : bouton Carnet + suivi des quêtes (parchemin)
##   bas-gauche   : fil des annonces (butin, quêtes, compétences)
##   bas-droite   : bouton d'attaque (médaillon) + 4 compétences en arc, sous le pouce

var _gs: Node
var _player: Node2D
var _root: Control
var _lvl: Label
var _hp_bar: UISkin.Bar
var _mana_bar: UISkin.Bar
var _xp_bar: UISkin.Bar
var _title_label: Label
var _low_hp: ShaderMaterial
var _fx_box: PanelContainer
var _fx_label: Label
var _target_box: PanelContainer
var _target_name: Label
var _target_bar: UISkin.Bar
var _target: Node2D
var _target_t := 0.0
var _quest_box: PanelContainer
var _track_box: PanelContainer      # rappel discret de la quête suivie (sous la mini-carte)
var _track_name: Label
var _track_step: Label
var _track_where: Label
var _quest_list: VBoxContainer
var _feed: VBoxContainer
var _slots: Array = []
var _attack: Control
var _carnet_btn: Control
var _potion: Control
var carnet: Control
var shop: Control
var atelier: Control
var reward: Control
var minimap: Control
var bigmap: Control
var menu: Control
var _menu_btn: Control
var _guide: Control
var _hint_box: PanelContainer
var _hint_label: Label
var _hint_t := 0.0
var _hint_queue: Array = []


## Bouton rond dessiné : chaton (texture), icône, voile de recharge circulaire, secondes restantes.
class SkillSlot extends Control:
	signal tapped
	var frame := "slot"
	var icon: Texture2D
	var icon_scale := 1
	var hint := ""
	var badge := ""             # nombre restant (consommable)
	var ghost := false          # icône pâle : emplacement vide
	var cd := 0.0               # part de recharge restante (0..1)
	var cd_seconds := 0.0
	var usable := true
	var _flash := 0.0
	var _press := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
				or (e is InputEventScreenTouch and e.pressed):
			_press = 0.12
			tapped.emit()
			accept_event()

	func flash() -> void:
		_flash = 0.45

	func _process(delta: float) -> void:
		_flash = maxf(0.0, _flash - delta)
		_press = maxf(0.0, _press - delta)
		queue_redraw()

	func _draw() -> void:
		var off := Vector2(0, 1) if _press > 0.0 else Vector2.ZERO
		draw_texture(UISkin.tex(frame), off)
		var c := size / 2.0 + off
		if icon:
			var isz := icon.get_size() * icon_scale
			draw_texture_rect(icon, Rect2(c - isz / 2.0, isz), false,
				Color(0.6, 0.55, 0.7, 0.35) if ghost else (Color.WHITE if usable else Color(0.55, 0.55, 0.75, 0.8)))
		if cd > 0.04 and (size.x / 2.0 - 4.0) * TAU * cd > 4.0:   # voile circulaire (jamais une forme trop fine)
			var r := size.x / 2.0 - 4.0
			var pts := PackedVector2Array([c])
			var a0 := -PI / 2.0
			for i in 25:
				pts.append(c + Vector2.from_angle(a0 + TAU * cd * i / 24.0) * r)
			if pts.size() >= 3:
				draw_colored_polygon(pts, Color(0.1, 0.06, 0.12, 0.55))
			if cd_seconds >= 1.0:
				var f := get_theme_default_font()
				var s := str(ceili(cd_seconds))
				var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
				draw_string(f, c + Vector2(-w / 2.0 + 1, 5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UISkin.SHADOW)
				draw_string(f, c + Vector2(-w / 2.0, 4), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UISkin.CREAM)
		if _flash > 0.0:
			draw_arc(c, size.x / 2.0 - 2.0, 0, TAU, 24, Color("e05a48", _flash * 2.0), 2.0)
		if badge != "":
			var fb := get_theme_default_font()
			var bw := fb.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_string(fb, Vector2(size.x - bw - 1, size.y - 1), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UISkin.SHADOW)
			draw_string(fb, Vector2(size.x - bw - 2, size.y - 2), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UISkin.CREAM)
		if hint != "":
			var f2 := get_theme_default_font()
			draw_string(f2, Vector2(1, 9), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UISkin.SHADOW)
			draw_string(f2, Vector2(0, 8), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UISkin.GOLD)


## Guidage de l'accueil : chevron doré au-dessus de la cible si elle est à l'écran, sinon flèche au bord
## de l'écran pointée vers elle ; « hud:carnet » fait pulser le bouton du Carnet.
class GuideArrow extends Control:
	var hud: CanvasLayer
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var gs: Node = hud._gs
		if gs == null:
			return
		var name := ""
		if not gs.objective().is_empty():
			var targets: Dictionary = gs.objective().get("targets", {})
			name = targets.get(gs.current_zone, targets.get("*", ""))
		elif gs.tracked_quest() != "":
			name = hud.track_target()
		if name == "":
			return
		if name == "hud:carnet":
			var r: Rect2 = hud._carnet_btn.get_global_rect()
			draw_arc(r.get_center(), 18.0 + sin(_t * 5.0) * 2.0, 0, TAU, 24, Color("ffe08a"), 2.0)
			return
		var z := get_tree().get_first_node_in_group("zone")
		if z == null:
			return
		var w = z.find_target(name)
		if w == null:
			return
		var p: Vector2 = z.get_canvas_transform() * (w as Vector2)
		var view := Rect2(Vector2(26, 40), size - Vector2(52, 92))
		var gold := Color("ffe08a")
		var ink := Color("2a1a2e")
		if view.has_point(p):                              # cible visible : chevron qui rebondit
			var y := p.y - 42.0 + sin(_t * 4.0) * 2.0           # au-dessus du nom et du marqueur
			var tri := PackedVector2Array([Vector2(p.x - 5, y), Vector2(p.x + 5, y), Vector2(p.x, y + 6)])
			draw_colored_polygon(PackedVector2Array([tri[0] + Vector2(-1, -1), tri[1] + Vector2(1, -1), tri[2] + Vector2(0, 2)]), ink)
			draw_colored_polygon(tri, gold)
		else:                                              # hors écran : flèche au bord
			var c := size / 2.0
			var d := (p - c).normalized()
			var e := Vector2(clampf(p.x, view.position.x, view.end.x), clampf(p.y, view.position.y, view.end.y))
			var pad := Rect2(size.x - 150.0, size.y - 118.0, 150.0, 118.0)   # boutons d'action
			if pad.has_point(e):
				if absf(d.x) > absf(d.y):
					e.y = pad.position.y - 4.0
				else:
					e.x = pad.position.x - 4.0
			e += d * sin(_t * 4.0) * 2.0
			var n := d.orthogonal()
			draw_circle(e, 9, ink)
			draw_circle(e, 8, Color("4a3450"))
			var tri2 := PackedVector2Array([e + d * 6.0, e - d * 3.0 + n * 4.0, e - d * 3.0 - n * 4.0])
			draw_colored_polygon(tri2, gold)


## Cible de la flèche pour la quête suivie : la sortie à prendre, ou la cible dans la zone.
## Recalculée au plus toutes les 0,5 s (l'index est en cache, la route est un petit parcours).
var _tt := ""
var _tt_at := -1.0


func track_target() -> String:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _tt_at > 0.5:
		_tt_at = now
		var s: Dictionary = QuestGuide.step(_gs, _gs.tracked_quest(), _gs.current_zone)
		_tt = str(s.get("exit", "")) if str(s.get("exit", "")) != "" else str(s.get("spec", ""))
	return _tt


## Place un contrôle par rapport à un coin : (ax, ay) = ancre (0 ou 1), (x, y) = décalage depuis l'ancre.
func _place(c: Control, ax: float, ay: float, x: float, y: float, w: float, h: float) -> Control:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = x
	c.offset_top = y
	c.offset_right = x + w
	c.offset_bottom = y + h
	return c


func _ready() -> void:
	layer = 4
	_gs = (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	_player = get_tree().get_first_node_in_group("player")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UISkin.theme()
	add_child(_root)
	# liseré rouge des PV bas (sous tout le reste du HUD)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_low_hp = ShaderMaterial.new()
	_low_hp.shader = load("res://game/fx/low_hp.gdshader")
	vig.material = _low_hp
	_root.add_child(vig)

	# --- joueur : médaillon solaire + barres
	var med := TextureRect.new()
	med.texture = UISkin.tex("medallion")
	med.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_place(med, 0, 0, 3, 3, 28, 28))
	_lvl = UISkin.shadowed(Label.new(), UISkin.GOLD, 10)
	_lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lvl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(_place(_lvl, 0, 0, 3, 3, 28, 28))
	_hp_bar = UISkin.Bar.new("bar_hp", Vector2(100, 11))
	_root.add_child(_place(_hp_bar, 0, 0, 30, 6, 100, 11))
	_mana_bar = UISkin.Bar.new("bar_mana", Vector2(84, 7))
	_root.add_child(_place(_mana_bar, 0, 0, 30, 17, 84, 7))
	_xp_bar = UISkin.Bar.new("bar_xp", Vector2(70, 5))
	_root.add_child(_place(_xp_bar, 0, 0, 30, 24, 70, 5))
	_fx_box = PanelContainer.new()
	_fx_box.add_theme_stylebox_override("panel", UISkin.box("plate", 4, 3))
	_fx_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_label = UISkin.shadowed(Label.new(), Color("f0a090"), 10)
	_fx_box.add_child(_fx_label)
	_root.add_child(_place(_fx_box, 0, 0, 4, 42, 0, 0))
	_title_label = UISkin.shadowed(Label.new(), UISkin.GOLD)
	_root.add_child(_place(_title_label, 0, 0, 31, 28, 120, 12))
	_fx_box.visible = false

	# --- cible
	_target_box = PanelContainer.new()
	_target_box.add_theme_stylebox_override("panel", UISkin.box("plate", 4, 4))
	_target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 1)
	_target_box.add_child(tv)
	_target_name = UISkin.shadowed(Label.new(), UISkin.CREAM)
	_target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(_target_name)
	_target_bar = UISkin.Bar.new("bar_foe", Vector2(104, 6))
	tv.add_child(_target_bar)
	_root.add_child(_place(_target_box, 0.5, 0, -58, 3, 116, 26))
	_target_box.visible = false

	# --- Carnet + quêtes
	_carnet_btn = SkillSlot.new()
	_carnet_btn.icon = UISkin.icon("carnet")
	_carnet_btn.size = Vector2(30, 30)
	_carnet_btn.tapped.connect(toggle_carnet)
	_root.add_child(_place(_carnet_btn, 1, 0, -33, 3, 30, 30))
	_menu_btn = SkillSlot.new()
	_menu_btn.icon = UISkin.icon("menu")
	_menu_btn.size = Vector2(30, 30)
	_menu_btn.tapped.connect(toggle_menu)
	_root.add_child(_place(_menu_btn, 1, 0, -65, 3, 30, 30))
	_quest_box = PanelContainer.new()
	_quest_box.add_theme_stylebox_override("panel", UISkin.box("parchment", 8, 5))
	_quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_quest_list = VBoxContainer.new()
	_quest_list.add_theme_constant_override("separation", 0)
	_quest_box.add_child(_quest_list)
	_root.add_child(_place(_quest_box, 1, 0, -90, 4, 0, 0))
	# mini-carte sous les boutons du coin ; la toucher ouvre la carte de la zone
	minimap = (load("res://game/ui/minimap.gd") as GDScript).new()
	minimap.tapped.connect(toggle_map)
	_root.add_child(_place(minimap, 1, 0, -86, 36, 82, 58))
	_track_box = PanelContainer.new()
	_track_box.add_theme_stylebox_override("panel", UISkin.box("parchment", 8, 4))
	_track_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var trv := VBoxContainer.new()
	trv.add_theme_constant_override("separation", -2)
	_track_box.add_child(trv)
	_track_name = UISkin.ink(_mk(""), Color("a83a40"))
	_track_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trv.add_child(_track_name)
	_track_step = UISkin.ink(_mk(""), UISkin.INK)
	_track_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trv.add_child(_track_step)
	_track_where = UISkin.ink(_mk(""), UISkin.INK_FAINT)
	_track_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trv.add_child(_track_where)
	_root.add_child(_place(_track_box, 1, 0, -4, 96, 0, 0))
	_track_box.visible = false

	# --- fil d'annonces
	_feed = VBoxContainer.new()
	_feed.alignment = BoxContainer.ALIGNMENT_END
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.add_theme_constant_override("separation", 1)
	_root.add_child(_place(_feed, 0, 1, 6, -96, 220, 90))

	# --- attaque + compétences en arc autour du pouce
	_attack = SkillSlot.new()
	_attack.frame = "slot_big"
	_attack.icon = UISkin.icon("attaque")
	_attack.icon_scale = 2
	_attack.size = Vector2(42, 42)
	_attack.tapped.connect(func(): if _player: _player.attack())
	_root.add_child(_place(_attack, 1, 1, -48, -48, 42, 42))
	var center := Vector2(-27, -27)
	for i in 4:
		var s := SkillSlot.new()
		s.size = Vector2(30, 30)
		s.hint = str(i + 1)
		var a := deg_to_rad(180.0 + 30.0 * i)
		var p := center + Vector2.from_angle(a) * 60.0 - Vector2(15, 15)
		var idx := i
		s.tapped.connect(func(): _on_slot(idx))
		_root.add_child(_place(s, 1, 1, p.x, p.y, 30, 30))
		_slots.append(s)

	# raccourci de soin : le meilleur soin du sac, à gauche de l'arc (touche F sur PC)
	_potion = SkillSlot.new()
	_potion.size = Vector2(30, 30)
	_potion.hint = "F"
	_potion.tapped.connect(use_potion)
	_root.add_child(_place(_potion, 1, 1, -136, -38, 30, 30))

	# Carnet et échoppe : au-dessus des bandeaux et des bulles, sous le menu pause
	var panels := CanvasLayer.new()
	panels.layer = 15
	add_child(panels)
	var proot := Control.new()
	proot.set_anchors_preset(Control.PRESET_FULL_RECT)
	proot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proot.theme = UISkin.theme()
	panels.add_child(proot)
	carnet = (load("res://game/ui/carnet.gd") as GDScript).new()
	carnet.visible = false
	proot.add_child(carnet)
	shop = (load("res://game/ui/shop.gd") as GDScript).new()
	shop.visible = false
	proot.add_child(shop)
	atelier = (load("res://game/ui/atelier.gd") as GDScript).new()
	atelier.visible = false
	proot.add_child(atelier)
	bigmap = (load("res://game/ui/minimap.gd") as GDScript).new()
	bigmap.full = true
	bigmap.visible = false
	bigmap.tapped.connect(toggle_map)
	proot.add_child(_place(bigmap, 0.5, 0.5, -224, -124, 448, 248))
	(func():
		var z := get_parent()
		minimap.setup(z)
		bigmap.setup(z)
		bigmap.visible = false).call_deferred()
	# guidage de l'accueil : chevron / flèche vers la cible de l'objectif
	_guide = GuideArrow.new()
	_guide.hud = self
	_guide.set_anchors_preset(Control.PRESET_FULL_RECT)
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_guide)
	_root.move_child(_guide, 0)
	# bulle d'aide (une fois par sujet)
	_hint_box = PanelContainer.new()
	_hint_box.add_theme_stylebox_override("panel", UISkin.box("parchment", 8, 6))
	_hint_box.anchor_left = 0.5
	_hint_box.anchor_right = 0.5
	_hint_box.anchor_top = 1.0
	_hint_box.anchor_bottom = 1.0
	_hint_box.offset_left = -120
	_hint_box.offset_right = 70
	_hint_box.offset_top = -104
	_hint_box.offset_bottom = -64
	_hint_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_hint_box.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_hint_t = 0.0)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 5)
	_hint_box.add_child(hh)
	var hi := TextureRect.new()
	hi.texture = UISkin.tex("marker_quest")
	hi.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hh.add_child(hi)
	_hint_label = UISkin.ink(Label.new(), UISkin.INK)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(160, 0)
	hh.add_child(_hint_label)
	_hint_box.visible = false
	_root.add_child(_hint_box)
	# le menu passe au-dessus de tout (bandeau de zone, dialogues), sur un voile sombre
	# récompenses (niveau, titre, compétence, craft) : au-dessus du Carnet et de l'atelier, sous le menu
	var reward_layer := CanvasLayer.new()
	reward_layer.layer = 18
	add_child(reward_layer)
	reward = (load("res://game/ui/reward_popup.gd") as GDScript).new()
	reward.theme = UISkin.theme()
	reward_layer.add_child(reward)
	var top_layer := CanvasLayer.new()
	top_layer.layer = 20
	top_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(top_layer)
	var veil := ColorRect.new()
	veil.color = Color(0.1, 0.06, 0.12, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.visible = false
	top_layer.add_child(veil)
	menu = (load("res://game/ui/menu.gd") as GDScript).new()
	top_layer.add_child(menu)
	menu.visibility_changed.connect(func(): veil.visible = menu.visible)
	menu.quit_to_title.connect(func(): if _gs: _gs.go_title())
	if _gs:
		_gs.profile_changed.connect(_refresh_static)
		_gs.quest_changed.connect(_on_quest)
		_gs.item_gained.connect(_on_item)
		_gs.objective_changed.connect(_refresh_static)
		_gs.hint.connect(_on_hint)
	_refresh_static()


func _exit_tree() -> void:
	if _gs:
		for pair in [[_gs.profile_changed, _refresh_static], [_gs.quest_changed, _on_quest], [_gs.item_gained, _on_item],
				[_gs.objective_changed, _refresh_static], [_gs.hint, _on_hint]]:
			if (pair[0] as Signal).is_connected(pair[1]):
				(pair[0] as Signal).disconnect(pair[1])


## Vrai si une position d'écran tombe sur un élément d'interface (le toucher ne doit pas déplacer).
func blocks(screen_pos: Vector2) -> bool:
	for c in [_attack, carnet, shop, atelier, reward, minimap, bigmap, menu, _carnet_btn, _menu_btn, _potion, _hint_box] + _slots:
		if c.visible and c.get_global_rect().has_point(screen_pos):
			return true
	return false


func open_shop(id: String) -> void:
	Sfx.play("ui_open")
	carnet.visible = false
	atelier.visible = false
	shop.open(id)


func open_workshop(id: String) -> void:
	Sfx.play("ui_open")
	carnet.visible = false
	shop.visible = false
	atelier.open(id)


func toggle_menu() -> void:
	if shop.visible or atelier.visible or bigmap.visible:   # Échap ferme d'abord la fenêtre ouverte
		shop.visible = false
		atelier.visible = false
		bigmap.visible = false
		minimap.visible = minimap.available()
		return
	if menu.visible:
		menu.close()
	else:
		carnet.visible = false
		shop.visible = false
		atelier.visible = false
		menu.open()


func _on_hint(_key: String, text: String) -> void:
	_hint_queue.append(text)


## Carte de la zone en grand (touche M, ou toucher la mini-carte).
func toggle_map() -> void:
	if not minimap.available():
		return
	var open := not bigmap.visible
	Sfx.play("ui_page")
	carnet.visible = false
	shop.visible = false
	atelier.visible = false
	bigmap.visible = open
	minimap.visible = not open


func toggle_carnet() -> void:
	shop.visible = false
	atelier.visible = false
	if bigmap.visible:
		bigmap.visible = false
		minimap.visible = minimap.available()
	carnet.visible = not carnet.visible
	Sfx.play("ui_open" if carnet.visible else "ui_close")
	if carnet.visible:
		carnet.refresh()


func _on_slot(i: int) -> void:
	if _player:
		var why: String = _player.cast(i)
		if why != "" and why != "emplacement vide":
			flash_slot(i, why)


func flash_slot(i: int, why: String) -> void:
	_slots[i].flash()
	feed(why[0].to_upper() + why.substr(1))


## Mange / boit le meilleur soin du sac (raccourci du HUD ou touche F).
func use_potion() -> void:
	var id: String = _gs.best_heal()
	if id == "":
		_potion.flash()
		feed("Aucun soin dans le sac. Thessaly vend du Pain de Miel.")
		return
	var why: String = _gs.use_item(id)
	if why != "":
		_potion.flash()
		feed(why[0].to_upper() + why.substr(1))
	elif _player:
		var z := get_tree().get_first_node_in_group("zone")
		if z:
			z.float_text(_player.global_position + Vector2(0, -26), "+%d" % int(_gs.tpl("items", id).consumable.amount), Color("a8c84e"))


func set_target(t: Node2D) -> void:
	_target = t
	_target_t = 5.0


## Ligne du fil d'annonces : petite plaque, icône facultative.
func feed(text: String, tex: Texture2D = null) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UISkin.box("plate", 4, 2))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	row.add_child(h)
	if tex:
		var ic := TextureRect.new()
		ic.texture = tex
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(ic)
	var l := UISkin.shadowed(Label.new(), UISkin.CREAM)
	l.text = text
	h.add_child(l)
	_feed.add_child(row)
	while _feed.get_child_count() > 4:
		var old := _feed.get_child(0)
		_feed.remove_child(old)
		old.queue_free()
	row.modulate.a = 0.0
	var tw := row.create_tween()
	tw.tween_property(row, "modulate:a", 1.0, 0.15)
	tw.tween_interval(4.0)
	tw.tween_property(row, "modulate:a", 0.0, 0.8)
	tw.tween_callback(row.queue_free)


func _on_item(item_id: String, qty: int) -> void:
	feed("+%d %s" % [qty, _gs.item_name(item_id)], UISkin.item_icon(item_id))


func _on_quest(_q: String) -> void:
	_refresh_static()


## Rappel de la quête suivie : son nom, l'étape en cours (et la zone, si c'est ailleurs).
func _refresh_track(tutorial: bool) -> void:
	var qid: String = _gs.tracked_quest() if _gs else ""
	_track_box.visible = qid != "" and not tutorial
	if not _track_box.visible:
		return
	var nm: String = _gs.track_label(qid)
	_track_name.text = "◆ " + (nm if nm.length() <= 26 else nm.substr(0, 25) + "…")
	var s: Dictionary = QuestGuide.step(_gs, qid, _gs.current_zone)
	var txt: String = s.get("text", "")
	_track_step.text = txt if txt.length() <= 34 else txt.substr(0, 33) + "…"
	_track_where.text = ("› " + str(s.where)) if s.get("where", "") != "" else ""   # cible dans une autre zone
	_track_where.visible = _track_where.text != ""
	_track_box.offset_left = _track_box.offset_right      # repartir de la taille minimale (grandit vers la gauche)
	_track_box.offset_bottom = _track_box.offset_top


func _refresh_static() -> void:
	if not _gs:
		return
	var p: Dictionary = _gs.profile
	_lvl.text = str(int(p.level))
	var worn: String = p.get("title", "")
	_title_label.text = _gs.tpl("titles", worn).get("name", "") if worn != "" else ""
	_xp_bar.set_value(float(p.xp) / CombatRules.xp_to_next(p.level))
	# objectif de l'accueil (premières minutes seulement)
	for c in _quest_list.get_children():
		_quest_list.remove_child(c)
		c.queue_free()
	var any := false
	var obj: Dictionary = _gs.objective()
	if not obj.is_empty():
		any = true
		var oh := HBoxContainer.new()
		oh.add_theme_constant_override("separation", 2)
		var mk := TextureRect.new()
		mk.texture = UISkin.tex("marker_quest")
		mk.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		mk.custom_minimum_size = Vector2(10, 12)
		mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		oh.add_child(mk)
		oh.add_child(UISkin.ink(_mk("Objectif"), Color("a83a40")))
		_quest_list.add_child(oh)
		var ot := UISkin.ink(_mk(obj.text), UISkin.INK)
		ot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ot.custom_minimum_size = Vector2(150, 26)            # deux lignes réservées
		_quest_list.add_child(ot)
	# (les quêtes en cours ne s'affichent plus à l'écran : elles sont dans le Carnet › Quêtes)
	_quest_box.visible = any
	_refresh_track(any)
	# bouton d'attaque : l'arme portée (sinon le poing)
	var w: String = _gs.equipped("weapon")
	_attack.icon = UISkin.item_icon(w) if w != "" else UISkin.icon("attaque")
	_attack.icon_scale = 2
	if shop and shop.visible:
		shop.refresh()
	if atelier and atelier.visible and _gs.crafting.is_empty():
		atelier.refresh()
	# barre de compétences
	for i in 4:
		var sid: String = p.bar[i]
		_slots[i].icon = UISkin.icon(sid) if sid != "" else null
	if carnet and carnet.visible:
		carnet.refresh()


func _mk(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _process(delta: float) -> void:
	if not _gs:
		return
	var f: Fighter = _gs.fighter
	var ratio := f.hp / maxf(1.0, f.max_hp())
	var low := clampf((0.35 - ratio) / 0.35, 0.0, 1.0) if f.alive() else 0.0
	_low_hp.set_shader_parameter("intensity", low * (0.75 + 0.25 * sin(Time.get_ticks_msec() / 160.0)))
	_hp_bar.text = "%d / %d" % [ceili(f.hp), roundi(f.max_hp())]
	_hp_bar.set_value(f.hp / maxf(1.0, f.max_hp()))
	_mana_bar.set_value(f.mana / maxf(1.0, f.max_mana()))
	var fx := {}
	for e in f.effects:
		fx[e.label] = maxf(fx.get(e.label, 0.0), e.expires_at - Fighter.now())
	_fx_box.visible = not fx.is_empty()
	if _fx_box.visible:
		_fx_label.text = "  ".join(PackedStringArray(fx.keys().map(func(k): return "%s %ds" % [k, ceili(fx[k])])))
	_attack.cd = f.remaining("basic") / maxf(0.01, f.attack_cooldown())
	var heal: String = _gs.best_heal()
	_potion.icon = UISkin.item_icon(heal if heal != "" else "pain_de_miel")
	_potion.ghost = heal == ""
	_potion.badge = str(_gs.item_count(heal)) if heal != "" else ""
	_potion.cd = f.remaining("item") / 5.0
	_potion.cd_seconds = f.remaining("item")
	_potion.usable = heal != "" and f.hp < f.max_hp()
	for i in 4:
		var sid: String = _gs.profile.bar[i]
		if sid == "":
			_slots[i].cd = 0.0
			continue
		var sk: Dictionary = _gs.tpl("skills", sid)
		_slots[i].cd_seconds = f.remaining(sid)
		_slots[i].cd = f.remaining(sid) / maxf(0.01, float(sk.get("cooldown_seconds", 1)))
		_slots[i].usable = f.mana >= float(sk.get("mana_cost", 0))
	# bulles d'aide : une à la fois, 7 s ou jusqu'au toucher
	if _hint_t > 0.0:
		_hint_t -= delta
		_hint_box.modulate.a = clampf(_hint_t * 3.0, 0.0, 1.0)
		if _hint_t <= 0.0:
			_hint_box.visible = false
	elif not _hint_queue.is_empty():
		_hint_label.text = _hint_queue.pop_front()
		_hint_box.visible = true
		_hint_t = 7.0
	_target_t -= delta
	var show: bool = is_instance_valid(_target) and _target_t > 0.0 and _target.is_alive()
	_target_box.visible = show
	if show:
		var tf: Fighter = _target.fighter
		_target_name.text = "%s  ·  niv. %d" % [tf.display_name, tf.level]
		_target_bar.set_value(tf.hp / maxf(1.0, tf.max_hp()))
