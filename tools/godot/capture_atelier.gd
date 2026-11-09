extends SceneTree
## Capture de l'écran d'atelier : art/preview/godot_atelier_*.png (fenêtre visible).


func _initialize() -> void:
	create_timer(40.0, true, false, true).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_atelier_%s.png" % name))
	print("capture ", name)


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	gs.craft_cache = {"items": {}, "recipes": {}}
	gs.settings.craft_ai = false
	for it in [["croc_d_or_pur", 2], ["branche_morte", 4], ["poil_de_loup_dore", 3], ["fourrure_de_lapin", 2],
			["galet_veine", 2], ["pain_de_miel", 1]]:
		gs.add_item(it[0], it[1])
	change_scene_to_file(gs.zone_path("village_aube"))
	await _wait(2.8)
	var z := current_scene
	z.hud.open_workshop("forge")
	var at: Control = z.hud.atelier
	at._type = "arme"
	at._add("croc_d_or_pur")
	at._add("branche_morte")
	at._add("branche_morte")
	await _wait(0.3)
	await _shot("etabli")
	at._on_go()
	await _wait(1.2)
	await _shot("fabrication")
	await _wait(2.6)
	await _shot("resultat")
	quit()
