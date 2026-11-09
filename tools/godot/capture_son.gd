extends SceneTree
## Capture de la page « Son » du menu : art/preview/godot_menu_son.png


func _initialize() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	change_scene_to_file(gs.zone_path("village_aube"))
	var t := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < t:
		await process_frame
	var z := current_scene
	z.hud.toggle_menu()
	z.hud.menu._show("sound")
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_menu_son.png"))
	print("capture son")
	quit()
