class_name Album
extends CanvasLayer
# Sammelalbum: welche Szenen hinter den Fenstern schon entdeckt wurden. Öffnen/Schließen mit B.

var wirtschaft: Wirtschaft
var raster: GridContainer
var titel_zahl: Label
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
	var t := _text("SAMMELALBUM", 30, "1f5fae")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(t)
	titel_zahl = _text("", 22, "2e8b3d")
	kopf.add_child(titel_zahl)
	vb.add_child(_text("Hinter manchen Fenstern passiert etwas – putz sie sauber, um es zu entdecken.", 14, "2b5b8f"))
	raster = GridContainer.new()
	raster.columns = 2
	raster.add_theme_constant_override("h_separation", 16)
	raster.add_theme_constant_override("v_separation", 8)
	vb.add_child(raster)
	vb.add_child(_text("B oder Esc: schließen", 14, "2b5b8f"))
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

func aufbauen() -> void:
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
