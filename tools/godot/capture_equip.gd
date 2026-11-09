extends SceneTree
## Équipement visible en jeu : art/preview/godot_equip.png (montage agrandi, fenêtre visible).

var gs: Node
var shots: Array = []


func _initialize() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await process_frame


func _grab(_p: Node2D) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://art/preview/_equip_%02d.png" % shots.size()))
	shots.append(1)


func _outfit(eq: Dictionary) -> void:
	gs.profile.equipment = eq
	gs.recompute_stats()


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	change_scene_to_file(gs.zone_path("village_aube"))
	await _wait(3.0)
	var z := current_scene
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	p.global_position = Vector2(1000, 520)            # loin des bords : la caméra reste centrée
	p.get_node("Camera2D").reset_smoothing()
	for m in z.find_children("*", "Node2D", true, false):
		if m.get("leash") != null:
			m.set_process(false)
	var outfits := [
		{"weapon": "lame_d_ambre~epique", "head": "heaume_runique", "chest": "plastron_d_ecailles", "gloves": "gants_de_pecheur", "boots": "bottes_de_ronce"},
		{"weapon": "dague_villageoise", "head": "capuche_de_traqueuse", "chest": "gilet_de_cire", "boots": "bottes_de_passeuse"},
		{"weapon": "lance_du_seuil~legendaire", "head": "couronne_du_gardien", "chest": "cuirasse_d_or_pale", "gloves": "gantelets_de_pierre"},
		{"weapon": "hachette_d_isarn~rare", "chest": "coeur_d_ecorce", "gloves": "griffes_du_lynx_clair"},
	]
	for eq in outfits:
		_outfit(eq)
		for f in [Vector2.DOWN, Vector2.RIGHT, Vector2.UP]:
			p.facing = f
			p._act = ""
			await _wait(0.25)
			await _grab(p)
		p.facing = Vector2.RIGHT
		p.attack()
		await _wait(0.1)
		await _grab(p)
	print("capture equip ", shots.size())
	quit()
