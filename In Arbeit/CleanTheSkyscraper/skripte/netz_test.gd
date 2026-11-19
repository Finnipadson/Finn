class_name NetzTest
extends Node
# Test 37 – Mehrspieler-Grundlage (Phase 7a), läuft headless mit mehreren Prozessen auf 127.0.0.1:
#   godot --headless --path . -- --ansicht=37 [--netz-verzoegerung=150 --netz-verlust=5]
# Test 39 (Phase 7g) = derselbe Ablauf über Epic Online Services statt ENet: Gastgeber erstellt ein Internet-Spiel, die Gäste
# treten per Code bei (--join-code=…), alles läuft über EOS-P2P. Mit --relay=erzwingen nur über das Epic-Relay.
#   godot --headless --path . -- --ansicht=39 [--relay=erzwingen]
# Der Gastgeber-Prozess startet die Gäste selbst (OS.create_process, --rolle=gast --profil=testgastN --join=…).
# Ablauf: Gast 1 tritt bei (Geld, Fenster, Tageszeit, Spielerliste gleich?) → beide laufen, jeder sieht die Figur des
# anderen an der richtigen Stelle → Gastgeber ändert Geld, Gast 2 tritt mitten im Spiel bei → Gast 3 wird abgelehnt
# (voll) → Gast 2 verlässt die Runde selbst → Gastgeber beendet, Gast 1 landet mit Meldung im Hauptmenü.
# Phase 7b (Befehle + Kasse): Einzelspieler-Umrechnung alt ↔ neu und koop_faktor ohne Netz; dann kauft Gast 1 über die
# echten Knöpfe (Werkstatt: Motor, Kiosk: Abzieher, Kaffee, Espresso) → bei allen besessen, Geld stimmt, Koop-Preis ×1,25 (7h, vorher ×1,5),
# Boost nur beim Käufer (Helfer-Boost Espresso wirkt für alle); Gastgeber kauft eine Putzkraft → offenes Menü beim Gast
# aktualisiert sich; Kasse fast leer → Knopf beim Gast gesperrt, Kauf trotzdem geschickt → vom Gastgeber abgelehnt;
# zu dritt Preise ×1,5 (vorher ×2), Gast 2 hat alles Gekaufte, aber keinen Boost.
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
var eos := false           # Test 39: über Epic Online Services

func setup(sp: Spiel) -> void:
	s = sp
	process_mode = Node.PROCESS_MODE_ALWAYS   # 7f: läuft auch, wenn der Gastgeber für alle pausiert
	gast = "--rolle=gast" in OS.get_cmdline_user_args()
	eos = "--ansicht=39" in OS.get_cmdline_user_args()
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
	if "--nur-code" in OS.get_cmdline_user_args():   # 7g: Code-Fenster nach „Spiel erstellen“ übers Internet
		Netz.code = "K7MP2Q"
		m._code_fenster()
		await get_tree().create_timer(0.6).timeout
		print("NETZTEST BILD frame=%d" % Engine.get_frames_drawn())
		Netz.code = ""
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
	var e := ""
	if eos:
		var t0 := Time.get_ticks_msec()
		e = await Netz.host_starten_internet()
		_p("Internet-Spiel erstellt (EOS)", e == "" and Netz.transport == "eos" and Netz.code.length() == 6, "%s, Code %s, %d ms" % [e, Netz.code, Time.get_ticks_msec() - t0])
		if e != "":
			_ende()
			return
	else:
		e = Netz.host_starten(TEST_PORT)
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
	_p("Preis-Faktor: höchste Spielerzahl der letzten 10 min", f3 == 1.5 and f3b == 1.5 and f1 == 1.0 and w5.koop_faktor() == 1.25 and w5.upgrade_preis("motor") == 31 and w5.upgrade_preis("winde") == Wirtschaft.UPGRADES.winde.basis, "%.1f %.1f %.1f %.1f" % [f3, f3b, f1, w5.koop_faktor()])

func _gast_starten(n: String) -> void:
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--", "--ansicht=37", "--rolle=gast", "--profil=" + n, "--join=127.0.0.1:%d" % TEST_PORT]
	if eos:
		args = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--", "--ansicht=39", "--rolle=gast", "--profil=" + n, "--join-code=" + Netz.code]
	if not OS.has_feature("editor"):   # aus der exportierten .exe: Gäste sind auch die .exe (Spiel steckt drin), eigenes Log
		args = ["--headless", "--log-file", OS.get_user_data_dir().path_join("netztest_%s.log" % n)] + args.slice(args.find("--"))
	else:   # eigenes Log je Gast (Fehler der Gast-Prozesse sehen)
		args = ["--log-file", OS.get_user_data_dir().path_join("netztest_%s.log" % n)] + args
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--netz-") or a.begins_with("--relay="):
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
	if _beendet:
		return
	if gast:
		_gast_takt(dt)
		return
	if schritt == 79 or schritt == 80:
		s.ereignisse.takt(dt)   # im echten Spiel (ansicht 0) läuft der Takt immer; im Test nur hier (sonst zufällige Tauben)
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
				_p("Freie Gondel für Gast 1 bereitgestellt (7h)", s.wirtschaft.gondeln_gekauft() == 2, "%d Gondeln" % s.wirtschaft.gondeln_gekauft())
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
			_p("Preis-Faktor zu zweit ×1,25", w.koop_max == 2 and w.koop_faktor() == 1.25 and w.upgrade_preis("motor") == 31 and w.werkzeug_preis("abzieher") == 150, "×%.2f" % w.koop_faktor())
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
				schritt = 70
			elif zeit >= frist:
				_p("Kauf ohne Geld", false, "keine Antwort")
				schritt = 70
		70:   # 7c: zweite Gondel für den Gast
			var w := s.wirtschaft
			w.geld = 50000
			s.helfer.aktiv = false   # Zähler/Geld sollen sich nur durchs Putzen der Spieler ändern
			_kh = w.aktive_gondel
			_k2 = (_kh + 1) % 3
			var schon: bool = w.gondeln[_k2].gekauft   # 7h: beim Beitritt evtl. schon kostenlos bereitgestellt
			var e := Netz.befehl("gondel", {"seite": _k2}) if not schon else {"ok": true}
			_p("Gastgeber kauft zweite Gondel", e.ok and w.gondeln[_k2].gekauft, "Seite %d%s" % [_k2, " (schon bereitgestellt)" if schon else ""])
			schritt = 71
			warte_bis = zeit + 1.5
		71:
			Netz.test_nachricht.rpc_id(ids.testgast1, "GONDEL %d %d" % [_kh, _k2])
			schritt = 72
			frist = zeit + 30.0
		72:
			if _berichte.has("IN_GONDEL"):
				schritt = 73
				warte_bis = zeit + 1.2
			elif zeit >= frist:
				_p("Gast steigt in Gondel", false, "keine Antwort")
				schritt = 55
		73:   # Gondel des Gasts beim Gastgeber zu sehen (mit Figur + Werkzeug), seine geparkte ausgeblendet
			var b: Dictionary = _berichte.IN_GONDEL
			var soll := Vector3(float(b.x), float(b.y), float(b.z))
			var g := s.mitspieler.gondel_von(ids.testgast1)
			var pid := _profil_id("testgast1")
			_p("Gondel des Gasts beim Gastgeber an der richtigen Stelle", g != null and g.is_visible_in_tree() and g.global_position.distance_to(soll) < 0.6 and (g.get_node("figur") as Node3D).visible,
				"Abstand %.2f m" % (g.global_position.distance_to(soll) if g else -1.0))
			_p("Werkzeug des Gasts an seiner Gondel", s.mitspieler.werkzeug_von(ids.testgast1) == "abzieher", s.mitspieler.werkzeug_von(ids.testgast1))
			_p("Geparkte Gondel dieser Seite ausgeblendet", not (s.gondeln.modelle[_k2] as Node3D).visible and int((s.wirtschaft.spieler_daten.get(pid, {}) as Dictionary).get("aktive_gondel", -1)) == _k2, "")
			_vor = {"zahl": s.zustand.sauber_zahl, "verdient": int(s.wirtschaft.statistik.verdient), "je": int(s.wirtschaft.fenster_je.get(pid, 0))}
			Netz.test_nachricht.rpc_id(ids.testgast1, "WISCHEN")
			schritt = 74
			frist = zeit + 40.0
		74:
			if _berichte.has("GEWISCHT"):
				var b: Dictionary = _berichte.GEWISCHT
				var pid := _profil_id("testgast1")
				var n := int(b.n)
				var w := s.wirtschaft
				var dz: int = s.zustand.sauber_zahl - int(_vor.zahl)
				var dv: int = int(w.statistik.verdient) - int(_vor.verdient)
				var dj: int = int(w.fenster_je.get(pid, 0)) - int(_vor.je)
				_p("Gast putzt Fenster → beim Gastgeber sauber", n > 0 and dz == n and int(b.zahl) == s.zustand.sauber_zahl, "%d Fenster, Gastgeber +%d, Zähler %s / %d" % [n, dz, b.zahl, s.zustand.sauber_zahl])
				_p("Lohn einmal in der Kasse, mit Goldpolitur des Gasts", dj == n and dv == 2 * n and lohn_ohne_boost() == 1, "verdient +%d bei %d Fenstern" % [dv, n])
				# Zwei wischen dasselbe Fenster
				_w2 = _drei_dreckige(3)
				_vor = {"zahl": s.zustand.sauber_zahl, "verdient": int(w.statistik.verdient), "je": int(w.fenster_je.get(pid, 0))}
				Netz.test_nachricht.rpc_id(ids.testgast1, "DOPPEL %d %d" % [_w2.y, _w2.x])
				if s.zustand.wische(_w2.y, _w2.x, 0.5, 0.5, 3.0, 3.0):
					s._fenster_sauber(_w2.y, _w2.x)
				schritt = 75
				frist = zeit + 30.0
			elif zeit >= frist:
				_p("Gast putzt", false, "keine Antwort")
				schritt = 55
		75:
			if _berichte.has("DOPPELT"):
				var b: Dictionary = _berichte.DOPPELT
				var pid := _profil_id("testgast1")
				var w := s.wirtschaft
				_p("Zwei wischen dasselbe Fenster → zählt einmal", s.zustand.sauber_zahl - int(_vor.zahl) == 1 and int(b.zahl) == s.zustand.sauber_zahl and int(w.statistik.verdient) - int(_vor.verdient) == lohn_ohne_boost(3) and int(w.fenster_je.get(pid, 0)) == int(_vor.je),
					"+%d Fenster, verdient +%d, Gast-Zähler %s" % [s.zustand.sauber_zahl - int(_vor.zahl), int(w.statistik.verdient) - int(_vor.verdient), b.zahl])
				# Dreck-Updates: Taube auf dem eben geputzten, ein Helfer wischt am nächsten, ein Helfer macht das dritte fertig
				s.zustand.verschmutzen(_w2.y, _w2.x, 0.4)
				s.zustand.dreck_setzen(_w2.y, _w2.x + 1, 0.12)
				if s.zustand.sauber_machen(_w2.y, _w2.x + 2):
					s._helfer_geputzt(_w2.y, _w2.x + 2, "putzkraft")
				schritt = 76
				warte_bis = zeit + 1.5
			elif zeit >= frist:
				_p("Zwei wischen dasselbe", false, "keine Antwort")
				schritt = 55
		76:
			Netz.test_nachricht.rpc_id(ids.testgast1, "DRECK? %d %d %d" % [_w2.y, _w2.x, s.zustand.sauber_zahl])
			Netz.test_nachricht.rpc_id(ids.testgast1, "HOEHE")
			schritt = 77
			frist = zeit + 30.0
		77:
			if _berichte.has("HOEHE_OK"):
				_p("Höhenbonus beim Gastgeber eingetragen", s.wirtschaft.hoechster_abschnitt == 2, "Abschnitt %d" % s.wirtschaft.hoechster_abschnitt)
				schritt = 770
			elif zeit >= frist:
				_p("Höhenbonus", false, "keine Antwort")
				schritt = 770
		770:   # 7h: Gast hilft mit H auf einer anderen Seite mit, dann zurück
			Netz.test_nachricht.rpc_id(ids.testgast1, "HELFEN")
			schritt = 771
			frist = zeit + 20.0
		771:
			if _berichte.has("GEHOLFEN"):
				var b: Dictionary = _berichte.GEHOLFEN
				var orte: Array = s.mitspieler.gondel_orte()
				var sh := int(b.seite)
				_p("Gast hilft auf einer anderen Seite (H)", sh != _k2 and int(b.aktive) == _k2 and b.taste == "1", "Seite %d, eigene Gondel %d (%s)" % [sh, int(b.aktive), str(b)])
				_p("Gastgeber sieht die Gondel des Gasts auf der geholfenen Seite", orte.size() == 1 and int(orte[0].seite) == sh, str(orte))
				_p("Eigene Gondel des Gasts bleibt belegt (geparkte ausgeblendet)", not (s.gondeln.modelle[_k2] as Node3D).visible, "")
				Netz.test_nachricht.rpc_id(ids.testgast1, "HEIM")
				schritt = 772
				frist = zeit + 20.0
			elif zeit >= frist:
				_p("Gast hilft mit", false, "keine Antwort")
				schritt = 78
		772:
			if _berichte.has("HEIM_OK"):
				var b: Dictionary = _berichte.HEIM_OK
				_p("Gast wieder auf seiner Seite, Stand speichert die eigene Seite", int(b.seite) == _k2 and b.weg_ok == "1", str(b))
				schritt = 78
			elif zeit >= frist:
				_p("Gast zurück", false, "keine Antwort")
				schritt = 78
		78:   # 7d: Helfer wieder an; Taube (Gastgeber hat Limo → fliegt zur Gondel des Gasts), Böe, Sandsturm
			s.helfer.aktiv = true
			var orte: Array = s.mitspieler.gondel_orte()
			var nah := false
			if orte.size() == 1:
				var o: Dictionary = orte[0]
				nah = s.helfer._spieler_nah(int(o.stock), int(float(o.weg) / Turm.FENSTER_B), int(o.seite))
			_p("Helfer lassen die Gondel des Gasts aus", orte.size() == 1 and int(orte[0].seite) == _k2 and nah and s.helfer.weitere.size() == 1, str(orte))
			s.ereignisse.limo = true
			var ok := s.ereignisse.taube_jetzt()
			var tb: Dictionary = s.ereignisse.tauben.back() if ok else {}
			_taube = Vector2i(int(tb.get("spalte", -1)), int(tb.get("f", -1)))
			_p("Taube fliegt zur Gondel des Gasts", ok and orte.size() == 1 and absi(_taube.y - int(orte[0].stock)) <= 1, "Fenster %d/%d" % [_taube.y, _taube.x])
			s.ereignisse.boe_jetzt(0.6)
			s.ereignisse.sturm_jetzt()
			schritt = 79
			warte_bis = zeit + 6.5
		79:
			var hp := []
			for h in s.helfer.liste:
				var p: Vector3 = (h.node as Node3D).position
				hp.append("%d:%d=%f,%f,%f" % [Helfer.ARTEN.find(h.art), int(h.nr), p.x, p.y, p.z])
			Netz.test_nachricht.rpc_id(ids.testgast1, "WELT? %d %d %s" % [_taube.y, _taube.x, ";".join(hp)])
			schritt = 80
			warte_bis = zeit + 2.0
		80:   # Ereignisse beenden
			var e := s.ereignisse
			e.limo = false
			e.wind_ziel = 0.0
			e.ereignis.emit("wind", {"ziel": 0.0})
			e.sturm_phase = 0
			e.sturm_zeit = 600.0
			e.ereignis.emit("sturm", {"phase": 0})
			schritt = 81
		81:   # 7e: Casino (echter Hebel), Arcade-Kapsel (echter Knopf), Fang – alles über die gemeinsame Kasse/Kiste
			var w := s.wirtschaft
			_vor = {"bilanz": int(w.statistik.casino_bilanz), "spiele": int(w.statistik.casino_spiele), "arcade": int(w.statistik.arcade_gewinne),
				"moebel": w.moebel.size(), "walhai": int(w.fischkiste.get("walhai", 0))}
			Netz.test_nachricht.rpc_id(ids.testgast1, "CASINO")
			schritt = 82
			frist = zeit + 40.0
		82:
			if _berichte.has("CASINO_OK"):
				var b: Dictionary = _berichte.CASINO_OK
				var w := s.wirtschaft
				_p("Casino-Runde des Gasts in der gemeinsamen Kasse", int(w.statistik.casino_spiele) - int(_vor.spiele) == 1 and int(w.statistik.casino_bilanz) - int(_vor.bilanz) == int(b.aus) - int(b.einsatz),
					"Einsatz %s, Auszahlung %s, Bilanz %+d" % [b.einsatz, b.aus, int(w.statistik.casino_bilanz) - int(_vor.bilanz)])
				_p("Arcade-Gewinn des Gasts im gemeinsamen Lager", int(w.statistik.arcade_gewinne) - int(_vor.arcade) == 1 and w.moebel.size() - int(_vor.moebel) == 1 and w.anzahl_gegenstand(str(b.kapsel)) >= 1, str(b.kapsel))
				var fi: Dictionary = w.fisch_index.get("walhai", {})
				_p("Fang des Gasts in der gemeinsamen Fischkiste, Index mit Namen", int(w.fischkiste.get("walhai", 0)) - int(_vor.walhai) == 1 and str(fi.get("wer", "")) == "Testgast 1" and absf(float(fi.get("max", 0.0)) - 10.5) < 0.01, str(fi))
				_mi = w.moebel.size() - 1
				var e := Netz.befehl("moebel_sperren", {"i": _mi, "id": w.moebel[_mi].id})   # Gastgeber stellt um
				_p("Gastgeber sperrt Möbel zum Umstellen", e.ok, "")
				Netz.test_nachricht.rpc_id(ids.testgast1, "MOEBEL1 %d %s" % [_mi, w.moebel[_mi].id])
				schritt = 83
				frist = zeit + 30.0
			elif zeit >= frist:
				_p("Casino/Arcade beim Gast", false, "keine Antwort")
				schritt = 55
		83:
			if _berichte.has("MOEBEL1"):
				var w := s.wirtschaft
				Netz.befehl("moebel_setzen", {"i": _mi, "id": w.moebel[_mi].id, "x": 1.0, "z": 2.0, "dreh": 90.0})
				Netz.test_nachricht.rpc_id(ids.testgast1, "MOEBEL2 %d %s" % [_mi, w.moebel[_mi].id])
				schritt = 84
				frist = zeit + 30.0
			elif zeit >= frist:
				_p("Möbel-Sperre", false, "keine Antwort")
				schritt = 55
		84:
			if _berichte.has("MOEBEL2_OK"):
				var m: Dictionary = s.wirtschaft.moebel[_mi]
				_p("Gast räumt das Möbel ins Lager (nach dem Abstellen des Gastgebers)", not m.steht and absf(float(m.x) - 1.0) < 0.01 and absf(float(m.dreh) - 90.0) < 0.01 and Netz._moebel_sperre.is_empty(), str(m))
				schritt = 85
			elif zeit >= frist:
				_p("Möbel ins Lager", false, "keine Antwort")
				schritt = 85
		85:   # 7f: Gast chattet (Enter), winkt (G, 1), pingt
			Netz.test_nachricht.rpc_id(ids.testgast1, "SOZIAL")
			schritt = 86
			frist = zeit + 30.0
		86:
			if _berichte.has("SOZIAL_OK"):
				schritt = 87
				warte_bis = zeit + 1.5
			elif zeit >= frist:
				_p("Chat/Emote/Ping beim Gast", false, "keine Antwort")
				schritt = 55
		87:
			var gid: int = ids.testgast1
			_p("Chat des Gasts beim Gastgeber", "Testgast 1: Hallo von Gast 1" in s.miteinander.chat_texte(), str(s.miteinander.chat_texte()))
			_p("Emote des Gasts: Sprechblase über seiner Figur", s.mitspieler.blase_von(gid) == "Hallo!", s.mitspieler.blase_von(gid))
			var pg := {}
			for p in s.miteinander.pings:
				if p.name == "Testgast 1":
					pg = p
			var g := s.mitspieler.gondel_von(gid)
			_p("Ping des Gasts am Glas vor seiner Gondel", not pg.is_empty() and g != null and (pg.pos as Vector3).distance_to(g.global_position) < 6.0, "Abstand %.1f m" % ((pg.pos as Vector3).distance_to(g.global_position) if not pg.is_empty() and g else -1.0))
			s.miteinander.ping_karte(Vector2(10.0, 20.0))   # Gastgeber setzt einen Treffpunkt auf der Karte
			schritt = 874
			if DisplayServer.get_name() != "headless" and g != null:   # Testbild: zur Gondel des Gasts schauen
				var d := g.global_position + Vector3(0, 1.5, 0) - s.laeufer.cam.global_position
				s.laeufer.yaw = atan2(-d.x, -d.z)
				s.laeufer.pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 1.2)
				schritt = 871
				warte_bis = zeit + 0.8
		871:
			_bild_speichern("netztest_7f_welt.png")
			s.karte.oeffnen()
			schritt = 872
			warte_bis = zeit + 0.8
		872:
			_bild_speichern("netztest_7f_karte.png")
			s.karte.schliessen()
			schritt = 874
		874:
			Netz.alle_pausieren(true)
			_p("Gastgeber pausiert für alle", get_tree().paused and s.miteinander.pause_ebene.visible, "")
			schritt = 88
			warte_bis = zeit + 1.5
		88:
			Netz.test_nachricht.rpc_id(ids.testgast1, "PAUSE?")
			schritt = 89
			warte_bis = zeit + 1.0
		89:
			Netz.alle_pausieren(false)
			schritt = 890
			warte_bis = zeit + 1.5
		890:
			Netz.test_nachricht.rpc_id(ids.testgast1, "WEITER?")
			schritt = 55
			warte_bis = zeit + 1.0
		103:   # 7f: ein dritter Gast kommt (wieder Platz) und wird über das Pausenmenü rausgeworfen
			s.helfer.aktiv = false
			var d := "user://netztest_testgast3.txt"
			if FileAccess.file_exists(d):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(d))
			_gast_starten("testgast3")
			schritt = 104
			frist = zeit + 60.0
		104:
			if _id_von("testgast3") > 0:
				ids.testgast3 = _id_von("testgast3")
				schritt = 105
				warte_bis = zeit + 10.0   # seine eigenen Beitritts-Prüfungen laufen lassen
			elif zeit >= frist:
				_p("Gast 3 tritt bei", false, "Zeitlimit")
				schritt = 101
		105:
			s.pause_oeffnen()
			var k: Button = s.pause.find_child("kick_%d" % ids.testgast3, true, false) if s.pause else null
			var hat_liste := s.pause != null and s.pause.find_child("alle_pause", true, false) != null
			if k:
				k.pressed.emit()
			_p("Pausenmenü im Koop: Spielerliste, Rauswerfen, Für alle pausieren", k != null and hat_liste and not get_tree().paused, "")
			if s.pause:
				s.pause.schliessen()
			schritt = 106
			frist = zeit + 25.0
		106:
			var t := _datei("testgast3")
			if t != "":
				_p("Rausgeworfener Gast im Hauptmenü mit Meldung", "genommen" in t and Netz.spieler.size() == 2, t.strip_edges())
				schritt = 101
				warte_bis = zeit + 1.0
			elif zeit >= frist:
				_p("Rauswerfen", false, "keine Antwort von testgast3")
				schritt = 101
		101:   # 7d: Abspann startet der Gastgeber für alle
			s.abspann_starten()
			schritt = 102
			warte_bis = zeit + 2.0
		102:
			Netz.test_nachricht.rpc_id(ids.testgast1, "ABSPANN?")
			schritt = 11
			warte_bis = zeit + 1.5
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
			_p("Preis-Faktor zu dritt ×1,5", w.koop_max == 3 and w.koop_faktor() == 1.5 and w.upgrade_preis("arm") == 90, "×%.2f, Arm %d €" % [w.koop_faktor(), w.upgrade_preis("arm")])
			_p("koop_max im Spielstand", int(s.stand_daten().wirtschaft.koop_max) == 3, "")
			Netz.test_nachricht.rpc_id(ids.testgast1, "FAKTOR? 2.0")
			Netz.befehl("fahrzeug", {"id": "scooter"})   # Gast 2 soll damit fahren (7d: Fahrzeuge der anderen)
			Netz.test_nachricht.rpc_id(ids.testgast2, "BESITZ?")
			_gast_starten("testgast3")
			schritt = 8
			frist = zeit + 45.0
		8:
			var t := _datei("testgast3")
			if t != "":
				_p("Vierter Spieler abgelehnt (voll)", "voll" in t and Netz.spieler.size() == 3, t.strip_edges())
				schritt = 90
			elif zeit >= frist:
				_p("Vierter Spieler abgelehnt", false, "keine Antwort von testgast3")
				schritt = 90
		90:   # 7e: Yacht – Gastgeber steuert, Gast 2 steigt am Liegeplatz zu
			s.wirtschaft.yacht = true
			var e := Netz.befehl("yacht", {"rolle": "fahren"})
			if e.ok:
				s.strand.einsteigen()
			_p("Gastgeber steuert die Yacht", e.ok and s.strand.yacht.an_bord and not s.strand.yacht.mitfahrer and Netz._yacht_fahrer == 1, "")
			schritt = 91
			warte_bis = zeit + 1.0
		91:
			Netz.test_nachricht.rpc_id(ids.testgast2, "YACHT_MIT")
			schritt = 92
			frist = zeit + 30.0
		92:
			if _berichte.has("YACHT_MIT"):
				var y := s.strand.yacht
				y.position += Vector3(-60.0, 0.0, 0.0)   # hinaus aufs Meer
				schritt = 93
				warte_bis = zeit + 2.0
			elif zeit >= frist:
				_p("Gast steigt zu", false, "keine Antwort")
				schritt = 9
		93:
			var y := s.strand.yacht
			Netz.test_nachricht.rpc_id(ids.testgast2, "YACHT? %f %f" % [y.position.x, y.position.z])
			Netz.test_nachricht.rpc_id(ids.testgast1, "YACHT_FAHREN")
			schritt = 94
			warte_bis = zeit + 3.0
		94:   # zurück an den Steg, Gastgeber steigt aus (Steuer frei), Gast 2 steigt aus
			s.strand.yacht.anlegen()
			s.strand.aussteigen()
			_p("Steuer nach dem Aussteigen frei", Netz._yacht_fahrer == 0 and not s.strand.yacht.an_bord, "")
			schritt = 95
			warte_bis = zeit + 1.5
		95:
			Netz.test_nachricht.rpc_id(ids.testgast2, "YACHT_AUS")
			schritt = 9
			warte_bis = zeit + 2.0
		9:   # Gast 2 verlässt die Runde selbst
			Netz.test_nachricht.rpc_id(ids.testgast2, "VERLASSEN")
			schritt = 10
			frist = zeit + 25.0
		10:
			var t := _datei("testgast2")
			if t != "" and Netz.spieler.size() == 2:
				_p("Gast 2 hat verlassen, Liste wieder 2", true, t.strip_edges())
				_p("Ort von Gast 2 gemerkt", Netz.orte.has(_profil_id("testgast2")) or Netz.orte.size() >= 2, "%d Orte" % Netz.orte.size())
				schritt = 103
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
var _taube := Vector2i(-1, -1)
var _mi := 0
var _kh := 0
var _k2 := 1
var _vor := {}
var _w2 := Vector2i.ZERO   # (spalte, stockwerk) für „zwei wischen dasselbe“ + Dreck

func _bild_speichern(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://" + n)
	print("NETZTEST BILD %s" % ProjectSettings.globalize_path("user://" + n))

func lohn_ohne_boost(f := 0) -> int:
	return s.lohn_mit_boni(f)

# drei dreckige Fenster nebeneinander in Stockwerk f (ohne Wisch-Slot)
func _drei_dreckige(f: int) -> Vector2i:
	for sp in range(5, s.turm.fenster_pro_stock[f] - 3):
		var ok := true
		for d in 3:
			var id: int = s.turm.fenster_basis[f] + sp + d
			if s.zustand.ist_sauber(f, sp + d) or s.zustand.slots.has(id):
				ok = false
		if ok:
			return Vector2i(sp, f)
	return Vector2i(5, f)
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
		var empf0 := int(Netz.lage_zaehler.get(id, 0))
		await get_tree().create_timer(1.0).timeout
		var ist := s.mitspieler.figur_pos(id)
		var fi: Dictionary = s.mitspieler.figuren.get(id, {})
		_p("Figur von %s an der richtigen Stelle" % wer, ist.distance_to(soll) < 0.6 and s.mitspieler.figur_sichtbar(id), "Abstand %.2f m (Ziel %s, Lage %s, soll %s; Gast hat %s Lage-Pakete gesendet, eigene Lage %s; empfangen %d, in der letzten Sekunde %d)" % [ist.distance_to(soll), fi.get("ziel"), str(fi.get("lage", [])).left(80), soll, t.split(" ")[4] if t.split(" ").size() > 4 else "?", t.split(" ")[5] if t.split(" ").size() > 5 else "?", int(Netz.lage_zaehler.get(id, 0)), int(Netz.lage_zaehler.get(id, 0)) - empf0])
	elif t.begins_with("GELD "):
		_p("Geld bei %s wie beim Gastgeber" % wer, int(t.substr(5)) == s.wirtschaft.geld, "%s / %d €" % [t.substr(5), s.wirtschaft.geld])
	elif t.begins_with("ZAHL "):
		_p("Saubere Fenster bei %s wie beim Gastgeber" % wer, int(t.substr(5)) == s.zustand.sauber_zahl and s.zustand.sauber_zahl >= SAUBER, "%s / %d" % [t.substr(5), s.zustand.sauber_zahl])
	elif t.begins_with("PHASE "):
		var d := absf(wrapf(float(t.substr(6)) - s.welt.zeit.phase, -0.5, 0.5))
		_p("Tageszeit bei %s wie beim Gastgeber" % wer, d < 0.003, "Unterschied %.4f (= %.1f s)" % [d, d * Tageszeit.TAG])
	elif t.begins_with("PROFIL "):
		_profil_ids[wer.to_lower().replace(" ", "")] = t.substr(7)
	elif t == "FAHRZEUG":
		await get_tree().create_timer(1.5).timeout
		_p("Fahrzeug von %s beim Gastgeber zu sehen" % wer, s.mitspieler.fahrzeug_von(id) == "scooter", s.mitspieler.fahrzeug_von(id))
	elif t.begins_with("STEMPEL "):
		var w2 := t.split(" ")
		await get_tree().create_timer(0.8).timeout
		var fo := s.zustand.fortschritt(int(w2[1]), int(w2[2]))
		_p("Wisch-Stempel des Gasts kommen beim Gastgeber an", fo > 0.0 and fo < 1.0, "Fenster %s/%s, Fortschritt %.2f" % [w2[1], w2[2], fo])
	elif t.get_slice(" ", 0) in ["GEKAUFT", "ABGELEHNT", "IN_GONDEL", "GEWISCHT", "DOPPELT", "HOEHE_OK", "GEHOLFEN", "HEIM_OK", "CASINO_OK", "MOEBEL1", "MOEBEL2_OK", "YACHT_MIT", "SOZIAL_OK"]:
		var teile := t.split(" ")
		var b := {}
		for x in teile.slice(1):
			if "=" in x:
				b[x.get_slice("=", 0)] = x.get_slice("=", 1)
		_berichte[teile[0]] = b

var _beendet := false
func _ende() -> void:
	if _beendet:   # Netz.beenden wartet mit EOS kurz aufs Abmelden – nur einmal auswerten
		return
	_beendet = true
	print("NETZTEST ERGEBNIS ok=%d fehler=%d" % [ok, fehler])
	Netz.beenden(0 if fehler == 0 else 1)   # mit EOS: abmelden, sonst hängt der Prozess

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
		Netz.beenden()
		return
	if not Netz.ist_gast() or Netz.gast_stand.is_empty():
		if zeit > 90.0:
			gemeldet = true
			_gast_schreiben("Zeitlimit beim Beitreten")
			Netz.beenden()
		return
	_gast_zeit += dt
	if not _geprueft and _gast_zeit > 2.0 and s.laeufer.aktiv:
		_geprueft = true
		var h := 1
		Netz.test_nachricht.rpc_id(h, "PROFIL " + str(Netz.profil.id))
		Netz.test_nachricht.rpc_id(h, "GELD %d" % s.wirtschaft.geld)
		Netz.test_nachricht.rpc_id(h, "ZAHL %d" % s.zustand.sauber_zahl)   # Gastgeber vergleicht (7c: es werden mehr)
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
		Netz.test_nachricht.rpc_id(h, "GASTPOS %f %f %f %d %s" % [q.x, q.y + s.laeufer.hoch, q.z, int(Netz.lage_zaehler.gesendet), str(s.lage_daten()).left(60).replace(" ", "")])

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
	elif t.begins_with("GONDEL "):
		_gast_gondel(int(t.get_slice(" ", 1)), int(t.get_slice(" ", 2)))
	elif t == "WISCHEN":
		_gast_wischen()
	elif t.begins_with("DOPPEL "):
		var f := int(t.get_slice(" ", 1))
		var sp := int(t.get_slice(" ", 2))
		if s.zustand.wische(f, sp, 0.5, 0.5, 3.0, 3.0):
			s._fenster_sauber(f, sp)
		await get_tree().create_timer(2.0).timeout
		Netz.test_nachricht.rpc_id(1, "DOPPELT zahl=%d" % s.zustand.sauber_zahl)
	elif t.begins_with("DRECK? "):
		var f := int(t.get_slice(" ", 1))
		var sp := int(t.get_slice(" ", 2))
		var z := s.zustand
		_melden(not z.ist_sauber(f, sp) and absf(z.dreck(f, sp) - 0.4) < 0.01, "Taube beim Gastgeber → Fenster beim Gast wieder dreckig", "Dreck %.2f" % z.dreck(f, sp))
		_melden(absf(z.dreck(f, sp + 1) - 0.12) < 0.01, "Helfer wischt beim Gastgeber → Dreck beim Gast weniger", "Dreck %.2f" % z.dreck(f, sp + 1))
		_melden(z.ist_sauber(f, sp + 2) and z.sauber_zahl == int(t.get_slice(" ", 3)), "Helfer-Fenster beim Gast sauber, Zähler gleich", "%d / %s" % [z.sauber_zahl, t.get_slice(" ", 3)])
	elif t == "HELFEN":   # 7h: Taste H in der Gondel
		var vorher := s.spieler.seite
		if s.shop.offen:   # Werkstatt ist von „SHOP_AUF“ noch offen – mit offenem Menü wirkt H (absichtlich) nicht
			s.shop.umschalten()
		await get_tree().create_timer(5.5).timeout   # Hinweis-Takt läuft alle 5 s (eigene Seite ist hier noch dreckig → kein Hinweis)
		var info := "aktiv=%s express=%s faehrt=%s dreck=%s" % [s.spieler.aktiv, s.express, s.extras._faehrt, str(s.dreck_je_seite()).replace(" ", "")]
		_taste_ereignis(KEY_H)
		await get_tree().create_timer(1.2).timeout
		var taste := s.spieler.seite != vorher
		var direkt := false
		if not taste:   # Eingrenzen: geht der direkte Aufruf?
			s.mithelfen()
			await get_tree().create_timer(1.2).timeout
			direkt = s.spieler.seite != vorher
		Netz.test_nachricht.rpc_id(1, "GEHOLFEN seite=%d aktive=%d taste=%d direkt=%d %s" % [s.spieler.seite, s.wirtschaft.aktive_gondel, 1 if taste else 0, 1 if direkt else 0, info])
	elif t == "HEIM":
		var w_hilf := s.stand_daten()
		var heim := s._heim_weg()
		s.heim_kehren()
		await get_tree().create_timer(0.5).timeout
		Netz.test_nachricht.rpc_id(1, "HEIM_OK seite=%d weg_ok=%d" % [s.spieler.seite, 1 if absf(float(w_hilf.weg) - heim) < 0.01 and absf(s.spieler.weg - heim) < 0.5 else 0])
	elif t == "HOEHE":
		var e1 := await _befehl("hoehe", {"abschnitt": 2, "stock": 12})
		var e2 := await _befehl("hoehe", {"abschnitt": 2, "stock": 12})
		_melden(e1.get("ok", false) and int(e1.get("bonus", 0)) == 75 and not e2.get("ok", true), "Höhenbonus einmal, vom Gastgeber gezahlt", "%s / %s" % [e1, e2])
		Netz.test_nachricht.rpc_id(1, "HOEHE_OK")
	elif t.begins_with("FAKTOR? "):
		var k: Button = s.shop.find_child("up_arm", true, false)
		_melden(s.wirtschaft.koop_faktor() == 1.5 and s.wirtschaft.upgrade_preis("arm") == 90 and k != null and k.text == "90 €", "Preis-Faktor zu dritt beim Gast (Knopf zeigt 90 €)", "×%.2f, Knopf '%s'" % [s.wirtschaft.koop_faktor(), k.text if k else "-"])
	elif t == "BESITZ?":
		var w := s.wirtschaft
		_melden(w.stufen.motor == 1 and "abzieher" in w.besitz and w.helfer.putzkraft == 1, "Gast 2: alles Gekaufte da", "Motor %d, %s" % [w.stufen.motor, w.besitz])
		_melden(w.boosts.is_empty() and w.aktiv == "schwamm" and w.boost_wirkung("tempo") == 0.0, "Gast 2: kein fremder Boost, eigenes Werkzeug", "boosts %s, aktiv %s" % [w.boosts.keys(), w.aktiv])
		_melden(w.koop_faktor() == 1.5, "Gast 2: Preis-Faktor ×1,5", "×%.2f" % w.koop_faktor())
		await get_tree().create_timer(1.5).timeout   # Scooter des Gastgebers ist jetzt in fahrzeuge
		if "scooter" in w.fahrzeuge:
			s._fahrzeug_waehlen("scooter")
		Netz.test_nachricht.rpc_id(1, "FAHRZEUG")
	elif t == "CASINO":
		_gast_casino()
	elif t == "SOZIAL":
		_gast_sozial()
	elif t == "PAUSE?":
		_melden(get_tree().paused and s.miteinander.pause_ebene.visible and "pausiert" in s.miteinander.pause_text.text and not s.miteinander.pause_knopf.visible, "Pause für alle beim Gast (ohne Weiter-Knopf)", s.miteinander.pause_text.text)
	elif t == "WEITER?":
		var treff := false
		for p in s.miteinander.pings:
			if p.name == "Testhost" and Vector2(p.pos.x, p.pos.z).distance_to(Vector2(10, 20)) < 0.5:
				treff = true
		_melden(not get_tree().paused and not s.miteinander.pause_ebene.visible, "Weiter für alle beim Gast", "")
		_melden(treff, "Treffpunkt von der Karte des Gastgebers beim Gast", "")
	elif t.begins_with("MOEBEL1 "):
		var i := int(t.get_slice(" ", 1))
		var id := t.get_slice(" ", 2)
		var e1 := await _befehl("moebel_sperren", {"i": i, "id": id})
		_melden(not e1.get("ok", true) and "stellt das gerade um" in str(e1.get("grund", "")), "Möbel gesperrt, während der Gastgeber umstellt", str(e1.get("grund", "")))
		var e2 := await _befehl("moebel_verkaufen", {"i": i, "id": id})
		_melden(not e2.get("ok", true), "Verkaufen während des Umstellens abgelehnt", str(e2.get("grund", "")))
		Netz.test_nachricht.rpc_id(1, "MOEBEL1")
	elif t.begins_with("MOEBEL2 "):
		var i := int(t.get_slice(" ", 1))
		var id := t.get_slice(" ", 2)
		var e1 := await _befehl("moebel_sperren", {"i": i, "id": id})
		var e2 := await _befehl("moebel_lager", {"i": i, "id": id})
		await get_tree().create_timer(1.0).timeout
		_melden(e1.get("ok", false) and e2.get("ok", false) and i < s.wirtschaft.moebel.size() and not s.wirtschaft.moebel[i].steht, "Nach dem Abstellen: Gast darf umstellen und ins Lager räumen", "%s / %s" % [e1, e2])
		Netz.test_nachricht.rpc_id(1, "MOEBEL2_OK")
	elif t == "YACHT_MIT":
		var e := await _befehl("yacht", {"rolle": "fahren"})
		if e.get("ok", false) and str(e.get("rolle", "")) == "mit":
			s.strand.einsteigen(true, str(e.get("fahrer", "")))
		_melden(s.strand.yacht.an_bord and s.strand.yacht.mitfahrer, "Gast 2 steigt am Liegeplatz zu (Gastgeber steuert)", str(e))
		Netz.test_nachricht.rpc_id(1, "YACHT_MIT")
	elif t.begins_with("YACHT? "):
		var soll := Vector3(float(t.get_slice(" ", 1)), 0.0, float(t.get_slice(" ", 2)))
		var y := s.strand.yacht
		var d := Vector2(y.position.x - soll.x, y.position.z - soll.z).length()
		_melden(y.fremd and y.an_bord and d < 1.0, "Mitfahrer: Yacht folgt dem Fahrer", "Abstand %.2f m" % d)
	elif t == "YACHT_FAHREN":
		var e := await _befehl("yacht", {"rolle": "fahren"})
		_melden(not e.get("ok", true) and "unterwegs" in str(e.get("grund", "")), "Yacht unterwegs → Steuern/Zusteigen abgelehnt", str(e.get("grund", "")))
	elif t == "YACHT_AUS":
		var y := s.strand.yacht
		var war := y.an_bord and y.am_liegeplatz()
		if war:
			s.strand.aussteigen()
		_melden(war and not y.an_bord and not y.fremd, "Mitfahrer steigt am Steg aus, Yacht wieder am Liegeplatz", "")
	elif t == "ABSPANN?":
		_melden(s.abspann != null and is_instance_valid(s.abspann), "Abspann beim Gast gestartet (vom Gastgeber)", "")
	elif t.begins_with("WELT? "):
		var teile := t.split(" ")
		var f := int(teile[1])
		var sp := int(teile[2])
		var e := s.ereignisse
		_melden(e.gast and e.tauben.size() >= 1 and f >= 0 and not s.zustand.ist_sauber(f, sp), "Taube vom Gastgeber beim Gast zu sehen, Fenster bekleckert", "%d Tauben" % e.tauben.size())
		_melden(absf(e.wind_ziel - 0.6) < 0.01 and s.spieler.wind > 0.3, "Böe vom Gastgeber schaukelt die Gondel des Gasts", "wind %.2f" % s.spieler.wind)
		_melden(e.sturm_phase == 1, "Sandsturm-Warnung beim Gast", "Phase %d" % e.sturm_phase)
		var gut := 0
		var alle := 0
		var info := ""
		for it in (teile[3] if teile.size() > 3 else "").split(";", false):
			alle += 1
			var k := it.get_slice("=", 0)
			var p := it.get_slice("=", 1).split_floats(",")
			for h in s.helfer.liste:
				if "%d:%d" % [Helfer.ARTEN.find(h.art), int(h.nr)] == k:
					var d := (h.node as Node3D).position.distance_to(Vector3(p[0], p[1], p[2]))
					info += "%s %.2f m " % [k, d]
					if d < 2.5 and (h.node as Node3D).visible:
						gut += 1
		_melden(alle > 0 and gut == alle and not s.helfer.aktiv and s.helfer.gast, "Helfer des Gastgebers beim Gast an derselben Stelle", info)

# Gast 1 (7f): Enter → Chat, G + 1 → Winken, Ping auf das Glas vor der Gondel – über echte Tasten-Ereignisse
func _gast_sozial() -> void:
	if s.shop.offen:
		s.shop.umschalten()
	await get_tree().process_frame
	_taste_ereignis(KEY_ENTER)
	await get_tree().process_frame
	var chat := s.miteinander.chat_offen()
	s.miteinander.eingabe.text = "Hallo von Gast 1"
	s.miteinander.eingabe.text_submitted.emit(s.miteinander.eingabe.text)
	await get_tree().process_frame
	_taste_ereignis(KEY_G)
	await get_tree().process_frame
	var rad := s.miteinander.rad.visible
	_taste_ereignis(KEY_1)
	await get_tree().process_frame
	_melden(chat and rad and not s.miteinander.blockiert(), "Chat (Enter) und Emote-Rad (G, 1) öffnen und schließen", "chat %s, rad %s" % [chat, rad])
	s.miteinander.ping_hier()
	await get_tree().create_timer(1.5).timeout
	_melden("Testgast 1: Hallo von Gast 1" in s.miteinander.chat_texte() and s.miteinander.pings.size() >= 1, "Eigene Nachricht + Ping kommen über den Gastgeber zurück", str(s.miteinander.chat_texte()))
	s.shop.umschalten()   # Werkstatt wieder auf (spätere Prüfung „Preis-Faktor zu dritt“)
	Netz.test_nachricht.rpc_id(1, "SOZIAL_OK")

func _taste_ereignis(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := ev.duplicate() as InputEventKey
	ev2.pressed = false
	Input.parse_input_event(ev2)

# Gast 1: Bandit über den echten Hebel, zwei unerlaubte Casino-Wünsche, Kapsel über den echten Knopf, ein Walhai
func _gast_casino() -> void:
	var w := s.wirtschaft
	s.cmenu.oeffnen("bandit", "Einarmiger Bandit")
	var k: Button = s.cmenu.find_child("b_hebel", true, false)
	if k and not k.disabled:
		k.pressed.emit()
	var t0 := zeit
	while s.cmenu.laeuft and zeit - t0 < 12.0:
		await get_tree().process_frame
	var einsatz := s.cmenu.einsatz
	var aus := s.cmenu.letzter_gewinn
	s.cmenu.schliessen()
	_melden(k != null and not s.cmenu.laeuft, "Gast spielt Bandit (echter Hebel)", "Einsatz %d, Auszahlung %d" % [einsatz, aus])
	var e := await _befehl("casino_gewinn", {"einsatz": 500, "aus": 5000})
	_melden(not e.get("ok", true), "Casino-Gewinn ohne bezahlte Runde abgelehnt", str(e.get("grund", "")))
	var e2 := await _befehl("zahlen", {"betrag": w.geld, "art": "casino"})
	_melden(not e2.get("ok", true) and "zu hoch" in str(e2.get("grund", "")), "Casino-Einsatzgrenze vom Gastgeber geprüft", str(e2.get("grund", "")))
	s.extras.menu.oeffnen("kapsel", "Kapsel-Automat")
	var kk: Button = s.extras.menu.find_child("kapsel", true, false)
	if kk and not kk.disabled:
		kk.pressed.emit()
	await get_tree().create_timer(2.5).timeout
	var id := s.extras.menu.letzte_kapsel
	s.extras.menu.schliessen()
	_melden(id != "", "Gast zieht eine Kapsel (echter Knopf)", id)
	Netz.fang("walhai", 10.5)
	await get_tree().create_timer(1.5).timeout
	_melden(int(w.fischkiste.get("walhai", 0)) >= 1, "Walhai in der Fischkiste des Gasts (vom Gastgeber bestätigt)", "")
	Netz.test_nachricht.rpc_id(1, "CASINO_OK einsatz=%d aus=%d kapsel=%s" % [einsatz, aus, id])

func _befehl(name: String, d: Dictionary) -> Dictionary:
	var nr := str(Netz.befehl(name, d).get("nr", ""))
	while true:   # auf genau diese Antwort warten (andere Befehle können dazwischen fertig werden)
		var r: Array = await Netz.befehl_fertig
		if str(r[0]) == nr:
			return r[1]
	return {}

# Gast 1: besetzte Gondel des Gastgebers abgelehnt, freie genommen, eingestiegen
func _gast_gondel(kh: int, k2: int) -> void:
	var e1 := await _befehl("gondel_nehmen", {"seite": kh})
	_melden(not e1.get("ok", true) and "fährt gerade" in str(e1.get("grund", "")), "Besetzte Gondel abgelehnt", str(e1.get("grund", "")))
	var e2 := await _befehl("gondel_nehmen", {"seite": k2})
	_melden(e2.get("ok", false), "Freie Gondel genommen", str(e2))
	if e2.get("ok", false):
		s._gondel_wechseln(k2)
		s._einsteigen()
	await get_tree().create_timer(1.2).timeout
	var g := s.spieler.gondel.global_position
	_melden(s.spieler.aktiv and s.wirtschaft.aktive_gondel == k2, "Gast sitzt in Gondel %d" % k2, "")
	Netz.test_nachricht.rpc_id(1, "IN_GONDEL x=%f y=%f z=%f" % [g.x, g.y, g.z])

# Gast 1: Goldpolitur kaufen, ein kleiner Stempel (kommt beim Gastgeber an?), dann ein großer (Fenster fertig → Gastgeber zahlt)
func _gast_wischen() -> void:
	var e := await _befehl("boost", {"id": "goldpolitur"})
	_melden(e.get("ok", false) and s.wirtschaft.boost_aktiv("goldpolitur"), "Gast kauft Goldpolitur", str(e))
	var sp := s.spieler
	var o := Vector2(0.0, 1.6)
	sp._stempel(o)
	var f0 := -1
	var s0 := -1
	for j in range(0, sp.stempel_neu.size() - 5, 6):
		if sp.stempel_neu[j + 2] >= 0.0 and sp.stempel_neu[j + 2] <= 1.0 and sp.stempel_neu[j + 3] >= 0.0 and sp.stempel_neu[j + 3] <= 1.0:
			f0 = int(sp.stempel_neu[j])
			s0 = int(sp.stempel_neu[j + 1])
			break
	Netz.test_nachricht.rpc_id(1, "STEMPEL %d %d" % [f0, s0])
	await get_tree().create_timer(1.6).timeout
	var vor := s.zustand.sauber_zahl
	var rx := sp.wz_rx
	var ry := sp.wz_ry
	sp.wz_rx = 4.0   # riesig: deckt die Fenster vor der Gondel ganz ab
	sp.wz_ry = 4.0
	sp._stempel(o)
	sp.wz_rx = rx
	sp.wz_ry = ry
	var n := s.zustand.sauber_zahl - vor
	await get_tree().create_timer(2.5).timeout
	Netz.test_nachricht.rpc_id(1, "GEWISCHT n=%d zahl=%d geld=%d" % [n, s.zustand.sauber_zahl, s.wirtschaft.geld])
# Gast 1: über die echten Knöpfe kaufen (Werkstatt, Kiosk Werkzeuge, Snacks, Sky-Bar) – jeder Kauf wartet auf die Antwort
func _gast_kaufen() -> void:
	var w := s.wirtschaft
	_melden(w.koop_faktor() == 1.25, "Preis-Faktor zu zweit beim Gast", "×%.2f" % w.koop_faktor())
	_melden(w.geld == 5000, "Kasse vom Gastgeber übernommen", "%d €" % w.geld)
	s.shop.umschalten()
	s.shop._reiter_waehlen(2)   # Ausbau
	await _druecken(s.shop, "up_motor", "%s €" % Hud.punkte(31))
	s.shop.umschalten()
	s.hmenu.oeffnen("grund", "Werkzeuge")
	await _druecken(s.hmenu, "w_abzieher", "150 €")
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
