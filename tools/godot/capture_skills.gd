extends SceneTree
## Planches des animations de compétences : art/preview/godot_skill_<id>_<n>.png (fenêtre visible).

var gs: Node
const SHOTS := {
	"frappe": [0.03, 0.09, 0.14, 0.19, 0.27],
	"trait_de_lumiere": [0.05, 0.12, 0.17, 0.24, 0.32],
	"croc_dore": [0.02, 0.05, 0.09, 0.14, 0.2],
	"premiers_soins": [0.12, 0.3, 0.5, 0.7, 0.9],
}


func _initialize() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func(): quit(2))
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
	gs.profile.level = 3
	gs.profile.skills = ["frappe", "trait_de_lumiere", "croc_dore", "premiers_soins"]
	gs.profile.bar = ["frappe", "trait_de_lumiere", "croc_dore", "premiers_soins"]
	change_scene_to_file(gs.zone_path("sentier_lisiere"))
	await _wait(3.0)
	var z := current_scene
	var p: CharacterBody2D = z.find_child("Joueur", true, false)
	var wolf: Node2D = null
	for m in get_nodes_in_group("mobs"):
		if m.template_id == "loup_dore":
			wolf = m
			break
	for m in get_nodes_in_group("mobs"):           # les autres bêtes : loin
		if m != wolf:
			m.global_position += Vector2(2000, 2000)
	p.global_position = wolf._home + Vector2(-12, 0)        # terrain dégagé : là où vivent les loups
	var slot := 0
	for sid in SHOTS:
		p.fighter.mana = 999
		p.fighter.hp = p.fighter.max_hp() * 0.4
		wolf.set_process(false)
		wolf.visible = true
		wolf.fighter.hp = wolf.fighter.max_hp()
		wolf.global_position = p.global_position + Vector2({"trait_de_lumiere": 70, "premiers_soins": 90}.get(sid, 22), 0)
		p.get_node("Camera2D").reset_smoothing()
		await _wait(0.6)
		var t0 := Time.get_ticks_msec()
		print(sid, " -> ", p.cast(slot, Vector2.RIGHT))
		var i := 0
		for at in SHOTS[sid]:
			while Time.get_ticks_msec() - t0 < int(at * 1000):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art/preview/godot_skill_%s_%d.png" % [sid, i]))
			i += 1
		slot += 1
		await _wait(1.2)
	quit()
