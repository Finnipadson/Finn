class_name Verkehr
extends Node3D
# Straßenverkehr rund um den Turm: Autos fahren auf den Straßen (Rechtsverkehr), halten an roten Ampeln
# und hinter dem Vordermann. Dazu Ampeln an allen Kreuzungen und grüne Autobahnschilder über einigen Straßen.
# Modelle: Kenney Car Kit (modelle/autos) und City Kit Roads (modelle/strasse), CC0.
# Jedes Automodell ist ein MultiMesh; die Positionen werden jedes Bild als ein Puffer geschrieben (schnell).

const RASTER := 75.0
const BEREICH := 620.0         # so weit vom Turm fährt Verkehr und stehen Ampeln
const SPUR := 3.9              # Abstand der Fahrspur zur Straßenmitte
const HALTELINIE := 14.0       # Automitte hält so weit vor der Kreuzungsmitte (vor dem Zebrastreifen)
const TEMPO := 15.0            # m/s (54 km/h)
const BREMSEN := 5.0
const ANFAHREN := 2.6
const ABSTAND := 7.5           # von Mitte zu Mitte hinter dem Vordermann
const MASS := 1.6              # Kenney-Autos auf echte Größe
const AUTO_DREH := 0.0         # falls die Modelle nach hinten schauen: PI
# Ampel-Takt (s): Richtung A grün, gelb, alle rot, Richtung B grün, gelb, alle rot
const GRUEN := 11.0
const GELB := 2.5
const ALLE_ROT := 2.5
const WENDE_TEMPO := 7.0        # m/s beim Wenden am Ende einer Straße
const MODELLE := ["sedan", "suv", "suv-luxury", "sedan-sports", "hatchback-sports", "van", "taxi", "police", "delivery", "truck"]
const ANTEIL := [22, 16, 14, 8, 8, 6, 12, 3, 6, 5]     # wie oft jedes Modell vorkommt
const EIGENE_FARBE := [true, true, true, true, true, true, false, false, true, true]
const LACKE := ["f2f2f0", "f2f2f0", "e8e8e6", "b9bdc2", "9aa0a8", "1c1d20", "26282c", "3a3f47", "c9b38a", "20324f", "7a1d1d", "5b6b53"]

var welt: Welt
var rng := RandomNumberGenerator.new()
var spuren: Array = []        # Ringe: {achse, c, s0, s1, lang, ring, halte, A, R, C, autos}
var autos: Array = []         # {spur, u, v, vmax, modell, farbe}
var mm: Array = []            # MultiMesh je Modell
var zahl: Array = []          # Autos je Modell
var zeit := 0.0
var ampel_mat: Array = []     # [Achse][Lampe] Materialien der Leuchtscheiben
var je_modell: Array = []     # Autos je Modell (für die Puffer)

func baue(w: Welt) -> void:
	welt = w
	rng.seed = 23
	_spuren()
	_autos()
	_ampeln()
	_schilder()
	print("Verkehr: %d Spuren, %d Autos" % [spuren.size(), autos.size()])

# ---------------------------------------------------------------- Ampeln (Zustand)
# 0 = grün, 1 = gelb, 2 = rot. Achse 0 = Straßen entlang z (x fest), Achse 1 = Straßen entlang x.
func ampel(achse: int) -> int:
	var periode := 2.0 * (GRUEN + GELB + ALLE_ROT)
	var t := fposmod(zeit + (0.0 if achse == 0 else periode * 0.5), periode)
	if t < GRUEN:
		return 0
	if t < GRUEN + GELB:
		return 1
	return 2

# ---------------------------------------------------------------- Straßen in Spuren zerlegen
# Jede Spur ist ein Ring über ein durchgehendes Straßenstück von Kreuzung s0 bis Kreuzung s1:
# hin (rechte Seite), auf der Kreuzung s1 wenden, zurück, auf der Kreuzung s0 wenden. So tauchen nie Autos auf oder ab.
func _punkt(achse: int, c: float, s: float) -> Vector2:
	return Vector2(c, s) if achse == 0 else Vector2(s, c)

func _spuren() -> void:
	var k0 := int(BEREICH / RASTER) + 1
	for achse in 2:
		for k in range(-k0, k0):
			var c := RASTER * (k + 0.5)
			var s0 := INF
			var s_vor := 0.0
			for j in range(-k0, k0 + 1):
				var s := RASTER * (j + 0.5)
				var drin := _punkt(achse, c, s).length() < BEREICH - 10.0 and welt.kreuzung_ok(_punkt(achse, c, s))
				var weiter := drin and s0 != INF and welt.stueck_da(_punkt(achse, c, s_vor), _punkt(achse, c, s))
				if s0 != INF and not weiter:
					if s_vor > s0:
						_spur(achse, c, s0, s_vor)
					s0 = INF
				if drin and s0 == INF:
					s0 = s
				s_vor = s
			if s0 != INF and s_vor > s0:
				_spur(achse, c, s0, s_vor)

func _spur(achse: int, c: float, s0: float, s1: float) -> void:
	var lang := s1 - s0
	var halb := PI * SPUR
	var halte := PackedFloat32Array()
	var s := s0 + RASTER
	while s <= s1 + 0.1:          # hin: Kreuzungen nach s0 (auch die Wende-Kreuzung s1)
		if welt.querverkehr(_punkt(achse, c, s), achse):
			halte.append(s - s0 - HALTELINIE)
		s += RASTER
	s = s1 - RASTER
	while s >= s0 - 0.1:          # zurück: Kreuzungen vor s1 (auch die Wende-Kreuzung s0)
		if welt.querverkehr(_punkt(achse, c, s), achse):
			halte.append(lang + halb + (s1 - s) - HALTELINIE)
		s -= RASTER
	var A := Vector2(0, 1) if achse == 0 else Vector2(1, 0)
	spuren.append({"achse": achse, "c": c, "s0": s0, "s1": s1, "lang": lang, "ring": 2.0 * lang + 2.0 * halb,
		"halte": halte, "A": A, "R": Vector2(-A.y, A.x), "C": Vector2(c, 0) if achse == 0 else Vector2(0, c), "autos": []})

func _autos() -> void:
	var summe := 0
	for a in ANTEIL:
		summe += a
	for i in MODELLE.size():
		zahl.append(0)
	for si in spuren.size():
		var sp: Dictionary = spuren[si]
		var u := rng.randf_range(0.0, 20.0)
		while u < float(sp.ring) - 30.0:
			var wahl := rng.randi_range(0, summe - 1)
			var m := 0
			while wahl >= ANTEIL[m]:
				wahl -= ANTEIL[m]
				m += 1
			var farbe := Color(LACKE[rng.randi() % LACKE.size()]) if EIGENE_FARBE[m] else Color(1, 1, 1, 0)
			var auto := {"spur": si, "u": u, "v": TEMPO, "vmax": TEMPO * rng.randf_range(0.8, 1.1), "modell": m, "nr": zahl[m], "farbe": farbe}
			zahl[m] += 1
			autos.append(auto)
			sp.autos.append(auto)
			u += rng.randf_range(40.0, 120.0)
		sp.autos.reverse()   # Index 0 = vorderstes Auto
	for m in MODELLE.size():
		var l := []
		for a in autos:
			if a.modell == m:
				l.append(a)
		je_modell.append(l)
	for m in MODELLE.size():
		_auto_mm(m)

# Ein Modell zu einem einzigen Mesh zusammenfassen (Karosserie + Räder) und als MultiMesh anlegen
func _auto_mm(m: int) -> void:
	var szene: Node3D = load("res://modelle/autos/%s.glb" % MODELLE[m]).instantiate()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for teil in _meshes(szene, Transform3D.IDENTITY):
		var mesh: Mesh = teil.mesh
		for f in mesh.get_surface_count():
			st.append_from(mesh, f, teil.xf)
	szene.free()
	var mesh := st.commit()
	var mul := MultiMesh.new()
	mul.transform_format = MultiMesh.TRANSFORM_3D
	mul.use_colors = true
	mul.mesh = mesh
	mul.instance_count = zahl[m]
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mul
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shader/auto.gdshader")
	var tex: Texture2D = load("res://modelle/autos/Textures/colormap.png")
	sm.set_shader_parameter("farben", tex)
	sm.set_shader_parameter("zelle", _lack_zelle(mesh, tex.get_image()))
	mi.material_override = sm
	mi.custom_aabb = AABB(Vector3(-BEREICH, -1, -BEREICH), Vector3(BEREICH * 2, 6, BEREICH * 2))
	add_child(mi)
	mm.append(mul)

# Das bunte Palettenfeld, das die größte Fläche des Modells bedeckt = Lack
func _lack_zelle(mesh: ArrayMesh, bild: Image) -> Vector2:
	var flaeche := {}
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx = arr[Mesh.ARRAY_INDEX]
	var n: int = idx.size() if idx != null else v.size()
	for t in range(0, n, 3):
		var a: int = idx[t] if idx != null else t
		var b: int = idx[t + 1] if idx != null else t + 1
		var c: int = idx[t + 2] if idx != null else t + 2
		var f := (v[b] - v[a]).cross(v[c] - v[a]).length()
		var z := (uv[a] * Vector2(8, 4)).floor()
		flaeche[z] = flaeche.get(z, 0.0) + f
	var beste := Vector2(-1, -1)
	var max_f := 0.0
	for z in flaeche:
		var zz: Vector2 = z
		var px := bild.get_pixel(clampi(int((zz.x + 0.5) / 8.0 * bild.get_width()), 0, bild.get_width() - 1), clampi(int((zz.y + 0.5) / 4.0 * bild.get_height()), 0, bild.get_height() - 1))
		if px.s < 0.35 or px.v < 0.35:   # Glas, Reifen, Grau: kein Lack
			continue
		if flaeche[z] > max_f:
			max_f = flaeche[z]
			beste = zz
	return beste

func _meshes(n: Node, xf: Transform3D) -> Array:
	var l := []
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		l.append({"mesh": (n as MeshInstance3D).mesh, "xf": t})
	for c in n.get_children():
		l.append_array(_meshes(c, t))
	return l

# ---------------------------------------------------------------- Fahren
func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	zeit += dt
	for sp in spuren:
		_spur_fahren(sp, dt)
	for m in mm.size():
		var b := PackedFloat32Array()
		b.resize(zahl[m] * 16)
		var o := 0
		for a in je_modell[m]:
			var q: Vector3 = a.pos       # x, z, Einblenden
			var r: Vector2 = a.dreh      # cos, sin (mit Maßstab)
			var f: Color = a.farbe
			b[o] = r.x; b[o + 1] = 0.0; b[o + 2] = r.y; b[o + 3] = q.x
			b[o + 4] = 0.0; b[o + 5] = MASS * q.z; b[o + 6] = 0.0; b[o + 7] = 0.0
			b[o + 8] = -r.y; b[o + 9] = 0.0; b[o + 10] = r.x; b[o + 11] = q.y
			b[o + 12] = f.r; b[o + 13] = f.g; b[o + 14] = f.b; b[o + 15] = f.a
			o += 16
		(mm[m] as MultiMesh).buffer = b

func _spur_fahren(sp: Dictionary, dt: float) -> void:
	var liste: Array = sp.autos
	var n := liste.size()
	if n == 0:
		return
	var ring: float = sp.ring
	var lang: float = sp.lang
	var halb := PI * SPUR
	var licht := ampel(sp.achse)
	var halte: PackedFloat32Array = sp.halte
	for i in n:
		var a: Dictionary = liste[i]
		var vorne: Dictionary = liste[(i - 1 + n) % n]     # Autos sind in Fahrtrichtung sortiert (Ring)
		var u: float = a.u
		var frei := 1e9
		if n > 1:
			frei = fposmod(float(vorne.u) - u, ring) - ABSTAND
		# Haltelinie vor der nächsten Kreuzung mit Querverkehr
		if licht != 0:
			for h in halte:
				var bis := h - u
				if bis > -0.5:
					# bei Gelb nur anhalten, wenn es noch geht – vor dem Wenden immer (Wenden dauert länger)
					var wende := absf(h - (lang - HALTELINIE)) < 0.1 or absf(h - (2.0 * lang + halb - HALTELINIE)) < 0.1
					if licht == 2 or bis > 10.0 or wende:
						frei = minf(frei, bis)
					break
		var ziel := minf(float(a.vmax), sqrt(2.0 * BREMSEN * maxf(frei - 0.5, 0.0)))
		# vor dem Wenden langsamer werden
		var bis_wende := 0.0
		if u < lang:
			bis_wende = lang - u
		elif u >= lang + halb and u < 2.0 * lang + halb:
			bis_wende = 2.0 * lang + halb - u
		ziel = minf(ziel, sqrt(WENDE_TEMPO * WENDE_TEMPO + 2.0 * BREMSEN * bis_wende))
		var v: float = a.v
		v = ziel if ziel < v else minf(ziel, v + ANFAHREN * dt)
		a.v = v
		u += v * dt
		a.u = u
		_lage(a, u, sp)
	# das vorderste Auto hat den Ring einmal umrundet: hinten einreihen
	while float(liste[0].u) >= ring:
		var raus: Dictionary = liste.pop_front()
		raus.u = float(raus.u) - ring
		_lage(raus, raus.u, sp)
		liste.push_back(raus)
	# Halte-Liste ist nach u sortiert, damit „break“ oben stimmt
	pass

func _lage(a: Dictionary, u: float, sp: Dictionary) -> void:
	var A: Vector2 = sp.A
	var R: Vector2 = sp.R
	var C: Vector2 = sp.C
	var s0: float = sp.s0
	var s1: float = sp.s1
	var lang: float = sp.lang
	var halb := PI * SPUR
	var p: Vector2
	var d: Vector2
	if u < lang:
		p = C + A * (s0 + u) + R * SPUR
		d = A
	elif u < lang + halb:
		var t := (u - lang) / SPUR
		p = C + A * (s1 + SPUR * sin(t)) + R * (SPUR * cos(t))
		d = A * cos(t) - R * sin(t)
	elif u < 2.0 * lang + halb:
		p = C + A * (s1 - (u - lang - halb)) - R * SPUR
		d = -A
	else:
		var t := (u - 2.0 * lang - halb) / SPUR
		p = C + A * (s0 - SPUR * sin(t)) - R * (SPUR * cos(t))
		d = -A * cos(t) + R * sin(t)
	var w := atan2(d.x, d.y) + AUTO_DREH
	a.pos = Vector3(p.x, p.y, 1.0)
	a.dreh = Vector2(cos(w), sin(w)) * MASS

# ---------------------------------------------------------------- Ampeln + Schilder (Modelle)
func _ampeln() -> void:
	var xf: Array = []
	var k0 := int(BEREICH / RASTER) + 1
	for i in range(-k0, k0):
		for j in range(-k0, k0):
			var k := Vector2(RASTER * (i + 0.5), RASTER * (j + 0.5))
			if k.length() > BEREICH - 10.0:
				continue
			for achse in 2:
				for richtung in [1, -1]:
					var h := Vector2(0, richtung) if achse == 0 else Vector2(richtung, 0)
					var rechts := Vector2(-h.y, h.x)
					if not welt.stueck_da(k - h * RASTER, k) or not welt.querverkehr(k, achse):
						continue
					var p := k - h * 12.0 + rechts * 7.4     # rechts vor der Kreuzung am Straßenrand
					var t := Transform3D(Basis(Vector3.UP, atan2(h.x, h.y) + AMPEL_DREH).scaled(Vector3.ONE * AMPEL_MASS), Vector3(p.x, 0, p.y))
					xf.append([t, achse])
					welt.hindernisse.append(Rect2(p - Vector2(0.3, 0.3), Vector2(0.6, 0.6)))
	var nur_xf: Array = []
	for e in xf:
		nur_xf.append(e[0])
	_modell_mm("res://modelle/strasse/traffic-light-hanging.glb", nur_xf)
	# Leuchtende Scheiben auf den drei Lampen (grün unten, gelb, rot oben); je Achse und Lampe ein Material
	var scheibe := CylinderMesh.new()
	scheibe.top_radius = 0.016
	scheibe.bottom_radius = 0.016
	scheibe.height = 0.004
	scheibe.radial_segments = 12
	scheibe.rings = 1
	var liegend := Basis(Vector3(0, 0, 1), PI / 2.0)   # Scheibe schaut nach −X wie die Lampen im Modell
	for achse in 2:
		var mats := []
		for lampe in 3:
			var km := StandardMaterial3D.new()
			km.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			km.albedo_color = Color("1a1a1a")
			mats.append(km)
			var mul := MultiMesh.new()
			mul.transform_format = MultiMesh.TRANSFORM_3D
			mul.mesh = scheibe
			var l: Array = []
			for e in xf:
				if e[1] == achse:
					l.append(e[0])
			mul.instance_count = l.size()
			var lokal := Transform3D(liegend, Vector3(-0.053, AMPEL_LAMPEN_Y[lampe], -0.2195))
			for i in l.size():
				var t: Transform3D = l[i]
				mul.set_instance_transform(i, t * lokal)
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mul
			mi.material_override = km
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
		ampel_mat.append(mats)

const AMPEL_MASS := 10.0
const AMPEL_DREH := -PI / 2.0                 # Modell: Lampen schauen nach −X, Ausleger nach −Z
const AMPEL_LAMPEN_Y := [0.396, 0.437, 0.478]  # grün, gelb, rot (Modell-Einheiten)
const LAMPEN_AN := ["3dff6e", "ffc21a", "ff2a1a"]

func _physics_process(_dt: float) -> void:
	for achse in ampel_mat.size():
		var zustand := ampel(achse)
		for lampe in 3:
			var an := Color(LAMPEN_AN[lampe]) * 1.6 if lampe == zustand else Color("202020")
			(ampel_mat[achse][lampe] as StandardMaterial3D).albedo_color = an

# Grüne Schilderbrücken über einigen Straßen (wie an den großen Straßen in Dubai)
func _schilder() -> void:
	var xf: Array = []
	var texte: Array = []
	var orte := SCHILDER
	var ziele := ["Wüstennadel  ↑\nInnenstadt", "Hafen  →\nMarina  ↑", "Flughafen  ↑\nWüste  →", "Wüstennadel  ←\nAltstadt  ↑", "Strand  ↑\nMarina  →", "Innenstadt  ↑\nHafen  ←"]
	for i in orte.size():
		var o: Array = orte[i]
		var achse: int = o[0]
		var c: float = o[1]
		var s: float = o[2]
		var richtung: int = o[3]
		var p := _punkt(achse, c, s)
		var k_vor := floorf((s - RASTER * 0.5) / RASTER) * RASTER + RASTER * 0.5   # Schild nur über vorhandener Straße
		if not welt.stueck_da(_punkt(achse, c, k_vor), _punkt(achse, c, k_vor + RASTER)):
			continue
		var h := Vector2(0, richtung) if achse == 0 else Vector2(richtung, 0)
		var rechts := Vector2(-h.y, h.x)
		var b := Basis(Vector3.UP, atan2(h.x, h.y) + SCHILD_DREH).scaled(Vector3.ONE * SCHILD_MASS)
		xf.append(Transform3D(b, Vector3(p.x, 0, p.y)))
		for sseite in [-1.0, 1.0]:
			var q: Vector2 = p + rechts * (sseite * SCHILD_MASS * 0.5)
			welt.hindernisse.append(Rect2(q - Vector2(0.4, 0.4), Vector2(0.8, 0.8)))
		var l := Label3D.new()
		l.text = ziele[i]
		l.font_size = 110
		l.pixel_size = 0.0058
		l.outline_size = 0
		l.modulate = Color.WHITE
		l.shaded = false
		l.double_sided = false
		var vorn := -h * (SCHILD_VORN)
		l.position = Vector3(p.x + vorn.x, SCHILD_TEXT_Y, p.y + vorn.y)
		l.rotation.y = atan2(-h.x, -h.y)
		add_child(l)
	_modell_mm("res://modelle/strasse/sign-highway-wide.glb", xf)

const SCHILD_MASS := 14.0
# Schilderbrücken: [Achse, Straße, Lage entlang der Straße, Fahrtrichtung] – dort lässt StadtDetails Platz (keine Palme)
const SCHILDER := [[0, 187.5, 225.0, 1], [0, -187.5, -300.0, -1], [1, 112.5, -300.0, -1], [1, -262.5, 225.0, 1], [0, 337.5, -150.0, -1], [1, 187.5, 375.0, 1]]

static func schild_punkte() -> Array:
	var l := []
	for o in SCHILDER:
		l.append(Vector2(o[1], o[2]) if o[0] == 0 else Vector2(o[2], o[1]))
	return l
const SCHILD_DREH := -PI / 2.0
const SCHILD_TEXT_Y := 8.85
const SCHILD_VORN := 1.2

func _modell_mm(pfad: String, xf: Array) -> void:
	if xf.is_empty():
		return
	var szene: Node3D = load(pfad).instantiate()
	for teil in _meshes(szene, Transform3D.IDENTITY):
		var mul := MultiMesh.new()
		mul.transform_format = MultiMesh.TRANSFORM_3D
		mul.mesh = teil.mesh
		mul.instance_count = xf.size()
		for i in xf.size():
			var t: Transform3D = xf[i]
			mul.set_instance_transform(i, t * teil.xf)
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mul
		add_child(mi)
	szene.free()
