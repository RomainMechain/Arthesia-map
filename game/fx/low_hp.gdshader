shader_type canvas_item;
// Liseré rouge au bord de l'écran quand les PV sont bas (intensité 0..1, pulsée par le HUD).
// En paliers, pour rester « pixel ».

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;                 // 0 au centre, 1 au bord
	float edge = max(d.x, d.y);
	float v = smoothstep(0.62, 1.0, edge);
	v = floor(v * 4.0) / 4.0;
	COLOR = vec4(0.66, 0.16, 0.2, v * 0.8 * intensity);
}
