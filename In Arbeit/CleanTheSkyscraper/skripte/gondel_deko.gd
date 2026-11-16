class_name GondelDeko
# Gondel-Werkstatt (nur Optik): Rumpf der Gondel (gemeinsam für die Spieler-Gondel, die Vorführ-Gondel in der Werkstatt
# und das Souvenir), Lackierungs-Muster über der Grundfarbe und Zubehör (Aufkleber, Blumenkästen, Sonnenschirm).
# Gondel-Maße (lokal): Boden 3,8 × 1,15 m auf y = 0, Seitenwände bei x = ±1,88, Geländer vorne z = −0,55 (Wand), hinten z = +0,55.

const GOLD := "e8b53a"
static var _kleber := {}       # Aufkleber-ID -> ImageTexture (einmal gezeichnet)

# Kasten der Gondel aus Code (Boden, Geländer, Seitenwände, Pfosten); seile = 600-m-Seile nach oben
static func rumpf(g: Node3D, lack: Material, grau: Material, seile := true) -> void:
	RaumBau.box(g, Vector3(3.8, 0.12, 1.15), Vector3(0, -0.06, 0), lack)          # Boden
	RaumBau.box(g, Vector3(3.8, 0.06, 0.06), Vector3(0, 1.05, -0.55), lack)       # Geländer vorne (zur Wand)
	RaumBau.box(g, Vector3(3.8, 0.06, 0.06), Vector3(0, 1.05, 0.55), lack)        # Geländer hinten
	RaumBau.box(g, Vector3(3.8, 0.04, 0.04), Vector3(0, 0.55, 0.55), lack)
	for x in [-1.88, 1.88]:
		RaumBau.box(g, Vector3(0.06, 1.05, 1.15), Vector3(x, 0.52, 0), lack)      # Seitenwände
		if seile:
			var seil := Bau.zylinder(0.025, 0.025, 600.0, grau, 6)
			seil.position = Vector3(x * 0.92, 300.0, 0.0)
			g.add_child(seil)
		RaumBau.box(g, Vector3(0.12, 0.25, 0.12), Vector3(x * 0.92, 1.25, 0.0), grau)
	for x in [-1.2, -0.4, 0.4, 1.2]:
		RaumBau.box(g, Vector3(0.05, 1.05, 0.05), Vector3(x, 0.52, 0.55), lack)

# ---------------------------------------------------------------- Lackierung
# Muster über der Grundfarbe ins Material schreiben (triplanar, damit es auf allen Kästen gleich groß ist)
static func lack(m: StandardMaterial3D, grund_hex: String, lack_id: String) -> void:
	var grund := Color(grund_hex)
	var gold := grund_hex == GOLD
	m.albedo_color = grund
	m.albedo_texture = null
	m.metallic = 0.8 if gold else 0.0
	m.roughness = 0.3 if gold else 0.5
	m.uv1_triplanar = false
	m.uv1_scale = Vector3.ONE
	match lack_id:
		"lack_streifen", "lack_punkte", "lack_karo", "lack_tarn", "lack_karbon":
			m.albedo_color = Color.WHITE
			m.albedo_texture = _muster(lack_id, grund)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * ({"lack_streifen": 1.0, "lack_punkte": 2.5, "lack_karo": 2.5, "lack_tarn": 0.8, "lack_karbon": 8.0}[lack_id])
			if lack_id == "lack_karbon":
				m.roughness = 0.25
				m.metallic = 0.3
		"lack_chrom":
			m.metallic = 1.0
			m.roughness = 0.08
			m.albedo_color = grund.lerp(Color.WHITE, 0.35)

static func _muster(id: String, grund: Color) -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var weiss := Color(0.96, 0.96, 0.96)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var flecken := []
	for k in 9:
		flecken.append([Vector2(rng.randf() * n, rng.randf() * n), 6.0 + rng.randf() * 9.0, k % 3])
	for y in n:
		for x in n:
			var c := grund
			match id:
				"lack_streifen":   # zwei waagerechte Streifen (triplanar: läuft um die Gondel)
					if (y >= 26 and y < 31) or (y >= 35 and y < 40):
						c = weiss
				"lack_punkte":
					var d := Vector2(x % 32, y % 32).distance_to(Vector2(16, 16))
					if d < 7.0:
						c = weiss
				"lack_karo":
					c = Color(0.08, 0.08, 0.1) if ((x / 16) + (y / 16)) % 2 == 0 else weiss
				"lack_tarn":
					var sand := [Color("d8c08a"), Color("a9875a"), Color("6f5a3e")]
					c = Color("c9a46a")
					for f in flecken:
						for dx in [-n, 0, n]:
							for dy in [-n, 0, n]:
								if Vector2(x + dx, y + dy).distance_to(f[0]) < f[1]:
									c = sand[f[2]]
					c = c.lerp(grund, 0.2)
				"lack_karbon":   # Geflecht aus hellen und dunklen Bändern
					var feld := ((x / 8) + (y / 8)) % 2 == 0
					var t := float(x % 8 if feld else y % 8) / 8.0
					c = Color(0.1, 0.1, 0.12).lerp(Color(0.26, 0.27, 0.3), 0.5 + 0.5 * sin(t * PI)).lerp(grund, 0.12)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- Zubehör
# Baut Aufkleber, Blumenkästen und Schirm neu in den Knoten deko (alte Kinder werden entfernt)
static func zubehoer(deko: Node3D, aufkleber: String, blumen: String, schirm: String) -> void:
	for c in deko.get_children():
		deko.remove_child(c)
		c.queue_free()
	if aufkleber != "kleber_keine" and aufkleber != "":
		_aufkleber(deko, aufkleber)
	if blumen != "blumen_keine" and blumen != "":
		_blumen(deko, blumen)
	if schirm != "schirm_keiner" and schirm != "":
		_schirm(deko, schirm)

static func _aufkleber(deko: Node3D, id: String) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = kleber_bild(id)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 0.4
	var logo := id == "kleber_logo"
	var g := Vector2(0.9, 0.45) if logo else Vector2(0.42, 0.42)
	# je Seitenwand innen und außen
	for x in [-1.88, 1.88]:
		for aussen in [false, true]:
			var normal := signf(x) * (1.0 if aussen else -1.0)
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = g
			q.mesh = qm
			q.material_override = m
			q.position = Vector3(x + normal * 0.034, 0.55, 0.0)
			q.rotation.y = PI / 2.0 if normal > 0.0 else -PI / 2.0
			deko.add_child(q)

# Bild eines Aufklebers (128 × 128 bzw. 256 × 128 fürs Logo), mit weißem Rand wie ein echter Sticker
static func kleber_bild(id: String) -> ImageTexture:
	if _kleber.has(id):
		return _kleber[id]
	var logo := id == "kleber_logo"
	var bw := 256 if logo else 128
	var bh := 128
	var img := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var farbe := Color(Wirtschaft.KOSMETIK.filter(func(k): return k.id == id)[0].farbe) if id != "" else Color.WHITE
	for y in bh:
		for x in bw:
			var p := Vector2((x + 0.5) / bh * 2.0 - float(bw) / bh, (y + 0.5) / bh * 2.0 - 1.0)   # -1..1 (Logo breiter)
			var d := _form(id, p)
			if d < -0.07:
				img.set_pixel(x, y, _innen(id, p, farbe))
			elif d < 0.0:
				img.set_pixel(x, y, Color(1, 1, 1))   # weißer Rand
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_kleber[id] = t
	return t

# Abstand zu einem Vieleck (negativ = innen)
static func _poly_abstand(p: Vector2, poly: PackedVector2Array) -> float:
	var d := 9.0
	for i in poly.size():
		d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])))
	return -d if Geometry2D.is_point_in_polygon(p, poly) else d

# Abstand zur Form (negativ = innen)
static func _form(id: String, p: Vector2) -> float:
	match id:
		"kleber_herz":
			var kreise := minf(p.distance_to(Vector2(-0.36, -0.22)) - 0.42, p.distance_to(Vector2(0.36, -0.22)) - 0.42)
			return minf(kreise, _poly_abstand(p, PackedVector2Array([Vector2(-0.74, -0.08), Vector2(0.74, -0.08), Vector2(0, 0.88)])))
		"kleber_stern":
			var stern := PackedVector2Array()
			for k in 10:
				var a := -PI * 0.5 + k * PI / 5.0
				stern.append(Vector2(cos(a), sin(a)) * (0.95 if k % 2 == 0 else 0.42) + Vector2(0, 0.05))
			return _poly_abstand(p, stern)
		"kleber_blitz":
			return _poly_abstand(p, PackedVector2Array([Vector2(0.15, -0.95), Vector2(-0.55, 0.1), Vector2(-0.05, 0.1), Vector2(-0.25, 0.95), Vector2(0.55, -0.15), Vector2(0.05, -0.15), Vector2(0.35, -0.95)])) - 0.05
		"kleber_palme":
			var stamm := absf(p.x - 0.15 * (p.y + 1.0) * 0.3) - 0.08
			stamm = maxf(stamm, maxf(p.y - 0.95, -p.y - 0.1))
			var krone := 9.0
			for k in 5:
				var a := -PI * 0.5 + (k - 2) * 0.55
				var dir := Vector2(cos(a), sin(a))
				var c := Vector2(0.05, -0.15) + dir * 0.42
				krone = minf(krone, (p - c).length() - 0.27)
			return minf(stamm, krone)
		"kleber_logo":
			var q := Vector2(absf(p.x) - 1.05, absf(p.y) - 0.75)
			return minf(maxf(q.x, q.y), 0.0) + Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() - 0.2
		_:   # Smiley: Kreis
			return p.length() - 0.92

static func _innen(id: String, p: Vector2, farbe: Color) -> Color:
	match id:
		"kleber_smiley":
			var auge := minf(Vector2(absf(p.x) - 0.3, p.y + 0.25).length(), 9.0)
			if auge < 0.12:
				return Color("2b2d33")
			var mund := absf(Vector2(p.x, p.y + 0.05).length() - 0.5)
			if mund < 0.07 and p.y > 0.15:
				return Color("2b2d33")
		"kleber_palme":
			if p.y > 0.0 and absf(p.x - 0.15 * (p.y + 1.0) * 0.3) < 0.1:
				return Color("8a5a2b")
		"kleber_logo":
			# Mini-Turm links, Streifen rechts als „Schriftzug“
			if Geometry2D.is_point_in_polygon(p, PackedVector2Array([Vector2(-0.95, 0.62), Vector2(-0.55, 0.62), Vector2(-0.75, -0.72)])):
				return Color("e6eef5")
			if p.x > -0.4 and p.x < 1.05 and (absf(p.y + 0.22) < 0.1 or absf(p.y - 0.18) < 0.06):
				return Color(1, 1, 1)
	return farbe

static func _blumen(deko: Node3D, id: String) -> void:
	var kasten := Bau.matt("6b4a32" if id != "blumen_palme" else "e8e2d4", 0.8)
	var erde := Bau.matt("3b2a1e", 1.0)
	var bluten := {"blumen_rot": ["flower_redA"], "blumen_lila": ["flower_purpleA"], "blumen_bunt": ["flower_redA", "flower_yellowA", "flower_purpleA"], "blumen_gruen": ["plant_bush"]}
	for s in [-1.0, 1.0]:
		var mitte := Vector3(s * 0.95, 0.98, 0.72)
		if id == "blumen_palme":
			# Kübel in den hinteren Ecken auf dem Boden, darin eine kleine Palme
			var kp := Vector3(s * 1.6, 0.0, 0.32)
			RaumBau.zyl(deko, 0.17, 0.32, kp + Vector3(0, 0.16, 0), kasten, 16, 0.13)
			RaumBau.zyl(deko, 0.15, 0.02, kp + Vector3(0, 0.31, 0), erde, 16)
			var palme := RaumBau.modell(deko, "natur/palm-detailed-straight", kp + Vector3(0, 0.3, 0), 0.32, s)
			_palmen_farbe(palme)
			continue
		RaumBau.box(deko, Vector3(0.95, 0.2, 0.22), mitte, kasten)
		RaumBau.box(deko, Vector3(0.9, 0.02, 0.18), mitte + Vector3(0, 0.1, 0), erde)
		for haken in [-0.35, 0.35]:
			RaumBau.box(deko, Vector3(0.04, 0.16, 0.2), mitte + Vector3(haken, 0.1, -0.1), Bau.metall("6b7078", 0.4, 0.6))
		var liste: Array = bluten.get(id, ["flower_redA"])
		for k in 5:
			var name: String = liste[k % liste.size()]
			var b := RaumBau.modell(deko, "natur/" + name, mitte + Vector3(-0.36 + k * 0.18, 0.1, (k % 2) * 0.05 - 0.025), 1.0, k * 1.3)
			b.scale = Vector3.ONE * (0.34 if name != "plant_bush" else 0.26) / maxf(RaumBau.aabb(b).size.y, 0.01)   # auf feste Höhe bringen
			if name == "plant_bush":
				RaumBau.faerben(b, Bau.matt("3f6a2e", 0.85))

static func _palmen_farbe(n: Node3D) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://shader/palme.gdshader")
	m.set_shader_parameter("farben", load("res://modelle/natur/Textures/colormap.png"))
	m.set_shader_parameter("wind", 0.2)
	RaumBau.faerben(n, m)

static func _schirm(deko: Node3D, id: String) -> void:
	# Schirm an der rechten Seitenwand festgeklemmt, Dach (Ø 2 m) über der rechten Hälfte der Gondel
	var p := Vector3(1.78, 0.0, 0.42)
	var stahl := Bau.metall("c9ced4", 0.3, 0.8)
	RaumBau.box(deko, Vector3(0.08, 0.12, 0.08), p + Vector3(0, 0.95, 0), stahl)
	RaumBau.zyl(deko, 0.022, 2.45, p + Vector3(0, 1.22, 0), stahl, 8)
	var farben: Array = {"schirm_streifen": [Color("e2483e"), Color("f6f2ea")], "schirm_uni": [Color("e4d3b0")], "schirm_gold": [Color("e8b53a")]}.get(id, [Color("e4d3b0")])
	var dach := _schirmdach(1.0, 0.32, farben, id == "schirm_gold")
	dach.position = p + Vector3(-0.15, 2.48, 0)
	dach.rotation.z = 0.1
	deko.add_child(dach)
	RaumBau.zyl(deko, 0.05, 0.08, p + Vector3(-0.15, 2.5, 0), stahl, 8)

# Schirmdach als flacher Kegel aus 12 Bahnen (abwechselnd in den Farben), Spitze oben bei y = 0
static func _schirmdach(r: float, h: float, farben: Array, gold: bool) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	for i in n:
		var a0 := i * TAU / n
		var a1 := (i + 1) * TAU / n
		var c: Color = farben[i % farben.size()]
		var spitze := Vector3.ZERO
		var p0 := Vector3(sin(a0) * r, -h, cos(a0) * r)
		var p1 := Vector3(sin(a1) * r, -h, cos(a1) * r)
		var nrm := (p1 - spitze).cross(p0 - spitze).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		for q in [spitze, p1, p0]:
			st.set_color(c)
			st.set_normal(nrm)
			st.add_vertex(q)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.25 if gold else 0.85
	m.metallic = 0.95 if gold else 0.0
	mi.material_override = m
	return mi
