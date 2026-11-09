extends Node2D
## Zone d'une attaque annoncée, dessinée au sol : elle se remplit pendant `duration`.
## Sortir de la zone avant la fin = attaque évitée (règle « sortir de la zone », docs/combat_v1.md).

var area: Dictionary = {}
var dir := Vector2.RIGHT
var duration := 0.6
var _t := 0.0

const EDGE := Color(0.88, 0.35, 0.28, 0.85)
const FILL := Color(0.88, 0.35, 0.28, 0.22)
const GROW := Color(0.96, 0.72, 0.29, 0.38)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / maxf(duration, 0.01), 0.0, 1.0)
	match area.get("shape", "arc"):
		"circle":
			var r := float(area.get("radius", 24))
			draw_circle(Vector2.ZERO, r, FILL)
			draw_circle(Vector2.ZERO, r * k, GROW)
			draw_arc(Vector2.ZERO, r, 0, TAU, 32, EDGE, 1.0)
		"line":
			var L := float(area.get("range", 96))
			var w := float(area.get("width", 10))
			var n := dir.orthogonal() * w / 2.0
			draw_colored_polygon(PackedVector2Array([n, dir * L + n, dir * L - n, -n]), FILL)
			if L * k > 2.0:
				draw_colored_polygon(PackedVector2Array([n, dir * L * k + n, dir * L * k - n, -n]), GROW)
		_:
			var r := float(area.get("range", 22))
			var half := deg_to_rad(float(area.get("angle", 80)) / 2.0)
			var a0 := dir.angle() - half
			var a1 := dir.angle() + half
			draw_colored_polygon(_sector(r, a0, a1), FILL)
			if r * k > 3.0:                               # secteur trop petit : on attend (triangulation)
				draw_colored_polygon(_sector(r * k, a0, a1), GROW)
			draw_arc(Vector2.ZERO, r, a0, a1, 16, EDGE, 1.0)
			draw_line(Vector2.ZERO, Vector2.from_angle(a0) * r, EDGE, 1.0)
			draw_line(Vector2.ZERO, Vector2.from_angle(a1) * r, EDGE, 1.0)


func _sector(r: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 13:
		pts.append(Vector2.from_angle(lerpf(a0, a1, i / 12.0)) * r)
	return pts
