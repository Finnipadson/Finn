class_name Spieler
extends Node3D
# Die Gondel mit Ich-Ansicht: an der Fassade entlang fahren (A/D), hoch/runter (W/S), umschauen (Maus),
# putzen: linke Maustaste halten + Maus bewegen → das Werkzeug reibt über das Glas.
# Beim Putzen zusätzlich rechte Maustaste halten → umschauen, das Werkzeug bleibt am Glas.
# Hochdruckreiniger: linke Maustaste halten → putzt dort, wo das Fadenkreuz hinzeigt (Maus schaut weiter um).

signal fenster_sauber(f: int, spalte: int)
signal oben_gesperrt

const ABSTAND := 1.8          # Gondel-Mitte vor dem Glas (m)
const AUGE := 1.65            # Augenhöhe über dem Gondelboden
const TEMPO_SEITE := 1.6      # m/s (ohne Motor-Upgrade)
const TEMPO_HOCH := 1.1       # m/s
const REICH_UNTEN := 0.25     # Höhe über dem Gondelboden
const SPRAY_WEIT := 9.0       # Hochdruckreiniger: maximale Entfernung zum Glas
const MAUS_LOOK := 0.0022
const MAUS_WISCH := 0.0032    # m pro Mauspixel beim Putzen

var turm: Turm
var zustand: FensterZustand
# Werkzeug + Upgrades (werden von außen gesetzt)
var wz_id := "schwamm"
var wz_rx := 0.17
var wz_ry := 0.17
var wz_art := "wisch"
var wz: Dictionary = {}           # ganzes Werkzeug (für Neubau des Modells)
var tempo_faktor := 1.0
var reich_seite := 1.8
var reich_oben := 2.9

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
var rechts_gedrueckt := false  # rechte Maustaste: beim Putzen umschauen statt wischen
var schwamm_off := Vector2(0.2, 1.5)   # (seitlich, Höhe über Gondelboden) auf der Glasebene
var spray_trifft := false
var letzter_stempel := Vector2(INF, INF)
var werkzeug: Node3D          # Modell des Werkzeugs (Schwamm, Abzieher, …)
var strahl: MeshInstance3D    # Wasserstrahl des Hochdruckreinigers
var arm: MeshInstance3D          # Oberarm
var unterarm: MeshInstance3D
var hand: MeshInstance3D
var stange: MeshInstance3D       # Teleskopstange zu Schwamm/Abzieher (die Scheibe ist ~2 m weg)
var stangen_griff: MeshInstance3D
var gelenk: MeshInstance3D
var arm_teile: Node3D
const OBERARM := 0.36
const UNTERARM := 0.36
# Nur Optik (das Putzen selbst rechnet mit schwamm_off): weiche Übergänge Ruhe ↔ Glas, Kippen, Atmen, Rückstoß
var _anlegen := 0.0              # 0 = Ruhe-Pose, 1 = Werkzeug liegt am Glas
var _zielen := 0.0               # Sprüher: 0 = gesenkt, 1 = im Anschlag
var _kipp := 0.0
var _letzt_off := Vector2.ZERO
var _anim_zeit := 0.0
var gesperrt := false         # true = keine Eingaben (Testbilder, Shop offen)
var pause_offen := false      # Pausenmenü offen (im Mehrspieler läuft die Welt weiter – Klicks gehören dann dem Menü)
var wind := 0.0               # 0..1, wird von Ereignisse gesetzt: Gondel schaukelt
var aktiv := true             # false = ausgestiegen, man läuft zu Fuß (Gondel bleibt unten stehen)
var wisch_faktor := 1.0       # Glanzspray: größere Wisch-Fläche
var gondel_mat: StandardMaterial3D
var deko: Node3D
var _zubehoer := []
var arm_mat: StandardMaterial3D
var schwamm_farbe := "ffd84a"
var _gesperrt_zeit := 0.0
var seite := -1                # Turmseite dieser Gondel (-1 = überall)
var mitschreiben := false      # Mehrspieler: Wisch-Stempel sammeln (holt Netz jedes Bild ab)
var stempel_neu := PackedFloat32Array()   # je Stempel 6 Werte: f, spalte, mx, my, rx, ry

func setup(t: Turm, z: FensterZustand, start_stock: int, start_weg: float, oberste_hoehe: float) -> void:
	turm = t
	zustand = z
	stock = start_stock
	weg = start_weg
	y = start_stock * Turm.STOCK_H + 0.3
	max_y = oberste_hoehe
	_bauen()
	werkzeug_setzen(Wirtschaft.WERKZEUGE[0])
	_platzieren(0.0)

# ---------------------------------------------------------------- Modelle
func _bauen() -> void:
	gondel = Node3D.new()
	add_child(gondel)
	gondel_mat = Bau.matt("ffc531", 0.5)
	var grau := Bau.metall("6b7078", 0.4, 0.6)
	GondelDeko.rumpf(gondel, gondel_mat, grau)
	deko = Node3D.new()        # Gondel-Werkstatt: Aufkleber, Blumenkästen, Schirm
	gondel.add_child(deko)
	var eimer := Bau.zylinder(0.17, 0.13, 0.3, Bau.matt("2f7fd6", 0.45), 16)
	eimer.position = Vector3(-1.4, 0.15, 0.2)
	gondel.add_child(eimer)
	cam = Camera3D.new()
	cam.fov = Optionen.fov() + 3.0
	cam.near = 0.03
	cam.far = 40000.0
	cam.position = Vector3(0, AUGE, 0.3)
	gondel.add_child(cam)
	arm_mat = Bau.matt("3a86d4", 0.85)
	arm_teile = Node3D.new()
	add_child(arm_teile)
	arm = Bau.zylinder(0.052, 0.06, 1.0, arm_mat, 12)
	arm_teile.add_child(arm)
	unterarm = Bau.zylinder(0.042, 0.05, 1.0, arm_mat, 12)
	arm_teile.add_child(unterarm)
	hand = MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.047
	hm.height = 0.094
	hand.mesh = hm
	hand.material_override = Bau.matt("f1c29b", 0.6)
	arm_teile.add_child(hand)
	stange = Bau.zylinder(0.014, 0.014, 1.0, Bau.metall("c9ced4", 0.3, 0.8), 8)
	arm_teile.add_child(stange)
	stangen_griff = Bau.zylinder(0.024, 0.024, 1.0, Bau.matt("2b2b2b", 0.85), 10)
	arm_teile.add_child(stangen_griff)
	gelenk = MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 0.028
	gm.height = 0.056
	gelenk.mesh = gm
	gelenk.material_override = Bau.matt("33363d", 0.6)
	arm_teile.add_child(gelenk)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.85, 0.95, 1.0, 0.55)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.emission_enabled = true
	sm.emission = Color(0.6, 0.85, 1.0)
	sm.emission_energy_multiplier = 0.4
	strahl = Bau.zylinder(0.012, 0.03, 1.0, sm, 8)
	strahl.visible = false
	add_child(strahl)

func _box(eltern: Node3D, groesse: Vector3, p: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = groesse
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	eltern.add_child(mi)
	return mi

# Werkzeug wechseln: Größe/Art übernehmen und Modell neu bauen
func werkzeug_setzen(w: Dictionary) -> void:
	wz_id = w.id
	wz_rx = w.rx
	wz_ry = w.ry
	wz_art = w.art
	wischt = false
	if werkzeug:
		werkzeug.queue_free()
	wz = w
	werkzeug = werkzeug_modell(w, schwamm_farbe)
	add_child(werkzeug)
	if werkzeug.has_node("stiel"):
		(werkzeug.get_node("stiel") as Node3D).visible = false   # die Teleskopstange ersetzt den kurzen Stiel
	_anlegen = 0.0
	_zielen = 0.0
	_kipp = 0.0

# Modell eines Werkzeugs (ohne Hand) – auch für die Bilder in Hotbar und Menüs (Symbole)
static func werkzeug_modell(w: Dictionary, schwamm_farbe := "ffd84a") -> Node3D:
	var n := Node3D.new()
	match str(w.get("modell", "schwamm")):
		"schwamm":
			var s: float = w.get("groesse", 1.0)
			var farbe: String = w.get("farbe", schwamm_farbe) if w.has("farbe") else schwamm_farbe
			_sbox(n, Vector3(0.24, 0.15, 0.07) * s, Vector3.ZERO, Bau.matt(farbe, 0.95))
			_sbox(n, Vector3(0.24 * s, 0.15 * s, 0.025), Vector3(0, 0, -0.045 * s), Bau.matt("3aa655", 0.9))
			_marke(n, "ansatz", Vector3(0, 0, 0.035 * s))   # hier sitzt die Teleskopstange
		"abzieher":
			var breit: float = float(w.rx) * 2.0
			var gummi := Bau.matt("2b2b2b", 0.7)
			var alu := Bau.metall("c9ced4", 0.3, 0.8)
			_sbox(n, Vector3(breit, 0.05, 0.03), Vector3(0, 0, -0.03), gummi)
			_sbox(n, Vector3(breit, 0.07, 0.03), Vector3(0, 0.02, 0.0), alu)
			if w.get("doppel", false):
				_sbox(n, Vector3(breit, 0.05, 0.03), Vector3(0, 0.16, -0.03), gummi)
				_sbox(n, Vector3(breit, 0.07, 0.03), Vector3(0, 0.18, 0.0), alu)
			var stiel := Bau.zylinder(0.022, 0.022, 0.3, Bau.matt("e2483e", 0.6), 10)
			stiel.rotation.x = PI / 2.0
			stiel.position = Vector3(0, 0.05, 0.17)
			stiel.name = "stiel"   # an der Stange ausgeblendet (die Stange ersetzt den Stiel)
			n.add_child(stiel)
			_marke(n, "ansatz", Vector3(0, 0.09 if w.get("doppel", false) else 0.02, 0.015))
		"spray":
			var g: float = w.get("groesse", 1.0)
			var koerper: String = {"hochdruck": "ffc531", "dampf": "e2483e", "lanze": "3a86d4"}.get(w.id, "ffc531")
			_sbox(n, Vector3(0.06, 0.1, 0.2) * g, Vector3(0, 0, 0.05), Bau.matt(koerper, 0.5))
			var rohr := Bau.zylinder(0.018, 0.022, 0.45, Bau.metall("3b3f46", 0.4, 0.6), 10)
			rohr.rotation.x = PI / 2.0
			rohr.position = Vector3(0, 0.03, -0.3)
			n.add_child(rohr)
			var duese := Node3D.new()
			duese.name = "duese"
			duese.position = Vector3(0, 0.03, -0.53)
			n.add_child(duese)
			_sbox(n, Vector3(0.04, 0.1, 0.05), Vector3(0, -0.09, 0.1), Bau.matt("33363d", 0.6))
			_marke(n, "griff", Vector3(0, -0.08, 0.1))
	return n

static func _marke(eltern: Node3D, name: String, p: Vector3) -> void:
	var m := Node3D.new()
	m.name = name
	m.position = p
	eltern.add_child(m)

static func _sbox(eltern: Node3D, groesse: Vector3, p: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = groesse
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	eltern.add_child(mi)

# Aussehen vom Händler „Mode & Farben“ (nur Optik)
func aussehen(gondel_hex: String, kleidung_hex: String, schwamm_hex: String, lack := "lack_uni", zubehoer := []) -> void:
	GondelDeko.lack(gondel_mat, gondel_hex, lack)
	if zubehoer.size() >= 3 and zubehoer != _zubehoer:
		_zubehoer = zubehoer.duplicate()
		GondelDeko.zubehoer(deko, zubehoer[0], zubehoer[1], zubehoer[2], zubehoer[3] if zubehoer.size() > 3 else "gradio_keins")
	arm_mat.albedo_color = Color(kleidung_hex)
	if schwamm_hex != schwamm_farbe:
		schwamm_farbe = schwamm_hex
		werkzeug_setzen(wz)

# ---------------------------------------------------------------- Eingaben
func _input(e: InputEvent) -> void:
	if gesperrt or not aktiv or pause_offen:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT:
		rechts_gedrueckt = e.pressed
		if not e.pressed:
			letzter_stempel = Vector2(INF, INF)   # nach dem Umschauen neu ansetzen, keine Linie quer übers Glas
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif e.pressed:
			wischen_start()
		else:
			wischt = false
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if wischt and wz_art == "wisch" and not rechts_gedrueckt:
			schwamm_off += Vector2(e.relative.x, -e.relative.y) * MAUS_WISCH
			_begrenzen()
		else:
			yaw = wrapf(yaw - e.relative.x * MAUS_LOOK * Optionen.maus_x(), -PI, PI)   # rundum frei umschauen
			pitch = clampf(pitch - e.relative.y * MAUS_LOOK * Optionen.maus_y(), -1.5, 1.5)
	elif e is InputEventKey and e.pressed and Optionen.k(e) == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		wischt = false

# Wo trifft das Fadenkreuz die Glasebene vor der Gondel? (Vector2(INF) = gar nicht)
func fadenkreuz_ziel(max_weit: float) -> Vector2:
	var dir := -cam.global_basis.z
	var nenner := dir.dot(normal)
	if nenner > -0.05:
		return Vector2(INF, INF)
	var t := (glas_punkt - cam.global_position).dot(normal) / nenner
	if t > max_weit:
		return Vector2(INF, INF)
	var treffer := cam.global_position + dir * t
	return Vector2((treffer - glas_punkt).dot(rechts), treffer.y - y)

# Putzen beginnt dort, wo das Fadenkreuz auf das Glas zeigt
func wischen_start() -> void:
	wischt = true
	letzter_stempel = Vector2(INF, INF)
	if wz_art == "wisch":
		var z := fadenkreuz_ziel(50.0)
		if z.x != INF:
			schwamm_off = z
		_begrenzen()

func _begrenzen() -> void:
	schwamm_off.x = clampf(schwamm_off.x, -reich_seite, reich_seite)
	schwamm_off.y = clampf(schwamm_off.y, REICH_UNTEN, reich_oben)

# ---------------------------------------------------------------- Ablauf
func _process(dt: float) -> void:
	_gesperrt_zeit = maxf(0.0, _gesperrt_zeit - dt)
	if not gesperrt and aktiv and not pause_offen:
		var seite := 0.0
		var hoch := 0.0
		if Optionen.gedrueckt(KEY_D): seite += 1.0
		if Optionen.gedrueckt(KEY_A): seite -= 1.0
		if Optionen.gedrueckt(KEY_W): hoch += 1.0
		if Optionen.gedrueckt(KEY_S): hoch -= 1.0
		weg += seite * richtung * TEMPO_SEITE * tempo_faktor * dt
		var neu := y + hoch * TEMPO_HOCH * tempo_faktor * dt
		if hoch > 0.0 and neu > max_y and _gesperrt_zeit <= 0.0:
			oben_gesperrt.emit()
			_gesperrt_zeit = 3.0
		y = clampf(neu, 0.3, max_y)
	if aktiv and wischt and wz_art == "wisch" and not rechts_gedrueckt and Optionen.wert("kamera_folgt"):
		_kamera_folgen(dt)
	_platzieren(dt)
	spray_trifft = false
	if wischt:
		if wz_art == "spray":
			var z := fadenkreuz_ziel(SPRAY_WEIT)
			if z.x != INF and absf(z.x) < 8.0 and z.y > -3.0 and z.y < 8.0:
				spray_trifft = true
				schwamm_off = z
				_wischen()
			else:
				letzter_stempel = Vector2(INF, INF)
		else:
			_wischen()
	werkzeug.visible = aktiv
	arm_teile.visible = aktiv
	if not aktiv:
		wischt = false
		strahl.visible = false
	else:
		_hand(dt)
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
	if seite >= 0:   # jede Gondel bleibt auf ihrer Turmseite
		weg = turm.weg_auf_seite(stock, weg, seite)
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
	# Wind: Gondel schaukelt seitlich und ein wenig vor und zurück, Kamera kippt leicht
	var zeit := Time.get_ticks_msec() / 1000.0
	if wind > 0.001:
		gondel.position += rechts * sin(zeit * 1.3) * 0.3 * wind + normal * sin(zeit * 0.8) * 0.12 * wind
		gondel.rotate_object_local(Vector3.FORWARD, sin(zeit * 1.1) * 0.04 * wind)
	cam.rotation = Vector3(pitch, yaw, 0)

# Beim Putzen: kommt das Werkzeug an den Bildrand, schwenkt der Blick weich hinterher (Mitte = ruhige Zone,
# damit Hin-und-her-Reiben das Bild nicht wackeln lässt). Ändert nur yaw/pitch, nicht das Wischen.
const FOLGEN_ZONE := 0.5      # Anteil des halben Sichtfelds, in dem die Kamera still bleibt
const FOLGEN_TEMPO := 5.0
func _kamera_folgen(dt: float) -> void:
	var ziel := glas_punkt + rechts * schwamm_off.x + Vector3.UP * schwamm_off.y
	var d := gondel.global_basis.inverse() * (ziel - cam.global_position)
	var ziel_yaw := atan2(-d.x, -d.z)
	var ziel_pitch := atan2(d.y, Vector2(d.x, d.z).length())
	var halb_v := deg_to_rad(cam.fov) * 0.5
	var sicht := get_viewport().get_visible_rect().size
	var halb_h := atan(tan(halb_v) * sicht.x / maxf(sicht.y, 1.0))
	var k := minf(1.0, dt * FOLGEN_TEMPO)
	var dy := wrapf(ziel_yaw - yaw, -PI, PI)
	var zone_h := halb_h * FOLGEN_ZONE
	if absf(dy) > zone_h:
		yaw = wrapf(yaw + (dy - signf(dy) * zone_h) * k, -PI, PI)
	var dp := ziel_pitch - pitch
	var zone_v := halb_v * FOLGEN_ZONE
	if absf(dp) > zone_v:
		pitch = clampf(pitch + (dp - signf(dp) * zone_v) * k, -1.5, 1.5)

# Strich: von der letzten zur aktuellen Position lückenlos stempeln
func _wischen() -> void:
	var ziel := schwamm_off
	if letzter_stempel.x == INF:
		_stempel(ziel)
		letzter_stempel = ziel
		return
	var klein := minf(wz_rx, wz_ry)
	var strecke := letzter_stempel.distance_to(ziel)
	if strecke < klein * 0.25:
		return
	var schritte := mini(int(ceil(strecke / (klein * 0.4))), 60)
	for i in range(1, schritte + 1):
		_stempel(letzter_stempel.lerp(ziel, float(i) / schritte))
	letzter_stempel = ziel

func _stempel(o: Vector2) -> void:
	if wind > 0.001:   # bei Wind wird das Putzen etwas ungenauer
		var zeit := Time.get_ticks_msec() / 1000.0
		o += Vector2(sin(zeit * 9.0), cos(zeit * 7.0)) * Vector2(0.05, 0.035) * wind
	var w := weg + o.x * richtung
	var yw := y + o.y
	var glas_h := Turm.STOCK_H * (1.0 - Turm.BAND_ANTEIL)
	var rx := wz_rx * wisch_faktor / Turm.FENSTER_B
	var ry := wz_ry * wisch_faktor / glas_h
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
		var weit := int(ceil(rx)) + 1
		for ds in range(-weit, weit + 1):
			var mx: float = lx - ds
			if mx < -rx or mx > 1.0 + rx:
				continue
			if mitschreiben:   # Mehrspieler: Stempel gehen an die anderen (Netz.stempel)
				stempel_neu.append_array([f, spalte + ds, mx, gy, rx, ry])
			if zustand.wische(f, spalte + ds, mx, gy, rx, ry):
				fenster_sauber.emit(f, spalte + ds)

# Arm (Schulter → Ellbogen → Hand) + Werkzeug. Schwamm und Abzieher sitzen auf einer Teleskopstange: die Hand bleibt
# vor dem Körper, die Stange fährt beim Ansetzen aus bis an die Scheibe. Alles nur Optik.
func _hand(dt: float) -> void:
	_anim_zeit += dt
	var ct := cam.global_transform
	var schulter := ct * Vector3(0.3, -0.4, 0.04)
	var knick := ct.basis * Vector3(0.75, -0.6, 0.25)   # Ellbogen zeigt nach außen unten
	strahl.visible = false
	var atem := sin(_anim_zeit * 1.7) * 0.006
	var griff_p: Vector3
	if wz_art == "spray":
		stange.visible = false
		stangen_griff.visible = false
		gelenk.visible = false
		_zielen = move_toward(_zielen, 1.0 if wischt else 0.0, dt * 7.0)
		var z := smoothstep(0.0, 1.0, _zielen)
		var rueck := 0.0
		if spray_trifft:   # Rückstoß: das Gerät zittert leicht nach hinten
			rueck = (sin(_anim_zeit * 47.0) * 0.5 + 0.5) * 0.014 + (sin(_anim_zeit * 31.0) * 0.004)
		var ruhe := Transform3D(Basis.from_euler(Vector3(-0.3, 0.3, 0.12)), Vector3(0.38, -0.44 + atem, -0.6))
		var anschlag := Transform3D(Basis.from_euler(Vector3(0.05, 0.08, 0.0)), Vector3(0.34, -0.3, -0.7 + rueck))
		werkzeug.global_transform = ct * ruhe.interpolate_with(anschlag, z)
		if spray_trifft:
			var duese: Node3D = werkzeug.get_node("duese")
			var a := duese.global_position
			var b := glas_punkt + rechts * schwamm_off.x + Vector3.UP * schwamm_off.y
			zwischen(strahl, a, b)
			strahl.visible = true
		griff_p = (werkzeug.get_node("griff") as Node3D).global_position
		_griff_drehen(werkzeug.global_basis * Vector3.FORWARD)
	else:
		var am_glas := wischt
		var ist_abzieher: bool = wz.get("modell", "") == "abzieher"
		_anlegen = move_toward(_anlegen, 1.0 if am_glas else 0.0, dt * 9.0)
		var b := smoothstep(0.0, 1.0, _anlegen)
		# leichtes Kippen mit der Wischrichtung (Schwamm stärker, Abzieher kaum)
		var kipp_ziel := 0.0
		if am_glas and dt > 0.0 and _anlegen > 0.5:   # nicht beim Ansetzen (Sprung zum Fadenkreuz)
			var tempo := (schwamm_off - _letzt_off) / dt
			var st := 0.015 if ist_abzieher else 0.05
			kipp_ziel = clampf(-tempo.x * st, -0.16, 0.16)
		_letzt_off = schwamm_off
		_kipp = lerpf(_kipp, kipp_ziel, minf(1.0, dt * 8.0))
		var glas := Transform3D(gondel.global_basis * Basis(Vector3.BACK, _kipp),
			glas_punkt + rechts * schwamm_off.x + Vector3.UP * schwamm_off.y + normal * 0.07)
		# Ruhe: Stange eingefahren, Werkzeug schräg vor dem Körper (Abzieher hochkant, damit die lange Lippe nicht die Sicht versperrt)
		var ruhe := ct * (Transform3D(Basis.from_euler(Vector3(0.4, -0.45, 1.15)), Vector3(0.55, -0.32 + atem, -1.0)) if ist_abzieher
			else Transform3D(Basis.from_euler(Vector3(0.55, -0.3, 0.12)), Vector3(0.5, -0.3 + atem, -1.0)))
		werkzeug.global_transform = ruhe.interpolate_with(glas, b)
		var ansatz := (werkzeug.get_node("ansatz") as Node3D).global_position
		# Hand: vor dem Körper, ein Stück in Richtung Werkzeug gezogen, höchstens eine Armlänge weit
		var g0 := ct * Vector3(0.2, -0.34 + atem, -0.5)
		griff_p = g0 + (ansatz - g0).normalized() * 0.12
		var reich := OBERARM + UNTERARM - 0.02
		if griff_p.distance_to(schulter) > reich:
			griff_p = schulter + (griff_p - schulter).normalized() * reich
		var r := (ansatz - griff_p).normalized()
		zwischen(stange, griff_p - r * 0.22, ansatz)
		zwischen(stangen_griff, griff_p - r * 0.2, griff_p + r * 0.12)
		gelenk.global_position = ansatz
		stange.visible = true
		stangen_griff.visible = true
		gelenk.visible = true
		_griff_drehen(r)
	hand.global_position = griff_p
	_arm_setzen(schulter, griff_p, knick)

# Faust um den Griff: etwas länglich quer zur Greifrichtung
func _griff_drehen(r: Vector3) -> void:
	var oben := Vector3.UP if absf(r.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	hand.global_basis = Basis.looking_at(r, oben).scaled_local(Vector3(1.15, 1.0, 1.35))

# Zwei-Knochen-Arm: Ellbogen so, dass Ober- und Unterarm genau reichen, Knick zur Seite „knick“
func _arm_setzen(s: Vector3, h: Vector3, knick: Vector3) -> void:
	var d := h - s
	var l := clampf(d.length(), 0.05, OBERARM + UNTERARM - 0.001)
	var dir := d.normalized()
	var a := (OBERARM * OBERARM - UNTERARM * UNTERARM + l * l) / (2.0 * l)
	var hoch := sqrt(maxf(OBERARM * OBERARM - a * a, 0.0))
	var seit := knick - dir * knick.dot(dir)
	seit = seit.normalized() if seit.length() > 0.001 else Vector3.DOWN
	var ell := s + dir * a + seit * hoch
	zwischen(arm, s, ell)
	zwischen(unterarm, ell, s + dir * l)

static func zwischen(mi: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	mi.global_position = a + d * 0.5
	var yv := d.normalized()
	var xv := yv.cross(Vector3.UP if absf(yv.y) < 0.95 else Vector3.RIGHT).normalized()
	mi.global_basis = Basis(xv, yv * maxf(d.length(), 0.01), xv.cross(yv))

# Mitte eines Fensters in Weltkoordinaten (für Funkeln + Anzeigen)
func fenster_mitte(f: int, spalte: int) -> Vector3:
	var yy := f * Turm.STOCK_H + Turm.STOCK_H * (Turm.BAND_ANTEIL + (1.0 - Turm.BAND_ANTEIL) * 0.5)
	var p := turm.fassaden_punkt(f, (spalte + 0.5) * Turm.FENSTER_B, yy)
	return p.pos + p.normal * 0.15
