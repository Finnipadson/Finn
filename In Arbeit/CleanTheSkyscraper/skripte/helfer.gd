class_name Helfer
extends Node3D
# Automatik (Phase 4): Helfer putzen nebenbei Fenster – nur während man spielt und nur bis zur Seil-Grenze.
#  - Putzkraft: kleine Gondel mit Figur an einer Turmseite, putzt das unterste dreckige Fenster ihrer Seite
#  - Putzroboter: klettert an einer Turmseite eine Fensterspalte hoch und schrubbt sie ab
#  - Putzdrohne: fliegt um den ganzen Turm (außen um die Flügel herum) und sprüht Fenster sauber
# Während des Putzens verblasst der Dreck sichtbar. Fertige Fenster meldet das Signal geputzt (Spiel zahlt Lohn abzüglich Anteil).
# Fenster in der Nähe der Spieler-Gondel lassen sie aus – die putzt man selbst.

signal geputzt(f: int, spalte: int, art: String)

const GONDEL_ABSTAND := 1.3
const FAHRT_HOCH := 4.0         # m/s
const FAHRT_SEITE := 4.0
const DROHNE_TEMPO := 18.0
const DROHNE_AUSSEN := 88.0     # so weit außen fliegen Drohnen um den Turm (Flügel unten reichen bis 75 m)
const DROHNE_ABSTAND := 2.4

var turm: Turm
var zustand: FensterZustand
var wirtschaft: Wirtschaft
var spieler: Spieler
var liste: Array = []           # ein Dictionary je Helfer
var reserviert := {}            # Fenster-Nummer -> true
var ab_stock := [0, 0, 0]       # unterstes Stockwerk mit dreckigen Fenstern je Seite (Suche beschleunigen)
var _neu_suchen := 0.0
var zeit := 0.0
var verlauf: Array = []         # Zeitpunkte geputzter Fenster (für „Fenster/Minute“)
var aktiv := true

func setup(t: Turm, z: FensterZustand, w: Wirtschaft, s: Spieler) -> void:
	turm = t
	zustand = z
	wirtschaft = w
	spieler = s
	abgleichen()

# Anzahl der Helfer an die gekauften angleichen (nach einem Kauf aufrufen)
func abgleichen() -> void:
	for art in ["putzkraft", "roboter", "drohne"]:
		var da := 0
		for h in liste:
			if h.art == art:
				da += 1
		for i in range(da, int(wirtschaft.helfer[art])):
			_neu(art, i)

func anzahl() -> int:
	return liste.size()

func pro_minute() -> float:
	var n := 0.0
	for h in liste:
		n += 60.0 / float(Wirtschaft.HELFER[h.art].sekunden)
	return n

func zuletzt_pro_minute() -> int:
	while verlauf.size() > 0 and zeit - float(verlauf[0]) > 60.0:
		verlauf.pop_front()
	return verlauf.size()

func _neu(art: String, i: int) -> void:
	var seite := i % 3
	var h := {"art": art, "seite": seite, "nr": i, "phase": "suchen", "f": 0, "weg": turm.seiten_mitte(0, seite) + (i / 3) * 6.0,
		"y": 0.3, "ziel": Vector2i(-1, -1), "zeit": 0.0, "dreck": 1.0, "pos": Vector3.ZERO, "route": [], "warte": randf() * 2.0}
	match art:
		"putzkraft": h.node = _putzkraft_modell()
		"roboter": h.node = _roboter_modell()
		_:
			h.node = _drohnen_modell()
			var p := turm.fassaden_punkt(0, h.weg, 0.0)
			h.pos = p.pos + p.normal * 6.0 + Vector3.UP * 3.0
	add_child(h.node)
	liste.append(h)
	_platzieren(h)

# ---------------------------------------------------------------- Ablauf
func _process(dt: float) -> void:
	if not aktiv:
		return
	zeit += dt
	_neu_suchen -= dt
	if _neu_suchen <= 0.0:   # ab und zu ganz unten neu anfangen (Tauben und Sandsturm machen Fenster wieder dreckig)
		_neu_suchen = 30.0
		ab_stock = [0, 0, 0]
	for h in liste:
		match h.art:
			"drohne": _drohne(h, dt)
			_: _an_der_fassade(h, dt)

# Putzkraft + Roboter: fahren an der Fassade ihrer Seite (Weg + Höhe)
func _an_der_fassade(h: Dictionary, dt: float) -> void:
	match h.phase:
		"suchen":
			h.warte = float(h.warte) - dt
			if h.warte > 0.0:
				_platzieren(h)
				return
			var z := _naechstes(h)
			if z.x < 0:
				h.warte = 3.0           # nichts zu tun (alles sauber bis zur Seil-Grenze)
				_platzieren(h)
				return
			_reservieren(h, z)
			h.phase = "fahren"
		"fahren":
			var z: Vector2i = h.ziel
			var ziel_y := z.y * Turm.STOCK_H + (0.3 if h.art == "putzkraft" else Turm.STOCK_H * 0.35)
			var y: float = h.y
			if absf(y - ziel_y) > 0.01:
				h.y = move_toward(y, ziel_y, FAHRT_HOCH * dt)
			else:
				var f := turm.stockwerk_bei(float(h.y) + 1.2) if h.art == "putzkraft" else z.y
				var ziel_weg := (z.x + 0.5) * Turm.FENSTER_B
				var v: Vector2 = turm.seiten[f][h.seite]
				var u := turm.umfaenge[f]
				var rel := fposmod(float(h.weg) - v.x, u)
				var rel_ziel := fposmod(ziel_weg - v.x, u)
				rel = move_toward(rel, rel_ziel, FAHRT_SEITE * dt)
				h.weg = fposmod(v.x + rel, u)
				if absf(rel - rel_ziel) < 0.01:
					h.phase = "putzen"
					h.zeit = 0.0
					h.dreck = maxf(0.3, zustand.dreck(z.y, z.x))
			_platzieren(h)
		"putzen":
			_putzen(h, dt)
			_platzieren(h)

func _putzen(h: Dictionary, dt: float) -> void:
	var z: Vector2i = h.ziel
	var dauer: float = Wirtschaft.HELFER[h.art].sekunden
	h.zeit = float(h.zeit) + dt
	if zustand.ist_sauber(z.y, z.x):   # hat schon jemand anderes geputzt
		_fertig(h)
		return
	var t := clampf(float(h.zeit) / dauer, 0.0, 1.0)
	zustand.dreck_setzen(z.y, z.x, float(h.dreck) * (1.0 - t))
	if t >= 1.0:
		if zustand.sauber_machen(z.y, z.x):
			verlauf.append(zeit)
			geputzt.emit(z.y, z.x, h.art)
		_fertig(h)

func _fertig(h: Dictionary) -> void:
	var z: Vector2i = h.ziel
	reserviert.erase(turm.fenster_basis[z.y] + z.x)
	h.phase = "suchen"
	h.warte = 0.2

func _reservieren(h: Dictionary, z: Vector2i) -> void:
	h.ziel = z
	reserviert[turm.fenster_basis[z.y] + z.x] = true

# Position + Ausrichtung an der Fassade (Weg wird beim Stufen-Wechsel umgerechnet wie bei der Gondel)
func _platzieren(h: Dictionary) -> void:
	if h.art == "drohne":
		return
	var y: float = h.y
	var f := turm.stockwerk_bei(y + (1.2 if h.art == "putzkraft" else 0.0))
	if f != int(h.f):
		if not turm.gleicher_grundriss(f, int(h.f)):
			var alt := turm.fassaden_punkt(int(h.f), float(h.weg), y)
			h.weg = turm.naechster_weg(f, Vector2(alt.pos.x, alt.pos.z))
		h.f = f
	h.weg = turm.weg_auf_seite(f, float(h.weg), h.seite, 0.5)   # Randfenster liegen 0,75 m vor der Grenze
	var p := turm.fassaden_punkt(f, float(h.weg), y)
	var n: Node3D = h.node
	n.position = p.pos + p.normal * (GONDEL_ABSTAND if h.art == "putzkraft" else 0.32)
	n.basis = Basis.looking_at(-p.normal, Vector3.UP)
	# kleine Bewegungen beim Putzen
	var arbeit := n.get_node_or_null("arbeit") as Node3D
	if arbeit:
		var an: bool = h.phase == "putzen"
		if h.art == "putzkraft":
			arbeit.position = Vector3(sin(zeit * 5.0) * 0.45, 1.5 + cos(zeit * 4.0) * 0.35, -0.95) if an else Vector3(0.3, 1.0, -0.4)
		else:
			arbeit.rotation.x += (14.0 if an else 2.0) * get_process_delta_time()

# ---------------------------------------------------------------- Drohne
func _drohne(h: Dictionary, dt: float) -> void:
	var n: Node3D = h.node
	for r in n.get_meta("rotoren"):
		(r as Node3D).rotation.y += 40.0 * dt
	var spray := n.get_node("spray") as Node3D
	spray.visible = h.phase == "putzen"
	match h.phase:
		"suchen":
			h.warte = float(h.warte) - dt
			if h.warte > 0.0:
				return
			var z := Vector2i(-1, -1)
			var seite := 0
			var pos3: Vector3 = h.pos
			for k in 3:   # erst die eigene Seite, dann die nächsten
				seite = (int(h.seite) + k) % 3
				var f0 := clampi(int(ab_stock[seite]), 0, Turm.STOCKWERKE - 1)
				z = _suche(seite, turm.naechster_weg(f0, Vector2(pos3.x, pos3.z)))
				if z.x >= 0:
					break
			if z.x < 0:
				h.warte = 3.0
				return
			h.seite = seite
			_reservieren(h, z)
			var mitte := spieler.fenster_mitte(z.y, z.x)
			var p := turm.fassaden_punkt(z.y, (z.x + 0.5) * Turm.FENSTER_B, mitte.y)
			var ziel: Vector3 = mitte + p.normal * DROHNE_ABSTAND
			h.route = _route(h.pos, ziel)
			h.blick = -p.normal
			h.phase = "fahren"
		"fahren":
			var route: Array = h.route
			if route.is_empty():
				h.phase = "putzen"
				h.zeit = 0.0
				var z2: Vector2i = h.ziel
				h.dreck = maxf(0.3, zustand.dreck(z2.y, z2.x))
			else:
				var ziel: Vector3 = route[0]
				var pos: Vector3 = h.pos
				var d := ziel - pos
				var schritt := DROHNE_TEMPO * dt
				if d.length() <= schritt:
					h.pos = ziel
					route.pop_front()
				else:
					h.pos = pos + d.normalized() * schritt
					n.basis = n.basis.slerp(Basis.looking_at(Vector3(d.x, 0, d.z).normalized() if Vector2(d.x, d.z).length() > 0.1 else -n.basis.z, Vector3.UP), minf(1.0, dt * 4.0))
		"putzen":
			var b: Vector3 = h.blick
			n.basis = n.basis.slerp(Basis.looking_at(b, Vector3.UP), minf(1.0, dt * 6.0))
			_putzen(h, dt)
	n.position = h.pos + Vector3.UP * sin(zeit * 3.0 + float(h.nr)) * 0.08

# Flugweg: bei kleinem Winkel direkt, sonst erst nach außen, um den Turm herum (über den Flügeln) und wieder hinein
func _route(von: Vector3, nach: Vector3) -> Array:
	var a0 := atan2(von.z, von.x)
	var a1 := atan2(nach.z, nach.x)
	var diff := wrapf(a1 - a0, -PI, PI)
	if absf(diff) < deg_to_rad(18.0):
		return [nach]
	var r := maxf(DROHNE_AUSSEN, maxf(Vector2(von.x, von.z).length(), Vector2(nach.x, nach.z).length()))
	var l := [Vector3(cos(a0) * r, von.y, sin(a0) * r)]
	var schritte := int(ceil(absf(diff) / deg_to_rad(15.0)))
	for i in range(1, schritte + 1):
		var a := a0 + diff * i / schritte
		var yy := lerpf(von.y, nach.y, float(i) / schritte)
		l.append(Vector3(cos(a) * r, yy, sin(a) * r))
	l.append(nach)
	return l

# ---------------------------------------------------------------- Fenster aussuchen
func _naechstes(h: Dictionary) -> Vector2i:
	# Roboter: erst in derselben Spalte weiter nach oben
	if h.art == "roboter":
		var z: Vector2i = h.ziel
		if z.x >= 0:
			var grenze := mini(wirtschaft.oberstes_stockwerk(), Turm.STOCKWERKE)
			for f in range(z.y + 1, grenze):
				if not turm.gleicher_grundriss(f, z.y):
					break
				var id := turm.fenster_basis[f] + z.x
				if zustand.sauber[id] == 0 and not reserviert.has(id) and not _spieler_nah(f, z.x, h.seite):
					return Vector2i(z.x, f)
	return _suche(h.seite, float(h.weg))

# Unterstes Stockwerk mit freier Arbeit auf der Seite, dort das Fenster, das am nächsten an „nahe_weg“ liegt
func _suche(seite: int, nahe_weg: float) -> Vector2i:
	var grenze := mini(wirtschaft.oberstes_stockwerk(), Turm.STOCKWERKE)
	var erst := int(ab_stock[seite])
	for f in range(erst, grenze):
		var alles_sauber := true
		var beste := -1
		var beste_d := INF
		var u := turm.umfaenge[f]
		for c in turm.spalten_der_seite(f, seite):
			var id := turm.fenster_basis[f] + c
			if zustand.sauber[id] == 1:
				continue
			alles_sauber = false
			if reserviert.has(id) or _spieler_nah(f, c, seite):
				continue
			var d := absf(wrapf((c + 0.5) * Turm.FENSTER_B - nahe_weg, -u * 0.5, u * 0.5))
			if d < beste_d:
				beste_d = d
				beste = c
		if beste >= 0:
			return Vector2i(beste, f)
		if alles_sauber and f == int(ab_stock[seite]):
			ab_stock[seite] = f + 1
	return Vector2i(-1, -1)

func _spieler_nah(f: int, c: int, seite: int) -> bool:
	if spieler == null or not spieler.aktiv or seite != spieler.seite:
		return false
	if absi(f - spieler.stock) > 2:
		return false
	var u := turm.umfaenge[f]
	var d := absf(wrapf((c + 0.5) * Turm.FENSTER_B - spieler.weg, -u * 0.5, u * 0.5))
	return d < 6.0

# ---------------------------------------------------------------- Modelle
func _putzkraft_modell() -> Node3D:
	var g := Node3D.new()
	var blau := Bau.matt("3a86d4", 0.5)
	var weiss := Bau.matt("eef2f5", 0.6)
	var grau := Bau.metall("6b7078", 0.4, 0.6)
	_box(g, Vector3(2.2, 0.1, 0.9), Vector3(0, -0.05, 0), blau)
	_box(g, Vector3(2.2, 0.05, 0.05), Vector3(0, 1.0, 0.43), weiss)
	_box(g, Vector3(2.2, 0.05, 0.05), Vector3(0, 1.0, -0.43), weiss)
	for x in [-1.08, 1.08]:
		_box(g, Vector3(0.05, 1.0, 0.9), Vector3(x, 0.5, 0), blau)
		var seil := Bau.zylinder(0.02, 0.02, 400.0, grau, 5)
		seil.position = Vector3(x * 0.9, 200.0, 0)
		g.add_child(seil)
	var figur: Node3D = load("res://modelle/leute/character-worker.glb").instantiate()
	figur.scale = Vector3.ONE * 2.1
	figur.rotation.y = PI          # Kenney-Figuren schauen nach +Z, die Gondel-Front ist −Z
	figur.position = Vector3(0.2, 0.0, 0.1)
	g.add_child(figur)
	var ap := figur.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		for a in ap.get_animation_list():
			if "idle" in a.to_lower():
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
				ap.play(a)
				break
	var schwamm := Node3D.new()
	schwamm.name = "arbeit"
	_box(schwamm, Vector3(0.3, 0.2, 0.08), Vector3.ZERO, Bau.matt("ffd84a", 0.9))
	g.add_child(schwamm)
	return g

func _roboter_modell() -> Node3D:
	var g := Node3D.new()
	_box(g, Vector3(1.1, 0.8, 0.4), Vector3(0, 0, 0.1), Bau.matt("3b3f46", 0.5))
	_box(g, Vector3(1.12, 0.12, 0.42), Vector3(0, 0.2, 0.1), Bau.matt("ffc531", 0.5))
	var licht := Bau.matt("ff8a1e", 0.4)
	licht.emission_enabled = true
	licht.emission = Color("ff8a1e")
	licht.emission_energy_multiplier = 2.0
	_box(g, Vector3(0.12, 0.08, 0.12), Vector3(0, 0.44, 0.15), licht)
	var buerste := Node3D.new()
	buerste.name = "arbeit"
	buerste.position = Vector3(0, -0.25, -0.14)
	var walze := Bau.zylinder(0.13, 0.13, 1.25, Bau.matt("2f86c8", 0.95), 12)
	walze.rotation.z = PI / 2.0
	buerste.add_child(walze)
	g.add_child(buerste)
	for x in [-0.45, 0.45]:   # Saugnäpfe
		var s := Bau.zylinder(0.1, 0.1, 0.06, Bau.matt("222222", 0.7), 10)
		s.rotation.x = PI / 2.0
		s.position = Vector3(x, 0.25, -0.12)
		g.add_child(s)
	return g

func _drohnen_modell() -> Node3D:
	var g := Node3D.new()
	var weiss := Bau.matt("f4f4f2", 0.4)
	var dunkel := Bau.matt("2b2d33", 0.6)
	_box(g, Vector3(0.5, 0.16, 0.6), Vector3.ZERO, weiss)
	var rotoren := []
	for e in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var arm := Vector3(e.x * 0.45, 0.02, e.y * 0.45)
		var stab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.04, 0.62)
		stab.mesh = bm
		stab.material_override = dunkel
		stab.position = arm * 0.5
		stab.rotation.y = atan2(arm.x, arm.z)
		g.add_child(stab)
		var r := Node3D.new()
		r.position = arm + Vector3.UP * 0.08
		var blatt := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(0.5, 0.01, 0.05)
		blatt.mesh = bm2
		blatt.material_override = dunkel
		r.add_child(blatt)
		g.add_child(r)
		rotoren.append(r)
	g.set_meta("rotoren", rotoren)
	var duese := Bau.zylinder(0.03, 0.04, 0.3, Bau.metall("c9ced4", 0.3, 0.8), 8)
	duese.rotation.x = PI / 2.0
	duese.position = Vector3(0, -0.06, -0.4)
	g.add_child(duese)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.85, 0.95, 1.0, 0.4)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.emission_enabled = true
	sm.emission = Color(0.6, 0.85, 1.0)
	sm.emission_energy_multiplier = 0.4
	var spray := Bau.zylinder(0.45, 0.03, DROHNE_ABSTAND - 0.4, sm, 10)   # oben (weit weg, am Glas) breit
	spray.name = "spray"
	spray.rotation.x = -PI / 2.0
	spray.position = Vector3(0, -0.06, -0.55 - (DROHNE_ABSTAND - 0.4) * 0.5)
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(spray)
	return g

func _box(eltern: Node3D, groesse: Vector3, p: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = groesse
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	eltern.add_child(mi)
