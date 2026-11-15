shader_type spatial;

// Boden: Platz um den Turm mit Park, Stadt mit Straßenraster, weicher Übergang in die Wüste
uniform vec3 sand : source_color = vec3(0.85, 0.71, 0.48);
uniform vec3 stadtboden : source_color = vec3(0.76, 0.73, 0.68);
uniform vec3 asphalt : source_color = vec3(0.4, 0.41, 0.43);
uniform vec3 plaza : source_color = vec3(0.88, 0.85, 0.79);
uniform vec3 gruen : source_color = vec3(0.36, 0.6, 0.3);
uniform float raster = 75.0;
uniform float plaza_r = 100.0;   // muss zu Welt.PLATZ_R passen
uniform vec2 see_mitte = vec2(0.0);   // Welt.see_mitte() usw. – setzt welt.gd
uniform vec2 see_dir = vec2(1.0, 0.0);
uniform vec2 see_halb = vec2(50.0, 85.0);
uniform float see_rund = 35.0;
uniform float promenade = 16.0;
uniform float allee_r = 540.0;        // bis hier Mittelstreifen mit Palmen (StadtDetails.ALLEE_BIS)

varying vec3 wp;

float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y);
}
float sst(float e, float x, float w) { return smoothstep(e - w, e + w, x); }
float see_sdf(vec2 p) {
	vec2 rel = p - see_mitte;
	vec2 l = vec2(dot(rel, see_dir), dot(rel, vec2(-see_dir.y, see_dir.x)));
	vec2 q = abs(l) - (see_halb - vec2(see_rund));
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - see_rund;
}

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
	float see_k = 1.0 - sst(promenade, see_sdf(p), 0.5);
	float plaza_k = max(1.0 - smoothstep(plaza_r - 5.0, plaza_r + 5.0, d), see_k);
	float str = (1.0 - sst(6.5, naechste, aa)) * stadt * (1.0 - plaza_k);
	c = mix(c, asphalt * (0.94 + 0.08 * vn(p * 0.7)), str);
	float laengs = (q.x < q.y) ? p.y : p.x;
	float quer = (q.x < q.y) ? p.x : p.y;
	float zur_kreuzung = max(q.x, q.y);
	float fern = 1.0 - smoothstep(2.0, 6.0, aa * 30.0);
	// Mittelstreifen mit Rasen + Bordstein in Turmnähe (dort stehen Palmen + Laternen), sonst gestrichelte Linie
	float allee = 1.0 - smoothstep(allee_r - 5.0, allee_r + 5.0, d);
	float mittel = (1.0 - sst(1.5, naechste, aa)) * sst(9.0, zur_kreuzung, aa) * str * allee;
	vec3 rasen = gruen * (0.8 + 0.3 * vn(p * 0.4));
	c = mix(c, mix(vec3(0.78, 0.76, 0.72), rasen, 1.0 - sst(1.15, naechste, aa)), mittel);
	float linie = (1.0 - sst(0.15, naechste, aa)) * step(0.5, fract(laengs / 6.0)) * str * (1.0 - allee);
	c = mix(c, vec3(0.95), linie * fern);
	// Fahrbahnränder + Zebrastreifen vor den Kreuzungen
	float randlinie = (1.0 - sst(0.12, abs(naechste - 5.8), aa)) * str * sst(7.0, zur_kreuzung, aa);
	c = mix(c, vec3(0.92), randlinie * fern);
	float zebra = sst(7.5, zur_kreuzung, aa) * (1.0 - sst(11.0, zur_kreuzung, aa)) * step(0.5, fract(quer / 1.2)) * str * (1.0 - sst(5.5, naechste, aa));
	c = mix(c, vec3(0.93), zebra * fern * (1.0 - smoothstep(700.0, 900.0, d)));
	// Platz um den Turm: helle Platten, Grünring
	vec2 platte = abs(fract(p / 3.0) - 0.5);
	vec3 pl = plaza * (0.97 + 0.04 * hs(floor(p / 3.0))) * (1.0 - 0.08 * (1.0 - sst(0.47, max(platte.x, platte.y), aa / 3.0)));
	float ring = sst(84.0, d, 2.0) * (1.0 - sst(96.0, d, 2.0));
	pl = mix(pl, gruen * (0.85 + 0.25 * vn(p * 0.3)), ring * step(0.3, vn(p * 0.05 + 3.0)));
	c = mix(c, pl, plaza_k);
	ALBEDO = c;
	ROUGHNESS = 0.92;
}
