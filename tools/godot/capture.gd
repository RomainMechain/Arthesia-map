extends SceneTree
## Captures en jeu (rendu réel du moteur) pour valider une zone.
## Usage (fenêtre visible, pas --headless) :
##   godot --path . --script res://tools/godot/capture.gd -- floor_1 village_aube x,y:nom x,y:nom ...
## Écrit art/preview/godot_<zone>_<nom>.png (vue joueur) et godot_<zone>_carte.png (carte entière).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var floor_id: String = args[0]
	var zone_id: String = args[1]
	var out_dir := ProjectSettings.globalize_path("res://art/preview/")
	var packed: PackedScene = load("res://scenes/zones/%s/%s.tscn" % [floor_id, zone_id])

	# 1) vues joueur
	var zone := packed.instantiate()
	root.add_child(zone)
	var player: Node2D = zone.find_child("Joueur", true, false)
	var cam: Camera2D = player.get_node("Camera2D")
	for spec in args.slice(2):
		var parts: PackedStringArray = spec.split(":")
		var xy: PackedStringArray = parts[0].split(",")
		player.global_position = Vector2(float(xy[0]), float(xy[1]))
		for i in 3:
			await process_frame
		cam.reset_smoothing()
		if parts.size() > 2:                              # x,y:nom:entry_id -> ouvre son dialogue
			zone._open(zone.find_child(parts[2], true, false))
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png(out_dir + "godot_%s_%s.png" % [zone_id, parts[1]])
		print("capture ", parts[1], " ", img.get_size())
	zone.queue_free()
	await process_frame

	# 2) carte entière à l'échelle 1 dans un SubViewport
	var vp := SubViewport.new()
	var map := packed.instantiate()
	var cam2: Camera2D = map.find_child("Camera2D", true, false)
	cam2.enabled = false
	var size: Vector2i = Vector2i(1280, 864)
	var lay: Node = map.find_child("sol", true, false)
	if lay is TileMapLayer:
		size = Vector2i((lay as TileMapLayer).get_used_rect().size * 16)
	vp.size = size
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(map)
	root.add_child(vp)
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out_dir + "godot_%s_carte.png" % zone_id)
	print("capture carte ", size)
	quit()
