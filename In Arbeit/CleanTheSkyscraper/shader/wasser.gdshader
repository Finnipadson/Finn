shader_type spatial;
render_mode cull_disabled;

// See am Turmfuß: dunkles, spiegelndes Wasser mit kleinen Wellen (SSR spiegelt den Turm)
uniform vec3 tief : source_color = vec3(0.03, 0.14, 0.17);
uniform vec3 flach : source_color = vec3(0.08, 0.3, 0.32);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Summe aus Sinuswellen → Steigung für die Normale
vec2 welle(vec2 p, float t) {
	vec2 g = vec2(0.0);
	g += vec2(0.8, 0.6) * cos(dot(p, vec2(0.8, 0.6)) * 0.9 + t * 1.3) * 0.9;
	g += vec2(-0.5, 0.86) * cos(dot(p, vec2(-0.5, 0.86)) * 1.7 + t * 1.9) * 0.5;
	g += vec2(0.2, -0.98) * cos(dot(p, vec2(0.2, -0.98)) * 3.1 + t * 2.6) * 0.25;
	g += vec2(-0.9, -0.3) * cos(dot(p, vec2(-0.9, -0.3)) * 5.3 + t * 3.4) * 0.12;
	return g;
}

void fragment() {
	vec2 p = wp.xz;
	float abst = length(CAMERA_POSITION_WORLD - wp);
	float ruhig = 1.0 - smoothstep(60.0, 900.0, abst);   // weit weg glatter (sonst Flimmern)
	vec2 g = welle(p, TIME) * 0.035 * ruhig;
	vec3 n_welt = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_welt, 0.0)).xyz);
	float f = 0.5 + 0.5 * sin(p.x * 0.05) * sin(p.y * 0.04);
	ALBEDO = mix(tief, flach, f * 0.4);
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.65;
}
