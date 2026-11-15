shader_type spatial;

// Boden: Platz um den Turm mit Park, Stadt mit Straßenraster, weicher Übergang in die Wüste
uniform vec3 sand : source_color = vec3(0.85, 0.71, 0.48);
uniform vec3 stadtboden : source_color = vec3(0.76, 0.73, 0.68);
uniform vec3 asphalt : source_color = vec3(0.4, 0.41, 0.43);
uniform vec3 plaza : source_color = vec3(0.88, 0.85, 0.79);
uniform vec3 gruen : source_color = vec3(0.36, 0.6, 0.3);
uniform float raster = 75.0;
uniform float plaza_r = 125.0;   // muss zu Welt.PLATZ_R passen

varying vec3 wp;

float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y);
}
float sst(float e, float x, float w) { return smoothstep(e - w, e + w, x); }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float d = length(p);
	float aa = max(fwidth(p.x), fwidth(p.y));
	// Wüste mit Rippeln und Flecken
	vec3 w = sand * (0.9 + 0.12 * vn(p * 0.01) + 0.05 * vn(p * 0.2));
	w *= 1.0 - 0.04 * sin(p.x * 0.35 + vn(p * 0.02) * 6.0) * (1.0 - smoothstep(50.0, 400.0, aa * 400.0));
	// Stadtfläche mit unregelmäßigem Rand
	float stadt = 1.0 - smoothstep(1350.0, 1950.0, d + (vn(p * 0.004) - 0.5) * 600.0);
	vec3 c = mix(w, stadtboden * (0.95 + 0.08 * vn(p * 0.05)), stadt);
	// Straßenraster zwischen den Häuserblöcken (Blöcke liegen auf Vielfachen von 75 m)
	vec2 q = abs(fract(p / raster) - 0.5) * raster;
	float naechste = min(q.x, q.y);
	float plaza_k = 1.0 - smoothstep(plaza_r - 5.0, plaza_r + 5.0, d);
	float str = (1.0 - sst(6.5, naechste, aa)) * stadt * (1.0 - plaza_k);
	c = mix(c, asphalt, str);
	// gestrichelte Mittellinie
	float laengs = (q.x < q.y) ? p.y : p.x;
	float linie = (1.0 - sst(0.15, naechste, aa)) * step(0.5, fract(laengs / 6.0)) * str;
	c = mix(c, vec3(0.95), linie * (1.0 - smoothstep(2.0, 6.0, aa * 30.0)));
	// Platz um den Turm: helle Platten, Grünring
	vec2 platte = abs(fract(p / 3.0) - 0.5);
	vec3 pl = plaza * (0.97 + 0.04 * hs(floor(p / 3.0))) * (1.0 - 0.08 * (1.0 - sst(0.47, max(platte.x, platte.y), aa / 3.0)));
	float ring = sst(70.0, d, 2.0) * (1.0 - sst(88.0, d, 2.0));
	pl = mix(pl, gruen * (0.85 + 0.25 * vn(p * 0.3)), ring * step(0.3, vn(p * 0.05 + 3.0)));
	c = mix(c, pl, plaza_k);
	ALBEDO = c;
	ROUGHNESS = 0.92;
}
