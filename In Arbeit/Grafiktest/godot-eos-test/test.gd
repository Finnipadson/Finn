extends Node
# Ladetest EOSG unter Godot 4.7: lädt die Erweiterung, prüft Klassen, startet das EOS-SDK.
# Ohne Epic-Konto: Platform/Login mit Platzhalter-IDs (Fehler dort sind erwartet und werden nur gemeldet).
# Zeilen beginnen mit "EOSTEST", Ergebnis am Ende "EOSTEST ERGEBNIS ok=… fehler=…".

var ok := 0
var fehler := 0

func _p(name: String, gut: bool, info := "") -> void:
	if gut:
		ok += 1
	else:
		fehler += 1
	print("EOSTEST %s %s %s" % ["OK  " if gut else "FEHLER", name, info])

func _ready() -> void:
	print("EOSTEST Godot %s" % Engine.get_version_info().string)
	_p("Singleton IEOS da", Engine.has_singleton("IEOS"))
	var klassen := []
	for k in ClassDB.get_class_list():
		if "EOS" in k:
			klassen.append(k)
	klassen.sort()
	print("EOSTEST Klassen: %s" % ", ".join(klassen))
	var peer_klasse := ""
	for k in klassen:
		if ClassDB.is_parent_class(k, "MultiplayerPeer"):
			peer_klasse = k
	_p("Multiplayer-Peer-Klasse da", peer_klasse != "", peer_klasse)
	if peer_klasse != "":
		var peer = ClassDB.instantiate(peer_klasse)
		_p("Peer erzeugbar", peer != null)
		var namen := []
		for m in ClassDB.class_get_method_list(peer_klasse, true):
			namen.append(m.name)
		print("EOSTEST Peer-Methoden: %s" % ", ".join(namen))
		_p("Peer ist MultiplayerPeer", peer is MultiplayerPeer)
		# An SceneMultiplayer hängen geht erst nach create_server/create_client (braucht Login) – wie bei ENet.
		for m in ["create_server", "create_client", "create_mesh"]:
			_p("Peer hat " + m, m in namen)
	# EOS-SDK starten (braucht keine Konto-Daten)
	var init := EOS.Platform.InitializeOptions.new()
	init.product_name = "CleanTheSkyscraperTest"
	init.product_version = "0.1"
	var res: EOS.Result = await HPlatform.initialize_async(init)
	_p("EOS-SDK initialisiert", EOS.is_success(res) or res == EOS.Result.AlreadyConfigured, EOS.result_str(res))
	# Platform mit Platzhalter-IDs (ohne Konto) – nur zur Info
	var opts := EOS.Platform.CreateOptions.new()
	opts.product_id = "platzhalter"
	opts.sandbox_id = "platzhalter"
	opts.deployment_id = "platzhalter"
	opts.client_id = "platzhalter"
	opts.client_secret = "platzhalter"
	var erstellt = EOS.Platform.PlatformInterface.create(opts)
	print("EOSTEST INFO Platform mit Platzhalter-IDs: %s (für echten Login braucht es das Epic-Konto)" % str(erstellt))
	# ein paar Bilder ticken lassen, damit Absturz beim Tick auffällt
	for i in 30:
		await get_tree().process_frame
	_p("30 Bilder mit EOS-Tick ohne Absturz", true)
	print("EOSTEST ERGEBNIS ok=%d fehler=%d" % [ok, fehler])
	if not "--ohne-abmelden" in OS.get_cmdline_user_args():
		# Ohne das hängt Godot beim Beenden (gemessen 18.11.2026)
		EOS.Platform.PlatformInterface.release()
		var sd = EOS.Platform.PlatformInterface.shutdown()
		print("EOSTEST INFO EOS beendet: %s" % EOS.result_str(sd))
	print("EOSTEST ENDE")
	get_tree().quit(0 if fehler == 0 else 1)
