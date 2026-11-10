extends SceneTree
## Suivi de quête, PNJ vivants, bestiaire (headless).
## godot --headless --path . --script tools/godot/life_test.gd

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


func _go(zone: String) -> Node:
	gs.travel(gs.current_zone, zone, "")
	var t := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < t and (gs.is_travelling() or current_scene == null or current_scene.get("zone_id") != zone):
		await process_frame
	await _wait(0.5)
	return current_scene


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	change_scene_to_file(gs.zone_path("village_aube"))
	await _wait(2.5)
	gs.current_zone = "village_aube"
	var z := current_scene

	# --- 1) suivi de quête
	var idx: Dictionary = QuestGuide.index()
	_check(idx.has("village_aube") and idx.has("rive_paisible") and idx.village_aube.givers.get("intro_peche") == "npc_garin",
		"index du monde : %d zones, Garin donne la truite" % idx.size())
	var r: Dictionary = QuestGuide.route("village_aube", "foret_ancienne")
	_check(r.hops >= 1 and r.exit != "", "route village -> forêt : %d passage(s), par %s" % [r.hops, r.exit])
	gs.accept_quest("intro_peche")
	_check(gs.tracked_quest() == "intro_peche", "quête acceptée : suivie automatiquement")
	var s: Dictionary = QuestGuide.step(gs, "intro_peche", "village_aube")
	_check(s.zone == "rive_paisible" and s.spec.begins_with("res:") and s.exit != "",
		"truite : à pêcher en %s (%s), sortie %s" % [s.zone, s.spec, s.exit])
	_check(z.find_target(s.exit) != null, "la flèche trouve la sortie à prendre")
	var hud: Node = z.hud
	await _wait(0.6)
	_check(hud._track_box.visible and hud._track_where.text.contains("Rive"), "rappel à l'écran : « %s | %s | %s »" % [hud._track_name.text, hud._track_step.text, hud._track_where.text])
	gs.add_item("truite_argentee_aube", 3)
	gs._refresh_quests()
	s = QuestGuide.step(gs, "intro_peche", "village_aube")
	_check(gs.quest_state("intro_peche") == "complete" and s.spec == "npc_garin" and s.exit == "" and s.text.contains("Garin"),
		"à rendre : la flèche pointe Garin (%s)" % s.text)
	gs.accept_quest("veille_silencieuse")
	s = QuestGuide.step(gs, "veille_silencieuse", "village_aube")
	_check(s.spec == "mob:loup_dore" and s.zone == "sentier_lisiere", "loups : sur le Sentier (%s)" % s.zone)
	gs.track_quest("intro_peche")
	_check(gs.tracked_quest() == "intro_peche", "on choisit la quête suivie depuis le Carnet")

	# --- 2) PNJ vivants : dialogue qui évolue
	var garin: Node2D = z.find_child("npc_garin", true, false)
	var before: Array = garin.current_dialogues()
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	p.global_position = garin.global_position + Vector2(14, 6)
	z._open(garin)
	z._dialog.close()
	gs.turn_in_quest("intro_peche")
	_check(gs.tracked_quest() == "veille_silencieuse", "quête rendue : le suivi passe à la suivante")
	var after: Array = garin.current_dialogues()
	_check(garin.dialogue_key() == "intro_peche" and after != before and after.size() == 3,
		"Garin a de nouvelles répliques après la truite")
	z._open(garin)
	_check(z._dialog._pages.size() == 3, "nouvelles répliques : elles défilent toutes (%d pages)" % z._dialog._pages.size())
	z._dialog.close()
	z._open(garin)
	_check(z._dialog._pages.size() == 1, "déjà entendues : une seule ensuite")
	z._dialog.close()

	# --- 2b) se tourner, marcher, phrase en passant
	var aldric: Node2D = z.find_child("npc_aldric", true, false)
	_check(aldric._living and aldric.sprite.vframes == 3, "Aldric est vivant (planche 4×3)")
	p.global_position = aldric.global_position + Vector2(-30, 0)
	await _wait(0.3)
	_check(aldric._row == 2 and aldric.sprite.flip_h, "Aldric se tourne vers toi (profil gauche)")
	p.global_position = aldric.global_position + Vector2(0, -30)
	await _wait(0.2)
	_check(aldric._row == 1, "… puis de dos quand tu passes au-dessus")
	p.global_position = aldric.global_position + Vector2(400, 300)
	aldric._idle_t = 0.0
	var home: Vector2 = aldric._home
	var moved := false
	for i in 40:
		await _wait(0.1)
		if aldric.position.distance_to(home) > 1.0:
			moved = true
			break
		if not aldric._walking and aldric._idle_t > 0.5:
			aldric._idle_t = 0.0
	_check(moved, "Aldric fait quelques pas autour de sa place")
	_check(aldric.position.distance_to(home) <= 16.0, "… sans s'éloigner (%.1f px)" % aldric.position.distance_to(home))
	aldric._bark_ready = 0.0
	aldric._was_near = false
	aldric._walking = false
	aldric.get_script().set("_bark_at", -100.0)
	p.global_position = aldric.global_position + Vector2(50, 0)
	await _wait(0.3)
	_check(aldric._bark_box != null and aldric._bark_box.visible and aldric._bark_label.text != "",
		"phrase en passant : « %s »" % (aldric._bark_label.text if aldric._bark_label else ""))

	# --- 3) bestiaire
	_check(not gs.profile.seen.has("loup_dore"), "loup pas encore croisé")
	z = await _go("sentier_lisiere")
	p = z.find_child("Joueur", true, false)
	var wolf: Node2D = null
	for m in get_nodes_in_group("mobs"):
		if m.template_id == "loup_dore":
			wolf = m
			break
	_check(z.find_target("mob:loup_dore") != null, "suivi : la flèche trouve un loup")
	p.global_position = wolf.global_position + Vector2(80, 0)
	await _wait(0.3)
	_check(gs.profile.seen.has("loup_dore"), "loup croisé à distance : noté au bestiaire")
	gs.see_loot("loup_dore", "poil_de_loup_dore")
	var hud2: Node = z.hud
	hud2.toggle_carnet()
	var c: Node = hud2.carnet
	c._tabs.current_tab = 7
	c._beast_sel = "loup_dore"
	c.refresh()
	await _wait(0.2)
	var txt := _texts(c._pages["Bestiaire"][1])
	_check(txt.contains("Loup Doré") and txt.contains("Attaques") and txt.contains("Poil"), "fiche du bestiaire : nom, attaques, butin vu")
	_check(txt.contains("???"), "butin pas encore vu : « ??? »")
	var lt := _texts(c._pages["Bestiaire"][0])
	_check(lt.contains("???"), "créatures jamais croisées : silhouettes « ??? »")
	print("%d échec(s)" % fails)
	quit(1 if fails else 0)


func _texts(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + "\n"
	for ch in n.get_children():
		out += _texts(ch)
	return out
