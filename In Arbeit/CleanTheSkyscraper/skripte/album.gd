class_name Album
extends CanvasLayer
# Sammelalbum (Taste B) mit zwei Reitern: „Szenen“ (was hinter den Fenstern entdeckt wurde) und „Fische“ (Fisch-Index:
# gefangene Fische mit Bild und größter Länge, fehlende als Umriss). Reiter per Klick oder Tab/Q/1/2 wechseln.

var wirtschaft: Wirtschaft
var raster: GridContainer
var titel_zahl: Label
var titel: Label
var unter: Label
var reiter_leiste: HBoxContainer
var fische_raster: GridContainer
var fuss: Label
var reiter := 0                 # 0 Szenen, 1 Fische
var offen := false

func setup(w: Wirtschaft) -> void:
	wirtschaft = w
	layer = 10
	var hinter := ColorRect.new()
	hinter.color = Color(0.05, 0.12, 0.22, 0.45)
	hinter.set_anchors_preset(Control.PRESET_FULL_RECT)
	hinter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hinter)
	var fenster := PanelContainer.new()
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
	fenster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hinter.add_child(fenster)
	for k in ["anchor_left", "anchor_right", "anchor_top", "anchor_bottom"]:
		fenster.set(k, 0.5)
	fenster.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fenster.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	fenster.add_child(vb)
	var kopf := HBoxContainer.new()
	vb.add_child(kopf)
	titel = _text("SAMMELALBUM", 30, "1f5fae")
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(titel)
	titel_zahl = _text("", 22, "2e8b3d")
	kopf.add_child(titel_zahl)
	reiter_leiste = HBoxContainer.new()
	reiter_leiste.add_theme_constant_override("separation", 8)
	vb.add_child(reiter_leiste)
	for i in 2:
		var b := Button.new()
		b.name = "reiter_%d" % i
		b.text = ["Szenen", "Fische"][i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(140, 34)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(func():
			reiter = i
			aufbauen())
		reiter_leiste.add_child(b)
	unter = _text("", 14, "2b5b8f")
	vb.add_child(unter)
	raster = GridContainer.new()
	raster.columns = 2
	raster.add_theme_constant_override("h_separation", 16)
	raster.add_theme_constant_override("v_separation", 8)
	vb.add_child(raster)
	fische_raster = GridContainer.new()
	fische_raster.columns = 5
	fische_raster.add_theme_constant_override("h_separation", 10)
	fische_raster.add_theme_constant_override("v_separation", 8)
	vb.add_child(fische_raster)
	fuss = _text("B oder Esc: schließen · Tab: Reiter wechseln", 14, "2b5b8f")
	vb.add_child(fuss)
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
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func umschalten() -> void:
	offen = not offen
	visible = offen
	if offen:
		aufbauen()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(e: InputEvent) -> void:
	if offen and e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_TAB, KEY_Q, KEY_1, KEY_2, KEY_LEFT, KEY_RIGHT]:
		reiter = {KEY_1: 0, KEY_2: 1}.get(e.keycode, 1 - reiter)
		aufbauen()
		get_viewport().set_input_as_handled()

func aufbauen() -> void:
	for i in 2:
		var b: Button = reiter_leiste.get_child(i)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("1f5fae") if i == reiter else Color("dbe7f3")
		sb.set_corner_radius_all(9)
		for z in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(z, sb)
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, Color.WHITE if i == reiter else Color("1f5fae"))
	raster.visible = reiter == 0
	fische_raster.visible = reiter == 1
	if reiter == 1:
		_fische()
		return
	unter.text = "Hinter manchen Fenstern passiert etwas – putz sie sauber, um es zu entdecken."
	for c in raster.get_children():
		c.queue_free()
	var gefunden := 0
	for typ in range(1, FensterZustand.SZENEN.size()):
		var n: int = wirtschaft.album.get(str(typ), 0)
		if n > 0:
			gefunden += 1
		var karte := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("e7f3fb") if n > 0 else Color("eceff2")
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		karte.add_theme_stylebox_override("panel", sb)
		karte.custom_minimum_size = Vector2(330, 0)
		karte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var zeile := HBoxContainer.new()
		karte.add_child(zeile)
		var name_l := _text("%d  %s" % [typ, FensterZustand.SZENEN[typ] if n > 0 else "???"], 18, "123a6b" if n > 0 else "9aa8b6")
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zeile.add_child(name_l)
		zeile.add_child(_text("%d×" % n if n > 0 else "", 16, "2e8b3d"))
		raster.add_child(karte)
	titel_zahl.text = "%d / %d entdeckt" % [gefunden, FensterZustand.SZENEN.size() - 1]

# Fisch-Index: 20 Karten (Bild bzw. Umriss, Name, größte Länge, Anzahl)
func _fische() -> void:
	for c in fische_raster.get_children():
		fische_raster.remove_child(c)
		c.queue_free()
	var n_da := 0
	for i in Wirtschaft.FISCHE.size():
		var f: Dictionary = Wirtschaft.FISCHE[i]
		var e: Dictionary = wirtschaft.fisch_index.get(f.id, {})
		var da := not e.is_empty()
		if da:
			n_da += 1
		var karte := PanelContainer.new()
		karte.name = "fisch_" + str(f.id)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("e7f3fb") if da else Color("eceff2")
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		karte.add_theme_stylebox_override("panel", sb)
		karte.custom_minimum_size = Vector2(150, 0)
		karte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		karte.add_child(vb)
		var bild := TextureRect.new()
		bild.texture = Symbole.bilder.get(("f_" if da else "fu_") + str(f.id))
		bild.custom_minimum_size = Vector2(138, 62)
		bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not da:
			bild.modulate = Color(1, 1, 1, 0.55)
		vb.add_child(bild)
		var nm := _text("%d  %s" % [i + 1, f.name if da else "???"], 13, "123a6b" if da else "9aa8b6")
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size = Vector2(138, 0)
		vb.add_child(nm)
		var info := ("bis %s · %d×" % [Fische.laenge_text(float(e.max)), int(e.n)]) if da else ("Chance %s %%" % str(f.chance).replace(".", ","))
		vb.add_child(_text(info, 12, "2e8b3d" if da else "9aa8b6"))
		fische_raster.add_child(karte)
	titel_zahl.text = "%d / %d Fische" % [n_da, Wirtschaft.FISCHE.size()]
	unter.text = ("Alle 20 gefangen – deine Yacht liegt am Steg!" if wirtschaft.yacht else "Fang alle 20 Fische (Steg am Strand, Fischladen) – dann bekommst du eine eigene Yacht!")
