extends Node
# Mehrspieler übers Internet (Phase 7g): Epic Online Services über EOSG 2.3.1. Wird von Netz nur geladen, wenn das
# EOSG-Paket (addons/, gdextension) und die Zugangsdaten (eos_zugang.cfg) da sind – sonst läuft das Spiel ohne Internet-Option.
# Kein class_name: das Skript nennt EOSG-Klassen (EOSGMultiplayerPeer, HLobby …), die ohne Paket nicht existieren.
#
# Ablauf (wie im Verbindungstest Grafiktest/godot-eos-test/verbindung.gd):
#   anmelden()      EOS-Platform einmal starten, anonym per Geräte-ID anmelden (kein Epic-Konto nötig)
#   erstellen()     Lobby mit 6-stelligem Code als Attribut, EOSGMultiplayerPeer als Server → {peer, code} oder {fehler}
#   beitreten(code) Lobby per Code suchen (wiederholt, der Code ist erst nach ~2 s durchsuchbar), beitreten, Client
#   lobby_weg()     Lobby verlassen (Gast) bzw. auflösen (Gastgeber), läuft im Hintergrund
#   herunterfahren() vor dem Beenden: Lobby weg, abmelden, Referenzen frei, release() + shutdown() (sonst hängt der Prozess)

const SOCKET := "skyscraper"
const BUCKET := "skyscraper:koop1"
const ZEICHEN := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   # ohne I, O, 0, 1 (leicht zu verwechseln)
const SUCH_VERSUCHE := 7
const FRIST := 25.0                                    # Sekunden je Netz-Schritt

var plattform := false     # EOS-Platform läuft (dann vor dem Beenden herunterfahren)
var angemeldet := false
var lobby = null           # HLobby
var relay := "erlauben"    # Test-Schalter --relay=erzwingen
var _offen := 0            # Lobby-Aufräumen läuft noch
var _anmelden_laeuft := false

func _ready() -> void:
	HLog.log_level = HLog.LogLevel.WARN
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--relay="):
			relay = a.substr(8)
	# Ohne Tick laufen EOS-Rückrufe und P2P nicht – auch nicht, während das Spiel pausiert ist
	var rt := get_node_or_null("/root/EOSGRuntime")
	if rt:
		rt.process_mode = Node.PROCESS_MODE_ALWAYS
	for n in ["HPlatform", "HAuth", "HLobbies", "HP2P"]:
		var k := get_node_or_null("/root/" + n)
		if k:
			k.process_mode = Node.PROCESS_MODE_ALWAYS

static func zugang_pfad() -> String:
	var neben := OS.get_executable_path().get_base_dir().path_join("eos_zugang.cfg")
	if not OS.has_feature("editor") and FileAccess.file_exists(neben):
		return neben
	return "res://eos_zugang.cfg"

static func zugang_ok() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(zugang_pfad()) != OK:
		return false
	for k in ["product_id", "sandbox_id", "deployment_id", "client_id", "client_secret"]:
		if str(cfg.get_value("epic", k, "")).strip_edges() == "":
			return false
	return true

static func code_pruefen(roh: String) -> String:
	var c := roh.strip_edges().to_upper().replace(" ", "").replace("-", "")
	if c.length() != 6:
		return ""
	for z in c:
		if not z in ZEICHEN:
			return ""
	return c

# Eine async-Funktion mit Zeitlimit: {fertig, wert}
func _mit_frist(f: Callable, sek := FRIST) -> Dictionary:
	var st := {"fertig": false, "wert": null}
	var lauf := func():
		st["wert"] = await f.call()
		st["fertig"] = true
	lauf.call()
	var t0 := Time.get_ticks_msec()
	while not st.fertig and Time.get_ticks_msec() - t0 < sek * 1000.0:
		await get_tree().process_frame
	return st

func anmelden(anzeige: String) -> String:
	while _anmelden_laeuft:
		await get_tree().process_frame
	if angemeldet:
		return ""
	_anmelden_laeuft = true
	var f := await _anmelden(anzeige)
	_anmelden_laeuft = false
	return f

func _anmelden(anzeige: String) -> String:
	if not plattform:
		var cfg := ConfigFile.new()
		if cfg.load(zugang_pfad()) != OK:
			return "Die Epic-Zugangsdaten (eos_zugang.cfg) fehlen."
		var c := HCredentials.new()
		c.product_name = "CleanTheSkyscraper"
		c.product_version = "1.0"
		for k in ["product_id", "sandbox_id", "deployment_id", "client_id", "client_secret"]:
			c.set(k, str(cfg.get_value("epic", k, "")).strip_edges())
		var st := await _mit_frist(HPlatform.setup_eos_async.bind(c), 15.0)
		if not st.fertig or not st.wert:
			return "Epic Online Services konnte nicht starten."
		plattform = true
		get_tree().auto_accept_quit = false   # Fenster-X: erst sauber abmelden (Netz._notification → beenden)
		HP2P.set_relay_control(EOS.P2P.RelayControl.ForceRelays if relay == "erzwingen" else EOS.P2P.RelayControl.AllowRelays)
	var name := anzeige.strip_edges()
	if name == "":
		name = "Putzprofi"
	var st2 := await _mit_frist(HAuth.login_anonymous_async.bind(name))
	if not st2.fertig or not st2.wert or HAuth.product_user_id == "":
		return "Keine Verbindung zu Epic. Bist du mit dem Internet verbunden?"
	angemeldet = true
	return ""

func neuer_code() -> String:
	var c := ""
	for i in 6:
		c += ZEICHEN[randi() % ZEICHEN.length()]
	return c

# Gastgeber: Lobby + Server. max = Plätze in der Lobby (einer mehr als Spieler, damit ein Vierter höflich „voll“ hört)
func erstellen(anzeige: String, max_plaetze: int) -> Dictionary:
	var f := await anmelden(anzeige)
	if f != "":
		return {"fehler": f}
	lobby_weg()
	var opts := EOS.Lobby.CreateLobbyOptions.new()
	opts.bucket_id = BUCKET
	opts.max_lobby_members = max_plaetze
	opts.presence_enabled = false
	opts.enable_join_by_id = false
	var st := await _mit_frist(HLobbies.create_lobby_async.bind(opts))
	if not st.fertig or st.wert == null:
		return {"fehler": "Das Spiel konnte bei Epic nicht angelegt werden. Bitte gleich nochmal versuchen."}
	lobby = st.wert
	var code := neuer_code()
	lobby.add_attribute("code", code)
	var st2 := await _mit_frist(lobby.update_async)
	if not st2.fertig or not st2.wert:
		lobby_weg()
		return {"fehler": "Der Code konnte nicht gespeichert werden. Bitte gleich nochmal versuchen."}
	var peer := EOSGMultiplayerPeer.new()
	var e := peer.create_server(SOCKET)
	if e != OK:
		lobby_weg()
		return {"fehler": "Spiel konnte nicht gestartet werden (%s)." % error_string(e)}
	return {"peer": peer, "code": code}

# Gast: Lobby per Code suchen und beitreten, Client zum Besitzer der Lobby. status(text) zeigt den Fortschritt.
func beitreten(anzeige: String, code: String, status: Callable) -> Dictionary:
	var f := await anmelden(anzeige)
	if f != "":
		return {"fehler": f}
	lobby_weg()
	var gefunden = null
	for v in SUCH_VERSUCHE:
		if v > 0:
			status.call("Suche das Spiel mit dem Code %s … (Versuch %d)" % [code, v + 1])
			await get_tree().create_timer(2.0).timeout
		var st := await _mit_frist(HLobbies.search_by_attribute_async.bind({"key": "code", "value": code}), 15.0)
		if st.fertig and st.wert is Array and (st.wert as Array).size() > 0:
			gefunden = st.wert[0]
			break
	if gefunden == null:
		return {"fehler": "Kein Spiel mit dem Code %s gefunden. Stimmt der Code? Läuft das Spiel beim Gastgeber noch?" % code}
	if int(gefunden.available_slots) <= 0:
		return {"fehler": "Das Spiel ist voll (höchstens 3 Spieler)."}
	status.call("Spiel gefunden – trete bei …")
	var st2 := await _mit_frist(HLobbies.join_async.bind(gefunden))
	if not st2.fertig or st2.wert == null:
		return {"fehler": "Beitritt nicht möglich – das Spiel ist voll oder wurde gerade beendet."}
	lobby = st2.wert
	var peer := EOSGMultiplayerPeer.new()
	var e := peer.create_client(SOCKET, str(lobby.owner_product_user_id))
	if e != OK:
		lobby_weg()
		return {"fehler": "Verbindung nicht möglich (%s)." % error_string(e)}
	return {"peer": peer}

# Lobby verlassen bzw. auflösen (im Hintergrund, die Referenz ist sofort weg)
func lobby_weg() -> void:
	if lobby == null:
		return
	var l = lobby
	lobby = null
	_offen += 1
	if l.is_owner():
		await _mit_frist(l.destroy_async, 5.0)
	else:
		await _mit_frist(l.leave_async, 5.0)
	_offen -= 1

func herunterfahren() -> void:
	if not plattform:
		return
	lobby_weg()
	var t0 := Time.get_ticks_msec()
	while _offen > 0 and Time.get_ticks_msec() - t0 < 6000:
		await get_tree().process_frame
	if angemeldet:
		await _mit_frist(HAuth.logout_async, 4.0)
		angemeldet = false
	for i in 5:
		await get_tree().process_frame
	EOS.Platform.PlatformInterface.release()
	EOS.Platform.PlatformInterface.shutdown()
	plattform = false
