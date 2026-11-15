class_name Shop
extends CanvasLayer
# Werkstatt: Gondeln (je Turmseite), Helfer, Gondel-Upgrades, Seilwinde, Einstellungen. Öffnen/Schließen mit Tab.
# Werkzeuge gibt es an den Kiosken auf dem Platz.

signal geaendert
signal neues_spiel

var wirtschaft: Wirtschaft
var fenster: PanelContainer
var scroll: ScrollContainer
var liste: VBoxContainer
var geld_label: Label
var offen := false
var reset_bestaetigen := false

func setup(w: Wirtschaft) -> void:
	wirtschaft = w
	layer = 10
	var hinter := ColorRect.new()
	hinter.color = Color(0.05, 0.12, 0.22, 0.45)
	hinter.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hinter)
	fenster = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.99, 0.97, 0.97)
	sb.border_color = Color("1f5fae")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	fenster.add_theme_stylebox_override("panel", sb)
	fenster.custom_minimum_size = Vector2(760, 0)
	hinter.add_child(fenster)
	# genau in die Bildmitte: Anker 0,5 + Abstand 0, wächst in beide Richtungen
	fenster.anchor_left = 0.5
	fenster.anchor_right = 0.5
	fenster.anchor_top = 0.5
	fenster.anchor_bottom = 0.5
	fenster.offset_left = 0
	fenster.offset_right = 0
	fenster.offset_top = 0
	fenster.offset_bottom = 0
	fenster.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fenster.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	fenster.add_child(vb)
	var kopf := HBoxContainer.new()
	vb.add_child(kopf)
	var titel := _text("WERKSTATT", 30, "1f5fae")
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	kopf.add_child(titel)
	geld_label = _text("", 26, "2e8b3d")
	kopf.add_child(geld_label)
	liste = VBoxContainer.new()
	liste.add_theme_constant_override("separation", 6)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll = ScrollContainer.new()   # lange Liste: scrollen statt aus dem Bild ragen
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(liste)
	vb.add_child(scroll)
	var fuss := HBoxContainer.new()
	vb.add_child(fuss)
	var hinweis := _text("Tab oder Esc: schließen · Zahlen 1–0: Werkzeug wechseln", 14, "2b5b8f")
	hinweis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hinweis.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	fuss.add_child(hinweis)
	var reset := _knopf("Neues Spiel", Color("b8483e"))
	reset.name = "reset"
	reset.pressed.connect(_reset)
	fuss.add_child(reset)
	visible = false

func _text(t: String, g: int, farbe: String) -> Label:
	var l := Label.new()
	l.text = t
	var ls := LabelSettings.new()
	ls.font_size = g
	ls.font_color = Color(farbe)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI Black", "Arial Black", "Segoe UI"])
	f.font_weight = 900
	ls.font = f
	l.label_settings = ls
	return l

func _knopf(t: String, farbe: Color) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(190, 40)
	b.add_theme_font_size_override("font_size", 17)
	for zustand in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = farbe if zustand != "disabled" else Color("b9c4cf")
		if zustand == "hover":
			sb.bg_color = farbe.lightened(0.15)
		sb.set_corner_radius_all(10)
		b.add_theme_stylebox_override(zustand, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("eef3f7"))
	return b

func umschalten() -> void:
	offen = not offen
	visible = offen
	reset_bestaetigen = false
	if offen:
		aufbauen()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Liste neu füllen (nach jedem Kauf)
func aufbauen() -> void:
	scroll.custom_minimum_size = Vector2(0, maxf(240.0, get_viewport().get_visible_rect().size.y - 190.0))
	for c in liste.get_children():
		c.queue_free()
	geld_label.text = "%s €" % Hud.punkte(wirtschaft.geld)
	var hinweis_kiosk := _text("Werkzeuge kaufst du an den Kiosken auf dem Platz (rot: Werkzeuge, grün: Profi-Werkzeuge) und wählst sie mit 1–0 oder dem Mausrad.", 13, "2b5b8f")
	hinweis_kiosk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	liste.add_child(hinweis_kiosk)
	# Gondeln: eine je Turmseite
	liste.add_child(_ueberschrift("Gondeln (eine je Turmseite)"))
	for k in 3:
		var g: Dictionary = wirtschaft.gondeln[k]
		var kg: Button
		if g.gekauft:
			kg = _knopf("Gehört dir", Color("2e8b3d"))
			kg.disabled = true
		else:
			kg = _knopf("Kaufen · %s €" % Hud.punkte(wirtschaft.gondel_preis()), Color("e08a1e"))
			kg.disabled = wirtschaft.geld < wirtschaft.gondel_preis()
			kg.pressed.connect(_kaufe_gondel.bind(k))
		kg.name = "go_%d" % k
		var txt := "Putzt die Seite %s. Steht unten am Turm – zum Wechseln mit E aussteigen und hinlaufen." % Turm.SEITEN_NAMEN[k]
		if k == wirtschaft.aktive_gondel:
			txt += "  (Du sitzt gerade in dieser.)"
		liste.add_child(_zeile("Gondel " + Turm.SEITEN_NAMEN[k], txt, kg))
	# Helfer
	liste.add_child(_ueberschrift("Helfer (putzen, solange du spielst – bis zur Seil-Grenze)"))
	for id in Wirtschaft.HELFER:
		var h: Dictionary = Wirtschaft.HELFER[id]
		var kh: Button
		if wirtschaft.helfer_voll(id):
			kh = _knopf("Alle %d da" % h.max, Color("2e8b3d"))
			kh.disabled = true
		else:
			kh = _knopf("Kaufen · %s €" % Hud.punkte(wirtschaft.helfer_preis(id)), Color("e08a1e"))
			kh.disabled = wirtschaft.geld < wirtschaft.helfer_preis(id)
			kh.pressed.connect(_kaufe_helfer.bind(id))
		kh.name = "he_" + id
		liste.add_child(_zeile("%s  (%d/%d)" % [h.name, wirtschaft.helfer[id], h.max], h.text, kh))
	liste.add_child(_ueberschrift("Gondel-Ausbau (gilt für alle Gondeln)"))
	for id in Wirtschaft.UPGRADES:
		var u: Dictionary = Wirtschaft.UPGRADES[id]
		var stufe: int = wirtschaft.stufen[id]
		var knopf2: Button
		if wirtschaft.upgrade_voll(id):
			knopf2 = _knopf("Fertig ausgebaut", Color("2e8b3d"))
			knopf2.disabled = true
		else:
			knopf2 = _knopf("Kaufen · %s €" % Hud.punkte(wirtschaft.upgrade_preis(id)), Color("e08a1e"))
			knopf2.disabled = wirtschaft.geld < wirtschaft.upgrade_preis(id)
			knopf2.pressed.connect(_kaufe_upgrade.bind(id))
		knopf2.name = "up_" + id
		var info := "%s  (Stufe %d/%d)" % [u.text, stufe, u.max]
		if id == "winde":
			info = "%s  Jetzt bis Stockwerk %d." % [u.text, wirtschaft.oberstes_stockwerk()]
		liste.add_child(_zeile(u.name, info, knopf2))
	liste.add_child(_ueberschrift("Einstellungen"))
	var namen := {"tauben": ["Tauben", "Tauben bekleckern ab und zu ein sauberes Fenster."], "sandsturm": ["Sandsturm", "Ab und zu ein Sandsturm, danach sind ein paar Fenster staubig."], "wind": ["Windböen", "Die Gondel schaukelt, Putzen wird etwas ungenauer."]}
	for k in namen:
		var an: bool = wirtschaft.einstellungen[k]
		var knopf3 := _knopf("An" if an else "Aus", Color("2e8b3d") if an else Color("8a96a3"))
		knopf3.name = "ein_" + k
		knopf3.pressed.connect(_umschalten_einstellung.bind(k))
		liste.add_child(_zeile(namen[k][0], namen[k][1], knopf3))

func _ueberschrift(t: String) -> Label:
	var l := _text(t.to_upper(), 15, "7a9cc0")
	return l

func _zeile(titel: String, text: String, knopf: Button) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	vb.add_child(_text(titel, 19, "123a6b"))
	var t := _text(text, 13, "2b5b8f")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(480, 0)
	vb.add_child(t)
	hb.add_child(vb)
	hb.add_child(knopf)
	return hb

func _kaufe_werkzeug(id: String) -> void:
	if wirtschaft.kaufe_werkzeug(id):
		geaendert.emit()
	aufbauen()

func _nehmen(id: String) -> void:
	wirtschaft.ausruesten(id)
	geaendert.emit()
	aufbauen()

func _kaufe_gondel(k: int) -> void:
	if wirtschaft.kaufe_gondel(k):
		geaendert.emit()
	aufbauen()

func _kaufe_helfer(id: String) -> void:
	if wirtschaft.kaufe_helfer(id):
		geaendert.emit()
	aufbauen()

func _kaufe_upgrade(id: String) -> void:
	if wirtschaft.kaufe_upgrade(id):
		geaendert.emit()
	aufbauen()

func _umschalten_einstellung(k: String) -> void:
	wirtschaft.einstellungen[k] = not wirtschaft.einstellungen[k]
	geaendert.emit()
	aufbauen()

func _reset() -> void:
	var b: Button = find_child("reset", true, false)
	if not reset_bestaetigen:
		reset_bestaetigen = true
		b.text = "Wirklich? Nochmal klicken"
		return
	reset_bestaetigen = false
	b.text = "Neues Spiel"
	neues_spiel.emit()
