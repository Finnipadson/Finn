class_name Spieler
extends Node3D
# Die Gondel mit Ich-Ansicht: an der Fassade entlang fahren (A/D), hoch/runter (W/S), umschauen (Maus),
# putzen (linke Maustaste halten + Maus bewegen → der Schwamm reibt über das Glas).

signal fenster_sauber(f: int, spalte: int)

const ABSTAND := 1.8         # Gondel-Mitte vor dem Glas (m)
const AUGE := 1.65            # Augenhöhe über dem Gondelboden
const TEMPO_SEITE := 1.6      # m/s
const TEMPO_HOCH := 1.1       # m/s
const REICH_SEITE := 1.8      # wie weit der Arm seitlich reicht
const REICH_UNTEN := 0.25     # Höhe über dem Gondelboden
const REICH_OBEN := 2.9
const MAUS_LOOK := 0.0022
const MAUS_WISCH := 0.0032    # m pro Mauspixel beim Putzen

var turm: Turm
var zustand: FensterZustand
var schwamm_r := 0.17         # Radius des Schwamms (m) – wird später durch Werkzeuge größer
var weg := 0.0                # Position entlang des Umfangs
var y := 0.5                  # Höhe des Gondelbodens
var max_y := 70.0
var stock := 0
var yaw := 0.0
var pitch := -0.08
var gondel: Node3D
var cam: Camera3D
var normal := Vector3.BACK
var winkel := 0.0             # Blickrichtung der Gondel (geglättet)
var rechts := Vector3.RIGHT   # Bildschirm-rechts entlang der Fassade
var richtung := 1.0           # +1 wenn „rechts“ den Weg vergrößert
var glas_punkt := Vector3.ZERO
var wischt := false
var schwamm_off := Vector2(0.2, 1.5)   # (seitlich, Höhe über Gondelboden) auf der Glasebene
var letzter_stempel := Vector2(INF, INF)
var schwamm: Node3D
var arm: MeshInstance3D
var hand: Node3D
var gesperrt := false          # true = keine Eingaben (Testbilder)

func setup(t: Turm, z: FensterZustand, start_stock: int, start_weg: float, oberste_hoehe: float) -> void:
	turm = t
	zustand = z
	stock = start_stock
	weg = start_weg
	y = start_stock * Turm.STOCK_H + 0.3
	max_y = oberste_hoehe
	_bauen()
	_platzieren(0.0)

# ---------------------------------------------------------------- Modelle
func _bauen() -> void:
	gondel = Node3D.new()
	add_child(gondel)
	var gelb := Bau.matt("ffc531", 0.5)
	var grau := Bau.metall("6b7078", 0.4, 0.6)
	_box(gondel, Vector3(3.8, 0.12, 1.15), Vector3(0, -0.06, 0), gelb)          # Boden
	_box(gondel, Vector3(3.8, 0.06, 0.06), Vector3(0, 1.05, -0.55), gelb)       # Geländer vorne (zur Wand)
	_box(gondel, Vector3(3.8, 0.06, 0.06), Vector3(0, 1.05, 0.55), gelb)        # Geländer hinten
	_box(gondel, Vector3(3.8, 0.04, 0.04), Vector3(0, 0.55, 0.55), gelb)
	for x in [-1.88, 1.88]:
		_box(gondel, Vector3(0.06, 1.05, 1.15), Vector3(x, 0.52, 0), gelb)      # Seitenwände
		var seil := Bau.zylinder(0.025, 0.025, 600.0, grau, 6)
		seil.position = Vector3(x * 0.92, 300.0, 0.0)
		gondel.add_child(seil)
		_box(gondel, Vector3(0.12, 0.25, 0.12), Vector3(x * 0.92, 1.25, 0.0), grau)
	for x in [-1.2, -0.4, 0.4, 1.2]:
		_box(gondel, Vector3(0.05, 1.05, 0.05), Vector3(x, 0.52, 0.55), gelb)
	# Eimer in der Gondel
	var eimer := Bau.zylinder(0.17, 0.13, 0.3, Bau.matt("2f7fd6", 0.45), 16)
	eimer.position = Vector3(-1.4, 0.15, 0.2)
	gondel.add_child(eimer)
	cam = Camera3D.new()
	cam.fov = 78.0
	cam.near = 0.03
	cam.far = 40000.0
	cam.position = Vector3(0, AUGE, 0.3)
	gondel.add_child(cam)
	# Hand mit Schwamm
	schwamm = Node3D.new()
	add_child(schwamm)
	_box(schwamm, Vector3(0.24, 0.15, 0.07), Vector3.ZERO, Bau.matt("ffd84a", 0.95))
	_box(schwamm, Vector3(0.24, 0.15, 0.025), Vector3(0, 0, -0.045), Bau.matt("3aa655", 0.9))
	hand = Node3D.new()
	schwamm.add_child(hand)
	var haut := Bau.matt("f1c29b", 0.6)
	var k := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	k.mesh = sm
	k.material_override = haut
	k.position = Vector3(0.02, 0.0, 0.07)
	k.scale = Vector3(1.4, 1.0, 1.0)
	hand.add_child(k)
	arm = Bau.zylinder(0.05, 0.06, 1.0, Bau.matt("3a86d4", 0.85), 12)
	add_child(arm)

func _box(eltern: Node3D, groesse: Vector3, p: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = groesse
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	eltern.add_child(mi)
	return mi

# ---------------------------------------------------------------- Eingaben
func _input(e: InputEvent) -> void:
	if gesperrt:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif e.pressed:
			wischen_start()
		else:
			wischt = false
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if wischt:
			schwamm_off += Vector2(e.relative.x, -e.relative.y) * MAUS_WISCH
			_begrenzen()
		else:
			yaw = wrapf(yaw - e.relative.x * MAUS_LOOK, -PI, PI)   # rundum frei umschauen
			pitch = clampf(pitch - e.relative.y * MAUS_LOOK, -1.5, 1.5)
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		wischt = false

# Putzen beginnt dort, wo das Fadenkreuz auf das Glas zeigt
func wischen_start() -> void:
	wischt = true
	var dir := -cam.global_basis.z
	var nenner := dir.dot(normal)
	if nenner < -0.05:
		var t := (glas_punkt - cam.global_position).dot(normal) / nenner
		var treffer := cam.global_position + dir * t
		schwamm_off = Vector2((treffer - glas_punkt).dot(rechts), treffer.y - y)
	_begrenzen()
	letzter_stempel = Vector2(INF, INF)

func _begrenzen() -> void:
	schwamm_off.x = clampf(schwamm_off.x, -REICH_SEITE, REICH_SEITE)
	schwamm_off.y = clampf(schwamm_off.y, REICH_UNTEN, REICH_OBEN)

# ---------------------------------------------------------------- Ablauf
func _process(dt: float) -> void:
	if not gesperrt:
		var seite := 0.0
		var hoch := 0.0
		if Input.is_key_pressed(KEY_D): seite += 1.0
		if Input.is_key_pressed(KEY_A): seite -= 1.0
		if Input.is_key_pressed(KEY_W): hoch += 1.0
		if Input.is_key_pressed(KEY_S): hoch -= 1.0
		weg += seite * richtung * TEMPO_SEITE * dt
		y = clampf(y + hoch * TEMPO_HOCH * dt, 0.3, max_y)
	_platzieren(dt)
	if wischt:
		_wischen()
	_hand()
	zustand.aktualisieren()

func _platzieren(dt: float) -> void:
	var f := turm.stockwerk_bei(y + 1.2)
	var sprung := false
	if f != stock:
		if not turm.gleicher_grundriss(f, stock):
			# Grundriss ändert sich (Stufe): an die nächstgelegene Stelle der neuen Fassade springen
			weg = turm.naechster_weg(f, Vector2(glas_punkt.x, glas_punkt.z))
			sprung = true
		stock = f
	weg = fposmod(weg, turm.umfaenge[stock])
	var p := turm.fassaden_punkt(stock, weg, y)
	glas_punkt = p.pos
	# Ausrichtung: Mittel der Fassaden-Normalen ±2 m um die Gondel, dann weich hindrehen.
	# So dreht die Gondel an Ecken und Rundungen gleichmäßig statt von Fassadenstück zu Fassadenstück zu springen.
	var ziel_n := Vector3.ZERO
	for o in [-2.0, -1.0, 0.0, 1.0, 2.0]:
		ziel_n += turm.fassaden_punkt(stock, weg + o, y).normal
	ziel_n = ziel_n.normalized() if ziel_n.length() > 0.01 else p.normal
	var ziel_w := atan2(ziel_n.x, ziel_n.z)
	winkel = ziel_w if (dt <= 0.0 or sprung) else lerp_angle(winkel, ziel_w, minf(1.0, dt * 5.0))
	normal = Vector3(sin(winkel), 0.0, cos(winkel))
	gondel.position = glas_punkt + normal * ABSTAND
	gondel.basis = Basis.looking_at(-normal, Vector3.UP)
	rechts = gondel.basis.x
	richtung = 1.0 if p.tangente.dot(rechts) >= 0.0 else -1.0
	cam.rotation = Vector3(pitch, yaw, 0)

# Schwamm-Strich: von der letzten zur aktuellen Position lückenlos stempeln
func _wischen() -> void:
	var ziel := schwamm_off
	if letzter_stempel.x == INF:
		_stempel(ziel)
		letzter_stempel = ziel
		return
	var strecke := letzter_stempel.distance_to(ziel)
	if strecke < schwamm_r * 0.25:
		return
	var schritte := int(ceil(strecke / (schwamm_r * 0.4)))
	for i in range(1, schritte + 1):
		_stempel(letzter_stempel.lerp(ziel, float(i) / schritte))
	letzter_stempel = ziel

func _stempel(o: Vector2) -> void:
	var w := weg + o.x * richtung
	var yw := y + o.y
	var glas_h := Turm.STOCK_H * (1.0 - Turm.BAND_ANTEIL)
	var rx := schwamm_r / Turm.FENSTER_B
	var ry := schwamm_r / glas_h
	var fm := turm.stockwerk_bei(yw)
	for f in [fm - 1, fm, fm + 1]:
		if not turm.gleicher_grundriss(f, stock):
			continue
		var gy: float = ((yw - f * Turm.STOCK_H) - Turm.STOCK_H * Turm.BAND_ANTEIL) / glas_h
		if gy < -ry or gy > 1.0 + ry:
			continue
		var u := fposmod(w, turm.umfaenge[f]) / Turm.FENSTER_B
		var spalte := int(floor(u))
		var lx := u - spalte
		for ds in [-1, 0, 1]:
			var mx: float = lx - ds
			if mx < -rx or mx > 1.0 + rx:
				continue
			if zustand.wische(f, spalte + ds, mx, gy, rx, ry):
				fenster_sauber.emit(f, spalte + ds)

func _hand() -> void:
	var schulter := cam.global_transform * Vector3(0.38, -0.5, 0.1)
	if wischt:
		var p := glas_punkt + rechts * schwamm_off.x + Vector3.UP * schwamm_off.y + normal * 0.07
		schwamm.global_position = p
		schwamm.global_basis = gondel.global_basis
	else:
		schwamm.global_transform = cam.global_transform * Transform3D(Basis.from_euler(Vector3(0.5, -0.35, 0.15)), Vector3(0.42, -0.4, -0.85))
	var hand_p := schwamm.global_transform * Vector3(0.02, 0.0, 0.09)
	var d := hand_p - schulter
	arm.global_position = schulter + d * 0.5
	var yv := d.normalized()
	var xv := yv.cross(Vector3.UP if absf(yv.y) < 0.95 else Vector3.RIGHT).normalized()
	arm.global_basis = Basis(xv, yv * d.length(), xv.cross(yv))

# Mitte eines Fensters in Weltkoordinaten (für Funkeln + Anzeigen)
func fenster_mitte(f: int, spalte: int) -> Vector3:
	var yy := f * Turm.STOCK_H + Turm.STOCK_H * (Turm.BAND_ANTEIL + (1.0 - Turm.BAND_ANTEIL) * 0.5)
	var p := turm.fassaden_punkt(f, (spalte + 0.5) * Turm.FENSTER_B, yy)
	return p.pos + p.normal * 0.15
