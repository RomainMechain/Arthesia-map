extends SceneTree
## Captures des sensations de combat et des titres : art/preview/godot_feel_*.png (fenêtre visible).

var gs: Node


func _initialize() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_feel_%s.png" % name))
	print("capture ", name)


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	for k in ["atk", "atk", "atk", "atk", "def", "hp"]:
		gs.spend_point(k)
	gs.add_item("dague_villageoise", 1)
	gs.equip_item("dague_villageoise")
	change_scene_to_file(gs.zone_path("sentier_lisiere"))
	for i in 30:
		await process_frame
	var z := current_scene
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	var loup: Node2D = z.find_child("loup_dore_spawn_1", true, false)
	p.global_position = loup.global_position + Vector2(-26, 2)
	p.get_node("Camera2D").reset_smoothing()
	await _wait(1.0)
	# impact critique (forcé) + portée de l'arme au sol
	var r := {"damage": 12.0, "final_damage": 12.0, "critical": true, "dodged": false, "absorbed": 0.0}
	z.report_hit(loup, r, p)
	await _wait(0.05)
	await _shot("critique")
	# mort : figé blanc puis grains dorés
	loup.fighter.hp = 1.0
	await _wait(0.4)
	loup.fighter.hp = 0.0
	loup.react({"damage": 1.0, "final_damage": 1.0, "critical": false, "dodged": false}, p.global_position)
	await _wait(0.28)
	await _shot("mort")
	# PV bas : liseré rouge
	gs.fighter.hp = gs.fighter.max_hp() * 0.12
	await _wait(0.3)
	await _shot("pv_bas")
	# titre débloqué, porté, et onglet Titres
	gs.fighter.hp = gs.fighter.max_hp()
	gs.profile.kills["loup_dore"] = 100
	while gs.profile.level < 3:
		gs.gain_xp(CombatRules.xp_to_next(gs.profile.level))
	gs.check_titles()
	gs.equip_title("fleau_des_loups_dores")
	await _wait(0.5)
	await _shot("titre_debloque")
	z.hud.toggle_carnet()
	var c: Control = z.hud.carnet
	c._tabs.current_tab = 1
	c._slot = "title"
	c.refresh()
	await _wait(0.3)
	await _shot("titres")
	quit()
