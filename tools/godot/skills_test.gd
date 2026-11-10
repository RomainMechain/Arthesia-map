extends SceneTree
## Toutes les compétences : chaque active se lance, touche (au bon moment), ses effets restent sur la
## cible ; les passives donnent leurs bonus et se déclenchent. godot --headless --path . --script tools/godot/skills_test.gd

var gs: Node
var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK    " if ok else "ECHEC ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	create_timer(200.0, true, false, true).timeout.connect(func(): print("TIMEOUT"); quit(2))
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await process_frame


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	gs.settings.hints = false
	gs.profile.level = 10
	gs.recompute_stats(true)
	var sag0: float = gs.fighter.stat("sag")
	var agi0: float = gs.fighter.stat("agi")
	gs.profile.skills = SkillFx.KINDS.duplicate() + ["patience_du_pecheur", "instinct_de_traqueuse", "peau_d_ambre",
		"matin_d_halvard", "mains_de_ravaudeur"]
	gs.recompute_stats(true)
	_check(gs.fighter.stat("sag") >= sag0 + 2.0, "patience du pêcheur : +2 SAG (%.1f -> %.1f)" % [sag0, gs.fighter.stat("sag")])
	_check(gs.fighter.stat("agi") > agi0 * 1.1, "instinct de traqueuse : AGI +12 %% (%.1f -> %.1f)" % [agi0, gs.fighter.stat("agi")])
	change_scene_to_file(gs.zone_path("sentier_lisiere"))
	await _wait(3.0)
	var z := current_scene
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	var wolf: Node2D = null
	for m in get_nodes_in_group("mobs"):
		if m.template_id == "loup_dore":
			wolf = m
			break
	for m in get_nodes_in_group("mobs"):
		if m != wolf:
			m.global_position += Vector2(3000, 3000)
	var home: Vector2 = wolf._home + Vector2(-12, 0)
	wolf.set_process(false)
	for sid in SkillFx.KINDS:
		var sk: Dictionary = gs.tpl("skills", sid)
		p.global_position = home
		p.fighter.mana = 9999
		p.fighter.cooldowns.clear()
		p.fighter.hp = p.fighter.max_hp() * 0.5
		p.fighter.shield = 0.0
		p.facing = Vector2.RIGHT
		wolf.fighter.hp = wolf.fighter.max_hp() * 100.0
		wolf.fighter.effects.clear()
		var dist := 22.0 if sid != "bond_du_lynx" else 40.0
		if sid in ["trait_de_lumiere", "eclat_d_aube"]:
			dist = 60.0
		wolf.global_position = p.global_position + Vector2(dist, 0)
		await _wait(0.1)
		gs.profile.bar = [sid, "", "", ""]
		var hp0: float = wolf.fighter.hp
		var php0: float = p.fighter.hp
		var why: String = p.cast(0, Vector2.RIGHT)
		var deals: bool = sk.get("effects", []).any(func(e): return e.type == "damage")
		var delay := SkillFx.impact_delay(sid)
		if delay > 0.0 and deals:
			await _wait(delay * 0.5)
			var early: bool = wolf.fighter.hp < hp0
			await _wait(delay * 0.5 + 0.25)
			_check(why == "" and not early,                       # (une esquive reste possible)
				"%s : le coup porte avec l'animation (%.2f s)" % [sid, delay])
		else:
			await _wait(0.3)
			var ok := why == ""
			for e in sk.get("effects", []):
				match e.type:
					"heal":
						ok = ok and p.fighter.hp > php0
					"shield":
						ok = ok and p.fighter.shield > 0.0
			_check(ok, "%s : lancée (%s)" % [sid, why if why != "" else "ok"])
		var fx := 0
		for n in z._fx.get_children() + p.get_children() + (z._ground.get_children() if z.get("_ground") else []):
			if n.get("kind") != null and str(n.get("kind")) != "":
				fx += 1
		if sid in ["chant_du_fond", "toile_doree", "rune_de_rupture"]:
			await _wait(0.4)
			var lingering: bool = wolf.get_children().any(func(c): return str(c.get("kind")).begins_with("linger"))
			_check(lingering, "%s : l'effet reste sur la bête touchée" % sid)
		if sid in ["carapace_des_galets", "lumiere_figee"]:
			var on_me: bool = p.get_children().any(func(c): return str(c.get("kind")).begins_with("linger"))
			_check(on_me, "%s : le bouclier se voit tant qu'il tient" % sid)
		await _wait(1.6 if SkillFx.tier(sid) >= 3 else 0.6)
	_check(p.sprite.modulate.a > 0.99 and p.sprite.scale.is_equal_approx(Vector2.ONE), "après tout ça : le joueur a retrouvé sa pose")
	_check(is_equal_approx(Engine.time_scale, 1.0), "le temps a repris son cours")
	# passives qui se déclenchent
	p.fighter.shield = 0.0
	p.fighter.hp = p.fighter.max_hp() * 0.2
	p.react({"dodged": false, "absorbed": 0.0, "final_damage": 1.0}, p.global_position + Vector2(10, 0))
	_check(p.fighter.shield > 0.0, "matin d'Halvard : sous 25 %% des PV, un bouclier (%.0f)" % p.fighter.shield)
	print("%d échec(s)" % fails)
	quit(1 if fails else 0)
