shader_type canvas_item;
// Calque d'équipement : les gris (3 niveaux) prennent la teinte de la matière de l'objet ;
// le reste (bois, gemme, contour) garde sa couleur. Lueur de rareté autour de l'objet
// (« rare » : liseré fixe ; « épique » : il pulse) et éclair blanc quand le joueur est touché.

uniform vec4 light : source_color = vec4(0.91, 0.91, 0.91, 1.0);
uniform vec4 mid : source_color = vec4(0.64, 0.64, 0.64, 1.0);
uniform vec4 dark : source_color = vec4(0.38, 0.38, 0.38, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.88, 0.54, 1.0);
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// armures : pas de contour (il passerait au milieu du corps), un reflet de la couleur du rang
uniform float shine : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.5 && abs(c.r - c.g) < 0.01 && abs(c.g - c.b) < 0.01) {
		float lv = c.r;
		c.rgb = lv > 0.78 ? light.rgb : (lv > 0.5 ? mid.rgb : dark.rgb);
		if (shine > 0.0 && lv > 0.5) {
			float w = shine * mix(1.0, 0.5 + 0.5 * sin(TIME * 3.0), pulse);
			c.rgb = mix(c.rgb, glow_color.rgb, floor(w * 4.0) / 8.0);
		}
	}
	if (c.a < 0.5 && glow > 0.0) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (n > 0.5) {
			float k = glow * mix(1.0, 0.45 + 0.55 * (0.5 + 0.5 * sin(TIME * 4.0)), pulse);
			c = vec4(glow_color.rgb, floor(k * 4.0) / 4.0 * 0.85);   // en paliers : reste « pixel »
		}
	}
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	COLOR = c;
}
