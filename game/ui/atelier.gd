extends PanelContainer
## Atelier (craft) : à gauche ton sac (toucher un objet le pose sur l'établi), à droite ce que tu veux
## fabriquer, l'établi, l'aperçu (recette connue ou inédite, chances de rareté) et le bouton. Une
## recette inédite est inventée par Claude pendant que la barre avance (GameState.craft_start).

var _gs: Node
var workshop := ""
var _type := ""
var _bench := {}                     # item_id -> quantité posée
var _title: Label
var _prof: Label
var _prof_bar: UISkin.Bar
var _bag: VBoxContainer
var _types: HFlowContainer
var _bench_box: VBoxContainer
var _preview: Label
var _odds: Label
var _bar: UISkin.Bar
var _go: Button
var _info: Label
var _work_t := 0.0


func _ready() -> void:
	_gs = (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -214
	offset_right = 214
	offset_top = -126
	offset_bottom = 126
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UISkin.box("book", 11, 9))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	_title = UISkin.ink(Label.new(), UISkin.INK, 20)
	top.add_child(_title)
	# métier de l'atelier : niveau + barre d'XP
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 1)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(pv)
	_prof = UISkin.ink(Label.new(), UISkin.INK)
	pv.add_child(_prof)
	_prof_bar = UISkin.Bar.new("bar_xp", Vector2(110, 5))
	pv.add_child(_prof_bar)
	var close := Button.new()
	close.text = " Fermer "
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): visible = false)
	top.add_child(close)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 6)
	vb.add_child(cols)
	# --- gauche : le sac
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 1)
	cols.add_child(left)
	left.add_child(_heading("Ton sac"))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sc)
	_bag = VBoxContainer.new()
	_bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag.add_theme_constant_override("separation", 1)
	sc.add_child(_bag)
	var rule := ColorRect.new()
	rule.color = UISkin.INK_FAINT
	rule.custom_minimum_size = Vector2(1, 0)
	cols.add_child(rule)
	# --- droite : type, établi, aperçu, fabrication
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.15
	right.add_theme_constant_override("separation", 2)
	cols.add_child(right)
	right.add_child(_heading("Fabriquer"))
	_types = HFlowContainer.new()
	_types.add_theme_constant_override("h_separation", 2)
	_types.add_theme_constant_override("v_separation", 2)
	right.add_child(_types)
	right.add_child(_heading("Établi"))
	_bench_box = VBoxContainer.new()
	_bench_box.add_theme_constant_override("separation", 1)
	_bench_box.custom_minimum_size = Vector2(0, 50)
	right.add_child(_bench_box)
	_preview = UISkin.ink(Label.new(), UISkin.INK)
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_preview)
	_odds = UISkin.ink(Label.new(), UISkin.INK_SOFT)
	_odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_odds)
	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 4)
	right.add_child(act)
	_bar = UISkin.Bar.new("bar_xp", Vector2(90, 6))
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	act.add_child(_bar)
	_go = Button.new()
	_go.text = " Fabriquer "
	_go.focus_mode = Control.FOCUS_NONE
	_go.pressed.connect(_on_go)
	act.add_child(_go)
	# --- bas : messages, fiche du résultat
	var info_box := PanelContainer.new()
	info_box.add_theme_stylebox_override("panel", UISkin.box("plate", 4, 4))
	info_box.custom_minimum_size = Vector2(0, 30)
	vb.add_child(info_box)
	_info = UISkin.shadowed(Label.new(), UISkin.CREAM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(_info)
	if _gs:
		_gs.craft_done.connect(_on_done)


func _exit_tree() -> void:
	if _gs and _gs.craft_done.is_connected(_on_done):
		_gs.craft_done.disconnect(_on_done)


func _heading(text: String) -> Label:
	var t := UISkin.ink(Label.new(), Color("a83a40"))
	t.text = text
	return t


func open(id: String) -> void:
	workshop = id
	visible = true
	var types: Array = _gs.workshop_types(id)
	if _type == "" or not types.any(func(t): return t.id == _type):
		_type = types[0].id if not types.is_empty() else ""
	_bench = {}
	# établi préparé depuis le Carnet › Recettes
	var prep: Dictionary = _gs.prepared_bench
	if prep.get("workshop", "") == id:
		_type = prep.type
		for iid in prep.inputs:
			var n: int = mini(int(prep.inputs[iid]), _gs.item_count(iid))
			if n > 0:
				_bench[iid] = n
		_gs.prepared_bench = {}
	var w: Dictionary = _gs.tpl("workshops", id)
	_info.text = w.get("description", "")
	if id == "enchantement":
		_info.text = "Pose un équipement et au moins un réactif, choisis l'orientation de la rune. Un objet ne s'enchante qu'une fois."
	if not _gs.craft_ai.available() or not _gs.settings.get("craft_ai", true):
		_info.text += "  Claude n'est pas joignable ici : les recettes inédites recevront un nom provisoire."
	_gs.craft_retry_pending()
	refresh()


func _clear(box: Node) -> void:
	for c in box.get_children():                # pas de free() : le bouton cliqué est encore actif
		box.remove_child(c)
		c.queue_free()


func _rank_color(item_id: String) -> Color:
	var r: String = _gs.item_rank(item_id)
	return UISkin.INK if r == "commun" else Color(CraftRules.RANK_COLORS[r]).darkened(0.35)


func _item_row(box: Control, item_id: String, right_text: String, enabled: bool, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.modulate.a = 1.0 if enabled else 0.45
	box.add_child(row)
	var ic := TextureRect.new()
	ic.texture = UISkin.item_icon(item_id)
	ic.custom_minimum_size = Vector2(16, 16)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var n := UISkin.ink(Label.new(), _rank_color(item_id))
	n.text = _gs.item_name(item_id)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(n)
	var q := UISkin.ink(Label.new(), UISkin.INK_SOFT)
	q.text = right_text
	row.add_child(q)
	row.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
				or (e is InputEventScreenTouch and e.pressed):
			cb.call())


func _bench_total() -> int:
	var n := 0
	for id in _bench:
		n += int(_bench[id])
	return n


func refresh() -> void:
	if not _gs or workshop == "":
		return
	var w: Dictionary = _gs.tpl("workshops", workshop)
	var prof: String = _gs.craft_profession(workshop)
	_title.text = w.get("name", workshop) + " "
	var lv: int = _gs.prof_level(prof)
	_prof.text = "%s · niveau %d   %d / %d XP" % [_gs.PROF_NAMES.get(prof, prof), lv, int(_gs.prof_xp(prof)), _gs.prof_to_next(lv)]
	_prof_bar.set_value(_gs.prof_xp(prof) / _gs.prof_to_next(lv))
	# sac : d'abord ce qui peut aller sur l'établi
	_clear(_bag)
	var ids: Array = _gs.profile.inventory.keys()
	ids.sort_custom(func(a, b):
		var ba: bool = _gs.ingredient_block(workshop, a) == ""
		var bb: bool = _gs.ingredient_block(workshop, b) == ""
		return ba and not bb if ba != bb else _gs.item_name(a) < _gs.item_name(b))
	if ids.is_empty():
		var e := UISkin.ink(Label.new(), UISkin.INK_FAINT)
		e.text = "Ton sac est vide."
		_bag.add_child(e)
	for id in ids:
		var id2: String = id
		var left: int = _gs.item_count(id2) - int(_bench.get(id2, 0))
		var why: String = _gs.ingredient_block(workshop, id2)
		_item_row(_bag, id2, "×%d" % left, why == "" and left > 0, func(): _add(id2))
	# types d'objet
	_clear(_types)
	for t in _gs.workshop_types(workshop):
		var b := Button.new()
		b.text = " %s " % t.label
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = t.id == _type
		b.modulate = Color.WHITE if t.id == _type else Color(1, 1, 1, 0.5)   # le choix ressort
		var tid: String = t.id
		b.pressed.connect(func(): _type = tid; refresh())
		_types.add_child(b)
	# établi
	_clear(_bench_box)
	if _bench.is_empty():
		var e2 := UISkin.ink(Label.new(), UISkin.INK_FAINT)
		e2.text = ("Pose un équipement à enchanter puis un ou plusieurs réactifs." if workshop == "enchantement"
			else "Touche un objet de ton sac pour le poser ici (%d sortes, %d en tout au plus)." % [
			CraftRules.MAX_INPUTS, CraftRules.MAX_TOTAL])
		e2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bench_box.add_child(e2)
	for id in _bench:
		var id3: String = id
		_item_row(_bench_box, id3, "×%d  retirer" % int(_bench[id3]), true, func(): _remove(id3))
	_update_preview()


func _update_preview() -> void:
	var busy: bool = not _gs.crafting.is_empty()
	var why: String = _gs.craft_check(workshop, _type, _bench) if not busy else ""
	var pv: Dictionary = _gs.craft_preview(workshop, _type, _bench)
	if busy:
		_preview.text = "Claude imagine l'objet…" if _gs.crafting.waiting_ai else "L'artisan façonne…"
	elif pv.is_empty():
		_preview.text = "Choisis quoi fabriquer, puis pose des ingrédients."
	elif pv.known:
		var mine: Dictionary = _gs.profile.crafts.get(pv.key, {})
		_preview.text = "Recette connue : %s (niv. %d)." % [pv.item.get("name", "?"), int(pv.level)] + 			("  Faite %d fois, au mieux %s." % [int(mine.count), CraftRules.RANK_NAMES[mine.best]] if not mine.is_empty() else "")
	else:
		_preview.text = "Recette inédite : Claude inventera l'objet (niv. %d). Elle sera ensuite toujours la même." % int(pv.level)
	if not pv.is_empty() and not busy:
		var parts := PackedStringArray()
		for i in 5:
			var v: float = pv.odds[i]
			if v >= 0.5:
				parts.append("%s %d %%" % [CraftRules.RANK_NAMES[CraftRules.RANKS[i]].capitalize(), roundi(v)])
		_odds.text = ("" if pv.known else "≈ ") + " · ".join(parts)
	else:
		_odds.text = ""
	_go.disabled = busy or why != ""
	_go.tooltip_text = why
	if why != "" and not pv.is_empty():
		_odds.text = why[0].to_upper() + why.substr(1) + "."


func _add(id: String) -> void:
	var why: String = _gs.ingredient_block(workshop, id)
	if why != "":
		_info.text = "%s : %s." % [_gs.item_name(id), why]
		return
	if _gs.item_count(id) - int(_bench.get(id, 0)) <= 0:
		return
	if not _bench.has(id) and _bench.size() >= CraftRules.MAX_INPUTS:
		_info.text = "%d sortes d'ingrédients au plus." % CraftRules.MAX_INPUTS
		return
	if _bench_total() >= CraftRules.MAX_TOTAL:
		_info.text = "L'établi est plein (%d ingrédients)." % CraftRules.MAX_TOTAL
		return
	_bench[id] = int(_bench.get(id, 0)) + 1
	_describe(id)
	refresh()


func _remove(id: String) -> void:
	_bench[id] = int(_bench.get(id, 0)) - 1
	if _bench[id] <= 0:
		_bench.erase(id)
	refresh()


func _on_go() -> void:
	var why: String = _gs.craft_start(workshop, _type, _bench)
	if why != "":
		_info.text = why[0].to_upper() + why.substr(1) + "."
		return
	_info.text = ""
	# l'établi garde la recette : on peut la refaire si le sac le permet
	for id in _bench.keys():
		if _gs.item_count(id) < int(_bench[id]):
			_bench[id] = _gs.item_count(id)
			if _bench[id] <= 0:
				_bench.erase(id)
	refresh()


func _on_done(item_id: String, discovered: bool) -> void:
	if not visible:
		return
	var rank: String = _gs.item_rank(item_id)
	_info.text = ("Nouvelle recette ! " if discovered else "") + _stats_line(item_id) + \
		("" if rank == "commun" else "  — rang %s !" % CraftRules.RANK_NAMES[rank])
	refresh()


func _describe(id: String) -> void:
	_info.text = _stats_line(id)


func _stats_line(item_id: String) -> String:
	var t: Dictionary = _gs.tpl("items", item_id)
	var line: String = t.get("name", item_id) + " — " + t.get("description", "")
	if t.has("equipment"):
		var parts := []
		for k in t.equipment.get("stat_bonuses", {}):
			parts.append("+%s %s" % [str(snappedf(float(t.equipment.stat_bonuses[k]), 0.1)).trim_suffix(".0").replace(".", ","), k.to_upper()])
		line += "  (" + ", ".join(PackedStringArray(parts)) + ", niv. %d)" % int(t.equipment.get("level_required", 1))
	elif t.has("consumable"):
		line += "  (%s %d)" % ["soigne" if t.consumable.effect_type == "heal" else "mana +", int(t.consumable.amount)]
	return line


func _process(_delta: float) -> void:
	if not visible or not _gs:
		return
	var pr: Dictionary = _gs.craft_progress()
	_bar.set_value(pr.get("k", 0.0))
	if not pr.is_empty():
		_work_t -= _delta
		if _work_t <= 0.0:
			_work_t = 0.75
			var snd: String = {"forge": "anvil", "sculpture": "anvil", "enchantement": "anvil", "alchimie": "potion",
				"cuisine": "gather", "couture": "ui_page"}.get(workshop, "gather")
			Sfx.play(snd, -7.0, 0.1)
	else:
		_work_t = 0.0
	if not pr.is_empty():
		_preview.text = "Claude imagine l'objet…" if pr.waiting_ai else "L'artisan façonne…"
