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
var mehr: Control                    # Fenster Mehrspieler (7a)
var mehr_status: Label
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
	if Netz.menue_meldung != "":   # z. B. „Der Gastgeber hat das Spiel beendet.“
		var mm := UiGlas.text(Netz.menue_meldung, 15, Color("ffb35c"), true)
		mm.name = "netz_meldung"
		mm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mm.custom_minimum_size = Vector2(360, 0)
		vb.add_child(mm)
		Netz.menue_meldung = ""
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
	var mp := UiGlas.knopf("Mehrspieler", "nehmen")
	mp.name = "mehrspieler"
	mp.pressed.connect(_mehrspieler)
	var ei := UiGlas.knopf("Einstellungen", "nehmen")
	ei.name = "einstellungen"
	ei.pressed.connect(_einstellungen)
	var ende := UiGlas.knopf("Beenden", "nehmen")
	ende.name = "beenden"
	ende.pressed.connect(_beenden)
	for b in [weiter, mp, neu, ei, ende]:
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
	Netz.beenden()   # mit EOS: erst abmelden (sonst hängt das Spiel beim Beenden)

# ---------------------------------------------------------------- Mehrspieler (7a Heimnetz per IP, 7g Internet per Code über Epic)
func _mehrspieler() -> void:
	if mehr:
		mehr.queue_free()
	var teile := UiGlas.fenster(self, 620)
	mehr = teile[0]
	var vb: VBoxContainer = teile[1]
	var kopf := HBoxContainer.new()
	vb.add_child(kopf)
	var t := UiGlas.text("Mehrspieler", 26, UiGlas.TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(t)
	var zu := UiGlas.knopf("Zurück", "kaufen")
	zu.name = "mp_zurueck"
	zu.custom_minimum_size = Vector2(120, 38)
	zu.pressed.connect(func():
		Netz.abbrechen()
		mehr.queue_free()
		mehr = null)
	kopf.add_child(zu)
	_netz_knoepfe = []
	vb.add_child(UiGlas.text("Bis zu %d Spieler putzen gemeinsam deinen Turm. Der Spielstand liegt beim Gastgeber." % Netz.MAX_SPIELER, 14, UiGlas.TEXT_LEISE))
	# Profil
	vb.add_child(UiGlas.ueberschrift("Dein Name und deine Farbe"))
	var name_feld := LineEdit.new()
	name_feld.name = "name_feld"
	name_feld.text = Netz.profil.name
	name_feld.max_length = 16
	name_feld.custom_minimum_size = Vector2(0, 40)
	name_feld.add_theme_font_size_override("font_size", 18)
	name_feld.text_changed.connect(func(neu: String):
		Netz.profil.name = neu
		Netz.profil_speichern())
	vb.add_child(name_feld)
	var farben := HBoxContainer.new()
	farben.add_theme_constant_override("separation", 8)
	vb.add_child(farben)
	for i in Netz.FARBEN.size():
		var fb := Button.new()
		fb.name = "farbe_%d" % i
		fb.custom_minimum_size = Vector2(52, 36)
		fb.tooltip_text = Netz.FARB_NAMEN[i]
		var gewaehlt := int(Netz.profil.farbe) == i
		fb.add_theme_stylebox_override("normal", UiGlas.box(Color(Netz.FARBEN[i]), Color.WHITE if gewaehlt else Color(0, 0, 0, 0), 8, 4))
		fb.add_theme_stylebox_override("hover", UiGlas.box(Color(Netz.FARBEN[i]).lightened(0.2), Color.WHITE, 8, 4))
		fb.text = "✓" if gewaehlt else ""
		fb.pressed.connect(func():
			Netz.profil.farbe = i
			Netz.profil_speichern()
			_mehrspieler())
		farben.add_child(fb)
	# Übers Internet mit Code (7g, Epic Online Services)
	vb.add_child(UiGlas.ueberschrift("Übers Internet (mit Code)"))
	if Netz.internet_moeglich():
		var erst_i := UiGlas.knopf("Spiel erstellen und Code bekommen", "kaufen")
		erst_i.name = "erstellen_internet"
		erst_i.custom_minimum_size = Vector2(0, 44)
		erst_i.pressed.connect(_erstellen_internet)
		vb.add_child(erst_i)
		_netz_knoepfe.append(erst_i)
		var zeile_c := HBoxContainer.new()
		zeile_c.add_theme_constant_override("separation", 8)
		vb.add_child(zeile_c)
		var code_feld := LineEdit.new()
		code_feld.name = "code_feld"
		code_feld.placeholder_text = "Code vom Gastgeber, z. B. K7MP2Q"
		code_feld.max_length = 9
		code_feld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		code_feld.custom_minimum_size = Vector2(0, 40)
		code_feld.add_theme_font_size_override("font_size", 17)
		zeile_c.add_child(code_feld)
		var bei_c := UiGlas.knopf("Beitreten", "kaufen")
		bei_c.name = "beitreten_code"
		bei_c.custom_minimum_size = Vector2(140, 40)
		bei_c.pressed.connect(func(): _beitreten_code(code_feld.text))
		code_feld.text_submitted.connect(func(_t): _beitreten_code(code_feld.text))
		zeile_c.add_child(bei_c)
		_netz_knoepfe.append(bei_c)
	else:
		var hw := UiGlas.text(Netz.eos_grund + " Im Heimnetz könnt ihr trotzdem zusammen spielen.", 13, UiGlas.TEXT_LEISE)
		hw.name = "internet_hinweis"
		hw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(hw)
	# Heimnetz (7a: ENet per IP)
	vb.add_child(UiGlas.ueberschrift("Im Heimnetz (gleiches WLAN)"))
	var adr := Netz.lan_adressen()
	vb.add_child(UiGlas.text("Freunde im selben Netz treten mit dieser Adresse bei: %s" % (", ".join(adr) if adr.size() > 0 else "(keine Netzwerk-Adresse gefunden)"), 14, UiGlas.AKZENT))
	var zeile := HBoxContainer.new()
	zeile.add_theme_constant_override("separation", 8)
	vb.add_child(zeile)
	var erst := UiGlas.knopf("Spiel erstellen", "nehmen")
	erst.name = "erstellen"
	erst.custom_minimum_size = Vector2(170, 40)
	erst.pressed.connect(_erstellen)
	zeile.add_child(erst)
	var adr_feld := LineEdit.new()
	adr_feld.name = "adresse_feld"
	adr_feld.placeholder_text = "Adresse, z. B. 192.168.1.23"
	adr_feld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adr_feld.custom_minimum_size = Vector2(0, 40)
	adr_feld.add_theme_font_size_override("font_size", 17)
	zeile.add_child(adr_feld)
	var bei := UiGlas.knopf("Beitreten", "nehmen")
	bei.name = "beitreten"
	bei.custom_minimum_size = Vector2(120, 40)
	bei.pressed.connect(func(): Netz.beitreten(adr_feld.text))
	adr_feld.text_submitted.connect(func(_t): Netz.beitreten(adr_feld.text))
	zeile.add_child(bei)
	_netz_knoepfe.append_array([erst, bei])
	var zeile_s := HBoxContainer.new()
	zeile_s.add_theme_constant_override("separation", 8)
	vb.add_child(zeile_s)
	mehr_status = UiGlas.text("", 14, Color("ffb35c"))
	mehr_status.name = "mp_status"
	mehr_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mehr_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zeile_s.add_child(mehr_status)
	mp_abbrechen = UiGlas.knopf("Abbrechen", "nehmen")
	mp_abbrechen.name = "mp_abbrechen"
	mp_abbrechen.custom_minimum_size = Vector2(120, 36)
	mp_abbrechen.pressed.connect(Netz.abbrechen)
	zeile_s.add_child(mp_abbrechen)
	if not Netz.status_geaendert.is_connected(_netz_status):
		Netz.status_geaendert.connect(_netz_status)
	_knoepfe_netz()

# Knöpfe sperren, solange eine Verbindung aufgebaut wird; Abbrechen nur dann sichtbar
var _netz_knoepfe: Array = []
var mp_abbrechen: Button
func _knoepfe_netz() -> void:
	var laeuft := Netz.modus in ["erstelle", "suche", "verbinde"]
	for b in _netz_knoepfe:
		if is_instance_valid(b):
			(b as Button).disabled = laeuft
	if is_instance_valid(mp_abbrechen):
		mp_abbrechen.visible = laeuft

func _beitreten_code(t: String) -> void:
	Netz.beitreten_code(t)
	_knoepfe_netz()

func _erstellen_internet() -> void:
	var fehler: String = await Netz.host_starten_internet()   # Knöpfe sperrt schon die Status-Meldung
	if not is_instance_valid(self) or _weg:
		return
	_knoepfe_netz()
	if fehler != "":
		_netz_status(fehler)
		return
	_code_fenster()

# Nach „Spiel erstellen“ übers Internet: großer Code zum Weitergeben, Kopieren-Knopf, dann ins Spiel
var code_fenster: Control
func _code_fenster() -> void:
	if mehr:
		mehr.queue_free()
		mehr = null
	var teile := UiGlas.fenster(self, 560)
	code_fenster = teile[0]
	var vb: VBoxContainer = teile[1]
	vb.add_child(UiGlas.text("Spiel erstellt!", 26, UiGlas.TEXT, true))
	vb.add_child(UiGlas.text("Gib deinen Freunden diesen Code. Sie wählen „Mehrspieler“ und geben ihn bei „Übers Internet“ ein.", 14, UiGlas.TEXT_LEISE))
	(vb.get_child(-1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var c := UiGlas.text(Netz.code, 64, UiGlas.AKZENT, true)
	c.name = "code_gross"
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(c)
	var zeile := HBoxContainer.new()
	zeile.add_theme_constant_override("separation", 10)
	zeile.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(zeile)
	var kop := UiGlas.knopf("Code kopieren", "nehmen")
	kop.name = "code_kopieren"
	kop.custom_minimum_size = Vector2(200, 44)
	kop.pressed.connect(func():
		DisplayServer.clipboard_set(Netz.code)
		kop.text = "Kopiert ✓")
	zeile.add_child(kop)
	var los := UiGlas.knopf("Ins Spiel", "kaufen")
	los.name = "ins_spiel"
	los.custom_minimum_size = Vector2(200, 44)
	los.pressed.connect(func():
		code_fenster.queue_free()
		code_fenster = null
		schliessen()
		spiel.hud.meldung("Internet-Spiel läuft · Code %s (steht auch oben rechts und im Pausenmenü)" % Netz.code, 8.0))
	zeile.add_child(los)
	vb.add_child(UiGlas.text("Der Code gilt, solange dein Spiel läuft. Höchstens %d Spieler." % Netz.MAX_SPIELER, 12, UiGlas.TEXT_LEISE))

func _netz_status(t: String) -> void:
	if is_instance_valid(mehr_status):
		mehr_status.text = t
	_knoepfe_netz()

func _exit_tree() -> void:
	if Netz.status_geaendert.is_connected(_netz_status):
		Netz.status_geaendert.disconnect(_netz_status)

func _erstellen() -> void:
	var fehler := Netz.host_starten()
	if fehler != "":
		_netz_status(fehler)
		return
	if mehr:
		mehr.queue_free()
		mehr = null
	schliessen()
	var adr := Netz.lan_adressen()
	spiel.hud.meldung("Mehrspieler-Spiel erstellt! Freunde treten bei mit: %s" % (adr[0] if adr.size() > 0 else "deiner Adresse"), 8.0)

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
