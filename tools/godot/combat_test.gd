extends SceneTree
## Test du combat V1 (docs/combat_v1.md) dans le Sentier de la Lisière :
## coups et compétences, mort d'une bête (XP, butin, compteur), agressivité des loups, esquive d'une
## attaque annoncée en sortant de la zone, déblocages, quête d'Aurin complète, défaite et pénalités.
## Usage : godot --headless --path . --script res://tools/godot/combat_test.gd

var _fail := 0
var gs: Node


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func(): print("ECHEC délai dépassé"); quit(2))
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_fail += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _z() -> Node:
	return current_scene


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	change_scene_to_file(gs.zone_path("sentier_lisiere"))
	for i in 10:
		await process_frame
	if _z() == null:
		_check(false, "la scène du sentier se charge")
		quit(1)
		return
	var z := _z()
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	_check(gs.profile.bar.slice(0, 2) == ["frappe", "trait_de_lumiere"],
		"départ mains nues, barre : %s" % [gs.profile.bar])
	_check(absf(gs.fighter.max_hp() - 80.0) < 0.01 and gs.fighter.attack_cooldown() > 1.4,
		"stats de base : %d PV, attaque toutes les %.2f s" % [gs.fighter.max_hp(), gs.fighter.attack_cooldown()])

	# build « aventurier » de la référence d'équilibrage pour les 6 points du niveau 1
	for k in ["hp", "atk", "atk", "def", "def", "int"]:
		gs.spend_point(k)
	# 1) tuer un lapin : coups + compétences, en restant collé à lui
	var lapin: Node2D = z.find_child("lapin_spawn_1", true, false)
	var xp0: int = gs.profile.xp
	var t0 := Time.get_ticks_msec()
	var casts := 0
	for i in 60 * 240:
		if not is_instance_valid(lapin) or not lapin.is_alive():
			break
		lapin._home = lapin.position                              # le test suit la bête : son territoire aussi
		p.global_position = lapin.global_position + Vector2(-12, 0)
		p.attack(Vector2.RIGHT)
		for s in 2:
			if p.cast(s, Vector2.RIGHT) == "":
				casts += 1
		await physics_frame
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	_check(not lapin.is_alive(), "lapin vaincu en %.0f s (%d compétences lancées), PV joueur %d/%d" %
		[secs, casts, gs.fighter.hp, gs.fighter.max_hp()])
	_check(gs.profile.xp > xp0 or gs.profile.level > 1, "XP gagnée : %.2f -> %.2f (niv. %d)" % [xp0, gs.profile.xp, gs.profile.level])
	_check(int(gs.profile.kills.get("lapin_bondissant", 0)) == 1, "compteur de lapins : 1")
	var drops := 0
	for i in 400:
		drops += 1 if not lapin._roll_loot().is_empty() else 0
	_check(drops == 400, "butin garanti : %d %% des bêtes lâchent un objet" % roundi(drops / 4.0))
	await _frames(90)                                         # le butin du lapin (garanti) est ramassé d'abord
	var n0: int = gs.item_count("patte_de_lapin")
	z.drop_loot(p.global_position + Vector2(20, -6), [["patte_de_lapin", 1]])
	await _frames(90)
	_check(gs.item_count("patte_de_lapin") == n0 + 1, "butin ramassé automatiquement : %s" % [gs.profile.inventory])

	# 2) un loup attaque quand on entre dans son rayon
	gs.fighter.hp = gs.fighter.max_hp()
	var loup: Node2D = z.find_child("loup_dore_spawn_1", true, false)
	p.global_position = loup.global_position + Vector2(40, 0)
	var hp0: float = gs.fighter.hp
	await _frames(240)
	_check(loup.provoked and gs.fighter.hp < hp0, "le loup attaque de lui-même (PV %d -> %d)" % [hp0, gs.fighter.hp])
	var loup2: Node2D = z.find_child("loup_dore_spawn_2_1", true, false)
	loup2._disengage()
	loup2.state = "wander"
	loup2.position = loup2._home
	p.global_position = loup2.global_position + Vector2(50, 0)
	for i in 30:
		await physics_frame
		if loup2.provoked:
			break
	var hp_al: float = gs.fighter.hp
	_check(loup2.provoked and loup2.state == "alert" and loup2._alert.visible,
		"le loup prévient : « ! » rouge et arrêt avant la charge (état %s)" % loup2.state)
	await _frames(int(loup2.ALERT_PAUSE * 60) + 6)
	_check(loup2.state != "alert", "puis il charge (état %s)" % loup2.state)

	# 3) griffure annoncée : on sort de la zone -> évitée ; on reste -> touché
	var griffe: Dictionary = loup.tpl.moveset.filter(func(m): return m.id == "griffure_luisante")[0]
	_check(float(griffe.telegraph_seconds) > 0.0, "la griffure luisante s'annonce (%.1f s)" % griffe.telegraph_seconds)
	await _dodge_case(loup, p, griffe, true)
	await _dodge_case(loup, p, griffe, false)

	# 4) quête d'Aurin : accepter, tuer 4 loups, rendre
	var aurin: Node = z.find_child("aurin_presence", true, false)
	var d: Dictionary = aurin.interact()
	_check(d.action.get("kind") == "accept", "Aurin propose : %s" % d.extra)
	z._open(aurin)
	z.do_dialog_action()
	_check(gs.quest_state("veille_silencieuse") == "active" and aurin.get_node("Marqueur").text == "…",
		"quête acceptée, marqueur « … »")
	for i in 4:
		gs.on_kill("loup_dore", 1, "normal")
	_check(gs.quest_state("veille_silencieuse") == "complete" and aurin.get_node("Marqueur").text == "?",
		"4 loups : quête à rendre, marqueur « ? » (%s)" % [gs.quest_progress_text("veille_silencieuse")])
	_check(not ("croc_dore" in gs.profile.skills), "Croc Doré pas encore débloqué à 4 loups (il en faut 12)")
	for i in 8:
		gs.on_kill("loup_dore", 1, "normal")
	_check("croc_dore" in gs.profile.skills, "12 loups : Croc Doré débloqué (barre pleine : %s)" % [gs.profile.bar])
	gs.equip_skill("croc_dore", 3)
	_check(gs.profile.bar[3] == "croc_dore", "Croc Doré placé dans l'emplacement 4 depuis le Carnet")
	var gold0: int = gs.profile.gold
	z._open(aurin)
	z.do_dialog_action()
	_check(gs.quest_state("veille_silencieuse") == "turned_in" and gs.profile.gold == gold0 + 5,
		"quête rendue : +5 or (%d)" % gs.profile.gold)

	# 5) niveau : 6 points, Premiers Soins
	var lvl0: int = gs.profile.level
	gs.gain_xp(CombatRules.xp_to_next(gs.profile.level))
	_check(gs.profile.level == lvl0 + 1 and gs.profile.unspent >= 6, "niveau %d, %d points" % [gs.profile.level, gs.profile.unspent])
	_check("premiers_soins" in gs.profile.skills, "Premiers Soins débloqués au niveau 2")
	var atk0: float = gs.fighter.stat("atk")
	gs.spend_point("atk")
	_check(absf(gs.fighter.stat("atk") - atk0 - 2.0) < 0.01, "1 point en ATK : %d -> %d" % [atk0, gs.fighter.stat("atk")])

	# 5 bis) fiche du Carnet : préparer, annuler, valider
	var carnet: Control = _z().hud.carnet
	_z().hud.toggle_carnet()
	var pts0: int = gs.profile.unspent
	var hp_base: float = gs.fighter.stat("hp")
	carnet._change("hp", 1)
	carnet._change("hp", 1)
	_check(gs.profile.unspent == pts0 and absf(gs.fighter.stat("hp") - hp_base) < 0.01, "fiche : 2 points préparés, rien n'est encore dépensé")
	carnet._cancel()
	carnet._change("hp", 1)
	carnet._commit()
	_check(gs.profile.unspent == pts0 - 1 and absf(gs.fighter.stat("hp") - hp_base - 25.0) < 0.01,
		"fiche : annulation puis 1 point validé en PV (+25)")
	# plusieurs stats d'un coup (bug : seul le premier point passait)
	gs.profile.unspent = maxi(int(gs.profile.unspent), 4)
	var pts1: int = gs.profile.unspent
	var a0: int = gs.profile.alloc.atk
	var d0: int = gs.profile.alloc.def
	var ag0: int = gs.profile.alloc.agi
	carnet._change("atk", 1)
	carnet._change("atk", 1)
	carnet._change("def", 1)
	carnet._change("agi", 1)
	carnet._commit()
	_check(gs.profile.unspent == pts1 - 4 and gs.profile.alloc.atk == a0 + 2 and gs.profile.alloc.def == d0 + 1
		and gs.profile.alloc.agi == ag0 + 1, "fiche : 2 ATK + 1 DEF + 1 AGI validés ensemble (%d points restants)" % gs.profile.unspent)
	_z().hud.toggle_carnet()

	# 5 ter) commerce et équipement
	gs.profile.gold = 100
	_check(gs.buy("echoppe_thessaly", "dague_villageoise") == "" and gs.profile.gold == 65 and gs.item_count("dague_villageoise") == 1,
		"achat chez Thessaly : Dague Villageoise pour 35 or (reste %d)" % gs.profile.gold)
	var atk_bare: float = gs.fighter.stat("atk")
	_check(gs.equip_item("dague_villageoise") == "" and gs.item_count("dague_villageoise") == 0
		and absf(gs.fighter.stat("atk") - atk_bare - 1.4) < 0.01 and int(gs.weapon_area().range) == 26,
		"dague équipée : ATK %.1f -> %.1f, portée 26 px" % [atk_bare, gs.fighter.stat("atk")])
	gs.add_item("hachette_d_isarn", 1)
	_check(gs.can_equip("hachette_d_isarn") == "niveau 4 requis" or gs.profile.level >= 4,
		"Hachette d'Isarn refusée : %s" % gs.can_equip("hachette_d_isarn"))
	gs.unequip("weapon")
	_check(gs.item_count("dague_villageoise") == 1 and absf(gs.fighter.stat("atk") - atk_bare) < 0.01, "dague retirée : retour au sac")
	gs.equip_item("dague_villageoise")
	var g0: int = gs.profile.gold
	gs.add_item("poil_de_loup_dore", 2)
	var gain: int = gs.sell("poil_de_loup_dore", 2)
	_check(gain == 2 * gs.sell_price("poil_de_loup_dore") and gs.profile.gold == g0 + gain,
		"revente : 2 Poils de Loup Doré pour %d or (35 %% de %d, arrondi)" % [gain, int(gs.tpl("items", "poil_de_loup_dore").base_value)])
	gs.buy("echoppe_thessaly", "pain_de_miel")
	gs.fighter.hp = 10.0
	_check(gs.use_item("pain_de_miel") == "" and absf(gs.fighter.hp - 51.0) < 0.5 and gs.item_count("pain_de_miel") == 0,
		"Pain de Miel : +41 PV (%d)" % gs.fighter.hp)
	gs.add_item("pain_de_miel", 1)
	_check(gs.use_item("pain_de_miel").begins_with("attends"), "recharge des consommables : %s" % gs.use_item("pain_de_miel"))
	# raccourci de soin du HUD : prend le meilleur soin du sac
	gs.fighter.cooldowns.erase("item")
	gs.add_item("ragout_chaud", 1)
	gs.fighter.hp = 10.0
	var best: String = gs.best_heal()
	var n_best: int = gs.item_count(best)
	_z().hud.use_potion()
	_check(gs.item_count(best) == n_best - 1 and gs.fighter.hp > 10.0,
		"raccourci de soin : %s utilisé (PV 10 -> %d)" % [gs.item_name(best), gs.fighter.hp])

	# 5 quater) récolte : barre, objet, XP de métier, stock, prérequis
	var mousse: Node2D = _z().find_child("mousse_noeud", true, false)
	var calm := get_nodes_in_group("mobs")
	for m in calm:                                          # les loups voisins restent tranquilles pendant ce test
		m.set_process(false)
	p.global_position = mousse.global_position + Vector2(-14, 4)
	await _frames(5)
	var n_mousse: int = gs.item_count("mousse_lumineuse_aube")
	_z()._open(mousse)
	_check(_z().is_gathering(), "récolte de la Mousse Lumineuse lancée (%.0f s)" % mousse.gather_time())
	await _frames(int(mousse.gather_time() * 60) + 10)
	_check(gs.item_count("mousse_lumineuse_aube") > n_mousse and gs.prof_xp("herboristerie") > 0.0
		and mousse.stock == mousse.max_stock - 1 and int(gs.profile.gathers.get("mousse_lumineuse", 0)) == 1,
		"mousse récoltée : %d dans le sac, herboristerie %.0f XP, stock %d/%d" % [gs.item_count("mousse_lumineuse_aube"),
		gs.prof_xp("herboristerie"), mousse.stock, mousse.max_stock])
	_z()._open(mousse)
	p.move_to(p.global_position + Vector2(-60, 0))
	await _frames(10)
	_check(not _z().is_gathering(), "se déplacer interrompt la récolte")
	for m in calm:
		m.set_process(true)
	var racine: Node2D = _z().find_child("racine_noeud", true, false)
	_check(racine.can_gather() == "Herboristerie niv. 2 requis", "Racine Dorée : %s" % racine.can_gather())
	for i in 50:
		gs.on_gather("mousse_lumineuse", "herboristerie", 1)
	_check(gs.prof_level("herboristerie") == 2 and racine.can_gather() == "", "50 récoltes : herboristerie niv. 2, la racine s'ouvre")

	# 5 quinquies) titres : secret tant que la condition n'est pas remplie, puis +6 % ATK une fois porté
	_check(not "fleau_des_loups_dores" in gs.profile.titles, "Fléau des Loups Dorés encore secret")
	var got_title := []
	gs.title_unlocked.connect(func(t): got_title.append(t))
	gs.profile.kills["loup_dore"] = 99
	while gs.profile.level < 3:
		gs.gain_xp(CombatRules.xp_to_next(gs.profile.level))
	gs.on_kill("loup_dore", 1, "normal")
	_check("fleau_des_loups_dores" in gs.profile.titles and got_title == ["fleau_des_loups_dores"],
		"100 loups au niveau 3 : titre « Fléau des Loups Dorés » débloqué et annoncé")
	var atk_t: float = gs.fighter.stat("atk")
	gs.equip_title("fleau_des_loups_dores")
	_check(absf(gs.fighter.stat("atk") - atk_t * 1.06) < 0.05, "titre porté : ATK %.1f -> %.1f (+6 %%)" % [atk_t, gs.fighter.stat("atk")])
	gs.equip_title("")
	_check(absf(gs.fighter.stat("atk") - atk_t) < 0.05, "titre retiré : ATK revient à %.1f" % gs.fighter.stat("atk"))

	# 6) défaite : retour au village, Ébranlé, perte d'or, 20 % des PV
	gs.profile.gold = 200
	gs.fighter.effects.clear()
	gs.fighter.hp = 1.0
	p.global_position = loup.global_position + Vector2(14, 0)
	# on ne lit pas la scène courante pendant le changement de zone (pointeur possiblement libéré) :
	# on attend que GameState ait fini le voyage
	for i in 900:
		if gs.current_zone == "village_aube" and not gs.is_travelling():
			break
		await physics_frame
	await _frames(30)
	_check(_z() != null and _z().zone_id == "village_aube", "défaite : retour à Val-de-l'Aube")
	var shaken: Array = gs.fighter.effects.filter(func(e): return e.source == "ebranle")
	_check(shaken.size() == 6, "Ébranlé : -20 %% sur les 6 stats (%d effets)" % shaken.size())
	_check(gs.profile.gold == 194, "or : 200 -> %d (3 %%)" % gs.profile.gold)
	var hp_ratio: float = gs.fighter.hp / gs.fighter.max_hp()
	_check(hp_ratio > 0.15 and hp_ratio < 0.3, "relevé à %d %% des PV" % roundi(hp_ratio * 100))

	print("\n%d échec(s)" % _fail)
	quit(_fail)


func _dodge_case(loup: Node2D, p: CharacterBody2D, move: Dictionary, step_out: bool) -> void:
	await _frames(40)
	var others := get_nodes_in_group("mobs").filter(func(m): return m != loup)
	for m in others:                                       # seul ce loup agit pendant le test
		m.set_process(false)
	gs.fighter.hp = gs.fighter.max_hp()
	loup.state = "chase"
	loup.position = loup._home
	p.global_position = loup.global_position + Vector2(18, 0)
	var hp0: float = gs.fighter.hp
	gs.fighter.rng.seed = 7                                   # pas d'esquive aléatoire sur ce coup
	loup._start_move(move, Vector2.RIGHT)
	var tele_ok: bool = loup.state == "windup"
	if step_out:
		p.global_position = loup.global_position + Vector2(70, 0)
	await _frames(int(float(move.telegraph_seconds) * 60) + 4)
	if step_out:
		_check(tele_ok and gs.fighter.hp >= hp0, "sorti de la zone : griffure évitée (PV %d -> %d)" % [hp0, gs.fighter.hp])
	else:
		_check(tele_ok and gs.fighter.hp < hp0, "resté dans la zone : griffure encaissée (PV %d -> %d)" % [hp0, gs.fighter.hp])
	for m in others:
		m.set_process(true)
