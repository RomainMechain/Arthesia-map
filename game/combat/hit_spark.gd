extends Node2D
## Éclat d'impact : une étoile de lumière à 4 ou 8 branches qui jaillit puis s'éteint (au pixel).

var crit := false
var color := Color("fff4d6")
var _t := 0.0
const LIFE := 0.16


func _ready() -> void:
	z_index = 25
	rotation = randf() * 0.4


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	var arms := 8 if crit else 4
	var reach := (9.0 if crit else 6.0) * (0.5 + k)
	var a := 1.0 - k
	for i in arms:
		var d := Vector2.from_angle(i * TAU / arms)
		var len := reach * (1.0 if i % 2 == 0 else 0.6)
		draw_line(d * 2.0, d * len, Color(color, a), 1.0)
	draw_rect(Rect2(-1, -1, 2, 2), Color(1, 1, 1, a))
	if crit:
		draw_arc(Vector2.ZERO, reach + 2.0, 0, TAU, 16, Color("ffe08a", a * 0.8), 1.0)
