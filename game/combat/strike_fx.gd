extends Node2D
## Trace visuelle d'un coup : arc balayé (corps à corps), trait de lumière (ligne), onde (cercle),
## éclat de soin. Purement décoratif ; les dégâts sont réglés par les règles.

var area: Dictionary = {}
var dir := Vector2.RIGHT
var color := Color("fff4d6")
var life := 0.16
var weapon: Texture2D             # arme portée : elle balaie l'arc avec la trace
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / life, 0.0, 1.0)
	var c := Color(color, 1.0 - k)
	match area.get("shape", "arc"):
		"line":
			var L := float(area.get("range", 96))
			if weapon:                                    # coup d'estoc (lance) : l'arme jaillit
				var ang2 := dir.angle()
				draw_set_transform(dir * L * minf(1.0, k * 2.0) * 0.6, ang2 + PI / 4.0, Vector2.ONE)
				draw_texture(weapon, Vector2(-8, -8), Color(1, 1, 1, 1.0 - k * 0.6))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var head := dir * L * minf(1.0, k * 1.6)
			var tail := dir * L * maxf(0.0, k * 1.6 - 0.45)
			draw_line(tail, head, Color("ffe08a", 1.0 - k * 0.5), float(area.get("width", 10)) * 0.4)
			draw_line(tail, head, Color("fff4d6", 1.0 - k * 0.5), 1.0)
		"circle":
			draw_arc(Vector2.ZERO, float(area.get("radius", 24)) * (0.4 + 0.6 * k), 0, TAU, 32, c, 2.0)
		"self":
			for i in 6:
				var a := i * TAU / 6.0 + k * 2.0
				draw_rect(Rect2(Vector2.from_angle(a) * (6.0 + 6.0 * k) + Vector2(0, -12 - 10 * k), Vector2(2, 2)),
					Color("a8c84e", 1.0 - k))
		_:
			var r := float(area.get("range", 22))
			var half := deg_to_rad(float(area.get("angle", 90)) / 2.0)
			var sweep := lerpf(-half, half, minf(1.0, k * 1.8))
			var a := dir.angle()
			draw_arc(Vector2.ZERO, r * 0.85, a - half, a + sweep, 12, c, 3.0)
			draw_arc(Vector2.ZERO, r * 0.85 - 2.0, a - half * 0.6, a + sweep, 10, Color("fff4d6", (1.0 - k) * 0.8), 1.0)
			if weapon:                                    # la lame suit le bout de la trace
				var ang := a + sweep
				draw_set_transform(Vector2.from_angle(ang) * r * 0.55, ang + PI / 4.0, Vector2.ONE)
				draw_texture(weapon, Vector2(-8, -8), Color(1, 1, 1, 1.0 - k * 0.6))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
