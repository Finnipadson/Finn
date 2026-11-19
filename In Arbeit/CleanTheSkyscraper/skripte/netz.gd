extends Node
# Mehrspieler (Phase 7a): Autoload „Netz“ – Verbindung, Spielerliste, Profil, Beitritt mit Voll-Zustand, Lage der Mitspieler,
# Tageszeit vom Gastgeber. Zwei Transporte, gleiche RPCs (der Spiel-Code merkt keinen Unterschied):
#   "enet" Heimnetz/IP und alte Tests (127.0.0.1) · "eos" Internet per 6-stelligem Code über Epic Online Services (7g,
#   skripte/netz_eos.gd, nur geladen, wenn EOSG + eos_zugang.cfg da sind). Bis zu 3 Spieler; der Gastgeber (Peer 1) hat den
#   echten Spielstand und speichert. Beenden mit EOS immer über Netz.beenden() (meldet ab, sonst hängt der Prozess).
# Große Daten gehen in Stücken à 1.000 Byte (EOS-Paketgrenze ~1.170 Byte, Vorab-Test 18.11.2026).
# Einzelspieler: modus "" → nichts davon läuft, das Spiel verhält sich wie vorher.
#
# Schalter: --host[=PORT]  sofort als Gastgeber starten · --join=ADRESSE[:PORT]  sofort beitreten
#           --profil=NAME  eigenes Profil (user://profil_NAME.json, für mehrere Instanzen auf einem PC)
#           --netz-verzoegerung=MS --netz-verlust=PROZENT  künstlich schlechtes Netz (nur Lage-Pakete werden verworfen)
#           --host-internet  sofort Internet-Spiel erstellen · --join-code=CODE  sofort per Internet-Code beitreten · --relay=erzwingen  EOS nur über Epic-Relay (Test)

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
var transport := ""              # "enet" | "eos" (solange verbunden)
var code := ""                   # Internet-Code des laufenden Spiels (Gastgeber und Gäste)
var eos: Node = null             # netz_eos.gd, null = Internet nicht möglich (Grund in eos_grund)
var eos_grund := ""
var _rtt := {}                   # EOS: peer_id -> Laufzeit hin+zurück in ms (eigene Messung)
var _ping_zeit := 0.0
var _beendet := false

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
	_eos_laden()
	multiplayer.peer_connected.connect(_peer_da)
	multiplayer.peer_disconnected.connect(_peer_weg)
	multiplayer.connected_to_server.connect(_verbunden)
	multiplayer.connection_failed.connect(_fehlgeschlagen)
	multiplayer.server_disconnected.connect(_server_weg)

func aktiv() -> bool:
	return modus == "host" or modus == "gast"

# Internet-Teil nur laden, wenn EOSG (gdextension + Autoloads) und die Zugangsdaten da sind – sonst bleibt das Spiel normal
func _eos_laden() -> void:
	if not ClassDB.class_exists("EOSGMultiplayerPeer") or get_node_or_null("/root/HAuth") == null or get_node_or_null("/root/EOSGRuntime") == null:
		eos_grund = "Internet-Spiel nicht verfügbar: das EOS-Paket (EOSG) fehlt in diesem Spiel."
		return
	var sk = load("res://skripte/netz_eos.gd")
	if sk == null:
		eos_grund = "Internet-Spiel nicht verfügbar (EOS-Teil ließ sich nicht laden)."
		return
	if not sk.zugang_ok():
		eos_grund = "Internet-Spiel nicht verfügbar: die Epic-Zugangsdaten (eos_zugang.cfg) fehlen."
		return
	eos = sk.new()
	eos.name = "Eos"
	add_child(eos)

func internet_moeglich() -> bool:
	return eos != null

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
	_host_fertig(p, "enet")
	return ""

func _host_fertig(p: MultiplayerPeer, t: String) -> void:
	multiplayer.multiplayer_peer = p
	modus = "host"
	transport = t
	spieler = {1: {"name": profil.name, "farbe": profil.farbe, "profil_id": profil.id}}
	_anwesend_setzen()
	spieler_geaendert.emit()

# Internet (EOS): Lobby mit Code anlegen. Gibt "" (Code in Netz.code) oder eine Fehlermeldung zurück.
func host_starten_internet() -> String:
	if eos == null:
		return eos_grund
	trennen()
	modus = "erstelle"
	status_geaendert.emit("Verbinde mit Epic Online Services …")
	var r: Dictionary = await eos.erstellen(profil.name, MAX_SPIELER + 1)   # ein Platz mehr: ein Vierter hört höflich „voll“
	if modus != "erstelle":   # inzwischen abgebrochen
		if r.has("peer"):
			(r.peer as MultiplayerPeer).close()
			eos.lobby_weg()
		return "Abgebrochen."
	modus = ""
	if r.has("fehler"):
		status_geaendert.emit(str(r.fehler))
		return str(r.fehler)
	code = str(r.code)
	_host_fertig(r.peer, "eos")
	return ""

# Internet (EOS): per Code beitreten. Fortschritt und Fehler kommen über status_geaendert.
func beitreten_code(roh: String) -> void:
	if eos == null:
		status_geaendert.emit(eos_grund)
		return
	var c: String = eos.code_pruefen(roh)
	if c == "":
		status_geaendert.emit("Der Code hat 6 Zeichen (Buchstaben und Ziffern, ohne O, I, 0 und 1).")
		return
	if modus == "" and spiel and is_instance_valid(spiel) and spiel.zustand:
		spiel._speichern()   # eigener Einzelspieler-Stand: vorher sichern (danach speichert nur der Gastgeber)
	trennen()
	modus = "suche"
	status_geaendert.emit("Verbinde mit Epic Online Services …")
	var zeigen := func(t: String) -> void:
		if modus == "suche":
			status_geaendert.emit(t)
	var r: Dictionary = await eos.beitreten(profil.name, c, zeigen)
	if modus != "suche":   # inzwischen abgebrochen
		if r.has("peer"):
			(r.peer as MultiplayerPeer).close()
			eos.lobby_weg()
		return
	if r.has("fehler"):
		modus = ""
		status_geaendert.emit(str(r.fehler))
		return
	code = c
	_adresse = "Code " + c
	transport = "eos"
	multiplayer.multiplayer_peer = r.peer
	modus = "verbinde"
	status_geaendert.emit("Spiel gefunden – verbinde mit dem Gastgeber …")
	# EOS meldet einen Fehlschlag nicht immer: nach 25 s ohne Verbindung aufgeben
	var t0 := Time.get_ticks_msec()
	while modus == "verbinde" and code == c and Time.get_ticks_msec() - t0 < 25000:
		await get_tree().process_frame
	if modus == "verbinde" and code == c:
		trennen()
		status_geaendert.emit("Keine Verbindung zum Gastgeber. Bitte nochmal versuchen – hilft das nicht, den Code neu erstellen lassen.")

# Menü: laufendes Erstellen/Suchen/Verbinden abbrechen
func abbrechen() -> void:
	if modus in ["erstelle", "suche", "verbinde"]:
		trennen()
		status_geaendert.emit("")

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
	transport = "enet"
	status_geaendert.emit("Verbinde mit %s …" % _adresse)

# Verbindung beenden (ohne Szenenwechsel). Gastgeber: alle Gäste fliegen raus und bekommen eine Meldung.
func trennen() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if eos:
		eos.lobby_weg()   # Gastgeber löst die Lobby auf (der Code gilt nicht mehr), Gast verlässt sie
	modus = ""
	transport = ""
	code = ""
	_rtt = {}
	_lage_letzte = {}
	spieler = {}
	_stuecke = {}
	_bereite = {}
	_bereit = false
	_warten = {}
	_feld_hash = {}
	_sd_hash = {}
	_eigen_hash = 0
	_reserviert = {}
	_offen = {}
	_moebel_sperre = {}
	_yacht_fahrer = 0
	if alle_pausiert:
		alle_pausiert = false
		if is_inside_tree():
			get_tree().paused = false
		if spiel and is_instance_valid(spiel) and spiel.miteinander:
			spiel.miteinander.pause_zeigen(false)
	if _w():
		spiel.spieler.mitschreiben = false
		spiel.spieler.stempel_neu = PackedFloat32Array()
		spiel.zustand.protokollieren = false
		spiel.zustand.protokoll = {}
		if spiel.helfer:
			spiel.helfer.weitere = []
		if spiel.ereignisse:
			spiel.ereignisse.weitere = []
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
	# Mit EOS fängt Netz das Fenster-X ab (auto_accept_quit aus): erst abmelden, dann beenden
	if what == NOTIFICATION_WM_CLOSE_REQUEST and eos and eos.plattform:
		beenden()

# Spiel beenden – immer hierüber (mit EOS: Lobby weg, abmelden, release() + shutdown(), sonst hängt der Prozess)
func beenden(rueckgabe := 0) -> void:
	if _beendet:
		return
	_beendet = true
	trennen()
	if eos and eos.plattform:
		await eos.herunterfahren()
	get_tree().quit(rueckgabe)

func _verbunden() -> void:
	_nicht_drosseln(1)
	status_geaendert.emit("Verbunden – lade die Welt des Gastgebers …")
	anmelden.rpc_id(1, profil.duplicate())

func _fehlgeschlagen() -> void:
	var war_eos := transport == "eos"
	trennen()
	status_geaendert.emit("Keine Verbindung zum Gastgeber. Bitte nochmal versuchen." if war_eos else "Verbindung fehlgeschlagen. Stimmt die Adresse? Läuft beim Gastgeber das Spiel?")

func _server_weg() -> void:
	var t := "Der Gastgeber hat das Spiel beendet."
	if modus == "verbinde":
		t = "Der Gastgeber hat die Verbindung abgelehnt."
	zurueck_ins_menue(t)

func _peer_da(id: int) -> void:
	_nicht_drosseln(id)   # Gast meldet sich gleich mit anmelden()

# ENet drosselt bei schwankender Laufzeit die „unzuverlässigen“ Pakete bis auf null – nach einem Beitritt (viel Verkehr durch die
# Welt-Übertragung) kam sekundenlang keine Lage eines Gasts an, seine Figur stand still (Test 37, 7h: 52 gesendet, 9 angekommen).
# Unsere Lage-Pakete sind klein (20 Hz, < 200 Byte) → Drosselung abschalten (Verlangsamung 0, Throttle bleibt voll).
func _nicht_drosseln(id: int) -> void:
	var p := multiplayer.multiplayer_peer
	if p is ENetMultiplayerPeer:
		var pp := (p as ENetMultiplayerPeer).get_peer(id)
		if pp:
			pp.throttle_configure(5000, 2, 0)   # Standard-Intervall 5 s, Beschleunigung 2, Verlangsamung 0

func _peer_weg(id: int) -> void:
	if not ist_host() or not spieler.has(id):
		return
	var n := name_von(id)
	if _yacht_fahrer == id:
		_yacht_fahrer = 0
	for i in _moebel_sperre.keys():
		if int(_moebel_sperre[i][0]) == id:
			_moebel_sperre.erase(i)
	spieler.erase(id)
	_bereite.erase(id)
	_rtt.erase(id)
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
	var gondel := _koop_gondel(id)
	var stand := spiel.stand_daten()
	stand["ort"] = orte.get(spieler[id].profil_id, {})
	_anwesend_setzen()
	stand["netz"] = {"spieler": spieler, "belegte_gondeln": _belegte_gondeln(id), "gondel": gondel}
	_gross_senden(id, "stand", var_to_bytes(stand).compress(FileAccess.COMPRESSION_GZIP))
	liste.rpc(spieler)
	spieler_geaendert.emit()
	spiel.hud.meldung("%s ist dem Spiel beigetreten." % spieler[id].name, 3.0)

# 7h: Gondel für den neuen Gast – entscheidet der Gastgeber und trägt sie sofort ein (sonst bekamen zwei kurz nacheinander
# beitretende Gäste dieselbe). Seine eigene vom letzten Mal, sonst die erste freie gekaufte; ist keine frei, stellt der Gastgeber
# kostenlos eine an einer freien Seite bereit (sonst könnten Freunde in einem frischen Spiel lange nicht mitputzen – gemessen mit
# dem Koop-Bot: 2.000 € bei ~7 €/min). -1 = keine (alle drei belegt).
func _koop_gondel(id: int) -> int:
	var w := _w()
	if w == null:
		return -1
	var belegt := _belegte_gondeln(id)
	var pid := str(spieler[id].profil_id)
	if not w.spieler_daten.has(pid):
		w.spieler_daten[pid] = w.neue_spieler_daten()
	var sd: Dictionary = w.spieler_daten[pid]
	var eigene := int(sd.get("aktive_gondel", -1))
	var reihe: Array = ([eigene] if eigene >= 0 and eigene < 3 else []) + [0, 1, 2]
	var wahl := -1
	for k in reihe:
		if w.gondeln[k].gekauft and not k in belegt:
			wahl = k
			break
	if wahl < 0:
		for k in reihe:
			if not w.gondeln[k].gekauft and not k in belegt:
				wahl = k
				w.gondeln[k].gekauft = true
				spiel.gondeln.aktualisieren(w.aktive_gondel)
				spiel.hud.meldung("Gondel %s für %s bereitgestellt (im Koop kostenlos)." % [Turm.SEITEN_NAMEN[k], spieler[id].name], 4.0)
				break
	if wahl >= 0:
		sd["aktive_gondel"] = wahl
	return wahl

func _rauswerfen_spaeter(id: int) -> void:
	await get_tree().create_timer(0.5).timeout
	var p := multiplayer.multiplayer_peer
	if p and not (p is OfflineMultiplayerPeer) and id in multiplayer.get_peers():
		p.disconnect_peer(id)

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
	elif art == "sauber" and _bereit and _w():
		spiel.zustand.abgleichen(alles.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP))

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
	if aktiv() and transport == "eos":
		_ping_takt(dt)
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
			_lage_senden(l)
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
		_lage_senden(l)

# EOS kennt kein „unreliable ordered“ (EOSG stellt dann auf reliable um): dort „unreliable“ mit Laufnummer, ältere verwerfen
var _lage_nr := 0
var _lage_letzte := {}           # Absender (bzw. "h" Helfer) -> letzte Laufnummer
var lage_zaehler := {"gesendet": 0}   # Test: gesendete Lage-Pakete und empfangene je Absender
func _lage_senden(l: Array) -> void:
	lage_zaehler["gesendet"] = int(lage_zaehler["gesendet"]) + 1
	if transport == "eos":
		_lage_nr += 1
		lage_eos.rpc(_lage_nr, l)
	else:
		lage.rpc(l)

func _neuer(k, nr: int) -> bool:
	if nr <= int(_lage_letzte.get(k, 0)):
		return false
	_lage_letzte[k] = nr
	return true

@rpc("any_peer", "call_remote", "unreliable")
func lage_eos(nr: int, l: Array) -> void:
	if _neuer(multiplayer.get_remote_sender_id(), nr):
		lage(l)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func lage(l: Array) -> void:
	if verlust > 0.0 and randf() < verlust:
		return
	var id := multiplayer.get_remote_sender_id()
	lage_zaehler[id] = int(lage_zaehler.get(id, 0)) + 1
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
	"tuerme_fertig", "abspann", "koop_max", "fenster_je"]
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
		return {"ok": false, "wartet": true, "nr": nr}
	var w := _w()
	if w == null:
		return {"ok": false}
	var e := _ausfuehren(name, d, w.ich, meine_id())
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
func _ausfuehren(name: String, d: Dictionary, pid: String, peer := 1) -> Dictionary:
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
		# ---- 7e: Casino, Arcade, Angeln, Penthouse, Yacht (nur Gäste schicken zahlen/…_gewinn/fang; Einzelspieler und
		# Gastgeber rechnen in zahlen()/casino_gewinn()/arcade_gewinn()/fang() direkt)
		"zahlen":
			var b := int(d.get("betrag", 0))
			var art := str(d.get("art", ""))
			if art == "casino" and b > CasinoRegeln.max_einsatz(w.geld):
				e["grund"] = "Einsatz zu hoch – höchstens %s € (10 %% der gemeinsamen Kasse)." % Hud.punkte(CasinoRegeln.max_einsatz(w.geld))
			elif b > 0 and w.geld >= b and art in ["casino", "arcade"]:
				w.geld -= b
				if art == "arcade":
					w.statistik.arcade_spiele = int(w.statistik.arcade_spiele) + 1
				_offen[pid + "|" + art] = b
				e["ok"] = true
		"casino_gewinn":
			var einsatz := int(d.get("einsatz", 0))
			var aus := int(d.get("aus", 0))
			if int(_offen.get(pid + "|casino", -1)) == einsatz and aus >= 0 and aus <= einsatz * 100:
				_offen.erase(pid + "|casino")
				w.geld += aus
				w.casino_runde(einsatz, aus)
				e["ok"] = true
				if aus - einsatz >= GROSSER_GEWINN:
					_an_alle("%s hat im Casino %s € gewonnen!" % [name_von(peer), Hud.punkte(aus - einsatz)], peer)
			else:
				e["grund"] = "Dieser Gewinn passt nicht zu deinem Einsatz."
		"arcade_gewinn":
			if _offen.has(pid + "|arcade") and str(w.gegenstand(id).get("quelle", "")) == "arcade":
				_offen.erase(pid + "|arcade")
				w.bekomme_gegenstand(id)
				w.statistik.arcade_gewinne = int(w.statistik.arcade_gewinne) + 1
				e["ok"] = true
				if w.seltenheit(id) >= 2:
					_an_alle("%s hat in der Arcade gewonnen: %s!" % [name_von(peer), w.gegenstand(id).name], peer)
			else:
				e["grund"] = ""
		"fang":
			if not Wirtschaft.fisch(id).is_empty():
				if w.fisch_gefangen(id, float(d.get("laenge", 0.0)), name_von(peer)):
					_an_alle("%s hat gefangen: %s – neu im Fisch-Index!" % [name_von(peer), Wirtschaft.fisch(id).name], peer)
				e["ok"] = true
		"moebel_sperren", "moebel_setzen", "moebel_frei", "moebel_lager", "moebel_verkaufen":
			_moebel_befehl(name, d, peer, e)
		"yacht":
			if str(d.get("rolle", "")) == "aus":
				if _yacht_fahrer == peer:
					_yacht_fahrer = 0
				e["ok"] = true
			elif _yacht_fahrer == 0 or _yacht_fahrer == peer or not spieler.has(_yacht_fahrer):
				_yacht_fahrer = peer
				e["rolle"] = "fahren"
				e["ok"] = true
			elif spiel.strand.yacht.am_liegeplatz():
				e["rolle"] = "mit"
				e["fahrer"] = name_von(_yacht_fahrer)
				e["ok"] = true
			else:
				e["grund"] = "Die Yacht ist gerade mit %s unterwegs – warte am Steg, dann kannst du zusteigen." % name_von(_yacht_fahrer)
		"hoehe":   # neue Höhe erreicht: einmaliger Bonus (wer zuerst kommt)
			var a := int(d.get("abschnitt", 0))
			if a > w.hoechster_abschnitt:
				w.hoechster_abschnitt = a
				var bonus := 25 * w.lohn(int(d.get("stock", 0)))
				w.geld += bonus
				e["bonus"] = bonus
				e["ok"] = true
			else:
				e["grund"] = ""
		"gondel_nehmen":   # 7c: eine Gondel, in der ein anderer sitzt, ist gesperrt
			var k := int(d.get("seite", -1))
			var fahrer := _gondel_fahrer(k, pid)
			if k < 0 or k > 2 or not w.gondeln[k].gekauft:
				e["grund"] = "Diese Gondel ist noch nicht gekauft."
			elif fahrer != "":
				e["grund"] = "Gondel %s fährt gerade %s." % [Turm.SEITEN_NAMEN[k], fahrer]
			else:
				e["ok"] = true
				_reserviert[k] = [pid, Time.get_ticks_msec() + 4000]   # bis die eigene Meldung des Gasts da ist
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
	var e := _ausfuehren(name, d, pid, id)
	var eigen := {}
	var nach: Dictionary = w.spieler_daten[pid]
	for k in nach:
		if hash(nach[k]) != hash(vorher.get(k)):
			eigen[k] = nach[k]
	if e.ok and not name in ["zahlen", "casino_gewinn", "fang", "moebel_sperren", "moebel_frei", "yacht", "hoehe"]:
		spiel._ausruestung()            # Helfer, Gondeln, Seil-Grenze; speichert
		spiel.menues_aktualisieren()
		if name.begins_with("moebel_") or name == "arcade_gewinn":
			spiel.extras.penthouse.aktualisieren()   # Möbel des Gasts im Penthouse des Gastgebers
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
		if not e.get("ok", false) and str(e.get("grund", "")) != "":
			spiel.hud.meldung(str(e.grund), 3.0)
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

# Wer sitzt in Gondel k (Name, "" = frei)? Zählt alle Spieler in der Runde außer pid, dazu frische Zusagen.
var _reserviert := {}            # Gastgeber: Seite -> [profil_id, bis (ms)]
func _gondel_fahrer(k: int, pid: String) -> String:
	var w := _w()
	if w == null or not aktiv():
		return ""
	for id in spieler:
		var p: String = w.ich if id == meine_id() else str(spieler[id].profil_id)
		if p != pid and int((w.spieler_daten.get(p, {}) as Dictionary).get("aktive_gondel", -1)) == k:
			return name_von(id)
	var r: Array = _reserviert.get(k, [])
	if not r.is_empty() and str(r[0]) != pid and Time.get_ticks_msec() < int(r[1]):
		for id in spieler:
			if str(spieler[id].profil_id) == str(r[0]) or (id == meine_id() and w.ich == str(r[0])):
				return name_von(id)
	return ""

# ---------------------------------------------------------------- Gemeinsam putzen (Phase 7c)
# Jeder wischt sofort bei sich (Spieler sammelt die Stempel in stempel_neu), die Stempel gehen jedes Bild an die anderen
# (Gast → Gastgeber → übrige Gäste) und werden dort nur gezeigt (wische mit fertig_erlaubt = false). Ob ein Fenster fertig
# ist, entscheidet nur der Gastgeber: ein Gast meldet „fertig“ (fertig_wunsch), der Gastgeber zahlt mit den Boosts des
# Putzers und schickt „fertig“ an alle (zählt einmal, auch wenn zwei dasselbe Fenster wischen). Dreck-Änderungen der
# Helfer/Tauben/Sandsturm sammelt FensterZustand.protokoll, der Gastgeber schickt sie 5× pro Sekunde.
const STEMPEL_JE_PAKET := 36     # 6 Werte × 4 Byte × 36 = 864 Byte (EOS-Paketgrenze)
const DRECK_JE_PAKET := 56

func _stempel_takt() -> void:
	var sp: Spieler = spiel.spieler
	sp.mitschreiben = true
	if sp.stempel_neu.is_empty():
		return
	var alle := sp.stempel_neu
	sp.stempel_neu = PackedFloat32Array()
	var n := STEMPEL_JE_PAKET * 6
	var i := 0
	while i < alle.size():
		var teil := alle.slice(i, mini(i + n, alle.size()))
		i += n
		if ist_host():
			for g in _bereite:
				_spaeter(func(): stempel.rpc_id(g, 1, teil))
		else:
			_spaeter(func(): stempel.rpc_id(1, 0, teil))

# Stempel empfangen. Gastgeber: von einem Gast → zeigen + an die übrigen Gäste weiter; Gast: von (von) → zeigen
@rpc("any_peer", "call_remote", "reliable")
func stempel(von: int, s: PackedFloat32Array) -> void:
	if spiel == null or not is_instance_valid(spiel) or spiel.zustand == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if ist_host():
		if not _bereite.has(sender):
			return
		for g in _bereite:
			if g != sender:
				_spaeter(func(): stempel.rpc_id(g, sender, s))
	elif not _bereit or sender != 1:
		return
	var z := spiel.zustand
	for j in range(0, s.size() - 5, 6):
		z.wische(int(s[j]), int(s[j + 1]), s[j + 2], s[j + 3], s[j + 4], s[j + 5], false)

func fertig_melden(f: int, spalte: int) -> void:
	_spaeter(func(): fertig_wunsch.rpc_id(1, f, spalte))

@rpc("any_peer", "call_remote", "reliable")
func fertig_wunsch(f: int, spalte: int) -> void:
	var w := _w()
	if not ist_host() or w == null:
		return
	var id := multiplayer.get_remote_sender_id()
	if not spieler.has(id) or f < 0 or f >= Turm.STOCKWERKE:
		return
	if not spiel.zustand.sauber_machen(f, spalte):
		return   # schon sauber (jemand war schneller) – zählt nur einmal
	var r := spiel.fenster_bezahlen(f, spalte, str(spieler[id].profil_id))
	spiel.netz_fertig(f, spalte, id, r)
	fertig_senden(f, spalte, id, r)

# Gastgeber: Fenster fertig an alle Gäste (wer = Peer des Putzers, 0 = Helfer)
func fertig_senden(f: int, spalte: int, wer: int, r: Dictionary) -> void:
	if not ist_host():
		return
	for g in _bereite:
		_spaeter(func(): fertig.rpc_id(g, f, spalte, wer, r))

@rpc("authority", "call_remote", "reliable")
func fertig(f: int, spalte: int, wer: int, r: Dictionary) -> void:
	if _bereit and _w():
		spiel.netz_fertig(f, spalte, wer, r)

func _dreck_takt() -> void:
	var z := spiel.zustand
	z.protokollieren = not _bereite.is_empty()
	if z.protokoll.is_empty():
		return
	var d := PackedFloat32Array()
	for id in z.protokoll:
		d.append_array(PackedFloat32Array(z.protokoll[id]))
	z.protokoll = {}
	var n := DRECK_JE_PAKET * 4
	var i := 0
	while i < d.size():
		var teil := d.slice(i, mini(i + n, d.size()))
		i += n
		for g in _bereite:
			_spaeter(func(): dreck.rpc_id(g, teil))

@rpc("authority", "call_remote", "reliable")
func dreck(d: PackedFloat32Array) -> void:
	if not _bereit or _w() == null:
		return
	var z := spiel.zustand
	for j in range(0, d.size() - 3, 4):
		var f := int(d[j])
		var s := int(d[j + 1])
		if int(d[j + 3]) == 1 and z.verschmutzen(f, s, d[j + 2]):
			continue
		z.dreck_setzen(f, s, d[j + 2])

# ---------------------------------------------------------------- Welt vom Gastgeber (Phase 7d)
# Helfer laufen nur beim Gastgeber (lassen die Gondeln aller Spieler aus), Lage 10× pro Sekunde an die Gäste.
# Tauben/Böen/Sandsturm würfelt der Gastgeber (Ereignisse.ereignis → ereignis_rpc), Tauben fliegen auch zu den Gondeln
# der Gäste (außer sie haben Zitronenlimo). Abspann bei 100 % startet der Gastgeber für alle.
const HELFER_HZ := 10.0
var _helfer_zeit := 0.0

func _welt_takt(dt: float) -> void:
	var orte: Array = spiel.mitspieler.gondel_orte() if spiel.mitspieler else []
	spiel.helfer.weitere = orte
	var w := spiel.wirtschaft
	var tw := []
	for o in orte:
		var o2: Dictionary = (o as Dictionary).duplicate()
		o2["limo"] = w.boost_wirkung("tauben", str(o.pid)) > 0.0
		tw.append(o2)
	spiel.ereignisse.weitere = tw
	_helfer_zeit += dt
	if _helfer_zeit >= 1.0 / HELFER_HZ and not _bereite.is_empty() and spiel.helfer.anzahl() > 0:
		_helfer_zeit = 0.0
		var d := spiel.helfer.lage_daten()
		_lage_nr += 1
		var nr := _lage_nr
		for g in _bereite:
			if transport == "eos":
				_spaeter(func(): helfer_lage_eos.rpc_id(g, nr, d))
			else:
				_spaeter(func(): helfer_lage.rpc_id(g, d))

@rpc("authority", "call_remote", "unreliable")
func helfer_lage_eos(nr: int, d: PackedFloat32Array) -> void:
	if _neuer("h", nr):
		helfer_lage(d)

@rpc("authority", "call_remote", "unreliable_ordered")
func helfer_lage(d: PackedFloat32Array) -> void:
	if verlust > 0.0 and randf() < verlust:
		return
	if _bereit and _w() and spiel.helfer:
		spiel.helfer.lage_setzen(d)

func ereignis_senden(art: String, d: Dictionary) -> void:
	if not ist_host():
		return
	for g in _bereite:
		_spaeter(func(): ereignis_rpc.rpc_id(g, art, d))

@rpc("authority", "call_remote", "reliable")
func ereignis_rpc(art: String, d: Dictionary) -> void:
	if _bereit and _w() and spiel.ereignisse:
		spiel.ereignisse.netz_ereignis(art, d)

func abspann_senden() -> void:
	if not ist_host():
		return
	for g in _bereite:
		_spaeter(func(): abspann_rpc.rpc_id(g))

@rpc("authority", "call_remote", "reliable")
func abspann_rpc() -> void:
	if _bereit and _w() and (spiel.abspann == null or not is_instance_valid(spiel.abspann)):
		spiel.abspann_starten()

# ---------------------------------------------------------------- Extras im Koop (Phase 7e)
# Casino/Arcade: Einsatz und Gewinn über die gemeinsame Kasse. Der Gast rechnet sofort bei sich (Kasse vorab angepasst) und
# schickt zahlen + casino_gewinn/arcade_gewinn; der Gastgeber prüft Grenze/Geld und dass der Gewinn zu einer bezahlten Runde
# passt (_offen). Fang = gemeinsame Fischkiste + Index (größte Länge mit Namen). Penthouse: Umstellen sperrt das Stück beim
# Gastgeber (_moebel_sperre), Abstellen/Lager/Verkaufen sind Befehle. Yacht: wer zuerst einsteigt, steuert (_yacht_fahrer);
# am Liegeplatz steigen andere zu (Mitfahrer: Yacht folgt der Lage des Fahrers).
const GROSSER_GEWINN := 1000
var _offen := {}                 # Gastgeber: "profil|art" -> bezahlter Betrag
var _moebel_sperre := {}         # Gastgeber: Index -> [peer, id]
var _yacht_fahrer := 0           # Gastgeber: Peer am Steuer (0 = keiner)

# Einsatz/Spielpreis abziehen. false = zu wenig Geld
func zahlen(betrag: int, art: String) -> bool:
	var w := _w()
	if w == null or betrag <= 0 or w.geld < betrag:
		return false
	w.geld -= betrag
	if art == "arcade":
		w.statistik.arcade_spiele = int(w.statistik.arcade_spiele) + 1
	if ist_gast():
		_kasse -= betrag
		befehl("zahlen", {"betrag": betrag, "art": art})
	return true

func casino_gewinn(einsatz: int, aus: int) -> void:
	var w := _w()
	if w == null:
		return
	w.geld += aus
	w.casino_runde(einsatz, aus)
	if ist_gast():
		_kasse += aus
		befehl("casino_gewinn", {"einsatz": einsatz, "aus": aus})
	elif ist_host() and aus - einsatz >= GROSSER_GEWINN:
		_an_alle("%s hat im Casino %s € gewonnen!" % [profil.name, Hud.punkte(aus - einsatz)], 1)

func arcade_gewinn(id: String) -> void:
	var w := _w()
	if w == null:
		return
	w.bekomme_gegenstand(id)
	w.statistik.arcade_gewinne = int(w.statistik.arcade_gewinne) + 1
	if ist_gast():
		befehl("arcade_gewinn", {"id": id})
	elif ist_host() and w.seltenheit(id) >= 2:
		_an_alle("%s hat in der Arcade gewonnen: %s!" % [profil.name, w.gegenstand(id).name], 1)

# Fisch gefangen: true = neue Art (beim Gast vorab lokal, der Gastgeber trägt ihn in die gemeinsame Kiste ein)
func fang(id: String, laenge: float) -> bool:
	var w := _w()
	if w == null:
		return false
	var neu := w.fisch_gefangen(id, laenge, profil.name if aktiv() else "")
	if ist_gast():
		befehl("fang", {"id": id, "laenge": laenge})
	elif ist_host() and neu:
		_an_alle("%s hat gefangen: %s – neu im Fisch-Index!" % [profil.name, Wirtschaft.fisch(id).name], 1)
	return neu

# Meldung bei allen außer wer (Gastgeber zeigt sie selbst, wenn nicht er es war)
func _an_alle(t: String, wer: int) -> void:
	if not ist_host():
		return
	if wer != 1 and spiel and spiel.hud:
		spiel.hud.meldung(t, 3.5)
	for g in _bereite:
		if g != wer:
			hinweis.rpc_id(g, t)

# Gastgeber: Erfolge usw. auch bei den Gästen melden
func an_alle(t: String) -> void:
	if ist_host():
		for g in _bereite:
			hinweis.rpc_id(g, t)

func _moebel_befehl(name: String, d: Dictionary, peer: int, e: Dictionary) -> void:
	var w := _w()
	var i := int(d.get("i", -1))
	if i < 0 or i >= w.moebel.size() or str(w.moebel[i].id) != str(d.get("id", "")):
		e["grund"] = "Das Möbelstück gibt es so nicht mehr."
		return
	var sp: Array = _moebel_sperre.get(i, [])
	var fremd := not sp.is_empty() and int(sp[0]) != peer and spieler.has(int(sp[0]))
	var m: Dictionary = w.moebel[i]
	match name:
		"moebel_sperren":
			if fremd:
				e["grund"] = "%s stellt das gerade um." % name_von(int(sp[0]))
				return
			_moebel_sperre[i] = [peer, m.id]
		"moebel_setzen":
			if fremd:
				e["grund"] = "%s stellt das gerade um." % name_von(int(sp[0]))
				return
			m.x = float(d.get("x", m.x))
			m.z = float(d.get("z", m.z))
			m.dreh = float(d.get("dreh", m.dreh))
			m.steht = true
			_moebel_sperre.erase(i)
		"moebel_frei":
			if not fremd:
				_moebel_sperre.erase(i)
		"moebel_lager":
			if fremd:
				e["grund"] = "%s stellt das gerade um." % name_von(int(sp[0]))
				return
			m.steht = false
			_moebel_sperre.erase(i)
		"moebel_verkaufen":
			if not _moebel_sperre.is_empty() and not (_moebel_sperre.size() == 1 and not fremd and _moebel_sperre.has(i)):
				e["grund"] = "Gerade stellt jemand etwas um – gleich nochmal versuchen."
				return
			if m.steht:
				e["grund"] = "Erst ins Lager räumen, dann verkaufen."
				return
			w.geld += w.verkaufswert(m.id)
			w.moebel.remove_at(i)
			_moebel_sperre.erase(i)
	e["ok"] = true

# ---------------------------------------------------------------- Miteinander (Phase 7f): Chat, Emotes, Pings, Pause, Rauswerfen
var alle_pausiert := false

# art = chat / emote / ping. Über den Gastgeber an alle (auch zurück an den Absender: gleiche Reihenfolge überall)
func sozial_senden(art: String, d: Dictionary) -> void:
	if ist_host():
		_sozial_verteilen(1, art, d)
	elif ist_gast() and _bereit:
		_spaeter(func(): sozial_wunsch.rpc_id(1, art, d))

@rpc("any_peer", "call_remote", "reliable")
func sozial_wunsch(art: String, d: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if ist_host() and _bereite.has(id) and art in ["chat", "emote", "ping"]:
		if art == "chat":
			d = {"t": str(d.get("t", "")).left(120)}
		_sozial_verteilen(id, art, d)

func _sozial_verteilen(id: int, art: String, d: Dictionary) -> void:
	if spiel and is_instance_valid(spiel) and spiel.miteinander:
		spiel.miteinander.empfangen(id, art, d)
	for g in _bereite:
		_spaeter(func(): sozial.rpc_id(g, id, art, d))

@rpc("authority", "call_remote", "reliable")
func sozial(id: int, art: String, d: Dictionary) -> void:
	if _bereit and _w() and spiel.miteinander:
		spiel.miteinander.empfangen(id, art, d)

# Gastgeber: Spiel für alle anhalten / weiter
func alle_pausieren(an: bool) -> void:
	if not ist_host():
		return
	_pause_setzen(an)
	for g in _bereite:
		_spaeter(func(): pause_rpc.rpc_id(g, an))

@rpc("authority", "call_remote", "reliable")
func pause_rpc(an: bool) -> void:
	if _bereit:
		_pause_setzen(an)

func _pause_setzen(an: bool) -> void:
	alle_pausiert = an
	get_tree().paused = an
	if spiel and is_instance_valid(spiel) and spiel.miteinander:
		spiel.miteinander.pause_zeigen(an)

# Gastgeber: einen Gast aus der Runde nehmen
func rauswerfen(id: int) -> void:
	if not ist_host() or id == 1 or not spieler.has(id):
		return
	abgelehnt.rpc_id(id, "Der Gastgeber hat dich aus dem Spiel genommen.")
	_rauswerfen_spaeter(id)

# Laufzeit hin und zurück in ms (-1 = unbekannt). Gastgeber: zu jedem Gast, Gast: zum Gastgeber
func ping_ms(id: int) -> int:
	var p := multiplayer.multiplayer_peer
	if id == meine_id() or not aktiv():
		return -1
	if transport == "eos":
		return int(_rtt.get(id, -1))
	if not (p is ENetMultiplayerPeer):
		return -1
	var pp := (p as ENetMultiplayerPeer).get_peer(id)
	if pp == null:
		return -1
	return int(pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))

# Gast: Welt fertig geladen (Spiel.starten) → Gastgeber schickt den aktuellen Stand aller Felder
func gast_bereit() -> void:
	var w := _w()
	if not ist_gast() or w == null:
		return
	_bereit = true
	if spiel.helfer:   # Helfer laufen nur beim Gastgeber, hier nur die Modelle an seinen Positionen (7d)
		spiel.helfer.aktiv = false
		spiel.helfer.gast = true
	if spiel.ereignisse:   # Tauben, Böen, Sandsturm kommen vom Gastgeber (7d)
		spiel.ereignisse.gast = true
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
		# saubere Fenster noch einmal (was während des Ladens fertig wurde, hat der Gast verpasst)
		_gross_senden(id, "sauber", spiel.zustand.sauber.compress(FileAccess.COMPRESSION_GZIP))
		var e := spiel.ereignisse   # laufende Böe / Sandsturm gleich mitteilen
		_spaeter(func(): ereignis_rpc.rpc_id(id, "wind", {"ziel": e.wind_ziel}))
		_spaeter(func(): ereignis_rpc.rpc_id(id, "sturm", {"phase": e.sturm_phase}))
		if alle_pausiert:
			_spaeter(func(): pause_rpc.rpc_id(id, true))

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
	if ist_host() or (ist_gast() and _bereit):
		_stempel_takt()
	if ist_host():
		_welt_takt(dt)
		_feld_zeit += dt
		_stat_zeit += dt
		if _feld_zeit >= FELD_TAKT:
			_feld_zeit = 0.0
			_felder_pruefen()
			_dreck_takt()
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

# EOS hat keine Laufzeit-Statistik wie ENet: alle 2 s selbst messen (Gastgeber ↔ jeder Gast)
func _ping_takt(dt: float) -> void:
	_ping_zeit += dt
	if _ping_zeit < 2.0:
		return
	_ping_zeit = 0.0
	for id in multiplayer.get_peers():
		netz_ping.rpc_id(id, Time.get_ticks_msec())

@rpc("any_peer", "call_remote", "unreliable")
func netz_ping(t: int) -> void:
	netz_pong.rpc_id(multiplayer.get_remote_sender_id(), t)

@rpc("any_peer", "call_remote", "unreliable")
func netz_pong(t: int) -> void:
	_rtt[multiplayer.get_remote_sender_id()] = Time.get_ticks_msec() - t

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
