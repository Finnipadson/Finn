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
uniform vec4 sperren[5];              // Casino + Läden: x0, z0, x1, z1 (schon vergrößert), keine Kreuzung darin (Welt.gebaeude)
uniform float allee_r = 540.0;        // bis hier Mittelstreifen mit Palmen (StadtDetails.ALLEE_BIS)
// Küste (Kueste.*): Strandpromenade westlich von prom_x bis zur Ufermauer ufer_x, Palmen-Boulevard um z = boul_z
uniform float ufer_x = -606.0;
uniform float prom_x = -572.0;
uniform float boul_z = -112.5;
uniform float boul_halb = 22.0;
uniform float boul_x0 = -150.0;

varying vec3 wp;

float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y);
}
float sst(float e, float x, float w) { return smoothstep(e - w, e + w, x); }
// Gegen Flimmern: wie viel eines Bildpunkts (Breite aa) liegt im Band |x| < hb? Dünne Linien werden in der Ferne
// automatisch blasser statt als harte, springende Pixel zu erscheinen.
float band_k(float x, float hb, float aa) {
	aa = max(aa, 1e-4);
	return clamp((min(x + aa * 0.5, hb) - max(x - aa * 0.5, -hb)) / aa, 0.0, 1.0);
}
// periodische Streifen: Anteil des Bildpunkts (Breite w, in Perioden) in [0, b) jeder Periode
float str_int(float x, float b) { return floor(x) * b + min(fract(x), b); }
float streifen(float x, float b, float w) {
	w = max(w, 1e-4);
	return clamp((str_int(x + w * 0.5, b) - str_int(x - w * 0.5, b)) / w, 0.0, 1.0);
}
// Fugen eines Rasters (Abstand zur nächsten Fuge = Band um ganze Zahlen), x in Zellen
float fuge(float x, float hb, float w) { return streifen(x + hb, hb * 2.0, w); }
float see_sdf(vec2 p) {
	vec2 rel = p - see_mitte;
	vec2 l = vec2(dot(rel, see_dir), dot(rel, vec2(-see_dir.y, see_dir.x)));
	vec2 q = abs(l) - (see_halb - vec2(see_rund));
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - see_rund;
}
float kreuz_ok(vec2 k) {
	if (length(k) < plaza_r + kreuz_platz) return 0.0;
	if (see_sdf(k) < promenade + kreuz_see) return 0.0;
	if (k.x < prom_x + 2.0) return 0.0;
	if (abs(k.y - boul_z) < 1.0 && k.x < boul_x0) return 0.0;
	for (int i = 0; i < 5; i++) {
		vec4 r = sperren[i];
		if (k.x > r.x && k.x < r.z && k.y > r.y && k.y < r.w) return 0.0;
	}
	return 1.0;
}


// ---------------- Leere Grundstücke (Grundstuecke.gd, 19.11.2026): Bodenbelag je Nutzung. l = Ort im Grundstück
// (schon gedreht, |l| <= 28), vr = Variante (0–3), c = Boden darunter. Alle Linien über band_k gefiltert (kein Flimmern).
uniform sampler2D felder : filter_nearest, hint_default_black;   // je Feld: R = Typ, G = Drehung, B = Variante × 60
vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }   // Farbwerte wie Hex/sRGB angeben (die Uniforms tun das per source_color)
// Blumenbeet wie am Platz: einzelne Blüten in 0,4-m-Zellen, in der Ferne Mischfarbe
vec3 blumen_feld(vec2 p, float aa, float nah04, vec3 rasen) {
	vec2 zelle = floor(p * 2.5);
	vec2 mb = (zelle + 0.25 + 0.5 * vec2(hs(zelle), hs(zelle + 7.7))) / 2.5;
	float punkt = (1.0 - sst(0.08, length(p - mb), aa * 0.7)) * step(0.45, hs(zelle + 3.3));
	float wahl = hs(zelle + 1.9);
	vec3 bluete = wahl < 0.33 ? vec3(0.86, 0.2, 0.32) : (wahl < 0.66 ? vec3(0.97, 0.82, 0.25) : vec3(0.95, 0.95, 0.97));
	vec3 erde = vec3(0.32, 0.4, 0.2) * (0.8 + 0.3 * mix(0.5, vn(p * 3.0), nah04));
	return mix(mix(erde, bluete, punkt), mix(erde, vec3(0.93, 0.66, 0.51), 0.07), 1.0 - nah04);
}
vec3 grundstueck(int typ, int vr, vec2 l, vec2 p, float aa, float nah, vec3 c) {
	float rand_d = 28.0 - max(abs(l.x), abs(l.y));       // Abstand zum Grundstücksrand (innen positiv)
	vec3 kante = vec3(0.86, 0.85, 0.82);
	float rk = band_k(rand_d - 0.2, 0.2, aa);              // 0,4-m-Bordstein ringsum
	vec3 rasen = gruen * (0.82 + 0.28 * mix(0.5, vn(p * 0.4), nah) + 0.06 * vn(p * 0.05));
	vec3 kies = lin(vec3(0.84, 0.8, 0.72)) * (0.95 + 0.06 * mix(0.5, vn(p * 2.0), nah));
	vec3 asph = asphalt * (1.04 + 0.07 * mix(0.5, vn(p * 0.7), nah));
	float nah04 = 1.0 - smoothstep(0.04, 0.15, aa);
	vec3 g = c;
	if (typ == 1) {   // Parkplatz: 0 = Reihen, 1 = Schrägparker 60°, 2 = Reihen mit Baum-Inseln
		g = asph * (1.0 - 0.07 * smoothstep(0.6, 0.85, vn(p * 0.4 + 17.0)));   // Ölflecken
		float reihe = max(max(band_k(l.y + 25.0, 2.5, aa), band_k(l.y + 11.0, 5.0, aa)), max(band_k(l.y - 5.5, 5.0, aa), band_k(l.y - 19.5, 2.5, aa)));
		float in_x;
		float strich;
		if (vr == 1) {
			in_x = band_k(l.x + 3.5, 22.5, aa);
			float rc = l.y < -20.0 ? -25.0 : (l.y < -11.0 ? -13.5 : (l.y < -2.0 ? -8.5 : (l.y < 5.5 ? 3.0 : (l.y < 14.0 ? 8.0 : 19.5))));
			float sx = (l.x + 26.0 - (l.y - rc) * 0.5774) / 3.0;
			strich = band_k((fract(sx + 0.5) - 0.5) * 2.598, 0.06, aa);
		} else {
			in_x = band_k(l.x + 3.9, 22.16, aa);
			strich = band_k((fract((l.x + 26.0) / 2.6 + 0.5) - 0.5) * 2.6, 0.06, aa);
		}
		float mitte = band_k(l.y + 11.0, 0.06, aa) + band_k(l.y - 5.5, 0.06, aa);
		g = mix(g, vec3(0.93), clamp(strich * reihe + mitte, 0.0, 1.0) * in_x * 0.9);
		if (vr == 2) {   // jeder 6. Stellplatz ist eine Insel mit Baum
			float k = floor((l.x + 26.0) / 2.6);
			float lx = fract((l.x + 26.0) / 2.6) * 2.6;
			float ist = step(4.5, mod(k, 6.0)) * reihe * in_x;
			g = mix(g, kante, ist);
			g = mix(g, rasen, ist * sst(0.3, min(lx, 2.6 - lx), aa));
		}
		float gs = band_k(l.y - 25.2, 2.6, aa) * band_k(l.x + 1.0, 25.0, aa);
		g = mix(g, rasen, gs);
		g = mix(g, kante, band_k(l.y - 22.45, 0.15, aa) * band_k(l.x + 1.0, 25.15, aa));
		rk *= 1.0 - band_k(l.y + 2.75, 3.25, aa) * step(0.0, l.x);
	} else if (typ == 2) {   // Park: 0 = Wegekreuz, 1 = Diagonalen, 2 = Blumenpark mit Ringweg, 3 = Picknickwiese
		g = rasen;
		float weg = 0.0;
		if (vr == 0 || vr == 1) {
			weg = vr == 0 ? max(band_k(l.x, 1.3, aa), band_k(l.y, 1.3, aa))
				: max(band_k((l.x - l.y) * 0.7071, 1.3, aa), band_k((l.x + l.y) * 0.7071, 1.3, aa));
			weg = max(weg, 1.0 - sst(7.0, length(l), aa));
			weg = max(weg, band_k(rand_d - 2.6, 1.1, aa));
		} else if (vr == 2) {
			float r = length(l);
			float beet = (1.0 - sst(12.6, r, aa)) * sst(7.6, r, aa);
			g = mix(g, blumen_feld(p, aa, nah04, rasen), beet);
			weg = max(1.0 - sst(7.0, r, aa), band_k(r - 14.0, 1.3, aa));
			weg = max(weg, max(band_k((l.x - l.y) * 0.7071, 1.2, aa), band_k((l.x + l.y) * 0.7071, 1.2, aa)) * (1.0 - sst(14.0, r, aa)));
			weg = max(weg, max(band_k(l.x, 1.3, aa) * sst(14.0, abs(l.y), aa), band_k(l.y, 1.3, aa) * sst(14.0, abs(l.x), aa)));
			weg = max(weg, band_k(rand_d - 2.6, 1.1, aa));
			g = mix(g, kante, band_k(r - 7.0, 0.15, aa) + band_k(r - 12.75, 0.15, aa) * (1.0 - weg));
		} else {
			weg = band_k(l.y - 6.0 * sin(l.x * 0.12), 1.3, aa);
			weg = max(weg, 1.0 - sst(5.5, length(l - vec2(16.0, -16.0)), aa));
		}
		g = mix(g, kies, weg);
		if (vr == 0 || vr == 1) g = mix(g, kante, band_k(length(l) - 7.0, 0.15, aa));
	} else if (typ == 7) {   // Park mit Teich: Rasen, Weg um den Teich, Zugänge von zwei Seiten
		g = rasen;
		float r = length(l / vec2(19.5, 16.5));
		float weg = band_k((r - 1.0) * 18.0, 1.3, aa);
		weg = max(weg, band_k(l.y, 1.3, aa) * sst(18.5, abs(l.x), aa));
		weg = max(weg, band_k(l.x, 1.3, aa) * sst(15.5, abs(l.y), aa));
		g = mix(g, kies, weg);
		g = mix(g, rasen * 0.8, 1.0 - sst(1.06, length(l / vec2(14.0, 11.0)), aa / 12.0));   // Ufer unter dem Wasser
	} else if (typ == 3) {   // Baustelle: festgefahrene Erde, Reifenspuren, Schotter vor dem Tor
		g = mix(lin(vec3(0.66, 0.56, 0.42)), sand * 0.92, vn(p * 0.08)) * (0.92 + 0.1 * mix(0.5, vn(p * 1.3), nah));
		float sp = l.y - 9.0 - 4.0 * sin(l.x * 0.11);
		g *= 1.0 - 0.18 * band_k(abs(sp) - 0.9, 0.25, aa);
		g = mix(g, lin(vec3(0.66, 0.65, 0.62)) * (0.9 + 0.15 * mix(0.5, hs(floor(p * 3.0)), nah)), band_k(l.y, 5.0, aa) * sst(17.0, l.x, aa));
		rk *= 0.6;
	} else if (typ == 4) {   // Sandbrache: Sand, trockene Grasflecken, Reifenspuren
		g = mix(sand, gehweg, 0.3) * (0.95 + 0.08 * vn(p * 0.15) + 0.04 * mix(0.5, vn(p * 1.5), nah));
		g = mix(g, lin(vec3(0.66, 0.64, 0.42)) * (0.9 + 0.2 * mix(0.5, vn(p * 0.9), nah)), smoothstep(0.58, 0.78, vn(p * 0.12 + 40.0)) * 0.85);
		float sp = l.x + 6.0 - 5.0 * sin(l.y * 0.09 + 1.0);
		g *= 1.0 - 0.1 * band_k(abs(sp) - 0.9, 0.25, aa);
	} else if (typ == 5) {   // Sportplatz: 0 = 2 Basketballfelder, 1 = 2 Tennisplätze (Sand), 2 = Kleinfeld-Fußball
		g = lin(vec3(0.42, 0.56, 0.47)) * (0.95 + 0.06 * mix(0.5, vn(p * 0.6), nah));
		float lin_w = 0.0;
		if (vr == 0) {
			vec2 q = vec2(l.x - sign(l.x) * 9.0, l.y);
			float feld = (1.0 - sst(7.0, abs(q.x), aa)) * (1.0 - sst(13.0, abs(q.y), aa));
			g = mix(g, lin(vec3(0.33, 0.52, 0.7)) * (0.96 + 0.05 * mix(0.5, vn(p * 0.8), nah)), feld);
			lin_w = band_k(max(abs(q.x) - 7.0, abs(q.y) - 13.0), 0.05, aa);
			lin_w = max(lin_w, band_k(q.y, 0.05, aa) * feld);
			lin_w = max(lin_w, band_k(length(q) - 1.8, 0.05, aa));
			lin_w = max(lin_w, band_k(max(abs(q.x) - 2.45, abs(abs(q.y) - 10.1) - 2.9), 0.05, aa));
			lin_w = max(lin_w, band_k(length(vec2(q.x, abs(q.y) - 11.4)) - 6.6, 0.05, aa) * (1.0 - sst(11.4, abs(q.y), aa)));
			lin_w = max(lin_w, band_k(abs(q.x) - 6.6, 0.05, aa) * sst(11.4, abs(q.y), aa) * feld);
		} else if (vr == 1) {
			g = lin(vec3(0.27, 0.42, 0.33)) * (0.95 + 0.06 * mix(0.5, vn(p * 0.6), nah));
			vec2 q = vec2(l.x - sign(l.x) * 7.0, l.y);
			float feld = (1.0 - sst(6.4, abs(q.x), aa)) * (1.0 - sst(13.6, abs(q.y), aa));
			g = mix(g, lin(vec3(0.74, 0.42, 0.27)) * (0.93 + 0.1 * mix(0.5, vn(p * 1.5), nah)), feld);
			float innen = (1.0 - sst(11.885, abs(q.y), aa));
			lin_w = band_k(max(abs(q.x) - 5.485, abs(q.y) - 11.885), 0.05, aa);
			lin_w = max(lin_w, band_k(abs(q.x) - 4.115, 0.05, aa) * innen);
			lin_w = max(lin_w, band_k(abs(q.y) - 6.4, 0.05, aa) * (1.0 - sst(4.115, abs(q.x), aa)));
			lin_w = max(lin_w, band_k(q.x, 0.05, aa) * (1.0 - sst(6.4, abs(q.y), aa)));
		} else {
			float feld = (1.0 - sst(15.0, abs(l.x), aa)) * (1.0 - sst(23.0, abs(l.y), aa));
			vec3 rasen_k = lin(vec3(0.36, 0.62, 0.3)) * (0.95 + 0.07 * streifen(l.y / 5.0, 0.5, aa / 5.0));
			g = mix(g, rasen_k, feld);
			lin_w = band_k(max(abs(l.x) - 15.0, abs(l.y) - 23.0), 0.06, aa);
			lin_w = max(lin_w, band_k(l.y, 0.06, aa) * feld);
			lin_w = max(lin_w, band_k(length(l) - 4.5, 0.06, aa));
			lin_w = max(lin_w, band_k(max(abs(l.x) - 8.0, abs(abs(l.y) - 20.0) - 3.0), 0.06, aa));
		}
		g = mix(g, vec3(0.94), lin_w);
	} else if (typ == 6) {   // Riesenrad: helle 1,5-m-Steinplatten, Rasenbeete in den Ecken
		vec2 kp = l / 1.5;
		float kf = max(fuge(kp.x, 0.025, aa / 1.5), fuge(kp.y, 0.025, aa / 1.5));
		g = stein_hell * (0.9 + 0.12 * mix(0.5, hs(floor(kp) + 5.0), nah)) * (1.0 - 0.14 * kf);
		float beet = 1.0 - sst(6.5, length(abs(l) - vec2(25.0)), aa);
		g = mix(g, rasen, beet);
		g = mix(g, kante, band_k(length(abs(l) - vec2(25.0)) - 6.5, 0.15, aa));
		g = mix(g, stein_dunkel * 0.95, band_k(l.y, 0.5, aa) * band_k(l.x, 14.0, aa));   // Granitband unter dem Rad
	} else if (typ == 8) {   // Foodtruck-Markt: warme 1-m-Platten, dunkler Rand
		vec2 kp = l;
		float kf = max(fuge(kp.x, 0.03, aa), fuge(kp.y, 0.03, aa));
		vec3 warm = lin(vec3(0.86, 0.76, 0.62));
		g = mix(stein_hell, warm, 0.55 * mix(0.5, hs(floor(kp) + 9.0), nah)) * (1.0 - 0.15 * kf);
		g = mix(g, stein_dunkel, band_k(rand_d - 2.0, 0.6, aa));
	} else if (typ == 9) {   // Tankstelle: Asphalt, Betonfläche unter dem Dach, Gehweg vor dem Shop, Grünstreifen vorn
		g = asph;
		float pad = (1.0 - sst(15.0, abs(l.x), aa)) * (1.0 - sst(9.0, abs(l.y), aa));
		vec2 kp = l / 4.0;
		vec3 beton = lin(vec3(0.74, 0.74, 0.72)) * (0.95 + 0.05 * mix(0.5, hs(floor(kp)), nah)) * (1.0 - 0.15 * max(fuge(kp.x, 0.01, aa / 4.0), fuge(kp.y, 0.01, aa / 4.0)));
		g = mix(g, beton, pad);
		g = mix(g, gehweg, (1.0 - sst(-15.0, l.y, aa)) * (1.0 - sst(14.0, abs(l.x), aa)) * sst(-27.0, l.y, aa));
		float ein = band_k(abs(l.x) - 16.0, 5.5, aa);
		g = mix(g, rasen, sst(23.5, l.y, aa) * (1.0 - ein));
		rk *= 1.0 - ein * sst(23.0, l.y, aa);
	} else if (typ == 10) {   // Parkhaus: Asphalt, Einfahrt vorn
		g = asph;
		rk *= 1.0 - band_k(l.x, 4.0, aa) * sst(20.0, l.y, aa);
	} else if (typ == 11) {   // Spielplatz: Rasen, Kiesweg ringsum, Sand und roter Fallschutz unter den Geräten
		g = rasen;
		g = mix(g, kies, band_k(rand_d - 2.6, 1.1, aa));
		vec3 sandf = mix(sand, gehweg, 0.3) * (0.95 + 0.06 * mix(0.5, vn(p * 1.5), nah));
		vec3 gummi = lin(vec3(0.71, 0.4, 0.3)) * (0.95 + 0.05 * mix(0.5, vn(p * 2.0), nah));
		vec3 gummi_b = lin(vec3(0.35, 0.55, 0.75)) * (0.95 + 0.05 * mix(0.5, vn(p * 2.0), nah));
		g = mix(g, sandf, (1.0 - sst(7.0, abs(l.x + 11.0), aa)) * (1.0 - sst(6.0, abs(l.y + 14.0), aa)));
		g = mix(g, gummi, 1.0 - sst(7.0, length(l - vec2(11.0, -12.0)), aa));
		g = mix(g, sandf, (1.0 - sst(4.5, abs(l.x + 11.0), aa)) * (1.0 - sst(4.5, abs(l.y - 11.0), aa)));
		g = mix(g, gummi, (1.0 - sst(5.0, abs(l.x - 12.0), aa)) * (1.0 - sst(3.0, abs(l.y - 12.0), aa)));
		g = mix(g, gummi_b, 1.0 - sst(4.2, length(l - vec2(0.0, 1.0)), aa));
	}
	g = mix(g, kante, rk);
	return mix(c, g, sst(0.0, rand_d, aa));
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float d = length(p);
	float aa = max(fwidth(p.x), fwidth(p.y)) * 1.25;
	// Zufall pro Platte / feines Rauschen nur, solange es mehrere Bildpunkte groß ist – sonst Mittelwert
	float nah_075 = 1.0 - smoothstep(0.08, 0.3, aa);     // 0,75-m-Platten
	float nah_2 = 1.0 - smoothstep(0.2, 0.8, aa);        // ~2-m-Platten / Rauschen
	float nah_04 = 1.0 - smoothstep(0.04, 0.15, aa);     // 0,4-m-Blumenzellen
	// Wüste mit Rippeln und Flecken
	vec3 w = sand * (0.9 + 0.12 * vn(p * 0.01) + 0.05 * vn(p * 0.2));
	w *= 1.0 - 0.04 * sin(p.x * 0.35 + vn(p * 0.02) * 6.0) * (1.0 - smoothstep(50.0, 400.0, aa * 400.0));
	// Stadtfläche mit unregelmäßigem Rand
	float stadt = 1.0 - smoothstep(1350.0, 1950.0, d + (vn(p * 0.004) - 0.5) * 600.0);
	// Gehweg: 0,75-m-Platten mit Fugen
	vec2 gp = p / 0.75;
	float gw_aa = aa / 0.75;
	float gfuge = max(fuge(gp.x, 0.05, gw_aa), fuge(gp.y, 0.05, gw_aa));
	vec3 gw = gehweg * (0.95 + 0.07 * mix(0.5, hs(floor(gp)), nah_075) + 0.04 * vn(p * 0.08));
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
	c = mix(c, asphalt * (0.94 + 0.08 * mix(0.5, vn(p * 0.7), nah_2)), str);
	// Mittelstreifen mit Rasen + Bordstein in Turmnähe (dort stehen Palmen + Laternen), sonst gestrichelte Linie
	// Mittelstreifen je ganzem Straßenstück (Mitte des Stücks näher als allee_r) – endet so immer an einer Kreuzung
	vec2 stueck_mitte = entlang_z ? vec2(lin.x, k_lo_z + raster * 0.5) : vec2(k_lo_x + raster * 0.5, lin.y);
	float allee = step(length(stueck_mitte), allee_r);
	float mittel = (1.0 - sst(1.5, naechste, aa)) * sst(12.0, zur_kreuzung, aa) * str * allee;
	vec3 rasen = gruen * (0.8 + 0.3 * mix(0.5, vn(p * 0.4), nah_2));
	c = mix(c, mix(vec3(0.78, 0.76, 0.72), rasen, 1.0 - sst(1.15, naechste, aa)), mittel);
	float linie = band_k(naechste, 0.15, aa) * streifen(laengs / 6.0 + 0.5, 0.5, aa / 6.0) * str * (1.0 - allee) * sst(12.0, zur_kreuzung, aa);
	c = mix(c, vec3(0.95), linie);
	// Fahrbahnränder + Zebrastreifen vor den Kreuzungen
	float randlinie = band_k(naechste - 5.8, 0.12, aa) * str * sst(7.0, zur_kreuzung, aa);
	c = mix(c, vec3(0.92), randlinie);
	float zebra = sst(7.5, zur_kreuzung, aa) * (1.0 - sst(11.0, zur_kreuzung, aa)) * streifen(quer / 1.2 + 0.5, 0.5, aa / 1.2) * str * (1.0 - sst(5.5, naechste, aa));
	c = mix(c, vec3(0.93), zebra * (1.0 - smoothstep(700.0, 900.0, d)));

	// ---------------- Leere Grundstücke (Feld-Mitten bei k·raster, Datentextur 41 × 41 ab −1500 m)
	vec2 fz = floor(p / raster + 0.5);
	ivec2 fij = ivec2(fz) + ivec2(20);
	vec2 fl = p - fz * raster;
	if (fij.x >= 0 && fij.y >= 0 && fij.x < 41 && fij.y < 41 && max(abs(fl.x), abs(fl.y)) < 28.5) {
		vec4 fd = texelFetch(felder, fij, 0);
		int typ = int(fd.r * 255.0 + 0.5);
		if (typ > 0) {
			int dreh = int(fd.g * 255.0 + 0.5);
			vec2 l = fl;
			if (dreh == 1) l = vec2(fl.y, -fl.x);
			else if (dreh == 2) l = -fl;
			else if (dreh == 3) l = vec2(-fl.y, fl.x);
			c = grundstueck(typ, int(fd.b * 255.0 / 60.0 + 0.5), l, p, aa, nah_2, c);
		}
	}

	// ---------------- Strandpromenade + Palmen-Boulevard: große helle Platten (1,5 m), dunkle Granitbänder längs,
	// Rasenstreifen für die Palmenreihen (|dz| 8,5–10,5 m), zur Ufermauer hin ein breites dunkles Band
	float dz = abs(p.y - boul_z);
	// Der Boulevard reicht bis unter die See-Promenade (die liegt darüber); sichtbar endet er an deren Rand mit einer
	// klaren Bordsteinkante (sd = Abstand zur See-Promenade)
	float sd = see_sdf(p) - promenade;
	float boul = (1.0 - sst(boul_halb, dz, aa)) * (1.0 - sst(boul_x0, p.x, aa));
	float prom = 1.0 - sst(prom_x + 1.0, p.x, aa);
	float k_kueste = max(boul, prom);
	if (k_kueste > 0.001) {
		vec2 kp = vec2(p.x, p.y) / 1.5;
		float k_aa = aa / 1.5;
		float kf = max(fuge(kp.x, 0.025, k_aa), fuge(kp.y, 0.025, k_aa));
		float kplatte = mix(0.5, hs(floor(kp) + 11.0), nah_2);
		vec3 kst = stein_hell * (0.9 + 0.12 * kplatte + 0.05 * mix(0.5, vn(p * 0.5), nah_2));
		kst *= 1.0 - 0.14 * kf;
		// Granitbänder längs: am Boulevard parallel zur Achse, an der Promenade parallel zur Küste
		float gb = boul > prom ? max(band_k(dz - 6.2, 0.45, aa), band_k(dz - 21.2, 0.5, aa)) * sst(0.5, sd, aa) : max(band_k(p.x - ufer_x - 3.0, 0.6, aa), band_k(p.x - prom_x + 2.0, 0.4, aa));
		kst = mix(kst, stein_dunkel * (0.92 + 0.12 * mix(0.5, vn(p * 0.9), nah_2)), gb);
		vec3 krasen = gruen * (0.8 + 0.3 * mix(0.5, vn(p * 0.4), nah_2));
		// Rasenstreifen endet 1,5 m vor der See-Promenade mit einer Kante quer (wie an der Ufermauer)
		float rs_da = boul * (1.0 - prom) * sst(ufer_x + 8.0, p.x, aa) * sst(1.5, sd, aa);
		float rs = band_k(dz - 9.5, 1.0, aa) * rs_da;
		kst = mix(kst, krasen, rs);
		float rs_kante = clamp(band_k(dz - 8.4, 0.12, aa) + band_k(dz - 10.6, 0.12, aa), 0.0, 1.0) * boul * (1.0 - prom) * sst(ufer_x + 8.0, p.x, aa) * sst(1.38, sd, aa)
			+ band_k(sd - 1.44, 0.12, aa) * band_k(dz - 9.5, 1.22, aa) * boul;
		kst = mix(kst, vec3(0.86, 0.85, 0.82), clamp(rs_kante, 0.0, 1.0));
		// Bordsteinkante am Übergang zur See-Promenade: heller Stein (0,35 m) mit dunkler Fuge davor
		kst = mix(kst, vec3(0.88, 0.87, 0.84), band_k(sd - 0.2, 0.17, aa) * boul * (1.0 - prom));
		kst = mix(kst, stein_dunkel * 0.8, band_k(sd - 0.4, 0.03, aa) * boul * (1.0 - prom));
		c = mix(c, kst, k_kueste);
	}

	// ---------------- Platz + See-Promenade: polierte Steinplatten in Ringen um den Turm
	float see_k = 1.0 - sst(promenade, see_sdf(p), mix(0.5, aa * 0.5, boul));   // am Boulevard scharf (Bordstein)
	float plaza_k = max(1.0 - smoothstep(plaza_r - 1.0, plaza_r + 1.0, d), see_k);
	float ringw = 1.6;
	float ri = floor(d / ringw);
	float bogen = atan(p.y, p.x) * d + hs(vec2(ri, 3.1)) * 3.0;
	float tl = 2.4;
	float ti = floor(bogen / tl);
	// Fugen gefiltert; die Bogen-Richtung hat am Winkelsprung (−x-Achse) eine Naht → dort Breite begrenzen
	float aa_b = min(fwidth(bogen) * 1.25, 4.0);
	float pfuge = max(fuge(d / ringw, 0.035 / ringw, aa / ringw), fuge(bogen / tl, 0.035 / tl, aa_b / tl));
	float band = streifen(d / (ringw * 12.0), 1.0 / 12.0, aa / (ringw * 12.0));   // dunkles Granitband alle 12 Ringe
	float platte = mix(0.5, hs(vec2(ri, ti)), nah_2);
	vec3 pl = stein_hell * (0.88 + 0.16 * platte + 0.06 * mix(0.5, vn(p * 0.6), nah_2));
	pl = mix(pl, pl * vec3(1.03, 0.97, 0.9), mix(0.3, step(0.7, platte), nah_2));   // ein paar wärmere Platten
	pl = mix(pl, stein_dunkel * (0.9 + 0.15 * mix(0.5, vn(p * 0.9), nah_2)), band);
	pl *= 1.0 - 0.17 * pfuge;
	// Grünring mit Blumenbeeten (dort stehen die Palmen)
	float ring = sst(84.0, d, max(0.6, aa)) * (1.0 - sst(96.0, d, max(0.6, aa)));
	// Blumenbeete: weiche, längliche Flecken im Rasen, Blüten als feines Rauschen
	float beet = sst(0.55, sin(atan(p.y, p.x) * 30.0) * 0.5 + 0.5 + (vn(p * 0.25) - 0.5) * 0.4, 0.06) * (1.0 - sst(3.5, abs(d - 90.0), 0.8));
	// einzelne runde Blüten in kleinen Zellen (0,4 m), Farbe je Zelle
	vec2 zelle = floor(p * 2.5);
	vec2 mitte_b = (zelle + 0.25 + 0.5 * vec2(hs(zelle), hs(zelle + 7.7))) / 2.5;
	float hat = step(0.45, hs(zelle + 3.3));
	float punkt = (1.0 - sst(0.08, length(p - mitte_b), aa * 0.7)) * hat;
	float wahl = hs(zelle + 1.9);
	vec3 bluete = wahl < 0.33 ? vec3(0.86, 0.2, 0.32) : (wahl < 0.66 ? vec3(0.97, 0.82, 0.25) : vec3(0.95, 0.95, 0.97));
	vec3 erde = vec3(0.32, 0.4, 0.2) * (0.8 + 0.3 * mix(0.5, vn(p * 3.0), nah_04));
	// in der Ferne: Blüten als gleichmäßige Mischfarbe (ca. 55 % Zellen mit Blüte, Punkt ≈ 13 % der Zelle)
	vec3 bunt_mittel = mix(erde, vec3(0.93, 0.66, 0.51), 0.07);
	vec3 blumen = mix(rasen, mix(mix(erde, bluete, punkt), bunt_mittel, 1.0 - nah_04), beet);
	float rand_ring = band_k(d - 84.0, 0.25, aa) + band_k(d - 96.0, 0.25, aa);
	pl = mix(pl, blumen, ring * (1.0 - see_k));
	pl = mix(pl, vec3(0.86, 0.85, 0.82), clamp(rand_ring, 0.0, 1.0) * (1.0 - see_k));
	c = mix(c, pl, plaza_k);
	ALBEDO = c;
	ROUGHNESS = mix(0.92, 0.6, plaza_k * (1.0 - ring));
	SPECULAR = mix(0.4, 0.6, plaza_k);
}
