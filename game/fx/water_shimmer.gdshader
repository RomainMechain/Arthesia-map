shader_type canvas_item;
// Miroitement de l'eau : des éclats d'aube passent sur les pixels clairs des tuiles d'eau.

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = COLOR;                                        // déjà la texture x modulation
	vec2 p = floor(wpos);
	float s = sin(p.x * 0.45 + p.y * 0.2 + TIME * 1.8) * sin(p.y * 0.7 - p.x * 0.1 - TIME * 1.2);
	float lum = dot(c.rgb, vec3(0.33));
	if (s > 0.82 && lum > 0.45) {
		c.rgb = mix(c.rgb, vec3(1.0, 0.96, 0.84), 0.65);
	} else if (s < -0.9 && lum > 0.35) {
		c.rgb *= 0.92;                                     // creux de vaguelette
	}
	COLOR = c;
}
