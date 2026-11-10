extends PanelContainer
## Boîte de dialogue : conversation en pages (texte qui s'écrit), puis choix.
##
## Avec un PNJ : la première fois, toutes ses répliques défilent ; ensuite on arrive sur ses choix
## (« Discuter » rejoue tout). Les choix : chaque quête proposée (fiche : récit, objectifs, récompenses,
## puis Accepter / Plus tard), la quête à rendre, la quête en cours, le commerce, « Au revoir ».
## Avancer : toucher la boîte, E / Entrée / Espace ; un premier appui termine la ligne en cours.
## Les actions (accepter, rendre, commerce…) sont confiées à la zone par le signal `action`.

signal action(act: Dictionary)
signal closed

const CPS := 55.0                          # caractères par seconde (effet machine à écrire)
const PAGE_CHARS := 150                    # au-delà, un texte est coupé en plusieurs pages
const INK := Color("4f3324")
const INK_SOFT := Color("7a5030")
const ACCENT := Color("a83a40")
const GOOD := Color("4a8040")

var it: Node2D                             # l'interlocuteur
var _gs: Node
var _pages: Array = []                     # [{text, extra}]
var _choices: Array = []                   # [{label, act}] après la dernière page
var _then: Callable                        # à la fin des pages (sans choix) : suite de la conversation
var _typed := 0.0
var _portrait_box: PanelContainer
var _portrait: TextureRect
var _name: Label
var _role: Label
var _text: Label
var _extra: Label
var _pager: Label
var _buttons: HFlowContainer


func _ready() -> void:
	_gs = (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	anchor_left = 0
	anchor_right = 1
	anchor_top = 1
	anchor_bottom = 1
	offset_left = 34
	offset_right = -34
	offset_top = -100
	offset_bottom = -6
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UISkin.box("parchment", 8, 7))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 7)
	add_child(hb)
	_portrait_box = PanelContainer.new()
	_portrait_box.add_theme_stylebox_override("panel", UISkin.box("frame_dark", 8, 5))
	_portrait_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.custom_minimum_size = Vector2(40, 52)
	_portrait_box.add_child(_portrait)
	hb.add_child(_portrait_box)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	vb.add_child(name_row)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UISkin.box("plate", 4, 3))
	_name = UISkin.shadowed(Label.new(), UISkin.GOLD)
	plate.add_child(_name)
	name_row.add_child(plate)
	_role = UISkin.ink(Label.new(), UISkin.INK_FAINT)
	_role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_role)
	_pager = UISkin.ink(Label.new(), UISkin.INK_FAINT)
	_pager.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_pager)
	_text = UISkin.ink(Label.new(), INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 38)
	vb.add_child(_text)
	_extra = UISkin.ink(Label.new(), ACCENT)
	_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_extra)
	_buttons = HFlowContainer.new()
	_buttons.alignment = FlowContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("h_separation", 4)
	_buttons.add_theme_constant_override("v_separation", 2)
	vb.add_child(_buttons)
	gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
				or (e is InputEventScreenTouch and e.pressed):
			advance()
			accept_event())
	visible = false


func is_open() -> bool:
	return visible


# --------------------------------------------------------------------------- conversation
## Ouvre une conversation avec `who`. `intro` : répliques imposées avant tout (accueil d'Yvenne).
func open(who: Node2D, intro: Array = []) -> void:
	it = who
	var d: Dictionary = who.interact()
	_name.text = d.name
	_role.text = d.role
	_set_portrait(who)
	visible = true
	if who.get("template_type") == "board":
		_board_menu(true)                         # tableau des contrats du jour
		return
	if not who.get("quests") is Array or (who.quests.is_empty() and who.get("template_type") != "npc"):
		_simple(d)                                # échoppe, atelier, barque, découverte… : une page
		return
	var key: String = who.dialogue_key() if who.has_method("dialogue_key") else "base"
	var talked: bool = _gs != null and str(_gs.profile.get("talked", {}).get(who.entry_id, "")) == key
	var all: Array = who.current_dialogues() if who.has_method("current_dialogues") else Array(who.dialogues)
	var lines: Array = intro.duplicate()
	if intro.is_empty():
		if talked and not all.is_empty():
			lines = [all[randi() % all.size()]]   # déjà entendu : une réplique, puis les choix
		else:
			lines = all                            # première fois (ou nouvelles répliques) : tout défile
	if _gs:
		_gs.profile.get("talked", {})[who.entry_id] = key
	_show_pages(lines.map(func(l): return {"text": l}), _menu_choices())


## Page unique avec l'action de l'élément (commerce, fabriquer, traverser, noter…).
func _simple(d: Dictionary) -> void:
	var ch := []
	var act: Dictionary = d.get("action", {})
	if not act.is_empty():
		ch.append({"label": str(act.label).strip_edges(), "act": act})
	ch.append({"label": "Fermer", "act": {"kind": "close"}})
	_show_pages([{"text": d.text, "extra": d.extra}], ch)


func _menu_choices() -> Array:
	var ch := []
	var done: Array = it.quests.filter(func(q): return it._state(q) == "complete")
	var offer: Array = it.available_quests()
	var active: Array = it.quests.filter(func(q): return it._state(q) == "active")
	for q in done:
		ch.append({"label": "? Rendre : %s" % q.name, "act": {"kind": "turn_in_page", "quest_id": q.quest_id}})
	for q in offer:
		ch.append({"label": "! %s" % q.name, "act": {"kind": "quest_page", "quest_id": q.quest_id}})
	for q in active:
		ch.append({"label": "… %s" % q.name, "act": {"kind": "progress_page", "quest_id": q.quest_id}})
	if it.get("template_type") == "shop":
		ch.append({"label": "Commerce", "act": {"kind": "shop", "shop_id": it.template_id}})
	if not _lines().is_empty():
		ch.append({"label": "Discuter", "act": {"kind": "talk"}})
	var hints: Array = it.locked_hints()
	if not hints.is_empty() and offer.is_empty() and done.is_empty():
		_extra_hint = str(hints[0].spawn.get("hint", ""))
	ch.append({"label": "Au revoir", "act": {"kind": "close"}})
	return ch


var _extra_hint := ""


func _lines() -> Array:
	return it.current_dialogues() if it.has_method("current_dialogues") else Array(it.dialogues)


## Fiche d'une quête proposée : récit (coupé en pages), puis objectifs et récompenses.
func _quest_pages(qid: String) -> void:
	var t: Dictionary = _gs.tpl("quests", qid)
	var pages: Array = _split(str(t.get("description", ""))).map(func(s): return {"text": s})
	pages.append({"text": "« %s »\nObjectifs : %s" % [t.get("name", qid), ", ".join(PackedStringArray(_objectives(qid, t)))],
		"extra": "Récompense : " + _rewards_text(t)})
	_show_pages(pages, [
		{"label": "Accepter", "act": {"kind": "accept", "quest_id": qid}},
		{"label": "Plus tard", "act": {"kind": "menu"}}])


func _objectives(qid: String, t: Dictionary) -> Array:
	if _gs.quest_state(qid) != "":
		return _gs.quest_progress_text(qid)
	return it._objectives_preview(t)


func _rewards_text(t: Dictionary) -> String:
	var rw: Dictionary = t.get("rewards", {})
	var parts := PackedStringArray()
	if int(rw.get("xp", 0)) > 0:
		parts.append("%d XP" % int(rw.xp))
	if int(rw.get("gold", 0)) > 0:
		parts.append("%d or" % int(rw.gold))
	for i in rw.get("items", []):
		parts.append("%s ×%d" % [_gs.item_name(i.item_id), int(i.get("quantity", 1))])
	return ", ".join(parts) if not parts.is_empty() else "la gratitude de quelqu'un"


func _progress_page(qid: String) -> void:
	var t: Dictionary = _gs.tpl("quests", qid)
	_show_pages([{"text": "« %s » — %s" % [t.get("name", qid), ", ".join(PackedStringArray(_gs.quest_progress_text(qid)))],
		"extra": "Reviens quand ce sera fait."}], [{"label": "Retour", "act": {"kind": "menu"}}])


func _turn_in_page(qid: String) -> void:
	var t: Dictionary = _gs.tpl("quests", qid)
	_show_pages([{"text": "« %s » : c'est fait ?" % t.get("name", qid), "extra": "Récompense : " + _rewards_text(t)}], [
		{"label": "Rendre la quête", "act": {"kind": "turn_in", "quest_id": qid}},
		{"label": "Plus tard", "act": {"kind": "menu"}}])


## Coupe un long texte en pages, aux fins de phrase.
func _split(text: String) -> Array:
	if text.length() <= PAGE_CHARS:
		return [text]
	var out := []
	var cur := ""
	for s in text.replace(". ", ".|").replace("! ", "!|").replace("? ", "?|").replace("… ", "…|").split("|"):
		if cur != "" and (cur + " " + s).length() > PAGE_CHARS:
			out.append(cur)
			cur = s
		else:
			cur = s if cur == "" else cur + " " + s
	if cur != "":
		out.append(cur)
	return out


# --------------------------------------------------------------------------- pages et choix
func _show_pages(pages: Array, choices: Array) -> void:
	_pages = pages.filter(func(p): return str(p.get("text", "")) != "")
	if _pages.is_empty():
		_pages = [{"text": "…"}]
	_choices = choices
	_page(0)


var _idx := 0


func _page(i: int) -> void:
	_idx = i
	var p: Dictionary = _pages[i]
	_text.text = str(p.text)
	_typed = 0.0
	_text.visible_characters = 0
	var ex := str(p.get("extra", ""))
	if ex == "" and i == _pages.size() - 1 and _extra_hint != "":
		ex = _extra_hint
	_extra.text = ex
	_extra.visible = ex != ""
	_pager.text = "%d / %d" % [i + 1, _pages.size()] if _pages.size() > 1 else ""
	_clear_buttons()
	set_process(true)


func _process(delta: float) -> void:
	if not visible:
		return
	if _text.visible_characters >= 0 and _text.visible_characters < _text.text.length():
		_typed += delta * CPS
		_text.visible_characters = mini(int(_typed), _text.text.length())
		if _text.visible_characters >= _text.text.length():
			_text.visible_characters = -1
			_page_done()


func _page_done() -> void:
	_clear_buttons()
	if _idx < _pages.size() - 1:
		_add_button("Suivant »", func(): _page(_idx + 1))
		return
	for c in _choices:
		var a: Dictionary = c.act
		_add_button(c.label, func(): _choose(a))


func _clear_buttons() -> void:
	for b in _buttons.get_children():                 # pas de free() : le bouton touché traite encore son clic
		_buttons.remove_child(b)
		b.queue_free()


func _add_button(label: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = " %s " % label
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	_buttons.add_child(b)


## Avancer : finir la ligne, page suivante, ou (sur les choix) le premier choix si c'est « Suivant ».
func advance() -> void:
	if not visible:
		return
	if _text.visible_characters != -1:
		_text.visible_characters = -1
		_page_done()
		return
	if _idx < _pages.size() - 1:
		_page(_idx + 1)
	elif _choices.size() == 1:
		_choose(_choices[0].act)


## Action principale (tests, raccourci) : passe les pages et prend le premier vrai choix (quête à
## rendre, quête proposée, commerce, traverser…) jusqu'à ce qu'une action soit jouée.
func primary() -> void:
	for i in 8:
		if not visible:
			return
		_text.visible_characters = -1
		if _idx < _pages.size() - 1:
			_page(_pages.size() - 1)
			_text.visible_characters = -1
		_page_done()
		var pick = null
		for c in _choices:
			if not (c.act.kind in ["close", "talk", "menu", "progress_page", "board"]):
				pick = c
				break
		if pick == null:
			close()
			return
		var k: String = pick.act.kind
		_choose(pick.act)
		if k in ["accept", "turn_in", "shop", "workshop", "ferry", "discovery", "contract_take", "contract_claim"]:
			return


func _choose(a: Dictionary) -> void:
	match a.kind:
		"close":
			close()
		"menu":
			_extra_hint = ""
			_show_pages([{"text": _menu_line()}], _menu_choices())
		"talk":
			_extra_hint = ""
			_show_pages(_lines().map(func(l): return {"text": l}), _menu_choices())
		"board":
			_board_menu()
		"contract_page":
			_contract_page(int(a.i))
		"contract_take":
			_gs.contract_take(int(a.i))
			_show_pages([{"text": "Tu détaches la feuille et la glisses dans ton Carnet.",
				"extra": _gs.contract_progress_text(_gs.contract(int(a.i)))}],
				[{"label": "Retour", "act": {"kind": "board"}}, {"label": "Fermer", "act": {"kind": "close"}}])
		"contract_claim":
			_gs.contract_claim(int(a.i))
			_show_pages([{"text": "Quelqu'un a laissé ta paie sous la punaise, comme promis."}],
				[{"label": "Retour", "act": {"kind": "board"}}, {"label": "Fermer", "act": {"kind": "close"}}])
		"quest_page":
			_quest_pages(a.quest_id)
		"progress_page":
			_progress_page(a.quest_id)
		"turn_in_page":
			_turn_in_page(a.quest_id)
		"accept":
			action.emit(a)
			var t: Dictionary = _gs.tpl("quests", a.quest_id)
			_show_pages([{"text": "Quête acceptée : « %s »." % t.get("name", ""),
				"extra": "Objectifs : " + ", ".join(PackedStringArray(_gs.quest_progress_text(a.quest_id)))}],
				[{"label": "Merci", "act": {"kind": "menu"}}, {"label": "Au revoir", "act": {"kind": "close"}}])
		"turn_in":
			action.emit(a)
			_show_pages([{"text": _thanks_line()}],
				[{"label": "Continuer", "act": {"kind": "menu"}}, {"label": "Au revoir", "act": {"kind": "close"}}])
		_:
			action.emit(a)                            # commerce, fabriquer, traverser, noter…
			if visible and a.kind in ["shop", "workshop", "ferry", "discovery"]:
				close()


# --------------------------------------------------------------------------- tableau des contrats
func _board_menu(first := false) -> void:
	var list: Array = _gs.contracts()
	var ch := []
	var left := 0
	for i in list.size():
		var c: Dictionary = list[i]
		var mark: String = {"open": "! ", "active": "… ", "complete": "? Rendre : ", "claimed": "✓ "}.get(c.state, "")
		if c.state != "claimed":
			left += 1
		ch.append({"label": mark + _gs.contract_title(c), "act": {"kind": "contract_page", "i": i}})
	ch.append({"label": "Fermer", "act": {"kind": "close"}})
	var txt := "Trois feuilles punaisées sur le bois. On les renouvelle chaque jour." if first \
		else "Le tableau des contrats."
	if left == 0:
		txt = "Tous les contrats du jour sont remplis. De nouvelles feuilles seront punaisées demain."
	_show_pages([{"text": txt}], ch)


func _contract_page(i: int) -> void:
	var c: Dictionary = _gs.contract(i)
	var extra: String = "Récompense : " + str(_gs.contract_reward_text(c))
	var ch := []
	match str(c.state):
		"open":
			ch.append({"label": "Prendre", "act": {"kind": "contract_take", "i": i}})
		"active":
			extra = _gs.contract_progress_text(c) + "   ·   " + extra
		"complete":
			ch.append({"label": "Rendre le contrat", "act": {"kind": "contract_claim", "i": i}})
		"claimed":
			extra = "Contrat rempli."
	ch.append({"label": "Retour", "act": {"kind": "board"}})
	_show_pages([{"text": _gs.contract_text(c), "extra": extra}], ch)


func _menu_line() -> String:
	return ["Autre chose ?", "Je t'écoute.", "Oui ?", "Que puis-je pour toi ?"][randi() % 4]


func _thanks_line() -> String:
	return ["Merci, Marqué. Je n'oublierai pas.", "Tu as tenu parole. Voilà pour ta peine.",
		"C'est plus que je n'espérais. Merci."][randi() % 3]


func close() -> void:
	visible = false
	_clear_buttons()
	set_process(false)
	_extra_hint = ""
	closed.emit()


func _set_portrait(who: Node2D) -> void:
	var spr: Sprite2D = who.get_node_or_null("Sprite")
	_portrait_box.visible = spr != null and spr.texture != null
	if spr and spr.texture:
		var at := AtlasTexture.new()
		at.atlas = spr.texture
		var fw: float = spr.texture.get_width() / float(spr.hframes)
		var fh: float = spr.texture.get_height() / float(spr.vframes)
		at.region = Rect2(0, 0, fw, fh)
		_portrait.texture = at
