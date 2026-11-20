class_name Turm
extends Node3D
# Die „Wüstennadel“: Y-Grundriss mit spiralförmigen Stufen, Glas mit Räumen dahinter, echte Rahmen, Spitze.
# Kennt außerdem jedes Fenster: Nummerierung pro Stockwerk und Positionen auf der Fassade (für Gondel + Putzen).

const STOCK_H := 4.2          # Höhe eines Stockwerks (m)
const STOCKWERKE := 168
const FENSTER_B := 1.5        # Fensterbreite (m) – muss zum Shader-Parameter passen
const BAND_ANTEIL := 0.22     # Brüstung unten im Stockwerk
const BREITE := 27.0          # Flügelbreite unten
const KERN := 15.0            # Radius des Kerns
const FLUEGEL_START := 60.0   # Flügellänge unten
const STUFE_AB := 18          # ab diesem Stockwerk beginnen die Stufen
const STUFE_ALLE := 6         # alle 6 Stockwerke wird ein Flügel kürzer
const STUFE_UM := 5.5         # um so viele Meter

var stockwerke: Array = []                 # [{poly, y0, h}]
var umfaenge := PackedFloat32Array()       # Umfang je Stockwerk (m)
var fenster_pro_stock := PackedInt32Array()
var fenster_basis := PackedInt32Array()    # Nummer des ersten Fensters je Stockwerk
var fenster_gesamt := 0
var oben := 0.0                            # Dachhöhe ohne Spitze
var spitze := 0.0                          # Höhe inkl. Spitze
var glas: ShaderMaterial
var spitze_glas: ShaderMaterial            # Glas der Spitze (gleicher Shader, ohne Spielzustand, sauber)
# Drei Seiten (je ein Flügel, Grenzen in den Lücken bei −30°, 90°, 210°): je Stockwerk [Vector2(Start-Weg, Länge)] für Seite 0..2
const SEITEN_WINKEL := [-90.0, 30.0, 150.0]
const SEITEN_NAMEN := ["Nord", "Ost", "West"]
var seiten: Array = []
var seiten_spalten: Array = []   # je Stockwerk: [PackedInt32Array] Fensterspalten je Seite

func _ready() -> void:
	_grundrisse()
	_fenster_zaehlen()
	_seiten_berechnen()
	glas = Bau.shader_mat(Bau.TURM_SHADER, {"glas_tint": Color("4d7397"), "paneel": Color("9aa4ae"), "stock": STOCK_H, "fenster_breite": FENSTER_B, "band_anteil": BAND_ANTEIL})
	add_child(Bau.baue(stockwerke, glas, Bau.matt("c9c4bb")))
	var rahmen_mat := Bau.shader_mat(load("res://shader/rahmen.gdshader"), {"farbe": Color("c9ced4"), "fern_farbe": Color("7d8c9c")})
	add_child(Bau.rahmen(stockwerke, FENSTER_B, BAND_ANTEIL, rahmen_mat))
	_spitze(rahmen_mat)
	_terrassen()
	if not "--ohne-bodenlicht" in OS.get_cmdline_user_args():   # Vergleichs-Schalter
		_bodenstrahler([glas, rahmen_mat])

# Terrassen auf den Rücksprüngen der Flügel (20.11.2026, alte Notiz „schlichte Dächer ohne Deko“): Glasgeländer entlang
# der alten Flügelspitze, dazu je Terrasse abwechselnd Liegen mit Sonnenschirm oder Pflanzkübel mit Bäumchen und Bank.
# Alles in wenigen MultiMeshes (Farbe je Instanz), ohne Schatten, nur in Gondelnähe sichtbar.
func _terrassen() -> void:
	var laengen := [FLUEGEL_START, FLUEGEL_START, FLUEGEL_START]
	var teile := {"box": [], "zyl": [], "kegel": [], "kugel": []}
	var nr := 0
	for f in STOCKWERKE:
		if f >= STUFE_AB and (f - STUFE_AB) % STUFE_ALLE == 0:
			var w := ((f - STUFE_AB) / STUFE_ALLE) % 3
			var alt: float = laengen[w]
			laengen[w] = maxf(KERN, alt - STUFE_UM)
			if laengen[w] <= KERN + 1.0 or laengen.max() <= KERN + 0.5:
				continue
			var b := BREITE * (1.0 - ((f - 1) - (f - 1) % STUFE_ALLE) / 420.0)
			_terrasse(teile, w, alt, float(laengen[w]), b, f * STOCK_H, nr)
			nr += 1
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.6
	for form in teile:
		var liste: Array = teile[form]
		if liste.is_empty():
			continue
		var mesh: Mesh
		match form:
			"zyl", "kegel":
				var c := CylinderMesh.new()
				c.top_radius = 0.0 if form == "kegel" else 0.5
				c.bottom_radius = 0.5
				c.height = 1.0
				c.radial_segments = 12
				c.rings = 1
				mesh = c
			"kugel":
				var k := SphereMesh.new()
				k.radius = 0.5
				k.height = 1.0
				k.radial_segments = 10
				k.rings = 6
				mesh = k
			_:
				var bm := BoxMesh.new()
				bm.size = Vector3.ONE
				mesh = bm
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = liste.size()
		for i in liste.size():
			mm.set_instance_transform(i, liste[i][0])
			mm.set_instance_color(i, liste[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

func _terrasse(teile: Dictionary, w: int, l_alt: float, l_neu: float, b: float, y: float, nr: int) -> void:
	var a := TAU * w / 3.0 - PI / 2.0
	var d := Vector2(cos(a), sin(a))
	var q := Vector2(-d.y, d.x)
	var r := b * 0.5
	var m_alt := d * (l_alt - r)
	var m_neu := d * (l_neu - r)
	var glas := Color("bcd6e0")
	var alu := Color("c9ced4")
	# Geländer: Bogen der alten Flügelspitze + gerade Stücke an den Seiten bis zur neuen Wand
	var punkte: Array = []
	for j in 13:
		var t := -PI / 2.0 + PI * j / 12.0
		punkte.append(m_alt + (d * cos(t) + q * sin(t)) * (r - 0.15))
	var zuege: Array = []
	for j in 12:
		zuege.append([punkte[j], punkte[j + 1]])
	for s in [-1.0, 1.0]:
		zuege.append([m_neu + q * s * (r - 0.15), m_alt + q * s * (r - 0.15)])
	for z in zuege:
		var p0: Vector2 = z[0]
		var p1: Vector2 = z[1]
		var mitte := (p0 + p1) * 0.5
		var lang := p0.distance_to(p1) + 0.05
		var gier := atan2(p1.x - p0.x, p1.y - p0.y)
		var basis := Basis(Vector3.UP, gier)
		teile.box.append([Transform3D(basis * Basis.from_scale(Vector3(0.05, 1.05, lang)), Vector3(mitte.x, y + 0.53, mitte.y)), glas])
		teile.box.append([Transform3D(basis * Basis.from_scale(Vector3(0.09, 0.07, lang)), Vector3(mitte.x, y + 1.08, mitte.y)), alu])
	# Möblierung auf dem Halbmond zwischen alter und neuer Spitze
	var ort := func(t: float, rr: float) -> Vector2:
		return m_alt + (d * cos(t) + q * sin(t)) * rr
	var mitte_p: Vector2 = ort.call(0.0, r - 1.6)
	_kuebel_baum(teile, mitte_p, y)
	for s in [-1.0, 1.0]:
		var p: Vector2 = ort.call(s * 0.75, r - 2.0)
		var raus := (p - m_alt).normalized()
		var gier := atan2(raus.x, raus.y)
		if nr % 2 == 0:   # zwei Liegen + Sonnenschirm
			for k in [-0.55, 0.55]:
				var seit: Vector2 = Vector2(raus.y, -raus.x) * float(k)
				teile.box.append([Transform3D(Basis(Vector3.UP, gier) * Basis.from_scale(Vector3(0.65, 0.3, 1.9)), Vector3(p.x + seit.x, y + 0.15, p.y + seit.y)), Color("f2f2ee")])
				teile.box.append([Transform3D(Basis(Vector3.UP, gier) * Basis(Vector3.RIGHT, -0.6) * Basis.from_scale(Vector3(0.65, 0.08, 0.7)), Vector3(p.x + seit.x - raus.x * 0.75, y + 0.5, p.y + seit.y - raus.y * 0.75)), Color("f2f2ee")])
			var sp := p - raus * 1.6
			teile.zyl.append([Transform3D(Basis.from_scale(Vector3(0.08, 2.3, 0.08)), Vector3(sp.x, y + 1.15, sp.y)), alu])
			teile.kegel.append([Transform3D(Basis.from_scale(Vector3(2.8, 0.5, 2.8)), Vector3(sp.x, y + 2.35, sp.y)), [Color("d9644f"), Color("4f93c4"), Color("e8b33c")][(nr / 2) % 3]])
		else:   # Bank + kleiner Kübel
			teile.box.append([Transform3D(Basis(Vector3.UP, gier + PI * 0.5) * Basis.from_scale(Vector3(1.8, 0.45, 0.5)), Vector3(p.x, y + 0.23, p.y)), Color("a8744a")])
			_kuebel_baum(teile, p + Vector2(raus.y, -raus.x) * 1.6, y, 0.7)

func _kuebel_baum(teile: Dictionary, p: Vector2, y: float, s := 1.0) -> void:
	teile.box.append([Transform3D(Basis.from_scale(Vector3(1.1, 0.7, 1.1) * s), Vector3(p.x, y + 0.35 * s, p.y)), Color("d6d0c4")])
	teile.zyl.append([Transform3D(Basis.from_scale(Vector3(0.14, 1.4, 0.14) * s), Vector3(p.x, y + (0.7 + 0.7) * s, p.y)), Color("7a5a3c")])
	teile.kugel.append([Transform3D(Basis.from_scale(Vector3(1.6, 1.4, 1.6) * s), Vector3(p.x, y + 2.3 * s, p.y)), Color("4f7d3a")])

# Bodenstrahler rund um den Turmfuß (19.11.2026): je ~8 m eine Leuchte im Boden, die Shader von Glas und Rahmen zeichnen
# die Lichtkegel an der Fassade (gleiche Winkel, siehe strahler_licht in turm/rahmen.gdshader)
var strahler_n := 0
func _bodenstrahler(mats: Array) -> void:
	var poly: PackedVector2Array = stockwerke[0].poly
	strahler_n = maxi(12, int(round(umfaenge[0] / 8.0)))
	var bl := Bodenlicht.new()
	bl.name = "bodenstrahler"
	add_child(bl)
	var m := Bau.mitte(poly)
	for k in strahler_n:
		var a := TAU * k / strahler_n
		var dir := Vector2(cos(a), sin(a))
		var best := -1.0
		var normal := dir
		for j in poly.size():
			var p0 := poly[j]
			var p1 := poly[(j + 1) % poly.size()]
			var hit = Geometry2D.segment_intersects_segment(Vector2.ZERO, dir * 2000.0, p0, p1)
			if hit != null and (hit as Vector2).length() > best:
				best = (hit as Vector2).length()
				normal = Bau.aussen(p0, p1, m)
		if best < 0.0:
			continue
		var q := dir * best + normal * 1.6
		bl.leuchte(Vector3(q.x, 0.0, q.y), 1.3)
	bl.fertig()
	for mat in mats:
		(mat as ShaderMaterial).set_shader_parameter("strahler_n", float(strahler_n))

# ---------------------------------------------------------------- Form
func _grundrisse() -> void:
	var laengen := [FLUEGEL_START, FLUEGEL_START, FLUEGEL_START]
	for f in STOCKWERKE:
		if f >= STUFE_AB and (f - STUFE_AB) % STUFE_ALLE == 0:
			var w := ((f - STUFE_AB) / STUFE_ALLE) % 3
			laengen[w] = maxf(KERN, laengen[w] - STUFE_UM)
		var b := BREITE * (1.0 - (f - f % STUFE_ALLE) / 420.0)
		var poly: PackedVector2Array
		if laengen.max() <= KERN + 0.5:
			poly = Bau.kreis(KERN * (1.0 - (f - 140) / 120.0), 24)
		else:
			poly = Bau.y_grundriss(laengen, b, KERN)
		stockwerke.append({"poly": poly, "y0": f * STOCK_H, "h": STOCK_H})
	oben = STOCKWERKE * STOCK_H

# Spitze (Wunsch des Users 19.11.2026, Variante A „Glas-Stufen“): die Fassade läuft in 4 weiteren runden Stufen weiter
# (gleicher Glas-Shader mit Räumen, Brüstungsbändern und Rahmen – nur nicht putzbar), darüber ein schlanker Glas-Schaft
# (dünner als der Aufzugskern der Aussichtsplattform bei 800 m, damit er nicht in den Raum ragt), oben eine Nadel in
# Rahmenfarbe mit Ringen. Vorher: glänzende blaugraue Metall-Zylinder mit Rippen + Alu-Nadel (passte nicht zum Turm).
const SPITZE_STUFEN := [[10.2, 6, 24], [8.4, 6, 24], [6.4, 5, 20], [4.4, 3, 16]]   # Radius, Stockwerke, Ecken
const SCHAFT_R := 2.8
const SCHAFT_BIS := 862.0
const NADEL_BIS := 935.0
func _spitze(rahmen_mat: Material) -> void:
	spitze_glas = Bau.shader_mat(Bau.TURM_SHADER, {"glas_tint": Color("4d7397"), "paneel": Color("9aa4ae"), "stock": STOCK_H, "fenster_breite": FENSTER_B, "band_anteil": BAND_ANTEIL, "dreckig": 0.0})
	var stw := []
	var y := oben
	for st in SPITZE_STUFEN:
		for k in int(st[1]):
			stw.append({"poly": Bau.kreis(float(st[0]), int(st[2])), "y0": y, "h": STOCK_H})
			y += STOCK_H
	while y < SCHAFT_BIS:
		stw.append({"poly": Bau.kreis(SCHAFT_R, 12), "y0": y, "h": STOCK_H})
		y += STOCK_H
	add_child(Bau.baue(stw, spitze_glas, Bau.matt("c9c4bb")))
	add_child(Bau.rahmen(stw, FENSTER_B, BAND_ANTEIL, rahmen_mat))
	# Nadel: Rahmen-Alu, matt wie die Fensterrahmen, mit Ringen in Brüstungsfarbe
	var hoehe := NADEL_BIS - y
	var nadel := Bau.zylinder(0.14, 1.15, hoehe, Bau.metall("c9ced4", 0.45, 0.45), 16)
	nadel.position.y = y + hoehe * 0.5
	add_child(nadel)
	var band := Bau.matt("9aa4ae", 0.6)
	var t := 4.0
	while t < hoehe - 3.0:
		var r := lerpf(1.15, 0.14, t / hoehe) + 0.14
		var ring := Bau.zylinder(r, r, 0.35, band, 16)
		ring.position.y = y + t
		add_child(ring)
		t += 6.0
	spitze = NADEL_BIS

# ---------------------------------------------------------------- Fenster
func _fenster_zaehlen() -> void:
	umfaenge.resize(STOCKWERKE)
	fenster_pro_stock.resize(STOCKWERKE)
	fenster_basis.resize(STOCKWERKE)
	fenster_gesamt = 0
	for f in STOCKWERKE:
		var u := Bau.umfang(stockwerke[f].poly)
		umfaenge[f] = u
		fenster_pro_stock[f] = int(u / FENSTER_B)
		fenster_basis[f] = fenster_gesamt
		fenster_gesamt += fenster_pro_stock[f]

# Nummer des Fensters an Stockwerk f und Weg (m) entlang des Umfangs, -1 wenn keins (Rest am Umfang-Ende)
func fenster_id(f: int, weg: float) -> int:
	if f < 0 or f >= STOCKWERKE:
		return -1
	var spalte := int(floor(fposmod(weg, umfaenge[f]) / FENSTER_B))
	if spalte >= fenster_pro_stock[f]:
		return -1
	return fenster_basis[f] + spalte

# Weg entlang des Umfangs von Stockwerk f, der einem Punkt (x, z) am nächsten liegt
func naechster_weg(f: int, q: Vector2) -> float:
	var p: PackedVector2Array = stockwerke[f].poly
	var bester := INF
	var ergebnis := 0.0
	var weg := 0.0
	for k in p.size():
		var a := p[k]
		var b := p[(k + 1) % p.size()]
		var lang := a.distance_to(b)
		var t := clampf((q - a).dot(b - a) / maxf(lang * lang, 0.0001), 0.0, 1.0)
		var dist := q.distance_to(a.lerp(b, t))
		if dist < bester:
			bester = dist
			ergebnis = weg + t * lang
		weg += lang
	return ergebnis

func gleicher_grundriss(f1: int, f2: int) -> bool:
	if f1 < 0 or f2 < 0 or f1 >= STOCKWERKE or f2 >= STOCKWERKE:
		return false
	return stockwerke[f1].poly == stockwerke[f2].poly

func stockwerk_bei(y: float) -> int:
	return clampi(int(floor(y / STOCK_H)), 0, STOCKWERKE - 1)

# Punkt auf der Fassade: Stockwerk f, Weg entlang des Umfangs, Höhe y → Position, Außen-Normale, Tangente
func fassaden_punkt(f: int, weg: float, y: float) -> Dictionary:
	var p: PackedVector2Array = stockwerke[f].poly
	var m := Bau.mitte(p)
	var rest := fposmod(weg, umfaenge[f])
	for k in p.size():
		var a := p[k]
		var b := p[(k + 1) % p.size()]
		var lang := a.distance_to(b)
		if rest <= lang or k == p.size() - 1:
			var q := a.lerp(b, clampf(rest / maxf(lang, 0.001), 0.0, 1.0))
			var n2 := Bau.aussen(a, b, m)
			var t2 := (b - a).normalized()
			return {"pos": Vector3(q.x, y, q.y), "normal": Vector3(n2.x, 0, n2.y), "tangente": Vector3(t2.x, 0, t2.y)}
		rest -= lang
	return {}

# ---------------------------------------------------------------- Seiten (eine Gondel je Seite)
static func seite_von(q: Vector2) -> int:
	var w := rad_to_deg(atan2(q.y, q.x))
	var beste := 0
	for k in 3:
		if absf(wrapf(w - SEITEN_WINKEL[k], -180.0, 180.0)) < absf(wrapf(w - SEITEN_WINKEL[beste], -180.0, 180.0)):
			beste = k
	return beste

func _seiten_berechnen() -> void:
	# Jedes Fenster bekommt die Seite seines Mittelpunkts; der Bereich einer Seite reicht vom ersten bis zum letzten ihrer Fenster
	for f in STOCKWERKE:
		if f > 0 and gleicher_grundriss(f, f - 1):
			seiten.append(seiten[f - 1])
			seiten_spalten.append(seiten_spalten[f - 1])
			continue
		var n := fenster_pro_stock[f]
		var marke := PackedInt32Array()
		marke.resize(n)
		for c in n:
			var p := fassaden_punkt(f, (c + 0.5) * FENSTER_B, 0.0)
			marke[c] = seite_von(Vector2(p.pos.x, p.pos.z))
		var bereich := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
		var spalten := [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
		for k in 3:
			var erste := -1
			for c in n:
				if marke[c] == k and marke[(c - 1 + n) % n] != k:
					erste = c
					break
			if erste < 0:
				continue
			var c2 := erste
			while marke[c2 % n] == k and spalten[k].size() < n:
				spalten[k].append(c2 % n)
				c2 += 1
			var ende_weg := float(((c2 - 1) % n) + 1) * FENSTER_B
			bereich[k] = Vector2(erste * FENSTER_B, fposmod(ende_weg - erste * FENSTER_B - 0.001, umfaenge[f]) + 0.001)
		seiten.append(bereich)
		seiten_spalten.append(spalten)

# Seite eines Punktes auf der Fassade
func seite_bei(f: int, weg: float) -> int:
	var b: Array = seiten[f]
	var u := umfaenge[f]
	for k in 3:
		var v: Vector2 = b[k]
		if fposmod(weg - v.x, u) <= v.y:
			return k
	return 0

# Weg so begrenzen, dass er auf Seite k bleibt (rand = Abstand zu den Grenzen)
func weg_auf_seite(f: int, weg: float, k: int, rand := 2.0) -> float:
	var v: Vector2 = seiten[f][k]
	var u := umfaenge[f]
	var rel := fposmod(weg - v.x, u)
	if rel > v.y:   # außerhalb: zum näheren Ende
		rel = v.y - rand if rel - v.y < u - rel else rand
	rel = clampf(rel, minf(rand, v.y * 0.5), maxf(v.y - rand, v.y * 0.5))
	return fposmod(v.x + rel, u)

# Mitte der Seite k (Weg) – dort parkt eine Gondel
func seiten_mitte(f: int, k: int) -> float:
	var v: Vector2 = seiten[f][k]
	return fposmod(v.x + v.y * 0.5, umfaenge[f])

# Fensterspalten auf Seite k
func spalten_der_seite(f: int, k: int) -> PackedInt32Array:
	return seiten_spalten[f][k]
