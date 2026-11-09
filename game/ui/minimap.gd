extends Control
## Mini-carte de la zone (image 1 px/tuile, tools/zone/compile_zone.py) et ses repères : toi, les
## quêtes (« ! » à prendre, « ? » à rendre), échoppes et ateliers, récoltes, bêtes, sorties.
## `full = false` : coin de l'écran, centrée sur toi, 2 px par tuile. `full = true` : toute la zone,
## avec le nom des sorties et une légende. Toucher l'une ouvre/ferme l'autre (touche M aussi).

signal tapped

const T := 16.0
const C_PLAYER := Color("fff4d6")
const C_OUTLINE := Color("2a1a2e")
const C_QUEST := Color("f5b84a")
const C_TURNIN := Color("ffe08a")
const C_SHOP := Color("e8c06a")
const C_GATHER := Color("a8e070")
const C_MOB := Color("e05a48")
const C_EXIT := Color("ece2cf")
const C_RUNE := Color("5ae8e0")              # le cyan : réservé aux runes (découvertes)

var full := false
var zone: Node
var _tex: Texture2D
var _tiles := Vector2.ZERO
var _t := 0.0
var _frame: StyleBox


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame = UISkin.box("frame_dark", 4, 2)
	gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
				or (e is InputEventScreenTouch and e.pressed):
			tapped.emit()
			accept_event())


func setup(z: Node) -> void:
	zone = z
	var path: String = z.get("minimap_path") if z else ""
	_tex = load(path) if path != "" and ResourceLoader.exists(path) else null
	_tiles = Vector2(_tex.get_size()) if _tex else Vector2.ZERO
	visible = _tex != null and not full
	queue_redraw()


func available() -> bool:
	return _tex != null


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


## Vue : rectangle d'écran où l'on dessine, origine (en tuiles) et échelle (px par tuile).
func _view() -> Dictionary:
	if full:
		var area := Vector2(size.x - 16, size.y - 44)
		var k := maxf(1.0, floorf(minf(area.x / _tiles.x, area.y / _tiles.y)))
		var dst := _tiles * k
		var pos := Vector2(floorf((size.x - dst.x) / 2.0), 22)
		return {"rect": Rect2(pos, dst), "origin": Vector2.ZERO, "k": k}
	var inner := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	var k2 := 2.0
	var span := inner.size / k2
	var p := _player_tile()
	var o := (p - span / 2.0).clamp(Vector2.ZERO, (_tiles - span).max(Vector2.ZERO))
	return {"rect": inner, "origin": o.floor(), "k": k2}


func _player_tile() -> Vector2:
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	return pl.global_position / T if pl else _tiles / 2.0


func _to_map(world: Vector2, v: Dictionary) -> Vector2:
	return v.rect.position + (world / T - v.origin) * v.k


func _draw() -> void:
	if not _tex:
		return
	if full:
		draw_style_box(UISkin.box("book", 11, 9), Rect2(Vector2.ZERO, size))
	else:
		draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	var v := _view()
	var r: Rect2 = v.rect
	var src := Rect2(v.origin, r.size / v.k)
	draw_texture_rect_region(_tex, r, src)
	var font := get_theme_default_font()
	# sorties
	for ex in (zone.get_node_or_null("Sorties").get_children() if zone and zone.get_node_or_null("Sorties") else []):
		if ex.get_child_count() == 0:
			continue
		var gsx := get_node_or_null("/root/GameState")
		if ex.get("secret") and gsx and not gsx.zone_unlocked(ex.get("target_zone")):
			continue
		var wp: Vector2 = ex.global_position + (ex.get_child(0) as Node2D).position
		var mp := _to_map(wp, v).clamp(r.position + Vector2(2, 2), r.end - Vector2(3, 3))
		_dot(mp, 3, C_EXIT)
		if full:
			var lbl: String = str(ex.get("label"))
			var tw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			var tp := (mp + Vector2(-tw / 2.0, -5)).clamp(Vector2(4, 12), Vector2(size.x - tw - 4, size.y - 4))
			draw_string(font, tp + Vector2(1, 1), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_OUTLINE)
			draw_string(font, tp, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_EXIT)
	# repères
	for n in get_tree().get_nodes_in_group("interactables"):
		if not (n is Node2D) or n.get("leash") != null:
			continue
		var mp2 := _to_map((n as Node2D).global_position, v)
		if not r.grow(-1).has_point(mp2):
			continue
		var tt: String = str(n.get("template_type"))
		var mk: Label = n.get("marker")
		var mt: String = mk.text if mk else ""
		if mt == "?" or mt == "!":
			continue                                 # dessinés au-dessus, après les autres
		match tt:
			"shop", "workshop", "player_market":
				_dot(mp2, 3, C_SHOP)
			"resource":
				if int(n.get("stock")) > 0:
					_dot(mp2, 2, C_GATHER)
			"discovery":
				var gs := get_node_or_null("/root/GameState")
				if gs and not gs.profile.get("notes", {}).has(n.get("data").get("note", "")):
					_dot(mp2, 3, C_RUNE)
			"ferry":
				_dot(mp2, 2, Color("a8743f"))
	var marked_pos = null
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.is_alive() and not m.get("submerged"):
			var mp3 := _to_map((m as Node2D).global_position, v)
			if m.get("dormant") or (m.get("temper") == "ambusher" and not m.get("provoked")):
				continue                                 # un arbre mort, un lynx dans la lumière : rien à voir
			if m.get("marked"):
				marked_pos = (m as Node2D).global_position
			elif r.grow(-1).has_point(mp3):
				_dot(mp3, 2, C_MOB)
	# créature marquée : repère doré qui pulse, sur la mini-carte seulement (pas l'endroit exact en grand)
	if marked_pos != null and not full:
		var mp5 := _to_map(marked_pos, v).clamp(r.position + Vector2(3, 3), r.end - Vector2(4, 4))
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		_dot(mp5, 4, Color("f5b84a").lerp(Color("fff4d6"), pulse))
	for n in get_tree().get_nodes_in_group("interactables"):
		var mk2: Label = n.get("marker") if n.get("leash") == null else null
		if mk2 == null or not (mk2.text in ["!", "?"]):
			continue
		if mk2.modulate.a < 0.6:
			continue                                 # quête verrouillée (« ! » pâle) : pas sur la carte
		var mp4 := _to_map((n as Node2D).global_position, v)
		if r.grow(-1).has_point(mp4):
			_quest_mark(mp4 + Vector2(0, -2), mk2.text == "?")
	# toi
	var pp := _to_map(_player_tile() * T, v)
	var pl := get_tree().get_first_node_in_group("player")
	var face: Vector2 = pl.get("facing") if pl else Vector2.DOWN
	draw_line(pp, pp + face.normalized() * 4.0, C_OUTLINE, 3.0)
	draw_line(pp, pp + face.normalized() * 4.0, C_PLAYER, 1.0)
	_dot(pp, 3, C_PLAYER if fmod(_t, 1.0) < 0.75 or full else Color("ffe08a"))
	if full:
		var zn: String = str(zone.get("zone_name")) if zone else ""
		draw_string(font, Vector2(12, 16), zn, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("4f3324"))
		_legend(font)


func _dot(p: Vector2, s: int, col: Color) -> void:
	var a := (p - Vector2(s, s) / 2.0).floor()
	draw_rect(Rect2(a - Vector2.ONE, Vector2(s + 2, s + 2)), C_OUTLINE)
	draw_rect(Rect2(a, Vector2(s, s)), col)


## « ! » (quête à prendre) ou « ? » (à rendre, plus clair et qui pulse), 3×6 px cerclés.
func _quest_mark(p: Vector2, turnin: bool) -> void:
	var a := p.floor() - Vector2(1, 5)
	var col := C_TURNIN if turnin else C_QUEST
	if turnin and fmod(_t, 0.8) > 0.55:
		col = Color.WHITE
	draw_rect(Rect2(a - Vector2.ONE, Vector2(5, 8)), C_OUTLINE)
	if turnin:
		draw_rect(Rect2(a, Vector2(3, 1)), col)
		draw_rect(Rect2(a + Vector2(2, 1), Vector2(1, 2)), col)
		draw_rect(Rect2(a + Vector2(1, 2), Vector2(1, 2)), col)
		draw_rect(Rect2(a + Vector2(1, 5), Vector2(1, 1)), col)
	else:
		draw_rect(Rect2(a + Vector2(1, 0), Vector2(1, 4)), col)
		draw_rect(Rect2(a + Vector2(1, 5), Vector2(1, 1)), col)


func _legend(font: Font) -> void:
	var items := [[C_PLAYER, "toi"], [C_QUEST, "quête"], [C_SHOP, "échoppe, atelier"], [C_GATHER, "récolte"],
		[C_MOB, "bête"], [C_EXIT, "sortie"]]
	var x := 14.0
	var y := size.y - 14.0
	for it in items:
		_dot(Vector2(x, y - 3), 3, it[0])
		draw_string(font, Vector2(x + 5, y), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("4f3324"))
		x += 10.0 + font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 8.0
	var hint := "M ou toucher : fermer"
	draw_string(font, Vector2(size.x - 14 - font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, 16),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("a8743f"))
