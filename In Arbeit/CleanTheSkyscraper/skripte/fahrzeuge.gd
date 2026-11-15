class_name Fahrzeuge
# Modelle der Fahrzeuge am Boden (aus Code): E-Scooter, Hoverboard, Jetpack.
# Vorne ist −Z (wie die Blickrichtung des Läufers). Ursprung = unter den Füßen.

static func modell(id: String) -> Node3D:
	var g := Node3D.new()
	match id:
		"scooter":
			var rot := Bau.matt("e2483e", 0.45)
			var schwarz := Bau.matt("1f2126", 0.7)
			_box(g, Vector3(0.18, 0.05, 0.95), Vector3(0, 0.12, 0.05), schwarz)          # Trittbrett
			for z in [-0.42, 0.5]:
				var rad := Bau.zylinder(0.1, 0.1, 0.06, schwarz, 14)
				rad.rotation.z = PI / 2.0
				rad.position = Vector3(0, 0.1, z)
				g.add_child(rad)
			var stange := Bau.zylinder(0.025, 0.03, 1.05, rot, 8)
			stange.position = Vector3(0, 0.62, -0.5)
			stange.rotation.x = -0.12
			g.add_child(stange)
			_box(g, Vector3(0.55, 0.04, 0.04), Vector3(0, 1.13, -0.56), schwarz)          # Lenker
			for x in [-0.25, 0.25]:
				_box(g, Vector3(0.1, 0.05, 0.05), Vector3(x, 1.13, -0.56), Bau.matt("444850", 0.8))
			var licht := _leuchte("fff2c0", 2.5)
			_box(g, Vector3(0.08, 0.05, 0.03), Vector3(0, 1.0, -0.6), licht)
		"hoverboard":
			var brett := Bau.matt("1d2b4a", 0.35)
			_box(g, Vector3(0.36, 0.07, 1.15), Vector3(0, 0.0, 0), brett)
			_box(g, Vector3(0.3, 0.02, 1.0), Vector3(0, 0.045, 0), Bau.matt("35c8ff", 0.4))   # Griptape-Streifen
			var glut := _leuchte("35c8ff", 3.0)
			_box(g, Vector3(0.3, 0.02, 1.05), Vector3(0, -0.045, 0), glut)                     # leuchtende Unterseite
			for z in [-0.42, 0.42]:
				var duese := Bau.zylinder(0.1, 0.07, 0.06, _leuchte("8fe8ff", 2.0), 12)
				duese.position = Vector3(0, -0.07, z)
				g.add_child(duese)
		"jetpack":
			var orange := Bau.matt("ffb03a", 0.4)
			for x in [-0.14, 0.14]:
				var tank := Bau.zylinder(0.11, 0.11, 0.6, orange, 12)
				tank.position = Vector3(x, 1.2, 0.28)
				g.add_child(tank)
				var flamme := Bau.zylinder(0.07, 0.0, 0.5, _leuchte("ff7a1a", 4.0), 10)
				flamme.position = Vector3(x, 0.65, 0.28)
				flamme.name = "flamme%d" % (0 if x < 0 else 1)
				g.add_child(flamme)
			_box(g, Vector3(0.3, 0.45, 0.08), Vector3(0, 1.25, 0.18), Bau.matt("3b3f46", 0.6))
	return g

static func _box(eltern: Node3D, groesse: Vector3, p: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = groesse
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	eltern.add_child(mi)

static func _leuchte(farbe: String, kraft: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(farbe)
	m.emission_enabled = true
	m.emission = Color(farbe)
	m.emission_energy_multiplier = kraft
	return m
