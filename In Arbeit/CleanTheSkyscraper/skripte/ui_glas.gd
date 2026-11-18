class_name UiGlas
# Gemeinsamer Stil für Menüs (Vorlage „Glas modern“, gewählt vom User): dunkles Glas, Reiter, Karten mit Symbol-Kachel,
# helle Akzentfarbe Cyan. Alles statisch, damit Werkstatt und Kiosk-Menüs gleich aussehen.

const GLAS := Color(0.106, 0.165, 0.239, 0.95)       # Fenster-Hintergrund
const RAND := Color(1, 1, 1, 0.13)
const KARTE := Color(1, 1, 1, 0.07)
const KARTE_RAND := Color(1, 1, 1, 0.13)
const TEXT := Color("e8f1fa")
const TEXT_LEISE := Color("9fb3c8")
const AKZENT := Color("35c8ff")
const AKZENT_DUNKEL := Color("06263a")
const GELD := Color("5fd3a0")
const GEFAHR := Color("ff6b6b")

static func schrift(dick := false) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI Semibold", "Segoe UI", "Arial"] if dick else ["Segoe UI", "Arial"])
	f.font_weight = 600 if dick else 400
	return f

static func text(t: String, groesse: int, farbe: Color = TEXT, dick := false) -> Label:
	var l := Label.new()
	l.text = t
	var ls := LabelSettings.new()
	ls.font_size = groesse
	ls.font_color = farbe
	ls.font = schrift(dick)
	l.label_settings = ls
	return l

static func box(farbe: Color, rand: Color, radius: int, innen: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = farbe
	sb.border_color = rand
	sb.set_border_width_all(1 if rand.a > 0.0 else 0)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = innen
	sb.content_margin_right = innen
	sb.content_margin_top = innen * 0.7
	sb.content_margin_bottom = innen * 0.7
	return sb

# Großes Fenster in der Bildmitte mit abgedunkeltem Hintergrund. Gibt [Hintergrund, VBox für den Inhalt] zurück.
static func fenster(eltern: Node, breite: float) -> Array:
	var hinter := ColorRect.new()
	hinter.color = Color(0.02, 0.04, 0.08, 0.5)
	hinter.set_anchors_preset(Control.PRESET_FULL_RECT)
	eltern.add_child(hinter)
	var f := PanelContainer.new()
	f.add_theme_stylebox_override("panel", box(GLAS, RAND, 16, 22))
	f.custom_minimum_size = Vector2(breite, 0)
	hinter.add_child(f)
	for k in ["anchor_left", "anchor_right", "anchor_top", "anchor_bottom"]:
		f.set(k, 0.5)
	f.grow_horizontal = Control.GROW_DIRECTION_BOTH
	f.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	f.add_child(vb)
	return [hinter, vb]

# Knopf. art: kaufen (Cyan), nehmen (Glas), besitz (grün umrandet), an/aus (Schalter), gefahr (rot umrandet)
static func knopf(t: String, art := "kaufen") -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(150, 38)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", schrift(true))
	b.add_theme_font_size_override("font_size", 15)
	var grund: Color
	var schrift_farbe: Color
	var rand := Color(0, 0, 0, 0)
	match art:
		"kaufen":
			grund = AKZENT
			schrift_farbe = AKZENT_DUNKEL
		"besitz":
			grund = Color(GELD, 0.12)
			rand = Color(GELD, 0.7)
			schrift_farbe = GELD
		"an":
			grund = Color(GELD, 0.85)
			schrift_farbe = Color("06261a")
		"gefahr":
			grund = Color(GEFAHR, 0.1)
			rand = Color(GEFAHR, 0.7)
			schrift_farbe = GEFAHR
		_:   # nehmen, aus
			grund = Color(1, 1, 1, 0.12)
			rand = Color(1, 1, 1, 0.2)
			schrift_farbe = TEXT
	for z in ["normal", "hover", "pressed", "disabled"]:
		var sb := box(grund, rand, 8, 12)
		if z == "hover":
			sb.bg_color = grund.lightened(0.12) if grund.a > 0.5 else Color(grund, grund.a + 0.1)
		if z == "disabled":
			sb.bg_color = Color(1, 1, 1, 0.06)
			sb.border_color = Color(1, 1, 1, 0.1)
		b.add_theme_stylebox_override(z, sb)
	b.add_theme_color_override("font_color", schrift_farbe)
	b.add_theme_color_override("font_hover_color", schrift_farbe)
	b.add_theme_color_override("font_pressed_color", schrift_farbe)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	return b

# Reiter (Pille); aktiv = Cyan
static func reiter(t: String, aktiv: bool) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", schrift(true))
	b.add_theme_font_size_override("font_size", 15)
	for z in ["normal", "hover", "pressed"]:
		var sb := box(AKZENT if aktiv else Color(1, 1, 1, 0.1 if z != "hover" else 0.18), Color(0, 0, 0, 0), 8, 14)
		b.add_theme_stylebox_override(z, sb)
	var fc := AKZENT_DUNKEL if aktiv else TEXT
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, fc)
	return b

# Karte: Symbol-Kachel, Titel + Text (+ Stufen-Punkte), rechts ein Knopf
static func karte(titel: String, info: String, knopf_n: Control, kurz := "", farbe: Color = AKZENT, stufe := -1, max_stufe := 0, bild: Texture2D = null) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(KARTE, KARTE_RAND, 10, 12))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	p.add_child(hb)
	if kurz != "":
		var kachel := PanelContainer.new()
		var ks := box(Color(farbe, 0.2), Color(farbe, 0.45), 8, 0)
		kachel.add_theme_stylebox_override("panel", ks)
		kachel.custom_minimum_size = Vector2(44, 44)
		kachel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if bild:
			kachel.custom_minimum_size = Vector2(56, 56)
			var tr := TextureRect.new()
			tr.texture = bild
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			kachel.add_child(tr)
		else:
			var kl := text(kurz, 15, farbe, true)
			kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			kachel.add_child(kl)
		hb.add_child(kachel)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 1)
	vb.add_child(text(titel, 17, TEXT, true))
	if info != "":
		var l := text(info, 13, TEXT_LEISE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(380, 0)
		vb.add_child(l)
	if max_stufe > 0:
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 3)
		for i in mini(max_stufe, 27):
			var r := ColorRect.new()
			r.custom_minimum_size = Vector2(10 if max_stufe <= 10 else 6, 5)
			r.color = AKZENT if i < stufe else Color(1, 1, 1, 0.15)
			pips.add_child(r)
		vb.add_child(pips)
	hb.add_child(vb)
	knopf_n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(knopf_n)
	return p

static func ueberschrift(t: String) -> Label:
	return text(t, 13, TEXT_LEISE, true)

# Schieberegler (0..1 oder min..max) im Glas-Stil
static func regler(wert: float, von := 0.0, bis := 1.0, schritt := 0.05) -> HSlider:
	var s := HSlider.new()
	s.min_value = von
	s.max_value = bis
	s.step = schritt
	s.value = wert
	s.custom_minimum_size = Vector2(220, 30)
	s.focus_mode = Control.FOCUS_NONE
	var bahn := box(Color(1, 1, 1, 0.14), Color(0, 0, 0, 0), 4, 0)
	bahn.content_margin_top = 3
	bahn.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", bahn)
	var voll := box(AKZENT, Color(0, 0, 0, 0), 4, 0)
	voll.content_margin_top = 3
	voll.content_margin_bottom = 3
	s.add_theme_stylebox_override("grabber_area", voll)
	s.add_theme_stylebox_override("grabber_area_highlight", voll)
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	for y in 18:
		for x in 18:
			var r := Vector2(x - 8.5, y - 8.5).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(8.6 - r, 0.0, 1.0)))
	var t := ImageTexture.create_from_image(img)
	s.add_theme_icon_override("grabber", t)
	s.add_theme_icon_override("grabber_highlight", t)
	return s

# Reihe von Pillen-Knöpfen (eine davon gewählt). Gibt das HBox zurück; wahl(i) wird beim Klick gerufen.
static func auswahl(namen: Array, gewaehlt: int, wahl: Callable) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	for i in namen.size():
		var b := reiter(str(namen[i]), i == gewaehlt)
		b.name = "w_%d" % i
		b.pressed.connect(wahl.bind(i))
		hb.add_child(b)
	return hb
