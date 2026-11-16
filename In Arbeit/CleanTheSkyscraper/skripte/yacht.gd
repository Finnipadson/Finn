class_name Yacht
extends Node3D
# Eigene Yacht (Belohnung für alle 20 Fische im Index): liegt am Steg (Kueste.LIEGEPLATZ), mit E einsteigen,
# W/S Gas/rückwärts, A/D lenken, Shift schneller, Maus schaut um (Kamera hinter dem Boot). Fährt nur auf dem Meer
# (nicht an den Strand, nicht in den Steg). Lokal: Bug nach −Z, Wasserlinie bei y = 0.

const LANG := 17.0
const MAX := 15.0
const MAX_SCHNELL := 22.0
const RUECK := -4.0

var an_bord := false
var tempo := 0.0
var richtung := PI * 0.5        # rotation.y (PI/2 = Bug nach −x)
var cam: Camera3D
var blick := 0.0                 # Maus: Kamera um das Boot drehen
var blick_hoch := 0.2
var kielwasser: MeshInstance3D
var _kw_mat: ShaderMaterial
var _zeit := 0.0

func setup() -> void:
	add_child(bauen())
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.1
	cam.far = 40000.0
	add_child(cam)
	cam.top_level = true
	kielwasser = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(4.5, 1.0)
	qm.orientation = PlaneMesh.FACE_Y
	kielwasser.mesh = qm
	var sh := Shader.new()   # Kielwasser: Schaum, der nach hinten und zu den Rändern ausläuft
	sh.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float staerke = 0.0;
float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y); }
void fragment() {
	float rand = 1.0 - pow(abs(UV.x - 0.5) * 2.0, 2.0);
	float n = vn(vec2(UV.x * 8.0, UV.y * 30.0 + TIME * 3.0));
	ALBEDO = vec3(0.95, 0.98, 1.0);
	ALPHA = staerke * rand * (1.0 - UV.y) * (0.3 + 0.7 * n);
}"""
	_kw_mat = ShaderMaterial.new()
	_kw_mat.shader = sh
	kielwasser.material_override = _kw_mat
	kielwasser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(kielwasser)
	anlegen()

# zurück an den Liegeplatz
func anlegen() -> void:
	tempo = 0.0
	richtung = PI * 0.5
	position = Kueste.LIEGEPLATZ
	rotation = Vector3(0, richtung, 0)

func am_liegeplatz() -> bool:
	return Vector2(position.x - Kueste.LIEGEPLATZ.x, position.z - Kueste.LIEGEPLATZ.z).length() < 30.0 and absf(tempo) < 2.0

func vorne() -> Vector3:
	return Vector3(-sin(richtung), 0, -cos(richtung))

# weit draußen (seltene Fische beißen öfter)
func draussen() -> bool:
	return position.x < Kueste.WASSER_X - 150.0

# Wohin fliegt die Pose beim Angeln (vom Heck nach hinten)?
func angel_ziel() -> Vector3:
	var p := position - vorne() * (LANG * 0.5 + 9.0)
	return Vector3(p.x, Kueste.MEER_Y + 0.05, p.z)

func angel_xf() -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0.95, 0.0, 0.0)), Vector3(0.8, 1.9, LANG * 0.5 - 1.5))

func _frei(p: Vector3) -> bool:
	var q := Vector2(p.x, p.z)
	if q.x > Kueste.WASSER_X - 14.0 or q.x < -9000.0 or absf(q.y) > 5000.0:
		return false
	var steg := Rect2(Vector2(Kueste.STEG_ENDE - 2.0, Kueste.STEG_Z - Kueste.STEG_HALB - 3.0), Vector2(Kueste.UFER_X - Kueste.STEG_ENDE + 4.0, Kueste.STEG_HALB * 2.0 + 6.0))
	if steg.has_point(q) or Kueste.KOPF.grow(3.0).has_point(q):
		return false
	return true

func _process(dt: float) -> void:
	_zeit += dt
	if an_bord:
		var gas := 0.0
		if Input.is_key_pressed(KEY_W): gas += 1.0
		if Input.is_key_pressed(KEY_S): gas -= 1.0
		var lenk := 0.0
		if Input.is_key_pressed(KEY_A): lenk += 1.0
		if Input.is_key_pressed(KEY_D): lenk -= 1.0
		var maxi := MAX_SCHNELL if Input.is_key_pressed(KEY_SHIFT) else MAX
		if gas > 0.0:
			tempo = move_toward(tempo, maxi, 3.5 * dt)
		elif gas < 0.0:
			tempo = move_toward(tempo, RUECK, (5.0 if tempo > 0.0 else 2.0) * dt)
		else:
			tempo = move_toward(tempo, 0.0, 1.2 * dt)
		richtung += lenk * dt * clampf(absf(tempo) / 6.0, 0.15, 1.0) * 0.55 * signf(tempo if absf(tempo) > 0.1 else 1.0)
		var neu := position + vorne() * tempo * dt
		var bug := neu + vorne() * LANG * 0.5
		var heck := neu - vorne() * LANG * 0.5
		if _frei(neu) and _frei(bug) and _frei(heck):
			position = neu
		else:
			tempo = 0.0
	# schaukeln
	var wind := 1.0 + absf(tempo) * 0.04
	rotation = Vector3(sin(_zeit * 0.9) * 0.012 * wind - tempo * 0.0025, richtung, sin(_zeit * 0.7 + 1.0) * 0.018 * wind)
	position.y = Kueste.MEER_Y + sin(_zeit * 1.1) * 0.08
	# Kielwasser hinter dem Heck
	var k := clampf(absf(tempo) / MAX, 0.0, 1.0)
	_kw_mat.set_shader_parameter("staerke", 0.75 * k)
	kielwasser.scale = Vector3(1.0 + k * 0.6, 1.0, 2.0 + k * 26.0)
	kielwasser.position = Vector3(0, 0.03 - position.y + Kueste.MEER_Y, LANG * 0.5 + kielwasser.scale.z * 0.5)
	if an_bord:
		var hinten := Vector3(sin(richtung + blick), 0, cos(richtung + blick))
		var weit := 21.0
		cam.global_position = position + hinten * weit * cos(blick_hoch) + Vector3(0, 3.0 + weit * sin(blick_hoch), 0)
		cam.look_at(position + Vector3(0, 3.0, 0), Vector3.UP)

func maus(rel: Vector2) -> void:
	blick = wrapf(blick - rel.x * 0.004, -PI, PI)
	blick_hoch = clampf(blick_hoch + rel.y * 0.003, 0.08, 1.1)

# ---------------------------------------------------------------- Modell aus Code
static func bauen() -> Node3D:
	var n := Node3D.new()
	n.name = "YachtModell"
	var weiss := Bau.matt("f6f7f8", 0.35)
	var blau := Bau.matt("163a63", 0.4)
	var teak := Bau.matt("b78550", 0.7)
	var glas := Bau.metall("1b2733", 0.08, 0.6)
	var chrom := Bau.metall("e3e7ec", 0.2, 0.9)
	# Rumpf: Spanten von hinten (+z) nach vorne (−z): [z, halbe Breite, Deckhöhe, Kiel]
	var spanten := [[8.5, 2.35, 1.1, -0.85], [6.0, 2.5, 1.1, -1.0], [3.0, 2.55, 1.15, -1.1], [0.0, 2.5, 1.2, -1.1], [-3.0, 2.2, 1.3, -1.0],
		[-5.5, 1.6, 1.45, -0.7], [-7.5, 0.8, 1.6, -0.2], [-8.6, 0.05, 1.7, 0.6]]
	var oben := SurfaceTool.new()
	oben.begin(Mesh.PRIMITIVE_TRIANGLES)
	var unten := SurfaceTool.new()
	unten.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in spanten.size() - 1:
		var a: Array = spanten[i]
		var b: Array = spanten[i + 1]
		for s in [-1.0, 1.0]:
			var a_deck := Vector3(s * a[1], a[2], a[0])
			var b_deck := Vector3(s * b[1], b[2], b[0])
			var a_kimm := Vector3(s * a[1] * 0.92, 0.15, a[0])
			var b_kimm := Vector3(s * b[1] * 0.92, 0.15, b[0])
			var a_kiel := Vector3(0, a[3], a[0])
			var b_kiel := Vector3(0, b[3], b[0])
			_quad(oben, a_deck, b_deck, b_kimm, a_kimm, Vector3(s, 0.2, 0))
			_quad(unten, a_kimm, b_kimm, b_kiel, a_kiel, Vector3(s, -0.6, 0))
		_quad(deck, Vector3(-a[1], a[2], a[0]), Vector3(a[1], a[2], a[0]), Vector3(b[1], b[2], b[0]), Vector3(-b[1], b[2], b[0]), Vector3.UP)
	var h: Array = spanten[0]   # Heckspiegel
	_quad(oben, Vector3(-h[1], h[2], h[0]), Vector3(h[1], h[2], h[0]), Vector3(h[1] * 0.92, 0.15, h[0]), Vector3(-h[1] * 0.92, 0.15, h[0]), Vector3(0, 0, 1))
	_tri(unten, Vector3(-h[1] * 0.92, 0.15, h[0]), Vector3(h[1] * 0.92, 0.15, h[0]), Vector3(0, h[3], h[0]), Vector3(0, 0, 1))
	var rumpf: Array = []   # eigenes Vertex-Format (ohne UV) – nicht mit den Kästen verschmelzen, sonst fehlt er
	for st_m in [[oben, weiss], [unten, blau], [deck, teak]]:
		var mi := MeshInstance3D.new()
		mi.mesh = (st_m[0] as SurfaceTool).commit()
		mi.material_override = st_m[1]
		n.add_child(mi)
		rumpf.append(mi)
	# Zierstreifen, Badeplattform
	for s in [-1.0, 1.0]:
		var z := RaumBau.box(n, Vector3(0.04, 0.12, 13.0), Vector3(s * 2.48, 0.75, 1.5), blau)
		z.rotation.y = s * 0.02
	RaumBau.box(n, Vector3(4.4, 0.12, 1.2), Vector3(0, 0.3, 9.0), teak)
	# Aufbau: Kabine mit Fensterband, schräge Frontscheibe, Flybridge mit Geländer und Sitzen
	RaumBau.box(n, Vector3(3.8, 1.5, 7.0), Vector3(0, 1.95, 0.8), weiss)
	for s in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(0.04, 0.6, 5.6), Vector3(s * 1.91, 2.1, 0.9), glas)
	var front := RaumBau.box(n, Vector3(3.6, 1.2, 0.08), Vector3(0, 2.05, -2.85), glas)
	front.rotation.x = -0.55
	RaumBau.box(n, Vector3(3.9, 0.12, 6.2), Vector3(0, 2.76, 1.4), weiss)
	RaumBau.box(n, Vector3(3.2, 0.5, 1.6), Vector3(0, 3.07, 3.3), Bau.matt("e9eef2", 0.6))
	RaumBau.box(n, Vector3(1.0, 0.8, 0.6), Vector3(0.6, 3.2, 0.2), weiss)
	var schirm := RaumBau.box(n, Vector3(1.2, 0.4, 0.05), Vector3(0.6, 3.75, -0.12), glas)
	schirm.rotation.x = -0.4
	for s in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(0.04, 0.04, 5.6), Vector3(s * 1.9, 3.7, 1.6), chrom)
		for k in 6:
			RaumBau.box(n, Vector3(0.04, 0.9, 0.04), Vector3(s * 1.9, 3.25, -1.2 + k * 1.1), chrom)
	# Radarbügel
	for s in [-1.0, 1.0]:
		var b := RaumBau.box(n, Vector3(0.18, 1.6, 0.4), Vector3(s * 1.2, 3.6, 3.9), weiss)
		b.rotation.z = s * 0.25
	RaumBau.box(n, Vector3(2.6, 0.2, 0.45), Vector3(0, 4.35, 3.9), weiss)
	RaumBau.zyl(n, 0.35, 0.18, Vector3(0, 4.55, 3.9), Bau.matt("f4f4f4", 0.4), 16)
	# Reling am Vorschiff
	for s in [-1.0, 1.0]:
		var r := RaumBau.box(n, Vector3(0.035, 0.035, 6.0), Vector3(s * 1.55, 2.05, -5.0), chrom)
		r.rotation.y = s * 0.2
		for k in 5:
			var z := -2.6 - k * 1.3
			RaumBau.box(n, Vector3(0.035, 0.6, 0.035), Vector3(s * (2.2 - k * 0.32), 1.6 + k * 0.08, z), chrom)
	# Sonnenliegen auf dem Vorschiff
	for s in [-1.0, 1.0]:
		var l := RaumBau.box(n, Vector3(0.9, 0.15, 2.0), Vector3(s * 0.55, 1.55, -4.6), Bau.matt("eef2f6", 0.7))
		l.rotation.x = 0.08
	var name_l := RaumBau.schrift(n, "MEERESBRISE", Vector3(0, 0.75, 8.53), 0.0, 64, 0.01, Color("163a63"))
	name_l.rotation.y = 0.0
	RaumBau.verschmelzen(n, rumpf)
	return n

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	var nrm := (b - a).cross(c - a).normalized()
	if nrm.dot(n) < 0.0:
		nrm = -nrm
	var ecken := [a, b, c] if (c - a).cross(b - a).dot(nrm) > 0.0 else [a, c, b]
	for v in ecken:
		st.set_normal(nrm)
		st.add_vertex(v)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)
