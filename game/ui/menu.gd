extends PanelContainer
## Menu (pause en jeu, ou réglages depuis l'écran titre). Pages : principale, Réglages, Commandes.
## En jeu, l'ouvrir met la partie en pause ; Échap le referme.

signal closed
signal quit_to_title

var in_title := false             # ouvert depuis l'écran titre : pas de pause ni de « retour au titre »
var _gs: Node
var _box: VBoxContainer
var _confirm_erase := false

const AMBIENCE := [[1.0, "Pleine"], [0.5, "Douce"], [0.0, "Coupée"]]


func _ready() -> void:
	_gs = (get_node_or_null("/root/GameState") if is_inside_tree() else null)
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -112
	offset_right = 112
	offset_top = -96
	offset_bottom = 96
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UISkin.box("frame_dark", 8, 10))
	theme = UISkin.theme()
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	add_child(_box)
	visible = false


func open(page := "main") -> void:
	visible = true
	_confirm_erase = false
	if not in_title:
		get_tree().paused = true
	_show(page)


func close() -> void:
	visible = false
	if not in_title:
		get_tree().paused = false
	closed.emit()


func _unhandled_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _title(text: String) -> void:
	var l := UISkin.shadowed(Label.new(), UISkin.GOLD, 20)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)
	var rule := ColorRect.new()
	rule.color = Color("f5b84a", 0.5)
	rule.custom_minimum_size = Vector2(0, 1)
	_box.add_child(rule)


func _big_button(text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 18)
	b.disabled = disabled
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


## Ligne de réglage : libellé à gauche, bouton-valeur à droite (on touche pour changer).
func _setting(label: String, value: String, cb: Callable) -> void:
	var h := HBoxContainer.new()
	_box.add_child(h)
	var l := UISkin.shadowed(Label.new(), UISkin.CREAM)
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var b := Button.new()
	b.text = " %s " % value
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(64, 0)
	b.pressed.connect(cb)
	h.add_child(b)


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func _show(page: String) -> void:
	_clear()
	match page:
		"main":
			_title("Pause")
			_big_button("Reprendre", close)
			_big_button("Réglages", func(): _show("settings"))
			_big_button("Commandes", func(): _show("controls"))
			_big_button("Retour à l'écran titre", func():
				close()
				if _gs:
					_gs.save()
				quit_to_title.emit())
			if not OS.has_feature("mobile"):
				_big_button("Quitter le jeu", func():
					if _gs:
						_gs.save()
					get_tree().quit())
		"settings":
			_title("Réglages")
			var amb: float = float(_gs.settings.get("ambience", 1.0)) if _gs else 1.0
			var idx := 0
			for i in AMBIENCE.size():
				if absf(AMBIENCE[i][0] - amb) < 0.01:
					idx = i
			_setting("Lumière d'aube", AMBIENCE[idx][1], func():
				_gs.set_setting("ambience", AMBIENCE[(idx + 1) % AMBIENCE.size()][0])
				_show("settings"))
			_setting("Vibrations", "Oui" if _gs.settings.get("vibrate", true) else "Non", func():
				_gs.set_setting("vibrate", not _gs.settings.get("vibrate", true))
				_show("settings"))
			_setting("Bulles d'aide", "Oui" if _gs.settings.get("hints", true) else "Non", func():
				_gs.set_setting("hints", not _gs.settings.get("hints", true))
				_show("settings"))
			if not in_title:
				_setting("Accueil du joueur", "Revoir", func():
					_gs.replay_tutorial()
					close())
			if _confirm_erase:
				var w := UISkin.shadowed(Label.new(), Color("f0a090"))
				w.text = "Effacer toute la progression ?"
				w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_box.add_child(w)
				var h := HBoxContainer.new()
				h.alignment = BoxContainer.ALIGNMENT_CENTER
				h.add_theme_constant_override("separation", 8)
				_box.add_child(h)
				var yes := Button.new()
				yes.text = " Oui, effacer "
				yes.focus_mode = Control.FOCUS_NONE
				yes.pressed.connect(func():
					_gs.new_game()
					_confirm_erase = false
					if in_title:
						_show("settings")
					else:
						close()
						quit_to_title.emit())
				h.add_child(yes)
				var no := Button.new()
				no.text = " Non "
				no.focus_mode = Control.FOCUS_NONE
				no.pressed.connect(func(): _confirm_erase = false; _show("settings"))
				h.add_child(no)
			else:
				_setting("Sauvegarde", "Effacer", func(): _confirm_erase = true; _show("settings"))
			var sp := Control.new()
			sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_box.add_child(sp)
			_big_button("Retour", func():
				if in_title:
					close()
				else:
					_show("main"))
		"controls":
			_title("Commandes")
			for line in [
				["Se déplacer", "toucher le sol · ZQSD"],
				["Frapper", "gros bouton · clic gauche"],
				["Compétences", "boutons en arc · 1 à 4"],
				["Se soigner", "bouton de soin · F"],
				["Parler, récolter", "toucher · E"],
				["Carnet", "bouton · Tab"],
				["Menu", "bouton · Échap"],
			]:
				var h := HBoxContainer.new()
				_box.add_child(h)
				var a := UISkin.shadowed(Label.new(), UISkin.GOLD)
				a.text = line[0]
				a.custom_minimum_size = Vector2(84, 0)
				h.add_child(a)
				var b := UISkin.shadowed(Label.new(), UISkin.CREAM)
				b.text = line[1]
				h.add_child(b)
			var sp2 := Control.new()
			sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_box.add_child(sp2)
			_big_button("Retour", func(): _show("main"))
