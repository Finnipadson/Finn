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
float fbm2(vec2 p) { return 0.5 * vn(p) + 0.25 * vn(p * 2.03) + 0.125; }
float fbm3(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 3; i++) { s += a * vn(p); p *= 2.03; a *= 0.5; } return s + 0.0625; }
float fbm4(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { s += a * vn(p); p *= 2.03; a *= 0.5; } return s + 0.03125; }

vec4 wolken(vec3 d) {
	// Wolken (19.11.2026 überarbeitet): Haufenwolken auf einer gedachten Ebene mit verwirbelter Form, Licht von der Sonne
	// (dunklere Unterseite, helle Ränder im Gegenlicht), dazu hohe Schleierwolken. Keine Zeit-Animation (sonst würde das
	// Himmelslicht jedes Bild neu berechnet). Zum Horizont hin weniger Detail (gegen Flimmern).
	vec3 sn = normalize(sonne);
	vec2 uv = d.xz / (d.y + 0.12) * 1.1;
	float horiz_k = smoothstep(0.0, 0.12, d.y);
	vec2 warp = vec2(fbm2(uv * 0.55 + vec2(7.1, 2.3)), fbm2(uv * 0.55 + vec2(1.7, 9.2))) - 0.5;
	vec2 q = uv * 1.2 + vec2(3.0, 1.0) + warp * 0.9;
	float n = fbm(q);
	// hohe Schleierwolken (gestreckt, sehr zart)
	vec2 uc = vec2(uv.x * 0.35 + uv.y * 0.12, uv.y * 1.6 - uv.x * 0.2) * 0.9;
	float ci0 = smoothstep(0.55, 0.8, fbm3(uc + vec2(11.0, 4.0))) * smoothstep(0.02, 0.25, d.y);
	float hoch0 = clamp(normalize(sonne).y * 3.0, 0.0, 1.0);
	vec3 sf0 = mix(vec3(1.0, 0.62, 0.38), vec3(1.0, 0.97, 0.9), smoothstep(0.0, 0.4, normalize(sonne).y));
	vec3 licht0 = wolken_farbe * mix(vec3(1.0), sf0, 0.35 * (1.0 - hoch0 * 0.6));
	if (n < 0.47) {   // sicher keine Haufenwolke (auch mit Bäuschen nicht): Rest sparen
		return vec4(licht0 * 1.02, ci0 * 0.28);
	}
	// feine Bäusche am Rand (höhere Frequenz), zum Horizont ausgeblendet
	n += (fbm3(q * 3.1 + vec2(5.3, 8.1)) - 0.5) * 0.16 * smoothstep(0.04, 0.3, d.y);
	float wolke = smoothstep(0.555, 0.615, n) * horiz_k;
	// Licht: Dichte ein Stück zur Sonne hin = Schatten im Inneren / an der Unterseite
	vec2 zur_sonne = normalize(sn.xz + vec2(1e-4)) * 0.11;
	float n2 = fbm4(q + zur_sonne);
	float schatten = clamp((n2 - 0.5) * 3.6, 0.0, 1.0);
	float dicke = smoothstep(0.62, 0.82, n);                // Wolkenkern
	float hoch = clamp(sn.y * 3.0, 0.0, 1.0);
	vec3 sf2 = mix(vec3(1.0, 0.62, 0.38), vec3(1.0, 0.97, 0.9), smoothstep(0.0, 0.4, sn.y));
	vec3 licht = wolken_farbe * mix(vec3(1.0), sf2, 0.35 * (1.0 - hoch * 0.6));
	vec3 schatten_farbe = mix(mix(oben, horizont, 0.45) * 0.78, vec3(0.62, 0.68, 0.78), 0.35) * mix(wolken_farbe, vec3(1.0), 0.5);
	vec3 wc = mix(licht, schatten_farbe, clamp(schatten * 0.85 + dicke * 0.3, 0.0, 0.9));
	// Silberrand: dünne Ränder leuchten, wenn man Richtung Sonne schaut
	float rand = wolke * (1.0 - smoothstep(0.575, 0.64, n));
	float gegen = pow(max(dot(d, sn), 0.0), 6.0) * (1.0 - nacht);
	wc += sf2 * rand * gegen * 1.4;
	float ci = ci0 * (1.0 - wolke);
	float a_ci = ci * 0.28 * (1.0 - wolke * 0.96);
	float a_w = wolke * 0.96;
	float a = a_ci + a_w;
	return vec4((licht * 1.02 * a_ci + wc * a_w) / max(a, 1e-4), a);
}

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
		vec4 w = wolken(d);
		c = mix(c, w.rgb, w.a);
	}
	COLOR = c;
}
