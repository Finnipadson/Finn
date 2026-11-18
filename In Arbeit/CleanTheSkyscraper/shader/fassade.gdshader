shader_type spatial;
render_mode cull_disabled;

// UV ist in Metern: x = Weg entlang der Fassade, y = Höhe.
uniform vec3 glas : source_color = vec3(0.45, 0.62, 0.78);
uniform vec3 rahmen : source_color = vec3(0.78, 0.80, 0.83);
uniform vec3 bruestung : source_color = vec3(0.62, 0.66, 0.70);
uniform vec3 schmutz_farbe : source_color = vec3(0.50, 0.42, 0.30);
uniform float fenster_breite = 1.6;
uniform float stock = 4.2;
uniform float band_anteil = 0.22;   // Brüstung unten im Stockwerk
uniform float rahmen_x = 0.05;
uniform float dreckig = 0.7;        // Anteil dreckiger Fenster
uniform float licht = 0.08;         // Anteil Fenster mit Licht dahinter
uniform float metall = 0.65;
global uniform float nacht;          // Tageszeit (Phase 5): nachts sind viele Fenster hell

float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y);
}

// Innenraum (Arcade, Penthouse): Fassade in diesem Höhenband weglassen, solange die Kamera drin ist
uniform vec2 innen_band = vec2(-1.0, -1.0);
varying float wy;
void vertex() {
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

// Gefilterte Streifen (gegen Flimmern): Anteil eines Bildpunkts (Breite w, in Zellen), der in einem
// periodischen Streifen [0, b) jeder Zelle liegt – statt harter step()-Kante, die beim Bewegen springt.
float streifen_int(float x, float b) { return floor(x) * b + min(fract(x), b); }
float streifen(float x, float b, float w) {
	w = max(w, 1e-4);
	return clamp((streifen_int(x + w * 0.5, b) - streifen_int(x - w * 0.5, b)) / w, 0.0, 1.0);
}

void fragment() {
	if (wy > innen_band.x && wy < innen_band.y) discard;
	vec2 c = vec2(UV.x / fenster_breite, UV.y / stock);
	vec2 id = floor(c);
	vec2 f = fract(c);
	// Breite eines Bildpunkts in Zellen (etwas mehr als 1 Pixel → weiche, ruhige Kanten)
	vec2 w = fwidth(c) * 1.25;
	float band = streifen(c.y, band_anteil, w.y);
	float rx = streifen(c.x + rahmen_x, rahmen_x * 2.0, w.x);
	float ry = streifen(c.y - band_anteil, 0.035, w.y) + streifen(c.y + 0.025, 0.025, w.y);
	float ist_glas = (1.0 - rx) * clamp(1.0 - band - ry, 0.0, 1.0);
	// Zufallswerte pro Fenster (Helligkeit, Dreck, Licht) nur, solange ein Fenster mehrere Bildpunkte groß ist –
	// sonst springen sie beim Bewegen von Pixel zu Pixel. Danach weich auf Mittelwerte.
	float gross = max(w.x, w.y * 2.0);
	float fern = smoothstep(0.12, 0.45, gross);
	float h = mix(hs(id), 0.5, fern);
	float dreck = mix(step(1.0 - dreckig, hs(id + 17.3)), dreckig, fern);
	float schlieren = vn(vec2(f.x * 6.0 + id.x * 3.1, f.y * 1.5 + id.y * 2.7)) * 0.6 + vn(f * 14.0 + id * 5.0) * 0.4;
	schlieren = mix(schlieren, 0.5, smoothstep(0.03, 0.12, gross));
	float rand = smoothstep(0.25, 0.0, min(min(f.x, 1.0 - f.x) * 2.0, (f.y - band_anteil) * 2.5));
	rand = mix(rand, 0.3, smoothstep(0.05, 0.2, gross));
	float d = dreck * clamp(schlieren * 0.9 + rand * 0.5, 0.0, 1.0);
	vec3 g = glas * (0.88 + 0.24 * h);
	g = mix(g, schmutz_farbe, clamp(d * 1.1, 0.0, 0.95));
	vec3 r = mix(rahmen, bruestung, band / max(band + ry + rx * (1.0 - band), 1e-4));
	// Ganz weit weg (Fenster kleiner als ein Bildpunkt) auf die Fassaden-Mittelfarbe
	float sehr_fern = smoothstep(0.6, 1.4, gross) * 0.85;
	vec3 mittel = mix(mix(rahmen, bruestung, band_anteil), mix(glas, schmutz_farbe, dreckig * 0.4), 0.8);
	ALBEDO = mix(mix(r, g, ist_glas), mittel, sehr_fern);
	METALLIC = mix(mix(0.25, metall * (1.0 - d * 0.9), ist_glas), metall * 0.6, sehr_fern);
	ROUGHNESS = mix(mix(0.45, mix(0.08, 0.9, d), ist_glas), 0.3, sehr_fern);
	// Licht hinter dem Fenster: in der Ferne als gleichmäßiger, schwacher Schein statt einzelner Punkte
	float li = mix(licht, 0.42, nacht);
	float an = mix(step(1.0 - li, hs(id + 41.7)), li, fern) * ist_glas * (1.0 - d);
	vec3 lf = mix(vec3(1.0, 0.82, 0.55), mix(vec3(1.0, 0.78, 0.5), vec3(0.75, 0.88, 1.0), step(0.7, hs(id + 7.7))), nacht * (1.0 - fern));
	// in der Ferne nur ein schwacher Schimmer (sonst glühen ganze Häuser), nah kräftig
	EMISSION = lf * an * mix(0.6, mix(1.6, 0.45, fern), nacht) * (1.0 - sehr_fern * (1.0 - nacht * 0.5));
}
