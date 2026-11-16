shader_type spatial;
render_mode cull_disabled;

// Meer hinter dem Strand: am Ufer türkis, draußen tiefblau, Schaum an der Wasserlinie, die mit den Wellen hin und her
// schwappt. Wellen nur über die Normale (in der Ferne glatter, gegen Flimmern).
uniform float ufer_x = -646.0;        // Wasserlinie (Kueste.WASSER_X); Meer liegt bei x < ufer_x
uniform vec3 flach : source_color = vec3(0.30, 0.78, 0.76);
uniform vec3 mittel : source_color = vec3(0.05, 0.50, 0.64);
uniform vec3 tief : source_color = vec3(0.02, 0.20, 0.40);
uniform vec3 sand_nass : source_color = vec3(0.62, 0.55, 0.40);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y);
}

vec2 welle(vec2 p, float t) {
	vec2 g = vec2(0.0);
	g += vec2(-0.9, 0.3) * cos(dot(p, vec2(-0.9, 0.3)) * 0.35 + t * 1.1) * 1.0;
	g += vec2(-0.6, -0.8) * cos(dot(p, vec2(-0.6, -0.8)) * 0.8 + t * 1.6) * 0.5;
	g += vec2(0.3, -0.95) * cos(dot(p, vec2(0.3, -0.95)) * 1.9 + t * 2.4) * 0.25;
	g += vec2(-0.95, -0.2) * cos(dot(p, vec2(-0.95, -0.2)) * 4.1 + t * 3.3) * 0.12;
	return g;
}

void fragment() {
	vec2 p = wp.xz;
	float abst = length(CAMERA_POSITION_WORLD - wp);
	float ruhig = 1.0 - smoothstep(80.0, 1400.0, abst);
	float aa = max(fwidth(p.x), fwidth(p.y));
	// Abstand vom Ufer ins Meer, Wasserlinie schwappt mit den Wellen
	float schwapp = 1.3 * sin(TIME * 0.55 + p.y * 0.045) + 0.6 * sin(TIME * 1.05 + p.y * 0.12 + 1.7);
	float d = ufer_x - p.x;
	float dd = d - 1.6 + schwapp + (vn(p * vec2(0.05, 0.12)) - 0.5) * 2.5;
	vec3 c = mix(flach, mittel, smoothstep(1.0, 45.0, d + (vn(p * 0.03) - 0.5) * 12.0));
	c = mix(c, tief, smoothstep(60.0, 600.0, d));
	// Flecken (Riffe/Sandbänke) im flachen Wasser, weit draußen ausgeblendet
	float fleck = vn(p * 0.025) * (1.0 - smoothstep(30.0, 160.0, d)) * (1.0 - smoothstep(0.5, 4.0, aa));
	c = mix(c, c * vec3(0.75, 0.95, 0.9), fleck * 0.5);
	// ganz am Ufer: nasser Sand schimmert durch
	c = mix(sand_nass, c, smoothstep(-1.5, 2.5, dd));
	// Schaum: Band an der schwappenden Linie + zweite, ausrollende Welle dahinter
	float n1 = vn(p * vec2(0.6, 0.35) + vec2(TIME * 0.4, TIME * 0.2));
	float schaum = (1.0 - smoothstep(0.0, 1.8 + aa, abs(dd))) * (0.55 + 0.6 * n1);
	float rolle = fract(TIME * 0.09 + p.y * 0.002);
	float zweite = (1.0 - smoothstep(0.0, 1.2 + aa, abs(d - 6.0 - rolle * 10.0))) * (1.0 - rolle) * (0.4 + 0.6 * n1);
	schaum = clamp(max(schaum, zweite * 0.7), 0.0, 1.0) * (1.0 - smoothstep(1.0, 6.0, aa));
	c = mix(c, vec3(0.95, 0.97, 0.98), schaum * 0.85);
	vec2 g = welle(p, TIME) * 0.045 * ruhig;
	g += (vec2(vn(p * 1.3 + TIME * 0.3), vn(p * 1.3 + 7.0 - TIME * 0.3)) - 0.5) * 0.06 * (1.0 - smoothstep(20.0, 200.0, abst));
	vec3 n_welt = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_welt, 0.0)).xyz);
	ALBEDO = c;
	ROUGHNESS = mix(0.06, 0.55, schaum);
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
