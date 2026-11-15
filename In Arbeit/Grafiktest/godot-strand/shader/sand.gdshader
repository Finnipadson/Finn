shader_type spatial;
render_mode cull_disabled;

uniform float wasser = 0.0;
varying vec3 wpos;

float h21(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float caus(vec2 p, float t) {
	vec2 q = p; float c = 0.0;
	for (int i = 0; i < 3; i++) { q += vec2(sin(q.y * 1.3 + t * 0.8), cos(q.x * 1.1 - t * 0.7)) * 0.6; c += abs(sin(q.x + q.y)); }
	return pow(1.0 - c / 3.0, 5.0);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	c *= 0.975 + h21(floor(wpos.xz * 14.0)) * 0.05;
	float tief = 1.0 - smoothstep(-3.0, -0.5, wpos.y);
	float rip = sin(wpos.x * 0.8 + sin(wpos.z * 0.21) * 3.0 + wpos.z * 0.15);
	c *= 1.0 - 0.11 * rip * tief;
	float nass = 1.0 - smoothstep(wasser + 0.1, wasser + 1.0, wpos.y);
	c *= mix(1.0, 0.7, nass);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.6, nass);
	float unter = 1.0 - smoothstep(wasser - 0.1, wasser + 0.05, wpos.y);
	float cf = 1.0 - smoothstep(1.0, 14.0, wasser - wpos.y);
	EMISSION = vec3(0.55, 0.85, 0.95) * caus(wpos.xz * 0.25, TIME) * unter * cf * 0.45;
}
