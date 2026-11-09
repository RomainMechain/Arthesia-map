extends SceneTree
## Captures du combat en jeu (fenêtre visible) : art/preview/godot_combat_*.png
## Usage : godot --path . --script res://tools/godot/capture_combat.gd

var gs: Node


func _initialize() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://art/preview/godot_combat_%s.png" % name))
	print("capture ", name)


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await process_frame


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.gain_xp(CombatRules.xp_to_next(1))                 # niveau 2 : 6 points en attente pour la fiche
	gs.accept_quest("veille_silencieuse")
	change_scene_to_file(gs.zone_path("sentier_lisiere"))
	for i in 30:
		await process_frame
	var z := current_scene
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	var loup: Node2D = z.find_child("loup_dore_spawn_1", true, false)
	p.global_position = loup.global_position + Vector2(-30, 6)
	p.get_node("Camera2D").reset_smoothing()
	gs.add_item("pain_de_miel", 3)
	await _wait(0.35)
	await _shot("alerte")                               # les loups repèrent le joueur
	await _wait(2.15)                                   # les loups engagent
	for i in 4:
		p.attack((loup.global_position - p.global_position))
		p.cast(0, loup.global_position - p.global_position)
		await _wait(0.45)
	p.cast(1, loup.global_position - p.global_position)
	await _wait(0.08)
	await _shot("echange")
	# coup annoncé : la zone se remplit au sol
	var griffe: Dictionary = loup.tpl.moveset.filter(func(m): return m.id == "griffure_luisante")[0]
	loup.state = "chase"
	loup._start_move(griffe, (p.global_position - loup.global_position).normalized())
	await _wait(0.35)
	await _shot("telegraphe")
	await _wait(1.0)
	z.hud.toggle_carnet()
	var c: Control = z.hud.carnet
	c._change("atk", 1)
	c._change("atk", 1)
	c._change("agi", 1)
	await _wait(0.2)
	await _shot("carnet")
	c._tabs.current_tab = 2
	c._selected_skill = "premiers_soins"
	c.refresh()
	await _wait(0.2)
	await _shot("carnet_competences")
	for it in [["patte_de_lapin", 3], ["poil_de_loup_dore", 5], ["champignon_dore", 2], ["plume_doree", 1],
			["mousse_lumineuse_aube", 4], ["eclat_de_pierre_taillee", 2], ["dague_villageoise", 1], ["pain_de_miel", 1]]:
		gs.add_item(it[0], it[1])
	c._tabs.current_tab = 3
	c._selected_item = "dague_villageoise"
	c.refresh()
	await _wait(0.3)
	await _shot("carnet_sac")
	gs.add_item("gants_de_pecheur", 1)
	gs.add_item("hachette_d_isarn", 1)
	gs.equip_item("dague_villageoise")
	gs.equip_item("amulette_du_levant") if gs.item_count("amulette_du_levant") > 0 else null
	c._tabs.current_tab = 1
	c._slot = "gloves"
	c.refresh()
	await _wait(0.3)
	await _shot("carnet_equipement")
	c._tabs.current_tab = 5
	c._map_sel = "foret_ancienne"
	c.refresh()
	await _wait(0.3)
	await _shot("carnet_carte")
	c._tabs.current_tab = 4
	c.refresh()
	await _wait(0.3)
	await _shot("carnet_quetes")
	c.visible = false
	gs.profile.gold = 60
	z.hud.open_shop("echoppe_thessaly")
	await _wait(0.3)
	await _shot("commerce")
	z.hud.shop.visible = false
	for i in 3:
		p.attack((loup.global_position - p.global_position))
		await _wait(0.06)
		await _shot("coup_dague_%d" % i)
		await _wait(1.5)
	c.visible = false
	z.drop_loot(p.global_position + Vector2(30, -10), [["croc_d_or_pur", 1], ["poil_de_loup_dore", 2]])
	await _wait(0.25)
	await _shot("butin")
	quit()
