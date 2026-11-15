shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

// Bodenhöhe kommt pro Ecke über UV2.x → Tiefe = Wasserstand - Boden
uniform float wasser = 0.0;
uniform float modus = 0.0; // 0 = Nahbereich, 1 = fernes Meer
uniform vec3 flach : source_color = vec3(0.22, 0.80, 0.78);
uniform vec3 mittel : source_color = vec3(0.12, 0.62, 0.80);
uniform vec3 tief : source_color = vec3(0.05, 0.30, 0.62);

varying float tiefe;
varying vec3 wp;

float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y);
}
float wv(vec2 p, float t) {
	return sin(p.x * 0.35 + t * 1.3) * 0.5 + sin(p.y * 0.29 - t * 1.1) * 0.5 + sin((p.x - p.y) * 0.6 + t * 2.1) * 0.25
		+ vn(p * 0.8 + t * 0.35) * 0.7 + vn(p * 2.3 - vec2(t * 0.6, t * 0.2)) * 0.3;
}
float caus(vec2 p, float t) {
	vec2 q = p; float c = 0.0;
	for (int i = 0; i < 3; i++) { q += vec2(sin(q.y * 1.3 + t * 0.8), cos(q.x * 1.1 - t * 0.7)) * 0.6; c += abs(sin(q.x + q.y)); }
	return pow(1.0 - c / 3.0, 5.0);
}

void vertex() {
	float g = UV2.x;
	vec3 p = VERTEX;
	float d = wasser - g;
	float w = (sin(p.x * 0.08 + TIME * 1.1) * 0.12 + sin(p.z * 0.11 - TIME * 0.9) * 0.1 + sin((p.x + p.z) * 0.21 + TIME * 1.7) * 0.05) * smoothstep(0.0, 4.0, d);
	p.y = wasser + w + sin(TIME * 0.9) * 0.07;
	tiefe = p.y - g;
	VERTEX = p;
	wp = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	bool innen = abs(wp.x) < 399.0 && abs(wp.z) < 399.0;
	if (modus < 0.5 && !innen) discard;
	if (modus > 0.5 && innen) discard;
	float d = tiefe;
	if (d < 0.0) discard;
	float dist = length(CAMERA_POSITION_WORLD - wp);
	vec3 col = mix(flach, mittel, smoothstep(0.3, 6.0, d));
	col = mix(col, tief, smoothstep(6.0, 32.0, d));
	float amp = 0.3 * (1.0 - smoothstep(60.0, 500.0, dist));
	vec2 p = wp.xz; float e = 0.35;
	float n0 = wv(p, TIME);
	vec3 N = normalize(vec3((n0 - wv(p + vec2(e, 0.0), TIME)) * amp / e, 1.0, (n0 - wv(p + vec2(0.0, e), TIME)) * amp / e));
	NORMAL = normalize((VIEW_MATRIX * vec4(N, 0.0)).xyz);
	col += vec3(0.85, 1.0, 1.0) * caus(p * 0.3, TIME) * 0.3 * (1.0 - smoothstep(0.4, 5.0, d));
	float fn = vn(p * 0.55 + TIME * 0.25);
	float ufer = 1.0 - smoothstep(0.04, 0.22 + fn * 0.25, d);
	float band = smoothstep(0.55, 1.0, sin(d * 6.0 - TIME * 2.0 + fn * 5.0)) * (1.0 - smoothstep(0.25, 1.7, d)) * step(0.25, fn + 0.2);
	float schaum = clamp(max(ufer, band * 0.8), 0.0, 1.0);
	ALBEDO = mix(col * 0.8, vec3(0.95), schaum);
	ROUGHNESS = mix(0.05, 0.8, schaum);
	SPECULAR = 0.5;
	ALPHA = max(mix(0.62, 0.96, smoothstep(0.0, 4.0, d)), schaum * 0.95);
}
