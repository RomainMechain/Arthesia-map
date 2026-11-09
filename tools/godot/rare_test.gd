extends SceneTree
## Test des apparitions rares (créatures marquées par l'aube).

var _fail := 0


func _initialize() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func(): print("TIMEOUT"); quit(2))
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_fail += 1


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await process_frame


func _kill(m: Node2D, p: Node2D) -> void:
	m.fighter.hp = 0.0
	m.react({"damage": 1.0, "final_damage": 1.0, "critical": false, "dodged": false}, p.global_position)


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	change_scene_to_file(gs.zone_path("sentier_lisiere"))
	await _wait(1.0)
	var z := current_scene
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	var rs: Node = z.rare_spawner
	_check(rs != null, "le Sentier (zone de combat) a des apparitions rares")
	_check(gs.profile.rare_next.has("sentier_lisiere") and float(gs.profile.rare_next.sentier_lisiere) >= 900.0,
		"prochaine apparition dans %d min" % int(float(gs.profile.rare_next.get("sentier_lisiere", 0)) / 60.0))
	# apparition forcée
	_check(rs.spawn(), "une créature marquée se lève")
	var m: Node2D = rs.current
	var src: Node2D = z.find_child(String(m.name).trim_prefix("marque_"), true, false)
	_check(m.marked and m.fighter.max_hp() > src.fighter.max_hp() * 2.0 and m.fighter.level == src.fighter.level + 1,
		"%s : PV %d (au lieu de %d), niv. %d" % [m.fighter.display_name, m.fighter.max_hp(), src.fighter.max_hp(), m.fighter.level])
	_check(m.temper != "calm" and m.fighter.role == "elite", "elle chasse (tempérament %s), rang élite" % m.temper)
	_check(m.global_position.distance_to(p.global_position) > 200.0, "loin du joueur (%d px)" % m.global_position.distance_to(p.global_position))
	_check(not rs.spawn(), "une seule à la fois")
	# victoire : éclat d'aube figée, compteur
	p.global_position = m.global_position + Vector2(-20, 0)
	await _wait(0.3)
	_kill(m, p)
	await _wait(2.5)
	_check(gs.item_count("eclat_d_aube_fige") >= 1, "butin : Éclat d'Aube Figée (×%d)" % gs.item_count("eclat_d_aube_fige"))
	_check(int(gs.profile.kills.get("marque", 0)) == 1, "compteur des créatures marquées : 1")
	_check(gs.item_rank("eclat_d_aube_fige") == "epique", "ingrédient épique : rang rare garanti au craft")
	await _wait(1.2)
	_check(not is_instance_valid(m), "elle ne revient pas")
	# titre au bout de 3
	gs.profile.kills["marque"] = 2
	_check(rs.spawn(), "deuxième apparition")
	var m2: Node2D = rs.current
	p.global_position = m2.global_position + Vector2(-20, 0)
	_kill(m2, p)
	await _wait(0.5)
	_check("traqueur_d_aube" in gs.profile.titles, "titre « Traqueur d'Aube » débloqué")
	# disparition si personne ne la trouve
	await _wait(1.5)
	p.global_position = Vector2(200, 640)
	_check(rs.spawn(), "troisième apparition")
	var m3: Node2D = rs.current
	_check(z.hud.minimap.visible, "repère sur la mini-carte (créature marquée)")
	rs._life = rs.LIFETIME - 0.1
	await _wait(1.6)
	_check(not is_instance_valid(m3) or m3.modulate.a < 0.5, "au bout de 5 min sans être trouvée, elle s'évanouit")
	# zones sans combat : pas d'apparition
	change_scene_to_file(gs.zone_path("village_aube"))
	await _wait(0.8)
	_check(current_scene.rare_spawner == null, "pas d'apparition au village")
	print("\n%d échec(s)" % _fail)
	quit(_fail)
