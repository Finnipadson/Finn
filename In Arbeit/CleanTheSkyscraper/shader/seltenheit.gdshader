shader_type spatial;
// Leuchtender Rand um seltene Gegenstände (Overlay): Farbe der Seltenheit, pulsiert leicht
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform vec3 farbe : source_color = vec3(0.3, 0.65, 1.0);
uniform float kraft = 1.0;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float puls = 0.75 + 0.25 * sin(TIME * 3.0);
	ALBEDO = farbe * f * kraft * puls;
}
