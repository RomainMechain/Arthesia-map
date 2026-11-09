extends SceneTree
## Capture d'une créature marquée par l'aube : art/preview/godot_marque.png


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
	change_scene_to_file(gs.zone_path("sentier_lisiere"))
	await _wait(1.0)
	var z := current_scene
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	var src: Node2D = z.find_child("loup_dore_spawn_1", true, false)
	for m in get_nodes_in_group("mobs"):
		if m != src:
			m.set_process(false)
	p.global_position = src.global_position + Vector2(-260, 0)
	z.rare_spawner.spawn()
	var mk: Node2D = z.rare_spawner.current
	mk.set_process(false)
	mk.global_position = src.global_position + Vector2(30, 0)
	src.set_process(false)
	p.global_position = src.global_position + Vector2(0, 40)
	p.get_node("Camera2D").reset_smoothing()
	await _wait(4.6)
	mk.set_process(true)
	mk.state = "wander"
	await _wait(0.4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_marque.png"))
	print("capture marque ", mk.tpl.get("name"))
	quit()
