shader_type spatial;

// Strand zwischen Ufermauer und Wasserlinie: heller, feiner Sand mit Rippeln, nass und dunkler nahe am Wasser
// (im Takt des Schwappens wie in meer.gdshader), an der Mauer ein Schattenstreifen.
uniform float ufer_x = -646.0;
uniform float mauer_x = -606.0;
uniform vec3 hell : source_color = vec3(0.93, 0.84, 0.66);
uniform vec3 nass : source_color = vec3(0.66, 0.58, 0.43);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 p = wp.xz;
	float aa = max(fwidth(p.x), fwidth(p.y));
	float fein = 1.0 - smoothstep(0.05, 0.4, aa);
	vec3 c = hell * (0.92 + 0.1 * vn(p * 0.08) + 0.05 * mix(0.5, vn(p * 2.5), fein));
	// Rippeln quer zum Ufer, weit weg ausgeblendet
	float rippel = sin(p.x * 2.2 + vn(p * 0.3) * 5.0) * (1.0 - smoothstep(0.02, 0.15, aa));
	c *= 1.0 + 0.03 * rippel;
	float schwapp = 1.3 * sin(TIME * 0.55 + p.y * 0.045) + 0.6 * sin(TIME * 1.05 + p.y * 0.12 + 1.7);
	float vom_wasser = p.x - ufer_x;   // > 0 auf dem Sand
	float nasse = 1.0 - smoothstep(0.0, 3.5, vom_wasser - max(schwapp, -1.0) * 0.6 - 1.2);
	c = mix(c, nass * (0.95 + 0.08 * vn(p * 0.5)), nasse);
	c *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 2.0, mauer_x - p.x));
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.35, nasse);
	SPECULAR = mix(0.3, 0.6, nasse);
}
