class_name ExtrasMenu
extends CanvasLayer
# Menüs der Extras im Stil „Glas modern“ (UiGlas): Aufzüge, Möbel-Läden + Einrichten (Tablet), Kapsel-Automat,
# Erfolge + Statistik (Taste P oder Vitrine). Knopf-Namen (fahr_, kauf_, auf_, weg_, verk_, kapsel, reiter_) nutzen die Tests.

signal fahren(ziel: String)
signal platzieren(index: int)
signal geaendert
signal kapsel_gewonnen(id: String)

var wirtschaft: Wirtschaft
var liste: VBoxContainer
var scroll: ScrollContainer
var titel: Label
var geld_label: Label
var unter: Label
var reiter_leiste: HBoxContainer
var fuss: Label
var art := ""            # aufzug_turm, aufzug_casino, katalog, designer, exklusiv, kapsel, erfolge
var reiter := 0
var offen := false
var oberstes := 0        # Seil reicht bis zu diesem Stockwerk (für den Turm-Aufzug)
var ort := ""            # wo man gerade ist (Aufzug: aktuelle Etage markieren)
var kapsel_laeuft := false
var letzte_kapsel := ""

func setup(w: Wirtschaft) -> void:
	wirtschaft = w
	layer = 10
	var vb: VBoxContainer = UiGlas.fenster(self, 760)[1]
	var kopf := HBoxContainer.new()
	vb.add_child(kopf)
	titel = UiGlas.text("", 26, UiGlas.TEXT, true)
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(titel)
	geld_label = UiGlas.text("", 24, UiGlas.GELD, true)
	kopf.add_child(geld_label)
	unter = UiGlas.ueberschrift("")
	vb.add_child(unter)
	reiter_leiste = HBoxContainer.new()
	reiter_leiste.add_theme_constant_override("separation", 6)
	vb.add_child(reiter_leiste)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	liste = VBoxContainer.new()
	liste.add_theme_constant_override("separation", 8)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(liste)
	fuss = UiGlas.text("E oder Esc: schließen", 13, UiGlas.TEXT_LEISE)
	vb.add_child(fuss)
	visible = false

func oeffnen(a: String, name: String) -> void:
	art = a
	reiter = 0
	titel.text = name
	offen = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	aufbauen()

func schliessen() -> void:
	if kapsel_laeuft:
		return
	offen = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _leeren(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)   # sofort raus, damit neue Knöpfe ihre Namen behalten
		c.queue_free()

func _reiter(namen: Array) -> void:
	reiter_leiste.visible = true
	for i in namen.size():
		var b := UiGlas.reiter(namen[i], i == reiter)
		b.name = "reiter_%d" % i
		b.pressed.connect(func():
			reiter = i
			aufbauen())
		reiter_leiste.add_child(b)

func aufbauen() -> void:
	_leeren(liste)
	_leeren(reiter_leiste)
	reiter_leiste.visible = false
	scroll.custom_minimum_size.y = 470
	geld_label.text = "%s €" % Hud.punkte(wirtschaft.geld)
	match art:
		"aufzug_turm": _aufzug_turm()
		"aufzug_casino": _aufzug_casino()
		"katalog":
			_reiter(["Kaufen", "Meine Sachen", "Boni"])
			[_laden, _sachen, _boni][reiter].call()
		"designer", "exklusiv": _laden()
		"kapsel": _kapsel()
		"erfolge":
			_reiter(["Erfolge", "Statistik"])
			[_erfolge, _statistik][reiter].call()

# ---------------------------------------------------------------- Aufzüge
func _aufzug_turm() -> void:
	unter.text = "EXPRESS-AUFZUG – EINE ETAGE IST FREI, SOBALD DEIN SEIL SO HOCH REICHT"
	_ziel("unten", "Erdgeschoss", "Zurück auf den Platz am Turm.", true, "EG")
	for e in SkyLounge.ETAGEN:
		var frei: bool = oberstes >= int(e.stock)
		var info: String = e.text
		if not frei:
			info += "  Gesperrt: Seil bis Stockwerk %d nötig (jetzt %d)." % [e.stock, oberstes]
		_ziel(e.id, "%s · %d m" % [e.name, SkyLounge.meter(e)], info, frei, "%d" % SkyLounge.meter(e))

func _aufzug_casino() -> void:
	unter.text = "AUFZUG IM CASINO-HOCHHAUS"
	_ziel("casino", "Erdgeschoss · Casino", "Blackjack, Glücksrad, Banditen, Rubbellose.", true, "EG")
	_ziel("arcade", "1. Stock · Arcade-Halle", "Greifautomaten und Kapsel-Automaten – Gewinne fürs Penthouse.", true, "1")
	_ziel("penthouse", "Dach · Dein Penthouse", "Möbel aufstellen, Pokale in der Vitrine.", true, "PH")

func _ziel(id: String, name: String, info: String, frei: bool, kurz: String) -> void:
	var hier := id == ort or (id in ["unten", "casino"] and ort == "")
	var k := UiGlas.knopf("Du bist hier" if hier else ("Fahren" if frei else "Gesperrt"), "besitz" if hier else ("kaufen" if frei else "nehmen"))
	k.disabled = hier or not frei
	k.name = "fahr_" + id
	k.pressed.connect(func(): fahren.emit(id))
	liste.add_child(UiGlas.karte(name, info, k, kurz, UiGlas.AKZENT if frei else UiGlas.TEXT_LEISE))

# ---------------------------------------------------------------- Läden
func _bonus_text(id: String) -> String:
	var g := wirtschaft.gegenstand(id)
	if not g.has("bonus"):
		return "Deko"
	return "+%d %% %s" % [int(round(wirtschaft.gegenstand_bonus(id) * 100.0)), Wirtschaft.BONUS_ARTEN[g.bonus]]

func _laden() -> void:
	var quelle := "katalog" if art == "katalog" else art
	unter.text = {"katalog": "MÖBEL-KATALOG – WIRD INS LAGER GELIEFERT, AUFSTELLEN UNTER „MEINE SACHEN“",
		"designer": "DESIGNER-MÖBEL – BONUS WIRKT, WENN SIE IM PENTHOUSE STEHEN",
		"exklusiv": "EXKLUSIV-MÖBEL – DAS BESTE FÜR DEIN PENTHOUSE"}[quelle]
	for id in Wirtschaft.GEGENSTAENDE:
		var g: Dictionary = Wirtschaft.GEGENSTAENDE[id]
		if g.quelle != quelle:
			continue
		var p := wirtschaft.gegenstand_preis(id)
		var k := UiGlas.knopf("%s €" % Hud.punkte(p))
		k.disabled = wirtschaft.geld < p
		k.name = "kauf_" + id
		k.pressed.connect(func():
			if wirtschaft.kaufe_gegenstand(id):
				geaendert.emit()
			aufbauen())
		var n := wirtschaft.anzahl_gegenstand(id)
		var info := _bonus_text(id) + ("  ·  Hast du schon %d×" % n if n > 0 else "")
		var stufe := wirtschaft.seltenheit(id)
		liste.add_child(UiGlas.karte(g.name, info, k, "M", Color(Wirtschaft.SELTEN_FARBE[stufe]) if g.has("bonus") else UiGlas.AKZENT, -1, 0, Symbole.bilder.get("g_" + id)))

func _sachen() -> void:
	unter.text = "AUFSTELLEN: VORSCHAU MIT DER MAUS ZIELEN · R/MAUSRAD DREHEN · KLICK ABSTELLEN"
	if wirtschaft.moebel.is_empty():
		liste.add_child(UiGlas.text("Noch nichts da – kauf etwas im Katalog oder gewinn etwas in der Arcade-Halle.", 15, UiGlas.TEXT_LEISE))
		return
	for i in wirtschaft.moebel.size():
		var m: Dictionary = wirtschaft.moebel[i]
		var g := wirtschaft.gegenstand(m.id)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var auf := UiGlas.knopf("Umstellen" if m.steht else "Aufstellen", "nehmen" if m.steht else "kaufen")
		auf.custom_minimum_size.x = 120
		auf.name = "auf_%d" % i
		auf.pressed.connect(func(): platzieren.emit(i))
		hb.add_child(auf)
		if m.steht:
			var weg := UiGlas.knopf("Ins Lager", "nehmen")
			weg.custom_minimum_size.x = 110
			weg.name = "weg_%d" % i
			weg.pressed.connect(func():
				wirtschaft.moebel[i].steht = false
				geaendert.emit()
				aufbauen())
			hb.add_child(weg)
		else:
			var v := UiGlas.knopf("Verkaufen +%s €" % Hud.punkte(wirtschaft.verkaufswert(m.id)), "gefahr")
			v.custom_minimum_size.x = 150
			v.name = "verk_%d" % i
			v.pressed.connect(func():
				wirtschaft.geld += wirtschaft.verkaufswert(m.id)
				wirtschaft.moebel.remove_at(i)
				geaendert.emit()
				aufbauen())
			hb.add_child(v)
		var stufe := wirtschaft.seltenheit(m.id)
		var info := "%s · %s · %s" % [Wirtschaft.SELTENHEIT[stufe] if g.quelle == "arcade" or g.has("seltenheit") else "Möbel", _bonus_text(m.id), "steht" if m.steht else "im Lager"]
		liste.add_child(UiGlas.karte(g.name, info, hb, "M", Color(Wirtschaft.SELTEN_FARBE[stufe]), -1, 0, Symbole.bilder.get("g_" + m.id)))

func _boni() -> void:
	unter.text = "BONI ALLER AUFGESTELLTEN GEGENSTÄNDE (HÖCHSTENS +%d %% JE ART)" % int(Wirtschaft.BONUS_MAX * 100.0)
	for art_id in Wirtschaft.BONUS_ARTEN:
		var b := wirtschaft.bonus(art_id)
		var wert := UiGlas.text("+%d %%" % int(round(b * 100.0)), 22, UiGlas.GELD if b > 0.0 else UiGlas.TEXT_LEISE, true)
		wert.custom_minimum_size.x = 90
		wert.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		liste.add_child(UiGlas.karte(Wirtschaft.BONUS_ARTEN[art_id], "", wert, "%", UiGlas.GELD, int(round(b * 20.0)), 20))

# ---------------------------------------------------------------- Kapsel-Automat
func _kapsel() -> void:
	unter.text = "MÜNZE REIN, KAPSEL RAUS – IMMER EIN GEWINN FÜRS PENTHOUSE"
	scroll.custom_minimum_size.y = 560
	var chancen := HBoxContainer.new()
	chancen.add_theme_constant_override("separation", 10)
	for i in 4:
		var l := UiGlas.text("%s %s %%" % [Wirtschaft.SELTENHEIT[i], str(Wirtschaft.KAPSEL_CHANCE[i] * 100.0).trim_suffix(".0")], 14, Color(Wirtschaft.SELTEN_FARBE[i]), true)
		chancen.add_child(l)
	liste.add_child(chancen)
	var buehne := CenterContainer.new()
	buehne.custom_minimum_size = Vector2(0, 200 if letzte_kapsel != "" else 140)
	buehne.name = "buehne"
	liste.add_child(buehne)
	if letzte_kapsel != "":
		buehne.add_child(_gewinn_karte(letzte_kapsel))
	var p := wirtschaft.arcade_preis("kapsel")
	var k := UiGlas.knopf("Kapsel ziehen · %s €" % Hud.punkte(p))
	k.disabled = wirtschaft.geld < p or kapsel_laeuft
	k.name = "kapsel"
	k.custom_minimum_size.x = 260
	k.pressed.connect(_kapsel_ziehen)
	var c := CenterContainer.new()
	c.add_child(k)
	liste.add_child(c)
	_vorschau()

# Alle möglichen Gewinne mit Bild, Name und Bonus, je Seltenheit eine Reihe
func _vorschau() -> void:
	liste.add_child(UiGlas.ueberschrift("MÖGLICHE GEWINNE"))
	var gitter := GridContainer.new()
	gitter.columns = 5
	gitter.add_theme_constant_override("h_separation", 6)
	gitter.add_theme_constant_override("v_separation", 6)
	liste.add_child(gitter)
	for stufe in 4:
		var farbe := Color(Wirtschaft.SELTEN_FARBE[stufe])
		for id in Wirtschaft.GEGENSTAENDE:
			var g: Dictionary = Wirtschaft.GEGENSTAENDE[id]
			if g.quelle != "arcade" or int(g.seltenheit) != stufe:
				continue
			var p := PanelContainer.new()
			p.add_theme_stylebox_override("panel", UiGlas.box(Color(farbe, 0.1), Color(farbe, 0.5), 8, 6))
			p.custom_minimum_size = Vector2(138, 0)
			p.name = "vorschau_" + id
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			p.add_child(hb)
			var tr := TextureRect.new()
			tr.texture = Symbole.bilder.get("g_" + id)
			tr.custom_minimum_size = Vector2(44, 44)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hb.add_child(tr)
			var vb := VBoxContainer.new()
			vb.add_theme_constant_override("separation", 0)
			vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var n := UiGlas.text(g.name, 12, UiGlas.TEXT, true)
			n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			n.custom_minimum_size = Vector2(76, 0)
			vb.add_child(n)
			vb.add_child(UiGlas.text("+%d %% %s" % [int(round(wirtschaft.gegenstand_bonus(id) * 100.0)), _bonus_kurz(g.bonus)], 11, farbe))
			var hat := wirtschaft.anzahl_gegenstand(id)
			if hat > 0:
				vb.add_child(UiGlas.text("hast du %d×" % hat, 10, UiGlas.TEXT_LEISE))
			hb.add_child(vb)
			gitter.add_child(p)

static func _bonus_kurz(art_id: String) -> String:
	return {"lohn": "Geld", "flaeche": "Fläche", "tempo": "Tempo", "helfer": "Helfer", "boost": "Boosts"}.get(art_id, art_id)

func _kapsel_ziehen() -> void:
	var p := wirtschaft.arcade_preis("kapsel")
	if kapsel_laeuft or wirtschaft.geld < p:
		return
	wirtschaft.geld -= p
	wirtschaft.statistik.arcade_spiele = int(wirtschaft.statistik.arcade_spiele) + 1
	var stufe := wirtschaft.kapsel_stufe(randf())
	var id := wirtschaft.zufall_gegenstand(stufe)
	kapsel_laeuft = true
	letzte_kapsel = ""
	aufbauen()
	var buehne := liste.get_node("buehne") as CenterContainer
	# Kapsel: runder Ball in der Farbe der Seltenheit, wackelt und springt auf
	var ball := Panel.new()
	ball.custom_minimum_size = Vector2(120, 120)
	var sb := UiGlas.box(Color(Wirtschaft.SELTEN_FARBE[stufe]), Color(1, 1, 1, 0.6), 60, 0)
	sb.set_border_width_all(4)
	ball.add_theme_stylebox_override("panel", sb)
	ball.pivot_offset = Vector2(60, 60)
	buehne.add_child(ball)
	var tw := create_tween()
	for j in 4:
		tw.tween_property(ball, "rotation", 0.35 if j % 2 == 0 else -0.35, 0.12)
	tw.tween_property(ball, "rotation", 0.0, 0.1)
	tw.tween_property(ball, "scale", Vector2(1.35, 1.35), 0.18)
	tw.tween_property(ball, "modulate:a", 0.0, 0.15)
	await tw.finished
	wirtschaft.bekomme_gegenstand(id)
	wirtschaft.statistik.arcade_gewinne = int(wirtschaft.statistik.arcade_gewinne) + 1
	letzte_kapsel = id
	kapsel_laeuft = false
	kapsel_gewonnen.emit(id)
	if offen and art == "kapsel":
		aufbauen()

func _gewinn_karte(id: String) -> Control:
	var g := wirtschaft.gegenstand(id)
	var stufe := wirtschaft.seltenheit(id)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiGlas.box(Color(Color(Wirtschaft.SELTEN_FARBE[stufe]), 0.16), Color(Wirtschaft.SELTEN_FARBE[stufe]), 14, 18))
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(vb)
	var bild: Texture2D = Symbole.bilder.get("g_" + id)
	if bild:
		var tr := TextureRect.new()
		tr.texture = bild
		tr.custom_minimum_size = Vector2(110, 110)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vb.add_child(tr)
	for t in [[Wirtschaft.SELTENHEIT[stufe].to_upper(), 14, Color(Wirtschaft.SELTEN_FARBE[stufe])], [g.name, 22, UiGlas.TEXT], [_bonus_text(id) + " · liegt im Penthouse-Lager", 13, UiGlas.TEXT_LEISE]]:
		var l := UiGlas.text(t[0], t[1], t[2], true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
	return p

# ---------------------------------------------------------------- Erfolge + Statistik
func _erfolge() -> void:
	unter.text = "%d VON %d ERFOLGEN – JEDER GIBT GELD UND EINEN POKAL FÜR DIE VITRINE IM PENTHOUSE" % [wirtschaft.erfolge.size(), Erfolge.LISTE.size()]
	var gitter := GridContainer.new()
	gitter.columns = 2
	gitter.add_theme_constant_override("h_separation", 8)
	gitter.add_theme_constant_override("v_separation", 8)
	liste.add_child(gitter)
	for e in Erfolge.LISTE:
		var da := wirtschaft.erfolge.has(e.id)
		var farbe := Color(Erfolge.POKAL_FARBE[e.pokal]) if da else UiGlas.TEXT_LEISE
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiGlas.box(Color(farbe, 0.1 if da else 0.04), Color(farbe, 0.5 if da else 0.15), 10, 10))
		p.custom_minimum_size = Vector2(350, 0)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		p.add_child(hb)
		var kachel := UiGlas.text("★" if da else "☆", 26, farbe, true)
		kachel.custom_minimum_size = Vector2(30, 0)
		hb.add_child(kachel)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(UiGlas.text(e.name, 15, UiGlas.TEXT if da else UiGlas.TEXT_LEISE, true))
		vb.add_child(UiGlas.text("%s · %s € · %s" % [e.text, Hud.punkte(e.geld), Erfolge.POKAL[e.pokal]], 12, UiGlas.TEXT_LEISE))
		hb.add_child(vb)
		gitter.add_child(p)

static func zeit_text(s: float) -> String:
	var m := int(s) / 60
	return "%d:%02d h" % [m / 60, m % 60] if m >= 60 else "%d min" % m

func _statistik() -> void:
	unter.text = "STATISTIK UND REKORDE"
	var st := wirtschaft.statistik
	var zeilen := [
		["Spielzeit", zeit_text(float(st.spielzeit))],
		["Fenster selbst geputzt", Hud.punkte(int(st.fenster_selbst))],
		["Fenster von Helfern", Hud.punkte(int(st.fenster_helfer))],
		["Geld mit Fenstern verdient", "%s €" % Hud.punkte(int(st.verdient))],
		["Geld aus Erfolgen", "%s €" % Hud.punkte(int(st.erfolg_geld))],
		["Zu Fuß unterwegs", "%.1f km" % (float(st.gelaufen) / 1000.0)],
		["Boosts gekauft", str(int(st.boosts))],
		["Casino-Runden · Bilanz", "%d · %s%s €" % [int(st.casino_spiele), "+" if int(st.casino_bilanz) >= 0 else "−", Hud.punkte(absi(int(st.casino_bilanz)))]],
		["Arcade-Spiele · Gewinne", "%d · %d" % [int(st.arcade_spiele), int(st.arcade_gewinne)]],
		["Gegenstände im Penthouse", "%d (davon %d aufgestellt)" % [wirtschaft.moebel.size(), wirtschaft.moebel.filter(func(m): return m.steht).size()]],
	]
	var rekorde := [
		["Höchste Höhe", "%d m" % int(st.hoechste)],
		["Meiste Fenster in einer Minute", str(int(st.rekord_minute))],
		["Größter Casino-Gewinn", "%s €" % Hud.punkte(int(st.casino_rekord))],
		["Längste Spielrunde", zeit_text(float(st.sitzung_rekord))],
	]
	for gruppe in [["ALLGEMEIN", zeilen], ["REKORDE", rekorde]]:
		liste.add_child(UiGlas.ueberschrift(gruppe[0]))
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiGlas.box(UiGlas.KARTE, UiGlas.KARTE_RAND, 10, 14))
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 30)
		g.add_theme_constant_override("v_separation", 4)
		p.add_child(g)
		for z in gruppe[1]:
			var a := UiGlas.text(z[0], 15, UiGlas.TEXT_LEISE)
			a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(a)
			var b := UiGlas.text(z[1], 15, UiGlas.GELD if gruppe[0] == "REKORDE" else UiGlas.TEXT, true)
			b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			g.add_child(b)
		liste.add_child(p)
