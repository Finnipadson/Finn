class_name Yacht
extends Node3D
# Eigene Mega-Yacht „Meeresbrise“ (Belohnung für alle 20 Fische im Index, ~90 m): liegt längs am Stegkopf
# (Kueste.LIEGEPLATZ, Gangway bei Kueste.GANGWAY_X), mit E einsteigen, W/S Gas/rückwärts, A/D lenken, Shift schneller,
# Maus schaut um (Kamera weit hinter dem Schiff). Fährt nur auf dem Meer (nicht an den Strand, nicht in den Steg).
# Lokal: Bug nach −Z, Wasserlinie bei y = 0, Seite +X zeigt am Liegeplatz zum Steg (Seitentür für die Gangway).
# Modell aus Code (bauen()): schlanker silberner Rumpf mit geradem Bug, lange dunkle Fensterbänder, vier gestufte
# Decks mit Teak-Terrassen, offenes Heckdeck mit Pool, Liegen und Sonnenpolstern, Glasreling, dunkler Mast mit Radar.

const LANG := 90.0
const BREIT := 14.0
const DECK_HECK := 2.4          # Heck-/Pooldeck über der Wasserlinie (= Höhe des Stegs)
const DECK := 5.0               # Hauptdeck
const MAX := 12.0               # m/s (43 km/h)
const MAX_SCHNELL := 18.0       # mit Shift (65 km/h)
const RUECK := -3.0
const TUER_Z := 19.0
# Rumpf: Spanten von hinten (+z) nach vorne (−z): [z, halbe Breite, Deckhöhe, Kiel]; gerader, senkrechter Bug
const SPANTEN := [[45.0, 6.3, DECK_HECK, -1.4], [40.0, 6.85, DECK_HECK, -2.2], [30.3, 7.0, DECK_HECK, -2.8], [30.0, 7.0, DECK, -2.8],
	[15.0, 7.0, 5.1, -3.1], [-5.0, 7.0, 5.25, -3.2], [-20.0, 6.5, 5.5, -3.1], [-30.0, 5.4, 5.75, -2.8], [-38.0, 3.6, 5.95, -2.4],
	[-43.0, 1.6, 6.1, -2.2], [-45.0, 0.25, 6.2, -2.1]]            # Seitentür (lokal z) – liegt am Liegeplatz genau bei Kueste.GANGWAY_X

var an_bord := false
var tempo := 0.0
var richtung := PI * 0.5        # rotation.y (PI/2 = Bug nach −x)
var cam: Camera3D
var blick := 0.0                 # Maus: Kamera um das Schiff drehen
var blick_hoch := 0.22
var kielwasser: MeshInstance3D
var bugwellen: Array = []
var _kw_mat: ShaderMaterial
var _zeit := 0.0

func setup() -> void:
	add_child(bauen())
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.2
	cam.far = 40000.0
	add_child(cam)
	cam.top_level = true
	var sh := Shader.new()   # Kielwasser/Bugwelle: Schaum, der nach hinten und zu den Rändern ausläuft
	sh.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float staerke = 0.0;
float hs(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y); }
void fragment() {
	float rand = 1.0 - pow(abs(UV.x - 0.5) * 2.0, 2.0);
	float n = vn(vec2(UV.x * 10.0, UV.y * 40.0 + TIME * 3.0));
	ALBEDO = vec3(0.95, 0.98, 1.0);
	ALPHA = staerke * rand * (1.0 - UV.y) * (0.3 + 0.7 * n);
}"""
	_kw_mat = ShaderMaterial.new()
	_kw_mat.shader = sh
	kielwasser = _schaum(Vector2(BREIT * 0.85, 1.0))
	for s in [-1.0, 1.0]:
		bugwellen.append(_schaum(Vector2(3.5, 1.0)))
	anlegen()

func _schaum(g: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = g
	qm.orientation = PlaneMesh.FACE_Y
	mi.mesh = qm
	mi.material_override = _kw_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

# zurück an den Liegeplatz
func anlegen() -> void:
	tempo = 0.0
	richtung = PI * 0.5
	position = Kueste.LIEGEPLATZ
	rotation = Vector3(0, richtung, 0)

func am_liegeplatz() -> bool:
	return Vector2(position.x - Kueste.LIEGEPLATZ.x, position.z - Kueste.LIEGEPLATZ.z).length() < 45.0 and absf(tempo) < 2.0

func vorne() -> Vector3:
	return Vector3(-sin(richtung), 0, -cos(richtung))

func quer() -> Vector3:
	return Vector3(cos(richtung), 0, -sin(richtung))

# weit draußen (seltene Fische beißen öfter)
func draussen() -> bool:
	return position.x < Kueste.WASSER_X - 150.0

# Wohin fliegt die Pose beim Angeln (vom Heck nach hinten)?
func angel_ziel() -> Vector3:
	var p := position - vorne() * (LANG * 0.5 + 10.0)
	return Vector3(p.x, Kueste.MEER_Y + 0.05, p.z)

# Angel in der Hand am Heck (hinter den Sonnenpolstern, an der Reling)
func angel_xf() -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0.95, 0.0, 0.0)), Vector3(1.2, DECK_HECK + 1.0, LANG * 0.5 - 0.6))

func _frei(p: Vector3) -> bool:
	var q := Vector2(p.x, p.z)
	if q.x > Kueste.WASSER_X - 14.0 or q.x < -9000.0 or absf(q.y) > 5000.0:
		return false
	var steg := Rect2(Vector2(Kueste.STEG_ENDE - 2.0, Kueste.STEG_Z - Kueste.STEG_HALB - 3.0), Vector2(Kueste.UFER_X - Kueste.STEG_ENDE + 4.0, Kueste.STEG_HALB * 2.0 + 6.0))
	if steg.has_point(q) or Kueste.KOPF.grow(1.0).has_point(q):
		return false
	return true

# ganzer Rumpf frei? (Bug, Heck, Mitte und die Seiten vorne/mitte/hinten)
func _rumpf_frei(m: Vector3) -> bool:
	var v := vorne()
	var s := quer() * (BREIT * 0.5 - 0.5)
	for p in [m, m + v * LANG * 0.5, m - v * LANG * 0.5, m + s, m - s, m + v * LANG * 0.3 + s * 0.7, m + v * LANG * 0.3 - s * 0.7,
			m - v * LANG * 0.45 + s, m - v * LANG * 0.45 - s]:
		if not _frei(p):
			return false
	return true

func _process(dt: float) -> void:
	_zeit += dt
	if an_bord:
		var gas := 0.0
		if Optionen.gedrueckt(KEY_W): gas += 1.0
		if Optionen.gedrueckt(KEY_S): gas -= 1.0
		var lenk := 0.0
		if Optionen.gedrueckt(KEY_A): lenk += 1.0
		if Optionen.gedrueckt(KEY_D): lenk -= 1.0
		var maxi := MAX_SCHNELL if Optionen.gedrueckt(KEY_SHIFT) else MAX
		if gas > 0.0:
			tempo = move_toward(tempo, maxi, 2.6 * dt)
		elif gas < 0.0:
			tempo = move_toward(tempo, RUECK, (3.5 if tempo > 0.0 else 1.5) * dt)
		else:
			tempo = move_toward(tempo, 0.0, 0.9 * dt)
		var alt := richtung
		richtung += lenk * dt * clampf(absf(tempo) / 6.0, 0.15, 1.0) * 0.28 * signf(tempo if absf(tempo) > 0.1 else 1.0)
		var neu := position + vorne() * tempo * dt
		if not _rumpf_frei(neu):
			richtung = alt   # Drehen geht nicht (Heck schwenkt z. B. in den Steg): erst einmal geradeaus weiter
			neu = position + vorne() * tempo * dt
		if _rumpf_frei(neu):
			position = neu
		else:
			tempo = 0.0
	# schaukeln (ein großes Schiff nur sanft)
	var wind := 1.0 + absf(tempo) * 0.03
	rotation = Vector3(sin(_zeit * 0.5) * 0.004 * wind - tempo * 0.0008, richtung, sin(_zeit * 0.4 + 1.0) * 0.007 * wind)
	position.y = Kueste.MEER_Y + sin(_zeit * 0.6) * 0.06
	# Kielwasser hinter dem Heck, Bugwellen schräg nach hinten
	var k := clampf(absf(tempo) / MAX, 0.0, 1.0)
	_kw_mat.set_shader_parameter("staerke", 0.8 * k)
	var wy := 0.03 - position.y + Kueste.MEER_Y
	kielwasser.scale = Vector3(1.0 + k * 0.5, 1.0, 4.0 + k * 90.0)
	kielwasser.position = Vector3(0, wy, LANG * 0.5 + kielwasser.scale.z * 0.5)
	for i in bugwellen.size():
		var s := -1.0 if i == 0 else 1.0
		var b: MeshInstance3D = bugwellen[i]
		var l := 4.0 + k * 45.0
		b.scale = Vector3(1.0 + k, 1.0, l)
		b.rotation = Vector3(0, s * 0.32, 0)
		b.position = Vector3(s * 0.8, wy + 0.01, -LANG * 0.5 + 0.5) + Vector3(sin(s * 0.32), 0, cos(s * 0.32)) * l * 0.5
	if an_bord:
		var hinten := Vector3(sin(richtung + blick), 0, cos(richtung + blick))
		var weit := 78.0
		cam.global_position = position + hinten * weit * cos(blick_hoch) + Vector3(0, 9.0 + weit * sin(blick_hoch), 0)
		cam.look_at(position + Vector3(0, 8.0, 0), Vector3.UP)

func maus(rel: Vector2) -> void:
	blick = wrapf(blick - rel.x * 0.004 * Optionen.maus_x(), -PI, PI)
	blick_hoch = clampf(blick_hoch + rel.y * 0.003 * Optionen.maus_y(), 0.06, 1.1)

# ---------------------------------------------------------------- Modell aus Code
static func bauen() -> Node3D:
	var n := Node3D.new()
	n.name = "YachtModell"
	var silber := Bau.metall("bcc2c8", 0.3, 0.5)
	var weiss := Bau.matt("eef0f2", 0.35)
	var dunkel := Bau.metall("3a4048", 0.3, 0.5)
	var unter := Bau.matt("2c333b", 0.6)
	var teak := Bau.matt("b98652", 0.7)
	var teak2 := Bau.matt("a87545", 0.72)
	var glas := Bau.metall("121a22", 0.06, 0.7)
	var reling := RaumBau.glas("d6ecf7", 0.22)
	var chrom := Bau.metall("e3e7ec", 0.2, 0.9)
	var polster := Bau.matt("f3f1ec", 0.85)
	var polster2 := Bau.matt("9aa4ad", 0.85)
	# ---- Rumpf aus SPANTEN
	var spanten := SPANTEN
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
			var pa := _profil(a, s)
			var pb := _profil(b, s)
			_quad(oben, pa[0], pb[0], pb[1], pa[1], Vector3(s, 0.05, 0))     # senkrechte Bordwand (silber)
			_quad(unten, pa[1], pb[1], pb[2], pa[2], Vector3(s, -0.4, 0))
			_quad(unten, pa[2], pb[2], pb[3], pa[3], Vector3(s * 0.4, -1.0, 0))
		_quad(deck, Vector3(-a[1], a[2], a[0]), Vector3(a[1], a[2], a[0]), Vector3(b[1], b[2], b[0]), Vector3(-b[1], b[2], b[0]), Vector3.UP)
	var h: Array = spanten[0]   # Heckspiegel
	var ph_l := _profil(h, -1.0)
	var ph_r := _profil(h, 1.0)
	_quad(oben, ph_l[0], ph_r[0], ph_r[1], ph_l[1], Vector3(0, 0, 1))
	_quad(unten, ph_l[1], ph_r[1], ph_r[2], ph_l[2], Vector3(0, 0, 1))
	_tri(unten, ph_l[2], ph_r[2], Vector3(0, h[3], h[0]), Vector3(0, 0, 1))
	var v: Array = spanten[spanten.size() - 1]   # Bug: schmale senkrechte Fläche
	var pv_l := _profil(v, -1.0)
	var pv_r := _profil(v, 1.0)
	_quad(oben, pv_l[0], pv_r[0], pv_r[1], pv_l[1], Vector3(0, 0, -1))
	_quad(unten, pv_l[1], pv_r[1], pv_r[2], pv_l[2], Vector3(0, 0, -1))
	var rumpf: Array = []   # eigenes Vertex-Format (ohne UV) – nicht mit den Kästen verschmelzen, sonst fehlt er
	for st_m in [[oben, silber], [unten, unter], [deck, teak]]:
		var mi := MeshInstance3D.new()
		mi.mesh = (st_m[0] as SurfaceTool).commit()
		mi.material_override = st_m[1]
		n.add_child(mi)
		rumpf.append(mi)
	# Stufe Heckdeck → Hauptdeck (weiße Wand) + Treppen an beiden Seiten
	RaumBau.box(n, Vector3(BREIT - 0.1, DECK - DECK_HECK, 0.3), Vector3(0, (DECK + DECK_HECK) * 0.5, 30.15), weiss)
	for s in [-1.0, 1.0]:
		for k in 8:
			RaumBau.box(n, Vector3(1.3, (k + 1) * (DECK - DECK_HECK) / 8.0, 0.36), Vector3(s * 5.9, DECK_HECK + (k + 1) * (DECK - DECK_HECK) / 16.0, 30.3 + 2.88 - k * 0.36 + 0.18), teak2 if k % 2 == 0 else teak)
	# Badeplattform am Heck
	RaumBau.box(n, Vector3(10.5, 0.25, 2.2), Vector3(0, 0.55, 46.0), teak)
	# ---- lange dunkle Fensterbänder in der Bordwand (beide Seiten), kleine Fenster hinten, Schlitze am Bug, Seitentür
	for s in [-1.0, 1.0]:
		_band(n, s, 3.4, Vector3(0.05, 1.3, 0), -31.0, 26.0, glas)        # langes Fensterband (Unterdeck)
		_band(n, s, 1.55, Vector3(0.05, 0.5, 0), -24.0, 18.0, glas)       # schmales Band darunter
		_band(n, s, DECK - 0.25, Vector3(0.06, 0.12, 0), -44.0, 29.8, dunkel)   # Zierlinie am Deck
		for k in 3:
			RaumBau.box(n, Vector3(0.05, 0.9, 1.6), Vector3(s * 7.02, 1.5, 30.0 + k * 2.6), glas)
		for k in 3:   # drei senkrechte Schlitze vorne
			var zs := -34.0 - k * 0.9
			_band(n, s, 3.4, Vector3(0.05, 1.1, 0), zs - 0.18, zs + 0.18, glas)
	RaumBau.box(n, Vector3(0.06, 2.2, 1.8), Vector3(7.03, DECK_HECK + 1.1, TUER_Z), Bau.matt("1d252d", 0.4))
	# ---- Aufbauten: vier gestufte Decks [z vorne, z hinten, halbe Breite, unten, oben, Dach hinten bis z, Terrasse ab z]
	var ebenen := [[-27.0, 27.0, 6.4, DECK, 8.4, 29.0, 17.0], [-21.0, 17.0, 5.8, 8.75, 11.9, 19.0, 9.0], [-15.0, 9.0, 5.0, 12.25, 15.0, 11.0, 2.0],
		[-10.0, 0.0, 3.6, 15.35, 17.1, 1.0, 99.0]]
	for i in ebenen.size():
		var e: Array = ebenen[i]
		var z0: float = e[0]
		var z1: float = e[1]
		var hb: float = e[2]
		var y0: float = e[3]
		var y1: float = e[4]
		var lz := z1 - z0
		# Wand (weiß), umlaufendes dunkles Fensterband, vorne schräge Glasfront
		RaumBau.box(n, Vector3(hb * 2.0, y1 - y0, lz - 2.0), Vector3(0, (y0 + y1) * 0.5, (z0 + 2.0 + z1) * 0.5), weiss)
		var bandh := (y1 - y0) * (0.62 if i < 3 else 0.8)
		var bandy := y0 + (y1 - y0) * 0.5 + (0.1 if i < 3 else 0.0)
		for s in [-1.0, 1.0]:
			RaumBau.box(n, Vector3(0.05, bandh, lz - 3.5), Vector3(s * (hb + 0.02), bandy, (z0 + 2.5 + z1 - 1.0) * 0.5), glas)
			if i < 3:   # Teakholz-Paneele zwischen den Fensterabschnitten (wie beim Vorbild)
				for k in 2:
					RaumBau.box(n, Vector3(0.07, bandh + 0.02, 1.4), Vector3(s * (hb + 0.03), bandy, lerpf(z0 + 2.5, z1 - 1.0, 0.33 + k * 0.33)), teak2)
		RaumBau.box(n, Vector3(hb * 2.0 - 0.6, bandh, 0.05), Vector3(0, bandy, z1 + 0.02), glas)
		var front := RaumBau.box(n, Vector3(hb * 2.0 - 0.2, (y1 - y0) / cos(0.45), 0.08), Vector3(0, (y0 + y1) * 0.5, z0 + 1.2), glas)
		front.rotation.x = 0.45   # oben nach hinten geneigt
		for s in [-1.0, 1.0]:   # Seitenteile der Glasfront
			RaumBau.box(n, Vector3(0.1, y1 - y0, 2.0), Vector3(s * (hb - 0.05), (y0 + y1) * 0.5, z0 + 1.0), weiss)
		# Dach mit dunkler Kante, ragt vorne und hinten über; hinten Teak-Terrasse auf dem Dach
		var dz0 := z0 - 0.4
		var dz1: float = e[5]
		var dach_hb := hb + (0.4 if i < 3 else 1.2)
		RaumBau.box(n, Vector3(dach_hb * 2.0, 0.35, dz1 - dz0), Vector3(0, y1 + 0.175, (dz0 + dz1) * 0.5), dunkel if i == 3 else weiss)
		for s in [-1.0, 1.0]:
			RaumBau.box(n, Vector3(0.08, 0.36, dz1 - dz0), Vector3(s * (dach_hb + 0.03), y1 + 0.175, (dz0 + dz1) * 0.5), dunkel)
		RaumBau.box(n, Vector3(dach_hb * 2.0, 0.36, 0.08), Vector3(0, y1 + 0.175, dz0 - 0.03), dunkel)
		var tz: float = e[6]
		if tz < dz1:
			RaumBau.box(n, Vector3(dach_hb * 2.0 - 0.3, 0.04, dz1 - tz - 0.2), Vector3(0, y1 + 0.37, (tz + dz1) * 0.5), teak)
			# Glasreling um die Terrasse
			for s in [-1.0, 1.0]:
				RaumBau.box(n, Vector3(0.04, 1.0, dz1 - tz), Vector3(s * (dach_hb - 0.1), y1 + 0.85, (tz + dz1) * 0.5), reling)
				RaumBau.box(n, Vector3(0.07, 0.06, dz1 - tz), Vector3(s * (dach_hb - 0.1), y1 + 1.38, (tz + dz1) * 0.5), chrom)
			RaumBau.box(n, Vector3(dach_hb * 2.0 - 0.2, 1.0, 0.04), Vector3(0, y1 + 0.85, dz1 - 0.1), reling)
			RaumBau.box(n, Vector3(dach_hb * 2.0 - 0.2, 0.06, 0.07), Vector3(0, y1 + 1.38, dz1 - 0.1), chrom)
			# Lounge: U-Sofa mit Tisch und zwei Sesseln
			var lz2 := (tz + dz1) * 0.5 + 0.5
			var ly := y1 + 0.39
			for s in [-1.0, 1.0]:
				RaumBau.box(n, Vector3(0.9, 0.45, 3.4), Vector3(s * 2.4, ly + 0.22, lz2), polster)
				RaumBau.box(n, Vector3(0.25, 0.5, 3.4), Vector3(s * 2.8, ly + 0.6, lz2), polster)
				RaumBau.box(n, Vector3(0.9, 0.45, 0.9), Vector3(s * 1.2, ly + 0.22, lz2 + 2.4), polster2)
			RaumBau.box(n, Vector3(3.9, 0.45, 0.9), Vector3(0, ly + 0.22, lz2 - 1.6), polster)
			RaumBau.box(n, Vector3(1.6, 0.4, 1.6), Vector3(0, ly + 0.2, lz2 + 0.2), teak2)
	# Whirlpool auf der obersten Terrasse (Deck 3, hinter dem Hardtop)
	var jac_y := 15.0 + 0.39
	RaumBau.zyl(n, 1.25, 0.5, Vector3(0.0, jac_y + 0.25, 3.4), weiss, 20)
	RaumBau.zyl(n, 1.05, 0.04, Vector3(0.0, jac_y + 0.5, 3.4), RaumBau.leuchte("3fc9dc", 0.35), 20)
	# ---- Hardtop oben + dunkler Mast mit Radar (wie beim Vorbild)
	var top_y := 17.1 + 0.35
	RaumBau.box(n, Vector3(2.2, 2.4, 2.6), Vector3(0, top_y + 1.2, -5.0), dunkel)
	var mast := RaumBau.zyl(n, 0.32, 5.5, Vector3(0, top_y + 5.1, -5.4), dunkel, 10, 0.75)
	mast.rotation.x = -0.12
	RaumBau.box(n, Vector3(4.6, 0.25, 0.5), Vector3(0, top_y + 4.0, -5.2), dunkel)
	for s in [-1.0, 1.0]:
		Andenken._kugel_mesh(n, 0.7, Vector3(s * 1.9, top_y + 4.75, -5.2), Bau.matt("f4f4f4", 0.4), 14)
		RaumBau.zyl(n, 0.05, 1.4, Vector3(s * 1.1, top_y + 6.3, -5.6), dunkel, 6)
	RaumBau.zyl(n, 0.04, 3.0, Vector3(0, top_y + 9.2, -5.9), dunkel, 6)
	RaumBau.box(n, Vector3(1.8, 0.12, 0.4), Vector3(0, top_y + 7.0, -5.7), dunkel)   # Querbalken mit Antennen
	# ---- Vorschiff: Teak (vom Rumpf), Sonnenpolster, Glasreling an der Bordkante
	for s in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(2.4, 0.35, 4.2), Vector3(s * 1.4, 5.85, -32.5), polster)
		RaumBau.box(n, Vector3(2.4, 0.12, 0.6), Vector3(s * 1.4, 6.08, -30.6), polster2)
	RaumBau.box(n, Vector3(5.6, 0.5, 1.2), Vector3(0, 5.8, -28.6), polster)
	for i in range(4, spanten.size() - 1):
		var a: Array = spanten[i]
		var b: Array = spanten[i + 1]
		if float(a[0]) > -27.0:
			continue
		for s in [-1.0, 1.0]:
			var pa := Vector3(s * (float(a[1]) - 0.1), float(a[2]) + 0.55, a[0])
			var pb := Vector3(s * (float(b[1]) - 0.1), float(b[2]) + 0.55, b[0])
			_stab(n, pa, pb, Vector3(0.04, 1.0, 1.0), reling)
			_stab(n, pa + Vector3(0, 0.52, 0), pb + Vector3(0, 0.52, 0), Vector3(0.06, 0.06, 1.0), chrom)
	# Seitendeck-Reling am Hauptdeck (zwischen Aufbau und Bordkante) + Heckdeck-Reling
	for s in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(0.04, 1.0, 57.0), Vector3(s * 6.9, DECK + 0.6, 1.5), reling)
		RaumBau.box(n, Vector3(0.06, 0.06, 57.0), Vector3(s * 6.9, DECK + 1.12, 1.5), chrom)
		RaumBau.box(n, Vector3(0.04, 1.0, 13.5), Vector3(s * 6.7, DECK_HECK + 0.55, 37.4), reling)
		RaumBau.box(n, Vector3(0.06, 0.06, 13.5), Vector3(s * 6.7, DECK_HECK + 1.07, 37.4), chrom)
		RaumBau.box(n, Vector3(4.0, 1.0, 0.04), Vector3(s * 4.2, DECK_HECK + 0.55, 44.6), reling)
	# ---- offenes Heckdeck: Pool mit weißem Rand, Liegen, Sonnenpolster am Heck
	for s in [-1.0, 1.0]:   # Pool-Rand (weiß), Wasser innen etwas tiefer
		RaumBau.box(n, Vector3(0.4, 0.25, 6.6), Vector3(s * 2.6, DECK_HECK + 0.125, 37.0), weiss)
		RaumBau.box(n, Vector3(5.6, 0.25, 0.4), Vector3(0, DECK_HECK + 0.125, 37.0 + s * 3.1), weiss)
	RaumBau.box(n, Vector3(4.8, 0.04, 5.8), Vector3(0, DECK_HECK + 0.16, 37.0), RaumBau.leuchte("39c6d8", 0.35))
	for s in [-1.0, 1.0]:
		for k in 3:
			var lz := 33.5 + k * 2.6
			RaumBau.box(n, Vector3(0.8, 0.3, 1.9), Vector3(s * 4.6, DECK_HECK + 0.15, lz + 0.3), weiss)
			RaumBau.box(n, Vector3(0.72, 0.1, 1.3), Vector3(s * 4.6, DECK_HECK + 0.35, lz + 0.6), polster)
			var lehne := RaumBau.box(n, Vector3(0.72, 0.1, 0.7), Vector3(s * 4.6, DECK_HECK + 0.52, lz - 0.35), polster)
			lehne.rotation.x = 0.6
	RaumBau.box(n, Vector3(8.4, 0.4, 2.6), Vector3(0, DECK_HECK + 0.2, 42.4), polster)
	RaumBau.box(n, Vector3(8.4, 0.6, 0.35), Vector3(0, DECK_HECK + 0.5, 41.0), polster2)
	# ---- Hauptdeck achtern (vor der Stufe): Esstisch mit Stühlen unter dem Dachüberstand
	RaumBau.box(n, Vector3(1.4, 0.75, 3.6), Vector3(0, DECK + 0.375, 28.2), teak2)
	for s in [-1.0, 1.0]:
		for k in 3:
			RaumBau.box(n, Vector3(0.5, 0.5, 0.5), Vector3(s * 1.1, DECK + 0.25, 27.0 + k * 1.2), polster2)
	# Name am Heck
	var name_l := RaumBau.schrift(n, "MEERESBRISE", Vector3(0, 1.4, 45.05), 0.0, 96, 0.018, Color("3a4048"))
	name_l.rotation.y = 0.0
	RaumBau.verschmelzen(n, rumpf)
	return n

# halbe Rumpfbreite bei z (zwischen den Spanten interpoliert)
static func hb_bei(z: float) -> float:
	for i in SPANTEN.size() - 1:
		var a: Array = SPANTEN[i]
		var b: Array = SPANTEN[i + 1]
		if z <= float(a[0]) and z >= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (float(a[0]) - z) / maxf(float(a[0]) - float(b[0]), 0.001))
	return 0.0

# Band auf der Bordwand (Seite s, Höhe y) von z0 bis z1, folgt der Rumpfform (Stücke zwischen den Spanten)
static func _band(n: Node3D, s: float, y: float, g: Vector3, z0: float, z1: float, m: Material) -> void:
	var zs := [z0]
	for sp in SPANTEN:
		if float(sp[0]) > z0 and float(sp[0]) < z1:
			zs.append(float(sp[0]))
	zs.append(z1)
	zs.sort()
	for i in zs.size() - 1:
		var a := Vector3(s * (hb_bei(zs[i]) + 0.02), y, zs[i])
		var b := Vector3(s * (hb_bei(zs[i + 1]) + 0.02), y, zs[i + 1])
		_stab(n, a, b, g, m)

# Querschnitt eines Spants auf Seite s: Deckkante, Bordwand unten (knapp über Wasser), Kimm, Kiel
static func _profil(sp: Array, s: float) -> Array:
	var z: float = sp[0]
	var hb: float = sp[1]
	return [Vector3(s * hb, sp[2], z), Vector3(s * hb, 0.35, z), Vector3(s * hb * 0.78, float(sp[3]) * 0.5, z), Vector3(0, sp[3], z)]

# Kasten von a nach b (g.z wird durch die Länge ersetzt)
static func _stab(n: Node3D, a: Vector3, b: Vector3, g: Vector3, m: Material) -> void:
	var mi := RaumBau.box(n, Vector3(g.x, g.y, a.distance_to(b) + 0.02), (a + b) * 0.5, m)
	mi.basis = Basis.looking_at(b - a, Vector3.UP)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	var nrm := (b - a).cross(c - a).normalized()
	if nrm.length() < 0.5:
		return
	if nrm.dot(n) < 0.0:
		nrm = -nrm
	var ecken := [a, b, c] if (c - a).cross(b - a).dot(nrm) > 0.0 else [a, c, b]
	for v in ecken:
		st.set_normal(nrm)
		st.add_vertex(v)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)
