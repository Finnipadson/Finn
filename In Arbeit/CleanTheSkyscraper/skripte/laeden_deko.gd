class_name LadenDeko
# Verschönerung der vier Läden (Wunsch des Users: „sehen lieblos aus“): Markisen, Aufsteller, Fußmatten und Strahler
# außen, Bodenmuster, Pflanzen und Leute innen, dazu je Laden eigene Details:
#   Möbelhaus: Empfang, Wegweiser-Pfeile, Einkaufswagen · Werkstatt: Rolltor, Werkbank mit Schweißfunken, Lackierkabine
#   Souvenirshop: Regale voller Kleinkram, Modell-Stadt, Lichterketten, Kühlschrank · Gold: Spiegelwand, roter Teppich
#   mit Samtkordeln, großer Kronleuchter, Lichtkegel, Glitzer, Wachmann.
# Alles in Laden-Koordinaten (Tür bei −x), Kollision über l._fest().

const AUFSTELLER := {"moebel": "NEU: Whirlpool-Wanne!", "werkstatt": "Heute: Lavendel-\nBlumenkasten", "souvenir": "Andenken für jeden\nMeilenstein", "gold": "Nur echt\nmit Glanz"}

static func schmuecken(l: Laeden) -> void:
	for id in l.laeden:
		_aussen(l, id)
	_moebelhaus(l)
	_werkstatt(l)
	_souvenir(l)
	_gold(l)

# ---------------------------------------------------------------- Bausteine
static func _tuer_h(id: String) -> float:
	return minf(3.4, float(Laeden.DATEN[id].hoch) - 1.0)

# Kenney-Figur (schaut in Richtung blick), fest
static func _person(l: Laeden, id: String, modell: String, p: Vector2, blick: Vector2, dunkel := false) -> void:
	var f := RaumBau.modell(l._innen(id), modell, Vector3(p.x, 0.07, p.y), Haendler.MINI, atan2(blick.x, blick.y))
	if dunkel:
		Moebel._toenen(f, Color("1b1e2a"))
	l._fest(id, p.x - 0.3, p.y - 0.3, p.x + 0.3, p.y + 0.3)

# Kenney-Modell mittig aufstellen, Kollision aus seiner Größe
static func _modell(l: Laeden, id: String, name: String, p: Vector2, s: float, dreh := 0.0, y := 0.07) -> Node3D:
	var m := RaumBau.mittig(l._innen(id), name, Vector3(p.x, y, p.y), s, dreh)
	var b := RaumBau.aabb(m)
	if b.size.y > 0.15 and y < 0.1:
		l._fest(id, b.position.x + 0.05, b.position.z + 0.05, b.end.x - 0.05, b.end.z - 0.05)
	return m

static func _pflanze(l: Laeden, id: String, p: Vector2, gross := 1.6) -> void:
	_modell(l, id, "moebel/pottedPlant", p, Moebel.MASS * gross)

static func _funke(l: Laeden, n: Node3D, p: Vector3, farbe: String, tempo := 2.5) -> void:
	var fm := RaumBau.leuchte(farbe, 0.0)
	l._funkeln.append([fm, tempo + randf() * 2.0, randf() * TAU])
	var f := RaumBau.box(n, Vector3(0.015, 0.07, 0.015), p, fm)
	f.rotation = Vector3(PI / 4.0, randf() * PI, 0)

static func _mat_transparent(farbe: String, a: float, leuchten := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(Color(farbe), a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shadow_to_opacity = false
	if leuchten:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

# ---------------------------------------------------------------- Bodenmuster (256 px = 4 m, siehe RaumBau.flaeche uv 0,25)
static func boden(id: String) -> ImageTexture:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rausch := FastNoiseLite.new()
	rausch.seed = 5
	rausch.frequency = 0.03
	var fein := FastNoiseLite.new()
	fein.seed = 9
	fein.frequency = 0.18
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var flecken := []
	for k in 5:
		flecken.append([Vector2(rng.randf() * n, rng.randf() * n), 6.0 + rng.randf() * 14.0])
	for y in n:
		for x in n:
			var c := Color.WHITE
			match id:
				"moebel":   # helle Steinfliesen 1 × 1 m mit Fugen
					var zelle := Vector2i(x / 64, y / 64)
					var v := 0.03 * sin(zelle.x * 12.9 + zelle.y * 78.2)
					c = Color("e6e0d6").lightened(v)
					if x % 64 < 2 or y % 64 < 2:
						c = Color("c9c1b4")
				"werkstatt":   # Beton mit Ölflecken
					var r := rausch.get_noise_2d(x, y) * 0.06 + fein.get_noise_2d(x, y) * 0.03
					c = Color("8d939b").lightened(r)
					for f in flecken:
						var d := Vector2(x, y).distance_to(f[0]) / float(f[1])
						if d < 1.0:
							c = c.lerp(Color("3a3d42"), (1.0 - d) * 0.6)
					if x % 128 < 1 or y % 128 < 1:
						c = c.darkened(0.25)
				"souvenir":   # warme Holzdielen (0,25 m breit, versetzte Stöße)
					var diele := y / 16
					var versatz := (diele * 97) % 256
					var stoss := (x + versatz) % 160
					var holz := fein.get_noise_2d(x * 0.15, y * 2.0) * 0.08 + 0.04 * sin(diele * 7.3)
					c = Color("b98b5e").lightened(holz)
					if y % 16 < 1 or stoss < 1:
						c = Color("7a5536")
				"gold":   # schwarzer Marmor mit hellen Adern, 2-m-Platten mit Goldfugen
					var ader := absf(sin((x + rausch.get_noise_2d(x, y) * 160.0) * 0.045 + y * 0.02))
					c = Color("15161c").lerp(Color("5a5c66"), pow(1.0 - ader, 18.0) * 0.8)
					if x % 128 < 2 or y % 128 < 2:
						c = Color("c99a3a")
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- Außen (alle Läden)
static func _aussen(l: Laeden, id: String) -> void:
	var d: Dictionary = Laeden.DATEN[id]
	var haus: Node3D = l.laeden[id].knoten
	var h: float = d.halb
	var tuer: float = d.tuer
	var th := _tuer_h(id)
	var gold := id == "gold"
	var farbe: Color = Color("1b1e2a") if gold else Color(d.farbe)
	var hell: Color = Color("2b2d33") if gold else Color("f6f2ea")
	# Markisen über den Schaufenstern: vorne links und rechts vom Vordach, dazu an beiden Seiten
	var von := tuer * 0.5 + 1.7
	for s in [-1.0, 1.0]:
		var lang := h - 0.3 - von
		_markise(haus, Vector3(-h, th, s * (von + lang * 0.5)), 0.0, lang, farbe, hell)
		var seite_oben := minf(th, float(d.hoch) - 1.2)
		_markise(haus, Vector3(0, seite_oben, s * h), s * PI * 0.5, h * 2.0 - 2.0, farbe, hell)
	# Aufsteller vor der Tür (Tafel, zwei Seiten beschriftet)
	var ap := Vector2(-h - 3.0, -(tuer * 0.5 + 1.0))
	var tafel := Bau.matt("23262c", 0.7)
	for s2 in [-1.0, 1.0]:
		var brett := RaumBau.box(haus, Vector3(0.04, 1.0, 0.62), Vector3(ap.x + s2 * 0.17, 0.5, ap.y), tafel)
		brett.rotation.z = s2 * 0.32
		RaumBau.schrift(haus, AUFSTELLER[id], Vector3(ap.x + s2 * 0.23, 0.6, ap.y), PI * 0.5 * s2, 34, 0.0042, Color("fff6e0"), false)
	RaumBau.box(haus, Vector3(0.5, 0.06, 0.66), Vector3(ap.x, 0.98, ap.y), Bau.matt(d.farbe if not gold else "c99a3a", 0.5))
	l._fest(id, ap.x - 0.45, ap.y - 0.4, ap.x + 0.45, ap.y + 0.4)
	# Fußmatte vor der Tür
	RaumBau.box(haus, Vector3(1.0, 0.02, tuer * 0.8), Vector3(-h - 0.7, 0.03, 0), Bau.matt(Color(d.farbe).darkened(0.55).to_html(false) if not gold else "6a1030", 1.0))
	# Strahler, die das Schild anleuchten
	var band_y := th + (float(d.hoch) - th) * 0.55 + 0.2
	for s3 in [-1.0, 0.0, 1.0]:
		var z3: float = s3 * minf(h - 2.0, 2.2 + str(d.schild).length() * 0.95) * 0.33
		RaumBau.box(haus, Vector3(0.6, 0.04, 0.04), Vector3(-h - 0.4, band_y + 0.9, z3), Bau.metall("2b2d33", 0.4, 0.6))
		var kopf := RaumBau.zyl(haus, 0.07, 0.16, Vector3(-h - 0.7, band_y + 0.86, z3), Bau.metall("2b2d33", 0.4, 0.6), 10, 0.09)
		kopf.rotation.z = 0.6
		var lichtkegel := RaumBau.zyl(haus, 0.07, 0.9, Vector3(-h - 0.48, band_y + 0.45, z3), _mat_transparent("fff2c8", 0.07, true), 12, 0.4)
		lichtkegel.rotation.z = 0.45

# Gestreifte Markise (schräg nach außen/unten). p = Mitte an der Außenwand (y = Oberkante), dreh: 0 = Wand vorne (−x),
# +PI/2 = Seite +z, −PI/2 = Seite −z. lang = Länge entlang der Wand.
static func _markise(haus: Node3D, p: Vector3, dreh: float, lang: float, farbe: Color, hell: Color) -> void:
	var w := Node3D.new()
	w.position = p
	w.rotation.y = dreh
	haus.add_child(w)
	var streifen := maxi(1, int(lang / 0.5))
	var breite := lang / streifen
	var neigung := atan2(0.45, 1.3)
	var m1 := Bau.matt(farbe.to_html(false), 0.85)
	var m2 := Bau.matt(hell.to_html(false), 0.85)
	for k in streifen:
		var z := -lang * 0.5 + (k + 0.5) * breite
		var m := m1 if k % 2 == 0 else m2
		var b := RaumBau.box(w, Vector3(1.38, 0.03, breite), Vector3(-0.65, 0.03, z), m)
		b.rotation.z = neigung
		RaumBau.box(w, Vector3(0.03, 0.26, breite), Vector3(-1.31, -0.32, z), m)   # Volant vorne
	for z2 in [-lang * 0.5, lang * 0.5]:
		var arm := RaumBau.box(w, Vector3(1.4, 0.04, 0.04), Vector3(-0.65, -0.02, z2), Bau.metall("2b2d33", 0.4, 0.6))
		arm.rotation.z = neigung

# ---------------------------------------------------------------- Möbelhaus
static func _moebelhaus(l: Laeden) -> void:
	var id := "moebel"
	var n := l._innen(id)
	var iw: float = Laeden.DATEN[id].halb - Laeden.WAND
	# Empfang mit Mitarbeiterin + Logo-Wand
	l._theke(id, Vector2(-14.6, -8.2), 3.4, Bau.matt("f7f4ee", 0.5), Bau.metall("ffb03a", 0.3, 0.6))
	l._figur(id, "character-female-c", Vector2(-13.5, -8.2))
	RaumBau.box(n, Vector3(0.1, 1.2, 3.6), Vector3(-12.75, 2.2, -8.2), Bau.matt("ffb03a", 0.5))
	var logo := RaumBau.schrift(n, "EMPFANG", Vector3(-12.85, 2.2, -8.2), -PI / 2.0, 70, 0.006, Color("ffffff"))
	logo.modulate = Color(1.4, 1.4, 1.4)
	# Wegweiser-Pfeile auf dem Gang (zeigen nach hinten)
	var orange := Bau.matt("ffb03a", 0.6)
	for x in [-11.0, -5.0, 1.0, 7.0, 13.0]:
		for s in [-1.0, 1.0]:
			var b := RaumBau.box(n, Vector3(0.75, 0.012, 0.16), Vector3(x - 0.2, 0.075, s * 0.26), orange)
			b.rotation.y = s * PI / 4.0
	# Einkaufswagen im Foyer
	for k in 3:
		_wagen(n, Vector3(-16.8 + k * 0.35, 0.07, 12.5))
	l._fest(id, -17.4, 11.9, -15.5, 13.1)
	# Pflanzen in den Ecken des Foyers
	for s2 in [-1.0, 1.0]:
		_pflanze(l, id, Vector2(-16.9, s2 * 16.9))
	_pflanze(l, id, Vector2(-16.9, -4.0), 1.3)
	# Kundschaft auf dem Gang (schaut in die Räume) + Mitarbeiter
	_person(l, id, "leute/character-female-a", Vector2(-7.4, 1.9), Vector2(0, 1))
	_person(l, id, "leute/character-male-e", Vector2(2.6, -1.9), Vector2(0, -1))
	_person(l, id, "leute/character-male-b", Vector2(11.6, 2.0), Vector2(0.3, 1))
	_person(l, id, "leute/character-female-c", Vector2(12.4, 2.1), Vector2(-0.3, 1))
	_person(l, id, "laden/character-employee", Vector2(6.0, -1.6), Vector2(1, 0))

# Einkaufswagen aus Code (Drahtkorb, Griff, Räder)
static func _wagen(n: Node3D, p: Vector3) -> void:
	var w := Node3D.new()
	w.position = p
	w.rotation.y = PI / 2.0
	n.add_child(w)
	var draht := Bau.metall("c9ced4", 0.3, 0.9)
	var rot := Bau.matt("e2483e", 0.5)
	RaumBau.box(w, Vector3(0.55, 0.02, 0.85), Vector3(0, 0.5, 0), draht)
	for s in [-1.0, 1.0]:
		RaumBau.box(w, Vector3(0.02, 0.45, 0.85), Vector3(s * 0.27, 0.72, 0), draht)
		RaumBau.box(w, Vector3(0.55, 0.45, 0.02), Vector3(0, 0.72, s * 0.42), draht)
		for z in [-0.35, 0.35]:
			var rad := RaumBau.zyl(w, 0.05, 0.03, Vector3(s * 0.22, 0.05, z), Bau.matt("2b2d33", 0.6), 10)
			rad.rotation.z = PI / 2.0
			RaumBau.box(w, Vector3(0.02, 0.45, 0.02), Vector3(s * 0.22, 0.28, z), draht)
	RaumBau.box(w, Vector3(0.6, 0.05, 0.05), Vector3(0, 1.0, 0.52), rot)

# ---------------------------------------------------------------- Gondel-Werkstatt
static func _werkstatt(l: Laeden) -> void:
	var id := "werkstatt"
	var n := l._innen(id)
	var d: Dictionary = Laeden.DATEN[id]
	var h: float = d.halb
	var iw := h - Laeden.WAND
	var tuer: float = d.tuer
	var th := _tuer_h(id)
	var stahl := Bau.metall("6b7078", 0.4, 0.6)
	# Rolltor: Wickelrolle über der Öffnung, Führungsschienen, unterste Lamellen schauen heraus
	var haus: Node3D = l.laeden[id].knoten
	var rolle := RaumBau.zyl(haus, 0.32, tuer + 0.4, Vector3(-h + 0.75, th + 0.4, 0), Bau.matt("9aa3ad", 0.5), 20)
	rolle.rotation.x = PI / 2.0
	for k in 3:
		RaumBau.box(haus, Vector3(0.05, 0.12, tuer), Vector3(-h + 0.5, th - 0.07 - k * 0.13, 0), Bau.metall("b8bec6" if k % 2 == 0 else "9aa3ad", 0.4, 0.5))
	for s in [-1.0, 1.0]:
		RaumBau.box(haus, Vector3(0.14, th + 0.4, 0.12), Vector3(-h + 0.5, (th + 0.4) * 0.5, s * (tuer * 0.5 + 0.06)), stahl)
	# Werkbank mit Schraubstock, Werkzeug und Schweißer (Funken)
	var bank := Vector2(-9.5, -iw + 0.5)
	RaumBau.box(n, Vector3(3.0, 0.85, 0.8), Vector3(bank.x, 0.5, bank.y), Bau.matt("6b7078", 0.6))
	RaumBau.box(n, Vector3(3.1, 0.07, 0.9), Vector3(bank.x, 0.96, bank.y), Bau.matt("8a5a3b", 0.7))
	RaumBau.box(n, Vector3(0.18, 0.16, 0.22), Vector3(bank.x - 1.1, 1.08, bank.y), Bau.matt("3a86d4", 0.5))
	RaumBau.box(n, Vector3(0.5, 0.25, 0.3), Vector3(bank.x + 1.0, 1.12, bank.y - 0.1), Bau.matt("e2483e", 0.4))
	for k in 4:
		var wz := RaumBau.zyl(n, 0.015, 0.3, Vector3(bank.x - 0.5 + k * 0.18, 1.01, bank.y + 0.2), Bau.matt(["ffc531", "e2483e", "2b2d33", "3a86d4"][k], 0.5), 6)
		wz.rotation.z = PI / 2.0
	RaumBau.box(n, Vector3(3.0, 1.2, 0.04), Vector3(bank.x, 1.9, -iw + 0.04), Bau.matt("c9a46a", 0.8))   # Lochwand
	for k in 6:
		RaumBau.box(n, Vector3(0.04, 0.3, 0.06), Vector3(bank.x - 1.2 + k * 0.48, 1.9, -iw + 0.1), Bau.matt(["2b2d33", "e2483e", "ffc531"][k % 3], 0.5))
	l._fest(id, bank.x - 1.55, -iw, bank.x + 1.55, bank.y + 0.45)
	var schweisser := Vector2(bank.x + 0.2, bank.y + 1.0)
	_person(l, id, "leute/character-male-e", schweisser, Vector2(0, -1))
	var funkenpunkt := Vector3(bank.x + 0.1, 1.1, bank.y + 0.15)
	for k in 12:
		_funke(l, n, funkenpunkt + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.3), randf_range(-0.1, 0.25)), "ffb050", 6.0)
	RaumBau.licht(n, funkenpunkt + Vector3(0, 0.3, 0.3), "ffb878", 0.6, 3.0)
	# Lackierkabine hinten rechts: Glaswände, Lichtdecke, eine zweite Gondel wird gerade pink lackiert
	var k0 := Vector2(4.0, 4.5)
	var k1 := Vector2(iw, iw)
	var glas := RaumBau.glas("e8f4ff", 0.14)
	var kh := 3.4
	RaumBau.box(n, Vector3(0.05, kh, k1.y - k0.y), Vector3(k0.x, kh * 0.5, (k0.y + k1.y) * 0.5), glas)
	RaumBau.box(n, Vector3(k1.x - k0.x, kh, 0.05), Vector3((k0.x + k1.x) * 0.5, kh * 0.5, k0.y), glas)
	for p in [Vector2(k0.x, k0.y), Vector2(k0.x, k1.y), Vector2(k1.x, k0.y), Vector2(k0.x, (k0.y + k1.y) * 0.5), Vector2((k0.x + k1.x) * 0.5, k0.y)]:
		RaumBau.box(n, Vector3(0.1, kh, 0.1), Vector3(p.x, kh * 0.5, p.y), stahl)
	RaumBau.box(n, Vector3(k1.x - k0.x, 0.12, k1.y - k0.y), Vector3((k0.x + k1.x) * 0.5, kh + 0.06, (k0.y + k1.y) * 0.5), Bau.matt("d9dde2", 0.6))
	for k in 3:
		RaumBau.box(n, Vector3(k1.x - k0.x - 0.6, 0.03, 0.4), Vector3((k0.x + k1.x) * 0.5, kh - 0.02, k0.y + 1.5 + k * 2.2), RaumBau.leuchte("f4f8ff", 2.2))
	var schild := RaumBau.schrift(n, "LACKIERKABINE", Vector3((k0.x + k1.x) * 0.5, kh - 0.4, k0.y - 0.04), PI, 60, 0.006, Color("35c8ff"))
	schild.modulate = Color(0.5, 1.6, 2.0)
	var g := Node3D.new()
	g.position = Vector3(8.0, 0.75, 8.6)
	n.add_child(g)
	GondelDeko.rumpf(g, Bau.matt("b8bec6", 0.6), stahl, false)
	for s2 in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(0.3, 0.7, 0.9), Vector3(8.0 + s2 * 1.4, 0.35, 8.6), Bau.matt("ffc531", 0.6))
	RaumBau.box(n, Vector3(1.6, 0.9, 0.02), Vector3(7.4, 1.25, 8.6 - 0.6), Bau.matt("ff4fb8", 0.35))   # frisch lackiert
	var maler := Vector2(7.3, 6.4)
	_person(l, id, "leute/character-worker", maler, Vector2(0, 1))
	var pistole := Spieler.werkzeug_modell(Wirtschaft.WERKZEUGE[4])
	pistole.position = Vector3(maler.x + 0.25, 1.2, maler.y + 0.45)
	pistole.rotation = Vector3(-PI / 2.0, 0, 0)
	n.add_child(pistole)
	var nebel := _mat_transparent("ff7ac8", 0.18)
	for k in 4:
		var kugel := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.25 + k * 0.08
		sm.height = sm.radius * 2.0
		kugel.mesh = sm
		kugel.material_override = nebel
		kugel.position = Vector3(maler.x + 0.25, 1.2 + k * 0.03, maler.y + 0.8 + k * 0.32)
		n.add_child(kugel)
	l._fest(id, k0.x - 0.1, k0.y - 0.1, k1.x, k1.y)
	# Kundin schaut sich die Vorführ-Gondel an, Pflanze in der Ecke
	_person(l, id, "leute/character-female-a", Vector2(-1.2, -3.4), Vector2(1, 0.6))
	_pflanze(l, id, Vector2(-iw + 0.6, iw - 0.6))

# ---------------------------------------------------------------- Souvenirshop
static func _souvenir(l: Laeden) -> void:
	var id := "souvenir"
	var n := l._innen(id)
	var d: Dictionary = Laeden.DATEN[id]
	var iw: float = d.halb - Laeden.WAND
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	# Zwei Regalinseln voller Kleinkram
	for s in [-1.0, 1.0]:
		var m := Vector2(-3.5, s * 3.0)
		RaumBau.box(n, Vector3(3.0, 0.5, 0.9), Vector3(m.x, 0.32, m.y), Bau.matt("f1eee8", 0.5))
		RaumBau.box(n, Vector3(3.0, 1.0, 0.08), Vector3(m.x, 1.05, m.y), Bau.matt("8a5a3b", 0.6))
		for b in 2:
			RaumBau.box(n, Vector3(3.0, 0.04, 0.9), Vector3(m.x, 0.6 + b * 0.62, m.y), Bau.matt("8a5a3b", 0.6))
		l._fest(id, m.x - 1.55, m.y - 0.5, m.x + 1.55, m.y + 0.5)
		for b in 2:
			var y := 0.62 + b * 0.62
			for k in 10:
				var x := m.x - 1.35 + k * 0.3
				for seite in [-1.0, 1.0]:
					var z: float = m.y + seite * 0.25
					_kleinkram(n, Vector3(x, y, z), rng)
	# Modell-Stadt unter Glas auf einem Tisch mit Teppich
	var st := Vector2(3.0, 0.0)
	RaumBau.box(n, Vector3(4.6, 0.012, 4.6), Vector3(st.x, 0.075, st.y), Bau.matt("8a1f2e", 0.95))
	RaumBau.box(n, Vector3(4.2, 0.014, 4.2), Vector3(st.x, 0.078, st.y), Bau.matt("b8323f", 0.95))
	RaumBau.box(n, Vector3(2.6, 0.85, 2.6), Vector3(st.x, 0.5, st.y), Bau.matt("6b4a32", 0.6))
	RaumBau.box(n, Vector3(2.5, 0.04, 2.5), Vector3(st.x, 0.94, st.y), Bau.matt("d9c49a", 0.9))
	RaumBau.box(n, Vector3(0.8, 0.01, 0.5), Vector3(st.x - 0.7, 0.965, st.y + 0.6), RaumBau.leuchte("4aa8ff", 0.4))   # See
	Andenken._mini_turm(n, 0.96, 1.25, Bau.metall("c9d6e2", 0.25, 0.8))
	for c in n.get_children().slice(-5):
		(c as Node3D).position += Vector3(st.x, 0, st.y)
	for k in 34:
		var a := rng.randf() * TAU
		var r := 0.35 + rng.randf() * 0.8
		var p := Vector3(st.x + cos(a) * r, 0.96, st.y + sin(a) * r)
		if Vector2(p.x - (st.x - 0.7), p.z - (st.y + 0.6)).length() < 0.45:
			continue
		var hh := 0.05 + rng.randf() * 0.22
		RaumBau.box(n, Vector3(0.09, hh, 0.09), p + Vector3(0, hh * 0.5, 0), Bau.matt(["8fb1c9", "e6dccb", "6d8aa3", "c9b79a"][k % 4], 0.5))
	for k in 10:
		var a2 := k * TAU / 10.0
		var pp := Vector3(st.x + cos(a2) * 1.05, 0.96, st.y + sin(a2) * 1.05)
		RaumBau.zyl(n, 0.006, 0.08, pp + Vector3(0, 0.04, 0), Bau.matt("8a5a2b", 0.8), 5)
		RaumBau.box(n, Vector3(0.07, 0.02, 0.07), pp + Vector3(0, 0.09, 0), Bau.matt("3f8a4a", 0.8))
	RaumBau.box(n, Vector3(2.5, 1.5, 2.5), Vector3(st.x, 1.71, st.y), RaumBau.glas("e8f4ff", 0.08))
	l._fest(id, st.x - 1.35, st.y - 1.35, st.x + 1.35, st.y + 1.35)
	var tafel := RaumBau.schrift(n, "Die Wüstennadel – Modell 1 : 400", Vector3(st.x - 1.33, 0.75, st.y), -PI / 2.0, 34, 0.0045, Color("fff6e0"), false)
	tafel.modulate = Color("fff6e0")
	# Lichterketten unter der Decke rundum
	var warm := [RaumBau.leuchte("ffd27a", 2.5), RaumBau.leuchte("ff9ad5", 2.0), RaumBau.leuchte("8fe0ff", 2.0)]
	var y0: float = float(d.hoch) - 0.25
	var ecken := [Vector2(-iw, -iw), Vector2(iw, -iw), Vector2(iw, iw), Vector2(-iw, iw)]
	var i := 0
	for e in 4:
		var a3: Vector2 = ecken[e] * 0.97
		var b3: Vector2 = ecken[(e + 1) % 4] * 0.97
		var schritte := int(a3.distance_to(b3) / 0.5)
		for k in schritte:
			var t := float(k) / schritte
			var q := a3.lerp(b3, t)
			var durchhang := absf(sin(t * PI * 6.0)) * 0.18
			RaumBau.box(n, Vector3.ONE * 0.06, Vector3(q.x, y0 - 0.18 + durchhang, q.y), warm[i % 3])
			i += 1
	# Getränke-Kühlschrank, Kleiderständer mit T-Shirts, Pflanzen, Touristen
	_modell(l, id, "laden/freezers-standing", Vector2(-6.8, iw - 0.6), Haendler.MINI, PI)
	_modell(l, id, "laden/clothing-rack", Vector2(6.0, 5.2), Haendler.MINI, PI / 2.0)
	for s3 in [-1.0, 1.0]:
		_pflanze(l, id, Vector2(iw - 0.6, s3 * (iw - 0.6)), 1.4)
	_person(l, id, "leute/character-male-b", Vector2(0.9, 1.9), Vector2(2.1, -1.9))
	_person(l, id, "leute/character-female-a", Vector2(-3.5, -4.3), Vector2(0, 1))

# Ein Stück Kleinkram fürs Regal: Tasse, T-Shirt-Stapel, Mini-Turm, Schneekugel oder Schlüsselanhänger
static func _kleinkram(n: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var farben := ["e2483e", "3a86d4", "ffc531", "3fc29a", "ff9ad5", "f4f4f4", "b36bff"]
	var c: String = farben[rng.randi() % farben.size()]
	match rng.randi() % 5:
		0:
			RaumBau.zyl(n, 0.045, 0.1, p + Vector3(0, 0.05, 0), Bau.matt(c, 0.3), 12)
			RaumBau.box(n, Vector3(0.02, 0.05, 0.015), p + Vector3(0.055, 0.05, 0), Bau.matt(c, 0.3))
		1:
			for k in 3:
				RaumBau.box(n, Vector3(0.24, 0.035, 0.2), p + Vector3(0, 0.02 + k * 0.037, 0), Bau.matt(farben[(rng.randi() + k) % farben.size()], 0.9))
		2:
			Andenken._mini_turm(n, p.y, 0.24, Bau.metall("c9d6e2", 0.25, 0.8))
			for c2 in n.get_children().slice(-5):
				(c2 as Node3D).position += Vector3(p.x, 0, p.z)
		3:
			RaumBau.zyl(n, 0.05, 0.03, p + Vector3(0, 0.015, 0), Bau.matt("6b3f22", 0.5), 12)
			var k2 := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.06
			sm.height = 0.12
			k2.mesh = sm
			k2.material_override = RaumBau.glas("d8eeff", 0.25)
			k2.position = p + Vector3(0, 0.09, 0)
			n.add_child(k2)
		_:
			RaumBau.box(n, Vector3(0.05, 0.07, 0.01), p + Vector3(0, 0.04, 0), Andenken.gold())

# ---------------------------------------------------------------- Goldschmuck
static func _gold(l: Laeden) -> void:
	var id := "gold"
	var n := l._innen(id)
	var d: Dictionary = Laeden.DATEN[id]
	var iw: float = d.halb - Laeden.WAND
	var hoch: float = d.hoch
	var gold := Andenken.gold()
	# Spiegelwand hinten mit Goldrahmen, Reflexions-Sonde (einmal gerechnet)
	var spiegel := StandardMaterial3D.new()
	spiegel.albedo_color = Color(0.9, 0.92, 0.95)
	spiegel.metallic = 1.0
	spiegel.roughness = 0.02
	RaumBau.box(n, Vector3(0.03, 3.1, 16.0), Vector3(iw - 0.05, 1.85, 0), spiegel)
	for s in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(0.06, 3.3, 0.12), Vector3(iw - 0.06, 1.85, s * 8.05), gold)
	for y in [0.27, 3.43]:
		RaumBau.box(n, Vector3(0.06, 0.12, 16.2), Vector3(iw - 0.06, y, 0), gold)
	var sonde := ReflectionProbe.new()
	sonde.size = Vector3(iw * 2.0, hoch, iw * 2.0)
	sonde.position = Vector3(0, hoch * 0.5, 0)
	sonde.update_mode = ReflectionProbe.UPDATE_ONCE
	sonde.interior = true
	sonde.box_projection = true
	n.add_child(sonde)
	# Roter Teppich von der Tür zur Mitte, Absperrpfosten mit Samtkordeln
	RaumBau.box(n, Vector3(12.0, 0.012, 1.9), Vector3(-iw + 6.0, 0.075, 0), Bau.matt("a01428", 0.95))
	for s2 in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(12.0, 0.014, 0.06), Vector3(-iw + 6.0, 0.078, s2 * 0.95), gold)
		var xs := [-8.0, -5.5, -3.0, -0.5]
		for k in xs.size():
			var px: float = xs[k]
			RaumBau.zyl(n, 0.15, 0.04, Vector3(px, 0.09, s2 * 1.35), gold, 16)
			RaumBau.zyl(n, 0.035, 0.95, Vector3(px, 0.55, s2 * 1.35), gold, 10)
			var kopf := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.06
			sm.height = 0.12
			kopf.mesh = sm
			kopf.material_override = gold
			kopf.position = Vector3(px, 1.05, s2 * 1.35)
			n.add_child(kopf)
			l._fest(id, px - 0.15, s2 * 1.35 - 0.15, px + 0.15, s2 * 1.35 + 0.15)
			if k < xs.size() - 1:
				var kordel := RaumBau.zyl(n, 0.025, 2.5, Vector3(px + 1.25, 0.92, s2 * 1.35), Bau.matt("7a1020", 0.7), 8)
				kordel.rotation.z = PI / 2.0
	# Großer Kronleuchter in der Mitte
	var kl := Vector3(0.5, hoch - 0.1, 0)
	RaumBau.zyl(n, 0.03, 0.5, kl - Vector3(0, 0.25, 0), gold, 8)
	var kristall := RaumBau.glas("ffffff", 0.45)
	var kerze := RaumBau.leuchte("ffe2a0", 3.5)
	for stufe in 3:
		var y := kl.y - 0.6 - stufe * 0.35
		var r := 1.3 - stufe * 0.38
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.04
		tm.outer_radius = r
		ring.mesh = tm
		ring.material_override = gold
		ring.position = Vector3(kl.x, y, kl.z)
		n.add_child(ring)
		var anzahl := 16 - stufe * 4
		for k in anzahl:
			var a := k * TAU / anzahl
			var p := Vector3(kl.x + sin(a) * r, y, kl.z + cos(a) * r)
			RaumBau.box(n, Vector3(0.035, 0.22, 0.035), p - Vector3(0, 0.16, 0), kristall)
			RaumBau.box(n, Vector3(0.03, 0.06, 0.03), p + Vector3(0, 0.05, 0), kerze)
			if k % 3 == 0:
				_funke(l, n, p - Vector3(0, 0.3, 0), "ffffff", 2.0)
	for k in 6:
		var a := k * TAU / 6.0
		var arm := RaumBau.zyl(n, 0.015, 1.3, Vector3(kl.x + sin(a) * 0.65, kl.y - 0.6, kl.z + cos(a) * 0.65), gold, 6)
		arm.rotation = Vector3(cos(a) * PI / 2.0, 0, -sin(a) * PI / 2.0)
	RaumBau.licht(n, Vector3(kl.x, kl.y - 1.4, kl.z), "ffe2a8", 1.6, 9.0)
	# Strahler mit sichtbarem Lichtkegel und Glitzer über jedem Gold-Stück
	var kegel := _mat_transparent("fff0c8", 0.05, true)
	for i in 6:
		var gp: Vector2 = l._gold_platz(i)[0]
		RaumBau.zyl(n, 0.12, 0.2, Vector3(gp.x, hoch - 0.1, gp.y), Bau.matt("0d0e12", 0.3), 12)
		RaumBau.zyl(n, 0.1, hoch - 0.4, Vector3(gp.x, (hoch - 0.2) * 0.5 + 0.1, gp.y), kegel, 20, 1.0)
		for k in 6:
			_funke(l, n, Vector3(gp.x + randf_range(-0.7, 0.7), 0.6 + randf() * 1.4, gp.y + randf_range(-0.7, 0.7)), "fff6d0", 2.0)
	# Wachmann an der Tür, ein Kunde, Pflanzen
	_person(l, id, "leute/character-male-b", Vector2(-8.8, -2.3), Vector2(1, 0), true)
	_person(l, id, "leute/character-male-e", Vector2(4.6, 5.4), Vector2(-0.8, 1))
	for s3 in [-1.0, 1.0]:
		_pflanze(l, id, Vector2(-iw + 0.6, s3 * (iw - 0.6)), 1.4)
