class_name HaendlerMenu
extends CanvasLayer
# Menü eines Kiosks im Stil „Glas modern“ (UiGlas): Boosts (Putzmittel, Snacks), Aussehen (Mode & Farben, mit Reitern),
# Werkzeuge (rot: Grund-, grün: Profi-Werkzeuge) und Fahrzeuge. Knopf-Namen (b_, k_, w_, f_) nutzen die Tests.

signal geaendert

const MODE_REITER := ["gondel", "kleidung", "schwamm"]
const MODE_NAMEN := {"gondel": "Gondel", "kleidung": "Kleidung", "schwamm": "Schwamm"}

var wirtschaft: Wirtschaft
var liste: VBoxContainer
var titel: Label
var geld_label: Label
var unter: Label
var reiter_leiste: HBoxContainer
var stand := ""
var offen := false
var mode_reiter := 0

func setup(w: Wirtschaft) -> void:
	wirtschaft = w
	layer = 10
	var vb: VBoxContainer = UiGlas.fenster(self, 720)[1]
	var kopf := HBoxContainer.new()
	vb.add_child(kopf)
	titel = UiGlas.text("", 26, UiGlas.TEXT, true)
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(titel)
	geld_label = UiGlas.text("", 24, UiGlas.GELD, true)
	kopf.add_child(geld_label)
	unter = UiGlas.ueberschrift("")
	vb.add_child(unter)
	reiter_leiste = HBoxContainer.new()
	reiter_leiste.add_theme_constant_override("separation", 6)
	vb.add_child(reiter_leiste)
	liste = VBoxContainer.new()
	liste.add_theme_constant_override("separation", 8)
	vb.add_child(liste)
	vb.add_child(UiGlas.text("E oder Esc: schließen", 13, UiGlas.TEXT_LEISE))
	visible = false

func oeffnen(stand_id: String, name: String) -> void:
	stand = stand_id
	titel.text = name
	offen = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	aufbauen()

func schliessen() -> void:
	offen = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _leeren(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)   # sofort raus, damit neue Knöpfe ihre Namen behalten
		c.queue_free()

func aufbauen() -> void:
	_leeren(liste)
	_leeren(reiter_leiste)
	reiter_leiste.visible = stand == "mode"
	geld_label.text = "%s €" % Hud.punkte(wirtschaft.geld)
	match stand:
		"werkzeug", "grund": _werkzeuge(stand == "werkzeug")
		"fahrzeug": _fahrzeuge()
		"mode": _mode()
		_: _boosts()

func _werkzeuge(profi: bool) -> void:
	unter.text = "PROFI-WERKZEUGE – MIT 6–0 ODER DEM MAUSRAD WÄHLEN" if profi else "WERKZEUGE – MIT 1–5 ODER DEM MAUSRAD WÄHLEN"
	unter.text += wirtschaft.koop_text()
	var farben := {"schwamm": "ffd84a", "grossschwamm": "ffd84a", "abzieher": "c9ced4", "doppel": "c9ced4", "hochdruck": "ffc531", "teleskop": "c9ced4", "dampf": "ff6b6b", "lanze": "35c8ff"}
	for i in Wirtschaft.WERKZEUGE.size():
		var w: Dictionary = Wirtschaft.WERKZEUGE[i]
		if bool(w.get("profi", false)) != profi:
			continue
		var knopf: Button
		if wirtschaft.aktiv == w.id:
			knopf = UiGlas.knopf("In der Hand", "besitz")
			knopf.disabled = true
		elif w.id in wirtschaft.besitz:
			knopf = UiGlas.knopf("Nehmen", "nehmen")
			knopf.pressed.connect(_nehmen.bind(w.id))
		else:
			knopf = UiGlas.knopf("%s €" % Hud.punkte(wirtschaft.werkzeug_preis(w.id)))
			knopf.disabled = wirtschaft.geld < wirtschaft.werkzeug_preis(w.id)
			knopf.set_meta("preis", wirtschaft.werkzeug_preis(w.id))   # Mehrspieler: Sperre bei Geld-Änderung nachführen
			knopf.pressed.connect(_kaufe_werkzeug.bind(w.id))
		knopf.name = "w_" + w.id
		var farbe := Color(w.get("farbe", farben.get(w.id, "35c8ff")))
		liste.add_child(UiGlas.karte(w.name, w.text + "  (Taste %d)" % ((i + 1) % 10), knopf, str((i + 1) % 10), farbe, -1, 0, Symbole.bilder.get(w.id)))

func _fahrzeuge() -> void:
	unter.text = "ZU FUSS MIT 1–4 ODER DEM MAUSRAD WÄHLEN"
	var kurz := {"scooter": "SC", "hoverboard": "HB", "jetpack": "JP"}
	for f in Wirtschaft.FAHRZEUGE:
		var knopf: Button
		if wirtschaft.fahrzeug == f.id:
			knopf = UiGlas.knopf("Absteigen", "besitz")
			knopf.pressed.connect(_fahrzeug_nehmen.bind(""))
		elif f.id in wirtschaft.fahrzeuge:
			knopf = UiGlas.knopf("Aufsteigen", "nehmen")
			knopf.pressed.connect(_fahrzeug_nehmen.bind(f.id))
		else:
			knopf = UiGlas.knopf("%s €" % Hud.punkte(int(f.preis)))
			knopf.disabled = wirtschaft.geld < int(f.preis)
			knopf.set_meta("preis", int(f.preis))   # Mehrspieler: Sperre bei Geld-Änderung nachführen
			knopf.pressed.connect(_kaufe_fahrzeug.bind(f.id))
		knopf.name = "f_" + f.id
		liste.add_child(UiGlas.karte(f.name, f.text, knopf, kurz.get(f.id, ""), Color(f.farbe), -1, 0, Symbole.bilder.get(f.id)))

func _mode() -> void:
	unter.text = "NUR OPTIK – EINMAL KAUFEN, DANN JEDERZEIT ANZIEHEN"
	for i in MODE_REITER.size():
		var r := UiGlas.reiter(MODE_NAMEN[MODE_REITER[i]], i == mode_reiter)
		r.pressed.connect(_mode_reiter.bind(i))
		reiter_leiste.add_child(r)
	for i in MODE_REITER.size():
		var art: String = MODE_REITER[i]
		var seite := VBoxContainer.new()
		seite.add_theme_constant_override("separation", 8)
		seite.visible = i == mode_reiter
		liste.add_child(seite)
		for k in Wirtschaft.KOSMETIK:
			if k.art != art:
				continue
			var knopf: Button
			if wirtschaft.kosmetik_aktiv[art] == k.id:
				knopf = UiGlas.knopf("Trage ich", "besitz")
				knopf.disabled = true
			elif k.id in wirtschaft.kosmetik_besitz:
				knopf = UiGlas.knopf("Anziehen", "nehmen")
				knopf.pressed.connect(_nutzen.bind(k.id))
			else:
				knopf = UiGlas.knopf("%s €" % Hud.punkte(int(k.preis)) if int(k.preis) > 0 else "Gratis")
				knopf.disabled = wirtschaft.geld < int(k.preis)
				knopf.set_meta("preis", int(k.preis))   # Mehrspieler: Sperre bei Geld-Änderung nachführen
				knopf.pressed.connect(_kaufe_kosmetik.bind(k.id))
			knopf.name = "k_" + k.id
			seite.add_child(UiGlas.karte(k.name, "", knopf, " ", Color(k.farbe)))

func _mode_reiter(i: int) -> void:
	mode_reiter = i
	aufbauen()

func _boosts() -> void:
	unter.text = "WIRKT EINE ZEIT LANG – NOCHMAL KAUFEN VERLÄNGERT · GLEICHE WIRKUNG: NUR DER STÄRKSTE ZÄHLT"
	var kurz := {"glanzspray": "GS", "goldpolitur": "GP", "kaffee": "KA", "eis": "EI", "limo": "LI", "cocktail": "SC", "mojito": "MO", "espresso": "ES", "mittag": "MM", "chefmenue": "KC", "champagner": "GC",
		"kokos": "KO", "mango": "MA", "ananas": "AN", "limette": "LI", "pina": "PC", "lagoon": "BL", "sunrise": "TS", "caipi": "CA"}
	var farbe := {"glanzspray": "35c8ff", "goldpolitur": "ffc531", "kaffee": "c8925a", "eis": "ff9ad5", "limo": "e8e04a", "cocktail": "ff4fb8", "mojito": "7fe08a", "espresso": "c8925a", "mittag": "ffb03a", "chefmenue": "ffc531", "champagner": "f2e3b0",
		"kokos": "f4efe2", "mango": "ffb03a", "ananas": "ffd84a", "limette": "7fe08a", "pina": "fff2c8", "lagoon": "35c8ff", "sunrise": "ff7a3a", "caipi": "a8e063"}
	for id in Wirtschaft.BOOSTS:
		var b: Dictionary = Wirtschaft.BOOSTS[id]
		if b.stand != stand:
			continue
		var rest := float(wirtschaft.boosts.get(id, 0.0))
		var info: String = b.text
		if rest > 0.0:
			info += "  Läuft noch %d:%02d." % [int(rest) / 60, int(rest) % 60]
		var knopf2 := UiGlas.knopf(("+ %s €" if rest > 0.0 else "%s €") % Hud.punkte(wirtschaft.boost_preis(id)))
		knopf2.disabled = wirtschaft.geld < wirtschaft.boost_preis(id)
		knopf2.set_meta("preis", wirtschaft.boost_preis(id))   # Mehrspieler: Sperre bei Geld-Änderung nachführen
		knopf2.pressed.connect(_kaufe_boost.bind(id))
		knopf2.name = "b_" + id
		liste.add_child(UiGlas.karte(b.name, info, knopf2, kurz.get(id, ""), Color(farbe.get(id, "35c8ff"))))

# Alle Käufe/Wechsel laufen über Netz.befehl (Einzelspieler: sofort, Gast: beim Gastgeber) – Ergebnis kommt in _fertig
func _kaufe_fahrzeug(id: String) -> void:
	Netz.befehl("fahrzeug", {"id": id}, _fertig)

func _fahrzeug_nehmen(id: String) -> void:
	Netz.befehl("fahrzeug_nehmen", {"id": id}, _fertig_immer)

func _kaufe_werkzeug(id: String) -> void:
	Netz.befehl("werkzeug", {"id": id}, _fertig)

func _nehmen(id: String) -> void:
	Netz.befehl("ausruesten", {"id": id}, _fertig_immer)

func _kaufe_boost(id: String) -> void:
	Netz.befehl("boost", {"id": id}, _fertig)

func _kaufe_kosmetik(id: String) -> void:
	Netz.befehl("kosmetik", {"id": id}, _fertig)

func _nutzen(id: String) -> void:
	Netz.befehl("kosmetik_nutzen", {"id": id}, _fertig_immer)

func _fertig(e: Dictionary) -> void:
	if e.get("ok", false):
		geaendert.emit()
	aufbauen()

func _fertig_immer(_e: Dictionary) -> void:
	geaendert.emit()
	aufbauen()
