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

void fragment() {
	if (wy > innen_band.x && wy < innen_band.y) discard;
	vec2 c = vec2(UV.x / fenster_breite, UV.y / stock);
	vec2 id = floor(c);
	vec2 f = fract(c);
	float band = step(f.y, band_anteil);
	float rx = step(f.x, rahmen_x) + step(1.0 - rahmen_x, f.x);
	float ry = step(f.y, band_anteil + 0.035) * (1.0 - band) + step(0.975, f.y);
	float ist_glas = (1.0 - clamp(rx + ry, 0.0, 1.0)) * (1.0 - band);
	float h = hs(id);
	// Dreck: nur ein Teil der Fenster, mit Schlieren und Rand
	float dreck = step(1.0 - dreckig, hs(id + 17.3));
	float schlieren = vn(vec2(f.x * 6.0 + id.x * 3.1, f.y * 1.5 + id.y * 2.7)) * 0.6 + vn(f * 14.0 + id * 5.0) * 0.4;
	float rand = smoothstep(0.25, 0.0, min(min(f.x, 1.0 - f.x) * 2.0, (f.y - band_anteil) * 2.5));
	float d = dreck * clamp(schlieren * 0.9 + rand * 0.5, 0.0, 1.0);
	vec3 g = glas * (0.88 + 0.24 * h);
	g = mix(g, schmutz_farbe, clamp(d * 1.1, 0.0, 0.95));
	vec3 r = mix(rahmen, bruestung, band);
	// In der Ferne (Fenster kleiner als ein Pixel) auf Mittelwerte überblenden → kein Flimmern
	float fern = smoothstep(0.5, 1.4, max(fwidth(c.x), fwidth(c.y) * 2.0)) * 0.85;
	vec3 mittel = mix(mix(rahmen, bruestung, band_anteil), mix(glas, schmutz_farbe, dreckig * 0.4), 0.8);
	ALBEDO = mix(mix(r, g, ist_glas), mittel, fern);
	METALLIC = mix(mix(0.25, metall * (1.0 - d * 0.9), ist_glas), metall * 0.6, fern);
	ROUGHNESS = mix(mix(0.45, mix(0.08, 0.9, d), ist_glas), 0.3, fern);
	float an = step(1.0 - licht, hs(id + 41.7)) * ist_glas * (1.0 - d);
	EMISSION = vec3(1.0, 0.82, 0.55) * an * 0.6 * (1.0 - fern);
}
