extends Node2D
## Barre de récolte au-dessus du joueur : plaque de laiton, icône de la ressource, remplissage doré.

var progress := 0.0
var icon: Texture2D
var _frame: StyleBoxTexture


func _ready() -> void:
	z_index = 30
	_frame = UISkin.box("plate", 4, 0)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := 34.0
	var r := Rect2(-w / 2.0 + 6.0, -38.0, w, 8.0)
	draw_style_box(_frame, r.grow(1))
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2((r.size.x - 4) * clampf(progress, 0, 1), r.size.y - 4)), Color("f5b84a"))
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2((r.size.x - 4) * clampf(progress, 0, 1), 1)), Color("fff4d6"))
	if icon:
		draw_texture(icon, Vector2(r.position.x - 17.0, r.position.y - 4.0))
