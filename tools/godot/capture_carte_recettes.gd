extends SceneTree
## Captures : mini-carte, carte de la zone, enchantement, Carnet › Recettes (art/preview/godot_mm_*.png).

var gs: Node


func _initialize() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_mm_%s.png" % name))
	print("capture ", name)


func _close_popups(z: Node) -> void:
	while z.hud.reward.visible:
		z.hud.reward._next()


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	gs.settings.craft_ai = false
	gs.craft_cache = {"items": {}, "recipes": {}}
	change_scene_to_file(gs.zone_path("village_aube"))
	await _wait(3.0)
	var z := current_scene
	await _shot("mini_village")
	z.hud.toggle_map()
	await _wait(0.3)
	await _shot("carte_village")
	z.hud.toggle_map()
	# crafts : une lame, puis on l'enchante (Force) avec un réactif
	gs.profile.professions["enchanteur"] = {"level": 1, "xp": 0.0}
	for it in [["croc_d_or_pur", 1], ["branche_morte", 2], ["poil_de_loup_dore", 3], ["plume_doree", 2]]:
		gs.add_item(it[0], it[1])
	gs.craft_start("forge", "arme", {"croc_d_or_pur": 1, "branche_morte": 2})
	await _wait(3.6)
	_close_popups(z)
	var lame := ""
	for id in gs.profile.inventory:
		if (id as String).begins_with("craft_"):
			lame = id
	z.hud.open_workshop("enchantement")
	var at: Control = z.hud.atelier
	at._type = "force"
	at._add(lame)
	at._add("poil_de_loup_dore")
	at._add("plume_doree")
	await _wait(0.3)
	await _shot("enchant_etabli")
	at._on_go()
	await _wait(3.8)
	await _shot("enchant_resultat")
	_close_popups(z)
	z.hud.atelier.visible = false
	z.hud.toggle_carnet()
	var c: Control = z.hud.carnet
	c._tabs.current_tab = 6
	c.refresh()
	await _wait(0.3)
	await _shot("recettes")
	z.hud.toggle_carnet()
	gs.accept_quest("intro_peche")
	gs.travel("village_aube", "rive_paisible", "exit_village_aube")
	await _wait(3.5)
	z = current_scene
	z.hud.toggle_map()
	await _wait(0.3)
	await _shot("carte_rive")
	quit()
