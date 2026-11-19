shader_type spatial;

// Kenney-Autos (Car Kit, CC0) mit eigener Lackfarbe pro Auto:
// Die Textur ist eine Farbpalette aus 8×4 Feldern. Das Feld mit dem Lack (zelle) wird mit der Instanzfarbe ersetzt,
// wenn deren Alpha > 0,5 ist (Taxi und Polizei behalten ihre Farben).
uniform sampler2D farben : source_color, filter_linear_mipmap;
uniform vec2 zelle = vec2(-1.0);
global uniform float nacht;   // Tageszeit (Phase 5): Scheinwerfer + Rücklichter
uniform float lichter = 1.0;  // 0 = geparkt (Grundstuecke.gd): nachts keine Scheinwerfer

varying vec4 lack;
varying vec3 ln;

void vertex() {
	lack = COLOR;
	ln = NORMAL;
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
	// Nachts: helle Flächen vorn leuchten weiß (Scheinwerfer), rote Flächen hinten rot (Rücklichter)
	if (nacht > 0.01 && lichter > 0.5) {
		float hell = smoothstep(0.7, 0.85, dot(c, vec3(0.333)));
		float rot = smoothstep(0.25, 0.45, c.r - max(c.g, c.b));
		EMISSION = vec3(1.0, 0.95, 0.8) * hell * smoothstep(0.6, 0.9, ln.z) * 3.0 * nacht
			+ vec3(1.0, 0.1, 0.05) * rot * smoothstep(0.6, 0.9, -ln.z) * 2.5 * nacht;
	}
}
