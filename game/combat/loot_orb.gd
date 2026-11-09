extends Node2D
## Butin : un éclat doré saute hors de la bête puis file vers le joueur (ramassage automatique).

var target: Node2D
var item_id := ""
var qty := 1
var _t := 0.0
var _start := Vector2.ZERO
var _hop := Vector2.ZERO


var _tex: Texture2D


func _ready() -> void:
	_tex = UISkin.item_icon(item_id)
	_start = position
	_hop = Vector2(randf_range(-14, 14), randf_range(-6, 6))
	z_index = 15


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.35:                                     # saut hors du corps
		var k := _t / 0.35
		position = _start + _hop * k + Vector2(0, -16 * sin(k * PI))
	elif is_instance_valid(target):                   # aspiration vers le joueur
		var goal := target.global_position + Vector2(0, -10)
		var d := goal - global_position
		var spd := 120.0 + 400.0 * (_t - 0.35)
		if d.length() < 6.0:
			var gs := (get_node_or_null("/root/GameState") if is_inside_tree() else null)
			if gs:
				gs.add_item(item_id, qty)
			queue_free()
			return
		global_position += d.normalized() * minf(spd * delta, d.length())
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 18.0)
	if _tex:                                          # l'objet lui-même, avec un halo doré
		draw_circle(Vector2.ZERO, 7.0 + pulse, Color("ffe08a", 0.25))
		draw_texture(_tex, Vector2(-8, -8))
		return
	draw_colored_polygon(PackedVector2Array([Vector2(0, -3), Vector2(3, 0), Vector2(0, 3), Vector2(-3, 0)]),
		Color("f5b84a"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -2), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]),
		Color("fff4d6", 0.6 + 0.4 * pulse))
