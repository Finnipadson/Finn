class_name StadtDetails
extends Node3D
# Details für die Stadt im Stil von Dubai:
# - großer See am Turmfuß mit Fontänen-Show (Wasser und Fontänen aus Code, shader/wasser + shader/fontaene)
# - Palmen (Kenney Pirate Kit, CC0, modelle/natur) auf dem Platz, um den See und auf den Mittelstreifen der Straßen
# - Straßenlaternen mit zwei Armen auf den Mittelstreifen (aus Code)
# Alles Wiederholte liegt in MultiMeshes, damit es schnell bleibt.

const PALMEN := ["natur/palm-detailed-straight", "natur/palm-detailed-bend"]
const ALLEE_BIS := 540.0       # so weit vom Turm haben die Straßen Mittelstreifen mit Palmen (Boden-Shader: allee_r)
const RASTER := 75.0

var welt: Welt
var rng := RandomNumberGenerator.new()
var palmen_xf: Array = [[], []]    # Transform3D je Palmen-Art
var lampen_xf: Array = []
var palmen_mat: ShaderMaterial
var bank_xf: Array = []
var kuebel_xf: Array = []
var busch_xf: Array = []
var eimer_xf: Array = []
var leute_zahl := 0
const FIGUREN := ["leute/character-female-a", "leute/character-female-c", "leute/character-male-b", "leute/character-male-e", "leute/character-worker"]

func baue(w: Welt) -> void:
	welt = w
	rng.seed = 7
	_see()
	_platz_palmen()
	_see_palmen()
	_alleen()
	_platz_moebel()
	_see_baenke()
	_fussgaenger()
	_kueste()
	_leute()
	palmen_mat = ShaderMaterial.new()
	palmen_mat.shader = load("res://shader/palme.gdshader")
	palmen_mat.set_shader_parameter("farben", load("res://modelle/natur/Textures/colormap.png"))
	for i in PALMEN.size():
		_mm_aus_modell("res://modelle/%s.glb" % PALMEN[i], palmen_xf[i], palmen_mat)
	_mm_aus_modell("res://modelle/natur/plant_bushDetailed.glb", busch_xf, Bau.matt("3f6a2e", 0.85))   # natürliches Grün statt Kenney-Türkis
	_lampen_mm()
	_moebel_mm()
	print("Stadtdetails: %d Bänke, %d Pflanzkübel, %d Mülleimer, %d Leute" % [bank_xf.size(), kuebel_xf.size(), eimer_xf.size(), leute_zahl])

# ---------------------------------------------------------------- See mit Fontänen
func _see() -> void:
	var rand := welt.see_umriss(0.0)
	# Wasserfläche (konvex → Fächer aus der Mitte)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m := welt.see_mitte()
	for i in rand.size():
		var a: Vector2 = rand[i]
		var b: Vector2 = rand[(i + 1) % rand.size()]
		_tri(st, Vector3(m.x, 0.3, m.y), Vector3(b.x, 0.3, b.y), Vector3(a.x, 0.3, a.y), Vector3.UP)
	var wasser := MeshInstance3D.new()
	wasser.mesh = st.commit()
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shader/wasser.gdshader")
	wasser.material_override = wm
	wasser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wasser)
	# Steinkante rundherum (0,55 m hoch, 0,7 m breit)
	var innen := rand
	var aussen := welt.see_umriss(0.7)
	var kante := SurfaceTool.new()
	kante.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.55
	for i in innen.size():
		var j := (i + 1) % innen.size()
		var i0: Vector2 = innen[i]
		var i1: Vector2 = innen[j]
		var a0: Vector2 = aussen[i]
		var a1: Vector2 = aussen[j]
		var raus := Vector3(a0.x - i0.x, 0, a0.y - i0.y).normalized()
		if absf((i0.y + i1.y) * 0.5 - Kueste.BOUL_Z) < Kueste.KANAL_HALB + Kueste.RAND_B * 0.5 and i0.x < Kueste.BOUL_X0:
			continue   # hier mündet der Kanal zum Meer
		_quad(kante, Vector3(i0.x, h, i0.y), Vector3(i1.x, h, i1.y), Vector3(a1.x, h, a1.y), Vector3(a0.x, h, a0.y), Vector3.UP)   # oben
		_quad(kante, Vector3(a0.x, h, a0.y), Vector3(a1.x, h, a1.y), Vector3(a1.x, 0, a1.y), Vector3(a0.x, 0, a0.y), raus)        # außen
		_quad(kante, Vector3(i1.x, h, i1.y), Vector3(i0.x, h, i0.y), Vector3(i0.x, 0, i0.y), Vector3(i1.x, 0, i1.y), -raus)       # innen
	var km := MeshInstance3D.new()
	km.mesh = kante.commit()
	km.material_override = Bau.matt("ddd2bd", 0.75)
	add_child(km)
	_fontaenen()

# Dreieck mit gewünschter Vorderseite (Godot: Vorderseite im Uhrzeigersinn)
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	var ecken := [a, b, c] if (c - a).cross(b - a).dot(n) > 0.0 else [a, c, b]
	st.set_normal(n)
	for v in ecken:
		st.add_vertex(v)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)

# Lage der Fontänen in See-Koordinaten (x = weg vom Turm, y = quer), Werte siehe shader/fontaene (INSTANCE_CUSTOM)
func _fontaenen_liste() -> Array:
	var l := []
	var n := 44
	for i in n:   # großer Bogen
		var t := float(i) / (n - 1)
		var b := lerpf(-70.0, 70.0, t)
		l.append({"p": Vector2(-12.0 + 24.0 * pow(b / 70.0, 2.0), b), "c": Color(t, 0.0, 38.0, rng.randf())})
	for i in 13:  # niedrige Reihe davor
		var t := float(i) / 12.0
		l.append({"p": Vector2(-32.0, lerpf(-60.0, 60.0, t)), "c": Color(t, 0.0, 16.0, rng.randf())})
	for i in 16:  # Ring
		var a := TAU * i / 16.0
		l.append({"p": Vector2(22.0, 0.0) + Vector2(cos(a), sin(a)) * 14.0, "c": Color(float(i) / 16.0, 1.0, 55.0, rng.randf())})
	l.append({"p": Vector2(22.0, 0.0), "c": Color(0.5, 2.0, 85.0, 0.5)})   # große Mittelfontäne
	return l

func _fontaenen() -> void:
	var liste := _fontaenen_liste()
	var m := welt.see_mitte()
	var basis := Node3D.new()
	basis.position = Vector3(m.x, 0.3, m.y)
	add_child(basis)
	var strahl := CylinderMesh.new()
	strahl.top_radius = 0.5
	strahl.bottom_radius = 0.5
	strahl.height = 1.0
	strahl.radial_segments = 10
	strahl.rings = 6
	strahl.cap_top = false
	strahl.cap_bottom = false
	var wolke := SphereMesh.new()
	wolke.radius = 1.0
	wolke.height = 2.0
	wolke.radial_segments = 12
	wolke.rings = 6
	var schaum := PlaneMesh.new()
	schaum.size = Vector2(2, 2)
	var meshes := [strahl, wolke, schaum]
	for art in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[art]
		mm.instance_count = liste.size()
		for i in liste.size():
			var f: Dictionary = liste[i]
			var w := welt.see_welt(f.p) - m
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(w.x, 0, w.y)))
			mm.set_instance_custom_data(i, f.c)
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shader/fontaene.gdshader")
		sm.set_shader_parameter("art", art)
		sm.render_priority = [1, 2, 0][art]
		mi.material_override = sm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-110, -1, -110), Vector3(220, 110, 220))   # Shader hebt die Fontänen an
		basis.add_child(mi)

# ---------------------------------------------------------------- Palmen + Laternen
func _palme(p: Vector2, hindernis := true, hoehe := 0.0, gerade := false) -> void:
	var s := rng.randf_range(2.3, 3.1)
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
	var art := 0 if rng.randf() < 0.55 else 1
	palmen_xf[0 if gerade else art].append(Transform3D(b, Vector3(p.x, hoehe, p.y)))
	if hindernis:
		welt.hindernisse.append(Rect2(p - Vector2(0.45, 0.45), Vector2(0.9, 0.9)))

func _lampe(p: Vector2, quer: Vector2) -> void:
	var b := Basis(Vector3.UP, atan2(quer.x, quer.y))
	lampen_xf.append(Transform3D(b, Vector3(p.x, 0, p.y)))
	welt.hindernisse.append(Rect2(p - Vector2(0.3, 0.3), Vector2(0.6, 0.6)))

# Ring aus Palmen am Rand des Platzes (im Grünring des Boden-Shaders)
func _platz_palmen() -> void:
	var r := Welt.PLATZ_R - 9.0
	var n := int(TAU * r / 12.0)
	for i in n:
		var a := TAU * i / n
		var p := Vector2(cos(a), sin(a)) * r
		if welt.see_abstand(p) < 10.0:
			continue
		_palme(p)

# Palmen und Laternen auf der Promenade um den See
func _see_palmen() -> void:
	var pal := welt.see_umriss(8.0, 3.0)
	var lam := welt.see_umriss(13.0, 3.0)
	var weg := 0.0
	for i in pal.size():
		var a: Vector2 = pal[i]
		weg += a.distance_to(pal[(i + 1) % pal.size()])
		if weg >= 14.0:
			weg = 0.0
			if a.length() > Welt.PLATZ_R - 2.0 and not _am_kanal(a):
				_palme(a)
	weg = 0.0
	for i in lam.size():
		var a: Vector2 = lam[i]
		var b: Vector2 = lam[(i + 1) % lam.size()]
		weg += a.distance_to(b)
		if weg >= 28.0 and a.length() > Welt.PLATZ_R + 2.0 and not _am_kanal(a):
			weg = 0.0
			_lampe(a, (b - a).normalized().orthogonal())

# Mittelstreifen aller Straßen in Turmnähe: je Straßenstück (zwischen zwei Kreuzungen) Palme – Laterne – Palme,
# nur auf dem Rasen-Mittelstreifen (der beginnt 12 m vor der Kreuzung, davor liegen Zebrastreifen und Kreuzung)
const ALLEE_ORTE := [22.5, 37.5, 52.5]   # Abstand vom Anfang des Straßenstücks (Kreuzung zu Kreuzung = RASTER)

func _alleen() -> void:
	var k0 := -int(ALLEE_BIS / RASTER) - 1
	for richtung in 2:
		for k in range(k0, -k0 + 1):
			var c := RASTER * (k + 0.5)       # Straßenmitte (Häuser stehen auf Vielfachen von 75 m)
			if absf(c) > ALLEE_BIS:
				continue
			for j in range(k0, -k0 + 1):
				var k_lo := RASTER * (j + 0.5)   # Kreuzung am Anfang des Straßenstücks
				var a := Vector2(c, k_lo) if richtung == 0 else Vector2(k_lo, c)
				var b := Vector2(c, k_lo + RASTER) if richtung == 0 else Vector2(k_lo + RASTER, c)
				if not welt.stueck_da(a, b):
					continue
				var quer := Vector2(1, 0) if richtung == 0 else Vector2(0, 1)
				for i in ALLEE_ORTE.size():
					var p := a.lerp(b, ALLEE_ORTE[i] / RASTER)
					if p.length() > ALLEE_BIS - 6.0 or not _frei_fuer_allee(p):   # Mittelstreifen endet bei ALLEE_BIS
						continue
					if i == 1:
						_lampe(p, quer)
					else:
						_palme(p)
	print("Stadtdetails: %d Palmen, %d Laternen" % [palmen_xf[0].size() + palmen_xf[1].size(), lampen_xf.size()])

func _frei_fuer_allee(p: Vector2) -> bool:
	if p.length() < Welt.PLATZ_R + 8.0:
		return false
	if welt.see_abstand(p) < 18.0:
		return false
	for q in Verkehr.schild_punkte():   # unter den Schilderbrücken keine Palme
		if p.distance_to(q) < 14.0:
			return false
	return not welt.bebaut(p, 8.0)

# MultiMesh(es) aus allen MeshInstance3D eines Modells
func _mm_aus_modell(pfad: String, xf: Array, mat: Material = null) -> void:
	if xf.is_empty():
		return
	if not ResourceLoader.exists(pfad):
		push_warning("Modell fehlt: " + pfad)
		return
	var szene: Node3D = load(pfad).instantiate()
	for mi in _meshes(szene, Transform3D.IDENTITY):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = xf.size()
		for i in xf.size():
			var t: Transform3D = xf[i]
			mm.set_instance_transform(i, t * mi.xf)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if mat:
			mmi.material_override = mat
		add_child(mmi)
	szene.free()

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

# Laterne: 10-m-Mast mit zwei Auslegern quer zur Straße (lokal: Ausleger entlang ±X)
func _lampen_mm() -> void:
	if lampen_xf.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.09
	mast.bottom_radius = 0.16
	mast.height = 10.0
	mast.radial_segments = 8
	mast.rings = 1
	st.append_from(mast, 0, Transform3D(Basis.IDENTITY, Vector3(0, 5.0, 0)))
	var sockel := CylinderMesh.new()
	sockel.top_radius = 0.24
	sockel.bottom_radius = 0.28
	sockel.height = 0.8
	sockel.radial_segments = 8
	sockel.rings = 1
	st.append_from(sockel, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)))
	for s in [-1.0, 1.0]:
		var arm := BoxMesh.new()
		arm.size = Vector3(2.6, 0.1, 0.12)
		st.append_from(arm, 0, Transform3D(Basis(Vector3(0, 0, 1), s * 0.12), Vector3(s * 1.25, 9.95 + 0.15, 0)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	mm.instance_count = lampen_xf.size()
	for i in lampen_xf.size():
		mm.set_instance_transform(i, lampen_xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Bau.metall("8d939b", 0.35, 0.8)
	add_child(mmi)
	# Leuchtköpfe: eigene Mesh, damit sie hell leuchten können
	var kopf := BoxMesh.new()
	kopf.size = Vector3(0.9, 0.16, 0.38)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [-1.0, 1.0]:
		st2.append_from(kopf, 0, Transform3D(Basis.IDENTITY, Vector3(s * 2.45, 10.32, 0)))
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.mesh = st2.commit()
	mm2.instance_count = lampen_xf.size()
	for i in lampen_xf.size():
		mm2.set_instance_transform(i, lampen_xf[i])
	var mmi2 := MultiMeshInstance3D.new()
	mmi2.multimesh = mm2
	var km := Bau.matt("f1f3f5", 0.4)
	km.emission_enabled = true
	km.emission = Color("fff2d8")
	km.emission_energy_multiplier = 0.6
	mmi2.material_override = km
	add_child(mmi2)

# ---------------------------------------------------------------- Sitzbänke, Pflanzkübel, Mülleimer, Leute
# Bank: schaut nach −Z (Lehne hinten bei +Z). blick = Richtung, in die man auf der Bank schaut.
func _bank(p: Vector2, blick: Vector2) -> void:
	var b := Basis.looking_at(Vector3(blick.x, 0, blick.y), Vector3.UP)
	bank_xf.append(Transform3D(b, Vector3(p.x, 0, p.y)))
	welt.hindernisse.append(Rect2(p - Vector2(0.8, 0.8), Vector2(1.6, 1.6)))

func _kuebel(p: Vector2, mit_palme := false) -> void:
	kuebel_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * 0.2), Vector3(p.x, 0, p.y)))
	if mit_palme:
		_palme(p, false, 0.55)
	else:
		var s := rng.randf_range(4.2, 5.0)
		busch_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, 0.6, p.y)))
	welt.hindernisse.append(Rect2(p - Vector2(0.85, 0.85), Vector2(1.7, 1.7)))

func _eimer(p: Vector2) -> void:
	eimer_xf.append(Transform3D(Basis.IDENTITY, Vector3(p.x, 0, p.y)))
	welt.hindernisse.append(Rect2(p - Vector2(0.3, 0.3), Vector2(0.6, 0.6)))

func _winkel_frei(a: float, liste: Array, abstand: float) -> bool:
	for w in liste:
		if absf(wrapf(a - deg_to_rad(w), -PI, PI)) < deg_to_rad(abstand):
			return false
	return true

const FLUEGEL_WINKEL := [30.0, 150.0, 270.0]

# Platz: Bänke vor dem Palmenring (Blick zum Turm), Mülleimer, Pflanzkübel in den Lücken zwischen den Flügeln
func _platz_moebel() -> void:
	var n := 40
	for i in n:
		var a := TAU * (i + 0.5) / n
		if not _winkel_frei(a, Welt.STAND_WINKEL, 9.0):
			continue
		var r := Vector2(cos(a), sin(a))
		_bank(r * 80.0, -r)
		if i % 4 == 0:
			_eimer(r * 80.0 + r.orthogonal() * 1.6)
	for i in 24:
		var a := TAU * i / 24.0
		if not _winkel_frei(a, FLUEGEL_WINKEL, 20.0) or not _winkel_frei(a, Welt.STAND_WINKEL, 9.0):
			continue
		_kuebel(Vector2(cos(a), sin(a)) * 58.0)

# See: Bänke mit Blick aufs Wasser
func _see_baenke() -> void:
	var l := welt.see_umriss(4.5, 2.0)
	var weg := 0.0
	for i in l.size():
		var a: Vector2 = l[i]
		var b: Vector2 = l[(i + 1) % l.size()]
		weg += a.distance_to(b)
		if weg < 20.0 or a.length() < Welt.PLATZ_R + 2.0 or _am_kanal(a):
			continue
		weg = 0.0
		var innen := (b - a).normalized().orthogonal()
		if welt.see_abstand(a + innen) > welt.see_abstand(a):
			innen = -innen
		_bank(a, innen)

# Fußgängerzonen: wo früher Straßen zum Turm führten (Straßenstück fehlt), stehen Pflanzkübel mit Palmen und Büschen
func _fussgaenger() -> void:
	var k0 := int(500.0 / RASTER) + 1
	for richtung in 2:
		for k in range(-k0, k0):
			var c := RASTER * (k + 0.5)
			for j in range(-k0, k0):
				var k_lo := RASTER * (j + 0.5)
				var a := Vector2(c, k_lo) if richtung == 0 else Vector2(k_lo, c)
				var b := Vector2(c, k_lo + RASTER) if richtung == 0 else Vector2(k_lo + RASTER, c)
				if welt.stueck_da(a, b):
					continue
				var nr := 0
				var s := k_lo + 12.0
				while s <= k_lo + RASTER - 12.0:
					var p := Vector2(c, s) if richtung == 0 else Vector2(s, c)
					s += 10.0
					if p.length() < Welt.PLATZ_R + 6.0 or welt.see_abstand(p) < Welt.PROMENADE + 3.0 or welt.bebaut(p, 6.0) or _im_boulevard(p):
						continue
					var quer := Vector2(1, 0) if richtung == 0 else Vector2(0, 1)
					match nr % 3:
						0: _kuebel(p, true)
						1:
							_bank(p + quer * 1.2, quer)
							_bank(p - quer * 1.2, -quer)
						2: _kuebel(p, false)
					if nr % 6 == 1:
						_eimer(p + quer * 3.2)
					nr += 1

# ---------------------------------------------------------------- Küste: Palmen-Boulevard + Strandpromenade
func _am_kanal(p: Vector2) -> bool:
	return absf(p.y - Kueste.BOUL_Z) < Kueste.KANAL_HALB + Kueste.RAND_B + 2.5 and p.x < Kueste.BOUL_X0 and p.x > Kueste.UFER_X

func _im_boulevard(p: Vector2) -> bool:
	return p.x < Kueste.PROM_X + 4.0 or (absf(p.y - Kueste.BOUL_Z) < Kueste.BOUL_HALB + 2.0 and p.x < Kueste.BOUL_X0)

func _kueste() -> void:
	var k := welt.kueste
	var z0 := Kueste.BOUL_Z
	# Boulevard (Querschnitt ab Kanalmitte): Kanal 0–3,6 · innerer Weg 3,6–6,7 (frei) · Bänke am Rasenrand 7,5 ·
	# Rasenstreifen 8,4–10,6 mit einer Reihe gerader Palmen · äußerer Weg 10,6–19,7 (frei) · Möblierungsstreifen 20,6
	# (Laternen und Pflanzkübel im Wechsel) · Granitband/Rand 21–22. So bleiben beide Gehwege und die Kartenroute frei.
	var x := k.kanal_start - 16.0
	var i := 0
	while x > Kueste.UFER_X + 8.0:
		var nah_bruecke := absf(x - k._naechste_bruecke(x)) < Kueste.BRUECKE_HALB + 3.5
		for s in [-1.0, 1.0]:
			_palme(Vector2(x, z0 + s * 9.5), true, 0.0, true)
			var aussen := Vector2(x, z0 + s * 20.6)
			var am_schild := false   # keine Laterne/kein Kübel vor einem Wegweiser (verdeckt sonst die Schrift)
			for sp in k.schilder:
				if absf((sp as Vector2).x - x) < 9.0 and absf((sp as Vector2).y - aussen.y) < 6.0:
					am_schild = true
			if welt.see_abstand(aussen) > Welt.PROMENADE + 2.0 and not am_schild:
				if i % 2 == 0:
					_lampe(aussen, Vector2(0, 1))
				else:
					_kuebel(aussen)
			if i % 2 == 1 and not nah_bruecke:
				_bank(Vector2(x, z0 + s * 7.5), Vector2(0, -s))
				if i % 4 == 1:
					_eimer(Vector2(x - 1.5, z0 + s * 7.7))
		x -= 12.0
		i += 1
	# Strandpromenade: Palmen an der Mauer, Bänke mit Blick aufs Meer, Laternen zur Stadt hin
	var z := -900.0
	i = 0
	while z < 700.0:
		var frei := absf(z - z0) > Kueste.BOUL_HALB + 4.0 and absf(z - Kueste.STEG_Z) > Kueste.STEG_HALB + 3.0
		if frei:
			if i % 2 == 0:
				_palme(Vector2(Kueste.UFER_X + 5.0, z))
			else:
				_bank(Vector2(Kueste.UFER_X + 1.6, z), Vector2(-1, 0))
			# Laternen nicht in die Verlängerung der Straßen (dort kommt man aus der Stadt auf die Promenade)
			var strasse := absf(wrapf(z - Welt.RASTER * 0.5, -Welt.RASTER * 0.5, Welt.RASTER * 0.5))
			if i % 4 == 0 and strasse > 10.0:
				_lampe(Vector2(Kueste.PROM_X - 4.0, z), Vector2(1, 0))
			if i % 10 == 5:
				_eimer(Vector2(Kueste.UFER_X + 1.6, z + 1.8))
		z += 8.0
		i += 1
	# Leute: Boulevard, Promenade, Strand, Steg
	# Boulevard: Leute stehen im Möblierungsstreifen zwischen Laterne und Kübel (nicht auf den Gehwegen)
	var mitte_x := func(xx: float) -> float:   # Mitte zwischen zwei Laternen-/Kübel-Plätzen nahe xx
		var st := k.kanal_start - 16.0
		return st - (roundf((st - xx) / 12.0) + 0.5) * 12.0
	var orte := [[Vector2(mitte_x.call(-300.0), z0 + 20.2), 0.0], [Vector2(mitte_x.call(-300.0) - 1.1, z0 + 19.6), 0.0],
		[Vector2(mitte_x.call(-420.0), z0 - 20.2), 0.0], [Vector2(mitte_x.call(-520.0), z0 + 20.2), 0.0],
		[Vector2(-592.0, z0 - 30.0), 0.0], [Vector2(-592.0, z0 + 40.0), 0.0], [Vector2(-700.0, Kueste.STEG_Z + 5.5), 0.0], [Vector2(-760.0, Kueste.STEG_Z - 5.0), 0.0],
		[Vector2(-624.0, -40.0), -1.0], [Vector2(-636.0, 20.0), -1.0], [Vector2(-642.0, 60.0), -1.0], [Vector2(-622.0, 110.0), -1.0], [Vector2(-640.0, -20.0), -1.0]]
	for o in orte:
		var p: Vector2 = o[0]
		var y := Kueste.sand_y(p.x) if float(o[1]) < 0.0 else 0.0
		var f := _figur(FIGUREN[rng.randi() % FIGUREN.size()], p, y, 2.8)   # an der Küste etwas größer (~1,55 m)
		var blick := Vector2(-1, 0) if p.x < Kueste.UFER_X + 20.0 else Vector2(0, z0 - p.y)
		f.rotation.y = atan2(blick.x, blick.y)
		welt.hindernisse.append(Rect2(p - Vector2(0.35, 0.35), Vector2(0.7, 0.7)))
		leute_zahl += 1

# Leute, die auf dem Platz und an der Promenade herumstehen (Kenney Mini Characters, Ruhe-Animation)
func _leute() -> void:
	var orte := []
	for i in 16:
		var a := rng.randf() * TAU
		if not _winkel_frei(a, FLUEGEL_WINKEL, 22.0) or not _winkel_frei(a, Welt.STAND_WINKEL, 8.0):
			continue
		orte.append(Vector2(cos(a), sin(a)) * rng.randf_range(40.0, 72.0))
	var l := welt.see_umriss(8.0, 3.0)
	for i in 14:
		var q: Vector2 = l[rng.randi() % l.size()]
		if q.length() > Welt.PLATZ_R + 2.0 and not _am_kanal(q):
			orte.append(q)
	for o in orte:
		var p: Vector2 = o
		for j in rng.randi_range(1, 2):   # einzeln oder zu zweit
			var q := p + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * (0.0 if j == 0 else 1.3)
			var f := _figur(FIGUREN[rng.randi() % FIGUREN.size()], q)
			var ziel := welt.see_mitte() if welt.see_abstand(q) < 30.0 else (p if j > 0 else Vector2.ZERO)
			if j == 0 and welt.see_abstand(q) >= 30.0:
				ziel = Vector2.ZERO
			var d := ziel - q
			if d.length() > 0.1:
				f.rotation.y = atan2(d.x, d.y)   # Kenney-Figuren schauen nach +Z
			welt.hindernisse.append(Rect2(q - Vector2(0.35, 0.35), Vector2(0.7, 0.7)))
			leute_zahl += 1

func _figur(name: String, p: Vector2, y := 0.0, gross := 2.3) -> Node3D:
	var n: Node3D = load("res://modelle/%s.glb" % name).instantiate()
	n.position = Vector3(p.x, y, p.y)
	n.scale = Vector3.ONE * gross
	add_child(n)
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		var wahl := ""
		for a in ap.get_animation_list():
			if "idle" in a.to_lower():
				wahl = a
				break
		if wahl != "":
			ap.get_animation(wahl).loop_mode = Animation.LOOP_LINEAR
			ap.play(wahl)
			ap.seek(rng.randf() * 2.0, true)
	return n

func _moebel_mm() -> void:
	var stein := Bau.matt("d6d0c4", 0.7)
	var holz := Bau.matt("a8744a", 0.65)
	var erde := Bau.matt("4a3a2a", 1.0)
	var dunkel := Bau.metall("3a3e45", 0.4, 0.6)
	# Bank: zwei Steinblöcke + Holzsitz + Lehne
	var bank := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-0.72, 0.72]:
		_quader(st, Vector3(0.36, 0.42, 0.5), Vector3(x, 0.21, 0))
	st.commit(bank)
	bank.surface_set_material(0, stein)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		_quader(st, Vector3(2.0, 0.06, 0.11), Vector3(0, 0.45, -0.19 + k * 0.13))
	for k in 2:
		_quader(st, Vector3(2.0, 0.11, 0.05), Vector3(0, 0.66 + k * 0.15, 0.25))
	_quader(st, Vector3(0.06, 0.4, 0.06), Vector3(-0.72, 0.62, 0.27))
	_quader(st, Vector3(0.06, 0.4, 0.06), Vector3(0.72, 0.62, 0.27))
	st.commit(bank)
	bank.surface_set_material(1, holz)
	_mm_mesh(bank, bank_xf)
	# Pflanzkübel: heller Betonkasten mit Erde
	var kuebel := ArrayMesh.new()
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quader(st, Vector3(1.6, 0.55, 1.6), Vector3(0, 0.275, 0))
	_quader(st, Vector3(1.7, 0.06, 1.7), Vector3(0, 0.56, 0))
	st.commit(kuebel)
	kuebel.surface_set_material(0, stein)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quader(st, Vector3(1.4, 0.04, 1.4), Vector3(0, 0.6, 0))
	st.commit(kuebel)
	kuebel.surface_set_material(1, erde)
	_mm_mesh(kuebel, kuebel_xf)
	# Mülleimer
	var eimer := ArrayMesh.new()
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := CylinderMesh.new()
	z.top_radius = 0.27
	z.bottom_radius = 0.24
	z.height = 0.9
	z.radial_segments = 12
	z.rings = 1
	st.append_from(z, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)))
	st.commit(eimer)
	eimer.surface_set_material(0, dunkel)
	_mm_mesh(eimer, eimer_xf)

func _quader(st: SurfaceTool, g: Vector3, p: Vector3) -> void:
	var bm := BoxMesh.new()
	bm.size = g
	st.append_from(bm, 0, Transform3D(Basis.IDENTITY, p))

func _mm_mesh(mesh: Mesh, xf: Array) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	add_child(mi)
