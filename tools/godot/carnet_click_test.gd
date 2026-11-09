extends SceneTree
## Clics dans le Carnet : chaque élément touchable doit réagir sans erreur (le Carnet se reconstruit
## pendant le clic). Usage : godot --headless --path . --script res://tools/godot/carnet_click_test.gd

var _fail := 0


func _initialize() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func(): print("ECHEC délai dépassé"); quit(2))
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_fail += 1


func _click(c: Control) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = c.size / 2.0
	c.gui_input.emit(e)
	if c.has_method("_gui_input"):
		c._gui_input(e)


func _clickables(root_node: Node, cls: String) -> Array:
	return root_node.find_children("*", cls, true, false).filter(func(n): return n.is_visible_in_tree())


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.gain_xp(CombatRules.xp_to_next(1))
	for it in [["patte_de_lapin", 3], ["poil_de_loup_dore", 2], ["dague_villageoise", 1], ["pain_de_miel", 2]]:
		gs.add_item(it[0], it[1])
	gs.accept_quest("veille_silencieuse")
	change_scene_to_file(gs.zone_path("sentier_lisiere"))
	for i in 20:
		await process_frame
	var z := current_scene
	z.hud.toggle_carnet()
	var c: Control = z.hud.carnet
	await process_frame
	# Sac : cliquer le 2e objet
	c._tabs.current_tab = 3
	await process_frame
	var cells := _clickables(c._pages["Sac"][0], "Control").filter(func(n): return n.get("qty") != null and n.tex != null)
	_click(cells[1])
	await process_frame
	await process_frame
	_check(c._selected_item == gs.profile.inventory.keys()[1], "Sac : objet choisi (%s)" % c._selected_item)
	# Compétences : cliquer une ligne puis un emplacement
	c._tabs.current_tab = 2
	await process_frame
	var rows := _clickables(c._pages["Compétences"][1], "PanelContainer").filter(func(n): return n.mouse_filter == Control.MOUSE_FILTER_STOP)
	_click(rows[1])
	await process_frame
	_check(c._selected_skill == gs.profile.skills[1], "Compétences : ligne choisie (%s)" % c._selected_skill)
	var slots := _clickables(c._pages["Compétences"][0], "Control").filter(func(n): return n.get("qty") != null)
	_click(slots[3])
	await process_frame
	_check(gs.profile.bar[3] == gs.profile.skills[1] or gs.profile.bar.has(gs.profile.skills[1]), "Compétences : placée dans l'emplacement 4 (%s)" % [gs.profile.bar])
	# Personnage : ligne de caractéristique
	c._tabs.current_tab = 0
	await process_frame
	var srows := _clickables(c._pages["Personnage"][0], "PanelContainer").filter(func(n): return n.mouse_filter == Control.MOUSE_FILTER_STOP)
	_click(srows[3])
	await process_frame
	_check(c._focus == "agi", "Personnage : caractéristique choisie (%s)" % c._focus)
	# Équipement : un emplacement
	c._tabs.current_tab = 1
	await process_frame
	var eq := _clickables(c._pages["Équipement"][0], "Control").filter(func(n): return n.get("ghost") != null)
	_click(eq[0])
	await process_frame
	_check(c._slot == "head", "Équipement : emplacement choisi (%s)" % c._slot)
	# Échoppe : bouton « Acheter » (la liste se reconstruit pendant le clic)
	c.visible = false
	gs.profile.gold = 100
	z.hud.open_shop("echoppe_thessaly")
	await process_frame
	var buy: Button = _clickables(z.hud.shop, "Button").filter(func(b): return b.text == "Acheter")[0]
	var n0: int = gs.item_count("pain_de_miel")
	buy.pressed.emit()
	await process_frame
	await process_frame
	_check(gs.item_count("pain_de_miel") == n0 + 1 and gs.profile.gold == 82, "Échoppe : achat par clic (or %d)" % gs.profile.gold)
	print("\n%d échec(s)" % _fail)
	quit(_fail)
