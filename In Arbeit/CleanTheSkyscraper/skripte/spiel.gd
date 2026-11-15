class_name Spiel
extends Node3D
# Das eigentliche Spiel: Gondel + Putzen + Geld + Shop + Speichern.
# Testmodi (über haupt.gd, --ansicht=N): 5 Putz-Demo, 6/7 Fahrtests, 8 Maus-Test, 9 Shop-Test, 10 Speicher-Test, 13 Laufen, 14 Händler, 16 Casino, 17 Casino-Bilder.

const SPIELSTAND := "user://spielstand.json"
const TESTSTAND := "user://spielstand_test.json"
const AUTOSAVE := 20.0

var turm: Turm
var welt: Welt
var zustand: FensterZustand
var spieler: Spieler
var hud: Hud
var shop: Shop
var album: Album
var ereignisse: Ereignisse
var laeufer: Laeufer
var haendler: Haendler
var hmenu: HaendlerMenu
var casino: Casino
var cmenu: CasinoMenu
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
	album = Album.new()
	add_child(album)
	album.setup(wirtschaft)
	ereignisse = Ereignisse.new()
	add_child(ereignisse)
	ereignisse.setup(spieler, zustand, turm, welt, hud)
	ereignisse.erlaubt = wirtschaft.einstellungen
	laeufer = Laeufer.new()
	add_child(laeufer)
	laeufer.setup(turm, welt)
	for sp in welt.stellplaetze:
		laeufer.hindernisse.append(sp.rect)
	laeufer.hindernisse.append_array(welt.hindernisse)   # Palmen, Laternen
	laeufer.polygone.append(welt.see_umriss(Laeufer.RADIUS + 0.75))   # nicht in den See laufen
	haendler = Haendler.new()
	add_child(haendler)
	haendler.setup(welt.stand_orte)
	laeufer.hindernisse.append_array(haendler.rechtecke)
	hmenu = HaendlerMenu.new()
	add_child(hmenu)
	hmenu.setup(wirtschaft)
	hmenu.geaendert.connect(_ausruestung)
	casino = Casino.new()
	add_child(casino)
	casino.setup(welt.casino_rect)
	laeufer.hindernisse.append_array(casino.rechtecke)
	cmenu = CasinoMenu.new()
	add_child(cmenu)
	cmenu.setup(wirtschaft)
	cmenu.gespielt.connect(_speichern)
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
	var ka := wirtschaft.kosmetik_aktiv
	spieler.aussehen(wirtschaft.kosmetik(ka.gondel).farbe, wirtschaft.kosmetik(ka.kleidung).farbe, wirtschaft.kosmetik(ka.schwamm).farbe)
	_werte()
	if ereignisse:
		ereignisse.erlaubt = wirtschaft.einstellungen
	var oberste := Turm.STOCKWERKE if frei else wirtschaft.oberstes_stockwerk()
	spieler.max_y = oberste * Turm.STOCK_H - 2.6
	_speichern()

# Upgrades + laufende Boosts auf die Gondel übertragen (jedes Bild, weil Boosts ablaufen)
func _werte() -> void:
	spieler.tempo_faktor = wirtschaft.tempo_faktor() * (1.6 if wirtschaft.boost_aktiv("kaffee") else 1.0)
	var eis := 0.8 if wirtschaft.boost_aktiv("eis") else 0.0
	spieler.reich_seite = wirtschaft.reichweite_seite() + eis
	spieler.reich_oben = wirtschaft.reichweite_oben() + eis
	spieler.wisch_faktor = 1.5 if wirtschaft.boost_aktiv("glanzspray") else 1.0
	if ereignisse:
		ereignisse.limo = wirtschaft.boost_aktiv("limo")
	var t := ""
	for id in wirtschaft.boosts:
		var rest := int(wirtschaft.boosts[id])
		t += "%s %d:%02d\n" % [Wirtschaft.BOOSTS[id].name, rest / 60, rest % 60]
	hud.boosts(t.strip_edges())

func _fenster_sauber(f: int, spalte: int) -> void:
	var lohn := wirtschaft.lohn(f) * (2 if wirtschaft.boost_aktiv("goldpolitur") else 1)
	wirtschaft.geld += lohn
	hud.pop("+%d €" % lohn)
	_funkeln(spieler.fenster_mitte(f, spalte))
	var szene := zustand.szene(f, spalte)
	if szene > 0:
		var k := str(szene)
		var neu := not wirtschaft.album.has(k)
		wirtschaft.album[k] = int(wirtschaft.album.get(k, 0)) + 1
		var name: String = FensterZustand.SZENEN[szene]
		if neu:
			var bonus := 10 * lohn
			wirtschaft.geld += bonus
			hud.meldung("Neu im Sammelalbum: %s!  +%d €
(B öffnet das Album)" % [name, bonus], 4.0)
		else:
			hud.meldung(name, 1.5)

func _oben_gesperrt() -> void:
	hud.meldung("Das Seil ist zu kurz! Mit Tab in der Werkstatt eine längere Seilwinde kaufen.", 3.0)

# ---------------------------------------------------------------- Eingaben (Shop, Werkzeugwechsel)
func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if cmenu.offen:
		if e.keycode == KEY_E or e.keycode == KEY_ESCAPE:
			cmenu.schliessen()
			get_viewport().set_input_as_handled()
		return
	if hmenu.offen:
		if e.keycode == KEY_E or e.keycode == KEY_ESCAPE:
			hmenu.schliessen()
			get_viewport().set_input_as_handled()
		return
	if (e.keycode == KEY_TAB and not album.offen) or (e.keycode == KEY_ESCAPE and shop.offen):
		shop.umschalten()
		spieler.gesperrt = shop.offen or (ansicht >= 5 and ansicht <= 7)
		spieler.wischt = false
		get_viewport().set_input_as_handled()
	elif (e.keycode == KEY_B and not shop.offen) or (e.keycode == KEY_ESCAPE and album.offen):
		album.umschalten()
		spieler.gesperrt = album.offen or (ansicht >= 5 and ansicht <= 7)
		spieler.wischt = false
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_E and not shop.offen and not album.offen:
		_ein_aus()
	elif e.keycode >= KEY_1 and e.keycode <= KEY_5 and not shop.offen:
		var i: int = e.keycode - KEY_1
		if i < Wirtschaft.WERKZEUGE.size() and wirtschaft.ausruesten(Wirtschaft.WERKZEUGE[i].id):
			_ausruestung()
			hud.meldung(Wirtschaft.WERKZEUGE[i].name, 1.2)

# ---------------------------------------------------------------- Aussteigen / Einsteigen
const UNTEN := 0.5        # Gondelboden so tief = ganz unten, man kann aussteigen
const EINSTEIG_WEIT := 4.0

func _ein_aus() -> void:
	if spieler.aktiv:
		if spieler.y > UNTEN:
			hud.meldung("Fahr mit S ganz nach unten, um auszusteigen.", 2.0)
			return
		var n := spieler.normal
		var pos := spieler.gondel.global_position + n * 2.2
		spieler.aktiv = false
		laeufer.aktivieren(pos, atan2(n.x, n.z), spieler.gondel.global_position)
		hud.steuerung(true)
	else:
		var st := haendler.stand_bei(Vector2(laeufer.position.x, laeufer.position.z))
		if st >= 0:
			hmenu.oeffnen(Haendler.STAENDE[st].id, Haendler.STAENDE[st].name)
			laeufer.gesperrt = true
			return
		var cs := casino.station_bei(Vector2(laeufer.position.x, laeufer.position.z))
		if cs >= 0:
			cmenu.oeffnen(Casino.STATIONEN[cs].id, Casino.STATIONEN[cs].name)
			laeufer.gesperrt = true
			return
		if _abstand_gondel() > EINSTEIG_WEIT:
			hud.meldung("Geh zurück zur Gondel, um einzusteigen.", 2.0)
			return
		laeufer.deaktivieren()
		spieler.aktiv = true
		spieler.cam.current = true
		hud.steuerung(false)

func _abstand_gondel() -> float:
	var g := spieler.gondel.global_position
	return Vector2(laeufer.position.x - g.x, laeufer.position.z - g.z).length()

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
		11: _szenen_test(dt)
		12: _ereignis_test(dt)
		13: _lauf_test(dt)
		14: _haendler_test(dt)
		15: _kiosk_bilder(dt)
		16: _casino_test(dt)
		17: _casino_bilder(dt)
	if ansicht == 0 or ansicht == 12:
		ereignisse.takt(dt)
	# Neue Höhe erreicht (je 6 Stockwerke = ein Abschnitt): einmaliger Bonus + Aussicht feiern
	var abschnitt := spieler.stock / Wirtschaft.ABSCHNITT
	if abschnitt > wirtschaft.hoechster_abschnitt:
		wirtschaft.hoechster_abschnitt = abschnitt
		var bonus := 25 * wirtschaft.lohn(spieler.stock)
		wirtschaft.geld += bonus
		hud.meldung("Neue Höhe: %d m!  Höhenbonus +%d €" % [int(spieler.y), bonus], 3.5)
		_speichern()
	hud.zeige(zustand.sauber_zahl, turm.fenster_gesamt, wirtschaft.geld, spieler.y, spieler.stock, not spieler.aktiv)
	var menue := shop.offen or album.offen or hmenu.offen or cmenu.offen
	laeufer.set_process(not menue)
	laeufer.gesperrt = menue
	wirtschaft.boosts_takt(dt)
	_werte()
	if spieler.aktiv:
		hud.status("E: Gondel verlassen" if spieler.y <= UNTEN else "")
	else:
		var st2 := haendler.stand_bei(Vector2(laeufer.position.x, laeufer.position.z))
		var cs2 := casino.station_bei(Vector2(laeufer.position.x, laeufer.position.z))
		if st2 >= 0:
			hud.status("E: %s ansehen" % Haendler.STAENDE[st2].name)
		elif cs2 >= 0:
			hud.status("E: %s" % Casino.STATIONEN[cs2].hinweis)
		else:
			hud.status("E: in die Gondel einsteigen" if _abstand_gondel() <= EINSTEIG_WEIT else "")
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

# 11: alle 10 Szenen nebeneinander in die Fenster vor der Gondel setzen und sauber machen
var _sz := 0
func _szenen_test(_dt: float) -> void:
	if _sz == 0:
		_sz = 1
		spieler.gesperrt = true
		var mitte := int(spieler.weg / Turm.FENSTER_B)
		for i in 10:
			var f := spieler.stock + (0 if i < 5 else 1)
			var sp := mitte - 2 + (i % 5)
			zustand.szene_setzen(f, sp, i + 1)
			while not zustand.wische(f, sp, 0.5, 0.5, 2.0, 2.0):
				pass
			_fenster_sauber(f, sp)
		spieler.pitch = 0.18
		print("TEST album: %s" % [wirtschaft.album])

# 15: nacheinander vor jeden Kiosk stellen (für Testbilder)
func _kiosk_bilder(dt: float) -> void:
	demo_zeit += dt
	if spieler.aktiv:
		spieler.y = 0.3
		_ein_aus()
	var i := mini(int(demo_zeit / 1.5), 2) if demo_zeit < 4.5 else mini(int((demo_zeit - 4.5) / 1.5), 2)
	var v: Vector2 = haendler.vorne[i]
	var r := v.normalized()
	var weit := 7.0 if demo_zeit < 4.5 else 1.6   # danach jeden Kiosk von nah
	laeufer.position = Vector3(v.x - r.x * weit, 0, v.y - r.y * weit)
	laeufer.yaw = atan2(-r.x, -r.y) + (0.25 if demo_zeit < 4.5 else 0.0)
	laeufer.pitch = 0.02

# 14: zu den Ständen gehen, mit E öffnen, über die echten Knöpfe kaufen, Wirkung prüfen
var _ht := 0
func _haendler_test(dt: float) -> void:
	demo_zeit += dt
	var mitte := get_viewport().get_visible_rect().size * 0.5
	match _ht:
		0:
			spieler.y = 0.3
			if demo_zeit > 0.4:
				_klick(mitte, true)
				_klick(mitte, false)
				_taste(KEY_E)          # aussteigen
				_ht = 1
		1:
			if demo_zeit > 0.7:
				# vor den Snackstand stellen (Stand 2) und ansprechen
				var v: Vector2 = haendler.vorne[2]
				laeufer.position = Vector3(v.x, 0, v.y)
				_taste(KEY_E)
				_ht = 2
		2:
			if demo_zeit > 1.0:
				_ht = -1
				print("TEST snackstand offen=%s stand=%s" % [hmenu.offen, hmenu.stand])
				for n in ["b_kaffee", "b_eis", "b_limo"]:
					var b: Button = hmenu.find_child(n, true, false)
					if b and not b.disabled:
						b.pressed.emit()
					await get_tree().process_frame
				print("TEST boosts=%s tempo=%.2f reich=%.1f limo=%s" % [wirtschaft.boosts.keys(), spieler.tempo_faktor, spieler.reich_seite, ereignisse.limo])
				_taste(KEY_E)
				await get_tree().create_timer(0.2).timeout
				var v2: Vector2 = haendler.vorne[1]
				laeufer.position = Vector3(v2.x, 0, v2.y)
				_taste(KEY_E)
				await get_tree().create_timer(0.2).timeout
				for n in ["k_gondel_rot", "k_kleid_orange", "k_schwamm_pink"]:
					var b: Button = hmenu.find_child(n, true, false)
					if b and not b.disabled:
						b.pressed.emit()
					await get_tree().process_frame
				print("TEST mode: aktiv=%s gondelfarbe=%s jacke=%s" % [wirtschaft.kosmetik_aktiv, spieler.gondel_mat.albedo_color.to_html(false), spieler.arm_mat.albedo_color.to_html(false)])
				_taste(KEY_E)
				await get_tree().create_timer(0.2).timeout
				var v3: Vector2 = haendler.vorne[0]
				laeufer.position = Vector3(v3.x, 0, v3.y)
				_taste(KEY_E)
				await get_tree().create_timer(0.2).timeout
				for n in ["b_glanzspray", "b_goldpolitur"]:
					var b: Button = hmenu.find_child(n, true, false)
					if b and not b.disabled:
						b.pressed.emit()
					await get_tree().process_frame
				print("TEST putzmittel: wisch_faktor=%.1f gold=%s geld=%d" % [spieler.wisch_faktor, wirtschaft.boost_aktiv("goldpolitur"), wirtschaft.geld])
				_taste(KEY_E)
				await get_tree().create_timer(0.2).timeout
				# Blick auf die Stände
				var vm: Vector2 = haendler.vorne[1]
				var r := vm.normalized()
				laeufer.position = Vector3(vm.x - r.x * 9.0, 0, vm.y - r.y * 9.0)
				laeufer.yaw = atan2(-r.x, -r.y)
				laeufer.pitch = -0.05
				print("TEST menü zu=%s" % (not hmenu.offen))

# 13: unten aussteigen, zum Turm laufen (muss vorher stoppen), zurück und einsteigen
var _lt := 0
func _lauf_test(dt: float) -> void:
	demo_zeit += dt
	var mitte := get_viewport().get_visible_rect().size * 0.5
	match _lt:
		0:
			spieler.y = 0.3
			if demo_zeit > 0.4:
				_klick(mitte, true)
				_klick(mitte, false)
				_taste(KEY_E)
				_lt = 1
		1:
			if demo_zeit > 0.7:
				print("TEST ausgestiegen: zu_fuss=%s kamera_laeufer=%s" % [not spieler.aktiv, laeufer.cam.current])
				_halte(KEY_S, true)       # rückwärts vom Turm weg
				_lt = 2
		2:
			if demo_zeit > 2.7:
				_halte(KEY_S, false)
				print("TEST weggelaufen: abstand_gondel=%.1f" % _abstand_gondel())
				_taste(KEY_E)             # zu weit weg → darf nicht einsteigen
				_lt = 3
		3:
			if demo_zeit > 3.0:
				print("TEST zu weit weg: noch zu Fuß=%s" % (not spieler.aktiv))
				_halte(KEY_W, true)       # zurück Richtung Gondel/Turm
				_lt = 4
		4:
			if demo_zeit > 6.5:
				_halte(KEY_W, false)
				print("TEST an der Gondel gestoppt: abstand=%.1f (>= 1.9)" % _abstand_gondel())
				_taste(KEY_E)
				_lt = 5
		5:
			if demo_zeit > 6.8:
				print("TEST eingestiegen: in_gondel=%s kamera_gondel=%s" % [spieler.aktiv, spieler.cam.current])
				_lt = 6
		6:
			# Einstellungen über die echten Knöpfe in der Werkstatt ausschalten
			_taste(KEY_TAB)
			_lt = 7
		7:
			if demo_zeit > 7.2:
				_lt = -1
				for n in ["ein_tauben", "ein_sandsturm"]:
					var b: Button = shop.find_child(n, true, false)
					if b:
						b.pressed.emit()
					await get_tree().process_frame
				print("TEST einstellungen: %s erlaubt_ereignisse=%s" % [wirtschaft.einstellungen, ereignisse.erlaubt])
				_taste(KEY_TAB)

# 17: Casino von außen, innen und jede Station (für Testbilder)
func _casino_bilder(dt: float) -> void:
	demo_zeit += dt
	if spieler.aktiv:
		spieler.y = 0.3
		_ein_aus()
	var i := int(demo_zeit / 1.5)
	var m := casino.mitte
	var von := casino.eingang + Vector2(-16.0, -9.0)
	var nach := m
	laeufer.pitch = 0.12
	match i:
		0: pass
		1:
			von = casino.eingang + Vector2(-2.0, 0.0)
			laeufer.pitch = 0.2
		2:
			von = m + Vector2(-11.5, 0.0)
			nach = m + Vector2(5.0, 0.0)
			laeufer.pitch = 0.05
		3:
			von = m + Vector2(10.5, -11.0)
			nach = m + Vector2(-4.0, 6.0)
			laeufer.pitch = -0.05
		_:
			var k := mini(i - 4, 3)
			von = casino.vorne[k]
			nach = casino.ziel[k]
			laeufer.pitch = 0.0 if k != 1 else 0.3
	var d := (nach - von).normalized()
	laeufer.position = Vector3(von.x, 0, von.y)
	laeufer.yaw = atan2(-d.x, -d.y)

# 16: ins Casino laufen, jede Station mit E öffnen, über die echten Knöpfe spielen, Geld prüfen
var _ct := 0
func _casino_test(dt: float) -> void:
	demo_zeit += dt
	var mitte := get_viewport().get_visible_rect().size * 0.5
	match _ct:
		0:
			spieler.y = 0.3
			if demo_zeit > 0.4:
				_klick(mitte, true)
				_klick(mitte, false)
				_taste(KEY_E)          # aussteigen
				_ct = 1
		1:
			if demo_zeit > 0.7:
				# draußen vor die Tür stellen, hineinschauen und mit W hineinlaufen
				laeufer.position = Vector3(casino.eingang.x, 0, casino.eingang.y)
				laeufer.yaw = atan2(-1.0, 0.0)
				_halte(KEY_W, true)
				_ct = 2
		2:
			if demo_zeit > 3.2:
				_halte(KEY_W, false)
				var p := Vector2(laeufer.position.x, laeufer.position.z)
				print("TEST durch die Tür gelaufen: drinnen=%s" % casino.drinnen(p))
				# gegen die Wand neben der Tür: darf nicht durch
				laeufer.position = Vector3(casino.eingang.x, 0, casino.eingang.y + 7.0)
				_halte(KEY_W, true)
				_ct = 3
		3:
			if demo_zeit > 5.2:
				_halte(KEY_W, false)
				var p := Vector2(laeufer.position.x, laeufer.position.z)
				var erreichbar := true
				for v in casino.vorne:
					erreichbar = erreichbar and laeufer.frei(v)
				print("TEST Wand hält: draußen=%s  Stationen frei erreichbar=%s" % [not casino.drinnen(p), erreichbar])
				_ct = -1
				await _casino_spielen()
				_ct = 4

func _zu_station(i: int) -> void:
	var v: Vector2 = casino.vorne[i]
	var d: Vector2 = (casino.ziel[i] - v).normalized()
	laeufer.position = Vector3(v.x, 0, v.y)
	laeufer.yaw = atan2(-d.x, -d.y)
	laeufer.pitch = 0.25 if i == 1 else 0.0
	await get_tree().create_timer(0.8).timeout
	print("TEST station %d: hinweis='%s'" % [i, hud.status_l.text])
	_taste(KEY_E)
	await get_tree().create_timer(0.4).timeout

func _knopf_druecken(name: String) -> bool:
	var b: Button = cmenu.find_child(name, true, false)
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true

func _casino_spielen() -> void:
	cmenu.schnell = true
	cmenu.rng.seed = 4711
	var fehler := 0
	# ---- Blackjack
	await _zu_station(0)
	print("TEST blackjack offen=%s spiel=%s maus_frei=%s einsatz=%d max=%d" % [cmenu.offen, cmenu.spiel, Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, cmenu.einsatz, CasinoRegeln.max_einsatz(wirtschaft.geld)])
	_knopf_druecken("b_plus")
	_knopf_druecken("b_plus")
	var start := wirtschaft.geld
	for r in 12:
		var vorher := wirtschaft.geld
		var e := cmenu.einsatz
		_knopf_druecken("b_austeilen")
		var abgezogen := wirtschaft.geld == vorher - e or not cmenu.laeuft
		while cmenu.laeuft and CasinoRegeln.wert(cmenu.bj_spieler) < 16:
			_knopf_druecken("b_ziehen")
		if cmenu.laeuft:
			_knopf_druecken("b_stehen")
		var sw := CasinoRegeln.wert(cmenu.bj_spieler)
		var gw := CasinoRegeln.wert(cmenu.bj_geber)
		var soll := vorher - e + int(round(e * CasinoRegeln.bj_auszahlung(cmenu.bj_spieler, cmenu.bj_geber)))
		var geber_ok := gw >= 17 or sw > 21 or CasinoRegeln.ist_blackjack(cmenu.bj_spieler) or CasinoRegeln.ist_blackjack(cmenu.bj_geber)
		var ok := wirtschaft.geld == soll and geber_ok and not cmenu.laeuft
		if not ok:
			fehler += 1
		if r < 5:
			print("TEST blackjack runde %d: du=%d geber=%d faktor=%.1f geld %d → %d (soll %d) ok=%s abgezogen=%s | %s" % [r + 1, sw, gw, cmenu.letzter_faktor, vorher, wirtschaft.geld, soll, ok, abgezogen, cmenu.ergebnis.text])
		await get_tree().process_frame
	print("TEST blackjack 12 Runden: geld %d → %d, fehler=%d" % [start, wirtschaft.geld, fehler])
	await get_tree().create_timer(0.8).timeout
	_taste(KEY_E)
	await get_tree().create_timer(0.3).timeout
	print("TEST blackjack zu=%s maus_gefangen=%s" % [not cmenu.offen, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED])
	# ---- Glücksrad
	await _zu_station(1)
	_knopf_druecken("b_max")
	for r in 5:
		var vorher := wirtschaft.geld
		var e := cmenu.einsatz
		_knopf_druecken("b_drehen")
		var gesperrt := not _knopf_druecken("b_drehen")      # während des Drehens kein zweiter Dreh
		while cmenu.laeuft:
			await get_tree().process_frame
		var m := float(CasinoRegeln.RAD[cmenu.rad_feld])
		var soll := vorher - e + int(round(e * m))
		if wirtschaft.geld != soll or cmenu.rad.feld() != cmenu.rad_feld:
			fehler += 1
		print("TEST rad dreh %d: einsatz=%d feld=%d (%s) zeiger_auf=%d geld %d → %d (soll %d) knopf_gesperrt=%s" % [r + 1, e, cmenu.rad_feld, CasinoRegeln.mal(m), cmenu.rad.feld(), vorher, wirtschaft.geld, soll, gesperrt])
	await get_tree().create_timer(0.6).timeout
	# mitten im Drehen schließen: Ergebnis kommt sofort
	var v2 := wirtschaft.geld
	var e2 := cmenu.einsatz
	_knopf_druecken("b_drehen")
	await get_tree().process_frame
	_taste(KEY_E)
	await get_tree().create_timer(0.3).timeout
	print("TEST rad beim Drehen geschlossen: zu=%s abgerechnet=%s" % [not cmenu.offen, wirtschaft.geld == v2 - e2 + cmenu.letzter_gewinn and not cmenu.laeuft])
	# ---- Bandit
	await _zu_station(2)
	for r in 8:
		var vorher := wirtschaft.geld
		var e := cmenu.einsatz
		_knopf_druecken("b_hebel")
		while cmenu.laeuft:
			await get_tree().process_frame
		var z: Array = cmenu.walzen_ziel
		var soll := vorher - e + int(round(e * CasinoRegeln.walzen_gewinn(z[0], z[1], z[2])))
		var zeigt := [cmenu.walzen[0].symbol(), cmenu.walzen[1].symbol(), cmenu.walzen[2].symbol()]
		if wirtschaft.geld != soll or zeigt != z:
			fehler += 1
		if r < 4:
			print("TEST bandit %d: walzen=%s zeigt=%s faktor=%.1f geld %d → %d (soll %d) | %s" % [r + 1, z, zeigt, cmenu.letzter_faktor, vorher, wirtschaft.geld, soll, cmenu.ergebnis.text])
	await get_tree().create_timer(0.8).timeout
	_taste(KEY_ESCAPE)
	await get_tree().create_timer(0.3).timeout
	# ---- Rubbellos: mit echten Mausbewegungen rubbeln
	await _zu_station(3)
	for r in 3:
		var vorher := wirtschaft.geld
		var e := cmenu.einsatz
		_knopf_druecken("b_kaufen")
		await get_tree().process_frame
		await get_tree().process_frame
		var los := cmenu.los
		var ecke := los.get_global_rect().position
		var zeilen := 9
		for zl in zeilen:
			var y: float = 30.0 + zl * 210.0 / (zeilen - 1)
			_maus(ecke + Vector2(25.0, y), true, false)
			for sx in 21:
				var x: float = 25.0 + sx * 20.0
				_maus(ecke + Vector2(x if zl % 2 == 0 else 450.0 - x, y), true, true)
			_maus(ecke + Vector2(425.0, y), false, false)
			await get_tree().process_frame
			if zl == 4 and r == 0:
				print("TEST los halb gerubbelt: feld0 frei=%.2f feld8 frei=%.2f läuft=%s" % [los.frei_anteil(0), los.frei_anteil(8), cmenu.laeuft])
				await get_tree().create_timer(0.6).timeout      # halb freigerubbelt (Testbild)
			if not cmenu.laeuft:
				break
		var soll := vorher - e + int(round(e * float(los.daten.gewinn)))
		if wirtschaft.geld != soll or cmenu.laeuft:
			fehler += 1
		print("TEST los %d: felder=%s gewinn=%.0f× fertig=%s geld %d → %d (soll %d) | %s" % [r + 1, los.daten.felder, float(los.daten.gewinn), not cmenu.laeuft, vorher, wirtschaft.geld, soll, cmenu.ergebnis.text])
		await get_tree().create_timer(0.5).timeout
	_taste(KEY_E)
	await get_tree().create_timer(0.3).timeout
	# ---- zu wenig Geld: nichts geht
	var merk := wirtschaft.geld
	wirtschaft.geld = 7
	await _zu_station(2)
	var ging := _knopf_druecken("b_hebel")
	print("TEST zu wenig geld: hebel gesperrt=%s geld bleibt=%s text='%s'" % [not ging, wirtschaft.geld == 7, cmenu.einsatz_label.text])
	_taste(KEY_E)
	wirtschaft.geld = merk
	# ---- Rückzahlung der Spiele messen
	var rg := RandomNumberGenerator.new()
	rg.seed = 99
	for s in ["blackjack", "rad", "bandit", "los"]:
		print("TEST rückzahlung %s: %.1f %% (Ziel 90–99)" % [s, CasinoRegeln.messen(s, 200000, rg) * 100.0])
	print("TEST casino fertig: fehler=%d geld=%d" % [fehler, wirtschaft.geld])

# echte Mausbewegung/-klick an Bildschirmpunkt p (für Menüs, Maus ist dort frei)
func _maus(p: Vector2, gedrueckt: bool, bewegung: bool) -> void:
	if bewegung:
		var b := InputEventMouseMotion.new()
		b.position = p
		b.global_position = p
		b.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(b)
	else:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = gedrueckt
		e.position = p
		e.global_position = p
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if gedrueckt else 0
		Input.parse_input_event(e)

func _halte(k: Key, gedrueckt: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = gedrueckt
	Input.parse_input_event(e)

# 12: Taube, Windböe und Sandsturm sofort auslösen
var _et := 0
func _ereignis_test(dt: float) -> void:
	demo_zeit += dt
	if _et == 0:
		_et = 1
		spieler.gesperrt = true
		spieler.pitch = -0.45
		var mitte := int(spieler.weg / Turm.FENSTER_B)
		for sp in range(mitte - 4, mitte + 5):
			while not zustand.wische(spieler.stock, sp, 0.5, 0.5, 2.0, 2.0):
				pass
		var vorher := zustand.sauber_zahl
		print("TEST taube losgeschickt=%s sauber vorher=%d" % [ereignisse.taube_jetzt(), vorher])
		ereignisse.boe_jetzt(1.0)
	elif _et == 1 and demo_zeit > 5.5:
		_et = 2
		print("TEST nach Taube: sauber=%d wind=%.2f tauben=%d" % [zustand.sauber_zahl, ereignisse.wind, ereignisse.tauben.size()])
		ereignisse.sturm_jetzt()
		ereignisse.sturm_zeit = 0.5
		spieler.yaw = PI      # beim Sturm auf die Stadt schauen
		spieler.pitch = -0.15
	elif _et == 2 and ereignisse.sturm_phase == 2 and ereignisse.sturm_staerke > 0.9:
		_et = 3
		print("TEST sturm stark=%.2f nebel=%.4f" % [ereignisse.sturm_staerke, welt.env.fog_density])
		ereignisse.sturm_zeit = 0.1
	elif _et == 3 and ereignisse.sturm_phase == 0:
		_et = 4
		print("TEST sturm vorbei: sauber=%d" % zustand.sauber_zahl)

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
