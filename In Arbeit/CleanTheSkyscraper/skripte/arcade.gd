class_name Arcade
extends Node3D
# Arcade-Halle im 1. Stock des Casino-Hochhauses (Aufzug im Casino): dunkler Raum mit Neon, zwei Greifautomaten,
# zwei Kapsel-Automaten und ein paar Deko-Automaten. Gewinne sind Gegenstände fürs Penthouse (Seltenheit 0–3).
# Greifautomat: Kamera vor die Scheibe, WASD/Pfeile bewegen die Kralle, Leertaste greift. Die Kralle trifft nur,
# wenn sie gut über einem Preis steht; seltene Preise rutschen öfter wieder heraus.

signal greif_ende(id: String)      # "" = nichts gewonnen

const HALB := Casino.HALB - Casino.WAND
const KASTEN := 0.56               # halbe Innenbreite des Greifautomaten (Kralle bewegt sich darin)
const BODEN_Y := 0.95              # Höhe des Preis-Bodens im Automaten
const OBEN_Y := 1.95               # Höhe der Kralle oben
const ZEIT := 20.0                 # Sekunden zum Zielen
const TEMPO := 0.45                # m/s der Kralle
const TREFFER_R := 0.13            # so nah muss die Kralle über der Mitte eines Preises sein
const RUTSCH := [0.12, 0.3, 0.5, 0.65]   # Chance, dass ein Preis beim Hochziehen wieder herausfällt

var mitte := Vector2.ZERO
var boden := 0.0
var decke := 0.0
var raum := {}
var stationen: Array = []
var innen: Node3D
var _leucht: Array = []
var automaten: Array = []          # Greifautomaten: {knoten, kralle, seil, finger, preise: [{id, knoten}], cam}
# laufendes Greifspiel
var spiel := -1                    # Index in automaten, -1 = keins
var phase := ""
var zeit := 0.0
var k_pos := Vector2.ZERO          # Kralle (lokal im Automaten, x/z)
var k_y := OBEN_Y
var gegriffen := -1                # Index in preise
var _rutsch_bei := -1.0            # Höhe, bei der der Preis herausrutscht (-1 = hält)
var _auf := 1.0                    # Finger offen (1) / zu (0)

func setup(grundstueck: Rect2) -> void:
	mitte = grundstueck.get_center()
	position = Vector3(mitte.x, 0, mitte.y)
	boden = Casino.HOCH + 0.3 + 0.04
	decke = Casino.HOCH + 0.3 + 3.5 - 0.15
	innen = Node3D.new()
	innen.visible = false
	add_child(innen)
	raum = {"poly": PackedVector2Array([_w(-HALB + 0.4, -HALB + 0.4), _w(HALB - 0.4, -HALB + 0.4), _w(HALB - 0.4, HALB - 0.4), _w(-HALB + 0.4, HALB - 0.4)]),
		"rechtecke": [], "kreise": [], "boden": boden}
	_raum()
	_aufzug()
	for i in 2:
		_greifautomat(Vector2(-6.5 + i * 3.4, -HALB + 1.2), i)
	for i in 2:
		_kapselautomat(Vector2(-6.5 + i * 3.4, HALB - 1.0))
	_deko()

func _w(x: float, z: float) -> Vector2:
	return mitte + Vector2(x, z)

func _fest(x0: float, z0: float, x1: float, z1: float) -> void:
	raum.rechtecke.append(Rect2(_w(x0, z0), Vector2(x1 - x0, z1 - z0)))

func ankunft() -> Vector2:
	return _w(7.6, 0.0)

func _process(dt: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in _leucht.size():
		(_leucht[i] as StandardMaterial3D).emission_energy_multiplier = 2.0 + sin(t * 2.5 + i * 1.7) * 0.9
	if spiel >= 0:
		_greif_takt(dt)

# ---------------------------------------------------------------- Raum
func _teppich() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var farben := [Color("ff3fa0"), Color("35c8ff"), Color("ffc531"), Color("7fe08a")]
	for y in n:
		for x in n:
			img.set_pixel(x, y, Color("141529"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 28:   # bunte Kringel und Dreiecke wie in einer Spielhalle
		var c: Color = farben[k % 4]
		var m := Vector2(rng.randi() % n, rng.randi() % n)
		var r := 2.0 + rng.randf() * 3.0
		for y in n:
			for x in n:
				var d := Vector2(x, y) - m
				d = Vector2(wrapf(d.x, -n * 0.5, n * 0.5), wrapf(d.y, -n * 0.5, n * 0.5))
				if absf(d.length() - r) < 0.7 if k % 2 == 0 else (absf(d.x) + absf(d.y) < r * 0.8):
					img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _raum() -> void:
	var h := HALB
	var poly := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = _teppich()
	tm.roughness = 1.0
	RaumBau.flaeche(innen, poly, boden, tm, true, 0.18)
	RaumBau.flaeche(innen, poly, decke, Bau.matt("0d0e18", 0.9), false)
	RaumBau.waende(innen, PackedVector2Array([Vector2(-h, -h), Vector2(-h, h), Vector2(h, h), Vector2(h, -h)]), boden, decke, Bau.matt("161828", 0.7))
	var farben := ["ff3fa0", "35c8ff", "ffc531", "b36bff"]
	for s in 4:   # Neon-Streifen an den Wänden (nicht hinter dem Schild)
		if s == 2:
			continue
		var lm := RaumBau.leuchte(farben[s], 2.2)
		_leucht.append(lm)
		var y := boden + 2.6
		match s:
			0: RaumBau.box(innen, Vector3(2.0 * h, 0.06, 0.06), Vector3(0, y, -h + 0.05), lm)
			1: RaumBau.box(innen, Vector3(2.0 * h, 0.06, 0.06), Vector3(0, y, h - 0.05), lm)
			2: RaumBau.box(innen, Vector3(0.06, 0.06, 2.0 * h), Vector3(-h + 0.05, y, 0), lm)
			3: RaumBau.box(innen, Vector3(0.06, 0.06, 2.0 * h), Vector3(h - 0.05, y, 0), lm)
	for i in 5:   # Neonröhren an der Decke
		var lm2 := RaumBau.leuchte(farben[i % 4], 1.8)
		_leucht.append(lm2)
		RaumBau.box(innen, Vector3(0.08, 0.05, 2.0 * h - 3.0), Vector3(-9.0 + i * 4.5, decke - 0.04, 0), lm2)
	for ix in 3:
		for iz in 2:
			RaumBau.licht(innen, Vector3(-8.0 + ix * 8.0, decke - 0.5, -5.5 + iz * 11.0), ["ff6fc0", "6fd8ff", "ffd87a"][ix], 1.1, 11.0)
	var schild := RaumBau.schrift(innen, "ARCADE", Vector3(-h + 0.08, boden + 2.6, 0), PI * 0.5, 200, 0.0042, Color("ff3fa0"))
	schild.modulate = Color(2.0, 0.6, 1.4)

func _aufzug() -> void:
	var stahl := Bau.metall("c9ced4", 0.25, 0.85)
	RaumBau.box(innen, Vector3(3.2, decke - boden, 3.2), Vector3(11.0, (boden + decke) * 0.5, 0), Bau.matt("20222c", 0.5))
	for s in [-1.0, 1.0]:
		RaumBau.box(innen, Vector3(0.06, 2.6, 0.95), Vector3(9.38, boden + 1.3, s * 0.49), stahl)
	RaumBau.box(innen, Vector3(0.1, 0.1, 0.04), Vector3(9.36, boden + 1.3, 1.3), RaumBau.leuchte("ffcf6a", 2.5))
	_fest(9.4, -1.6, 12.6, 1.6)
	stationen.append({"art": "aufzug_casino", "name": "Aufzug", "hinweis": "E: Aufzug", "pos": _w(7.6, 0.0), "ziel": _w(9.4, 0.0)})

# ---------------------------------------------------------------- Greifautomat
func _greifautomat(p: Vector2, nr: int) -> void:
	var a := Node3D.new()
	a.position = Vector3(p.x, boden, p.y)
	innen.add_child(a)
	var farbe: String = ["ff3fa0", "35c8ff"][nr % 2]
	var korpus := Bau.matt(farbe, 0.4)
	var dunkel := Bau.matt("161828", 0.5)
	var b := KASTEN + 0.1
	RaumBau.box(a, Vector3(b * 2.0, BODEN_Y, b * 2.0), Vector3(0, BODEN_Y * 0.5, 0), korpus)
	RaumBau.box(a, Vector3(KASTEN * 2.0, 0.02, KASTEN * 2.0), Vector3(0, BODEN_Y + 0.01, 0), Bau.matt("2a1f3f", 0.9))
	var gl := RaumBau.glas("e8f4ff", 0.1)
	for s in [-1.0, 1.0]:
		RaumBau.box(a, Vector3(b * 2.0, OBEN_Y - BODEN_Y + 0.25, 0.02), Vector3(0, (BODEN_Y + OBEN_Y + 0.25) * 0.5, s * b), gl)
		RaumBau.box(a, Vector3(0.02, OBEN_Y - BODEN_Y + 0.25, b * 2.0), Vector3(s * b, (BODEN_Y + OBEN_Y + 0.25) * 0.5, 0), gl)
		for t in [-1.0, 1.0]:
			RaumBau.box(a, Vector3(0.06, OBEN_Y - BODEN_Y + 0.25, 0.06), Vector3(s * b, (BODEN_Y + OBEN_Y + 0.25) * 0.5, t * b), korpus)
	RaumBau.box(a, Vector3(b * 2.0 + 0.04, 0.4, b * 2.0 + 0.04), Vector3(0, OBEN_Y + 0.45, 0), korpus)
	var lm := RaumBau.leuchte("fff1d6", 2.4)
	_leucht.append(lm)
	RaumBau.box(a, Vector3(b * 2.0 - 0.1, 0.04, b * 2.0 - 0.1), Vector3(0, OBEN_Y + 0.23, 0), lm)
	var titel := RaumBau.schrift(a, "GREIFER", Vector3(0, OBEN_Y + 0.45, b + 0.03), 0.0, 90, 0.004, Color("ffffff"))
	titel.modulate = Color(1.6, 1.6, 1.6)
	# Auswurf-Schacht vorne links (Preise fallen hinein) + Klappe unten
	RaumBau.box(a, Vector3(0.34, 0.3, 0.34), Vector3(-KASTEN + 0.17, BODEN_Y + 0.15, KASTEN - 0.17), RaumBau.glas("ffffff", 0.3))
	RaumBau.box(a, Vector3(0.36, 0.3, 0.04), Vector3(-KASTEN + 0.17, 0.35, b + 0.01), dunkel)
	# Bedienpult mit Hebel und Knopf
	RaumBau.box(a, Vector3(b * 2.0, 0.1, 0.3), Vector3(0, BODEN_Y - 0.05, b + 0.15), korpus)
	RaumBau.zyl(a, 0.015, 0.18, Vector3(0.1, BODEN_Y + 0.09, b + 0.15), Bau.metall("c9ced4"), 8)
	var kugel := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	kugel.mesh = sm
	kugel.material_override = Bau.matt("e2483e", 0.3)
	kugel.position = Vector3(0.1, BODEN_Y + 0.2, b + 0.15)
	a.add_child(kugel)
	RaumBau.zyl(a, 0.045, 0.03, Vector3(0.32, BODEN_Y + 0.015, b + 0.15), RaumBau.leuchte("ffc531", 2.0), 14)
	# Kralle: Wagen oben, Seil, drei Finger
	var kralle := Node3D.new()
	a.add_child(kralle)
	var chrom := Bau.metall("d9dde2", 0.2, 0.95)
	RaumBau.box(kralle, Vector3(0.12, 0.06, 0.12), Vector3.ZERO, chrom)
	var seil := RaumBau.zyl(kralle, 0.006, 1.0, Vector3.ZERO, Bau.matt("2b2f36", 0.6), 6)
	var kopf := Node3D.new()
	kralle.add_child(kopf)
	RaumBau.zyl(kopf, 0.045, 0.08, Vector3(0, 0.04, 0), chrom, 12)
	var finger := []
	for j in 3:
		var drehpunkt := Node3D.new()
		drehpunkt.rotation.y = TAU * j / 3.0
		kopf.add_child(drehpunkt)
		var gelenk := Node3D.new()
		gelenk.position = Vector3(0, 0, 0.04)
		drehpunkt.add_child(gelenk)
		RaumBau.box(gelenk, Vector3(0.025, 0.14, 0.02), Vector3(0, -0.07, 0), chrom)
		finger.append(gelenk)
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.05
	a.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.95, b + 1.15), Vector3(0, 1.25, 0), Vector3.UP)
	var auto := {"knoten": a, "kralle": kralle, "seil": seil, "kopf": kopf, "finger": finger, "preise": [], "cam": cam, "mitte": p}
	automaten.append(auto)
	_kralle_setzen(auto, Vector2.ZERO, OBEN_Y, 1.0)
	auffuellen(nr)
	_fest(p.x - b - 0.05, p.y - b - 0.05, p.x + b + 0.05, p.y + b + 0.35)
	stationen.append({"art": "greif", "nr": nr, "name": "Greifautomat", "hinweis": "", "pos": _w(p.x, p.y + b + 1.3), "ziel": _w(p.x, p.y)})

func _kralle_setzen(a: Dictionary, p: Vector2, y: float, auf: float) -> void:
	var kr: Node3D = a.kralle
	kr.position = Vector3(p.x, OBEN_Y + 0.2, p.y)
	var laenge := OBEN_Y + 0.2 - y
	var seil: MeshInstance3D = a.seil
	(seil.mesh as CylinderMesh).height = maxf(laenge, 0.01)
	seil.position.y = -laenge * 0.5
	(a.kopf as Node3D).position.y = -laenge
	for g in a.finger:
		(g as Node3D).rotation.x = lerpf(0.18, -0.6, auf)

# Neue Preise in den Automaten legen (Mischung: viele gewöhnliche, wenige seltene)
func auffuellen(nr: int) -> void:
	var a: Dictionary = automaten[nr]
	for p in a.preise:
		(p.knoten as Node3D).queue_free()
	a.preise = []
	var stufen := [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2]
	if randf() < 0.35:
		stufen.append(3)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var plaetze := []
	for s in stufen:
		var id := Wirtschaft.new().zufall_gegenstand(s)
		var n := Moebel.modell(id)
		var gross := Moebel.groesse(id)
		var mass := 0.2 / maxf(maxf(gross.x, gross.z), gross.y * 0.8)
		n.scale = Vector3.ONE * mass
		var p := Vector2.ZERO
		for versuch in 30:   # Platz suchen, nicht im Auswurf-Schacht, nicht zu dicht
			p = Vector2(rng.randf_range(-KASTEN + 0.12, KASTEN - 0.12), rng.randf_range(-KASTEN + 0.12, KASTEN - 0.12))
			var frei := p.distance_to(Vector2(-KASTEN + 0.17, KASTEN - 0.17)) > 0.3
			for q in plaetze:
				if p.distance_to(q) < 0.2:
					frei = false
			if frei:
				break
		plaetze.append(p)
		n.position = Vector3(p.x, BODEN_Y + 0.02, p.y)
		n.rotation.y = rng.randf() * TAU
		(a.knoten as Node3D).add_child(n)
		a.preise.append({"id": id, "knoten": n, "pos": p})

func greif_starten(nr: int) -> Camera3D:
	spiel = nr
	phase = "steuern"
	zeit = ZEIT
	k_pos = Vector2.ZERO
	k_y = OBEN_Y
	gegriffen = -1
	_auf = 1.0
	var a: Dictionary = automaten[nr]
	_kralle_setzen(a, k_pos, k_y, _auf)
	var cam: Camera3D = a.cam
	cam.current = true
	return cam

func greif_abbrechen() -> void:
	if spiel >= 0:
		phase = "zurueck"

func _greif_takt(dt: float) -> void:
	var a: Dictionary = automaten[spiel]
	var auswurf := Vector2(-KASTEN + 0.17, KASTEN - 0.17)
	match phase:
		"steuern":
			zeit -= dt
			var d := Vector2.ZERO
			if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): d.x -= 1.0
			if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): d.x += 1.0
			if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): d.y -= 1.0
			if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): d.y += 1.0
			k_pos += d.normalized() * TEMPO * dt if d != Vector2.ZERO else Vector2.ZERO
			k_pos = k_pos.clamp(Vector2.ONE * (-KASTEN + 0.08), Vector2.ONE * (KASTEN - 0.08))
			if zeit <= 0.0:
				greifen()
		"runter":
			# bis knapp über den Preis darunter (oder den Boden)
			var ziel := BODEN_Y + 0.2
			k_y = move_toward(k_y, ziel, 0.6 * dt)
			if k_y <= ziel + 0.001:
				phase = "zu"
		"zu":
			_auf = move_toward(_auf, 0.0, 2.5 * dt)
			if _auf <= 0.0:
				gegriffen = _treffer()
				_rutsch_bei = -1.0
				if gegriffen >= 0:
					var p: Dictionary = a.preise[gegriffen]
					var naehe := clampf(k_pos.distance_to(p.pos) / TREFFER_R, 0.0, 1.0)
					var rutsch: float = RUTSCH[Wirtschaft.new().seltenheit(p.id)] + naehe * 0.25
					if randf() < rutsch:
						_rutsch_bei = randf_range(BODEN_Y + 0.35, OBEN_Y - 0.05)
				phase = "hoch"
		"hoch":
			k_y = move_toward(k_y, OBEN_Y, 0.5 * dt)
			if _rutsch_bei > 0.0 and k_y >= _rutsch_bei and gegriffen >= 0:
				_fallen_lassen(a, false)
			if k_y >= OBEN_Y - 0.001:
				phase = "zum_auswurf" if gegriffen >= 0 else "zurueck"
		"zum_auswurf":
			k_pos = k_pos.move_toward(auswurf, 0.4 * dt)
			if k_pos.distance_to(auswurf) < 0.005:
				phase = "loslassen"
		"loslassen":
			_auf = move_toward(_auf, 1.0, 2.5 * dt)
			if _auf >= 1.0:
				var id: String = a.preise[gegriffen].id
				_fallen_lassen(a, true)
				phase = ""
				_ende(id)
				return
		"zurueck":
			_auf = move_toward(_auf, 1.0, 2.5 * dt)
			k_y = move_toward(k_y, OBEN_Y, 0.5 * dt)
			k_pos = k_pos.move_toward(Vector2.ZERO, 0.4 * dt)
			if _auf >= 1.0 and k_y >= OBEN_Y - 0.001 and k_pos.length() < 0.005:
				phase = ""
				_ende("")
				return
	_kralle_setzen(a, k_pos, k_y, _auf)
	if gegriffen >= 0:
		var n: Node3D = a.preise[gegriffen].knoten
		n.position = Vector3(k_pos.x, k_y - 0.24, k_pos.y)

func greifen() -> void:
	if phase == "steuern":
		phase = "runter"

# Preis unter der Kralle (nah genug an seiner Mitte), -1 = daneben
func _treffer() -> int:
	var a: Dictionary = automaten[spiel]
	var beste := -1
	var best_d := TREFFER_R
	for i in a.preise.size():
		var d := k_pos.distance_to(a.preise[i].pos)
		if d < best_d:
			best_d = d
			beste = i
	return beste

# Gegriffenen Preis loslassen: im Auswurf = gewonnen (aus dem Automaten nehmen), sonst fällt er zurück
func _fallen_lassen(a: Dictionary, gewonnen: bool) -> void:
	var p: Dictionary = a.preise[gegriffen]
	var n: Node3D = p.knoten
	if gewonnen:
		n.queue_free()
		a.preise.remove_at(gegriffen)
	else:
		p.pos = k_pos.clamp(Vector2.ONE * (-KASTEN + 0.12), Vector2.ONE * (KASTEN - 0.12))
		if p.pos.distance_to(Vector2(-KASTEN + 0.17, KASTEN - 0.17)) < 0.3:
			p.pos += Vector2(0.3, -0.3)
		n.position = Vector3(p.pos.x, BODEN_Y + 0.02, p.pos.y)
	gegriffen = -1

func _ende(id: String) -> void:
	var nr := spiel
	spiel = -1
	if (automaten[nr].preise as Array).size() < 5:
		auffuellen(nr)
	greif_ende.emit(id)

# ---------------------------------------------------------------- Kapsel-Automat + Deko
func _kapselautomat(p: Vector2) -> void:
	var a := Node3D.new()
	a.position = Vector3(p.x, boden, p.y)
	a.rotation.y = PI
	innen.add_child(a)
	var rot := Bau.matt("e2483e", 0.35)
	RaumBau.box(a, Vector3(0.9, 1.1, 0.7), Vector3(0, 0.55, 0), rot)
	RaumBau.box(a, Vector3(0.3, 0.2, 0.05), Vector3(0, 0.45, 0.36), Bau.matt("161828", 0.5))
	RaumBau.zyl(a, 0.09, 0.05, Vector3(0.22, 0.85, 0.37), Bau.metall("d9dde2", 0.2), 16).rotation.x = PI * 0.5
	var kugel := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.9
	kugel.mesh = sm
	kugel.material_override = RaumBau.glas("e8f4ff", 0.18)
	kugel.position = Vector3(0, 1.55, 0)
	a.add_child(kugel)
	var farben := ["ff3fa0", "35c8ff", "ffc531", "7fe08a", "b36bff", "ffffff"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.x * 10.0)
	for k in 26:
		var kap := MeshInstance3D.new()
		var km := SphereMesh.new()
		km.radius = 0.075
		km.height = 0.15
		kap.mesh = km
		kap.material_override = Bau.matt(farben[k % farben.size()], 0.3)
		var r := rng.randf() * 0.32
		var w := rng.randf() * TAU
		kap.position = Vector3(cos(w) * r, 1.22 + rng.randf() * (0.32 - r * 0.6), sin(w) * r)
		a.add_child(kap)
	RaumBau.zyl(a, 0.3, 0.12, Vector3(0, 2.05, 0), rot, 24)
	var t := RaumBau.schrift(a, "KAPSELN", Vector3(0, 0.95, 0.36), 0.0, 70, 0.004, Color("ffffff"))
	t.modulate = Color(1.5, 1.5, 1.5)
	_fest(p.x - 0.5, p.y - 0.4, p.x + 0.5, p.y + 0.4)
	stationen.append({"art": "kapsel", "name": "Kapsel-Automat", "hinweis": "", "pos": _w(p.x, p.y - 1.4), "ziel": _w(p.x, p.y)})

func _deko() -> void:
	# Spielautomaten-Reihe an der Rückwand (−X) und ein Airhockey-Tisch in der Mitte
	var farben := ["35c8ff", "ff3fa0", "ffc531", "7fe08a", "b36bff", "ff8a1e"]
	for i in 6:
		var z := -7.5 + i * 3.0
		var a := Node3D.new()
		a.position = Vector3(-HALB + 0.6, boden, z)
		a.rotation.y = PI * 0.5
		innen.add_child(a)
		RaumBau.box(a, Vector3(0.9, 1.9, 0.8), Vector3(0, 0.95, 0), Bau.matt("1b1e2a", 0.4))
		var bild := RaumBau.leuchte(farben[i], 1.6)
		_leucht.append(bild)
		var schirm := RaumBau.box(a, Vector3(0.7, 0.55, 0.04), Vector3(0, 1.45, 0.38), bild)
		schirm.rotation.x = -0.2
		RaumBau.box(a, Vector3(0.9, 0.18, 0.5), Vector3(0, 1.0, 0.55), Bau.matt(farben[i], 0.4))
		RaumBau.box(a, Vector3(0.9, 0.25, 0.06), Vector3(0, 1.92, 0.4), RaumBau.leuchte("ffffff", 1.4))
	_fest(-HALB, -8.2, -HALB + 1.3, 8.2)
	var tisch := Node3D.new()
	tisch.position = Vector3(1.5, boden, 0)
	innen.add_child(tisch)
	RaumBau.box(tisch, Vector3(2.4, 0.8, 1.3), Vector3(0, 0.4, 0), Bau.matt("1b1e2a", 0.4))
	RaumBau.box(tisch, Vector3(2.3, 0.03, 1.2), Vector3(0, 0.815, 0), RaumBau.leuchte("e8f4ff", 0.6))
	for s in [-1.0, 1.0]:
		RaumBau.zyl(tisch, 0.08, 0.06, Vector3(s * 0.8, 0.86, 0), Bau.matt("e2483e" if s < 0 else "35c8ff", 0.3), 16)
	_fest(0.2, -0.7, 2.8, 0.7)
	RaumBau.modell(innen, "leute/character-male-b", Vector3(0.1, boden, 0.4), 2.5, -PI * 0.5)
	RaumBau.modell(innen, "leute/character-female-c", Vector3(-4.0, boden, -6.8), 2.5, PI)
