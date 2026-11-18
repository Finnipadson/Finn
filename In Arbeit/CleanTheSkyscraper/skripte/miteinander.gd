class_name Miteinander
extends CanvasLayer
# Mehrspieler (Phase 7f): Text-Chat (Enter), Emote-Rad (G: Winken, Daumen hoch, Zeigen, Jubeln), Ping (mittlere Maustaste)
# auf Fenster/Orte (auch auf der Karte M), Anzeige „Für alle pausiert“. Alles geht über Netz.sozial_senden → Gastgeber →
# alle (empfangen). Im Einzelspieler ist nichts davon aktiv. Tasten in Optionen.AKTIONEN (chat, emote), umbelegbar.

const CHAT_ZEILEN := 7
const CHAT_DAUER := 12.0           # so lange bleibt eine Zeile sichtbar (offen: alle)
const PING_DAUER := 9.0
const EMOTE_DAUER := 5.0
const EMOTES := [
	{"id": "winken", "name": "Winken", "text": "Hallo!"},
	{"id": "daumen", "name": "Daumen hoch", "text": "Super!"},
	{"id": "zeigen", "name": "Zeigen", "text": "Da!"},
	{"id": "jubeln", "name": "Jubeln", "text": "Juhuu!"},
]

var spiel: Spiel
var chat_box: VBoxContainer
var chat_panel: PanelContainer     # dunkler Glas-Hintergrund (lesbar auf hellem Boden)
var eingabe: LineEdit
var zeilen: Array = []             # {label, zeit}
var rad: Control
var pause_ebene: Control
var pause_text: Label
var pause_knopf: Button
var pings: Array = []              # {knoten, pos, zeit, farbe, name}
var welt_knoten: Node3D            # Pings + Emote-Blasen in der Welt
var _gesperrt_vorher := false
var _offen := ""                   # "", "chat", "rad"

func setup(s: Spiel) -> void:
	spiel = s
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	welt_knoten = Node3D.new()
	welt_knoten.name = "miteinander_welt"
	s.add_child(welt_knoten)
	# Chat unten links
	var rahmen := VBoxContainer.new()
	rahmen.anchor_top = 1.0
	rahmen.anchor_bottom = 1.0
	rahmen.offset_left = 18
	rahmen.offset_top = -330
	rahmen.offset_bottom = -120
	rahmen.offset_right = 560
	rahmen.alignment = BoxContainer.ALIGNMENT_END
	rahmen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rahmen)
	chat_panel = PanelContainer.new()
	chat_panel.add_theme_stylebox_override("panel", UiGlas.box(Color(UiGlas.GLAS, 0.6), Color(1, 1, 1, 0.08), 10, 8))
	chat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_panel.visible = false
	rahmen.add_child(chat_panel)
	chat_box = VBoxContainer.new()
	chat_box.add_theme_constant_override("separation", 2)
	chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_panel.add_child(chat_box)
	eingabe = LineEdit.new()
	eingabe.name = "chat_eingabe"
	eingabe.max_length = 120
	eingabe.placeholder_text = "Nachricht an alle – Enter: senden · Esc: abbrechen"
	eingabe.custom_minimum_size = Vector2(520, 36)
	eingabe.add_theme_stylebox_override("normal", UiGlas.box(Color(UiGlas.GLAS, 0.9), UiGlas.AKZENT, 8, 8))
	eingabe.add_theme_stylebox_override("focus", UiGlas.box(Color(UiGlas.GLAS, 0.95), UiGlas.AKZENT, 8, 8))
	eingabe.visible = false
	eingabe.text_submitted.connect(_senden)
	rahmen.add_child(eingabe)
	_rad_bauen()
	_pause_bauen()

func aktiv() -> bool:
	return Netz.aktiv()

func blockiert() -> bool:
	return _offen != ""

func chat_offen() -> bool:
	return _offen == "chat"

# ---------------------------------------------------------------- Eingaben (vor dem Spiel)
func _input(e: InputEvent) -> void:
	if not aktiv() or get_tree().paused:
		return
	if _offen == "chat":
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
			_schliessen()
			get_viewport().set_input_as_handled()
		return   # alles andere bekommt die Eingabezeile
	if _offen == "rad":
		if e is InputEventKey and e.pressed and not e.echo:
			var k := Optionen.k(e)
			if k >= KEY_1 and k <= KEY_4:
				emote(EMOTES[k - KEY_1].id)
				_schliessen()
			elif k == KEY_ESCAPE or k == Optionen.standard_taste("emote"):
				_schliessen()
			get_viewport().set_input_as_handled()
		return
	if _anderes_offen():
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k := Optionen.k(e)
		if k == Optionen.standard_taste("chat") or (k == KEY_KP_ENTER and Optionen.standard_taste("chat") == KEY_ENTER):
			chat_oeffnen()
			get_viewport().set_input_as_handled()
		elif k == Optionen.standard_taste("emote"):
			rad_oeffnen()
			get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_MIDDLE and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		ping_hier()
		get_viewport().set_input_as_handled()

func _anderes_offen() -> bool:
	var s := spiel
	return s.shop.offen or s.album.offen or s.hmenu.offen or s.cmenu.offen or s.extras.menue_offen() or s.karte.offen or s.pause != null \
		or (s.abspann != null and is_instance_valid(s.abspann)) or s.strand.menu.offen

func chat_oeffnen() -> void:
	_offen = "chat"
	_sperren(true)
	eingabe.visible = true
	eingabe.text = ""
	eingabe.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_zeilen_zeigen()

func rad_oeffnen() -> void:
	_offen = "rad"
	_sperren(true)
	rad.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _schliessen() -> void:
	_offen = ""
	eingabe.visible = false
	eingabe.release_focus()
	rad.visible = false
	_sperren(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _sperren(an: bool) -> void:
	if an:
		_gesperrt_vorher = spiel.spieler.gesperrt
		spiel.spieler.gesperrt = true
		spiel.spieler.wischt = false
	else:
		spiel.spieler.gesperrt = _gesperrt_vorher
	spiel.laeufer.gesperrt = an

func _senden(t: String) -> void:
	t = t.strip_edges()
	if t != "":
		Netz.sozial_senden("chat", {"t": t.left(120)})
	_schliessen()

# ---------------------------------------------------------------- Emote-Rad
func _rad_bauen() -> void:
	rad = Control.new()
	rad.set_anchors_preset(Control.PRESET_FULL_RECT)
	rad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rad.visible = false
	add_child(rad)
	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	mitte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rad.add_child(mitte)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiGlas.box(Color(UiGlas.GLAS, 0.9), UiGlas.RAND, 18, 18))
	mitte.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pc.add_child(vb)
	vb.add_child(UiGlas.text("Emote – Klick oder 1–4", 18, UiGlas.TEXT, true))
	var gitter := GridContainer.new()
	gitter.columns = 2
	gitter.add_theme_constant_override("h_separation", 8)
	gitter.add_theme_constant_override("v_separation", 8)
	vb.add_child(gitter)
	for i in EMOTES.size():
		var em: Dictionary = EMOTES[i]
		var b := UiGlas.knopf("%d  %s" % [i + 1, em.name], "nehmen")
		b.name = "emote_" + str(em.id)
		b.custom_minimum_size = Vector2(190, 52)
		b.pressed.connect(func():
			emote(str(em.id))
			_schliessen())
		gitter.add_child(b)

func emote(id: String) -> void:
	Netz.sozial_senden("emote", {"art": id})
	if id == "zeigen":
		ping_hier()   # Zeigen markiert auch die Stelle

# ---------------------------------------------------------------- Ping
# Wohin zeigt die Kamera? In der Gondel: Glas vor einem (Fenster), zu Fuß: Boden, sonst 40 m geradeaus
func ziel() -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var o := cam.global_position
	var d := -cam.global_basis.z
	var sp := spiel.spieler
	if sp.aktiv:
		var den := d.dot(sp.normal)
		if den < -0.01:
			var t := (sp.glas_punkt - o).dot(sp.normal) / den
			if t > 0.0 and t < 250.0:
				var p := o + d * t
				var f := spiel.turm.stockwerk_bei(p.y)
				return {"pos": p, "text": "Fenster (Stockwerk %d)" % (f + 1)}
	var boden := 0.0 if sp.aktiv else spiel.laeufer.position.y
	if d.y < -0.01:
		var t2 := (boden - o.y) / d.y
		if t2 < 500.0:
			return {"pos": o + d * t2, "text": "Hier"}
	return {"pos": o + d * 40.0, "text": "Da"}

func ping_hier() -> void:
	var z := ziel()
	if z.is_empty():
		return
	var p: Vector3 = z.pos
	Netz.sozial_senden("ping", {"x": p.x, "y": p.y, "z": p.z, "t": str(z.text)})

func ping_karte(p2: Vector2) -> void:
	Netz.sozial_senden("ping", {"x": p2.x, "y": 0.5, "z": p2.y, "t": "Treffpunkt"})

func _ping_zeigen(id: int, p: Vector3, text: String) -> void:
	var farbe := Netz.farbe(id)
	var n := Node3D.new()
	welt_knoten.add_child(n)
	n.global_position = p
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(farbe, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	var saeule := Bau.zylinder(0.06, 0.06, 6.0, m, 8)
	saeule.position.y = 3.0
	saeule.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(saeule)
	var ring := Bau.zylinder(0.7, 0.7, 0.05, m, 24)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	var l := Label3D.new()
	l.text = "%s: %s" % [Netz.name_von(id), text]
	l.font_size = 40
	l.pixel_size = 0.0012
	l.fixed_size = true
	l.no_depth_test = true
	l.outline_size = 10
	l.outline_modulate = Color(0.02, 0.04, 0.08, 0.9)
	l.modulate = farbe
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 6.4
	n.add_child(l)
	pings.append({"knoten": n, "pos": p, "zeit": PING_DAUER, "farbe": farbe, "name": Netz.name_von(id)})
	Ton.spielen("ding", -6.0, 1.2)

# ---------------------------------------------------------------- Empfang (vom Gastgeber, auch eigene Nachrichten)
func empfangen(id: int, art: String, d: Dictionary) -> void:
	match art:
		"chat":
			_chat_zeile("%s: %s" % [Netz.name_von(id), str(d.get("t", ""))], Netz.farbe(id))
			if id != Netz.meine_id():
				Ton.spielen("klick", -6.0, 1.4)
		"emote":
			var em := _emote_daten(str(d.get("art", "")))
			if em.is_empty():
				return
			if id == Netz.meine_id():
				spiel.hud.meldung("Du: %s" % em.text, 1.5)
			else:
				spiel.mitspieler.blase(id, str(em.text), EMOTE_DAUER)
				_chat_zeile("%s: %s" % [Netz.name_von(id), em.name.to_lower()], Color(Netz.farbe(id), 0.8))
		"ping":
			_ping_zeigen(id, Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0))), str(d.get("t", "")))

func _emote_daten(id: String) -> Dictionary:
	for em in EMOTES:
		if em.id == id:
			return em
	return {}

func _chat_zeile(t: String, farbe: Color) -> void:
	var l := UiGlas.text(t, 16, Color(farbe, 1.0).lightened(0.25))
	l.label_settings.outline_size = 5
	l.label_settings.outline_color = Color(0, 0, 0, 0.8)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	chat_box.add_child(l)
	zeilen.append({"label": l, "zeit": CHAT_DAUER})
	while zeilen.size() > 30:
		(zeilen[0].label as Label).queue_free()
		zeilen.pop_front()
	_zeilen_zeigen()

func _zeilen_zeigen() -> void:
	var n := 0
	for i in range(zeilen.size() - 1, -1, -1):
		var z: Dictionary = zeilen[i]
		var l: Label = z.label
		l.visible = n < CHAT_ZEILEN and (_offen == "chat" or float(z.zeit) > 0.0)
		l.modulate.a = 1.0 if _offen == "chat" else clampf(float(z.zeit), 0.0, 1.0)
		if l.visible:
			n += 1
	chat_panel.visible = n > 0

# Für Tests + Karte
func chat_texte() -> Array:
	var l := []
	for z in zeilen:
		l.append((z.label as Label).text)
	return l

# ---------------------------------------------------------------- Für alle pausieren (nur der Gastgeber schaltet)
func _pause_bauen() -> void:
	pause_ebene = Control.new()
	pause_ebene.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_ebene.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_ebene.visible = false
	add_child(pause_ebene)
	var dunkel := ColorRect.new()
	dunkel.color = Color(0, 0, 0, 0.35)
	dunkel.set_anchors_preset(Control.PRESET_FULL_RECT)
	dunkel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_ebene.add_child(dunkel)
	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	mitte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_ebene.add_child(mitte)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiGlas.box(Color(UiGlas.GLAS, 0.92), UiGlas.RAND, 18, 22))
	mitte.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	pause_text = UiGlas.text("Pause für alle", 26, UiGlas.TEXT, true)
	vb.add_child(pause_text)
	pause_knopf = UiGlas.knopf("Für alle weiterspielen", "kaufen")
	pause_knopf.name = "alle_weiter"
	pause_knopf.custom_minimum_size = Vector2(320, 46)
	pause_knopf.pressed.connect(func(): Netz.alle_pausieren(false))
	vb.add_child(pause_knopf)

func pause_zeigen(an: bool) -> void:
	pause_ebene.visible = an
	pause_knopf.visible = Netz.ist_host()
	pause_text.text = "Pause für alle" if Netz.ist_host() else "%s hat das Spiel für alle pausiert." % Netz.name_von(1)
	if an:
		if _offen != "":
			_schliessen()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif spiel.pause == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ---------------------------------------------------------------- Ablauf
func _process(dt: float) -> void:
	if get_tree().paused:
		return
	var weg := false
	for z in zeilen:
		var alt := float(z.zeit)
		z.zeit = alt - dt
		if (alt > 0.0) != (float(z.zeit) > 0.0) or (alt > 0.0 and alt < 1.0):
			weg = true
	if weg:
		_zeilen_zeigen()
	for pg in pings.duplicate():
		pg.zeit = float(pg.zeit) - dt
		var n: Node3D = pg.knoten
		n.rotation.y += dt * 1.5
		n.scale = Vector3.ONE * (1.0 + 0.15 * sin(float(pg.zeit) * 6.0))
		if float(pg.zeit) <= 0.0:
			n.queue_free()
			pings.erase(pg)
	if not aktiv() and _offen != "":
		_schliessen()
