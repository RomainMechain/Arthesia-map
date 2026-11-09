shader_type canvas_item;
// Végétation : le haut du sprite ondule au vent et s'écarte quand le joueur passe tout près.
// Décalages arrondis au pixel : pas de flou, juste un frémissement.

uniform vec2 player_pos = vec2(-9999.0);
uniform float amp = 1.0;          // amplitude du vent (px)
uniform float push = 2.0;         // écart au passage du joueur (px)

void vertex() {
	vec2 foot = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float h = 1.0 - UV.y;                                  // 1 en haut du sprite, 0 au pied
	float wind = sin(TIME * 1.4 + foot.x * 0.05 + foot.y * 0.031) * amp;
	float d = distance(foot, player_pos);
	float away = clamp(1.0 - d / 16.0, 0.0, 1.0) * sign(foot.x - player_pos.x + 0.01) * push;
	VERTEX.x += round((wind + away) * h);
}
