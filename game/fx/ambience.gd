extends Node
## Ambiance de l'aube éternelle (posée par la zone) :
##   rais de lumière obliques, ombres de nuages qui glissent, pollen doré en suspension,
##   miroitement de l'eau, végétation qui ondule au vent et s'écarte au passage du joueur.
## Réglages par type de zone (le village est plus sobre que la forêt).

var zone: Node2D
var player: Node2D
var _rays: ShaderMaterial
var _clouds: ShaderMaterial
var _veg: ShaderMaterial
var _trees: ShaderMaterial

const PRESETS := {
	"town": {"rays": 0.10, "clouds": 0.13, "pollen": 20},
	"wilderness": {"rays": 0.15, "clouds": 0.16, "pollen": 36},
}


func setup(z: Node2D, p: Node2D, zone_type: String) -> void:
	zone = z
	player = p
	var preset: Dictionary = PRESETS.get(zone_type, PRESETS.wilderness)
	# calques plein écran au-dessus du monde, sous l'interface
	var layer := CanvasLayer.new()
	layer.name = "Ambiance"
	layer.layer = 1
	add_child(layer)
	_clouds = _overlay(layer, "res://game/fx/cloud_shadows.gdshader", preset.clouds)
	_rays = _overlay(layer, "res://game/fx/dawn_light.gdshader", preset.rays)
	_pollen(int(preset.pollen))
	_materials()
	_preset = preset
	var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	if gs:
		gs.settings_changed.connect(_apply_settings)
	_apply_settings()


var _preset: Dictionary
var _pollen_node: CPUParticles2D


## Réglage « Lumière d'aube » : pleine, douce (moitié), coupée.
func _apply_settings() -> void:
	var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	var k: float = float(gs.settings.get("ambience", 1.0)) if gs else 1.0
	_rays.set_shader_parameter("strength", _preset.rays * k)
	_clouds.set_shader_parameter("strength", _preset.clouds * k)
	if _pollen_node:
		_pollen_node.emitting = k > 0.0
		_pollen_node.visible = k > 0.0


func _exit_tree() -> void:
	var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	if gs and gs.settings_changed.is_connected(_apply_settings):
		gs.settings_changed.disconnect(_apply_settings)


func _overlay(layer: CanvasLayer, shader: String, strength: float) -> ShaderMaterial:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(shader)
	m.set_shader_parameter("strength", strength)
	r.material = m
	layer.add_child(r)
	return m


## Pollen doré : émis autour de la caméra, mais il reste dans le monde (local_coords = false).
func _pollen(amount: int) -> void:
	var cam: Node = player.get_node_or_null("Camera2D")
	if not cam:
		return
	var p := CPUParticles2D.new()
	p.name = "Pollen"
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(270, 160)
	p.direction = Vector2(1, -0.3)
	p.spread = 60.0
	p.gravity = Vector2(0, 0.6)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.color = Color("ffe08a")
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	p.color_ramp = g
	p.z_index = 40
	cam.add_child(p)
	_pollen_node = p


## Matériaux partagés : eau qui miroite, végétation qui ondule (petites plantes et arbres).
func _materials() -> void:
	var water := ShaderMaterial.new()
	water.shader = load("res://game/fx/water_shimmer.gdshader")
	for n in zone.find_children("eau_*", "TileMapLayer", true, false):
		n.material = water
	_veg = ShaderMaterial.new()
	_veg.shader = load("res://game/fx/sway.gdshader")
	_veg.set_shader_parameter("amp", 1.0)
	_veg.set_shader_parameter("push", 2.0)
	_trees = ShaderMaterial.new()
	_trees.shader = _veg.shader
	_trees.set_shader_parameter("amp", 0.6)
	_trees.set_shader_parameter("push", 0.0)
	for root_name in ["Monde", "DecorSol"]:
		var root := zone.get_node_or_null(root_name)
		if not root:
			continue
		for s in root.get_children():
			if not (s is Sprite2D) or s.texture == null:
				continue
			var path: String = s.texture.resource_path
			if "/vegetation/arbre" in path or "chene_ancien" in path:
				s.material = _trees
			elif "/vegetation/" in path or "fougere" in path:
				s.material = _veg


func _process(_delta: float) -> void:
	if not is_instance_valid(zone):
		return
	var top_left: Vector2 = -zone.get_canvas_transform().origin
	var vp: Vector2 = zone.get_viewport().get_visible_rect().size
	for m in [_rays, _clouds]:
		m.set_shader_parameter("cam_offset", top_left)
		m.set_shader_parameter("screen_px", vp)
	if is_instance_valid(player):
		_veg.set_shader_parameter("player_pos", player.global_position)
