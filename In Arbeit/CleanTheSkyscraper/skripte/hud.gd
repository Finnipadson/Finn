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
	var rechts := _karte(1.0, 0.0, -16, 16)
	var vb3 := VBoxContainer.new()
	rechts.add_child(vb3)
	_label(vb3, "Geld", 15, "123a6b")
	geld = _label(vb3, "0 €", 26, "2e8b3d")
	# Fortschritt am Fenster unter dem Schwamm
	var unten := _karte(0.5, 1.0, 0, -70)
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
	hinweis = _label(wurzel, "Klick: Maus fangen · Maus: umschauen · Linke Maustaste halten + Maus bewegen: putzen\nA/D: an der Fassade entlang · W/S: hoch/runter · Esc: Maus frei", 14, "ffffff")
	hinweis.label_settings.outline_size = 6
	hinweis.label_settings.outline_color = Color("123a6b")
	_platz(hinweis, 0.5, 1.0, 0, -14)
	kreuz = ColorRect.new()
	kreuz.color = Color(1, 1, 1, 0.9)
	kreuz.custom_minimum_size = Vector2(6, 6)
	wurzel.add_child(kreuz)
	_platz(kreuz, 0.5, 0.5, 0, 0)

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

func zeige(sauber: int, gesamt: int, euro: int, meter: float, stockwerk: int) -> void:
	zahl.text = "%s / %s" % [punkte(sauber), punkte(gesamt)]
	geld.text = "%s €" % punkte(euro)
	hoehe.text = "%d m · Stockwerk %d" % [int(meter), stockwerk + 1]

func fortschritt(wert: float, sichtbar: bool) -> void:
	balken.get_meta("karte").visible = sichtbar
	balken.value = wert * 100.0
	balken_text.text = "Fenster: %d %%" % int(wert * 100.0)

# Kurze Einblendung, die nach oben wegschwebt (z. B. „+1 €“)
func pop(t: String, farbe := "2e8b3d") -> void:
	var l := _label(wurzel, t, 30, "ffffff")
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
