class_name EinstellungenUi
extends VBoxContainer
# Einstellungen im Glas-Stil (Phase 5): Ton, Bild, Maus, Tasten. Steckt in der Werkstatt (Reiter „Einstellungen“)
# und im Hauptmenü. Alles wird sofort angewendet und in user://einstellungen.json gespeichert (Optionen).

var warte_auf := ""        # Aktion, die gerade eine neue Taste bekommt

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aufbauen()

func aufbauen() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	add_child(UiGlas.ueberschrift("TON"))
	_regler("musik", "Musik", "Ruhige Lounge-Musik – je höher du bist, desto leiser.", "♪", 0.0, 1.0)
	_regler("geraeusche", "Geräusche", "Putzen, Wind, Stadt, Casino, Fahrzeuge …", "FX", 0.0, 1.0)
	_regler("radio", "Gondel-Radio", "Lautstärke des Radios (Zubehör aus der Gondel-Werkstatt).", "FM", 0.0, 1.0)
	add_child(UiGlas.ueberschrift("BILD"))
	var q := UiGlas.auswahl(Optionen.QUALITAET, int(Optionen.wert("qualitaet")), _waehlen.bind("qualitaet"))
	q.name = "qualitaet"
	add_child(UiGlas.karte("Bildqualität", "Niedrig: schneller, weniger Kantenglättung und Schatten. Hoch: am schönsten.", q, "Q", Color("9fb3c8")))
	_schalter("ruhig", "Ruhiges Bild", "An: kein Wackeln im Stand. Aus: Kanten beim Fahren noch glatter (TAA), dafür wackelt das Bild im Stand leicht.", "AA")
	var namen := []
	var gewaehlt := 0
	for i in Optionen.FPS.size():
		namen.append(Optionen.FPS[i][1])
		if int(Optionen.FPS[i][0]) == int(Optionen.wert("fps")):
			gewaehlt = i
	var f := UiGlas.auswahl(namen, gewaehlt, _fps)
	f.name = "fps"
	add_child(UiGlas.karte("Bilder pro Sekunde", "Grenze für die Bildrate. „Bildschirm“ = so viele wie der Monitor zeigt.", f, "FPS", Color("9fb3c8")))
	_schalter("vollbild", "Vollbild", "Spiel bildschirmfüllend statt im Fenster.", "▣")
	add_child(UiGlas.ueberschrift("MAUS"))
	_regler("maus", "Empfindlichkeit", "Wie schnell du dich mit der Maus umschaust.", "M", 0.3, 2.5)
	_schalter("maus_umkehren", "Maus umkehren", "Maus nach vorn schieben = nach unten schauen.", "↕")
	add_child(UiGlas.ueberschrift("TASTEN – ANKLICKEN, DANN NEUE TASTE DRÜCKEN (ESC = ABBRECHEN)"))
	for a in Optionen.AKTIONEN:
		var id: String = a[0]
		var k := UiGlas.knopf("Taste drücken …" if warte_auf == id else Optionen.taste_name(id), "kaufen" if warte_auf == id else "nehmen")
		k.custom_minimum_size = Vector2(170, 34)
		k.name = "taste_" + id
		k.pressed.connect(_taste_waehlen.bind(id))
		var z := HBoxContainer.new()
		var l := UiGlas.text(a[2], 15, UiGlas.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		z.add_child(l)
		z.add_child(k)
		add_child(z)
	var std := UiGlas.knopf("Standard-Tasten", "gefahr")
	std.name = "tasten_standard"
	std.custom_minimum_size = Vector2(200, 34)
	std.pressed.connect(func():
		Ton.klick()
		Optionen.setzen("tasten", {})
		aufbauen())
	add_child(std)

func _regler(id: String, titel: String, info: String, kurz: String, von: float, bis: float) -> void:
	var s := UiGlas.regler(float(Optionen.wert(id)), von, bis, 0.05)
	s.name = "r_" + id
	s.value_changed.connect(func(v: float): Optionen.setzen(id, v, false))
	s.drag_ended.connect(func(_c: bool):
		Optionen.speichern()
		if id == "geraeusche":
			Ton.spielen("geld"))   # Probe-Geräusch
	add_child(UiGlas.karte(titel, info, s, kurz, UiGlas.AKZENT))

func _schalter(id: String, titel: String, info: String, kurz: String) -> void:
	var an: bool = Optionen.wert(id)
	var k := UiGlas.knopf("An" if an else "Aus", "an" if an else "aus")
	k.custom_minimum_size = Vector2(90, 38)
	k.name = "s_" + id
	k.pressed.connect(func():
		Ton.klick()
		Optionen.setzen(id, not bool(Optionen.wert(id)))
		aufbauen())
	add_child(UiGlas.karte(titel, info, k, kurz, Color("9fb3c8")))

func _waehlen(i: int, id: String) -> void:
	Ton.klick()
	Optionen.setzen(id, i)
	aufbauen()

func _fps(i: int) -> void:
	Ton.klick()
	Optionen.setzen("fps", int(Optionen.FPS[i][0]))
	aufbauen()

func _taste_waehlen(id: String) -> void:
	Ton.klick()
	warte_auf = "" if warte_auf == id else id
	aufbauen()

func _input(e: InputEvent) -> void:
	if warte_auf == "" or not is_visible_in_tree():
		return
	if e is InputEventKey and e.pressed and not e.echo:
		get_viewport().set_input_as_handled()
		var k: Key = e.keycode
		if k != KEY_ESCAPE:
			Optionen.belegen(warte_auf, k)
			Ton.klick()
		warte_auf = ""
		aufbauen()
