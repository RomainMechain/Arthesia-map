shader_type canvas_item;
// Flash blanc à l'impact : 0 = normal, 1 = silhouette blanche.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 0.97, 0.88), flash);
}
