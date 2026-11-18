class_name Karte
extends CanvasLayer
# Karte (Taste M): Stadt von oben – Straßen, Häuser, See, Palmen-Boulevard, Strand, Meer, Steg – mit Turm, Kiosken,
# Läden, Casino, Aufzügen, Strandbar, Fischladen, Yacht und der eigenen Position. Klick auf einen Ort (oder irgendwohin)
# setzt ein Ziel; oben im Bild zeigt dann ein Pfeil den Weg (um den See, über den Boulevard, die Treppe hinunter …)
# mit Entfernung. Wegsuche: wenige Wegpunkte + Sichtprüfung auf einem groben Raster (2 m).
# Mausrad: Zoom, rechte Maustaste ziehen: verschieben, X: Ziel löschen, M/Esc: schließen.

const ZELLE := 2.0
const BEREICH := Rect2(-840.0, -720.0, 1400.0, 1440.0)   # Raster für die Wegsuche (x, z)

var spiel: Spiel
var offen := false
var flaeche: Control
var pfeil: Control
var legende: Label
var orte: Array = []            # {name, pos (Vector2, begehbar), farbe, ebene}
var ziel := Vector2.INF
var ziel_name := ""
var ziel_ebene := 0             # 0 = Stadt/Promenade/Steg, 1 = Strand (unten)
var route := PackedVector2Array()
var _route_zeit := 0.0
var mitte := Vector2(-200.0, -60.0)
var zoom := 0.62                # Bildpunkte pro Meter
var _ziehen := false
var _schrift: Font              # einmal anlegen (neu angelegte Systemschriften zeigen beim Zeichnen nur Kästchen)
var _strassen: Array = []       # [a, b]
var _raster := PackedByteArray()   # 0 frei, 1 fest (Ebene oben), Bit 2: frei am Strand
var _rn := Vector2i.ZERO
var _knoten: Array = []         # {p, ebene}
var _nachbarn: Array = []       # je Knoten [[j, Länge], …]
var _d: Array = []              # Weglänge je Knoten bis zum Ziel (nach ziel_setzen)
var _her: Array = []            # nächster Knoten Richtung Ziel (−1 = Ziel direkt)

func setup(s: Spiel) -> void:
	spiel = s
	layer = 12
	flaeche = Control.new()
	flaeche.set_anchors_preset(Control.PRESET_FULL_RECT)
	flaeche.mouse_filter = Control.MOUSE_FILTER_STOP
	flaeche.draw.connect(_zeichnen)
	flaeche.gui_input.connect(_flaeche_input)
	flaeche.visible = false
	add_child(flaeche)
	legende = UiGlas.text("Klick: Ziel setzen · Mausrad: Zoom · rechte Maustaste ziehen: verschieben · X: Ziel löschen · M oder Esc: schließen", 15, UiGlas.TEXT, true)
	legende.position = Vector2(24, 18)
	legende.visible = false
	add_child(legende)
	pfeil = Control.new()
	pfeil.anchor_left = 0.5
	pfeil.anchor_right = 0.5
	pfeil.offset_left = -130
	pfeil.offset_right = 130
	pfeil.offset_top = 70
	pfeil.offset_bottom = 170
	pfeil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pfeil.draw.connect(_pfeil_zeichnen)
	pfeil.visible = false
	add_child(pfeil)
	_orte_sammeln.call_deferred()

func _orte_sammeln() -> void:
	orte.clear()
	var w := spiel.welt
	orte.append({"name": "Wüstennadel (Gondeln)", "pos": Vector2(0, 40.0) if spiel.laeufer.frei(Vector2(0, 40)) else spiel.extras.sky.unten_pos, "farbe": "ffffff", "art": "turm"})
	orte.append({"name": "Express-Aufzug Sky-Lounge", "pos": spiel.extras.sky.unten_pos, "farbe": "b36bff", "art": "aufzug"})
	for i in Haendler.STAENDE.size():
		orte.append({"name": "Kiosk: " + str(Haendler.STAENDE[i].name), "pos": spiel.haendler.vorne[i], "farbe": str(Haendler.STAENDE[i].farbe), "art": "kiosk"})
	for id in spiel.extras.laeden.laeden:
		var l: Dictionary = spiel.extras.laeden.laeden[id]
		orte.append({"name": str(Laeden.DATEN[id].name), "pos": l.eingang, "farbe": str(Laeden.DATEN[id].farbe), "art": "laden"})
	orte.append({"name": "Casino", "pos": spiel.casino.eingang, "farbe": "e2483e", "art": "casino"})
	var k := w.kueste
	orte.append({"name": "Strandbar", "pos": k.stationen[0].pos, "farbe": "ffb03a", "art": "strand", "ebene": 1})
	orte.append({"name": "Fischladen (Steg)", "pos": k.stationen[1].pos, "farbe": "35c8ff", "art": "strand"})
	orte.append({"name": "Steg-Spitze (Angeln)", "pos": Vector2(Kueste.KOPF.get_center().x, Kueste.KOPF.get_center().y), "farbe": "7fe08a", "art": "strand"})
	orte.append({"name": "Yacht-Liegeplatz", "pos": k.stationen[2].pos, "farbe": "f4f4f4", "art": "strand"})
	orte.append({"name": "Strand", "pos": Vector2(-630.0, -40.0), "farbe": "ffd84a", "art": "strand", "ebene": 1})
	orte.append({"name": "Palmen-Boulevard", "pos": Vector2(k.kanal_start - 30.0, Kueste.BOUL_Z + 12.0), "farbe": "3fc29a", "art": "strand"})
	# Straßen für die Zeichnung
	for richtung in 2:
		for kk in range(-22, 22):
			var c := Welt.RASTER * (kk + 0.5)
			for j in range(-22, 22):
				var lo := Welt.RASTER * (j + 0.5)
				var a := Vector2(c, lo) if richtung == 0 else Vector2(lo, c)
				var b := Vector2(c, lo + Welt.RASTER) if richtung == 0 else Vector2(lo + Welt.RASTER, c)
				if w.stueck_da(a, b):
					_strassen.append([a, b])

# ---------------------------------------------------------------- Öffnen / Schließen
func oeffnen() -> void:
	if _raster.is_empty():
		_raster_bauen()
	offen = true
	flaeche.visible = true
	legende.visible = true
	var p := _spieler_pos()
	mitte = p.lerp(Vector2(-250, -60), 0.5)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	flaeche.queue_redraw()

func schliessen() -> void:
	offen = false
	flaeche.visible = false
	legende.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(e: InputEvent) -> void:
	if not offen:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match Optionen.k(e):
			KEY_M, KEY_ESCAPE: schliessen()
			KEY_X: ziel_loeschen()
		get_viewport().set_input_as_handled()

func _flaeche_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var b := e as InputEventMouseButton
		if b.pressed and b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var vorher := _welt(b.position)
			zoom = clampf(zoom * (1.2 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.15, 4.0)
			mitte += vorher - _welt(b.position)
		elif b.button_index == MOUSE_BUTTON_RIGHT:
			_ziehen = b.pressed
		elif b.button_index == MOUSE_BUTTON_LEFT and b.pressed:
			klick(b.position)
		elif b.button_index == MOUSE_BUTTON_MIDDLE and b.pressed and Netz.aktiv() and spiel.miteinander:
			spiel.miteinander.ping_karte(_welt(b.position))   # Mehrspieler: Treffpunkt für alle
		flaeche.queue_redraw()
	elif e is InputEventMouseMotion and _ziehen:
		mitte -= (e as InputEventMouseMotion).relative / zoom
		flaeche.queue_redraw()

# Klick auf die Karte (Bildschirm-Punkt): nächster Ort in 18 px, sonst der Punkt selbst
func klick(sp: Vector2) -> void:
	var best := {}
	var best_d := 18.0
	for o in orte:
		var d := _bild(o.pos).distance_to(sp)
		if d < best_d:
			best_d = d
			best = o
	if not best.is_empty():
		ziel_setzen(best.pos, best.name, int(best.get("ebene", 0)))
	else:
		var p := _welt(sp)
		var ebene := 1 if p.x < Kueste.UFER_X - 0.5 and not Kueste.auf_steg(p) else 0
		ziel_setzen(p, "Markierung", ebene)

func ziel_setzen(p: Vector2, name: String, ebene := 0) -> void:
	ziel = p
	ziel_name = name
	ziel_ebene = ebene
	_route_zeit = 0.0
	if _raster.is_empty():
		_raster_bauen()
	_ziel_baum()
	_route_neu()
	spiel.hud.meldung("Ziel: %s – folge dem Pfeil oben." % name, 2.5)
	flaeche.queue_redraw()

func ziel_loeschen() -> void:
	ziel = Vector2.INF
	ziel_name = ""
	route = PackedVector2Array()
	pfeil.visible = false
	flaeche.queue_redraw()

# ---------------------------------------------------------------- Umrechnung
func _bild(p: Vector2) -> Vector2:
	return flaeche.size * 0.5 + (p - mitte) * zoom

func _welt(sp: Vector2) -> Vector2:
	return mitte + (sp - flaeche.size * 0.5) / zoom

func _spieler_pos() -> Vector2:
	if spiel.strand and spiel.strand.yacht.an_bord:
		var y := spiel.strand.yacht.position
		return Vector2(y.x, y.z)
	if spiel.spieler.aktiv:
		var g := spiel.spieler.gondel.global_position
		return Vector2(g.x, g.z)
	return Vector2(spiel.laeufer.position.x, spiel.laeufer.position.z)

func _spieler_ebene() -> int:
	return 1 if not spiel.spieler.aktiv and spiel.laeufer.position.y < -1.0 else 0

func _spieler_yaw() -> float:
	if spiel.strand and spiel.strand.yacht.an_bord:
		return spiel.strand.yacht.cam.global_rotation.y
	if spiel.spieler.aktiv:
		return spiel.spieler.cam.global_rotation.y
	return spiel.laeufer.yaw

# ---------------------------------------------------------------- Zeichnen
func _zeichnen() -> void:
	var c := flaeche
	var w := spiel.welt
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("dcc497"))
	var stadt := _bild(Vector2.ZERO)
	c.draw_circle(stadt, 1600.0 * zoom, Color("d6d0c4"))
	# Meer + Strand
	var x_w := _bild(Vector2(Kueste.WASSER_X, 0)).x
	var x_u := _bild(Vector2(Kueste.UFER_X, 0)).x
	c.draw_rect(Rect2(Vector2(-10, -10), Vector2(maxf(x_w + 10, 0), c.size.y + 20)), Color("2f8fc0"))
	c.draw_rect(Rect2(Vector2(x_w, -10), Vector2(x_u - x_w, c.size.y + 20)), Color("f0dca8"))
	# Straßen
	for s in _strassen:
		c.draw_line(_bild(s[0]), _bild(s[1]), Color("8f9399"), maxf(13.0 * zoom, 1.0))
	# Boulevard + Kanal
	var k := w.kueste
	_rect(Rect2(Vector2(Kueste.UFER_X, Kueste.BOUL_Z - Kueste.BOUL_HALB), Vector2(Kueste.BOUL_X0 - Kueste.UFER_X, Kueste.BOUL_HALB * 2.0)), Color("e9e2d2"))
	_rect(Rect2(Vector2(Kueste.UFER_X, -1600.0), Vector2(Kueste.PROM_X - Kueste.UFER_X, 3200.0)), Color("e9e2d2"))
	_rect(Rect2(Vector2(Kueste.WASSER_X, Kueste.BOUL_Z - Kueste.KANAL_HALB), Vector2(k.kanal_start - Kueste.WASSER_X, Kueste.KANAL_HALB * 2.0)), Color("3aa0d0"))
	# See
	var see := w.see_umriss(0.0, 8.0)
	var pts := PackedVector2Array()
	for p in see:
		pts.append(_bild(p))
	c.draw_colored_polygon(pts, Color("3aa0d0"))
	# Häuser
	for h in w.haeuser:
		_rect(h, Color("b9b2a6"))
	for g in w.gebaeude:
		_rect(g, Color("c9a77a"))
	# Steg
	_rect(Rect2(Vector2(Kueste.STEG_ENDE, Kueste.STEG_Z - Kueste.STEG_HALB), Vector2(Kueste.UFER_X - Kueste.STEG_ENDE, Kueste.STEG_HALB * 2.0)), Color("a8744a"))
	_rect(Kueste.KOPF, Color("a8744a"))
	_rect(Kueste.FISCHLADEN, Color("2f6fa8"))
	_rect(Kueste.BAR, Color("c9a258"))
	if spiel.strand:   # Yacht maßstäblich (90 × 14 m, Bug spitz), mindestens ein paar Bildpunkte groß
		var yt := spiel.strand.yacht
		var y2 := Vector2(yt.position.x, yt.position.z)
		var v3 := yt.vorne()
		var v := Vector2(v3.x, v3.z)
		var q := Vector2(-v.y, v.x)
		var hl := maxf(Yacht.LANG * 0.5, 7.0 / maxf(zoom, 0.001))
		var hb := hl * Yacht.BREIT / Yacht.LANG
		var umriss := PackedVector2Array()
		for e in [[1.0, 0.0], [0.6, 1.0], [-1.0, 0.9], [-1.0, -0.9], [0.6, -1.0]]:
			umriss.append(_bild(y2 + v * hl * float(e[0]) + q * hb * float(e[1])))
		c.draw_colored_polygon(umriss, Color("ffffff"))
		umriss.append(umriss[0])
		c.draw_polyline(umriss, Color("3a4048"), 1.5)
	# Turm
	var tp := PackedVector2Array()
	for p in spiel.turm.stockwerke[0].poly:
		tp.append(_bild(p))
	c.draw_colored_polygon(tp, Color("4a5260"))
	# Route
	if ziel != Vector2.INF:
		var vor := _bild(_spieler_pos())
		for p in route:
			var b := _bild(p)
			c.draw_dashed_line(vor, b, Color("ff4fb8"), 3.0, 10.0)
			vor = b
		c.draw_circle(_bild(ziel), 9.0, Color("ff4fb8"))
	# Orte
	var f := _font()
	for o in orte:
		if str(o.get("art", "")) == "kiosk" and zoom < 0.9:
			c.draw_circle(_bild(o.pos), 5.0, Color(str(o.farbe)))
			continue
		var b := _bild(o.pos)
		c.draw_circle(b, 7.0, Color(str(o.farbe)))
		c.draw_arc(b, 7.5, 0, TAU, 20, Color(0, 0, 0, 0.6), 1.5)
		c.draw_string_outline(f, b + Vector2(10, 5), str(o.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.75))
		c.draw_string(f, b + Vector2(10, 5), str(o.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	# Mehrspieler (7f): Pings und die anderen Spieler in ihrer Farbe
	if Netz.aktiv() and spiel.miteinander:
		for pg in spiel.miteinander.pings:
			var pb := _bild(Vector2(pg.pos.x, pg.pos.z))
			c.draw_arc(pb, 11.0 + 3.0 * sin(Time.get_ticks_msec() * 0.008), 0, TAU, 24, pg.farbe, 3.0)
			var pt := "Ping von %s" % pg.name
			c.draw_string_outline(f, pb + Vector2(14, 16), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.75))
			c.draw_string(f, pb + Vector2(14, 16), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, pg.farbe)
		for id in spiel.mitspieler.figuren:
			var l: Array = spiel.mitspieler.figuren[id].lage
			if l.size() < 4:
				continue
			var mb := _bild(Vector2(float(l[1]), float(l[3])))
			var fa := Netz.farbe(id)
			c.draw_circle(mb, 8.0, fa)
			c.draw_arc(mb, 8.5, 0, TAU, 20, Color(0, 0, 0, 0.7), 2.0)
			c.draw_string_outline(f, mb + Vector2(11, -9), Netz.name_von(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.8))
			c.draw_string(f, mb + Vector2(11, -9), Netz.name_von(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, fa)
	# Ich
	var ich := _bild(_spieler_pos())
	var yaw := _spieler_yaw()
	var vorn := Vector2(-sin(yaw), -cos(yaw))
	var quer := vorn.orthogonal()
	c.draw_colored_polygon(PackedVector2Array([ich + vorn * 14.0, ich - vorn * 8.0 + quer * 8.0, ich - vorn * 4.0, ich - vorn * 8.0 - quer * 8.0]), Color("ffd84a"))
	c.draw_polyline(PackedVector2Array([ich + vorn * 14.0, ich - vorn * 8.0 + quer * 8.0, ich - vorn * 4.0, ich - vorn * 8.0 - quer * 8.0, ich + vorn * 14.0]), Color(0, 0, 0, 0.8), 2.0)
	c.draw_string_outline(f, ich + Vector2(12, -10), "Du", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.8))
	c.draw_string(f, ich + Vector2(12, -10), "Du", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffd84a"))

func _font() -> Font:
	if _schrift == null:
		_schrift = legende.label_settings.font
	return _schrift

func _rect(r: Rect2, farbe: Color) -> void:
	var a := _bild(r.position)
	var b := _bild(r.end)
	flaeche.draw_rect(Rect2(a, b - a), farbe)

# ---------------------------------------------------------------- Pfeil im Bild
func _process(dt: float) -> void:
	if offen:
		flaeche.queue_redraw()
	if ziel == Vector2.INF:
		pfeil.visible = false
		return
	var p := _spieler_pos()
	if p.distance_to(ziel) < 6.0 and _spieler_ebene() == ziel_ebene:
		spiel.hud.meldung("Ziel erreicht: %s" % ziel_name, 2.5)
		ziel_loeschen()
		return
	_route_zeit -= dt
	if _route_zeit <= 0.0:
		_route_zeit = 1.0
		_route_neu()
	pfeil.visible = not offen and not spiel.spieler.aktiv and spiel.extras.ort == ""
	pfeil.queue_redraw()

# Richtung zum nächsten Wegpunkt relativ zur Blickrichtung (rad, + = rechts)
func pfeil_winkel() -> float:
	if route.is_empty():
		return 0.0
	var p := _spieler_pos()
	var i := 0
	# erreichte bzw. schon passierte Wegpunkte überspringen (näher am übernächsten als der Wegpunkt selbst)
	while i < route.size() - 1 and (route[i].distance_to(p) < 5.0 or p.distance_to(route[i + 1]) < route[i].distance_to(route[i + 1])):
		i += 1
	var d := route[i] - p
	var yaw := _spieler_yaw()
	var vorn := Vector2(-sin(yaw), -cos(yaw))
	var rechts := Vector2(cos(yaw), -sin(yaw))
	return atan2(d.dot(rechts), d.dot(vorn))

func rest_weg() -> float:
	var s := 0.0
	var vor := _spieler_pos()
	for q in route:
		s += vor.distance_to(q)
		vor = q
	return s

func _pfeil_zeichnen() -> void:
	var m := Vector2(pfeil.size.x * 0.5, 38.0)
	var a := pfeil_winkel()
	var form := [Vector2(0, -30), Vector2(20, 2), Vector2(8, 2), Vector2(8, 26), Vector2(-8, 26), Vector2(-8, 2), Vector2(-20, 2)]
	var pts := PackedVector2Array()
	for q in form:
		pts.append(m + (q as Vector2).rotated(a))
	pfeil.draw_colored_polygon(pts, Color("ff4fb8"))
	pts.append(pts[0])
	pfeil.draw_polyline(pts, Color(1, 1, 1, 0.9), 2.5)
	var f := _font()
	var t := "%s · %d m" % [ziel_name, int(rest_weg())]
	var breit := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	pfeil.draw_string_outline(f, Vector2(m.x - breit * 0.5, 92), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color(0, 0, 0, 0.8))
	pfeil.draw_string(f, Vector2(m.x - breit * 0.5, 92), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)

# ---------------------------------------------------------------- Wegsuche
# Raster: Bit 0 = oben (Stadt/Promenade/Steg) gesperrt, Bit 1 = unten (Strand) gesperrt
func _raster_bauen() -> void:
	var t0 := Time.get_ticks_msec()
	_rn = Vector2i(int(BEREICH.size.x / ZELLE), int(BEREICH.size.y / ZELLE))
	_raster.resize(_rn.x * _rn.y)
	_raster.fill(0)
	var w := spiel.welt
	var L := spiel.laeufer
	for h in w.haeuser:
		_sperren(h as Rect2, 3)
	for g in w.gebaeude:
		_sperren((g as Rect2).grow(-1.5), 3)
	var see := w.see_umriss(1.0, 4.0)
	for pg in [see, L.turm_rand]:
		var lo := Vector2(INF, INF)
		var hi := -lo
		for p in pg:
			lo = lo.min(p)
			hi = hi.max(p)
		for zy in range(maxi(0, int((lo.y - BEREICH.position.y) / ZELLE)), mini(_rn.y, int((hi.y - BEREICH.position.y) / ZELLE) + 1)):
			for zx in range(maxi(0, int((lo.x - BEREICH.position.x) / ZELLE)), mini(_rn.x, int((hi.x - BEREICH.position.x) / ZELLE) + 1)):
				if Geometry2D.is_point_in_polygon(_mitte(zx, zy), pg):
					_raster[zy * _rn.x + zx] |= 3
	# Küste: Kanal, Mauer, Meer, Steg je Ebene
	var k := w.kueste
	var x_bis := int((Kueste.BOUL_X0 + 40.0 - BEREICH.position.x) / ZELLE)
	for zy in _rn.y:
		for zx in mini(x_bis, _rn.x):
			var p := _mitte(zx, zy)
			var i := zy * _rn.x + zx
			if not k.frei(p, 0.0):
				_raster[i] |= 1
			if p.x < Kueste.UFER_X + 1.0 and not k.frei(p, Kueste.STRAND_Y):
				_raster[i] |= 2
			elif p.x >= Kueste.UFER_X + 1.0:
				_raster[i] |= 2
	# Wegpunkte: alle freien Kreuzungspunkte des Straßenrasters, Ring um den Platz, um den See, Boulevard, Küste
	var kn := []
	for gx in range(-12, 8):
		for gz in range(-10, 10):
			var q := Vector2(Welt.RASTER * (gx + 0.5), Welt.RASTER * (gz + 0.5))
			if BEREICH.has_point(q) and not _gesperrt(q, 0) and q.length() > Welt.PLATZ_R + 5.0:
				kn.append([q, 0])
	for i in 16:
		var a2 := TAU * (i + 0.5) / 16.0
		for r in [70.0, Welt.PLATZ_R + 12.0]:
			var q: Vector2 = Vector2(cos(a2), sin(a2)) * float(r)
			if not _gesperrt(q, 0):
				kn.append([q, 0])
	var e := Vector2(50.0, 85.0) - Vector2.ONE * 35.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			kn.append([w.see_welt(Vector2(e.x * sx, e.y * sy) + Vector2(sx, sy).normalized() * 45.0), 0])
		kn.append([w.see_welt(Vector2(sx * 60.0, 0.0)), 0])
		kn.append([w.see_welt(Vector2(0.0, sx * 95.0)), 0])
	for s2 in [-1.0, 1.0]:
		kn.append([Vector2(k.kanal_start - 25.0, Kueste.BOUL_Z + s2 * 15.0), 0])   # Mitte des äußeren Wegs (frei)
		kn.append([Vector2(-596.0, Kueste.BOUL_Z + s2 * 15.0), 0])
		for bx in k.bruecken:
			kn.append([Vector2(float(bx), Kueste.BOUL_Z + s2 * 6.5), 0])
	var treppen := []
	for t in Kueste.TREPPEN:
		var zm: float = (t.x + t.y) * 0.5
		kn.append([Vector2(Kueste.UFER_X + 3.0, zm), 0])
		kn.append([Vector2(Kueste.UFER_X - Kueste.TREPPE_LANG - 2.0, zm), 1])
		treppen.append([kn.size() - 2, kn.size() - 1])
	kn.append([Vector2(-600.0, Kueste.STEG_Z), 0])
	kn.append([Vector2(-690.0, Kueste.STEG_Z + 4.5), 0])
	kn.append([Kueste.KOPF.get_center(), 0])
	for s2 in [-1.0, 1.0]:
		kn.append([Vector2(Kueste.STRAND_BRUECKE, Kueste.BOUL_Z + s2 * 6.0), 1])
	for z in [-60.0, 0.0, 80.0]:
		kn.append([Vector2(-625.0, z), 1])
	for q in kn:
		_knoten.append({"p": q[0], "ebene": q[1]})
		_nachbarn.append([])
	var kanten := 0
	for i in _knoten.size():
		for j in range(i + 1, _knoten.size()):
			var pi_: Vector2 = _knoten[i].p
			var pj: Vector2 = _knoten[j].p
			if _knoten[i].ebene == _knoten[j].ebene and pi_.distance_to(pj) < NAH and _sicht(pi_, pj, int(_knoten[i].ebene)):
				_verbinden(i, j, pi_.distance_to(pj))
				kanten += 1
	for t in treppen:
		_verbinden(t[0], t[1], Kueste.TREPPE_LANG + 5.0)
		kanten += 1
	print("Karte: Raster %d×%d, %d Wegpunkte, %d Kanten, %d ms" % [_rn.x, _rn.y, _knoten.size(), kanten, Time.get_ticks_msec() - t0])

const NAH := 170.0              # Wegpunkte so nah werden verbunden (wenn frei)

func _verbinden(i: int, j: int, l: float) -> void:
	_nachbarn[i].append([j, l])
	_nachbarn[j].append([i, l])

func _mitte(zx: int, zy: int) -> Vector2:
	return BEREICH.position + (Vector2(zx, zy) + Vector2(0.5, 0.5)) * ZELLE

func _sperren(r: Rect2, bits: int) -> void:
	for zy in range(maxi(0, int((r.position.y - BEREICH.position.y) / ZELLE)), mini(_rn.y, int((r.end.y - BEREICH.position.y) / ZELLE) + 1)):
		for zx in range(maxi(0, int((r.position.x - BEREICH.position.x) / ZELLE)), mini(_rn.x, int((r.end.x - BEREICH.position.x) / ZELLE) + 1)):
			if r.has_point(_mitte(zx, zy)):
				_raster[zy * _rn.x + zx] |= bits

func _gesperrt(p: Vector2, ebene: int) -> bool:
	if not BEREICH.has_point(p):
		return false
	var zx := int((p.x - BEREICH.position.x) / ZELLE)
	var zy := int((p.y - BEREICH.position.y) / ZELLE)
	if zx < 0 or zy < 0 or zx >= _rn.x or zy >= _rn.y:
		return false
	return (_raster[zy * _rn.x + zx] & (2 if ebene == 1 else 1)) != 0

# Freie Sicht von a nach b? Steht man in einem Gebäude (Laden, Casino) bzw. liegt das Ziel darin, zählen die
# gesperrten Stücke am Anfang bzw. am Ende nicht.
func _sicht(a: Vector2, b: Vector2, ebene: int) -> bool:
	var n := maxi(1, int(a.distance_to(b) / 1.0))
	var draussen := false
	var wieder_zu := false
	for i in range(1, n):
		if _gesperrt(a.lerp(b, float(i) / n), ebene):
			if draussen:
				wieder_zu = true
		elif wieder_zu:
			return false
		else:
			draussen = true
	return not wieder_zu or _gesperrt(b, ebene)

# Beim Setzen des Ziels: kürzeste Wege aller Wegpunkte zum Ziel (Dijkstra rückwärts)
func _ziel_baum() -> void:
	var n := _knoten.size()
	_d = []
	_her = []
	var fertig: Array = []
	for i in n:
		_d.append(INF)
		_her.append(-2)
		fertig.append(false)
	for i in n:   # Wegpunkte, die das Ziel direkt sehen
		var p: Vector2 = _knoten[i].p
		if int(_knoten[i].ebene) == ziel_ebene and p.distance_to(ziel) < 260.0 and _sicht(p, ziel, ziel_ebene):
			_d[i] = p.distance_to(ziel)
			_her[i] = -1
	for _r in n:
		var u := -1
		for i in n:
			if not fertig[i] and float(_d[i]) < INF and (u < 0 or float(_d[i]) < float(_d[u])):
				u = i
		if u < 0:
			break
		fertig[u] = true
		for nb in _nachbarn[u]:
			var v: int = nb[0]
			var l: float = float(_d[u]) + float(nb[1])
			if l < float(_d[v]):
				_d[v] = l
				_her[v] = u

func _route_neu() -> void:
	if ziel == Vector2.INF:
		return
	if _raster.is_empty():
		_raster_bauen()
	var start := _spieler_pos()
	var e0 := _spieler_ebene()
	if (spiel.strand and spiel.strand.yacht.an_bord) or (e0 == ziel_ebene and _sicht(start, ziel, e0)):
		route = PackedVector2Array([ziel])
		return
	if _d.size() != _knoten.size():
		_ziel_baum()
	var best := -1
	var best_l := INF
	for i in _knoten.size():
		if int(_knoten[i].ebene) != e0 or float(_d[i]) == INF:
			continue
		var p: Vector2 = _knoten[i].p
		var l := start.distance_to(p)
		if l > 260.0 or l + float(_d[i]) >= best_l:
			continue
		if _sicht(start, p, e0):
			best = i
			best_l = l + float(_d[i])
	if best < 0:
		route = PackedVector2Array([ziel])   # nichts gefunden: geradeaus
		return
	var r := PackedVector2Array()
	var k := best
	while k >= 0:
		r.append(_knoten[k].p)
		k = int(_her[k])
	r.append(ziel)
	route = r
