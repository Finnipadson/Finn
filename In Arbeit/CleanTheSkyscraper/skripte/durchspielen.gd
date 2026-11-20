class_name Durchspielen
extends Node
# Durchspiel-Bot (Schalter --durchspielen): spielt das echte Spiel (wie ansicht 0, eigener Spielstand
# user://spielstand_durchlauf.json) vom Start zu Fuß bis weit in den Turm. Putzt über denselben Wisch-Code wie die Maus
# (schwamm_off / Fadenkreuz beim Sprühen), fährt die Gondel mit dem echten Tempo, läuft zu Fuß mit Wegsuche zu Kiosken,
# Läden, Casino, Arcade, Penthouse und Sky-Lounge und kauft über die echten Knöpfe. Speichert + lädt einmal mitten im Lauf.
# Protokoll: Zeilen „DS …“ auf der Konsole. Schnell: --headless --fixed-fps 20 (läuft so schnell wie die CPU kann).
# Weitere Schalter: --bis=STUNDEN (Spielzeit-Ende, Standard 30), --hand=M/S (Wischtempo, Standard 2,5), --zeitraffer=F (Engine.time_scale)
# Koop (Phase 7h): --koop → dieser Bot ist Gastgeber (ENet 127.0.0.1) und startet zwei Bot-Gäste (--koop-gast) als eigene
# Prozesse (Log user://koop_gastN.log). Jeder putzt mit seiner eigenen Gondel seine Seite; Werkstatt-Käufe und Ausflüge macht
# der Gastgeber, Gäste nehmen eine freie Gondel (oder kaufen eine) und angeln, solange keine frei ist. Alle 5 min
# „DS … ABGLEICH“ (Fenster, Kasse, Besitz aller drei), dazu Netz-Datenmenge und Wisch-Atlas. Gleiches Tempo für alle:
# --headless --fixed-fps 20 --max-fps 300 (= 15× Echtzeit; die Gäste bekommen dieselben Werte).

const BOT_STAND_BASIS := "user://durchlauf_bot"
static var BOT_STAND := bot_stand()

# --stand=NAME: eigener Spielstand + Bot-Zustand, damit mehrere Läufe gleichzeitig gehen
static func endung() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stand="):
			return "_" + a.split("=")[1]
	return ""

static func bot_stand() -> String:
	return BOT_STAND_BASIS + endung() + ".json"
const ZELLE := 0.5                 # Raster der Wegsuche zu Fuß (m)
const LADEN_TEST_NACH := 3.0 * 3600.0   # nach so viel Spielzeit einmal speichern + neu laden

var s: Spiel
var x: Extras
var w: Wirtschaft
var hand := 2.5                    # m/s: so schnell reibt die Hand das Werkzeug über das Glas
var hand_spray := 3.0              # m/s: so schnell schwenkt man den Strahl
var bis := 30.0 * 3600.0
var st := {}                       # Zustand des Bots (wird über das Neu-Laden gerettet)
var unerreichbar := {}             # Fenster-ID -> Versuche
var _verlauf: Array = []           # [spielzeit, verdient, fenster_selbst, fenster_helfer] alle 30 s
var _naechste_probe := 0.0
var _naechster_stand := 0.0
var _letzte_meldung := ""
var _fenster_zeit := {}            # Werkzeug -> [Fenster, Sekunden]
var _laufen_haenger := 0
var bilder_ordner := ""            # --bilder=ORDNER: mit Grafik alle 60 s ein kleines Bild + FPS (für Sammelbilder)
var _naechstes_bild := 20.0
var _bild_nr := 0
var _fps_werte: Array = []
var angeltest := 0.0               # --angeltest[=MIN]: nur angeln (Messung), dann beenden
const ANGEL_ALLE := 50.0 * 60.0    # so oft (Spielzeit) macht der Bot einen Angel-Ausflug
const ANGEL_DAUER := 6.0 * 60.0    # so lange angelt er dann (wie ein Mensch zwischendurch)
const KOOP_PORT := 24690
const ABGLEICH_ALLE := 300.0
var koop := ""                     # "" | "host" | "gast"
var _koop_bilder := 0              # Bilder seit Start (Tempo-Messung)
var _koop_ms := 0
var _naechster_abgleich := ABGLEICH_ALLE
var _abgleich := {}                # Gastgeber: Name -> letzter Bericht
var _netz_bytes := 0               # Gastgeber: gesendet + empfangen (ENet)
var _slots_max := 0
var _gast_werkzeug_zeit := 0.0
var koop_fps := 300                # Bilder je echter Sekunde für alle Koop-Prozesse (fixed-fps 20 → 15× Echtzeit)

func setup(spiel: Spiel) -> void:
	s = spiel
	x = spiel.extras
	w = spiel.wirtschaft
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bis="):
			bis = float(a.split("=")[1]) * 3600.0
		if a.begins_with("--hand="):
			hand = float(a.split("=")[1])
			hand_spray = hand * 1.2
		if a.begins_with("--bilder="):
			bilder_ordner = a.split("=")[1]
		if a.begins_with("--angeltest"):
			angeltest = float(a.split("=")[1]) if "=" in a else 30.0
		if a.begins_with("--zeitraffer="):
			Engine.time_scale = float(a.split("=")[1])
		if a == "--koop":
			koop = "host"
		if a == "--koop-gast":
			koop = "gast"
		if a.begins_with("--koop-fps="):
			koop_fps = int(a.split("=")[1])
	if koop == "gast" and not (Netz.ist_gast() and not Netz.gast_stand.is_empty()):
		# Gast-Prozess: die erste Szene läuft nur bis zum Beitritt (dann lädt die Welt des Gastgebers neu). Kommt man
		# zurück ins eigene Spiel (Gastgeber beendet), ist der Koop-Lauf vorbei.
		if Netz.menue_meldung != "":
			print("DS KOOP ENDE Gast %s: %s" % [Netz.profil.name, Netz.menue_meldung])
			Netz.beenden()
		else:
			get_tree().create_timer(120.0).timeout.connect(func():
				if not Netz.ist_gast():
					print("DS FEHLER Koop-Gast %s: kein Beitritt nach 120 s" % Netz.profil.name)
					Netz.beenden(1))
		return
	if koop == "gast":
		Netz.test_nachricht_da.connect(_koop_nachricht)
	st = {"kaeufe": 0, "laden_test": false, "casino": -1e9, "arcade": -1e9, "ausflug": -1e9, "album": false, "erfolge_menue": false,
		"jetpack_flug": false, "mode": false, "werkstatt_deko": false, "tote_zeit": 0.0, "unerreichbar": 0, "haenger_gondel": 0,
		"haenger_fuss": 0, "teleport_raum": 0, "vorher": {}, "angeln": 1800.0 - ANGEL_ALLE, "angel_runden": 0, "angel_geld": 0, "angel_minuten": 0.0}
	if koop == "" and FileAccess.file_exists(BOT_STAND):
		var d = JSON.parse_string(FileAccess.get_file_as_string(BOT_STAND))
		if d is Dictionary and d.get("neu_laden", false):
			for k in d.st:
				st[k] = d.st[k]
			_vergleich_nach_laden()
	_ablauf.call_deferred()

func _zeit() -> float:
	return float(w.statistik.spielzeit)

func _uhr() -> String:
	var t := int(_zeit())
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]

func _log(t: String) -> void:
	print("DS [%s] %s%s" % [_uhr(), "" if koop != "gast" else "(%s) " % Netz.profil.name, t])

func _warte(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _bild() -> void:
	await get_tree().process_frame

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

# ---------------------------------------------------------------- Protokoll / Einnahmen
func _process(_dt: float) -> void:
	if koop != "":
		_koop_takt()
	if s.hud.meld.text != _letzte_meldung:
		_letzte_meldung = s.hud.meld.text
		if _letzte_meldung != "" and (_letzte_meldung.begins_with("Erfolg") or _letzte_meldung.begins_with("Neue Höhe") or _letzte_meldung.begins_with("Neu im") or _letzte_meldung.contains("Sandsturm") or _letzte_meldung.contains("fehlen")):
			_log("MELDUNG " + _letzte_meldung.replace("\n", " | "))
	var t := _zeit()
	var proz := 100.0 * s.zustand.sauber_zahl / s.turm.fenster_gesamt
	for m in [5, 10, 25, 50, 75, 90, 99]:
		if proz >= m and not st.has("ziel_%d" % m):
			st["ziel_%d" % m] = t
			_log("MEILENSTEIN %d %% der Fenster sauber (%d)" % [m, s.zustand.sauber_zahl])
	if t >= _naechste_probe:
		_naechste_probe = t + 30.0
		_verlauf.append([t, int(w.statistik.verdient), int(w.statistik.fenster_selbst), int(w.statistik.fenster_helfer)])
		if _verlauf.size() > 60:
			_verlauf.pop_front()
	if DisplayServer.get_name() != "headless" and t >= _naechstes_bild:
		_naechstes_bild = t + 30.0
		var fps := Engine.get_frames_per_second()
		_fps_werte.append(fps)
		var wo := "Gondel %d m" % int(s.spieler.y) if s.spieler.aktiv else ("zu Fuß" if x.ort == "" else x.ort)
		_log("FPS %d (%s, Helfer %d)" % [fps, wo, s.helfer.anzahl()])
		if bilder_ordner != "":
			var img := get_viewport().get_texture().get_image()
			img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
			img.save_png("%s/b%02d.png" % [bilder_ordner, _bild_nr])
			_bild_nr += 1
	if t >= _naechster_stand:
		_naechster_stand = t + 600.0
		_stand()
		if koop == "host":
			_koop_stand()

# Einnahmen pro Minute (letzte ~10 min): gesamt, nur selbst geputzte Fenster, Helfer-Fenster pro Minute
func _rate() -> Dictionary:
	if _verlauf.size() < 2:
		return {"geld": 0.0, "selbst": 0.0, "helfer": 0.0}
	var a: Array = _verlauf[maxi(0, _verlauf.size() - 21)]
	var b: Array = _verlauf[_verlauf.size() - 1]
	var m := maxf((float(b[0]) - float(a[0])) / 60.0, 0.1)
	return {"geld": (int(b[1]) - int(a[1])) / m, "selbst": (int(b[2]) - int(a[2])) / m, "helfer": (int(b[3]) - int(a[3])) / m}

func _stand() -> void:
	var r := _rate()
	var proz := 100.0 * s.zustand.sauber_zahl / s.turm.fenster_gesamt
	var wz := []
	for id in _fenster_zeit:
		var v: Array = _fenster_zeit[id]
		wz.append("%s %.1fs" % [id, float(v[1]) / maxf(1.0, float(v[0]))])
	_log("STAND geld=%d fenster=%d (%.1f %%) seil=%d motor=%d arm=%d helfer=%d/%d/%d gondeln=%d werkzeug=%s €/min=%.0f selbst/min=%.1f helfer/min=%.1f bonus lohn=%.0f%% flaeche=%.0f%% tempo=%.0f%% helfer=%.0f%% erfolge=%d moebel=%d | s/Fenster: %s" % [
		w.geld, s.zustand.sauber_zahl, proz, w.oberstes_stockwerk(), w.stufen.motor, w.stufen.arm, w.helfer.putzkraft, w.helfer.roboter, w.helfer.drohne,
		w.gondeln_gekauft(), w.aktiv, r.geld, r.selbst, r.helfer, w.bonus("lohn") * 100, w.bonus("flaeche") * 100, w.bonus("tempo") * 100, w.bonus("helfer") * 100,
		w.erfolge.size(), w.moebel.size(), ", ".join(wz)])

func _kauf(was: String, preis: int) -> void:
	st.kaeufe = int(st.kaeufe) + 1
	_log("KAUF %s für %d € (danach %d €)" % [was, preis, w.geld])

# ---------------------------------------------------------------- Hauptablauf
func _ablauf() -> void:
	await _warte(1.0)
	if koop != "":
		_koop_bilder = 0
	_koop_ms = Time.get_ticks_msec()
	if koop == "host":
		_koop_starten()
	_log("START fenster=%d geld=%d seil=%d gesamt=%d hand=%.1f m/s" % [s.zustand.sauber_zahl, w.geld, w.oberstes_stockwerk(), s.turm.fenster_gesamt, hand])
	_raster_bauen()
	if "--dreck" in OS.get_cmdline_user_args():   # Test (FPS-Lauf im späten Spielstand): oben wieder alles dreckig
		var n := 0
		for f in range(60, Turm.STOCKWERKE):
			for c in s.turm.fenster_pro_stock[f]:
				if s.zustand.verschmutzen(f, c, 1.0):
					n += 1
		_log("DRECK %d Fenster ab Stockwerk 60 wieder dreckig" % n)
	if "--werkzeugtest" in OS.get_cmdline_user_args():
		await _werkzeugtest()
		get_tree().quit()
		return
	if angeltest > 0.0:
		await _angeltest()
		get_tree().quit()
		return
	if "--wegtest" in OS.get_cmdline_user_args():
		await _wegtest()
		get_tree().quit()
		return
	var leer_seit := -1.0
	while true:
		if s.zustand.sauber_zahl >= s.turm.fenster_gesamt:
			_log("ZIEL alle Fenster sauber!")
			if koop == "gast":   # Gast wartet, bis der Gastgeber beendet
				await _warte(5.0)
				continue
			break
		if _zeit() >= bis:
			_log("ENDE Spielzeit-Grenze erreicht")
			break
		if koop == "" and not bool(st.laden_test) and _zeit() >= LADEN_TEST_NACH:
			await _speichern_laden()
			return
		if koop == "gast":
			if not await _gast_gondel():
				await _gast_warten()
				continue
			await _gast_werkzeug()
		elif not s.spieler.aktiv:
			await _einsteigen()
			continue
		if koop != "gast":
			await _werkstatt()
		if koop != "gast" and _ausflug_noetig():
			await _ausflug()
			continue
		var ziel := _naechstes_fenster(s.spieler.seite)   # 7h: beim Mithelfen die geholfene Seite
		if ziel.is_empty():
			if koop != "" and await _koop_helfen():
				leer_seit = -1.0
				continue
			# Seite fertig (bis zur Seil-Grenze): andere Seite, neue Gondel oder warten (tote Phase)
			var k := _andere_seite()
			if k >= 0:
				await _seite_wechseln(k)
				leer_seit = -1.0
				continue
			if leer_seit < 0.0:
				leer_seit = _zeit()
				_log("LEER nichts mehr zu putzen bis Stockwerk %d (Seilwinde %d € bei %d €)" % [w.oberstes_stockwerk(), w.upgrade_preis("winde"), w.geld])
			await _warte(5.0)
			st.tote_zeit = float(st.tote_zeit) + 5.0
			continue
		if leer_seit >= 0.0:
			_log("LEER vorbei nach %d s" % int(_zeit() - leer_seit))
			leer_seit = -1.0
		await _putze(ziel)
		if not bool(st.album) and w.album.size() > 0:
			st.album = true
			s._taste(KEY_B)
			await _warte(0.5)
			_log("ALBUM offen=%s szenen=%d" % [s.album.offen, w.album.size()])
			s._taste(KEY_B)
			await _warte(0.3)
	_ende()

func _ende() -> void:
	if koop == "host":
		await _koop_ende()
	x.erfolge_pruefen()   # letzte Erfolge noch vergeben (sonst fehlte „Alle Fenster“, wenn das Ende < 1 s nach dem letzten Fenster kam)
	_stand()
	var ids := []
	for e in Erfolge.LISTE:
		if not w.erfolge.has(e.id):
			ids.append(e.id)
	_log("FERTIG spielzeit=%s fenster=%d/%d geld=%d verdient=%d erfolge=%d/%d fehlend=%s käufe=%d tote_zeit=%ds unerreichbar=%d hänger_gondel=%d hänger_fuß=%d teleport_raum=%d casino_bilanz=%d" % [
		_uhr(), s.zustand.sauber_zahl, s.turm.fenster_gesamt, w.geld, int(w.statistik.verdient), w.erfolge.size(), Erfolge.LISTE.size(), str(ids),
		int(st.kaeufe), int(st.tote_zeit), unerreichbar.size(), int(st.haenger_gondel), int(st.haenger_fuss), int(st.teleport_raum), int(w.statistik.casino_bilanz)])
	s._speichern()
	Netz.beenden()

# ---------------------------------------------------------------- Speichern + Laden mitten im Lauf
func _schnappschuss() -> Dictionary:
	return {"geld": w.geld, "sauber": s.zustand.sauber_zahl, "stufen": w.stufen.duplicate(), "helfer": w.helfer.duplicate(), "besitz": w.besitz.size(),
		"moebel": w.moebel.size(), "steht": w.moebel.filter(func(m): return m.steht).size(), "erfolge": w.erfolge.size(), "gondeln": w.gondeln_gekauft(),
		"fahrzeuge": w.fahrzeuge.size(), "album": w.album.size(), "verdient": int(w.statistik.verdient), "kosmetik": w.kosmetik_besitz.size()}

func _speichern_laden() -> void:
	st.laden_test = true
	if s.spieler.aktiv and not s.express:
		pass
	st.vorher = _schnappschuss()
	s._speichern()
	var f := FileAccess.open(BOT_STAND, FileAccess.WRITE)
	f.store_string(JSON.stringify({"neu_laden": true, "st": st}))
	f.close()
	_log("LADETEST speichere und lade neu: %s" % str(st.vorher))
	s.zustand = null   # nicht beim Abbau noch einmal speichern (ist schon gespeichert)
	get_tree().reload_current_scene()

func _vergleich_nach_laden() -> void:
	var f := FileAccess.open(BOT_STAND, FileAccess.WRITE)
	f.store_string(JSON.stringify({"neu_laden": false, "st": st}))
	f.close()
	await get_tree().process_frame
	await get_tree().process_frame
	var nach: Dictionary = JSON.parse_string(JSON.stringify(_schnappschuss()))
	var vorher: Dictionary = JSON.parse_string(JSON.stringify(st.vorher))
	var unterschiede := []
	for k in vorher:
		if str(vorher[k]) != str(nach[k]):
			unterschiede.append("%s: %s → %s" % [k, str(vorher[k]), str(nach[k])])
	_log("LADETEST nach dem Laden: %s" % ("alles gleich" if unterschiede.is_empty() else "UNTERSCHIEDE " + "; ".join(unterschiede)))

# ---------------------------------------------------------------- Putzen
# Nächstes dreckiges Fenster auf Seite k bis zur Seil-Grenze (nicht von Helfern reserviert), nach Fahrzeit sortiert
func _naechstes_fenster(k: int) -> Dictionary:
	var sp := s.spieler
	var oben := w.oberstes_stockwerk()
	var vs := Spieler.TEMPO_SEITE * sp.tempo_faktor
	var vh := Spieler.TEMPO_HOCH * sp.tempo_faktor
	var spray := sp.wz_art == "spray"
	var bester := {}
	var best_k := INF
	var f_g := s.turm.stockwerk_bei(sp.y + 1.6)
	for runde in 2:
		var von := 0 if runde == 1 else maxi(0, f_g - 2)
		var nach := oben if runde == 1 else mini(oben, f_g + 3)
		for f in range(von, nach):
			var gleich := s.turm.gleicher_grundriss(f, sp.stock)
			var dy := absf(f * Turm.STOCK_H + 2.5 - (sp.y + 1.6))
			var basis := s.turm.fenster_basis[f]
			for c in s.turm.spalten_der_seite(f, k):
				var id: int = basis + c
				if s.zustand.sauber[id] == 1 or s.helfer.reserviert.has(id) or int(unerreichbar.get(id, 0)) >= 2:
					continue
				var dw := 40.0
				if gleich:
					var u: float = s.turm.umfaenge[f]
					dw = absf(wrapf((c + 0.5) * Turm.FENSTER_B - sp.weg, -u * 0.5, u * 0.5))
				var kosten := dy / vh + dw / vs
				if spray and gleich and dw < 5.0 and dy < 3.5:
					kosten *= 0.2   # im Strahl-Bereich: ohne Fahren
				if kosten < best_k:
					best_k = kosten
					bester = {"f": f, "c": c, "id": id}
		if not bester.is_empty():
			return bester
	return bester

# Anteil dreckiger Fenster auf Seite k bis zur Seil-Grenze
func _dreck_anteil(k: int) -> float:
	var n := 0
	var d := 0
	for f in w.oberstes_stockwerk():
		var basis := s.turm.fenster_basis[f]
		for c in s.turm.spalten_der_seite(f, k):
			n += 1
			if s.zustand.sauber[basis + c] == 0:
				d += 1
	return float(d) / maxf(1.0, n)

# Gondel mit echtem Tempo zu (weg auf Stockwerk f, Höhe y) fahren
func _gondel_hin(f: int, weg_ziel: float, y_ziel: float) -> void:
	var sp := s.spieler
	y_ziel = clampf(y_ziel, 0.3, sp.max_y)
	var t := 0.0
	var still := 0.0
	var alt := Vector2(sp.weg, sp.y)
	while true:
		var dt := get_process_delta_time()
		var vs := Spieler.TEMPO_SEITE * sp.tempo_faktor * dt
		var vh := Spieler.TEMPO_HOCH * sp.tempo_faktor * dt
		var dy := y_ziel - sp.y
		var dw := 0.0
		var gleich := s.turm.gleicher_grundriss(f, sp.stock)
		if gleich:
			var u: float = s.turm.umfaenge[sp.stock]
			dw = wrapf(weg_ziel - sp.weg, -u * 0.5, u * 0.5)
		if absf(dy) < 0.02 and gleich and absf(dw) < 0.03:
			return
		sp.y = clampf(sp.y + clampf(dy, -vh, vh), 0.3, sp.max_y)
		if gleich:
			sp.weg += clampf(dw, -vs, vs)
		await _bild()
		t += dt
		still += dt
		if still > 1.5:
			if Vector2(sp.weg, sp.y).distance_to(alt) < 0.05:
				return   # Seitenrand / Seil-Grenze: weiter geht es nicht
			alt = Vector2(sp.weg, sp.y)
			still = 0.0
		if t > 600.0:
			st.haenger_gondel = int(st.haenger_gondel) + 1
			_log("HÄNGER Gondel fährt seit 10 min (Ziel f=%d weg=%.1f y=%.1f, ist stock=%d weg=%.1f y=%.1f)" % [f, weg_ziel, y_ziel, sp.stock, sp.weg, sp.y])
			return

# Striche über ein Fenster (in Weg/Höhe, Meter), in Bändern, die aus einer Gondel-Höhe erreichbar sind
func _baender(f: int, c: int) -> Array:
	var sp := s.spieler
	var rx := sp.wz_rx * sp.wisch_faktor
	var ry := sp.wz_ry * sp.wisch_faktor
	var w0 := c * Turm.FENSTER_B
	var gb := f * Turm.STOCK_H + Turm.STOCK_H * Turm.BAND_ANTEIL
	var gt := (f + 1) * Turm.STOCK_H
	var ix := minf(rx * 0.55, Turm.FENSTER_B * 0.5)   # so weit innen, dass die Ellipse auch die Ecken erwischt
	var iy := minf(ry * 0.55, (gt - gb) * 0.5)
	var u0 := w0 + ix
	var u1 := w0 + Turm.FENSTER_B - ix
	var h0 := gb + iy
	var h1 := gt - iy
	var spalten := rx >= ry
	var abstand := 1.7 * (rx if spalten else ry)
	var spray := sp.wz_art == "spray"
	var span := (h1 - h0 + 0.01) if spray else (sp.reich_oben - Spieler.REICH_UNTEN - 0.06)
	var anzahl := maxi(1, ceili((h1 - h0) / span))
	var baender := []
	for b in anzahl:
		var b0 := h0 + (h1 - h0) * b / anzahl
		var b1 := h0 + (h1 - h0) * (b + 1) / anzahl
		var y := 0.0
		if spray:
			y = (b0 + b1) * 0.5 - 2.4
		else:
			y = maxf(b0 - Spieler.REICH_UNTEN - 0.03, b1 - sp.reich_oben + 0.03)
		var pfad := PackedVector2Array()
		if spalten:
			var n := maxi(1, ceili((u1 - u0) / abstand) + 1)
			for i in n:
				var u := u0 + (u1 - u0) * (float(i) / maxf(1, n - 1)) if n > 1 else (u0 + u1) * 0.5
				if i % 2 == 0:
					pfad.append(Vector2(u, b0)); pfad.append(Vector2(u, b1))
				else:
					pfad.append(Vector2(u, b1)); pfad.append(Vector2(u, b0))
		else:
			var n2 := maxi(1, ceili((b1 - b0) / abstand) + 1)
			for i in n2:
				var hh := b0 + (b1 - b0) * (float(i) / maxf(1, n2 - 1)) if n2 > 1 else (b0 + b1) * 0.5
				if i % 2 == 0:
					pfad.append(Vector2(u0, hh)); pfad.append(Vector2(u1, hh))
				else:
					pfad.append(Vector2(u1, hh)); pfad.append(Vector2(u0, hh))
		baender.append({"y": y, "pfad": pfad})
	return baender

# Werkzeug-Mitte auf einen Glaspunkt (Weg, Höhe) setzen. false = außer Reichweite
func _ziele_auf(f: int, p: Vector2) -> bool:
	var sp := s.spieler
	if not s.turm.gleicher_grundriss(f, sp.stock):
		return false
	var u: float = s.turm.umfaenge[sp.stock]
	var ox := wrapf(p.x - sp.weg, -u * 0.5, u * 0.5) * sp.richtung
	var oy := p.y - sp.y
	if sp.wz_art == "spray":
		# Kamera so drehen, dass das Fadenkreuz den Punkt trifft (wie mit der Maus umschauen)
		var ziel := sp.glas_punkt + sp.rechts * ox + Vector3.UP * oy
		var l := sp.gondel.global_basis.inverse() * (ziel - sp.cam.global_position)
		sp.yaw = atan2(-l.x, -l.z)
		sp.pitch = atan2(l.y, Vector2(l.x, l.z).length())
		return absf(ox) < 7.5 and oy > -2.8 and oy < 7.8 and (ziel - sp.cam.global_position).length() < Spieler.SPRAY_WEIT
	var ok := absf(ox) <= sp.reich_seite + 0.001 and oy >= Spieler.REICH_UNTEN - 0.001 and oy <= sp.reich_oben + 0.001
	sp.schwamm_off = Vector2(clampf(ox, -sp.reich_seite, sp.reich_seite), clampf(oy, Spieler.REICH_UNTEN, sp.reich_oben))
	return ok

func _putze(z: Dictionary) -> void:
	var sp := s.spieler
	var f: int = z.f
	var c: int = z.c
	var id: int = z.id
	var t0 := _zeit()
	var mitte_w := (c + 0.5) * Turm.FENSTER_B
	var weg_ziel := s.turm.weg_auf_seite(f, mitte_w, s.spieler.seite)
	for band in _baender(f, c):
		if s.zustand.sauber[id] == 1:
			break
		var y: float = band.y
		# Sprühen: nur fahren, wenn das Fenster nicht schon gut im Strahl-Bereich liegt
		if sp.wz_art == "spray" and s.turm.gleicher_grundriss(f, sp.stock):
			var u: float = s.turm.umfaenge[sp.stock]
			var dw := absf(wrapf(mitte_w - sp.weg, -u * 0.5, u * 0.5))
			var dy := (f * Turm.STOCK_H + 2.5) - sp.y
			if dw < 5.0 and dy > -1.0 and dy < 5.5:
				y = sp.y
				weg_ziel = sp.weg
		sp.wischt = false
		await _gondel_hin(f, weg_ziel, y)
		var pfad: PackedVector2Array = band.pfad
		var tempo := hand_spray if sp.wz_art == "spray" else hand
		var pos := pfad[0]
		_ziele_auf(f, pos)
		sp.letzter_stempel = Vector2(INF, INF)
		await _bild()
		sp.wischt = true
		for i in range(1, pfad.size()):
			var ziel := pfad[i]
			while pos.distance_to(ziel) > 0.001:
				pos = pos.move_toward(ziel, tempo * get_process_delta_time())
				_ziele_auf(f, pos)
				await _bild()
				if s.zustand.sauber[id] == 1 or not sp.aktiv:
					break
			if s.zustand.sauber[id] == 1 or not sp.aktiv:
				break
		await _bild()
		sp.wischt = false
	sp.wischt = false
	var dauer := _zeit() - t0
	if s.zustand.sauber[id] == 1:
		var v: Array = _fenster_zeit.get(sp.wz_id, [0, 0.0])
		_fenster_zeit[sp.wz_id] = [int(v[0]) + 1, float(v[1]) + dauer]
	else:
		unerreichbar[id] = int(unerreichbar.get(id, 0)) + 1
		if int(unerreichbar[id]) == 2:
			st.unerreichbar = int(st.unerreichbar) + 1
			var sv: Vector2 = s.turm.seiten[f][s.spieler.seite]
			_log("UNERREICHBAR Fenster f=%d c=%d (Seite %d, Seite reicht weg %.1f..%.1f, Fenster %.1f..%.1f, Fortschritt %.0f %%, Werkzeug %s)" % [
				f, c, w.aktive_gondel, sv.x, sv.x + sv.y, c * Turm.FENSTER_B, (c + 1) * Turm.FENSTER_B, s.zustand.fortschritt(f, c) * 100, sp.wz_id])
	if dauer > 90.0:
		_log("LANGSAM Fenster f=%d c=%d dauerte %d s" % [f, c, int(dauer)])

func _andere_seite() -> int:
	var beste := -1
	var bester_anteil := 0.02
	for k in 3:
		if k == w.aktive_gondel or _fremd_belegt(k):
			continue
		var a := _dreck_anteil(k)
		if a > bester_anteil and (w.gondeln[k].gekauft or w.geld >= w.gondel_preis()):
			beste = k
			bester_anteil = a
	return beste

# ---------------------------------------------------------------- Werkstatt (Tab): Seilwinde, Motor, Arm, Helfer, Gondeln
func _werkstatt() -> void:
	if s.express or not s.spieler.aktiv:
		return
	var r := _rate()
	var plan := []
	var dreck := _dreck_anteil(w.aktive_gondel)
	var rest := w.geld
	var reserve := 0
	if not w.upgrade_voll("winde"):
		var pw := w.upgrade_preis("winde")
		if pw <= rest and (dreck < 0.25 or pw <= 0.3 * rest):
			plan.append("up_winde")
			rest -= pw
		elif dreck < 0.4:
			reserve = pw
	for id in ["motor", "arm"]:
		if not w.upgrade_voll(id) and w.upgrade_preis(id) <= 0.35 * (rest - reserve):
			plan.append("up_" + id)
			rest -= w.upgrade_preis(id)
	for k in 3:
		if not w.gondeln[k].gekauft and w.gondel_preis() <= 0.5 * (rest - reserve):
			plan.append("go_%d" % k)
			rest -= w.gondel_preis()
			break
	# Helfer: der mit dem besten Preis pro Fenster/min (nach Lohn-Anteil)
	var leistung := {"putzkraft": 4.0 * 0.7, "roboter": 10.0 * 0.75, "drohne": 20.0 * 0.8}
	var bester := ""
	var best_p := INF
	for id in leistung:
		if w.helfer_voll(id):
			continue
		var pp := w.helfer_preis(id) / float(leistung[id])
		if pp < best_p and w.helfer_preis(id) <= 0.5 * (rest - reserve):
			best_p = pp
			bester = id
	if bester != "":
		plan.append("he_" + bester)
	if plan.is_empty():
		return
	s._taste(KEY_TAB)
	await _bild()
	if not s.shop.offen:
		_log("FEHLER Tab öffnet die Werkstatt nicht")
		return
	for n in plan:
		var preis := 0
		if n.begins_with("up_"):
			preis = w.upgrade_preis(n.substr(3))
		elif n.begins_with("he_"):
			preis = w.helfer_preis(n.substr(3))
		else:
			preis = w.gondel_preis()
		var vorher := str(w.stufen) + str(w.helfer) + str(w.gondeln_gekauft())
		if _knopf(s.shop, n):
			if str(w.stufen) + str(w.helfer) + str(w.gondeln_gekauft()) != vorher:
				_kauf(n + (" → Seil bis Stockwerk %d" % w.oberstes_stockwerk() if n == "up_winde" else ""), preis)
			await _bild()
	s._taste(KEY_TAB)
	await _bild()
	if r.geld < 0.0:
		pass

# ---------------------------------------------------------------- Ausflüge zu Fuß
# gemessen mit --werkzeugtest (Sekunden pro Fenster ohne Boosts, voller Ausbau): so viel taugt ein Werkzeug wirklich
const GEMESSEN := {"schwamm": 8.9, "grossschwamm": 5.6, "abzieher": 4.3, "doppel": 3.9, "hochdruck": 4.2, "mikro": 4.3, "profi": 3.2, "teleskop": 1.6, "dampf": 1.1, "lanze": 0.7}

func _werkzeug_wert(wz: Dictionary) -> float:
	return 1.0 / float(GEMESSEN.get(wz.id, 9.0))

func _bestes_werkzeug() -> String:
	var beste := "schwamm"
	for wz in Wirtschaft.WERKZEUGE:
		if wz.id in w.besitz and _werkzeug_wert(wz) > _werkzeug_wert(w.werkzeug(beste)):
			beste = wz.id
	return beste

# Was lohnt sich gerade zu Fuß? (Liste von Aufträgen)
func _einkaufsliste() -> Array:
	var l := []
	var r := _rate()
	var g := w.geld
	var reserve := w.upgrade_preis("winde") if not w.upgrade_voll("winde") and _dreck_anteil(w.aktive_gondel) < 0.4 else 0
	var frei := g - reserve
	# Werkzeug: das beste bezahlbare, das besser ist als das jetzige
	var jetzt := _werkzeug_wert(w.werkzeug(_bestes_werkzeug()))
	var kauf := {}
	for wz in Wirtschaft.WERKZEUGE:
		if not wz.id in w.besitz and w.werkzeug_preis(wz.id) <= frei and _werkzeug_wert(wz) > jetzt * 1.05:
			if kauf.is_empty() or _werkzeug_wert(wz) > _werkzeug_wert(kauf):
				kauf = wz
	if not kauf.is_empty():
		l.append({"art": "werkzeug", "id": kauf.id, "stand": "werkzeug" if kauf.get("profi", false) else "grund"})
		frei -= w.werkzeug_preis(kauf.id)
	# alle 10 Werkzeuge für den Erfolg, wenn es billig geworden ist
	for wz in Wirtschaft.WERKZEUGE:
		if not wz.id in w.besitz and w.werkzeug_preis(wz.id) <= 0.05 * frei and (kauf.is_empty() or wz.id != kauf.id):
			l.append({"art": "werkzeug", "id": wz.id, "stand": "werkzeug" if wz.get("profi", false) else "grund"})
			frei -= w.werkzeug_preis(wz.id)
	for f in Wirtschaft.FAHRZEUGE:
		if not f.id in w.fahrzeuge and int(f.preis) * 4 <= frei:
			l.append({"art": "fahrzeug", "id": f.id})
			frei -= int(f.preis)
	if not bool(st.mode) and frei > 1500:
		l.append({"art": "mode", "id": "gondel_blau"})
	# Möbel mit Bonus (Katalog/Möbelhaus/Designer/Exklusiv/Souvenir/Gold), wenn sie sich in ~15 min Einnahmen bezahlt machen
	for id in Wirtschaft.GEGENSTAENDE:
		var gg: Dictionary = Wirtschaft.GEGENSTAENDE[id]
		if not gg.has("bonus") or w.anzahl_gegenstand(id) > 0 or w.kauf_sperre(id) != "":
			continue
		var p := int(gg.get("preis", 0))
		var q: String = gg.quelle
		if p <= 0 or q == "arcade":
			continue
		var grenze: float = r.geld * (60.0 if q == "gold" else 20.0)
		if p <= grenze and p <= 0.4 * frei:
			if q == "designer" and w.oberstes_stockwerk() < 120 or q == "exklusiv" and w.oberstes_stockwerk() < 168:
				continue
			l.append({"art": "gegenstand", "id": id, "quelle": q})
			frei -= p
	if not bool(st.werkstatt_deko) and frei > 8000:
		l.append({"art": "werkstatt_deko"})
	# Sky-Lounge-Etagen zum ersten Mal besuchen
	for e in [["lounge", 48], ["restaurant", 120], ["plattform", 168]]:
		if w.oberstes_stockwerk() >= int(e[1]) and not str(e[0]) in w.besucht:
			l.append({"art": "lounge", "id": e[0]})
	if _zeit() - float(st.casino) > 3.0 * 3600.0 and g > 2000:
		l.append({"art": "casino"})
	if _zeit() - float(st.arcade) > 45.0 * 60.0 and w.arcade_preis("kapsel") <= maxf(r.geld * 4.0, 0.0) and g > 1000:
		l.append({"art": "arcade"})
	# Angeln: etwa jede Stunde ein Ausflug an den Strand (Nebenaufgabe), sobald eine Angel bezahlbar ist
	if _zeit() - float(st.angeln) > ANGEL_ALLE and (w.angel() != "" or g >= 400):
		l.append({"art": "angeln"})
	return l

func _ausflug_noetig() -> bool:
	var l := _einkaufsliste()
	if l.is_empty():
		return false
	return _zeit() - float(st.ausflug) > 180.0   # höchstens alle 3 min (falls ein Kauf hängt)

func _boost_liste() -> Array:
	var r := _rate()
	var selbst: float = r.geld
	var l := []
	var g := w.geld
	if w.boost_preis("goldpolitur") <= 0.6 * selbst * 5.0 and w.boost_preis("goldpolitur") <= 0.2 * g:
		l.append(["putz", "goldpolitur"])
	if w.boost_preis("glanzspray") <= 0.3 * selbst * 5.0 and w.boost_preis("glanzspray") <= 0.1 * g:
		l.append(["putz", "glanzspray"])
	if w.boost_preis("kaffee") <= 0.15 * selbst * 4.0 and w.boost_preis("kaffee") <= 0.05 * g:
		l.append(["snack", "kaffee"])
	return l

func _ausflug() -> void:
	var l := _einkaufsliste()
	st.ausflug = _zeit()
	_log("AUSFLUG %s" % str(l.map(func(a): return str(a.art) + ":" + str(a.get("id", "")))))
	await _aussteigen()
	_fahrzeug_beste()
	var platzieren := false
	# Kioske: Werkzeuge, Fahrzeuge, Mode, Boosts
	for a in l:
		match a.art:
			"werkzeug":
				await _kiosk(str(a.stand), ["w_" + str(a.id)])
			"fahrzeug":
				await _kiosk("fahrzeug", ["f_" + str(a.id)])
				_fahrzeug_beste()
			"mode":
				await _kiosk("mode", ["k_" + str(a.id)])
				st.mode = true
	var boosts := _boost_liste()
	var staende := {}
	for b in boosts:
		if not staende.has(b[0]):
			staende[b[0]] = []
		staende[b[0]].append("b_" + str(b[1]))
	for k in staende:
		await _kiosk(str(k), staende[k])
	# Läden und Extras
	for a in l:
		match a.art:
			"gegenstand":
				var q: String = a.quelle
				if q in ["katalog", "moebelhaus"]:
					await _laden_kauf("moebel", str(a.id))
				elif q == "souvenir":
					await _laden_kauf("souvenir", str(a.id))
				elif q == "gold":
					await _laden_kauf("gold", str(a.id))
				elif q in ["designer", "exklusiv"]:
					await _lounge_besuch("restaurant" if q == "designer" else "plattform", str(a.id))
				platzieren = true
			"werkstatt_deko":
				await _werkstatt_deko()
			"lounge":
				await _lounge_besuch(str(a.id), "")
			"casino":
				await _casino()
			"arcade":
				await _arcade()
				platzieren = true
			"angeln":
				await _angelausflug()
	if platzieren or w.moebel.any(func(m): return not m.steht and Wirtschaft.GEGENSTAENDE[m.id].has("bonus")):
		await _penthouse()
	if "jetpack" in w.fahrzeuge and not bool(st.jetpack_flug):
		await _jetpack_flug()
	if not bool(st.erfolge_menue):
		st.erfolge_menue = true
		s._taste(KEY_P)
		await _warte(0.4)
		_log("ERFOLGE-Menü offen=%s art=%s (%d von %d)" % [x.menu.offen, x.menu.art, w.erfolge.size(), Erfolge.LISTE.size()])
		s._taste(KEY_P)
		await _warte(0.3)

func _fahrzeug_beste() -> void:
	var fz: Array = s._fahrzeug_liste()
	var wahl := ""
	for id in ["scooter", "hoverboard"]:
		if id in fz:
			wahl = id
	var i := fz.find(wahl)
	if i >= 0 and w.fahrzeug != wahl and not s.spieler.aktiv:
		s._taste(KEY_1 + i)

func _aussteigen() -> void:
	if not s.spieler.aktiv:
		return
	var t := 0.0
	s._taste(KEY_E)
	while s.spieler.aktiv and t < 120.0:
		await _warte(0.25)
		t += 0.25
		if not s.express and s.spieler.aktiv and s.spieler.y <= Spiel.UNTEN:
			s._taste(KEY_E)
	if s.spieler.aktiv:
		_log("FEHLER Aussteigen klappt nicht (y=%.1f express=%s)" % [s.spieler.y, s.express])

func _einsteigen() -> void:
	if s.spieler.aktiv:
		return
	if x.ort != "":
		await _zurueck_nach_unten()
	var g := s.spieler.gondel.global_position
	var n := s.spieler.normal
	var ziel := Vector2(g.x + n.x * 3.2, g.z + n.z * 3.2)
	await _gehe(ziel)
	# Steckt der Bot an einem Hindernis vor der Gondel fest (Ziel aufgegeben, > 4 m weg), von schräg vorn probieren
	# (vorher die Ursache der „Einsteigen klappt nicht“-Hänger, Abstand 4,2–4,8 m)
	for winkel in [0.8, -0.8, 1.4, -1.4]:
		if s._abstand_gondel() <= Spiel.EINSTEIG_WEIT - 0.3:
			break
		var nd := Vector2(n.x, n.z).rotated(winkel)
		await _gehe(Vector2(g.x, g.z) + nd * 2.6)
	await _hinschauen(Vector2(g.x, g.z))
	s._taste(KEY_E)
	await _warte(0.3)
	if not s.spieler.aktiv:
		var lp := Vector2(s.laeufer.position.x, s.laeufer.position.z)
		_log("HÄNGER Einsteigen klappt nicht, Abstand %.1f m (faehrt=%s ort='%s' station=%s menue=%s hoch=%.1f andere=%d gesperrt=%s laeufer_aktiv=%s)" % [s._abstand_gondel(),
			x._faehrt, x.ort, str(x.station().get("art", "")), s.extras.menue_offen() or s.shop.offen or s.hmenu.offen or s.cmenu.offen or s.album.offen, s.laeufer.hoch,
			s.gondeln.bei(lp, Spiel.EINSTEIG_WEIT), s.laeufer.gesperrt, s.laeufer.aktiv])
		st.haenger_fuss = int(st.haenger_fuss) + 1
		s.laeufer.position = Vector3(ziel.x, 0, ziel.y)
		await _bild()
		s._taste(KEY_E)
		await _warte(0.3)
	var t := 0.0
	while s.express and t < 120.0:
		await _warte(0.25)
		t += 0.25
	s.spieler.gesperrt = true
	# bestes Werkzeug in die Hand (Taste 1–0)
	var beste := _bestes_werkzeug()
	if w.aktiv != beste:
		for i in Wirtschaft.WERKZEUGE.size():
			if Wirtschaft.WERKZEUGE[i].id == beste:
				s._taste(KEY_0 if i == 9 else KEY_1 + i)
		await _bild()
		s.spieler.gesperrt = true
		_log("WERKZEUG %s in der Hand (%s)" % [w.aktiv, "ok" if w.aktiv == beste else "FEHLER Taste"])

func _seite_wechseln(k: int) -> void:
	_log("SEITE wechseln %d → %d (Dreck dort %.0f %%)" % [w.aktive_gondel, k, _dreck_anteil(k) * 100])
	await _aussteigen()
	_fahrzeug_beste()
	var pp: Vector3 = s.gondeln.park_punkt(k).pos
	var nn: Vector3 = s.gondeln.park_punkt(k).normal
	await _gehe(Vector2(pp.x + nn.x * 2.8, pp.z + nn.z * 2.8))
	await _hinschauen(Vector2(pp.x, pp.z))
	if not w.gondeln[k].gekauft:
		var g0 := w.geld
		s._taste(KEY_E)
		await _warte(0.3)
		if w.gondeln[k].gekauft:
			_kauf("Gondel %s (zu Fuß)" % Turm.SEITEN_NAMEN[k], g0 - w.geld)
	s._taste(KEY_E)
	await _warte(0.3)
	if w.aktive_gondel != k or not s.spieler.aktiv:
		_log("FEHLER Umsteigen in Gondel %d klappt nicht (aktiv=%d, in Gondel=%s)" % [k, w.aktive_gondel, s.spieler.aktiv])
	await _einsteigen()

# Kiosk: hingehen, E, Knöpfe, E
func _kiosk(stand: String, knoepfe: Array) -> void:
	var i := -1
	for j in Haendler.STAENDE.size():
		if Haendler.STAENDE[j].id == stand:
			i = j
	var p: Vector2 = s.haendler.vorne[i]
	await _gehe(p)
	await _hinschauen(p + p.normalized() * 2.0)
	s._taste(KEY_E)
	await _warte(0.3)
	if not s.hmenu.offen:
		_log("FEHLER Kiosk %s öffnet nicht (Abstand %.1f m)" % [stand, p.distance_to(Vector2(s.laeufer.position.x, s.laeufer.position.z))])
		return
	for n in knoepfe:
		var g0 := w.geld
		var id: String = n.substr(2)
		var preis := 0
		match n.substr(0, 2):
			"w_": preis = w.werkzeug_preis(id)
			"f_": preis = int(w.fahrzeug_daten(id).get("preis", 0))
			"b_": preis = w.boost_preis(id)
			"k_": preis = int(w.kosmetik(id).preis)
		if _knopf(s.hmenu, n):
			if w.geld < g0:
				_kauf("%s am Kiosk %s" % [n, stand], preis)
			await _bild()
		else:
			_log("KNOPF %s am Kiosk %s nicht drückbar (geld %d)" % [n, stand, w.geld])
	s._taste(KEY_E)
	await _warte(0.3)

func _hinschauen(ziel: Vector2) -> void:
	var d := ziel - Vector2(s.laeufer.position.x, s.laeufer.position.z)
	if d.length() > 0.01:
		s.laeufer.yaw = atan2(-d.x, -d.y)
	await _bild()

# Läden: zur Station des Stücks gehen, E, kaufen, E
func _laden_station(laden: String, id: String) -> Dictionary:
	for sta in x.laeden.stationen:
		if sta.laden == laden and (sta.id == id or id == "" and sta.id == ""):
			return sta
	return {}

func _laden_kauf(laden: String, id: String) -> void:
	var sta := _laden_station(laden, id)
	if sta.is_empty():
		sta = _laden_station(laden, "")
	if sta.is_empty():
		_log("FEHLER keine Station für %s im Laden %s" % [id, laden])
		return
	await _gehe(sta.pos)
	await _hinschauen(sta.ziel)
	s._taste(KEY_E)
	await _warte(0.3)
	if not x.menu.offen:
		_log("FEHLER Laden %s: Menü öffnet nicht an %s" % [laden, id])
		return
	var g0 := w.geld
	if _knopf(x.menu, "kauf_" + id):
		await _bild()
		_kauf("%s im Laden %s" % [id, laden], w.gegenstand_preis(id))
	else:
		_log("KNOPF kauf_%s im Laden %s nicht drückbar (sperre '%s', geld %d)" % [id, laden, w.kauf_sperre(id), w.geld])
	s._taste(KEY_E)
	await _warte(0.3)

func _werkstatt_deko() -> void:
	st.werkstatt_deko = true
	var sta := _laden_station("werkstatt", "")
	if sta.is_empty():
		for st2 in x.laeden.stationen:
			if st2.laden == "werkstatt":
				sta = st2
	await _gehe(sta.pos)
	await _hinschauen(sta.ziel)
	s._taste(KEY_E)
	await _warte(0.3)
	if not x.menu.offen:
		_log("FEHLER Gondel-Werkstatt öffnet nicht")
		return
	for paar in [[1, "lack_streifen"], [2, "kleber_stern"], [3, "blumen_rot"]]:
		_knopf(x.menu, "reiter_%d" % paar[0])
		await _bild()
		var g0 := w.geld
		if _knopf(x.menu, "k_" + str(paar[1])):
			await _bild()
			_kauf("%s in der Gondel-Werkstatt" % paar[1], g0 - w.geld)
	s._taste(KEY_E)
	await _warte(0.3)
	_log("GONDEL-DEKO aktiv: %s" % str(w.kosmetik_aktiv))

# ---------------------------------------------------------------- Räume (Aufzüge, Lounge, Arcade, Penthouse)
func _station(art: String, nr := -1) -> Dictionary:
	for sta in x._stationen():
		if sta.art == art and (nr < 0 or int(sta.get("nr", -1)) == nr):
			return sta
	return {}

# im Raum geradeaus zur Station laufen (W halten), bei Hängern hinstellen
func _im_raum_zu(sta: Dictionary) -> void:
	var p: Vector2 = sta.pos
	var t := 0.0
	var alt := Vector2(s.laeufer.position.x, s.laeufer.position.z)
	var still := 0.0
	_halte(KEY_W, true)
	while true:
		var q := Vector2(s.laeufer.position.x, s.laeufer.position.z)
		var d := p - q
		if d.length() < 0.4:
			break
		s.laeufer.yaw = atan2(-d.x, -d.y)
		await _bild()
		var dt := get_process_delta_time()
		t += dt
		still += dt
		if still > 1.5:
			if q.distance_to(alt) < 0.3:
				st.teleport_raum = int(st.teleport_raum) + 1
				_log("RAUM %s: Weg zur Station %s versperrt bei (%.1f, %.1f) – Bot stellt sich hin" % [x.ort, sta.art, q.x, q.y])
				break
			alt = q
			still = 0.0
		if t > 30.0:
			break
	_halte(KEY_W, false)
	if Vector2(s.laeufer.position.x, s.laeufer.position.z).distance_to(p) > 1.0:
		s.laeufer.position = Vector3(p.x, s.laeufer.position.y, p.y)
	await _hinschauen(sta.get("ziel", p))

func _fahre(ziel: String) -> bool:
	var ok := _knopf(x.menu, "fahr_" + ziel)
	await _warte(1.5)
	if not ok:
		_log("FEHLER Aufzug: fahr_%s nicht drückbar (ort %s)" % [ziel, x.ort])
	return ok

func _zurueck_nach_unten() -> void:
	if x.ort == "":
		return
	var art := "aufzug" if x.ort in ["lounge", "restaurant", "plattform"] else "aufzug_casino"
	await _im_raum_zu(_station(art))
	s._taste(KEY_E)
	await _warte(0.3)
	await _fahre("unten" if art == "aufzug" else "casino")

func _lounge_besuch(etage: String, kauf: String) -> void:
	await _gehe(x.sky.unten_pos)
	await _hinschauen(x.sky.unten_ziel)
	s._taste(KEY_E)
	await _warte(0.3)
	if not x.menu.offen:
		_log("FEHLER Express-Aufzug öffnet nicht")
		return
	if not await _fahre(etage):
		s._taste(KEY_E)
		return
	_log("LOUNGE %s besucht (ort=%s, y=%.0f m)" % [etage, x.ort, s.laeufer.position.y])
	# Boost an der Bar/Theke, wenn er sich lohnt
	var r := _rate()
	var bar := {"lounge": ["bar", ["cocktail", "mojito", "espresso"]], "restaurant": ["restaurant", ["chefmenue", "mittag"]], "plattform": ["gipfel", ["champagner"]]}
	var b: Array = bar[etage]
	var sta := _station(str(b[0]))
	if not sta.is_empty():
		await _im_raum_zu(sta)
		s._taste(KEY_E)
		await _warte(0.3)
		if s.hmenu.offen:
			for id in b[1]:
				var dauer_min: float = Wirtschaft.BOOSTS[id].dauer / 60.0
				var lohn: float = float((Wirtschaft.BOOSTS[id].get("wirkung", {}) as Dictionary).get("lohn", 0.3))
				if w.boost_preis(id) <= lohn * r.geld * dauer_min * 0.7 and w.boost_preis(id) <= 0.25 * w.geld:
					var bp := w.boost_preis(id)
					if _knopf(s.hmenu, "b_" + id):
						_kauf("%s (%s)" % [id, etage], bp)
			s._taste(KEY_E)
			await _warte(0.3)
		else:
			_log("FEHLER Theke %s öffnet nicht" % b[0])
	if kauf != "":
		var art := "designer" if etage == "restaurant" else "exklusiv"
		await _im_raum_zu(_station(art))
		s._taste(KEY_E)
		await _warte(0.3)
		var g1 := w.geld
		if x.menu.offen and _knopf(x.menu, "kauf_" + kauf):
			_kauf("%s (%s)" % [kauf, etage], w.gegenstand_preis(kauf))
		else:
			_log("FEHLER %s: kauf_%s geht nicht" % [art, kauf])
		s._taste(KEY_E)
		await _warte(0.3)
	await _zurueck_nach_unten()

func _casino_aufzug(ziel: String) -> bool:
	await _gehe(s.casino.aufzug_pos)
	await _hinschauen(s.casino.aufzug_ziel)
	s._taste(KEY_E)
	await _warte(0.3)
	if not x.menu.offen:
		_log("FEHLER Casino-Aufzug öffnet nicht")
		return false
	return await _fahre(ziel)

func _arcade() -> void:
	st.arcade = _zeit()
	if not await _casino_aufzug("arcade"):
		return
	var a := x.arcade
	# Greifautomat: Kralle mit den echten Tasten über einen Preis steuern (mit kleinem Zielfehler wie ein Mensch)
	for nr in [0]:
		var sta := _station("greif", nr)
		await _im_raum_zu(sta)
		var g0 := w.geld
		var n0 := w.moebel.size()
		s._taste(KEY_E)
		await _warte(0.3)
		if a.spiel < 0:
			_log("FEHLER Greifautomat startet nicht (geld %d, preis %d)" % [w.geld, w.arcade_preis("greif")])
			continue
		var preise: Array = a.automaten[nr].preise
		var ziel: Vector2 = (preise[randi() % preise.size()].pos as Vector2) + Vector2(randf_range(-0.06, 0.06), randf_range(-0.06, 0.06))
		var t := 0.0
		while a.spiel >= 0 and a.phase == "steuern" and t < 15.0:
			var d := ziel - a.k_pos
			_halte(KEY_D, d.x > 0.02)
			_halte(KEY_A, d.x < -0.02)
			_halte(KEY_S, d.y > 0.02)
			_halte(KEY_W, d.y < -0.02)
			if d.length() < 0.03:
				break
			await _bild()
			t += get_process_delta_time()
		for k in [KEY_A, KEY_D, KEY_W, KEY_S]:
			_halte(k, false)
		s._taste(KEY_SPACE)
		t = 0.0
		while a.spiel >= 0 and t < 25.0:
			await _warte(0.25)
			t += 0.25
		_log("ARCADE Greifautomat: %s (%d €)" % ["Gewinn " + str(w.moebel[w.moebel.size() - 1].id) if w.moebel.size() > n0 else "daneben", w.arcade_preis("greif")])
	# Kapsel-Automat: so oft es sich lohnt (höchstens 3)
	var ks := _station("kapsel")
	await _im_raum_zu(ks)
	s._taste(KEY_E)
	await _warte(0.3)
	if x.menu.offen:
		for i in 3:
			var g1 := w.geld
			if w.arcade_preis("kapsel") > 0.1 * w.geld or not _knopf(x.menu, "kapsel"):
				break
			await _warte(2.0)
			_log("ARCADE Kapsel: %s (%d €)" % [x.menu.letzte_kapsel, g1 - w.geld])
		s._taste(KEY_E)
		await _warte(0.3)
	else:
		_log("FEHLER Kapsel-Automat öffnet nicht")
	await _zurueck_nach_unten()

# Penthouse: alles aus dem Lager aufstellen (Bonus zählt nur, wenn es steht)
func _penthouse() -> void:
	if x.ort != "penthouse":
		if x.ort != "":
			await _zurueck_nach_unten()
		if not await _casino_aufzug("penthouse"):
			return
	var ph := x.penthouse
	var tab := _station("tablet")
	var gestellt := 0
	var versuche := 0
	while versuche < 40:
		var idx := -1
		for i in w.moebel.size():
			if not w.moebel[i].steht:
				idx = i
				break
		if idx < 0:
			break
		versuche += 1
		await _im_raum_zu(tab)
		s._taste(KEY_E)
		await _warte(0.3)
		if not x.menu.offen:
			_log("FEHLER Tablet öffnet nicht")
			break
		_knopf(x.menu, "reiter_1")
		await _bild()
		if not _knopf(x.menu, "auf_%d" % idx):
			_log("FEHLER auf_%d nicht drückbar" % idx)
			s._taste(KEY_E)
			break
		await _bild()
		# freien Platz suchen: Raster im Penthouse, Vorschau steht 2,6 m vor dem Spieler
		var ok := false
		var m := ph.mitte
		for r in range(0, 9):
			for v in range(-4, 5):
				var p := m + Vector2(-9.0 + r * 2.2, -9.0 + (v + 4) * 2.2)
				s.laeufer.position = Vector3(p.x, s.laeufer.position.y, p.y)
				s.laeufer.yaw = 0.0
				await _bild()
				await _bild()
				if ph.platz_ok:
					ok = true
					break
			if ok:
				break
		if ok:
			s._taste(KEY_E)
			await _warte(0.2)
			if w.moebel[idx].steht:
				gestellt += 1
		else:
			s._taste(KEY_ESCAPE)
			await _warte(0.2)
			_log("PENTHOUSE kein freier Platz mehr für %s" % w.moebel[idx].id)
			break
	_log("PENTHOUSE %d aufgestellt, %d stehen, %d im Lager · Boni lohn %.0f %% fläche %.0f %% tempo %.0f %% helfer %.0f %% boost %.0f %%" % [gestellt,
		w.moebel.filter(func(mm): return mm.steht).size(), w.moebel.filter(func(mm): return not mm.steht).size(),
		w.bonus("lohn") * 100, w.bonus("flaeche") * 100, w.bonus("tempo") * 100, w.bonus("helfer") * 100, w.bonus("boost") * 100])
	await _zurueck_nach_unten()

# Casino: jedes Spiel ein paar Runden mit kleinem Einsatz, dazu einmal mit Max
func _casino() -> void:
	st.casino = _zeit()
	var bilanz0 := int(w.statistik.casino_bilanz)
	var cm := s.cmenu
	for i in Casino.STATIONEN.size():
		await _gehe(s.casino.vorne[i])
		await _hinschauen(s.casino.ziel[i])
		s._taste(KEY_E)
		await _warte(0.3)
		if not cm.offen:
			_log("FEHLER Casino-Station %s öffnet nicht" % Casino.STATIONEN[i].id)
			continue
		var id: String = Casino.STATIONEN[i].id
		for runde in 4:
			if runde == 3:
				_knopf(cm, "b_max")
			match id:
				"blackjack":
					if not _knopf(cm, "b_austeilen"):
						break
					var t := 0
					while cm.laeuft and CasinoRegeln.wert(cm.bj_spieler) < 16 and t < 10:
						_knopf(cm, "b_ziehen")
						t += 1
						await _warte(0.4)
					if cm.laeuft:
						_knopf(cm, "b_stehen")
				"rad":
					if not _knopf(cm, "b_drehen"):
						break
				"bandit":
					if not _knopf(cm, "b_hebel"):
						break
				"los":
					if not _knopf(cm, "b_kaufen"):
						break
					await _warte(0.5)
					_knopf(cm, "b_aufdecken")
			var t2 := 0.0
			while cm.laeuft and t2 < 15.0:
				await _warte(0.25)
				t2 += 0.25
			await _warte(0.5)
		s._taste(KEY_E)
		await _warte(0.3)
	_log("CASINO 4 Spiele à 4 Runden: Bilanz %+d € (gesamt %+d €, Rekord %d €)" % [int(w.statistik.casino_bilanz) - bilanz0, int(w.statistik.casino_bilanz), int(w.statistik.casino_rekord)])

func _jetpack_flug() -> void:
	st.jetpack_flug = true
	var fz: Array = s._fahrzeug_liste()
	s._taste(KEY_1 + fz.find("jetpack"))
	await _bild()
	_halte(KEY_SPACE, true)
	await _warte(4.0)
	_halte(KEY_SPACE, false)
	var h := s.laeufer.hoch
	_halte(KEY_CTRL, true)
	var t := 0.0
	while s.laeufer.hoch > 0.01 and t < 20.0:
		await _warte(0.25)
		t += 0.25
	_halte(KEY_CTRL, false)
	_log("JETPACK geflogen bis %.0f m, gelandet=%s" % [h, s.laeufer.hoch < 0.01])
	_fahrzeug_beste()

# --werkzeugtest: jedes Werkzeug putzt 24 Fenster (Stockwerk 30–40, voller Ausbau, keine Boosts/Helfer) – Sekunden pro Fenster
func _werkzeugtest() -> void:
	w.geld = 10000000
	w.stufen = {"motor": 5, "arm": 3, "winde": 10}
	w.helfer = {"putzkraft": 0, "roboter": 0, "drohne": 0}
	s.ereignisse.erlaubt = {"tauben": false, "sandsturm": false, "wind": false, "taa": false}
	for wz in Wirtschaft.WERKZEUGE:
		if not wz.id in w.besitz:
			w.besitz.append(wz.id)
	s._ausruestung()
	await _einsteigen()
	var ergebnis := []
	var nur := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--werkzeuge="):
			nur = a.split("=")[1].split(",")
	for wz in Wirtschaft.WERKZEUGE:
		if not nur.is_empty() and not wz.id in nur:
			continue
		for f in range(30, 41):
			for c in s.turm.fenster_pro_stock[f]:
				s.zustand.verschmutzen(f, c, 1.0)
		s.spieler.y = 30 * Turm.STOCK_H + 1.0
		s.spieler.weg = s.turm.seiten_mitte(30, w.aktive_gondel)
		w.ausruesten(wz.id)
		s._ausruestung()
		s.spieler.gesperrt = true
		await _bild()
		var t0 := _zeit()
		var n0 := s.zustand.sauber_zahl
		while s.zustand.sauber_zahl - n0 < 24 and _zeit() - t0 < 900.0:
			var z := _naechstes_fenster(w.aktive_gondel)
			if z.is_empty():
				break
			await _putze(z)
		var n := s.zustand.sauber_zahl - n0
		ergebnis.append("%s %.2f s" % [wz.id, (_zeit() - t0) / maxf(1, n)])
	_log("WERKZEUGTEST (hand %.1f m/s, Sekunden pro Fenster): %s" % [hand, ", ".join(ergebnis)])

# Gondel parkt direkt neben dem Express-Aufzug: E soll nehmen, wohin man schaut
func _einstieg_test() -> void:
	var sp := s.spieler
	var u := x.sky.unten_pos
	var k := w.aktive_gondel
	sp.weg = s.turm.weg_auf_seite(0, s.turm.naechster_weg(0, u), k)
	sp._platzieren(0.0)
	var g := sp.gondel.global_position
	s.laeufer.gondel_pos = Vector2(g.x, g.z)
	s.laeufer.position = Vector3(u.x, 0, u.y)
	var abstand := s._abstand_gondel()
	await _hinschauen(x.sky.unten_ziel)
	await _bild()
	await _bild()
	var hinweis_a: String = s.hud.status_l.text
	s._taste(KEY_E)
	await _warte(0.3)
	var aufzug := x.menu.offen and x.menu.art == "aufzug_turm" and not sp.aktiv
	if x.menu.offen:
		s._taste(KEY_E)
		await _warte(0.3)
	await _hinschauen(Vector2(g.x, g.z))
	await _bild()
	await _bild()
	var hinweis_g: String = s.hud.status_l.text
	s._taste(KEY_E)
	await _warte(0.3)
	var gondel := sp.aktiv and not x.menu.offen
	_log("EINSTIEGTEST Gondel %.1f m vom Aufzug-Standpunkt: Blick Aufzug → Menü=%s ('%s'), Blick Gondel → eingestiegen=%s ('%s')" % [abstand, aufzug, hinweis_a, gondel, hinweis_g])
	if sp.aktiv:
		s._taste(KEY_E)
		await _warte(0.5)

# --wegtest: zu Fuß zu jeder Station am Boden laufen (echte Kollision) und prüfen, ob man ankommt
func _wegtest() -> void:
	await _einstieg_test()
	var ziele := []
	for i in s.haendler.vorne.size():
		ziele.append(["Kiosk " + str(Haendler.STAENDE[i].id), s.haendler.vorne[i]])
	for i in s.casino.vorne.size():
		ziele.append(["Casino " + str(Casino.STATIONEN[i].id), s.casino.vorne[i]])
	ziele.append(["Casino-Aufzug", s.casino.aufzug_pos])
	ziele.append(["Sky-Aufzug", x.sky.unten_pos])
	for sta in x.laeden.stationen:
		ziele.append(["%s %s" % [sta.laden, sta.id], sta.pos])
	for k in 3:
		var pp: Vector3 = s.gondeln.park_punkt(k).pos
		var nn: Vector3 = s.gondeln.park_punkt(k).normal
		ziele.append(["Gondel %d" % k, Vector2(pp.x + nn.x * 3.2, pp.z + nn.z * 3.2)])
	var fehlt := []
	var h0 := int(st.haenger_fuss)
	for z in ziele:
		await _gehe(z[1])
		var d := Vector2(s.laeufer.position.x, s.laeufer.position.z).distance_to(z[1])
		if d > 1.7:
			fehlt.append("%s (%.1f m)" % [z[0], d])
	_log("WEGTEST %d Ziele, nicht erreicht: %d %s, Hänger %d" % [ziele.size(), fehlt.size(), str(fehlt), int(st.haenger_fuss) - h0])

# ---------------------------------------------------------------- Zu Fuß: Wegsuche auf einem Raster
var raster := PackedByteArray()
var r_n := 0
var r_min := Vector2.ZERO

func _raster_bauen() -> void:
	var t0 := Time.get_ticks_msec()
	var ziele: Array = [s.casino.eingang, s.casino.aufzug_pos, x.sky.unten_pos]
	ziele.append_array(s.haendler.vorne)
	ziele.append_array(s.casino.vorne)
	for sta in x.laeden.stationen:
		ziele.append(sta.pos)
	var weit := 0.0
	for p in ziele:
		weit = maxf(weit, (p as Vector2).length())
	weit += 40.0
	r_min = Vector2(-weit, -weit)
	r_n = int(2.0 * weit / ZELLE)
	raster.resize(r_n * r_n)
	raster.fill(0)
	var L := s.laeufer
	var gebiet := Rect2(r_min, Vector2.ONE * 2.0 * weit)
	# 1 = nah an einer Kante (wird gemieden, damit der Bot nicht genau auf Ecken zuläuft), 2 = fest
	for stufe in [[Laeufer.RADIUS + 0.4, 1], [Laeufer.RADIUS + 0.05, 2]]:
		for r in L.haeuser + L.hindernisse:
			var rr: Rect2 = (r as Rect2).grow(float(stufe[0]))
			if rr.intersects(gebiet):
				_rect_sperren(rr, int(stufe[1]))
	for pg in L.polygone + [L.turm_rand]:
		_poly_sperren(pg)
	_log("RASTER %d×%d Zellen (%.0f m), %d ms" % [r_n, r_n, 2.0 * weit, Time.get_ticks_msec() - t0])

func _zelle(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - r_min.x) / ZELLE)), int(floor((p.y - r_min.y) / ZELLE)))

func _mitte(z: Vector2i) -> Vector2:
	return r_min + (Vector2(z) + Vector2(0.5, 0.5)) * ZELLE

func _rect_sperren(r: Rect2, wert := 2) -> void:
	var a := _zelle(r.position)
	var b := _zelle(r.end)
	for zy in range(maxi(0, a.y), mini(r_n, b.y + 1)):
		for zx in range(maxi(0, a.x), mini(r_n, b.x + 1)):
			if r.has_point(_mitte(Vector2i(zx, zy))):
				raster[zy * r_n + zx] = maxi(raster[zy * r_n + zx], wert)

func _poly_sperren(pg: PackedVector2Array) -> void:
	if pg.size() < 3:
		return
	var lo := pg[0]
	var hi := pg[0]
	for p in pg:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var a := _zelle(lo)
	var b := _zelle(hi)
	for zy in range(maxi(0, a.y), mini(r_n, b.y + 1)):
		for zx in range(maxi(0, a.x), mini(r_n, b.x + 1)):
			if Geometry2D.is_point_in_polygon(_mitte(Vector2i(zx, zy)), pg):
				raster[zy * r_n + zx] = 2

func _frei_zelle(z: Vector2i, extra: Dictionary) -> bool:
	if z.x < 0 or z.y < 0 or z.x >= r_n or z.y >= r_n:
		return false
	var i := z.y * r_n + z.x
	return raster[i] < 2 and not extra.has(i)

# A* auf dem Raster, danach Abkürzungen, die laeufer.frei() erlaubt
func _weg(von: Vector2, nach: Vector2) -> PackedVector2Array:
	var extra := {}
	var gondeln: Array = s.gondeln.positionen().duplicate()
	if not s.spieler.aktiv:
		var g := s.spieler.gondel.global_position
		gondeln.append(Vector2(g.x, g.z))
	for g in gondeln:
		var gz := _zelle(g)
		var rz := ceili((Laeufer.GONDEL_R + Laeufer.RADIUS + 0.1) / ZELLE)
		for dy in range(-rz, rz + 1):
			for dx in range(-rz, rz + 1):
				var z := gz + Vector2i(dx, dy)
				if z.x >= 0 and z.y >= 0 and z.x < r_n and z.y < r_n and _mitte(z).distance_to(g) < Laeufer.GONDEL_R + Laeufer.RADIUS + 0.1:
					extra[z.y * r_n + z.x] = true
	var start := _naechste_freie(_zelle(von), extra)
	var ziel := _naechste_freie(_zelle(nach), extra)
	if start.x < 0 or ziel.x < 0:
		return PackedVector2Array([von, nach])
	var si := start.y * r_n + start.x
	var zi := ziel.y * r_n + ziel.x
	var g_kosten := {si: 0.0}
	var her := {si: -1}
	var offen_f := [0.0]
	var offen_i := [si]
	var nb := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var schritte := 0
	var gefunden := false
	while offen_i.size() > 0 and schritte < 400000:
		schritte += 1
		var i: int = _heap_pop(offen_f, offen_i)
		if i == zi:
			gefunden = true
			break
		var z := Vector2i(i % r_n, i / r_n)
		var gi: float = g_kosten[i]
		for d in nb:
			var n: Vector2i = z + d
			if not _frei_zelle(n, extra):
				continue
			if d.x != 0 and d.y != 0 and (not _frei_zelle(Vector2i(z.x + d.x, z.y), extra) or not _frei_zelle(Vector2i(z.x, z.y + d.y), extra)):
				continue
			var ni := n.y * r_n + n.x
			var ng := gi + (1.4142 if d.x != 0 and d.y != 0 else 1.0) * (6.0 if raster[n.y * r_n + n.x] == 1 else 1.0)
			if ng < float(g_kosten.get(ni, INF)):
				g_kosten[ni] = ng
				her[ni] = i
				var h := Vector2(n - ziel).length()
				_heap_push(offen_f, offen_i, ng + h, ni)
	if not gefunden:
		_log("WEG nicht gefunden von (%.0f, %.0f) nach (%.0f, %.0f) nach %d Schritten" % [von.x, von.y, nach.x, nach.y, schritte])
		return PackedVector2Array([von, nach])
	var roh := PackedVector2Array()
	var k := zi
	while k >= 0:
		roh.append(_mitte(Vector2i(k % r_n, k / r_n)))
		k = int(her[k])
	roh.reverse()
	roh[0] = von
	roh.append(nach)
	# glätten: so weit wie möglich geradeaus (mit der echten Kollision geprüft)
	var glatt := PackedVector2Array([von])
	var a := 0
	while a < roh.size() - 1:
		var b := mini(roh.size() - 1, a + 80)
		while b > a + 1 and not _gerade_frei(roh[a], roh[b]):
			b -= 1
		glatt.append(roh[b])
		a = b
	return glatt

func _gerade_frei(a: Vector2, b: Vector2) -> bool:
	var n := maxi(1, int(a.distance_to(b) / 0.2))
	for i in range(1, n + 1):
		var p := a.lerp(b, float(i) / n)
		if raster.size() > 0 and raster[clampi(_zelle(p).y, 0, r_n - 1) * r_n + clampi(_zelle(p).x, 0, r_n - 1)] >= 1 and i < n and i > 2:
			return false
		if i % 2 == 0 and not s.laeufer.frei(p):
			return false
	return true

func _naechste_freie(z: Vector2i, extra: Dictionary) -> Vector2i:
	for r in 12:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and _frei_zelle(z + Vector2i(dx, dy), extra):
					return z + Vector2i(dx, dy)
	return Vector2i(-1, -1)

func _heap_push(fa: Array, ia: Array, f: float, i: int) -> void:
	fa.append(f)
	ia.append(i)
	var k := fa.size() - 1
	while k > 0:
		var p := (k - 1) / 2
		if fa[p] <= fa[k]:
			break
		var tf: float = fa[p]; fa[p] = fa[k]; fa[k] = tf
		var ti: int = ia[p]; ia[p] = ia[k]; ia[k] = ti
		k = p

func _heap_pop(fa: Array, ia: Array) -> int:
	var oben: int = ia[0]
	var lf: float = fa.pop_back()
	var li: int = ia.pop_back()
	if fa.size() > 0:
		fa[0] = lf
		ia[0] = li
		var k := 0
		var n := fa.size()
		while true:
			var l := 2 * k + 1
			var r := l + 1
			var m := k
			if l < n and fa[l] < fa[m]: m = l
			if r < n and fa[r] < fa[m]: m = r
			if m == k:
				break
			var tf: float = fa[m]; fa[m] = fa[k]; fa[k] = tf
			var ti: int = ia[m]; ia[m] = ia[k]; ia[k] = ti
			k = m
	return oben

# Zu Fuß (oder mit Fahrzeug) zu einem Punkt laufen: W halten, Blick zum nächsten Wegpunkt
func _gehe(ziel: Vector2) -> void:
	if x.ort != "":
		await _zurueck_nach_unten()
	var L := s.laeufer
	var von := Vector2(L.position.x, L.position.z)
	if von.distance_to(ziel) < 0.5:
		return
	var pfad := _weg(von, ziel)
	var rennen := w.fahrzeug == ""
	_halte(KEY_SHIFT, rennen)
	_halte(KEY_W, true)
	var i := 1
	var still := 0.0
	var alt := von
	var t := 0.0
	var versuche := 0
	while i < pfad.size():
		var q := Vector2(L.position.x, L.position.z)
		var d := pfad[i] - q
		if d.length() < (0.35 if i == pfad.size() - 1 else 0.8):
			i += 1
			continue
		L.yaw = atan2(-d.x, -d.y)
		await _bild()
		var dt := get_process_delta_time()
		still += dt
		t += dt
		if still > 1.5:
			if q.distance_to(alt) < 0.4 and q.distance_to(ziel) < 1.6:
				break   # Ziel steht knapp hinter einer Kante (Theke, Station): nah genug
			if q.distance_to(alt) < 0.4 and versuche == 0 and still < 2.0:
				for k in [KEY_A, KEY_D]:
					var vor := Vector2(L.position.x, L.position.z)
					_halte(k, true)
					await _warte(0.6)
					_halte(k, false)
					if Vector2(L.position.x, L.position.z).distance_to(vor) > 0.3:
						break
				q = Vector2(L.position.x, L.position.z)
				alt = q - Vector2(1, 0)   # ausgewichen: als Bewegung zählen
			if q.distance_to(alt) < 0.4:
				versuche += 1
				_laufen_haenger += 1
				st.haenger_fuss = int(st.haenger_fuss) + 1
				_log("HÄNGER zu Fuß bei (%.1f, %.1f) auf dem Weg nach (%.1f, %.1f), Wegpunkt %d/%d – %s" % [q.x, q.y, ziel.x, ziel.y, i, pfad.size(), "neuer Weg" if versuche < 3 else "Bot stellt sich ans Ziel"])
				if versuche >= 3:
					L.position = Vector3(ziel.x, 0, ziel.y)
					break
				pfad = _weg(q, ziel)
				i = 1
			alt = q
			still = 0.0
		if t > 240.0:
			_log("HÄNGER zu Fuß: Weg nach (%.1f, %.1f) dauert über 4 min" % [ziel.x, ziel.y])
			L.position = Vector3(ziel.x, 0, ziel.y)
			break
	_halte(KEY_W, false)
	_halte(KEY_SHIFT, false)
	await _bild()

# ---------------------------------------------------------------- Angeln (Strand, Steg, Fischladen)
# Weit laufen: Route der Karte (um den See, über den Boulevard, Treppe) Stück für Stück mit _gehe
func _gehe_weit(ziel: Vector2, ebene := 0) -> void:
	if x.ort != "":
		await _zurueck_nach_unten()
	s.karte.ziel_setzen(ziel, "Bot", ebene)
	var r: PackedVector2Array = s.karte.route.duplicate()
	s.karte.ziel_loeschen()
	var von := Vector2(s.laeufer.position.x, s.laeufer.position.z)
	if r.size() <= 1 and von.distance_to(ziel) > 150.0:
		_log("ROUTE fehlt von (%.0f, %.0f) nach (%.0f, %.0f) – geradeaus" % [von.x, von.y, ziel.x, ziel.y])
	for p in r:
		await _gehe(p)

func _strand_station(art: String) -> Dictionary:
	for k in s.strand.stationen():
		if k.art == art:
			return k
	return {}

func _fischladen(knoepfe: Array) -> void:
	var stt := _strand_station("fischladen")
	await _gehe_weit(stt.pos)
	await _hinschauen(stt.ziel)
	s._taste(KEY_E)
	await _warte(0.3)
	if not s.strand.menu.offen:
		_log("FEHLER Fischladen öffnet nicht (bei %.0f, %.0f)" % [s.laeufer.position.x, s.laeufer.position.z])
		return
	for n in knoepfe:
		if str(n).begins_with("angel_"):
			s.strand.menu.reiter = 1
			s.strand.menu.aufbauen()
		var g0 := w.geld
		if _knopf(s.strand.menu, n):
			if w.geld < g0:
				_kauf("%s im Fischladen" % n, g0 - w.geld)
		await _bild()
	s._taste(KEY_E)
	await _warte(0.3)

# Strandbar: Drinks mit Angel-Wirkung
func _strandbar(knoepfe: Array) -> void:
	var stt := _strand_station("strandbar")
	await _gehe_weit(stt.pos, 1)
	await _hinschauen(stt.ziel)
	s._taste(KEY_E)
	await _warte(0.3)
	if not s.hmenu.offen:
		_log("FEHLER Strandbar öffnet nicht (bei %.0f, %.0f, y=%.1f)" % [s.laeufer.position.x, s.laeufer.position.z, s.laeufer.position.y])
		return
	for n in knoepfe:
		var g0 := w.geld
		if _knopf(s.hmenu, n):
			_kauf("%s an der Strandbar" % n, g0 - w.geld)
	s._taste(KEY_E)
	await _warte(0.3)

func _angelausflug() -> void:
	st.angeln = _zeit()
	var t0 := _zeit()
	var r := _rate()
	var verdient0 := int(w.statistik.verdient)
	# Angel kaufen bzw. aufrüsten (wie ein Mensch: nur wenn es kaum weh tut)
	var kauf := []
	for a in Wirtschaft.ANGELN:
		if not a.id in w.angeln and (int(a.preis) <= 0.5 * w.geld if a.id == "bambus" else int(a.preis) * 8 <= w.geld):
			kauf.append("angel_" + str(a.id))
	if w.angel() == "" and kauf.is_empty():
		return
	_log("AUSFLUG Angeln (Angel %s, Käufe %s)" % [w.angel(), str(kauf)])
	var drinks := []
	for d in ["b_mango", "b_kokos", "b_limette"]:
		if w.boost_preis(d.substr(2)) * 30 <= w.geld:
			drinks.append(d)
	if not drinks.is_empty():
		await _strandbar(drinks)
	await _fischladen(kauf)
	# an die Steg-Spitze, Richtung Meer
	var platz: Vector2 = Kueste.KOPF.get_center() + Vector2(-11.0, randf_range(-8.0, 8.0))
	await _gehe_weit(platz)
	await _hinschauen(platz + Vector2(-10.0, 0.0))
	await _bild()
	if not s.angel_hand:   # 19.11.2026: Angel aus der Leiste in die Hand nehmen
		s._taste(KEY_1 + s.angel_taste() - 1)
		await _warte(0.3)
	if s.strand.wurf_ziel() == Vector3.INF:
		_log("FEHLER Angeln: an der Steg-Spitze kein Wurf möglich (bei %.0f, %.0f, y=%.1f)" % [s.laeufer.position.x, s.laeufer.position.z, s.laeufer.position.y])
		return
	var t_angeln := _zeit()
	var n0 := int(w.statistik.fische)
	var arten0 := w.fisch_index.size()
	var runden := 0
	while _zeit() - t_angeln < ANGEL_DAUER:
		runden += 1
		if not await _angel_runde():
			await _warte(1.0)
			if s.strand.wurf_ziel() == Vector3.INF:
				await _hinschauen(Vector2(s.laeufer.position.x - 10.0, s.laeufer.position.z))
	var minuten := (_zeit() - t_angeln) / 60.0
	var fische := int(w.statistik.fische) - n0
	var wert := 0
	for id in w.fischkiste:
		wert += int(w.fischkiste[id]) * w.fisch_preis(id)
	await _fischladen(["verkauf_alle"])
	var gesamt_min := (_zeit() - t0) / 60.0
	var helfer_geld := int(w.statistik.verdient) - verdient0 - wert
	st.angel_runden = int(st.angel_runden) + 1
	st.angel_geld = int(st.angel_geld) + wert
	st.angel_minuten = float(st.angel_minuten) + gesamt_min
	# zurück zur Gondel (Route über Boulevard und um den See)
	var g := s.spieler.gondel.global_position
	var nn := s.spieler.normal
	await _gehe_weit(Vector2(g.x + nn.x * 3.2, g.z + nn.z * 3.2))
	st.angel_minuten = float(st.angel_minuten) - gesamt_min
	gesamt_min = (_zeit() - t0) / 60.0   # mit echtem Rückweg
	st.angel_minuten = float(st.angel_minuten) + gesamt_min
	_log("ANGELN %.1f min geangelt (+%.1f min Wege): %d Fische in %d Würfen, Index %d→%d/20, Erlös %d € = %.0f €/min beim Angeln, %.0f €/min mit Wegen | Putzen vorher %.0f €/min (selbst %.1f Fenster/min), Helfer während des Ausflugs %d € | Angel %s, Abschnitt %d" % [
		minuten, gesamt_min - minuten, fische, runden, arten0, w.fisch_index.size(), wert, wert / maxf(minuten, 0.1), wert / maxf(gesamt_min, 0.1),
		r.geld, r.selbst, helfer_geld, w.angel(), w.hoechster_abschnitt])

# Eine Angel-Runde mit echter Maustaste: Klick, warten, Spannungsbalken mit Reaktionszeit (sieht den Fisch ~0,2 s zu spät)
func _angel_runde() -> bool:
	var A := s.strand.angeln
	if s.strand.wurf_ziel() == Vector3.INF:
		return false
	s._klick(Vector2(400, 300), true)
	s._klick(Vector2(400, 300), false)
	await _bild()
	if not A.aktiv():
		return false
	var fische0 := int(w.statistik.fische)
	var halte := false
	var verlauf: Array = []
	var t := 0.0
	while A.aktiv() and t < 90.0:
		await _bild()
		t += get_process_delta_time()
		if A.zustand != "drill":
			continue
		verlauf.append([t, A.fp])
		while verlauf.size() > 1 and t - float(verlauf[1][0]) > 0.5 / hand:   # Reaktionszeit: 0,2 s (schnelle Hand) … 0,4 s (langsam)
			verlauf.pop_front()
		var fp_gesehen: float = verlauf[0][1]
		var mitte := A.kp + A.kasten_g * 0.5 + A.kv * 0.2
		var soll := fp_gesehen > mitte
		if soll != halte:
			halte = soll
			s._klick(Vector2(400, 300), halte)
	if halte:
		s._klick(Vector2(400, 300), false)
	await _bild()
	return int(w.statistik.fische) > fische0

# --angeltest[=MIN]: nur angeln (an der Steg-Spitze) und messen. Weitere Schalter: --angel=bambus|carbon|hochsee,
# --abschnitt=N (Preis-Stufe), --drinks (Mango + Kokos + Limette laufen die ganze Zeit), --boot (von der Yacht weit draußen)
func _angeltest() -> void:
	var angel := "bambus"
	var drinks := false
	var boot := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--angel="):
			angel = a.split("=")[1]
		if a.begins_with("--abschnitt="):
			w.hoechster_abschnitt = int(a.split("=")[1])
		if a == "--drinks":
			drinks = true
		if a == "--boot":
			boot = true
	for a in Wirtschaft.ANGELN:
		w.angeln.append(a.id)
		if a.id == angel:
			break
	await _aussteigen()
	if boot:
		w.yacht = true
		s.strand.einsteigen()
		s.strand.yacht.position = Vector3(Kueste.WASSER_X - 400.0, Kueste.MEER_Y, -200.0)
		s.strand.yacht.tempo = 0.0
	else:
		var platz: Vector2 = Kueste.KOPF.get_center() + Vector2(-11.0, 0.0)
		s.laeufer.position = Vector3(platz.x, 0.0, platz.y)
		await _hinschauen(platz + Vector2(-10.0, 0.0))
	var t0 := _zeit()
	var zahl := {}
	var runden := 0
	var erste_alle := -1.0
	while _zeit() - t0 < angeltest * 60.0:
		if drinks:
			for d in ["mango", "kokos", "limette"]:
				if not w.boost_aktiv(d):
					w.boosts[d] = 600.0
		runden += 1
		var n0: Dictionary = w.fischkiste.duplicate()
		await _angel_runde()
		for id in w.fischkiste:
			if int(w.fischkiste[id]) > int(n0.get(id, 0)):
				zahl[id] = int(zahl.get(id, 0)) + 1
		if erste_alle < 0.0 and w.index_voll():
			erste_alle = _zeit() - t0
	var minuten := (_zeit() - t0) / 60.0
	var fische := 0
	var wert := 0
	for id in w.fischkiste:
		fische += int(w.fischkiste[id])
		wert += int(w.fischkiste[id]) * w.fisch_preis(id)
	var teile := []
	for f in Wirtschaft.FISCHE:
		teile.append("%s %d" % [f.id, int(zahl.get(f.id, 0))])
	_log("ANGELTEST %s%s%s Abschnitt %d: %.0f min, %d Würfe, %d Fische (%.1f/min, %.0f %% der Würfe), Index %d/20%s, Wert %d € = %.1f €/min | %s" % [
		angel, " + Drinks" if drinks else "", " vom Boot" if boot else "", w.hoechster_abschnitt, minuten, runden, fische, fische / maxf(minuten, 0.1),
		100.0 * fische / maxf(runden, 1), w.fisch_index.size(), (" (alle nach %.0f min)" % (erste_alle / 60.0)) if erste_alle >= 0.0 else "", wert, wert / maxf(minuten, 0.1), ", ".join(teile)])

# ================================================================ Koop-Bot (Phase 7h)
# Gondel k gehört gerade einem Mitspieler (dessen aktive_gondel, wie Netz._gondel_fahrer)
func _fremd_belegt(k: int) -> bool:
	if not Netz.aktiv():
		return false
	for pid in w.anwesend:
		if str(pid) != w.ich and int((w.spieler_daten.get(str(pid), {}) as Dictionary).get("aktive_gondel", -1)) == k:
			return true
	return false

func _koop_starten() -> void:
	var e := Netz.host_starten(KOOP_PORT)
	if e != "":
		_log("FEHLER Koop-Gastgeber: " + e)
		return
	if not Netz.test_nachricht_da.is_connected(_koop_nachricht):
		Netz.test_nachricht_da.connect(_koop_nachricht)
	for n in 2:
		var name := "koopgast%d" % (n + 1)
		var args := ["--headless", "--fixed-fps", "20", "--log-file", OS.get_user_data_dir().path_join("koop_gast%d.log" % (n + 1)),
			"--path", ProjectSettings.globalize_path("res://"), "--", "--durchspielen", "--koop-gast", "--profil=" + name, "--stand=" + name,
			"--join=127.0.0.1:%d" % KOOP_PORT]
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--hand=") or a.begins_with("--netz-") or a.begins_with("--koop-fps="):
				args.append(a)
		var pid := OS.create_process(OS.get_executable_path(), args)
		_log("KOOP Gast %s gestartet (pid %d, Log user://koop_gast%d.log)" % [name, pid, n + 1])
		await _warte(3.0)

func _koop_takt() -> void:
	_koop_bilder += 1
	# Gleiches Tempo für alle Prozesse (Engine.max_fps wirkt mit --fixed-fps nicht): vor der Soll-Zeit kurz schlafen
	var soll_ms := int(_koop_bilder * 50.0 / (koop_fps / 20.0))
	var ist_ms := Time.get_ticks_msec() - _koop_ms
	if soll_ms > ist_ms:
		OS.delay_msec(mini(soll_ms - ist_ms, 100))
	var n := 0
	for id in s.zustand.slot_fenster:
		if id >= 0:
			n += 1
	_slots_max = maxi(_slots_max, n)
	if koop == "host" and Netz.ist_host() and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		var h := (multiplayer.multiplayer_peer as ENetMultiplayerPeer).host
		if h:
			_netz_bytes += h.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) + h.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	if koop == "gast" and Netz.ist_gast() and _zeit() >= _naechster_abgleich:
		_naechster_abgleich = _zeit() + ABGLEICH_ALLE
		Netz.test_nachricht.rpc_id(1, "KOOP " + JSON.stringify(_koop_bericht()))

# Spielgeschwindigkeit dieses Prozesses (Spielsekunden je echter Sekunde)
func _tempo() -> float:
	return _koop_bilder * 0.05 / maxf(0.001, (Time.get_ticks_msec() - _koop_ms) / 1000.0)

func _koop_bericht() -> Dictionary:
	return {"name": Netz.profil.name, "zahl": s.zustand.sauber_zahl, "geld": w.geld, "besitz": w.besitz.size(), "stufen": str(w.stufen), "helfer": str(w.helfer),
		"gondeln": w.gondeln_gekauft(), "seite": w.aktive_gondel, "in_gondel": s.spieler.aktiv, "werkzeug": w.aktiv, "tempo": snappedf(_tempo(), 0.1),
		"slots": _slots_max, "verdraengt": s.zustand.verdraengt, "unerreichbar": unerreichbar.size(), "tote_zeit": int(st.get("tote_zeit", 0))}

func _koop_nachricht(_id: int, t: String) -> void:
	if t == "KOOP?" and koop == "gast":
		Netz.test_nachricht.rpc_id(1, "KOOP " + JSON.stringify(_koop_bericht()))
		return
	if not t.begins_with("KOOP ") or koop != "host":
		return
	var d = JSON.parse_string(t.substr(5))
	if not (d is Dictionary):
		return
	_abgleich[str(d.name)] = d
	var ich: Dictionary = JSON.parse_string(JSON.stringify(_koop_bericht()))   # gleiche Zahlendarstellung wie der Bericht
	var abw := []
	for k in ["zahl", "geld", "besitz", "stufen", "helfer", "gondeln"]:
		if str(d[k]) != str(ich[k]):
			abw.append("%s %s≠%s" % [k, str(d[k]), str(ich[k])])
	_log("ABGLEICH %s: %s | Seite %s, in Gondel %s, Werkzeug %s, Tempo %s×, Atlas max %s (verdrängt %s), unerreichbar %s, tote Zeit %s s" % [d.name,
		"gleich" if abw.is_empty() else "ABWEICHUNG " + ", ".join(abw), d.seite, d.in_gondel, d.werkzeug, d.tempo, d.slots, d.verdraengt, d.unerreichbar, d.tote_zeit])

func _koop_stand() -> void:
	var je := []
	for id in Netz.spieler:
		var pid: String = w.ich if id == 1 else str(Netz.spieler[id].profil_id)
		je.append("%s %d" % [Netz.name_von(id), int(w.fenster_je.get(pid, 0))])
	var min_spiel := maxf(1.0, _zeit() / 60.0)
	_log("KOOP spieler=%d faktor=×%.1f fenster je Spieler: %s | Helfer %d | Netz %.1f KB je Spielminute | Tempo %.1f× | Atlas max %d, verdrängt %d" % [
		Netz.spieler.size(), w.koop_faktor(), ", ".join(je), int(w.statistik.fenster_helfer), _netz_bytes / 1024.0 / min_spiel, _tempo(), _slots_max, s.zustand.verdraengt])

# Ende: letzter Abgleich mit beiden Gästen (alle Fenster sauber → nichts ändert sich mehr)
func _koop_ende() -> void:
	_koop_stand()
	_abgleich = {}
	for id in Netz.spieler:
		if id != 1:
			Netz.test_nachricht.rpc_id(id, "KOOP?")
	var t := 0.0
	while _abgleich.size() < Netz.spieler.size() - 1 and t < 10.0:
		await _warte(0.5)
		t += 0.5
	_log("KOOP Schluss-Abgleich: %d von %d Gästen gemeldet" % [_abgleich.size(), Netz.spieler.size() - 1])

# Gast: eigene Gondel sicherstellen (frei + gekauft, sonst eine freie kaufen). false = keine Gondel zu haben
func _gast_gondel() -> bool:
	var k := w.aktive_gondel
	if s.spieler.aktiv and k >= 0 and not _fremd_belegt(k):
		return true
	if s.spieler.aktiv:   # sitzt in einer Gondel, die ein anderer hat (sollte nicht vorkommen)
		_log("FEHLER Gast sitzt in Gondel %d, die ein Mitspieler hat" % k)
		await _aussteigen()
	if k >= 0 and k < 3 and w.gondeln[k].gekauft and not _fremd_belegt(k):
		await _einsteigen()
		return s.spieler.aktiv
	var wahl := -1
	for j in 3:
		if w.gondeln[j].gekauft and not _fremd_belegt(j):
			wahl = j
			break
	if wahl < 0:
		for j in 3:
			if not w.gondeln[j].gekauft and w.geld >= w.gondel_preis():
				wahl = j
				break
	if wahl < 0:
		return false
	_log("GONDEL nehme Gondel %s (%s)" % [Turm.SEITEN_NAMEN[wahl], "gekauft" if w.gondeln[wahl].gekauft else "kaufe für %d €" % w.gondel_preis()])
	await _seite_wechseln(wahl)
	return s.spieler.aktiv and w.aktive_gondel == wahl

# Gast ohne Gondel: angeln (Geld in die gemeinsame Kasse) oder kurz warten
func _gast_warten() -> void:
	if not st.has("ohne_gondel_seit"):
		st["ohne_gondel_seit"] = _zeit()
		_log("WARTEN keine freie Gondel (Kasse %d €, Gondel kostet %d €)" % [w.geld, w.gondel_preis()])
	await _warte(5.0)
	st.tote_zeit = float(st.tote_zeit) + 5.0

# Gast: besseres (vom Gastgeber gekauftes) Werkzeug in die Hand nehmen
func _gast_werkzeug() -> void:
	if st.has("ohne_gondel_seit"):
		_log("GONDEL wieder putzen nach %d s ohne Gondel" % int(_zeit() - float(st.ohne_gondel_seit)))
		st.erase("ohne_gondel_seit")
	if _zeit() < _gast_werkzeug_zeit:
		return
	_gast_werkzeug_zeit = _zeit() + 60.0
	var beste := _bestes_werkzeug()
	if w.aktiv == beste:
		return
	for i in Wirtschaft.WERKZEUGE.size():
		if Wirtschaft.WERKZEUGE[i].id == beste:
			s._taste(KEY_0 if i == 9 else KEY_1 + i)
	await _bild()
	_log("WERKZEUG %s in der Hand (%s)" % [w.aktiv, "ok" if w.aktiv == beste else "FEHLER Taste"])

# 7h: eigene (bzw. geholfene) Seite sauber, woanders noch Dreck → mit H mithelfen (wie ein Mensch nach dem Hinweis)
func _koop_helfen() -> bool:
	if not s.spieler.aktiv or s.express:
		return false
	var d: Array = s.dreck_je_seite()
	var anderswo := false
	for k in 3:
		if k != s.spieler.seite and int(d[k]) > 0:
			anderswo = true
	if not anderswo:
		return false
	var vorher := s.spieler.seite
	s._taste(KEY_H)
	await _warte(1.0)
	if s.spieler.seite == vorher:
		_log("FEHLER Mithelfen (H) wechselt die Seite nicht")
		return false
	st["helfen"] = int(st.get("helfen", 0)) + 1
	_log("HELFEN jetzt auf Seite %s (Dreck je Seite %s, eigene Gondel %s)" % [Turm.SEITEN_NAMEN[s.spieler.seite], str(d), Turm.SEITEN_NAMEN[w.aktive_gondel]])
	return true
