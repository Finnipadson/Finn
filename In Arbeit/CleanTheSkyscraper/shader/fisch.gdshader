shader_type spatial;
render_mode cull_disabled;

// Fischkörper aus Code (fische.gd): UV.x = 0 Schwanz … 1 Kopf, UV.y = 0 Bauch … 1 Rücken.
// muster: 0 keins, 1 Querbänder, 2 Punkte, 3 Längsstreifen, 4 Fleck (Bereich fleck), 5 helle Punkte + Linien (Walhai),
// 6 Netz/Marmor, 7 Querbänder fein (Feuerfisch)
uniform vec3 farbe : source_color = vec3(0.5);
uniform vec3 bauch : source_color = vec3(0.9);
uniform vec3 muster_farbe : source_color = vec3(0.1);
uniform int muster = 0;
uniform float anzahl = 5.0;
uniform vec4 fleck = vec4(0.3, 0.7, 0.3, 1.0);   // u0, u1, v0, v1
uniform float glanz = 0.35;

float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	vec3 c = mix(bauch, farbe, smoothstep(0.3, 0.62, v));
	float m = 0.0;
	if (muster == 1 || muster == 7) {
		float b = fract(u * anzahl);
		m = smoothstep(0.42, 0.5, b) * (1.0 - smoothstep(0.82, 0.9, b));
		if (muster == 1) m *= smoothstep(0.2, 0.4, v);
	} else if (muster == 2 || muster == 5) {
		vec2 q = vec2(u * anzahl, v * anzahl * 0.55);
		vec2 z = floor(q);
		vec2 mp = z + 0.25 + 0.5 * vec2(hs(z), hs(z + 3.7));
		float r = length(q - mp);
		m = 1.0 - smoothstep(0.16, 0.24, r);
		if (muster == 5) {
			m = max(m, (1.0 - smoothstep(0.03, 0.07, abs(fract(u * anzahl * 0.5) - 0.5))) * smoothstep(0.55, 0.7, v) * 0.8);
			m *= smoothstep(0.35, 0.55, v);
		}
	} else if (muster == 3) {
		float b = fract(v * anzahl);
		m = smoothstep(0.4, 0.5, b) * (1.0 - smoothstep(0.75, 0.85, b));
	} else if (muster == 4) {
		m = smoothstep(fleck.x, fleck.x + 0.05, u) * (1.0 - smoothstep(fleck.y - 0.05, fleck.y, u)) * smoothstep(fleck.z, fleck.z + 0.05, v) * (1.0 - smoothstep(fleck.w - 0.05, fleck.w, v));
	} else if (muster == 6) {
		float n = vn(vec2(u * anzahl, v * anzahl * 0.5));
		m = smoothstep(0.45, 0.55, n);
	}
	c = mix(c, muster_farbe, m);
	ALBEDO = c;
	ROUGHNESS = 1.0 - glanz;
	SPECULAR = 0.5;
}
