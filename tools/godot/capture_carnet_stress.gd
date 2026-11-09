extends SceneTree
## Carnet sous contenu chargé (noms longs, beaucoup d'objets/quêtes/métiers) : art/preview/godot_carnet_stress_*.png


func _initialize() -> void:
	create_timer(80.0, true, false, true).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_carnet_stress_%s.png" % name))
	print("capture ", name)


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	gs.settings.craft_ai = false
	# objet crafté au nom et à la description très longs
	gs.craft_cache = {"items": {"craft_long": {"id": "craft_long", "name": "Grande Lame Crépusculaire du Dernier Croc d'Aube",
		"description": "Un croc de loup doré, où l'aube s'est figée, est serti à chaud dans une poignée de bois sec et léger. La lame garde la chaleur d'une lumière qui ne se couche jamais et frappe avec la vivacité de la bête qui l'a perdu en mourant, sans jamais faiblir ni trembler.",
		"category": "equipment", "level": 1, "base_value": 30, "stack_size": 1, "generation": 1, "icon": "dague_villageoise",
		"equipment": {"slot": "weapon", "level_required": 1, "stat_bonuses": {"atk": 3, "agi": 2}}}}, "recipes": {}}
	gs.add_item("craft_long~legendaire", 1)
	gs.add_item("craft_long", 1)
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/templates/index.json"))
	var n := 0
	for e in d:
		if e.get("kind") == "item" and n < 60:
			gs.add_item(e.id, 1 + n % 12)
			n += 1
	for q in ["intro_peche", "filets_a_ravauder", "les_filets_d_ober", "ce_qui_tire_les_filets", "pinces_sur_les_galets", "ce_qui_remue_sous_l_eau"]:
		gs.accept_quest(q)
	gs.add_note("cercle_immerge", "Le cercle sous l'îlot, sept pierres taillées sous l'eau claire de l'anse", "Texte très long. ".repeat(40))
	for p in ["forgeron", "couturier", "sculpteur", "alchimiste", "cuisinier", "herboristerie", "peche", "minage", "runographie"]:
		gs.profile.professions[p] = {"level": 3, "xp": 40.0}
	gs.profile.gold = 123456
	while gs.profile.level < 8:
		gs.gain_xp(CombatRules.xp_to_next(gs.profile.level))
	gs.equip_item("craft_long~legendaire")
	change_scene_to_file(gs.zone_path("village_aube"))
	await _wait(2.8)
	var z := current_scene
	z.hud.toggle_carnet()
	var c: Control = z.hud.carnet
	var names := ["perso", "equip", "comp", "sac", "quetes", "carte"]
	for i in 6:
		c._tabs.current_tab = i
		if i == 3:
			c._selected_item = "craft_long~legendaire"
		if i == 4:
			c._quest_sel = "ce_qui_remue_sous_l_eau"
		c.refresh()
		await _wait(0.3)
		await _shot(names[i])
	c._tabs.current_tab = 4
	c._quest_sel = "note:cercle_immerge"
	c.refresh()
	await _wait(0.3)
	await _shot("note")
	c._tabs.current_tab = 1
	c._slot = "weapon"
	c.refresh()
	await _wait(0.3)
	await _shot("equip_arme")
	quit()
