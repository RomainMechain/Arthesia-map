extends SceneTree
## Captures : suivi de quête, PNJ vivants, bestiaire -> art/preview/godot_life_*.png (fenêtre visible).

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
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_life_%s.png" % name))
	print("capture ", name)


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	change_scene_to_file(gs.zone_path("village_aube"))
	await _wait(2.5)
	gs.current_zone = "village_aube"
	var z := current_scene
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	gs.accept_quest("intro_peche")
	gs.accept_quest("marche_equitable")
	gs.track_quest("intro_peche")
	await _wait(0.8)
	await _shot("suivi")
	# PNJ : Aldric de profil, avec sa phrase
	var aldric: Node2D = z.find_child("npc_aldric", true, false)
	p.global_position = aldric.global_position + Vector2(-34, 4)
	p.get_node("Camera2D").reset_smoothing()
	aldric._bark_ready = 0.0
	aldric._was_near = true
	await _wait(0.3)
	aldric.bark("Une chope ? Elle est propre. Elle l'est toujours.")
	await _wait(0.4)
	await _shot("pnj")
	# Carnet : quêtes (suivre) puis bestiaire
	gs.see_monster("loup_dore")
	gs.see_monster("lapin_bondissant")
	gs.profile.kills["loup_dore"] = 7
	gs.see_loot("loup_dore", "poil_de_loup_dore")
	gs.see_loot("loup_dore", "champignon_dore")
	z.hud.toggle_carnet()
	var c: Node = z.hud.carnet
	c._tabs.current_tab = 4
	c._quest_sel = "intro_peche"
	c.refresh()
	await _wait(0.4)
	await _shot("quetes")
	c._tabs.current_tab = 7
	c._beast_sel = "loup_dore"
	c.refresh()
	await _wait(0.4)
	await _shot("bestiaire")
	quit()
