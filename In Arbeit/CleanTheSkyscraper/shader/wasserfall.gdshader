shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Kanal stürzt die Ufermauer hinunter: helle Streifen laufen nach unten, unten Gischt
float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	float s = vn(vec2(UV.x * 22.0, UV.y * 3.0 - TIME * 3.5));
	float s2 = vn(vec2(UV.x * 50.0 + 3.0, UV.y * 6.0 - TIME * 5.0));
	float gischt = smoothstep(0.75, 1.0, UV.y);
	float a = 0.45 + 0.35 * s + 0.2 * s2 + gischt * 0.4;
	a *= smoothstep(0.0, 0.06, UV.x) * smoothstep(0.0, 0.06, 1.0 - UV.x);
	ALBEDO = mix(vec3(0.55, 0.8, 0.85), vec3(0.95, 0.98, 1.0), clamp(s * 0.6 + gischt, 0.0, 1.0));
	EMISSION = vec3(0.12, 0.14, 0.15);
	ROUGHNESS = 0.2;
	ALPHA = clamp(a, 0.0, 0.92);
}
