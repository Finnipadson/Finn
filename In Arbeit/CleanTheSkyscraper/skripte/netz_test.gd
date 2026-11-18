class_name NetzTest
extends Node
# Test 37 – Mehrspieler-Grundlage (Phase 7a), läuft headless mit mehreren Prozessen auf 127.0.0.1:
#   godot --headless --path . -- --ansicht=37 [--netz-verzoegerung=150 --netz-verlust=5]
# Der Gastgeber-Prozess startet die Gäste selbst (OS.create_process, --rolle=gast --profil=testgastN --join=…).
# Ablauf: Gast 1 tritt bei (Geld, Fenster, Tageszeit, Spielerliste gleich?) → beide laufen, jeder sieht die Figur des
# anderen an der richtigen Stelle → Gastgeber ändert Geld, Gast 2 tritt mitten im Spiel bei → Gast 3 wird abgelehnt
# (voll) → Gast 2 verlässt die Runde selbst → Gastgeber beendet, Gast 1 landet mit Meldung im Hauptmenü.
# Phase 7b (Befehle + Kasse): Einzelspieler-Umrechnung alt ↔ neu und koop_faktor ohne Netz; dann kauft Gast 1 über die
# echten Knöpfe (Werkstatt: Motor, Kiosk: Abzieher, Kaffee, Espresso) → bei allen besessen, Geld stimmt, Koop-Preis ×1,5,
# Boost nur beim Käufer (Helfer-Boost Espresso wirkt für alle); Gastgeber kauft eine Putzkraft → offenes Menü beim Gast
# aktualisiert sich; Kasse fast leer → Knopf beim Gast gesperrt, Kauf trotzdem geschickt → vom Gastgeber abgelehnt;
# zu dritt Preise ×2, Gast 2 hat alles Gekaufte, aber keinen Boost.
# Gäste melden per Netz.test_nachricht („OK …“/„FEHLER …“) bzw. nach dem Trennen per Datei user://netztest_<profil>.txt.
# Ergebnis: „NETZTEST ERGEBNIS ok=… fehler=…“.

const TEST_PORT := 24681
const SAUBER := 25

var s: Spiel
var gast := false
var ok := 0
var fehler := 0
var schritt := 0
var zeit := 0.0
var warte_bis := 0.0
var frist := 0.0          # Zeitlimit des aktuellen Schritts
var ids := {}              # profil-name -> peer-id
var gemeldet := false
var _host_pos := Vector3.ZERO

func setup(sp: Spiel) -> void:
	s = sp
	gast = "--rolle=gast" in OS.get_cmdline_user_args()
	Netz.test_nachricht_da.connect(_nachricht)
	if "--nur-menue" in OS.get_cmdline_user_args():   # Testbild: Hauptmenü → Mehrspieler-Fenster
		_menue_bild()
		return
	if gast:
		_gast_setup()
	else:
		_host_setup()

func _menue_bild() -> void:
	await get_tree().create_timer(1.5).timeout
	var m: Hauptmenue = s.get_parent().hauptmenue_zeigen()
	await get_tree().create_timer(0.5).timeout
	m._mehrspieler()
	Netz.status_geaendert.emit("Verbinde mit 192.168.1.23:24680 …")
	await get_tree().create_timer(1.0).timeout
	print("NETZTEST BILD frame=%d" % Engine.get_frames_drawn())
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()

func _p(name: String, gut: bool, info := "") -> void:
	if gut:
		ok += 1
	else:
		fehler += 1
	print("NETZTEST %s %s %s" % ["OK  " if gut else "FEHLER", name, info])

func _profil() -> String:
	return Netz.profil_pfad.get_file().get_basename().substr(7)

# ================================================================ Gastgeber
func _host_setup() -> void:
	if Netz.profil_pfad == "user://profil_test.json":   # eigener Name für den Test-Gastgeber
		Netz.profil_pfad = "user://profil_testhost.json"
		Netz.profil = {"id": "", "name": "", "farbe": 0}
		Netz.profil_laden()
	s.wirtschaft.ich_setzen(str(Netz.profil.id))
	_einzel_pruefen()
	for n in ["testgast1", "testgast2", "testgast3"]:
		var d := "user://netztest_%s.txt" % n
		if FileAccess.file_exists(d):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(d))
	var e := Netz.host_starten(TEST_PORT)
	_p("Gastgeber gestartet", e == "", e)
	s.wirtschaft.geld = 4321
	for i in SAUBER:
		s.zustand.sauber_machen(1, i)
	s.welt.zeit.phase = 0.3
	s.welt.zeit.laeuft = true
	s.spieler.y = 0.3
	s.start_zu_fuss = 2          # zu Fuß, damit Gäste eine Figur sehen
	schritt = 1

# 7b ohne Netz: alter Stand → spieler_daten, Speichern wie früher, Koop-Stand als Gast/allein laden, Helfer-Boost, Preis-Faktor
func _einzel_pruefen() -> void:
	var w := s.wirtschaft
	_p("Einzelspieler: Preis-Faktor 1", w.koop_faktor() == 1.0 and w.upgrade_preis("motor") == 25 and w.werkzeug_preis("abzieher") == 120 and w.gondel_preis() in [0, 1000, 5000], "×%.2f, Motor %d €" % [w.koop_faktor(), w.upgrade_preis("motor")])
	var alt := {"geld": 50, "besitz": ["schwamm", "abzieher"], "aktiv": "abzieher", "boosts": {"kaffee": 100.0}, "fahrzeuge": ["scooter"], "fahrzeug": "scooter",
		"aktive_gondel": 1, "radio": {"an": false, "sender": 2}, "kosmetik_besitz": ["gondel_rot"], "kosmetik_aktiv": {"gondel": "gondel_rot"}}
	var w2 := Wirtschaft.new()
	w2.ich = "p1"
	w2.laden(alt)
	_p("Alter Stand → Werte je Spieler", w2.spieler_daten.has("p1") and w2.aktiv == "abzieher" and w2.boost_aktiv("kaffee") and w2.fahrzeug == "scooter" and w2.aktive_gondel == 1 and not w2.radio.an and w2.kosmetik_aktiv.gondel == "gondel_rot" and w2.kosmetik_aktiv.lack == "lack_uni", str(w2.spieler_daten.get("p1", {})))
	var d2 := w2.speichern()
	_p("Speichern allein wie früher", d2.aktiv == "abzieher" and d2.fahrzeug == "scooter" and int(d2.aktive_gondel) == 1 and (d2.boosts as Dictionary).has("kaffee") and not d2.has("spieler_daten") and d2.spieler_id == "p1", "")
	# Koop-Stand: p2 war Gast mit Eis
	w2.spieler_daten["p2"] = w2.spieler_pruefen({"aktiv": "schwamm", "boosts": {"eis": 50.0, "espresso": 40.0}, "aktive_gondel": 2})
	var d3: Dictionary = JSON.parse_string(JSON.stringify(w2.speichern()))
	var w3 := Wirtschaft.new()
	w3.ich = "p2"
	w3.laden(d3, true)
	_p("Koop-Stand als Gast laden", w3.aktiv == "schwamm" and w3.boost_aktiv("eis") and not w3.boost_aktiv("kaffee") and w3.aktive_gondel == 2 and str(w3.spieler_daten.get("p1", {}).get("aktiv", "")) == "abzieher", "aktiv=%s boosts=%s" % [w3.aktiv, w3.boosts])
	var w4 := Wirtschaft.new()
	w4.ich = "p1"
	w4.laden(d3)
	_p("Koop-Stand allein weiterspielen", w4.aktiv == "abzieher" and w4.boost_aktiv("kaffee") and w4.spieler_daten.has("p2") and (w4.speichern().get("spieler_daten", {}) as Dictionary).has("p2"), "")
	w3.anwesend = ["p1", "p2"]
	w3.spieler_daten["p1"].boosts = {}
	w3.spieler_daten["p2"].boosts = {"espresso": 40.0}
	w3.als("p1")
	var helfer_p1 := w3.boost_wirkung("helfer")
	var tempo_p1 := w3.boost_wirkung("tempo")
	w3.als("")
	_p("Boost nur beim Käufer, Helfer-Boost für alle", tempo_p1 == 0.0 and helfer_p1 == 0.5 and w3.boost_wirkung("tempo") == 1.0 and w3.boost_wirkung("tempo", "p1") == 0.0, "tempo p1 %.1f / helfer p1 %.1f" % [tempo_p1, helfer_p1])
	w3.boosts_takt(10.0)
	_p("Boosts aller Anwesenden laufen ab", absf(float(w3.spieler_daten["p2"].boosts.espresso) - 30.0) < 0.01, "")
	var w5 := Wirtschaft.new()
	w5.koop_takt(1.0, 3)
	var f3 := w5.koop_faktor()
	w5.koop_takt(1.0, 1)
	var f3b := w5.koop_faktor()
	w5.koop_takt(Wirtschaft.KOOP_FENSTER, 1)
	var f1 := w5.koop_faktor()
	w5.koop_takt(1.0, 2)
	_p("Preis-Faktor: höchste Spielerzahl der letzten 10 min", f3 == 2.0 and f3b == 2.0 and f1 == 1.0 and w5.koop_faktor() == 1.5 and w5.upgrade_preis("motor") == 38, "%.1f %.1f %.1f %.1f" % [f3, f3b, f1, w5.koop_faktor()])

func _gast_starten(n: String) -> void:
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--", "--ansicht=37", "--rolle=gast", "--profil=" + n, "--join=127.0.0.1:%d" % TEST_PORT]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--netz-"):
			args.append(a)
	var pid := OS.create_process(OS.get_executable_path(), args)
	print("NETZTEST INFO %s gestartet (pid %d)" % [n, pid])

func _id_von(n: String) -> int:
	for id in Netz.spieler:
		if str(Netz.spieler[id].name).to_lower().replace(" ", "") == n:
			return id
	return -1

func _datei(n: String) -> String:
	var d := "user://netztest_%s.txt" % n
	return FileAccess.get_file_as_string(d) if FileAccess.file_exists(d) else ""

func _process(dt: float) -> void:
	zeit += dt
	if gast:
		_gast_takt(dt)
		return
	if zeit < warte_bis:
		return
	match schritt:
		1:   # Gast 1 starten
			if s.laeufer.aktiv:
				_gast_starten("testgast1")
				schritt = 2
				frist = zeit + 60.0   # Zeitlimit für den Beitritt
		2:
			if _id_von("testgast1") > 0:
				ids.testgast1 = _id_von("testgast1")
				_p("Gast 1 beigetreten", true, "%.1f s" % zeit)
				schritt = 3
				warte_bis = zeit + 6.0   # Gast prüft seinen Stand, läuft los
			elif zeit >= frist:
				_p("Gast 1 beigetreten", false, "Zeitlimit")
				_ende()
		3:   # Gastgeber läuft ein Stück, sagt dem Gast, wo er steht
			var p := s.laeufer.position + Vector3(3.0, 0, 0)
			if s.laeufer.frei(Vector2(p.x, p.z)):
				s.laeufer.position = p
			schritt = 4
			warte_bis = zeit + 1.5
		4:
			_host_pos = s.laeufer.position
			Netz.test_nachricht.rpc_id(ids.testgast1, "HOSTPOS %f %f %f" % [_host_pos.x, _host_pos.y + s.laeufer.hoch, _host_pos.z])
			schritt = 5
			warte_bis = zeit + 3.0
		5:   # Mit Grafik: zum Gast schauen (Testbild); kein await hier – _process läuft jedes Bild weiter
			if DisplayServer.get_name() != "headless" and ids.has("testgast1"):
				var g := s.mitspieler.figur_pos(ids.testgast1)
				var d := g - s.laeufer.position
				s.laeufer.yaw = atan2(-d.x, -d.z)
				s.laeufer.pitch = -0.12
				if d.length() < 3.0:
					s.laeufer.position -= Vector3(d.x, 0, d.z).normalized() * (3.0 - d.length())
			schritt = 60
			warte_bis = zeit + 0.6
		60:   # 7b: Kasse setzen, Gast 1 kauft über echte Knöpfe
			var w := s.wirtschaft
			_p("Preis-Faktor zu zweit ×1,5", w.koop_max == 2 and w.koop_faktor() == 1.5 and w.upgrade_preis("motor") == 38 and w.werkzeug_preis("abzieher") == 180, "×%.2f" % w.koop_faktor())
			w.geld = 5000
			_preise = {"motor": w.upgrade_preis("motor"), "abzieher": w.werkzeug_preis("abzieher"), "kaffee": w.boost_preis("kaffee"), "espresso": w.boost_preis("espresso")}
			schritt = 61
			warte_bis = zeit + 1.5
		61:
			Netz.test_nachricht.rpc_id(ids.testgast1, "KAUFEN")
			schritt = 62
			frist = zeit + 40.0
		62:
			if _berichte.has("GEKAUFT"):
				var b: Dictionary = _berichte.GEKAUFT
				var w := s.wirtschaft
				var pid := _profil_id("testgast1")
				var soll := 5000 - int(_preise.motor) - int(_preise.abzieher) - int(_preise.kaffee) - int(_preise.espresso)
				_p("Gast-Kauf beim Gastgeber besessen", w.stufen.motor == 1 and "abzieher" in w.besitz, "Motor %d, besitz %s" % [w.stufen.motor, w.besitz])
				_p("Geld nach Gast-Käufen stimmt", w.geld == soll and int(b.geld) == w.geld, "%d / Gast %s / soll %d" % [w.geld, b.geld, soll])
				_p("Beim Gast besessen", int(b.motor) == 1 and b.abzieher == "1", "")
				_p("Gekauftes Werkzeug nur in der Hand des Käufers", w.aktiv == "schwamm" and b.aktiv == "abzieher" and str((w.spieler_daten.get(pid, {}) as Dictionary).get("aktiv", "")) == "abzieher", "Gastgeber %s, Gast %s" % [w.aktiv, b.aktiv])
				var gb: Dictionary = (w.spieler_daten.get(pid, {}) as Dictionary).get("boosts", {})
				_p("Boost nur beim Käufer", not w.boost_aktiv("kaffee") and w.boost_wirkung("tempo") == 0.0 and gb.has("kaffee") and b.kaffee == "1" and absf(s.spieler.tempo_faktor - w.tempo_faktor() * (1.0 + w.bonus("tempo"))) < 0.001 and float(b.tempo) > s.spieler.tempo_faktor * 1.9,
					"Gastgeber-Tempo %.2f, Gast-Tempo %s, Gast-Boosts %s" % [s.spieler.tempo_faktor, b.tempo, gb.keys()])
				_p("Helfer-Boost (Espresso des Gasts) wirkt für alle", w.boost_wirkung("helfer") == 0.5 and absf(s.helfer.tempo - (1.0 + w.bonus("helfer") + 0.5)) < 0.001, "helfer %.2f" % s.helfer.tempo)
				schritt = 63
			elif zeit >= frist:
				_p("Gast 1 kauft", false, "keine Antwort")
				schritt = 63
		63:   # Gast öffnet die Werkstatt, Gastgeber kauft eine Putzkraft → offenes Menü beim Gast aktualisiert sich
			Netz.test_nachricht.rpc_id(ids.testgast1, "SHOP_AUF")
			schritt = 64
			warte_bis = zeit + 1.5
		64:
			s.shop.umschalten()
			var k: Button = s.shop.find_child("he_putzkraft", true, false)
			var vor: int = s.wirtschaft.helfer.putzkraft
			if k and not k.disabled:
				k.pressed.emit()
			s.shop.umschalten()
			_p("Gastgeber kauft Putzkraft (Knopf)", s.wirtschaft.helfer.putzkraft == vor + 1, "%d" % s.wirtschaft.helfer.putzkraft)
			schritt = 65
			warte_bis = zeit + 1.5
		65:
			Netz.test_nachricht.rpc_id(ids.testgast1, "MENUE? %d" % s.wirtschaft.helfer_preis("putzkraft"))
			s.wirtschaft.geld = 10   # Kasse fast leer
			schritt = 66
			warte_bis = zeit + 1.5
		66:
			Netz.test_nachricht.rpc_id(ids.testgast1, "OHNEGELD")
			schritt = 67
			frist = zeit + 30.0
		67:
			if _berichte.has("ABGELEHNT"):
				_p("Kauf ohne Geld: nichts gekauft, Kasse unverändert", s.wirtschaft.stufen.arm == 0 and s.wirtschaft.geld == 10, "Arm %d, %d €" % [s.wirtschaft.stufen.arm, s.wirtschaft.geld])
				schritt = 55
			elif zeit >= frist:
				_p("Kauf ohne Geld", false, "keine Antwort")
				schritt = 55
		55:   # Geld ändern, Gast 2 tritt mitten im Spiel bei
			if DisplayServer.get_name() != "headless":
				print("NETZTEST BILD frame=%d" % Engine.get_frames_drawn())
			s.wirtschaft.geld = 7777
			_gast_starten("testgast2")
			schritt = 6
			frist = zeit + 60.0
		6:
			if _id_von("testgast2") > 0:
				ids.testgast2 = _id_von("testgast2")
				_p("Gast 2 mitten im Spiel beigetreten", Netz.spieler.size() == 3, "%d Spieler" % Netz.spieler.size())
				schritt = 7
				warte_bis = zeit + 5.0
			elif zeit >= frist:
				_p("Gast 2 beigetreten", false, "Zeitlimit")
				_ende()
		7:   # Gast 1 muss jetzt 3 Spieler in der Liste haben; Gast 3 wird abgelehnt
			Netz.test_nachricht.rpc_id(ids.testgast1, "LISTE?")
			var w := s.wirtschaft
			_p("Preis-Faktor zu dritt ×2", w.koop_max == 3 and w.koop_faktor() == 2.0 and w.upgrade_preis("arm") == 120, "×%.2f, Arm %d €" % [w.koop_faktor(), w.upgrade_preis("arm")])
			_p("koop_max im Spielstand", int(s.stand_daten().wirtschaft.koop_max) == 3, "")
			Netz.test_nachricht.rpc_id(ids.testgast1, "FAKTOR? 2.0")
			Netz.test_nachricht.rpc_id(ids.testgast2, "BESITZ?")
			_gast_starten("testgast3")
			schritt = 8
			frist = zeit + 45.0
		8:
			var t := _datei("testgast3")
			if t != "":
				_p("Vierter Spieler abgelehnt (voll)", "voll" in t and Netz.spieler.size() == 3, t.strip_edges())
				schritt = 9
			elif zeit >= frist:
				_p("Vierter Spieler abgelehnt", false, "keine Antwort von testgast3")
				schritt = 9
		9:   # Gast 2 verlässt die Runde selbst
			Netz.test_nachricht.rpc_id(ids.testgast2, "VERLASSEN")
			schritt = 10
			frist = zeit + 25.0
		10:
			var t := _datei("testgast2")
			if t != "" and Netz.spieler.size() == 2:
				_p("Gast 2 hat verlassen, Liste wieder 2", true, t.strip_edges())
				_p("Ort von Gast 2 gemerkt", Netz.orte.has(_profil_id("testgast2")) or Netz.orte.size() >= 2, "%d Orte" % Netz.orte.size())
				schritt = 11
				warte_bis = zeit + 1.0
			elif zeit >= frist:
				_p("Gast 2 hat verlassen", false, "Datei '%s', %d Spieler" % [t.strip_edges(), Netz.spieler.size()])
				schritt = 11
		11:   # Gastgeber beendet → Gast 1 bekommt Meldung + Hauptmenü
			Netz.trennen()
			schritt = 12
			frist = zeit + 25.0
			_ende_start = zeit
		12:
			var t := _datei("testgast1")
			if t != "":
				_p("Gastgeber weg → Gast 1 im Hauptmenü mit Meldung", "Gastgeber" in t, "%s (nach %.1f s)" % [t.strip_edges(), zeit - _ende_start])
				_ende()
			elif zeit >= frist:
				_p("Gastgeber weg → Gast 1 merkt es", false, "Zeitlimit")
				_ende()

var _ende_start := 0.0
var _preise := {}
var _berichte := {}        # Gast-Berichte „NAME k=v …“
var _profil_ids := {}
func _profil_id(n: String) -> String:
	return str(_profil_ids.get(n, ""))

func _nachricht(id: int, t: String) -> void:
	if gast:
		_gast_nachricht(id, t)
		return
	# Gastgeber: Berichte der Gäste zählen
	var wer := Netz.name_von(id)
	if t.begins_with("OK ") or t.begins_with("FEHLER "):
		var gut := t.begins_with("OK ")
		var rest := t.substr(3 if gut else 7)
		_p("[%s] %s" % [wer, rest], gut)
	elif t.begins_with("GASTPOS "):
		var w := t.substr(8).split_floats(" ")
		var soll := Vector3(w[0], w[1], w[2])
		await get_tree().create_timer(1.0).timeout
		var ist := s.mitspieler.figur_pos(id)
		_p("Figur von %s an der richtigen Stelle" % wer, ist.distance_to(soll) < 0.6 and s.mitspieler.figur_sichtbar(id), "Abstand %.2f m" % ist.distance_to(soll))
	elif t.begins_with("GELD "):
		_p("Geld bei %s wie beim Gastgeber" % wer, int(t.substr(5)) == s.wirtschaft.geld, "%s / %d €" % [t.substr(5), s.wirtschaft.geld])
	elif t.begins_with("PHASE "):
		var d := absf(wrapf(float(t.substr(6)) - s.welt.zeit.phase, -0.5, 0.5))
		_p("Tageszeit bei %s wie beim Gastgeber" % wer, d < 0.003, "Unterschied %.4f (= %.1f s)" % [d, d * Tageszeit.TAG])
	elif t.begins_with("PROFIL "):
		_profil_ids[wer.to_lower().replace(" ", "")] = t.substr(7)
	elif t.begins_with("GEKAUFT ") or t.begins_with("ABGELEHNT"):
		var teile := t.split(" ")
		var b := {}
		for x in teile.slice(1):
			if "=" in x:
				b[x.get_slice("=", 0)] = x.get_slice("=", 1)
		_berichte[teile[0]] = b

func _ende() -> void:
	print("NETZTEST ERGEBNIS ok=%d fehler=%d" % [ok, fehler])
	Netz.trennen()
	get_tree().quit(0 if fehler == 0 else 1)

# ================================================================ Gast
var _geprueft := false
var _gast_zeit := 0.0

func _gast_setup() -> void:
	pass

func _gast_schreiben(t: String) -> void:
	var f := FileAccess.open("user://netztest_%s.txt" % _profil(), FileAccess.WRITE)
	f.store_string(t)
	f.close()
	print("NETZTEST [%s] %s" % [_profil(), t])

func _gast_takt(dt: float) -> void:
	if gemeldet:
		return
	# Nach Ablehnen / Verlassen / Gastgeber-weg steht die Meldung in Netz.menue_meldung (bzw. ist schon angezeigt)
	if Netz.menue_meldung != "" and not Netz.aktiv():
		gemeldet = true
		_gast_schreiben(Netz.menue_meldung)
		get_tree().quit()
		return
	if not Netz.ist_gast() or Netz.gast_stand.is_empty():
		if zeit > 90.0:
			gemeldet = true
			_gast_schreiben("Zeitlimit beim Beitreten")
			get_tree().quit()
		return
	_gast_zeit += dt
	if not _geprueft and _gast_zeit > 2.0 and s.laeufer.aktiv:
		_geprueft = true
		var h := 1
		Netz.test_nachricht.rpc_id(h, "PROFIL " + str(Netz.profil.id))
		Netz.test_nachricht.rpc_id(h, "GELD %d" % s.wirtschaft.geld)
		_melden(s.zustand.sauber_zahl == SAUBER, "Saubere Fenster übernommen", "%d" % s.zustand.sauber_zahl)
		_melden(Netz.spieler.size() >= 2 and Netz.spieler.has(1), "Spielerliste da", "%d Spieler" % Netz.spieler.size())
		_melden(s.welt.zeit.phase >= 0.0 and s.welt.zeit.laeuft, "Tageszeit läuft beim Gast", "Phase %.3f" % s.welt.zeit.phase)
		Netz.test_nachricht.rpc_id(h, "PHASE %f" % s.welt.zeit.phase)
		_melden(not s.spieler.aktiv and s.laeufer.aktiv, "Gast startet zu Fuß", "")
		_melden(s.mitspieler.liste_ebene.visible and s.mitspieler.liste_box.get_child_count() == Netz.spieler.size() + 1, "Spielerliste im HUD", "%d Zeilen" % s.mitspieler.liste_box.get_child_count())
		# ein Stück laufen und dem Gastgeber sagen, wo man steht
		var p := s.laeufer.position + Vector3(-4.0, 0, 2.5)
		if s.laeufer.frei(Vector2(p.x, p.z)):
			s.laeufer.position = p
		await get_tree().create_timer(1.0).timeout
		var q := s.laeufer.position
		Netz.test_nachricht.rpc_id(h, "GASTPOS %f %f %f" % [q.x, q.y + s.laeufer.hoch, q.z])

func _melden(gut: bool, name: String, info: String) -> void:
	Netz.test_nachricht.rpc_id(1, ("OK " if gut else "FEHLER ") + name + ((" – " + info) if info != "" else ""))

func _gast_nachricht(_id: int, t: String) -> void:
	if t.begins_with("HOSTPOS "):
		var w := t.substr(8).split_floats(" ")
		var soll := Vector3(w[0], w[1], w[2])
		await get_tree().create_timer(1.0).timeout
		var ist := s.mitspieler.figur_pos(1)
		_melden(ist.distance_to(soll) < 0.6 and s.mitspieler.figur_sichtbar(1), "Figur des Gastgebers an der richtigen Stelle", "Abstand %.2f m" % ist.distance_to(soll))
	elif t == "LISTE?":
		_melden(Netz.spieler.size() == 3 and s.mitspieler.liste_box.get_child_count() == 4, "Liste beim Gast nach drittem Beitritt", "%d Spieler" % Netz.spieler.size())
	elif t == "VERLASSEN":
		s._zum_hauptmenue()
	elif t == "KAUFEN":
		_gast_kaufen()
	elif t == "SHOP_AUF":
		if not s.shop.offen:
			s.shop.umschalten()
		s.shop._reiter_waehlen(1)   # Helfer
	elif t.begins_with("MENUE? "):
		var soll := int(t.substr(7))
		var k: Button = s.shop.find_child("he_putzkraft", true, false)
		_melden(s.shop.offen and s.wirtschaft.helfer.putzkraft == 1 and k != null and k.text == "%s €" % Hud.punkte(soll) and soll == s.wirtschaft.helfer_preis("putzkraft"),
			"Offene Werkstatt beim Gast aktualisiert (Putzkraft vom Gastgeber)", "%d Putzkraft, Knopf '%s', soll %d €" % [s.wirtschaft.helfer.putzkraft, k.text if k else "-", soll])
	elif t == "OHNEGELD":
		_gast_ohne_geld()
	elif t.begins_with("FAKTOR? "):
		var k: Button = s.shop.find_child("up_arm", true, false)
		_melden(s.wirtschaft.koop_faktor() == 2.0 and s.wirtschaft.upgrade_preis("arm") == 120 and k != null and k.text == "120 €", "Preis-Faktor zu dritt beim Gast (Knopf zeigt 120 €)", "×%.2f, Knopf '%s'" % [s.wirtschaft.koop_faktor(), k.text if k else "-"])
	elif t == "BESITZ?":
		var w := s.wirtschaft
		_melden(w.stufen.motor == 1 and "abzieher" in w.besitz and w.helfer.putzkraft == 1, "Gast 2: alles Gekaufte da", "Motor %d, %s" % [w.stufen.motor, w.besitz])
		_melden(w.boosts.is_empty() and w.aktiv == "schwamm" and w.boost_wirkung("tempo") == 0.0, "Gast 2: kein fremder Boost, eigenes Werkzeug", "boosts %s, aktiv %s" % [w.boosts.keys(), w.aktiv])
		_melden(w.koop_faktor() == 2.0, "Gast 2: Preis-Faktor ×2", "×%.2f" % w.koop_faktor())

# Gast 1: über die echten Knöpfe kaufen (Werkstatt, Kiosk Werkzeuge, Snacks, Sky-Bar) – jeder Kauf wartet auf die Antwort
func _gast_kaufen() -> void:
	var w := s.wirtschaft
	_melden(w.koop_faktor() == 1.5, "Preis-Faktor zu zweit beim Gast", "×%.2f" % w.koop_faktor())
	_melden(w.geld == 5000, "Kasse vom Gastgeber übernommen", "%d €" % w.geld)
	s.shop.umschalten()
	s.shop._reiter_waehlen(2)   # Ausbau
	await _druecken(s.shop, "up_motor", "%s €" % Hud.punkte(38))
	s.shop.umschalten()
	s.hmenu.oeffnen("grund", "Werkzeuge")
	await _druecken(s.hmenu, "w_abzieher", "180 €")
	s.hmenu.schliessen()
	s.hmenu.oeffnen("snack", "Snacks")
	await _druecken(s.hmenu, "b_kaffee", "")
	s.hmenu.schliessen()
	s.hmenu.oeffnen("bar", "Sky-Bar")
	await _druecken(s.hmenu, "b_espresso", "")
	s.hmenu.schliessen()
	await get_tree().create_timer(1.0).timeout   # eigene Werte (Werkzeug in der Hand) sind beim Gastgeber
	Netz.test_nachricht.rpc_id(1, "GEKAUFT geld=%d motor=%d abzieher=%d aktiv=%s kaffee=%d tempo=%.3f" % [w.geld, w.stufen.motor, int("abzieher" in w.besitz), w.aktiv, int(w.boost_aktiv("kaffee")), s.spieler.tempo_faktor])

func _druecken(menu: Node, name: String, text: String) -> void:
	var k: Button = menu.find_child(name, true, false)
	if k == null or k.disabled or (text != "" and k.text != text):
		_melden(false, "Knopf %s" % name, "fehlt/gesperrt/Text '%s' statt '%s'" % [k.text if k else "-", text])
		return
	k.pressed.emit()
	var r: Array = await Netz.befehl_fertig
	var e: Dictionary = r[1]
	_melden(e.get("ok", false), "Gast kauft %s (Antwort vom Gastgeber)" % name, str(e))

# Gast 1: Kasse fast leer → Knopf gesperrt; Wunsch trotzdem schicken (wie bei einem Kauf, den ein anderer gerade überholt)
func _gast_ohne_geld() -> void:
	var w := s.wirtschaft
	var k: Button = s.shop.find_child("up_arm", true, false)
	_melden(w.geld == 10 and k != null and k.disabled, "Knopf ohne Geld gesperrt (offenes Menü)", "%d €, gesperrt %s" % [w.geld, k.disabled if k else "-"])
	Netz.befehl("upgrade", {"id": "arm"})
	var r: Array = await Netz.befehl_fertig
	var e: Dictionary = r[1]
	await get_tree().create_timer(0.6).timeout
	_melden(not e.get("ok", true) and w.stufen.arm == 0 and w.geld == 10 and "Kasse" in str(e.get("grund", "")), "Kauf ohne Geld vom Gastgeber abgelehnt", str(e.get("grund", "")))
	Netz.test_nachricht.rpc_id(1, "ABGELEHNT arm=%d" % w.stufen.arm)
