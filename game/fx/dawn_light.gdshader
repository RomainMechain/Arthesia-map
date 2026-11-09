shader_type canvas_item;
// Rais de l'aube éternelle : bandes de lumière obliques (venues du haut-gauche) qui ondulent à peine.
// Ancrés au monde (cam_offset) pour ne pas glisser avec la caméra ; quantifiés pour rester « pixel ».
render_mode blend_add;

uniform vec2 cam_offset = vec2(0.0);
uniform vec2 screen_px = vec2(480.0, 270.0);
uniform float strength = 0.10;

void fragment() {
	vec2 w = floor(cam_offset + SCREEN_UV * screen_px);
	float d = w.x * 0.8 + w.y * 0.6;
	float band = (sin(d * 0.032 + TIME * 0.22) * 0.5 + 0.5) * (sin(d * 0.0105 - TIME * 0.06 + 1.3) * 0.5 + 0.5);
	float ray = smoothstep(0.30, 0.85, band);
	ray = floor(ray * 4.0) / 4.0;                          // paliers : pas de dégradé lisse
	float fade = clamp(1.0 - SCREEN_UV.y * 0.65, 0.0, 1.0); // plus fort en haut de l'écran
	COLOR = vec4(vec3(1.0, 0.86, 0.55) * ray * strength * fade, 1.0);
}
