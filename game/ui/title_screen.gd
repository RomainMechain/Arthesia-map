extends Control
## Écran titre : ciel d'aube en bandes, soleil sur l'horizon, la Tour au loin (rune cyan des Architectes
## au sommet), collines et lisière ; rais de lumière et pollen. Continuer / Nouvelle partie / Réglages / Quitter.

var _gs: Node
var _buttons: VBoxContainer
var _confirm: HBoxContainer
var _menu: Control
var _t := 0.0

const SKY := ["4a3450", "5a3e5e", "6a2a44", "7a5878", "a83a40", "d9822b", "f5b84a", "ffe08a", "fff4d6"]


func _ready() -> void:
	_gs = (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	Sfx.title_screen()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UISkin.theme()
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(func(): _draw_scene(bg))
	add_child(bg)
	resized.connect(bg.queue_redraw)
	# rais de lumière par-dessus
	var rays := ColorRect.new()
	rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://game/fx/dawn_light.gdshader")
	m.set_shader_parameter("strength", 0.16)
	rays.material = m
	add_child(rays)
	_pollen()
	# titre
	var title := UISkin.shadowed(Label.new(), UISkin.GOLD, 20)
	title.text = "Arthesia"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -60
	title.offset_right = 60
	title.offset_top = 22
	title.scale = Vector2(2, 2)
	title.pivot_offset = Vector2(60, 0)
	add_child(title)
	var sub := UISkin.shadowed(Label.new(), UISkin.CREAM, 10)
	sub.text = "L'Aube qui ne Finit Jamais"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_left = 0.5
	sub.anchor_right = 0.5
	sub.offset_left = -100
	sub.offset_right = 100
	sub.offset_top = 68
	add_child(sub)
	# boutons sur une plaque sombre sertie
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UISkin.box("frame_dark", 8, 8))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -70
	panel.offset_right = 70
	panel.offset_top = -126
	panel.offset_bottom = -22
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4)
	v.add_child(_buttons)
	_confirm = HBoxContainer.new()
	_confirm.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm.visible = false
	v.add_child(_confirm)
	_build_buttons()
	var ver := UISkin.shadowed(Label.new(), Color("c4b59c"), 10)
	ver.text = "prototype · étage 1"
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -96
	ver.offset_top = -14
	ver.offset_right = -4
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)
	_menu = (load("res://game/ui/menu.gd") as GDScript).new()
	_menu.in_title = true
	add_child(_menu)


func _btn(parent: Node, text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = disabled
	b.custom_minimum_size = Vector2(0, 18)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_buttons() -> void:
	for c in _buttons.get_children():
		_buttons.remove_child(c)
		c.queue_free()
	var has_save: bool = _gs != null and _gs.has_save()
	_btn(_buttons, "Continuer", _continue, not has_save)
	_btn(_buttons, "Nouvelle partie", func():
		if has_save:
			_ask_new_game()
		else:
			_new_game())
	_btn(_buttons, "Réglages", func(): _menu.open("settings"))
	if not OS.has_feature("mobile"):
		_btn(_buttons, "Quitter", func(): get_tree().quit())


func _ask_new_game() -> void:
	for c in _confirm.get_children():
		_confirm.remove_child(c)
		c.queue_free()
	var l := UISkin.shadowed(Label.new(), Color("f0a090"))
	l.text = "Effacer la partie ?"
	_confirm.add_child(l)
	_btn(_confirm, " Oui ", _new_game)
	_btn(_confirm, " Non ", func(): _confirm.visible = false)
	_confirm.visible = true


func _continue() -> void:
	if _gs:
		_gs.start_game()


func _new_game() -> void:
	if _gs:
		_gs.new_game()
		_gs.start_game()


func _pollen() -> void:
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(260, 150)
	p.position = Vector2(240, 135)
	p.direction = Vector2(1, -0.3)
	p.spread = 60.0
	p.gravity = Vector2(0, 0.5)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.color = Color("ffe08a")
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	p.color_ramp = g
	add_child(p)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Rune au sommet de la Tour : seule touche froide de l'écran, elle pulse doucement.
func _draw() -> void:
	var tx := size.x * 0.68
	var top := size.y * 0.16
	var k := 0.6 + 0.4 * sin(_t * 1.6)
	draw_circle(Vector2(tx, top + 3), 4.0 + k * 2.0, Color("5ae8e0", 0.18 * k))
	draw_rect(Rect2(tx - 1, top + 1, 3, 4), Color("b8fff0", 0.6 + 0.4 * k))


func _draw_scene(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	var horizon := h * 0.62
	# ciel : bandes en paliers, tramées à la jonction
	var bands := SKY.size()
	for i in bands:
		var y0 := horizon * i / bands
		var y1 := horizon * (i + 1) / bands
		c.draw_rect(Rect2(0, y0, w, y1 - y0 + 1), Color(SKY[i]))
		if i + 1 < bands:
			var nxt := Color(SKY[i + 1])
			for x in range(0, int(w), 2):
				c.draw_rect(Rect2(x + (int(y1) % 2), y1 - 2, 1, 1), nxt)
	# soleil posé sur l'horizon
	var sun := Vector2(w * 0.3, horizon)
	c.draw_circle(sun, 30, Color("ffe08a"))
	c.draw_circle(sun, 24, Color("fff4d6"))
	# la Tour au loin
	var tx := w * 0.68
	var top := h * 0.16
	var tower := PackedVector2Array([Vector2(tx - 8, horizon), Vector2(tx - 5, top + 18), Vector2(tx - 3, top + 4),
		Vector2(tx, top), Vector2(tx + 3, top + 4), Vector2(tx + 5, top + 18), Vector2(tx + 8, horizon)])
	c.draw_colored_polygon(tower, Color("4a3450"))
	for i in 6:                                            # étages de la Tour
		var y := top + 22 + i * (horizon - top - 22) / 6.0
		var half := 5.0 + 3.0 * i / 6.0
		c.draw_rect(Rect2(tx - half, y, half * 2, 1), Color("6a2a44"))
	# collines et lisière
	_hills(c, horizon - 6, 14, Color("7a5878"), 0.012, 1.0)
	_hills(c, horizon + 6, 10, Color("4a3450"), 0.02, 2.0)
	c.draw_rect(Rect2(0, horizon + 10, w, h - horizon - 10), Color("2f5a3a"))
	_trees(c, horizon + 14, Color("1d3a2e"), 9.0, 3.0)
	_trees(c, horizon + 30, Color("2f5a3a"), 12.0, 7.0)
	c.draw_rect(Rect2(0, horizon + 40, w, h), Color("1d3a2e"))
	_trees(c, h - 30, Color("2a1a2e"), 16.0, 11.0)
	c.draw_rect(Rect2(0, h - 22, w, 22), Color("2a1a2e"))


func _hills(c: Control, base: float, amp: float, col: Color, freq: float, seed: float) -> void:
	var pts := PackedVector2Array([Vector2(0, c.size.y)])
	var x := 0.0
	while x <= c.size.x + 4:
		pts.append(Vector2(x, base - amp * (0.5 + 0.5 * sin(x * freq + seed)) - amp * 0.3 * sin(x * freq * 2.7 + seed * 3.0)))
		x += 4.0
	pts.append(Vector2(c.size.x, c.size.y))
	c.draw_colored_polygon(pts, col)


func _trees(c: Control, base: float, col: Color, r: float, seed: float) -> void:
	var x := -r
	var i := 0
	while x < c.size.x + r:
		var rr := r * (0.75 + 0.25 * sin(i * 1.7 + seed))
		c.draw_circle(Vector2(x, base - rr * 0.6), rr, col)
		x += r * 1.3
		i += 1
	c.draw_rect(Rect2(0, base - r * 0.2, c.size.x, r * 2), col)
