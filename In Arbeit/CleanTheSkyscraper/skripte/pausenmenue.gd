class_name Pausenmenue
extends CanvasLayer
# Esc im Spiel (wenn kein anderes Menü offen ist): Spiel pausiert, Glas-Menü mit Weiterspielen, Einstellungen,
# Speichern, Hauptmenü und Speichern + Beenden. Esc im Menü = weiterspielen.

var spiel: Spiel
var wurzel: Control
var einst: Control
var info: Label
var _zu := false

func setup(s: Spiel) -> void:
	spiel = s
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	s.spieler.wischt = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var teile := UiGlas.fenster(self, 420)
	wurzel = teile[0]
	var vb: VBoxContainer = teile[1]
	vb.add_child(UiGlas.text("Pause", 30, UiGlas.TEXT, true))
	var w := s.wirtschaft
	var sz := int(w.statistik.spielzeit)
	var proz := 100.0 * s.zustand.sauber_zahl / maxf(1.0, s.turm.fenster_gesamt)
	vb.add_child(UiGlas.text("%s %% sauber · %s € · gespielt %d h %02d min" % [str(snappedf(proz, 0.1)).replace(".", ","), Hud.punkte(w.geld), sz / 3600, (sz / 60) % 60], 14, UiGlas.TEXT_LEISE))
	var abst := Control.new()
	abst.custom_minimum_size = Vector2(0, 6)
	vb.add_child(abst)
	for k in [["weiter", "Weiterspielen", "kaufen", schliessen], ["einstellungen", "Einstellungen", "nehmen", _einstellungen],
			["speichern", "Speichern", "nehmen", _speichern], ["hauptmenue", "Hauptmenü", "nehmen", _hauptmenue],
			["beenden", "Speichern und beenden", "gefahr", _beenden]]:
		var b := UiGlas.knopf(k[1], k[2])
		b.name = k[0]
		b.custom_minimum_size = Vector2(370, 46)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(k[3])
		vb.add_child(b)
	info = UiGlas.text("Esc: weiterspielen", 13, UiGlas.TEXT_LEISE)
	vb.add_child(info)

func _input(e: InputEvent) -> void:
	if _zu or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if einst:
			einst.queue_free()
			einst = null
		else:
			schliessen()

func _speichern() -> void:
	spiel._speichern()
	info.text = "Gespeichert ✓"

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

func _hauptmenue() -> void:
	spiel._speichern()
	_weg()
	if spiel.get_parent().has_method("hauptmenue_zeigen"):
		spiel.get_parent().hauptmenue_zeigen()

func _beenden() -> void:
	spiel._speichern()
	get_tree().quit()

func schliessen() -> void:
	_weg()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _weg() -> void:
	if _zu:
		return
	_zu = true
	get_tree().paused = false
	spiel.pause = null
	queue_free()
