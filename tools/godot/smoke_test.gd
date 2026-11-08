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

	print("\n%d échec(s)" % _fail)
	quit(_fail)
