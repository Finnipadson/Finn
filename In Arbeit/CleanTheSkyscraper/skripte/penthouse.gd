class_name Penthouse
extends Node3D
# Eigenes Penthouse in den obersten zwei Stockwerken des Casino-Hochhauses (Aufzug im Casino):
# Glaswände rundum mit Blick auf den Turm, Vitrine mit den Pokalen der Erfolge, Tablet (Möbel-Katalog + Einrichten)
# und frei platzierbare Gegenstände aus Wirtschaft.moebel (steht = aufgestellt, nur dann wirkt der Bonus).
# Platzieren: Vorschau vor dem Spieler, R/Mausrad drehen, Linksklick/E abstellen, X ins Lager, Esc abbrechen.

const HALB := Casino.HALB - Casino.WAND      # Innenmaß (halb)
const STOCK_AB := Casino.TURM_STOCKWERKE - 2 # unterstes der zwei Stockwerke
const RASTER := 0.25
const ABSTAND := 2.6                         # so weit vor dem Spieler steht die Vorschau
const VITRINE_PLAETZE := 30

var mitte := Vector2.ZERO
var boden := 0.0
var decke := 0.0
var raum := {}
var stationen: Array = []
var wirtschaft: Wirtschaft
var feste: Array = []        # Rect2 (Welt) der festen Dinge (Aufzug, Vitrine, Tablet)
var knoten_moebel: Node3D
var knoten_pokale: Node3D
var innen: Node3D
var laeufer: Laeufer
# Platzieren
var platz_index := -1        # Index in wirtschaft.moebel, -1 = aus
var platz_alt := {}          # vorheriger Stand (zum Abbrechen)
var platz_dreh := 0.0
var platz_ok := false
var vorschau: Node3D
var _ok_mat: ShaderMaterial
var _nein_mat: ShaderMaterial

func setup(grundstueck: Rect2, w: Wirtschaft, l: Laeufer) -> void:
	wirtschaft = w
	laeufer = l
	mitte = grundstueck.get_center()
	position = Vector3(mitte.x, 0, mitte.y)
	boden = Casino.HOCH + 0.3 + STOCK_AB * 3.5 + 0.04
	decke = Casino.HOCH + 0.3 + Casino.TURM_STOCKWERKE * 3.5 - 0.3
	innen = Node3D.new()
	innen.visible = false
	add_child(innen)
	_raum()
	_aufzug()
	_vitrine()
	_tablet()
	knoten_moebel = Node3D.new()
	innen.add_child(knoten_moebel)
	_ok_mat = _vorschau_mat(Color(0.3, 1.0, 0.55))
	_nein_mat = _vorschau_mat(Color(1.0, 0.3, 0.3))
	raum = {"poly": PackedVector2Array([_w(-HALB + 0.35, -HALB + 0.35), _w(HALB - 0.35, -HALB + 0.35), _w(HALB - 0.35, HALB - 0.35), _w(-HALB + 0.35, HALB - 0.35)]),
		"rechtecke": [], "kreise": [], "boden": boden}
	aktualisieren()

func _w(x: float, z: float) -> Vector2:
	return mitte + Vector2(x, z)

func _fest(x0: float, z0: float, x1: float, z1: float) -> void:
	feste.append(Rect2(_w(x0, z0), Vector2(x1 - x0, z1 - z0)))

func ankunft() -> Vector2:
	return _w(7.6, 0.0)

# ---------------------------------------------------------------- Raum
func _raum() -> void:
	var h := HALB
	var poly := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var holz := StandardMaterial3D.new()
	holz.albedo_texture = _parkett()
	holz.uv1_scale = Vector3(1, 1, 1)
	holz.roughness = 0.45
	RaumBau.flaeche(innen, poly, boden, holz, true, 0.125)
	RaumBau.flaeche(innen, poly, decke, Bau.matt("f4f2ee", 0.9), false)
	RaumBau.waende(innen, PackedVector2Array([Vector2(-h, -h), Vector2(-h, h), Vector2(h, h), Vector2(h, -h)]), boden, decke, RaumBau.glas("d8eeff", 0.07))
	# Fensterpfosten, Sockel und Deckenleiste
	var stahl := Bau.metall("2b2f36", 0.35, 0.7)
	for i in 11:
		var t := -h + 2.0 * h * i / 10.0
		for p in [Vector2(t, -h), Vector2(t, h), Vector2(-h, t), Vector2(h, t)]:
			RaumBau.box(innen, Vector3(0.1, decke - boden, 0.1), Vector3(p.x, (boden + decke) * 0.5, p.y), stahl)
	for s in [-1.0, 1.0]:
		RaumBau.box(innen, Vector3(2.0 * h, 0.12, 0.14), Vector3(0, boden + 0.06, s * h), stahl)
		RaumBau.box(innen, Vector3(0.14, 0.12, 2.0 * h), Vector3(s * h, boden + 0.06, 0), stahl)
	# Lichter + Deckenspots
	for ix in 3:
		for iz in 3:
			var p := Vector3(-8.0 + ix * 8.0, decke - 0.8, -8.0 + iz * 8.0)
			RaumBau.licht(innen, p, "fff0dc", 1.1, 12.0)
			RaumBau.zyl(innen, 0.25, 0.04, Vector3(p.x, decke - 0.02, p.z), RaumBau.leuchte("fff6e6", 2.0), 16)
	# zwei Pflanzen + ein Schild
	RaumBau.modell(innen, "natur/plant_bushLarge", Vector3(-11.5, boden, -11.5), 1.4)
	RaumBau.modell(innen, "natur/plant_bushLarge", Vector3(-11.5, boden, 11.5), 1.4)
	_fest(-12.3, -12.3, -10.7, -10.7)
	_fest(-12.3, 10.7, -10.7, 12.3)

func _parkett() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in n:
		var reihe := y / 8
		var versatz := (reihe % 2) * 16
		for x in n:
			var brett := (x + versatz) / 32
			var ton := 0.92 + 0.08 * sin(float(brett * 7 + reihe * 3))
			var c := Color("c49a6c") * ton
			if y % 8 == 0 or (x + versatz) % 32 == 0:
				c = c.darkened(0.25)
			c = c.darkened(rng.randf() * 0.04)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _aufzug() -> void:
	var stein := Bau.matt("ece8e1", 0.4)
	var stahl := Bau.metall("c9ced4", 0.25, 0.85)
	RaumBau.box(innen, Vector3(3.2, decke - boden, 3.2), Vector3(11.0, (boden + decke) * 0.5, 0), stein)
	for s in [-1.0, 1.0]:
		RaumBau.box(innen, Vector3(0.06, 2.6, 0.95), Vector3(9.38, boden + 1.3, s * 0.49), stahl)
	RaumBau.box(innen, Vector3(0.1, 0.1, 0.04), Vector3(9.36, boden + 1.3, 1.3), RaumBau.leuchte("ffcf6a", 2.5))
	RaumBau.schrift(innen, "PENTHOUSE", Vector3(9.37, boden + 3.2, 0), -PI * 0.5, 90, 0.006, Color("2b2f36"))
	_fest(9.4, -1.6, 12.6, 1.6)
	stationen.append({"art": "aufzug_casino", "name": "Aufzug", "hinweis": "E: Aufzug", "pos": _w(7.6, 0.0), "ziel": _w(9.4, 0.0)})

# ---------------------------------------------------------------- Vitrine mit Pokalen
func _vitrine() -> void:
	var x := 12.2
	var z0 := 2.6
	var breite := 6.2
	var zm := z0 + breite * 0.5
	var dunkel := Bau.matt("20242c", 0.4)
	RaumBau.box(innen, Vector3(0.7, 0.3, breite), Vector3(x, boden + 0.15, zm), dunkel)
	RaumBau.box(innen, Vector3(0.7, 0.12, breite), Vector3(x, boden + 2.6, zm), dunkel)
	RaumBau.box(innen, Vector3(0.06, 2.3, breite), Vector3(x + 0.32, boden + 1.45, zm), Bau.matt("2c3340", 0.6))
	for j in 3:
		RaumBau.box(innen, Vector3(0.6, 0.03, breite - 0.1), Vector3(x, boden + 0.32 + j * 0.75, zm), RaumBau.glas("ffffff", 0.35))
		RaumBau.box(innen, Vector3(0.04, 0.03, breite - 0.1), Vector3(x - 0.3, boden + 0.34 + j * 0.75, zm), RaumBau.leuchte("fff1d6", 1.5))
	RaumBau.box(innen, Vector3(0.03, 2.3, breite), Vector3(x - 0.34, boden + 1.45, zm), RaumBau.glas("e8f4ff", 0.12))
	RaumBau.licht(innen, Vector3(x - 1.2, boden + 2.2, zm), "fff1d6", 0.8, 5.0)
	RaumBau.schrift(innen, "POKALE", Vector3(x - 0.36, boden + 2.85, zm), -PI * 0.5, 70, 0.0025, Color("2b2f36"))
	_fest(x - 0.4, z0, HALB, z0 + breite)
	knoten_pokale = Node3D.new()
	knoten_pokale.position = Vector3(x, boden, z0)
	innen.add_child(knoten_pokale)
	stationen.append({"art": "vitrine", "name": "Vitrine", "hinweis": "E: Erfolge und Statistik", "pos": _w(x - 1.9, zm), "ziel": _w(x, zm)})

# Pokal aus Klötzen und Zylindern (stufe 0–2 = Bronze/Silber/Gold)
static func pokal(stufe: int) -> Node3D:
	var n := Node3D.new()
	var m := Bau.metall(Erfolge.POKAL_FARBE[stufe], 0.22, 0.95)
	var gr := 0.85 + 0.15 * stufe
	RaumBau.box(n, Vector3(0.16, 0.06, 0.16) * gr, Vector3(0, 0.03 * gr, 0), Bau.matt("2b2620", 0.5))
	RaumBau.zyl(n, 0.018 * gr, 0.1 * gr, Vector3(0, 0.11 * gr, 0), m, 10)
	RaumBau.zyl(n, 0.075 * gr, 0.12 * gr, Vector3(0, 0.22 * gr, 0), m, 18, 0.03 * gr)
	for s in [-1.0, 1.0]:
		var t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.025 * gr
		tm.outer_radius = 0.04 * gr
		t.mesh = tm
		t.material_override = m
		t.position = Vector3(s * 0.075 * gr, 0.22 * gr, 0)
		t.rotation.x = PI * 0.5
		n.add_child(t)
	return n

func pokale_aktualisieren() -> void:
	for c in knoten_pokale.get_children():
		c.queue_free()
	var i := 0
	for e in Erfolge.LISTE:
		if not wirtschaft.erfolge.has(e.id) or i >= VITRINE_PLAETZE:
			continue
		var p := pokal(int(e.pokal))
		var reihe := i / 10
		var spalte := i % 10
		p.position = Vector3(-0.05, 0.34 + reihe * 0.75, 0.35 + spalte * 0.6)
		knoten_pokale.add_child(p)
		i += 1

# ---------------------------------------------------------------- Tablet (Katalog + Einrichten)
func _tablet() -> void:
	var p := Vector2(9.2, -5.0)
	RaumBau.box(innen, Vector3(0.5, 0.06, 0.5), Vector3(p.x, boden + 0.03, p.y), Bau.matt("2b2f36", 0.4))
	RaumBau.zyl(innen, 0.04, 1.1, Vector3(p.x, boden + 0.6, p.y), Bau.metall("c9ced4", 0.25, 0.85), 10)
	var schirm := RaumBau.box(innen, Vector3(0.05, 0.42, 0.6), Vector3(p.x - 0.05, boden + 1.25, p.y), RaumBau.leuchte("35c8ff", 1.2))
	schirm.rotation.z = 0.5
	_fest(p.x - 0.35, p.y - 0.35, p.x + 0.35, p.y + 0.35)
	stationen.append({"art": "tablet", "name": "Möbel-Tablet", "hinweis": "E: Möbel kaufen und einrichten", "pos": _w(p.x - 1.5, p.y), "ziel": _w(p.x, p.y)})

# ---------------------------------------------------------------- Möbel aufstellen
func aktualisieren() -> void:
	for c in knoten_moebel.get_children():
		c.queue_free()
	raum.rechtecke = feste.duplicate()
	for i in wirtschaft.moebel.size():
		var m: Dictionary = wirtschaft.moebel[i]
		if not m.steht or i == platz_index:
			continue
		var n := Moebel.modell(m.id)
		n.position = Vector3(float(m.x), boden, float(m.z))
		n.rotation.y = deg_to_rad(float(m.dreh))
		knoten_moebel.add_child(n)
		var r := _rect(m.id, Vector2(m.x, m.z), float(m.dreh))
		if Moebel.hoehe(m.id) > 0.15:
			raum.rechtecke.append(r)
	pokale_aktualisieren()

# Grundfläche als Rechteck (Welt) – x/z im Penthouse sind lokale Koordinaten
func _rect(id: String, p: Vector2, dreh: float) -> Rect2:
	var f := Moebel.flaeche(id, dreh)
	return Rect2(mitte + p - f * 0.5, f).grow(-0.05)

func platzieren_start(index: int) -> void:
	platz_index = index
	var m: Dictionary = wirtschaft.moebel[index]
	platz_alt = m.duplicate()
	platz_dreh = float(m.dreh)
	if vorschau:
		vorschau.queue_free()
	vorschau = Moebel.modell(m.id)
	innen.add_child(vorschau)
	aktualisieren()

func platzieren_aktiv() -> bool:
	return platz_index >= 0

func drehen(schritt: float) -> void:
	platz_dreh = fposmod(platz_dreh + schritt, 360.0)

# Ende: abstellen (true) oder abbrechen. lager = ins Lager räumen
func platzieren_ende(abstellen: bool, lager := false) -> bool:
	if platz_index < 0:
		return false
	var m: Dictionary = wirtschaft.moebel[platz_index]
	var ok := true
	if lager:
		m.steht = false
	elif abstellen:
		if not platz_ok:
			return false
		var p := _vorschau_punkt()
		m.x = p.x
		m.z = p.y
		m.dreh = platz_dreh
		m.steht = true
	else:
		for k in platz_alt:
			m[k] = platz_alt[k]
		ok = false
	platz_index = -1
	if vorschau:
		vorschau.queue_free()
		vorschau = null
	aktualisieren()
	return ok

# Punkt vor dem Spieler (lokal), auf das Raster gerundet und im Raum gehalten
func _vorschau_punkt() -> Vector2:
	var vor := Vector2(-sin(laeufer.yaw), -cos(laeufer.yaw))
	var p := Vector2(laeufer.position.x, laeufer.position.z) - mitte + vor * ABSTAND
	p = (p / RASTER).round() * RASTER
	var g := HALB - 0.4
	return Vector2(clampf(p.x, -g, g), clampf(p.y, -g, g))

func _process(_dt: float) -> void:
	if platz_index < 0 or not vorschau:
		return
	var id: String = wirtschaft.moebel[platz_index].id
	var p := _vorschau_punkt()
	vorschau.position = Vector3(p.x, boden, p.y)
	vorschau.rotation.y = deg_to_rad(platz_dreh)
	var r := _rect(id, p, platz_dreh)
	var g := HALB - 0.3
	platz_ok = r.position.x >= mitte.x - g and r.end.x <= mitte.x + g and r.position.y >= mitte.y - g and r.end.y <= mitte.y + g
	var flach := Moebel.hoehe(id) <= 0.15
	if platz_ok and not flach:
		for q in raum.rechtecke:
			if r.intersects(q):
				platz_ok = false
				break
		if r.grow(Laeufer.RADIUS).has_point(Vector2(laeufer.position.x, laeufer.position.z)):
			platz_ok = false
	RaumBau.faerben(vorschau, _ok_mat if platz_ok else _nein_mat, true)

func _vorschau_mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shader/seltenheit.gdshader")
	m.set_shader_parameter("farbe", c)
	m.set_shader_parameter("kraft", 1.6)
	return m

# Aufgestellter Gegenstand direkt vor dem Spieler (zum Umstellen), -1 = keiner
func gegenstand_vorne() -> int:
	var pos := Vector2(laeufer.position.x, laeufer.position.z) - mitte
	var vor := Vector2(-sin(laeufer.yaw), -cos(laeufer.yaw))
	var beste := -1
	var best_d := 2.6
	for i in wirtschaft.moebel.size():
		var m: Dictionary = wirtschaft.moebel[i]
		if not m.steht:
			continue
		var d := Vector2(m.x, m.z) - pos
		var l := d.length()
		if l < best_d and (l < 0.8 or d.normalized().dot(vor) > 0.6):
			best_d = l
			beste = i
	return beste
