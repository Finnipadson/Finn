shader_type spatial;

// Kenney-Palmen etwas natürlicher: Farben aus der Kenney-Palette entsättigt (Stamm braun statt orange, Blätter olivgrün)
uniform sampler2D farben : source_color, filter_linear_mipmap;

void fragment() {
	vec3 c = texture(farben, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 0.42) * vec3(0.95, 0.88, 0.76);
	ALBEDO = c;
	ROUGHNESS = 0.85;
}
