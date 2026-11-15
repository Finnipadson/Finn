shader_type spatial;

// Kenney-Autos (Car Kit, CC0) mit eigener Lackfarbe pro Auto:
// Die Textur ist eine Farbpalette aus 8×4 Feldern. Das Feld mit dem Lack (zelle) wird mit der Instanzfarbe ersetzt,
// wenn deren Alpha > 0,5 ist (Taxi und Polizei behalten ihre Farben).
uniform sampler2D farben : source_color, filter_linear_mipmap;
uniform vec2 zelle = vec2(-1.0);

varying vec4 lack;

void vertex() {
	lack = COLOR;
}

void fragment() {
	vec3 c = texture(farben, UV).rgb;
	vec2 z = floor(UV * vec2(8.0, 4.0));
	if (lack.a > 0.5 && z == zelle) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = lack.rgb * clamp(l / 0.55, 0.7, 1.25);
		METALLIC = 0.5;
		ROUGHNESS = 0.25;
	} else {
		ROUGHNESS = 0.6;
	}
	ALBEDO = c;
}
