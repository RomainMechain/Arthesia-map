extends SceneTree
## Test du son : bus et volumes, bruitages chargés, ambiance et humeur musicale par zone, boss.

var _fail := 0


func _initialize() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func(): print("TIMEOUT"); quit(2))
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_fail += 1


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	var snd: Node = root.get_node_or_null("Sound")
	_check(snd != null, "autoload Sound présent")
	_check(AudioServer.get_bus_index("Musique") >= 0 and AudioServer.get_bus_index("Effets") >= 0, "bus Musique et Effets")
	var missing := []
	for n in ["swing", "swing_heavy", "hit", "crit", "dodge", "hurt", "mob_death", "telegraph", "alert", "dive", "splash",
			"loot", "gold", "potion", "gather", "gather_done", "fish", "anvil", "craft_done", "level_up", "unlock",
			"quest_accept", "quest_done", "discovery", "ui_click", "ui_page", "ui_open", "ui_close", "step", "step_water", "oars"]:
		if snd._stream(snd.SFX_DIR % n) == null:
			missing.append(n)
	_check(missing.is_empty(), "31 bruitages chargés %s" % ("" if missing.is_empty() else str(missing)))
	gs.set_setting("vol_sfx", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effets")), "volume des effets à 0 : bus coupé")
	gs.set_setting("vol_sfx", 0.6)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Effets"))
		and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Effets")) - linear_to_db(0.6)) < 0.1, "volume des effets à 60 %")
	change_scene_to_file(gs.zone_path("village_aube"))
	for i in 30:
		await process_frame
	_check(snd._amb_key.ends_with("village.wav") and snd.current_mood() == "calme", "village : ambiance village, humeur calme")
	_check(snd._amb[snd._amb_on].playing, "l'ambiance joue (boucle)")
	snd.push_mood("boss")
	_check(snd.current_mood() == "boss", "combat de boss : humeur boss")
	snd.pop_mood("boss")
	_check(snd.current_mood() == "calme", "fin du combat : retour au calme")
	snd.enter_zone("ruines_architectes", "ruins")
	_check(snd.current_mood() == "tension", "zone dangereuse (ruines) : humeur tension")
	Sfx.play("hit")
	_check(true, "Sfx.play sans erreur")
	print("\n%d échec(s)" % _fail)
	quit(_fail)
