class_name Shop
extends CanvasLayer
# Werkstatt (Tab): Reiter Gondeln · Helfer · Ausbau · Einstellungen, Stil „Glas modern“ (UiGlas).
# Werkzeuge gibt es an den Kiosken auf dem Platz. Alle Reiter werden gebaut (nicht sichtbare versteckt),
# damit Tests jeden Knopf über seinen Namen finden.

signal geaendert
signal neues_spiel
signal hauptmenue

const REITER := ["Gondeln", "Helfer", "Ausbau", "Einstellungen"]   # Einstellungen: Ereignisse + EinstellungenUi

var wirtschaft: Wirtschaft
var scroll: ScrollContainer
var seiten: Array = []           # VBoxContainer je Reiter
var reiter_leiste: HBoxContainer
var geld_label: Label
var reiter := 0
var offen := false
var reset_bestaetigen := false

func setup(w: Wirtschaft) -> void:
	wirtschaft = w
	layer = 10
	var vb: VBoxContainer = UiGlas.fenster(self, 780)[1]
	var kopf := HBoxContainer.new()
	vb.add_child(kopf)
	var titel := UiGlas.text("Werkstatt", 26, UiGlas.TEXT, true)
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(titel)
	geld_label = UiGlas.text("", 24, UiGlas.GELD, true)
	kopf.add_child(geld_label)
	reiter_leiste = HBoxContainer.new()
	reiter_leiste.add_theme_constant_override("separation", 6)
	vb.add_child(reiter_leiste)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var stapel := VBoxContainer.new()
	stapel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stapel)
	for i in REITER.size():
		var s := VBoxContainer.new()
		s.add_theme_constant_override("separation", 8)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stapel.add_child(s)
		seiten.append(s)
	var fuss := HBoxContainer.new()
	vb.add_child(fuss)
	var hinweis := UiGlas.text("Tab oder Esc: schließen  ·  Werkzeuge gibt es an den Kiosken auf dem Platz", 13, UiGlas.TEXT_LEISE)
	hinweis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fuss.add_child(hinweis)
	visible = false

func umschalten() -> void:
	offen = not offen
	visible = offen
	reset_bestaetigen = false
	if offen:
		aufbauen()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _reiter_waehlen(i: int) -> void:
	reiter = i
	aufbauen()

# Alles neu füllen (nach jedem Kauf)
func aufbauen() -> void:
	geld_label.text = "%s €" % Hud.punkte(wirtschaft.geld)
	for c in reiter_leiste.get_children():
		reiter_leiste.remove_child(c)   # sofort raus, damit die neuen Knöpfe ihre Namen behalten
		c.queue_free()
	for i in REITER.size():
		var r := UiGlas.reiter(REITER[i], i == reiter)
		r.name = "reiter_%d" % i
		r.pressed.connect(_reiter_waehlen.bind(i))
		reiter_leiste.add_child(r)
	for i in seiten.size():
		var s: VBoxContainer = seiten[i]
		for c in s.get_children():
			s.remove_child(c)
			c.queue_free()
		s.visible = i == reiter
	_gondeln(seiten[0])
	_helfer(seiten[1])
	_ausbau(seiten[2])
	_einstellungen(seiten[3])
	_hoehe_anpassen.call_deferred()

# Liste so hoch wie ihr Inhalt, höchstens bis knapp unter den Bildrand (dann scrollen)
func _hoehe_anpassen() -> void:
	var inhalt: float = (seiten[reiter] as VBoxContainer).get_combined_minimum_size().y
	var platz := get_viewport().get_visible_rect().size.y - 250.0
	scroll.custom_minimum_size = Vector2(0, clampf(inhalt, 120.0, maxf(240.0, platz)))

func _gondeln(s: VBoxContainer) -> void:
	s.add_child(UiGlas.ueberschrift("EINE GONDEL JE TURMSEITE – ZUM WECHSELN UNTEN MIT E AUSSTEIGEN UND HINLAUFEN" + _koop_text()))
	for k in 3:
		var g: Dictionary = wirtschaft.gondeln[k]
		var kg: Button
		if g.gekauft:
			kg = UiGlas.knopf("Gehört dir", "besitz")
			kg.disabled = true
		else:
			kg = UiGlas.knopf("%s €" % Hud.punkte(wirtschaft.gondel_preis()))
			kg.disabled = wirtschaft.geld < wirtschaft.gondel_preis()
			kg.set_meta("preis", wirtschaft.gondel_preis())   # Mehrspieler: Sperre bei Geld-Änderung nachführen
			kg.pressed.connect(_kaufe_gondel.bind(k))
		kg.name = "go_%d" % k
		var txt := "Putzt die Seite %s." % Turm.SEITEN_NAMEN[k]
		if k == wirtschaft.aktive_gondel:
			txt += "  Du sitzt gerade in dieser."
		elif g.gekauft and float(g.hoehe) > 1.5:
			txt += "  Zuletzt auf %d m." % int(g.hoehe)
		s.add_child(UiGlas.karte("Gondel " + Turm.SEITEN_NAMEN[k], txt, kg, Turm.SEITEN_NAMEN[k].substr(0, 1), Color("ffc531")))

func _helfer(s: VBoxContainer) -> void:
	s.add_child(UiGlas.ueberschrift("PUTZEN, SOLANGE DU SPIELST – BIS ZUR SEIL-GRENZE" + _koop_text()))
	var kurz := {"putzkraft": "PK", "roboter": "RB", "drohne": "DR"}
	var farbe := {"putzkraft": Color("3a86d4"), "roboter": Color("b18cff"), "drohne": Color("5fd3a0")}
	for id in Wirtschaft.HELFER:
		var h: Dictionary = Wirtschaft.HELFER[id]
		var kh: Button
		if wirtschaft.helfer_voll(id):
			kh = UiGlas.knopf("Alle da", "besitz")
			kh.disabled = true
		else:
			kh = UiGlas.knopf("%s €" % Hud.punkte(wirtschaft.helfer_preis(id)))
			kh.disabled = wirtschaft.geld < wirtschaft.helfer_preis(id)
			kh.set_meta("preis", wirtschaft.helfer_preis(id))   # Mehrspieler: Sperre bei Geld-Änderung nachführen
			kh.pressed.connect(_kaufe_helfer.bind(id))
		kh.name = "he_" + id
		s.add_child(UiGlas.karte("%s  %d/%d" % [h.name, wirtschaft.helfer[id], h.max], h.text, kh, kurz[id], farbe[id], wirtschaft.helfer[id], h.max))

func _ausbau(s: VBoxContainer) -> void:
	s.add_child(UiGlas.ueberschrift("GILT FÜR ALLE GONDELN" + _koop_text()))
	var kurz := {"motor": "MO", "arm": "AR", "winde": "SW"}
	for id in Wirtschaft.UPGRADES:
		var u: Dictionary = Wirtschaft.UPGRADES[id]
		var stufe: int = wirtschaft.stufen[id]
		var k2: Button
		if wirtschaft.upgrade_voll(id):
			k2 = UiGlas.knopf("Fertig", "besitz")
			k2.disabled = true
		else:
			k2 = UiGlas.knopf("%s €" % Hud.punkte(wirtschaft.upgrade_preis(id)))
			k2.disabled = wirtschaft.geld < wirtschaft.upgrade_preis(id)
			k2.set_meta("preis", wirtschaft.upgrade_preis(id))   # Mehrspieler: Sperre bei Geld-Änderung nachführen
			k2.pressed.connect(_kaufe_upgrade.bind(id))
		k2.name = "up_" + id
		var info: String = u.text
		if id == "winde":
			info += "  Jetzt bis Stockwerk %d." % wirtschaft.oberstes_stockwerk()
		s.add_child(UiGlas.karte(u.name, info, k2, kurz[id], UiGlas.AKZENT, stufe, u.max))

# Mehrspieler: Fortschritts-Käufe kosten mehr (höchste Spielerzahl der letzten 10 min)
func _koop_text() -> String:
	return wirtschaft.koop_text()

func _einstellungen(s: VBoxContainer) -> void:
	s.add_child(UiGlas.ueberschrift("EREIGNISSE" + (" – STELLT DER GASTGEBER EIN" if Netz.ist_gast() else "")))
	var namen := {"tauben": ["Tauben", "Tauben bekleckern ab und zu ein sauberes Fenster.", "TB"], "sandsturm": ["Sandsturm", "Ab und zu ein Sandsturm, danach sind ein paar Fenster staubig.", "SS"], "wind": ["Windböen", "Die Gondel schaukelt, Putzen wird etwas ungenauer.", "WB"]}
	for k in namen:
		var an: bool = wirtschaft.einstellungen[k]
		var k3 := UiGlas.knopf("An" if an else "Aus", "an" if an else "aus")
		k3.custom_minimum_size = Vector2(90, 38)
		k3.name = "ein_" + k
		k3.pressed.connect(_umschalten_einstellung.bind(k))
		k3.disabled = Netz.ist_gast()
		s.add_child(UiGlas.karte(namen[k][0], namen[k][1], k3, namen[k][2], Color("9fb3c8")))
	s.add_child(EinstellungenUi.new())   # Ton, Bild, Maus, Tasten (gelten für alle Spielstände)
	s.add_child(UiGlas.ueberschrift("SPIELSTAND"))
	var reset := UiGlas.knopf("Wirklich? Nochmal klicken" if reset_bestaetigen else "Neues Spiel", "gefahr")
	reset.custom_minimum_size = Vector2(220, 38)
	reset.name = "reset"
	reset.pressed.connect(_reset)
	s.add_child(UiGlas.karte("Neues Spiel", "Löscht deinen Fortschritt und fängt ganz von vorn an.", reset, "!", UiGlas.GEFAHR))
	var menue := UiGlas.knopf("Hauptmenü", "nehmen")
	menue.name = "hauptmenue"
	menue.custom_minimum_size = Vector2(160, 38)
	menue.pressed.connect(func(): hauptmenue.emit())
	s.add_child(UiGlas.karte("Zum Hauptmenü", "Speichert und zeigt das Startmenü mit dem Flug um den Turm.", menue, "≡", UiGlas.AKZENT))

# Käufe über Netz.befehl (Einzelspieler: sofort, Gast: beim Gastgeber, Antwort in _fertig)
func _kaufe_gondel(k: int) -> void:
	Netz.befehl("gondel", {"seite": k}, _fertig)

func _kaufe_helfer(id: String) -> void:
	Netz.befehl("helfer", {"id": id}, _fertig)

func _kaufe_upgrade(id: String) -> void:
	Netz.befehl("upgrade", {"id": id}, _fertig)

func _fertig(e: Dictionary) -> void:
	if e.get("ok", false):
		geaendert.emit()
	aufbauen()

func _umschalten_einstellung(k: String) -> void:
	wirtschaft.einstellungen[k] = not wirtschaft.einstellungen[k]
	geaendert.emit()
	aufbauen()

func _reset() -> void:
	if not reset_bestaetigen:
		reset_bestaetigen = true
		aufbauen()
		return
	reset_bestaetigen = false
	neues_spiel.emit()
