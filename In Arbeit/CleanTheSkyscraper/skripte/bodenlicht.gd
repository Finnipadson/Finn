class_name Bodenlicht
extends Node3D
# Bodenleuchten (Grafik, 19.11.2026, Wunsch des Users nach einem Foto): Metallscheibe im Boden, nachts ein warmer
# Leuchtpunkt, ein weicher Lichtkreis auf dem Boden und auf Wunsch ein Lichtfächer an einer Wand/Kante (wie bei
# angestrahlten Bordsteinen). Keine echten Lichtquellen – nur leuchtende, additive Flächen in MultiMeshes (fast kostenlos).
# Tagsüber sieht man nur die Scheiben. Leuchtpunkte werden nie kleiner als ~2 Bildpunkte und verblassen in großer Ferne
# (sonst blitzen Hunderte winzige Punkte beim Bewegen).

const WARM := Color(1.0, 0.78, 0.52)

const KREIS_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
global uniform float nacht;
uniform vec3 farbe : source_color = vec3(1.0, 0.78, 0.52);
uniform float staerke = 0.55;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(max(1.0 - d, 0.0), 2.2);
	float an = smoothstep(0.25, 0.6, nacht);
	float ferne = 1.0 - smoothstep(350.0, 900.0, length(VERTEX));
	ALBEDO = farbe * a * staerke * an * ferne;
}
"""

const FAECHER_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
global uniform float nacht;
uniform vec3 farbe : source_color = vec3(1.0, 0.78, 0.52);
uniform float staerke = 0.4;
void fragment() {
	// Fächer: Lichtfleck unten in der Mitte, halbrund nach oben und zu den Seiten weich auslaufend (UV.y = 1 unten)
	float x = (UV.x - 0.5) * 2.0;
	float h = 1.0 - UV.y;
	float a = pow(max(1.0 - length(vec2(x, h * 0.9)), 0.0), 2.0);
	float an = smoothstep(0.25, 0.6, nacht);
	float ferne = 1.0 - smoothstep(300.0, 800.0, length(VERTEX));
	ALBEDO = farbe * a * staerke * an * ferne;
}
"""

const PUNKT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, world_vertex_coords;
global uniform float nacht;
uniform vec3 farbe : source_color = vec3(1.0, 0.86, 0.66);
varying float ferne;
void vertex() {
	vec3 mitte = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(CAMERA_POSITION_WORLD - mitte);
	float groesse = max(0.32, dist * 0.0024);
	vec3 r = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 u = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 ecke = VERTEX - mitte;
	VERTEX = mitte + (r * ecke.x + u * ecke.y) * groesse;
	ferne = 1.0 - smoothstep(250.0, 800.0, dist);
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = (1.0 - smoothstep(0.05, 1.0, d));
	a = a * a;
	ALBEDO = farbe * a * 1.3 * smoothstep(0.25, 0.6, nacht) * ferne;
}
"""

var _scheiben: Array = []     # Transform3D
var _punkte: Array = []       # Vector3
var _kreise: Array = []       # Transform3D (PlaneMesh 1×1, skaliert)
var _faecher: Array = []      # Transform3D (QuadMesh 1×1, senkrecht)

# Leuchte bei pos (Boden). kreis_r = Lichtkreis auf dem Boden (0 = keiner).
func leuchte(pos: Vector3, kreis_r := 1.8) -> void:
	_scheiben.append(Transform3D(Basis(), pos + Vector3.UP * 0.01))
	_punkte.append(pos + Vector3.UP * 0.12)
	if kreis_r > 0.0:
		_kreise.append(Transform3D(Basis.from_scale(Vector3(kreis_r * 2.0, 1.0, kreis_r * 2.0)), pos + Vector3.UP * 0.035))

# Lichtfächer an einer senkrechten Fläche: unten-Mitte bei fuss, Fläche zeigt nach normal (waagerecht), Breite/Höhe in m
func faecher(fuss: Vector3, normal: Vector3, breite: float, hoehe: float) -> void:
	var n := Vector3(normal.x, 0.0, normal.z).normalized()
	var x := Vector3.UP.cross(n).normalized()
	var b := Basis(x * breite, Vector3.UP * hoehe, n)
	_faecher.append(Transform3D(b, fuss + n * 0.02 + Vector3.UP * hoehe * 0.5))

func anzahl() -> int:
	return _scheiben.size()

func fertig() -> void:
	if _scheiben.is_empty():
		return
	var scheibe := CylinderMesh.new()
	scheibe.top_radius = 0.17
	scheibe.bottom_radius = 0.19
	scheibe.height = 0.04
	scheibe.radial_segments = 16
	scheibe.rings = 1
	var met := StandardMaterial3D.new()
	met.albedo_color = Color("aeb4ba")
	met.metallic = 0.8
	met.roughness = 0.35
	_mm(scheibe, met, _scheiben, true)
	var ebene := PlaneMesh.new()
	ebene.size = Vector2.ONE
	_mm(ebene, _shader_mat(KREIS_SHADER), _kreise, false)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_mm(quad, _shader_mat(FAECHER_SHADER), _faecher, false)
	var pt: Array = []
	for p in _punkte:
		pt.append(Transform3D(Basis(), p))
	var mmi := _mm(quad, _shader_mat(PUNKT_SHADER), pt, false)
	if mmi:
		mmi.custom_aabb = AABB(Vector3(-3000, -100, -3000), Vector3(6000, 1200, 6000))   # Billboards wachsen im Shader

func _shader_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _mm(mesh: Mesh, mat: Material, xf: Array, schatten: bool) -> MultiMeshInstance3D:
	if xf.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if schatten else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi
