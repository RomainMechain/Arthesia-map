extends PanelContainer
## Carnet de voyage — carnet relié de cuir, chaque onglet est une DOUBLE PAGE (gauche | reliure | droite).
## Une seule grammaire visuelle partout :
##   titres de section à l'encre soulignés d'un filet ; lignes de registre (alternées, valeurs alignées à
##   droite, sélection surlignée d'or) ; encarts de parchemin plus foncé pour les fiches de détail.
## Onglets : Personnage, Équipement, Compétences, Sac, Quêtes, Carte.

var _gs: Node
var _tabs: TabContainer
var _pages := {}                 # nom d'onglet -> [page gauche, page droite]
var _pending := {"hp": 0, "atk": 0, "def": 0, "agi": 0, "int": 0, "sag": 0}
var _focus := "hp"
var _selected_skill := ""
var _selected_item := ""
var _slot := "weapon"
var _quest_sel := ""
var _map_sel := ""
var _recipe_sel := ""

const STATS := ["hp", "atk", "def", "agi", "int", "sag"]
const STAT_NAMES := {"hp": "Points de vie", "atk": "Attaque", "def": "Défense", "agi": "Agilité",
	"int": "Intelligence", "sag": "Sagesse"}
const STAT_HELP := {
	"hp": "Tes points de vie. Quand ils tombent à zéro, tu te réveilles au village, ébranlé.",
	"atk": "Force des coups physiques : Frappe, Coup Puissant, Croc Doré, et ton coup de base.",
	"def": "Réduit tous les dégâts reçus, physiques comme magiques.",
	"agi": "Accélère ton coup de base et augmente tes chances de critique et d'esquive.",
	"int": "Force des sorts (Trait de Lumière, Éclat d'Aube) et réserve de mana.",
	"sag": "Puissance des soins et des boucliers, et régénération du mana.",
}
const SLOT_NAMES := {"title": "Titre", "weapon": "Arme", "head": "Tête", "chest": "Torse", "gloves": "Mains", "boots": "Pieds",
	"ring": "Anneau", "amulet": "Amulette"}
const SLOT_GHOST := {"weapon": "dague_villageoise", "head": "capuche_de_traqueuse", "chest": "plastron_d_ecailles",
	"gloves": "gants_de_pecheur", "boots": "bottes_de_passeuse", "ring": "anneau_de_verre_d_aube", "amulet": "amulette_du_levant"}
const SLOT_POS := {"head": Vector2(77, 2), "amulet": Vector2(128, 24), "weapon": Vector2(26, 24),
	"gloves": Vector2(26, 70), "ring": Vector2(128, 70), "chest": Vector2(55, 116), "boots": Vector2(99, 116)}
const CATEGORY := {"material": "Matériau", "consumable": "Consommable", "equipment": "Équipement", "tool": "Outil"}
const EFFECT := {"heal": "Rend %d PV", "restore_mana": "Rend %d mana", "buff_stat": "Renforce"}

const INK := Color("4f3324")
const INK_SOFT := Color("7a5030")
const INK_FAINT := Color("a8743f")
const ACCENT := Color("a83a40")      # encre rouge : à faire, à rendre, points libres
const GOOD := Color("4a8040")        # gain
const ROW_ALT := Color(0.83, 0.64, 0.4, 0.14)
const ROW_SEL := Color(1.0, 0.88, 0.54, 0.55)
const PAGE_W := 186.0


# =========================================================================== structure
func _ready() -> void:
	_gs = (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -212
	offset_right = 212
	offset_top = -129
	offset_bottom = 129
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UISkin.box("book", 11, 9))
	# support libre (pas un conteneur) : onglets plein cadre + bouton « × » dans le coin
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_tabs = TabContainer.new()
	_tabs.focus_mode = Control.FOCUS_NONE
	_tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_tabs)
	for t in ["Personnage", "Équipement", "Compétences", "Sac", "Quêtes", "Carte", "Recettes", "Bestiaire"]:
		_pages[t] = _spread(t)
	_tabs.set_tab_title(0, "Perso")
	_tabs.tab_changed.connect(func(_i):
		Sfx.play("ui_page", -3.0)
		refresh())
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.anchor_left = 1.0
	close.anchor_right = 1.0
	close.offset_left = -16
	close.offset_right = 0
	close.offset_top = 0
	close.offset_bottom = 14
	close.pressed.connect(func(): visible = false)
	holder.add_child(close)


## Une double page : [gauche | reliure | droite].
func _spread(title: String) -> Array:
	var spread := HBoxContainer.new()
	spread.name = title
	spread.add_theme_constant_override("separation", 0)
	_tabs.add_child(spread)
	var left := _page_box(spread)
	var spine := Control.new()
	spine.custom_minimum_size = Vector2(12, 0)
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spine.draw.connect(func():
		var h := spine.size.y
		spine.draw_rect(Rect2(5, 3, 1, h - 6), Color(0.48, 0.31, 0.19, 0.35))
		spine.draw_rect(Rect2(6, 3, 1, h - 6), Color(0.48, 0.31, 0.19, 0.15)))
	spread.add_child(spine)
	var right := _page_box(spread)
	return [left, right]


func _page_box(spread: HBoxContainer) -> VBoxContainer:
	var m := MarginContainer.new()
	m.custom_minimum_size = Vector2(PAGE_W, 0)
	m.clip_contents = true                         # une page ne déborde jamais sur la reliure
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 3)
	spread.add_child(m)
	# la page défile si son contenu est trop long (beaucoup d'objets, de métiers, un long texte)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	m.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v


## Le cadre de page (MarginContainer) qui contient une page (VBox dans un ScrollContainer).
func _page_root(page: Control) -> Control:
	return page.get_parent().get_parent()


## Après construction : aucun texte ne doit élargir la page. Un nom qui s'étire (SIZE_EXPAND) est
## coupé avec « … » ; un texte fixe trop long passe à la ligne.
func _fit(node: Node) -> void:
	for ch in node.get_children():
		if ch is Label:
			var l := ch as Label
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
				if l.size_flags_horizontal & Control.SIZE_EXPAND:
					l.clip_text = true
					l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				elif l.get_minimum_size().x > PAGE_W * 0.6:
					l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fit(ch)


# =========================================================================== petits composants
func _label(parent: Node, text: String, col := INK, size := 10, wrap := false) -> Label:
	var l := UISkin.ink(Label.new(), col, size)
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if parent:
		parent.add_child(l)
	return l


## Titre de section : texte à l'encre, filet jusqu'au bord, texte d'appoint à droite.
func _section(parent: Node, title: String, right := "", right_col := INK_SOFT) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	parent.add_child(h)
	_label(h, title, INK)
	var rule := Control.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.custom_minimum_size = Vector2(8, 10)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(func(): rule.draw_rect(Rect2(0, 6, rule.size.x, 1), Color(0.66, 0.45, 0.25, 0.6)))
	h.add_child(rule)
	if right != "":
		_label(h, right, right_col)


## Ligne de registre : fond alterné ou surligné, contenu en rangée. Touchable si `cb`.
func _row(parent: Node, index: int, selected := false, cb := Callable()) -> HBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ROW_SEL if selected else (ROW_ALT if index % 2 == 0 else Color(0, 0, 0, 0))
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP if cb.is_valid() else Control.MOUSE_FILTER_IGNORE
	if cb.is_valid():
		p.gui_input.connect(func(e: InputEvent):
			if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
					or (e is InputEventScreenTouch and e.pressed):
				cb.call())
	parent.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	return h


## Encart de parchemin plus foncé (fiche de détail, aide).
func _inset(parent: Node, expand := false) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.82, 0.6, 0.55)
	sb.border_color = Color(0.66, 0.45, 0.25, 0.7)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(4)
	p.add_theme_stylebox_override("panel", sb)
	if expand:
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	p.add_child(v)
	return v


## Case à cocher dessinée (objectifs de quête).
func _check(parent: Node, done: bool) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(9, 10)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		c.draw_rect(Rect2(1, 2, 7, 7), INK_SOFT, false, 1.0)
		if done:
			c.draw_rect(Rect2(3, 4, 3, 3), GOOD))
	parent.add_child(c)


func _icon(tex: Texture2D, box := 16) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.custom_minimum_size = Vector2(box, box)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _big_icon(tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.custom_minimum_size = Vector2(32, 32)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _button(text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = disabled
	b.pressed.connect(cb)
	return b


func _spacer(parent: Node) -> void:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)


func _push(parent: Node) -> void:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)


func _scroll(parent: Node) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	sc.add_child(v)
	return v


func _kv(parent: Node, index: int, key: String, value: String, vcol := INK) -> void:
	var r := _row(parent, index)
	var n := _label(r, key, INK_SOFT)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(r, value, vcol)


## Vide un conteneur sans détruire tout de suite : l'élément qu'on vient de toucher est peut-être
## encore en train de traiter son clic (le libérer maintenant ferait planter le moteur).
static func _clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


static func num(v: float) -> String:
	return str(snappedf(v, 0.1)).trim_suffix(".0").replace(".", ",")


# =========================================================================== rendu
func refresh() -> void:
	if not _gs or not is_inside_tree():
		return
	if _pending_total() > int(_gs.profile.unspent):
		_cancel()
		return
	for t in _pages:
		for page in _pages[t]:
			_clear(page)
	_build_perso(_pages["Personnage"][0], _pages["Personnage"][1])
	_build_equip(_pages["Équipement"][0], _pages["Équipement"][1])
	_build_comp(_pages["Compétences"][0], _pages["Compétences"][1])
	_build_sac(_pages["Sac"][0], _pages["Sac"][1])
	_build_quetes(_pages["Quêtes"][0], _pages["Quêtes"][1])
	_build_carte(_pages["Carte"][0], _pages["Carte"][1])
	_build_recettes(_pages["Recettes"][0], _pages["Recettes"][1])
	_build_bestiaire(_pages["Bestiaire"][0], _pages["Bestiaire"][1])
	for t in _pages:
		for page in _pages[t]:
			_fit(page)


# --------------------------------------------------------------------------- Personnage
func _pending_total() -> int:
	var n := 0
	for k in STATS:
		n += _pending[k]
	return n


func _stats(with_pending: bool) -> Dictionary:
	var f: Fighter = _gs.fighter
	var s := {}
	for k in STATS:
		var b: float = float(f.base.get(k, 0.0)) + (float(_pending[k]) * float(CombatRules.POINT_VALUE[k]) if with_pending else 0.0)
		s[k] = CombatRules.modified(b, f.effects, k)
	return s


## Chiffres de combat contre une bête de ton niveau (AGI de référence ≈ 5 + 1,4 x niveau).
func _derived(s: Dictionary) -> Array:
	var lvl: int = _gs.profile.level
	var foe_agi := 5.0 + 1.4 * lvl
	return [
		["Points de vie", "%d" % roundi(s.hp)],
		["Mana", "%d" % roundi(CombatRules.max_mana(s.int, lvl))],
		["Mana par seconde", num(CombatRules.mana_regen(s.sag, lvl))],
		["Coup de base (dégâts)", "%d" % roundi(CombatRules.BASIC_ATTACK_POWER * maxf(s.atk, s.int))],
		["Rythme du coup", ("%.2f s" % CombatRules.basic_attack_cooldown(s.agi, lvl)).replace(".", ",")],
		["Dégâts reçus", "-%d %%" % roundi(CombatRules.mitigation(s.def, lvl) * 100.0)],
		["Critique", "%d %%" % roundi(CombatRules.crit_chance(s.agi, foe_agi) * 100.0)],
		["Esquive", "%d %%" % roundi(CombatRules.dodge_chance(foe_agi, s.agi) * 100.0)],
	]


func _change(k: String, d: int) -> void:
	var free: int = int(_gs.profile.unspent) - _pending_total()
	if d > 0 and free <= 0:
		return
	_pending[k] = maxi(0, _pending[k] + d)
	_focus = k
	refresh()


func _commit() -> void:
	# on vide d'abord les points en attente : chaque spend_point redessine le Carnet, qui annulerait
	# sinon le reste (« plus de points en attente que de points libres »)
	var todo: Dictionary = _pending.duplicate()
	for k in STATS:
		_pending[k] = 0
	for k in STATS:
		for i in int(todo[k]):
			_gs.spend_point(k)
	refresh()


func _cancel() -> void:
	for k in STATS:
		_pending[k] = 0
	refresh()


func _build_perso(left: VBoxContainer, right: VBoxContainer) -> void:
	var p: Dictionary = _gs.profile
	# --- gauche : niveau, XP, caractéristiques
	var head := HBoxContainer.new()
	left.add_child(head)
	_label(head, "Niveau %d" % p.level, INK, 20)
	_push(head)
	var xpv := VBoxContainer.new()
	xpv.add_theme_constant_override("separation", 1)
	head.add_child(xpv)
	var xl := _label(xpv, "%d / %d XP" % [int(p.xp), CombatRules.xp_to_next(p.level)], INK_SOFT)
	xl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var xp := UISkin.Bar.new("bar_xp", Vector2(80, 5))
	xp.set_value(float(p.xp) / CombatRules.xp_to_next(p.level))
	xpv.add_child(xp)
	var free: int = int(p.unspent) - _pending_total()
	_section(left, "Caractéristiques", ("%d point%s libre%s" % [free, "s" if free > 1 else "", "s" if free > 1 else ""])
		if p.unspent > 0 else "", ACCENT)
	var now := _stats(false)
	var nxt := _stats(true)
	var i := 0
	for k in STATS:
		var kk: String = k
		var r := _row(left, i, _focus == k, func(): _focus = kk; refresh())
		i += 1
		r.add_child(_icon(UISkin.icon("stat_" + k), 12))
		var n := _label(r, STAT_NAMES[k], INK)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var g := _label(r, ("+%d" % roundi(nxt[k] - now[k])) if _pending[k] > 0 else "", GOOD)
		g.custom_minimum_size = Vector2(20, 0)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var v := _label(r, str(roundi(now[k])), INK)
		v.custom_minimum_size = Vector2(24, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if p.unspent > 0:
			r.add_child(_button("-", func(): _change(kk, -1), _pending[k] <= 0))
			r.add_child(_button("+", func(): _change(kk, 1), free <= 0))
	_spacer(left)
	if _pending_total() > 0:
		var act := HBoxContainer.new()
		act.alignment = BoxContainer.ALIGNMENT_END
		act.add_theme_constant_override("separation", 4)
		left.add_child(act)
		act.add_child(_button(" Annuler ", _cancel))
		act.add_child(_button(" Valider ", _commit))
	elif p.unspent == 0:
		_label(left, "Prochains points au niveau %d." % (p.level + 1), INK_FAINT)
	# --- droite : au combat + aide
	_section(right, "Au combat", "à ton niveau", INK_FAINT)
	var dn := _derived(now)
	var dx := _derived(nxt)
	for j in dn.size():
		var r := _row(right, j)
		var n := _label(r, dn[j][0], INK_SOFT)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if dx[j][1] != dn[j][1]:
			_label(r, dn[j][1] + " >", INK_FAINT)
			_label(r, dx[j][1], GOOD)
		else:
			_label(r, dn[j][1], INK)
	_spacer(right)
	var help := _inset(right)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 3)
	help.add_child(hh)
	hh.add_child(_icon(UISkin.icon("stat_" + _focus), 12))
	_label(hh, STAT_NAMES[_focus], INK)
	_push(hh)
	_label(hh, "+%s par point" % num(CombatRules.POINT_VALUE[_focus]), INK_SOFT)
	_label(help, STAT_HELP[_focus], INK_SOFT, 10, true)


# --------------------------------------------------------------------------- Équipement
## Case (sac, équipement, barre) : chaton de pierre, icône, quantité ; touchable.
class ItemCell extends Control:
	signal tapped
	var tex: Texture2D
	var ghost: Texture2D        # silhouette pâle de l'emplacement vide
	var qty := 0
	var selected := false

	func _init() -> void:
		custom_minimum_size = Vector2(30, 30)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
				or (e is InputEventScreenTouch and e.pressed):
			tapped.emit()
			accept_event()

	func _draw() -> void:
		draw_texture(UISkin.tex("slot"), Vector2.ZERO)
		if tex:
			draw_texture(tex, Vector2(7, 6))
		elif ghost:
			draw_texture(ghost, Vector2(7, 6), Color(0.6, 0.55, 0.7, 0.35))
		if selected:
			draw_rect(Rect2(1, 1, 28, 28), Color("ffe08a", 0.18))
			draw_rect(Rect2(0, 0, 30, 30), UISkin.GOLD, false, 2.0)
		if qty > 1:
			var f := get_theme_default_font()
			var s := str(qty)
			var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_string(f, Vector2(27 - w, 28), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UISkin.SHADOW)
			draw_string(f, Vector2(26 - w, 27), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UISkin.CREAM)


func _bonuses(item_id: String) -> Dictionary:
	return _gs.tpl("items", item_id).get("equipment", {}).get("stat_bonuses", {})


func _bonus_text(item_id: String) -> String:
	var parts := []
	var b := _bonuses(item_id)
	for k in b:
		parts.append("+%s %s" % [num(float(b[k])), STAT_NAMES.get(k, k)])
	return ", ".join(PackedStringArray(parts))


func _diff(cand: String, slot: String) -> Array:
	var cur: String = _gs.equipped(slot)
	var a := _bonuses(cand)
	var b := _bonuses(cur) if cur != "" else {}
	var out := []
	for k in STATS:
		var d := float(a.get(k, 0.0)) - float(b.get(k, 0.0))
		if absf(d) > 0.01:
			out.append([("+" if d > 0 else "-") + num(absf(d)) + " " + STAT_NAMES[k], d > 0])
	return out


func _build_equip(left: VBoxContainer, right: VBoxContainer) -> void:
	_section(left, "Équipement porté")
	var doll := Control.new()
	doll.custom_minimum_size = Vector2(PAGE_W, 148)
	left.add_child(doll)
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/art/characters/player/player_8dir.png")
	at.region = Rect2(0, 0, 24, 26)
	var portrait := TextureRect.new()
	portrait.texture = at
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.position = Vector2(68, 42)
	portrait.size = Vector2(48, 52)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll.add_child(portrait)
	for slot in SLOT_POS:
		var c := ItemCell.new()
		var it: String = _gs.equipped(slot)
		c.tex = UISkin.item_icon(it) if it != "" else null
		c.ghost = UISkin.item_icon(SLOT_GHOST[slot])
		c.selected = slot == _slot
		c.position = SLOT_POS[slot]
		var sl: String = slot
		c.tapped.connect(func(): _slot = sl; refresh())
		doll.add_child(c)
	_spacer(left)
	var tot := {}
	for sl in _gs.profile.equipment:
		var b := _bonuses(_gs.profile.equipment[sl])
		for k in b:
			tot[k] = float(tot.get(k, 0.0)) + float(b[k])
	var parts := []
	for k in STATS:
		if tot.has(k):
			parts.append("+%s %s" % [num(tot[k]), STAT_NAMES[k]])
	_kv(left, 0, "Bonus d'équipement", ", ".join(PackedStringArray(parts)) if not parts.is_empty() else "aucun",
		GOOD if not parts.is_empty() else INK_FAINT)
	# ligne du titre porté (touchable : la page de droite liste les titres)
	var worn: String = _gs.profile.get("title", "")
	var tr := _row(left, 1, _slot == "title", func(): _slot = "title"; refresh())
	tr.add_child(_icon(UISkin.tex("marker_quest"), 12))
	var tn := _label(tr, "Titre", INK_SOFT)
	tn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(tr, _gs.tpl("titles", worn).get("name", worn) if worn != "" else "aucun", INK if worn != "" else INK_FAINT)
	if _slot == "title":
		_build_titles(right)
		return
	# --- droite : l'emplacement choisi
	_section(right, SLOT_NAMES[_slot])
	var cur: String = _gs.equipped(_slot)
	var card := _inset(right)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 5)
	card.add_child(ch)
	if cur != "":
		ch.add_child(_big_icon(UISkin.item_icon(cur)))
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 0)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch.add_child(cv)
		_label(cv, _gs.item_name(cur), INK)
		_label(cv, _bonus_text(cur), GOOD, 10, true)
		var rb := _button(" Retirer ", func(): _gs.unequip(_slot); refresh())
		rb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ch.add_child(rb)
	else:
		_label(ch, "Rien de porté ici.", INK_FAINT)
	_section(right, "Dans ton sac")
	var i := 0
	for iid in _gs.profile.inventory.keys():
		if _gs.tpl("items", iid).get("equipment", {}).get("slot", "") != _slot:
			continue
		var r := _row(right, i)
		i += 1
		r.add_child(_icon(UISkin.item_icon(iid)))
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", 0)
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(nv)
		_label(nv, _gs.item_name(iid), INK)
		var dh := HFlowContainer.new()            # les écarts passent à la ligne au lieu d'élargir la page
		dh.add_theme_constant_override("h_separation", 6)
		dh.add_theme_constant_override("v_separation", 0)
		nv.add_child(dh)
		for d in _diff(iid, _slot):
			_label(dh, d[0], GOOD if d[1] else ACCENT)
		var why: String = _gs.can_equip(iid)
		var id2: String = iid
		var eb := _button(" Équiper " if why == "" else " " + why + " ", func(): _gs.equip_item(id2); refresh(), why != "")
		eb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(eb)
	if i == 0:
		_label(right, "Aucun objet de ce type." + ("  L'échoppe de Thessaly, sur la place du village, vend une Dague Villageoise."
			if _slot == "weapon" and cur == "" else ""), INK_FAINT, 10, true)


## Titres : obtenus (description, bonus, porter / retirer) ; les autres restent secrets.
func _build_titles(right: VBoxContainer) -> void:
	var owned: Array = _gs.profile.get("titles", [])
	var all: Array = _gs.title_ids()
	_section(right, "Titres", "%d / %d" % [owned.size(), all.size()], INK_FAINT)
	var list := _scroll(right)
	var worn: String = _gs.profile.get("title", "")
	var i := 0
	for tid in owned:
		var t: Dictionary = _gs.tpl("titles", tid)
		var r := _row(list, i, tid == worn)
		i += 1
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(v)
		_label(v, t.get("name", tid), INK)
		var parts := []
		for e in t.get("effects", []):
			if e.get("type") == "stat_bonus_percent":
				parts.append("+%d %% %s" % [int(e.amount_percent), STAT_NAMES.get(e.stat, e.stat)])
		_label(v, ", ".join(PackedStringArray(parts)), GOOD)
		_label(v, t.get("description", ""), INK_SOFT, 10, true)
		var t2: String = tid
		var b := _button(" Retirer " if tid == worn else " Porter ", func(): _gs.equip_title("" if t2 == worn else t2); refresh())
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(b)
	var secret := all.size() - owned.size()
	if secret > 0:
		var r := _row(list, i)
		var sl := _label(r, "%s  ×%d" % ["???", secret], INK_FAINT)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(r, "accomplissements secrets", INK_FAINT)
	if owned.is_empty():
		_label(right, "Les titres récompensent de grands accomplissements. Leurs conditions restent secrètes.", INK_FAINT, 10, true)


# --------------------------------------------------------------------------- Compétences et métiers
func _effect_text(sk: Dictionary) -> String:
	var f: Fighter = _gs.fighter
	var parts := []
	for e in sk.get("effects", []):
		match e.type:
			"damage":
				parts.append("Dégâts %d" % roundi(float(e.get("base", 0)) + float(e.get("power", 0)) * f.skill_stat(sk.get("damage_type", "physical"))))
			"heal":
				parts.append("Soin %d PV" % roundi(float(e.get("base", 0)) + float(e.get("power", 0)) * f.stat("sag")))
			"shield":
				parts.append("Bouclier")
			"buff":
				parts.append("+%d %% %s" % [int(e.get("amount_percent", 0)), STAT_NAMES.get(e.get("stat", ""), "")])
	return "  ·  ".join(PackedStringArray(parts))


func _build_comp(left: VBoxContainer, right: VBoxContainer) -> void:
	var p: Dictionary = _gs.profile
	# --- gauche : barre de combat + métiers
	_section(left, "Barre de combat")
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)
	left.add_child(bar)
	for i in 4:
		var sid: String = p.bar[i]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		bar.add_child(col)
		var c := ItemCell.new()
		c.tex = UISkin.icon(sid) if sid != "" else null
		c.selected = _selected_skill != "" and _selected_skill != sid
		var idx := i
		c.tapped.connect(func():
			if _selected_skill != "":
				_gs.equip_skill(_selected_skill, idx)
				_selected_skill = ""
				refresh())
		col.add_child(c)
		var k := _label(col, str(i + 1), INK_FAINT)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(left, ("Touche un emplacement doré pour y placer « %s »." % _gs.tpl("skills", _selected_skill).get("name", ""))
		if _selected_skill != "" else "Choisis une compétence à droite, puis son emplacement.",
		GOOD if _selected_skill != "" else INK_FAINT, 10, true)
	_spacer(left)
	var crafts: Array = ["forgeron", "couturier", "sculpteur", "alchimiste", "cuisinier", "enchanteur"]
	var profs: Array = ["herboristerie", "bucheronnage", "peche", "archeologie", "chasse"]
	for p2 in p.get("professions", {}):
		if not p2 in profs and not p2 in crafts:
			profs.append(p2)
	_prof_rows(left, "Métiers de récolte", profs)
	_prof_rows(left, "Métiers d'artisanat", crafts)
	# --- droite : liste des compétences + détail
	_section(right, "Compétences", "%d connues" % p.skills.size(), INK_FAINT)
	var list := _scroll(right)
	var i := 0
	for sid in p.skills:
		var sk: Dictionary = _gs.tpl("skills", sid)
		var s2: String = sid
		var r := _row(list, i, sid == _selected_skill, func(): _selected_skill = "" if _selected_skill == s2 else s2; refresh())
		i += 1
		r.add_child(_icon(UISkin.icon(sid)))
		var tr := SkillFx.tier(sid)
		var n := _label(r, sk.get("name", sid), INK if tr < 2 else Color(SkillFx.TIER_COLORS[tr]))   # la rareté colore le nom
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot: int = p.bar.find(sid)
		if slot >= 0:
			_label(r, "[%d]" % (slot + 1), INK_SOFT)
		_label(r, "passive" if sk.get("kind") != "active" else "%d mana" % int(sk.get("mana_cost", 0)), INK_FAINT)
	var shown := 0
	for sid in _gs._skill_ids():
		if sid in p.skills or shown >= 2:
			continue
		var c: Dictionary = _gs.tpl("skills", sid).get("unlock_condition", {})
		if c.get("type") == "level":
			var r := _row(list, i)
			i += 1
			var ic := _icon(UISkin.icon(sid))
			ic.modulate = Color(1, 1, 1, 0.35)
			r.add_child(ic)
			var n := _label(r, _gs.tpl("skills", sid).get("name", sid), INK_FAINT)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_label(r, "niveau %d" % int(c.min), INK_FAINT)
			shown += 1
	var d := _inset(right)
	if _selected_skill != "":
		var sk: Dictionary = _gs.tpl("skills", _selected_skill)
		var hd := HBoxContainer.new()
		d.add_child(hd)
		_label(hd, sk.get("name", ""), INK)
		_push(hd)
		_label(hd, "%d mana · %d s" % [int(sk.get("mana_cost", 0)), int(sk.get("cooldown_seconds", 0))], INK_SOFT)
		var tr2 := SkillFx.tier(_selected_skill)
		_label(d, "Compétence " + SkillFx.TIER_NAMES[tr2], Color(SkillFx.TIER_COLORS[tr2]))
		_label(d, sk.get("description", ""), INK_SOFT, 10, true)
		_label(d, _effect_text(sk), GOOD)
	else:
		_label(d, "Touche une compétence pour lire sa description.", INK_FAINT, 10, true)


func _prof_rows(left: VBoxContainer, title: String, profs: Array) -> void:
	_section(left, title)
	var j := 0
	for p2 in profs:
		var r := _row(left, j)
		j += 1
		var n := _label(r, _gs.PROF_NAMES.get(p2, p2), INK)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pb := UISkin.Bar.new("bar_xp", Vector2(50, 5))
		pb.set_value(_gs.prof_xp(p2) / _gs.prof_to_next(_gs.prof_level(p2)))
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(pb)
		var lv := _label(r, "niv. %d" % _gs.prof_level(p2), INK_SOFT)
		lv.custom_minimum_size = Vector2(32, 0)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


# --------------------------------------------------------------------------- Sac
func _build_sac(left: VBoxContainer, right: VBoxContainer) -> void:
	var p: Dictionary = _gs.profile
	var n_items := 0
	for id in p.inventory:
		n_items += int(p.inventory[id])
	_section(left, "Sac", "%d objet%s" % [n_items, "s" if n_items > 1 else ""], INK_FAINT)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	left.add_child(grid)
	var ids: Array = p.inventory.keys()
	if not ids.is_empty() and not p.inventory.has(_selected_item):
		_selected_item = ids[0]
	for id in ids:
		var c := ItemCell.new()
		c.tex = UISkin.item_icon(id)
		c.qty = int(p.inventory[id])
		c.selected = id == _selected_item
		var iid: String = id
		c.tapped.connect(func(): _selected_item = iid; refresh())
		grid.add_child(c)
	for i in maxi(0, 15 - ids.size()):
		var e := ItemCell.new()
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(e)
	_spacer(left)
	var gold := _row(left, 0)
	gold.add_child(_icon(UISkin.icon("or")))
	var gl := _label(gold, "Bourse", INK_SOFT)
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(gold, "%d or" % p.gold, INK)
	# --- droite : fiche de l'objet
	if ids.is_empty():
		_section(right, "Objet")
		_label(right, "Le sac est vide. Les bêtes de la Lisière laissent toujours quelque chose derrière elles.", INK_FAINT, 10, true)
		return
	var t: Dictionary = _gs.tpl("items", _selected_item)
	_section(right, CATEGORY.get(t.get("category", ""), "Objet"))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	right.add_child(head)
	head.add_child(_big_icon(UISkin.item_icon(_selected_item)))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	head.add_child(hv)
	_label(hv, t.get("name", _selected_item), INK)
	var meta := "niveau %d" % int(t.get("level", 1))
	if t.has("equipment"):
		meta = SLOT_NAMES.get(t.equipment.get("slot", ""), "") + "  ·  " + meta
	_label(hv, meta, INK_SOFT)
	_kv(right, 0, "Quantité", str(int(p.inventory[_selected_item])))
	_kv(right, 1, "Valeur", "%d or  ·  revente %d" % [int(t.get("base_value", 0)), _gs.sell_price(_selected_item)])
	if t.has("equipment"):
		_kv(right, 2, "Bonus", _bonus_text(_selected_item), GOOD)
		_kv(right, 3, "Requis", "niveau %d" % int(t.equipment.get("level_required", 1)))
	elif t.has("consumable"):
		var c: Dictionary = t.consumable
		var fmt: String = EFFECT.get(c.get("effect_type", ""), "")
		_kv(right, 2, "Effet", (fmt % int(c.get("amount", 0))) if "%d" in fmt else fmt, GOOD)
	var d := _inset(right, true)
	_label(d, t.get("description", ""), INK_SOFT, 10, true)
	var sel: String = _selected_item
	if t.has("equipment") or t.has("consumable"):
		var acts := HBoxContainer.new()
		acts.alignment = BoxContainer.ALIGNMENT_END
		right.add_child(acts)
		if t.has("equipment"):
			var why: String = _gs.can_equip(sel)
			acts.add_child(_button(" Équiper " if why == "" else " " + why + " ", func():
				_slot = t.equipment.slot
				_gs.equip_item(sel)
				refresh(), why != ""))
		else:
			acts.add_child(_button(" Utiliser ", func():
				var res: String = _gs.use_item(sel)
				if res != "":
					_gs.notice.emit(res[0].to_upper() + res.substr(1))
				refresh()))


# --------------------------------------------------------------------------- Quêtes
func _build_quetes(left: VBoxContainer, right: VBoxContainer) -> void:
	var p: Dictionary = _gs.profile
	var order := {"complete": 0, "active": 1, "turned_in": 2}
	var ids: Array = p.quests.keys()
	ids.sort_custom(func(a, b): return order.get(p.quests[a].state, 3) < order.get(p.quests[b].state, 3))
	var n_active := ids.filter(func(q): return p.quests[q].state != "turned_in").size()
	_section(left, "Journal", "%d en cours" % n_active, INK_FAINT)
	var notes: Dictionary = p.get("notes", {})
	if ids.is_empty():
		_label(left, "Aucune quête pour l'instant. Cherche les « ! » dorés au-dessus des têtes.", INK_FAINT, 10, true)
	var is_note := _quest_sel.begins_with("note:") and notes.has(_quest_sel.substr(5))
	if not is_note and not p.quests.has(_quest_sel):
		if not ids.is_empty():
			_quest_sel = ids[0]
		elif not notes.is_empty():
			_quest_sel = "note:" + str(notes.keys()[0])
			is_note = true
	var i := 0
	for qid in ids:
		var st: String = p.quests[qid].state
		var q2: String = qid
		var r := _row(left, i, qid == _quest_sel, func(): _quest_sel = q2; refresh())
		i += 1
		r.add_child(_icon(UISkin.icon("quete")))
		var n := _label(r, ("◆ " if qid == _gs.tracked_quest() else "") + _gs.tpl("quests", qid).get("name", qid),
			INK if st != "turned_in" else INK_FAINT)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true                          # un nom long ne doit pas élargir la page
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_label(r, {"active": "en cours", "complete": "à rendre", "turned_in": "terminée"}.get(st, st),
			ACCENT if st == "complete" else INK_FAINT)
	# découvertes : notes de lore consignées en explorant
	if not notes.is_empty():
		_section(left, "Notes", "%d découverte%s" % [notes.size(), "s" if notes.size() > 1 else ""], INK_FAINT)
		var k2 := 0
		for nid in notes:
			var key: String = "note:" + str(nid)
			var r2 := _row(left, k2, key == _quest_sel, func(): _quest_sel = key; refresh())
			k2 += 1
			var n2 := _label(r2, str(notes[nid].title), INK)
			n2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n2.clip_text = true
			n2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_note:
		var note: Dictionary = notes[_quest_sel.substr(5)]
		_section(right, "Note", "découverte", INK_FAINT)
		_label(right, note.title, INK, 10)
		_label(right, note.text, INK_SOFT, 10, true)
		_spacer(right)
		_label(right, "Consignée en explorant. Certaines découvertes en appellent d'autres.", INK_FAINT, 10, true)
		return
	if ids.is_empty():
		_section(right, "Quête")
		return
	# --- droite : la quête choisie
	var t: Dictionary = _gs.tpl("quests", _quest_sel)
	var st2: String = p.quests[_quest_sel].state
	_section(right, "Quête", {"active": "en cours", "complete": "à rendre", "turned_in": "terminée"}.get(st2, ""),
		ACCENT if st2 == "complete" else INK_FAINT)
	_label(right, t.get("name", _quest_sel), INK, 10)
	_label(right, t.get("description", ""), INK_SOFT, 10, true)
	_section(right, "Objectifs")
	var j := 0
	for s in _gs.quest_progress_text(_quest_sel):
		var r := _row(right, j)
		j += 1
		var parts: PackedStringArray = (s as String).rsplit(" : ", true, 1)
		var done := st2 != "active"
		if parts.size() == 2:
			var nums := parts[1].split("/")
			done = done or (nums.size() == 2 and int(nums[0]) >= int(nums[1]))
		_check(r, done)
		var n := _label(r, parts[0], INK)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if parts.size() == 2:
			_label(r, parts[1], GOOD if done else INK)
	_section(right, "Récompense")
	var rw: Dictionary = t.get("rewards", {})
	var rr := _row(right, 0)
	rr.add_child(_icon(UISkin.icon("or")))
	_label(rr, "%d or" % int(rw.get("gold", 0)), INK)
	_push(rr)
	_label(rr, "%d XP" % int(rw.get("xp", 0)), INK_SOFT)
	var k := 1
	for it in rw.get("items", []):
		var ri := _row(right, k)
		k += 1
		ri.add_child(_icon(UISkin.item_icon(it.item_id)))
		_label(ri, "%s × %d" % [_gs.item_name(it.item_id), int(it.get("quantity", 1))], INK)
	if st2 in ["active", "complete"]:
		_spacer(right)
		var stp: Dictionary = QuestGuide.step(_gs, _quest_sel, _gs.current_zone)
		if stp.get("text", "") != "":
			var w: String = (" — " + str(stp.where)) if stp.get("where", "") != "" else ""
			_label(right, "Prochaine étape : %s%s" % [stp.text, w], ACCENT if st2 == "complete" else INK_SOFT, 10, true)
		var tracked: bool = _gs.tracked_quest() == _quest_sel
		var q3: String = _quest_sel
		var bt := _button(" Ne plus suivre " if tracked else " ◆ Suivre ", func():
			_gs.track_quest(q3)
			refresh())
		bt.size_flags_horizontal = Control.SIZE_SHRINK_END
		right.add_child(bt)


# --------------------------------------------------------------------------- Recettes
const WS_ORDER := ["forge", "couture", "sculpture", "alchimie", "cuisine", "enchantement"]


func _build_recettes(left: VBoxContainer, right: VBoxContainer) -> void:
	var recipes: Dictionary = _gs.craft_cache.recipes
	_section(left, "Recettes", "%d connue%s" % [recipes.size(), "s" if recipes.size() > 1 else ""], INK_FAINT)
	if recipes.is_empty():
		_label(left, "Aucune recette pour l'instant. Dans un atelier du village, pose des ingrédients et "
			+ "tente une combinaison : chaque recette inédite est inventée une fois, puis consignée ici.", INK_FAINT, 10, true)
		_section(right, "Recette")
		return
	if not recipes.has(_recipe_sel):
		_recipe_sel = ""
	var i := 0
	for ws in WS_ORDER:
		var keys: Array = recipes.keys().filter(func(k): return recipes[k].get("workshop", "") == ws)
		if keys.is_empty():
			continue
		keys.sort_custom(func(a, b): return float(recipes[a].get("found", 0)) > float(recipes[b].get("found", 0)))
		_label(left, _gs.tpl("workshops", ws).get("name", ws), ACCENT)
		for key in keys:
			if _recipe_sel == "":
				_recipe_sel = key
			var k2: String = key
			var it: Dictionary = _gs.tpl("items", recipes[key].item)
			var mine: Dictionary = _gs.profile.crafts.get(key, {})
			var r := _row(left, i, key == _recipe_sel, func(): _recipe_sel = k2; refresh())
			i += 1
			r.add_child(_icon(UISkin.item_icon(recipes[key].item)))
			var n := _label(r, it.get("name", "?"), INK)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if not mine.is_empty():
				var best: String = mine.best
				_label(r, "×%d" % int(mine.count),
					Color(CraftRules.RANK_COLORS[best]).darkened(0.35) if best != "commun" else INK_SOFT)
	# --- droite : la recette choisie
	var rec: Dictionary = recipes[_recipe_sel]
	var ws_id: String = rec.workshop
	var ty_label := ""
	for t in _gs.workshop_types(ws_id):
		if t.id == rec.type:
			ty_label = t.label
	_section(right, _gs.tpl("workshops", ws_id).get("name", ws_id), ty_label, INK_FAINT)
	var it2: Dictionary = _gs.tpl("items", rec.item)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	right.add_child(head)
	head.add_child(_big_icon(UISkin.item_icon(rec.item)))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	_label(hv, it2.get("name", "?"), INK, 10, true)
	_label(hv, "niveau %d  ·  cohérence %s%s" % [int(it2.get("level", 1)), rec.get("coherence", "normale"),
		"  ·  à nommer" if rec.get("pending", false) else ""], INK_SOFT, 10, true)
	if it2.has("equipment"):
		_label(right, _bonus_text(rec.item), GOOD, 10, true)
	elif it2.has("consumable"):
		_label(right, EFFECT.get(it2.consumable.effect_type, "%d") % int(it2.consumable.amount), GOOD)
	_label(right, it2.get("description", ""), INK_SOFT, 10, true)
	_section(right, "Ingrédients")
	var j := 0
	var enough := true
	for iid in rec.inputs:
		var need := int(rec.inputs[iid])
		var have: int = _gs.item_count(iid)
		enough = enough and have >= need
		var r2 := _row(right, j)
		j += 1
		r2.add_child(_icon(UISkin.item_icon(iid)))
		var n2 := _label(r2, _gs.item_name(iid), INK)
		n2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(r2, "%d / %d" % [mini(have, need), need], GOOD if have >= need else ACCENT)
	var mine2: Dictionary = _gs.profile.crafts.get(_recipe_sel, {})
	_label(right, ("Faite %d fois, au mieux %s." % [int(mine2.count), CraftRules.RANK_NAMES[mine2.best]]) if not mine2.is_empty()
		else "Découverte sur ce PC, jamais faite dans cette partie.", INK_FAINT, 10, true)
	var prepared: bool = _gs.prepared_bench.get("key", "") == _recipe_sel
	var acts := HBoxContainer.new()
	acts.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(acts)
	acts.add_child(_button(" Établi prêt " if prepared else " Préparer l'établi ", func():
		_gs.prepared_bench = {"key": _recipe_sel, "workshop": ws_id, "type": rec.type, "inputs": rec.inputs.duplicate()}
		refresh(), prepared))
	if prepared:
		_label(right, "Va à l'atelier (%s) : les ingrédients que tu as seront déjà posés." %
			_gs.tpl("workshops", ws_id).get("name", ws_id).to_lower(), GOOD, 10, true)
	elif not enough:
		_label(right, "Il te manque des ingrédients : ceux que tu as seront posés quand même.", INK_FAINT, 10, true)


# --------------------------------------------------------------------------- Carte de l'étage
const ZONE_COLORS := {"town": "f5b84a", "wilderness": "74a843", "water": "52aab8", "camp": "a8743f",
	"danger": "a83a40", "ruins": "948672", "boss": "6a2a44", "passage": "fff4d6"}
const ZONE_TYPES := {"town": "village", "wilderness": "nature", "water": "eaux", "camp": "campement",
	"danger": "danger", "ruins": "ruines", "boss": "gardien", "passage": "passage"}


## Carte à nœuds de l'étage (positions du squelette), sur toute la largeur du carnet.
class MapView extends Control:
	signal picked(zone_id: String)
	var gs: Node
	var selected := ""
	var _t := 0.0
	var _pos := {}

	func _init() -> void:
		custom_minimum_size = Vector2(380, 150)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func state(z: Dictionary) -> String:
		if z.id == gs.current_zone:
			return "here"
		if z.id in gs.profile.visited:
			return "visited"
		if gs.zone_unlocked(z.id):
			return "open"
		return "hidden" if z.get("visibility") == "hidden" else "locked"

	func quest_mark(zone_id: String) -> String:
		var path := "res://data/zones/%s/%s.json" % [gs.floor_id, zone_id]
		if not FileAccess.file_exists(path):
			return ""
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		var marks := []
		for e in (d.get("entries", []) if d is Dictionary else []):
			if e.get("template_type") != "quest_giver":
				continue
			var st: String = gs.quest_state(e.template_id)
			if st == "complete":
				marks.append("?")
			elif st == "active":
				marks.append("…")
			elif st == "" and (e.spawn.mode != "conditional" or gs.eval_condition(e.spawn.get("condition"))):
				marks.append("!")
		for m in ["?", "!", "…"]:
			if m in marks:
				return m
		return ""

	func _layout() -> void:
		var zs: Array = gs.floor_data().get("zones", [])
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for z in zs:
			lo = lo.min(Vector2(z.position.x, z.position.y))
			hi = hi.max(Vector2(z.position.x, z.position.y))
		for z in zs:
			_pos[z.id] = Vector2(lerpf(30, size.x - 30, (z.position.x - lo.x) / maxf(1, hi.x - lo.x)),
				lerpf(20, size.y - 24, (z.position.y - lo.y) / maxf(1, hi.y - lo.y)))

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
				or (e is InputEventScreenTouch and e.pressed):
			var best := ""
			var bd := 14.0
			for id in _pos:
				var d: float = (_pos[id] as Vector2).distance_to(e.position)
				if d < bd:
					best = id
					bd = d
			if best != "":
				selected = best
				picked.emit(best)
				accept_event()

	func _draw() -> void:
		if gs == null:
			return
		_layout()
		var f := get_theme_default_font()
		var zs := {}
		for z in gs.floor_data().get("zones", []):
			zs[z.id] = z
		for c in gs.floor_data().get("connections", []):
			if not (_pos.has(c[0]) and _pos.has(c[1])):
				continue
			var s0 := state(zs[c[0]])
			var s1 := state(zs[c[1]])
			if s0 == "hidden" or s1 == "hidden":
				continue
			var known: bool = s0 != "locked" and s1 != "locked"
			draw_dashed_line(_pos[c[0]], _pos[c[1]], Color("7a5030") if known else Color("a8743f", 0.35), 1.0, 3.0)
		var placed: Array = []                          # noms : dessous, ou dessus s'ils se chevauchent
		for id in _pos:
			var z: Dictionary = zs[id]
			var st := state(z)
			if st == "hidden":
				continue
			var p: Vector2 = _pos[id]
			var col := Color(ZONE_COLORS.get(z.type, "c4b59c"))
			match st:
				"locked":
					draw_circle(p, 4, Color("c4b59c", 0.5))
					draw_arc(p, 4, 0, TAU, 16, Color("a8743f", 0.8), 1.0)
				"open":
					draw_circle(p, 5, Color(col, 0.45))
					draw_arc(p, 5, 0, TAU, 16, Color("4f3324"), 1.0)
				_:
					draw_circle(p, 5, col)
					draw_arc(p, 5, 0, TAU, 16, Color("2a1a2e"), 1.0)
					draw_circle(p + Vector2(-1.5, -1.5), 1.2, Color(1, 1, 1, 0.55))
			if st == "here":
				draw_arc(p, 8.0 + sin(_t * 4.0) * 0.8, 0, TAU, 20, Color("f5b84a"), 2.0)
			if id == selected:
				draw_arc(p, 10, 0, TAU, 20, Color("a83a40"), 1.0)
			if st == "locked":
				continue
			var name: String = z.name
			var w := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			var lx := clampf(p.x - w / 2.0, 1.0, size.x - w - 1.0)
			var r := Rect2(lx, p.y + 8, w, 10)
			for o in placed:
				if r.intersects(o):
					r.position.y = p.y - 20
					break
			placed.append(r)
			draw_string(f, Vector2(r.position.x, r.position.y + 8), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color("4f3324") if st != "open" else Color("7a5030"))
			var m := quest_mark(id)
			if m != "":
				draw_texture(UISkin.tex({"!": "marker_quest", "?": "marker_turnin", "…": "marker_active"}[m]),
					p + Vector2(6, -14))


func _build_carte(left: VBoxContainer, right: VBoxContainer) -> void:
	# la carte prend toute la double page : reliure et page droite masquées
	var spread: Node = _page_root(left).get_parent()
	spread.get_child(1).visible = false
	_page_root(right).visible = false
	var fd: Dictionary = _gs.floor_data()
	_section(left, fd.get("name", "Étage"), "touche une zone", INK_FAINT)
	var mv := MapView.new()
	mv.gs = _gs
	if _map_sel == "":
		_map_sel = _gs.current_zone
	mv.selected = _map_sel
	mv.picked.connect(func(id): _map_sel = id; refresh())
	left.add_child(mv)
	var z: Dictionary = _gs.zone_info(_map_sel)
	if z.is_empty():
		return
	var st: String = mv.state(z)
	var card := _inset(left, true)
	var h := HBoxContainer.new()
	card.add_child(h)
	_label(h, z.name if st != "locked" else "Zone inconnue", INK)
	_push(h)
	_label(h, ({"here": "tu es ici", "visited": "visitée", "open": "accessible", "locked": "verrouillée"}.get(st, "")
		+ ("  ·  " + ZONE_TYPES.get(z.type, z.type) if st != "locked" else "")), ACCENT if st == "locked" else INK_SOFT)
	var txt: String = z.get("description", "") if st in ["here", "visited"] else (z.get("hint", "") if z.get("hint") else "Personne ne sait ce qu'il y a là-bas.")
	_label(card, txt, INK_SOFT, 10, true)

# --------------------------------------------------------------------------- Bestiaire
const TEMPER_TEXT := {
	"calm": "Paisible : elle ne t'attaque que si tu la frappes.",
	"predator": "Prédatrice : elle fond sur toi dès qu'elle te repère (le « ! » rouge).",
	"skittish": "Craintive : elle s'enfuit quand tu approches. Frappe avant qu'elle file.",
	"sentinel": "Sentinelle : elle garde sa place et frappe qui s'en approche.",
	"swimmer": "Nageuse : elle plonge pour esquiver, puis ressurgit pour mordre.",
	"charger": "Chargeuse : elle prend son élan et fonce droit devant. Écarte-toi de sa ligne.",
	"ambusher": "Embusquée : presque invisible dans la lumière, elle frappe quand tu passes trop près.",
	"guardian": "Gardienne : lente mais puissante, elle ne lâche pas le terrain qu'elle protège.",
	"dormant": "Endormie : on la prend pour un arbre mort… jusqu'à ce qu'on approche.",
}
const ROLE_TEXT := {"normal": "commune", "elite": "élite", "boss": "boss", "rare": "rare"}
var _beast_sel := ""


## Toutes les bêtes du monde (index des zones), dans l'ordre de niveau : {id: {temper, zones[]}}.
func _bestiary() -> Dictionary:
	var out := {}
	var idx: Dictionary = QuestGuide.index()
	for zid in idx:
		for mid in idx[zid].mobs:
			if not out.has(mid):
				out[mid] = {"temper": str(idx[zid].mobs[mid]), "zones": []}
			out[mid].zones.append(str(idx[zid].name))
	return out


func _beast_frame(mid: String) -> Texture2D:
	var path := "res://assets/art/monsters/%s_idle.png" % mid
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, tex.get_width() / 8.0, tex.get_height())
	return at


func _move_name(id: String) -> String:
	var s := id.replace("_", " ")
	return s.substr(0, 1).to_upper() + s.substr(1)


func _move_hint(mv: Dictionary) -> String:
	var area: Dictionary = mv.get("area", {}) if mv.get("area") is Dictionary else {}
	var parts := PackedStringArray()
	match area.get("shape", ""):
		"arc":
			parts.append("devant elle, de près")
		"circle":
			parts.append("tout autour d'elle")
		"line":
			parts.append("en ligne droite, loin")
	if mv.get("charge", false):
		parts.append("elle fonce")
	if float(mv.get("telegraph_seconds", 0)) > 0.0:
		parts.append("annoncée par une zone rouge : sors-en")
	elif mv.get("damage_type") == "magical":
		parts.append("magique")
	return ", ".join(parts)


func _build_bestiaire(left: VBoxContainer, right: VBoxContainer) -> void:
	var all := _bestiary()
	var ids: Array = all.keys()
	ids.sort_custom(func(a, b):
		var la := int(_gs.tpl("monsters", a).get("level", 1))
		var lb := int(_gs.tpl("monsters", b).get("level", 1))
		return la < lb or (la == lb and str(a) < str(b)))
	var seen: Dictionary = _gs.profile.get("seen", {})
	var n_seen := ids.filter(func(m): return seen.has(m)).size()
	_section(left, "Bestiaire", "%d / %d" % [n_seen, ids.size()], INK_FAINT)
	if not ids.has(_beast_sel):
		var first_seen := ids.filter(func(m): return seen.has(m))
		_beast_sel = first_seen[0] if not first_seen.is_empty() else (ids[0] if not ids.is_empty() else "")
	var i := 0
	for mid in ids:
		var known: bool = seen.has(mid)
		var m2: String = mid
		var r := _row(left, i, mid == _beast_sel, func(): _beast_sel = m2; refresh())
		i += 1
		var ic := _icon(_beast_frame(mid), 18)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not known:
			ic.modulate = Color(0.1, 0.06, 0.1, 0.55)       # silhouette : pas encore croisée
		r.add_child(ic)
		var n := _label(r, _gs.tpl("monsters", mid).get("name", mid) if known else "???", INK if known else INK_FAINT)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var k := int(_gs.profile.kills.get(mid, 0))
		_label(r, ("× %d" % k) if k > 0 else ("niv. %d" % int(_gs.tpl("monsters", mid).get("level", 1)) if known else ""), INK_SOFT)
	if _beast_sel == "":
		_section(right, "Créature")
		return
	# --- droite : la créature choisie
	var t: Dictionary = _gs.tpl("monsters", _beast_sel)
	var info: Dictionary = all[_beast_sel]
	if not seen.has(_beast_sel):
		_section(right, "Créature", "inconnue", INK_FAINT)
		var sil := _big_icon(_beast_frame(_beast_sel))
		sil.custom_minimum_size = Vector2(56, 40)
		sil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sil.modulate = Color(0.1, 0.06, 0.1, 0.55)
		right.add_child(sil)
		_label(right, "Tu ne l'as pas encore croisée.", INK_SOFT, 10, true)
		_label(right, "On en parle du côté de : " + ", ".join(PackedStringArray(info.zones)), INK_FAINT, 10, true)
		return
	_section(right, t.get("name", _beast_sel), "niv. %d · %s" % [int(t.get("level", 1)), ROLE_TEXT.get(t.get("role", "normal"), "")], INK_FAINT)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	right.add_child(top)
	var pic := _big_icon(_beast_frame(_beast_sel))
	pic.custom_minimum_size = Vector2(56, 44)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(pic)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	top.add_child(tv)
	_label(tv, TEMPER_TEXT.get(info.temper, ""), INK, 10, true)
	_label(tv, "Vaincue : %d fois" % int(_gs.profile.kills.get(_beast_sel, 0)), INK_SOFT)
	_label(right, t.get("description", ""), INK_SOFT, 10, true)
	_section(right, "Attaques")
	var j := 0
	for mv in t.get("moveset", []):
		var r2 := _row(right, j)
		j += 1
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r2.add_child(col)
		_label(col, _move_name(str(mv.get("id", "?"))), INK)
		var hint := _move_hint(mv)
		if hint != "":
			_label(col, hint, INK_SOFT, 10, true)
	_section(right, "Butin")
	var ls: Dictionary = _gs.profile.get("loot_seen", {}).get(_beast_sel, {})
	var k2 := 0
	for l in t.get("loot_table", []):
		var iid: String = str(l.get("item_id", ""))
		var got: bool = ls.has(iid)
		var r3 := _row(right, k2)
		k2 += 1
		var ic2 := _icon(UISkin.item_icon(iid))
		if not got:
			ic2.modulate = Color(0.1, 0.06, 0.1, 0.5)
		r3.add_child(ic2)
		var ln := _label(r3, _gs.item_name(iid) if got else "???", INK if got else INK_FAINT)
		ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ln.clip_text = true
		ln.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var ch := float(l.get("chance", 0.0))
		_label(r3, "rare" if ch > 0.0 and ch < 0.05 else "", ACCENT)
	_label(right, "Trouvée : " + ", ".join(PackedStringArray(info.zones)), INK_FAINT, 10, true)
