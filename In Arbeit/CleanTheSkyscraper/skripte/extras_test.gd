class_name ExtrasTest
extends Node
# Tests der Extras (gibt „TEST …“ auf der Konsole aus, echte Tasten/Knöpfe wo möglich):
# 24 Erfolge + Statistik, 25 Sky-Lounge, 26 Penthouse, 27 Arcade, 28 Testbilder (je 1,5 s eine Ansicht).

var s: Spiel
var x: Extras
var w: Wirtschaft
var fehler := 0

func setup(spiel: Spiel) -> void:
	s = spiel
	x = spiel.extras
	w = spiel.wirtschaft
	_ablauf.call_deferred()

func _warte(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _pruefe(name: String, ok: bool, info := "") -> void:
	if not ok:
		fehler += 1
	print("TEST %s %s %s" % ["OK  " if ok else "FEHLER", name, info])

func _knopf(n: String) -> bool:
	for menu in [x.menu, s.hmenu]:
		var b: Button = menu.find_child(n, true, false)
		if b and menu.offen:
			if b.disabled:
				return false
			b.pressed.emit()
			return true
	return false

func _knopf_aus(n: String) -> bool:
	var b: Button = x.menu.find_child(n, true, false)
	return b != null and b.disabled

# Vor eine Station stellen (Welt-Punkte) und hinschauen
func _vor(st: Dictionary) -> void:
	var p: Vector2 = st.pos
	var z: Vector2 = st.get("ziel", p + Vector2(0, -1))
	var d := (z - p).normalized()
	s.laeufer.position = Vector3(p.x, s.laeufer.position.y, p.y)
	s.laeufer.yaw = atan2(-d.x, -d.y)
	s.laeufer.pitch = 0.0

func _station(art: String) -> Dictionary:
	for st in x._stationen():
		if st.art == art:
			return st
	return {}

func _aussteigen() -> void:
	await _warte(0.4)
	if s.spieler.aktiv:
		s.spieler.y = 0.3
		s._ein_aus()
	await _warte(0.3)

func _fahren(ziel: String) -> bool:
	var ok := _knopf("fahr_" + ziel)
	await _warte(1.3)
	return ok

func _ablauf() -> void:
	await _aussteigen()
	match s.ansicht:
		24: await _erfolge()
		25: await _lounge()
		26: await _penthouse()
		27: await _arcade()
		28: await _bilder()
	print("TEST fertig: fehler=%d geld=%d" % [fehler, w.geld])
	if s.ansicht != 28:
		get_tree().quit()

# ---------------------------------------------------------------- 24 Erfolge + Statistik
func _erfolge() -> void:
	var geld0 := w.geld
	w.statistik.fenster_selbst = 119
	s.spieler.fenster_sauber.emit(10, 3)       # echtes Signal wie beim Putzen: zählt + Lohn
	_pruefe("fenster gezaehlt", int(w.statistik.fenster_selbst) == 120 and int(w.statistik.verdient) == s.lohn_mit_boni(10), "verdient=%d" % w.statistik.verdient)
	_pruefe("rekord minute", int(w.statistik.rekord_minute) == 1)
	w.statistik.hoechste = 150.0
	w.album["1"] = 1
	w.casino_runde(100, 300)
	var vorher := w.geld
	var neu := x.erfolge_pruefen()
	var ids := neu.map(func(e): return e.id)
	ids.sort()
	_pruefe("erfolge", ids == ["album_1", "casino_1", "fenster_10", "fenster_100", "hoehe_100"], str(ids))
	_pruefe("erfolg geld", w.geld - vorher == 1300, "+%d" % (w.geld - vorher))
	_pruefe("nicht doppelt", x.erfolge_pruefen().is_empty())
	await _warte(1.5)
	_pruefe("spielzeit laeuft", float(w.statistik.spielzeit) > 1.0, "%.1f s" % w.statistik.spielzeit)
	# Speichern + Laden der neuen Felder
	w.bekomme_gegenstand("teddy_gold")
	w.moebel[0].steht = true
	var d = JSON.parse_string(JSON.stringify(w.speichern()))
	var w2 := Wirtschaft.new()
	w2.laden(d)
	_pruefe("laden", w2.erfolge.size() == 5 and int(w2.statistik.fenster_selbst) == 120 and w2.moebel.size() == 1 and w2.moebel[0].steht and is_equal_approx(w2.bonus("lohn"), 0.2), "erfolge=%d bonus=%.2f" % [w2.erfolge.size(), w2.bonus("lohn")])
	_pruefe("lohn mit bonus", s.lohn_mit_boni(60) == int(round(w.lohn(60) * 1.2)), "%d statt %d" % [s.lohn_mit_boni(60), w.lohn(60)])
	# Taste P öffnet Erfolge, Reiter Statistik, P schließt
	s._taste(KEY_P)
	await _warte(0.3)
	_pruefe("P oeffnet", x.menu.offen and x.menu.art == "erfolge")
	_knopf("reiter_1")
	await _warte(0.3)
	_pruefe("statistik reiter", x.menu.reiter == 1)
	s._taste(KEY_P)
	await _warte(0.3)
	_pruefe("P schliesst", not x.menu.offen)
	_pruefe("geld insgesamt", w.geld > geld0)

# ---------------------------------------------------------------- 25 Sky-Lounge
func _lounge() -> void:
	w.stufen.winde = 7          # Seil bis Stockwerk 48: nur die Lounge ist frei
	s._ausruestung()
	_vor({"pos": x.sky.unten_pos, "ziel": x.sky.unten_ziel})
	await _warte(0.3)
	_pruefe("hinweis unten", x.status().begins_with("E: Express"), x.status())
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("aufzug menu", x.menu.offen and x.menu.art == "aufzug_turm")
	_pruefe("restaurant gesperrt", _knopf_aus("fahr_restaurant") and not _knopf_aus("fahr_lounge"))
	_pruefe("fahrt lounge", await _fahren("lounge"))
	var e: Dictionary = x.sky.etagen["lounge"]
	_pruefe("in der lounge", x.ort == "lounge" and absf(s.laeufer.position.y - e.boden) < 0.01, "y=%.1f" % s.laeufer.position.y)
	# Laufen bis an die Glaswand: darf nicht hinaus
	s._halte(KEY_W, true)
	await _warte(4.0)
	s._halte(KEY_W, false)
	var p := Vector2(s.laeufer.position.x, s.laeufer.position.z)
	_pruefe("glaswand haelt", Geometry2D.is_point_in_polygon(p, s.turm.stockwerke[48].poly) and p.y > 8.0, "z=%.1f" % p.y)
	# Sky-Bar: Cocktail kaufen → +50 % Lohn
	_vor(_station("bar"))
	await _warte(0.2)
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("bar menu", s.hmenu.offen and s.hmenu.stand == "bar")
	var l0 := s.lohn_mit_boni(100)
	_pruefe("cocktail kaufen", _knopf("b_cocktail") and w.boost_aktiv("cocktail"))
	_pruefe("cocktail wirkt", s.lohn_mit_boni(100) == int(round(l0 * 1.5)), "%d -> %d" % [l0, s.lohn_mit_boni(100)])
	s._taste(KEY_E)
	await _warte(0.3)
	# Zurück nach unten, Seil ganz hoch, ins Restaurant
	_vor(_station("aufzug"))
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("fahrt unten", await _fahren("unten") and x.ort == "" and s.laeufer.position.y == 0.0)
	w.stufen.winde = 27
	s._ausruestung()
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("fahrt restaurant", await _fahren("restaurant") and x.ort == "restaurant")
	_vor(_station("designer"))
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("designer menu", x.menu.offen and x.menu.art == "designer")
	_pruefe("designer kaufen", _knopf("kauf_design_sofa") and w.anzahl_gegenstand("design_sofa") == 1)
	s._taste(KEY_E)
	await _warte(0.3)
	_vor(_station("restaurant"))
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("restaurant menu", s.hmenu.offen and s.hmenu.stand == "restaurant" and _knopf("b_mittag") and w.boost_wirkung("tempo") >= 0.6)
	s._taste(KEY_E)
	await _warte(0.3)
	_vor(_station("aufzug"))
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("fahrt plattform", await _fahren("plattform") and x.ort == "plattform" and s.laeufer.position.y == 800.0)
	_vor(_station("exklusiv"))
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("exklusiv menu", x.menu.offen and x.menu.art == "exklusiv")
	s._taste(KEY_E)
	await _warte(0.3)
	_vor(_station("gipfel"))
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("gipfel champagner", s.hmenu.offen and _knopf("b_champagner") and w.boost_wirkung("lohn") >= 2.5)
	s._taste(KEY_E)
	await _warte(1.2)
	_pruefe("besucht + erfolge", w.besucht.size() == 3 and w.erfolge.has("lounge") and w.erfolge.has("restaurant") and w.erfolge.has("plattform"), str(w.besucht))

# ---------------------------------------------------------------- 26 Penthouse
func _zum_penthouse() -> void:
	_vor({"pos": s.casino.aufzug_pos, "ziel": s.casino.aufzug_pos + Vector2(-2, 0)})
	await _warte(0.2)
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("casino aufzug", x.menu.offen and x.menu.art == "aufzug_casino")

func _klick() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for g in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = g
		e.position = get_viewport().get_visible_rect().size * 0.5
		Input.parse_input_event(e)

func _penthouse() -> void:
	await _zum_penthouse()
	_pruefe("fahrt penthouse", await _fahren("penthouse") and x.ort == "penthouse" and absf(s.laeufer.position.y - x.penthouse.boden) < 0.01, "y=%.1f" % s.laeufer.position.y)
	_vor(_station("tablet"))
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("tablet", x.menu.offen and x.menu.art == "katalog")
	var geld0 := w.geld
	_pruefe("kaufen", _knopf("kauf_sofa") and _knopf("kauf_schreibtisch") and _knopf("kauf_teppich"), "")
	_pruefe("preis", geld0 - w.geld == w.gegenstand_preis("sofa") + w.gegenstand_preis("schreibtisch") + w.gegenstand_preis("teppich"))
	_knopf("reiter_1")
	await _warte(0.2)
	_pruefe("aufstellen", _knopf("auf_0") and x.penthouse.platzieren_aktiv() and not x.menu.offen)
	var m := x.penthouse.mitte
	s.laeufer.position = Vector3(m.x - 2.0, s.laeufer.position.y, m.y)
	s.laeufer.yaw = PI * 0.5            # schaut nach −X
	await _warte(0.3)
	_pruefe("platz frei", x.penthouse.platz_ok)
	_klick()
	await _warte(0.3)
	var sofa: Dictionary = w.moebel[0]
	_pruefe("sofa steht", sofa.steht and absf(sofa.x - (-4.5)) < 0.3, "x=%.2f z=%.2f" % [sofa.x, sofa.z])
	_pruefe("sofa ist fest", not s.laeufer.frei(m + Vector2(sofa.x, sofa.z)))
	# Schreibtisch (Bonus Lohn +2 %) mit R gedreht daneben
	x._platzieren(1)
	s.laeufer.position = Vector3(m.x - 2.0, s.laeufer.position.y, m.y + 5.0)
	s._taste(KEY_R)
	await _warte(0.3)
	_klick()
	await _warte(0.3)
	_pruefe("schreibtisch", w.moebel[1].steht and is_equal_approx(float(w.moebel[1].dreh), 45.0) and is_equal_approx(w.bonus("lohn"), 0.02), "bonus=%.2f" % w.bonus("lohn"))
	# Nicht auf das Sofa stellen
	x._platzieren(2)
	s.laeufer.position = Vector3(m.x - 2.0, s.laeufer.position.y, m.y)
	await _warte(0.3)
	var teppich_flach := Moebel.hoehe("teppich") <= 0.15
	_pruefe("teppich darf drunter / sonst gesperrt", x.penthouse.platz_ok == teppich_flach, "flach=%s ok=%s" % [teppich_flach, x.penthouse.platz_ok])
	s._taste(KEY_ESCAPE)
	await _warte(0.2)
	_pruefe("abbrechen", not x.penthouse.platzieren_aktiv() and not w.moebel[2].steht)
	# Umstellen mit E vor dem Sofa, dann X = ins Lager
	s.laeufer.position = Vector3(m.x - 2.6, s.laeufer.position.y, m.y)
	s.laeufer.yaw = PI * 0.5
	await _warte(0.2)
	_pruefe("hinweis umstellen", x.status().ends_with("umstellen"), x.status())
	s._taste(KEY_E)
	await _warte(0.2)
	_pruefe("umstellen", x.penthouse.platz_index == 0)
	s._taste(KEY_X)
	await _warte(0.2)
	_pruefe("ins lager", not w.moebel[0].steht and not x.penthouse.platzieren_aktiv())
	# Pokale in der Vitrine
	for id in ["fenster_10", "hoehe_100", "geld_1m"]:
		w.erfolge[id] = true
	x.penthouse.pokale_aktualisieren()
	await _warte(0.2)
	_pruefe("pokale", x.penthouse.knoten_pokale.get_child_count() == w.erfolge.size(), "%d" % x.penthouse.knoten_pokale.get_child_count())
	_vor(_station("vitrine"))
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("vitrine oeffnet erfolge", x.menu.offen and x.menu.art == "erfolge")
	s._taste(KEY_E)
	await _warte(0.3)
	_vor(_station("aufzug_casino"))
	s._taste(KEY_E)
	await _warte(0.3)
	_pruefe("zurueck ins casino", await _fahren("casino") and x.ort == "" and s.casino.drinnen(Vector2(s.laeufer.position.x, s.laeufer.position.z)))

# ---------------------------------------------------------------- 27 Arcade
func _arcade() -> void:
	await _zum_penthouse()
	_pruefe("fahrt arcade", await _fahren("arcade") and x.ort == "arcade")
	var a := x.arcade
	var gewonnen := 0
	var versuche := 0
	for runde in 6:
		_vor(_station("greif"))
		await _warte(0.2)
		var geld0 := w.geld
		s._taste(KEY_E)
		await _warte(0.2)
		versuche += 1
		if runde == 0:
			_pruefe("greif startet", a.spiel == 0 and geld0 - w.geld == w.arcade_preis("greif") and a.automaten[0].cam.current)
			s._halte(KEY_D, true)
			await _warte(0.5)
			s._halte(KEY_D, false)
			_pruefe("kralle faehrt", a.k_pos.x > 0.15, "x=%.2f" % a.k_pos.x)
		var ziel: Vector2 = a.automaten[0].preise[0].pos   # genau über den ersten Preis
		a.k_pos = ziel
		var anzahl0 := w.moebel.size()
		s._taste(KEY_SPACE)
		var t := 0.0
		while a.spiel >= 0 and t < 15.0:
			await _warte(0.25)
			t += 0.25
		if w.moebel.size() > anzahl0:
			gewonnen += 1
		await _warte(0.3)
		if gewonnen >= 2:
			break
	_pruefe("greif gewinnt manchmal", gewonnen >= 1, "%d von %d" % [gewonnen, versuche])
	_pruefe("kamera zurueck", s.laeufer.cam.current)
	# daneben greifen gewinnt nie
	_vor(_station("greif"))
	s._taste(KEY_E)
	await _warte(0.2)
	var leer := Vector2(0.45, -0.45)
	for p in a.automaten[0].preise:
		if (p.pos as Vector2).distance_to(leer) < 0.2:
			leer = Vector2(0.0, -0.45)
	a.k_pos = leer
	var n0 := w.moebel.size()
	s._taste(KEY_SPACE)
	var t2 := 0.0
	while a.spiel >= 0 and t2 < 15.0:
		await _warte(0.25)
		t2 += 0.25
	_pruefe("daneben", w.moebel.size() == n0)
	# Kapsel-Automat
	var ks := _station("kapsel")
	_vor(ks)
	await _warte(0.2)
	s._taste(KEY_E)
	await _warte(0.3)
	var n1 := w.moebel.size()
	var g1 := w.geld
	_pruefe("kapsel", x.menu.art == "kapsel" and _knopf("kapsel"))
	await _warte(1.5)
	_pruefe("kapsel gewinn", w.moebel.size() == n1 + 1 and g1 - w.geld == w.arcade_preis("kapsel") and x.menu.letzte_kapsel != "", x.menu.letzte_kapsel)
	s._taste(KEY_E)
	# Verteilung der Kapsel-Seltenheiten
	var z := [0, 0, 0, 0]
	for i in 20000:
		z[w.kapsel_stufe(randf())] += 1
	_pruefe("kapsel chancen", absf(z[0] / 20000.0 - 0.7) < 0.02 and absf(z[3] / 20000.0 - 0.01) < 0.004, str(z))
	_pruefe("statistik arcade", int(w.statistik.arcade_spiele) == versuche + 2 and int(w.statistik.arcade_gewinne) == gewonnen + 1, "%d/%d" % [w.statistik.arcade_spiele, w.statistik.arcade_gewinne])

# ---------------------------------------------------------------- 28 Testbilder
func _blick(p: Vector3, ziel: Vector3) -> void:
	var l := s.laeufer
	l.position = p - Vector3(0, Laeufer.AUGE, 0)
	var d := ziel - p
	l.yaw = atan2(-d.x, -d.z)
	l.pitch = atan2(d.y, Vector2(d.x, d.z).length())

# Bild fertig: Bildnummer ausgeben (für das Sammelbild aus --write-movie)
func _foto(nr: int) -> void:
	await _warte(1.4)
	print("BILD %d frame=%d" % [nr, Engine.get_frames_drawn()])
	await _warte(0.1)

func _bilder() -> void:
	w.stufen.winde = 27
	w.geld = 500000
	s._ausruestung()
	var l := s.laeufer
	# 0: Express-Aufzug unten
	_blick(Vector3(9, 2.2, 36), Vector3(0, 4, 17))
	await _foto(0)
	# 1–2: Lounge
	x._teleport("lounge")
	_blick(Vector3(0, x.sky.etagen.lounge.boden + 1.7, 6), Vector3(26, x.sky.etagen.lounge.boden + 1.0, 15))
	await _foto(1)
	_vor(_station("bar"))
	await _foto(2)
	# 3: Restaurant
	x._teleport("restaurant")
	_blick(Vector3(-4.4, x.sky.etagen.restaurant.boden + 1.8, 8.3), Vector3(-13.9, x.sky.etagen.restaurant.boden + 0.6, 8.0))
	await _foto(3)
	# 4–5: Plattform von außen und innen
	x._teleport("unten")
	l.raum = {"poly": RaumBau.kreis(200.0), "boden": 0.0}
	_blick(Vector3(26, 812, 30), Vector3(0, 801, 0))
	await _foto(4)
	x._teleport("plattform")
	_blick(Vector3(-2, 801.7, 6.5), Vector3(-10, 799.0, 2))
	await _foto(5)
	# 6–7: Arcade + Greifautomat
	x._teleport("arcade")
	var m := x.arcade.mitte
	_blick(Vector3(m.x + 8, x.arcade.boden + 1.9, m.y + 6), Vector3(m.x - 6, x.arcade.boden + 1.0, m.y - 6))
	await _foto(6)
	x._greif_starten(0)
	await _foto(7)
	x.arcade.spiel = -1
	l.cam.current = true
	# 8: Penthouse mit Möbeln + Blick zum Turm, 9: Vitrine
	for id in ["sofa_ecke", "couchtisch", "teppich", "fernseher", "tv_schrank", "pflanze", "stehlampe", "teddy_gold", "relax_sessel", "teddy_blau"]:
		w.bekomme_gegenstand(id)
	var plaetze := [[-6.0, -6.0, 0.0], [-4.5, -4.5, 0.0], [-4.5, -4.5, 0.0], [-9.0, -1.5, 90.0], [-9.0, -1.5, 90.0], [-11.0, -9.0, 0.0], [-2.0, -10.0, 0.0], [-1.5, -7.0, 210.0], [2.0, -8.0, 200.0], [-7.5, -9.5, 30.0]]
	for i in plaetze.size():
		var mm: Dictionary = w.moebel[w.moebel.size() - plaetze.size() + i]
		mm.steht = true
		mm.x = plaetze[i][0]
		mm.z = plaetze[i][1]
		mm.dreh = plaetze[i][2]
	for e in Erfolge.LISTE.slice(0, 17):
		w.erfolge[e.id] = true
	x._teleport("penthouse")
	var pm := x.penthouse.mitte
	_blick(Vector3(pm.x + 6, x.penthouse.boden + 2.2, pm.y + 7), Vector3(pm.x - 8, x.penthouse.boden + 0.6, pm.y - 7))
	await _foto(8)
	_vor(_station("vitrine"))
	l.pitch = -0.15
	await _foto(9)
	# 10–13: Menüs
	x.menu.oeffnen("erfolge", "Erfolge")
	await _foto(10)
	x.menu.reiter = 1
	x.menu.aufbauen()
	await _foto(11)
	x.menu.oeffnen("katalog", "Möbel-Tablet")
	await _foto(12)
	x.menu.reiter = 1
	x.menu.aufbauen()
	await _foto(13)
	x.menu.oeffnen("aufzug_turm", "Express-Aufzug")
	x.menu.oberstes = 120
	x.menu.aufbauen()
	await _foto(14)
	x.menu.schliessen()
	get_tree().quit()
