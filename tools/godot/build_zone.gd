extends SceneTree
## Construit res://scenes/zones/<floor>/<zone>.tscn à partir de data/build/<zone>.build.json.
## Usage : godot --headless --path . --script res://tools/godot/build_zone.gd -- floor_1 village_aube

const T := 16
const FONT_OUTLINE := Color("2a1a2e")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <floor> <zone_id>")
		quit(1)
		return
	var floor_id: String = args[0]
	var zone_id: String = args[1]
	var text := FileAccess.get_file_as_string("res://data/build/%s.build.json" % zone_id)
	var b: Dictionary = JSON.parse_string(text)
	var root := _build(b, floor_id)
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		push_error("pack: %s" % err)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://scenes/zones/%s" % floor_id)
	var out := "res://scenes/zones/%s/%s.tscn" % [floor_id, zone_id]
	err = ResourceSaver.save(scene, out)
	print("scene: ", out, " err=", err)
	root.free()
	quit(0 if err == OK else 1)


func _build(b: Dictionary, floor_id: String) -> Node2D:
	var root := Node2D.new()
	root.name = (b.zone_id as String).to_pascal_case()
	root.set_script(load("res://game/zone.gd"))
	root.set("zone_id", b.zone_id)
	root.set("zone_name", b.name)

	var mod := CanvasModulate.new()
	mod.name = "Ambiance"
	mod.color = Color(b.ambient.modulate)
	root.add_child(mod)

	# --- sol : un TileSet partagé (sauvegardé à part), une TileMapLayer par couche
	var ts := _tileset(b, floor_id)
	var sol := Node2D.new()
	sol.name = "Sol"
	root.add_child(sol)
	for layer in b.layers:
		if layer.cells.is_empty():
			continue
		var tml := TileMapLayer.new()
		tml.name = layer.name
		tml.tile_set = ts
		var src: int = ts.get_meta("sources")[layer.atlas]
		for c in layer.cells:
			tml.set_cell(Vector2i(c[0], c[1]), src, Vector2i(c[2], c[3]))
		sol.add_child(tml)

	var floor_props := Node2D.new()
	floor_props.name = "DecorSol"
	root.add_child(floor_props)
	for p in b.floor_props:
		floor_props.add_child(_sprite(p))

	# --- monde trié par profondeur (pieds) : décors, PNJ, joueur
	var world := Node2D.new()
	world.name = "Monde"
	world.y_sort_enabled = true
	root.add_child(world)
	var count := {}
	for p in b.props:
		var s := _sprite(p)
		var base := (p.sprite as String).get_file().get_basename()
		count[base] = count.get(base, 0) + 1
		s.name = "%s_%d" % [base, count[base]]
		if p.has("colliders"):
			var body := StaticBody2D.new()
			body.name = "Collision"
			for c in p.colliders:
				body.add_child(_rect_shape(Rect2(c[0], c[1], c[2], c[3])))
			s.add_child(body)
		world.add_child(s)

	for it in b.interactables:
		world.add_child(_interactable(it))

	world.add_child(_player(b))

	# --- collisions globales (forêts, eau, bords)
	var col := StaticBody2D.new()
	col.name = "Collisions"
	root.add_child(col)
	for c in b.colliders:
		if c.has("polygon"):
			var poly := CollisionPolygon2D.new()
			var pts := PackedVector2Array()
			for v in c.polygon:
				pts.append(Vector2(v[0], v[1]))
			poly.polygon = pts
			col.add_child(poly)
		else:
			var r: Array = c.rect
			col.add_child(_rect_shape(Rect2(r[0], r[1], r[2], r[3])))

	# --- sorties
	var exits := Node2D.new()
	exits.name = "Sorties"
	root.add_child(exits)
	for e in b.exits:
		var a := Area2D.new()
		a.name = e.id
		a.set_script(load("res://game/zone_exit.gd"))
		a.set("target_zone", e.to)
		a.set("label", e.label)
		var r: Array = e.rect
		a.add_child(_rect_shape(Rect2(r[0], r[1], max(r[2], T), max(r[3], T))))
		exits.add_child(a)

	# --- effets
	var fx := Node2D.new()
	fx.name = "Effets"
	root.add_child(fx)
	for f in b.fx:
		fx.add_child(_fx(f))

	_own(root, root)
	return root


func _tileset(b: Dictionary, floor_id: String) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var sources := {}
	for key in b.atlases:
		var tex: Texture2D = load(b.atlases[key])
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(T, T)
		var grid := Vector2i(tex.get_size()) / T
		for y in grid.y:
			for x in grid.x:
				src.create_tile(Vector2i(x, y))
		sources[key] = ts.add_source(src)
	ts.set_meta("sources", sources)
	var path := "res://assets/tilesets/%s.tres" % floor_id
	DirAccess.make_dir_recursive_absolute("res://assets/tilesets")
	ResourceSaver.save(ts, path, ResourceSaver.FLAG_CHANGE_PATH)
	return ts


func _sprite(p: Dictionary) -> Sprite2D:
	var s := Sprite2D.new()
	var tex: Texture2D = load(p.sprite)
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-floori(tex.get_width() / 2.0), -tex.get_height())
	s.position = Vector2(p.x, p.y)
	return s


func _rect_shape(r: Rect2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.position + r.size / 2.0
	return cs


func _label(text: String, y: float, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", FONT_OUTLINE)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_shadow_color", FONT_OUTLINE)   # police bitmap : ombre 1 px
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.size = Vector2(120, 12)
	l.position = Vector2(-60, y)
	return l


func _interactable(it: Dictionary) -> Node2D:
	var n := Node2D.new()
	n.name = it.entry_id
	n.position = Vector2(it.x, it.y)
	n.set_script(load("res://game/interactable.gd"))
	n.set("entry_id", it.entry_id)
	n.set("template_type", it.template_type)
	n.set("template_id", it.template_id)
	n.set("display_name", it.name)
	n.set("role", it.role)
	n.set("dialogues", PackedStringArray(it.get("dialogues", [])))
	n.set("quests", it.quests)
	var top := -16.0
	if it.has("sprite"):
		var tex: Texture2D = load(it.sprite)
		var s := Sprite2D.new()
		s.name = "Sprite"
		s.texture = tex
		s.hframes = 4
		s.centered = false
		s.offset = Vector2(-8, -tex.get_height())
		n.add_child(s)
		top = -tex.get_height() - 2.0
		var body := StaticBody2D.new()
		body.name = "Collision"
		body.add_child(_rect_shape(Rect2(-5, -4, 10, 4)))
		n.add_child(body)
	n.add_child(_named(_label(it.name, top - 12.0, 10, Color("fff4d6")), "Nom"))
	n.add_child(_named(_label("", top - 32.0, 20, Color("ffe08a")), "Marqueur"))
	return n


func _named(node: Node, nm: String) -> Node:
	node.name = nm
	return node


func _player(b: Dictionary) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.name = "Joueur"
	p.add_to_group("player", true)
	p.position = Vector2(b.spawn[0], b.spawn[1])
	p.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	p.set_script(load("res://game/player.gd"))
	var tex: Texture2D = load("res://assets/art/characters/player/player_idle_down.png")
	var s := Sprite2D.new()
	s.name = "Sprite"
	s.texture = tex
	s.hframes = 4
	s.centered = false
	s.offset = Vector2(-8, -tex.get_height())
	p.add_child(s)
	p.add_child(_rect_shape(Rect2(-4, -5, 8, 5)))
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position = Vector2(0, -12)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(b.size_px[0])
	cam.limit_bottom = int(b.size_px[1])
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	p.add_child(cam)
	return p


func _fx(f: Dictionary) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = Vector2(f.x, f.y)
	p.name = f.kind
	match f.kind:
		"smoke", "smoke_light":
			p.amount = 10 if f.kind == "smoke" else 6
			p.lifetime = 3.0
			p.direction = Vector2(0.3, -1)
			p.spread = 12.0
			p.gravity = Vector2(4, -6)
			p.initial_velocity_min = 6.0
			p.initial_velocity_max = 10.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
			p.color = Color("c4b59c") if f.kind == "smoke" else Color("ece2cf")
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 0.7))
			g.set_color(1, Color(1, 1, 1, 0.0))
			p.color_ramp = g
		"embers":
			p.amount = 6
			p.lifetime = 1.2
			p.direction = Vector2(0, -1)
			p.spread = 40.0
			p.gravity = Vector2(0, -10)
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 12.0
			p.color = Color("f5b84a")
		"fireflies_rune":
			p.amount = 8
			p.lifetime = 4.0
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 20.0
			p.gravity = Vector2(0, -2)
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 4.0
			p.spread = 180.0
			p.color = Color("5ae8e0")
			var g2 := Gradient.new()
			g2.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			g2.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
			p.color_ramp = g2
	return p


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(c, root)
