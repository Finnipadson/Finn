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
// Spielzustand (FensterZustand): Dreck pro Fenster + feine Wisch-Masken
uniform bool mit_zustand = false;
uniform sampler2D zustand : filter_nearest;
uniform sampler2D wisch : filter_linear;
uniform vec2 zustand_px = vec2(1.0, 1.0);
uniform vec2 slots = vec2(16.0, 4.0);
uniform vec2 slot_px = vec2(64.0, 128.0);

varying vec3 wp;
varying vec3 wt;
varying vec3 wn;

float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wt = normalize((MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz);
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// weiche Stufe: statt harter Kante über die Breite eines Bildpunkts überblenden (gegen Flimmern)
float sst(float e, float x, float w) { return smoothstep(e - w, e + w, x); }

vec3 raum(vec2 rp, vec2 rid, vec3 r, float aw) {
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
	c = mix(c, vec3(0.75, 0.74, 0.7) * (0.85 + 0.15 * streifen), jal);
	c *= mix(1.0, 0.25, step(0.9, hs(rid + 13.0)));
	return c;
}

void fragment() {
	vec2 c = vec2(UV.x / fenster_breite, UV.y / stock);
	vec2 id = floor(c);
	vec2 f = fract(c);
	float band = 1.0 - sst(band_anteil, f.y, fwidth(c.y));
	float rx = UV.x / (fenster_breite * raum_fenster);
	vec2 rid = vec2(floor(rx), id.y);
	vec2 rp = vec2(fract(rx), clamp((f.y - band_anteil) / (1.0 - band_anteil), 0.0, 1.0));
	vec3 r = normalize(wp - CAMERA_POSITION_WORLD);
	float aw = max(fwidth(rp.x), fwidth(rp.y)) * 0.75;
	vec3 innen = raum(rp, rid, r, aw);
	// Dreck
	float dreck = step(1.0 - dreckig, hs(id + 17.3));
	float maske = 1.0;
	if (mit_zustand) {
		vec4 zs = texture(zustand, (id + 0.5) / zustand_px);
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
	float d = dreck * clamp((schl * 0.9 + rand * 0.5) * (mit_zustand ? 1.25 : 1.0), 0.0, 1.0) * maske;
	// In der Ferne Mittelwerte statt Details
	float fern = smoothstep(0.2, 0.8, max(fwidth(c.x), fwidth(c.y) * 2.0)) * 0.85;
	vec3 glas = mix(glas_tint * 0.12, schmutz_farbe, clamp(d * 0.9, 0.0, 0.75));
	ALBEDO = mix(mix(glas, paneel, band), mix(glas_tint * 0.3, paneel, band_anteil), fern);
	METALLIC = band * 0.6;
	ROUGHNESS = mix(mix(0.03, 0.85, d), 0.35, band);
	SPECULAR = 0.65;
	EMISSION = innen * mix(vec3(1.0), glas_tint * 1.6, 0.55) * innen_hell * (1.0 - band) * (1.0 - d * 0.85) * (1.0 - fern * 0.7);
}
