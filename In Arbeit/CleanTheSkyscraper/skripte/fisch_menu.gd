class_name FischMenu
extends CanvasLayer
# Fischladen am Steg (Stil „Glas modern“): Reiter „Fische verkaufen“ (je Art oder alles) und „Angeln“ (drei Stufen).
# Knopf-Namen für Tests/Bot: reiter_0/1, verkauf_<id>, verkauf_alle, angel_<id>.

signal geaendert

var wirtschaft: Wirtschaft
var liste: VBoxContainer
var scroll: ScrollContainer
var titel: Label
var geld_label: Label
var unter: Label
var reiter_leiste: HBoxContainer
var reiter := 0
var offen := false

func setup(w: Wirtschaft) -> void:
	wirtschaft = w
	layer = 10
	var vb: VBoxContainer = UiGlas.fenster(self, 760)[1]
	var kopf := HBoxContainer.new()
	vb.add_child(kopf)
	titel = UiGlas.text("Fischladen", 26, UiGlas.TEXT, true)
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
	scroll.custom_minimum_size = Vector2(0, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	liste = VBoxContainer.new()
	liste.add_theme_constant_override("separation", 8)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(liste)
	vb.add_child(UiGlas.text("E oder Esc: schließen · B: Fisch-Index im Album", 13, UiGlas.TEXT_LEISE))
	visible = false

func oeffnen() -> void:
	# ohne Angel zuerst der Angel-Reiter, sonst Verkaufen
	reiter = 1 if wirtschaft.angel() == "" else 0
	offen = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	aufbauen()

func schliessen() -> void:
	offen = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _leeren(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)   # sofort raus, damit neue Knöpfe ihre Namen behalten
		c.queue_free()

func aufbauen() -> void:
	_leeren(liste)
	_leeren(reiter_leiste)
	geld_label.text = "%s €" % Hud.punkte(wirtschaft.geld)
	var namen := ["Fische verkaufen (%d)" % wirtschaft.fische_in_kiste(), "Angeln"]
	for i in namen.size():
		var b := UiGlas.reiter(namen[i], i == reiter)
		b.name = "reiter_%d" % i
		b.pressed.connect(func():
			reiter = i
			aufbauen())
		reiter_leiste.add_child(b)
	if reiter == 0:
		_verkaufen()
	else:
		_angeln()

func _verkaufen() -> void:
	var boost := wirtschaft.boost_wirkung("fischpreis")
	unter.text = "JE SELTENER, DESTO MEHR GELD · PREISE STEIGEN MIT DEINER HÖHE" + (" · TEQUILA SUNRISE: +%d %%" % int(boost * 100) if boost > 0.0 else "")
	var summe := 0
	for f in Wirtschaft.FISCHE:
		summe += int(wirtschaft.fischkiste.get(f.id, 0)) * wirtschaft.fisch_preis(f.id)
	var alle := UiGlas.knopf("Alles verkaufen: %s €" % Hud.punkte(summe))
	alle.name = "verkauf_alle"
	alle.disabled = summe <= 0
	alle.custom_minimum_size = Vector2(300, 42)
	alle.pressed.connect(func():
		wirtschaft.verkaufe_alle_fische()
		geaendert.emit()
		aufbauen())
	liste.add_child(alle)
	var leer := true
	for f in Wirtschaft.FISCHE:
		var n := int(wirtschaft.fischkiste.get(f.id, 0))
		if n <= 0:
			continue
		leer = false
		var p := wirtschaft.fisch_preis(f.id)
		var k := UiGlas.knopf("%d × %s €" % [n, Hud.punkte(p)])
		k.name = "verkauf_" + str(f.id)
		k.pressed.connect(func():
			wirtschaft.verkaufe_fisch(str(f.id))
			geaendert.emit()
			aufbauen())
		var info := "%s · gefangen bis %s" % [str(f.text), Fische.laenge_text(float(wirtschaft.fisch_index.get(f.id, {}).get("max", f.groesse)))]
		liste.add_child(UiGlas.karte(str(f.name), info, k, "F", Color("35c8ff"), -1, 0, Symbole.bilder.get("f_" + str(f.id))))
	if leer:
		var t := UiGlas.text("Deine Fischkiste ist leer. Am Steg oder am Strand Richtung Wasser schauen und klicken, um die Angel auszuwerfen.", 15, UiGlas.TEXT_LEISE)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(680, 0)
		liste.add_child(t)

func _angeln() -> void:
	unter.text = "DIE BESTE GEKAUFTE ANGEL NIMMST DU AUTOMATISCH · FISCH-INDEX: %d / %d" % [wirtschaft.fisch_index.size(), Wirtschaft.FISCHE.size()]
	var beste := wirtschaft.angel()
	for a in Wirtschaft.ANGELN:
		var k: Button
		if a.id == beste:
			k = UiGlas.knopf("In der Hand", "besitz")
			k.disabled = true
		elif a.id in wirtschaft.angeln:
			k = UiGlas.knopf("Gekauft", "besitz")
			k.disabled = true
		else:
			k = UiGlas.knopf("%s €" % Hud.punkte(int(a.preis)))
			k.disabled = wirtschaft.geld < int(a.preis)
			k.pressed.connect(func():
				wirtschaft.kaufe_angel(str(a.id))
				geaendert.emit()
				aufbauen())
		k.name = "angel_" + str(a.id)
		var info := "%s Fangkasten %d %%." % [str(a.text), int(float(a.kasten) * 100)]
		liste.add_child(UiGlas.karte(str(a.name), info, k, {"bambus": "BA", "carbon": "CA", "hochsee": "HS"}[a.id], Color({"bambus": "c9a258", "carbon": "3a3d44", "hochsee": "35c8ff"}[a.id]), -1, 0, Symbole.bilder.get("a_" + str(a.id))))
	var hilfe := UiGlas.text("So geht Angeln: Am Steg (oder unten am Wasser) Richtung Meer schauen und klicken. Wenn ein Fisch beißt, erscheint der Spannungsbalken: Maustaste gedrückt halten hebt den grünen Kasten, loslassen lässt ihn sinken. Halte den Fisch im Kasten, bis der Balken rechts voll ist. Seltene Fische zappeln wilder. Für alle 20 Fische im Index gibt es eine eigene Yacht!", 14, UiGlas.TEXT_LEISE)
	hilfe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hilfe.custom_minimum_size = Vector2(680, 0)
	liste.add_child(hilfe)
