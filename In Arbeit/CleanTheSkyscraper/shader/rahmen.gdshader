shader_type spatial;

// Fensterrahmen: in der Nähe Alu, mit der Entfernung Richtung Fassaden-Mittelfarbe (weniger Kontrast = kein Flimmern)
uniform vec3 farbe : source_color = vec3(0.79, 0.81, 0.83);
uniform vec3 fern_farbe : source_color = vec3(0.45, 0.52, 0.60);
uniform float fern_ab = 35.0;
uniform float fern_bis = 160.0;

uniform float strahler_n = 0.0;       // Bodenstrahler am Turmfuß (Anzahl, 0 = aus)
global uniform float nacht;

varying float dist;
varying vec3 wpos;

// Bodenstrahler am Turmfuß (19.11.2026): N Strahler in gleichen Winkeln um den Turm, Lichtkegel unten schmal, oben breit,
// nach oben schwächer. In der Ferne (Kegel kleiner als ein paar Bildpunkte) gemittelt – gegen Flimmern.
float strahler_licht(vec3 p, float n) {
	float an = smoothstep(0.25, 0.6, nacht);
	if (an <= 0.0 || n < 1.0 || p.y > 70.0) return 0.0;
	float th = atan(p.z, p.x) * n;
	float breit = mix(18.0, 2.5, smoothstep(0.0, 28.0, p.y));
	float kegel = pow(0.5 + 0.5 * cos(th), breit);
	float mittel = 0.25 / sqrt(breit);
	kegel = mix(kegel, mittel, smoothstep(0.08, 0.35, fwidth(th) / 6.2832));
	return an * kegel * exp(-max(p.y, 0.0) / 13.0) * smoothstep(-0.5, 0.6, p.y);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wpos = wp;
	dist = length(CAMERA_POSITION_WORLD - wp);
}

void fragment() {
	float k = smoothstep(fern_ab, fern_bis, dist);
	ALBEDO = mix(farbe, fern_farbe, k);
	// wenig Metall + etwas rau: kein hartes Glitzern an den Kanten, wenn sich die Gondel dreht
	METALLIC = mix(0.35, 0.2, k);
	ROUGHNESS = mix(0.45, 0.6, k);
	EMISSION = vec3(1.0, 0.8, 0.55) * strahler_licht(wpos, strahler_n) * ALBEDO * 2.4;
}
