class_name Andenken
# Modelle aus Code für Souvenirs (Souvenirshop) und Gold-Deko (Goldschmuck-Laden). Moebel.modell() ruft bauen() auf,
# wenn in Wirtschaft.GEGENSTAENDE das Modell mit "code:" beginnt. Maße in Metern, Unterkante auf y = 0.
# Kleine Souvenirs stehen auf einem weißen Ausstellungs-Sockel, damit man sie im Penthouse sieht.

const SOCKEL_H := 0.9

static func gold() -> StandardMaterial3D:
	return Bau.metall("e8b53a", 0.2, 0.95)

static func bauen(art: String) -> Node3D:
	var n := Node3D.new()
	match art:
		"postkarten": _postkarten(n)
		"schneekugel": _kugel(n, false)
		"wolkenkugel": _kugel(n, true)
		"taube": _taube(n)
		"nadel": _nadel(n, SOCKEL_H, 0.55, Bau.metall("b9c8d6", 0.25, 0.8), true)
		"wuerfel": _wuerfel(n)
		"fontaene": _fontaene(n)
		"gondel": _gondel(n)
		"sanduhr": _sanduhr(n)
		"schwamm": _schwamm(n)
		"rahmen": _rahmen(n)
		"kristall": _kristall(n)
		"barren": _barren(n)
		"leuchter": _leuchter(n)
		"statue": _statue(n)
		"goldnadel": _goldnadel(n)
		"globus": _globus(n)
		"brunnen": _brunnen(n)
		_: RaumBau.box(n, Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, 0), Bau.matt("c9d3dd"))
	return n

# Weißer Ausstellungs-Sockel mit dunkler Platte oben
static func _sockel(n: Node3D, h := SOCKEL_H) -> void:
	RaumBau.box(n, Vector3(0.42, h - 0.04, 0.42), Vector3(0, (h - 0.04) * 0.5, 0), Bau.matt("f1eee8", 0.35))
	RaumBau.box(n, Vector3(0.46, 0.04, 0.46), Vector3(0, h - 0.02, 0), Bau.matt("2b2f36", 0.3))

static func _kugel_mesh(n: Node3D, r: float, p: Vector3, m: Material, ringe := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = ringe * 2
	sm.rings = ringe
	mi.mesh = sm
	mi.material_override = m
	mi.position = p
	n.add_child(mi)
	return mi

# ---------------------------------------------------------------- Souvenirs
static func _postkarten(n: Node3D) -> void:
	var stahl := Bau.metall("c9ced4", 0.3, 0.8)
	RaumBau.zyl(n, 0.22, 0.04, Vector3(0, 0.02, 0), stahl, 20)
	RaumBau.zyl(n, 0.025, 1.55, Vector3(0, 0.8, 0), stahl, 8)
	var farben := ["35c8ff", "ff9ad5", "ffc531", "7fe08a", "e2483e", "b36bff", "f4f4f4", "3a86d4"]
	for stufe in 3:
		var y := 0.75 + stufe * 0.3
		for k in 6:
			var a := k * TAU / 6.0 + stufe * 0.4
			var karte := RaumBau.box(n, Vector3(0.15, 0.1, 0.008), Vector3(sin(a) * 0.12, y, cos(a) * 0.12), Bau.matt(farben[(k + stufe * 3) % farben.size()], 0.6))
			karte.rotation.y = a
			karte.rotation.x = -0.15

static func _mini_turm(n: Node3D, y0: float, h: float, m: Material) -> void:
	# drei schmaler werdende Stufen + Spitze (erinnert an die Wüstennadel)
	var r := h * 0.16
	var y := y0
	for k in 4:
		var sh: float = h * [0.34, 0.26, 0.18, 0.1][k]
		RaumBau.zyl(n, r * (0.8 - k * 0.17), sh, Vector3(0, y + sh * 0.5, 0), m, 12, r * (1.0 - k * 0.17))
		y += sh
	RaumBau.zyl(n, 0.002, h * 0.12, Vector3(0, y + h * 0.06, 0), m, 6, r * 0.2)

static func _kugel(n: Node3D, wolken: bool) -> void:
	_sockel(n)
	var y := SOCKEL_H
	RaumBau.zyl(n, 0.15, 0.08, Vector3(0, y + 0.04, 0), Bau.matt("6b3f22" if not wolken else "2b2f36", 0.5), 20, 0.17)
	_mini_turm(n, y + 0.08, 0.26 if not wolken else 0.3, Bau.metall("c9d6e2", 0.25, 0.8))
	if wolken:
		for k in 6:
			var a := k * TAU / 6.0
			_kugel_mesh(n, 0.05, Vector3(sin(a) * 0.08, y + 0.17, cos(a) * 0.08), Bau.matt("ffffff", 0.9), 6)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for k in 14:
			var p := Vector3(rng.randf_range(-0.1, 0.1), y + 0.09 + rng.randf() * 0.2, rng.randf_range(-0.1, 0.1))
			RaumBau.box(n, Vector3.ONE * 0.012, p, RaumBau.leuchte("ffffff", 0.6))
	_kugel_mesh(n, 0.16, Vector3(0, y + 0.22, 0), RaumBau.glas("d8eeff" if not wolken else "bfe0ff", 0.18), 16)

static func _taube(n: Node3D) -> void:
	_sockel(n)
	var y := SOCKEL_H
	var por := Bau.matt("f4f2ee", 0.2)
	var k := _kugel_mesh(n, 0.1, Vector3(0, y + 0.1, 0), por)
	k.scale = Vector3(0.75, 0.8, 1.25)
	_kugel_mesh(n, 0.055, Vector3(0, y + 0.2, -0.1), por)
	var schnabel := RaumBau.zyl(n, 0.0, 0.05, Vector3(0, y + 0.19, -0.165), Bau.matt("e8b53a", 0.4), 8, 0.012)
	schnabel.rotation.x = -PI / 2.0
	var schwanz := RaumBau.box(n, Vector3(0.1, 0.02, 0.12), Vector3(0, y + 0.12, 0.15), por)
	schwanz.rotation.x = -0.4
	for s in [-1.0, 1.0]:
		RaumBau.box(n, Vector3.ONE * 0.018, Vector3(s * 0.028, y + 0.215, -0.14), Bau.matt("1b1e2a", 0.3))
		var fluegel := RaumBau.box(n, Vector3(0.02, 0.08, 0.17), Vector3(s * 0.075, y + 0.11, 0.02), Bau.matt("dfe6ee", 0.25))
		fluegel.rotation.z = s * 0.2

static func _nadel(n: Node3D, y: float, h: float, m: Material, mit_sockel: bool) -> void:
	if mit_sockel:
		_sockel(n)
	RaumBau.box(n, Vector3(0.2, 0.03, 0.2), Vector3(0, y + 0.015, 0), Bau.matt("d9cfbd", 0.6))
	_mini_turm(n, y + 0.03, h, m)

static func _wuerfel(n: Node3D) -> void:
	_sockel(n)
	var rot := Bau.matt("c8102e", 0.25)
	var weiss := Bau.matt("ffffff", 0.3)
	for i in 2:
		var w := Node3D.new()
		w.position = Vector3(-0.07 + i * 0.13, SOCKEL_H + 0.06, 0.02 - i * 0.05)
		w.rotation.y = 0.3 + i * 0.7
		n.add_child(w)
		RaumBau.box(w, Vector3.ONE * 0.12, Vector3.ZERO, rot)
		# Augen: oben 5, vorne 3, rechts 2
		for p in [Vector2(0, 0), Vector2(-0.03, -0.03), Vector2(0.03, 0.03), Vector2(-0.03, 0.03), Vector2(0.03, -0.03)]:
			RaumBau.box(w, Vector3(0.018, 0.004, 0.018), Vector3(p.x, 0.06, p.y), weiss)
		for p in [Vector2(-0.03, 0.03), Vector2(0, 0), Vector2(0.03, -0.03)]:
			RaumBau.box(w, Vector3(0.018, 0.018, 0.004), Vector3(p.x, p.y, 0.06), weiss)
		for p in [Vector2(-0.03, 0.03), Vector2(0.03, -0.03)]:
			RaumBau.box(w, Vector3(0.004, 0.018, 0.018), Vector3(0.06, p.y, p.x), weiss)

static func _wasser(kraft := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.85, 1.0, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color("6fd0ff")
	m.emission_energy_multiplier = kraft
	m.roughness = 0.05
	return m

static func _fontaene(n: Node3D) -> void:
	_sockel(n)
	var y := SOCKEL_H
	RaumBau.zyl(n, 0.2, 0.05, Vector3(0, y + 0.025, 0), Bau.matt("d9cfbd", 0.5), 24)
	RaumBau.zyl(n, 0.18, 0.012, Vector3(0, y + 0.052, 0), _wasser(), 24)
	var strahl := _wasser(1.0)
	RaumBau.zyl(n, 0.006, 0.32, Vector3(0, y + 0.21, 0), strahl, 6, 0.012)
	for k in 6:
		var a := k * TAU / 6.0
		var s := RaumBau.zyl(n, 0.004, 0.14, Vector3(sin(a) * 0.07, y + 0.11, cos(a) * 0.07), strahl, 6, 0.008)
		s.rotation = Vector3(cos(a) * 0.35, 0, -sin(a) * 0.35)

static func _gondel(n: Node3D) -> void:
	_sockel(n)
	var y := SOCKEL_H
	var stahl := Bau.metall("9aa3ad", 0.3, 0.8)
	for s in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(0.012, 0.42, 0.012), Vector3(s * 0.15, y + 0.21, 0), stahl)
	RaumBau.box(n, Vector3(0.34, 0.012, 0.012), Vector3(0, y + 0.42, 0), stahl)
	var g := Node3D.new()
	g.position = Vector3(0, y + 0.14, 0)
	g.scale = Vector3.ONE * 0.065
	n.add_child(g)
	GondelDeko.rumpf(g, Bau.matt("ffc531", 0.5), stahl, false)
	for s in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(0.004, 0.2, 0.004), Vector3(s * 0.11, y + 0.3, 0), stahl)

static func _sanduhr(n: Node3D) -> void:
	_sockel(n)
	var y := SOCKEL_H
	var holz := Bau.matt("6b3f22", 0.5)
	RaumBau.zyl(n, 0.09, 0.025, Vector3(0, y + 0.0125, 0), holz, 16)
	RaumBau.zyl(n, 0.09, 0.025, Vector3(0, y + 0.3, 0), holz, 16)
	for s in [-1.0, 1.0]:
		RaumBau.zyl(n, 0.008, 0.28, Vector3(s * 0.075, y + 0.155, 0), holz, 6)
	var glas := RaumBau.glas("e8f4ff", 0.22)
	RaumBau.zyl(n, 0.012, 0.13, Vector3(0, y + 0.09, 0), glas, 14, 0.06)
	RaumBau.zyl(n, 0.06, 0.13, Vector3(0, y + 0.22, 0), glas, 14, 0.012)
	var sand := Bau.matt("d9a85a", 0.9)
	RaumBau.zyl(n, 0.0, 0.05, Vector3(0, y + 0.05, 0), sand, 12, 0.055)
	RaumBau.zyl(n, 0.035, 0.04, Vector3(0, y + 0.19, 0), sand, 12, 0.008)

static func _schwamm(n: Node3D) -> void:
	_sockel(n)
	RaumBau.box(n, Vector3(0.3, 0.05, 0.22), Vector3(0, SOCKEL_H + 0.025, 0), Bau.matt("8a1020", 0.85))
	var s := Spieler.werkzeug_modell(Wirtschaft.WERKZEUGE[0])
	s.position = Vector3(0, SOCKEL_H + 0.1, 0)
	s.rotation = Vector3(-PI / 2.0, 0.4, 0)
	s.scale = Vector3.ONE * 1.4
	n.add_child(s)
	RaumBau.faerben(s, gold())

static func _rahmen(n: Node3D) -> void:
	var holz := Bau.matt("4a2c18", 0.5)
	# Staffelei mit Rahmen voller Szenen-Bilder
	for s in [-1.0, 1.0]:
		var bein := RaumBau.box(n, Vector3(0.04, 1.6, 0.04), Vector3(s * 0.32, 0.78, 0), holz)
		bein.rotation.z = s * -0.1
	var hinten := RaumBau.box(n, Vector3(0.04, 1.5, 0.04), Vector3(0, 0.72, 0.3), holz)
	hinten.rotation.x = -0.35
	var r := Node3D.new()
	r.position = Vector3(0, 1.05, -0.03)
	r.rotation.x = 0.12
	n.add_child(r)
	RaumBau.box(r, Vector3(0.86, 0.66, 0.04), Vector3.ZERO, gold())
	RaumBau.box(r, Vector3(0.76, 0.56, 0.02), Vector3(0, 0, -0.016), Bau.matt("f4f2ee", 0.6))
	var farben := ["ff9ad5", "ffc531", "35c8ff", "7fe08a", "b36bff", "e2483e", "3a86d4", "ff8a1e", "3fc29a", "c8925a"]
	for i in 10:
		var x := -0.28 + (i % 5) * 0.14
		var y := 0.12 - (i / 5) * 0.24
		RaumBau.box(r, Vector3(0.11, 0.18, 0.01), Vector3(x, y, -0.03), Bau.matt(farben[i], 0.6))
	RaumBau.box(n, Vector3(0.7, 0.04, 0.08), Vector3(0, 0.7, -0.06), holz)

static func _kristall(n: Node3D) -> void:
	_sockel(n)
	var kristall := StandardMaterial3D.new()
	kristall.albedo_color = Color(0.75, 0.9, 1.0, 0.55)
	kristall.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	kristall.metallic = 0.3
	kristall.roughness = 0.02
	kristall.emission_enabled = true
	kristall.emission = Color("9fdcff")
	kristall.emission_energy_multiplier = 0.6
	_nadel(n, SOCKEL_H, 0.75, kristall, false)

# ---------------------------------------------------------------- Gold-Deko
static func _marmor_sockel(n: Node3D, b: float, h: float) -> void:
	RaumBau.box(n, Vector3(b, h, b), Vector3(0, h * 0.5, 0), Bau.matt("f1eee8", 0.2))
	RaumBau.box(n, Vector3(b + 0.06, 0.05, b + 0.06), Vector3(0, h, 0), gold())
	RaumBau.box(n, Vector3(b + 0.06, 0.05, b + 0.06), Vector3(0, 0.025, 0), gold())

static func _barren(n: Node3D) -> void:
	RaumBau.box(n, Vector3(0.95, 0.12, 0.62), Vector3(0, 0.06, 0), Bau.matt("1b1e2a", 0.25))
	var g := gold()
	var lagen := [[4, 0.0], [3, 0.0], [2, 0.0], [1, 0.0]]
	for l in lagen.size():
		var anzahl: int = lagen[l][0]
		for i in anzahl:
			for reihe in (2 if l < 2 else 1):
				var x := (i - (anzahl - 1) * 0.5) * 0.2
				var z := (reihe - (0.5 if l < 2 else 0.0)) * 0.26
				var b := RaumBau.zyl(n, 0.06, 0.08, Vector3(x, 0.16 + l * 0.08, z), g, 4, 0.085)
				b.rotation.y = PI / 4.0
				b.scale = Vector3(1.0, 1.0, 1.9)

static func _leuchter(n: Node3D) -> void:
	var g := gold()
	RaumBau.zyl(n, 0.32, 0.06, Vector3(0, 0.03, 0), g, 24, 0.38)
	RaumBau.zyl(n, 0.04, 1.9, Vector3(0, 1.0, 0), g, 12, 0.06)
	var flamme := RaumBau.leuchte("ffd27a", 4.0)
	var kristall := RaumBau.glas("ffffff", 0.35)
	for stufe in 3:
		var y := 1.2 + stufe * 0.32
		var r := 0.5 - stufe * 0.14
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.025
		tm.outer_radius = r
		ring.mesh = tm
		ring.material_override = g
		ring.position = Vector3(0, y, 0)
		n.add_child(ring)
		var anzahl := 8 - stufe * 2
		for k in anzahl:
			var a := k * TAU / anzahl + stufe * 0.3
			var p := Vector3(sin(a) * r, y, cos(a) * r)
			RaumBau.zyl(n, 0.02, 0.12, p + Vector3(0, 0.07, 0), Bau.matt("f6f1e4", 0.6), 8)
			_kugel_mesh(n, 0.02, p + Vector3(0, 0.15, 0), flamme, 6)
			RaumBau.box(n, Vector3(0.025, 0.07, 0.025), p - Vector3(0, 0.07, 0), kristall)
	_kugel_mesh(n, 0.07, Vector3(0, 2.0, 0), g, 10)

static func _statue(n: Node3D) -> void:
	_marmor_sockel(n, 0.7, 0.55)
	var pfad := "res://modelle/leute/character-worker.glb"
	var figur: Node3D
	if ResourceLoader.exists(pfad):
		figur = load(pfad).instantiate()
	else:
		figur = Node3D.new()
		RaumBau.zyl(figur, 0.2, 0.8, Vector3(0, 0.4, 0), Bau.matt("ffffff"), 12)
	figur.position = Vector3(0, 0.6, 0)
	figur.rotation.y = PI
	figur.scale = Vector3.ONE * 2.0
	n.add_child(figur)
	RaumBau.faerben(figur, gold())
	var abzieher := Spieler.werkzeug_modell(Wirtschaft.WERKZEUGE[2])
	abzieher.position = Vector3(0.32, 1.55, -0.1)
	abzieher.rotation = Vector3(0, 0, 0.5)
	n.add_child(abzieher)
	RaumBau.faerben(abzieher, gold())

static func _goldnadel(n: Node3D) -> void:
	_marmor_sockel(n, 0.6, 0.3)
	_mini_turm(n, 0.35, 1.9, gold())

static func _globus(n: Node3D) -> void:
	var g := gold()
	RaumBau.zyl(n, 0.28, 0.06, Vector3(0, 0.03, 0), Bau.matt("1b1e2a", 0.25), 24, 0.32)
	RaumBau.zyl(n, 0.04, 0.7, Vector3(0, 0.4, 0), g, 10, 0.07)
	var achse := Node3D.new()
	achse.position = Vector3(0, 1.2, 0)
	achse.rotation.z = 0.41
	n.add_child(achse)
	_kugel_mesh(achse, 0.42, Vector3.ZERO, g, 20)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.47
	tm.outer_radius = 0.5
	ring.mesh = tm
	ring.material_override = g
	ring.rotation.x = PI / 2.0
	achse.add_child(ring)
	# „Kontinente“ als leicht erhabene, hellere Flecken
	var hell := Bau.metall("f6d77a", 0.35, 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 12:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 0.7), rng.randf_range(-1, 1)).normalized()
		var f := _kugel_mesh(achse, 0.1 + rng.randf() * 0.06, d * 0.36, hell, 8)
		f.basis = Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT) * Basis.from_scale(Vector3(1, 1, 0.55))

static func _brunnen(n: Node3D) -> void:
	var g := gold()
	var wasser := _wasser(0.7)
	RaumBau.zyl(n, 0.9, 0.35, Vector3(0, 0.175, 0), g, 32, 0.95)
	RaumBau.zyl(n, 0.84, 0.02, Vector3(0, 0.33, 0), wasser, 32)
	RaumBau.zyl(n, 0.08, 0.7, Vector3(0, 0.6, 0), g, 12, 0.14)
	RaumBau.zyl(n, 0.48, 0.12, Vector3(0, 0.98, 0), g, 24, 0.3)
	RaumBau.zyl(n, 0.44, 0.02, Vector3(0, 1.03, 0), wasser, 24)
	RaumBau.zyl(n, 0.05, 0.4, Vector3(0, 1.22, 0), g, 10, 0.08)
	RaumBau.zyl(n, 0.24, 0.08, Vector3(0, 1.44, 0), g, 20, 0.14)
	RaumBau.zyl(n, 0.012, 0.3, Vector3(0, 1.62, 0), wasser, 6, 0.02)
	# Wasserschleier von der oberen Schale nach unten
	for k in 8:
		var a := k * TAU / 8.0
		RaumBau.zyl(n, 0.012, 0.6, Vector3(sin(a) * 0.46, 0.68, cos(a) * 0.46), wasser, 6, 0.02)
