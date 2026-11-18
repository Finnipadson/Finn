class_name Extras
extends Node
# Steuert die Extras: Sky-Lounge (Express-Aufzug am Turm), Arcade-Halle + Penthouse (Aufzug im Casino),
# Erfolge + Statistik (Taste P). Merkt sich, wo man ist (ort: "" = draußen/Casino, lounge, restaurant, plattform,
# arcade, penthouse), fährt mit Aufzügen (Blende), zeigt Hinweise und nimmt E/P/R/X/Leertaste entgegen.
# Tests: --ansicht=24 Erfolge/Statistik, 25 Sky-Lounge, 26 Penthouse, 27 Arcade, 28 Bilder.

const NAH := 2.4

var spiel: Spiel
var w: Wirtschaft
var sky: SkyLounge
var arcade: Arcade
var penthouse: Penthouse
var menu: ExtrasMenu
var laeden: Laeden
var ort := ""
var blende: ColorRect
var _faehrt := false
var _pruef := 0.0
var _sitzung := 0.0
var _minute: Array = []          # Zeitpunkte selbst geputzter Fenster (Rekord pro Minute)
var _uhr := 0.0

func setup(s: Spiel) -> void:
	spiel = s
	w = s.wirtschaft
	sky = SkyLounge.new()
	s.add_child(sky)
	sky.setup(s.turm)
	s.laeufer.polygone.append(RaumBau.verschieben(sky.unten_poly, Laeufer.RADIUS))
	arcade = Arcade.new()
	s.add_child(arcade)
	arcade.setup(s.welt.casino_rect)
	arcade.greif_ende.connect(_greif_ende)
	penthouse = Penthouse.new()
	s.add_child(penthouse)
	penthouse.setup(s.welt.casino_rect, w, s.laeufer)
	laeden = Laeden.new()   # Möbelhaus, Gondel-Werkstatt, Souvenirshop, Goldschmuck rund um den Platz
	s.add_child(laeden)
	laeden.setup(s.welt, w)
	s.laeufer.hindernisse.append_array(laeden.rechtecke)
	s.laeufer.bloecke.append_array(laeden.bloecke)
	menu = ExtrasMenu.new()
	s.add_child(menu)
	menu.setup(w)
	menu.fahren.connect(fahren)
	menu.platzieren.connect(_platzieren)
	menu.geaendert.connect(_geaendert)
	menu.kapsel_gewonnen.connect(_kapsel_gewonnen)
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	blende = ColorRect.new()
	blende.color = Color(0.02, 0.03, 0.05, 0.0)
	blende.set_anchors_preset(Control.PRESET_FULL_RECT)
	blende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(blende)
	# Älterer Spielstand ohne Statistik: schon geputzte Fenster und erreichte Höhe übernehmen (zählen für Erfolge)
	if int(w.statistik.fenster_selbst) + int(w.statistik.fenster_helfer) == 0 and s.zustand.sauber_zahl > 0:
		w.statistik.fenster_selbst = s.zustand.sauber_zahl
	w.statistik.hoechste = maxf(float(w.statistik.hoechste), w.hoechster_abschnitt * Wirtschaft.ABSCHNITT * Turm.STOCK_H)

# ---------------------------------------------------------------- Zustand
func menue_offen() -> bool:
	return menu.offen or arcade.spiel >= 0 or _faehrt

func drinnen() -> bool:
	return ort != ""

# Anzeige oben links (Höhe), "" = draußen
func ort_name() -> String:
	match ort:
		"": return ""
		"arcade": return "Arcade-Halle · 1. Stock"
		"penthouse": return "Penthouse · %d m" % int(penthouse.boden)
		_: return "%s · %d m" % [sky.etagen[ort].name, sky.etagen[ort].meter]

func _process(dt: float) -> void:
	_uhr += dt
	if spiel.ansicht == 0 or spiel.ansicht == 24:
		w.statistik.spielzeit = float(w.statistik.spielzeit) + dt
		_sitzung += dt
		w.statistik.sitzung_rekord = maxf(float(w.statistik.sitzung_rekord), _sitzung)
	if spiel.spieler.aktiv:
		w.statistik.hoechste = maxf(float(w.statistik.hoechste), spiel.spieler.y)
	w.statistik.gelaufen = float(w.statistik.gelaufen) + spiel.laeufer.gelaufen
	spiel.laeufer.gelaufen = 0.0
	_pruef -= dt
	if _pruef <= 0.0:
		_pruef = 1.0
		erfolge_pruefen()

func fenster_geputzt() -> void:
	_minute.append(_uhr)
	while _minute.size() > 0 and _uhr - float(_minute[0]) > 60.0:
		_minute.pop_front()
	w.statistik.rekord_minute = maxi(int(w.statistik.rekord_minute), _minute.size())

func erfolge_pruefen() -> Array:
	if Netz.ist_gast():
		return []   # Mehrspieler: Erfolge + Prämien vergibt nur der Gastgeber (Abgleich ab 7b)
	var neu := Erfolge.pruefen(w, spiel.zustand.sauber_zahl, spiel.turm.fenster_gesamt)
	if neu.size() > 0:
		var e: Dictionary = neu[0]
		var t := "Erfolg: %s!  +%s €\n%s-Pokal steht jetzt in der Vitrine im Penthouse (P: Erfolge)" % [e.name, Hud.punkte(e.geld), Erfolge.POKAL[e.pokal]]
		if neu.size() > 1:
			t += "\n…und %d weitere" % (neu.size() - 1)
		if laeden.souvenirs_geaendert():
			t += "\nNeues Andenken im Souvenirshop freigeschaltet!"
			laeden.aktualisieren()
		spiel.hud.meldung(t, 4.5)
		Netz.an_alle(t)   # Mehrspieler: Erfolge gelten für alle
		penthouse.pokale_aktualisieren()
		spiel._speichern()
	return neu

# ---------------------------------------------------------------- Stationen
func _stationen() -> Array:
	match ort:
		"":
			return [{"art": "aufzug_turm", "name": "Express-Aufzug", "hinweis": "E: Express-Aufzug zur Sky-Lounge", "pos": sky.unten_pos, "ziel": sky.unten_ziel},
				{"art": "aufzug_casino", "name": "Aufzug", "hinweis": "E: Aufzug (Arcade-Halle, Penthouse)", "pos": spiel.casino.aufzug_pos, "ziel": spiel.casino.aufzug_ziel}] + laeden.stationen + (spiel.strand.stationen() if spiel.strand else [])
		"arcade": return arcade.stationen
		"penthouse": return penthouse.stationen
		_: return sky.etagen[ort].stationen

func station() -> Dictionary:
	var p := Vector2(spiel.laeufer.position.x, spiel.laeufer.position.z)
	var beste := {}
	var best_d := NAH
	for s in _stationen():
		var d := p.distance_to(s.pos)
		if d < best_d:
			best_d = d
			beste = s
	return beste

func status() -> String:
	if _faehrt:
		return ""
	if arcade.spiel >= 0:
		return "WASD/Pfeile: Kralle bewegen · Leertaste: greifen · noch %d s · Esc: aufgeben" % ceili(arcade.zeit) if arcade.phase == "steuern" else ""
	if penthouse.platzieren_aktiv():
		return "Klick/E: abstellen%s · R/Mausrad: drehen · X: ins Lager · Esc: abbrechen" % ("" if penthouse.platz_ok else " (hier geht es nicht)")
	var s := station()
	if not s.is_empty():
		match s.art:
			"greif": return "E: Greifautomat spielen (%s €)" % Hud.punkte(w.arcade_preis("greif"))
			"kapsel": return "E: Kapsel-Automat (%s €)" % Hud.punkte(w.arcade_preis("kapsel"))
		return s.hinweis
	if ort == "penthouse":
		var i := penthouse.gegenstand_vorne()
		if i >= 0:
			return "E: %s umstellen" % w.gegenstand(w.moebel[i].id).name
	return ""

# E gedrückt (zu Fuß). true = erledigt (Spiel macht nichts weiter)
func e_druecken() -> bool:
	if _faehrt or arcade.spiel >= 0:
		return true
	if penthouse.platzieren_aktiv():
		_abstellen()
		return true
	var s := station()
	if s.is_empty():
		if ort == "penthouse":
			var i := penthouse.gegenstand_vorne()
			if i >= 0:
				_platzieren(i)
		return drinnen()
	match s.art:
		"aufzug_turm":
			menu.oberstes = Turm.STOCKWERKE if spiel.frei else w.oberstes_stockwerk()
			menu.ort = ort
			menu.oeffnen("aufzug_turm", "Express-Aufzug")
		"aufzug":
			menu.oberstes = Turm.STOCKWERKE if spiel.frei else w.oberstes_stockwerk()
			menu.ort = ort
			menu.oeffnen("aufzug_turm", "Express-Aufzug · %s" % sky.etagen[ort].name)
		"aufzug_casino":
			menu.ort = ort
			menu.oeffnen("aufzug_casino", "Aufzug")
		"bar", "restaurant", "gipfel":
			spiel.hmenu.oeffnen(s.art, s.name)
		"designer", "exklusiv":
			menu.oeffnen(s.art, s.name)
		"tablet":
			menu.oeffnen("katalog", "Möbel-Tablet")
		"vitrine":
			menu.oeffnen("erfolge", "Erfolge")
		"kapsel":
			menu.oeffnen("kapsel", "Kapsel-Automat")
		"laden":
			menu.fokus = str(s.id)
			menu.oeffnen(s.menue, Laeden.DATEN[s.laden].name)
		"greif":
			_greif_starten(int(s.nr))
		"strandbar", "fischladen", "yacht":
			spiel.strand.station(s)
	return true

# Tasten (vor dem Spiel): Menü zu, P, Platzieren, Greifautomat. true = verbraucht
func taste(e: InputEventKey) -> bool:
	if menu.offen:
		if Optionen.k(e) == KEY_E or Optionen.k(e) == KEY_ESCAPE or (Optionen.k(e) == KEY_P and menu.art == "erfolge"):
			menu.schliessen()
			return true
		return true
	if arcade.spiel >= 0:
		if Optionen.k(e) == KEY_SPACE:
			arcade.greifen()
		elif Optionen.k(e) == KEY_ESCAPE:
			arcade.greif_abbrechen()
		return true
	if penthouse.platzieren_aktiv():
		match Optionen.k(e):
			KEY_R: penthouse.drehen(45.0)
			KEY_X:
				_platz_ende(false, true)
				_geaendert()
			KEY_ESCAPE: _platz_ende(false)
			KEY_E: _abstellen()
			_: return false
		return true
	if Optionen.k(e) == KEY_P and not spiel.shop.offen and not spiel.album.offen and not spiel.hmenu.offen and not spiel.cmenu.offen and not spiel.strand.blockiert():
		menu.oeffnen("erfolge", "Erfolge")
		return true
	return false

# Maus beim Platzieren: Klick stellt ab, Mausrad dreht. true = verbraucht
func maus(e: InputEventMouseButton) -> bool:
	if not penthouse.platzieren_aktiv() or not e.pressed:
		return penthouse.platzieren_aktiv()
	match e.button_index:
		MOUSE_BUTTON_LEFT:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				_abstellen()
		MOUSE_BUTTON_RIGHT: _platz_ende(false)
		MOUSE_BUTTON_WHEEL_UP: penthouse.drehen(-45.0)
		MOUSE_BUTTON_WHEEL_DOWN: penthouse.drehen(45.0)
	return true

func _abstellen() -> void:
	if _platz_ende(true):
		_geaendert()
	else:
		spiel.hud.meldung("Hier ist kein Platz – etwas weiter weg zielen oder drehen.", 1.5)

# Umstellen sperrt das Stück beim Gastgeber (Mehrspieler 7e: „Anna stellt das gerade um.“)
func _platzieren(index: int) -> void:
	if ort != "penthouse" or index < 0 or index >= w.moebel.size():
		return
	Netz.befehl("moebel_sperren", {"i": index, "id": w.moebel[index].id}, func(e: Dictionary):
		if e.get("ok", false) and ort == "penthouse" and not penthouse.platzieren_aktiv() and index < w.moebel.size():
			menu.schliessen()
			penthouse.platzieren_start(index)
		elif not e.get("ok", false) and not Netz.ist_gast():
			spiel.hud.meldung(str(e.get("grund", "")), 2.5))

# Umstellen beenden: abstellen / abbrechen / ins Lager – das Ergebnis geht als Befehl an den Gastgeber (gibt die Sperre frei)
func _platz_ende(abstellen: bool, lager := false) -> bool:
	var i := penthouse.platz_index
	var ok := penthouse.platzieren_ende(abstellen, lager)
	if i < 0 or i >= w.moebel.size():
		return ok
	var m: Dictionary = w.moebel[i]
	if lager:
		Netz.befehl("moebel_lager", {"i": i, "id": m.id})
	elif ok:
		Netz.befehl("moebel_setzen", {"i": i, "id": m.id, "x": m.x, "z": m.z, "dreh": m.dreh})
	elif not abstellen:
		Netz.befehl("moebel_frei", {"i": i, "id": m.id})
	return ok

func _geaendert() -> void:
	penthouse.aktualisieren()
	laeden.aktualisieren()
	spiel._ausruestung()   # Boni übernehmen + speichern
	if menu.offen:
		menu.geld_label.text = "%s €" % Hud.punkte(w.geld)

# ---------------------------------------------------------------- Aufzug fahren
func fahren(ziel: String) -> void:
	if _faehrt:
		return
	_faehrt = true
	menu.schliessen()
	var tw := create_tween()
	tw.tween_property(blende, "color:a", 1.0, 0.3)
	await tw.finished
	_teleport(ziel)
	await get_tree().create_timer(0.35).timeout
	var tw2 := create_tween()
	tw2.tween_property(blende, "color:a", 0.0, 0.35)
	_faehrt = false

func _teleport(ziel: String) -> void:
	if penthouse.platzieren_aktiv():
		_platz_ende(false)
	var l := spiel.laeufer
	var neu := ziel if ziel not in ["unten", "casino"] else ""
	ort = neu
	spiel.turm.glas.set_shader_parameter("innen_band", Vector2(-1, -1))
	spiel.casino.turm_mat.set_shader_parameter("innen_band", Vector2(-1, -1))
	for id in sky.etagen:
		(sky.etagen[id].knoten as Node3D).visible = id == ort
	arcade.innen.visible = ort == "arcade"
	penthouse.innen.visible = ort == "penthouse"
	var name := ""
	match ziel:
		"unten":
			l.raum_setzen({}, sky.unten_pos, PI)
			name = "Erdgeschoss"
		"casino":
			l.raum_setzen({}, spiel.casino.aufzug_pos, PI * 0.5)
			name = "Casino"
		"arcade":
			l.raum_setzen(arcade.raum, arcade.ankunft(), PI * 0.5)
			name = "Arcade-Halle"
		"penthouse":
			l.raum_setzen(penthouse.raum, penthouse.ankunft(), PI * 0.5)
			spiel.casino.turm_mat.set_shader_parameter("innen_band", Vector2(penthouse.boden - 0.6, penthouse.decke + 0.8))
			penthouse.aktualisieren()
			name = "Dein Penthouse"
		_:
			var e: Dictionary = sky.etagen[ziel]
			l.raum_setzen(e.raum, e.ankunft, e.yaw)
			spiel.turm.glas.set_shader_parameter("innen_band", e.band)
			name = "%s · %d m" % [e.name, e.meter]
	if ort != "" and w.besuchen(ort):
		erfolge_pruefen()
	spiel.hud.meldung(name, 2.0)

# ---------------------------------------------------------------- Arcade
func _greif_starten(nr: int) -> void:
	var p := w.arcade_preis("greif")
	if w.geld < p:
		spiel.hud.meldung("Der Greifautomat kostet %s € – dir fehlen noch %s €." % [Hud.punkte(p), Hud.punkte(p - w.geld)], 2.5)
		return
	Netz.zahlen(p, "arcade")
	arcade.greif_starten(nr)

func _greif_ende(id: String) -> void:
	spiel.laeufer.cam.current = true
	if id == "":
		spiel.hud.meldung("Daneben! Nochmal versuchen?", 2.0)
	else:
		_gewonnen(id)
	spiel._speichern()

func _kapsel_gewonnen(id: String) -> void:
	_gewonnen(id, false)

func _gewonnen(id: String, zaehlen := true) -> void:
	if zaehlen:
		Netz.arcade_gewinn(id)
	var stufe := w.seltenheit(id)
	spiel.hud.meldung("Gewonnen: %s (%s)!\nLiegt jetzt im Lager deines Penthouses – am Tablet aufstellen." % [w.gegenstand(id).name, Wirtschaft.SELTENHEIT[stufe]], 3.5)
	erfolge_pruefen()
	spiel._speichern()
