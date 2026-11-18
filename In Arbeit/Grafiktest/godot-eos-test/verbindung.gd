extends Node
# Verbindungstest über Epic Online Services (Schritt 2), zwei Prozesse auf einem PC:
#   godot --headless --path . verbindung.tscn -- --rolle=host --codedatei=PFAD [--relay=erzwingen]
#   godot --headless --path . verbindung.tscn -- --rolle=gast --codedatei=PFAD [--relay=erzwingen]
# Gastgeber: anonym anmelden, Lobby mit 6-stelligem Code, EOSGMultiplayerPeer als Server.
# Gast: wartet auf die Codedatei, anmelden, Lobby per Code suchen + beitreten, als Client verbinden.
# Dann 20× Ping/Pong per RPC (Laufzeit messen) + Daten in beide Richtungen. Zeilen beginnen mit "EOSNETZ".
# Die Zugangsdaten kommen aus eos_zugang.cfg und werden nie ausgegeben.

const SOCKET := "skyscraper"
const BUCKET := "skyscraper:test"
const PINGS := 20
const STUECK := 1000   # Bytes je RPC-Stück (EOS-Grenze ~1170 inkl. Godot-Kopf)

var rolle := ""
var codedatei := ""
var relay := "erlauben"
var ok := 0
var fehler := 0
var peer: EOSGMultiplayerPeer
var lobby: HLobby
var laufzeiten: Array = []
var gast_hallo := ""
var host_antwort := ""
var fertig := false

func _p(name: String, gut: bool, info := "") -> void:
	if gut:
		ok += 1
	else:
		fehler += 1
	print("EOSNETZ [%s] %s %s %s" % [rolle, "OK  " if gut else "FEHLER", name, info])

func _info(t: String) -> void:
	print("EOSNETZ [%s] INFO %s" % [rolle, t])

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rolle="):
			rolle = a.substr(8)
		elif a.begins_with("--codedatei="):
			codedatei = a.substr(12)
		elif a.begins_with("--relay="):
			relay = a.substr(8)
	HLog.log_level = HLog.LogLevel.WARN
	get_tree().create_timer(150.0).timeout.connect(func(): _p("Zeitlimit 150 s", false); _ende())
	if rolle == "gast":
		# Erst nach dem Gastgeber anmelden: die anonyme Anmeldung erneuert die Geräte-ID auf diesem PC,
		# so bekommen beide Prozesse verschiedene Nutzer.
		while not FileAccess.file_exists(codedatei):
			await get_tree().create_timer(0.5).timeout
	if not await _anmelden():
		_ende()
		return
	if rolle == "host":
		await _host()
	else:
		await _gast()

func _anmelden() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load("res://eos_zugang.cfg") != OK:
		_p("eos_zugang.cfg lesbar", false)
		return false
	var c := HCredentials.new()
	c.product_name = "CleanTheSkyscraperTest"
	c.product_version = "0.1"
	for k in ["product_id", "sandbox_id", "deployment_id", "client_id", "client_secret"]:
		c.set(k, str(cfg.get_value("epic", k, "")))
	var gut: bool = await HPlatform.setup_eos_async(c)
	_p("EOS-Platform mit echten IDs", gut)
	if not gut:
		return false
	var rc = HP2P.set_relay_control(EOS.P2P.RelayControl.ForceRelays if relay == "erzwingen" else EOS.P2P.RelayControl.AllowRelays)
	_info("Relay: %s (%s)" % [relay, EOS.result_str(rc)])
	var t0 := Time.get_ticks_msec()
	gut = await HAuth.login_anonymous_async("Gastgeber" if rolle == "host" else "Gast")
	_p("Anonym angemeldet (Geräte-ID)", gut and HAuth.product_user_id != "", "%d ms, Nutzer …%s" % [Time.get_ticks_msec() - t0, HAuth.product_user_id.right(6)])
	return gut

func _host() -> void:
	var code := ""
	var zeichen := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	for i in 6:
		code += zeichen[randi() % zeichen.length()]
	var opts := EOS.Lobby.CreateLobbyOptions.new()
	opts.bucket_id = BUCKET
	opts.max_lobby_members = 3
	opts.presence_enabled = false
	opts.enable_join_by_id = false
	lobby = await HLobbies.create_lobby_async(opts)
	_p("Lobby erstellt", lobby != null)
	if lobby == null:
		_ende()
		return
	lobby.add_attribute("code", code)
	var gut: bool = await lobby.update_async()
	_p("Code an der Lobby", gut, code)
	peer = EOSGMultiplayerPeer.new()
	var e = peer.create_server(SOCKET)
	_p("Server gestartet", e == OK, error_string(e))
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_host_gast_da)
	var f := FileAccess.open(codedatei, FileAccess.WRITE)
	f.store_string(code)
	f.close()
	_info("Code %s in Codedatei geschrieben, warte auf Gast" % code)

func _host_gast_da(id: int) -> void:
	_p("Gast verbunden", true, "Peer %d" % id)
	await get_tree().create_timer(0.5).timeout
	for i in PINGS:
		ping.rpc_id(id, Time.get_ticks_usec())
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(2.0).timeout
	_p("Alle Pongs zurück", laufzeiten.size() == PINGS, "%d/%d" % [laufzeiten.size(), PINGS])
	if laufzeiten.size() > 0:
		laufzeiten.sort()
		_info("Laufzeit hin+zurück: min %.0f ms, Mitte %.0f ms, max %.0f ms" % [laufzeiten[0], laufzeiten[laufzeiten.size() / 2], laufzeiten[-1]])
	_p("Hallo vom Gast angekommen", gast_hallo == "Hallo vom Gast", gast_hallo)
	var gross := PackedByteArray()
	gross.resize(30000)
	for i in gross.size():
		gross[i] = i % 251
	# EOS-P2P-Pakete sind auf ~1170 Byte begrenzt (ein 30-KB-RPC wird abgelehnt) → in Stücke teilen
	var t_start := Time.get_ticks_msec()
	var n := ceili(gross.size() / float(STUECK))
	for i in n:
		stueck.rpc_id(id, i, n, gross.slice(i * STUECK, mini((i + 1) * STUECK, gross.size())))
	while host_antwort == "" and Time.get_ticks_msec() - t_start < 10000:
		await get_tree().process_frame
	_info("30 KB in %d Stücken übertragen in %d ms" % [n, Time.get_ticks_msec() - t_start])
	_p("30-KB-Paket bestätigt", host_antwort == "30000 ok", host_antwort)
	tschuess.rpc_id(id)
	await get_tree().create_timer(1.0).timeout
	_ende()

func _gast() -> void:
	var t0 := Time.get_ticks_msec()
	while not FileAccess.file_exists(codedatei):
		await get_tree().create_timer(0.5).timeout
	var code := FileAccess.get_file_as_string(codedatei).strip_edges()
	_info("Code gelesen: %s" % code)
	var gefunden = null
	var versuche := 0
	while versuche < 15:
		versuche += 1
		gefunden = await HLobbies.search_by_attribute_async({"key": "code", "value": code})
		if gefunden is Array and gefunden.size() > 0:
			break
		var im_bucket = await HLobbies.search_by_bucket_id_async(BUCKET)
		_info("Versuch %d: per Code %d, im Bucket %d Lobbys" % [versuche, gefunden.size() if gefunden is Array else -1, im_bucket.size() if im_bucket is Array else -1])
		await get_tree().create_timer(2.0).timeout
	_p("Lobby per Code gefunden", gefunden is Array and gefunden.size() == 1, "%d Treffer nach %d Versuch(en), %d ms" % [gefunden.size() if gefunden is Array else -1, versuche, Time.get_ticks_msec() - t0])
	if not (gefunden is Array and gefunden.size() > 0):
		_ende()
		return
	lobby = await HLobbies.join_async(gefunden[0])
	_p("Lobby beigetreten", lobby != null)
	if lobby == null:
		_ende()
		return
	peer = EOSGMultiplayerPeer.new()
	var e = peer.create_client(SOCKET, lobby.owner_product_user_id)
	_p("Client gestartet", e == OK, error_string(e))
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func():
		_p("Mit Gastgeber verbunden", true, "%d ms nach Codeeingabe" % (Time.get_ticks_msec() - t0))
		hallo.rpc_id(1, "Hallo vom Gast"))
	multiplayer.connection_failed.connect(func(): _p("Verbindung", false, "connection_failed"); _ende())
	multiplayer.server_disconnected.connect(func():
		if not fertig:
			_p("Gastgeber unerwartet weg", false)
		_ende())

@rpc("authority", "call_remote", "reliable")
func ping(t: int) -> void:
	pong.rpc_id(1, t)

@rpc("any_peer", "call_remote", "reliable")
func pong(t: int) -> void:
	laufzeiten.append((Time.get_ticks_usec() - t) / 1000.0)

@rpc("any_peer", "call_remote", "reliable")
func hallo(t: String) -> void:
	gast_hallo = t

var _stuecke := {}
@rpc("authority", "call_remote", "reliable")
func stueck(i: int, n: int, d: PackedByteArray) -> void:
	_stuecke[i] = d
	if _stuecke.size() == n:
		var alles := PackedByteArray()
		for k in n:
			alles.append_array(_stuecke[k])
		daten(alles)

func daten(d: PackedByteArray) -> void:
	var gut := d.size() == 30000
	for i in range(0, d.size(), 997):
		gut = gut and d[i] == i % 251
	_p("30-KB-Paket heil angekommen", gut)
	antwort.rpc_id(1, "%d ok" % d.size() if gut else "kaputt")

@rpc("any_peer", "call_remote", "reliable")
func antwort(t: String) -> void:
	host_antwort = t

@rpc("authority", "call_remote", "reliable")
func tschuess() -> void:
	fertig = true
	_p("Gastgeber hat sauber beendet", true)
	_ende()

var _beendet := false
func _ende() -> void:
	if _beendet:
		return
	_beendet = true
	fertig = true
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
	if lobby:
		if rolle == "host":
			await lobby.destroy_async()
		else:
			await lobby.leave_async()
	await HAuth.logout_async()
	print("EOSNETZ [%s] ERGEBNIS ok=%d fehler=%d" % [rolle, ok, fehler])
	# Alle EOS-Objekte (Lobby-Details, Suchen, Peer) vor release() freigeben – sonst Absturz beim Beenden
	lobby = null
	peer = null
	for i in 5:
		await get_tree().process_frame
	EOS.Platform.PlatformInterface.release()
	EOS.Platform.PlatformInterface.shutdown()
	get_tree().quit(0 if fehler == 0 else 1)
