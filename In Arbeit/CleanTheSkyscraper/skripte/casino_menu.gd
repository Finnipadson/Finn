class_name CasinoMenu
extends CanvasLayer
# Fenster der vier Casino-Spiele (Blackjack, Glücksrad, Einarmiger Bandit, Rubbellos).
# Regeln und Zahlen stehen in casino_regeln.gd. Der Einsatz wird beim Start einer Runde abgezogen,
# der Gewinn am Ende gutgeschrieben. Wer das Fenster mitten in einer Runde schließt, bekommt das Ergebnis sofort.

signal gespielt                  # eine Runde ist abgerechnet → HUD aktualisieren, speichern

var wirtschaft: Wirtschaft
var offen := false
var spiel := ""
var einsatz := 10
var laeuft := false              # Runde ist im Gange
var schnell := false             # Tests: kurze Animationen
var rng := RandomNumberGenerator.new()
var letzter_gewinn := 0          # Auszahlung der letzten Runde (für Tests)
var letzter_faktor := 0.0

var titel: Label
var geld_label: Label
var inhalt: VBoxContainer
var knoepfe: HBoxContainer
var ergebnis: Label
var einsatz_label: Label
var b_minus: Button
var b_plus: Button
var b_max: Button
var _tween: Tween
static var _font: SystemFont

# Blackjack
var bj_spieler: Array = []
var bj_geber: Array = []
var bj_verdeckt := false
var bj_reihe_g: HBoxContainer
var bj_reihe_s: HBoxContainer
var bj_wert_g: Label
var bj_wert_s: Label
# Glücksrad
var rad: Rad
var rad_feld := 0
# Bandit
var walzen: Array = []
var walzen_ziel: Array = []
# Rubbellos
var los: Los

static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Segoe UI Black", "Arial Black", "Segoe UI"])
		_font.font_weight = 900
	return _font

func setup(w: Wirtschaft) -> void:
	wirtschaft = w
	rng.randomize()
	layer = 10
	var hinter := ColorRect.new()
	hinter.color = Color(0.08, 0.02, 0.06, 0.6)
	hinter.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hinter)
	var fenster := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1d1420")
	sb.border_color = Color("d9a441")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	fenster.add_theme_stylebox_override("panel", sb)
	fenster.custom_minimum_size = Vector2(800, 0)
	hinter.add_child(fenster)
	for k in ["anchor_left", "anchor_right", "anchor_top", "anchor_bottom"]:
		fenster.set(k, 0.5)
	fenster.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fenster.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	fenster.add_child(vb)
	var kopf := HBoxContainer.new()
	vb.add_child(kopf)
	titel = _text("", 30, "f2c230")
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(titel)
	geld_label = _text("", 26, "7fe08a")
	kopf.add_child(geld_label)
	inhalt = VBoxContainer.new()
	inhalt.add_theme_constant_override("separation", 6)
	inhalt.custom_minimum_size = Vector2(0, 330)
	inhalt.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(inhalt)
	ergebnis = _text("", 22, "ffffff")
	ergebnis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ergebnis.custom_minimum_size = Vector2(0, 34)
	vb.add_child(ergebnis)
	# Einsatz wählen
	var zeile := HBoxContainer.new()
	zeile.alignment = BoxContainer.ALIGNMENT_CENTER
	zeile.add_theme_constant_override("separation", 10)
	vb.add_child(zeile)
	b_minus = _knopf("−", Color("5a4a66"), 46)
	b_minus.name = "b_minus"
	b_minus.pressed.connect(_einsatz_schritt.bind(-1))
	zeile.add_child(b_minus)
	einsatz_label = _text("", 20, "ffffff")
	einsatz_label.custom_minimum_size = Vector2(330, 0)
	einsatz_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zeile.add_child(einsatz_label)
	b_plus = _knopf("+", Color("5a4a66"), 46)
	b_plus.name = "b_plus"
	b_plus.pressed.connect(_einsatz_schritt.bind(1))
	zeile.add_child(b_plus)
	b_max = _knopf("Max", Color("5a4a66"), 70)
	b_max.name = "b_max"
	b_max.pressed.connect(_einsatz_schritt.bind(99))
	zeile.add_child(b_max)
	knoepfe = HBoxContainer.new()
	knoepfe.alignment = BoxContainer.ALIGNMENT_CENTER
	knoepfe.add_theme_constant_override("separation", 12)
	vb.add_child(knoepfe)
	var fuss := _text("Nur Spielgeld · E oder Esc: schließen", 13, "b9a9c9")
	fuss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(fuss)
	visible = false

func _text(t: String, g: int, farbe: String) -> Label:
	var l := Label.new()
	l.text = t
	var ls := LabelSettings.new()
	ls.font_size = g
	ls.font_color = Color(farbe)
	ls.font = font()
	l.label_settings = ls
	return l

func _knopf(t: String, farbe: Color, breit := 190) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(breit, 42)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	for z in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = farbe if z != "disabled" else Color("3d3644")
		if z == "hover":
			sb.bg_color = farbe.lightened(0.15)
		sb.set_corner_radius_all(10)
		b.add_theme_stylebox_override(z, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("8a8292"))
	return b

func _aktion(name: String, t: String, farbe: String, ziel: Callable) -> Button:
	var b := _knopf(t, Color(farbe), 210)
	b.name = name
	b.pressed.connect(ziel)
	knoepfe.add_child(b)
	return b

# ---------------------------------------------------------------- Öffnen / Schließen
func oeffnen(id: String, name: String) -> void:
	spiel = id
	titel.text = name.to_upper()
	offen = true
	visible = true
	laeuft = false
	ergebnis.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in inhalt.get_children() + knoepfe.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	einsatz = clampi(einsatz, CasinoRegeln.EINSATZ_MIN, maxi(CasinoRegeln.max_einsatz(wirtschaft.geld), CasinoRegeln.EINSATZ_MIN))
	match spiel:
		"blackjack": _bj_bauen()
		"rad": _rad_bauen()
		"bandit": _bandit_bauen()
		"los": _los_bauen()
	_anzeige()

func schliessen() -> void:
	if laeuft:
		_sofort()
	offen = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# laufende Runde sofort zu Ende bringen (Fenster wird geschlossen)
func _sofort() -> void:
	if _tween:
		_tween.kill()
	match spiel:
		"blackjack": _bj_stehen()
		"rad": _rad_fertig()
		"bandit": _bandit_fertig()
		"los": los.aufdecken()

# ---------------------------------------------------------------- Einsatz und Geld
func _einsatz_schritt(richtung: int) -> void:
	if laeuft:
		return
	var grenze := CasinoRegeln.max_einsatz(wirtschaft.geld)
	if richtung == 99:
		einsatz = grenze
	else:
		var neu := einsatz
		if richtung > 0:
			for s in CasinoRegeln.STUFEN:
				if int(s) > einsatz:
					neu = int(s)
					break
		else:
			for s in CasinoRegeln.STUFEN:
				if int(s) < einsatz:
					neu = int(s)
		einsatz = mini(neu, grenze)
	einsatz = maxi(einsatz, CasinoRegeln.EINSATZ_MIN)
	_anzeige()

func _anzeige() -> void:
	var grenze := CasinoRegeln.max_einsatz(wirtschaft.geld)
	geld_label.text = "%s €" % Hud.punkte(wirtschaft.geld)
	if grenze == 0 and not laeuft:
		einsatz_label.text = "Zu wenig Geld (mindestens %d €)" % CasinoRegeln.EINSATZ_MIN
	else:
		einsatz_label.text = "Einsatz: %s €   (höchstens %s €)" % [Hud.punkte(einsatz), Hud.punkte(maxi(grenze, einsatz))]
	b_minus.disabled = laeuft or einsatz <= CasinoRegeln.EINSATZ_MIN
	b_plus.disabled = laeuft or einsatz >= grenze
	b_max.disabled = laeuft or einsatz >= grenze
	var kann := not laeuft and grenze > 0
	for b in knoepfe.get_children():
		match String(b.name):
			"b_austeilen", "b_drehen", "b_hebel", "b_kaufen": b.disabled = not kann
			"b_ziehen", "b_stehen", "b_aufdecken": b.disabled = not laeuft
	var kauf := knoepfe.get_node_or_null("b_kaufen") as Button
	if kauf:
		kauf.text = "Los kaufen · %s €" % Hud.punkte(einsatz)

# Einsatz abziehen und Runde starten
func _zahle() -> bool:
	var grenze := CasinoRegeln.max_einsatz(wirtschaft.geld)
	if laeuft or grenze == 0:
		return false
	einsatz = clampi(einsatz, CasinoRegeln.EINSATZ_MIN, grenze)
	wirtschaft.geld -= einsatz
	laeuft = true
	ergebnis.text = ""
	_anzeige()
	return true

# Runde abrechnen: faktor × Einsatz wird ausgezahlt
func _abrechnen(faktor: float, text: String) -> void:
	var aus := int(round(einsatz * faktor))
	wirtschaft.geld += aus
	letzter_gewinn = aus
	letzter_faktor = faktor
	laeuft = false
	var netto := aus - einsatz
	var farbe := Color("ffffff")
	if netto > 0:
		text += "  Gewonnen: +%s €" % Hud.punkte(netto)
		farbe = Color("7fe08a")
	elif netto == 0:
		text += "  Einsatz zurück."
	else:
		text += "  Verloren: −%s €" % Hud.punkte(-netto)
		farbe = Color("ff8a8a")
	ergebnis.text = text.strip_edges()
	ergebnis.label_settings.font_color = farbe
	einsatz = clampi(einsatz, CasinoRegeln.EINSATZ_MIN, maxi(CasinoRegeln.max_einsatz(wirtschaft.geld), CasinoRegeln.EINSATZ_MIN))
	_anzeige()
	gespielt.emit()

# ---------------------------------------------------------------- 1 Blackjack
func _bj_bauen() -> void:
	bj_spieler = []
	bj_geber = []
	inhalt.add_child(_mitte(_text("GEBER  (zieht bis 17)", 15, "b9a9c9")))
	bj_reihe_g = _kartenreihe()
	bj_wert_g = _text("", 18, "ffffff")
	inhalt.add_child(_mitte(bj_wert_g))
	inhalt.add_child(_mitte(_text("DU", 15, "b9a9c9")))
	bj_reihe_s = _kartenreihe()
	bj_wert_s = _text("", 18, "ffffff")
	inhalt.add_child(_mitte(bj_wert_s))
	inhalt.add_child(_mitte(_text("Näher an 21 als der Geber gewinnt den doppelten Einsatz · Blackjack (Ass + 10) zahlt 3:2 · über 21 verliert", 13, "b9a9c9")))
	_aktion("b_austeilen", "Austeilen", "2e8b3d", _bj_austeilen)
	_aktion("b_ziehen", "Karte ziehen", "1f5fae", _bj_ziehen)
	_aktion("b_stehen", "Stehen bleiben", "c86a10", _bj_stehen)

func _mitte(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c

func _kartenreihe() -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	hb.custom_minimum_size = Vector2(0, 96)
	inhalt.add_child(hb)
	return hb

func _karte(k: Dictionary, verdeckt: bool) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1f5fae") if verdeckt else Color("fbf8ef")
	sb.border_color = Color("d9a441") if verdeckt else Color("b9b2a2")
	sb.set_border_width_all(3 if verdeckt else 2)
	sb.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(66, 92)
	if not verdeckt:
		var rot := int(k.farbe) == 1 or int(k.farbe) == 2
		var l := _text("%s\n%s" % [CasinoRegeln.RAENGE[int(k.rang)], CasinoRegeln.FARBEN[int(k.farbe)]], 24, "c8202c" if rot else "1b1e2a")
		l.label_settings.line_spacing = -6
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
	return p

func _bj_zeigen() -> void:
	for c in bj_reihe_g.get_children() + bj_reihe_s.get_children():
		c.queue_free()
	for i in bj_geber.size():
		bj_reihe_g.add_child(_karte(bj_geber[i], bj_verdeckt and i == 1))
	for k in bj_spieler:
		bj_reihe_s.add_child(_karte(k, false))
	if bj_geber.is_empty():
		bj_wert_g.text = ""
		bj_wert_s.text = ""
		return
	bj_wert_g.text = ("zeigt %d" % CasinoRegeln.wert([bj_geber[0]])) if bj_verdeckt else "%d" % CasinoRegeln.wert(bj_geber)
	bj_wert_s.text = "%d" % CasinoRegeln.wert(bj_spieler)

func _bj_austeilen() -> void:
	if not _zahle():
		return
	bj_spieler = [CasinoRegeln.karte(rng), CasinoRegeln.karte(rng)]
	bj_geber = [CasinoRegeln.karte(rng), CasinoRegeln.karte(rng)]
	bj_verdeckt = true
	if CasinoRegeln.ist_blackjack(bj_spieler) or CasinoRegeln.ist_blackjack(bj_geber):
		_bj_ende()
	else:
		_bj_zeigen()

func _bj_ziehen() -> void:
	if not laeuft or spiel != "blackjack":
		return
	bj_spieler.append(CasinoRegeln.karte(rng))
	var w := CasinoRegeln.wert(bj_spieler)
	if w > 21:
		_bj_ende()
	elif w == 21:
		_bj_stehen()
	else:
		_bj_zeigen()

func _bj_stehen() -> void:
	if not laeuft or spiel != "blackjack":
		return
	CasinoRegeln.geber_zieht(bj_geber, rng)
	_bj_ende()

func _bj_ende() -> void:
	bj_verdeckt = false
	_bj_zeigen()
	var f := CasinoRegeln.bj_auszahlung(bj_spieler, bj_geber)
	var s := CasinoRegeln.wert(bj_spieler)
	var g := CasinoRegeln.wert(bj_geber)
	var text := ""
	if s > 21:
		text = "Über 21 – überkauft."
	elif f == 2.5:
		text = "Blackjack!"
	elif CasinoRegeln.ist_blackjack(bj_geber):
		text = "Der Geber hat Blackjack." if f == 0.0 else "Beide haben Blackjack."
	elif g > 21:
		text = "Der Geber hat sich überkauft."
	elif f == 1.0:
		text = "Unentschieden mit %d." % s
	else:
		text = "%d gegen %d." % [s, g]
	_abrechnen(f, text)

# ---------------------------------------------------------------- 2 Glücksrad
func _rad_bauen() -> void:
	rad = Rad.new()
	rad.custom_minimum_size = Vector2(330, 330)
	inhalt.add_child(_mitte(rad))
	_aktion("b_drehen", "Rad drehen", "c86a10", _rad_drehen)

func _rad_drehen() -> void:
	if not _zahle():
		return
	var n := CasinoRegeln.RAD.size()
	var s := TAU / n
	rad_feld = rng.randi() % n
	var ziel := -(rad_feld + 0.5 + rng.randf_range(-0.35, 0.35)) * s
	var ende := rad.winkel + TAU * (2 if schnell else 5) + fposmod(ziel - rad.winkel, TAU)
	_tween = create_tween()
	_tween.tween_property(rad, "winkel", ende, 0.5 if schnell else 4.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_rad_fertig)

func _rad_fertig() -> void:
	if not laeuft or spiel != "rad":
		return
	var s := TAU / CasinoRegeln.RAD.size()
	if rad.feld() != rad_feld:          # Fenster wurde mitten im Drehen geschlossen
		rad.winkel = -(rad_feld + 0.5) * s
	var m := float(CasinoRegeln.RAD[rad_feld])
	_abrechnen(m, "Das Rad zeigt %s." % CasinoRegeln.mal(m))

class Rad extends Control:
	var winkel := 0.0:
		set(v):
			winkel = v
			queue_redraw()

	# Feld unter dem Zeiger (oben)
	func feld() -> int:
		var n := CasinoRegeln.RAD.size()
		return int(fposmod(-winkel, TAU) / (TAU / n)) % n

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 14.0
		var n := CasinoRegeln.RAD.size()
		var s := TAU / n
		draw_circle(c, r + 8.0, Color("d9a441"))
		for i in n:
			var m := float(CasinoRegeln.RAD[i])
			var a0 := winkel + i * s - PI / 2.0
			var pts := PackedVector2Array([c])
			for k in 5:
				var a := a0 + s * k / 4.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, CasinoRegeln.rad_farbe(m))
			draw_line(c, c + Vector2(cos(a0), sin(a0)) * r, Color("f6f3ea"), 1.5, true)
		var f := CasinoMenu.font()
		for i in n:
			var m2 := float(CasinoRegeln.RAD[i])
			var am := winkel + (i + 0.5) * s
			draw_set_transform(c, am, Vector2.ONE)
			var t := "0" if m2 == 0.0 else CasinoRegeln.mal(m2)
			var gr := 13 if m2 > 0.0 else 11
			var b := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, gr).x
			draw_string(f, Vector2(-b * 0.5, -r + 20.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, gr, Color.WHITE if m2 > 0.0 else Color("8a93a3"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(c, 26.0, Color("d9a441"))
		draw_circle(c, 18.0, Color("1d1420"))
		var o := c + Vector2(0, -r - 12.0)
		draw_colored_polygon(PackedVector2Array([o + Vector2(-13, 0), o + Vector2(13, 0), o + Vector2(0, 30)]), Color("ff3b30"))
		draw_polyline(PackedVector2Array([o + Vector2(-13, 0), o + Vector2(13, 0), o + Vector2(0, 30), o + Vector2(-13, 0)]), Color.WHITE, 2.0, true)

# ---------------------------------------------------------------- 3 Einarmiger Bandit
func _bandit_bauen() -> void:
	walzen = []
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	inhalt.add_child(hb)
	for i in 3:
		var w := Walze.new()
		w.custom_minimum_size = Vector2(150, 190)
		w.pos = float(i + 1)
		hb.add_child(w)
		walzen.append(w)
	var d := CasinoRegeln.DREI
	inhalt.add_child(_mitte(_text("3× Gondel %d×  ·  3× Fenster %d×  ·  3× Eimer %d×  ·  3× Schwamm %d×" % [int(d.gondel), int(d.fenster), int(d.eimer), int(d.schwamm)], 15, "f2c230")))
	inhalt.add_child(_mitte(_text("2 gleiche: halber Einsatz zurück  ·  Tauben bringen nichts", 13, "b9a9c9")))
	_aktion("b_hebel", "Hebel ziehen", "c8202c", _bandit_start)

func _bandit_start() -> void:
	if not _zahle():
		return
	walzen_ziel = [rng.randi() % 5, rng.randi() % 5, rng.randi() % 5]
	_tween = create_tween()
	_tween.set_parallel(true)
	var lang := 0.0
	for i in 3:
		var w: Walze = walzen[i]
		var start: float = ceilf(w.pos) + 10.0 + i * 5.0
		var ende: float = start + posmod(int(walzen_ziel[i]) - int(start), 5)
		var dauer: float = (0.25 + i * 0.12) if schnell else (1.1 + i * 0.6)
		lang = dauer
		_tween.tween_property(w, "pos", ende, dauer).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(0.05)
	_tween.chain().tween_callback(_bandit_fertig)

func _bandit_fertig() -> void:
	if not laeuft or spiel != "bandit":
		return
	for i in 3:
		var w: Walze = walzen[i]
		if w.symbol() != int(walzen_ziel[i]):
			w.pos = float(walzen_ziel[i])
	var a := int(walzen_ziel[0])
	var b := int(walzen_ziel[1])
	var c := int(walzen_ziel[2])
	var f := CasinoRegeln.walzen_gewinn(a, b, c)
	var text := ""
	if a == b and b == c:
		var name: String = CasinoRegeln.SYMBOL_NAMEN[CasinoRegeln.SYMBOLE[a]]
		text = "Drei Tauben – alles vollgekleckert." if f == 0.0 else "Drei mal %s!" % name
	elif f > 0.0:
		text = "Zwei gleiche."
	else:
		text = "Leider nichts."
	_abrechnen(f, text)

class Walze extends Control:
	var pos := 0.0:
		set(v):
			pos = v
			queue_redraw()

	func _init() -> void:
		clip_contents = true

	func symbol() -> int:
		return posmod(int(round(pos)), 5)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("fbf8ef"))
		var zelle := size.y * 0.95
		var basis := int(floor(pos))
		var f := CasinoMenu.font()
		for j in range(basis - 1, basis + 3):
			var y := size.y * 0.5 + (j - pos) * zelle
			var id: String = CasinoRegeln.SYMBOLE[posmod(j, 5)]
			CasinoMenu.symbol(self, id, Vector2(size.x * 0.5, y - 8.0), 44.0)
			var t: String = CasinoRegeln.SYMBOL_NAMEN[id]
			var b := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(f, Vector2(size.x * 0.5 - b * 0.5, y + 58.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("4a4250"))
		draw_rect(Rect2(0, 0, size.x, 22), Color(0, 0, 0, 0.28))
		draw_rect(Rect2(0, size.y - 22, size.x, 22), Color(0, 0, 0, 0.28))
		draw_rect(Rect2(Vector2.ZERO, size), Color("d9a441"), false, 4.0)

# Putz-Symbole aus einfachen Formen (g = halbe Größe)
static func symbol(ci: CanvasItem, id: String, c: Vector2, g: float) -> void:
	match id:
		"schwamm":
			ci.draw_rect(Rect2(c + Vector2(-g, -g * 0.55), Vector2(g * 2.0, g * 1.1)), Color("f2c230"))
			ci.draw_rect(Rect2(c + Vector2(-g, g * 0.25), Vector2(g * 2.0, g * 0.3)), Color("3fa35a"))
			for p in [Vector2(-0.6, -0.2), Vector2(-0.1, -0.3), Vector2(0.45, -0.15), Vector2(-0.35, 0.05), Vector2(0.2, 0.0), Vector2(0.7, 0.05)]:
				var q: Vector2 = p
				ci.draw_circle(c + q * g, g * 0.09, Color("d9a01c"))
		"eimer":
			ci.draw_arc(c + Vector2(0, -g * 0.45), g * 0.72, PI, TAU, 16, Color("8a93a3"), 4.0, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-g * 0.8, -g * 0.45), c + Vector2(g * 0.8, -g * 0.45), c + Vector2(g * 0.55, g * 0.8), c + Vector2(-g * 0.55, g * 0.8)]), Color("2f86c8"))
			ci.draw_rect(Rect2(c + Vector2(-g * 0.86, -g * 0.55), Vector2(g * 1.72, g * 0.2)), Color("6fb4e6"))
			ci.draw_circle(c + Vector2(-g * 0.2, -g * 0.68), g * 0.14, Color("e6f6ff"))
			ci.draw_circle(c + Vector2(g * 0.15, -g * 0.74), g * 0.1, Color("e6f6ff"))
		"fenster":
			ci.draw_rect(Rect2(c - Vector2(g * 0.8, g * 0.8), Vector2(g * 1.6, g * 1.6)), Color("f4f4f2"))
			for p in [Vector2(-0.68, -0.68), Vector2(0.06, -0.68), Vector2(-0.68, 0.06), Vector2(0.06, 0.06)]:
				var q2: Vector2 = p
				ci.draw_rect(Rect2(c + q2 * g, Vector2(g * 0.62, g * 0.62)), Color("7cc8ee"))
			ci.draw_line(c + Vector2(-g * 0.55, -g * 0.2), c + Vector2(-g * 0.25, -g * 0.55), Color.WHITE, 3.0, true)
			ci.draw_line(c + Vector2(g * 0.2, g * 0.55), c + Vector2(g * 0.5, g * 0.2), Color.WHITE, 3.0, true)
		"gondel":
			ci.draw_line(c + Vector2(-g * 0.7, -g * 0.9), c + Vector2(-g * 0.7, g * 0.1), Color("5b5f66"), 3.0)
			ci.draw_line(c + Vector2(g * 0.7, -g * 0.9), c + Vector2(g * 0.7, g * 0.1), Color("5b5f66"), 3.0)
			ci.draw_rect(Rect2(c + Vector2(-g * 0.9, g * 0.1), Vector2(g * 1.8, g * 0.65)), Color("e08a1e"))
			ci.draw_rect(Rect2(c + Vector2(-g * 0.9, -g * 0.25), Vector2(g * 1.8, g * 0.1)), Color("8a93a3"))
			for k in 4:
				ci.draw_line(c + Vector2(-g * 0.9 + k * g * 0.6, -g * 0.25), c + Vector2(-g * 0.9 + k * g * 0.6, g * 0.1), Color("8a93a3"), 3.0)
			ci.draw_rect(Rect2(c + Vector2(-g * 0.9, g * 0.6), Vector2(g * 1.8, g * 0.15)), Color("9a5a10"))
		"taube":
			var k2 := PackedVector2Array()
			for i in 20:
				var a := TAU * i / 20.0
				k2.append(c + Vector2(cos(a) * g * 0.7 - g * 0.05, sin(a) * g * 0.42 + g * 0.2))
			ci.draw_colored_polygon(k2, Color("9aa3b0"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-g * 0.55, g * 0.1), c + Vector2(-g * 1.0, -g * 0.1), c + Vector2(-g * 0.9, g * 0.4)]), Color("7c8593"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-g * 0.3, g * 0.05), c + Vector2(g * 0.25, g * 0.1), c + Vector2(-g * 0.15, g * 0.45)]), Color("7c8593"))
			ci.draw_circle(c + Vector2(g * 0.5, -g * 0.3), g * 0.28, Color("aab3bf"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(g * 0.74, -g * 0.36), c + Vector2(g * 1.0, -g * 0.24), c + Vector2(g * 0.74, -g * 0.18)]), Color("e08a1e"))
			ci.draw_circle(c + Vector2(g * 0.56, -g * 0.36), g * 0.06, Color("1b1e2a"))
			ci.draw_line(c + Vector2(-g * 0.1, g * 0.6), c + Vector2(-g * 0.1, g * 0.85), Color("e08a1e"), 3.0)
			ci.draw_line(c + Vector2(g * 0.15, g * 0.6), c + Vector2(g * 0.15, g * 0.85), Color("e08a1e"), 3.0)

# ---------------------------------------------------------------- 4 Rubbellos
func _los_bauen() -> void:
	los = Los.new()
	los.custom_minimum_size = Los.GROESSE
	los.fertig.connect(_los_fertig)
	inhalt.add_child(_mitte(los))
	inhalt.add_child(_mitte(_text("Los kaufen und mit gedrückter Maustaste den Dreck wegrubbeln · 3 gleiche Beträge = dieser Betrag ist gewonnen", 13, "b9a9c9")))
	_aktion("b_kaufen", "Los kaufen", "c86a10", _los_kaufen)
	_aktion("b_aufdecken", "Alles aufdecken", "5a4a66", func() -> void: los.aufdecken())

func _los_kaufen() -> void:
	if not _zahle():
		return
	los.neu(CasinoRegeln.los(rng), einsatz)

func _los_fertig() -> void:
	if not laeuft or spiel != "los":
		return
	var f := float(los.daten.gewinn)
	_abrechnen(f, "Dreimal %s €!" % Hud.punkte(int(f * einsatz)) if f > 0.0 else "Keine drei gleichen.")

class Los extends Control:
	signal fertig
	const GROESSE := Vector2(450, 270)
	const RAND := 15.0
	const RASTER := 10               # Messraster für „wie viel ist frei“
	const PINSEL := 20.0

	var daten := {}
	var preis := 0
	var aktiv := false               # Los gekauft, noch nicht aufgedeckt
	var aufgedeckt := false
	var bild: Image
	var tex: ImageTexture
	var _grund: Image
	var _frei := {}                  # Rasterzellen, die schon frei sind
	var _reibt := false
	var _alt := Vector2.ZERO

	func _init() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var r := RandomNumberGenerator.new()
		r.seed = 7
		var w := int(GROESSE.x - RAND * 2.0)
		var h := int(GROESSE.y - RAND * 2.0)
		_grund = Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:               # Schicht aus Staub und Dreck
			for x in w:
				var v := 0.52 + r.randf() * 0.1 + sin(x * 0.07 + y * 0.03) * 0.04 + sin(y * 0.11) * 0.03
				_grund.set_pixel(x, y, Color(v * 0.95, v * 0.86, v * 0.7, 1.0))
		bild = Image.create(w, h, false, Image.FORMAT_RGBA8)
		bild.copy_from(_grund)
		tex = ImageTexture.create_from_image(bild)

	func neu(d: Dictionary, einsatz: int) -> void:
		daten = d
		preis = einsatz
		aktiv = true
		aufgedeckt = false
		_frei = {}
		bild.copy_from(_grund)
		tex.update(bild)
		queue_redraw()

	func feld_rect(i: int) -> Rect2:
		var w := (GROESSE.x - RAND * 2.0) / 3.0
		var h := (GROESSE.y - RAND * 2.0) / 3.0
		return Rect2(RAND + (i % 3) * w, RAND + (i / 3) * h, w, h)

	# Anteil eines Feldes, der schon frei gerubbelt ist (0..1)
	func frei_anteil(i: int) -> float:
		var r := feld_rect(i)
		var zahl := 0
		var alle := 0
		var x0 := int((r.position.x - RAND) / RASTER)
		var y0 := int((r.position.y - RAND) / RASTER)
		for y in range(y0, y0 + int(r.size.y / RASTER)):
			for x in range(x0, x0 + int(r.size.x / RASTER)):
				alle += 1
				if _frei.has(Vector2i(x, y)):
					zahl += 1
		return float(zahl) / maxi(alle, 1)

	# an Punkt p (im Control) rubbeln
	func rubbel(p: Vector2) -> void:
		if not aktiv:
			return
		var m := p - Vector2(RAND, RAND)
		var w := bild.get_width()
		var h := bild.get_height()
		for y in range(maxi(int(m.y - PINSEL), 0), mini(int(m.y + PINSEL) + 1, h)):
			for x in range(maxi(int(m.x - PINSEL), 0), mini(int(m.x + PINSEL) + 1, w)):
				if Vector2(x, y).distance_to(m) <= PINSEL:
					bild.set_pixel(x, y, Color(0, 0, 0, 0))
					_frei[Vector2i(x / RASTER, y / RASTER)] = true

	func _pruefen() -> void:
		tex.update(bild)
		queue_redraw()
		for i in 9:
			if frei_anteil(i) < 0.55:
				return
		aufdecken()

	func aufdecken() -> void:
		if not aktiv:
			return
		aktiv = false
		aufgedeckt = true
		bild.fill(Color(0, 0, 0, 0))
		tex.update(bild)
		queue_redraw()
		fertig.emit()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_reibt = e.pressed
			_alt = e.position
			if e.pressed and aktiv:
				rubbel(e.position)
				_pruefen()
		elif e is InputEventMouseMotion and _reibt and aktiv:
			var weg: float = _alt.distance_to(e.position)
			var schritte := maxi(int(weg / 7.0), 1)
			for k in range(1, schritte + 1):
				rubbel(_alt.lerp(e.position, float(k) / schritte))
			_alt = e.position
			_pruefen()

	func _draw() -> void:
		var f := CasinoMenu.font()
		draw_rect(Rect2(Vector2.ZERO, size), Color("f2c230"))
		draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), Color("fbf8ef"))
		if not daten.is_empty():
			var gew := float(daten.gewinn)
			for i in 9:
				var r := feld_rect(i).grow(-4.0)
				var v := float(daten.felder[i])
				var treffer := aufgedeckt and gew > 0.0 and v == gew
				draw_rect(r, Color("ffe9a0") if treffer else Color("e9f4fb"))
				draw_rect(r, Color("d9a441") if treffer else Color("b7d3e6"), false, 3.0 if treffer else 1.5)
				var t := "%s €" % Hud.punkte(int(v * preis))
				var b := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
				draw_string(f, r.get_center() + Vector2(-b * 0.5, 8.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("c86a10") if treffer else Color("123a6b"))
		draw_texture(tex, Vector2(RAND, RAND))
		if not aktiv and not aufgedeckt:
			var t2 := "Kauf ein Los!"
			var b2 := f.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			draw_string_outline(f, size * 0.5 + Vector2(-b2 * 0.5, 10.0), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, Color("5a4a36"))
			draw_string(f, size * 0.5 + Vector2(-b2 * 0.5, 10.0), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
