extends SceneTree
## Captures des fenêtres de récompense, de l'atelier et du HUD : art/preview/godot_reward_*.png (fenêtre visible).

var gs: Node


func _initialize() -> void:
	create_timer(80.0, true, false, true).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_reward_%s.png" % name))
	print("capture ", name)


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	gs.settings.craft_ai = false
	gs.craft_cache = {"items": {}, "recipes": {}}
	gs.accept_quest("intro_peche")
	change_scene_to_file(gs.zone_path("village_aube"))
	await _wait(3.0)
	var z := current_scene
	var r: Control = z.hud.reward
	await _shot("hud")                                   # plus de suivi de quêtes à l'écran
	gs.gain_xp(CombatRules.xp_to_next(gs.profile.level))
	await _wait(0.6)
	await _shot("niveau")
	r._next()
	gs.skill_unlocked.emit("trait_de_lumiere")
	await _wait(0.6)
	await _shot("competence")
	r._next()
	gs.title_unlocked.emit("fleau_des_loups_dores")
	await _wait(0.6)
	await _shot("titre")
	r._next()
	# craft : objet rare d'une nouvelle recette
	gs.add_item("croc_d_or_pur", 1)
	gs.add_item("poil_de_loup_dore", 2)
	z.hud.open_workshop("couture")
	var at: Control = z.hud.atelier
	at._type = "capuche"
	at._add("croc_d_or_pur")
	at._add("poil_de_loup_dore")
	at._add("poil_de_loup_dore")
	await _wait(0.3)
	at._on_go()
	await _wait(4.0)
	await _shot("craft")
	r._next()
	await _wait(0.3)
	await _shot("atelier")
	quit()
