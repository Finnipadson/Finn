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
	stand["netz"] = {"spieler": spieler, "belegte_gondeln": _belegte_gondeln()}
	_gross_senden(id, "stand", var_to_bytes(stand).compress(FileAccess.COMPRESSION_GZIP))
	liste.rpc(spieler)
	spieler_geaendert.emit()
	spiel.hud.meldung("%s ist dem Spiel beigetreten." % spieler[id].name, 3.0)

func _rauswerfen_spaeter(id: int) -> void:
	await get_tree().create_timer(0.5).timeout
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)

func _belegte_gondeln() -> Array:
	var b := []
	if spiel and spiel.wirtschaft.aktive_gondel >= 0:
		b.append(spiel.wirtschaft.aktive_gondel)
	return b

@rpc("authority", "call_remote", "reliable")
func abgelehnt(grund: String) -> void:
	zurueck_ins_menue(grund)

@rpc("authority", "call_remote", "reliable")
func liste(l: Dictionary) -> void:
	spieler = {}
	for k in l:
		spieler[int(k)] = l[k]
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
