extends SceneTree
## Captures de Rive Paisible : art/preview/godot_rive_*.png (fenêtre visible).

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
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_rive_%s.png" % name))
	print("capture ", name)


func _go(p: CharacterBody2D, tiles: Vector2) -> void:
	p.global_position = tiles * 16.0
	p.get_node("Camera2D").reset_smoothing()
	await _wait(0.6)


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	for k in ["atk", "atk", "atk", "def", "def", "hp"]:
		gs.spend_point(k)
	gs.accept_quest("intro_peche")
	change_scene_to_file(gs.zone_path("rive_paisible"))
	for i in 30:
		await process_frame
	var z := current_scene
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	for m in z.find_children("*", "Node2D", true, false).filter(func(n): return n.get("leash") != null):
		m.set_process(false)
	await _go(p, Vector2(27, 31))
	await _shot("hameau")
	await _go(p, Vector2(41.5, 20.5))
	z._start_gather(z.find_child("peche_eaux_basses", true, false))
	await _wait(1.6)
	await _shot("peche")
	z._gather = null
	z._gather_bar.visible = false
	await _go(p, Vector2(52.5, 32))
	await _shot("jetee")
	await _go(p, Vector2(64, 14))
	await _shot("ilot")
	await _go(p, Vector2(56, 40))
	await _shot("galets")
	await _go(p, Vector2(84, 42))
	await _shot("grand_ponton")
	var eel: Node2D = z.find_child("anguille_spawn_1", true, false)
	eel.set_process(true)
	gs.fighter.hp = 9999.0
	await _go(p, (eel.global_position + Vector2(-30, 0)) / 16.0)
	var t_end := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < t_end and not eel.submerged:
		await process_frame
	await _wait(0.35)
	await _shot("hauts_fonds")
	gs.add_note("cercle_immerge", "Le cercle sous l'îlot", z.find_child("cercle_immerge", true, false).dialogues[0])
	z.hud.toggle_carnet()
	var c: Control = z.hud.carnet
	c._quest_sel = "note:cercle_immerge"
	c._tabs.current_tab = 4
	c.refresh()
	await _wait(0.4)
	await _shot("notes")
	quit()
