extends SceneTree
## Capture du joueur et du loup PixelLab en jeu : art/preview/godot_pixellab.png


func _initialize() -> void:
	create_timer(40.0, true, false, true).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await process_frame


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	gs.profile.equipment = {"weapon": "lame_d_ambre", "head": "capuche_de_traqueuse"}
	gs.recompute_stats()
	change_scene_to_file(gs.zone_path("sentier_lisiere"))
	await _wait(3.0)
	var z := current_scene
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	var loups := ["loup_dore_spawn_1", "loup_dore_spawn_2", "loup_dore_spawn_2_1"]
	var c: Node2D = z.find_child(loups[0], true, false)
	for m in get_nodes_in_group("mobs"):
		m.set_process(false)
	for i in loups.size():
		var l: Node2D = z.find_child(loups[i], true, false)
		l.global_position = c.global_position + Vector2(-40 + i * 40, -10 + (i % 2) * 18)
		l.sprite.frame = [0, 3, 6][i]
		l.sprite.flip_h = i == 2
	p.global_position = c.global_position + Vector2(0, 40)
	p.facing = Vector2.UP
	p.get_node("Camera2D").reset_smoothing()
	await _wait(0.8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_pixellab.png"))
	print("capture ok")
	quit()
