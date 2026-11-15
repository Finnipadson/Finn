class_name Gondeln
extends Node3D
# Drei Gondeln, eine je Turmseite (Turm.SEITEN_NAMEN). In der aktiven sitzt der Spieler (Spieler-Knoten),
# die anderen parken unten an ihrer Seite. Noch nicht gekaufte tragen ein Schild „Zu verkaufen“.
# Wechseln: in der Gondel mit E nach unten fahren und aussteigen, zur anderen Gondel laufen, E drücken.

var turm: Turm
var wirtschaft: Wirtschaft
var modelle: Array = []       # Node3D je Seite
var schilder: Array = []      # Label3D je Seite
var aktive := 0

func setup(t: Turm, w: Wirtschaft) -> void:
	turm = t
	wirtschaft = w
	for k in 3:
		var m := _modell()
		add_child(m)
		modelle.append(m)
		var l := Label3D.new()
		l.font_size = 64
		l.pixel_size = 0.006
		l.outline_size = 14
		l.outline_modulate = Color("123a6b")
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		l.position = Vector3(0, 3.2, 0)
		m.add_child(l)
		schilder.append(l)

# Parkplatz der Gondel k (unten an ihrer Seite)
func park_weg(k: int) -> float:
	var w: float = wirtschaft.gondeln[k].weg
	return turm.weg_auf_seite(0, w, k) if w >= 0.0 else turm.seiten_mitte(0, k)

func park_punkt(k: int) -> Dictionary:
	var p := turm.fassaden_punkt(0, park_weg(k), 0.3)
	return {"pos": p.pos + p.normal * Spieler.ABSTAND, "normal": p.normal}

func aktualisieren(aktiv: int) -> void:
	aktive = aktiv
	for k in 3:
		var m: Node3D = modelle[k]
		m.visible = k != aktive
		var p := park_punkt(k)
		m.position = p.pos
		m.basis = Basis.looking_at(-p.normal, Vector3.UP)
		var name: String = Turm.SEITEN_NAMEN[k]
		var l: Label3D = schilder[k]
		if wirtschaft.gondeln[k].gekauft:
			var h: float = wirtschaft.gondeln[k].hoehe
			l.text = "Gondel %s" % name + ("\nzuletzt auf %d m" % int(h) if h > 1.5 else "")
			l.modulate = Color.WHITE
		else:
			l.text = "Gondel %s\nZu verkaufen: %s €" % [name, Hud.punkte(wirtschaft.gondel_preis())]
			l.modulate = Color("ffd84a")
		(m.get_meta("mat") as StandardMaterial3D).albedo_color = Color("ffc531") if wirtschaft.gondeln[k].gekauft else Color("9aa0a8")

# geparkte Gondeln (für die Kollision zu Fuß)
func positionen() -> Array:
	var l := []
	for k in 3:
		if k != aktive:
			var p: Vector3 = park_punkt(k).pos
			l.append(Vector2(p.x, p.z))
	return l

# nächste geparkte Gondel in Reichweite (-1 = keine)
func bei(q: Vector2, weit: float) -> int:
	var beste := -1
	var d := weit
	for k in 3:
		if k == aktive:
			continue
		var p: Vector3 = park_punkt(k).pos
		var a := q.distance_to(Vector2(p.x, p.z))
		if a < d:
			d = a
			beste = k
	return beste

func _modell() -> Node3D:
	var g := Node3D.new()
	var farbe := Bau.matt("ffc531", 0.5)
	g.set_meta("mat", farbe)
	var grau := Bau.metall("6b7078", 0.4, 0.6)
	_box(g, Vector3(3.8, 0.12, 1.15), Vector3(0, -0.06, 0), farbe)
	_box(g, Vector3(3.8, 0.06, 0.06), Vector3(0, 1.05, -0.55), farbe)
	_box(g, Vector3(3.8, 0.06, 0.06), Vector3(0, 1.05, 0.55), farbe)
	_box(g, Vector3(3.8, 0.04, 0.04), Vector3(0, 0.55, 0.55), farbe)
	for x in [-1.88, 1.88]:
		_box(g, Vector3(0.06, 1.05, 1.15), Vector3(x, 0.52, 0), farbe)
		var seil := Bau.zylinder(0.025, 0.025, 600.0, grau, 6)
		seil.position = Vector3(x * 0.92, 300.0, 0.0)
		g.add_child(seil)
		_box(g, Vector3(0.12, 0.25, 0.12), Vector3(x * 0.92, 1.25, 0.0), grau)
	for x in [-1.2, -0.4, 0.4, 1.2]:
		_box(g, Vector3(0.05, 1.05, 0.05), Vector3(x, 0.52, 0.55), farbe)
	return g

func _box(eltern: Node3D, groesse: Vector3, p: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = groesse
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	eltern.add_child(mi)
