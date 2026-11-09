extends PanelContainer
## Commerce avec un marchand (template Shop) : à gauche ses marchandises (sell_offers), à droite ton
## sac au prix de rachat (35 % de la valeur, K_SELL). Toucher un objet affiche sa fiche en bas.

var _gs: Node
var shop_id := ""
var _title: Label
var _gold: Label
var _offers: VBoxContainer
var _bag: VBoxContainer
var _info: Label
var _selected := ""


func _ready() -> void:
	_gs = (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -206
	offset_right = 206
	offset_top = -122
	offset_bottom = 122
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UISkin.box("book", 11, 9))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	_title = UISkin.ink(Label.new(), UISkin.INK, 20)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	var gi := TextureRect.new()
	gi.texture = UISkin.icon("or")
	gi.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	top.add_child(gi)
	_gold = UISkin.ink(Label.new(), UISkin.INK)
	_gold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_gold)
	var close := Button.new()
	close.text = " Fermer "
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): visible = false)
	top.add_child(close)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 6)
	vb.add_child(cols)
	_offers = _column(cols, "Marchandises")
	var rule := ColorRect.new()
	rule.color = UISkin.INK_FAINT
	rule.custom_minimum_size = Vector2(1, 0)
	cols.add_child(rule)
	_bag = _column(cols, "Ton sac (rachat à 35 %)")
	_bag.get_parent().get_parent().size_flags_stretch_ratio = 1.3
	var info_box := PanelContainer.new()
	info_box.add_theme_stylebox_override("panel", UISkin.box("plate", 4, 4))
	info_box.custom_minimum_size = Vector2(0, 30)
	vb.add_child(info_box)
	_info = UISkin.shadowed(Label.new(), UISkin.CREAM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(_info)


func _column(parent: Control, title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	parent.add_child(v)
	var t := UISkin.ink(Label.new(), Color("a83a40"))
	t.text = title
	v.add_child(t)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 1)
	sc.add_child(list)
	return list


func open(id: String) -> void:
	shop_id = id
	_selected = ""
	visible = true
	_info.text = _gs.tpl("shops", shop_id).get("description", "")
	refresh()


func _row(list: Control, item_id: String, price_text: String, btn_text: String, cb: Callable, can: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	list.add_child(row)
	var ic := TextureRect.new()
	ic.texture = UISkin.item_icon(item_id)
	ic.custom_minimum_size = Vector2(16, 16)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var n := UISkin.ink(Label.new(), Color("a83a40") if item_id == _selected else UISkin.INK)
	n.text = _gs.item_name(item_id)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	row.add_child(n)
	var p := UISkin.ink(Label.new(), UISkin.INK_SOFT)
	p.text = price_text
	row.add_child(p)
	var b := Button.new()
	b.text = btn_text
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not can
	b.pressed.connect(cb)
	row.add_child(b)
	row.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_selected = item_id
			_describe(item_id)
			refresh())


func _describe(item_id: String) -> void:
	var t: Dictionary = _gs.tpl("items", item_id)
	var line: String = t.get("name", item_id) + " — " + t.get("description", "")
	if t.has("equipment"):
		var parts := []
		for k in t.equipment.get("stat_bonuses", {}):
			parts.append("+%s %s" % [str(snappedf(float(t.equipment.stat_bonuses[k]), 0.1)).trim_suffix(".0").replace(".", ","), k.to_upper()])
		line += "  (" + ", ".join(PackedStringArray(parts)) + ", niv. %d)" % int(t.equipment.get("level_required", 1))
	_info.text = line


func refresh() -> void:
	if not _gs or shop_id == "":
		return
	var shop: Dictionary = _gs.tpl("shops", shop_id)
	_title.text = shop.get("name", shop_id)
	_gold.text = "%d or " % int(_gs.profile.gold)
	for c in _offers.get_children() + _bag.get_children():   # pas de free() : le bouton cliqué est encore actif
		c.get_parent().remove_child(c)
		c.queue_free()
	for o in shop.get("sell_offers", []):
		var iid: String = o.item_id
		_row(_offers, iid, "%d or" % int(o.price), "Acheter", func():
			var why: String = _gs.buy(shop_id, iid)
			_info.text = ("Acheté : %s." % _gs.item_name(iid)) if why == "" else why[0].to_upper() + why.substr(1) + "."
			refresh(), int(_gs.profile.gold) >= int(o.price))
	if _gs.profile.inventory.is_empty():
		var e := UISkin.ink(Label.new(), UISkin.INK_FAINT)
		e.text = "Rien à vendre."
		_bag.add_child(e)
	for iid in _gs.profile.inventory.keys():
		var id2: String = iid
		_row(_bag, id2, "×%d  %d or" % [_gs.item_count(id2), _gs.sell_price(id2)], "Vendre", func():
			var g: int = _gs.sell(id2)
			_info.text = "Vendu : %s (+%d or)." % [_gs.item_name(id2), g]
			refresh(), true)
