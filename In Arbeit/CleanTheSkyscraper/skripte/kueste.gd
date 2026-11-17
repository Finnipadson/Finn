class_name Kueste
extends Node3D
# Küste hinter dem See (Richtung 210°, ~600 m vom Turm): Strandpromenade, Ufermauer, Strand 2 m tiefer, Meer bis zum
# Horizont. Dazu der Palmen-Boulevard mit Kanal vom See bis zum Meer (auf der früheren Straßenlinie z = −112,5),
# große Treppe zum Sand, Strandbar, großer Steg mit Fischladen und Liegeplatz der Yacht.
# Baut welt.gd (auch ohne Spiel sichtbar). Zu Fuß: boden() = Höhe, frei() = zusätzliche Sperren (Laeufer.boden_fn/sperre_fn).
# Palmen, Laternen, Bänke setzt StadtDetails._kueste() (gleiche MultiMeshes wie in der Stadt).

const UFER_X := -606.0          # Ufermauer: westlich davon Strand
const PROM_X := -572.0          # ab hier (westlich) keine Häuser und Kreuzungen: Strandpromenade
const STRAND_Y := -2.0          # Sand an der Mauer
const MEER_Y := -2.4            # Wasserspiegel
const WASSER_X := -646.0        # Wasserlinie (Sand fällt bis hierher auf MEER_Y)
const NEIGUNG := (STRAND_Y - MEER_Y) / (UFER_X - WASSER_X)
const BOUL_Z := -112.5          # Mitte des Boulevards (frühere Straßenlinie)
const BOUL_HALB := 22.0
const BOUL_X0 := -150.0         # Boulevard beginnt am See (östlich davon See-Promenade)
const KANAL_HALB := 3.0
const KANAL_Y := 0.28
const RAND_B := 0.6             # Steinkante am Kanal (Breite)
const RAND_H := 0.55
const BRUECKE_H := 1.1          # Scheitel der gewölbten Steinbrücken
const BRUECKE_HALB := 2.0       # halbe Breite einer Brücke (entlang x)
const BRUECKE_L := 6.6          # Rampe läuft bei |dz| = 6,6 im Pflaster aus
const BRUESTUNG_DZ := 4.6       # Brüstung bis |dz| = 4,6 (1 m über die Kanalkante hinaus)
const BRUESTUNG_D := 0.3
const MAUER_D := 0.6            # Dicke der Ufermauer (westlich von UFER_X)
const TREPPE_LANG := 6.0
const TREPPEN := [Vector2(-131.0, -117.0), Vector2(-108.0, -94.0)]   # z-Bereiche der beiden Treppen neben dem Kanal
const STRAND_BRUECKE := -628.0  # Holzsteg über die Rinne am Strand
const STEG_Z := -200.0
const STEG_HALB := 8.0
const STEG_ENDE := -766.0
const KOPF := Rect2(-796.0, -216.0, 30.0, 32.0)        # Plattform am Stegende
const FISCHLADEN := Rect2(-702.0, -208.0, 16.0, 8.0)  # Hütte auf der Südhälfte des Stegs
const BAR := Rect2(-634.0, -78.0, 14.0, 10.0)          # Bar-Hütte am Strand (Theke nach Süden)
const LIEGEPLATZ := Vector3(-800.0, MEER_Y, -175.5)    # Mega-Yacht (Bug nach −x), längs an der Nordseite des Stegkopfs
const YACHT_HALB := Vector2(45.0, 7.0)                 # halbe Länge / halbe Breite (Yacht.LANG, Yacht.BREIT)
const GANGWAY_X := -781.0                              # Gangway von der Kopf-Mitte zur Seitentür der Yacht

var welt: Welt
var kanal_start := -180.0       # x, wo der Kanal in den See mündet (aus der See-Form berechnet)
var bruecken: Array = []        # x der Brücken über den Kanal
var rechtecke: Array = []       # feste Teile (Hütten) – für den Läufer
var stationen: Array = []       # {art, name, hinweis, pos, ziel}
var angel_orte: Array = []      # Vector2: gute Angelplätze (Bot, Karte)
var wasser_mat: ShaderMaterial
var meer_mat: ShaderMaterial
var rng := RandomNumberGenerator.new()

func baue(w: Welt) -> void:
	welt = w
	rng.seed = 21
	# Mündung: wo die Kanal-Mitte das Seeufer trifft (etwas ins Wasser hinein)
	var a := -100.0
	var b := -400.0
	for i in 40:
		var m := (a + b) * 0.5
		if w.see_abstand(Vector2(m, BOUL_Z)) < 0.0:
			a = m
		else:
			b = m
	kanal_start = a + 1.5
	bruecken = [kanal_start - 11.0, -330.0, -460.0, -589.0]
	wasser_mat = ShaderMaterial.new()
	wasser_mat.shader = load("res://shader/wasser.gdshader")
	_meer()
	_strand()
	_mauer()
	_treppen()
	_kanal()
	_steg()
	_bar()
	var deko := StrandDeko.new()   # Rettungstürme, Volleyball, Sandburgen, Möwen, Krabben, Bojen … (strand_deko.gd)
	add_child(deko)
	deko.baue(self)
	_schilder()
	for r in rechtecke:
		w.hindernisse.append(r)
	stationen = [
		{"art": "strandbar", "name": "Strandbar", "hinweis": "E: Strandbar (Strand-Drinks)", "pos": Vector2(BAR.get_center().x, BAR.position.y - 1.6), "ziel": Vector2(BAR.get_center().x, BAR.position.y + 1.0)},
		{"art": "fischladen", "name": "Fischladen", "hinweis": "E: Fischladen (Angeln kaufen, Fische verkaufen)", "pos": Vector2(FISCHLADEN.get_center().x, FISCHLADEN.end.y + 1.6), "ziel": Vector2(FISCHLADEN.get_center().x, FISCHLADEN.end.y - 1.0)},
		{"art": "yacht", "name": "Yacht", "hinweis": "", "pos": Vector2(GANGWAY_X, KOPF.position.y + KOPF.size.y - 1.2), "ziel": Vector2(GANGWAY_X, LIEGEPLATZ.z)},
	]
	angel_orte = [Vector2(KOPF.position.x + 1.5, KOPF.get_center().y), Vector2(KOPF.get_center().x, KOPF.position.y + 1.5),
		Vector2(-730.0, STEG_Z + STEG_HALB - 1.2), Vector2(WASSER_X + 2.5, -150.0)]

# ---------------------------------------------------------------- Höhe + Sperren zu Fuß
static func sand_y(x: float) -> float:
	return STRAND_Y - (UFER_X - x) * NEIGUNG

static func auf_steg(p: Vector2, rand := 0.0) -> bool:
	return (p.x >= STEG_ENDE - 0.5 and p.x <= UFER_X + 1.0 and absf(p.y - STEG_Z) <= STEG_HALB - rand) or KOPF.grow(-rand).has_point(p)

func _treppe(p: Vector2) -> bool:
	if p.x > UFER_X + 0.05 or p.x < UFER_X - TREPPE_LANG:
		return false
	for t in TREPPEN:
		if p.y > t.x + Laeufer.RADIUS and p.y < t.y - Laeufer.RADIUS:
			return true
	return false

# Höhe des Brückenwegs über dem Pflaster (dz = Abstand zur Kanalmitte): Bogen über dem Kanal, sanft auslaufend
static func bruecke_hoehe(dz: float) -> float:
	var t := absf(dz) / BRUECKE_L
	if t >= 1.0:
		return 0.0
	if t <= 0.75:
		return BRUECKE_H * (1.0 - t * t)
	var u := (t - 0.75) / 0.25   # Hermite-Auslauf: Wert/Steigung der Parabel bei 0,75 → 0 mit Steigung 0
	return BRUECKE_H * (((0.5 * u - 0.5625) * u - 0.375) * u + 0.4375)

func _bruecke(x: float) -> float:
	for bx in bruecken:
		if absf(x - float(bx)) < BRUECKE_HALB:
			return float(bx)
	return INF

# Bodenhöhe draußen (Strand, Treppen, Brücken); sonst 0
func boden(p: Vector2) -> float:
	var dz := absf(p.y - BOUL_Z)
	if p.x >= UFER_X:
		if dz < BRUECKE_L and p.x < kanal_start and _bruecke(p.x) != INF:
			return bruecke_hoehe(dz)
		return 0.0
	if auf_steg(p):
		return 0.0
	for t in TREPPEN:
		if p.y > t.x - 0.5 and p.y < t.y + 0.5 and p.x >= UFER_X - TREPPE_LANG:
			return lerpf(0.0, STRAND_Y, clampf((UFER_X - p.x) / TREPPE_LANG, 0.0, 1.0))
	if dz < KANAL_HALB + RAND_B + 0.5 and absf(p.x - STRAND_BRUECKE) < BRUECKE_HALB + 0.5:
		return strand_steg_y()
	return maxf(sand_y(p.x), MEER_Y)

# Darf man zu Fuß nach p (y = jetzige Höhe der Füße)? Kanal nur über Brücken, Ufermauer nur über Treppen/Steg, Meer nie.
func frei(p: Vector2, y: float) -> bool:
	var dz := absf(p.y - BOUL_Z)
	var kanal := dz < KANAL_HALB + RAND_B + Laeufer.RADIUS
	if p.x >= UFER_X:
		if kanal and p.x < kanal_start + 2.0 and p.x > UFER_X - 1.0:
			if absf(p.x - _bruecke(p.x)) > BRUECKE_HALB - Laeufer.RADIUS:
				return false
		# Brüstung der Brücken (seitlich nicht auf die Brücke steigen)
		if dz < BRUESTUNG_DZ + Laeufer.RADIUS and dz > KANAL_HALB + RAND_B and p.x < kanal_start:
			var bx := _naechste_bruecke(p.x)
			var ax := absf(p.x - bx)
			if ax < BRUECKE_HALB + Laeufer.RADIUS and ax > BRUECKE_HALB - BRUESTUNG_D - Laeufer.RADIUS:
				return false
		if y > STRAND_Y + 0.9 and p.x < UFER_X + 0.5 + Laeufer.RADIUS and not _treppe(p) and not auf_steg(p) and not _in_luecke(p.y):
			return false   # Brüstung oben auf der Ufermauer
		return y > STRAND_Y + 0.9 or _treppe(p)   # vom Strand aus ist die Mauer im Weg
	if _treppe(p):
		return true
	if y > STRAND_Y + 0.9:
		return auf_steg(p, Laeufer.RADIUS)   # oben: nur auf den Steg (nicht über die Mauer springen)
	# unten am Strand: Ufermauer (0,6 m dick) und Treppenwangen halten schon an ihrer Vorderseite
	if p.x > UFER_X - MAUER_D - Laeufer.RADIUS:
		return false
	for t in TREPPEN:
		if p.x > UFER_X - TREPPE_LANG - Laeufer.RADIUS and ((p.y > t.x - 0.7 - Laeufer.RADIUS and p.y < t.x + Laeufer.RADIUS) or (p.y > t.y - Laeufer.RADIUS and p.y < t.y + 0.7 + Laeufer.RADIUS)):
			return false
	if auf_steg(p) or (p.x > WASSER_X - 1.0 and absf(p.y - STEG_Z) < STEG_HALB + Laeufer.RADIUS + 0.3):
		return false   # unter dem Steg ist es zu niedrig
	if kanal and absf(p.x - STRAND_BRUECKE) > BRUECKE_HALB - Laeufer.RADIUS:
		return false
	return p.x > WASSER_X + 0.3

# Lücken in der Brüstung oben auf der Mauer (Treppen + Kanal, Steg)
func _in_luecke(z: float) -> bool:
	return (z > TREPPEN[0].x and z < TREPPEN[1].y) or absf(z - STEG_Z) < STEG_HALB

# Höhe des flachen Holzstegs über die Rinne am Strand
static func strand_steg_y() -> float:
	return sand_y(STRAND_BRUECKE) + 0.3

# Wasserspiegel der Rinne am Strand (knapp unter dem Sand, am Meer = Meeresspiegel)
static func rinne_y(x: float) -> float:
	return lerpf(STRAND_Y - 0.15, MEER_Y + 0.01, clampf((UFER_X - x) / (UFER_X - WASSER_X), 0.0, 1.0))

# Liegt p im Meer (für Angeln, Yacht)?
static func im_meer(p: Vector2) -> bool:
	return p.x < WASSER_X - 0.5 and not auf_steg(p)

# ---------------------------------------------------------------- Meer + Strand
func _meer() -> void:
	meer_mat = ShaderMaterial.new()
	meer_mat.shader = load("res://shader/meer.gdshader")
	meer_mat.set_shader_parameter("ufer_x", WASSER_X)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var x0 := -30000.0
	pm.size = Vector2(WASSER_X - x0, 60000.0)
	mi.mesh = pm
	mi.position = Vector3((WASSER_X + x0) * 0.5, MEER_Y, 0.0)
	mi.material_override = meer_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _strand() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# zwei Stücke: die Rinne (Kanal → Meer) bleibt ausgespart, dort liegt ein tieferes Bett mit Wasser
	var rz := KANAL_HALB + RAND_B * 0.5
	for zz in [[-30000.0, BOUL_Z - rz], [BOUL_Z + rz, 30000.0]]:
		var a := Vector3(UFER_X, STRAND_Y, zz[0])
		var b := Vector3(UFER_X, STRAND_Y, zz[1])
		var c := Vector3(WASSER_X, MEER_Y, zz[1])
		var d := Vector3(WASSER_X, MEER_Y, zz[0])
		var n := (c - a).cross(b - a).normalized()
		if n.y < 0.0:
			n = -n
		_tri(st, a, b, c, n)
		_tri(st, a, c, d, n)
	# Bett der Rinne (nasser Sand, 0,45 m tiefer)
	var ba := Vector3(UFER_X, STRAND_Y - 0.45, BOUL_Z - rz)
	var bb := Vector3(UFER_X, STRAND_Y - 0.45, BOUL_Z + rz)
	var bc := Vector3(WASSER_X - 1.0, MEER_Y - 0.3, BOUL_Z + rz)
	var bd := Vector3(WASSER_X - 1.0, MEER_Y - 0.3, BOUL_Z - rz)
	_tri(st, ba, bb, bc, Vector3.UP)
	_tri(st, ba, bc, bd, Vector3.UP)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shader/sand.gdshader")
	sm.set_shader_parameter("ufer_x", WASSER_X)
	sm.set_shader_parameter("mauer_x", UFER_X)
	mi.material_override = sm
	add_child(mi)

# Ufermauer (Stein) über die ganze Küste, oben eine niedrige Brüstung im Stadtbereich (Lücken an Treppen, Kanal, Steg)
func _mauer() -> void:
	var n := Node3D.new()
	n.name = "Mauer"
	add_child(n)
	var stein := Bau.matt("d8ccb4", 0.8)
	var hell := Bau.matt("ece4d4", 0.6)
	var hoch := -STRAND_Y + 0.3
	RaumBau.box(n, Vector3(0.6, hoch, 60000.0), Vector3(UFER_X - 0.3, -hoch * 0.5 + 0.0, 0.0), stein)
	# Brüstung (0,9 m) von z −1500 bis 1500 mit Lücken
	var luecken := [Vector2(TREPPEN[0].x, TREPPEN[1].y), Vector2(STEG_Z - STEG_HALB, STEG_Z + STEG_HALB)]
	var z := -1500.0
	var stuecke := []
	var start := z
	while z < 1500.0:
		var drin := false
		for l in luecken:
			if z > (l as Vector2).x - 0.01 and z < (l as Vector2).y + 0.01:
				drin = true
		if drin:
			if z - start > 0.5:
				stuecke.append(Vector2(start, z))
			start = z + 0.5
		z += 0.5
	if z - start > 0.5:
		stuecke.append(Vector2(start, z))
	for s in stuecke:
		var l: float = s.y - s.x
		RaumBau.box(n, Vector3(0.45, 0.75, l), Vector3(UFER_X + 0.25, 0.375, (s.x + s.y) * 0.5), stein)
		RaumBau.box(n, Vector3(0.55, 0.09, l), Vector3(UFER_X + 0.25, 0.79, (s.x + s.y) * 0.5), hell)
	RaumBau.verschmelzen(n)

# Zwei breite Treppen neben dem Kanal hinunter zum Sand (12 Stufen)
func _treppen() -> void:
	var n := Node3D.new()
	n.name = "Treppen"
	add_child(n)
	var stein := Bau.matt("e6dccb", 0.7)
	var kante := Bau.matt("cfc3ad", 0.75)
	var stufen := 12
	var auf := -STRAND_Y / stufen
	var tritt := TREPPE_LANG / stufen
	for t in TREPPEN:
		var breite: float = t.y - t.x
		var zm: float = (t.x + t.y) * 0.5
		for k in range(1, stufen):
			var oben := -k * auf
			var x1 := UFER_X - k * tritt
			RaumBau.box(n, Vector3(tritt + 0.02, oben - STRAND_Y + 0.3, breite), Vector3(x1 - tritt * 0.5, (oben + STRAND_Y - 0.3) * 0.5, zm), stein)
		# Wangen links/rechts (oben flach wie die Brüstung)
		for zs in [t.x - 0.35, t.y + 0.35]:
			RaumBau.box(n, Vector3(TREPPE_LANG, 0.8, 0.7), Vector3(UFER_X - TREPPE_LANG * 0.5, STRAND_Y + 0.4 + 0.0, zs), kante)
			var keil := RaumBau.box(n, Vector3(TREPPE_LANG * 1.05, 0.5, 0.7), Vector3(UFER_X - TREPPE_LANG * 0.5, STRAND_Y * 0.5 + 0.65, zs), kante)
			keil.rotation.z = atan2(-STRAND_Y, TREPPE_LANG)
	RaumBau.verschmelzen(n)

# ---------------------------------------------------------------- Kanal (See → Meer)
func _kanal() -> void:
	var n := Node3D.new()
	n.name = "Kanal"
	add_child(n)
	var stein := Bau.matt("ddd2bd", 0.75)
	var laenge := kanal_start - UFER_X
	var xm := (kanal_start + UFER_X) * 0.5
	var wasser := RaumBau.box(n, Vector3(laenge, 0.02, KANAL_HALB * 2.0 + 0.1), Vector3(xm, KANAL_Y, BOUL_Z), wasser_mat)
	wasser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Steinkante: von der Ufermauer bis an die Kante des Sees (dort endet sie schräg am Seerand)
	for s in [-1.0, 1.0]:
		var zr: float = BOUL_Z + s * (KANAL_HALB + RAND_B * 0.5)
		var ende := kanal_start
		while ende < -100.0 and welt.see_abstand(Vector2(ende, zr)) > 0.6:
			ende += 0.25
		RaumBau.box(n, Vector3(ende - UFER_X, RAND_H, RAND_B), Vector3((ende + UFER_X) * 0.5, RAND_H * 0.5, zr), stein)
	# Brücken: gewölbte Steinbrücken mit Brüstung (eigene Meshes, nicht verschmolzen)
	var holz := Bau.matt("a8744a", 0.65)
	var eigene: Array = []
	for bx in bruecken:
		eigene.append_array(_steinbruecke(n, float(bx), stein))
	# Wasserfall die Ufermauer hinunter + Rinne über den Strand ins Meer
	var fall := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(KANAL_HALB * 2.0, KANAL_Y - rinne_y(UFER_X - MAUER_D))
	fall.mesh = qm
	fall.rotation.y = -PI * 0.5
	fall.position = Vector3(UFER_X - 0.62, (KANAL_Y + rinne_y(UFER_X - MAUER_D)) * 0.5, BOUL_Z)
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shader/wasserfall.gdshader")
	fall.material_override = fm
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fall)
	# Wasser der Rinne: knapp unter dem Sand, fällt zum Meer hin ab (der Sand ist dort ausgespart)
	var x0 := UFER_X - MAUER_D
	var x1 := WASSER_X - 0.5
	var rinne_l := x0 - x1
	var fall_w := atan((rinne_y(x0) - rinne_y(x1)) / rinne_l)
	var rw := RaumBau.box(n, Vector3(rinne_l / cos(fall_w), 0.02, KANAL_HALB * 2.0 + 0.1),
		Vector3((x0 + x1) * 0.5, (rinne_y(x0) + rinne_y(x1)) * 0.5, BOUL_Z), wasser_mat)
	rw.rotation.z = -fall_w
	rw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Einfassung: niedrige Steinkante, 15 cm über dem Sand
	var kl_l := UFER_X - MAUER_D - WASSER_X
	for s in [-1.0, 1.0]:
		var zr: float = BOUL_Z + s * (KANAL_HALB + RAND_B * 0.5)
		var km := UFER_X - MAUER_D - kl_l * 0.5
		var kl := RaumBau.box(n, Vector3(kl_l, 0.8, RAND_B), Vector3(km, sand_y(km) + 0.15 - 0.4, zr), stein)
		kl.rotation.z = -atan(NEIGUNG)
	# flacher Holzsteg über die Rinne: Bohlen quer, Längsträger, Geländer
	var sy := strand_steg_y()
	var lang := (KANAL_HALB + RAND_B) * 2.0 + 1.0
	var holz2 := Bau.matt("94653f", 0.75)
	var bz := BOUL_Z - lang * 0.5
	var bk := 0
	while bz < BOUL_Z + lang * 0.5 - 0.1:
		RaumBau.box(n, Vector3(BRUECKE_HALB * 2.0, 0.07, 0.25), Vector3(STRAND_BRUECKE, sy - 0.035, bz + 0.15), holz if bk % 3 != 0 else holz2)
		bz += 0.3
		bk += 1
	for sx in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(0.18, 0.18, lang), Vector3(STRAND_BRUECKE + sx * (BRUECKE_HALB - 0.3), sy - 0.16, BOUL_Z), holz2)
		var gx: float = STRAND_BRUECKE + sx * (BRUECKE_HALB - 0.06)
		for k in 5:
			RaumBau.box(n, Vector3(0.1, 0.95, 0.1), Vector3(gx, sy + 0.47, BOUL_Z - lang * 0.5 + 0.2 + k * (lang - 0.4) / 4.0), holz2)
		RaumBau.box(n, Vector3(0.12, 0.08, lang), Vector3(gx, sy + 0.95, BOUL_Z), holz)
		RaumBau.box(n, Vector3(0.06, 0.06, lang), Vector3(gx, sy + 0.5, BOUL_Z), holz)
	RaumBau.verschmelzen(n, eigene)
	_kanal_fontaenen()

# Kleine Fontänen im Kanal: dieselbe Show wie im See (shader/fontaene), nur niedrig
func _kanal_fontaenen() -> void:
	var orte := []
	var x := kanal_start - 20.0
	var i := 0
	while x > UFER_X + 8.0:
		if _bruecke(x) == INF and absf(x - _naechste_bruecke(x)) > 5.0:
			orte.append(x)
		x -= 9.0
		i += 1
	var basis := Node3D.new()
	basis.position = Vector3(0, KANAL_Y, BOUL_Z)
	add_child(basis)
	var strahl := CylinderMesh.new()
	strahl.top_radius = 0.5
	strahl.bottom_radius = 0.5
	strahl.height = 1.0
	strahl.radial_segments = 8
	strahl.rings = 6
	strahl.cap_top = false
	strahl.cap_bottom = false
	var wolke := SphereMesh.new()
	wolke.radius = 1.0
	wolke.height = 2.0
	wolke.radial_segments = 10
	wolke.rings = 5
	var schaum := PlaneMesh.new()
	schaum.size = Vector2(1.2, 1.2)
	var meshes := [strahl, wolke, schaum]
	for art in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[art]
		mm.instance_count = orte.size()
		for k in orte.size():
			var t := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.35), Vector3(float(orte[k]), 0, 0))
			mm.set_instance_transform(k, t)
			mm.set_instance_custom_data(k, Color(float(k) / maxf(1.0, orte.size() - 1.0), 0.0, 22.0, rng.randf()))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shader/fontaene.gdshader")
		sm.set_shader_parameter("art", art)
		sm.render_priority = [1, 2, 0][art]
		mi.material_override = sm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(UFER_X - 10.0, -1, -10), Vector3(kanal_start - UFER_X + 20.0, 30, 20))
		basis.add_child(mi)

# Gewölbte Steinbrücke quer über den Kanal (bei x = bx): Weg folgt bruecke_hoehe(), Bogen über dem Wasser,
# Brüstung mit Deckstein auf beiden Seiten, Pfeiler an den Enden. Gibt die selbst gebauten MeshInstances zurück.
func _steinbruecke(n: Node3D, bx: float, stein: Material) -> Array:
	var weg := SurfaceTool.new()
	weg.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seite := SurfaceTool.new()
	seite.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := BRUECKE_HALB
	var a := KANAL_HALB + RAND_B          # Bogen spannt über Kanal + Kanten
	var stufen := 32
	var h := 0.72                          # Brüstung über dem Weg
	for i in stufen:
		var d0 := lerpf(-BRUECKE_L, BRUECKE_L, float(i) / stufen)
		var d1 := lerpf(-BRUECKE_L, BRUECKE_L, float(i + 1) / stufen)
		var y0 := bruecke_hoehe(d0) + 0.01
		var y1 := bruecke_hoehe(d1) + 0.01
		var z0 := BOUL_Z + d0
		var z1 := BOUL_Z + d1
		# Weg (Pflaster)
		var nw := Vector3(0, d1 - d0, -(y1 - y0)).normalized()
		_quad(weg, Vector3(bx - w, y0, z0), Vector3(bx + w, y0, z0), Vector3(bx + w, y1, z1), Vector3(bx - w, y1, z1), nw)
		# Seitenwände (bis zur Bogen-Unterkante bzw. in den Boden) + Bogen-Unterseite
		var u0 := _bogen_unten(d0, a)
		var u1 := _bogen_unten(d1, a)
		for sx in [-1.0, 1.0]:
			var x: float = bx + sx * w
			_quad(seite, Vector3(x, y0, z0), Vector3(x, y1, z1), Vector3(x, u1, z1), Vector3(x, u0, z0), Vector3(sx, 0, 0))
		if absf(d0) < a + 0.01 and absf(d1) < a + 0.01:
			var nu := Vector3(0, -(d1 - d0), (u1 - u0)).normalized()
			if nu.y > 0.0:
				nu = -nu
			_quad(seite, Vector3(bx - w, u0, z0), Vector3(bx + w, u0, z0), Vector3(bx + w, u1, z1), Vector3(bx - w, u1, z1), nu)
		# Brüstung: Mauer 0,72 m über dem Weg mit Deckstein
		if absf(d0) < BRUESTUNG_DZ + 0.01 and absf(d1) < BRUESTUNG_DZ + 0.01:
			for sx in [-1.0, 1.0]:
				var xa: float = bx + sx * w
				var xi: float = bx + sx * (w - BRUESTUNG_D)
				_quad(seite, Vector3(xa, y0, z0), Vector3(xa, y1, z1), Vector3(xa, y1 + h, z1), Vector3(xa, y0 + h, z0), Vector3(sx, 0, 0))
				_quad(seite, Vector3(xi, y0, z0), Vector3(xi, y1, z1), Vector3(xi, y1 + h, z1), Vector3(xi, y0 + h, z0), Vector3(-sx, 0, 0))
				var xa2: float = xa + sx * 0.05
				var xi2: float = xi - sx * 0.05
				var nd := Vector3(0, d1 - d0, -(y1 - y0)).normalized()
				_quad(deck, Vector3(xi2, y0 + h + 0.08, z0), Vector3(xa2, y0 + h + 0.08, z0), Vector3(xa2, y1 + h + 0.08, z1), Vector3(xi2, y1 + h + 0.08, z1), nd)
				_quad(deck, Vector3(xa2, y0 + h, z0), Vector3(xa2, y1 + h, z1), Vector3(xa2, y1 + h + 0.08, z1), Vector3(xa2, y0 + h + 0.08, z0), Vector3(sx, 0, 0))
				_quad(deck, Vector3(xi2, y0 + h, z0), Vector3(xi2, y1 + h, z1), Vector3(xi2, y1 + h + 0.08, z1), Vector3(xi2, y0 + h + 0.08, z0), Vector3(-sx, 0, 0))
				# Unterseite des Decksteins
				_quad(deck, Vector3(xi2, y0 + h, z0), Vector3(xa2, y0 + h, z0), Vector3(xa2, y1 + h, z1), Vector3(xi2, y1 + h, z1), -nd)
	var teile: Array = []
	for st_m in [[weg, Bau.matt("e4dccb", 0.75)], [seite, stein], [deck, Bau.matt("f1ebe0", 0.6)]]:
		var mi := MeshInstance3D.new()
		mi.mesh = (st_m[0] as SurfaceTool).commit()
		mi.material_override = st_m[1]
		n.add_child(mi)
		teile.append(mi)
	# Pfeiler an den Enden der Brüstung + Deckplatte
	for sz in [-1.0, 1.0]:
		var dz: float = sz * BRUESTUNG_DZ
		var y := bruecke_hoehe(dz)
		for sx in [-1.0, 1.0]:
			var px: float = bx + sx * (w - BRUESTUNG_D * 0.5)
			RaumBau.box(n, Vector3(0.46, y + 1.0, 0.46), Vector3(px, (y + 1.0) * 0.5, BOUL_Z + dz), stein)
			RaumBau.box(n, Vector3(0.56, 0.1, 0.56), Vector3(px, y + 1.05, BOUL_Z + dz), Bau.matt("f1ebe0", 0.6))
	return teile

# Unterkante des Bogens (über dem Kanal) bzw. Fundament im Boden
static func _bogen_unten(dz: float, a: float) -> float:
	if absf(dz) < a + 0.01:
		var t := clampf(dz / a, -1.0, 1.0)
		return 0.45 + (BRUECKE_H - 0.32 - 0.45) * (1.0 - t * t)
	return -0.05

# Viereck mit gewünschter Außenseite (nrm) – ohne UV, deshalb nie verschmelzen
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3) -> void:
	_tri(st, a, b, c, nrm)
	_tri(st, a, c, d, nrm)

func _naechste_bruecke(x: float) -> float:
	var best := INF
	for bx in bruecken:
		if absf(x - float(bx)) < absf(x - best):
			best = float(bx)
	return best

# ---------------------------------------------------------------- Großer Steg mit Fischladen + Liegeplatz
func _steg() -> void:
	var n := Node3D.new()
	n.name = "Steg"
	add_child(n)
	var holz := Bau.matt("b07d52", 0.7)
	var holz2 := Bau.matt("94653f", 0.75)
	var pfahl := Bau.matt("5a4632", 0.85)
	var gel := Bau.metall("e3e7ec", 0.3, 0.8)
	var laenge := UFER_X - STEG_ENDE
	# Belag: Bohlen quer (abwechselnd zwei Holztöne)
	var x := UFER_X
	var k := 0
	while x > STEG_ENDE:
		RaumBau.box(n, Vector3(0.26, 0.14, STEG_HALB * 2.0), Vector3(x - 0.15, -0.058, STEG_Z), holz if k % 3 != 0 else holz2)
		x -= 0.3
		k += 1
	RaumBau.box(n, Vector3(laenge, 0.3, STEG_HALB * 2.0 - 0.4), Vector3(UFER_X - laenge * 0.5, -0.29, STEG_Z), pfahl)   # Unterzug
	# Kopf-Plattform
	var kp := KOPF
	var zk := kp.position.y
	while zk < kp.end.y:
		RaumBau.box(n, Vector3(kp.size.x, 0.14, 0.26), Vector3(kp.get_center().x, -0.058, zk + 0.15), holz if int(zk) % 3 != 0 else holz2)
		zk += 0.3
	RaumBau.box(n, Vector3(kp.size.x - 0.4, 0.3, kp.size.y - 0.4), Vector3(kp.get_center().x, -0.29, kp.get_center().y), pfahl)
	# Pfähle bis ins Wasser
	x = UFER_X - 4.0
	while x > STEG_ENDE:
		for s in [-1.0, 1.0]:
			var unten := sand_y(x) - 0.6
			RaumBau.zyl(n, 0.22, -unten, Vector3(x, unten * 0.5, STEG_Z + s * (STEG_HALB - 0.4)), pfahl, 8)
		x -= 6.0
	for px in [kp.position.x + 0.5, kp.get_center().x, kp.end.x - 0.5]:
		for pz in [kp.position.y + 0.5, kp.get_center().y, kp.end.y - 0.5]:
			RaumBau.zyl(n, 0.26, 3.4, Vector3(px, -1.7, pz), pfahl, 8)
	# Geländer (Pfosten + zwei Holme), am Kopf rundum außer am Liegeplatz
	var linien := [
		[Vector2(UFER_X, STEG_Z - STEG_HALB), Vector2(STEG_ENDE, STEG_Z - STEG_HALB)],
		[Vector2(UFER_X, STEG_Z + STEG_HALB), Vector2(STEG_ENDE, STEG_Z + STEG_HALB)],
		[Vector2(kp.end.x, kp.position.y), Vector2(kp.position.x, kp.position.y)],
		[Vector2(kp.position.x, kp.position.y), Vector2(kp.position.x, kp.end.y)],
		[Vector2(kp.position.x, kp.end.y), Vector2(GANGWAY_X - 2.0, kp.end.y)],   # Lücke für die Gangway
		[Vector2(GANGWAY_X + 2.0, kp.end.y), Vector2(kp.end.x, kp.end.y)],
		[Vector2(kp.end.x, kp.position.y), Vector2(kp.end.x, STEG_Z - STEG_HALB)],
		[Vector2(kp.end.x, STEG_Z + STEG_HALB), Vector2(kp.end.x, kp.end.y)],
	]
	for l in linien:
		var a: Vector2 = l[0]
		var b: Vector2 = l[1]
		var len := a.distance_to(b)
		var m := (a + b) * 0.5
		var dreh := atan2(b.x - a.x, b.y - a.y)
		for hy in [0.55, 1.05]:
			var h := RaumBau.box(n, Vector3(0.06, 0.06, len), Vector3(m.x, hy, m.y), gel)
			h.rotation.y = dreh
		var anz := maxi(1, int(len / 2.5))
		for i in anz + 1:
			var p := a.lerp(b, float(i) / anz)
			RaumBau.box(n, Vector3(0.08, 1.1, 0.08), Vector3(p.x, 0.55, p.y), gel)
	# Poller + Taue am Liegeplatz
	for px in [kp.position.x + 1.5, GANGWAY_X - 6.0, GANGWAY_X + 6.0, kp.end.x - 1.5]:
		RaumBau.zyl(n, 0.2, 0.55, Vector3(px, 0.27, kp.end.y - 0.4), Bau.matt("2b2d33", 0.6), 10)
	# Gangway (Edelstahl mit Geländer) vom Stegkopf zur Seitentür der Yacht
	var gw_l := absf(kp.end.y - (LIEGEPLATZ.z - YACHT_HALB.y)) + 0.6
	var gw_z := (kp.end.y + LIEGEPLATZ.z - YACHT_HALB.y) * 0.5 + 0.3
	RaumBau.box(n, Vector3(1.4, 0.08, absf(gw_l)), Vector3(GANGWAY_X, 0.04, gw_z), Bau.metall("c9d0d6", 0.3, 0.8))
	for sx in [-0.68, 0.68]:
		RaumBau.box(n, Vector3(0.04, 0.04, absf(gw_l)), Vector3(GANGWAY_X + sx, 0.95, gw_z), gel)
		for j in 3:
			RaumBau.box(n, Vector3(0.04, 0.9, 0.04), Vector3(GANGWAY_X + sx, 0.5, gw_z - absf(gw_l) * 0.5 + 0.1 + j * (absf(gw_l) - 0.2) * 0.5), gel)
	# Laternen
	x = UFER_X - 20.0
	while x > STEG_ENDE:
		for s in [-1.0, 1.0]:
			RaumBau.zyl(n, 0.07, 4.0, Vector3(x, 2.0, STEG_Z + s * (STEG_HALB - 0.3)), gel, 8)
			RaumBau.box(n, Vector3(0.35, 0.25, 0.35), Vector3(x, 4.1, STEG_Z + s * (STEG_HALB - 0.3)), RaumBau.leuchte("fff2d8", 0.6))
		x -= 30.0
	RaumBau.verschmelzen(n)
	_fischladen()

func _fischladen() -> void:
	var n := Node3D.new()
	n.name = "Fischladen"
	add_child(n)
	var r := FISCHLADEN
	var weiss := Bau.matt("f4f1ea", 0.6)
	var blau := Bau.matt("2f6fa8", 0.6)
	var dach := Bau.matt("3a5f7d", 0.7)
	var holz := Bau.matt("8a5a34", 0.7)
	var h := 3.4
	var c := r.get_center()
	var fische: Array = []                 # Fisch-Modelle nicht verschmelzen (eigene Meshes)
	var hinten := r.position.y + 0.2      # Innenseite der Rückwand
	var theke_z := r.end.y - 0.7          # Mitte der Kühltheke
	# Rückwand + Seiten, vorne (Norden) offen mit Theke
	RaumBau.box(n, Vector3(r.size.x, h, 0.2), Vector3(c.x, h * 0.5, r.position.y + 0.1), weiss)
	for sx in [r.position.x + 0.1, r.end.x - 0.1]:
		RaumBau.box(n, Vector3(0.2, h, r.size.y), Vector3(sx, h * 0.5, c.y), weiss)
	# blaue Streifen außen (Fischerhütte) + innen eine blaue Holzvertäfelung bis 1,2 m
	for i in 5:
		RaumBau.box(n, Vector3(r.size.x + 0.05, 0.22, 0.24), Vector3(c.x, 0.4 + i * 0.7, r.position.y + 0.08), blau)
	RaumBau.box(n, Vector3(r.size.x - 0.4, 1.2, 0.04), Vector3(c.x, 0.6, hinten + 0.02), Bau.matt("5f97c6", 0.7))
	for sx in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(0.04, 1.2, r.size.y - 0.3), Vector3(c.x + sx * (r.size.x * 0.5 - 0.22), 0.6, c.y), Bau.matt("5f97c6", 0.7))
	# Fliesenboden hinter der Theke
	RaumBau.box(n, Vector3(r.size.x - 0.4, 0.03, theke_z - hinten - 0.5), Vector3(c.x, 0.015, (hinten + theke_z - 0.5) * 0.5), Bau.matt("e6edf1", 0.35))
	var d := RaumBau.box(n, Vector3(r.size.x + 1.2, 0.18, r.size.y + 2.2), Vector3(c.x, h + 0.35, c.y + 0.6), dach)
	d.rotation.x = -0.12
	# helle Decke innen (unter dem Dach)
	RaumBau.box(n, Vector3(r.size.x - 0.4, 0.05, r.size.y - 0.2), Vector3(c.x, h - 0.03, c.y), Bau.matt("fbfaf6", 0.8))
	# Markise vorne (blau-weiß gestreift)
	for i in 8:
		var m := RaumBau.box(n, Vector3(r.size.x / 8.0, 0.05, 1.8), Vector3(r.position.x + (i + 0.5) * r.size.x / 8.0, 2.7, r.end.y + 0.7), blau if i % 2 == 0 else weiss)
		m.rotation.x = 0.35
	# Kühltheke: 0,85 m hoch, Edelstahl, Crushed-Eis, schräge Glasscheibe vorne
	var tb := r.size.x - 1.6
	RaumBau.box(n, Vector3(tb, 0.85, 1.1), Vector3(c.x, 0.425, theke_z), Bau.metall("c9d0d6", 0.35, 0.7))
	RaumBau.box(n, Vector3(tb, 0.12, 0.06), Vector3(c.x, 0.2, theke_z + 0.56), blau)
	RaumBau.box(n, Vector3(tb - 0.2, 0.06, 0.95), Vector3(c.x, 0.88, theke_z), Bau.matt("eef7fb", 0.15))
	var eis := Bau.matt("f4fbff", 0.1)
	var ex := r.position.x + 1.0
	while ex < r.end.x - 1.0:   # feines Crushed-Eis (flache Brocken, unter den Fischen)
		for k in 2:
			var g := rng.randf_range(0.035, 0.06)
			var e := RaumBau.box(n, Vector3(g, g * 0.5, g), Vector3(ex + rng.randf() * 0.25, 0.905, theke_z - 0.38 + k * 0.76 + rng.randf_range(-0.06, 0.06)), eis)
			e.rotation = Vector3(rng.randf() * 0.6, rng.randf() * TAU, 0)
		ex += 0.25
	var scheibe := RaumBau.box(n, Vector3(tb, 0.32, 0.02), Vector3(c.x, 1.03, theke_z + 0.49), RaumBau.glas("e8f6ff", 0.14))
	scheibe.rotation.x = -0.45
	RaumBau.box(n, Vector3(tb, 0.04, 0.24), Vector3(c.x, 1.18, theke_z + 0.38), Bau.metall("c9d0d6", 0.35, 0.7))
	# Waage und Papierrolle auf der Theke (rechts), Preisschildchen
	var wx := r.end.x - 1.5
	RaumBau.box(n, Vector3(0.45, 0.12, 0.35), Vector3(wx, 1.35, theke_z + 0.25), Bau.matt("f4f4f4", 0.4))
	RaumBau.box(n, Vector3(0.36, 0.02, 0.3), Vector3(wx, 1.42, theke_z + 0.25), Bau.metall("dfe5ea", 0.2, 0.9))
	var anz := RaumBau.box(n, Vector3(0.3, 0.16, 0.04), Vector3(wx, 1.45, theke_z + 0.08), Bau.matt("1d2a36", 0.3))
	anz.rotation.x = -0.4
	RaumBau.zyl(n, 0.07, 0.4, Vector3(r.position.x + 1.3, 1.36, theke_z + 0.2), Bau.matt("efe9df", 0.8), 10)
	# Fische flach auf dem Eis (auf der Seite liegend, leicht schräg), zwei Reihen
	var auslage := ["sergeant", "papagei", "kaiser", "barrakuda", "feuer", "sohal", "koffer", "papagei", "sergeant", "barrakuda", "sohal", "kaiser", "papagei", "feuer"]
	var fx := r.position.x + 1.35
	var schritt := (tb - 1.6) / 6.0
	for i in auslage.size():
		var id: String = auslage[i]
		var f := Fische.modell(id)
		var lang := clampf(float(Fische.daten(id).groesse) * 2.0, 0.75, 1.0)
		var reihe := i % 2
		var gier := (0.35 if int(i / 2.0) % 2 == 0 else -0.35) + (PI if reihe == 1 else 0.0)
		f.transform = Transform3D(Basis(Vector3.UP, gier) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3.ONE * lang),
			Vector3(fx + int(i / 2.0) * schritt + 0.2 + reihe * 0.45, 0.97, theke_z - 0.2 + reihe * 0.38))
		n.add_child(f)
		fische.append(f)
	# Preisschildchen im Eis
	for i in 7:
		var s := RaumBau.box(n, Vector3(0.16, 0.1, 0.01), Vector3(fx + i * schritt + 0.2, 1.0, theke_z + 0.42), Bau.matt("ffffff", 0.5))
		s.rotation.x = -0.5
	# Wand-Deko: Fischernetz mit Schwimmern, gekreuzte Angeln, Preistafel, Rettungsring, Fisch-Trophäen, Kisten
	var netz := Bau.matt("6b5a42", 0.9)
	var nx0 := r.position.x + 0.8
	for k in 9:   # Netz als Raster aus dünnen Schnüren, durchhängend
		var t := float(k) / 8.0
		RaumBau.box(n, Vector3(0.02, 1.4, 0.02), Vector3(nx0 + t * 3.2, 2.35 - sin(t * PI) * 0.15, hinten + 0.06), netz)
	for k in 7:
		var hb := RaumBau.box(n, Vector3(3.2, 0.02, 0.02), Vector3(nx0 + 1.6, 1.7 + k * 0.2, hinten + 0.06), netz)
		hb.rotation.z = 0.02 * (k - 3)
	for k in 5:
		Andenken._kugel_mesh(n, 0.08, Vector3(nx0 + 0.3 + k * 0.65, 1.65 + (k % 2) * 0.25, hinten + 0.1), Bau.matt(["ff8a2a", "f4f1ea"][k % 2], 0.5), 8)
	var ruten := Vector3(nx0 + 5.0, 2.2, hinten + 0.08)
	for s in [-1.0, 1.0]:
		var rute := RaumBau.zyl(n, 0.02, 2.4, ruten, Bau.matt("2b2d33", 0.4), 6, 0.03)
		rute.rotation.z = s * 0.9
		var rolle := RaumBau.zyl(n, 0.06, 0.08, ruten + Vector3(s * 0.55, -0.4, 0.04), Bau.metall("c0c6cc", 0.3, 0.8), 10)
		rolle.rotation.x = PI * 0.5
	# Preistafel (Kreide) in der Mitte
	var tafel_x := c.x + 1.2
	RaumBau.box(n, Vector3(2.4, 1.4, 0.06), Vector3(tafel_x, 2.3, hinten + 0.05), holz)
	RaumBau.box(n, Vector3(2.2, 1.2, 0.04), Vector3(tafel_x, 2.3, hinten + 0.08), Bau.matt("26302c", 0.9))
	var preis := RaumBau.schrift(n, "FANGFRISCH\nSergeant · Kofferfisch\nPapagei · Kaiserfisch\nBarrakuda · Thun …\nPreise steigen mit der Höhe", Vector3(tafel_x, 2.3, hinten + 0.11), 0.0, 40, 0.0045, Color("f4f1ea"), false)
	preis.rotation.y = 0.0
	# Rettungsring rechts
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.22
	tm.outer_radius = 0.36
	ring.mesh = tm
	ring.material_override = Bau.matt("e2483e", 0.5)
	ring.position = Vector3(r.end.x - 2.0, 2.3, hinten + 0.1)
	ring.rotation.x = PI * 0.5
	n.add_child(ring)
	for k in 4:
		var wb := RaumBau.box(n, Vector3(0.16, 0.12, 0.17), Vector3(r.end.x - 2.0 + cos(k * PI * 0.5 + 0.785) * 0.29, 2.3 + sin(k * PI * 0.5 + 0.785) * 0.29, hinten + 0.1), weiss)
		wb.rotation.z = k * PI * 0.5 + 0.785
	# Fisch-Trophäen auf Holzbrettern an den Seitenwänden
	var tropha := [["barrakuda", -1.0, 0.0], ["kaiser", 1.0, -1.2], ["papagei", 1.0, 1.2]]
	for t in tropha:
		var sx: float = t[1]
		var wx2 := c.x + sx * (r.size.x * 0.5 - 0.24)
		var wz: float = c.y - 0.8 + float(t[2])
		var brett := RaumBau.box(n, Vector3(0.04, 0.5, 1.2), Vector3(wx2 - sx * 0.02, 2.3, wz), holz)
		brett.rotation.x = 0.0
		var f := Fische.modell(String(t[0]))
		f.transform = Transform3D(Basis(Vector3.UP, sx * PI * 0.5) * Basis.from_scale(Vector3.ONE * 0.95), Vector3(wx2 - sx * 0.12, 2.3, wz))
		n.add_child(f)
		fische.append(f)
	# Lampen: drei Pendelleuchten über der Theke (Licht ohne Schatten)
	for k in 3:
		var lx := r.position.x + r.size.x * (k + 1) / 4.0
		RaumBau.zyl(n, 0.01, 0.9, Vector3(lx, h - 0.5, theke_z - 0.2), Bau.matt("2b2d33", 0.4), 4)
		RaumBau.zyl(n, 0.08, 0.28, Vector3(lx, h - 1.05, theke_z - 0.2), Bau.matt("2f6fa8", 0.5), 12, 0.32)
		RaumBau.zyl(n, 0.2, 0.02, Vector3(lx, h - 1.2, theke_z - 0.2), RaumBau.leuchte("fff4dc", 2.5), 12)
	for k in 2:
		var licht := OmniLight3D.new()
		licht.position = Vector3(r.position.x + r.size.x * (k + 1) / 3.0, h - 0.6, c.y - 0.5)
		licht.omni_range = 7.0
		licht.light_energy = 1.4
		licht.light_color = Color("fff1d9")
		licht.shadow_enabled = false
		licht.distance_fade_enabled = true
		licht.distance_fade_begin = 60.0
		licht.distance_fade_length = 20.0
		n.add_child(licht)
	var l := RaumBau.schrift(n, "FISCHLADEN", Vector3(c.x, h + 0.95, r.end.y + 1.6), 0.0, 96, 0.012, Color("ffffff"))
	l.outline_size = 12
	l.outline_modulate = Color("1d4f7c")
	l.rotation.y = 0.0
	RaumBau.verschmelzen(n, fische)
	# Kisten hinten in den Ecken (Kenney Pirate Kit)
	for k in [[r.position.x + 0.9, 0.3], [r.end.x - 0.9, -0.2]]:
		if RaumBau.modell_da("strand/crate"):
			RaumBau.mittig(n, "strand/crate", Vector3(float(k[0]), 0.0, hinten + 0.6), 0.9, float(k[1]))
	# Verkäufer: steht auf einem Podest hinter der Theke (Oberkörper über der Theke sichtbar), schaut nach vorne
	RaumBau.box(n, Vector3(2.0, 0.55, 0.9), Vector3(c.x - 1.5, 0.275, theke_z - 1.2), Bau.matt("c9d0d6", 0.6))
	if RaumBau.modell_da("leute/character-male-b"):
		RaumBau.modell(n, "leute/character-male-b", Vector3(c.x - 1.5, 0.55, theke_z - 1.2), 2.8, 0.0)
	rechtecke.append(Rect2(r.position, Vector2(r.size.x, r.size.y)))

# ---------------------------------------------------------------- Strandbar
func _bar() -> void:
	var n := Node3D.new()
	n.name = "Strandbar"
	add_child(n)
	var r := BAR
	var c := r.get_center()
	var y0 := sand_y(c.x)
	var holz := Bau.matt("b98a55", 0.7)
	var dunkel := Bau.matt("6b4a2c", 0.75)
	var stroh := Bau.matt("d9b56a", 0.95)
	var h := 3.0
	# Pfosten, Rückwand, Theke vorne (Süden)
	for px in [r.position.x + 0.3, r.end.x - 0.3]:
		for pz in [r.position.y + 0.3, r.end.y - 0.3]:
			RaumBau.zyl(n, 0.16, h, Vector3(px, y0 + h * 0.5, pz), dunkel, 8)
	RaumBau.box(n, Vector3(r.size.x - 0.6, h - 0.4, 0.15), Vector3(c.x, y0 + (h - 0.4) * 0.5, r.end.y - 0.3), holz)
	for sx in [r.position.x + 0.3, r.end.x - 0.3]:
		RaumBau.box(n, Vector3(0.15, 1.1, r.size.y - 0.6), Vector3(sx, y0 + 0.55, c.y), holz)
	RaumBau.box(n, Vector3(r.size.x - 0.6, 1.1, 0.7), Vector3(c.x, y0 + 0.55, r.position.y + 0.6), holz)
	RaumBau.box(n, Vector3(r.size.x - 0.4, 0.08, 0.9), Vector3(c.x, y0 + 1.14, r.position.y + 0.6), dunkel)
	# Regal mit Flaschen + Früchten an der Rückwand
	RaumBau.box(n, Vector3(r.size.x - 2.0, 0.06, 0.4), Vector3(c.x, y0 + 1.6, r.end.y - 0.55), dunkel)
	var farben := ["e2483e", "ffc531", "7fe08a", "35c8ff", "ff9ad5", "f4f4f4"]
	for i in 18:
		var fx := r.position.x + 1.3 + i * (r.size.x - 2.6) / 17.0
		RaumBau.zyl(n, 0.06, 0.32, Vector3(fx, y0 + 1.8, r.end.y - 0.55), Bau.matt(farben[i % farben.size()], 0.25), 8)
	for i in 6:
		Andenken._kugel_mesh(n, 0.16, Vector3(r.position.x + 2.0 + i * 1.8, y0 + 1.3, r.position.y + 0.55), Bau.matt(["7a4a22", "ffb03a", "ffd84a"][i % 3], 0.7), 8)
	# Strohdach: flache Pyramide (4 Seiten) über die ganze Hütte + Fransen-Kante
	var dach_k := Node3D.new()
	dach_k.position = Vector3(c.x, y0 + h + 0.8, c.y)
	dach_k.scale = Vector3((r.size.x + 2.4) * 0.5 / 0.3536, 1.0, (r.size.y + 2.4) * 0.5 / 0.3536)
	n.add_child(dach_k)
	var dach := RaumBau.zyl(dach_k, 0.02, 1.6, Vector3.ZERO, stroh, 4, 0.5)
	dach.rotation.y = PI * 0.25
	RaumBau.box(n, Vector3(r.size.x + 2.3, 0.35, r.size.y + 2.3), Vector3(c.x, y0 + h + 0.05, c.y), Bau.matt("c9a258", 0.95))
	# Hocker vor der Theke
	for i in 6:
		var hx := r.position.x + 1.6 + i * (r.size.x - 3.2) / 5.0
		RaumBau.zyl(n, 0.05, 0.75, Vector3(hx, y0 + 0.375, r.position.y - 0.5), dunkel, 6)
		RaumBau.zyl(n, 0.22, 0.08, Vector3(hx, y0 + 0.78, r.position.y - 0.5), Bau.matt("35c8ff", 0.5), 12)
	var l := RaumBau.schrift(n, "STRANDBAR", Vector3(c.x, y0 + h + 1.9, r.position.y - 0.9), PI, 96, 0.012, Color("ffffff"))
	l.outline_size = 12
	l.outline_modulate = Color("c2452f")
	l.rotation.y = PI
	RaumBau.verschmelzen(n)
	if RaumBau.modell_da("leute/character-female-c"):
		RaumBau.box(n, Vector3(2.0, 0.35, 0.9), Vector3(c.x + 1.0, y0 + 0.175, c.y + 0.6), dunkel)   # Podest hinter der Theke
		RaumBau.modell(n, "leute/character-female-c", Vector3(c.x + 1.0, y0 + 0.35, c.y + 0.6), 2.8, PI)
	rechtecke.append(Rect2(r.position + Vector2(0, -0.2), r.size + Vector2(0, 0.2)))
	_strandmoebel()

# Sonnenschirme + Liegen nördlich der Bar und südlich des Stegs (MultiMesh)
func _strandmoebel() -> void:
	var schirme := []
	var liegen := []
	for reihe in [-617.0, -629.0, -639.0]:
		var z := -60.0
		while z < 260.0:
			if z > BAR.position.y - 3.0 and z < BAR.end.y + 6.0 and reihe > -638.0:
				z += 9.0
				continue
			schirme.append(Vector3(reihe, sand_y(reihe), z))
			z += 9.0
		if reihe > -620.0:   # Südstrand zwischen Treppe und Steg (an der Mauer, neben dem Volleyballfeld)
			for zs in [-140.0, -151.0, -177.0, -187.0]:
				schirme.append(Vector3(reihe + 0.5, sand_y(reihe + 0.5), zs))
		z = -232.0
		while z > -420.0:
			schirme.append(Vector3(reihe, sand_y(reihe), z))
			z -= 10.0
	var farben := [Color("e2483e"), Color("35c8ff"), Color("ffc531"), Color("f4f4f4"), Color("3fc29a")]
	var schirm_xf := []
	var schirm_farbe := []
	for p in schirme:
		schirm_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
		schirm_farbe.append(farben[rng.randi() % farben.size()])
		for s in [-1.0, 1.0]:
			var lp: Vector3 = p + Vector3(0.0, 0.0, s * 1.15)
			liegen.append(Transform3D(Basis(Vector3.UP, PI), Vector3(lp.x - 0.4, sand_y(lp.x - 0.4), lp.z)))
			rechtecke.append(Rect2(Vector2(lp.x - 1.5, lp.z - 0.4), Vector2(2.2, 0.8)))
		rechtecke.append(Rect2(Vector2(p.x - 0.15, p.z - 0.15), Vector2(0.3, 0.3)))
	# Schirm: Stange + achteckiges Dach (Farbe je Instanz × helle/dunkle Bahnen über die Vertex-Farbe)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 8
	var r := 1.6
	var spitze := Vector3(0, 2.55, 0)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := Vector3(cos(a0) * r, 2.05, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 2.05, sin(a1) * r)
		var hell := 1.0 if i % 2 == 0 else 0.55
		var nrm := (p0 - spitze).cross(p1 - spitze).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		st.set_color(Color(hell, hell, hell))
		_tri(st, spitze, p0, p1, nrm)
		st.set_color(Color(hell * 0.6, hell * 0.6, hell * 0.6))
		_tri(st, spitze, p0, p1, -nrm)   # Unterseite
	var dach_m := StandardMaterial3D.new()
	dach_m.vertex_color_use_as_albedo = true
	dach_m.roughness = 0.8
	var dach_mesh := st.commit()
	dach_mesh.surface_set_material(0, dach_m)
	var stange := Bau.zylinder(0.035, 0.035, 2.5, Bau.matt("f1eee8", 0.5), 6)
	_mm(dach_mesh, schirm_xf, null, schirm_farbe)
	var sm := (stange.mesh as Mesh)
	var stange_xf := []
	for t in schirm_xf:
		stange_xf.append((t as Transform3D).translated(Vector3(0, 1.25, 0)))
	_mm(sm, stange_xf, stange.material_override)
	stange.free()
	# Liege: Gestell + schräge Rückenlehne + Polster (lokal: Länge entlang x)
	var lm := ArrayMesh.new()
	var lt := SurfaceTool.new()
	lt.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quader(lt, Vector3(1.4, 0.08, 0.68), Vector3(0.25, 0.32, 0), 0.0)
	_quader(lt, Vector3(0.75, 0.08, 0.68), Vector3(-0.72, 0.55, 0), -0.55)
	for lx in [-0.35, 0.85]:
		for lz in [-0.3, 0.3]:
			_quader(lt, Vector3(0.05, 0.3, 0.05), Vector3(lx, 0.15, lz), 0.0)
	lt.commit(lm)
	lm.surface_set_material(0, Bau.matt("f4f1ea", 0.6))
	lt = SurfaceTool.new()
	lt.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quader(lt, Vector3(1.36, 0.06, 0.62), Vector3(0.25, 0.39, 0), 0.0)
	_quader(lt, Vector3(0.72, 0.06, 0.62), Vector3(-0.68, 0.61, 0), -0.55)
	lt.commit(lm)
	lm.surface_set_material(1, Bau.matt("2f8fd0", 0.8))
	_mm(lm, liegen, null)

func _quader(st: SurfaceTool, g: Vector3, p: Vector3, dreh_z: float) -> void:
	var bm := BoxMesh.new()
	bm.size = g
	st.append_from(bm, 0, Transform3D(Basis(Vector3(0, 0, 1), dreh_z), p))

func _mm(mesh: Mesh, xf: Array, mat: Material, farben: Array = []) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not farben.is_empty()
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		if not farben.is_empty():
			mm.set_instance_color(i, farben[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	if mat:
		mi.material_override = mat
	add_child(mi)

# Dreieck mit gewünschter Vorderseite (Godot: Vorderseite im Uhrzeigersinn)
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	var ecken := [a, b, c] if (c - a).cross(b - a).dot(n) > 0.0 else [a, c, b]
	st.set_normal(n)
	for v in ecken:
		st.set_uv(Vector2(v.x, v.z) * 0.1)
		st.add_vertex(v)

# ---------------------------------------------------------------- Schilder „Strand →“
func _schilder() -> void:
	var n := Node3D.new()
	n.name = "Schilder"
	add_child(n)
	var mast := Bau.metall("8d939b", 0.35, 0.8)
	var tafel := Bau.matt("1f6fb0", 0.5)
	# Lage, Blickrichtung (Text schaut dorthin), Text
	var orte := [
		[welt.see_welt(Vector2(-10.0, -100.0)), Vector2(1, 0.4), "Strand + Steg\nüber den Palmen-Boulevard"],
		[Vector2(kanal_start - 21.0, BOUL_Z + 19.0), Vector2(1, 0), "↑  Strand  ·  400 m"],
		[Vector2(-326.0, BOUL_Z - 19.0), Vector2(1, 0), "↑  Strand · Steg · Fischladen"],
		[Vector2(-458.0, BOUL_Z + 19.0), Vector2(1, 0), "↑  Strandbar · Strand"],
		[Vector2(-601.0, BOUL_Z - 19.0), Vector2(1, 0), "→  Steg + Fischladen\n↑  Treppe zum Strand"],
		[Vector2(-601.0, BOUL_Z + 19.0), Vector2(1, 0), "←  Strandbar (am Strand)\n↑  Treppe zum Strand"],
	]
	var rahmen := Bau.matt("f4f1ea", 0.5)
	const PX := 0.008
	const FS := 44
	for o in orte:
		var p: Vector2 = o[0]
		var b: Vector2 = (o[1] as Vector2).normalized()
		var dreh := atan2(b.x, b.y)
		var quer := Vector3(b.y, 0, -b.x)   # entlang der Tafel
		var txt := str(o[2])
		# Tafel so groß wie der Text (+ Rand); zwei Pfosten links und rechts neben der Tafel (verdecken nichts)
		var l0 := RaumBau.schrift(n, txt, Vector3.ZERO, 0.0, FS, PX, Color("ffffff"))
		var groesse := l0.font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, FS)
		if groesse.x < 10.0:   # ohne Schrift-Server (headless): schätzen
			var zeilen := txt.split("\n")
			var lang := 0
			for z in zeilen:
				lang = maxi(lang, z.length())
			groesse = Vector2(lang * FS * 0.62, zeilen.size() * FS * 1.35)
		l0.free()
		var tb := groesse.x * PX + 0.5
		var th := groesse.y * PX + 0.3
		var ty := 2.3 + th * 0.5
		var mitte := Vector3(p.x, ty, p.y)
		var t := RaumBau.box(n, Vector3(tb, th, 0.08), mitte, tafel)
		t.rotation.y = dreh
		var r := RaumBau.box(n, Vector3(tb + 0.1, th + 0.1, 0.05), mitte, rahmen)   # heller Rand rundum
		r.rotation.y = dreh
		for sx in [-1.0, 1.0]:
			var pp: Vector3 = Vector3(p.x, 0, p.y) + quer * sx * (tb * 0.5 + 0.13)
			RaumBau.zyl(n, 0.07, ty + th * 0.5 + 0.15, Vector3(pp.x, (ty + th * 0.5 + 0.15) * 0.5, pp.z), mast, 8)
			welt.hindernisse.append(Rect2(Vector2(pp.x, pp.z) - Vector2(0.2, 0.2), Vector2(0.4, 0.4)))
		for s in [1.0, -1.0]:
			var l := RaumBau.schrift(n, txt, mitte + Vector3(b.x, 0, b.y) * 0.06 * s, dreh if s > 0.0 else dreh + PI, FS, PX, Color("ffffff"))
			l.double_sided = false
			l.rotation.y = dreh if s > 0.0 else dreh + PI
