extends Node2D
## Racine d'une zone construite par tools/godot/build_zone.gd.
## Gère l'interaction (toucher / clic / Espace), la boîte de dialogue et les annonces.

@export var zone_id := ""
@export var zone_name := ""

const TAP_RADIUS := 16.0

var player: CharacterBody2D
var _nearest: Node2D = null
var _pending: Node2D = null
var _ui: CanvasLayer
var _dialog: PanelContainer
var _dialog_name: Label
var _dialog_text: Label
var _toast: Label
var _toast_t := 0.0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	_build_ui()
	for ex in find_children("*", "Area2D", true, false):
		if ex.has_signal("exit_reached"):
			ex.exit_reached.connect(_on_exit)
	toast(zone_name, 2.5)


func _process(delta: float) -> void:
	# PNJ le plus proche à portée : affiche son nom
	var best: Node2D = null
	var best_d := INF
	for it in get_tree().get_nodes_in_group("interactables"):
		var d: float = it.global_position.distance_to(player.global_position)
		if d < it.INTERACT_RADIUS and d < best_d:
			best = it
			best_d = d
	if best != _nearest:
		if _nearest:
			_nearest.set_highlight(false)
		if best:
			best.set_highlight(true)
		_nearest = best
	if _pending and _pending == _nearest:
		player.stop()
		_open(_pending)
		_pending = null
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if _dialog.visible:
			_dialog.visible = false
		elif _nearest:
			_open(_nearest)
		get_viewport().set_input_as_handled()
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	var dragging: bool = event is InputEventScreenDrag \
		or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
	if not (pressed or dragging):
		return
	if _dialog.visible:
		if pressed:
			_dialog.visible = false
		return
	var world: Vector2 = get_canvas_transform().affine_inverse() * event.position
	if pressed:
		_pending = _interactable_at(world)
		if _pending and _pending == _nearest:
			_open(_pending)
			_pending = null
			return
	player.move_to(world)


func _interactable_at(world: Vector2) -> Node2D:
	for it in get_tree().get_nodes_in_group("interactables"):
		# le point d'interaction est aux pieds ; on vise le corps (~10 px au-dessus)
		if (it.global_position + Vector2(0, -10)).distance_to(world) < TAP_RADIUS:
			return it
	return null


func _open(it: Node2D) -> void:
	var d: Dictionary = it.interact()
	_dialog_name.text = d.name + ("  ·  " + d.role if d.role != "" else "")
	_dialog_text.text = d.text + ("\n\n" + d.extra if d.extra != "" else "")
	_dialog.visible = true


func _on_exit(_target: String, label: String) -> void:
	toast("→ %s (zone à venir)" % label, 2.0)


func toast(text: String, seconds: float) -> void:
	_toast.text = text
	_toast_t = seconds
	_toast.modulate.a = 1.0


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var theme := Theme.new()
	theme.default_font_size = 10          # police pixel : 10 px = taille native
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	_ui.add_child(root)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 10
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_outline_color", Color("2a1a2e"))
	_toast.add_theme_constant_override("outline_size", 4)
	_toast.add_theme_color_override("font_shadow_color", Color("2a1a2e"))
	_toast.add_theme_constant_override("shadow_offset_x", 2)
	_toast.add_theme_constant_override("shadow_offset_y", 2)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_toast)

	_dialog = PanelContainer.new()
	_dialog.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dialog.offset_left = 40
	_dialog.offset_right = -40
	_dialog.offset_top = -78
	_dialog.offset_bottom = -8
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2a1a2eee")
	sb.border_color = Color("f5b84a")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	_dialog.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	_dialog.add_child(vb)
	_dialog_name = Label.new()
	_dialog_name.add_theme_color_override("font_color", Color("ffe08a"))
	_dialog_name.add_theme_font_size_override("font_size", 10)
	vb.add_child(_dialog_name)
	_dialog_text = Label.new()
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_text.add_theme_color_override("font_color", Color("fff4d6"))
	_dialog_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_dialog_text)
	_dialog.visible = false
	root.add_child(_dialog)
