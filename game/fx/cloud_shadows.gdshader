shader_type canvas_item;
// Ombres de nuages qui glissent lentement sur le sol (multiplication douce, teinte prune).
render_mode blend_mul;

uniform vec2 cam_offset = vec2(0.0);
uniform vec2 screen_px = vec2(480.0, 270.0);
uniform float strength = 0.16;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 w = floor(cam_offset + SCREEN_UV * screen_px);
	vec2 drift = vec2(TIME * 6.0, TIME * 2.5);              // le vent pousse vers l'est
	float n = noise((w - drift) * 0.0045) * 0.65 + noise((w - drift * 1.4) * 0.011) * 0.35;
	float cloud = smoothstep(0.52, 0.68, n);
	cloud = floor(cloud * 3.0) / 3.0;
	vec3 shade = mix(vec3(1.0), vec3(0.74, 0.70, 0.86), cloud * strength / 0.16);
	COLOR = vec4(shade, 1.0);
}
