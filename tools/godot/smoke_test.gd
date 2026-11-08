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
	var args := OS.get_cmdline_user_args()
	var zone: Node = (load("res://scenes/zones/%s/%s.tscn" % [args[0], args[1]]) as PackedScene).instantiate()
	root.add_child(zone)
	await _frames(2)
	var player: CharacterBody2D = zone.find_child("Joueur", true, false)
	_check(player != null, "le joueur existe")
	if args[1] == "sentier_lisiere":
		await _sentier(zone, player)
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
		_check(r != null and (r.interact().extra as String).begins_with("Récolte"),
			"%s : %s" % [id, r.interact().extra if r else "absent"])
	# 7) les sorties
	var exits := zone.find_child("Sorties", true, false).get_children().map(func(e): return e.target_zone)
	_check("village_aube" in exits and "foret_ancienne" in exits, "sorties : %s" % [exits])


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
	_check(yvenne.get_node("Marqueur").text == "?", "Yvenne : quêtes verrouillées affichées en « ? » avec indice")
