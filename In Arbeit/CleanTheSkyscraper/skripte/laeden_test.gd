class_name LaedenTest
extends Node
# Tests der vier Läden (gibt „TEST …“ aus): 29 = hineinlaufen, Wände, Stationen, Kaufen über die echten Knöpfe,
# Souvenir-Sperre, Gondel-Werkstatt, Speichern/Laden; 30 = Testbilder (BILD n frame=…).

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
	var b: Button = x.menu.find_child(n, true, false)
	if b == null or not x.menu.offen or b.disabled:
		return false
	b.pressed.emit()
	return true

func _vor(st: Dictionary) -> void:
	var p: Vector2 = st.pos
	var d: Vector2 = (st.ziel - p).normalized()
	s.laeufer.position = Vector3(p.x, 0, p.y)
	s.laeufer.yaw = atan2(-d.x, -d.y)
	s.laeufer.pitch = -0.1

func _stationen(laden: String, id := "*") -> Array:
	return x.laeden.stationen.filter(func(st): return st.laden == laden and (id == "*" or st.id == id))

func _halte(k: Key, an: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = an
	Input.parse_input_event(e)

func _ablauf() -> void:
	await _warte(0.4)
	if s.spieler.aktiv:
		s.spieler.y = 0.3
		s._ein_aus()
	await _warte(0.3)
	match s.ansicht:
		29: await _test()
		30: await _bilder()
	print("TEST fertig: fehler=%d geld=%d" % [fehler, w.geld])
	get_tree().quit()

# Durch die Tür laufen (W halten) und prüfen, dass man drin ist; danach gegen die Front neben der Tür laufen
func _hinein(id: String) -> void:
	var l: Dictionary = x.laeden.laeden[id]
	var ein: Vector2 = l.eingang
	var rein: Vector2 = (l.mitte - ein).normalized()
	s.laeufer.position = Vector3(ein.x, 0, ein.y)
	s.laeufer.yaw = atan2(-rein.x, -rein.y)
	_halte(KEY_W, true)
	await _warte(2.4)
	_halte(KEY_W, false)
	var p := Vector2(s.laeufer.position.x, s.laeufer.position.z)
	_pruefe("%s: durch die Tür" % id, x.laeden.drinnen(id, p), "%.1f m vom Eingang" % p.distance_to(ein))
	# neben der Tür (Schaufenster) darf man nicht hindurch
	var quer := rein.orthogonal()
	var neben: Vector2 = ein + quer * (float(Laeden.DATEN[id].tuer) * 0.5 + 2.2)
	s.laeufer.position = Vector3(neben.x, 0, neben.y)
	_halte(KEY_W, true)
	await _warte(2.0)
	_halte(KEY_W, false)
	p = Vector2(s.laeufer.position.x, s.laeufer.position.z)
	_pruefe("%s: Schaufenster hält" % id, not x.laeden.drinnen(id, p))
	# alle Standpunkte frei begehbar
	var blockiert := []
	for st in _stationen(id):
		s.laeufer.position = Vector3(ein.x, 0, ein.y)
		if not s.laeufer.frei(st.pos):
			blockiert.append(st.id if st.id != "" else "theke")
	_pruefe("%s: Stationen erreichbar" % id, blockiert.is_empty(), str(blockiert))

# Vor eine Station stellen, E drücken → Menü offen?
func _oeffnen(st: Dictionary) -> bool:
	_vor(st)
	await _warte(0.4)
	var hinweis: String = s.hud.status_l.text
	s._taste(KEY_E)
	await _warte(0.3)
	return x.menu.offen and hinweis != ""

func _schliessen() -> void:
	s._taste(KEY_E)
	await _warte(0.3)

func _test() -> void:
	w.geld = 2000000
	s._ausruestung()
	# Grundstücke: keine Häuser, keine Kreuzungen darauf
	var frei := true
	for id in s.welt.laden_rects:
		var r: Rect2 = s.welt.laden_rects[id]
		for hr in s.welt.haeuser:
			if r.intersects(hr):
				frei = false
	_pruefe("Grundstücke frei von Häusern", frei)
	# ---- Möbelhaus
	await _hinein("moebel")
	var sofa: Array = _stationen("moebel", "sofa_lang")
	_pruefe("Möbelhaus: Sofa ausgestellt", sofa.size() == 1)
	var anzahl := _stationen("moebel").size()
	_pruefe("Möbelhaus: alle Möbel ausgestellt", anzahl == 1 + Wirtschaft.GEGENSTAENDE.keys().filter(func(g): return w.moebel_raum(g) != "").size(), "%d Stationen" % anzahl)
	if sofa.size() == 1:
		_pruefe("Möbelhaus: E am Sofa öffnet", await _oeffnen(sofa[0]))
		_pruefe("Möbelhaus: Fokus + Raum-Reiter", x.menu.art == "moebelhaus" and x.menu.fokus == "sofa_lang" and x.menu.reiter == 0)
		var g0 := w.geld
		_pruefe("Möbelhaus: kaufen", _knopf("kauf_sofa_lang") and w.anzahl_gegenstand("sofa_lang") == 1 and g0 - w.geld == 750, "%d €" % (g0 - w.geld))
		_knopf("reiter_3")
		await _warte(0.2)
		_pruefe("Möbelhaus: Reiter Bad", x.menu.find_child("kauf_badewanne", true, false) != null)
		_pruefe("Möbelhaus: Badewanne kaufen", _knopf("kauf_badewanne") and w.anzahl_gegenstand("badewanne") == 1)
		await _schliessen()
		_pruefe("Möbelhaus: Menü zu", not x.menu.offen)
	# ---- Souvenirshop: gesperrt, dann Meilenstein → frei
	await _hinein("souvenir")
	var kasse: Array = _stationen("souvenir", "")
	_pruefe("Souvenir: Kasse öffnet", kasse.size() == 1 and await _oeffnen(kasse[0]))
	var b: Button = x.menu.find_child("kauf_sv_nadel", true, false)
	_pruefe("Souvenir: Nadel gesperrt", b != null and b.disabled and w.kauf_sperre("sv_nadel") == "gesperrt")
	await _schliessen()
	w.statistik.hoechste = 120.0
	x.erfolge_pruefen()
	await _warte(0.2)
	_pruefe("Souvenir: nach 100 m frei", w.kauf_sperre("sv_nadel") == "" and _stationen("souvenir", "sv_nadel")[0].hinweis.begins_with("E:"))
	_pruefe("Souvenir: E am Sockel", await _oeffnen(_stationen("souvenir", "sv_nadel")[0]))
	_pruefe("Souvenir: kaufen", _knopf("kauf_sv_nadel") and w.anzahl_gegenstand("sv_nadel") == 1)
	b = x.menu.find_child("kauf_sv_nadel", true, false)
	_pruefe("Souvenir: nur einmal", b != null and b.disabled and not w.kaufe_gegenstand("sv_nadel"))
	await _schliessen()
	# ---- Gondel-Werkstatt
	await _hinein("werkstatt")
	_pruefe("Werkstatt: öffnet", await _oeffnen(_stationen("werkstatt", "")[0]))
	_knopf("reiter_1")
	await _warte(0.1)
	_pruefe("Werkstatt: Lack kaufen", _knopf("k_lack_karo") and w.kosmetik_aktiv.lack == "lack_karo")
	_knopf("reiter_2")
	await _warte(0.1)
	_pruefe("Werkstatt: Aufkleber", _knopf("k_kleber_stern") and w.kosmetik_aktiv.aufkleber == "kleber_stern")
	_knopf("reiter_3")
	await _warte(0.1)
	_pruefe("Werkstatt: Blumen", _knopf("k_blumen_bunt") and w.kosmetik_aktiv.blumen == "blumen_bunt")
	_knopf("reiter_4")
	await _warte(0.1)
	_pruefe("Werkstatt: Schirm", _knopf("k_schirm_streifen") and w.kosmetik_aktiv.schirm == "schirm_streifen")
	_pruefe("Werkstatt: Spieler-Gondel geschmückt", s.spieler.deko.get_child_count() > 10 and s.spieler.gondel_mat.albedo_texture != null, "%d Teile" % s.spieler.deko.get_child_count())
	_pruefe("Werkstatt: Vorführ-Gondel geschmückt", x.laeden.vorfuehr_deko.get_child_count() == s.spieler.deko.get_child_count())
	_knopf("reiter_2")
	await _warte(0.1)
	_pruefe("Werkstatt: wechseln (gratis)", _knopf("k_kleber_keine") and w.kosmetik_aktiv.aufkleber == "kleber_keine" and "kleber_stern" in w.kosmetik_besitz)
	await _schliessen()
	# ---- Goldschmuck
	await _hinein("gold")
	var stueck: Array = _stationen("gold", "gold_barren")
	_pruefe("Gold: E am Barren", stueck.size() == 1 and await _oeffnen(stueck[0]))
	var g1 := w.geld
	_pruefe("Gold: kaufen", _knopf("kauf_gold_barren") and g1 - w.geld == 20000)
	_pruefe("Gold: einzigartig", w.kauf_sperre("gold_barren") == "besitz")
	await _schliessen()
	var gl: Rect2 = s.welt.laden_rects.gold
	_pruefe("Gold: neben dem Casino", gl.get_center().distance_to(s.welt.casino_rect.get_center()) < 50.0)
	# ---- Penthouse: Gold-Barren aufstellen → Bonus
	for m in w.moebel:
		if m.id == "gold_barren":
			m.steht = true
	_pruefe("Bonus Gold-Barren", is_equal_approx(w.bonus("lohn"), 0.2), "%.2f" % w.bonus("lohn"))
	# ---- Tablet: Möbelhaus-Möbel nachkaufen
	x.menu.oeffnen("katalog", "Möbel-Tablet")
	_pruefe("Tablet: Nachkauf aus dem Möbelhaus", x.menu.find_child("kauf_sofa_lang", true, false) != null and x.menu.find_child("kauf_herd", true, false) == null)
	x.menu.schliessen()
	# ---- Speichern + Laden (neue Felder), alter Spielstand ohne neue Felder
	var d = JSON.parse_string(JSON.stringify(w.speichern()))
	var w2 := Wirtschaft.new()
	w2.laden(d)
	_pruefe("laden neu", w2.kosmetik_aktiv.lack == "lack_karo" and w2.kosmetik_aktiv.schirm == "schirm_streifen" and "kleber_stern" in w2.kosmetik_besitz and w2.anzahl_gegenstand("gold_barren") == 1 and w2.anzahl_gegenstand("sv_nadel") == 1)
	var alt := {"geld": 50, "kosmetik_besitz": ["gondel_rot"], "kosmetik_aktiv": {"gondel": "gondel_rot"}}
	var w3 := Wirtschaft.new()
	w3.laden(alt)
	_pruefe("laden alt", w3.kosmetik_aktiv.gondel == "gondel_rot" and w3.kosmetik_aktiv.lack == "lack_uni" and "blumen_keine" in w3.kosmetik_besitz)
	# ---- Jetpack-Kollision: Hochhäuser über den Läden sind fest
	_pruefe("Läden-Hochhäuser als Block", x.laeden.bloecke.size() == 4 and s.laeufer.bloecke.size() >= 5)

# ---------------------------------------------------------------- 30 Testbilder
func _blick(p: Vector3, ziel: Vector3) -> void:
	var l := s.laeufer
	l.position = p - Vector3(0, Laeufer.AUGE, 0)
	var d := ziel - p
	l.yaw = atan2(-d.x, -d.z)
	l.pitch = atan2(d.y, Vector2(d.x, d.z).length())

func _foto(nr: int) -> void:
	await _warte(1.4)
	print("BILD %d frame=%d" % [nr, Engine.get_frames_drawn()])
	await _warte(0.1)

# lokaler Punkt (x, y, z) im Laden → Welt
func _lp(id: String, lx: float, y: float, lz: float) -> Vector3:
	var q := x.laeden.wp(id, lx, lz)
	return Vector3(q.x, y, q.y)

func _bilder() -> void:
	w.geld = 2000000
	for e in Erfolge.LISTE.slice(0, 20):
		w.erfolge[e.id] = true
	for gid in ["gold_barren", "sv_nadel"]:
		w.bekomme_gegenstand(gid)
	for k in ["lack_streifen", "kleber_herz", "blumen_bunt", "schirm_streifen"]:
		w.kaufe_kosmetik(k)
	s._ausruestung()
	x.laeden.aktualisieren()
	await _warte(0.5)
	var nr := 0
	for id in ["moebel", "werkstatt", "souvenir", "gold"]:
		var h: float = Laeden.DATEN[id].halb
		# außen: schräg vor dem Eingang
		_blick(_lp(id, -h - 22.0, 6.0, -12.0), _lp(id, -h, 4.0, 0.0))
		await _foto(nr)
		nr += 1
		# innen: von der Tür nach hinten
		_blick(_lp(id, -h + 1.5, 1.75, -h * 0.55), _lp(id, h * 0.6, 0.8, h * 0.3))
		await _foto(nr)
		nr += 1
	# Möbelhaus: in einen Raum hineinschauen, Werkstatt: Gondel von nah
	_blick(_lp("moebel", 2.0, 1.75, 1.0), _lp("moebel", 2.0, 0.6, 12.0))
	await _foto(nr)
	nr += 1
	_blick(_lp("moebel", 2.0, 1.75, -1.0), _lp("moebel", 2.0, 0.6, -12.0))
	await _foto(nr)
	nr += 1
	_blick(_lp("werkstatt", -2.0, 2.2, -2.5), _lp("werkstatt", 2.0, 1.4, 0.0))
	await _foto(nr)
	nr += 1
	# Spieler-Gondel mit Zubehör: aus der Ich-Ansicht nach hinten schauen
	s.laeufer.deaktivieren()
	s.spieler.aktiv = true
	s.spieler.cam.current = true
	s.spieler.y = 30.0
	s.spieler.yaw = PI
	s.spieler.pitch = -0.35
	await _foto(nr)
	nr += 1
	s.spieler.yaw = PI * 0.6
	s.spieler.pitch = 0.5
	await _foto(nr)
	nr += 1
	# Menüs
	s.spieler.aktiv = false
	s.laeufer.cam.current = true
	x.menu.oeffnen("werkstatt", "Gondel-Werkstatt")
	x.menu.reiter = 2
	x.menu.aufbauen()
	await _foto(nr)
	nr += 1
	x.menu.oeffnen("souvenir", "Souvenirshop")
	await _foto(nr)
	nr += 1
	x.menu.oeffnen("gold", "Goldschmuck")
	await _foto(nr)
	x.menu.schliessen()
