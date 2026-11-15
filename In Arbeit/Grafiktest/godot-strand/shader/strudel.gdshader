shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float staerke = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) discard;
	float a = atan(p.y, p.x);
	float sp = sin(a * 4.0 + log(r + 0.03) * 8.0 + TIME * 8.0);
	float lin = smoothstep(0.5, 0.95, sp) * smoothstep(0.04, 0.35, r);
	vec3 c = mix(vec3(0.01, 0.12, 0.35), vec3(0.25, 0.72, 0.88), smoothstep(0.0, 0.9, r));
	c = mix(c, vec3(1.0), lin * 0.85);
	ALBEDO = c;
	ALPHA = (1.0 - smoothstep(0.7, 1.0, r)) * 0.92 * staerke;
}
