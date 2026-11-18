class_name Abspann
extends CanvasLayer
# Abspann (Phase 5), wenn das letzte Fenster des Turms sauber ist: Feuerwerk um die Spitze, Kameraflug am Turm hinauf
# und rundherum, große Glückwunsch-Zeile, Statistik-Karte, dann laufen die Mitwirkenden durch. Danach frei weiterspielen.
# Esc / Leertaste / Klick überspringt (nach 3 s). Spielstand: Wirtschaft.abspann, tuerme_fertig (Phase 6: neuer Turm).

signal fertig

const DAUER := 46.0

var spiel: Spiel
var cam: Camera3D
var zeit := 0.0
var wurzel: Control
var titel: Label
var statistik: PanelContainer
var namen: VBoxContainer
var weiter: Button
var _feuer_zeit := 0.0
var _zu := false
var _start := Vector3.ZERO
var _phase0 := -1.0                  # Tageszeit am Anfang: die Feier geht in den Abend über (Feuerwerk leuchtet)

func setup(s: Spiel) -> void:
	spiel = s
	layer = 25
	s.hud.visible = false
	s.spieler.gesperrt = true
	s.spieler.wischt = false
	if s.laeufer.aktiv:
		s.laeufer.gesperrt = true
	cam = Camera3D.new()
	cam.far = 40000.0
	cam.fov = 62.0
	s.add_child(cam)
	_start = get_viewport().get_camera_3d().global_position if get_viewport().get_camera_3d() else Vector3(80, 60, 80)
	cam.global_position = _start
	cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_phase0 = s.welt.zeit.phase if s.welt.zeit.phase >= 0.0 else Tageszeit.phase_zu(17.0)
	if Ton.i:
		Ton.i.menue = true   # Musik in voller Lautstärke
		Ton.spielen("jackpot", 0.0)
		Ton.spielen("erfolg", -2.0)
	_bauen()

func _bauen() -> void:
	wurzel = Control.new()
	wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wurzel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wurzel)
	titel = UiGlas.text("Geschafft!\nDie %s glänzt." % Wirtschaft.turm_daten(spiel.wirtschaft.turm_nr).name, 54, UiGlas.TEXT, true)
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titel.label_settings.outline_size = 14
	titel.label_settings.outline_color = Color(0.02, 0.06, 0.12, 0.85)
	titel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	titel.offset_top = 70
	titel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	titel.modulate.a = 0.0
	wurzel.add_child(titel)
	statistik = _statistik_karte()
	statistik.modulate.a = 0.0
	wurzel.add_child(statistik)
	# Mitwirkende: laufen von unten nach oben durch
	namen = VBoxContainer.new()
	namen.add_theme_constant_override("separation", 6)
	namen.anchor_left = 0.5
	namen.anchor_right = 0.5
	namen.grow_horizontal = Control.GROW_DIRECTION_BOTH
	namen.anchor_top = 1.0
	namen.anchor_bottom = 1.0
	namen.offset_top = 40
	for z in [["Clean the Skyscraper", 34, true], ["", 10, false],
			["Idee, Wünsche und Spieltests", 16, false], ["du", 26, true], ["", 10, false],
			["Programmiert mit", 16, false], ["Claude", 26, true], ["", 10, false],
			["Spiel-Engine", 16, false], ["Godot 4.7", 24, true], ["", 10, false],
			["3D-Modelle (CC0)", 16, false], ["Kenney – Car Kit, City Kit, Furniture Kit,", 20, true], ["Food Kit, Mini Characters, Mini Shop, Nature Kit, Pirate Kit", 20, true], ["", 10, false],
			["Turm, Stadt, Strand, Yacht, Fische", 16, false], ["aus Code gebaut", 24, true], ["", 10, false],
			["Musik und Geräusche", 16, false], ["aus Code erzeugt", 24, true], ["", 20, false],
			["Danke fürs Putzen!", 30, true], ["Ein neuer Turm kommt in einem späteren Teil.", 18, false]]:
		var l := UiGlas.text(z[0], z[1], UiGlas.TEXT if z[2] else UiGlas.AKZENT, z[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.label_settings.outline_size = 8
		l.label_settings.outline_color = Color(0.02, 0.06, 0.12, 0.8)
		namen.add_child(l)
	wurzel.add_child(namen)
	weiter = UiGlas.knopf("Weiterspielen", "kaufen")
	weiter.name = "weiterspielen"
	weiter.custom_minimum_size = Vector2(260, 48)
	weiter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	weiter.offset_top = -110
	weiter.offset_bottom = -62
	weiter.offset_left = -130
	weiter.offset_right = 130
	weiter.modulate.a = 0.0
	weiter.disabled = true
	weiter.pressed.connect(schliessen)
	wurzel.add_child(weiter)
	var hinweis := UiGlas.text("Esc: überspringen", 13, UiGlas.TEXT_LEISE)
	hinweis.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hinweis.offset_left = -170
	hinweis.offset_top = -34
	wurzel.add_child(hinweis)

func _statistik_karte() -> PanelContainer:
	var w := spiel.wirtschaft
	var st := w.statistik
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiGlas.box(Color(UiGlas.GLAS, 0.88), UiGlas.RAND, 16, 24))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(520, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	vb.add_child(UiGlas.text("Deine Statistik", 24, UiGlas.TEXT, true))
	var sz := int(st.spielzeit)
	var zeilen := [
		["Spielzeit", "%d h %02d min" % [sz / 3600, (sz / 60) % 60]],
		["Fenster selbst geputzt", Hud.punkte(int(st.fenster_selbst))],
		["Fenster von Helfern", Hud.punkte(int(st.fenster_helfer))],
		["Insgesamt verdient", "%s €" % Hud.punkte(int(st.verdient))],
		["Höchster Punkt", "%d m" % int(st.hoechste)],
		["Erfolge", "%d von %d" % [w.erfolge.size(), Erfolge.LISTE.size()]],
		["Szenen im Album", "%d von %d" % [w.album.size(), FensterZustand.SZENEN.size() - 1]],
		["Fische im Index", "%d von %d" % [w.fisch_index.size(), Wirtschaft.FISCHE.size()]],
		["Zu Fuß unterwegs", "%s km" % str(snappedf(float(st.gelaufen) / 1000.0, 0.1)).replace(".", ",")],
	]
	if Netz.aktiv():   # Mehrspieler (7d): wer hat wie viele Fenster geputzt
		var ids := Netz.spieler.keys()
		ids.sort()
		for i in ids.size():
			var id: int = ids[i]
			var pid: String = w.ich if id == Netz.meine_id() else str(Netz.spieler[id].get("profil_id", ""))
			zeilen.insert(2 + i,["  davon %s" % Netz.name_von(id), Hud.punkte(int(w.fenster_je.get(pid, 0)))])
	for z in zeilen:
		var hb := HBoxContainer.new()
		var a := UiGlas.text(z[0], 16, UiGlas.TEXT_LEISE)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(a)
		hb.add_child(UiGlas.text(z[1], 17, UiGlas.GELD if z[0] == "Insgesamt verdient" else UiGlas.TEXT, true))
		vb.add_child(hb)
	return p

func _input(e: InputEvent) -> void:
	if _zu:
		return
	if e is InputEventKey or e is InputEventMouseButton:
		get_viewport().set_input_as_handled()   # Spiel bekommt während des Abspanns keine Tasten
		if e.is_pressed() and zeit > 3.0 and ((e is InputEventKey and e.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]) or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not weiter.get_global_rect().has_point(e.position))):
			if zeit < DAUER - 6.0:
				zeit = DAUER - 6.0   # zum Ende springen (Knopf erscheint)
			else:
				schliessen()
	if weiter.visible and not weiter.disabled and e is InputEventMouseButton and e.pressed and weiter.get_global_rect().has_point(e.position):
		schliessen()

# Feuerwerk: bunte Kugel aus Funken um die Spitze
func _rakete() -> void:
	var t := spiel.turm.spitze
	var a := randf() * TAU
	var pos := Vector3(cos(a) * randf_range(60.0, 220.0), randf_range(t * 0.55, t * 1.08), sin(a) * randf_range(60.0, 220.0))
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * 7.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Effekte._rund()
	qm.material = m
	p.mesh = qm
	p.amount = 90
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 2.4
	p.spread = 180.0
	p.gravity = Vector3(0, -7.0, 0)
	p.initial_velocity_min = 75.0
	p.initial_velocity_max = 90.0
	p.damping_min = 22.0
	p.damping_max = 28.0
	var farbe: Color = [Color("ff4f6d"), Color("35c8ff"), Color("ffd84a"), Color("7fe08a"), Color("b18cff"), Color("ff9a3a")].pick_random()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.15, farbe * 2.2)
	g.set_color(g.get_point_count() - 1, Color(farbe, 0.0))
	p.color_ramp = g
	p.position = pos
	spiel.add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)
	Ton.spielen_bei("knall", pos, 6.0, randf_range(0.8, 1.15))

func _process(dt: float) -> void:
	if _zu:
		return
	zeit += dt
	# Uhr läuft in 12 s vor bis 21:00 Uhr (oder bleibt, wenn es schon Nacht ist)
	var ziel_p := Tageszeit.phase_zu(21.0)
	var vor := fposmod(ziel_p - _phase0, 1.0)
	if vor > 0.5:
		vor = 0.0
	spiel.welt.zeit.phase = fposmod(_phase0 + vor * smoothstep(0.0, 12.0, zeit), 1.0)
	# Feuerwerk die ganze Zeit, am Anfang dichter
	_feuer_zeit -= dt
	if _feuer_zeit <= 0.0:
		_feuer_zeit = randf_range(0.25, 0.6) if zeit < 14.0 else randf_range(0.6, 1.4)
		_rakete()
	# Kamera: vom Platz aus am Turm hinauf (0–14 s), dann weit herum um die Spitze
	var t := spiel.turm.spitze
	var ziel: Vector3
	var blick: Vector3
	if zeit < 14.0:
		var k := smoothstep(0.0, 14.0, zeit)
		var a := 0.6 + k * 1.6
		var r := lerpf(140.0, 420.0, k)
		ziel = Vector3(cos(a) * r, lerpf(30.0, t * 0.9, k), sin(a) * r)
		blick = Vector3(0, lerpf(120.0, t * 0.85, k), 0)
		if zeit < 2.0:
			ziel = _start.lerp(ziel, smoothstep(0.0, 2.0, zeit))
	else:
		var a2 := 2.2 + (zeit - 14.0) * 0.06
		var r2 := 520.0 + sin((zeit - 14.0) * 0.08) * 120.0
		ziel = Vector3(cos(a2) * r2, t * 0.75 + sin(zeit * 0.1) * 60.0, sin(a2) * r2)
		blick = Vector3(0, t * 0.7, 0)
	cam.global_position = cam.global_position.lerp(ziel, minf(1.0, dt * 2.5)) if zeit > 2.0 else ziel
	cam.look_at(blick)
	# Texte ein- und ausblenden
	titel.modulate.a = smoothstep(1.5, 3.0, zeit) * (1.0 - smoothstep(12.0, 13.5, zeit))
	statistik.modulate.a = smoothstep(14.0, 15.5, zeit) * (1.0 - smoothstep(23.0, 24.5, zeit))
	var h := get_viewport().get_visible_rect().size.y
	var lauf := clampf((zeit - 24.5) / (DAUER - 8.0 - 24.5), 0.0, 1.0)
	namen.offset_top = lerpf(40.0, -h * 0.5 - namen.size.y * 0.5, lauf)
	namen.offset_bottom = namen.offset_top + namen.size.y
	weiter.modulate.a = smoothstep(DAUER - 7.0, DAUER - 5.5, zeit)
	weiter.disabled = zeit < DAUER - 6.0

func schliessen() -> void:
	if _zu:
		return
	_zu = true
	if Ton.i:
		Ton.i.menue = false
	spiel.hud.visible = true
	spiel.spieler.gesperrt = false
	spiel.laeufer.gesperrt = false
	if spiel.spieler.aktiv:
		spiel.spieler.cam.current = true
	else:
		spiel.laeufer.cam.current = true
	cam.queue_free()
	spiel.hud.meldung("Alle Fenster sauber! Spiel einfach weiter – Tauben und Sandstürme sorgen für Nachschub.\nEin neuer Turm kommt in einem späteren Teil.", 7.0)
	fertig.emit()
	queue_free()
