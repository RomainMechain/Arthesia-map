class_name UISkin
extends RefCounted
## Habillage « laiton d'aube » de l'interface : styles 9-slice et thème communs (tools/art/ui_kit.py).
## Panneaux de jeu sombres sertis de laiton, dialogues sur parchemin, Carnet relié de cuir.

const INK := Color("4f3324")        # encre brune (texte sur parchemin)
const INK_SOFT := Color("7a5030")
const INK_FAINT := Color("a8743f")
const CREAM := Color("fff4d6")      # texte sur pierre sombre
const GOLD := Color("ffe08a")
const AMBER := Color("f5b84a")
const SHADOW := Color("2a1a2e")
const STONE := Color("c4b59c")

static var _cache := {}


static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		_cache[name] = load("res://assets/art/ui/%s.png" % name)
	return _cache[name]


static func icon(name: String) -> Texture2D:
	var path := "res://assets/art/ui/icons/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null


static func item_icon(item_id: String) -> Texture2D:
	var base := item_id.get_slice("~", 0)                  # variante de rareté : même icône
	var path := "res://assets/art/ui/items/%s.png" % base
	if ResourceLoader.exists(path):
		return load(path)
	# objet crafté : il reprend l'icône d'un objet du jeu choisie à sa création
	var ml := Engine.get_main_loop() as SceneTree
	var gs: Node = ml.root.get_node_or_null("GameState") if ml else null
	if gs:
		var icon: String = str(gs.tpl("items", base).get("icon", ""))
		if icon != "" and ResourceLoader.exists("res://assets/art/ui/items/%s.png" % icon):
			return load("res://assets/art/ui/items/%s.png" % icon)
	return null


## Style 9-slice : `margin` = bords de la texture, `pad` = marge intérieure du contenu.
static func box(name: String, margin: int, pad: Variant = null) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	var p: float = float(margin) if pad == null else float(pad)
	sb.content_margin_left = p
	sb.content_margin_right = p
	sb.content_margin_top = p
	sb.content_margin_bottom = p
	return sb


static func shadowed(l: Label, col: Color = CREAM, size := 10) -> Label:
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func ink(l: Label, col: Color = INK, size := 10) -> Label:
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Thème commun : boutons de laiton, onglets en rubans, ascenseurs fins, texte crème ombré.
static func theme() -> Theme:
	if _cache.has("_theme"):
		return _cache["_theme"]
	var t := Theme.new()
	t.default_font_size = 10
	t.set_color("font_color", "Label", CREAM)
	# boutons
	t.set_stylebox("normal", "Button", box("button", 4, 3))
	t.set_stylebox("hover", "Button", box("button_hover", 4, 3))
	t.set_stylebox("pressed", "Button", box("button_pressed", 4, 3))
	t.set_stylebox("disabled", "Button", box("button_disabled", 4, 3))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(st, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color("665c55"))
	# onglets
	for st in [["tab_selected", "tab_active"], ["tab_unselected", "tab_inactive"], ["tab_hovered", "tab_inactive"]]:
		var tb := box(st[1], 4, 4)
		tb.content_margin_left = 2                   # 8 onglets doivent tenir dans le Carnet
		tb.content_margin_right = 2
		t.set_stylebox(st[0], "TabContainer", tb)
	t.set_stylebox("tab_focus", "TabContainer", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", INK)
	t.set_color("font_unselected_color", "TabContainer", Color("f0d29a"))
	t.set_color("font_hovered_color", "TabContainer", CREAM)
	t.set_constant("side_margin", "TabContainer", 0)
	# ascenseur fin, couleur cuir et laiton
	var track := StyleBoxFlat.new()
	track.bg_color = Color("d4a265")
	track.content_margin_left = 2
	track.content_margin_right = 2
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("a8743f")
	grab.content_margin_left = 2
	grab.content_margin_right = 2
	for n in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(n, "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("scroll_focus", "VScrollBar", track)
	_cache["_theme"] = t
	return t


## Barre texturée (cadre 9-slice + remplissage) : PV, mana, XP, ennemi. `ghost` montre les PV qui viennent
## d'être perdus (traînée claire qui rattrape la valeur), pour lire l'impact d'un coup.
class Bar extends Control:
	var value := 1.0
	var fill := "bar_hp"
	var text := ""
	var _ghost := 1.0
	var _frame: StyleBoxTexture

	func _init(fill_name := "bar_hp", sz := Vector2(60, 9)) -> void:
		fill = fill_name
		size = sz
		custom_minimum_size = sz
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame = UISkin.box("bar_frame", 2, 0)

	func set_value(v: float) -> void:
		v = clampf(v, 0.0, 1.0)
		if v > _ghost:
			_ghost = v
		value = v
		queue_redraw()

	func _process(delta: float) -> void:
		if _ghost > value:
			_ghost = maxf(value, _ghost - delta * 0.6)
			queue_redraw()

	func _draw() -> void:
		draw_style_box(_frame, Rect2(Vector2.ZERO, size))
		var inner := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		if _ghost > value:
			draw_rect(Rect2(inner.position, Vector2(inner.size.x * _ghost, inner.size.y)), Color("fff4d6", 0.55))
		if value > 0.0:
			draw_texture_rect(UISkin.tex(fill), Rect2(inner.position, Vector2(maxf(1.0, inner.size.x * value), inner.size.y)), false)
		if text != "":
			var f := get_theme_default_font()
			var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			var pos := Vector2((size.x - w) / 2.0, size.y - 1.0)
			draw_string(f, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UISkin.SHADOW)
			draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UISkin.CREAM)