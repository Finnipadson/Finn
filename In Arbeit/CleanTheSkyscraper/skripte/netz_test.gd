class_name NetzTest
extends Node
# Test 37 – Mehrspieler-Grundlage (Phase 7a), läuft headless mit mehreren Prozessen auf 127.0.0.1:
#   godot --headless --path . -- --ansicht=37 [--netz-verzoegerung=150 --netz-verlust=5]
# Der Gastgeber-Prozess startet die Gäste selbst (OS.create_process, --rolle=gast --profil=testgastN --join=…).
# Ablauf: Gast 1 tritt bei (Geld, Fenster, Tageszeit, Spielerliste gleich?) → beide laufen, jeder sieht die Figur des
# anderen an der richtigen Stelle → Gastgeber ändert Geld, Gast 2 tritt mitten im Spiel bei → Gast 3 wird abgelehnt
# (voll) → Gast 2 verlässt die Runde selbst → Gastgeber beendet, Gast 1 landet mit Meldung im Hauptmenü.
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
			schritt = 55
			warte_bis = zeit + 0.6
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
