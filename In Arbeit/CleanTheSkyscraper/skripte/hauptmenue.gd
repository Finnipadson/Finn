class_name Hauptmenue
extends CanvasLayer
# Hauptmenü (Phase 5): Beim Start fliegt die Kamera langsam um den Turm (echte Spielwelt, Tageszeit läuft weiter),
# links ein Glas-Menü mit Weiterspielen, Neues Spiel, Einstellungen und Beenden. Das Spiel ist so lange angehalten.

signal geschlossen

static var ueberspringen := false   # nach „Neues Spiel“ direkt ins Spiel (Szene wird neu geladen)

var spiel: Spiel
var cam: Camera3D
var winkel := 2.2
var zeit := 0.0
var wurzel: Control
var knoepfe: VBoxContainer
var einst: Control                   # Fenster Einstellungen
var neu_bestaetigen := false
var hat_stand := false
var _weg := false

func setup(s: Spiel) -> void:
	spiel = s
	layer = 20
	hat_stand = FileAccess.file_exists(s.pfad) and s.zustand.sauber_zahl + s.wirtschaft.geld > 0
	s.process_mode = Node.PROCESS_MODE_DISABLED
	s.hud.visible = false
	cam = Camera3D.new()
	cam.far = 40000.0
	cam.fov = 55.0
	add_child(cam)
	cam.current = true
	_kamera(0.0)
	if Ton.i:
		Ton.i.menue = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_bauen()

func _bauen() -> void:
	wurzel = Control.new()
	wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wurzel)
	# weicher dunkler Verlauf links, damit das Menü lesbar bleibt
	var verlauf := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.04, 0.08, 0.75))
	g.set_color(1, Color(0.02, 0.04, 0.08, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	verlauf.texture = gt
	verlauf.stretch_mode = TextureRect.STRETCH_SCALE
	verlauf.anchor_bottom = 1.0
	verlauf.offset_right = 760
	verlauf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wurzel.add_child(verlauf)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiGlas.box(Color(UiGlas.GLAS, 0.82), UiGlas.RAND, 18, 30))
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 70
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(420, 0)
	wurzel.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var titel := UiGlas.text("Clean the\nSkyscraper", 46, UiGlas.TEXT, true)
	titel.label_settings.line_spacing = -8
	vb.add_child(titel)
	vb.add_child(UiGlas.text("Die Wüstennadel · %d m · %s Fenster" % [int(spiel.turm.spitze), Hud.punkte(spiel.turm.fenster_gesamt)], 15, UiGlas.AKZENT, true))
	if hat_stand:
		var proz := 100.0 * spiel.zustand.sauber_zahl / maxf(1.0, spiel.turm.fenster_gesamt)
		vb.add_child(UiGlas.text("Dein Stand: %s %% sauber · %s €" % [str(snappedf(proz, 0.1)).replace(".", ","), Hud.punkte(spiel.wirtschaft.geld)], 14, UiGlas.TEXT_LEISE))
	var abstand := Control.new()
	abstand.custom_minimum_size = Vector2(0, 14)
	vb.add_child(abstand)
	knoepfe = VBoxContainer.new()
	knoepfe.add_theme_constant_override("separation", 10)
	vb.add_child(knoepfe)
	_knoepfe()
	var fuss := UiGlas.text("Maus + Tastatur · Tab Werkstatt · M Karte · B Album", 12, UiGlas.TEXT_LEISE)
	vb.add_child(fuss)

func _knoepfe() -> void:
	for c in knoepfe.get_children():
		knoepfe.remove_child(c)
		c.queue_free()
	var weiter := UiGlas.knopf("Weiterspielen" if hat_stand else "Spielen", "kaufen")
	weiter.name = "weiter"
	weiter.pressed.connect(schliessen)
	var neu := UiGlas.knopf("Wirklich alles löschen? Nochmal klicken" if neu_bestaetigen else "Neues Spiel", "gefahr" if neu_bestaetigen else "nehmen")
	neu.name = "neu"
	neu.pressed.connect(_neu)
	neu.visible = hat_stand
	var ei := UiGlas.knopf("Einstellungen", "nehmen")
	ei.name = "einstellungen"
	ei.pressed.connect(_einstellungen)
	var ende := UiGlas.knopf("Beenden", "nehmen")
	ende.name = "beenden"
	ende.pressed.connect(_beenden)
	for b in [weiter, neu, ei, ende]:
		(b as Button).custom_minimum_size = Vector2(360, 48)
		(b as Button).add_theme_font_size_override("font_size", 18)
		knoepfe.add_child(b)

func _neu() -> void:
	if not neu_bestaetigen:
		neu_bestaetigen = true
		_knoepfe()
		return
	ueberspringen = true
	if Ton.i:
		Ton.i.menue = false
	spiel._neues_spiel()

func _einstellungen() -> void:
	if einst:
		einst.queue_free()
	var teile := UiGlas.fenster(self, 760)
	einst = teile[0]
	var vb: VBoxContainer = teile[1]
	var kopf := HBoxContainer.new()
	vb.add_child(kopf)
	var t := UiGlas.text("Einstellungen", 26, UiGlas.TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(t)
	var zu := UiGlas.knopf("Zurück", "kaufen")
	zu.name = "zurueck"
	zu.custom_minimum_size = Vector2(120, 38)
	zu.pressed.connect(func():
		einst.queue_free()
		einst = null)
	kopf.add_child(zu)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, maxf(300.0, get_viewport().get_visible_rect().size.y - 220.0))
	vb.add_child(sc)
	var ui := EinstellungenUi.new()
	ui.name = "einstellungen_ui"
	sc.add_child(ui)

func _beenden() -> void:
	spiel._speichern()
	get_tree().quit()

# Ins Spiel: Menü ausblenden, Spiel weiterlaufen lassen
func schliessen() -> void:
	if _weg:
		return
	_weg = true
	if Ton.i:
		Ton.i.menue = false
	spiel.process_mode = Node.PROCESS_MODE_INHERIT
	spiel.hud.visible = true
	if spiel.spieler.aktiv:
		spiel.spieler.cam.current = true
	elif spiel.laeufer.aktiv:
		spiel.laeufer.cam.current = true
	else:
		spiel.spieler.cam.current = true
	var tw := create_tween()
	tw.tween_property(wurzel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		geschlossen.emit()
		queue_free())

# Kamera: langsam um den Turm, Höhe und Abstand schwingen leicht
func _kamera(dt: float) -> void:
	zeit += dt
	winkel += dt * TAU / 150.0
	var r := 820.0 + sin(zeit * 0.05) * 160.0
	var h := 260.0 + sin(zeit * 0.037 + 1.0) * 170.0
	cam.position = Vector3(cos(winkel) * r, h, sin(winkel) * r)
	cam.look_at(Vector3(0, spiel.turm.spitze * 0.42 + sin(zeit * 0.03) * 60.0, 0))

func _process(dt: float) -> void:
	if not _weg:
		_kamera(dt)
