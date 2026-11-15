class_name HaendlerMenu
extends CanvasLayer
# Menü eines Marktstands: Boosts kaufen (Putzmittel, Snacks) oder Aussehen kaufen/anziehen (Mode & Farben).

signal geaendert

var wirtschaft: Wirtschaft
var liste: VBoxContainer
var titel: Label
var geld_label: Label
var stand := ""
var offen := false

func setup(w: Wirtschaft) -> void:
	wirtschaft = w
	layer = 10
	var hinter := ColorRect.new()
	hinter.color = Color(0.05, 0.12, 0.22, 0.45)
	hinter.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hinter)
	var fenster := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.99, 0.97, 0.97)
	sb.border_color = Color("e08a1e")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	fenster.add_theme_stylebox_override("panel", sb)
	fenster.custom_minimum_size = Vector2(720, 0)
	hinter.add_child(fenster)
	for k in ["anchor_left", "anchor_right", "anchor_top", "anchor_bottom"]:
		fenster.set(k, 0.5)
	fenster.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fenster.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	fenster.add_child(vb)
	var kopf := HBoxContainer.new()
	vb.add_child(kopf)
	titel = _text("", 30, "c86a10")
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(titel)
	geld_label = _text("", 26, "2e8b3d")
	kopf.add_child(geld_label)
	liste = VBoxContainer.new()
	liste.add_theme_constant_override("separation", 6)
	vb.add_child(liste)
	vb.add_child(_text("E oder Esc: schließen", 14, "2b5b8f"))
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
	for z in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = farbe if z != "disabled" else Color("b9c4cf")
		if z == "hover":
			sb.bg_color = farbe.lightened(0.15)
		sb.set_corner_radius_all(10)
		b.add_theme_stylebox_override(z, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("eef3f7"))
	return b

func oeffnen(stand_id: String, name: String) -> void:
	stand = stand_id
	titel.text = name.to_upper()
	offen = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	aufbauen()

func schliessen() -> void:
	offen = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func aufbauen() -> void:
	for c in liste.get_children():
		c.queue_free()
	geld_label.text = "%s €" % Hud.punkte(wirtschaft.geld)
	if stand == "werkzeug" or stand == "grund":
		var profi := stand == "werkzeug"
		liste.add_child(_text("PROFI-WERKZEUGE – mit 6–0 oder dem Mausrad wählen" if profi else "WERKZEUGE – mit 1–5 oder dem Mausrad wählen", 15, "7a9cc0"))
		for i in Wirtschaft.WERKZEUGE.size():
			var w: Dictionary = Wirtschaft.WERKZEUGE[i]
			if bool(w.get("profi", false)) != profi:
				continue
			var knopf: Button
			if wirtschaft.aktiv == w.id:
				knopf = _knopf("In der Hand", Color("2e8b3d"))
				knopf.disabled = true
			elif w.id in wirtschaft.besitz:
				knopf = _knopf("Nehmen", Color("1f5fae"))
				knopf.pressed.connect(_nehmen.bind(w.id))
			else:
				knopf = _knopf("Kaufen · %s €" % Hud.punkte(int(w.preis)), Color("e08a1e"))
				knopf.disabled = wirtschaft.geld < int(w.preis)
				knopf.pressed.connect(_kaufe_werkzeug.bind(w.id))
			knopf.name = "w_" + w.id
			var info: String = w.text + "  (Taste %d)" % ((i + 1) % 10)
			liste.add_child(_zeile(w.name, info, knopf, Color(w.get("farbe", "00000000")) if w.has("farbe") else Color.TRANSPARENT))
	elif stand == "fahrzeug":
		liste.add_child(_text("FAHRZEUGE – zu Fuß mit 1–4 oder dem Mausrad wählen", 15, "7a9cc0"))
		for f in Wirtschaft.FAHRZEUGE:
			var knopf: Button
			if wirtschaft.fahrzeug == f.id:
				knopf = _knopf("Absteigen", Color("2e8b3d"))
				knopf.pressed.connect(_fahrzeug_nehmen.bind(""))
			elif f.id in wirtschaft.fahrzeuge:
				knopf = _knopf("Aufsteigen", Color("1f5fae"))
				knopf.pressed.connect(_fahrzeug_nehmen.bind(f.id))
			else:
				knopf = _knopf("Kaufen · %s €" % Hud.punkte(int(f.preis)), Color("e08a1e"))
				knopf.disabled = wirtschaft.geld < int(f.preis)
				knopf.pressed.connect(_kaufe_fahrzeug.bind(f.id))
			knopf.name = "f_" + f.id
			liste.add_child(_zeile(f.name, f.text, knopf, Color(f.farbe)))
	elif stand == "mode":
		for art in ["gondel", "kleidung", "schwamm"]:
			liste.add_child(_text({"gondel": "GONDEL", "kleidung": "ARBEITSKLEIDUNG", "schwamm": "SCHWAMM"}[art], 15, "7a9cc0"))
			for k in Wirtschaft.KOSMETIK:
				if k.art != art:
					continue
				var knopf: Button
				if wirtschaft.kosmetik_aktiv[art] == k.id:
					knopf = _knopf("Trage ich", Color("2e8b3d"))
					knopf.disabled = true
				elif k.id in wirtschaft.kosmetik_besitz:
					knopf = _knopf("Anziehen", Color("1f5fae"))
					knopf.pressed.connect(_nutzen.bind(k.id))
				else:
					knopf = _knopf("Kaufen · %s €" % Hud.punkte(int(k.preis)), Color("e08a1e"))
					knopf.disabled = wirtschaft.geld < int(k.preis)
					knopf.pressed.connect(_kaufe_kosmetik.bind(k.id))
				knopf.name = "k_" + k.id
				liste.add_child(_zeile(k.name, "", knopf, Color(k.farbe)))
	else:
		for id in Wirtschaft.BOOSTS:
			var b: Dictionary = Wirtschaft.BOOSTS[id]
			if b.stand != stand:
				continue
			var rest := float(wirtschaft.boosts.get(id, 0.0))
			var info: String = b.text
			if rest > 0.0:
				info += "  Läuft noch %d:%02d." % [int(rest) / 60, int(rest) % 60]
			var knopf2 := _knopf(("Verlängern · %s €" if rest > 0.0 else "Kaufen · %s €") % Hud.punkte(wirtschaft.boost_preis(id)), Color("e08a1e"))
			knopf2.disabled = wirtschaft.geld < wirtschaft.boost_preis(id)
			knopf2.pressed.connect(_kaufe_boost.bind(id))
			knopf2.name = "b_" + id
			liste.add_child(_zeile(b.name, info, knopf2, Color.TRANSPARENT))

func _zeile(t: String, text: String, knopf: Button, farbe: Color) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	if farbe.a > 0.0:
		var muster := ColorRect.new()
		muster.color = farbe
		muster.custom_minimum_size = Vector2(28, 28)
		muster.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(muster)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	vb.add_child(_text(t, 19, "123a6b"))
	if text != "":
		var l := _text(text, 13, "2b5b8f")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(440, 0)
		vb.add_child(l)
	hb.add_child(vb)
	hb.add_child(knopf)
	return hb

func _kaufe_fahrzeug(id: String) -> void:
	if wirtschaft.kaufe_fahrzeug(id):
		geaendert.emit()
	aufbauen()

func _fahrzeug_nehmen(id: String) -> void:
	wirtschaft.fahrzeug = id
	geaendert.emit()
	aufbauen()

func _kaufe_werkzeug(id: String) -> void:
	if wirtschaft.kaufe_werkzeug(id):
		geaendert.emit()
	aufbauen()

func _nehmen(id: String) -> void:
	wirtschaft.ausruesten(id)
	geaendert.emit()
	aufbauen()

func _kaufe_boost(id: String) -> void:
	if wirtschaft.kaufe_boost(id):
		geaendert.emit()
	aufbauen()

func _kaufe_kosmetik(id: String) -> void:
	if wirtschaft.kaufe_kosmetik(id):
		geaendert.emit()
	aufbauen()

func _nutzen(id: String) -> void:
	wirtschaft.nutze_kosmetik(id)
	geaendert.emit()
	aufbauen()
