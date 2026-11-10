extends SceneTree
## Tableau des contrats du jour (headless) : tirage, prendre, progresser, suivre, rendre, lendemain.
## godot --headless --path . --script tools/godot/contracts_test.gd

var gs: Node
var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK    " if ok else "ECHEC ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func(): print("TIMEOUT"); quit(2))
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await process_frame


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	gs.settings.hints = false
	gs.profile.visited = ["village_aube", "sentier_lisiere", "rive_paisible"]
	change_scene_to_file(gs.zone_path("village_aube"))
	await _wait(2.5)
	gs.current_zone = "village_aube"
	var z := current_scene
	var board: Node2D = z.find_child("tableau_contrats", true, false)
	_check(board != null and board.template_type == "board", "le tableau des contrats est sur la place")
	var list: Array = gs.contracts()
	_check(list.size() == 3, "trois contrats aujourd'hui : %s" % ", ".join(PackedStringArray(list.map(func(c): return gs.contract_title(c)))))
	_check(list.all(func(c): return c.state == "open" and int(c.gold) > 0 and int(c.xp) > 0), "chacun paie de l'or et de l'XP")
	_check(board.marker.text == "!", "marqueur « ! » sur le tableau")
	# un contrat de chasse forcé, pour le dérouler
	list[0] = gs._make_contract("hunt")
	var c: Dictionary = list[0]
	_check(c.target != "" and c.zone in gs.profile.visited, "chasse tirée dans une zone visitée (%s, %s)" % [c.target, c.zone])
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	p.global_position = board.global_position + Vector2(0, 14)
	z._open(board)
	await _wait(0.2)
	_check(z._dialog.visible and z._dialog._choices.size() == 4, "le tableau liste les 3 contrats (+ Fermer)")
	z._dialog._choose({"kind": "contract_page", "i": 0})
	z._dialog._choose({"kind": "contract_take", "i": 0})
	_check(c.state == "active" and gs.tracked_quest() == "c:0", "contrat pris : suivi automatiquement")
	var s: Dictionary = QuestGuide.step(gs, "c:0", "village_aube")
	_check(s.spec == "mob:" + c.target and s.exit != "", "la flèche mène aux %s (%s)" % [c.target, s.exit])
	z._dialog.close()
	await _wait(0.6)
	_check(z.hud._track_box.visible and z.hud._track_name.text.contains("Chasse"), "rappel à l'écran : « %s »" % z.hud._track_name.text)
	for i in int(c.count):
		gs.on_kill(c.target, 1, "normal")
	_check(c.state == "complete", "%d bêtes : contrat rempli" % int(c.count))
	_check(board.marker.text == "?", "le tableau affiche « ? »")
	s = QuestGuide.step(gs, "c:0", "village_aube")
	_check(s.spec == "tableau_contrats", "la flèche ramène au tableau")
	var gold0: int = int(gs.profile.gold)
	z._open(board)
	z._dialog._choose({"kind": "contract_page", "i": 0})
	z._dialog._choose({"kind": "contract_claim", "i": 0})
	_check(c.state == "claimed" and int(gs.profile.gold) == gold0 + int(c.gold), "contrat rendu : +%d or" % int(c.gold))
	z._dialog.close()
	# fabrication et créature marquée
	list[1] = gs._make_contract("craft")
	gs.contract_take(1)
	var cc: Dictionary = list[1]
	for i in int(cc.count):
		gs._contract_progress("craft", cc.target)
	_check(cc.state == "complete", "fabrication à %s : rempli" % cc.target)
	list[2] = gs._make_contract("marked")
	gs.contract_take(2)
	gs.on_marked_kill()
	_check(list[2].state == "complete", "créature marquée : rempli")
	# Carnet
	z.hud.toggle_carnet()
	var cn: Node = z.hud.carnet
	cn._tabs.current_tab = 4
	cn._quest_sel = "c:1"
	cn.refresh()
	await _wait(0.2)
	_check(_texts(cn._pages["Quêtes"][0]).contains("Contrats du jour") and _texts(cn._pages["Quêtes"][1]).contains("Récompense"),
		"le Carnet liste les contrats du jour")
	# le lendemain
	gs.profile.contracts.day = "2000-01-01"
	var fresh: Array = gs.contracts()
	_check(fresh.size() == 3 and fresh.all(func(x): return x.state == "open"), "le lendemain : trois nouveaux contrats")
	var rares := 0
	for i in 60:
		if not gs._make_contract("hunt").items.is_empty():
			rares += 1
	_check(rares > 5 and rares < 45, "matériau rare en prime de temps en temps (%d / 60)" % rares)
	var epic_cheap := 0
	var epic_marked := 0
	for i in 200:
		for k in ["gather", "craft", "hunt"]:
			for it in gs._make_contract(k).items:
				if gs.item_rank(it.item_id) in ["epique", "legendaire"]:
					epic_cheap += 1
		for it in gs._make_contract("marked").items:
			if gs.item_rank(it.item_id) in ["epique", "legendaire"]:
				epic_marked += 1
	_check(epic_cheap == 0, "jamais d'objet épique pour une chasse, une récolte ou une fabrication (%d)" % epic_cheap)
	_check(epic_marked > 20 and epic_marked < 110, "créature marquée : parfois un matériau épique (%d / 200)" % epic_marked)
	print("%d échec(s)" % fails)
	quit(1 if fails else 0)


func _texts(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + "\n"
	for ch in n.get_children():
		out += _texts(ch)
	return out
