extends SceneTree
## Captures du tableau des contrats : art/preview/godot_contrats_*.png (fenêtre visible).

var gs: Node


func _initialize() -> void:
	create_timer(40.0, true, false, true).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await process_frame


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_contrats_%s.png" % n))


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	gs.settings.hints = false
	gs.profile.visited = ["village_aube", "sentier_lisiere", "rive_paisible", "foret_ancienne"]
	change_scene_to_file(gs.zone_path("village_aube"))
	await _wait(2.5)
	gs.current_zone = "village_aube"
	var z := current_scene
	var board: Node2D = z.find_child("tableau_contrats", true, false)
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	p.global_position = board.global_position + Vector2(-6, 16)
	p.get_node("Camera2D").reset_smoothing()
	var l: Array = gs.contracts()
	l[0] = gs._make_contract("hunt")
	l[1] = gs._make_contract("gather")
	l[2] = gs._make_contract("marked")
	l[2].items = [{"item_id": "croc_d_or_pur", "quantity": 1}]
	await _wait(0.6)
	await _shot("place")
	z._open(board)
	for i in 6:
		z._dialog.advance()
	await _wait(0.3)
	await _shot("tableau")
	z._dialog._choose({"kind": "contract_page", "i": 2})
	for i in 6:
		z._dialog.advance()
	await _wait(0.3)
	await _shot("feuille")
	quit()
