shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Wasserfontänen wie bei einer Show: Höhe pro Fontäne aus INSTANCE_CUSTOM + Zeit.
// INSTANCE_CUSTOM: x = Lage entlang der Reihe (0..1), y = Gruppe (0 Bogen, 1 Ring, 2 Mitte), z = größte Höhe (m), w = Zufall
// art: 0 = Wasserstrahl (Zylinder), 1 = Gischt-Wolke oben (Kugel), 2 = Schaum auf dem Wasser (Fläche)
uniform int art = 0;
global uniform float nacht;   // Tageszeit (Phase 5): nachts beleuchtet

varying float hy;      // 0 unten … 1 oben (nur Strahl)
varying float staerke; // 0 = Fontäne aus
varying float zufall;

// Choreografie: 48 s Schleife mit vier Bildern
float hoehe(vec4 c, float t) {
	float s = mod(t, 48.0);
	float x = c.x;
	float h;
	if (s < 12.0) {          // Welle läuft über den Bogen
		h = 0.25 + 0.75 * pow(max(0.0, sin(s * 1.6 - x * 14.0)), 2.0);
		if (c.y > 0.5) h *= 0.35;
	} else if (s < 24.0) {   // alle zusammen im Takt
		h = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(s * 2.2), 3.0);
		if (c.y > 1.5) h = 0.5 + 0.5 * sin(s * 2.2 + 1.5);
	} else if (s < 36.0) {   // abwechselnd, Ring schießt hoch
		h = (mod(floor(x * 40.0), 2.0) < 0.5) == (sin(s * 1.4) > 0.0) ? 0.9 : 0.25;
		if (c.y > 0.5) h = 0.4 + 0.6 * pow(max(0.0, sin(s * 0.9 + x * 6.283)), 4.0);
	} else {                 // ruhiges Atmen, nur der Bogen
		h = c.y < 0.5 ? 0.3 + 0.2 * sin(s * 0.8 + x * 3.0) : 0.05;
	}
	// sanfte Übergänge an den Bildwechseln
	float rand = min(mod(s, 12.0), 12.0 - mod(s, 12.0));
	h *= 0.4 + 0.6 * smoothstep(0.0, 1.2, rand);
	return clamp(h, 0.0, 1.0) * c.z * (0.92 + 0.16 * c.w);
}

void vertex() {
	float h = hoehe(INSTANCE_CUSTOM, TIME);
	staerke = smoothstep(1.0, 4.0, h);
	zufall = INSTANCE_CUSTOM.w;
	if (art == 2) {
		// Schaum: flache Scheibe am Fuß, wächst mit der Fontäne
		float r = 1.5 + h * 0.08;
		VERTEX = VERTEX * vec3(r, 1.0, r) + vec3(0.0, 0.03, 0.0);
		hy = 0.0;
	} else if (art == 1) {
		// Wolke: Mesh ist eine Kugel mit Radius 1, um Strahlspitze herum aufgebläht
		float r = 0.8 + h * 0.07;
		VERTEX = VERTEX * vec3(r, r * 2.4, r) + vec3(0.0, h * 0.86, 0.0);
		hy = 1.0;
	} else {
		// Zylinder (Höhe 1, Mitte bei 0): unten Breite 1, nach oben schmaler
		hy = VERTEX.y + 0.5;
		float breit = mix(0.22, 1.1, hy * hy) * (0.6 + h * 0.01);
		VERTEX.xz *= breit / 0.5;
		VERTEX.y = hy * h;
	}
}

float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	// am Rand durchsichtiger (Blick schräg auf die Wassersäule)
	float rand = art == 2 ? 1.0 : abs(dot(NORMAL, VIEW));
	float a;
	if (art == 2) {
		float r = length(UV - 0.5) * 2.0;
		float n = vn(UV * 7.0 + vec2(TIME * 0.4, TIME * 0.25) + zufall * 10.0);
		a = 0.55 * (1.0 - smoothstep(0.3, 1.0, r)) * (0.4 + 0.8 * n);
	} else if (art == 1) {
		float n = vn(UV * vec2(9.0, 6.0) + vec2(TIME * 0.3, -TIME * 0.8) + zufall * 10.0);
		a = 0.3 * pow(rand, 2.0) * (0.4 + 0.9 * n);
	} else {
		float streifen = vn(vec2(UV.x * 18.0, hy * 6.0 - TIME * 5.0 + zufall * 7.0));
		a = (0.18 + 0.32 * streifen) * pow(rand, 1.5) * (1.0 - smoothstep(0.55, 1.0, hy)) * smoothstep(0.0, 0.08, hy);
	}
	ALBEDO = vec3(0.93, 0.97, 1.0);
	EMISSION = mix(vec3(0.25, 0.27, 0.3), vec3(0.7, 0.85, 1.0) * 1.4, nacht);
	ROUGHNESS = 0.3;
	ALPHA = clamp(a * staerke, 0.0, 1.0);
}
