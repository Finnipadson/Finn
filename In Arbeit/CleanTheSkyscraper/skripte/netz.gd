extends Node
# Mehrspieler (Phase 7a): Autoload „Netz“ – Verbindung, Spielerliste, Profil, Beitritt mit Voll-Zustand, Lage der Mitspieler,
# Tageszeit vom Gastgeber. Transport jetzt ENet (LAN/IP, Tests auf 127.0.0.1); in 7g kommt Epic Online Services dazu
# (EOSGMultiplayerPeer, gleiche RPCs). Bis zu 3 Spieler; der Gastgeber (Peer 1) hat den echten Spielstand und speichert.
# Große Daten gehen in Stücken à 1.000 Byte (EOS-Paketgrenze ~1.170 Byte, Vorab-Test 18.11.2026).
# Einzelspieler: modus "" → nichts davon läuft, das Spiel verhält sich wie vorher.
#
# Schalter: --host[=PORT]  sofort als Gastgeber starten · --join=ADRESSE[:PORT]  sofort beitreten
#           --profil=NAME  eigenes Profil (user://profil_NAME.json, für mehrere Instanzen auf einem PC)
#           --netz-verzoegerung=MS --netz-verlust=PROZENT  künstlich schlechtes Netz (nur Lage-Pakete werden verworfen)

signal spieler_geaendert                 # Liste geändert (Beitritt, Verlassen, Farbe)
signal status_geaendert(text: String)    # für das Mehrspieler-Menü (Verbinden …, Fehler)

const PORT := 24680
const MAX_SPIELER := 3
const STUECK := 1000
const LAGE_HZ := 20.0
const UHR_TAKT := 5.0
const FARBEN := ["2fb6ff", "ff7a3d", "7ed957", "ff5fa8", "ffd23f", "a77bff"]
const FARB_NAMEN := ["Blau", "Orange", "Grün", "Pink", "Gelb", "Lila"]

var modus := ""                  # "" = Einzelspieler, "host", "gast", "verbinde"
var profil := {"id": "", "name": "", "farbe": 0}
var profil_pfad := "user://profil.json"
var spieler := {}                # peer_id -> {name, farbe, profil_id}
var gast_stand := {}             # Voll-Zustand vom Gastgeber (Gast startet damit das Spiel)
var spiel: Spiel                 # setzt Spiel.starten
var menue_meldung := ""          # nach dem Verlassen im Hauptmenü zeigen (z. B. „Gastgeber hat beendet“)
var orte := {}                   # Gastgeber: profil_id -> Ort des Gasts (für den nächsten Beitritt, wird mitgespeichert)
var verzoegerung := 0.0          # Sekunden (Test-Schalter)
var verlust := 0.0               # 0..1 (Test-Schalter)
var _stuecke := {}               # Empfang: kennung -> {n, teile{}}
var _lage_zeit := 0.0
var _uhr_zeit := 0.0
var _adresse := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if (a.begins_with("--ansicht=") and a != "--ansicht=0") or a == "--durchspielen":
			profil_pfad = "user://profil_test.json"   # Tests/Bot nie mit dem echten Profil
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--profil="):
			profil_pfad = "user://profil_%s.json" % a.substr(9).validate_filename()
		elif a.begins_with("--netz-verzoegerung="):
			verzoegerung = float(a.substr(20)) / 1000.0
		elif a.begins_with("--netz-verlust="):
			verlust = clampf(float(a.substr(15)) / 100.0, 0.0, 1.0)
	profil_laden()
	multiplayer.peer_connected.connect(_peer_da)
	multiplayer.peer_disconnected.connect(_peer_weg)
	multiplayer.connected_to_server.connect(_verbunden)
	multiplayer.connection_failed.connect(_fehlgeschlagen)
	multiplayer.server_disconnected.connect(_server_weg)

func aktiv() -> bool:
	return modus == "host" or modus == "gast"

func ist_host() -> bool:
	return modus == "host"

func ist_gast() -> bool:
	return modus == "gast"

func farbe(id: int) -> Color:
	var s: Dictionary = spieler.get(id, {})
	return Color(FARBEN[int(s.get("farbe", 0)) % FARBEN.size()])

func name_von(id: int) -> String:
	return str((spieler.get(id, {}) as Dictionary).get("name", "Spieler"))

func meine_id() -> int:
	return multiplayer.get_unique_id() if aktiv() else 1

# ---------------------------------------------------------------- Profil
func profil_laden() -> void:
	var d = null
	if FileAccess.file_exists(profil_pfad):
		d = JSON.parse_string(FileAccess.get_file_as_string(profil_pfad))
	if d is Dictionary:
		profil.id = str(d.get("id", ""))
		profil.name = str(d.get("name", ""))
		profil.farbe = int(d.get("farbe", 0)) % FARBEN.size()
	if profil.id == "":
		profil.id = "%08x%08x" % [randi(), randi()]
	if profil.name == "":
		var p := profil_pfad.get_file().get_basename()
		profil.name = p.substr(7).capitalize() if p.begins_with("profil_") else "Putzprofi %d" % (randi() % 90 + 10)
		profil_speichern()

func profil_speichern() -> void:
	profil.name = str(profil.name).strip_edges().left(16)
	if profil.name == "":
		profil.name = "Putzprofi"
	var f := FileAccess.open(profil_pfad, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(profil))

# ---------------------------------------------------------------- Verbinden
func host_starten(port := PORT) -> String:
	trennen()
	var p := ENetMultiplayerPeer.new()
	var e := p.create_server(port, MAX_SPIELER)   # ein Platz mehr als Gäste, damit ein Vierter höflich „voll“ hört
	if e != OK:
		return "Spiel konnte nicht erstellt werden (Port %d belegt?)" % port
	multiplayer.multiplayer_peer = p
	modus = "host"
	spieler = {1: {"name": profil.name, "farbe": profil.farbe, "profil_id": profil.id}}
	_anwesend_setzen()
	spieler_geaendert.emit()
	return ""

func beitreten(adresse: String) -> void:
	if modus == "" and spiel and is_instance_valid(spiel) and spiel.zustand:
		spiel._speichern()   # eigener Einzelspieler-Stand: vorher sichern (danach speichert nur der Gastgeber)
	trennen()
	var ip := adresse.strip_edges()
	var port := PORT
	if ip.count(":") == 1:
		port = int(ip.get_slice(":", 1))
		ip = ip.get_slice(":", 0)
	if ip == "":
		ip = "127.0.0.1"
	_adresse = "%s:%d" % [ip, port]
	var p := ENetMultiplayerPeer.new()
	var e := p.create_client(ip, port)
	if e != OK:
		status_geaendert.emit("Verbindung nicht möglich (%s)" % error_string(e))
		return
	multiplayer.multiplayer_peer = p
	modus = "verbinde"
	status_geaendert.emit("Verbinde mit %s …" % _adresse)

# Verbindung beenden (ohne Szenenwechsel). Gastgeber: alle Gäste fliegen raus und bekommen eine Meldung.
func trennen() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	modus = ""
	spieler = {}
	_stuecke = {}
	_bereite = {}
	_bereit = false
	_warten = {}
	_feld_hash = {}
	_sd_hash = {}
	_eigen_hash = 0
	_anwesend_setzen()
	spieler_geaendert.emit()

# Gast verlässt die Runde (selbst oder weil der Gastgeber weg ist): zurück ins eigene Spiel mit Hauptmenü
func zurueck_ins_menue(meldung: String) -> void:
	var war_gast := modus == "gast" or not gast_stand.is_empty()
	trennen()
	gast_stand = {}
	menue_meldung = meldung
	if war_gast and is_inside_tree():
		if spiel and is_instance_valid(spiel):
			spiel.zustand = null   # nichts speichern (Gast hat keinen eigenen Stand in der Runde)
		Hauptmenue.ueberspringen = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().reload_current_scene.call_deferred()
	else:
		status_geaendert.emit(meldung)   # z. B. abgelehnt, bevor man drin war: Meldung im Mehrspieler-Menü

func _notification(what: int) -> void:
	# Beim Beenden die Verbindung sauber schließen, damit die anderen es sofort merken
	if (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE) and aktiv():
		multiplayer.multiplayer_peer.close()

func _verbunden() -> void:
	status_geaendert.emit("Verbunden – lade die Welt des Gastgebers …")
	anmelden.rpc_id(1, profil.duplicate())

func _fehlgeschlagen() -> void:
	trennen()
	status_geaendert.emit("Verbindung fehlgeschlagen. Stimmt die Adresse? Läuft beim Gastgeber das Spiel?")

func _server_weg() -> void:
	var t := "Der Gastgeber hat das Spiel beendet."
	if modus == "verbinde":
		t = "Der Gastgeber hat die Verbindung abgelehnt."
	zurueck_ins_menue(t)

func _peer_da(_id: int) -> void:
	pass   # Gast meldet sich gleich mit anmelden()

func _peer_weg(id: int) -> void:
	if not ist_host() or not spieler.has(id):
		return
	var n := name_von(id)
	spieler.erase(id)
	_bereite.erase(id)
	_anwesend_setzen()
	liste.rpc(spieler)
	spieler_geaendert.emit()
	if spiel and is_instance_valid(spiel):
		spiel.hud.meldung("%s hat das Spiel verlassen." % n, 3.0)

# ---------------------------------------------------------------- Beitritt (Gast → Gastgeber → Voll-Zustand)
@rpc("any_peer", "call_remote", "reliable")
func anmelden(p: Dictionary) -> void:
	if not ist_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if spieler.size() >= MAX_SPIELER:
		abgelehnt.rpc_id(id, "Das Spiel ist voll (höchstens %d Spieler)." % MAX_SPIELER)
		_rauswerfen_spaeter(id)
		return
	if spiel == null or not is_instance_valid(spiel) or spiel.zustand == null:
		abgelehnt.rpc_id(id, "Der Gastgeber ist gerade nicht im Spiel.")
		_rauswerfen_spaeter(id)
		return
	# Farbe: gewünschte, sonst die nächste freie
	var belegt := []
	for k in spieler:
		belegt.append(int(spieler[k].farbe))
	var fa := int(p.get("farbe", 0)) % FARBEN.size()
	while fa in belegt:
		fa = (fa + 1) % FARBEN.size()
	spieler[id] = {"name": str(p.get("name", "Gast")).left(16), "farbe": fa, "profil_id": str(p.get("profil_id", p.get("id", "")))}
	var stand := spiel.stand_daten()
	stand["ort"] = orte.get(spieler[id].profil_id, {})
	_anwesend_setzen()
	stand["netz"] = {"spieler": spieler, "belegte_gondeln": _belegte_gondeln(id)}
	_gross_senden(id, "stand", var_to_bytes(stand).compress(FileAccess.COMPRESSION_GZIP))
	liste.rpc(spieler)
	spieler_geaendert.emit()
	spiel.hud.meldung("%s ist dem Spiel beigetreten." % spieler[id].name, 3.0)

func _rauswerfen_spaeter(id: int) -> void:
	await get_tree().create_timer(0.5).timeout
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)

# Gondeln, in denen gerade jemand sitzt (Gastgeber + andere Gäste; der Neue zählt nicht)
func _belegte_gondeln(ausser := 0) -> Array:
	var b := []
	var w := _w()
	if w == null:
		return b
	for id in spieler:
		if id == ausser:
			continue
		var pid: String = w.ich if id == 1 else str(spieler[id].profil_id)
		var k := int((w.spieler_daten.get(pid, {}) as Dictionary).get("aktive_gondel", -1))
		if k >= 0 and not k in b:
			b.append(k)
	return b

@rpc("authority", "call_remote", "reliable")
func abgelehnt(grund: String) -> void:
	zurueck_ins_menue(grund)

@rpc("authority", "call_remote", "reliable")
func liste(l: Dictionary) -> void:
	spieler = {}
	for k in l:
		spieler[int(k)] = l[k]
	if _bereit:
		_anwesend_setzen()
	spieler_geaendert.emit()

# Große Daten in Stücken (EOS lässt nur ~1 KB je Paket durch)
func _gross_senden(id: int, art: String, daten: PackedByteArray) -> void:
	var kennung := "%s_%d" % [art, Time.get_ticks_usec()]
	var n := maxi(1, ceili(daten.size() / float(STUECK)))
	for i in n:
		stueck.rpc_id(id, kennung, art, i, n, daten.slice(i * STUECK, mini((i + 1) * STUECK, daten.size())))

@rpc("authority", "call_remote", "reliable")
func stueck(kennung: String, art: String, i: int, n: int, teil: PackedByteArray) -> void:
	if not _stuecke.has(kennung):
		_stuecke[kennung] = {"n": n, "teile": {}}
	_stuecke[kennung].teile[i] = teil
	if _stuecke[kennung].teile.size() < n:
		return
	var alles := PackedByteArray()
	for k in n:
		alles.append_array(_stuecke[kennung].teile[k])
	_stuecke.erase(kennung)
	if art == "stand":
		_stand_da(alles)
	elif art == "felder":
		_felder_anwenden(alles, true)

func _stand_da(gz: PackedByteArray) -> void:
	var roh := gz.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var d = bytes_to_var(roh)
	if not (d is Dictionary):
		zurueck_ins_menue("Die Welt des Gastgebers konnte nicht geladen werden.")
		return
	gast_stand = d
	modus = "gast"
	var netz: Dictionary = d.get("netz", {})
	liste(netz.get("spieler", {}))
	status_geaendert.emit("Welt geladen")
	# Szene neu laden: Spiel.starten nimmt dann gast_stand statt der eigenen Datei
	Hauptmenue.ueberspringen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene.call_deferred()

# Gast-Ort beim Verlassen merken (Gastgeber speichert ihn im Spielstand unter „netz_orte“)
@rpc("any_peer", "call_remote", "reliable")
func ort_melden(o: Dictionary) -> void:
	if not ist_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if spieler.has(id):
		orte[str(spieler[id].profil_id)] = o

# ---------------------------------------------------------------- Laufend: Lage + Tageszeit
func _process(dt: float) -> void:
	if not aktiv() or spiel == null or not is_instance_valid(spiel) or spiel.zustand == null:
		return
	_netz_takt(dt)
	_lage_zeit += dt
	if _lage_zeit >= 1.0 / LAGE_HZ:
		_lage_zeit = 0.0
		var l := spiel.lage_daten()
		if verzoegerung > 0.0:
			_spaeter_lage(l)
		else:
			lage.rpc(l)
	if ist_host():
		_uhr_zeit += dt
		if _uhr_zeit >= UHR_TAKT:
			_uhr_zeit = 0.0
			if spiel.welt.zeit.phase >= 0.0:
				uhr.rpc(spiel.welt.zeit.phase)
		# Gast-Orte laufend merken (falls ein Gast abstürzt)
		if spiel.mitspieler:
			for id in spieler:
				if id != 1:
					var o: Dictionary = spiel.mitspieler.ort_von(id)
					if not o.is_empty():
						orte[str(spieler[id].profil_id)] = o

func _spaeter_lage(l: Array) -> void:
	await get_tree().create_timer(verzoegerung).timeout
	if aktiv():
		lage.rpc(l)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func lage(l: Array) -> void:
	if verlust > 0.0 and randf() < verlust:
		return
	var id := multiplayer.get_remote_sender_id()
	if spiel and is_instance_valid(spiel) and spiel.mitspieler and spieler.has(id):
		spiel.mitspieler.lage(id, l)

@rpc("authority", "call_remote", "reliable")
func uhr(phase: float) -> void:
	if spiel and is_instance_valid(spiel) and spiel.welt.zeit.phase >= 0.0:
		var z := spiel.welt.zeit
		var d := wrapf(phase - z.phase, -0.5, 0.5)
		# großer Unterschied (Beitritt, Zeitsprung): springen, sonst weich angleichen (kein Lichtsprung)
		z.phase = phase if absf(d) > 0.01 else fposmod(z.phase + d * 0.5, 1.0)

# ---------------------------------------------------------------- Befehle + gemeinsame Kasse (Phase 7b)
# Netz.befehl(name, daten, fertig): Einzelspieler und Gastgeber führen sofort aus (fertig wird gleich gerufen – das Spiel
# verhält sich wie vorher), ein Gast schickt den Wunsch an den Gastgeber. Der prüft (Geld, Grenzen) und führt in den
# bestehenden Wirtschaft-Funktionen aus – für Werkzeug/Boosts/Aussehen des Gasts mit wirtschaft.als(profil_id) –, schickt die
# geänderten Wirtschaft-Felder an alle und dem Gast die Antwort {ok, grund, …} mit seinen geänderten eigenen Werten.
# Feld-Updates: der Gastgeber vergleicht 5× pro Sekunde (und sofort nach jedem Befehl) alle gemeinsamen Felder und schickt
# nur geänderte. Ein Gast zeigt beim Geld immer den Stand des Gastgebers (_kasse). Seine eigenen Werte (Werkzeug in der Hand,
# Fahrzeug, Aussehen, Gondel, Radio) meldet er selbst bei Änderung (meine_daten), damit Tasten 1–0 ohne Warten wirken.
signal befehl_fertig(name: String, ergebnis: Dictionary)   # Gast: Antwort ist da (für Tests)

const FELDER := ["geld", "besitz", "stufen", "album", "hoechster_abschnitt", "einstellungen", "kosmetik_besitz", "helfer",
	"fahrzeuge", "gondeln", "moebel", "erfolge", "besucht", "angeln", "fischkiste", "fisch_index", "yacht", "turm_nr",
	"tuerme_fertig", "abspann", "koop_max"]
# Änderung eines dieser Felder → Spiel._ausruestung beim Gast (Helfer, Gondeln, Seil-Grenze, Ereignis-Schalter)
const FELDER_AUSRUESTUNG := ["besitz", "stufen", "helfer", "fahrzeuge", "gondeln", "moebel", "einstellungen", "koop_max", "kosmetik_besitz"]
const EIGENE := ["aktiv", "kosmetik_aktiv", "fahrzeug", "aktive_gondel", "radio"]   # meldet der Gast selbst
const FELD_TAKT := 0.2           # höchstens 5× pro Sekunde
const STATISTIK_TAKT := 2.0

var _befehl_nr := 0
var _warten := {}                # Gast: Nummer -> Callable
var _feld_hash := {}             # Gastgeber: zuletzt geschickter Stand je Feld
var _sd_hash := {}               # Gastgeber: zuletzt geschickte Spieler-Werte je Profil
var _bereite := {}               # Gastgeber: Gäste, deren Welt fertig geladen ist (bekommen Feld-Updates)
var _feld_zeit := 0.0
var _stat_zeit := 0.0
var _bereit := false             # Gast: Welt geladen, Feld-Updates gelten
var _kasse := 0                  # Gast: Geld laut Gastgeber
var _eigen_hash := 0
var _eigen_zeit := 0.0

func _w() -> Wirtschaft:
	if spiel and is_instance_valid(spiel) and spiel.zustand:
		return spiel.wirtschaft
	return null

func befehl(name: String, d: Dictionary = {}, fertig: Callable = Callable()) -> Dictionary:
	if ist_gast():
		_befehl_nr += 1
		var nr := _befehl_nr
		if fertig.is_valid():
			_warten[nr] = fertig
		_spaeter(func(): befehl_wunsch.rpc_id(1, nr, name, d))
		return {"ok": false, "wartet": true}
	var w := _w()
	if w == null:
		return {"ok": false}
	var e := _ausfuehren(name, d, w.ich)
	if ist_host():
		if e.ok and e.has("was"):
			for g in _bereite:
				hinweis.rpc_id(g, "%s hat gekauft: %s" % [profil.name, e.was])
		_felder_pruefen()
	if fertig.is_valid():
		fertig.call(e)
	return e

func _spaeter(f: Callable) -> void:
	if verzoegerung > 0.0:
		await get_tree().create_timer(verzoegerung).timeout
		if not aktiv():
			return
	f.call()

# Ausführung (Einzelspieler/Gastgeber) für den Spieler mit Profil pid
func _ausfuehren(name: String, d: Dictionary, pid: String) -> Dictionary:
	var w := _w()
	var e := {"ok": false}
	var id := str(d.get("id", ""))
	var was := ""
	w.als(pid)
	match name:
		"werkzeug":
			e["ok"] = w.kaufe_werkzeug(id)
			was = w.werkzeug(id).name
		"ausruesten":
			e["ok"] = w.ausruesten(id)
		"upgrade":
			e["ok"] = Wirtschaft.UPGRADES.has(id) and w.kaufe_upgrade(id)
			was = Wirtschaft.UPGRADES.get(id, {}).get("name", id)
		"helfer":
			e["ok"] = Wirtschaft.HELFER.has(id) and w.kaufe_helfer(id)
			was = Wirtschaft.HELFER.get(id, {}).get("name", id)
		"gondel":
			var k := int(d.get("seite", -1))
			e["ok"] = k >= 0 and k < 3 and w.kaufe_gondel(k)
			was = "Gondel " + (Turm.SEITEN_NAMEN[k] if k >= 0 and k < 3 else "")
		"boost":
			e["ok"] = Wirtschaft.BOOSTS.has(id) and w.kaufe_boost(id)
		"kosmetik":
			e["ok"] = w.kosmetik(id).id == id and w.kaufe_kosmetik(id)
			was = str(w.kosmetik(id).name)
		"kosmetik_nutzen":
			e["ok"] = w.nutze_kosmetik(id)
		"fahrzeug":
			e["ok"] = w.kaufe_fahrzeug(id)
			was = str(w.fahrzeug_daten(id).get("name", id))
		"fahrzeug_nehmen":
			e["ok"] = id == "" or id in w.fahrzeuge
			if e.ok:
				w.fahrzeug = id
		"gegenstand":
			e["ok"] = w.kaufe_gegenstand(id)
			was = str(w.gegenstand(id).get("name", id))
		"angel":
			e["ok"] = w.kaufe_angel(id)
			was = str(w.angel_daten(id).get("name", id))
		"fisch":
			e["erloes"] = w.verkaufe_fisch(id, int(d.get("anzahl", -1)))
			e["ok"] = int(e.erloes) > 0
		"fische_alle":
			e["erloes"] = w.verkaufe_alle_fische()
			e["ok"] = int(e.erloes) > 0
		_:
			e["grund"] = "Unbekannter Befehl „%s“." % name
	w.als("")
	if e.ok and was != "":
		e["was"] = was
	if not e.ok and not e.has("grund"):
		e["grund"] = "Geht nicht – in der gemeinsamen Kasse sind %s €." % Hud.punkte(w.geld)
	return e

# Gastgeber: Wunsch eines Gasts
@rpc("any_peer", "call_remote", "reliable")
func befehl_wunsch(nr: int, name: String, d: Dictionary) -> void:
	if not ist_host():
		return
	var id := multiplayer.get_remote_sender_id()
	var w := _w()
	if w == null or not spieler.has(id):
		_spaeter(func(): befehl_antwort.rpc_id(id, nr, {"ok": false, "grund": "Der Gastgeber ist gerade nicht im Spiel."}, {}))
		return
	var pid := str(spieler[id].profil_id)
	if not w.spieler_daten.has(pid):
		w.spieler_daten[pid] = w.neue_spieler_daten()
	var vorher: Dictionary = (w.spieler_daten[pid] as Dictionary).duplicate(true)
	var e := _ausfuehren(name, d, pid)
	var eigen := {}
	var nach: Dictionary = w.spieler_daten[pid]
	for k in nach:
		if hash(nach[k]) != hash(vorher.get(k)):
			eigen[k] = nach[k]
	if e.ok:
		spiel._ausruestung()            # Helfer, Gondeln, Seil-Grenze; speichert
		spiel.menues_aktualisieren()
		if e.has("was"):
			var t := "%s hat gekauft: %s" % [name_von(id), e.was]
			spiel.hud.meldung(t, 3.0)
			for g in _bereite:
				if g != id:
					hinweis.rpc_id(g, t)
	_felder_pruefen()
	_spaeter(func(): befehl_antwort.rpc_id(id, nr, e, eigen))

# Gast: Antwort des Gastgebers (die Felder sind schon vorher angekommen)
@rpc("authority", "call_remote", "reliable")
func befehl_antwort(nr: int, e: Dictionary, eigen: Dictionary) -> void:
	var w := _w()
	if w and _bereit:
		var meine: Dictionary = w.spieler_daten.get(w.ich, {})
		if meine.is_empty():
			w.spieler_daten[w.ich] = w.neue_spieler_daten()
			meine = w.spieler_daten[w.ich]
		for k in eigen:
			if k in Wirtschaft.JE_SPIELER:
				meine[k] = eigen[k]
		if not e.get("ok", false):
			spiel.hud.meldung(str(e.get("grund", "Das geht gerade nicht.")), 3.0)
	befehl_fertig.emit(str(nr), e)
	var f: Callable = _warten.get(nr, Callable())
	_warten.erase(nr)
	if f.is_valid():
		f.call(e)

@rpc("authority", "call_remote", "reliable")
func hinweis(t: String) -> void:
	if spiel and is_instance_valid(spiel) and spiel.hud:
		spiel.hud.meldung(t, 3.0)

# Gastgeber: geänderte Felder (alle = Voll-Stand für einen frisch geladenen Gast an)
func _felder_pruefen(alle := false, an := 0) -> void:
	var w := _w()
	if w == null or (_bereite.is_empty() and an == 0):
		return
	var neu := {}
	for f in FELDER:
		var v = w.get(f)
		var h := hash(v)
		if alle:
			neu[f] = v
		elif _feld_hash.get(f, 0) != h:
			_feld_hash[f] = h
			neu[f] = v
	if alle:
		neu["statistik"] = w.statistik
	elif _stat_zeit >= STATISTIK_TAKT:
		_stat_zeit = 0.0
		var hs := hash(w.statistik)
		if _feld_hash.get("statistik", 0) != hs:
			_feld_hash["statistik"] = hs
			neu["statistik"] = w.statistik
	var sd := {}
	for pid in w.spieler_daten:
		var e: Dictionary = w.spieler_daten[pid]
		var h := hash([e.aktiv, e.kosmetik_aktiv, e.fahrzeug, e.aktive_gondel, e.radio, (e.boosts as Dictionary).keys()])
		if alle:
			sd[pid] = e
		elif _sd_hash.get(pid, 0) != h:
			_sd_hash[pid] = h
			sd[pid] = e
	if not sd.is_empty():
		neu["spieler_daten"] = sd
	if neu.is_empty():
		return
	var b := var_to_bytes(neu)
	var ziele: Array = [an] if an != 0 else _bereite.keys()
	_spaeter(func(): _felder_senden(b, ziele))

func _felder_senden(b: PackedByteArray, ziele: Array) -> void:
	var gz := b.size() > STUECK
	if gz:
		b = b.compress(FileAccess.COMPRESSION_GZIP)
	for id in ziele:
		if not spieler.has(id):
			continue
		if b.size() <= STUECK:
			felder.rpc_id(id, b, gz)
		else:
			_gross_senden(id, "felder", b)   # Möbel, Album … können größer als ein Paket werden

@rpc("authority", "call_remote", "reliable")
func felder(b: PackedByteArray, gz: bool) -> void:
	_felder_anwenden(b, gz)

func _felder_anwenden(b: PackedByteArray, gz: bool) -> void:
	var w := _w()
	if not ist_gast() or not _bereit or w == null:
		return
	if gz:
		b = b.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var d = bytes_to_var(b)
	if not (d is Dictionary):
		return
	var menues := false
	var ausruestung := false
	for f in d:
		if f == "spieler_daten":
			for pid in d[f]:
				if str(pid) != w.ich:   # eigene Werte: nur aus Befehls-Antworten
					w.spieler_daten[str(pid)] = d[f][pid]
			continue
		w.set(f, d[f])
		if f == "geld":
			_kasse = int(d[f])
		elif f != "statistik":
			menues = true
		if f in FELDER_AUSRUESTUNG:
			ausruestung = true
	spiel.netz_aktualisiert(menues, ausruestung)

# Gast: Welt fertig geladen (Spiel.starten) → Gastgeber schickt den aktuellen Stand aller Felder
func gast_bereit() -> void:
	var w := _w()
	if not ist_gast() or w == null:
		return
	_bereit = true
	_kasse = w.geld
	_anwesend_setzen()
	_spaeter(func(): bereit.rpc_id(1))

@rpc("any_peer", "call_remote", "reliable")
func bereit() -> void:
	if not ist_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if spieler.has(id):
		_bereite[id] = true
		_anwesend_setzen()
		_felder_pruefen(true, id)

# Gastgeber: eigene Werte eines Gasts (Werkzeug in der Hand, Fahrzeug, Aussehen, Gondel, Radio) – Boosts bleiben beim Gastgeber
@rpc("any_peer", "call_remote", "reliable")
func meine_daten(q: Dictionary) -> void:
	var w := _w()
	if not ist_host() or w == null:
		return
	var id := multiplayer.get_remote_sender_id()
	if not spieler.has(id):
		return
	var pid := str(spieler[id].profil_id)
	var p := w.spieler_pruefen(q)
	var e: Dictionary = w.spieler_daten.get(pid, w.neue_spieler_daten())
	for k in EIGENE:
		e[k] = p[k]
	w.spieler_daten[pid] = e

# Profil-IDs der Spieler in der Runde (Boosts laufen nur bei ihnen ab, Helfer-Boosts von allen)
func _anwesend_setzen() -> void:
	var w := _w()
	if w == null:
		return
	var l := []
	if aktiv():
		for id in spieler:
			l.append(w.ich if id == meine_id() else str(spieler[id].profil_id))
	w.anwesend = l

func _netz_takt(dt: float) -> void:
	var w := _w()
	if w == null:
		return
	if ist_host():
		_feld_zeit += dt
		_stat_zeit += dt
		if _feld_zeit >= FELD_TAKT:
			_feld_zeit = 0.0
			_felder_pruefen()
	elif ist_gast() and _bereit:
		if w.geld != _kasse:
			w.geld = _kasse   # die Kasse liegt beim Gastgeber (eigener Lohn zählt erst mit 7c)
		_eigen_zeit += dt
		if _eigen_zeit >= FELD_TAKT:
			_eigen_zeit = 0.0
			var e: Dictionary = w.spieler_daten.get(w.ich, {})
			if not e.is_empty():
				var h := hash([e.aktiv, e.kosmetik_aktiv, e.fahrzeug, e.aktive_gondel, e.radio])
				if h != _eigen_hash:
					_eigen_hash = h
					var q := {}
					for k in EIGENE:
						q[k] = e[k]
					_spaeter(func(): meine_daten.rpc_id(1, q))

# Nur für Test 37 (NetzTest): Textnachrichten zwischen den Test-Prozessen
signal test_nachricht_da(id: int, text: String)
@rpc("any_peer", "call_remote", "reliable")
func test_nachricht(t: String) -> void:
	test_nachricht_da.emit(multiplayer.get_remote_sender_id(), t)

# Eigene LAN-Adressen (für „Spiel erstellen“ im Menü)
static func lan_adressen() -> Array:
	var r := []
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and int(a.get_slice(".", 1)) >= 16 and int(a.get_slice(".", 1)) <= 31):
			r.append(a)
	return r
