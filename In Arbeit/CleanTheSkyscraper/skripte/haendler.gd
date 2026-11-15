class_name Haendler
extends Node3D
# Drei moderne Kioske auf dem Platz (in den Lücken zwischen den Turmflügeln), jeder mit Verkäufer.
# Gebäude (Glas, Dach, Leuchtschild, Theke) aus Code, Einrichtung + Figuren aus Kenney-Paketen (CC0):
# Mini Market (modelle/laden), Mini Characters (modelle/leute), Food Kit (modelle/essen), City Kit Commercial (modelle/stadt).
# Zu Fuß vor einen Kiosk gehen und E drücken → HaendlerMenu öffnet sich.

const STAENDE := [
	{"id": "putz", "name": "Putzmittel", "farbe": "2f86c8", "dunkel": "1d5a8a", "figur": "leute/character-worker"},
	{"id": "mode", "name": "Mode & Farben", "farbe": "d84f9a", "dunkel": "8f2f63", "figur": "leute/character-female-c"},
	{"id": "snack", "name": "Snacks", "farbe": "e08a1e", "dunkel": "9a5a10", "figur": "laden/character-employee"},
	{"id": "werkzeug", "name": "Profi-Werkzeuge", "farbe": "3f9d5a", "dunkel": "246b3a", "figur": "leute/character-male-b"},
	{"id": "grund", "name": "Werkzeuge", "farbe": "d4502f", "dunkel": "8f3520", "figur": "leute/character-male-e"},
	{"id": "fahrzeug", "name": "Fahrzeuge", "farbe": "7a5ad6", "dunkel": "4f3a94", "figur": "leute/character-female-a"},
]
const NAH := 2.8                 # so nah muss man vor dem Kiosk stehen
const MINI := 2.25               # Kenney-Mini-Modelle auf Menschengröße bringen
const BREIT := 4.6               # Kiosk-Breite (m)
const TIEF := 3.2

var vorne: Array = []            # Vector2: Punkt vor jedem Kiosk (zum Ansprechen)
var rechtecke: Array = []        # Rect2 für die Kollision zu Fuß
var glas_mat: StandardMaterial3D

func setup(orte: Array) -> void:
	glas_mat = StandardMaterial3D.new()
	glas_mat.albedo_color = Color(0.75, 0.88, 0.95, 0.28)
	glas_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glas_mat.metallic = 0.3
	glas_mat.roughness = 0.05
	for i in STAENDE.size():
		var sp: Dictionary = STAENDE[i]
		var ort: Vector3 = orte[i % orte.size()]
		var p2 := Vector2(ort.x, ort.z)
		var r := p2.normalized()      # von der Turmmitte nach außen
		var kiosk := _kiosk(sp)
		kiosk.position = Vector3(p2.x, 0, p2.y)
		kiosk.basis = Basis.looking_at(Vector3(-r.x, 0, -r.y), Vector3.UP)   # Front (−Z) zum Turm
		add_child(kiosk)
		vorne.append(p2 - r * 2.7)
		rechtecke.append(Rect2(p2 - Vector2(2.4, 2.4), Vector2(4.8, 4.8)))
		if sp.id == "snack":
			_sitzecke(p2, r)

# Welcher Kiosk ist nah genug? (-1 = keiner)
func stand_bei(p: Vector2) -> int:
	for i in vorne.size():
		if p.distance_to(vorne[i]) < NAH:
			return i
	return -1

# ---------------------------------------------------------------- Bausteine
func _box(eltern: Node3D, g: Vector3, p: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = g
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	eltern.add_child(mi)
	return mi

# Kenney-Modell laden; s = Maßstab, dreh = Drehung um Y
func _modell(name: String, p: Vector3, eltern: Node3D, s := MINI, dreh := 0.0) -> Node3D:
	var pfad := "res://modelle/%s.glb" % name
	if not ResourceLoader.exists(pfad):
		push_warning("Modell fehlt: " + pfad)
		return Node3D.new()
	var n: Node3D = load(pfad).instantiate()
	n.position = p
	n.rotation.y = dreh
	n.scale = Vector3.ONE * s
	eltern.add_child(n)
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:   # Figuren: Ruhe-Animation abspielen
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

# ---------------------------------------------------------------- Kiosk (Front = −Z)
func _kiosk(sp: Dictionary) -> Node3D:
	var n := Node3D.new()
	var weiss := Bau.matt("f4f4f2", 0.5)
	var grau := Bau.matt("3b3f46", 0.7)
	var farbe := Bau.matt(sp.farbe, 0.45)
	var dunkel := Bau.matt(sp.dunkel, 0.6)
	var h := 2.8
	_box(n, Vector3(BREIT + 0.3, 0.14, TIEF + 0.3), Vector3(0, 0.07, 0), grau)                     # Sockel
	_box(n, Vector3(BREIT, h, 0.12), Vector3(0, h * 0.5, TIEF * 0.5), dunkel)                       # Rückwand
	for s in [-1.0, 1.0]:
		_box(n, Vector3(0.08, h, TIEF), Vector3(s * BREIT * 0.5, h * 0.5, 0), glas_mat)             # Glas-Seitenwände
		_box(n, Vector3(0.12, h, 0.12), Vector3(s * BREIT * 0.5, h * 0.5, -TIEF * 0.5), weiss)      # Eckpfosten vorne
		_box(n, Vector3(0.12, h, 0.12), Vector3(s * BREIT * 0.5, h * 0.5, TIEF * 0.5), weiss)
	_box(n, Vector3(BREIT + 0.6, 0.22, TIEF + 0.9), Vector3(0, h + 0.11, -0.2), weiss)             # Flachdach (vorne überstehend)
	_box(n, Vector3(BREIT + 0.62, 0.55, 0.12), Vector3(0, h + 0.05, -TIEF * 0.5 - 0.62), farbe)    # Blende fürs Leuchtschild
	_box(n, Vector3(BREIT - 0.2, 0.06, TIEF - 0.4), Vector3(0, h - 0.04, 0), Bau.matt("fff6dc", 0.3))  # Deckenlicht-Fläche
	var licht := OmniLight3D.new()
	licht.position = Vector3(0, h - 0.5, 0)
	licht.light_energy = 1.2
	licht.omni_range = 5.0
	licht.light_color = Color("fff1d6")
	n.add_child(licht)
	# Theke vorne
	_box(n, Vector3(BREIT - 0.3, 1.0, 0.6), Vector3(0, 0.5 + 0.07, -TIEF * 0.5 + 0.3), farbe)
	_box(n, Vector3(BREIT - 0.1, 0.07, 0.75), Vector3(0, 1.1, -TIEF * 0.5 + 0.3), weiss)
	# Leuchtschild
	var schild := Label3D.new()
	schild.text = sp.name.to_upper()
	schild.font_size = 120
	schild.pixel_size = 0.0042
	schild.outline_size = 0
	schild.modulate = Color.WHITE
	schild.shaded = false
	schild.position = Vector3(0, h + 0.05, -TIEF * 0.5 - 0.69)
	schild.rotation.y = PI
	n.add_child(schild)
	# Verkäufer hinter der Theke (Kenney-Figuren schauen schon nach −Z, also zur Theke)
	_box(n, Vector3(1.2, 0.3, 1.0), Vector3(0.35, 0.29, -0.4), Bau.matt("3b3f46", 0.7))   # Podest hinter der Theke
	_modell(sp.figur, Vector3(0.35, 0.44, -0.4), n, 2.6, PI)
	match sp.id:
		"putz":
			_modell("laden/shelf-boxes", Vector3(-1.3, 0.14, 1.05), n, MINI)
			_modell("laden/shelf-bags", Vector3(0.6, 0.14, 1.05), n, MINI)
			_modell("laden/display-cans", Vector3(-1.4, 0.14, -0.2), n, 1.5)
			_modell("laden/cash-register", Vector3(1.4, 1.14, -1.25), n, 0.9, PI)
		"mode":
			_modell("laden/clothing-rack", Vector3(-1.2, 0.14, 0.9), n, MINI)
			_modell("laden/clothing-rack", Vector3(1.0, 0.14, 0.9), n, MINI)
			_modell("laden/clothing-table", Vector3(-1.3, 1.14, -1.25), n, 1.1, PI)
			_modell("laden/mannequin", Vector3(-BREIT * 0.5 - 0.9, 0.0, -TIEF * 0.5 - 0.3), n, 2.4, PI)
			_modell("laden/mannequin", Vector3(BREIT * 0.5 + 0.9, 0.0, -TIEF * 0.5 - 0.3), n, 2.4, PI)
		"werkzeug":
			_modell("laden/shelf-bags", Vector3(-1.3, 0.14, 1.05), n, MINI)
			_modell("laden/cash-register", Vector3(1.4, 1.14, -1.25), n, 0.9, PI)
			# Profi-Geräte auf der Theke: Dampfreiniger (rot), Wasserlanze (blau), große Schwämme
			for k in 2:
				var x2 := -1.4 + k * 0.9
				_box(n, Vector3(0.14, 0.22, 0.46), Vector3(x2, 1.25, -1.3), Bau.matt(["e2483e", "3a86d4"][k], 0.5))
				_box(n, Vector3(0.06, 0.06, 0.6), Vector3(x2, 1.32, -1.75), Bau.metall("3b3f46", 0.4, 0.6))
			_box(n, Vector3(0.5, 0.2, 0.3), Vector3(0.45, 1.2, -1.3), Bau.matt("6ac7e8", 0.95))
		"grund":
			_modell("laden/shelf-boxes", Vector3(-1.3, 0.14, 1.05), n, MINI)
			_modell("laden/display-small", Vector3(1.2, 0.14, 1.0), n, MINI)
			_modell("laden/cash-register", Vector3(1.4, 1.14, -1.25), n, 0.9, PI)
			# Werkzeuge auf der Theke (aus Code): Schwämme, Abzieher, Sprühpistole
			var x := -1.7
			for f in ["ffd84a", "6ac7e8", "ffb03a"]:
				_box(n, Vector3(0.3, 0.12, 0.2), Vector3(x, 1.2, -1.3), Bau.matt(f, 0.95))
				x += 0.42
			_box(n, Vector3(0.7, 0.05, 0.06), Vector3(-0.3, 1.17, -1.3), Bau.matt("2b2b2b", 0.7))
			_box(n, Vector3(0.7, 0.07, 0.06), Vector3(-0.3, 1.21, -1.25), Bau.metall("c9ced4", 0.3, 0.8))
			_box(n, Vector3(0.1, 0.16, 0.34), Vector3(0.3, 1.22, -1.3), Bau.matt("e2483e", 0.5))
			_box(n, Vector3(0.05, 0.05, 0.5), Vector3(0.3, 1.27, -1.6), Bau.metall("3b3f46", 0.4, 0.6))
		"fahrzeug":
			_modell("laden/cash-register", Vector3(1.4, 1.14, -1.25), n, 0.9, PI)
			# Fahrzeuge ausgestellt: vor dem Kiosk Scooter + Hoverboard, auf der Theke das Jetpack
			var sc := Fahrzeuge.modell("scooter")
			sc.position = Vector3(-BREIT * 0.5 - 0.8, 0.0, -TIEF * 0.5 - 0.6)
			sc.rotation.y = 0.5
			n.add_child(sc)
			var hb := Fahrzeuge.modell("hoverboard")
			hb.position = Vector3(BREIT * 0.5 + 0.8, 0.25, -TIEF * 0.5 - 0.6)
			hb.rotation = Vector3(0.0, -0.4, 0.0)
			n.add_child(hb)
			var jp := Fahrzeuge.modell("jetpack")
			jp.position = Vector3(-0.9, 1.14 - 1.0, -1.3)
			for c in jp.get_children():
				if c.name.begins_with("flamme"):
					c.visible = false
			n.add_child(jp)
		"snack":
			_modell("laden/freezers-standing", Vector3(-1.1, 0.14, 1.05), n, MINI)
			_modell("laden/display-bread", Vector3(1.2, 0.14, 1.0), n, MINI)
			_modell("laden/freezer", Vector3(-BREIT * 0.5 - 1.0, 0.0, -TIEF * 0.5 + 0.4), n, MINI, PI / 2.0)
			var x := -1.6
			for e in ["essen/cup-coffee", "essen/mug", "essen/ice-cream-cone", "essen/sundae", "essen/soda-can", "essen/lemon", "essen/donut-sprinkles"]:
				_modell(e, Vector3(x, 1.14, -1.35), n, 1.25, PI)
				x += 0.42
	return n

# Sonnenschirme mit Tischen vor dem Snack-Kiosk
func _sitzecke(p2: Vector2, r: Vector2) -> void:
	var t := Vector2(-r.y, r.x)
	var bein_mat := Bau.metall("9aa0a8", 0.4, 0.6)
	for k in [-1.0, 1.0]:
		var m: Vector2 = p2 - r * 7.0 + t * (k * 3.6)
		var schirm := _modell("stadt/detail-parasol-a" if k < 0 else "stadt/detail-parasol-b", Vector3(m.x, 0, m.y), self, 5.5)
		schirm.position.y = 0.0
		# der Kenney-Sonnenschirm bringt seinen Tisch schon mit
		for j in 3:   # Hocker
			var a := TAU * j / 3.0
			var h := Bau.zylinder(0.2, 0.2, 0.06, Bau.matt(STAENDE[2].farbe, 0.5), 14)
			h.position = Vector3(m.x + cos(a) * 1.0, 0.45, m.y + sin(a) * 1.0)
			add_child(h)
			var hb := Bau.zylinder(0.03, 0.03, 0.45, bein_mat, 6)
			hb.position = Vector3(m.x + cos(a) * 1.0, 0.225, m.y + sin(a) * 1.0)
			add_child(hb)
		rechtecke.append(Rect2(m - Vector2(0.7, 0.7), Vector2(1.4, 1.4)))
