class_name Casino
extends Node3D
# Begehbares, modernes Casino auf dem Grundstück Welt.casino_rect (Eingang zur Turmseite, −X).
# Gebäude aus Code (dunkle Fassade, Gold, Leuchtschrift), innen Teppich, Licht und vier Spielstationen:
# Blackjack-Tisch, Glücksrad, einarmige Banditen, Rubbellos-Theke. Davor stehen und E drücken → CasinoMenu.
# Figuren und Kleinteile aus den Kenney-Paketen (CC0) in modelle/.

const STATIONEN := [
	{"id": "blackjack", "name": "Blackjack", "hinweis": "Blackjack spielen"},
	{"id": "rad", "name": "Glücksrad", "hinweis": "Glücksrad drehen"},
	{"id": "bandit", "name": "Einarmiger Bandit", "hinweis": "Einarmigen Banditen spielen"},
	{"id": "los", "name": "Rubbellose", "hinweis": "Rubbellos kaufen"},
]
const HALB := 13.0               # halbe Kantenlänge des Gebäudes (26 × 26 m auf dem 30-m-Grundstück)
const HOCH := 6.5
const WAND := 0.4
const TUER := 5.0                # Breite der Tür-Öffnung
const TUER_H := 3.4
const NAH := 2.3                 # so nah muss man an einer Station stehen

var mitte := Vector2.ZERO        # Mitte des Gebäudes (x, z) in der Welt
var vorne: Array = []            # Vector2: Standpunkt vor jeder Station (Welt)
var ziel: Array = []             # Vector2: wohin man dort schaut (Welt)
var rechtecke: Array = []        # Rect2 für die Kollision zu Fuß (Wände + Stationen)
var eingang := Vector2.ZERO      # Punkt draußen vor der Tür (Welt)
var rad: Node3D                  # dreht sich langsam
var _leucht: Array = []          # blinkende Leuchtstreifen
var turm_mat: ShaderMaterial     # Fassade des Hochhauses darüber (Penthouse: innen_band)
var aufzug_pos := Vector2.ZERO   # vor der Aufzugstür (Welt) – Aufzug zur Arcade-Halle und ins Penthouse

func setup(grundstueck: Rect2) -> void:
	mitte = grundstueck.get_center()
	position = Vector3(mitte.x, 0, mitte.y)
	eingang = mitte + Vector2(-HALB - 6.0, 0)
	_gebaeude()
	_innen()
	_blackjack(Vector2(3.0, -7.6))
	_gluecksrad()
	_banditen()
	_lose(Vector2(-7.5, 9.6))
	_bar()
	_aufzug()

# Welche Station ist nah genug? (-1 = keine)
func station_bei(p: Vector2) -> int:
	for i in vorne.size():
		if p.distance_to(vorne[i]) < NAH:
			return i
	return -1

func drinnen(p: Vector2) -> bool:
	return absf(p.x - mitte.x) < HALB and absf(p.y - mitte.y) < HALB

func _process(dt: float) -> void:
	if rad:
		rad.rotation.x += dt * 0.35
	var t := Time.get_ticks_msec() * 0.001
	for i in _leucht.size():
		var m: StandardMaterial3D = _leucht[i]
		m.emission_energy_multiplier = 1.6 + sin(t * 2.0 + i * 1.3) * 0.8

# ---------------------------------------------------------------- Bausteine
func _box(g: Vector3, p: Vector3, m: Material, eltern: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = g
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	(eltern if eltern else self).add_child(mi)
	return mi

func _zyl(r: float, h: float, p: Vector3, m: Material, seg := 24) -> MeshInstance3D:
	var z := Bau.zylinder(r, r, h, m, seg)
	z.position = p
	add_child(z)
	return z

func _leuchte(farbe: String, kraft := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(farbe)
	m.emission_enabled = true
	m.emission = Color(farbe)
	m.emission_energy_multiplier = kraft
	return m

func _licht(p: Vector3, farbe: String, kraft: float, weit: float) -> void:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = Color(farbe)
	l.light_energy = kraft
	l.omni_range = weit
	add_child(l)

func _schrift(t: String, p: Vector3, dreh: float, groesse: int, pixel: float, farbe: Color) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font_size = groesse
	l.pixel_size = pixel
	l.outline_size = 0
	l.modulate = farbe
	l.shaded = false
	l.position = p
	l.rotation.y = dreh
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI Black", "Arial Black", "Segoe UI"])
	f.font_weight = 900
	l.font = f
	add_child(l)
	return l

# Kenney-Modell (wie in haendler.gd); Figuren spielen ihre Ruhe-Animation
func _modell(name: String, p: Vector3, s: float, dreh := 0.0) -> Node3D:
	var pfad := "res://modelle/%s.glb" % name
	if not ResourceLoader.exists(pfad):
		push_warning("Modell fehlt: " + pfad)
		return Node3D.new()
	var n: Node3D = load(pfad).instantiate()
	n.position = p
	n.rotation.y = dreh
	n.scale = Vector3.ONE * s
	add_child(n)
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		var namen := ap.get_animation_list()
		var wahl := ""
		for a in namen:
			if "idle" in a.to_lower():
				wahl = a
				break
		if wahl == "" and namen.size() > 0:
			wahl = namen[0]
		if wahl != "":
			ap.get_animation(wahl).loop_mode = Animation.LOOP_LINEAR
			ap.play(wahl)
	return n

# Hindernis in Gebäude-Koordinaten (x0, z0, x1, z1) → Welt
func _fest(x0: float, z0: float, x1: float, z1: float) -> void:
	rechtecke.append(Rect2(mitte + Vector2(x0, z0), Vector2(x1 - x0, z1 - z0)))

func _station(steh: Vector2, blick: Vector2) -> void:
	vorne.append(mitte + steh)
	ziel.append(mitte + blick)

# ---------------------------------------------------------------- Gebäude
func _gebaeude() -> void:
	var dunkel := Bau.matt("1b1e2a", 0.45)
	var gold := Bau.metall("d9a441", 0.25, 0.9)
	var h := HALB
	var mw := h - WAND * 0.5      # Wandmitte
	# Wände: hinten (+X), Seiten (±Z), vorne (−X) mit Tür-Öffnung
	_box(Vector3(WAND, HOCH, h * 2.0), Vector3(mw, HOCH * 0.5, 0), dunkel)
	_fest(h - WAND, -h, h, h)
	for s in [-1.0, 1.0]:
		_box(Vector3(h * 2.0, HOCH, WAND), Vector3(0, HOCH * 0.5, s * mw), dunkel)
		_fest(-h, s * mw - WAND * 0.5, h, s * mw + WAND * 0.5)
		var lang: float = h - TUER * 0.5
		var zm: float = s * (TUER * 0.5 + lang * 0.5)
		_box(Vector3(WAND, HOCH, lang), Vector3(-mw, HOCH * 0.5, zm), dunkel)
		_fest(-h, zm - lang * 0.5, -h + WAND, zm + lang * 0.5)
		# Leuchtstreifen an den vorderen Ecken
		var lm := _leuchte("ff3fa0" if s < 0 else "35c8ff")
		_leucht.append(lm)
		_box(Vector3(0.12, HOCH - 0.4, 0.12), Vector3(-h - 0.08, HOCH * 0.5, s * (h + 0.04)), lm)
	_box(Vector3(WAND, HOCH - TUER_H, TUER), Vector3(-mw, TUER_H + (HOCH - TUER_H) * 0.5, 0), dunkel)   # Sturz über der Tür
	# Türrahmen in Gold
	for s in [-1.0, 1.0]:
		_box(Vector3(WAND + 0.1, TUER_H, 0.16), Vector3(-mw, TUER_H * 0.5, s * TUER * 0.5), gold)
	_box(Vector3(WAND + 0.1, 0.16, TUER + 0.16), Vector3(-mw, TUER_H, 0), gold)
	# Dach mit Goldkante
	_box(Vector3(h * 2.0 + 0.8, 0.3, h * 2.0 + 0.8), Vector3(0, HOCH + 0.15, 0), dunkel)
	_box(Vector3(h * 2.0 + 0.9, 0.12, h * 2.0 + 0.9), Vector3(0, HOCH - 0.1, 0), gold)
	_box(Vector3(h * 2.0 + 0.5, 0.25, h * 2.0 + 0.5), Vector3(0, 0.125, 0), Bau.matt("2a2d38", 0.6))     # Sockel außen
	# Vordach über dem Eingang mit Lichtern
	_box(Vector3(3.6, 0.25, TUER + 3.0), Vector3(-h - 1.8, TUER_H + 0.45, 0), dunkel)
	_box(Vector3(3.7, 0.08, TUER + 3.1), Vector3(-h - 1.8, TUER_H + 0.3, 0), gold)
	var warm := _leuchte("ffe2a0", 2.5)
	for k in 5:
		_box(Vector3(0.3, 0.05, 0.3), Vector3(-h - 1.8, TUER_H + 0.25, -3.0 + k * 1.5), warm)
	_licht(Vector3(-h - 1.8, TUER_H - 0.3, 0), "ffe2a0", 1.5, 8.0)
	# Roter Teppich draußen + Absperrpfosten
	_box(Vector3(7.0, 0.05, 3.4), Vector3(-h - 3.3, 0.06, 0), Bau.matt("a01428", 0.95))
	for s in [-1.0, 1.0]:
		for k in 3:
			_zyl(0.06, 1.0, Vector3(-h - 1.2 - k * 2.4, 0.5, s * 2.0), gold, 10)
			_zyl(0.16, 0.05, Vector3(-h - 1.2 - k * 2.4, 0.03, s * 2.0), gold, 14)
		_box(Vector3(4.8, 0.06, 0.06), Vector3(-h - 3.6, 0.9, s * 2.0), Bau.matt("7a1020", 0.8))
		# Pflanzkübel
		_box(Vector3(1.2, 0.9, 1.2), Vector3(-h - 1.0, 0.45, s * 4.6), Bau.matt("2a2d38", 0.5))
		var busch := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.75
		sm.height = 1.5
		busch.mesh = sm
		busch.material_override = Bau.matt("3f8a4a", 0.9)
		busch.position = Vector3(-h - 1.0, 1.4, s * 4.6)
		add_child(busch)
		_fest(-h - 1.6, s * 4.6 - 0.6, -h - 0.4, s * 4.6 + 0.6)
	# Außen: Glasfassade wie bei den Hochhäusern der Stadt, darüber der Turm (Casino ist das Erdgeschoss)
	_verkleidung()
	_turm_drauf()
	# Leuchtschrift an der Fassade über dem Eingang, mit dunkler Tafel und Lichterkette
	_box(Vector3(0.12, 1.7, 11.0), Vector3(-h - 0.14, TUER_H + 1.75, 0), dunkel)
	_box(Vector3(0.14, 0.1, 11.2), Vector3(-h - 0.15, TUER_H + 2.62, 0), gold)
	_box(Vector3(0.14, 0.1, 11.2), Vector3(-h - 0.15, TUER_H + 0.88, 0), gold)
	_schrift("CASINO", Vector3(-h - 0.22, TUER_H + 1.75, 0), -PI / 2.0, 200, 0.0105, Color(1.0, 0.82, 0.3))
	var stern := _leuchte("ffd060", 3.0)
	_leucht.append(stern)
	for k in 11:
		_box(Vector3(0.08, 0.14, 0.14), Vector3(-h - 0.22, TUER_H + 0.95, -5.0 + k * 1.0), stern)
	# kleinere Schrift an den beiden Seiten
	for s2 in [-1.0, 1.0]:
		_box(Vector3(9.0, 1.3, 0.12), Vector3(0, HOCH - 1.5, s2 * (h + 0.14)), dunkel)
		_schrift("CASINO", Vector3(0, HOCH - 1.5, s2 * (h + 0.22)), PI if s2 < 0 else 0.0, 160, 0.0095, Color(1.0, 0.82, 0.3))

const TURM_STOCKWERKE := 34     # so viele Stockwerke (je 3,5 m) stehen über dem Casino

func _fassaden_mat() -> ShaderMaterial:
	return Bau.shader_mat(Bau.FASSADE_SHADER, {"glas": Color("8fb1c9"), "rahmen": Color("9aa3ad"), "bruestung": Color("8a929c"), "stock": 3.5, "fenster_breite": 1.8, "dreckig": 0.0, "metall": 0.7})

# Glasfassade außen um das Erdgeschoss (Innenwände bleiben dunkel); vorne mit Tür-Öffnung
func _verkleidung() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var o := HALB + 0.06
	var y0 := 0.25
	var y1 := HOCH + 0.3
	var t := TUER * 0.5
	# [von, bis, unten, oben] in Gebäude-Koordinaten (x, z), Außenseite links der Laufrichtung
	var stuecke := [
		[Vector2(o, -o), Vector2(o, o), y0, y1],          # hinten (+X)
		[Vector2(o, o), Vector2(-o, o), y0, y1],          # Seite +Z
		[Vector2(-o, -o), Vector2(o, -o), y0, y1],        # Seite −Z
		[Vector2(-o, o), Vector2(-o, t), y0, y1],         # vorne neben der Tür
		[Vector2(-o, -t), Vector2(-o, -o), y0, y1],
		[Vector2(-o, t), Vector2(-o, -t), TUER_H, y1],    # über der Tür
	]
	var weg := 0.0
	for e in stuecke:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var u0: float = e[2]
		var u1: float = e[3]
		var n2 := (b - a).normalized().orthogonal()
		if n2.dot((a + b) * 0.5) < 0.0:
			n2 = -n2
		var n := Vector3(n2.x, 0, n2.y)
		var lang := a.distance_to(b)
		var ecken := [[a, weg, u0], [b, weg + lang, u0], [b, weg + lang, u1], [a, weg, u0], [b, weg + lang, u1], [a, weg, u1]]
		# Vorderseite = im Uhrzeigersinn von außen gesehen
		var p0 := Vector3(a.x, u0, a.y)
		var p1 := Vector3(b.x, u0, b.y)
		var p2 := Vector3(b.x, u1, b.y)
		if (p2 - p0).cross(p1 - p0).dot(n) < 0.0:
			ecken = [[a, weg, u0], [b, weg + lang, u1], [b, weg + lang, u0], [a, weg, u0], [a, weg, u1], [b, weg + lang, u1]]
		var tg := Vector3(b.x - a.x, 0, b.y - a.y).normalized()
		for k in ecken:
			st.set_normal(n)
			st.set_tangent(Plane(tg, 1.0))
			st.set_uv(Vector2(k[1], k[2]))
			var q: Vector2 = k[0]
			st.add_vertex(Vector3(q.x, k[2], q.y))
		weg += lang
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _fassaden_mat()
	add_child(mi)

# Hochhaus über dem Casino, gleiche Fassade
func _turm_drauf() -> void:
	var poly := Bau.rechteck(HALB * 2.0 + 0.12, HALB * 2.0 + 0.12)
	var stw := []
	for k in TURM_STOCKWERKE:
		stw.append({"poly": poly, "y0": HOCH + 0.3 + k * 3.5, "h": 3.5})
	turm_mat = _fassaden_mat()
	add_child(Bau.baue(stw, turm_mat, Bau.matt("bdb3a3")))

# ---------------------------------------------------------------- Innenraum
func _teppich() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rot := Color("7a1428")
	var dunkel := Color("5c0e1f")
	var gold := Color("c9983e")
	for y in n:
		for x in n:
			var dx := absf(x - n * 0.5 + 0.5)
			var dy := absf(y - n * 0.5 + 0.5)
			var d := dx + dy            # Raute
			var c := rot
			if d < 7.0:
				c = gold
			elif d < 20.0:
				c = dunkel
			elif absf(d - 30.0) < 1.5:
				c = gold
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _innen() -> void:
	var h := HALB - WAND
	# Teppich
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = _teppich()
	tm.uv1_scale = Vector3(13, 13, 1)
	tm.roughness = 1.0
	var boden := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(h * 2.0, h * 2.0)
	boden.mesh = pm
	boden.material_override = tm
	boden.position = Vector3(0, 0.27, 0)
	add_child(boden)
	_box(Vector3(WAND + 0.2, 0.04, TUER), Vector3(-HALB + WAND * 0.5, 0.27, 0), Bau.metall("d9a441", 0.3, 0.9))   # Türschwelle
	# Innenverkleidung der Wände (weinrot, unten dunkles Holz) + Goldleiste
	var wein := Bau.matt("5a1a2c", 0.8)
	var holz := Bau.matt("2c1a14", 0.5)
	var gold := Bau.metall("d9a441", 0.25, 0.9)
	_box(Vector3(0.06, HOCH, h * 2.0), Vector3(h - 0.03, HOCH * 0.5, 0), wein)
	_box(Vector3(0.1, 1.2, h * 2.0), Vector3(h - 0.05, 0.85, 0), holz)
	_box(Vector3(0.12, 0.06, h * 2.0), Vector3(h - 0.06, 1.47, 0), gold)
	for s in [-1.0, 1.0]:
		_box(Vector3(h * 2.0, HOCH, 0.06), Vector3(0, HOCH * 0.5, s * (h - 0.03)), wein)
		_box(Vector3(h * 2.0, 1.2, 0.1), Vector3(0, 0.85, s * (h - 0.05)), holz)
		_box(Vector3(h * 2.0, 0.06, 0.12), Vector3(0, 1.47, s * (h - 0.06)), gold)
		var lang: float = h - TUER * 0.5
		var zm: float = s * (TUER * 0.5 + lang * 0.5)
		_box(Vector3(0.06, HOCH, lang), Vector3(-h + 0.03, HOCH * 0.5, zm), wein)
		_box(Vector3(0.1, 1.2, lang), Vector3(-h + 0.05, 0.85, zm), holz)
	_box(Vector3(0.06, HOCH - TUER_H - 0.1, TUER), Vector3(-h + 0.03, TUER_H + (HOCH - TUER_H) * 0.5 + 0.05, 0), wein)
	# Decke mit Lichtfeldern
	_box(Vector3(h * 2.0, 0.1, h * 2.0), Vector3(0, HOCH - 0.2, 0), Bau.matt("15161d", 0.9))
	var feld := _leuchte("fff0cf", 1.8)
	for ix in 3:
		for iz in 3:
			var p := Vector3(-8.0 + ix * 8.0, HOCH - 0.27, -8.0 + iz * 8.0)
			_box(Vector3(2.6, 0.05, 2.6), p, feld)
			_box(Vector3(2.9, 0.07, 2.9), p + Vector3(0, 0.02, 0), gold)
	for ix in 2:
		for iz in 2:
			_licht(Vector3(-6.0 + ix * 12.0, HOCH - 1.4, -6.0 + iz * 12.0), "ffe6bd", 2.2, 15.0)
	_licht(Vector3(0, HOCH - 1.4, 0), "ffe6bd", 2.0, 14.0)
	# vier Säulen mit Goldring
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_zyl(0.35, HOCH - 0.5, Vector3(sx * 4.5, (HOCH - 0.5) * 0.5 + 0.25, sz * 3.6), Bau.matt("20222c", 0.35), 20)
			_zyl(0.4, 0.3, Vector3(sx * 4.5, 0.42, sz * 3.6), gold, 20)
			_zyl(0.4, 0.3, Vector3(sx * 4.5, HOCH - 0.45, sz * 3.6), gold, 20)
			_fest(sx * 4.5 - 0.35, sz * 3.6 - 0.35, sx * 4.5 + 0.35, sz * 3.6 + 0.35)
	# ein paar Gäste
	_modell("leute/character-female-a", Vector3(6.4, 0.27, 4.5), 2.5, -2.2)
	_modell("leute/character-male-e", Vector3(7.3, 0.27, 5.4), 2.5, 2.4)
	_fest(5.9, 4.0, 7.8, 5.9)

# ---------------------------------------------------------------- 1 Blackjack
func _blackjack(m: Vector2) -> void:
	var filz := Bau.matt("1e7a45", 0.95)
	var holz := Bau.matt("3a2218", 0.4)
	var gold := Bau.metall("d9a441", 0.25, 0.9)
	_zyl(0.5, 0.75, Vector3(m.x, 0.64, m.y), holz, 16)
	_zyl(1.95, 0.12, Vector3(m.x, 1.05, m.y), holz, 40)
	_zyl(1.8, 0.04, Vector3(m.x, 1.12, m.y), filz, 40)
	_zyl(0.7, 0.05, Vector3(m.x, 0.3, m.y), gold, 20)
	# Karten und Chips auf dem Tisch
	var weiss := Bau.matt("f6f3ea", 0.6)
	for k in 2:
		var kp := _box(Vector3(0.24, 0.01, 0.34), Vector3(m.x - 0.2 + k * 0.3, 1.15, m.y + 0.8), weiss)
		kp.rotation.y = 0.15 - k * 0.3
		var kg := _box(Vector3(0.24, 0.01, 0.34), Vector3(m.x - 0.15 + k * 0.3, 1.15, m.y - 0.7), weiss if k == 0 else Bau.matt("1f5fae", 0.6))
		kg.rotation.y = -0.1 + k * 0.2
	var chipf := ["d83a3a", "2f86c8", "2e8b3d", "1b1e2a", "f2c230"]
	for k in 5:
		_zyl(0.09, 0.05 + 0.03 * ((k * 3) % 4), Vector3(m.x + 0.9 + (k % 3) * 0.22, 1.17, m.y - 0.5 + (k / 3) * 0.24), Bau.matt(chipf[k], 0.5), 14)
	_box(Vector3(0.5, 0.14, 0.3), Vector3(m.x - 1.1, 1.21, m.y - 0.6), Bau.matt("1b1e2a", 0.4))   # Kartenschlitten
	# Geber hinter dem Tisch (schaut nach +Z, zum Spieler)
	_box(Vector3(1.4, 0.4, 1.0), Vector3(m.x, 0.45, m.y - 2.35), Bau.matt("20222c", 0.5))   # Podest für den Geber
	_modell("laden/character-employee", Vector3(m.x, 0.65, m.y - 2.35), 2.8, 0.0)
	_licht(Vector3(m.x, 3.4, m.y), "eaffea", 1.6, 6.0)
	_box(Vector3(1.6, 0.08, 1.6), Vector3(m.x, 3.9, m.y), _leuchte("eaffea", 1.5))
	_schrift("BLACKJACK", Vector3(m.x, 4.4, -HALB + WAND + 0.1), 0.0, 96, 0.008, Color(0.7, 1.0, 0.75))
	_fest(m.x - 1.9, m.y - 2.8, m.x + 1.9, m.y + 1.9)
	_station(m + Vector2(0, 3.2), m + Vector2(0, -0.6))

# ---------------------------------------------------------------- 2 Glücksrad (an der Rückwand)
func _rad_bild() -> ImageTexture:
	var n := 512
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var felder := CasinoRegeln.RAD.size()
	for y in n:
		for x in n:
			var v := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
			var r := v.length()
			var c := Color(0, 0, 0, 0)
			if r < 0.16:
				c = Color("d9a441")
			elif r < 0.9:
				var w := fposmod(atan2(v.x, -v.y), TAU) / TAU * felder
				c = CasinoRegeln.rad_farbe(float(CasinoRegeln.RAD[int(w) % felder]))
				if absf(w - roundf(w)) < 0.06:
					c = Color("f6f3ea")
			elif r < 1.0:
				c = Color("d9a441")
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _gluecksrad() -> void:
	var x := HALB - WAND - 0.5
	var gold := Bau.metall("d9a441", 0.25, 0.9)
	_box(Vector3(0.5, 3.2, 0.5), Vector3(x + 0.1, 1.85, 0), Bau.matt("20222c", 0.4))
	_box(Vector3(1.4, 0.35, 3.2), Vector3(x - 0.2, 0.44, 0), Bau.matt("2c1a14", 0.5))
	rad = Node3D.new()
	rad.position = Vector3(x - 0.25, 3.3, 0)
	add_child(rad)
	var scheibe := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(4.6, 4.6)
	scheibe.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = _rad_bild()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.5
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission_energy_multiplier = 0.35
	scheibe.material_override = m
	scheibe.rotation.y = -PI / 2.0     # Vorderseite nach −X (in den Raum)
	rad.add_child(scheibe)
	# Zeiger oben
	var zeiger := _box(Vector3(0.12, 0.6, 0.3), Vector3(x - 0.35, 5.55, 0), _leuchte("ff3b30", 1.5))
	zeiger.rotation.x = 0.0
	_zyl(0.12, 0.3, Vector3(x - 0.3, 3.3, 0), gold, 12).rotation.z = PI / 2.0
	_licht(Vector3(x - 2.6, 4.2, 0), "fff0cf", 1.6, 7.0)
	_schrift("
GLÜCKSRAD", Vector3(x + 0.38, 6.45, 0), -PI / 2.0, 96, 0.008, Color(1.0, 0.85, 0.4))
	_fest(x - 0.9, -1.7, HALB, 1.7)
	_station(Vector2(x - 2.6, 0), Vector2(x, 0))

# ---------------------------------------------------------------- 3 Einarmige Banditen (an der Wand +Z)
func _banditen() -> void:
	var z := HALB - WAND - 0.55
	var farben := ["d83a3a", "2f86c8", "8a3fd0", "2e8b3d"]
	var chrom := Bau.metall("c9ced6", 0.2, 0.9)
	for k in 4:
		var x: float = -1.2 + k * 1.5
		var f: String = farben[k]
		_box(Vector3(1.1, 1.1, 0.9), Vector3(x, 0.82, z), Bau.matt("20222c", 0.4))              # Unterteil
		_box(Vector3(1.1, 1.3, 0.75), Vector3(x, 2.0, z + 0.07), Bau.matt(f, 0.35))             # Oberteil
		_box(Vector3(0.9, 0.5, 0.05), Vector3(x, 2.1, z - 0.32), _leuchte("fdf6e0", 0.9))       # Walzenfenster
		for w in 3:   # drei Symbole (bunte Felder)
			_box(Vector3(0.22, 0.34, 0.03), Vector3(x - 0.28 + w * 0.28, 2.1, z - 0.36), Bau.matt(["f2c230", "2f86c8", "9aa0a8"][(w + k) % 3], 0.5))
		_box(Vector3(1.1, 0.3, 0.8), Vector3(x, 2.8, z + 0.05), _leuchte(f, 1.4))               # Leuchtkopf
		_box(Vector3(0.9, 0.12, 0.3), Vector3(x, 1.42, z - 0.5), chrom)                         # Ablage
		_box(Vector3(0.06, 0.7, 0.06), Vector3(x + 0.62, 1.9, z - 0.1), chrom)                  # Hebel
		var knauf := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.1
		sm.height = 0.2
		knauf.mesh = sm
		knauf.material_override = Bau.matt("d83a3a", 0.3)
		knauf.position = Vector3(x + 0.62, 2.3, z - 0.1)
		add_child(knauf)
		_zyl(0.22, 0.5, Vector3(x, 0.52, z - 1.1), Bau.matt("20222c", 0.4), 14)                 # Hocker
		_zyl(0.28, 0.1, Vector3(x, 0.82, z - 1.1), Bau.matt("a01428", 0.8), 16)
	_licht(Vector3(1.0, 3.6, z - 2.2), "ffd9f2", 1.5, 7.0)
	_schrift("EINARMIGER BANDIT", Vector3(1.05, 4.6, HALB - WAND - 0.1), PI, 96, 0.008, Color(1.0, 0.6, 0.85))
	_fest(-2.0, z - 1.4, 4.1, HALB)
	_station(Vector2(1.05, z - 3.3), Vector2(1.05, z))

# ---------------------------------------------------------------- 4 Rubbellose (Theke)
func _lose(m: Vector2) -> void:
	var gold := Bau.metall("d9a441", 0.25, 0.9)
	_box(Vector3(3.6, 1.05, 0.8), Vector3(m.x, 0.8, m.y), Bau.matt("2c1a14", 0.5))
	_box(Vector3(3.8, 0.07, 0.95), Vector3(m.x, 1.36, m.y), Bau.matt("f4f4f2", 0.3))
	_box(Vector3(3.6, 0.12, 0.05), Vector3(m.x, 0.9, m.y - 0.42), _leuchte("f2c230", 1.2))
	_box(Vector3(1.4, 0.4, 1.0), Vector3(m.x, 0.45, m.y + 1.2), Bau.matt("20222c", 0.5))
	_modell("leute/character-female-c", Vector3(m.x, 0.65, m.y + 1.2), 2.8, PI)
	_modell("laden/cash-register", Vector3(m.x + 1.2, 1.4, m.y), 0.9, PI)
	# Lose in der Auslage: schräger Aufsteller mit bunten Karten
	var auf := _box(Vector3(1.3, 0.04, 0.5), Vector3(m.x - 1.15, 1.5, m.y), Bau.matt("20222c", 0.5))
	auf.rotation.x = 0.45
	var lf := ["f2c230", "35c8ff", "ff3fa0", "7fdc6a", "f2c230", "ff8a3a"]
	for k in 6:
		var l := _box(Vector3(0.3, 0.01, 0.18), Vector3(m.x - 1.55 + (k % 3) * 0.4, 1.48 + (0.1 if k >= 3 else 0.0), m.y - 0.1 + (0.21 if k >= 3 else 0.0)), Bau.matt(lf[k], 0.5))
		l.rotation.x = 0.45
	_box(Vector3(3.0, 1.0, 0.08), Vector3(m.x, 4.0, HALB - WAND - 0.12), Bau.matt("20222c", 0.5))
	_box(Vector3(3.1, 0.06, 0.1), Vector3(m.x, 3.48, HALB - WAND - 0.12), gold)
	_schrift("RUBBELLOSE", Vector3(m.x, 4.0, HALB - WAND - 0.18), PI, 96, 0.0065, Color(1.0, 0.9, 0.35))
	_licht(Vector3(m.x, 3.0, m.y - 1.0), "fff0cf", 1.4, 6.0)
	_fest(m.x - 1.9, m.y - 0.45, m.x + 1.9, HALB)
	_station(m + Vector2(0, -2.0), m)

# ---------------------------------------------------------------- Bar (nur Deko)
func _bar() -> void:
	var m := Vector2(-7.5, -10.2)
	_box(Vector3(5.0, 1.1, 0.8), Vector3(m.x, 0.82, m.y), Bau.matt("2c1a14", 0.5))
	_box(Vector3(5.2, 0.07, 1.0), Vector3(m.x, 1.4, m.y), Bau.matt("1b1e2a", 0.15))
	_box(Vector3(5.0, 0.1, 0.05), Vector3(m.x, 0.6, m.y + 0.42), _leuchte("35c8ff", 1.4))
	_box(Vector3(4.6, 2.0, 0.3), Vector3(m.x, 2.2, -HALB + WAND + 0.2), Bau.matt("20222c", 0.4))        # Rückregal
	for k in 3:
		_box(Vector3(4.4, 0.05, 0.34), Vector3(m.x, 1.6 + k * 0.6, -HALB + WAND + 0.24), _leuchte("ffcf8a", 0.9))
	var x := m.x - 1.9
	for e in ["essen/glass", "essen/soda-bottle", "essen/frappe", "essen/glass", "essen/soda", "essen/soda-bottle", "essen/glass", "essen/lemon"]:
		_modell(e, Vector3(x, 1.44, m.y - 0.05), 1.25, PI)
		_modell(e, Vector3(x + 0.1, 1.63, -HALB + WAND + 0.3), 1.1, PI)
		x += 0.55
	_modell("leute/character-male-b", Vector3(m.x, 0.27, m.y - 1.2), 2.6, 0.0)
	for k in 4:
		var hx: float = m.x - 1.8 + k * 1.2
		_zyl(0.05, 0.75, Vector3(hx, 0.64, m.y + 1.0), Bau.metall("c9ced6", 0.2, 0.9), 8)
		_zyl(0.26, 0.1, Vector3(hx, 1.05, m.y + 1.0), Bau.matt("a01428", 0.8), 16)
	_licht(Vector3(m.x, 3.2, m.y + 0.6), "bfe9ff", 1.2, 6.0)
	_schrift("BAR", Vector3(m.x, 3.9, -HALB + WAND + 0.1), 0.0, 96, 0.008, Color(0.55, 0.9, 1.0))
	_fest(m.x - 2.6, -HALB, m.x + 2.6, m.y + 1.3)

# Aufzug an der Innenwand neben dem Eingang (−X): fährt in die Arcade-Halle (1. Stock) und ins Penthouse (oben)
func _aufzug() -> void:
	var x := -HALB + WAND + 0.03
	var z := -6.0
	var stahl := Bau.metall("c9ced4", 0.25, 0.85)
	var gold := Bau.metall("d9a441", 0.25, 0.9)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.06, 2.7, 0.95), Vector3(x, 1.62, z + s * 0.49), stahl)
		_box(Vector3(0.1, 2.9, 0.12), Vector3(x, 1.72, z + s * 1.02), gold)
	_box(Vector3(0.1, 0.12, 2.16), Vector3(x, 3.1, z), gold)
	_box(Vector3(0.05, 0.1, 0.06), Vector3(x + 0.03, 1.6, z + 1.35), _leuchte("ffcf6a", 2.5))
	_schrift("ARCADE  ·  PENTHOUSE", Vector3(x + 0.04, 3.55, z), PI * 0.5, 60, 0.006, Color(1.0, 0.82, 0.3))
	aufzug_pos = mitte + Vector2(x + 2.0, z)
