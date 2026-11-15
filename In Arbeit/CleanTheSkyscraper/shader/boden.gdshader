shader_type spatial;

// Boden: Platz um den Turm (Steinplatten in Ringen), See-Promenade, Gehwege mit Platten und Bordstein,
// Straßen nur zwischen zwei „guten“ Kreuzungen (wie Welt.kreuzung_ok) – so endet jede Straße an einer Kreuzung.
uniform vec3 sand : source_color = vec3(0.85, 0.71, 0.48);
uniform vec3 gehweg : source_color = vec3(0.80, 0.77, 0.71);
uniform vec3 asphalt : source_color = vec3(0.4, 0.41, 0.43);
uniform vec3 stein_hell : source_color = vec3(0.80, 0.76, 0.69);
uniform vec3 stein_dunkel : source_color = vec3(0.42, 0.43, 0.46);
uniform vec3 gruen : source_color = vec3(0.36, 0.6, 0.3);
uniform float raster = 75.0;
uniform float plaza_r = 100.0;        // Welt.PLATZ_R
uniform float kreuz_platz = 30.0;     // Welt.KREUZ_PLATZ: Kreuzungen erst so weit hinter dem Platzrand
uniform vec2 see_mitte = vec2(0.0);   // Welt.see_mitte() usw. – setzt welt.gd
uniform vec2 see_dir = vec2(1.0, 0.0);
uniform vec2 see_halb = vec2(50.0, 85.0);
uniform float see_rund = 35.0;
uniform float promenade = 16.0;
uniform float kreuz_see = 14.0;       // Welt.KREUZ_SEE
uniform vec4 casino = vec4(1e6);      // x0, z0, x1, z1 (schon vergrößert), keine Kreuzung darin
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
float kreuz_ok(vec2 k) {
	if (length(k) < plaza_r + kreuz_platz) return 0.0;
	if (see_sdf(k) < promenade + kreuz_see) return 0.0;
	if (k.x > casino.x && k.x < casino.z && k.y > casino.y && k.y < casino.w) return 0.0;
	return 1.0;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float d = length(p);
	float aa = max(fwidth(p.x), fwidth(p.y));
	float fern = 1.0 - smoothstep(2.0, 6.0, aa * 30.0);
	// Wüste mit Rippeln und Flecken
	vec3 w = sand * (0.9 + 0.12 * vn(p * 0.01) + 0.05 * vn(p * 0.2));
	w *= 1.0 - 0.04 * sin(p.x * 0.35 + vn(p * 0.02) * 6.0) * (1.0 - smoothstep(50.0, 400.0, aa * 400.0));
	// Stadtfläche mit unregelmäßigem Rand
	float stadt = 1.0 - smoothstep(1350.0, 1950.0, d + (vn(p * 0.004) - 0.5) * 600.0);
	// Gehweg: 0,75-m-Platten mit Fugen
	vec2 gp = p / 0.75;
	vec2 gf = abs(fract(gp) - 0.5);
	float gfuge = (1.0 - sst(0.45, max(gf.x, gf.y), aa / 0.75 * 0.7)) * fern;
	vec3 gw = gehweg * (0.95 + 0.07 * hs(floor(gp)) + 0.04 * vn(p * 0.08));
	gw *= 1.0 - 0.12 * gfuge;
	vec3 c = mix(w, gw, stadt);

	// ---------------- Straßen
	vec2 lin = floor(p / raster) * raster + raster * 0.5;      // nächste Straßenmitte in x und in z
	vec2 q = abs(p - lin);
	float k_lo_z = floor((p.y - raster * 0.5) / raster) * raster + raster * 0.5;
	float k_lo_x = floor((p.x - raster * 0.5) / raster) * raster + raster * 0.5;
	float da_z = kreuz_ok(vec2(lin.x, k_lo_z)) * kreuz_ok(vec2(lin.x, k_lo_z + raster));   // Straße entlang z
	float da_x = kreuz_ok(vec2(k_lo_x, lin.y)) * kreuz_ok(vec2(k_lo_x + raster, lin.y));   // Straße entlang x
	float str_z = (1.0 - sst(6.5, q.x, aa)) * da_z;
	float str_x = (1.0 - sst(6.5, q.y, aa)) * da_x;
	float str = max(str_z, str_x);
	if (q.x < 6.6 && q.y < 6.6) {   // Kreuzungsfläche: da, wenn die Kreuzung gut ist und mindestens ein Arm existiert
		float arm = max(max(kreuz_ok(lin + vec2(raster, 0.0)), kreuz_ok(lin - vec2(raster, 0.0))), max(kreuz_ok(lin + vec2(0.0, raster)), kreuz_ok(lin - vec2(0.0, raster))));
		str = kreuz_ok(lin) * arm;
	}
	str *= stadt;
	bool entlang_z = str_z >= str_x;
	float naechste = entlang_z ? q.x : q.y;
	float zur_kreuzung = entlang_z ? q.y : q.x;
	float laengs = entlang_z ? p.y : p.x;
	float quer = entlang_z ? p.x : p.y;
	// Bordstein + Rinne neben der Fahrbahn
	float bord_da = max((1.0 - sst(7.2, q.x, aa)) * da_z, (1.0 - sst(7.2, q.y, aa)) * da_x) * stadt;
	c = mix(c, vec3(0.86, 0.85, 0.82), bord_da * (1.0 - str));
	c = mix(c, asphalt * (0.94 + 0.08 * vn(p * 0.7)), str);
	// Mittelstreifen mit Rasen + Bordstein in Turmnähe (dort stehen Palmen + Laternen), sonst gestrichelte Linie
	float allee = 1.0 - smoothstep(allee_r - 5.0, allee_r + 5.0, d);
	float mittel = (1.0 - sst(1.5, naechste, aa)) * sst(12.0, zur_kreuzung, aa) * str * allee;
	vec3 rasen = gruen * (0.8 + 0.3 * vn(p * 0.4));
	c = mix(c, mix(vec3(0.78, 0.76, 0.72), rasen, 1.0 - sst(1.15, naechste, aa)), mittel);
	float linie = (1.0 - sst(0.15, naechste, aa)) * step(0.5, fract(laengs / 6.0)) * str * (1.0 - allee) * sst(12.0, zur_kreuzung, aa);
	c = mix(c, vec3(0.95), linie * fern);
	// Fahrbahnränder + Zebrastreifen vor den Kreuzungen
	float randlinie = (1.0 - sst(0.12, abs(naechste - 5.8), aa)) * str * sst(7.0, zur_kreuzung, aa);
	c = mix(c, vec3(0.92), randlinie * fern);
	float zebra = sst(7.5, zur_kreuzung, aa) * (1.0 - sst(11.0, zur_kreuzung, aa)) * step(0.5, fract(quer / 1.2)) * str * (1.0 - sst(5.5, naechste, aa));
	c = mix(c, vec3(0.93), zebra * fern * (1.0 - smoothstep(700.0, 900.0, d)));

	// ---------------- Platz + See-Promenade: polierte Steinplatten in Ringen um den Turm
	float see_k = 1.0 - sst(promenade, see_sdf(p), 0.5);
	float plaza_k = max(1.0 - smoothstep(plaza_r - 1.0, plaza_r + 1.0, d), see_k);
	float ringw = 1.6;
	float ri = floor(d / ringw);
	float bogen = atan(p.y, p.x) * d + hs(vec2(ri, 3.1)) * 3.0;
	float tl = 2.4;
	float ti = floor(bogen / tl);
	float jr = min(fract(d / ringw), 1.0 - fract(d / ringw)) * ringw;
	float jt = min(fract(bogen / tl), 1.0 - fract(bogen / tl)) * tl;
	float pfuge = (1.0 - sst(0.035, min(jr, jt), aa * 0.7)) * fern;
	float band = step(mod(ri, 12.0), 0.5);                      // dunkles Granitband alle 12 Ringe
	float platte = hs(vec2(ri, ti));
	vec3 pl = stein_hell * (0.88 + 0.16 * platte + 0.06 * vn(p * 0.6));
	pl = mix(pl, pl * vec3(1.03, 0.97, 0.9), step(0.7, platte));   // ein paar wärmere Platten
	pl = mix(pl, stein_dunkel * (0.9 + 0.15 * vn(p * 0.9)), band);
	pl *= 1.0 - 0.17 * pfuge;
	// Grünring mit Blumenbeeten (dort stehen die Palmen)
	float ring = sst(84.0, d, 0.6) * (1.0 - sst(96.0, d, 0.6));
	// Blumenbeete: weiche, längliche Flecken im Rasen, Blüten als feines Rauschen
	float beet = sst(0.55, sin(atan(p.y, p.x) * 30.0) * 0.5 + 0.5 + (vn(p * 0.25) - 0.5) * 0.4, 0.06) * (1.0 - sst(3.5, abs(d - 90.0), 0.8));
	// einzelne runde Blüten in kleinen Zellen (0,4 m), Farbe je Zelle
	vec2 zelle = floor(p * 2.5);
	vec2 mitte_b = (zelle + 0.25 + 0.5 * vec2(hs(zelle), hs(zelle + 7.7))) / 2.5;
	float hat = step(0.45, hs(zelle + 3.3));
	float punkt = (1.0 - sst(0.08, length(p - mitte_b), aa * 0.7)) * hat;
	float wahl = hs(zelle + 1.9);
	vec3 bluete = wahl < 0.33 ? vec3(0.86, 0.2, 0.32) : (wahl < 0.66 ? vec3(0.97, 0.82, 0.25) : vec3(0.95, 0.95, 0.97));
	vec3 erde = vec3(0.32, 0.4, 0.2) * (0.8 + 0.3 * vn(p * 3.0));
	vec3 blumen = mix(rasen, mix(erde, bluete, punkt * fern), beet);
	float rand_ring = (1.0 - sst(0.25, abs(d - 84.0), aa)) + (1.0 - sst(0.25, abs(d - 96.0), aa));
	pl = mix(pl, blumen, ring * (1.0 - see_k));
	pl = mix(pl, vec3(0.86, 0.85, 0.82), clamp(rand_ring, 0.0, 1.0) * (1.0 - see_k));
	c = mix(c, pl, plaza_k);
	ALBEDO = c;
	ROUGHNESS = mix(0.92, 0.6, plaza_k * (1.0 - ring));
	SPECULAR = mix(0.4, 0.6, plaza_k);
}
