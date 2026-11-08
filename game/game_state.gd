extends Node
## Autoload « GameState » : état qui survit aux changements de zone.
## Pour l'instant : la zone d'où l'on vient (pour apparaître à la bonne sortie) et le fondu de transition.
## (Quêtes, inventaire, conditions viendront ici.)

signal zone_changed(zone_id: String)

var floor_id := "floor_1"
var current_zone := ""
var arrival_from := ""          # zone d'où l'on arrive ("" = point d'apparition par défaut)

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color("2a1a2e")
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)


func zone_path(zone_id: String) -> String:
	return "res://scenes/zones/%s/%s.tscn" % [floor_id, zone_id]


func has_zone(zone_id: String) -> bool:
	return ResourceLoader.exists(zone_path(zone_id))


func is_travelling() -> bool:
	return _busy


## Fondu au noir, changement de scène, fondu retour. La nouvelle zone place le joueur
## à la sortie qui mène vers `from_zone` (voir zone.gd).
func travel(from_zone: String, to_zone: String) -> void:
	if _busy or not has_zone(to_zone):
		return
	_busy = true
	arrival_from = from_zone
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.3)
	await tw.finished
	get_tree().change_scene_to_file(zone_path(to_zone))
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.35)
	await tw2.finished
	_busy = false
