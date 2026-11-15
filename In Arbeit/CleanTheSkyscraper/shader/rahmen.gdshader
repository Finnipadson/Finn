shader_type spatial;

// Fensterrahmen: in der Nähe Alu, mit der Entfernung Richtung Fassaden-Mittelfarbe (weniger Kontrast = kein Flimmern)
uniform vec3 farbe : source_color = vec3(0.79, 0.81, 0.83);
uniform vec3 fern_farbe : source_color = vec3(0.45, 0.52, 0.60);
uniform float fern_ab = 35.0;
uniform float fern_bis = 160.0;

varying float dist;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	dist = length(CAMERA_POSITION_WORLD - wp);
}

void fragment() {
	float k = smoothstep(fern_ab, fern_bis, dist);
	ALBEDO = mix(farbe, fern_farbe, k);
	METALLIC = mix(0.85, 0.3, k);
	ROUGHNESS = mix(0.3, 0.6, k);
}
