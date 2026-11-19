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
	if not "--ohne-bodenlicht" in OS.get_cmdline_user_args():   # Vergleichs-Schalter
		_bodenstrahler([glas, rahmen_mat])

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
