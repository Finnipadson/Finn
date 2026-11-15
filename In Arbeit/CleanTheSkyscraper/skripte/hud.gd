class_name Hud
extends CanvasLayer
# Anzeigen: saubere Fenster, Geld, Höhe, Fortschritt am aktuellen Fenster, kurze Einblendungen.

var zahl: Label
var geld: Label
var hoehe: Label
var hinweis: Label
var balken: ProgressBar
var balken_text: Label
var wurzel: Control
var kreuz: ColorRect
var bis: Label
var meld: Label
var meld_tween: Tween
var status_l: Label
var boost_l: Label
var hotbar_box: HBoxContainer
var hotbar_zeichen := ""

func _ready() -> void:
	wurzel = Control.new()
	wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wurzel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wurzel)
	var oben := _karte(0.5, 0.0, 0, 16)
	var vb := VBoxContainer.new()
	oben.add_child(vb)
	_label(vb, "SAUBERE FENSTER", 15, "1f5fae")
	zahl = _label(vb, "0 / 0", 34, "123a6b")
	var links := _karte(0.0, 0.0, 16, 16)
	var vb2 := VBoxContainer.new()
	links.add_child(vb2)
	_label(vb2, "Höhe", 15, "123a6b")
	hoehe = _label(vb2, "", 22, "1f5fae")
	bis = _label(vb2, "", 13, "2b5b8f")
	var rechts := _karte(1.0, 0.0, -16, 16)
	var vb3 := VBoxContainer.new()
	rechts.add_child(vb3)
	_label(vb3, "Geld", 15, "123a6b")
	geld = _label(vb3, "0 €", 26, "2e8b3d")
	boost_l = _label(vb3, "", 13, "c86a10")
	# Fortschritt am Fenster unter dem Schwamm
	var unten := _karte(0.5, 1.0, 0, -150)
	var vb4 := VBoxContainer.new()
	unten.add_child(vb4)
	balken_text = _label(vb4, "", 14, "123a6b")
	balken = ProgressBar.new()
	balken.custom_minimum_size = Vector2(260, 10)
	balken.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("d9ecf7")
	bg.set_corner_radius_all(5)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("3fb6d6")
	fg.set_corner_radius_all(5)
	balken.add_theme_stylebox_override("background", bg)
	balken.add_theme_stylebox_override("fill", fg)
	vb4.add_child(balken)
	unten.visible = false
	balken.set_meta("karte", unten)
	hinweis = _label(wurzel, "Klick: Maus fangen · Maus: umschauen · Linke Maustaste halten + Maus bewegen: putzen (+ Rechtsklick halten: umschauen)\nA/D: an der Fassade entlang · W/S: hoch/runter · E: runter + aussteigen · Tab: Werkstatt · 1–0 / Mausrad: Werkzeug · Esc: Maus frei", 14, "ffffff")
	hinweis.label_settings.outline_size = 6
	hinweis.label_settings.outline_color = Color("123a6b")
	_platz(hinweis, 0.5, 1.0, 0, -14)
	status_l = _label(wurzel, "", 18, "ffffff")
	status_l.label_settings.outline_size = 7
	status_l.label_settings.outline_color = Color("2e6b3d")
	_platz(status_l, 0.5, 1.0, 0, -132)
	# Hotbar unten in der Mitte: Werkzeuge (in der Gondel) bzw. Fahrzeuge (zu Fuß)
	hotbar_box = HBoxContainer.new()
	hotbar_box.add_theme_constant_override("separation", 6)
	wurzel.add_child(hotbar_box)
	_platz(hotbar_box, 0.5, 1.0, 0, -56)
	meld = _label(wurzel, "", 20, "ffffff")
	meld.label_settings.outline_size = 8
	meld.label_settings.outline_color = Color("123a6b")
	meld.custom_minimum_size = Vector2(900, 0)
	meld.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_platz(meld, 0.5, 0.5, 0, 90)
	meld.modulate.a = 0.0
	kreuz = ColorRect.new()
	kreuz.color = Color(1, 1, 1, 0.9)
	kreuz.custom_minimum_size = Vector2(6, 6)
	wurzel.add_child(kreuz)
	_platz(kreuz, 0.5, 0.5, 0, 0)
	_maus_durchlassen(wurzel)

# Anzeigen dürfen keine Mausklicks/-bewegungen schlucken (die Maus steht im Spiel immer in der Bildmitte!)
func _maus_durchlassen(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_maus_durchlassen(c)

func _karte(ax: float, ay: float, ox: float, oy: float) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.99, 0.97, 0.92)
	sb.border_color = Color("1f5fae")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", sb)
	wurzel.add_child(pc)
	_platz(pc, ax, ay, ox, oy)
	return pc

func _label(eltern: Node, t: String, groesse: int, farbe: String) -> Label:
	var l := Label.new()
	l.text = t
	var ls := LabelSettings.new()
	ls.font_size = groesse
	ls.font_color = Color(farbe)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI Black", "Arial Black", "Segoe UI"])
	f.font_weight = 900
	ls.font = f
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eltern.add_child(l)
	return l

func _platz(c: Control, ax: float, ay: float, ox: float, oy: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH if ax == 0.5 else (Control.GROW_DIRECTION_BEGIN if ax == 1.0 else Control.GROW_DIRECTION_END)
	c.grow_vertical = Control.GROW_DIRECTION_BOTH if ay == 0.5 else (Control.GROW_DIRECTION_BEGIN if ay == 1.0 else Control.GROW_DIRECTION_END)

static func punkte(n: int) -> String:
	var s := str(n)
	var aus := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			aus += "."
		aus += s[i]
	return aus

func zeige(sauber: int, gesamt: int, euro: int, meter: float, stockwerk: int, zu_fuss := false) -> void:
	zahl.text = "%s / %s" % [punkte(sauber), punkte(gesamt)]
	geld.text = "%s €" % punkte(euro)
	hoehe.text = "Am Boden · zu Fuß" if zu_fuss else "%d m · Stockwerk %d" % [int(meter), stockwerk + 1]

func boosts(t: String) -> void:
	boost_l.text = t
	boost_l.visible = t != ""

# kurzer Hinweis über der Steuerung (z. B. „E: Gondel verlassen“)
func status(t: String) -> void:
	status_l.text = t

func steuerung(zu_fuss: bool) -> void:
	if zu_fuss:
		hinweis.text = "Zu Fuß: WASD laufen · Shift rennen · Leertaste springen (Jetpack: hoch, Strg: runter) · E an der Gondel: einsteigen\n1–4 / Mausrad: Fahrzeug · Tab: Werkstatt · B: Album · Esc: Maus frei"
	else:
		hinweis.text = "Klick: Maus fangen · Maus: umschauen · Linke Maustaste halten + Maus bewegen: putzen (+ Rechtsklick halten: umschauen)\nA/D: an der Fassade entlang · W/S: hoch/runter · E: runter + aussteigen · Tab: Werkstatt · B: Album · 1–0 / Mausrad: Werkzeug · Esc: Maus frei"

# Hotbar: Einträge {taste, name, farbe, kurz}; aktiv = Index des gewählten. Baut nur neu, wenn sich etwas geändert hat.
func hotbar(eintraege: Array, aktiv: int) -> void:
	var zeichen := str(eintraege) + str(aktiv)
	if zeichen == hotbar_zeichen:
		return
	hotbar_zeichen = zeichen
	for c in hotbar_box.get_children():
		c.queue_free()
	for i in eintraege.size():
		var e: Dictionary = eintraege[i]
		var feld := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.92) if i == aktiv else Color(0.07, 0.16, 0.29, 0.62)
		sb.border_color = Color("ffc531") if i == aktiv else Color(1, 1, 1, 0.35)
		sb.set_border_width_all(3 if i == aktiv else 1)
		sb.set_corner_radius_all(9)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 2
		sb.content_margin_bottom = 3
		feld.add_theme_stylebox_override("panel", sb)
		feld.custom_minimum_size = Vector2(70, 62)
		feld.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 1)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		feld.add_child(vb)
		var kopf := HBoxContainer.new()
		kopf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(kopf)
		_label(kopf, str(e.taste), 12, "123a6b" if i == aktiv else "cfe0f0")
		var bild := ColorRect.new()   # kleines Farbbild des Werkzeugs/Fahrzeugs
		bild.color = Color(e.farbe)
		bild.custom_minimum_size = Vector2(30, 16)
		bild.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(bild)
		var n := _label(vb, str(e.kurz), 12, "123a6b" if i == aktiv else "ffffff")
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hotbar_box.add_child(feld)
	_maus_durchlassen(hotbar_box)

func freigeschaltet(stockwerke: int) -> void:
	bis.text = "Seil reicht bis Stockwerk %d" % stockwerke

# Text in der Bildmitte, blendet nach ein paar Sekunden aus
func meldung(t: String, dauer := 2.5) -> void:
	meld.text = t
	if meld_tween:
		meld_tween.kill()
	meld.modulate.a = 1.0
	meld_tween = create_tween()
	meld_tween.tween_interval(dauer)
	meld_tween.tween_property(meld, "modulate:a", 0.0, 0.5)

func fortschritt(wert: float, sichtbar: bool) -> void:
	balken.get_meta("karte").visible = sichtbar
	balken.value = wert * 100.0
	balken_text.text = "Fenster: %d %%" % int(wert * 100.0)

# Kurze Einblendung, die nach oben wegschwebt (z. B. „+1 €“)
func pop(t: String, farbe := "2e8b3d") -> void:
	var l := _label(wurzel, t, 30, "ffffff")
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.label_settings.outline_size = 9
	l.label_settings.outline_color = Color(farbe)
	l.custom_minimum_size = Vector2(300, 0)
	_platz(l, 0.5, 0.5, randf_range(-30, 30), -50)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "offset_top", -150.0, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "offset_bottom", -150.0, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)
