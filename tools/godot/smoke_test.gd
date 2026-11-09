extends SceneTree
## Test de fumée d'une zone : déplacement, collisions, interactions.
## Usage : godot --headless --path . --script res://tools/godot/smoke_test.gd -- floor_1 village_aube

var _fail := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_fail += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var _gs0 := root.get_node_or_null("GameState")
	if _gs0:
		_gs0.persist = false
		_gs0.reset_profile()
	var args := OS.get_cmdline_user_args()
	var zone: Node = (load("res://scenes/zones/%s/%s.tscn" % [args[0], args[1]]) as PackedScene).instantiate()
	root.add_child(zone)
	await _frames(2)
	var player: CharacterBody2D = zone.find_child("Joueur", true, false)
	_check(player != null, "le joueur existe")
	if args[1] == "sentier_lisiere":
		await _sentier(zone, player)
	elif args[1] == "rive_paisible":
		await _rive(zone, player)
	elif args[1] == "foret_ancienne":
		await _foret(zone, player)
	else:
		await _village(zone, player)
	print("\n%d échec(s)" % _fail)
	quit(_fail)


func _sentier(zone: Node, player: CharacterBody2D) -> void:
	# 1) remonter le sentier depuis l'entrée
	var start := player.global_position
	player.move_to(start + Vector2(0, -60))
	await _frames(90)
	_check(player.global_position.distance_to(start + Vector2(0, -60)) < 6.0,
		"remonte le sentier : %s -> %s" % [start, player.global_position])
	# 2) la forêt dense arrête le joueur
	player.global_position = Vector2(200, 624)
	player.move_to(Vector2(420, 624))
	await _frames(240)
	_check(player.global_position.x < 320, "arrêté par la forêt au bord de la clairière (x=%.0f)" % player.global_position.x)
	# 3) Aurin parle et propose la quête des loups
	var aurin: Node = zone.find_child("aurin_presence", true, false)
	_check(aurin != null and aurin.interact().text != "", "Aurin : « %s »" % (aurin.interact().text as String).left(60))
	_check(aurin.get_node("Marqueur").text == "!", "Aurin affiche « ! » : %s" % aurin.interact().extra)
	# 4) la faune : 11 bêtes (3 lapins, 1 renardeau, 4 loups, 3 oiseaux) qui bougent
	var mobs := zone.find_children("*", "Node2D", true, false).filter(func(n): return n.get("leash") != null)
	_check(mobs.size() == 11, "%d créatures" % mobs.size())
	var before := mobs.map(func(m): return m.position)
	player.global_position = Vector2(200, 640)
	await _frames(300)
	var moved := 0
	for i in mobs.size():
		if mobs[i].position.distance_to(before[i]) > 2.0:
			moved += 1
	_check(moved >= 5, "%d/%d créatures se sont déplacées en 5 s" % [moved, mobs.size()])
	# 5) un lapin fuit quand on s'approche
	var lapin: Node2D = zone.find_child("lapin_spawn_1", true, false)
	player.global_position = lapin.global_position + Vector2(-20, 0)
	var d0 := lapin.global_position.distance_to(player.global_position)
	await _frames(60)
	_check(lapin.global_position.distance_to(player.global_position) > d0 + 8.0, "le lapin fuit (%.0f -> %.0f px)" %
		[d0, lapin.global_position.distance_to(player.global_position)])
	# 6) les ressources s'expliquent
	for id in ["mousse_noeud", "champignons_noeud", "racine_noeud", "bois_mort_de_lisiere_noeud",
			"pierres_taillees_enfouies_noeud", "terriers_de_lapins_noeud"]:
		var r: Node = zone.find_child(id, true, false)
		_check(r != null and r.has_method("harvest") and (r.interact().extra as String) != "",
			"%s : %s" % [id, r.interact().extra if r else "absent"])
	# 7) les sorties
	var exits := zone.find_child("Sorties", true, false).get_children().map(func(e): return e.target_zone)
	_check("village_aube" in exits and "foret_ancienne" in exits, "sorties : %s" % [exits])


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await physics_frame


func _freeze_mobs(zone: Node) -> void:
	for m in zone.find_children("*", "Node2D", true, false).filter(func(n): return n.get("leash") != null):
		m.set_process(false)


func _rive(zone: Node, player: CharacterBody2D) -> void:
	var gs: Node = root.get_node("GameState")
	var T := 16.0
	var mobs := zone.find_children("*", "Node2D", true, false).filter(func(n): return n.get("leash") != null)
	_check(mobs.size() == 10, "%d créatures (6 crabes, 1 héron, 3 anguilles)" % mobs.size())
	# 1) marcher vers le hameau
	var start := player.global_position
	player.move_to(start + Vector2(80, 0))
	await _frames(90)
	_check(player.global_position.distance_to(start + Vector2(80, 0)) < 6.0, "marche vers le hameau")
	# 2) le lac arrête le joueur (on part de la plage de galets vers le large)
	var tmp: Array = mobs.map(func(m): return m.process_mode)
	_freeze_mobs(zone)
	player.global_position = Vector2(46.5, 31.5) * T
	player.move_to(Vector2(46.5, 18) * T)
	await _frames(200)
	_check(player.global_position.y > 23 * T, "arrêté au bord du lac (y=%.1f tuiles)" % (player.global_position.y / T))
	# 3) le grand ponton se parcourt au-dessus de l'eau
	player.global_position = Vector2(80, 46.5) * T
	player.move_to(Vector2(80, 39) * T)
	await _frames(150)
	_check(player.global_position.distance_to(Vector2(80, 39) * T) < 6.0,
		"marche sur le grand ponton (y=%.1f tuiles)" % (player.global_position.y / T))
	# ... mais on n'en tombe pas : l'eau borde les planches
	player.move_to(Vector2(76, 39) * T)
	await _frames(100)
	_check(player.global_position.x > 78.4 * T, "pas d'eau praticable à côté du ponton (x=%.1f)" % (player.global_position.x / T))
	# 4) hauts-fonds : on y marche, ralenti
	player.global_position = Vector2(68, 56) * T
	await _frames(3)
	var slow: float = player.speed_mult
	player.global_position = Vector2(40, 45) * T
	await _frames(3)
	_check(slow < 0.7 and player.speed_mult == 1.0, "hauts-fonds praticables et ralentis (x%.2f, pré x%.2f)" % [slow, player.speed_mult])
	# 5) pêche : trois postes de récolte classique
	for id in ["peche_eaux_basses", "peche_hameau", "peche_ilot"]:
		var r: Node = zone.find_child(id, true, false)
		_check(r != null and r.has_method("harvest") and (r.interact().extra as String) != "",
			"%s : %s / %s" % [id, r.interact().extra if r else "absent", r.info if r else ""])
	# 6) quête de Bertold : récolter des roseaux dorés fait avancer l'objectif
	gs.accept_quest("filets_a_ravauder")
	for i in 4:
		gs.on_gather("roseaux_dores", "herboristerie", 1)
	_check(gs.quest_state("filets_a_ravauder") == "complete", "Bertold : %s" % gs.quest_progress_text("filets_a_ravauder"))
	# 7) traversée en barque vers l'îlot
	var barque: Node = zone.find_child("traversee_maelis", true, false)
	var act: Dictionary = barque.interact().action
	_check(act.get("kind") == "ferry", "barque de Maëlis : action « %s »" % act.get("label", "?"))
	zone._open(barque)
	zone.do_dialog_action()
	await _wait(1.4)
	var on_islet: bool = player.global_position.distance_to(Vector2(63.5, 19) * T) < 4.0
	_check(on_islet, "traversée : sur l'îlot (%.1f, %.1f)" % [player.global_position.x / T, player.global_position.y / T])
	# 8) découverte : le cercle immergé ajoute une note au Carnet et un peu d'XP
	var cercle: Node = zone.find_child("cercle_immerge", true, false)
	var xp0: float = gs.profile.xp + gs.profile.level * 1000.0
	zone._open(cercle)
	zone.do_dialog_action()
	_check(gs.profile.notes.has("cercle_immerge") and gs.profile.xp + gs.profile.level * 1000.0 > xp0,
		"découverte notée : %s" % [gs.profile.notes.keys()])
	_check(cercle.interact().action.is_empty(), "une seule fois : %s" % cercle.interact().extra)
	# 9) retour à la jetée
	var retour: Node = zone.find_child("retour_ilot", true, false)
	zone._open(retour)
	zone.do_dialog_action()
	await _wait(1.4)
	_check(player.global_position.distance_to(Vector2(52.5, 31) * T) < 4.0, "retour à la jetée")
	# 10) le héron reste à son poste, l'anguille plonge (intouchable) puis ressurgit
	for m in mobs:
		m.set_process(true)
	var heron: Node2D = zone.find_child("heron_spawn", true, false)
	var h0 := heron.position
	player.global_position = Vector2(40, 45) * T
	await _wait(2.0)
	_check(heron.position.distance_to(h0) < 1.0, "le héron ne bouge pas tant qu'on est loin")
	var eel: Node2D = zone.find_child("anguille_spawn_1", true, false)
	for m in mobs:
		if m != eel:
			m.set_process(false)
	gs.fighter.hp = 9999.0
	player.global_position = eel.global_position + Vector2(-30, 0)
	var dived := false
	var t_end := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < t_end and not dived:
		await physics_frame
		if eel.submerged:
			dived = true
			_check(not (eel.global_position in player._mob_positions()), "sous l'eau : l'anguille n'est pas ciblable")
	_check(dived, "l'anguille plonge à l'approche")
	await _wait(1.3)
	_check(not eel.submerged and eel.sprite.modulate.a > 0.9, "elle ressurgit (état %s)" % eel.state)
	# 11) les sorties
	var exits := zone.find_child("Sorties", true, false).get_children().map(func(e): return e.target_zone)
	_check("village_aube" in exits and "camp_pecheurs" in exits and "lac_miroir" in exits, "sorties : %s" % [exits])


func _foret(zone: Node, player: CharacterBody2D) -> void:
	var gs: Node = root.get_node("GameState")
	var snd: Node = root.get_node_or_null("Sound")
	var T := 16.0
	var mobs := zone.find_children("*", "Node2D", true, false).filter(func(n): return n.get("leash") != null)
	_check(mobs.size() == 11, "%d bêtes (6 sangliers, 2 lynx, 2 ours, le Veilleur)" % mobs.size())
	if snd:
		await _frames(5)
		_check(snd.current_mood() == "tension" and snd._amb_key.ends_with("foret_profonde.wav"),
			"musique « tension », ambiance forêt profonde")
	# un sous-bois clair se traverse (on coupe entre les arbres)
	player.global_position = Vector2(8, 22) * T
	player.move_to(Vector2(28, 22) * T)
	await _frames(300)
	_check(player.global_position.x > 22 * T, "sous-bois clair praticable (x=%.1f tuiles)" % (player.global_position.x / T))
	# le Veilleur n'est pas là tant que 40 sangliers ne sont pas tombés
	var veil: Node2D = zone.find_child("veilleur_spawn", true, false)
	_check(not veil.visible and not veil.is_in_group("mobs"), "Veilleur d'écorce absent (0/40 sangliers)")
	gs.profile.kills["sanglier_des_fougeres"] = 40
	await _wait(2.4)
	_check(veil.visible and veil.is_in_group("mobs") and veil.dormant, "40 sangliers : il apparaît, endormi parmi les chênes morts")
	player.global_position = veil.global_position + Vector2(-90, 10)
	await _frames(20)
	_check(veil.dormant and not veil.provoked, "de loin : un chêne mort comme les autres")
	player.global_position = veil.global_position + Vector2(-30, 6)
	await _frames(10)
	_check(not veil.dormant and veil.provoked, "de près : il se réveille")
	# lynx : presque invisible dans la lumière, se révèle de près
	for m in mobs:
		m.set_process(m.temper == "ambusher")
	var lynx: Node2D = zone.find_child("lynx_spawn_1", true, false)
	player.global_position = lynx.global_position + Vector2(-140, 0)
	await _wait(1.6)
	_check(lynx.sprite.modulate.a < 0.4, "lynx caché dans les rais (opacité %.2f)" % lynx.sprite.modulate.a)
	gs.fighter.hp = 9999.0
	player.global_position = lynx.global_position + Vector2(-28, 0)
	await _wait(0.6)
	_check(lynx.sprite.modulate.a > 0.8 and lynx.provoked, "il se révèle et bondit")
	# sanglier : la charge le projette le long de la ligne annoncée
	for m in mobs:
		m.set_process(false)
	var boar: Node2D = zone.find_child("sanglier_spawn_1", true, false)
	boar.set_process(true)
	player.global_position = boar.global_position + Vector2(60, 0)
	var charge: Dictionary = (boar.tpl.moveset as Array).filter(func(mv): return mv.get("charge", false))[0]
	var p0 := boar.global_position
	boar._start_move(charge, Vector2.RIGHT)
	await _wait(1.3)
	_check(boar.global_position.x - p0.x > 30.0, "charge du sanglier : %d px en avant" % (boar.global_position.x - p0.x))
	# ours : lent
	var bear: Node2D = zone.find_child("ours_spawn_1", true, false)
	_check(bear.temper == "guardian" and bear._speed_k() < 1.0, "ours gardien, lent (×%.1f)" % bear._speed_k())
	# PNJ et quêtes
	var isarn: Node = zone.find_child("isarn_presence", true, false)
	var vesna: Node = zone.find_child("vesna_presence", true, false)
	_check(isarn.get_node("Marqueur").text == "!" and vesna.get_node("Marqueur").text == "!", "Isarn et Vesna proposent leurs quêtes")
	# ressources et découverte
	for id in ["chene_noeud", "fougere_noeud", "traces_noeud", "affleurement_rocheux_noeud", "pierres_moussues_gravees_noeud",
			"ecorce_noeud", "chene_2", "fougere_2", "traces_2", "pierres_2"]:
		var r: Node = zone.find_child(id, true, false)
		_check(r != null and r.has_method("harvest"), "%s : %s" % [id, r.interact().extra if r else "absent"])
	var dsc: Node = zone.find_child("lignes_sous_la_mousse", true, false)
	_check(dsc != null and dsc.interact().action.get("kind") == "discovery", "découverte : Les lignes sous la mousse")
	# sorties (dont la sortie cachée vers la Clairière des Veilleurs Oubliés)
	var exits := zone.find_child("Sorties", true, false).get_children()
	var targets := exits.map(func(e): return e.target_zone)
	var secret: Array = exits.filter(func(e): return e.secret).map(func(e): return e.target_zone)
	_check("sentier_lisiere" in targets and "lac_miroir" in targets and "sous_bois_perdu" in targets and secret == ["veilleurs_oublies"],
		"sorties : %s (cachée : %s)" % [targets, secret])


func _village(zone: Node, player: CharacterBody2D) -> void:
	# 1) se déplacer sur la route vers l'est (libre)
	var start := player.global_position
	player.move_to(start + Vector2(120, 0))
	await _frames(120)
	_check(player.global_position.distance_to(start + Vector2(120, 0)) < 6.0,
		"marche sur la route : %s -> %s" % [start, player.global_position])

	# 2) foncer dans l'auberge : la collision doit arrêter le joueur avant son mur
	var inn: Node2D = zone.find_child("auberge_1", true, false)
	player.global_position = inn.global_position + Vector2(0, 40)
	player.move_to(inn.global_position + Vector2(0, -200))
	await _frames(180)
	_check(player.global_position.y > inn.global_position.y - 1,
		"bloqué par l'auberge (y=%.0f, pied auberge=%.0f)" % [player.global_position.y, inn.global_position.y])

	# 3) le ruisseau bloque, le pont laisse passer
	player.global_position = Vector2(400, 700)
	player.move_to(Vector2(400, 800))
	await _frames(180)
	_check(player.global_position.y < 735, "bloqué par le ruisseau (y=%.0f)" % player.global_position.y)
	player.global_position = Vector2(960, 690)
	player.move_to(Vector2(960, 790))
	await _frames(180)
	_check(player.global_position.y > 770, "traverse le pont (y=%.0f)" % player.global_position.y)

	# 4) les PNJ répondent avec les répliques de leurs JSON
	for id in ["npc_yvenne", "npc_aldric", "npc_garin", "shop_echoppe", "market_autel", "ws_forge"]:
		var it: Node = zone.find_child(id, true, false)
		if it == null:
			_check(false, "%s présent" % id)
			continue
		var d: Dictionary = it.interact()
		_check(d.text != "", "%s : « %s »" % [d.name, (d.text as String).left(60)])
	var garin: Node = zone.find_child("npc_garin", true, false)
	_check(garin.interact().extra.begins_with("Quête"), "Garin propose sa quête : %s" % garin.interact().extra)
	var yvenne: Node = zone.find_child("npc_yvenne", true, false)
	_check(yvenne.get_node("Marqueur").text == "!" and yvenne.get_node("Marqueur").modulate.a < 0.5, "Yvenne : quêtes verrouillées affichées en « ! » pâle avec indice")
