class_name Spiel
extends Node3D
# Das eigentliche Spiel: Gondel + Putzen + Geld + Shop + Speichern.
# Testmodi (über haupt.gd, --ansicht=N): 5 Putz-Demo, 6/7 Fahrtests, 8 Maus-Test, 9 Shop-Test, 10 Speicher-Test.

const SPIELSTAND := "user://spielstand.json"
const TESTSTAND := "user://spielstand_test.json"
const AUTOSAVE := 20.0

var turm: Turm
var welt: Welt
var zustand: FensterZustand
var spieler: Spieler
var hud: Hud
var shop: Shop
var wirtschaft := Wirtschaft.new()
var ansicht := 0
var frei := false
var test_geld := -1
var pfad := SPIELSTAND
var speicher_zeit := 0.0
var demo_zeit := 0.0

func starten(t: Turm, w: Welt, a: int, ohne_sperre: bool, geld_test: int) -> void:
	turm = t
	welt = w
	ansicht = a
	frei = ohne_sperre
	test_geld = geld_test
	pfad = SPIELSTAND if ansicht == 0 else TESTSTAND
	zustand = FensterZustand.new(turm)
	zustand.verbinde(turm.glas)
	turm.glas.set_shader_parameter("mit_zustand", true)
	if ansicht == 10 and test_geld >= 0 and FileAccess.file_exists(pfad):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pfad))
	var stand: Dictionary = _lesen() if (ansicht == 0 or ansicht == 10) else {}
	wirtschaft.laden(stand.get("wirtschaft", {}))
	if stand.has("sauber"):
		zustand.laden(str(stand.sauber))
	if test_geld >= 0:
		wirtschaft.geld = test_geld
	spieler = Spieler.new()
	add_child(spieler)
	spieler.setup(turm, zustand, int(stand.get("stock", 2)), float(stand.get("weg", 236.0)), 0.0)
	if stand.has("y"):
		spieler.y = float(stand.y)
	spieler.fenster_sauber.connect(_fenster_sauber)
	spieler.oben_gesperrt.connect(_oben_gesperrt)
	hud = Hud.new()
	add_child(hud)
	shop = Shop.new()
	add_child(shop)
	shop.setup(wirtschaft)
	shop.geaendert.connect(_ausruestung)
	shop.neues_spiel.connect(_neues_spiel)
	_ausruestung()
	if ansicht >= 5 and ansicht <= 7:
		spieler.gesperrt = true
		spieler.yaw = 0.25
		spieler.pitch = 0.05
	if ansicht == 0 and stand.is_empty():
		hud.meldung("Willkommen! Halte die linke Maustaste und reibe das Fenster sauber.\nTab öffnet die Werkstatt.", 7.0)

# Werkzeug + Upgrades auf die Gondel übertragen
func _ausruestung() -> void:
	spieler.werkzeug_setzen(wirtschaft.werkzeug())
	spieler.tempo_faktor = wirtschaft.tempo_faktor()
	spieler.reich_seite = wirtschaft.reichweite_seite()
	spieler.reich_oben = wirtschaft.reichweite_oben()
	var oberste := Turm.STOCKWERKE if frei else wirtschaft.oberstes_stockwerk()
	spieler.max_y = oberste * Turm.STOCK_H - 2.6
	_speichern()

func _fenster_sauber(f: int, spalte: int) -> void:
	var lohn := wirtschaft.lohn(f)
	wirtschaft.geld += lohn
	hud.pop("+%d €" % lohn)
	_funkeln(spieler.fenster_mitte(f, spalte))

func _oben_gesperrt() -> void:
	hud.meldung("Das Seil ist zu kurz! Mit Tab in der Werkstatt eine längere Seilwinde kaufen.", 3.0)

# ---------------------------------------------------------------- Eingaben (Shop, Werkzeugwechsel)
func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_TAB or (e.keycode == KEY_ESCAPE and shop.offen):
		shop.umschalten()
		spieler.gesperrt = shop.offen or (ansicht >= 5 and ansicht <= 7)
		spieler.wischt = false
		get_viewport().set_input_as_handled()
	elif e.keycode >= KEY_1 and e.keycode <= KEY_5 and not shop.offen:
		var i: int = e.keycode - KEY_1
		if i < Wirtschaft.WERKZEUGE.size() and wirtschaft.ausruesten(Wirtschaft.WERKZEUGE[i].id):
			_ausruestung()
			hud.meldung(Wirtschaft.WERKZEUGE[i].name, 1.2)

# ---------------------------------------------------------------- Speichern
func _lesen() -> Dictionary:
	if not FileAccess.file_exists(pfad):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(pfad))
	return d if d is Dictionary else {}

func _speichern() -> void:
	if ansicht != 0 and ansicht != 10:
		return
	var d := {
		"version": 1,
		"wirtschaft": wirtschaft.speichern(),
		"sauber": zustand.speichern(),
		"stock": spieler.stock, "weg": spieler.weg, "y": spieler.y,
	}
	var f := FileAccess.open(pfad, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if zustand and spieler:
			_speichern()

func _neues_spiel() -> void:
	if FileAccess.file_exists(pfad):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pfad))
	zustand = null   # nicht beim Beenden wieder speichern
	set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()

# ---------------------------------------------------------------- Ablauf
func _process(dt: float) -> void:
	match ansicht:
		5: _demo(dt)
		6:
			spieler.weg += 5.0 * dt
			spieler.y = minf(spieler.y + 6.0 * dt, 30 * Turm.STOCK_H)
		7: spieler.weg += 4.0 * dt
		8: _maus_test(dt)
		9: _shop_test(dt)
		10: _speicher_test(dt)
	hud.zeige(zustand.sauber_zahl, turm.fenster_gesamt, wirtschaft.geld, spieler.y, spieler.stock)
	hud.freigeschaltet(Turm.STOCKWERKE if frei else wirtschaft.oberstes_stockwerk())
	if spieler.wischt and spieler.wz_art == "wisch":
		var u := fposmod(spieler.weg + spieler.schwamm_off.x * spieler.richtung, turm.umfaenge[spieler.stock]) / Turm.FENSTER_B
		var f := turm.stockwerk_bei(spieler.y + spieler.schwamm_off.y)
		hud.fortschritt(zustand.fortschritt(f, int(u)), true)
	else:
		hud.fortschritt(0.0, false)
	speicher_zeit += dt
	if speicher_zeit > AUTOSAVE:
		speicher_zeit = 0.0
		_speichern()

# ---------------------------------------------------------------- Funkeln
var _funkel_tex: Texture2D
func _funkeln(p: Vector3) -> void:
	var t := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.95, 0.75)
	if _funkel_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		_funkel_tex = gt
	m.albedo_texture = _funkel_tex
	qm.material = m
	t.mesh = qm
	t.amount = 28
	t.one_shot = true
	t.explosiveness = 0.85
	t.lifetime = 0.9
	t.direction = Vector3.UP
	t.spread = 180.0
	t.gravity = Vector3.ZERO
	t.initial_velocity_min = 0.6
	t.initial_velocity_max = 1.6
	t.scale_amount_min = 0.5
	t.scale_amount_max = 1.3
	t.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	t.emission_box_extents = Vector3(0.6, 1.2, 0.05)
	t.position = p
	add_child(t)
	t.emitting = true
	get_tree().create_timer(1.5).timeout.connect(t.queue_free)

# ---------------------------------------------------------------- Tests
# 5: Schwamm fährt Schlangenlinien – derselbe Code wie beim Putzen mit der Maus
func _demo(dt: float) -> void:
	demo_zeit += dt
	spieler.wischt = true
	var reihen := 14
	var dauer := 0.32
	var r := mini(int(demo_zeit / dauer), reihen - 1)
	var t := fmod(demo_zeit, dauer) / dauer
	if r % 2 == 1:
		t = 1.0 - t
	spieler.schwamm_off = Vector2(lerpf(-1.7, 1.2, t), lerpf(0.35, 2.5, float(r) / (reihen - 1)))

# 8: echte Maus-Ereignisse durch das ganze Eingabesystem
var _mt := 0
var _mt_rechts := 0
var _mt_off := Vector2.ZERO
var _mt_yaw := 0.0
func _maus_test(dt: float) -> void:
	demo_zeit += dt
	var mitte := get_viewport().get_visible_rect().size * 0.5
	if _mt == 0 and demo_zeit > 0.3:
		_klick(mitte, true)
		_klick(mitte, false)
		_mt = 1
	elif _mt == 1 and demo_zeit > 0.6:
		_klick(mitte, true)
		_mt = 2
	elif _mt == 2:
		_bewege(Vector2(cos(demo_zeit * 7.0) * 60.0, sin(demo_zeit * 2.3) * 25.0))
		if demo_zeit > 2.4 and _mt_rechts == 0:
			# Rechtsklick dazu: jetzt muss sich der Blick drehen, der Schwamm bleibt stehen
			_mt_rechts = 1
			_klick(mitte, true, MOUSE_BUTTON_RIGHT)
		elif _mt_rechts == 1:
			_mt_rechts = 2
			_mt_off = spieler.schwamm_off
			_mt_yaw = spieler.yaw
		if demo_zeit > 3.0:
			print("TEST rechtsklick: yaw geändert=%s schwamm gleich=%s" % [absf(spieler.yaw - _mt_yaw) > 0.05, spieler.schwamm_off.distance_to(_mt_off) < 0.001])
			_klick(mitte, false, MOUSE_BUTTON_RIGHT)
			_klick(mitte, false)
			print("TEST putzen: Fortschritt=%.2f" % zustand.fortschritt(spieler.stock, int(fposmod(spieler.weg, turm.umfaenge[spieler.stock]) / Turm.FENSTER_B)))
			_mt_yaw = spieler.yaw
			_mt = 3
	elif _mt == 3 and demo_zeit < 4.0:
		_bewege(Vector2(-25.0, 0.0))
	elif _mt == 3:
		print("TEST umschauen: Drehung=%.2f rad (Ziel > 0.5)" % absf(spieler.yaw - _mt_yaw))
		_mt = 4

# 9: Shop mit Tab öffnen, über die echten Knöpfe kaufen, Werkzeug wechseln, Hochdruck testen
var _st := 0
func _shop_test(dt: float) -> void:
	demo_zeit += dt
	var mitte := get_viewport().get_visible_rect().size * 0.5
	match _st:
		0:
			if demo_zeit > 0.3:
				_klick(mitte, true)
				_klick(mitte, false)
				_taste(KEY_TAB)
				_st = 1
		1:
			if demo_zeit > 0.6:
				_st = -1
				print("TEST shop offen=%s maus=%s" % [shop.offen, Input.mouse_mode])
				for n in ["wz_grossschwamm", "wz_abzieher", "up_motor", "up_arm", "up_winde", "up_winde", "wz_hochdruck"]:
					var b: Button = shop.find_child(n, true, false)
					if b and not b.disabled:
						b.pressed.emit()
					await get_tree().process_frame
				print("TEST gekauft: besitz=%s aktiv=%s stufen=%s geld=%d bis_stock=%d" % [wirtschaft.besitz, wirtschaft.aktiv, wirtschaft.stufen, wirtschaft.geld, wirtschaft.oberstes_stockwerk()])
				_taste(KEY_TAB)
				_st = 2
		2:
			if demo_zeit > 1.0:
				print("TEST shop zu=%s gesperrt=%s werkzeug=%s tempo=%.1f max_y=%.1f" % [not shop.offen, spieler.gesperrt, spieler.wz_id, spieler.tempo_faktor, spieler.max_y])
				_taste(KEY_3)
				_st = 3
		3:
			if demo_zeit > 1.3:
				print("TEST taste 3 → werkzeug=%s rx=%.2f" % [spieler.wz_id, spieler.wz_rx])
				_taste(KEY_5)
				_klick(mitte, true)
				_st = 4
		4:
			_bewege(Vector2(sin(demo_zeit * 3.0) * 30.0, cos(demo_zeit * 2.0) * 12.0))
			if demo_zeit > 3.5:
				_klick(mitte, false)
				print("TEST hochdruck: werkzeug=%s sauber=%d geld=%d" % [spieler.wz_id, zustand.sauber_zahl, wirtschaft.geld])
				_st = 5

# 10: Speichern + Laden (läuft zweimal: --geld setzt den Stand, ohne --geld wird geladen)
var _sp := 0
func _speicher_test(dt: float) -> void:
	demo_zeit += dt
	if _sp == 0 and demo_zeit > 0.5:
		if test_geld >= 0:
			wirtschaft.kaufe_werkzeug("abzieher")
			wirtschaft.kaufe_upgrade("winde")
			for s in 5:
				zustand.wische(spieler.stock, 10 + s, 0.5, 0.5, 2.0, 2.0)
			spieler.weg = 111.0
			_speichern()
			print("TEST gespeichert: geld=%d sauber=%d aktiv=%s winde=%d weg=%.1f" % [wirtschaft.geld, zustand.sauber_zahl, wirtschaft.aktiv, wirtschaft.stufen.winde, spieler.weg])
		else:
			print("TEST geladen: geld=%d sauber=%d aktiv=%s winde=%d weg=%.1f" % [wirtschaft.geld, zustand.sauber_zahl, wirtschaft.aktiv, wirtschaft.stufen.winde, spieler.weg])
		_sp = 1

func _klick(p: Vector2, gedrueckt: bool, knopf := MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = knopf
	e.pressed = gedrueckt
	e.position = p
	Input.parse_input_event(e)

func _bewege(rel: Vector2) -> void:
	var b := InputEventMouseMotion.new()
	b.position = get_viewport().get_visible_rect().size * 0.5
	b.relative = rel
	Input.parse_input_event(b)

func _taste(k: Key) -> void:
	for gedrueckt in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = gedrueckt
		Input.parse_input_event(e)
