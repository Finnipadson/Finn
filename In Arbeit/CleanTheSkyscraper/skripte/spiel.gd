class_name Spiel
extends Node3D
# Das eigentliche Spiel: Gondel + Putzen + Geld + Shop + Speichern.
# Testmodi (über haupt.gd, --ansicht=N): 5 Putz-Demo, 6/7 Fahrtests, 8 Maus-Test, 9 Shop-Test, 10 Speicher-Test, 13 Laufen, 14 Händler, 15 Kiosk-Bilder, 16 Casino, 17 Casino-Bilder, 18 Start zu Fuß, 19 Werkzeug-Kiosk, 20 Gondeln, 21 Helfer, 22 Fahrzeuge + Hotbar + Werkzeug-Stand, 23 Menü-Bilder, 24–28 Extras (ExtrasTest), 29–30 Läden (LaedenTest), 31–32 Strand (StrandTest), 33–34 Phase 5 (Phase5Test).

const SPIELSTAND := "user://spielstand.json"
const TESTSTAND := "user://spielstand_test.json"
const DURCHLAUF := "user://spielstand_durchlauf.json"   # --durchspielen: eigener Spielstand des Bots
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
var extras: Extras
var strand: Strand          # Strandbar, Fischladen, Angeln, Yacht (Geometrie: welt.kueste)
var karte: Karte            # Taste M: Stadtplan mit Ziel-Pfeil
var effekte: Effekte        # Phase 5: Glanz, Seifenblasen, Sprühnebel, Münzen
var pause: Pausenmenue      # Esc: Pausenmenü (Spiel pausiert)
var mitspieler: Mitspieler  # Mehrspieler (7a): Figuren + Spielerliste der anderen
var wirtschaft := Wirtschaft.new()
var ansicht := 0
var frei := false
var test_geld := -1
var pfad := SPIELSTAND
var speicher_zeit := 0.0
var demo_zeit := 0.0
var durchlauf := false    # --durchspielen: echtes Spiel (wie ansicht 0) mit Bot (Durchspielen), eigener Spielstand

func starten(t: Turm, w: Welt, a: int, ohne_sperre: bool, geld_test: int) -> void:
	turm = t
	welt = w
	ansicht = a
	frei = ohne_sperre
	test_geld = geld_test
	pfad = SPIELSTAND if ansicht == 0 else TESTSTAND
	durchlauf = ansicht == 0 and "--durchspielen" in OS.get_cmdline_user_args()
	if durchlauf:
		pfad = DURCHLAUF.replace(".json", Durchspielen.endung() + ".json")
		# neuer Lauf, außer der Bot lädt gerade mitten im Lauf neu (oder --weiter)
		var weiter := "--weiter" in OS.get_cmdline_user_args()
		if FileAccess.file_exists(Durchspielen.BOT_STAND):
			var d = JSON.parse_string(FileAccess.get_file_as_string(Durchspielen.BOT_STAND))
			weiter = weiter or (d is Dictionary and d.get("neu_laden", false))
		if not weiter and FileAccess.file_exists(pfad):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(pfad))
	if Ton.i:
		Ton.i.spiel = self
	Netz.spiel = self
	zustand = FensterZustand.new(turm)
	zustand.verbinde(turm.glas)
	turm.glas.set_shader_parameter("mit_zustand", true)
	if ansicht == 10 and test_geld >= 0 and FileAccess.file_exists(pfad):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pfad))
	if ansicht == 36 and Phase5Test.ort_stufe == 0 and FileAccess.file_exists(pfad):   # Test „Ort merken“: frisch anfangen
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pfad))
	# Mehrspieler-Gast: die Welt kommt vom Gastgeber (Netz.gast_stand), nicht aus der eigenen Datei
	var gast := Netz.ist_gast() and not Netz.gast_stand.is_empty()
	var stand: Dictionary = Netz.gast_stand if gast else (_lesen() if (ansicht == 0 or ansicht == 10 or ansicht == 36) else {})
	if not gast:
		Netz.orte = (stand.get("netz_orte", {}) as Dictionary).duplicate()
	# Je-Spieler-Werte (Werkzeug, Boosts, Aussehen …) liegen unter der eigenen Profil-ID (Phase 7b)
	wirtschaft.ich = str(Netz.profil.id) if str(Netz.profil.id) != "" else "ich"
	wirtschaft.als("")
	wirtschaft.laden(stand.get("wirtschaft", {}), gast)
	if stand.has("sauber"):
		zustand.laden(str(stand.sauber))
	if test_geld >= 0:
		wirtschaft.geld = test_geld
	spieler = Spieler.new()
	add_child(spieler)
	spieler.setup(turm, zustand, int(stand.get("stock", 2)), float(stand.get("weg", 236.0)), 0.0)
	if stand.has("y"):
		spieler.y = float(stand.y)
	if wirtschaft.aktive_gondel < 0:
		var k := turm.seite_bei(spieler.stock, spieler.weg)
		wirtschaft.aktive_gondel = k
		wirtschaft.gondeln[k].gekauft = true
		if not stand.is_empty() and not (stand.get("wirtschaft", {}) as Dictionary).has("gondeln"):
			for g in wirtschaft.gondeln:
				g.gekauft = true
	spieler.seite = wirtschaft.aktive_gondel
	gondeln = Gondeln.new()
	add_child(gondeln)
	gondeln.setup(turm, wirtschaft)
	gondeln.aktualisieren(wirtschaft.aktive_gondel)
	if gast:
		_gast_gondel(stand)
	spieler.fenster_sauber.connect(_fenster_sauber)
	var symbole := Symbole.new()   # Bilder für Hotbar + Menüs (einmal rendern)
	add_child(symbole)
	symbole.erzeugen()
	helfer = Helfer.new()
	add_child(helfer)
	helfer.setup(turm, zustand, wirtschaft, spieler)
	helfer.geputzt.connect(_helfer_geputzt)
	spieler.oben_gesperrt.connect(_oben_gesperrt)
	hud = Hud.new()
	add_child(hud)
	shop = Shop.new()
	add_child(shop)
	shop.setup(wirtschaft)
	shop.geaendert.connect(_ausruestung)
	shop.neues_spiel.connect(_neues_spiel)
	shop.hauptmenue.connect(_zum_hauptmenue)
	album = Album.new()
	add_child(album)
	album.setup(wirtschaft)
	ereignisse = Ereignisse.new()
	add_child(ereignisse)
	ereignisse.setup(spieler, zustand, turm, welt, hud)
	ereignisse.erlaubt = wirtschaft.einstellungen
	ereignisse.ereignis.connect(Netz.ereignis_senden)   # Mehrspieler: Gastgeber meldet Tauben/Böen/Sandsturm
	laeufer = Laeufer.new()
	add_child(laeufer)
	laeufer.setup(turm, welt)
	for sp in welt.stellplaetze:
		laeufer.hindernisse.append(sp.rect)
	laeufer.hindernisse.append_array(welt.hindernisse)   # Palmen, Laternen
	laeufer.polygone.append(welt.see_umriss(Laeufer.RADIUS + 0.75))   # nicht in den See laufen
	laeufer.boden_fn = welt.kueste.boden    # Strand, Treppen, Brücken
	laeufer.sperre_fn = welt.kueste.frei    # Kanal, Ufermauer, Meer
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
	laeufer.bloecke.append([welt.casino_rect, Casino.HOCH + 0.3 + Casino.TURM_STOCKWERKE * 3.5])
	cmenu = CasinoMenu.new()
	add_child(cmenu)
	cmenu.setup(wirtschaft)
	cmenu.gespielt.connect(_speichern)
	extras = Extras.new()
	add_child(extras)
	extras.setup(self)
	strand = Strand.new()
	add_child(strand)
	strand.setup(self)
	karte = Karte.new()
	add_child(karte)
	karte.setup(self)
	effekte = Effekte.new()
	add_child(effekte)
	effekte.setup(self)
	mitspieler = Mitspieler.new()
	add_child(mitspieler)
	mitspieler.setup(self)
	if ansicht == 37:   # Mehrspieler-Test (Gastgeber + Gäste als eigene Prozesse)
		var nt := NetzTest.new()
		add_child(nt)
		nt.setup(self)
	if ansicht >= 24 and ansicht <= 28:
		var et := ExtrasTest.new()
		add_child(et)
		et.setup(self)
	if ansicht >= 33 and ansicht <= 36:   # Phase 5: Ton, Einstellungen, Tageszeit, Effekte, Abspann
		var p5 := Phase5Test.new()
		add_child(p5)
		p5.setup(self)
	if ansicht == 31 or ansicht == 32:   # Strand, Angeln, Yacht, Karte: Test + Testbilder
		var stt := StrandTest.new()
		add_child(stt)
		stt.setup(self)
	if ansicht == 29 or ansicht == 30:   # Läden: Test + Testbilder
		var lt := LaedenTest.new()
		add_child(lt)
		lt.setup(self)
	if durchlauf:
		var bot := Durchspielen.new()
		add_child(bot)
		bot.setup(self)
	_ausruestung()
	if ansicht >= 5 and ansicht <= 7:
		spieler.gesperrt = true
		spieler.yaw = 0.25
		spieler.pitch = 0.05
	# Weiter am gespeicherten Ort (Phase 5, Wunsch des Users): in der Gondel an derselben Stelle bzw. zu Fuß dort, wo man
	# war (auch in Lounge, Penthouse, Arcade). Ohne gespeicherten Ort (alte Stände) wie früher zu Fuß neben der Gondel.
	var ort: Dictionary = stand.get("ort", {}) if ((ansicht == 0 and not durchlauf) or ansicht == 36 or gast) else {}
	if str(ort.get("modus", "")) == "gondel":
		spieler.yaw = float(ort.get("yaw", 0.0))
		spieler.pitch = float(ort.get("pitch", -0.08))
		letzte_hoehe = 0.0
	# Man startet zu Fuß neben der Gondel (unten). Die Gondel merkt sich die letzte Höhe und fährt beim Einsteigen dorthin zurück.
	elif ansicht == 0 or ansicht == 18 or ansicht == 36 or gast:
		if str(ort.get("modus", "")) == "fuss":
			_start_ort = ort
		if ansicht == 18:
			spieler.y = 20.0      # Test: so tun, als wäre man zuletzt auf 20 m gewesen
		letzte_hoehe = spieler.y if spieler.y > UNTEN + 1.0 else 0.0
		spieler.y = 0.3
		start_zu_fuss = 2
	# Tag und Nacht (Phase 5): nur im echten Spiel läuft die Zeit; Tests behalten die feste Sonne (außer --uhr=HH)
	if ansicht == 0 or gast:
		welt.zeit.phase = wirtschaft.tageszeit
		welt.zeit.laeuft = true
	_leuchtfeuer()
	if ansicht == 0 and str(ort.get("modus", "")) == "gondel":
		hud.meldung("Willkommen zurück! Weiter geht's in deiner Gondel auf %d m." % int(spieler.y), 5.0)
	elif ansicht == 0 and str(ort.get("modus", "")) == "fuss":
		hud.meldung("Willkommen zurück!", 3.0)
	elif ansicht == 0 and stand.is_empty():
		hud.meldung("Willkommen! Geh zur Gondel am Turm und drück E zum Einsteigen.\nDann mit der linken Maustaste das Fenster sauber reiben – Tab öffnet die Werkstatt.", 8.0)
	elif ansicht == 0 and letzte_hoehe > 0.0:
		hud.meldung("Willkommen zurück! Steig mit E in die Gondel – sie fährt dich zurück auf %d m." % int(letzte_hoehe), 6.0)
	if gast:
		hud.meldung("Du spielst bei %s mit! Turm, Geld und Gekauftes gehören allen." % Netz.name_von(1), 5.0)
		Netz.gast_bereit()   # ab jetzt Feld-Updates vom Gastgeber (gemeinsame Kasse)
	elif Netz.ist_host():
		Netz._anwesend_setzen()

# Mehrspieler-Gast: eine freie gekaufte Gondel nehmen (die des Gastgebers ist belegt; Belegung richtig ab 7c)
func _gast_gondel(stand: Dictionary) -> void:
	var belegt: Array = (stand.get("netz", {}) as Dictionary).get("belegte_gondeln", [])
	# eigene Gondel vom letzten Mal (je Spieler, 7b), sonst die erste freie gekaufte
	var wahl := -1
	var eigene := wirtschaft.aktive_gondel
	if eigene >= 0 and eigene < 3 and wirtschaft.gondeln[eigene].gekauft and not eigene in belegt:
		wahl = eigene
	else:
		for k in 3:
			if wirtschaft.gondeln[k].gekauft and not k in belegt:
				wahl = k
				break
	if wahl < 0:
		return
	# hinstellen wie _gondel_wechseln, ohne den Parkplatz der Gondel des Gastgebers zu überschreiben
	wirtschaft.aktive_gondel = wahl
	spieler.seite = wahl
	spieler.weg = gondeln.park_weg(wahl)
	spieler.y = 0.3
	spieler.stock = 0
	letzte_hoehe = float(wirtschaft.gondeln[wahl].hoehe)
	spieler._platzieren(0.0)
	gondeln.aktualisieren(wahl)

# Werkzeug + Upgrades auf die Gondel übertragen
func _ausruestung() -> void:
	if get_parent().has_method("_grafik"):
		get_parent()._grafik()   # Bildqualität (Optionen)
	spieler.werkzeug_setzen(wirtschaft.werkzeug())
	var ka := wirtschaft.kosmetik_aktiv
	spieler.aussehen(wirtschaft.kosmetik(ka.gondel).farbe, wirtschaft.kosmetik(ka.kleidung).farbe, wirtschaft.kosmetik(ka.schwamm).farbe, ka.lack, [ka.aufkleber, ka.blumen, ka.schirm, ka.radio])
	_werte()
	if helfer:
		helfer.abgleichen()
	if gondeln:
		gondeln.aktualisieren(wirtschaft.aktive_gondel)
	if ereignisse:
		ereignisse.erlaubt = wirtschaft.einstellungen
	var oberste := Turm.STOCKWERKE if frei else wirtschaft.oberstes_stockwerk()
	spieler.max_y = oberste * Turm.STOCK_H - 2.6
	_speichern()

# Mehrspieler-Gast: Felder vom Gastgeber sind angekommen (Netz._felder_anwenden)
func netz_aktualisiert(menues: bool, ausruestung: bool) -> void:
	if ausruestung:
		_ausruestung()
	if menues:
		menues_aktualisieren()
	else:
		for m in _menues():
			m.geld_label.text = "%s €" % Hud.punkte(wirtschaft.geld)
			_knoepfe_geld(m)

# Kauf-Knöpfe (Meta „preis“) je nach Kassenstand sperren/freigeben, ohne das Menü neu zu bauen (Klicks gehen nicht verloren)
func _knoepfe_geld(n: Node) -> void:
	for c in n.get_children():
		if c is Button and c.has_meta("preis"):
			(c as Button).disabled = wirtschaft.geld < int(c.get_meta("preis"))
		_knoepfe_geld(c)

func _menues() -> Array:
	var l := []
	for m in [shop, hmenu, extras.menu if extras else null, strand.menu if strand else null]:
		if m and m.offen and not (m is ExtrasMenu and m.kapsel_laeuft):   # Kapsel-Animation nicht abreißen
			l.append(m)
	return l

# Offene Menüs neu aufbauen (Kauf eines anderen Spielers, neue Felder vom Gastgeber)
func menues_aktualisieren() -> void:
	for m in _menues():
		m.aufbauen()

# Upgrades + laufende Boosts auf die Gondel übertragen (jedes Bild, weil Boosts ablaufen)
func _werte() -> void:
	# Penthouse-Boni (aufgestellte Gegenstände) + Spezial-Boosts der Sky-Lounge kommen dazu
	spieler.tempo_faktor = wirtschaft.tempo_faktor() * (1.0 + wirtschaft.bonus("tempo") + wirtschaft.boost_wirkung("tempo"))
	var eis := wirtschaft.boost_wirkung("reich")
	spieler.reich_seite = wirtschaft.reichweite_seite() + eis
	spieler.reich_oben = wirtschaft.reichweite_oben() + eis
	spieler.wisch_faktor = (1.0 + wirtschaft.bonus("flaeche") + wirtschaft.boost_wirkung("flaeche"))
	if helfer:
		helfer.tempo = 1.0 + wirtschaft.bonus("helfer") + wirtschaft.boost_wirkung("helfer")
	if ereignisse:
		ereignisse.limo = wirtschaft.boost_wirkung("tauben") > 0.0
	var t := ""
	if helfer and helfer.anzahl() > 0:
		t += "Helfer: %d · %d Fenster/min
" % [helfer.anzahl(), helfer.zuletzt_pro_minute()]
	for id in wirtschaft.boosts:
		var rest := int(wirtschaft.boosts[id])
		t += "%s %d:%02d\n" % [Wirtschaft.BOOSTS[id].name, rest / 60, rest % 60]
	hud.boosts(t.strip_edges())

# Lohn eines Fensters mit Goldpolitur, Spezial-Boosts und Penthouse-Bonus. wer = Profil-ID des Putzers ("" = ich):
# Boosts zählen nur für den, der das Fenster geputzt hat (Mehrspieler 7c)
func lohn_mit_boni(f: int, wer := "") -> int:
	var l := wirtschaft.lohn(f)
	return int(round(l * (1.0 + wirtschaft.bonus("lohn") + wirtschaft.boost_wirkung("lohn", wer))))

# Eigenes Fenster fertig. Mehrspieler-Gast: der Gastgeber entscheidet und zahlt (Netz.fertig_melden) – Glanz und Ton gleich,
# „+ €“ und Album-Meldung, sobald seine Antwort da ist (netz_fertig).
func _fenster_sauber(f: int, spalte: int) -> void:
	if Netz.ist_gast():
		Netz.fertig_melden(f, spalte)
		_fertig_effekte(f, spalte, 0, true)
		return
	var r := fenster_bezahlen(f, spalte, wirtschaft.ich)
	_fertig_effekte(f, spalte, int(r.lohn), true)
	_album_meldung(r)
	Netz.fertig_senden(f, spalte, Netz.meine_id(), r)

# Gastgeber/Einzelspieler: Lohn (mit den Boosts des Putzers), Statistik, Album für ein fertiges Fenster
func fenster_bezahlen(f: int, spalte: int, wer: String) -> Dictionary:
	var lohn := lohn_mit_boni(f, wer)
	wirtschaft.verdienen(lohn)
	wirtschaft.statistik.fenster_selbst = int(wirtschaft.statistik.fenster_selbst) + 1
	wirtschaft.fenster_je[wer] = int(wirtschaft.fenster_je.get(wer, 0)) + 1
	extras.fenster_geputzt()
	var r := {"lohn": lohn, "szene": "", "neu": false, "bonus": 0}
	var szene := zustand.szene(f, spalte)
	if szene > 0:
		var k := str(szene)
		r.neu = not wirtschaft.album.has(k)
		wirtschaft.album[k] = int(wirtschaft.album.get(k, 0)) + 1
		r.szene = FensterZustand.SZENEN[szene]
		if r.neu:
			r.bonus = 10 * lohn
			wirtschaft.geld += int(r.bonus)
	return r

func _album_meldung(r: Dictionary, finder := "") -> void:
	if str(r.get("szene", "")) == "":
		return
	if r.get("neu", false):
		Ton.spielen("erfolg", -5.0)
		if finder == "":
			hud.meldung("Neu im Sammelalbum: %s!  +%d €\n(B öffnet das Album)" % [r.szene, int(r.bonus)], 4.0)
		else:
			hud.meldung("Neu im Sammelalbum: %s – gefunden von %s!  +%d €" % [r.szene, finder, int(r.bonus)], 4.0)
	elif finder == "":
		hud.meldung(str(r.szene), 1.5)

# Glanz am Fenster; eigen = selbst geputzt (Ton, „+ €“, Münzen)
func _fertig_effekte(f: int, spalte: int, lohn: int, eigen: bool) -> void:
	if eigen:
		if lohn > 0:
			hud.pop("+%d €" % lohn)
		Ton.gedrosselt("quietschen", 0.12, -5.0, randf_range(0.9, 1.12))
		Ton.gedrosselt("glanz", 0.25, -9.0, randf_range(0.95, 1.08))
		if lohn > 0:
			Ton.gedrosselt("geld", 0.15, -12.0)
	_funkeln(spieler.fenster_mitte(f, spalte))
	effekte.fenster_glanz(f, spalte)
	if eigen and lohn > 0:
		effekte.muenzen(3)

# Mehrspieler: der Gastgeber meldet ein fertiges Fenster (wer = Peer, 0 = Helfer). Gastgeber: ein Gast war es.
func netz_fertig(f: int, spalte: int, wer: int, r: Dictionary) -> void:
	zustand.sauber_machen(f, spalte)
	if wer == 0:
		if helfer:
			helfer.verlauf.append(helfer.zeit)   # für „Fenster/min“ im HUD
		return
	if wer == Netz.meine_id():   # mein Fenster: jetzt kommt der Lohn
		hud.pop("+%d €" % int(r.get("lohn", 0)))
		Ton.gedrosselt("geld", 0.15, -12.0)
		effekte.muenzen(3)
		_album_meldung(r)
	else:
		_fertig_effekte(f, spalte, 0, false)
		_album_meldung(r, Netz.name_von(wer))

# ---------------------------------------------------------------- Fahrzeuge + Hotbar
func _fahrzeug_liste() -> Array:
	var l := [""]
	for f in Wirtschaft.FAHRZEUGE:
		if f.id in wirtschaft.fahrzeuge:
			l.append(f.id)
	return l

func _fahrzeug_waehlen(id: String) -> void:
	if laeufer.hoch > 1.5 and laeufer.fz_fliegt and id != "jetpack":
		hud.meldung("Erst landen (Strg), dann absteigen.", 2.0)
		return
	wirtschaft.fahrzeug = id
	laeufer.fahrzeug_setzen(id)
	hud.meldung("Zu Fuß" if id == "" else wirtschaft.fahrzeug_daten(id).name, 1.0)

const KURZ := {"schwamm": "Schwamm", "grossschwamm": "Gr. Schw.", "abzieher": "Abzieher", "doppel": "Doppel", "hochdruck": "Hochdr.",
	"mikro": "Mikrof.", "profi": "XXL", "teleskop": "Teleskop", "dampf": "Dampf", "lanze": "Lanze", "": "Zu Fuß", "scooter": "Scooter", "hoverboard": "Hover", "jetpack": "Jetpack"}

func _hotbar() -> void:
	var l := []
	var aktiv := 0
	if spieler.aktiv:
		for i in Wirtschaft.WERKZEUGE.size():
			var w: Dictionary = Wirtschaft.WERKZEUGE[i]
			if not w.id in wirtschaft.besitz:
				continue
			if w.id == wirtschaft.aktiv:
				aktiv = l.size()
			var farbe: String = w.get("farbe", {"schwamm": "ffd84a", "grossschwamm": "ffd84a", "abzieher": "c9ced4", "doppel": "c9ced4", "hochdruck": "ffc531", "teleskop": "c9ced4", "dampf": "e2483e", "lanze": "3a86d4"}.get(w.id, "ffffff"))
			l.append({"taste": (i + 1) % 10, "kurz": KURZ.get(w.id, w.name), "farbe": farbe, "bild": Symbole.bilder.get(w.id)})
	else:
		var fz := _fahrzeug_liste()
		for i in fz.size():
			var id: String = fz[i]
			if id == wirtschaft.fahrzeug:
				aktiv = i
			l.append({"taste": i + 1, "kurz": KURZ.get(id, id), "farbe": "9fd3a8" if id == "" else wirtschaft.fahrzeug_daten(id).farbe, "bild": Symbole.bilder.get(id)})
	hud.hotbar(l, aktiv)

# Ein Helfer hat ein Fenster fertig: Lohn abzüglich seines Anteils
func _helfer_geputzt(f: int, _spalte: int, art: String) -> void:
	var anteil: float = Wirtschaft.HELFER[art].anteil
	wirtschaft.verdienen(maxi(1, int(round(lohn_mit_boni(f) * (1.0 - anteil)))))
	wirtschaft.statistik.fenster_helfer = int(wirtschaft.statistik.fenster_helfer) + 1
	Netz.fertig_senden(f, _spalte, 0, {})   # Gäste: Fenster sauber

func _oben_gesperrt() -> void:
	hud.meldung("Das Seil ist zu kurz! Mit Tab in der Werkstatt eine längere Seilwinde kaufen.", 3.0)

# ---------------------------------------------------------------- Eingaben (Shop, Werkzeugwechsel)
func _input(e: InputEvent) -> void:
	if karte.offen:   # Karte (M) nimmt alle Eingaben selbst
		return
	if not shop.offen and not album.offen and not hmenu.offen and not cmenu.offen and not extras.menue_offen() and strand.maus(e):   # Angeln, Yacht
		get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseButton and extras.maus(e):   # Penthouse: Möbel platzieren
		get_viewport().set_input_as_handled()
		return
	# Mausrad: nächstes / voriges Werkzeug (Gondel) bzw. Fahrzeug (zu Fuß)
	if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if shop.offen or hmenu.offen or cmenu.offen or album.offen or express or extras.menue_offen():
			return
		var schritt := -1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		if spieler.aktiv:
			var l := []
			for w in Wirtschaft.WERKZEUGE:
				if w.id in wirtschaft.besitz:
					l.append(w.id)
			var i := l.find(wirtschaft.aktiv)
			wirtschaft.ausruesten(l[posmod(i + schritt, l.size())])
			_ausruestung()
		else:
			var fz := _fahrzeug_liste()
			_fahrzeug_waehlen(fz[posmod(fz.find(wirtschaft.fahrzeug) + schritt, fz.size())])
		return
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if Optionen.k(e) == KEY_M and not shop.offen and not album.offen and not hmenu.offen and not cmenu.offen and not extras.menue_offen() and not strand.menu.offen and strand.angeln.zustand != "drill":
		karte.oeffnen()
		get_viewport().set_input_as_handled()
		return
	if not hmenu.offen and not cmenu.offen and not shop.offen and not album.offen and strand.taste(e):
		get_viewport().set_input_as_handled()
		return
	if not hmenu.offen and not cmenu.offen and extras.taste(e):
		get_viewport().set_input_as_handled()
		return
	if cmenu.offen:
		if Optionen.k(e) == KEY_E or Optionen.k(e) == KEY_ESCAPE:
			cmenu.schliessen()
			get_viewport().set_input_as_handled()
		return
	if hmenu.offen:
		if Optionen.k(e) == KEY_E or Optionen.k(e) == KEY_ESCAPE:
			hmenu.schliessen()
			get_viewport().set_input_as_handled()
		return
	if (Optionen.k(e) == KEY_TAB and not album.offen) or (Optionen.k(e) == KEY_ESCAPE and shop.offen):
		shop.umschalten()
		spieler.gesperrt = shop.offen or (ansicht >= 5 and ansicht <= 7)
		spieler.wischt = false
		get_viewport().set_input_as_handled()
	elif (Optionen.k(e) == KEY_B and not shop.offen) or (Optionen.k(e) == KEY_ESCAPE and album.offen):
		album.umschalten()
		spieler.gesperrt = album.offen or (ansicht >= 5 and ansicht <= 7)
		spieler.wischt = false
		get_viewport().set_input_as_handled()
	elif Optionen.k(e) == KEY_E and not shop.offen and not album.offen:
		_ein_aus()
	elif Optionen.k(e) == KEY_ESCAPE and pause == null and not express and not extras.menue_offen() and not strand.blockiert():
		pause_oeffnen()
		get_viewport().set_input_as_handled()
	elif (Optionen.k(e) == KEY_R or Optionen.k(e) == KEY_T) and spieler.aktiv and not shop.offen and not album.offen and Ton.i:
		var t := Ton.i.radio_taste(Optionen.k(e) == KEY_T)
		if t != "":
			hud.meldung(t, 2.5)
			_speichern()
	elif Optionen.k(e) >= KEY_1 and Optionen.k(e) <= KEY_4 and not spieler.aktiv and not shop.offen and not hmenu.offen and not cmenu.offen:
		var fz := _fahrzeug_liste()
		var i2: int = Optionen.k(e) - KEY_1
		if i2 < fz.size():
			_fahrzeug_waehlen(fz[i2])
	elif Optionen.k(e) >= KEY_0 and Optionen.k(e) <= KEY_9 and spieler.aktiv and not shop.offen and not hmenu.offen and not cmenu.offen:
		var i: int = 9 if Optionen.k(e) == KEY_0 else Optionen.k(e) - KEY_1
		if i < Wirtschaft.WERKZEUGE.size() and wirtschaft.ausruesten(Wirtschaft.WERKZEUGE[i].id):
			_ausruestung()
			hud.meldung(Wirtschaft.WERKZEUGE[i].name, 1.2)

# ---------------------------------------------------------------- Aussteigen / Einsteigen
const UNTEN := 0.5        # Gondelboden so tief = ganz unten, man kann aussteigen
const EINSTEIG_WEIT := 4.0
const EXPRESS := 30.0     # m/s: Gondel fährt nach dem Einsteigen zur letzten Höhe
var letzte_hoehe := 0.0   # beim Start zu Fuß: dort war die Gondel zuletzt
var express := false
var start_zu_fuss := 0    # zählt Bilder bis zum Aussteigen am Anfang
var gondeln: Gondeln
var helfer: Helfer
var express_ziel := 0.0   # Express-Fahrt: dorthin (y)
var express_aussteigen := false   # nach der Fahrt nach unten aussteigen
var _hoehe_gemeldet := 0          # Mehrspieler-Gast: Höhenbonus schon beim Gastgeber angefragt

func _ein_aus() -> void:
	if spieler.aktiv:
		if express:
			return
		if spieler.y > UNTEN:
			# Express nach unten, Höhe merken (beim nächsten Einsteigen geht es wieder hinauf)
			letzte_hoehe = spieler.y
			express_ziel = 0.3
			express = true
			express_aussteigen = true
			spieler.gesperrt = true
			hud.meldung("Die Gondel fährt nach unten – du steigst dann aus. Deine Höhe (%d m) merkt sie sich." % int(letzte_hoehe), 3.0)
			return
		var n := spieler.normal
		var pos := spieler.gondel.global_position + n * 2.2
		spieler.aktiv = false
		laeufer.aktivieren(pos, atan2(n.x, n.z), spieler.gondel.global_position)
		laeufer.weitere_gondeln = gondeln.positionen()
		wirtschaft.gondeln[wirtschaft.aktive_gondel].hoehe = letzte_hoehe
		gondeln.aktualisieren(wirtschaft.aktive_gondel)
		hud.steuerung(true)
	else:
		var zur_gondel := _gondel_bevorzugt()
		if not zur_gondel and extras.e_druecken():   # Aufzüge, Sky-Lounge, Arcade, Penthouse
			return
		var st := haendler.stand_bei(Vector2(laeufer.position.x, laeufer.position.z))
		if st >= 0 and not zur_gondel:
			hmenu.oeffnen(Haendler.STAENDE[st].id, Haendler.STAENDE[st].name)
			laeufer.gesperrt = true
			return
		var cs := casino.station_bei(Vector2(laeufer.position.x, laeufer.position.z))
		if cs >= 0 and not zur_gondel:
			cmenu.oeffnen(Casino.STATIONEN[cs].id, Casino.STATIONEN[cs].name)
			laeufer.gesperrt = true
			return
		if laeufer.hoch > 1.5:
			hud.meldung("Erst landen – dann einsteigen.", 2.0)
			return
		var andere := gondeln.bei(Vector2(laeufer.position.x, laeufer.position.z), EINSTEIG_WEIT)
		if andere >= 0 and (_abstand_gondel() > EINSTEIG_WEIT or not wirtschaft.gondeln[andere].gekauft):
			if not wirtschaft.gondeln[andere].gekauft:
				var preis := wirtschaft.gondel_preis()
				Netz.befehl("gondel", {"seite": andere}, func(e: Dictionary):
					if e.get("ok", false):
						hud.meldung("Gondel %s gekauft! Drück E zum Einsteigen." % Turm.SEITEN_NAMEN[andere], 3.0)
						gondeln.aktualisieren(wirtschaft.aktive_gondel)
						_speichern()
					else:
						hud.meldung("Die Gondel %s kostet %s € – dir fehlen noch %s €." % [Turm.SEITEN_NAMEN[andere], Hud.punkte(preis), Hud.punkte(maxi(0, preis - wirtschaft.geld))], 3.0))
				return
			# Mehrspieler: eine Gondel, in der ein anderer sitzt, ist gesperrt (Gastgeber prüft)
			Netz.befehl("gondel_nehmen", {"seite": andere}, func(e: Dictionary):
				if e.get("ok", false) and not spieler.aktiv:
					_gondel_wechseln(andere)
					_einsteigen()
				elif not e.get("ok", false) and not Netz.ist_gast():
					hud.meldung(str(e.get("grund", "")), 3.0))
			return
		elif _abstand_gondel() > EINSTEIG_WEIT:
			hud.meldung("Geh zu einer Gondel am Turm, um einzusteigen.", 2.0)
			return
		_einsteigen()

func _einsteigen() -> void:
	laeufer.deaktivieren()
	spieler.aktiv = true
	spieler.cam.current = true
	hud.steuerung(false)
	if letzte_hoehe > UNTEN + 1.0:
		express_ziel = letzte_hoehe
		express = true
		spieler.gesperrt = true
		hud.meldung("Die Gondel fährt zurück auf %d m …" % int(letzte_hoehe), 3.0)

# In eine andere (geparkte) Gondel umsteigen: die bisherige parkt an ihrer Stelle
func _gondel_wechseln(k: int) -> void:
	var alt := wirtschaft.aktive_gondel
	wirtschaft.gondeln[alt].weg = spieler.weg
	wirtschaft.gondeln[alt].hoehe = letzte_hoehe
	wirtschaft.aktive_gondel = k
	spieler.seite = k
	spieler.weg = gondeln.park_weg(k)
	spieler.y = 0.3
	spieler.stock = 0
	letzte_hoehe = float(wirtschaft.gondeln[k].hoehe)
	spieler._platzieren(0.0)
	gondeln.aktualisieren(k)

# Steht man unten zugleich an der eigenen Gondel und an einer Station (Express-Aufzug, Kiosk), nimmt E das,
# wohin man schaut. Vorher öffnete E immer die Station – parkte die Gondel neben dem Aufzug, kam man nicht mehr hinein.
func _gondel_bevorzugt() -> bool:
	if spieler.aktiv or extras.ort != "" or _abstand_gondel() > EINSTEIG_WEIT:
		return false
	var p := Vector2(laeufer.position.x, laeufer.position.z)
	var ziele := []
	var sx := extras.station()
	if not sx.is_empty():
		ziele.append(sx.get("ziel", sx.pos))
	var hs := haendler.stand_bei(p)
	if hs >= 0:
		var v: Vector2 = haendler.vorne[hs]
		ziele.append(v + v.normalized() * 2.0)
	if ziele.is_empty():
		return true
	var vor := Vector2(-sin(laeufer.yaw), -cos(laeufer.yaw))
	var g := spieler.gondel.global_position
	var zur_g := vor.dot((Vector2(g.x, g.z) - p).normalized())
	for z in ziele:
		var d: Vector2 = (z as Vector2) - p
		if d.length() < 0.3 or vor.dot(d.normalized()) >= zur_g:   # Station ohne Blickziel / direkt davor: Station
			return false
	return true

func _abstand_gondel() -> float:
	var g := spieler.gondel.global_position
	return Vector2(laeufer.position.x - g.x, laeufer.position.z - g.z).length()

# ---------------------------------------------------------------- Speichern
func _lesen() -> Dictionary:
	if not FileAccess.file_exists(pfad):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(pfad))
	return d if d is Dictionary else {}

# Wo ist man gerade? (für den Start an derselben Stelle). Auf der Yacht: zu Fuß am Steg.
var _start_ort := {}
func _ort_daten() -> Dictionary:
	if spieler.aktiv:
		return {"modus": "gondel", "yaw": spieler.yaw, "pitch": spieler.pitch}
	if strand.yacht and strand.yacht.an_bord:
		var st: Vector2 = strand.k.stationen[2].pos
		return {"modus": "fuss", "x": st.x, "z": st.y, "yaw": 0.0, "pitch": 0.0, "innen": ""}
	return {"modus": "fuss", "x": laeufer.position.x, "z": laeufer.position.z, "yaw": laeufer.yaw, "pitch": laeufer.pitch, "innen": extras.ort}

func _ort_herstellen(o: Dictionary) -> void:
	var p := Vector2(float(o.get("x", 0.0)), float(o.get("z", 0.0)))
	var innen := str(o.get("innen", ""))
	if innen != "":
		if not (innen in ["arcade", "penthouse"] or extras.sky.etagen.has(innen)):
			return
		extras._teleport(innen)   # Raum, Sichtbarkeit, Aufzug-Ort wie mit dem Aufzug
	if not laeufer.frei(p):
		return   # Stelle inzwischen versperrt: an der Ankunft bzw. neben der Gondel bleiben
	laeufer.position.x = p.x
	laeufer.position.z = p.y
	if innen == "" and laeufer.boden_fn.is_valid():
		laeufer.position.y = laeufer.boden_fn.call(p)
	laeufer.yaw = float(o.get("yaw", 0.0))
	laeufer.pitch = float(o.get("pitch", 0.0))

# Spielstand als Dictionary (Speichern + Mehrspieler-Beitritt)
func stand_daten() -> Dictionary:
	wirtschaft.gondeln[wirtschaft.aktive_gondel].weg = spieler.weg
	wirtschaft.gondeln[wirtschaft.aktive_gondel].hoehe = maxf(spieler.y, letzte_hoehe)
	var d := {
		"version": 1,
		"wirtschaft": wirtschaft.speichern(),
		"sauber": zustand.speichern(),
		"stock": spieler.stock, "weg": spieler.weg, "y": maxf(spieler.y, letzte_hoehe),
		"ort": _ort_daten(),
	}
	if not Netz.orte.is_empty():
		d["netz_orte"] = Netz.orte
	return d

func _speichern() -> void:
	if ansicht != 0 and ansicht != 10 and ansicht != 36:
		return
	if Netz.ist_gast():
		return   # Gast: der Stand liegt beim Gastgeber
	var d := stand_daten()
	var f := FileAccess.open(pfad, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if zustand and spieler:
			_speichern()

# Esc: Pausenmenü (Weiterspielen, Einstellungen, Speichern, Hauptmenü, Beenden)
func pause_oeffnen() -> void:
	pause = Pausenmenue.new()
	get_parent().add_child(pause)
	pause.setup(self)

# Werkstatt → Einstellungen → „Hauptmenü“: speichern und das Startmenü über das laufende Spiel legen
func _zum_hauptmenue() -> void:
	if Netz.ist_gast():   # Gast verlässt die Runde → eigenes Spiel mit Hauptmenü
		Netz.zurueck_ins_menue("Du hast das Mehrspieler-Spiel verlassen.")
		return
	if Netz.ist_host():   # Gastgeber geht ins Menü → Runde endet für alle
		Netz.trennen()
	if shop.offen:
		shop.umschalten()
	spieler.gesperrt = ansicht >= 5 and ansicht <= 7
	spieler.wischt = false
	_speichern()
	if get_parent().has_method("hauptmenue_zeigen"):
		get_parent().hauptmenue_zeigen()

func _neues_spiel() -> void:
	if Netz.ist_gast():
		hud.meldung("Ein neues Spiel kann nur der Gastgeber anfangen.", 3.0)
		return
	Netz.trennen()
	if FileAccess.file_exists(pfad):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pfad))
	zustand = null   # nicht beim Beenden wieder speichern
	set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()

# Mehrspieler: eigene Lage für die anderen (Netz schickt sie 20× pro Sekunde), siehe Mitspieler.lage
func lage_daten() -> Array:
	if spieler.aktiv:
		# 7c: dazu Drehung der Gondel, Seite, Werkzeug und wo es gerade ist (für die Gondel-Figur bei den anderen)
		var g := spieler.gondel.global_position
		var wp := spieler.werkzeug.global_position if spieler.werkzeug else g
		return [1, g.x, g.y, g.z, spieler.yaw, "", "", spieler.winkel, spieler.seite, spieler.wz_id, wp.x, wp.y, wp.z, spieler.strahl.visible]
	if strand.yacht and strand.yacht.an_bord:
		return [2, 0.0, 0.0, 0.0, 0.0, "", ""]
	return [0, laeufer.position.x, laeufer.position.y + laeufer.hoch, laeufer.position.z, laeufer.yaw, extras.ort, laeufer.fahrzeug, laeufer.hoch]

# ---------------------------------------------------------------- Ablauf
func _process(dt: float) -> void:
	if start_zu_fuss > 0:
		start_zu_fuss -= 1
		if start_zu_fuss == 0 and spieler.aktiv:
			_ein_aus()
			if not _start_ort.is_empty():
				_ort_herstellen(_start_ort)
				_start_ort = {}
	if express:
		var ziel_y := minf(express_ziel, spieler.max_y)
		spieler.y = move_toward(spieler.y, ziel_y, EXPRESS * dt)
		if absf(spieler.y - ziel_y) < 0.01:
			express = false
			spieler.gesperrt = shop.offen or album.offen
			if express_aussteigen:
				express_aussteigen = false
				_ein_aus()
			else:
				letzte_hoehe = 0.0
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
		18: _start_test(dt)
		20: _gondel_test(dt)
		21: _helfer_test(dt)
		22: _fahrzeug_test(dt)
		23: _menue_bilder(dt)
		19: _werkzeug_test(dt)
	if ansicht == 0 or ansicht == 12 or Netz.ist_gast():   # Gast: spielt nur ab, was der Gastgeber würfelt (ereignisse.gast)
		ereignisse.takt(dt)
	# Neue Höhe erreicht (je 6 Stockwerke = ein Abschnitt): einmaliger Bonus + Aussicht feiern
	var abschnitt := spieler.stock / Wirtschaft.ABSCHNITT
	if abschnitt > wirtschaft.hoechster_abschnitt and not (Netz.ist_gast() and abschnitt <= _hoehe_gemeldet):
		_hoehe_gemeldet = abschnitt   # Gast: nur einmal fragen (Antwort braucht etwas)
		var meter := int(spieler.y)
		Netz.befehl("hoehe", {"abschnitt": abschnitt, "stock": spieler.stock}, func(e: Dictionary):
			if e.get("ok", false):
				Ton.spielen("glanz", -4.0, 0.8)
				hud.meldung("Neue Höhe: %d m!  Höhenbonus +%d €" % [meter, int(e.bonus)], 3.5)
				_speichern())
	hud.zeige(zustand.sauber_zahl, turm.fenster_gesamt, wirtschaft.geld, spieler.y, spieler.stock, not spieler.aktiv, strand.ort_name() if strand.ort_name() != "" else extras.ort_name())
	var menue := shop.offen or album.offen or hmenu.offen or cmenu.offen or extras.menue_offen() or strand.blockiert() or karte.offen
	laeufer.set_process(not menue)
	laeufer.gesperrt = menue
	wirtschaft.boosts_takt(dt)
	if not Netz.ist_gast():   # Preis-Faktor: höchste Spielerzahl der letzten 10 min (Gast bekommt ihn vom Gastgeber)
		wirtschaft.koop_takt(dt, Netz.spieler.size() if Netz.ist_host() else 1)
	_werte()
	if spieler.aktiv:
		hud.status("" if express else ("E: Gondel verlassen" if spieler.y <= UNTEN else "E: nach unten fahren und aussteigen"))
	elif strand.blockiert() or strand.status() != "":
		hud.status(strand.status())
	elif extras.drinnen() or (extras.status() != "" and not _gondel_bevorzugt()):
		hud.status(extras.status())
	else:
		var st2 := haendler.stand_bei(Vector2(laeufer.position.x, laeufer.position.z))
		var cs2 := casino.station_bei(Vector2(laeufer.position.x, laeufer.position.z))
		if st2 >= 0 and not _gondel_bevorzugt():
			hud.status("E: %s ansehen" % Haendler.STAENDE[st2].name)
		elif cs2 >= 0:
			hud.status("E: %s" % Casino.STATIONEN[cs2].hinweis)
		else:
			var ag := gondeln.bei(Vector2(laeufer.position.x, laeufer.position.z), EINSTEIG_WEIT)
			if ag >= 0 and not wirtschaft.gondeln[ag].gekauft:
				hud.status("E: Gondel %s kaufen (%s €)" % [Turm.SEITEN_NAMEN[ag], Hud.punkte(wirtschaft.gondel_preis())])
			elif ag >= 0 and _abstand_gondel() > EINSTEIG_WEIT:
				hud.status("E: in die Gondel %s einsteigen" % Turm.SEITEN_NAMEN[ag])
			else:
				hud.status("E: in die Gondel einsteigen" if _abstand_gondel() <= EINSTEIG_WEIT else "")
	hud.freigeschaltet(Turm.STOCKWERKE if frei else wirtschaft.oberstes_stockwerk())
	_hotbar()
	if not spieler.aktiv and laeufer.fahrzeug != wirtschaft.fahrzeug:   # am Fahrzeug-Kiosk gekauft/gewählt
		laeufer.fahrzeug_setzen(wirtschaft.fahrzeug)
	if spieler.wischt and spieler.wz_art == "wisch":
		var u := fposmod(spieler.weg + spieler.schwamm_off.x * spieler.richtung, turm.umfaenge[spieler.stock]) / Turm.FENSTER_B
		var f := turm.stockwerk_bei(spieler.y + spieler.schwamm_off.y)
		hud.fortschritt(zustand.fortschritt(f, int(u)), true)
	else:
		hud.fortschritt(0.0, false)
	# Alle Fenster sauber → einmal der Abspann (danach frei weiterspielen)
	if not wirtschaft.abspann and zustand.sauber_zahl >= turm.fenster_gesamt and ((ansicht == 0 and not durchlauf) or ansicht == 33) and not Netz.ist_gast():
		abspann_starten()   # im Mehrspieler startet ihn der Gastgeber für alle
	# Tageszeit: speichern, Innenräume hell halten, Uhr anzeigen, Leuchtfeuer auf der Spitze blinkt nachts
	if welt.zeit.phase >= 0.0:
		if welt.zeit.laeuft:
			wirtschaft.tageszeit = welt.zeit.phase
		welt.zeit.innen = extras.drinnen() or (laeufer.aktiv and not laeufer.raum.is_empty()) or (laeufer.aktiv and welt.casino_rect.has_point(Vector2(laeufer.position.x, laeufer.position.z)) and extras.ort == "")
		hud.uhr(Tageszeit.uhr_text(welt.zeit.phase))
		var n: float = welt.zeit.werte.get("nacht", 0.0)
		_feuer_mat.emission_energy_multiplier = (0.4 + 6.0 * n) * (1.0 if fmod(Time.get_ticks_msec() / 1000.0, 1.6) < 0.25 else 0.15)
	speicher_zeit += dt
	if speicher_zeit > AUTOSAVE:
		speicher_zeit = 0.0
		_speichern()

var abspann: Abspann
func abspann_starten() -> void:
	Netz.abspann_senden()
	wirtschaft.abspann = true
	if not wirtschaft.turm_nr in wirtschaft.tuerme_fertig:
		wirtschaft.tuerme_fertig.append(wirtschaft.turm_nr)
	_speichern()
	if shop.offen:
		shop.umschalten()
	if album.offen:
		album.umschalten()
	if hmenu.offen:
		hmenu.schliessen()
	if cmenu.offen:
		cmenu.schliessen()
	if karte.offen:
		karte.schliessen()
	abspann = Abspann.new()
	get_parent().add_child(abspann)
	abspann.setup(self)

# Rotes Flug-Warnlicht auf der Turmspitze (leuchtet nachts kräftig und blinkt)
var _feuer_mat: StandardMaterial3D
func _leuchtfeuer() -> void:
	_feuer_mat = RaumBau.leuchte("ff2a1a", 0.4)
	var k := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.9
	sm.height = 1.8
	k.mesh = sm
	k.material_override = _feuer_mat
	k.position = Vector3(0, turm.spitze + 0.6, 0)
	k.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(k)

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
				for id in ["grossschwamm", "abzieher", "hochdruck"]:   # Werkzeuge gibt es jetzt an den Kiosken
					wirtschaft.kaufe_werkzeug(id)
				for n in ["up_motor", "up_arm", "up_winde", "up_winde"]:
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
	var n := haendler.vorne.size()
	var i := mini(int(demo_zeit / 1.5), n - 1) if demo_zeit < 1.5 * n else mini(int((demo_zeit - 1.5 * n) / 1.5), n - 1)
	var v: Vector2 = haendler.vorne[i]
	var r := v.normalized()
	var weit := 7.0 if demo_zeit < 1.5 * n else 1.6   # danach jeden Kiosk von nah
	laeufer.position = Vector3(v.x - r.x * weit, 0, v.y - r.y * weit)
	laeufer.yaw = atan2(-r.x, -r.y) + (0.25 if demo_zeit < 1.5 * n else 0.0)
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
				for n in ["ein_tauben", "ein_sandsturm", "s_ruhig"]:
					var b: Button = shop.find_child(n, true, false)
					if b:
						b.pressed.emit()
					await get_tree().process_frame
				print("TEST einstellungen: %s erlaubt_ereignisse=%s taa=%s scale=%s" % [wirtschaft.einstellungen, ereignisse.erlaubt, get_viewport().use_taa, get_viewport().scaling_3d_scale])
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
			spieler.weg = turm.weg_auf_seite(spieler.stock, 230.0, spieler.seite)   # Stelle auf der eigenen Turmseite
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

# 18: Start zu Fuß neben der Gondel, einsteigen, Express-Fahrt zurück auf die letzte Höhe (20 m)
func _start_test(dt: float) -> void:
	demo_zeit += dt
	if _st_schritt == 0 and demo_zeit > 0.3:
		_st_schritt = 1
		print("TEST start zu Fuß: zu_fuss=%s kamera_laeufer=%s gondel_y=%.1f letzte_hoehe=%.1f abstand=%.1f" % [not spieler.aktiv, laeufer.cam.current, spieler.y, letzte_hoehe, _abstand_gondel()])
		var ev := InputEventKey.new()
		ev.keycode = KEY_E
		ev.pressed = true
		Input.parse_input_event(ev)
	elif _st_schritt == 1 and demo_zeit > 0.6:
		_st_schritt = 2
		print("TEST eingestiegen: in_gondel=%s express=%s gesperrt=%s" % [spieler.aktiv, express, spieler.gesperrt])
	elif _st_schritt == 2 and demo_zeit > 3.5:
		_st_schritt = 3
		print("TEST express fertig: gondel_y=%.1f (soll 20) express=%s gesperrt=%s gespeicherte_hoehe=%.1f" % [spieler.y, express, spieler.gesperrt, maxf(spieler.y, letzte_hoehe)])

var _st_schritt := 0

# 19: zum Werkzeug-Kiosk gehen, mit E öffnen, Mikrofaser-Schwamm kaufen, mit Taste 1 / 6 wechseln
var _wt := 0
func _werkzeug_test(dt: float) -> void:
	demo_zeit += dt
	match _wt:
		0:
			if demo_zeit > 0.4:
				spieler.y = 0.3
				if spieler.aktiv:
					_ein_aus()
				var i := 3
				var v: Vector2 = haendler.vorne[i]
				laeufer.position = Vector3(v.x, 0, v.y)
				_wt = 1
		1:
			if demo_zeit > 0.8:
				_taste(KEY_E)
				_wt = 2
		2:
			if demo_zeit > 1.1:
				var b: Button = hmenu.find_child("w_mikro", true, false)
				var vorher := wirtschaft.geld
				if b and not b.disabled:
					b.pressed.emit()
				print("TEST werkzeug-kiosk offen=%s stand=%s gekauft=%s aktiv=%s geld %d → %d (soll -350) modell=%s rx=%.2f" % [hmenu.offen, hmenu.stand, "mikro" in wirtschaft.besitz, wirtschaft.aktiv, vorher, wirtschaft.geld, spieler.wz_id, spieler.wz_rx])
				var gesperrt_knopf: Button = hmenu.find_child("w_lanze", true, false)
				print("TEST teures werkzeug gesperrt=%s" % (gesperrt_knopf != null and gesperrt_knopf.disabled))
				_taste(KEY_E)
				_wt = 3
		3:
			if demo_zeit > 1.5:   # Werkzeug-Tasten gelten in der Gondel: zurück zur Gondel und einsteigen
				var g := spieler.gondel.global_position
				laeufer.position = Vector3(g.x, 0, g.z) + spieler.normal * 2.4
				_taste(KEY_E)
				_wt = 31
		31:
			if demo_zeit > 1.8:
				_taste(KEY_1)
				_wt = 4
		4:
			if demo_zeit > 2.0:
				var nach1 := spieler.wz_id
				_taste(KEY_6)
				print("TEST tasten: menü_zu=%s taste1=%s" % [not hmenu.offen, nach1])
				_wt = 5
		5:
			if demo_zeit > 2.2:
				print("TEST taste6=%s in_gondel=%s" % [spieler.wz_id, spieler.aktiv])
				_wt = 6

func _halte_taste(k: Key, an: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = an
	Input.parse_input_event(e)

func _rad(runter: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_DOWN if runter else MOUSE_BUTTON_WHEEL_UP
	e.pressed = true
	Input.parse_input_event(e)

# 20: Gondeln – mit E aus 12 m nach unten (Höhe merken), andere Gondel kaufen, umsteigen, auf der eigenen Seite bleiben
var _gt := 0
var _gt_k := 0
var _gt_geld := 0
func _gondel_test(dt: float) -> void:
	demo_zeit += dt
	match _gt:
		0:
			if demo_zeit > 0.3:
				spieler.y = 12.0
				_taste(KEY_E)
				_gt = 1
		1:
			if demo_zeit > 2.0:
				var a := wirtschaft.aktive_gondel
				print("TEST express runter: zu_fuss=%s gemerkte_hoehe=%.1f (soll 12) seite=%s" % [not spieler.aktiv, float(wirtschaft.gondeln[a].hoehe), Turm.SEITEN_NAMEN[a]])
				_gt_k = (a + 1) % 3
				var p: Dictionary = gondeln.park_punkt(_gt_k)
				var q: Vector3 = p.pos + p.normal * 2.4
				laeufer.position = Vector3(q.x, 0, q.z)
				_gt_geld = wirtschaft.geld
				_gt = 2
		2:
			if demo_zeit > 2.3:
				_taste(KEY_E)   # kaufen
				_gt = 3
		3:
			if demo_zeit > 2.6:
				print("TEST gondel gekauft: %s geld %d → %d (soll -%d) status='%s'" % [wirtschaft.gondeln[_gt_k].gekauft, _gt_geld, wirtschaft.geld, Wirtschaft.GONDEL_PREISE[1], hud.status_l.text])
				_taste(KEY_E)   # umsteigen
				_gt = 4
		4:
			if demo_zeit > 3.0:
				print("TEST umgestiegen: in_gondel=%s aktive=%d (soll %d) spieler_seite=%d express=%s" % [spieler.aktiv, wirtschaft.aktive_gondel, _gt_k, spieler.seite, express])
				spieler.weg += 400.0   # weit weg schieben – muss auf der Seite bleiben
				_gt = 5
		5:
			if demo_zeit > 3.3:
				print("TEST seite gehalten: seite_jetzt=%d (soll %d)" % [turm.seite_bei(spieler.stock, spieler.weg), _gt_k])
				_halte_taste(KEY_D, true)
				_gt = 6
		6:
			if demo_zeit > 9.0:
				_halte_taste(KEY_D, false)
				print("TEST am Rand gestoppt: seite_jetzt=%d (soll %d) weg=%.1f" % [turm.seite_bei(spieler.stock, spieler.weg), _gt_k, spieler.weg])
				_gt = 7

# 21: Helfer – in der Werkstatt kaufen, 40 s arbeiten lassen, Fenster + Geld nachrechnen, nichts über der Seil-Grenze
var _ht2 := 0
var _ht2_geld := 0
var _ht2_sauber := 0
var _ht2_erwartet := 0
var _ht2_zahl := {}
var _ht2_kam: Camera3D
func _helfer_test(dt: float) -> void:
	demo_zeit += dt
	match _ht2:
		0:
			if demo_zeit > 0.3:
				_taste(KEY_TAB)
				_ht2 = 1
		1:
			if demo_zeit > 0.6:
				var vorher := wirtschaft.geld
				var soll := 0
				for n in ["he_putzkraft", "he_putzkraft", "he_putzkraft", "he_roboter", "he_drohne", "up_winde"]:
					var b: Button = shop.find_child(n, true, false)
					if n.begins_with("he_"):
						soll += wirtschaft.helfer_preis(n.substr(3))
					else:
						soll += wirtschaft.upgrade_preis("winde")
					if b and not b.disabled:
						b.pressed.emit()
				print("TEST helfer gekauft: %s geld %d → %d (soll -%d) helfer_da=%d" % [wirtschaft.helfer, vorher, wirtschaft.geld, soll, helfer.anzahl()])
				_taste(KEY_TAB)
				spieler.y = 40.0   # Spieler weiter oben, damit die Helfer unten freie Bahn haben
				var kam := Camera3D.new()   # Blick von außen auf die Seite, damit man die Helfer sieht
				add_child(kam)
				var fp := turm.fassaden_punkt(0, turm.seiten_mitte(0, spieler.seite) + 25.0, 6.0)
				kam.position = fp.pos + fp.normal * 26.0 + Vector3.UP * 4.0
				kam.look_at(fp.pos + Vector3.UP * 7.0)
				kam.current = true
				_ht2_kam = kam
				_ht2_geld = int(wirtschaft.statistik.verdient)   # nur Lohn (Erfolgs-Prämien landen auch auf dem Konto)
				_ht2_sauber = zustand.sauber_zahl
				helfer.geputzt.connect(func(f: int, _s: int, art: String) -> void:
					_ht2_erwartet += maxi(1, int(round(wirtschaft.lohn(f) * (1.0 - float(Wirtschaft.HELFER[art].anteil)))))
					_ht2_zahl[art] = int(_ht2_zahl.get(art, 0)) + 1)
				_ht2 = 2
		2:
			if _ht2_kam and helfer.anzahl() > 0:   # Kamera schaut abwechselnd auf jeden Helfer (Testbilder)
				var hn: Node3D = helfer.liste[int(demo_zeit / 6.0) % helfer.anzahl()].node
				var zp := hn.global_position
				var raus := Vector3(zp.x, 0, zp.z).normalized()
				_ht2_kam.position = zp + raus * 9.0 + raus.cross(Vector3.UP) * 4.0 + Vector3.UP * 2.5
				_ht2_kam.look_at(zp + Vector3.UP * 0.8)
			if demo_zeit > 45.0:
				var grenze := wirtschaft.oberstes_stockwerk()
				var zu_hoch := 0
				for f in range(grenze, Turm.STOCKWERKE):
					for c in turm.fenster_pro_stock[f]:
						if zustand.ist_sauber(f, c):
							zu_hoch += 1
				print("TEST helfer nach 45 s: fenster=%d je_art=%s geld +%d (soll +%d) über_grenze=%d pro_min=%d" % [zustand.sauber_zahl - _ht2_sauber, _ht2_zahl, int(wirtschaft.statistik.verdient) - _ht2_geld, _ht2_erwartet, zu_hoch, helfer.zuletzt_pro_minute()])
				_ht2 = 3

# 22: Fahrzeuge (Kiosk, Hotbar, Tempo, Jetpack), roter Werkzeug-Kiosk, Mausrad in der Gondel
var _ft := 0
var _ft_p := Vector3.ZERO
func _fahrzeug_test(dt: float) -> void:
	demo_zeit += dt
	match _ft:
		0:
			if demo_zeit > 0.3:
				spieler.y = 0.3
				_taste(KEY_E)   # aussteigen
				_ft = 1
		1:
			if demo_zeit > 0.6:
				var v: Vector2 = haendler.vorne[4]   # roter Kiosk „Werkzeuge“
				laeufer.position = Vector3(v.x, 0, v.y)
				_taste(KEY_E)
				_ft = 2
		2:
			if demo_zeit > 0.9:
				var b: Button = hmenu.find_child("w_grossschwamm", true, false)
				if b:
					b.pressed.emit()
				print("TEST roter kiosk: stand=%s gekauft=%s profi_hier=%s" % [hmenu.stand, "grossschwamm" in wirtschaft.besitz, hmenu.find_child("w_mikro", true, false) != null])
				_taste(KEY_E)
				_ft = 3
		3:
			if demo_zeit > 1.2:
				var v: Vector2 = haendler.vorne[5]   # Fahrzeug-Kiosk
				laeufer.position = Vector3(v.x, 0, v.y)
				_taste(KEY_E)
				_ft = 4
		4:
			if demo_zeit > 1.5:
				for n in ["f_scooter", "f_jetpack"]:
					var b: Button = hmenu.find_child(n, true, false)
					if b and not b.disabled:
						b.pressed.emit()
				print("TEST fahrzeuge gekauft: %s aktiv=%s" % [wirtschaft.fahrzeuge, wirtschaft.fahrzeug])
				_taste(KEY_E)
				_ft = 5
		5:
			if demo_zeit > 1.8:
				_taste(KEY_2)   # Scooter
				laeufer.position = Vector3(0, 0, 42)   # freie Fläche auf dem Platz (Lücke zwischen zwei Flügeln)
				laeufer.yaw = PI                        # Blick nach außen (+z)
				_ft = 6
		6:
			if demo_zeit > 2.0:
				_ft_p = laeufer.position
				_halte_taste(KEY_W, true)
				_ft = 7
		7:
			if demo_zeit > 3.0:
				_halte_taste(KEY_W, false)
				print("TEST scooter: fahrzeug=%s tempo=%.1f m/s (soll ~13) hotbar_felder=%d" % [laeufer.fahrzeug, laeufer.position.distance_to(_ft_p) / 1.0, hud.hotbar_box.get_child_count()])
				_rad(true)      # Mausrad → Jetpack
				_ft = 8
		8:
			if demo_zeit > 3.2:
				_halte_taste(KEY_SPACE, true)
				_ft = 9
		9:
			if demo_zeit > 5.2:
				_halte_taste(KEY_SPACE, false)
				var haus: Rect2 = welt.haeuser[0]
				var hh: float = welt.haeuser_hoehe[0]
				var mitte := haus.get_center()
				var alt := laeufer.hoch
				laeufer.hoch = hh + 2.0
				var drueber := laeufer.frei(mitte)
				laeufer.hoch = hh * 0.5
				var drin := laeufer.frei(mitte)
				laeufer.hoch = alt
				print("TEST jetpack: fahrzeug=%s hoch=%.1f (soll ~16) über_haus_frei=%s in_haus_frei=%s (soll true/false)" % [laeufer.fahrzeug, laeufer.hoch, drueber, drin])
				_halte_taste(KEY_CTRL, true)
				_ft = 10
		10:
			if demo_zeit > 8.0:
				_halte_taste(KEY_CTRL, false)
				print("TEST gelandet: hoch=%.1f" % laeufer.hoch)
				_ft = 11
		11:
			# zurück in die Gondel, Mausrad wechselt das Werkzeug
			var g := spieler.gondel.global_position
			laeufer.position = Vector3(g.x, 0, g.z) + spieler.normal * 2.4
			_taste(KEY_E)
			_ft = 12
		12:
			if demo_zeit > 8.6:
				var vorher := wirtschaft.aktiv
				_rad(false)
				_ft = 13
				print("TEST in_gondel=%s hotbar_felder=%d werkzeug_vorher=%s" % [spieler.aktiv, hud.hotbar_box.get_child_count(), vorher])
		13:
			if demo_zeit > 8.9:
				print("TEST mausrad: werkzeug_jetzt=%s" % wirtschaft.aktiv)
				_ft = 14

# 23: Testbilder aller Menüs – Werkstatt-Reiter nacheinander, dann jeder Kiosk (alle 1 s ein neues Bild)
var _mb := -1
func _menue_bilder(dt: float) -> void:
	demo_zeit += dt
	var i := int(demo_zeit)
	if i == _mb:
		return
	_mb = i
	if i == 1:
		shop.umschalten()
	elif i >= 2 and i <= 4:
		shop._reiter_waehlen(i - 1)
	elif i == 5:
		shop.umschalten()
		spieler.y = 0.3
		_ein_aus()
	elif i >= 6 and i < 6 + Haendler.STAENDE.size():
		if hmenu.offen:
			hmenu.schliessen()
		var k := i - 6
		hmenu.oeffnen(Haendler.STAENDE[k].id, Haendler.STAENDE[k].name)
