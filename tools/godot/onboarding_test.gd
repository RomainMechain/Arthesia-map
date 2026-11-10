extends SceneTree
## Écran titre, accueil du joueur (fil d'objectifs, guidage, Mère Yvenne), bulles d'aide, menu pause et
## réglages. Avec `--capture`, enregistre des captures (fenêtre visible) dans art/preview/godot_accueil_*.png.
## Usage : godot --headless --path . --script res://tools/godot/onboarding_test.gd

var _fail := 0
var gs: Node
var capture := false


func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	create_timer(120.0, true, false, true).timeout.connect(func(): print("ECHEC délai dépassé"); quit(2))
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_fail += 1


func _wait_scene(pred: Callable) -> void:
	for i in 600:
		if current_scene and pred.call(current_scene) and not gs.is_travelling():
			break
		await process_frame
	for i in 10:
		await process_frame


func _shot(name: String) -> void:
	if not capture:
		return
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_accueil_%s.png" % name))
	print("capture ", name)


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	# 1) écran titre
	change_scene_to_file("res://scenes/ui/titre.tscn")
	await _wait_scene(func(s): return s.name == "Titre")
	_check(current_scene.name == "Titre", "écran titre affiché")
	await _shot("titre")
	gs.new_game()
	gs.start_game()
	await _wait_scene(func(s): return s.get("zone_id") == "village_aube")
	var z := current_scene
	_check(z.zone_id == "village_aube" and gs.tutorial_step() == 0, "nouvelle partie : village, objectif 1")
	_check(gs.objective().text.begins_with("Parle à Mère Yvenne"), "objectif : %s" % gs.objective().text)
	_check(z.find_target("npc_yvenne") != null, "la flèche de guidage trouve Mère Yvenne")
	await _shot("arrivee")
	# 2) Mère Yvenne : accueil en 3 répliques
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	var yv: Node2D = z.find_child("npc_yvenne", true, false)
	p.global_position = yv.global_position + Vector2(14, 6)
	z._open(yv)
	_check(z._dialog.visible and z._dialog._text.text.begins_with("Ah… encore un Marqué") and z._dialog._pager.text == "1 / 3",
		"Yvenne accueille le Marqué (page %s)" % z._dialog._pager.text)
	for i in 60:
		await process_frame
	await _shot("yvenne")
	for i in 4:                                        # finir la ligne, page suivante…
		z._dialog.advance()
	_check(z._dialog._pager.text == "3 / 3", "les 3 répliques défilent (%s)" % z._dialog._pager.text)
	z._dialog.advance()
	_check(z._dialog._buttons.get_child_count() >= 1, "à la fin : les choix d'Yvenne (%d)" % z._dialog._buttons.get_child_count())
	z._dialog.close()
	_check(gs.tutorial_step() == 1 and not z._dialog.visible, "accueil terminé : objectif « répartir ses points »")
	z._open(yv)
	_check(z._dialog._pages.size() == 1, "deuxième visite : une réplique, puis les choix")
	z._dialog.close()
	# 3) points -> sentier -> chasse -> arme -> Aurin
	for k in ["hp", "atk", "atk", "def", "def", "int"]:
		gs.spend_point(k)
	_check(gs.tutorial_step() == 2, "points répartis : objectif « Sentier de la Lisière »")
	_check(z.find_target("exit_sentier_lisiere") != null, "la flèche pointe la sortie nord")
	gs.travel("village_aube", "sentier_lisiere")
	await _wait_scene(func(s): return s.get("zone_id") == "sentier_lisiere")
	_check(gs.tutorial_step() == 3, "arrivé au sentier : objectif « chasser »")
	for i in 3:
		gs.on_kill("lapin_bondissant", 1, "normal")
	_check(gs.tutorial_step() == 4, "3 bêtes : objectif « acheter une arme »")
	gs.profile.gold = 40
	gs.buy("echoppe_thessaly", "dague_villageoise")
	gs.equip_item("dague_villageoise")
	_check(gs.tutorial_step() == 5, "dague équipée : objectif « Aurin »")
	gs.accept_quest("veille_silencieuse")
	_check(gs.tutorial_step() == 6 and gs.objective().is_empty(), "quête d'Aurin acceptée : accueil terminé")
	# 4) bulles d'aide : une seule fois
	var got := []
	gs.hint.connect(func(k, _t): got.append(k))
	gs.show_hint("aggro")
	gs.show_hint("aggro")
	_check(got == ["aggro"], "bulle « repéré » montrée une seule fois")
	gs.set_setting("hints", false)
	gs.show_hint("telegraph")
	_check(got.size() == 1, "bulles coupées dans les réglages")
	gs.set_setting("hints", true)
	z = current_scene
	gs.replay_tutorial()
	gs.show_hint("resource")
	await _shot("bulle")
	# 5) menu pause et réglages
	z.hud.toggle_menu()
	_check(z.hud.menu.visible and paused, "menu : la partie est en pause")
	for i in 150:                                        # le bandeau de zone s'est effacé
		await process_frame
	await _shot("pause")
	z.hud.menu._show("settings")
	var amb0: float = gs.settings.ambience
	var btn: Button = z.hud.menu.find_children("*", "Button", true, false).filter(func(b): return "Pleine" in b.text or "Douce" in b.text or "Coupée" in b.text)[0]
	btn.pressed.emit()
	await process_frame
	_check(gs.settings.ambience != amb0, "réglage « Lumière d'aube » : %s -> %s" % [amb0, gs.settings.ambience])
	await _shot("reglages")
	z.hud.menu.close()
	_check(not paused, "menu fermé : la partie reprend")
	gs.set_setting("ambience", 1.0)
	# 6) retour au titre
	gs.go_title()
	await _wait_scene(func(s): return s.name == "Titre")
	_check(current_scene.name == "Titre", "retour à l'écran titre")
	print("\n%d échec(s)" % _fail)
	quit(_fail)
