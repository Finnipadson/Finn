shader_type spatial;
render_mode cull_disabled;

// Kenney-Palmen natürlicher: Stamm mit Ringen und Schuppen (Dattelpalme), Blätter mit Farbverlauf zur Spitze,
// feinen Streifen und Gegenlicht, dazu leichtes Wiegen im Wind. Stamm/Blatt wird an der Palettenfarbe erkannt.
uniform sampler2D farben : source_color, filter_linear_mipmap;
uniform vec3 rinde_hell : source_color = vec3(0.62, 0.5, 0.36);
uniform vec3 rinde_dunkel : source_color = vec3(0.33, 0.25, 0.17);
uniform vec3 blatt_innen : source_color = vec3(0.13, 0.27, 0.12);
uniform vec3 blatt_spitze : source_color = vec3(0.4, 0.52, 0.22);
uniform float wind = 1.0;
uniform float strahler = 1.0;      // 19.11.2026: Bodenleuchte am Fuß jeder Palme
global uniform float nacht;

varying vec3 lokal;
varying float ist_blatt;

void vertex() {
	lokal = VERTEX;
	vec3 c = texture(farben, UV).rgb;
	ist_blatt = step(c.r, c.g * 1.05);   // grün → Blatt
	// Wind: oben mehr als unten, Blätter flattern zusätzlich; Phase je Palme aus ihrer Weltposition
	vec3 ort = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = ort.x * 0.37 + ort.z * 0.23;
	float h = clamp(VERTEX.y / 4.2, 0.0, 1.0);
	float wiegen = sin(TIME * 0.9 + phase) * 0.05 * h * h;
	float flattern = sin(TIME * 3.1 + phase * 3.0 + VERTEX.x * 2.0) * 0.025 * ist_blatt * length(VERTEX.xz);
	VERTEX.x += (wiegen + flattern) * wind;
	VERTEX.z += (wiegen * 0.6 + flattern * 0.5) * wind;
	VERTEX.y += flattern * 0.6 * wind;
}

float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }

void fragment() {
	if (ist_blatt > 0.5) {
		// Farbverlauf: innen dunkel, zur Spitze heller; feine Längsstreifen (Fiederblätter)
		float weit = clamp(length(lokal.xz) / 1.6, 0.0, 1.0);
		vec3 c = mix(blatt_innen, blatt_spitze, smoothstep(0.1, 1.0, weit));
		float arg = atan(lokal.z, lokal.x) * 60.0 + weit * 20.0;
		// Gegen Flimmern: feine Streifen/Flecken ausblenden, sobald sie kleiner als ein Bildpunkt werden
		// (Winkelsprung bei atan begrenzt, damit die Naht nicht alles ausblendet)
		float fa = min(fwidth(arg), 10.0);
		float streifen = mix(0.5 + 0.5 * sin(arg), 0.5, smoothstep(0.8, 2.5, fa));
		c *= 0.86 + 0.18 * streifen;
		float fz = max(fwidth(lokal.x), fwidth(lokal.z)) * 6.0;
		c *= 0.92 + 0.12 * mix(hs(floor(lokal.xz * 6.0)), 0.5, smoothstep(0.15, 0.5, fz));
		ALBEDO = c;
		ROUGHNESS = 0.7;
		SPECULAR = 0.3;
		BACKLIGHT = c * 0.35;   // Sonne scheint durch die Blätter
		// Bodenleuchte: Unterseite der Krone nahe am Stamm warm angestrahlt
		float an = smoothstep(0.25, 0.6, nacht) * strahler;
		EMISSION = c * vec3(1.0, 0.82, 0.58) * an * 0.5 * (1.0 - weit * 0.8);
	} else {
		// Dattelpalmen-Stamm: waagerechte Ringe + schräge Schuppen
		float y = lokal.y * 7.0;
		float winkel = atan(lokal.z, lokal.x);
		float ring = smoothstep(0.0, 0.18, fract(y)) * smoothstep(1.0, 0.75, fract(y));
		float schuppe = 0.5 + 0.5 * sin(winkel * 6.0 + floor(y) * 1.7);
		// Gegen Flimmern: Ringe (7 pro Meter) in der Ferne zum Mittelwert, bevor sie zu Pixel-Treppen werden
		float fy = fwidth(y);
		float ferne = smoothstep(0.12, 0.45, fy);
		ring = mix(ring, 0.6, ferne);
		schuppe = mix(schuppe, 0.5, ferne);
		vec3 c = mix(rinde_dunkel, rinde_hell, ring * (0.65 + 0.35 * schuppe));
		c *= 0.9 + 0.15 * mix(hs(vec2(floor(y), floor(winkel * 3.0))), 0.5, ferne);
		ALBEDO = c;
		ROUGHNESS = 0.95;
		// Bodenleuchte: Stamm unten hell, nach oben weich schwächer
		float an = smoothstep(0.25, 0.6, nacht) * strahler;
		EMISSION = c * vec3(1.0, 0.88, 0.7) * an * (0.95 * exp(-max(lokal.y, 0.0) / 0.75) + 0.025);
	}
}
