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

func _ready() -> void:
	_grundrisse()
	_fenster_zaehlen()
	glas = Bau.shader_mat(Bau.TURM_SHADER, {"glas_tint": Color("4d7397"), "paneel": Color("9aa4ae"), "stock": STOCK_H, "fenster_breite": FENSTER_B, "band_anteil": BAND_ANTEIL})
	add_child(Bau.baue(stockwerke, glas, Bau.matt("c9c4bb")))
	var alu := Bau.metall("c9ced4")
	var rahmen_mat := Bau.shader_mat(load("res://shader/rahmen.gdshader"), {"farbe": Color("c9ced4"), "fern_farbe": Color("7d8c9c")})
	add_child(Bau.rahmen(stockwerke, FENSTER_B, BAND_ANTEIL, rahmen_mat))
	_spitze(alu)

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

func _spitze(alu: Material) -> void:
	var y := oben
	var r := KERN * (1.0 - (STOCKWERKE - 1 - 140) / 120.0)
	var segment_mat := Bau.metall("8fa3b8", 0.15, 0.6)
	for i in 14:
		var seg := 14.0 - i * 0.4
		var r2 := r * 0.8
		var mi := Bau.zylinder(r2, r, seg, segment_mat)
		mi.position.y = y + seg * 0.5
		add_child(mi)
		var ring := Bau.zylinder(r2 + 0.35, r2 + 0.35, 0.6, alu)
		ring.position.y = y + seg
		add_child(ring)
		for k in 6:
			var fin := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.2, seg, 0.25)
			fin.mesh = bm
			fin.material_override = alu
			var a := TAU * k / 6.0 + i * 0.2
			fin.position = Vector3(cos(a) * (r * 0.85 + 0.4), y + seg * 0.5, sin(a) * (r * 0.85 + 0.4))
			fin.rotation.y = -a
			add_child(fin)
		y += seg
		r = r2
	var nadel := Bau.zylinder(0.15, r, 70.0, alu)
	nadel.position.y = y + 35.0
	add_child(nadel)
	spitze = y + 70.0

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
