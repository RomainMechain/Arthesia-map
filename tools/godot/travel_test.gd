extends SceneTree
## Test des transitions : village -> sentier -> village, en marchant dans les sorties.
## Usage : godot --headless --path . --script res://tools/godot/travel_test.gd

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


func _zone() -> Node:
	return current_scene


func _walk_into_exit(exit_name: String) -> void:
	var z := _zone()
	var ex: Area2D = z.find_child(exit_name, true, false)
	var shape: CollisionShape2D = ex.get_child(0)
	var player: CharacterBody2D = z.find_child("Joueur", true, false)
	var target := ex.global_position + shape.position
	player.global_position = target + (ex.arrival - target).normalized() * 24.0
	player.move_to(target)


func _run() -> void:
	var gs := root.get_node_or_null("GameState")
	_check(gs != null, "autoload GameState chargé")
	if gs == null:
		gs = (load("res://game/game_state.gd") as GDScript).new()
		gs.name = "GameState"
		root.add_child(gs)
	change_scene_to_file(gs.zone_path("village_aube"))
	await _frames(5)
	_check(_zone().zone_id == "village_aube", "départ au village")

	_walk_into_exit("exit_sentier_lisiere")
	await _frames(150)
	var z := _zone()
	_check(z.zone_id == "sentier_lisiere", "arrivé dans : %s" % z.zone_id)
	var p: Node2D = z.find_child("Joueur", true, false)
	var arr: Vector2 = z.find_child("exit_village_aube", true, false).arrival
	_check(p.global_position.distance_to(arr) < 4.0, "apparaît à l'entrée sud du sentier %s (attendu %s)" % [p.global_position, arr])

	await _frames(30)
	_walk_into_exit("exit_village_aube")
	await _frames(150)
	z = _zone()
	_check(z.zone_id == "village_aube", "retour dans : %s" % z.zone_id)
	p = z.find_child("Joueur", true, false)
	arr = z.find_child("exit_sentier_lisiere", true, false).arrival
	_check(p.global_position.distance_to(arr) < 4.0, "réapparaît à la sortie nord du village %s (attendu %s)" % [p.global_position, arr])

	_walk_into_exit("exit_rive_paisible")
	await _frames(60)
	_check(_zone().zone_id == "village_aube" and not gs.is_travelling(), "Rive Paisible pas encore construite : on reste au village")

	print("\n%d échec(s)" % _fail)
	quit(_fail)
