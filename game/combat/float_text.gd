extends Label
## Chiffre de dégâts (ou « Esquivé », « +12 »...) qui saute au-dessus d'une cible puis s'efface.

var _t := 0.0
var _vy := -38.0
const LIFE := 0.8


static func make(text: String, color: Color, big := false) -> Label:
	var l: Label = (load("res://game/combat/float_text.gd") as GDScript).new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20 if big else 10)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color("2a1a2e"))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(60, 20)
	l.z_index = 20
	return l


func _ready() -> void:
	position += Vector2(-30 + randf_range(-4, 4), -10)


func _process(delta: float) -> void:
	_t += delta
	_vy += 70.0 * delta
	position.y += _vy * delta
	modulate.a = clampf((LIFE - _t) / 0.3, 0.0, 1.0)
	if _t >= LIFE:
		queue_free()
