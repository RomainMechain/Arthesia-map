extends SceneTree
## Planches des animations de toutes les compétences : art/preview/godot_skill_<id>_<n>.png
## godot --path . --script tools/godot/capture_skills2.gd [-- <id>...]   (fenêtre visible)

var gs: Node
const SHOTS := {
	"coup_puissant": [0.08, 0.2, 0.26, 0.32, 0.45],
	"eclat_d_aube": [0.08, 0.17, 0.24, 0.3, 0.4],
	"lame_d_aube": [0.04, 0.08, 0.12, 0.18, 0.28],
	"carapace_des_galets": [0.05, 0.12, 0.25, 0.4, 1.0],
	"bond_du_lynx": [0.06, 0.15, 0.2, 0.26, 0.36],
	"chant_du_fond": [0.1, 0.25, 0.4, 0.6, 1.5],
	"estoc_runique": [0.05, 0.12, 0.15, 0.2, 0.3],
	"rune_de_rupture": [0.15, 0.35, 0.48, 0.6, 0.9],
	"rune_tranchante": [0.03, 0.1, 0.14, 0.2, 0.3],
	"secousse_du_colosse": [0.15, 0.3, 0.36, 0.45, 0.7],
	"seve_des_fougeres": [0.2, 0.45, 0.7, 0.95, 1.2],
	"toile_doree": [0.1, 0.25, 0.4, 0.6, 1.2],
	"lame_des_consignes": [0.05, 0.2, 0.35, 0.5, 0.65],
	"lumiere_figee": [0.1, 0.35, 0.5, 0.7, 1.2],
	"verdict_du_heraut": [0.3, 0.62, 0.7, 0.85, 1.3],
}
const DIST := {"eclat_d_aube": 70, "bond_du_lynx": 42, "verdict_du_heraut": 26, "carapace_des_galets": 60,
	"seve_des_fougeres": 60, "lumiere_figee": 60}
const PASSIVES := {"peau_d_ambre": [0.05, 0.15, 0.3], "instinct_de_traqueuse": [0.05, 0.15, 0.25],
	"matin_d_halvard": [0.2, 0.6, 1.2], "mains_de_ravaudeur": [0.15, 0.35, 0.55], "patience_du_pecheur": [0.3, 0.9, 1.5]}


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_skill_%s.png" % name))


func _run() -> void:
	var only: Array = Array(OS.get_cmdline_user_args())
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	gs.settings.hints = false
	gs.profile.level = 10
	gs.profile.skills = SHOTS.keys() + PASSIVES.keys()
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
			m.global_position += Vector2(2000, 2000)
	var home: Vector2 = wolf._home + Vector2(-12, 0)
	for sid in SHOTS:
		if not only.is_empty() and not sid in only:
			continue
		p.global_position = home
		p.fighter.mana = 9999
		p.fighter.cooldowns.clear()
		p.fighter.hp = p.fighter.max_hp() * 0.4
		wolf.set_process(false)
		wolf.visible = true
		wolf.fighter.hp = wolf.fighter.max_hp() * 50.0
		wolf.global_position = p.global_position + Vector2(int(DIST.get(sid, 22)), 0)
		gs.profile.bar = [sid, "", "", ""]
		p.get_node("Camera2D").reset_smoothing()
		await _wait(0.8)
		var t0 := Time.get_ticks_msec()
		var why: String = p.cast(0, Vector2.RIGHT)
		if why != "":
			print(sid, " : ", why)
		var i := 0
		for at in SHOTS[sid]:
			while Time.get_ticks_msec() - t0 < int(at * 1000):
				await process_frame
			await _shot("%s_%d" % [sid, i])
			i += 1
		await _wait(1.6)
		print("ok ", sid)
	# passives
	wolf.global_position = home + Vector2(60, 0)
	for pid in PASSIVES:
		if not only.is_empty() and not pid in only:
			continue
		p.global_position = home
		p.get_node("Camera2D").reset_smoothing()
		await _wait(0.6)
		var t1 := Time.get_ticks_msec()
		SkillFx.passive(pid, p, z, {"from": p.global_position + Vector2(20, -4)})
		var j := 0
		for at in PASSIVES[pid]:
			while Time.get_ticks_msec() - t1 < int(at * 1000):
				await process_frame
			await _shot("%s_%d" % [pid, j])
			j += 1
		await _wait(1.2)
		print("ok ", pid)
	quit()
