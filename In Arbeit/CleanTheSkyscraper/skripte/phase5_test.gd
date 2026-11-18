class_name Phase5Test
extends Node
# Tests Phase 5 (gibt „TEST …“ aus): 33 = Prüfungen (Ton, Einstellungen, Tasten, Radio, Tageszeit, Effekte, Abspann),
# 34 = Testbilder (BILD n frame=…) + FPS, 35 = Hauptmenü (Prüfungen + Bilder). Mit Grafik starten (headless gibt es keinen Ton).
#   --nur=ton,tasten,…  nur diese Teile

var s: Spiel
var w: Wirtschaft
var fehler := 0
var nur := []

func setup(spiel: Spiel) -> void:
	s = spiel
	w = spiel.wirtschaft
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--nur="):
			nur = Array(a.split("=")[1].split(","))
	_ablauf.call_deferred()

func _teil(n: String) -> bool:
	return nur.is_empty() or n in nur

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

func _taste(k: Key) -> void:
	_halte(k, true)
	await get_tree().process_frame
	_halte(k, false)
	await get_tree().process_frame

func _knopf(menu: Node, n: String) -> bool:
	var b: BaseButton = menu.find_child(n, true, false)
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true

func _ablauf() -> void:
	await _warte(0.5)
	match s.ansicht:
		33: await _test()
		34: await _bilder()
		35: await _menue()
	print("TEST fertig: fehler=%d" % fehler)
	get_tree().quit()

# ---------------------------------------------------------------- Prüfungen
func _test() -> void:
	if _teil("ton"):
		await _ton()
	if _teil("tasten"):
		await _tasten()
	if _teil("einstellungen"):
		await _einstellungen()
	if _teil("radio"):
		await _radio()
	if _teil("effekte"):
		await _effekte()
	if _teil("tageszeit"):
		await _tageszeit()
	if _teil("abspann"):
		await _abspann()

func _ton() -> void:
	var t0 := Time.get_ticks_msec()
	while Ton._cache.size() < Synth.REZEPTE.size() and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	var dauer := (Time.get_ticks_msec() - t0) / 1000.0
	_pruefe("Alle Klänge erzeugt", Ton._cache.size() == Synth.REZEPTE.size(), "%d/%d in %.1f s" % [Ton._cache.size(), Synth.REZEPTE.size(), dauer])
	var kurz := []
	for n in Ton._cache:
		var l: float = (Ton._cache[n] as AudioStream).get_length()
		if l < 0.02:
			kurz.append(n)
	_pruefe("Klänge haben eine Länge", kurz.is_empty(), str(kurz))
	_pruefe("Kanäle Musik/Geraeusche/Radio", AudioServer.get_bus_index("Musik") > 0 and AudioServer.get_bus_index("Geraeusche") > 0 and AudioServer.get_bus_index("Radio") > 0)
	await _warte(2.0)
	_pruefe("Musik läuft", Ton.i.musik.an and Ton.i.musik.schritt > 8, "schritt=%d" % Ton.i.musik.schritt)
	# alle kurzen Geräusche nacheinander (für die Ton-Aufnahme per --write-movie)
	for n in Synth.REZEPTE:
		if not Synth.REZEPTE[n] and not n.begins_with("i_"):
			print("TON %s frame=%d" % [n, Engine.get_frames_drawn()])
			Ton.spielen(n)
			await _warte(minf((Ton._cache[n] as AudioStream).get_length(), 1.2) + 0.15)

func _tasten() -> void:
	# Gondel-Hoch auf Pfeil-oben legen: W tut nichts mehr, Pfeil-oben fährt hoch
	s.spieler.gesperrt = false
	s.spieler.y = 10.0
	s.spieler.max_y = 200.0
	Optionen.aktiv = true
	Optionen.belegen("vor", KEY_UP)
	var y0 := s.spieler.y
	_halte(KEY_W, true)
	await _warte(0.6)
	_halte(KEY_W, false)
	var y1 := s.spieler.y
	_halte(KEY_UP, true)
	await _warte(0.6)
	_halte(KEY_UP, false)
	var y2 := s.spieler.y
	_pruefe("Taste umbelegt: W fährt nicht mehr", absf(y1 - y0) < 0.01, "%.2f → %.2f" % [y0, y1])
	_pruefe("Taste umbelegt: Pfeil-oben fährt hoch", y2 > y1 + 0.3, "%.2f → %.2f" % [y1, y2])
	# Tausch: E auf Leertaste legen → Leertaste war „springen“, das bekommt jetzt E
	Optionen.belegen("benutzen", KEY_SPACE)
	_pruefe("Tasten tauschen bei Doppelbelegung", Optionen.taste("springen") == KEY_E and Optionen.taste("benutzen") == KEY_SPACE)
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	_pruefe("Leertaste meldet sich als E", Optionen.k(ev) == KEY_E)
	Optionen.setzen("tasten", {})
	_pruefe("Standard wiederhergestellt", Optionen.taste("vor") == KEY_W and Optionen.k(ev) == KEY_SPACE)
	Optionen.aktiv = false

func _einstellungen() -> void:
	await _taste(KEY_TAB)
	_pruefe("Werkstatt offen", s.shop.offen)
	_knopf(s.shop, "reiter_3")
	await get_tree().process_frame
	var ui: EinstellungenUi = s.shop.find_child("*EinstellungenUi*", true, false)
	if ui == null:
		for c in s.shop.find_children("*", "VBoxContainer", true, false):
			if c is EinstellungenUi:
				ui = c
	_pruefe("Einstellungen im Werkstatt-Reiter", ui != null)
	if ui == null:
		return
	_knopf(ui, "w_0")   # erste Auswahl = Qualität Niedrig
	await get_tree().process_frame
	_pruefe("Qualität Niedrig wirkt", int(Optionen.wert("qualitaet")) == 0 and is_equal_approx(get_viewport().scaling_3d_scale, 1.0), "scale=%.2f" % get_viewport().scaling_3d_scale)
	var q: Node = ui.find_child("qualitaet", true, false)
	_knopf(q, "w_2")
	await get_tree().process_frame
	_pruefe("Qualität Hoch wirkt", int(Optionen.wert("qualitaet")) == 2 and is_equal_approx(get_viewport().scaling_3d_scale, 2.0))
	var r: HSlider = ui.find_child("r_musik", true, false)
	r.value = 0.25
	_pruefe("Regler Musik", is_equal_approx(float(Optionen.wert("musik")), 0.25))
	r.value = 0.6
	Optionen.speichern()
	var j = JSON.parse_string(FileAccess.get_file_as_string(Optionen.TESTDATEI))
	_pruefe("Einstellungen gespeichert", j is Dictionary and is_equal_approx(float(j.musik), 0.6))
	_knopf(ui, "taste_karte")
	await get_tree().process_frame
	await _taste(KEY_N)
	_pruefe("Taste per Klick + Tastendruck umbelegt", Optionen.taste("karte") == KEY_N, Optionen.taste_name("karte"))
	_pruefe("Werkstatt bleibt dabei offen", s.shop.offen)
	Optionen.setzen("tasten", {})
	await _taste(KEY_TAB)

func _effekte() -> void:
	var e := s.effekte
	var vor := e.aktiv_glanz.size()
	s._fenster_sauber(3, 10)
	await get_tree().process_frame
	_pruefe("Glanz auf geputztem Fenster", e.aktiv_glanz.size() == vor + 1)
	var muenzen := 0
	for c in s.hud.wurzel.get_children():
		if c is TextureRect and (c as TextureRect).texture == e._muenz_tex:
			muenzen += 1
	_pruefe("Münzen fliegen ins Geld-Feld", muenzen == 3, str(muenzen))
	await _warte(1.2)
	_pruefe("Glanz verschwindet wieder", e.aktiv_glanz.size() == vor)
	s.spieler.wischt = true
	for k in 10:
		s.spieler.schwamm_off.x += 0.05
		await get_tree().process_frame
	_pruefe("Seifenblasen beim Wischen", e._blasen.emitting)
	s.spieler.wischt = false
	await get_tree().process_frame
	_pruefe("… und aus ohne Wischen", not e._blasen.emitting)

func _tageszeit() -> void:
	_pruefe("Uhr 6:30 = Phase 0", is_equal_approx(Tageszeit.uhr(0.0), 6.5))
	var ok := true
	for h in [0.5, 3.0, 5.7, 6.5, 9.0, 12.0, 18.9, 19.5, 21.0, 23.9]:
		if absf(Tageszeit.uhr(Tageszeit.phase_zu(h)) - h) > 0.01:
			ok = false
	_pruefe("Uhr ↔ Phase umkehrbar", ok)
	var mittag := Tageszeit.berechnen(Tageszeit.phase_zu(12.75))
	var nacht := Tageszeit.berechnen(Tageszeit.phase_zu(23.0))
	_pruefe("Mittags hoch, nachts unter dem Horizont", float(mittag.sonne_hoehe) > 55.0 and float(nacht.sonne_hoehe) < -5.0, "%.0f° / %.0f°" % [mittag.sonne_hoehe, nacht.sonne_hoehe])
	_pruefe("Nachtwert", float(mittag.nacht) < 0.01 and float(nacht.nacht) > 0.99)
	var hell := 0.0
	for k in 1200:
		if float(Tageszeit.berechnen(k / 1200.0).tag) > 0.5:
			hell += 1.0
	_pruefe("Etwa 14 von 20 Minuten hell", hell / 60.0 > 13.0 and hell / 60.0 < 15.5, "%.1f min" % (hell / 60.0))
	s.welt.zeit.phase = 0.5
	s.welt.zeit.laeuft = true
	await _warte(2.0)
	var dphase := s.welt.zeit.phase - 0.5
	_pruefe("Zeit läuft (20 min je Tag)", absf(dphase * Tageszeit.TAG - 2.0) < 0.3, "%.2f s" % (dphase * Tageszeit.TAG))
	s.welt.zeit.laeuft = false
	s.welt.zeit.phase = Tageszeit.phase_zu(22.0)
	await _warte(0.3)
	_pruefe("Nachts leuchten Laternen", Tageszeit.lampen.size() >= 2 and (Tageszeit.lampen[0][0] as StandardMaterial3D).emission_energy_multiplier > 3.0, "%d Lampen-Materialien" % Tageszeit.lampen.size())
	_pruefe("Nachtwert für die Shader", float(s.welt.zeit.werte.get("nacht", 0.0)) > 0.99)

func _abspann() -> void:
	var z := s.zustand
	var alt := z.sauber_zahl
	z.sauber_zahl = s.turm.fenster_gesamt   # so tun, als wäre alles sauber
	await _warte(0.3)
	var a := s.abspann
	_pruefe("Abspann startet, wenn alles sauber ist", a != null and is_instance_valid(a) and w.abspann and 1 in w.tuerme_fertig)
	if a == null:
		return
	_pruefe("Abspann-Kamera aktiv, HUD aus", a.cam.current and not s.hud.visible)
	await _taste(KEY_TAB)
	_pruefe("Tasten gehen nicht ins Spiel", not s.shop.offen)
	for t in [4.0, 16.0, 30.0]:
		while a.zeit < t:
			await get_tree().process_frame
		await _bild_machen("abspann %d s" % int(t), 1)
	await _warte(0.2)
	await _taste(KEY_ESCAPE)
	_pruefe("Esc springt zum Ende", a.zeit >= Abspann.DAUER - 6.0)
	await _warte(1.6)
	await _bild_machen("abspann ende", 1)
	_knopf(a, "weiterspielen")
	await _warte(0.3)
	_pruefe("Weiterspielen beendet den Abspann", not is_instance_valid(a) and s.hud.visible and not s.spieler.gesperrt)
	await _warte(0.5)
	_pruefe("Abspann nur einmal", s.abspann == null or not is_instance_valid(s.abspann))
	z.sauber_zahl = alt

func _radio() -> void:
	w.kosmetik_besitz.append("gradio_koffer")
	w.nutze_kosmetik("gradio_koffer")
	s._ausruestung()
	await get_tree().process_frame
	_pruefe("Radio-Modell in der Gondel", s.spieler.deko.find_child("radio", true, false) != null)
	w.radio.an = false
	await _taste(KEY_R)
	await _warte(1.5)
	_pruefe("R schaltet das Radio an", Ton.i.radio.an and w.radio.an, "stil=%s" % Ton.i.radio.stil)
	await _taste(KEY_T)
	await _warte(0.5)
	_pruefe("T wechselt den Sender", Ton.i.radio.stil == "funk", Ton.i.radio.stil)
	await _warte(3.0)
	_pruefe("Musik leise, solange das Radio spielt", Ton.i._musik_laut < 0.05, "%.2f" % Ton.i._musik_laut)
	for k in 2:
		await _taste(KEY_T)
		await _warte(3.0)
		print("TEST Sender %s läuft (schritt=%d)" % [Ton.i.radio.stil, Ton.i.radio.schritt])
	await _taste(KEY_R)
	await _warte(0.3)
	_pruefe("R schaltet aus", not Ton.i.radio.an)

# ---------------------------------------------------------------- Hauptmenü (35)
func _menue_finden() -> Hauptmenue:
	for c in s.get_parent().get_children():
		if c is Hauptmenue and not c.is_queued_for_deletion():
			return c
	return null

func _menue() -> void:
	await _warte(0.5)
	var m := _menue_finden()
	_pruefe("Hauptmenü beim Start", m != null)
	if m == null:
		return
	_pruefe("Spiel angehalten", s.process_mode == Node.PROCESS_MODE_DISABLED and not s.hud.visible)
	var p0 := m.cam.global_position
	await _warte(1.0)
	_pruefe("Kamera fliegt um den Turm", m.cam.current and m.cam.global_position.distance_to(p0) > 5.0, "%.1f m" % m.cam.global_position.distance_to(p0))
	for n in ["weiter", "einstellungen", "beenden"]:
		_pruefe("Knopf " + n, m.find_child(n, true, false) != null)
	_pruefe("Musik spielt im Menü", Ton.i == null or Ton.i.menue)
	await _warte(2.0)
	await _bild_machen("hauptmenue")
	_knopf(m, "einstellungen")
	await get_tree().process_frame
	_pruefe("Einstellungen öffnen", m.find_child("einstellungen_ui", true, false) != null)
	await _bild_machen("hauptmenue einstellungen")
	_knopf(m, "zurueck")
	await get_tree().process_frame
	_pruefe("Einstellungen schließen", m.einst == null)
	_knopf(m, "weiter")
	await _warte(0.8)
	_pruefe("Weiterspielen: Menü weg", _menue_finden() == null)
	_pruefe("Weiterspielen: Spiel läuft", s.process_mode == Node.PROCESS_MODE_INHERIT and s.hud.visible and (s.spieler.cam.current or s.laeufer.cam.current))
	await _bild_machen("im spiel")
	# aus der Werkstatt zurück ins Hauptmenü
	await _taste(KEY_TAB)
	_knopf(s.shop, "reiter_3")
	await get_tree().process_frame
	_knopf(s.shop, "hauptmenue")
	await _warte(0.5)
	m = _menue_finden()
	_pruefe("Werkstatt → Hauptmenü", m != null and not s.shop.offen and s.process_mode == Node.PROCESS_MODE_DISABLED)
	if m:
		_knopf(m, "weiter")
		await _warte(0.8)
		_pruefe("… und wieder zurück ins Spiel", _menue_finden() == null and s.hud.visible)

# ---------------------------------------------------------------- Bilder
var _bild := 0
func _bild_machen(name: String, warten := 8) -> void:
	for k in warten:   # Himmel-Licht (Radiance) wird über mehrere Bilder nachgeführt
		await get_tree().process_frame
	_bild += 1
	print("BILD %d frame=%d %s" % [_bild, Engine.get_frames_drawn(), name])

func _bilder() -> void:
	if _teil("tag"):
		await _tag_bilder()
	if _teil("flimmern"):
		await _flimmern()
	if _teil("effekte"):
		await _effekt_bilder()
	if _teil("fps"):
		await _fps()

# Bildrate (ohne --write-movie starten, z. B. --resolution 2560x1440): Spiel-Ansicht am Turm, Straße, Aussicht, Strand –
# je am Tag und in der Nacht (Ton, Musik, Tageszeit laufen mit)
func _fps() -> void:
	var cam := Camera3D.new()
	cam.far = 40000.0
	cam.fov = 70.0
	add_child(cam)
	var sm := s.welt.see_mitte()
	var orte := {
		"gondel": [],
		"strasse": [Vector3(262.5, 1.8, 41.5), Vector3(120, 8, 37.5)],
		"see": [Vector3(sm.x + 70.0, 3.0, sm.y + 120.0), Vector3(0, 120, 0)],
		"aussicht": [Vector3(160, 330, 120), Vector3(700, 0, 600)],
		"strand": [Vector3(-560, 6, -150), Vector3(-760, 0, -175)],
	}
	for uhr in [13.0, 22.0]:
		s.welt.zeit.phase = Tageszeit.phase_zu(uhr)
		s.welt.zeit.laeuft = true
		for k in orte:
			if orte[k].is_empty():
				s.spieler.cam.current = true
			else:
				cam.current = true
				cam.position = orte[k][0]
				cam.look_at(orte[k][1])
			await _warte(2.5)
			var summe := 0.0
			var n := 0
			var t0 := Time.get_ticks_usec()
			while Time.get_ticks_usec() - t0 < 2000000:
				await get_tree().process_frame
				n += 1
			summe = n / ((Time.get_ticks_usec() - t0) / 1000000.0)
			print("FPS %s %02d Uhr: %d bei %s" % [k, int(uhr), int(summe), get_viewport().get_visible_rect().size])

# Putzen mit Schwamm (Seifenblasen, Glanz, Münzen) und Wasserlanze (Sprühnebel)
func _effekt_bilder() -> void:
	var sp := s.spieler
	sp.gesperrt = true
	sp.yaw = 0.0
	sp.pitch = -0.05
	var t := 0.0
	var n := 0
	while t < 7.0:
		var dt := get_process_delta_time()
		t += dt
		sp.wischt = true
		var reihe := int(t / 0.35)
		var u := fmod(t, 0.35) / 0.35
		if reihe % 2 == 1:
			u = 1.0 - u
		sp.schwamm_off = Vector2(lerpf(-1.5, 0.3, u), lerpf(0.5, 2.6, clampf(float(reihe) / 18.0, 0.0, 1.0)))
		await get_tree().process_frame
		if t > 2.6 and t - dt <= 2.6:   # ein Fenster „fertig“ melden → Glanz + Münzen im Bild
			var spalte := int(fposmod(sp.weg, s.turm.umfaenge[sp.stock]) / Turm.FENSTER_B)
			s._fenster_sauber(s.turm.stockwerk_bei(sp.y + 1.5), spalte)
		if int(t / 0.7) > n:
			n = int(t / 0.7)
			print("BILD %d frame=%d wischen t=%.1f glanz=%d" % [100 + n, Engine.get_frames_drawn(), t, s.effekte.aktiv_glanz.size()])
	sp.wischt = false
	w.besitz.append("lanze")
	w.ausruesten("lanze")
	s._ausruestung()
	sp.y += 3.0
	sp.yaw = 0.25
	sp.pitch = 0.1
	sp.wischt = true
	for k in 40:
		await get_tree().process_frame
		sp.yaw = 0.15 + sin(k * 0.08) * 0.25
	print("BILD 120 frame=%d spruehen nebel=%s" % [Engine.get_frames_drawn(), s.effekte._nebel.emitting])
	sp.wischt = false

# Flimmert die wandernde Sonne? Je Ort 16 Bilder mit laufender Zeit (echtes Tempo) und 16 mit stehender Zeit.
# Auswertung: tools/flimmern_zeit.py (zweite zeitliche Ableitung je Bildpunkt).
func _flimmern() -> void:
	var cam := Camera3D.new()
	cam.far = 40000.0
	cam.fov = 70.0
	add_child(cam)
	cam.current = true
	s.hud.visible = false
	var p := s.turm.fassaden_punkt(25, 120.0, 25 * Turm.STOCK_H)
	var orte := {
		"turm_nah": [p.pos + p.normal * 7.0 + Vector3.UP * -1.0, p.pos + Vector3.UP * 1.0],
		"strasse": [Vector3(262.5, 1.8, 41.5), Vector3(120, 8, 37.5)],
		"platz": [Vector3(60, 1.8, 70), Vector3(0, 30, 0)],
	}
	for k in orte:
		for lauf in [true, false]:
			s.welt.zeit.phase = Tageszeit.phase_zu(15.0)
			s.welt.zeit.laeuft = lauf
			cam.position = orte[k][0]
			cam.look_at(orte[k][1])
			for i in 10:
				await get_tree().process_frame
			print("FLIMMER %s %s von=%d" % [k, "laeuft" if lauf else "steht", Engine.get_frames_drawn()])
			for i in 16:
				await get_tree().process_frame
	s.welt.zeit.laeuft = false

# Tag und Nacht: dieselben Orte zu verschiedenen Uhrzeiten (--uhren=9,13,… und --orte=fern,see,…)
func _tag_bilder() -> void:
	var cam := Camera3D.new()
	cam.far = 40000.0
	cam.fov = 60.0
	add_child(cam)
	cam.current = true
	s.hud.visible = false
	var sm := s.welt.see_mitte()
	var orte := {
		"fern": [Vector3(-668, 262, 1020), Vector3(0, 440, 0)],
		"see": [Vector3(sm.x + 70.0, 3.0, sm.y + 120.0), Vector3(0, 120, 0)],
		"oben": [Vector3(160, 330, 120), Vector3(700, 0, 600)],
		"strasse": [Vector3(262.5, 1.8, 37.5 + 4.0), Vector3(120, 8, 37.5)],
		"strand": [Vector3(-560, 6, -150), Vector3(-760, 0, -175)],
	}
	var uhren := [9.0, 13.0, 16.5, 18.6, 19.4, 20.2, 22.0, 5.8]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--uhren="):
			uhren = Array(a.split("=")[1].split_floats(","))
		if a.begins_with("--orte="):
			var nur_orte := a.split("=")[1].split(",")
			for k in orte.keys():
				if not k in nur_orte:
					orte.erase(k)
	for u in uhren:
		s.welt.zeit.phase = Tageszeit.phase_zu(float(u))
		s.welt.zeit.laeuft = false
		for k in orte:
			cam.position = orte[k][0]
			cam.look_at(orte[k][1])
			await _bild_machen("%s %s Uhr nacht=%.2f" % [k, str(u), float(s.welt.zeit.werte.get("nacht", 0.0))])
