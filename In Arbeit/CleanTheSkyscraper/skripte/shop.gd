class_name Shop
extends CanvasLayer
# Werkstatt: Werkzeuge kaufen/ausrüsten, Gondel-Upgrades, Seilwinde. Öffnen/Schließen mit Tab.

signal geaendert
signal neues_spiel

var wirtschaft: Wirtschaft
var fenster: PanelContainer
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
	vb.add_child(liste)
	var fuss := HBoxContainer.new()
	vb.add_child(fuss)
	var hinweis := _text("Tab oder Esc: schließen · Zahlen 1–5: Werkzeug wechseln", 14, "2b5b8f")
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
	for c in liste.get_children():
		c.queue_free()
	geld_label.text = "%s €" % Hud.punkte(wirtschaft.geld)
	liste.add_child(_ueberschrift("Werkzeuge"))
	for i in Wirtschaft.WERKZEUGE.size():
		var w: Dictionary = Wirtschaft.WERKZEUGE[i]
		var hat: bool = w.id in wirtschaft.besitz
		var knopf: Button
		if wirtschaft.aktiv == w.id:
			knopf = _knopf("In der Hand", Color("2e8b3d"))
			knopf.disabled = true
		elif hat:
			knopf = _knopf("Nehmen", Color("1f5fae"))
			knopf.pressed.connect(_nehmen.bind(w.id))
		else:
			knopf = _knopf("Kaufen · %s €" % Hud.punkte(int(w.preis)), Color("e08a1e"))
			knopf.disabled = wirtschaft.geld < int(w.preis)
			knopf.pressed.connect(_kaufe_werkzeug.bind(w.id))
		knopf.name = "wz_" + w.id
		liste.add_child(_zeile("%d  %s" % [i + 1, w.name], w.text, knopf))
	liste.add_child(_ueberschrift("Gondel"))
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

func _kaufe_upgrade(id: String) -> void:
	if wirtschaft.kaufe_upgrade(id):
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
