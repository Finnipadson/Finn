shader_type sky;

uniform vec3 oben : source_color = vec3(0.165, 0.47, 0.84);
uniform vec3 horizont : source_color = vec3(0.77, 0.89, 0.96);
uniform vec3 sonne = vec3(-0.35, 0.72, -0.6);
uniform vec3 mond = vec3(0.3, 0.6, 0.5);
uniform float nacht = 0.0;                         // Tageszeit: 0 Tag … 1 Nacht (Sterne, Mond)
uniform vec3 wolken_farbe : source_color = vec3(1.0);

float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p *= 2.03; a *= 0.5; } return s; }

void sky() {
	vec3 d = EYEDIR;
	float h = max(d.y, 0.0);
	vec3 c = mix(horizont, oben, pow(h, 0.38));
	float s = max(dot(d, normalize(sonne)), 0.0);
	float ueber = smoothstep(-0.08, 0.02, normalize(sonne).y);
	vec3 sf = mix(vec3(1.0, 0.55, 0.3), vec3(1.0, 0.95, 0.84), smoothstep(0.0, 0.35, normalize(sonne).y));
	c += sf * (pow(s, 900.0) * 8.0 + pow(s, 14.0) * 0.2 + pow(s, 4.0) * 0.12 * (1.0 - smoothstep(0.0, 0.3, normalize(sonne).y))) * ueber;
	if (nacht > 0.01 && d.y > -0.02) {
		// Sterne: feste Zellen am Himmel, weich gezeichnet (≥ 2 Bildpunkte), am Horizont ausgeblendet
		vec3 q = d * 160.0;
		vec3 zel = floor(q);
		vec3 fr = fract(q) - 0.5;
		float hz = hs(zel.xy + zel.z * 17.13);
		float stern = step(0.9, hz) * smoothstep(0.32, 0.05, length(fr - (vec3(hs(zel.yz), hs(zel.zx), hs(zel.xy + 3.1)) - 0.5) * 0.4));
		c += vec3(0.85, 0.9, 1.0) * stern * nacht * smoothstep(0.0, 0.25, d.y) * (0.5 + hz * 3.0);
		// Mond mit Hof
		float m = max(dot(d, normalize(mond)), 0.0);
		c += vec3(0.85, 0.9, 1.0) * (smoothstep(0.99975, 0.99985, m) * 1.6 + pow(m, 400.0) * 0.1) * nacht;
	}
	if (d.y > 0.0) {
		// Comic-Wolken auf einer gedachten Ebene
		vec2 uv = d.xz / (d.y + 0.12) * 1.1;
		float n = fbm(uv * 1.2 + vec2(3.0, 1.0));
		float wolke = smoothstep(0.55, 0.66, n) * smoothstep(0.0, 0.12, d.y);
		float schatten = smoothstep(0.55, 0.8, fbm(uv * 1.2 + vec2(3.0, 1.0) - normalize(sonne).xz * 0.08));
		vec3 wc = mix(vec3(1.0), vec3(0.76, 0.83, 0.92), schatten * 0.8) * wolken_farbe;
		c = mix(c, wc, wolke * 0.95);
	}
	COLOR = c;
}
