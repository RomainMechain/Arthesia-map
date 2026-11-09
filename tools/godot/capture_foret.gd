extends SceneTree
## Captures de la Forêt des Anciens : art/preview/godot_foret_*.png (fenêtre visible).

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
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_foret_%s.png" % name))
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
	gs.profile.kills["sanglier_des_fougeres"] = 40
	for k in ["atk", "atk", "def", "def", "hp", "hp"]:
		gs.spend_point(k)
	change_scene_to_file(gs.zone_path("foret_ancienne"))
	await _wait(3.0)
	var z := current_scene
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	for m in z.find_children("*", "Node2D", true, false).filter(func(n): return n.get("leash") != null):
		m.set_process(m.get("temper") in ["ambusher", "dormant"] or m.get("spawn_condition") != {})
	gs.fighter.hp = 9999.0
	await _go(p, Vector2(10, 29))
	await _shot("entree")
	await _go(p, Vector2(20, 22))
	await _shot("camp")
	await _go(p, Vector2(34, 44))
	await _shot("fougeres")
	await _go(p, Vector2(49, 38))
	await _shot("rais")
	await _go(p, Vector2(52, 14))
	await _wait(2.5)
	await _shot("cercle")
	var veil: Node2D = z.find_child("veilleur_spawn", true, false)
	veil.set_process(true)
	p.global_position = veil.global_position + Vector2(-26, 8)
	await _wait(1.0)
	await _shot("veilleur")
	await _go(p, Vector2(70, 43))
	await _shot("ours")
	z.hud.toggle_map()
	await _wait(0.3)
	await _shot("carte")
	quit()
