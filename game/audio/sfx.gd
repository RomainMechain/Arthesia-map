class_name Sfx
## Accès au son depuis n'importe quel script (le nœud « Sound », autoload game/audio/sound.gd).
## Sans lui (outils, tests sans autoload), ces appels ne font rien.


static func _s() -> Node:
	var ml := Engine.get_main_loop() as SceneTree
	return ml.root.get_node_or_null("Sound") if ml else null


static func play(name: String, volume_db := 0.0, pitch_var := 0.06, min_gap := 0.03) -> void:
	var s := _s()
	if s:
		s.play(name, volume_db, pitch_var, min_gap)


static func enter_zone(zone_id: String, zone_type: String) -> void:
	var s := _s()
	if s:
		s.enter_zone(zone_id, zone_type)


static func title_screen() -> void:
	var s := _s()
	if s:
		s.title_screen()


static func push_mood(m: String) -> void:
	var s := _s()
	if s:
		s.push_mood(m)


static func pop_mood(m: String) -> void:
	var s := _s()
	if s:
		s.pop_mood(m)
