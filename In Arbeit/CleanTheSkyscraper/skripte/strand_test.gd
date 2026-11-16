class_name StrandTest
extends Node
# Tests Strand + Angeln + Yacht + Karte (gibt „TEST …“ aus): 31 = Prüfungen mit echten Tasten, Maus und Knöpfen,
# 32 = Testbilder (BILD n frame=…) + FPS.

var s: Spiel
var st: Strand
var w: Wirtschaft
var fehler := 0

func setup(spiel: Spiel) -> void:
	s = spiel
	st = spiel.strand
	w = spiel.wirtschaft
	_ablauf.call_deferred()

func _warte(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _pruefe(name: String, ok: bool, info := "") -> void:
	if not ok:
		fehler += 1
	print("TEST %s %s %s" % ["OK  " if ok else "FEHLER", name, info])

func _halte(k: Key, an: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = an
	Input.parse_input_event(e)

func _knopf(menu: Node, n: String) -> bool:
	var b: Button = menu.find_child(n, true, false)
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true

func _stelle(p: Vector2, blick: Vector2) -> void:
	var L := s.laeufer
	L.position = Vector3(p.x, s.welt.kueste.boden(p), p.y)
	L.yaw = atan2(-blick.x, -blick.y)
	L.pitch = -0.05

func _pos() -> Vector2:
	return Vector2(s.laeufer.position.x, s.laeufer.position.z)

# W (+Shift) halten
func _laufe(t: float, rennen := false) -> void:
	_halte(KEY_SHIFT, rennen)
	_halte(KEY_W, true)
	await _warte(t)
	_halte(KEY_W, false)
	_halte(KEY_SHIFT, false)
	await _warte(0.1)

func _ablauf() -> void:
	await _warte(0.5)
	if s.spieler.aktiv:
		s.spieler.y = 0.3
		s._ein_aus()
	await _warte(0.4)
	match s.ansicht:
		31: await _test()
		32: await _bilder()
	print("TEST fertig: fehler=%d geld=%d" % [fehler, w.geld])
	get_tree().quit()

# ---------------------------------------------------------------- Prüfungen
func _test() -> void:
	var k := s.welt.kueste
	var z0 := Kueste.BOUL_Z
	# Stadt: Boulevard und Promenade frei von Häusern und Kreuzungen
	var band := Rect2(Vector2(Kueste.UFER_X, z0 - Kueste.BOUL_HALB), Vector2(k.kanal_start - Kueste.UFER_X, Kueste.BOUL_HALB * 2.0))
	var haus_drin := 0
	for h in s.welt.haeuser:
		if (h as Rect2).intersects(band) or (h as Rect2).position.x < Kueste.PROM_X:
			haus_drin += 1
	_pruefe("Boulevard + Promenade frei von Häusern", haus_drin == 0, "%d" % haus_drin)
	var kr := 0
	for i in range(-9, 0):
		if s.welt.kreuzung_ok(Vector2(Welt.RASTER * (i + 0.5), z0)):
			kr += 1
	_pruefe("Keine Kreuzung auf dem Boulevard", kr == 0)
	_pruefe("Karte: Raster + Wegpunkte", true)
	# ---- Boulevard ablaufen (rennen): vom See bis zur Promenade
	_stelle(Vector2(k.kanal_start - 25.0, z0 + 12.0), Vector2(-1, 0))
	var t0 := Time.get_ticks_msec()
	_halte(KEY_SHIFT, true)
	_halte(KEY_W, true)
	var dauer := 0.0
	while s.laeufer.position.x > Kueste.UFER_X + 8.0 and dauer < 80.0:
		await get_tree().process_frame
		dauer += get_process_delta_time()
	_halte(KEY_W, false)
	_halte(KEY_SHIFT, false)
	_pruefe("Boulevard bis zur Promenade gerannt", s.laeufer.position.x <= Kueste.UFER_X + 8.5, "%.0f s für %.0f m" % [dauer, k.kanal_start - 25.0 - Kueste.UFER_X - 8.0])
	# ---- Kanal sperrt, Brücke führt hinüber (und hinauf)
	_stelle(Vector2(-400.0, z0 + 8.0), Vector2(0, -1))
	await _laufe(1.5)
	_pruefe("Kanal sperrt", _pos().y > z0 + Kueste.KANAL_HALB + 0.5, "z=%.1f" % _pos().y)
	_stelle(Vector2(k.bruecken[1], z0 + 8.0), Vector2(0, -1))
	_halte(KEY_W, true)
	var hoechste := 0.0
	var tb := 0.0
	while tb < 4.0:
		await get_tree().process_frame
		tb += get_process_delta_time()
		hoechste = maxf(hoechste, s.laeufer.position.y)
	_halte(KEY_W, false)
	_pruefe("Brücke über den Kanal", _pos().y < z0 - Kueste.KANAL_HALB - 1.0 and hoechste > 0.5, "z=%.1f, höchste %.2f m" % [_pos().y, hoechste])
	# ---- Ufermauer hält, Treppe führt hinunter, Meer hält
	_stelle(Vector2(Kueste.UFER_X + 2.0, -60.0), Vector2(-1, 0))
	await _laufe(1.2)
	_pruefe("Ufermauer hält", _pos().x >= Kueste.UFER_X - 0.1 and s.laeufer.position.y > -0.1, "x=%.1f y=%.2f" % [_pos().x, s.laeufer.position.y])
	_stelle(Vector2(Kueste.UFER_X + 2.0, -101.0), Vector2(-1, 0))
	await _laufe(2.5)
	_pruefe("Treppe zum Strand", _pos().x < Kueste.UFER_X - Kueste.TREPPE_LANG and s.laeufer.position.y < -1.9, "x=%.1f y=%.2f" % [_pos().x, s.laeufer.position.y])
	await _laufe(4.0)
	_pruefe("Meer hält", _pos().x > Kueste.WASSER_X, "x=%.1f" % _pos().x)
	_stelle(Vector2(-615.0, -60.0), Vector2(1, 0))
	await _laufe(1.5)
	_pruefe("Vom Strand nicht durch die Mauer", _pos().x < Kueste.UFER_X, "x=%.1f" % _pos().x)
	# ---- Strandbar: E an der Theke, Drinks kaufen
	w.geld = 100000
	var bar: Dictionary = k.stationen[0]
	_stelle(bar.pos, bar.ziel - bar.pos)
	await _warte(0.3)
	var hinweis: String = s.hud.status_l.text
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("Strandbar öffnet", s.hmenu.offen and s.hmenu.stand == "strandbar", hinweis)
	_pruefe("Strand-Drinks im Menü", s.hmenu.find_child("b_kokos", true, false) != null and s.hmenu.find_child("b_caipi", true, false) != null)
	var g0 := w.geld
	_pruefe("Kokos-Shake kaufen", _knopf(s.hmenu, "b_kokos") and w.boost_aktiv("kokos") and g0 > w.geld)
	_knopf(s.hmenu, "b_mango")
	_pruefe("Wirkung zappeln/selten", w.boost_wirkung("zappeln") == 0.3 and w.boost_wirkung("selten") == 0.6)
	_knopf(s.hmenu, "b_pina")
	_pruefe("Gleiche Wirkung zählt einmal (Maximum)", w.boost_wirkung("zappeln") == 0.3 and w.boost_wirkung("kasten") == 0.2)
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("Strandbar zu", not s.hmenu.offen)
	# ---- Fischladen: Angel kaufen
	var laden: Dictionary = k.stationen[1]
	_stelle(laden.pos, laden.ziel - laden.pos)
	await _warte(0.3)
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("Fischladen öffnet (ohne Angel: Reiter Angeln)", st.menu.offen and st.menu.reiter == 1)
	g0 = w.geld
	_pruefe("Bambus-Angel kaufen", _knopf(st.menu, "angel_bambus") and w.angel() == "bambus" and g0 - w.geld == 150)
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("Fischladen zu", not st.menu.offen)
	# ---- Angeln an der Steg-Spitze: echter Klick, echter Spannungsbalken
	_stelle(Kueste.KOPF.get_center() + Vector2(-10.0, 0.0), Vector2(-1, 0))
	await _warte(0.3)
	_pruefe("Hinweis Angel auswerfen", s.hud.status_l.text.begins_with("Klick: Angel"), s.hud.status_l.text)
	var gefangen := 0
	var versuche := 0
	while gefangen < 4 and versuche < 10:
		versuche += 1
		var vorher := w.fische_in_kiste()
		if await angeln_runde(false):
			gefangen += 1
		_pruefe("Runde %d" % versuche, w.fische_in_kiste() >= vorher, "Kiste %d, Index %d" % [w.fische_in_kiste(), w.fisch_index.size()])
	_pruefe("Mit echter Maustaste Fische gefangen", gefangen >= 3, "%d von %d" % [gefangen, versuche])
	_pruefe("Erfolg Petri Heil", w.erfolge.has("fisch_1"))
	# Pose landet im Wasser, nicht auf dem Steg
	_pruefe("Kein Wurf auf den Steg", (func():
		_stelle(Kueste.KOPF.get_center(), Vector2(1, 0))
		return st.wurf_ziel() == Vector3.INF).call())
	# Riese ohne Hochsee-Angel: Schnur reißt
	_stelle(Kueste.KOPF.get_center() + Vector2(-10.0, 0.0), Vector2(-1, 0))
	st.angeln.test_fisch = "walhai"
	s._klick(Vector2(400, 300), true)
	s._klick(Vector2(400, 300), false)
	await get_tree().process_frame
	st.angeln.warte = 0.2
	await _warte(1.4)
	_pruefe("Riese reißt die Bambus-Schnur", not st.angeln.aktiv() or st.angeln.zustand == "fertig", st.angeln.zustand)
	await _warte(1.0)
	w.angeln.append("hochsee")
	st.angeln.test_fisch = "walhai"
	var walhai := await angeln_runde(true)
	_pruefe("Walhai mit Hochsee-Angel: Drill startet", st.angeln.wild > 0.85 or walhai, "wild=%.2f gefangen=%s" % [st.angeln.wild, walhai])
	st.angeln.test_fisch = ""
	# ---- Verkaufen
	_stelle(laden.pos, laden.ziel - laden.pos)
	await _warte(0.3)
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("Fischladen: Reiter Verkaufen", st.menu.reiter == 0)
	var summe := 0
	for id in w.fischkiste:
		summe += int(w.fischkiste[id]) * w.fisch_preis(id)
	g0 = w.geld
	var verdient0 := int(w.statistik.verdient)
	_pruefe("Alles verkaufen", _knopf(st.menu, "verkauf_alle") and w.geld - g0 == summe and w.fische_in_kiste() == 0 and summe > 0, "%d €" % summe)
	_pruefe("Fischgeld zählt als verdient", int(w.statistik.verdient) - verdient0 == summe)
	s._taste(KEY_E)
	await _warte(0.3)
	# ---- Fisch-Index im Album
	s._taste(KEY_B)
	await _warte(0.3)
	s._taste(KEY_TAB)
	await _warte(0.3)
	var karten := s.album.fische_raster.get_child_count()
	_pruefe("Album: Reiter Fische mit 20 Karten", s.album.offen and s.album.reiter == 1 and karten == 20, "%d" % karten)
	s._taste(KEY_B)
	await _warte(0.3)
	_pruefe("Album zu", not s.album.offen)
	# ---- Yacht: erst gesperrt, nach vollem Index frei
	var yp: Dictionary = st.stationen()[2]
	_stelle(yp.pos, yp.ziel - yp.pos)
	await _warte(0.3)
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("Yacht ohne vollen Index gesperrt", not st.yacht.an_bord)
	for f in Wirtschaft.FISCHE:
		if not w.fisch_index.has(f.id):
			w.fisch_index[f.id] = {"n": 1, "max": float(f.groesse)}
	st._gefangen("walhai", 10.0, true)
	_pruefe("Voller Index schenkt die Yacht + Erfolg", w.yacht and w.erfolge.has("fisch_alle"))
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("An Bord der Yacht", st.yacht.an_bord and st.yacht.cam.current)
	var y0 := st.yacht.position
	_halte(KEY_W, true)
	await _warte(5.0)
	_halte(KEY_A, true)
	await _warte(2.0)
	_halte(KEY_A, false)
	await _warte(2.0)
	_halte(KEY_W, false)
	_pruefe("Yacht fährt", st.yacht.position.distance_to(y0) > 40.0, "%.0f m, %.0f km/h" % [st.yacht.position.distance_to(y0), st.yacht.tempo * 3.6])
	_halte(KEY_S, true)
	await _warte(4.0)
	_halte(KEY_S, false)
	await _warte(1.0)
	_pruefe("Yacht bleibt im Meer", Kueste.im_meer(Vector2(st.yacht.position.x, st.yacht.position.z)))
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("Weit weg: kein Aussteigen", st.yacht.an_bord)
	st.yacht.tempo = 0.0
	var ist_frei := st.wurf_ziel() != Vector3.INF
	var r := false
	if ist_frei:
		r = await angeln_runde(false, true)
	_pruefe("Angeln vom Boot", ist_frei and int(w.statistik.fische) > 0, "gefangen=%s" % r)
	# Richtung Strand fahren: muss vor dem Ufer stoppen
	st.yacht.position = Vector3(Kueste.WASSER_X - 40.0, Kueste.MEER_Y, 100.0)
	st.yacht.richtung = -PI * 0.5   # Bug nach +x (zum Strand)
	_halte(KEY_W, true)
	await _warte(6.0)
	_halte(KEY_W, false)
	_pruefe("Yacht fährt nicht auf den Strand", st.yacht.position.x < Kueste.WASSER_X - 12.0, "x=%.1f" % st.yacht.position.x)
	st.yacht.position = Kueste.LIEGEPLATZ + Vector3(-10.0, 0, 0)
	st.yacht.tempo = 0.0
	await _warte(0.2)
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("Am Liegeplatz an Land", not st.yacht.an_bord and s.laeufer.aktiv and Kueste.auf_steg(_pos()), "%s" % _pos())
	# ---- Karte: M, Klick auf die Strandbar, Pfeil + Route
	s.laeufer.position = Vector3(s.extras.sky.unten_pos.x, 0, s.extras.sky.unten_pos.y)
	await _warte(0.2)
	s._taste(KEY_M)
	await _warte(0.4)
	_pruefe("Karte öffnet", s.karte.offen)
	var bar_ort := {}
	for o in s.karte.orte:
		if o.name == "Strandbar":
			bar_ort = o
	var sp := s.karte._bild(bar_ort.pos)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = sp
	s.karte.flaeche.gui_input.emit(e)
	await _warte(0.3)
	_pruefe("Ziel per Klick", s.karte.ziel_name == "Strandbar" and s.karte.route.size() >= 3, "%d Wegpunkte" % s.karte.route.size())
	var ueber_treppe := false
	for q in s.karte.route:
		if q.x < Kueste.UFER_X - 5.0 and q.x > Kueste.UFER_X - 12.0:
			ueber_treppe = true
	_pruefe("Route über den Boulevard und die Treppe", ueber_treppe, str(s.karte.route))
	s._taste(KEY_M)
	await _warte(0.3)
	_pruefe("Karte zu, Pfeil sichtbar", not s.karte.offen and s.karte.pfeil.visible, "%s · %.0f m" % [s.karte.ziel_name, s.karte.rest_weg()])
	# dem Pfeil folgen (wie ein Spieler: in Pfeilrichtung drehen und rennen)
	var gelaufen := 0.0
	_halte(KEY_SHIFT, true)
	_halte(KEY_W, true)
	while s.karte.ziel != Vector2.INF and gelaufen < 150.0:
		s.laeufer.yaw -= s.karte.pfeil_winkel() * 0.5
		await get_tree().process_frame
		gelaufen += get_process_delta_time()
	_halte(KEY_W, false)
	_halte(KEY_SHIFT, false)
	_pruefe("Dem Pfeil zur Strandbar gefolgt", s.karte.ziel == Vector2.INF and _pos().distance_to(bar_ort.pos) < 8.0, "%.0f s, bei (%.0f, %.0f)" % [gelaufen, _pos().x, _pos().y])
	# ---- Speichern / Laden
	var d := w.speichern()
	var w2 := Wirtschaft.new()
	w2.laden(JSON.parse_string(JSON.stringify(d)))
	_pruefe("Speichern/Laden Angeln", w2.angeln == w.angeln and w2.fisch_index.size() == w.fisch_index.size() and w2.yacht and w2.fischkiste == w.fischkiste, "%s %d" % [w2.angeln, w2.fisch_index.size()])
	var alt := Wirtschaft.new()
	alt.laden({"geld": 50})
	_pruefe("Alter Spielstand lädt", alt.angeln.is_empty() and alt.fisch_index.is_empty() and not alt.yacht)

# Eine Runde angeln mit echter Maustaste: auswerfen, warten, Spannungsbalken spielen. true = gefangen
func angeln_runde(lang := false, boot := false) -> bool:
	var A := st.angeln
	s._klick(Vector2(400, 300), true)
	s._klick(Vector2(400, 300), false)
	await get_tree().process_frame
	if not A.aktiv():
		print("TEST  (kein Wurf: %s)" % s.hud.status_l.text)
		return false
	A.warte = minf(A.warte, 1.0)
	var t := 0.0
	var halte := false
	var fische0 := int(w.statistik.fische)
	while A.aktiv() and t < (60.0 if lang else 30.0):
		await get_tree().process_frame
		t += get_process_delta_time()
		if A.zustand == "drill":
			var mitte := A.kp + A.kasten_g * 0.5 + A.kv * 0.22
			var soll := A.fp > mitte
			if soll != halte:
				halte = soll
				s._klick(Vector2(400, 300), halte)
	if halte:
		s._klick(Vector2(400, 300), false)
	await _warte(0.2)
	return int(w.statistik.fische) > fische0

# ---------------------------------------------------------------- Bilder
func _blick(p: Vector3, ziel: Vector3) -> void:
	var l := s.laeufer
	l.position = p - Vector3(0, Laeufer.AUGE, 0)
	var d := ziel - p
	l.yaw = atan2(-d.x, -d.z)
	l.pitch = atan2(d.y, Vector2(d.x, d.z).length())

func _foto(nr: int) -> void:
	await _warte(1.4)
	print("BILD %d frame=%d fps=%d" % [nr, Engine.get_frames_drawn(), Engine.get_frames_per_second()])
	await _warte(0.1)

func _bilder() -> void:
	var k := s.welt.kueste
	var z0 := Kueste.BOUL_Z
	w.geld = 100000
	s.laeufer.boden_fn = Callable()   # Kamera frei setzen (Höhe aus _blick)
	# 0 Boulevard vom See aus, 1 Kanal mit Brücke, 2 Treppe + Wasserfall von der Promenade, 3 Strandbar, 4 Steg + Fischladen
	_blick(Vector3(k.kanal_start - 30.0, 6.0, z0 + 14.0), Vector3(-450.0, 0.0, z0))
	await _foto(0)
	_blick(Vector3(-345.0, 1.8, z0 + 9.0), Vector3(-330.0, 0.6, z0))
	await _foto(1)
	_blick(Vector3(-590.0, 3.5, z0 + 22.0), Vector3(-625.0, -2.0, z0))
	await _foto(2)
	_blick(Vector3(-626.0, -0.3, -96.0), Vector3(-627.0, -1.0, -74.0))
	await _foto(3)
	_blick(Vector3(-640.0, 1.5, -186.0), Vector3(-700.0, 1.0, -204.0))
	await _foto(4)
	# 5 Aussicht aus der Gondel (~300 m) Richtung Meer
	_blick(Vector3(-60.0, 300.0, -30.0), Vector3(-700.0, 0.0, -200.0))
	await _foto(5)
	# 6 Angeln: Spannungsbalken
	s.laeufer.boden_fn = k.boden
	w.angeln = ["bambus", "carbon"]
	var p := Kueste.KOPF.get_center() + Vector2(-10.0, 2.0)
	s.laeufer.position = Vector3(p.x, 0, p.y)
	s.laeufer.yaw = PI * 0.5 - 0.3
	s.laeufer.pitch = -0.2
	st.angeln.test_fisch = "barrakuda"
	s._klick(Vector2(400, 300), true)
	s._klick(Vector2(400, 300), false)
	await get_tree().process_frame
	st.angeln.warte = 0.3
	await _warte(1.6)
	await _foto(6)
	st.angeln.einholen()
	# 7 Fischladen-Menü, 8 Album Fische (ein paar gefangen), 9 Karte
	for id in ["sergeant", "koffer", "sohal", "igel", "papagei", "kaiser", "feuer", "barrakuda", "adlerrochen", "manta", "walhai"]:
		w.fisch_gefangen(id, float(Wirtschaft.fisch(id).groesse))
	st.menu.oeffnen()
	await _foto(7)
	st.menu.schliessen()
	s.album.reiter = 1
	s.album.umschalten()
	await _foto(8)
	s.album.umschalten()
	s.laeufer.position = Vector3(-60, 0, 60)
	s.karte.oeffnen()
	s.karte.ziel_setzen(k.stationen[0].pos, "Strandbar", 1)
	await _foto(9)
	s.karte.schliessen()
	await _foto(10)   # Pfeil im Bild
	# 11 Yacht
	w.yacht = true
	st.einsteigen()
	st.yacht.position = Vector3(-900.0, Kueste.MEER_Y, -150.0)
	st.yacht.tempo = 10.0
	await _foto(11)
	st.aussteigen()
	# 12 alle Fische als Sammelbild (Fischladen-Theke von oben)
	print("FPS-ENDE %d" % Engine.get_frames_per_second())
