class_name Pausenmenue
extends CanvasLayer
# Esc im Spiel (wenn kein anderes Menü offen ist): Spiel pausiert, Glas-Menü mit Weiterspielen, Einstellungen,
# Speichern, Hauptmenü und Speichern + Beenden. Esc im Menü = weiterspielen.

var spiel: Spiel
var wurzel: Control
var einst: Control
var info: Label
var _zu := false

func setup(s: Spiel) -> void:
	spiel = s
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	s.spieler.wischt = false
	get_tree().paused = not Netz.aktiv()   # Mehrspieler: die Welt läuft weiter
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var teile := UiGlas.fenster(self, 420)
	wurzel = teile[0]
	var vb: VBoxContainer = teile[1]
	vb.add_child(UiGlas.text("Pause", 30, UiGlas.TEXT, true))
	var w := s.wirtschaft
	var sz := int(w.statistik.spielzeit)
	var proz := 100.0 * s.zustand.sauber_zahl / maxf(1.0, s.turm.fenster_gesamt)
	vb.add_child(UiGlas.text("%s %% sauber · %s € · gespielt %d h %02d min" % [str(snappedf(proz, 0.1)).replace(".", ","), Hud.punkte(w.geld), sz / 3600, (sz / 60) % 60], 14, UiGlas.TEXT_LEISE))
	var abst := Control.new()
	abst.custom_minimum_size = Vector2(0, 6)
	vb.add_child(abst)
	for k in [["weiter", "Weiterspielen", "kaufen", schliessen], ["einstellungen", "Einstellungen", "nehmen", _einstellungen],
			["speichern", "Speichern", "nehmen", _speichern], ["hauptmenue", "Hauptmenü", "nehmen", _hauptmenue],
			["beenden", "Speichern und beenden", "gefahr", _beenden]]:
		var b := UiGlas.knopf(k[1], k[2])
		b.name = k[0]
		b.custom_minimum_size = Vector2(370, 46)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(k[3])
		vb.add_child(b)
	if Netz.aktiv():
		_mehrspieler(vb)
	info = UiGlas.text("Esc: weiterspielen", 13, UiGlas.TEXT_LEISE)
	vb.add_child(info)

# Mehrspieler (7f): Spielerliste mit Farbe und Ping; Gastgeber: Rauswerfen + Für alle pausieren; Gast: Runde verlassen
var liste: VBoxContainer
func _mehrspieler(vb: VBoxContainer) -> void:
	var hm := vb.find_child("hauptmenue", false, false) as Button
	if hm and Netz.ist_gast():
		hm.text = "Runde verlassen"
	vb.add_child(UiGlas.ueberschrift("MEHRSPIELER"))
	if Netz.ist_host():
		var ad := Netz.lan_adressen()
		if not ad.is_empty():
			vb.add_child(UiGlas.text("Beitreten im Heimnetz mit: %s" % ", ".join(ad), 13, UiGlas.TEXT_LEISE))
	liste = VBoxContainer.new()
	liste.add_theme_constant_override("separation", 4)
	vb.add_child(liste)
	_liste()
	if Netz.ist_host():
		var p := UiGlas.knopf("Für alle pausieren", "nehmen")
		p.name = "alle_pause"
		p.custom_minimum_size = Vector2(370, 42)
		p.pressed.connect(func():
			Netz.alle_pausieren(true)
			_weg())
		vb.add_child(p)

func _liste() -> void:
	for c in liste.get_children():
		liste.remove_child(c)
		c.queue_free()
	var ids := Netz.spieler.keys()
	ids.sort()
	for id in ids:
		var hb := HBoxContainer.new()
		var ms := Netz.ping_ms(id)
		var t := "● %s%s%s" % [Netz.name_von(id), "  (Gastgeber)" if id == 1 else "", "  – du" if id == Netz.meine_id() else ("  · %d ms" % ms if ms >= 0 else "")]
		var l := UiGlas.text(t, 15, Netz.farbe(id))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		if Netz.ist_host() and id != 1:
			var k := UiGlas.knopf("Rauswerfen", "gefahr")
			k.name = "kick_%d" % id
			k.custom_minimum_size = Vector2(120, 32)
			k.pressed.connect(func():
				Netz.rauswerfen(id)
				info.text = "%s wurde aus dem Spiel genommen." % Netz.name_von(id))
			hb.add_child(k)
		liste.add_child(hb)

func _input(e: InputEvent) -> void:
	if _zu or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if einst:
			einst.queue_free()
			einst = null
		else:
			schliessen()

func _speichern() -> void:
	spiel._speichern()
	info.text = "Gespeichert ✓"

func _einstellungen() -> void:
	if einst:
		einst.queue_free()
	var teile := UiGlas.fenster(self, 760)
	einst = teile[0]
	var vb: VBoxContainer = teile[1]
	var kopf := HBoxContainer.new()
	vb.add_child(kopf)
	var t := UiGlas.text("Einstellungen", 26, UiGlas.TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(t)
	var zu := UiGlas.knopf("Zurück", "kaufen")
	zu.name = "zurueck"
	zu.custom_minimum_size = Vector2(120, 38)
	zu.pressed.connect(func():
		einst.queue_free()
		einst = null)
	kopf.add_child(zu)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, maxf(300.0, get_viewport().get_visible_rect().size.y - 220.0))
	vb.add_child(sc)
	var ui := EinstellungenUi.new()
	ui.name = "einstellungen_ui"
	sc.add_child(ui)

func _hauptmenue() -> void:
	_weg()
	spiel._zum_hauptmenue()   # speichert; im Mehrspieler: Runde verlassen bzw. beenden

func _beenden() -> void:
	spiel._speichern()
	Netz.trennen()
	get_tree().quit()

func schliessen() -> void:
	_weg()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _weg() -> void:
	if _zu:
		return
	_zu = true
	get_tree().paused = Netz.alle_pausiert   # „Für alle pausiert“ bleibt, bis der Gastgeber weiterspielt
	spiel.pause = null
	queue_free()
