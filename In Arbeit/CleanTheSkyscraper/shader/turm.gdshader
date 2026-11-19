shader_type spatial;
render_mode cull_disabled;

// Glasfassade des Hauptturms mit „Interior Mapping“: hinter jedem Fenster wird ein Raum vorgetäuscht.
// UV in Metern (x = Weg entlang der Fassade, y = Höhe). TANGENT zeigt in Richtung wachsender UV.x.
uniform vec3 glas_tint : source_color = vec3(0.30, 0.45, 0.58);
uniform vec3 paneel : source_color = vec3(0.55, 0.60, 0.66);
uniform vec3 schmutz_farbe : source_color = vec3(0.55, 0.50, 0.42);
uniform vec3 wand_a : source_color = vec3(0.86, 0.83, 0.77);
uniform vec3 wand_b : source_color = vec3(0.74, 0.79, 0.84);
uniform float fenster_breite = 1.5;
uniform float stock = 4.2;
uniform float band_anteil = 0.22;
uniform float dreckig = 0.45;
uniform float raum_fenster = 3.0;
uniform float raum_tiefe = 6.0;
uniform float innen_hell = 0.55;
uniform float spiegel = 0.0;
uniform float strahler_n = 0.0;       // Bodenstrahler am Turmfuß (Anzahl, 0 = aus)          // 0 = wie früher, 1 = sauberes Glas verspiegelt (Grafik 19.11.2026, mit ReflectionProbes)
global uniform float nacht;          // Tageszeit (Phase 5): Räume leuchten nachts heller
// Spielzustand (FensterZustand): Dreck pro Fenster + feine Wisch-Masken
uniform bool mit_zustand = false;
uniform sampler2D zustand : filter_nearest;
uniform sampler2D wisch : filter_linear;
uniform vec2 zustand_px = vec2(1.0, 1.0);
uniform vec2 slots = vec2(16.0, 8.0);
uniform vec2 slot_px = vec2(64.0, 128.0);

// Innenraum (Sky-Lounge): steht die Kamera drin, wird die Fassade in diesem Höhenband (y von, y bis) weggelassen –
// man sieht durch die eigenen Glaswände des Raums nach draußen
uniform vec2 innen_band = vec2(-1.0, -1.0);
varying vec3 wp;
varying vec3 wt;
varying vec3 wn;

float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y);
}


// Bodenstrahler am Turmfuß (19.11.2026): N Strahler in gleichen Winkeln um den Turm, Lichtkegel unten schmal, oben breit,
// nach oben schwächer. In der Ferne (Kegel kleiner als ein paar Bildpunkte) gemittelt – gegen Flimmern.
float strahler_licht(vec3 p, float n) {
	float an = smoothstep(0.25, 0.6, nacht);
	if (an <= 0.0 || n < 1.0 || p.y > 70.0) return 0.0;
	float th = atan(p.z, p.x) * n;
	float breit = mix(18.0, 2.5, smoothstep(0.0, 28.0, p.y));
	float kegel = pow(0.5 + 0.5 * cos(th), breit);
	float mittel = 0.25 / sqrt(breit);
	kegel = mix(kegel, mittel, smoothstep(0.08, 0.35, fwidth(th) / 6.2832));
	return an * kegel * exp(-max(p.y, 0.0) / 13.0) * smoothstep(-0.5, 0.6, p.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wt = normalize((MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz);
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// weiche Stufe: statt harter Kante über die Breite eines Bildpunkts überblenden (gegen Flimmern)
float sst(float e, float x, float w) { return smoothstep(e - w, e + w, x); }

// ---------------------------------------------------------------- Szenen hinter dem Glas (2D-Formen, in Metern im Fenster)
float kreis(vec2 p, vec2 c, float r) { return length(p - c) - r; }
float ell(vec2 p, vec2 c, vec2 r) { return (length((p - c) / r) - 1.0) * min(r.x, r.y); }
float kapsel(vec2 p, vec2 a, vec2 b, float r) { vec2 pa = p - a, ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return length(pa - ba * h) - r; }
float kasten(vec2 p, vec2 a, vec2 b) { vec2 c = (a + b) * 0.5; vec2 e = abs(b - a) * 0.5; vec2 q = abs(p - c) - e; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0); }
void male(inout vec4 o, float d, vec3 farbe) { float a = 1.0 - smoothstep(-0.012, 0.012, d); o = vec4(mix(o.rgb, farbe, a), max(o.a, a)); }

const vec3 HAUT = vec3(0.95, 0.75, 0.6);
const vec3 HOSE = vec3(0.2, 0.22, 0.3);

void person(inout vec4 o, vec2 m, vec2 fuss, vec3 hemd, float winken, float huepf, float lauf) {
	vec2 b = fuss + vec2(0.0, huepf);
	float s1 = sin(lauf) * 0.12;
	male(o, kapsel(m, b + vec2(-0.08 + s1, 0.0), b + vec2(-0.07, 0.78), 0.07), HOSE);
	male(o, kapsel(m, b + vec2(0.08 - s1, 0.0), b + vec2(0.07, 0.78), 0.07), HOSE);
	male(o, kapsel(m, b + vec2(0.0, 0.88), b + vec2(0.0, 1.28), 0.17), hemd);
	male(o, kapsel(m, b + vec2(-0.18, 1.3), b + vec2(-0.26 - s1 * 0.5, 0.88), 0.05), hemd);
	vec2 schulter = b + vec2(0.18, 1.3);
	float a = mix(2.6 + s1, 0.5 + 0.5 * sin(TIME * 7.0), winken);
	male(o, kapsel(m, schulter, schulter + vec2(sin(a), cos(a)) * 0.42, 0.05), hemd);
	male(o, kreis(m, schulter + vec2(sin(a), cos(a)) * 0.46, 0.055), HAUT);
	male(o, kreis(m, b + vec2(0.0, 1.55), 0.13), HAUT);
	male(o, ell(m, b + vec2(0.0, 1.63), vec2(0.14, 0.07)), vec3(0.25, 0.15, 0.1));
}

vec4 szene_bild(float typ, vec2 m, vec2 rid) {
	vec4 o = vec4(0.0);
	vec3 bunt = vec3(0.4 + 0.5 * hs(rid + 1.1), 0.3 + 0.5 * hs(rid + 2.2), 0.35 + 0.5 * hs(rid + 3.3));
	if (typ == 1.0) {            // Winkende Person
		person(o, m, vec2(0.75, 0.0), bunt, 1.0, 0.0, 0.0);
	} else if (typ == 2.0) {     // Katze auf der Fensterbank
		vec3 fell = mix(vec3(0.95, 0.55, 0.2), vec3(0.3, 0.3, 0.32), step(0.5, hs(rid + 4.0)));
		male(o, kapsel(m, vec2(0.42, 0.16), vec2(0.28, 0.32 + 0.07 * sin(TIME * 3.0)), 0.035), fell);
		male(o, ell(m, vec2(0.65, 0.2), vec2(0.25, 0.14)), fell);
		male(o, kapsel(m, vec2(0.9, 0.4), vec2(0.88, 0.49), 0.035), fell);
		male(o, kapsel(m, vec2(1.0, 0.4), vec2(1.02, 0.49), 0.035), fell);
		male(o, kreis(m, vec2(0.95, 0.33), 0.11), fell);
		male(o, kreis(m, vec2(0.91, 0.35), 0.017), vec3(0.9, 0.85, 0.2));
		male(o, kreis(m, vec2(0.99, 0.35), 0.017), vec3(0.9, 0.85, 0.2));
	} else if (typ == 3.0) {     // Party
		person(o, m, vec2(0.42, 0.0), vec3(0.9, 0.3, 0.5), 1.0, abs(sin(TIME * 5.0)) * 0.08, 0.0);
		person(o, m, vec2(1.08, 0.0), vec3(0.3, 0.6, 0.95), 0.0, abs(sin(TIME * 5.0 + 1.5)) * 0.08, TIME * 5.0);
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			vec2 bc = vec2(0.3 + fi * 0.45, 2.2 + 0.15 * sin(TIME * 1.5 + fi));
			male(o, kapsel(m, bc, bc - vec2(0.0, 0.55), 0.005), vec3(0.9));
			male(o, kreis(m, bc, 0.16), vec3(fi == 0.0 ? 1.0 : 0.3, fi == 1.0 ? 0.85 : 0.35, fi == 2.0 ? 1.0 : 0.3));
		}
	} else if (typ == 4.0) {     // Büro
		person(o, m, vec2(0.75, 0.35), bunt, 0.0, 0.0, 0.0);
		male(o, kasten(m, vec2(0.1, 0.0), vec2(0.16, 0.74)), vec3(0.3));
		male(o, kasten(m, vec2(1.34, 0.0), vec2(1.4, 0.74)), vec3(0.3));
		male(o, kasten(m, vec2(0.1, 0.72), vec2(1.4, 0.8)), vec3(0.6, 0.45, 0.3));
		male(o, kasten(m, vec2(0.5, 0.84), vec2(1.0, 1.16)), vec3(0.12));
		male(o, kasten(m, vec2(0.53, 0.87), vec2(0.97, 1.13)), vec3(0.45, 0.75, 1.3));
	} else if (typ == 5.0) {     // Fitness
		person(o, m, vec2(0.7, 0.14), vec3(0.95, 0.4, 0.2), 0.0, abs(sin(TIME * 9.0)) * 0.05, TIME * 9.0);
		male(o, kasten(m, vec2(0.15, 0.0), vec2(1.35, 0.14)), vec3(0.15));
		male(o, kapsel(m, vec2(1.3, 0.14), vec2(1.25, 1.05), 0.03), vec3(0.4));
	} else if (typ == 6.0) {     // Geburtstag
		person(o, m, vec2(1.18, 0.0), bunt, 1.0, 0.0, 0.0);
		male(o, kasten(m, vec2(0.15, 0.72), vec2(1.0, 0.78)), vec3(0.95));
		male(o, kasten(m, vec2(0.3, 0.78), vec2(0.85, 1.0)), vec3(1.0, 0.55, 0.7));
		male(o, kasten(m, vec2(0.3, 0.96), vec2(0.85, 1.02)), vec3(1.0));
		for (int i = 0; i < 3; i++) {
			float x = 0.42 + float(i) * 0.15;
			male(o, kasten(m, vec2(x - 0.012, 1.02), vec2(x + 0.012, 1.14)), vec3(0.4, 0.7, 1.0));
			male(o, ell(m, vec2(x, 1.18 + 0.01 * sin(TIME * 20.0 + float(i))), vec2(0.022, 0.038)), vec3(1.6, 1.0, 0.3));
		}
	} else if (typ == 8.0) {     // Dschungel
		for (int i = 0; i < 14; i++) {
			float fi = float(i);
			vec2 lc = vec2(0.15 + hs(vec2(fi, 1.0) + rid) * 1.2, 0.45 + hs(vec2(fi, 2.0) + rid) * 1.9);
			male(o, ell(m, lc, vec2(0.16, 0.09)), mix(vec3(0.15, 0.55, 0.2), vec3(0.4, 0.75, 0.25), hs(vec2(fi, 3.0))));
		}
		male(o, kasten(m, vec2(0.5, 0.0), vec2(1.0, 0.38)), vec3(0.75, 0.4, 0.25));
	} else if (typ == 9.0) {     // Aquarium
		male(o, kasten(m, vec2(0.12, 0.0), vec2(1.38, 0.7)), vec3(0.3, 0.2, 0.15));
		male(o, kasten(m, vec2(0.12, 0.7), vec2(1.38, 1.55)), vec3(0.25, 0.65, 1.1));
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float x = 0.25 + fract(TIME * (0.08 + fi * 0.03) + fi * 0.37) * 1.0;
			male(o, ell(m, vec2(x, 0.9 + fi * 0.2), vec2(0.07, 0.04)), vec3(1.3, 0.55, 0.1));
		}
		male(o, kreis(m, vec2(1.2, 0.8 + fract(TIME * 0.4) * 0.7), 0.02), vec3(1.4));
	} else if (typ == 10.0) {    // Hund
		vec3 fell = vec3(0.55, 0.35, 0.2);
		for (int i = 0; i < 4; i++) {
			float x = 0.5 + float(i) * 0.14;
			male(o, kapsel(m, vec2(x, 0.4), vec2(x, 0.02), 0.04), fell);
		}
		male(o, kapsel(m, vec2(0.42, 0.5), vec2(0.26, 0.72 + 0.1 * sin(TIME * 14.0)), 0.035), fell);
		male(o, ell(m, vec2(0.7, 0.47), vec2(0.3, 0.16)), fell);
		male(o, kreis(m, vec2(1.05, 0.66), 0.14), fell);
		male(o, ell(m, vec2(1.19, 0.61), vec2(0.08, 0.055)), vec3(0.7, 0.5, 0.35));
		male(o, ell(m, vec2(0.99, 0.72), vec2(0.05, 0.1)), vec3(0.35, 0.22, 0.12));
		male(o, kreis(m, vec2(1.26, 0.63), 0.022), vec3(0.08));
		male(o, kreis(m, vec2(1.09, 0.7), 0.018), vec3(0.08));
	}
	return o;
}

// Herz auf dem Glas (Liebesbrief), p in Fenster-Anteilen
float herz(vec2 p) {
	p = (p - vec2(0.5, 0.55)) * vec2(1.0, 2.2) * 3.2;
	p.y = -p.y + 0.35;
	float a = atan(p.x, p.y) / 3.14159;
	float r = length(p);
	float h = abs(a);
	float d = (13.0 * h - 22.0 * h * h + 10.0 * h * h * h) / (6.0 - 5.0 * h);
	return 1.0 - smoothstep(d - 0.05, d + 0.05, r);
}

vec3 raum(vec2 rp, vec2 rid, vec3 r, float aw, float szene, float wl) {
	float W = fenster_breite * raum_fenster;
	float Hr = stock * (1.0 - band_anteil);
	vec3 d = vec3(dot(r, wt), r.y, dot(r, wn));
	vec3 dn = vec3(d.x / W, d.y / Hr, min(d.z, -0.001) / raum_tiefe);
	vec3 pos = vec3(rp, 0.0);
	float tx = ((dn.x > 0.0 ? 1.0 : 0.0) - pos.x) / (abs(dn.x) < 1e-5 ? 1e-5 : dn.x);
	float ty = ((dn.y > 0.0 ? 1.0 : 0.0) - pos.y) / (abs(dn.y) < 1e-5 ? 1e-5 : dn.y);
	float tz = -1.0 / dn.z;
	float t = min(min(tx, ty), tz);
	vec3 hit = pos + dn * t;
	float rh = hs(rid);
	vec3 wand = mix(wand_a, wand_b, step(0.5, rh));
	vec3 c;
	if (t == tz) {
		c = wand;
		// Möbel/Schrank unten an der Rückwand, Bild an der Wand
		c *= 1.0 - 0.45 * (1.0 - sst(0.32, hit.y, aw)) * sst(0.15, hit.x, aw) * (1.0 - sst(0.75, hit.x, aw));
		c = mix(c, vec3(0.2, 0.35, 0.5), sst(0.55, hit.y, aw) * (1.0 - sst(0.8, hit.y, aw)) * sst(0.6, hit.x, aw) * (1.0 - sst(0.85, hit.x, aw)) * step(0.5, hs(rid + 2.0)));
	} else if (t == tx) {
		c = wand * 0.78;
	} else if (dn.y < 0.0) {
		c = mix(vec3(0.42, 0.36, 0.30), vec3(0.32, 0.34, 0.38), step(0.5, hs(rid + 9.0)));
	} else {
		c = vec3(0.9);
		float lampe = (1.0 - sst(0.18, abs(fract(hit.x * 1.5) - 0.5), aw * 1.5)) * (1.0 - sst(0.2, abs(hit.z + 0.45), aw));
		c += lampe * 1.4;
	}
	c *= mix(1.0, 0.5, clamp(-hit.z, 0.0, 1.0));
	// manche Räume mit Jalousie oder dunkel
	float jal = step(0.82, hs(rid + 5.0));
	// Jalousie-Streifen: verschwinden, sobald sie kleiner als ein Bildpunkt werden
	float streifen = mix(sst(0.5, fract(rp.y * 18.0), aw * 18.0), 0.5, clamp(aw * 18.0 * 2.0, 0.0, 1.0));
	if (szene < 0.5) {
		c = mix(c, vec3(0.75, 0.74, 0.7) * (0.85 + 0.15 * streifen), jal);
		c *= mix(1.0, 0.25, step(0.9, hs(rid + 13.0)));
	} else if (szene != 7.0) {
		if (szene == 3.0) {   // Party: Disco-Licht im ganzen Raum
			c *= mix(vec3(1.0), 0.6 + 0.6 * vec3(sin(TIME * 3.0), sin(TIME * 3.0 + 2.1), sin(TIME * 3.0 + 4.2)), 0.6);
		}
		// Szene auf einer Ebene hinter dem Glas (Tiere näher am Fenster)
		float tiefe = (szene == 2.0) ? 0.03 : ((szene == 10.0) ? 0.08 : 0.2);
		float ts = -tiefe / dn.z;
		if (ts < t) {
			vec3 q = pos + dn * ts;
			vec2 m = vec2((q.x * raum_fenster - wl) * fenster_breite, q.y * Hr);
			if (m.x > 0.0 && m.x < fenster_breite) {
				vec4 bild = szene_bild(szene, m, rid);
				c = mix(c, bild.rgb, bild.a);
			}
		}
	}
	return c;
}

void fragment() {
	if (wp.y > innen_band.x && wp.y < innen_band.y) discard;
	vec2 c = vec2(UV.x / fenster_breite, UV.y / stock);
	vec2 id = floor(c);
	vec2 f = fract(c);
	float band = 1.0 - sst(band_anteil, f.y, fwidth(c.y));
	float rx = UV.x / (fenster_breite * raum_fenster);
	vec2 rid = vec2(floor(rx), id.y);
	vec2 rp = vec2(fract(rx), clamp((f.y - band_anteil) / (1.0 - band_anteil), 0.0, 1.0));
	vec3 r = normalize(wp - CAMERA_POSITION_WORLD);
	float aw = max(fwidth(rp.x), fwidth(rp.y)) * 0.75;
	// Dreck + Szene aus dem Spielzustand
	float dreck = step(1.0 - dreckig, hs(id + 17.3));
	float maske = 1.0;
	float szene = 0.0;
	vec4 zs = vec4(0.0);
	if (mit_zustand) {
		zs = texture(zustand, (id + 0.5) / zustand_px);
		szene = floor(zs.b * 255.0 + 0.5);
	}
	vec3 innen = raum(rp, rid, r, aw, szene, mod(id.x, raum_fenster));
	// Gegen Flimmern: Sind die Räume nur noch wenige Bildpunkte groß, springen ihre Ecken (Parallaxe) und
	// die Zufallsfarben beim Fahren von Pixel zu Pixel. Dann weich auf eine flache Raumfarbe, weiter weg
	// auf einen Mittelwert über alle Räume.
	float rh = hs(rid);
	vec3 flach = mix(wand_a, wand_b, step(0.5, rh)) * 0.72;
	flach = mix(flach, vec3(0.75, 0.74, 0.7) * 0.92, step(0.82, hs(rid + 5.0)));
	flach *= mix(1.0, 0.25, step(0.9, hs(rid + 13.0)));
	vec3 alle = mix(wand_a, wand_b, 0.5) * 0.72 * 0.93;
	float klein = smoothstep(0.035, 0.12, aw);
	float winzig = smoothstep(0.12, 0.4, aw);
	if (szene < 0.5) {
		innen = mix(innen, flach, klein);
	}
	innen = mix(innen, alle, winzig);
	if (mit_zustand) {
		dreck = zs.r;
		float slot = floor(zs.g * 255.0 + 0.5) - 1.0;
		if (slot >= 0.0) {
			vec2 sp = vec2(mod(slot, slots.x), floor(slot / slots.x));
			vec2 lp = clamp(vec2(f.x, rp.y), 0.5 / slot_px, 1.0 - 0.5 / slot_px);
			maske = texture(wisch, (sp + lp) / slots).r;
		}
	}
	float schl = vn(vec2(f.x * 6.0 + id.x * 3.1, f.y * 1.5 + id.y * 2.7)) * 0.6 + vn(f * 14.0 + id * 5.0) * 0.4;
	float rand = smoothstep(0.25, 0.0, min(min(f.x, 1.0 - f.x) * 2.0, (f.y - band_anteil) * 2.5));
	// feine Schlieren (14 pro Fenster) und Schmutzrand ausblenden, bevor sie kleiner als ein Bildpunkt werden
	float gw = max(fwidth(c.x), fwidth(c.y));
	schl = mix(schl, 0.5, smoothstep(0.02, 0.07, gw));
	rand = mix(rand, 0.25, smoothstep(0.06, 0.2, gw));
	float d = dreck * clamp((schl * 0.9 + rand * 0.5) * (mit_zustand ? 1.25 : 1.0), 0.0, 1.0) * maske;
	// In der Ferne Mittelwerte statt Details
	float fern = smoothstep(0.2, 0.8, max(fwidth(c.x), fwidth(c.y) * 2.0)) * 0.85;
	vec3 glas = mix(glas_tint * 0.12, schmutz_farbe, clamp(d * 0.9, 0.0, 0.75));
	// Verspiegelung: sauberes Glas hat eine getönte Beschichtung (Metallic mit Glasfarbe), zum Rand hin (Fresnel) mehr Spiegel,
	// weniger Raum. Dreck nimmt sie weg – geputztes Glas glänzt sichtbar. In der Ferne etwas rauer (keine funkelnden Spiegelungen).
	float sauber_glas = (1.0 - clamp(d * 1.6, 0.0, 1.0)) * (1.0 - band) * spiegel;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float sp = sauber_glas * mix(0.42, 0.85, fres);
	glas = mix(glas, glas_tint * 0.85 + vec3(0.06), sauber_glas * 0.8);
	ALBEDO = mix(mix(glas, paneel, band), mix(glas_tint * 0.3, paneel, band_anteil), fern);
	METALLIC = max(band * 0.6, sp * (1.0 - fern * 0.5));
	ROUGHNESS = mix(mix(mix(0.03, 0.85, d), 0.35, band), 0.16, fern * spiegel) + sauber_glas * smoothstep(0.02, 0.2, gw) * 0.06;
	SPECULAR = 0.65;
	EMISSION = innen * mix(vec3(1.0), glas_tint * 1.6, 0.55 * (1.0 - nacht * 0.6)) * innen_hell * (1.0 + nacht * 1.2) * (1.0 - band) * (1.0 - d * 0.85) * (1.0 - fern * 0.7 * (1.0 - nacht * 0.5))
		* (1.0 - sp * (1.0 - nacht * 0.7) * 0.75);
	float sl = strahler_licht(wp, strahler_n);
	EMISSION += vec3(1.0, 0.8, 0.55) * sl * (ALBEDO * 2.4 + vec3(0.04));
	if (szene == 7.0) {   // Liebesbrief: Herz auf dem Glas
		float h = herz(vec2(f.x, rp.y)) * (1.0 - band) * (1.0 - fern);
		ALBEDO = mix(ALBEDO, vec3(0.9, 0.2, 0.35), h * (1.0 - d));
		EMISSION += vec3(0.9, 0.2, 0.35) * h * (1.0 - d) * 0.5;
	}
}
