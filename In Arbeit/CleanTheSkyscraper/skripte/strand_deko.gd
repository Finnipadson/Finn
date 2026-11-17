class_name StrandDeko
extends Node3D
# Mehr Leben am Strand (Wunsch des Users, 16.11.2026): fast alles aus Code (keine Namensnennung nötig), dazu Kenney-
# Modelle (CC0) aus modelle/strand. Rettungstürme, Volleyballfeld, Sandburgen mit Eimer + Schaufel, Strandbälle,
# Surfbretter, Handtücher, Kühlboxen, Ruderboote, Fässer, Kisten, Felsen, Treibholz, Dünengras, Bojen-Kette der
# Badezone, Muscheln + Seesterne (MultiMesh), Krabben (laufen hin und her), Möwen (stehen bzw. kreisen).
# Baut Kueste.baue(); feste Teile landen in kueste.rechtecke (Kollision zu Fuß).

var k: Kueste
var rng := RandomNumberGenerator.new()
var _moewen: Array = []          # {knoten, mitte, r, hoehe, tempo, phase, fluegel: [l, r]}
var _krabben: Array = []         # {knoten, a, b, t, tempo}
var _zeit := 0.0
var sand := Bau.matt("d8b97c", 0.95)
var sand_nass := Bau.matt("c4a26a", 0.95)
var weiss := Bau.matt("f6f6f2", 0.5)
var rot := Bau.matt("e2483e", 0.55)
var _gras := Bau.matt("8a9a4a", 0.9)

func baue(kueste: Kueste) -> void:
	k = kueste
	rng.seed = 33
	var fest := Node3D.new()      # wird am Ende zu wenigen Meshes verschmolzen
	fest.name = "StrandDekoFest"
	add_child(fest)
	# Südstrand zwischen Treppe und Steg (z −191 … −132): Volleyballfeld, Rettungsturm, Sandburgen, Ruderboote
	_rettungsturm(fest, Vector2(-640.5, -140.0), PI * 0.5)
	_rettungsturm(fest, Vector2(-641.0, 175.0), PI * 0.5)
	_volleyball(fest, Vector2(-626.0, -164.0))
	for p in [Vector2(-642.0, -150.0), Vector2(-643.0, -131.0), Vector2(-642.5, -35.0), Vector2(-643.5, 64.0), Vector2(-642.0, 118.0), Vector2(-643.0, 205.0)]:
		_sandburg(fest, p, rng.randf() * TAU)
	for p in [Vector2(-618.0, -150.0), Vector2(-636.0, -182.0), Vector2(-633.0, 30.0), Vector2(-622.0, 95.0), Vector2(-636.0, 150.0), Vector2(-622.0, 230.0)]:
		_strandball(fest, p)
	# Surfbretter an der Bar (Ostseite) und bei den Rettungstürmen
	var bar := Kueste.BAR
	for i in 4:
		_surfbrett(fest, Vector2(bar.end.x + 0.45, bar.position.y + 1.6 + i * 0.75), 0.18, ["35c8ff", "ffc531", "ff4fb8", "7fe08a"][i])
	_surfbrett(fest, Vector2(-637.0, -137.5), -0.15, "e2483e")
	_surfbrett(fest, Vector2(-637.6, 178.0), -0.15, "ffb03a")
	# Handtücher + Kühlboxen zwischen den Liegen und am Südstrand
	for i in 26:
		var z := rng.randf_range(-58.0, 255.0)
		var x := rng.randf_range(-640.0, -613.0)
		if _frei_fuer_tuch(Vector2(x, z)):
			_handtuch(fest, Vector2(x, z), rng.randf_range(-0.4, 0.4))
	for p in [Vector2(-614.0, -178.0), Vector2(-620.0, -137.0), Vector2(-634.0, -170.0)]:
		_handtuch(fest, p, rng.randf_range(-0.3, 0.3))
	for i in 10:
		var z := rng.randf_range(-55.0, 250.0)
		var x: float = [-619.2, -631.2, -641.2][i % 3]
		_kuehlbox(fest, Vector2(x, z), rng.randf() * TAU)
	_kuehlbox(fest, Vector2(-621.0, -136.0), 0.4)
	# Kenney-Modelle: Ruderboote, Fässer, Kisten, Felsen, Treibholz, Dünengras
	_modell(fest, "boat-row-large", Vector2(-640.0, -186.0), 1.25, 0.6, true)
	_modell(fest, "boat-row-small", Vector2(-637.0, 258.0), 1.25, -0.4, true)
	_modell(fest, "boat-row-small", Vector2(-643.0, -118.5 - 10.0), 1.2, 2.1, true)
	for p in [Vector2(-688.0, -196.0), Vector2(-689.2, -196.4), Vector2(-688.5, -195.0)]:   # auf dem Steg neben dem Fischladen
		_modell(fest, "barrel", p, 0.7, rng.randf() * TAU, true, 0.0)
	_modell(fest, "crate", Vector2(-684.5, -199.0), 0.9, 0.3, true, 0.0)
	_modell(fest, "crate-bottles", Vector2(bar.position.x - 1.2, bar.end.y - 1.2), 0.85, 0.1, true)
	_modell(fest, "barrel", Vector2(bar.position.x - 1.1, bar.end.y - 3.0), 0.7, 0.5, true)
	_modell(fest, "rocks-sand-a", Vector2(-649.0, -219.0), 0.9, 0.4, true)   # nicht unter dem Steg (z −208 … −192)
	_modell(fest, "rocks-sand-c", Vector2(-646.0, 268.0), 1.0, 1.2, true)
	_modell(fest, "rocks-sand-b", Vector2(-648.0, 300.0), 1.2, 2.0, true)
	for i in 8:
		var p := Vector2(rng.randf_range(-645.0, -637.0), rng.randf_range(-185.0, 255.0))
		if _frei_fuer_tuch(p):
			_modell(fest, "n_log", p, rng.randf_range(2.5, 3.6), rng.randf() * TAU, false)
	var z2 := -185.0
	while z2 < 270.0:   # Dünengras am Fuß der Ufermauer
		if not (z2 > Kueste.TREPPEN[0].x - 2.0 and z2 < Kueste.TREPPEN[1].y + 2.0) and not (z2 > Kueste.BAR.position.y - 3.0 and z2 < Kueste.BAR.end.y + 2.0):
			_modell(fest, "n_grass_large", Vector2(-607.6 - rng.randf() * 1.2, z2), rng.randf_range(3.0, 4.5), rng.randf() * TAU, false)
			RaumBau.faerben(fest.get_child(fest.get_child_count() - 1), _gras)   # natürliches Dünengrün statt Kenney-Türkis
		z2 += rng.randf_range(2.5, 6.0)
	RaumBau.verschmelzen(fest)
	_bojen()
	_muscheln()
	_krabben_bauen()
	_moewen_bauen()

func _sy(x: float) -> float:
	return Kueste.sand_y(x)

func _fest(r: Rect2) -> void:
	k.rechtecke.append(r)

func _frei_fuer_tuch(p: Vector2) -> bool:
	if Kueste.BAR.grow(3.0).has_point(p):
		return false
	for r in k.rechtecke:
		if (r as Rect2).grow(1.2).has_point(p):
			return false
	return absf(p.y - Kueste.BOUL_Z) > Kueste.KANAL_HALB + 3.0

# ---------------------------------------------------------------- Rettungsturm (rot-weiß, auf Stelzen, Fahne, Ring)
func _rettungsturm(eltern: Node3D, p: Vector2, dreh: float) -> void:
	var n := Node3D.new()
	n.position = Vector3(p.x, _sy(p.x), p.y)
	n.rotation.y = dreh
	eltern.add_child(n)
	var holz := Bau.matt("e9e2d2", 0.6)
	var dach := Bau.matt("c2352a", 0.6)
	var h := 2.4
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var bein := RaumBau.box(n, Vector3(0.14, h + 0.3, 0.14), Vector3(sx * 1.05, (h + 0.3) * 0.5 - 0.15, sz * 1.05), holz)
			bein.rotation = Vector3(sz * 0.05, 0, -sx * 0.05)
	for sz in [-1.0, 1.0]:   # Querstreben
		var q := RaumBau.box(n, Vector3(2.5, 0.08, 0.08), Vector3(0, 1.0, sz * 1.08), holz)
		q.rotation.z = 0.7
	RaumBau.box(n, Vector3(2.9, 0.14, 2.9), Vector3(0, h, 0), holz)
	# Kabine: rote Wände, weiße Fensteröffnung, Fenster nach vorne (−Z lokal = zum Meer)
	RaumBau.box(n, Vector3(2.2, 1.6, 0.1), Vector3(0, h + 0.85, 1.05), rot)
	for sx in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(0.1, 1.6, 2.2), Vector3(sx * 1.05, h + 0.85, 0), rot)
	RaumBau.box(n, Vector3(2.2, 0.55, 0.1), Vector3(0, h + 0.33, -1.05), rot)
	for sx in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(0.12, 1.1, 0.12), Vector3(sx * 1.0, h + 1.1, -1.05), weiss)
	var d := RaumBau.box(n, Vector3(3.0, 0.14, 3.2), Vector3(0, h + 1.85, -0.1), dach)
	d.rotation.x = -0.12
	# Geländer der Plattform vorne, Leiter hinten
	RaumBau.box(n, Vector3(2.9, 0.06, 0.06), Vector3(0, h + 0.9, -1.42), weiss)
	for sx in [-1.4, -0.45, 0.45, 1.4]:
		RaumBau.box(n, Vector3(0.06, 0.9, 0.06), Vector3(sx, h + 0.45, -1.42), weiss)
	for i in 7:
		RaumBau.box(n, Vector3(0.7, 0.06, 0.08), Vector3(0, 0.3 + i * 0.33, 1.65 + i * 0.07), holz)
	for sx in [-0.35, 0.35]:
		var l := RaumBau.box(n, Vector3(0.07, 2.6, 0.07), Vector3(sx, 1.25, 1.85), holz)
		l.rotation.x = -0.2
	# Fahnenmast mit roter Fahne, Rettungsring an der Seite, Schild
	RaumBau.zyl(n, 0.04, 2.2, Vector3(1.2, h + 2.9, 1.0), weiss, 6)
	var f := RaumBau.box(n, Vector3(0.02, 0.5, 0.8), Vector3(1.2, h + 3.75, 0.6), rot)
	f.rotation.x = 0.05
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.22
	tm.outer_radius = 0.36
	tm.rings = 12
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = Bau.matt("ff6b2c", 0.6)
	ring.rotation.z = PI * 0.5
	ring.position = Vector3(1.12, h + 0.8, 0.0)
	n.add_child(ring)
	var l3 := RaumBau.schrift(n, "RETTUNGSSCHWIMMER", Vector3(0, h + 1.55, -1.12), PI, 40, 0.006, Color("ffffff"))
	l3.rotation.y = PI
	l3.double_sided = false
	_fest(Rect2(p - Vector2(1.6, 1.6), Vector2(3.2, 3.2)))

# ---------------------------------------------------------------- Volleyballfeld (Netz quer zu z)
func _volleyball(eltern: Node3D, m: Vector2) -> void:
	var y0 := _sy(m.x)
	var n := Node3D.new()
	n.position = Vector3(m.x, y0, m.y)
	eltern.add_child(n)
	var seil := Bau.matt("2f6fb0", 0.7)
	var halb := Vector2(4.5, 8.0)   # x, z
	for s in [-1.0, 1.0]:   # Spielfeld-Linien (Bänder im Sand)
		RaumBau.box(n, Vector3(0.06, 0.04, halb.y * 2.0), Vector3(s * halb.x, 0.02, 0), seil)
		RaumBau.box(n, Vector3(halb.x * 2.0, 0.04, 0.06), Vector3(0, 0.02, s * halb.y), seil)
	for s in [-1.0, 1.0]:   # Pfosten
		RaumBau.zyl(n, 0.06, 2.6, Vector3(s * (halb.x + 0.6), 1.3, 0), weiss, 8)
	RaumBau.box(n, Vector3(halb.x * 2.0 + 1.2, 0.07, 0.03), Vector3(0, 2.43, 0), weiss)
	RaumBau.box(n, Vector3(halb.x * 2.0 + 1.2, 0.02, 0.02), Vector3(0, 1.45, 0), Bau.matt("2b2d33", 0.7))
	var netz := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(halb.x * 2.0 + 1.2, 0.98)
	netz.mesh = qm
	netz.position = Vector3(0, 1.94, 0)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode cull_disabled, shadows_disabled;\nvoid fragment() {\n\tvec2 g = fract(UV * vec2(64.0, 7.0));\n\tvec2 w = fwidth(UV * vec2(64.0, 7.0)) * 1.2;\n\tfloat l = max(1.0 - smoothstep(0.0, 0.12 + w.x, min(g.x, 1.0 - g.x)), 1.0 - smoothstep(0.0, 0.12 + w.y, min(g.y, 1.0 - g.y)));\n\tALBEDO = vec3(0.12);\n\tALPHA_SCISSOR_THRESHOLD = 0.5;\n\tALPHA = l;\n}\n"
	sm.shader = sh
	netz.material_override = sm
	netz.position = Vector3(m.x, y0 + 1.94, m.y)
	add_child(netz)
	_strandball(eltern, m + Vector2(1.5, 3.0), true)
	for s in [-1.0, 1.0]:
		_fest(Rect2(m + Vector2(s * (halb.x + 0.6), 0) - Vector2(0.25, 0.25), Vector2(0.5, 0.5)))

# ---------------------------------------------------------------- Sandburg mit Eimer + Schaufel
func _sandburg(eltern: Node3D, p: Vector2, dreh: float) -> void:
	var n := Node3D.new()
	n.position = Vector3(p.x, _sy(p.x) - 0.03, p.y)
	n.rotation.y = dreh
	eltern.add_child(n)
	RaumBau.zyl(n, 0.85, 0.3, Vector3(0, 0.15, 0), sand_nass, 14, 0.95)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var q := Vector3(cos(a) * 0.48, 0, sin(a) * 0.48)
		RaumBau.zyl(n, 0.15, 0.55, q + Vector3(0, 0.55, 0), sand, 8, 0.17)
		for j in 4:   # Zinnen
			var b := TAU * j / 4.0
			RaumBau.box(n, Vector3(0.06, 0.07, 0.06), q + Vector3(cos(b) * 0.12, 0.86, sin(b) * 0.12), sand)
		if i < 4:
			var mauer := RaumBau.box(n, Vector3(0.7, 0.3, 0.1), (q + Vector3(cos(a + PI * 0.5) * 0.34, 0, sin(a + PI * 0.5) * 0.34)) * 0.98 + Vector3(0, 0.45, 0), sand)
			mauer.rotation.y = -a
	RaumBau.zyl(n, 0.24, 0.8, Vector3(0, 0.7, 0), sand, 10, 0.26)
	RaumBau.zyl(n, 0.02, 0.35, Vector3(0, 1.27, 0), sand, 10, 0.27)
	RaumBau.zyl(n, 0.01, 0.4, Vector3(0, 1.6, 0), weiss, 4)
	RaumBau.box(n, Vector3(0.01, 0.12, 0.2), Vector3(0, 1.72, 0.1), Bau.matt(["e2483e", "35c8ff", "ffc531"][rng.randi() % 3], 0.6))
	# Eimer + Schaufel daneben
	var farbe := Bau.matt(["e2483e", "35c8ff", "ffc531", "3fc29a"][rng.randi() % 4], 0.45)
	RaumBau.zyl(n, 0.15, 0.24, Vector3(1.15, 0.12, 0.2), farbe, 12, 0.11)
	var sch := RaumBau.box(n, Vector3(0.12, 0.02, 0.4), Vector3(1.1, 0.03, -0.5), farbe)
	sch.rotation.y = 0.6
	_fest(Rect2(p - Vector2(0.9, 0.9), Vector2(1.8, 1.8)))

# ---------------------------------------------------------------- Strandball (bunte Segmente)
static var _ball_mesh: ArrayMesh
func _strandball(eltern: Node3D, p: Vector2, gross := false) -> void:
	if _ball_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var farben := [Color("e2483e"), Color("f6f6f2"), Color("35c8ff"), Color("f6f6f2"), Color("ffc531"), Color("f6f6f2")]
		var ringe := 10
		var seg := 18
		var r := 0.3
		for i in ringe:
			for j in seg:
				var pts := []
				for e in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
					var th := PI * float(e[0]) / ringe
					var ph := TAU * float(e[1]) / seg
					pts.append(Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)) * r)
				var c: Color = Color("f6f6f2") if i == 0 or i == ringe - 1 else farben[j * 6 / seg]
				for tri in [[pts[0], pts[1], pts[2]], [pts[0], pts[2], pts[3]]]:
					var nrm := ((tri[0] + tri[1] + tri[2]) as Vector3).normalized()
					var ecken: Array = tri if ((tri[2] - tri[0]) as Vector3).cross(tri[1] - tri[0]).dot(nrm) > 0.0 else [tri[0], tri[2], tri[1]]
					for v in ecken:
						st.set_color(c)
						st.set_normal((v as Vector3).normalized())
						st.add_vertex(v)
		_ball_mesh = st.commit()
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.35
		_ball_mesh.surface_set_material(0, m)
	var mi := MeshInstance3D.new()
	mi.mesh = _ball_mesh
	var s := 1.0 if gross else rng.randf_range(0.8, 1.1)
	mi.scale = Vector3.ONE * s
	mi.position = Vector3(p.x, _sy(p.x) + 0.29 * s, p.y)
	mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
	add_child(mi)

# ---------------------------------------------------------------- Surfbrett (steckt im Sand)
func _surfbrett(eltern: Node3D, p: Vector2, neigung: float, farbe: String) -> void:
	var n := Node3D.new()
	n.position = Vector3(p.x, _sy(p.x) - 0.3, p.y)
	n.rotation = Vector3(0, rng.randf_range(-0.3, 0.3), neigung)
	eltern.add_child(n)
	var b := Andenken._kugel_mesh(n, 0.5, Vector3(0, 1.1, 0), Bau.matt(farbe, 0.3), 12)
	b.scale = Vector3(0.55, 2.2, 0.08)
	RaumBau.box(n, Vector3(0.06, 1.9, 0.09), Vector3(0, 1.1, 0), weiss)
	_fest(Rect2(p - Vector2(0.35, 0.35), Vector2(0.7, 0.7)))

# ---------------------------------------------------------------- Handtuch, Kühlbox
func _handtuch(eltern: Node3D, p: Vector2, dreh: float) -> void:
	var n := Node3D.new()
	n.position = Vector3(p.x, _sy(p.x) + 0.012, p.y)
	n.rotation = Vector3(0, dreh, atan(Kueste.NEIGUNG))
	eltern.add_child(n)
	var paare := [["e2483e", "f6f6f2"], ["35c8ff", "f6f6f2"], ["ffc531", "ff7a3a"], ["3fc29a", "f4f1ea"], ["b36bff", "ff9ad5"]]
	var paar: Array = paare[rng.randi() % paare.size()]
	for i in 6:
		RaumBau.box(n, Vector3(0.9, 0.015, 0.3), Vector3(0, 0, -0.75 + i * 0.3), Bau.matt(paar[i % 2], 0.9))

func _kuehlbox(eltern: Node3D, p: Vector2, dreh: float) -> void:
	var n := Node3D.new()
	n.position = Vector3(p.x, _sy(p.x), p.y)
	n.rotation.y = dreh
	eltern.add_child(n)
	RaumBau.box(n, Vector3(0.55, 0.34, 0.36), Vector3(0, 0.17, 0), Bau.matt(["2f6fb0", "e2483e", "3fc29a"][rng.randi() % 3], 0.5))
	RaumBau.box(n, Vector3(0.58, 0.07, 0.39), Vector3(0, 0.37, 0), weiss)
	RaumBau.box(n, Vector3(0.3, 0.04, 0.04), Vector3(0, 0.43, 0), Bau.matt("2b2d33", 0.5))
	_fest(Rect2(p - Vector2(0.35, 0.35), Vector2(0.7, 0.7)))

# Kenney-Modell aus modelle/strand: Maßstab s, Drehung, fest = Kollision; y = Höhe (sonst Sand)
func _modell(eltern: Node3D, name: String, p: Vector2, s: float, dreh: float, fest: bool, y := INF) -> void:
	var hy := _sy(p.x) - 0.02 if y == INF else y
	var n := RaumBau.mittig(eltern, "strand/" + name, Vector3(p.x, hy, p.y), s, dreh)
	if fest:
		var b := RaumBau.aabb(n)
		var halb := maxf(b.size.x, b.size.z) * 0.45
		_fest(Rect2(p - Vector2(halb, halb), Vector2(halb * 2.0, halb * 2.0)))

# ---------------------------------------------------------------- Bojen-Kette der Badezone
func _bojen() -> void:
	var xf := []
	var farben := []
	var x0 := Kueste.WASSER_X - 55.0
	var z := -178.0
	var i := 0
	while z <= 262.0:
		xf.append(Transform3D(Basis.IDENTITY, Vector3(x0, Kueste.MEER_Y + 0.05, z)))
		farben.append(Color("e2483e") if i % 2 == 0 else Color("f6f6f2"))
		z += 8.0
		i += 1
	for zz in [-178.0, 262.0]:   # Enden zum Ufer
		var x := x0 + 8.0
		while x < Kueste.WASSER_X - 4.0:
			xf.append(Transform3D(Basis.IDENTITY, Vector3(x, Kueste.MEER_Y + 0.05, zz)))
			farben.append(Color("ffc531"))
			x += 8.0
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.6
	sm.radial_segments = 12
	sm.rings = 6
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.4
	sm.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sm
	mm.instance_count = xf.size()
	for j in xf.size():
		mm.set_instance_transform(j, xf[j])
		mm.set_instance_color(j, farben[j])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	add_child(mi)
	# Leine zwischen den Bojen
	var leine := RaumBau.box(self, Vector3(0.04, 0.04, 440.0), Vector3(x0, Kueste.MEER_Y + 0.02, 42.0), Bau.matt("ffc531", 0.6))
	leine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------------------------------------------------------------- Muscheln + Seesterne (MultiMesh)
func _muscheln() -> void:
	var stern := SurfaceTool.new()
	stern.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		var r := 0.13 if i % 2 == 0 else 0.05
		pts.append(Vector2(cos(a), sin(a)) * r)
	for i in 10:
		var a := pts[i]
		var b := pts[(i + 1) % 10]
		for tri in [[Vector3(0, 0.025, 0), Vector3(b.x, 0.0, b.y), Vector3(a.x, 0.0, a.y)]]:
			var nrm := ((tri[1] - tri[0]) as Vector3).cross(tri[2] - tri[0]).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			var ecken: Array = tri if ((tri[2] - tri[0]) as Vector3).cross(tri[1] - tri[0]).dot(nrm) > 0.0 else [tri[0], tri[2], tri[1]]
			for v in ecken:
				stern.set_normal(nrm)
				stern.add_vertex(v)
	var stern_mesh := stern.commit()
	var muschel := SphereMesh.new()
	muschel.radius = 0.06
	muschel.height = 0.06
	muschel.is_hemisphere = true
	muschel.radial_segments = 10
	muschel.rings = 3
	for art in 2:
		var xf := []
		var farben := []
		for i in (60 if art == 0 else 140):
			var x := rng.randf_range(Kueste.WASSER_X + 0.5, Kueste.WASSER_X + 9.0)
			var z := rng.randf_range(-188.0, 265.0)
			var p := Vector2(x, z)
			if absf(z - Kueste.BOUL_Z) < Kueste.KANAL_HALB + 1.5:
				continue
			var s := rng.randf_range(0.8, 1.6) if art == 0 else rng.randf_range(0.7, 1.4)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * (1.0 if art == 0 else 0.5), s * (1.0 if art == 0 else 0.8)))
			xf.append(Transform3D(b, Vector3(p.x, _sy(p.x) + 0.005, p.y)))
			farben.append([Color("ff7a3a"), Color("e2483e"), Color("b36bff"), Color("ffb03a")][rng.randi() % 4] if art == 0 else [Color("f6efe4"), Color("ffd9c8"), Color("e8d8c0"), Color("f2c2d0")][rng.randi() % 4])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = stern_mesh if art == 0 else muschel
		mm.instance_count = xf.size()
		for j in xf.size():
			mm.set_instance_transform(j, xf[j])
			mm.set_instance_color(j, farben[j])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.6
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 160.0
		add_child(mi)

# ---------------------------------------------------------------- Krabben (laufen seitwärts hin und her)
static func krabbe() -> Node3D:
	var n := Node3D.new()
	var panzer := Bau.matt("e0562c", 0.5)
	var b := Andenken._kugel_mesh(n, 0.12, Vector3(0, 0.1, 0), panzer, 10)
	b.scale = Vector3(1.4, 0.55, 1.0)
	for s in [-1.0, 1.0]:
		for i in 3:   # Beine
			var bein := RaumBau.box(n, Vector3(0.16, 0.02, 0.02), Vector3(s * 0.18, 0.06, -0.06 + i * 0.06), panzer)
			bein.rotation.z = s * 0.6
		var arm := RaumBau.box(n, Vector3(0.1, 0.03, 0.03), Vector3(s * 0.1, 0.1, -0.15), panzer)
		arm.rotation.y = s * 0.6
		var schere := Andenken._kugel_mesh(n, 0.045, Vector3(s * 0.15, 0.12, -0.22), panzer, 8)
		schere.scale = Vector3(1.0, 0.7, 1.4)
		RaumBau.zyl(n, 0.008, 0.06, Vector3(s * 0.04, 0.17, -0.1), panzer, 4)
		Andenken._kugel_mesh(n, 0.015, Vector3(s * 0.04, 0.205, -0.1), Bau.matt("111111", 0.2), 6)
	n.scale = Vector3.ONE * 1.5
	return n

func _krabben_bauen() -> void:
	for i in 10:
		var z := rng.randf_range(-185.0, 255.0)
		if absf(z - Kueste.BOUL_Z) < 6.0:
			continue
		var n := krabbe()
		add_child(n)
		var a := Vector2(Kueste.WASSER_X + rng.randf_range(1.0, 5.0), z)
		var b := a + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(2.0, 5.0) * (1.0 if rng.randf() < 0.5 else -1.0))
		_krabben.append({"knoten": n, "a": a, "b": b, "t": rng.randf(), "tempo": rng.randf_range(0.05, 0.12)})

# ---------------------------------------------------------------- Möwen (stehend + kreisend, Flügelschlag)
static func moewe(fliegt: bool) -> Array:
	var n := Node3D.new()
	var weiss_m := Bau.matt("f4f4f2", 0.6)
	var grau := Bau.matt("9aa5b1", 0.6)
	var schwarz := Bau.matt("22262c", 0.6)
	var gelb := Bau.matt("ffc531", 0.5)
	var k1 := Andenken._kugel_mesh(n, 0.16, Vector3(0, 0, 0), weiss_m, 8)
	k1.scale = Vector3(0.75, 0.75, 1.7)
	Andenken._kugel_mesh(n, 0.09, Vector3(0, 0.1, -0.24), weiss_m, 8)
	var schnabel := RaumBau.zyl(n, 0.002, 0.09, Vector3(0, 0.09, -0.35), gelb, 5, 0.022)
	schnabel.rotation.x = -PI * 0.5
	var schwanz := RaumBau.box(n, Vector3(0.12, 0.03, 0.12), Vector3(0, 0.02, 0.27), grau)
	schwanz.rotation.x = 0.2
	var fluegel := []
	for s in [-1.0, 1.0]:
		var gelenk := Node3D.new()
		gelenk.position = Vector3(s * 0.08, 0.06, -0.02)
		n.add_child(gelenk)
		var f := RaumBau.box(gelenk, Vector3(0.48, 0.02, 0.2) if fliegt else Vector3(0.05, 0.12, 0.34), Vector3(s * 0.24, 0, 0.02) if fliegt else Vector3(0, 0, 0.04), grau)
		if fliegt:
			RaumBau.box(gelenk, Vector3(0.14, 0.021, 0.16), Vector3(s * 0.48, 0, 0.04), schwarz)
		else:
			RaumBau.box(gelenk, Vector3(0.05, 0.08, 0.1), Vector3(0, -0.01, 0.24), schwarz)
		fluegel.append(gelenk)
	if not fliegt:
		for s in [-1.0, 1.0]:
			RaumBau.zyl(n, 0.012, 0.18, Vector3(s * 0.05, -0.18, 0.02), gelb, 4)
	n.scale = Vector3.ONE * 1.6
	return [n, fluegel]

func _moewen_bauen() -> void:
	# stehend: am Strand, auf dem Steg-Geländer, auf dem Dach des Rettungsturms
	var orte := [Vector3(-639.0, 0.0, -100.0), Vector3(-642.0, 0.0, 40.0), Vector3(-644.0, 0.0, 41.2), Vector3(-638.0, 0.0, 130.0),
		Vector3(-730.0, 1.48, Kueste.STEG_Z + Kueste.STEG_HALB), Vector3(-752.0, 1.48, Kueste.STEG_Z - Kueste.STEG_HALB), Vector3(-640.5, 4.95, -140.0)]
	for o in orte:
		var m: Array = moewe(false)
		var y: float = o.y if o.y > 0.0 else _sy(o.x) + 0.3
		if o.x == -640.5:
			y = _sy(o.x) + 4.95
		(m[0] as Node3D).position = Vector3(o.x, y, o.z)
		(m[0] as Node3D).rotation.y = rng.randf() * TAU
		add_child(m[0])
	# fliegend: kreisen über Strand, Steg und Meer
	for i in 12:
		var m: Array = moewe(true)
		add_child(m[0])
		var mitte := Vector2(rng.randf_range(-720.0, -630.0), rng.randf_range(-220.0, 220.0))
		_moewen.append({"knoten": m[0], "fluegel": m[1], "mitte": mitte, "r": rng.randf_range(12.0, 35.0), "hoehe": rng.randf_range(10.0, 28.0),
			"tempo": rng.randf_range(0.12, 0.3) * (1.0 if rng.randf() < 0.5 else -1.0), "phase": rng.randf() * TAU})

func _process(dt: float) -> void:
	_zeit += dt
	for m in _moewen:
		var a: float = float(m.phase) + _zeit * float(m.tempo)
		var r: float = m.r
		var c: Vector2 = m.mitte
		var p := c + Vector2(cos(a), sin(a)) * r
		var n: Node3D = m.knoten
		n.position = Vector3(p.x, float(m.hoehe) + sin(_zeit * 0.7 + float(m.phase)) * 1.5, p.y)
		var richtung := Vector2(-sin(a), cos(a)) * signf(float(m.tempo))
		n.rotation = Vector3(0, atan2(-richtung.x, -richtung.y), -0.35 * signf(float(m.tempo)))
		var schlag := sin(_zeit * 7.0 + float(m.phase)) * 0.5 if fmod(_zeit + float(m.phase), 6.0) < 2.5 else 0.08
		(m.fluegel[0] as Node3D).rotation.z = -schlag
		(m.fluegel[1] as Node3D).rotation.z = schlag
	for kr in _krabben:
		kr.t = float(kr.t) + dt * float(kr.tempo)
		var u := 0.5 - 0.5 * cos(float(kr.t) * TAU)
		var p: Vector2 = (kr.a as Vector2).lerp(kr.b, u)
		var n: Node3D = kr.knoten
		n.position = Vector3(p.x, Kueste.sand_y(p.x), p.y)
		var d: Vector2 = (kr.b as Vector2) - (kr.a as Vector2)
		n.rotation.y = atan2(-d.y, d.x)   # seitwärts laufen (lokale x-Achse in Laufrichtung)
		n.position.y += absf(sin(float(kr.t) * 60.0)) * 0.01
