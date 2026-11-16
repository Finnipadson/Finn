class_name Strand
extends Node
# Steuert den Strand im Spiel: Stationen (Strandbar, Fischladen, Yacht) für Extras, das Angeln (Angeln) zu Fuß und von
# der Yacht, die Yacht selbst (einsteigen, fahren, anlegen) und den Fischladen (FischMenu).
# Die Gebäude/Geometrie baut Kueste (welt.kueste).

var spiel: Spiel
var w: Wirtschaft
var k: Kueste
var menu: FischMenu
var angeln: Angeln
var yacht: Yacht

func setup(s: Spiel) -> void:
	spiel = s
	w = s.wirtschaft
	k = s.welt.kueste
	menu = FischMenu.new()
	s.add_child(menu)
	menu.setup(w)
	menu.geaendert.connect(func(): s._speichern())
	angeln = Angeln.new()
	s.add_child(angeln)
	angeln.setup(s)
	angeln.gefangen.connect(_gefangen)
	yacht = Yacht.new()
	s.add_child(yacht)
	yacht.setup()

# ---------------------------------------------------------------- Zustand
func blockiert() -> bool:
	return menu.offen or angeln.aktiv() or yacht.an_bord

func ort_name() -> String:
	if yacht.an_bord:
		return "Auf deiner Yacht · %d km/h" % int(absf(yacht.tempo) * 3.6)
	return ""

func stationen() -> Array:
	if yacht.an_bord:
		return []
	var l: Array = []
	for st in k.stationen:
		var c: Dictionary = st.duplicate()
		if c.art == "yacht":
			c.hinweis = "E: an Bord deiner Yacht gehen" if w.yacht else "Yacht „Meeresbrise“ – Belohnung für alle 20 Fische im Index (%d / 20)" % w.fisch_index.size()
		l.append(c)
	return l

# Kann man gerade (zu Fuß oder vom Boot) auswerfen? Gibt das Ziel der Pose zurück oder Vector3.INF
func wurf_ziel() -> Vector3:
	if w.angel() == "" or angeln.aktiv() or menu.offen:
		return Vector3.INF
	if yacht.an_bord:
		return yacht.angel_ziel() if absf(yacht.tempo) < 1.5 else Vector3.INF
	var L := spiel.laeufer
	if not L.aktiv or spiel.spieler.aktiv or spiel.extras.ort != "" or L.hoch > 0.5:
		return Vector3.INF
	var p := Vector2(L.position.x, L.position.z)
	var auf_steg := Kueste.auf_steg(p) and L.position.y > -1.0
	var am_wasser := p.x < Kueste.WASSER_X + 6.0 and L.position.y < -1.0
	if not auf_steg and not am_wasser:
		return Vector3.INF
	var vor := Vector2(-sin(L.yaw), -cos(L.yaw))
	var z := p + vor * 10.0
	if not Kueste.im_meer(z) or not Kueste.im_meer(p + vor * 6.0) and not auf_steg:
		return Vector3.INF
	if auf_steg and Kueste.auf_steg(z):
		return Vector3.INF
	# nicht in die Yacht werfen
	if Rect2(Vector2(Kueste.LIEGEPLATZ.x - Yacht.LANG * 0.5 - 1.0, Kueste.LIEGEPLATZ.z - 3.5), Vector2(Yacht.LANG + 2.0, 7.0)).has_point(z) and yacht.position.distance_to(Kueste.LIEGEPLATZ) < 5.0:
		return Vector3.INF
	return Vector3(z.x, Kueste.MEER_Y + 0.05, z.y)

func status() -> String:
	if menu.offen:
		return ""
	match angeln.zustand:
		"wurf", "warten": return "Warten, bis ein Fisch beißt …  (Rechtsklick, Esc oder Laufen: einholen)"
		"biss": return "Biss!"
		"drill": return "Maustaste gedrückt halten = Kasten hoch · loslassen = Kasten sinkt"
		"fertig": return ""
	if yacht.an_bord:
		if yacht.am_liegeplatz():
			return "E: an Land gehen" + (" · Klick: Angel auswerfen" if wurf_ziel() != Vector3.INF else "")
		if wurf_ziel() != Vector3.INF:
			return "Klick: Angel auswerfen" + (" (weit draußen: seltene Fische beißen öfter)" if yacht.draussen() else "")
		return "Zum Angeln anhalten (S) · E am Liegeplatz: an Land"
	if wurf_ziel() != Vector3.INF:
		return "Klick: Angel auswerfen (%s)" % Wirtschaft.angel_daten(w.angel()).name
	return ""

# ---------------------------------------------------------------- Stationen (E über Extras)
func station(s: Dictionary) -> void:
	match s.art:
		"strandbar":
			spiel.hmenu.oeffnen("strandbar", "Strandbar")
		"fischladen":
			menu.oeffnen()
		"yacht":
			if w.yacht:
				einsteigen()
			else:
				spiel.hud.meldung("Diese Yacht bekommt, wer alle 20 Fische gefangen hat.\nDein Fisch-Index: %d / 20 (B: Album → Fische)" % w.fisch_index.size(), 4.0)

func einsteigen() -> void:
	if angeln.aktiv():
		angeln.einholen()
	yacht.anlegen()
	yacht.an_bord = true
	yacht.blick = 0.45   # leicht seitlich: man sieht das Boot von der Seite
	spiel.laeufer.deaktivieren()
	spiel.laeufer.visible = false
	yacht.cam.current = true
	spiel.hud.hinweis.text = "Yacht: W Gas · S bremsen/rückwärts · A/D lenken · Shift schneller · Maus: umschauen\nStehend: Klick = angeln · E am Liegeplatz: an Land · M: Karte · Esc: Maus frei"
	spiel.hud.meldung("Leinen los! Weit draußen beißen seltene Fische öfter.", 3.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func aussteigen() -> void:
	if angeln.aktiv():
		angeln.einholen()
	yacht.an_bord = false
	yacht.anlegen()
	var st: Vector2 = k.stationen[2].pos
	spiel.laeufer.visible = true
	spiel.laeufer.aktivieren(Vector3(st.x, 0, st.y), 0.0, spiel.spieler.gondel.global_position)
	spiel.laeufer.weitere_gondeln = spiel.gondeln.positionen()
	spiel.hud.steuerung(true)
	spiel.hud.meldung("Die Yacht liegt wieder am Steg.", 2.0)
	spiel._speichern()

# ---------------------------------------------------------------- Eingaben (vor dem Spiel). true = verbraucht
func taste(e: InputEventKey) -> bool:
	if menu.offen:
		if e.keycode == KEY_E or e.keycode == KEY_ESCAPE:
			menu.schliessen()
		return true
	if angeln.aktiv():
		if e.keycode in [KEY_ESCAPE, KEY_E, KEY_S, KEY_W, KEY_A, KEY_D] and angeln.zustand != "drill" and angeln.zustand != "fertig":
			angeln.einholen("Angel eingeholt.")
			return true
		return e.keycode not in [KEY_M, KEY_B, KEY_P]
	if yacht.an_bord:
		match e.keycode:
			KEY_E:
				if yacht.am_liegeplatz():
					aussteigen()
				else:
					spiel.hud.meldung("Zum Aussteigen zurück zum Liegeplatz am Steg (M: Karte).", 2.5)
				return true
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				return true
			KEY_TAB:
				return true   # keine Werkstatt auf dem Wasser
		return false
	return false

func maus(e: InputEvent) -> bool:
	if menu.offen:
		return false
	if e is InputEventMouseMotion:
		if yacht.an_bord and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			yacht.maus(e.relative)
		return false
	if not (e is InputEventMouseButton):
		return false
	var b := e as InputEventMouseButton
	if angeln.aktiv():
		if b.button_index == MOUSE_BUTTON_LEFT:
			angeln.halten = b.pressed
		elif b.button_index == MOUSE_BUTTON_RIGHT and b.pressed and angeln.zustand in ["wurf", "warten"]:
			angeln.einholen("Angel eingeholt.")
		return true
	if b.button_index == MOUSE_BUTTON_LEFT and b.pressed:
		if yacht.an_bord and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var z := wurf_ziel()
		if z != Vector3.INF:
			if yacht.an_bord:
				angeln.werfen(yacht, yacht.angel_xf(), z, yacht.draussen())
			else:
				angeln.werfen(spiel.laeufer.cam, Transform3D(Basis.from_euler(Vector3(-0.95, 0.12, -0.12)), Vector3(0.28, -0.42, -0.45)), z, false)
			return true
		return yacht.an_bord
	return yacht.an_bord and b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]

# ---------------------------------------------------------------- Fang
func _gefangen(_id: String, _laenge: float, neu: bool) -> void:
	if neu and w.index_voll() and not w.yacht:
		w.yacht = true
		spiel.hud.meldung("Alle 20 Fische im Index – Meister-Angler!\nDeine eigene Yacht „Meeresbrise“ liegt jetzt am Ende des Stegs. Mit E an Bord gehen!", 7.0)
	spiel.extras.erfolge_pruefen()
	spiel._speichern()
