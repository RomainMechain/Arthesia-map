extends SceneTree
## Captures du dialogue : art/preview/godot_dialog_*.png (fenêtre visible).

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
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_dialog_%s.png" % name))
	print("capture ", name)


func _choose(d: Control, kind: String) -> void:
	for c in d._choices:
		if c.act.kind == kind:
			d._choose(c.act)
			return


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	change_scene_to_file(gs.zone_path("village_aube"))
	await _wait(3.0)
	var z := current_scene
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	var garin: Node2D = z.find_child("npc_garin", true, false)
	p.global_position = garin.global_position + Vector2(16, 8)
	p.get_node("Camera2D").reset_smoothing()
	await _wait(0.5)
	z._open(garin)
	await _wait(0.9)
	await _shot("discussion")
	var d: Control = z._dialog
	for i in 8:
		d.advance()
	await _wait(0.3)
	await _shot("choix")
	_choose(d, "quest_page")
	for i in 6:
		if d._idx < d._pages.size() - 1 or d._text.visible_characters != -1:
			d.advance()
	await _wait(0.4)
	await _shot("fiche")
	_choose(d, "accept")
	await _wait(2.5)
	await _shot("acceptee")
	d.close()
	gs.add_item("truite_argentee_aube", 3)
	z._open(garin)
	d.advance()
	_choose(d, "turn_in_page")
	d.advance()
	_choose(d, "turn_in")
	await _wait(0.8)
	await _shot("rendue")
	quit()
