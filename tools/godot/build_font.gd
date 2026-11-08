extends SceneTree
## Construit res://assets/fonts/arthesia_pixel.tres (FontFile bitmap) depuis la planche
## générée par tools/art/pixel_font.py.
## Usage : godot --headless --path . --script res://tools/godot/build_font.gd

const BASE := "res://assets/fonts/arthesia_pixel"


func _initialize() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + ".json"))
	var img := Image.load_from_file(ProjectSettings.globalize_path(BASE + ".png"))
	var h: int = meta.height
	var font := FontFile.new()
	font.fixed_size = h
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.multichannel_signed_distance_field = false
	font.generate_mipmaps = false
	var size := Vector2i(h, 0)
	font.set_cache_ascent(0, h, meta.ascent)
	font.set_cache_descent(0, h, meta.descent)
	font.set_texture_image(0, size, 0, img)
	for ch in meta.glyphs:
		var g: Array = meta.glyphs[ch]
		var c: int = (ch as String).unicode_at(0)
		font.set_glyph_advance(0, h, c, Vector2(g[2] + 1, 0))
		font.set_glyph_offset(0, size, c, Vector2(0, -meta.ascent))
		font.set_glyph_size(0, size, c, Vector2(g[2], h))
		font.set_glyph_uv_rect(0, size, c, Rect2(g[0], g[1], g[2], h))
		font.set_glyph_texture_idx(0, size, c, 0)
	for sp in [" ", " ", " "]:                      # espaces (dont insécables)
		var c: int = sp.unicode_at(0)
		font.set_glyph_advance(0, h, c, Vector2(meta.space, 0))
		font.set_glyph_size(0, size, c, Vector2.ZERO)
		font.set_glyph_uv_rect(0, size, c, Rect2())
		font.set_glyph_texture_idx(0, size, c, -1)
	var err := ResourceSaver.save(font, BASE + ".tres")
	print("font: ", BASE, ".tres err=", err, " glyphes=", meta.glyphs.size())
	quit(err)
