extends SceneTree
## Captures de la faune en situation : art/preview/godot_faune_*.png (fenêtre visible).

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
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_faune_%s.png" % name))
	print("capture ", name)


## Regroupe des bêtes autour d'un point, figées dans une image donnée.
func _pose(z: Node, p: CharacterBody2D, at: Vector2, list: Array) -> void:
	for m in z.find_children("*", "Node2D", true, false).filter(func(n): return n.get("leash") != null):
		m.set_process(false)
		m.global_position = Vector2(-999, -999)
	for e in list:
		var m: Node2D = z.find_child(e[0], true, false)
		m.global_position = at + e[1]
		m.sprite.frame = e[2]
		m.sprite.flip_h = e[3]
	p.global_position = at + Vector2(0, 20)
	p.get_node("Camera2D").reset_smoothing()
	await _wait(2.6)                                  # la bannière de zone s'efface


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	change_scene_to_file(gs.zone_path("sentier_lisiere"))
	for i in 30:
		await process_frame
	var z := current_scene
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	var c := Vector2(200, 600)
	await _pose(z, p, c, [
		["loup_dore_spawn_1", Vector2(-70, -14), 0, false], ["loup_dore_spawn_2", Vector2(-28, -14), 6, false],
		["loup_dore_spawn_2_1", Vector2(18, -14), 7, false],
		["renardeau_spawn", Vector2(64, -14), 0, true],
		["lapin_spawn_1", Vector2(-64, 14), 0, false], ["lapin_spawn_2", Vector2(-36, 14), 4, false],
		["oiseau_spawn_1", Vector2(30, 14), 1, false], ["oiseau_spawn_2", Vector2(58, 14), 4, false]])
	await _shot("lisiere")
	gs.accept_quest("intro_peche")
	change_scene_to_file(gs.zone_path("rive_paisible"))
	for i in 30:
		await process_frame
	z = current_scene
	p = z.find_child("Joueur", true, false)
	c = Vector2(50, 37) * 16.0
	await _pose(z, p, c, [
		["crabe_spawn_1", Vector2(-60, -6), 0, false], ["crabe_spawn_2", Vector2(-24, -6), 6, false],
		["crabe_spawn_3", Vector2(12, -6), 7, false], ["heron_spawn", Vector2(56, -6), 0, true]])
	await _shot("rive")
	c = Vector2(72, 54) * 16.0
	await _pose(z, p, c, [
		["anguille_spawn_1", Vector2(-64, -4), 2, false], ["anguille_spawn_2", Vector2(-20, -4), 6, false],
		["anguille_spawn_3", Vector2(24, -4), 7, false], ["heron_spawn", Vector2(66, -4), 7, false]])
	await _shot("hauts_fonds")
	quit()
