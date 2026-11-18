class_name Laeden
extends Node3D
# Vier begehbare Läden rund um den Platz, je im Erdgeschoss eines eigenen Hochhauses (Grundstücke Welt.LAEDEN):
#   Möbelhaus (Ausstellungsräume, E am Möbelstück = ansehen + kaufen), Gondel-Werkstatt (Vorführ-Gondel zeigt deine
#   Ausstattung), Souvenirshop (Andenken für Meilensteine) und Goldschmuck-Laden (neben dem Casino, Gold-Deko).
# Jeder Laden: Node3D am Grundstück, gedreht in 90°-Schritten, damit die Tür (lokal −X) zum Turm zeigt.
# Kollision zu Fuß: rechtecke (Welt). Stationen: {art "laden", menue, id, name, hinweis, pos, ziel} → Extras.

const WAND := 0.4
const SICHT := 65.0      # Innenräume nur zeichnen, wenn die Kamera so nah ist (Abstand zur Laden-Mitte)
const DATEN := {
	"moebel": {"name": "Möbelhaus", "schild": "MÖBELHAUS", "halb": 18.0, "hoch": 5.5, "tuer": 4.0, "stock": 18, "farbe": "ffb03a", "innen": "efe9df", "boden": "d8cdbb", "fassade": 0},
	"werkstatt": {"name": "Gondel-Werkstatt", "schild": "GONDEL-WERKSTATT", "halb": 13.0, "hoch": 6.5, "tuer": 7.0, "stock": 14, "farbe": "35c8ff", "innen": "d9dde2", "boden": "8a9098", "fassade": 2},
	"souvenir": {"name": "Souvenirshop", "schild": "SOUVENIRS", "halb": 11.0, "hoch": 4.5, "tuer": 3.0, "stock": 22, "farbe": "ff9ad5", "innen": "f6efe4", "boden": "b98b5e", "fassade": 1},
	"gold": {"name": "Goldschmuck", "schild": "GOLD & SCHMUCK", "halb": 10.0, "hoch": 5.0, "tuer": 3.0, "stock": 26, "farbe": "e8b53a", "innen": "1b1e2a", "boden": "15161c", "fassade": 2},
}

var laeden := {}             # ID -> {knoten, innen, mitte, dreh, halb, eingang}
var rechtecke: Array = []    # Rect2 (Welt) für die Kollision zu Fuß
var stationen: Array = []
var bloecke: Array = []      # [Rect2, Höhe] (Jetpack)
var wirtschaft: Wirtschaft
var vorfuehr_mat: StandardMaterial3D
var vorfuehr_deko: Node3D
var _souvenir_knoten: Node3D
var _gold_knoten: Node3D
var _funkeln: Array = []     # Glitzer im Schaufenster (Material + Phase)
var _zubehoer := []
var _lack := ""
var _gesperrt := {}          # Souvenir-ID -> gesperrt (beim letzten Aufbau)

func setup(welt: Welt, w: Wirtschaft) -> void:
	wirtschaft = w
	for l in Welt.LAEDEN:
		_haus(l.id, welt.laden_rects[l.id])
	_moebelhaus()
	_werkstatt()
	_souvenirshop()
	_goldladen()
	LadenDeko.schmuecken(self)   # Markisen, Leute, Bodenmuster, Details je Laden
	# Feste Bauteile zu wenigen Meshes zusammenfassen (sonst tausende Zeichenaufrufe: Markisenstreifen, Lichterketten …)
	for id in laeden:
		var innen: Node3D = laeden[id].innen
		RaumBau.verschmelzen(laeden[id].knoten, [innen])
		RaumBau.verschmelzen(innen, [_souvenir_knoten, _gold_knoten, vorfuehr_deko.get_parent()])
	aktualisieren()

# ---------------------------------------------------------------- Koordinaten
# lokal (x, z) im Laden → Welt (x, z)
func wp(id: String, x: float, z: float) -> Vector2:
	var l: Dictionary = laeden[id]
	var a: float = l.dreh
	return l.mitte + Vector2(x * cos(a) + z * sin(a), -x * sin(a) + z * cos(a))

func _fest(id: String, x0: float, z0: float, x1: float, z1: float) -> void:
	var a := wp(id, x0, z0)
	var b := wp(id, x1, z1)
	rechtecke.append(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs()))

func _station(id: String, menue: String, art_id: String, name: String, hinweis: String, steh: Vector2, blick: Vector2) -> void:
	stationen.append({"art": "laden", "laden": id, "menue": menue, "id": art_id, "name": name, "hinweis": hinweis,
		"pos": wp(id, steh.x, steh.y), "ziel": wp(id, blick.x, blick.y)})

func drinnen(id: String, p: Vector2) -> bool:
	var l: Dictionary = laeden[id]
	var q: Vector2 = p - l.mitte
	var a: float = -l.dreh
	var lok := Vector2(q.x * cos(a) + q.y * sin(a), -q.x * sin(a) + q.y * cos(a))
	return absf(lok.x) < l.halb and absf(lok.y) < l.halb

func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var c := Vector2(cam.global_position.x, cam.global_position.z)
		for id in laeden:
			(laeden[id].innen as Node3D).visible = c.distance_to(laeden[id].mitte) < SICHT and cam.global_position.y < 30.0
	var t := Time.get_ticks_msec() * 0.001
	for f in _funkeln:
		(f[0] as StandardMaterial3D).emission_energy_multiplier = maxf(0.0, sin(t * f[1] + f[2])) * 6.0

# ---------------------------------------------------------------- Gebäude (gemeinsam)
func _haus(id: String, grund: Rect2) -> void:
	var d: Dictionary = DATEN[id]
	var mitte := grund.get_center()
	# Tür (lokal −X) zeigt zur Turmseite: 90°-Schritt, dessen −X am besten zur Turmmitte weist
	var zum_turm := -mitte.normalized()
	var beste := 0.0
	var best_dot := -2.0
	for k in 4:
		var a := k * PI * 0.5
		var minus_x := Vector2(-cos(a), sin(a))
		if minus_x.dot(zum_turm) > best_dot:
			best_dot = minus_x.dot(zum_turm)
			beste = a
	var haus := Node3D.new()
	haus.position = Vector3(mitte.x, 0, mitte.y)
	haus.rotation.y = beste
	add_child(haus)
	var innen := Node3D.new()
	haus.add_child(innen)
	var h: float = d.halb
	laeden[id] = {"knoten": haus, "innen": innen, "mitte": mitte, "dreh": beste, "halb": h, "eingang": Vector2.ZERO}
	laeden[id].eingang = wp(id, -h - 5.0, 0.0)
	var hoch: float = d.hoch
	var tuer: float = d.tuer
	var tuer_h := minf(3.4, hoch - 1.0)
	var stein := Bau.matt("e9e2d4" if id != "gold" else "23252e", 0.55)
	var innen_mat := Bau.matt(d.innen, 0.75)
	var akzent := Bau.metall(d.farbe, 0.3, 0.6) if id != "gold" else Andenken.gold()
	var mw := h - WAND * 0.5
	# Rückwand + Seiten: große Fenster (man sieht von überall hinein); nur die Werkstatt hat hinten ihre Werkzeugwand
	var glas := RaumBau.glas("cfe8ff", 0.16)
	var fenster_oben := minf(tuer_h, hoch - 1.2)
	if id == "werkstatt" or id == "gold":   # Werkstatt: Werkzeugwand, Gold: Spiegelwand
		RaumBau.box(haus, Vector3(WAND, hoch, h * 2.0), Vector3(mw, hoch * 0.5, 0), stein)
		RaumBau.box(innen, Vector3(0.02, hoch, h * 2.0 - 0.8), Vector3(mw - WAND * 0.5 - 0.01, hoch * 0.5, 0), innen_mat)
	else:
		_glaswand(haus, Vector3(mw, 0, 0), 0.0, h * 2.0, hoch, fenster_oben, stein, glas)
	_fest(id, h - WAND, -h, h, h)
	for s in [-1.0, 1.0]:
		_glaswand(haus, Vector3(0, 0, s * mw), PI * 0.5, h * 2.0, hoch, fenster_oben, stein, glas)
		_fest(id, -h, s * mw - WAND * 0.5, h, s * mw + WAND * 0.5)
	# Vorderseite: Tür in der Mitte, daneben große Schaufenster mit Brüstung, darüber das Schild-Band
	for s in [-1.0, 1.0]:
		var z0 := tuer * 0.5
		var lang := h - z0
		var zm: float = s * (z0 + lang * 0.5)
		RaumBau.box(haus, Vector3(WAND, 0.5, lang), Vector3(-mw, 0.25, zm), stein)                      # Brüstung
		RaumBau.box(haus, Vector3(0.06, tuer_h - 0.5, lang - 0.6), Vector3(-mw, 0.5 + (tuer_h - 0.5) * 0.5, zm), glas)
		for zp in [z0 + 0.15, h - 0.3, z0 + lang * 0.5]:                                                 # Pfosten
			RaumBau.box(haus, Vector3(WAND + 0.04, tuer_h, 0.3), Vector3(-mw, tuer_h * 0.5, s * zp), stein if zp != z0 + lang * 0.5 else akzent)
		_fest(id, -h, minf(s * z0, s * h), -h + WAND, maxf(s * z0, s * h))
	RaumBau.box(haus, Vector3(WAND, hoch - tuer_h, h * 2.0), Vector3(-mw, tuer_h + (hoch - tuer_h) * 0.5, 0), stein)
	RaumBau.box(haus, Vector3(WAND + 0.1, 0.12, tuer + 0.3), Vector3(-mw, tuer_h, 0), akzent)               # Türsturz
	# Decke + Dach, darüber das Hochhaus
	var poly := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	RaumBau.flaeche(innen, poly, hoch - 0.02, Bau.matt("f4f2ee" if id != "gold" else "121318", 0.9), false)
	RaumBau.box(haus, Vector3(h * 2.0 + 0.6, 0.3, h * 2.0 + 0.6), Vector3(0, hoch + 0.15, 0), stein)
	for s in [-1.0, 1.0]:   # Zierleiste rundum unter dem Dach (nur außen)
		RaumBau.box(haus, Vector3(h * 2.0 + 0.7, 0.1, 0.35), Vector3(0, hoch - 0.05, s * (h + 0.17)), akzent)
		RaumBau.box(haus, Vector3(0.35, 0.1, h * 2.0 + 0.7), Vector3(s * (h + 0.17), hoch - 0.05, 0), akzent)
	for s in [-1.0, 1.0]:   # Sockel außen rundum (nicht durch den Innenraum)
		RaumBau.box(haus, Vector3(h * 2.0 + 0.4, 0.2, 0.22), Vector3(0, 0.1, s * (h + 0.09)), Bau.matt("8a8378", 0.7))
		RaumBau.box(haus, Vector3(0.22, 0.2, h * 2.0 + 0.4), Vector3(s * (h + 0.09), 0.1, 0), Bau.matt("8a8378", 0.7))
	var stw := []
	var turm_poly := Bau.rechteck(h * 2.0 + 0.12, h * 2.0 + 0.12)
	for k in int(d.stock):
		stw.append({"poly": turm_poly, "y0": hoch + 0.3 + k * 3.5, "h": 3.5})
	haus.add_child(Bau.baue(stw, _fassade(int(d.fassade)), Bau.matt("bdb3a3")))
	bloecke.append([grund, hoch + 0.3 + int(d.stock) * 3.5])
	# Vordach mit Lichtern + Leuchtschild über dem Eingang
	var vd := tuer + 3.0
	RaumBau.box(haus, Vector3(3.0, 0.22, vd), Vector3(-h - 1.5, tuer_h + 0.4, 0), stein)
	RaumBau.box(haus, Vector3(3.1, 0.07, vd + 0.1), Vector3(-h - 1.5, tuer_h + 0.26, 0), akzent)
	var warm := RaumBau.leuchte("ffe2a0", 2.5)
	for k in int(vd / 1.4):
		RaumBau.box(haus, Vector3(0.28, 0.04, 0.28), Vector3(-h - 1.5, tuer_h + 0.21, -vd * 0.5 + 0.7 + k * 1.4), warm)
	var band_y := tuer_h + (hoch - tuer_h) * 0.55 + 0.2
	var breite := minf(h * 2.0 - 2.0, 2.2 + d.schild.length() * 0.95)
	RaumBau.box(haus, Vector3(0.12, 1.3, breite), Vector3(-h - 0.14, band_y, 0), Bau.matt("1b1e2a", 0.4))
	var schild := RaumBau.schrift(haus, d.schild, Vector3(-h - 0.22, band_y, 0), -PI / 2.0, 160, 0.0072, Color(d.farbe))
	schild.modulate = Color(d.farbe) * 1.6
	# Schild auch an der Seite zum Platz (beide Seiten), kleiner
	for s in [-1.0, 1.0]:
		RaumBau.box(haus, Vector3(h * 1.2, 0.9, 0.1), Vector3(0, hoch - 0.75, s * (h + 0.12)), Bau.matt("1b1e2a", 0.4))
		var l2 := RaumBau.schrift(haus, d.schild, Vector3(0, hoch - 0.75, s * (h + 0.19)), 0.0 if s > 0 else PI, 120, 0.0062, Color(d.farbe))
		l2.modulate = Color(d.farbe) * 1.5
	# Innenboden
	var bm := StandardMaterial3D.new()
	bm.albedo_texture = LadenDeko.boden(id)
	bm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	bm.roughness = 0.35 if id in ["gold", "werkstatt"] else 0.7
	bm.metallic = 0.2 if id == "gold" else 0.0
	RaumBau.flaeche(innen, poly, 0.06, bm, true, 0.25)
	# Pflanzkübel neben der Tür
	for s in [-1.0, 1.0]:
		RaumBau.box(haus, Vector3(1.0, 0.8, 1.0), Vector3(-h - 0.9, 0.4, s * (tuer * 0.5 + 1.6)), Bau.matt("2a2d38", 0.5))
		RaumBau.modell(haus, "natur/plant_bushLarge", Vector3(-h - 0.9, 0.8, s * (tuer * 0.5 + 1.6)), 1.1)
		_fest(id, -h - 1.4, s * (tuer * 0.5 + 1.6) - 0.5, -h - 0.4, s * (tuer * 0.5 + 1.6) + 0.5)

# Wand mit Brüstung, durchgehendem Fensterband (Pfosten etwa alle 3,5 m) und Steinband darüber.
# Lokal verläuft die Wand entlang z (wie die Vorderseite); dreh = PI/2 für die Seiten.
func _glaswand(haus: Node3D, p: Vector3, dreh: float, lang: float, hoch: float, oben: float, stein: Material, glas: Material) -> void:
	var w := Node3D.new()
	w.position = p
	w.rotation.y = dreh
	haus.add_child(w)
	RaumBau.box(w, Vector3(WAND, 0.5, lang), Vector3(0, 0.25, 0), stein)
	RaumBau.box(w, Vector3(WAND, hoch - oben, lang), Vector3(0, oben + (hoch - oben) * 0.5, 0), stein)
	RaumBau.box(w, Vector3(0.06, oben - 0.5, lang - 0.4), Vector3(0, 0.5 + (oben - 0.5) * 0.5, 0), glas)
	var n := maxi(1, ceili((lang - 0.3) / 3.5))
	for k in n + 1:
		var z := -lang * 0.5 + 0.15 + k * (lang - 0.3) / n
		RaumBau.box(w, Vector3(WAND + 0.04, oben, 0.3), Vector3(0, oben * 0.5, z), stein)

func _fassade(art: int) -> ShaderMaterial:
	var p: Dictionary = [
		{"glas": Color("6d8aa3"), "rahmen": Color("e6dccb"), "bruestung": Color("d8c9b0"), "stock": 3.5, "fenster_breite": 2.2, "dreckig": 0.0, "band_anteil": 0.35, "metall": 0.4},
		{"glas": Color("5c7f8f"), "rahmen": Color("c9b79a"), "bruestung": Color("bba78a"), "stock": 3.5, "fenster_breite": 2.6, "dreckig": 0.0, "band_anteil": 0.4, "metall": 0.3},
		{"glas": Color("8fb1c9"), "rahmen": Color("9aa3ad"), "bruestung": Color("8a929c"), "stock": 3.5, "fenster_breite": 1.8, "dreckig": 0.0, "metall": 0.7},
	][art]
	return Bau.shader_mat(Bau.FASSADE_SHADER, p)

func _innen(id: String) -> Node3D:
	return laeden[id].innen

# Kenney-Figur hinter einer Theke (schaut nach −X, also zur Tür)
func _figur(id: String, modell: String, p: Vector2) -> void:
	RaumBau.box(_innen(id), Vector3(0.7, 0.06, 0.7), Vector3(p.x, 0.09, p.y), Bau.matt("2b2f36", 0.5))
	RaumBau.modell(_innen(id), "leute/" + modell, Vector3(p.x, 0.12, p.y), Haendler.MINI, -PI / 2.0)

func _theke(id: String, p: Vector2, laenge: float, mat: Material, oben: Material) -> void:
	RaumBau.box(_innen(id), Vector3(0.8, 1.05, laenge), Vector3(p.x, 0.525, p.y), mat)
	RaumBau.box(_innen(id), Vector3(0.9, 0.05, laenge + 0.1), Vector3(p.x, 1.075, p.y), oben)
	_fest(id, p.x - 0.4, p.y - laenge * 0.5, p.x + 0.4, p.y + laenge * 0.5)

# Preisschild über einem Ausstellungsstück (dreht sich zur Kamera)
func _schild(eltern: Node3D, t: String, p: Vector3, farbe := Color(1, 1, 1)) -> Label3D:
	var l := RaumBau.schrift(eltern, t, p, 0.0, 40, 0.006, farbe, false)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.7)
	return l

# ---------------------------------------------------------------- Möbelhaus
const MH_GANG := 3.0          # halbe Breite des Mittelgangs
const MH_PLAN := 2.1          # MH_EINRICHTUNG wurde für Moebel.MASS = 2,1 geplant; größere Möbel → Abstände mitwachsen
const MH_TIEFE := 11.0 * Moebel.MASS / MH_PLAN   # Tiefe der Ausstellungsräume (dahinter bis zur Außenwand: Lager)
const MH_RAEUME := [[-12.5, -2.9], [-2.7, 7.1], [7.3, 17.6]]   # x-Bereiche der drei Räume je Seite

func _moebelhaus() -> void:
	var id := "moebel"
	var n := _innen(id)
	var h: float = DATEN[id].halb
	var innen_w := h - WAND
	var trenn := Bau.matt("f7f4ee", 0.7)
	var leiste := Bau.metall("ffb03a", 0.3, 0.6)
	var raeume: Array = Wirtschaft.MOEBELHAUS_RAEUME
	for seite in [1.0, -1.0]:
		for k in 3:
			var r: Dictionary = raeume[k if seite > 0.0 else k + 3]
			var x0: float = MH_RAEUME[k][0]
			var x1: float = minf(MH_RAEUME[k][1], innen_w)
			# Trennwand links (zum Foyer bzw. zum Nachbarraum), 2,8 m hoch
			var zw0: float = seite * MH_GANG
			var zw1: float = seite * (MH_GANG + MH_TIEFE)
			RaumBau.box(n, Vector3(0.2, 2.8, MH_TIEFE), Vector3(x0 - 0.1, 1.4, (zw0 + zw1) * 0.5), trenn)
			RaumBau.box(n, Vector3(0.24, 0.08, MH_TIEFE), Vector3(x0 - 0.1, 2.84, (zw0 + zw1) * 0.5), leiste)
			# Rückwand des Raums; dahinter Lager mit Kartons (sieht man von außen durchs Fenster)
			RaumBau.box(n, Vector3(x1 - x0 + 0.2, 2.8, 0.2), Vector3((x0 + x1) * 0.5 - 0.1, 1.4, zw1 + seite * 0.1), trenn)
			RaumBau.box(n, Vector3(x1 - x0 + 0.24, 0.08, 0.24), Vector3((x0 + x1) * 0.5 - 0.1, 2.84, zw1 + seite * 0.1), leiste)
			_fest(id, x0 - 0.2, minf(zw1, zw1 + seite * 0.2), x1, maxf(zw1, zw1 + seite * 0.2))
			for kk in 3:
				var kx := lerpf(x0 + 1.2, x1 - 1.2, kk / 2.0)
				for st in 2 + (kk % 2):
					RaumBau.modell(n, "moebel/cardboardBoxClosed", Vector3(kx, 0.06 + st * 0.5, seite * (innen_w - 0.65)), Moebel.MASS, kk * 0.4)
			_fest(id, x0 - 0.2, minf(zw0, zw1), x0, maxf(zw0, zw1))
			# Boden des Raums in seiner Farbe
			var fl := PackedVector2Array([Vector2(x0, zw0), Vector2(x1, zw0), Vector2(x1, zw1), Vector2(x0, zw1)])
			if seite < 0.0:
				fl.reverse()
			RaumBau.flaeche(n, fl, 0.075, Bau.matt(r.farbe, 0.6), true)
			# Raum-Schild über dem Eingang zum Gang
			var sl := RaumBau.schrift(n, r.name, Vector3((x0 + x1) * 0.5, 3.4, seite * (MH_GANG + 0.05)), PI if seite > 0.0 else 0.0, 90, 0.006, Color("2b2d33"))
			sl.modulate = Color("3a3d44")
			RaumBau.box(n, Vector3(minf(x1 - x0 - 1.0, 6.0), 0.06, 0.06), Vector3((x0 + x1) * 0.5, 2.95, seite * (MH_GANG + 0.05)), leiste)
			RaumBau.licht(n, Vector3((x0 + x1) * 0.5, 4.2, seite * (MH_GANG + MH_TIEFE * 0.5)), "fff0dc", 1.3, 11.0)
			_raum_moebel(r.id, x0, x1, seite)
	# Gang: Lichter + Info-Terminal im Foyer
	for k in 2:
		RaumBau.licht(n, Vector3(-10.0 + k * 18.0, 4.6, 0), "fff6e6", 1.0, 12.0)
	var tp := Vector2(-14.8, 7.0)
	RaumBau.box(n, Vector3(0.6, 0.08, 0.6), Vector3(tp.x, 0.1, tp.y), Bau.matt("2b2f36", 0.4))
	RaumBau.zyl(n, 0.05, 1.1, Vector3(tp.x, 0.65, tp.y), Bau.metall("c9ced4", 0.25, 0.85), 10)
	var schirm := RaumBau.box(n, Vector3(0.06, 0.5, 0.7), Vector3(tp.x, 1.3, tp.y - 0.05), RaumBau.leuchte("ffb03a", 1.2))
	schirm.rotation.x = 0.5
	_fest(id, tp.x - 0.35, tp.y - 0.35, tp.x + 0.35, tp.y + 0.35)
	_station(id, "moebelhaus", "", "Möbelhaus", "E: Möbelhaus-Katalog (alle Räume)", Vector2(tp.x, tp.y - 1.4), tp)
	var w := RaumBau.schrift(n, "Willkommen! Möbel ansehen: davor stellen und E drücken", Vector3(h - WAND - 0.05, 3.6, 0), -PI / 2.0, 60, 0.006, Color("3a3d44"), false)
	w.modulate = Color("3a3d44")

# Einrichtung der Ausstellungsräume wie echte Zimmer. Raum-Koordinaten (für die Räume auf der −z-Seite):
# u = Meter ab der linken Trennwand, v = Meter vom Gang zur Außenwand (Raum ~9,6 × 14,6 m), r = Drehung in Grad
# (0 = Vorderseite zum Gang). Auf der +z-Seite wird gespiegelt. g = Möbel zum Kaufen, d = Deko (Kenney-Möbel),
# bild/lampe = Deko aus Code. y = Höhe (z. B. Fernseher auf dem TV-Schrank).
const MH_EINRICHTUNG := {
	"wohnen": [
		{"g": "tv_schrank", "u": 4.8, "v": 10.5, "r": 0}, {"g": "fernseher", "u": 4.8, "v": 10.55, "r": 0, "y": 0.65},
		{"d": "speakerSmall", "u": 3.4, "v": 10.65, "r": 0}, {"d": "speakerSmall", "u": 6.2, "v": 10.65, "r": 0},
		{"g": "teppich", "u": 4.8, "v": 7.15, "r": 0}, {"g": "couchtisch", "u": 4.8, "v": 7.15, "r": 0},
		{"g": "sofa_lang", "u": 4.8, "v": 5.05, "r": 180}, {"g": "sessel", "u": 2.3, "v": 7.25, "r": 90},
		{"g": "sofa_ecke", "u": 8.1, "v": 8.45, "r": 270}, {"g": "beistelltisch", "u": 7.0, "v": 5.05, "r": 180},
		{"d": "lampRoundTable", "u": 7.3, "v": 5.05, "r": 0, "y": 0.81}, {"g": "sofa", "u": 0.95, "v": 1.95, "r": 90},
		{"d": "pottedPlant", "u": 0.6, "v": 10.55, "r": 0}, {"bild": 0, "u": 0.0, "v": 6.15}, {"lampe": 0, "u": 4.8, "v": 7.15},
	],
	"schlafen": [
		{"g": "bett", "u": 4.8, "v": 9.85, "r": 0}, {"g": "nachttisch", "u": 3.2, "v": 10.75, "r": 0},
		{"d": "cabinetBedDrawerTable", "u": 6.4, "v": 10.75, "r": 0}, {"d": "lampRoundTable", "u": 3.2, "v": 10.75, "r": 0, "y": 0.55},
		{"d": "lampRoundTable", "u": 6.4, "v": 10.75, "r": 0, "y": 0.55}, {"d": "rugRectangle", "u": 4.8, "v": 7.15, "r": 90, "s": 1.0},
		{"d": "benchCushionLow", "u": 4.8, "v": 8.15, "r": 0}, {"g": "kleiderschrank", "u": 0.35, "v": 7.05, "r": 90},
		{"g": "etagenbett", "u": 9.0, "v": 4.55, "r": 0}, {"g": "einzelbett", "u": 9.0, "v": 1.45, "r": 0},
		{"d": "pottedPlant", "u": 0.6, "v": 10.55, "r": 0}, {"bild": 1, "u": 0.0, "v": 9.55}, {"lampe": 1, "u": 4.8, "v": 7.55},
	],
	"kueche": [
		{"g": "kueche", "u": 0.65, "v": 10.6, "r": 0}, {"g": "herd", "u": 2.35, "v": 10.63, "r": 0},
		{"g": "spuele", "u": 3.25, "v": 10.63, "r": 0}, {"d": "kitchenCabinet", "u": 4.15, "v": 10.63, "r": 0},
		{"d": "kitchenCabinet", "u": 5.05, "v": 10.63, "r": 0}, {"d": "kitchenMicrowave", "u": 4.15, "v": 10.65, "r": 0, "y": 0.94},
		{"d": "kitchenCoffeeMachine", "u": 5.05, "v": 10.65, "r": 0, "y": 0.94},
		{"g": "kuechenbar", "u": 3.0, "v": 7.75, "r": 180}, {"g": "bar_hocker", "u": 2.6, "v": 6.95, "r": 180},
		{"d": "stoolBar", "u": 3.4, "v": 6.95, "r": 180},
		{"g": "esstisch", "u": 7.4, "v": 8.15, "r": 0}, {"g": "stuhl", "u": 7.0, "v": 7.25, "r": 180},
		{"d": "chairCushion", "u": 7.8, "v": 7.25, "r": 180}, {"d": "chairCushion", "u": 7.0, "v": 9.05, "r": 0}, {"d": "chairCushion", "u": 7.8, "v": 9.05, "r": 0},
		{"d": "rugRectangle", "u": 4.8, "v": 2.95, "r": 0}, {"g": "glastisch", "u": 4.8, "v": 2.95, "r": 0},
		{"g": "designstuhl", "u": 4.4, "v": 2.05, "r": 180}, {"d": "chairModernFrameCushion", "u": 5.2, "v": 2.05, "r": 180},
		{"d": "chairModernFrameCushion", "u": 4.4, "v": 3.85, "r": 0}, {"d": "chairModernFrameCushion", "u": 5.2, "v": 3.85, "r": 0},
		{"bild": 2, "u": 0.0, "v": 5.55}, {"lampe": 2, "u": 4.8, "v": 2.95}, {"lampe": 2, "u": 7.4, "v": 8.15},
	],
	"bad": [
		{"g": "badewanne", "u": 2.0, "v": 10.45, "r": 0}, {"d": "rugDoormat", "u": 2.0, "v": 9.25, "r": 0},
		{"g": "dusche", "u": 8.8, "v": 10.45, "r": 0}, {"g": "waschbecken", "u": 0.4, "v": 6.05, "r": 90},
		{"d": "bathroomMirror", "u": 0.15, "v": 6.05, "r": 90, "y": 1.25}, {"g": "toilette", "u": 0.5, "v": 3.55, "r": 90},
		{"g": "waschturm", "u": 9.1, "v": 6.05, "r": 270}, {"d": "rugRound", "u": 4.8, "v": 6.05, "r": 0},
		{"d": "pottedPlant", "u": 5.6, "v": 10.65, "r": 0}, {"d": "bathroomCabinetDrawer", "u": 9.2, "v": 7.95, "r": 270},
		{"lampe": 3, "u": 4.8, "v": 6.05},
	],
	"buero": [
		{"g": "eckschreibtisch", "u": 1.2, "v": 9.95, "r": 0}, {"d": "computerScreen", "u": 0.9, "v": 10.55, "r": 0, "y": 0.81},
		{"d": "chairDesk", "u": 1.7, "v": 8.5, "r": 180},
		{"g": "schreibtisch", "u": 6.0, "v": 10.5, "r": 0}, {"d": "laptop", "u": 6.0, "v": 10.55, "r": 0, "y": 0.81},
		{"g": "buerostuhl", "u": 6.0, "v": 9.35, "r": 180}, {"g": "regal", "u": 9.3, "v": 6.55, "r": 270},
		{"g": "aktenschrank", "u": 0.3, "v": 5.05, "r": 90}, {"d": "rugRectangle", "u": 5.0, "v": 6.15, "r": 90},
		{"d": "pottedPlant", "u": 9.0, "v": 10.45, "r": 0}, {"d": "loungeChair", "u": 4.4, "v": 5.55, "r": 0},
		{"d": "sideTable", "u": 5.8, "v": 5.55, "r": 0}, {"d": "books", "u": 5.8, "v": 5.55, "r": 0, "y": 0.81},
		{"bild": 3, "u": 0.0, "v": 7.95}, {"lampe": 4, "u": 6.0, "v": 9.55},
	],
	"licht": [
		{"d": "rugRound", "u": 4.8, "v": 7.05, "r": 0}, {"g": "stehlampe", "u": 2.4, "v": 9.15, "r": 0},
		{"g": "pflanze", "u": 4.8, "v": 10.35, "r": 0}, {"g": "garderobe", "u": 7.4, "v": 9.15, "r": 0},
		{"d": "sideTable", "u": 4.8, "v": 7.05, "r": 0}, {"d": "lampRoundTable", "u": 4.3, "v": 7.05, "r": 0, "y": 0.81},
		{"d": "plantSmall2", "u": 5.3, "v": 7.05, "r": 0, "y": 0.81}, {"d": "pottedPlant", "u": 0.7, "v": 10.55, "r": 0},
		{"d": "pottedPlant", "u": 9.0, "v": 10.55, "r": 0}, {"d": "loungeChairRelax", "u": 2.2, "v": 5.55, "r": 90},
		{"d": "bench", "u": 7.6, "v": 5.55, "r": 270}, {"bild": 4, "u": 0.0, "v": 7.55},
		{"lampe": 0, "u": 3.0, "v": 7.05}, {"lampe": 1, "u": 4.8, "v": 7.05}, {"lampe": 2, "u": 6.6, "v": 7.05},
	],
}
const BILD_FARBEN := [["e9a23b", "3a86d4", "f4f2ee"], ["9fb4d6", "f4d6c8", "6d8aa3"], ["3fc29a", "ffc531", "e2483e"], ["7fd0e0", "f4f2ee", "3a86d4"], ["b36bff", "ff9ad5", "ffc531"]]
const LAMPEN_FARBEN := ["f4f2ee", "2b2d33", "e9a23b", "c9ced4", "3fc29a"]

# Möbel und Deko eines Ausstellungsraums nach MH_EINRICHTUNG aufstellen
func _raum_moebel(raum: String, x0: float, x1: float, seite: float) -> void:
	var n := _innen("moebel")
	var feste_lokal: Array = []      # Rect2 in Laden-Koordinaten (für die Standpunkte)
	var plaetze: Array = []
	var k := Moebel.MASS / MH_PLAN       # Abstände wachsen mit der Möbelgröße (u um die Raummitte, v ab dem Gang)
	var breite := x1 - x0
	for e in MH_EINRICHTUNG.get(raum, []):
		var u: float = breite * 0.5 + (float(e.u) - 4.8) * k
		var v: float = float(e.v) * k
		if e.has("bild"):
			u = float(e.u)
		elif not e.has("lampe"):   # an den Wänden halten (Größe nach der Drehung)
			var r0: float = float(e.r) if seite < 0.0 else 180.0 - float(e.r)
			var fl := Moebel.flaeche(str(e.g), r0) if e.has("g") else _deko_flaeche(str(e.d), r0, float(e.get("s", 1.0)))
			u = clampf(u, fl.x * 0.5 + 0.05, breite - fl.x * 0.5 - 0.05)
			v = clampf(v, fl.y * 0.5 + 0.05, MH_TIEFE - fl.y * 0.5 - 0.05)
		var p := Vector2(x0 + u, seite * (MH_GANG + v))
		if e.has("bild"):
			_bild(n, Vector3(x0 + 0.02, 1.75, p.y), BILD_FARBEN[int(e.bild)])
			continue
		if e.has("lampe"):
			_haengelampe(n, Vector3(p.x, 0, p.y), DATEN.moebel.hoch, LAMPEN_FARBEN[int(e.lampe)])
			continue
		var r: float = float(e.r) if seite < 0.0 else 180.0 - float(e.r)
		var y: float = float(e.get("y", 0.0)) * k
		if e.has("d"):
			var d := RaumBau.mittig(n, "moebel/" + str(e.d), Vector3(p.x, 0.08 + y, p.y), Moebel.MASS * float(e.get("s", 1.0)), deg_to_rad(r))
			if y == 0.0:
				var b := RaumBau.aabb(d)
				if b.size.y > 0.15:
					var q := Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z)).grow(-0.05)
					_fest("moebel", q.position.x, q.position.y, q.end.x, q.end.y)
					feste_lokal.append(q)
			continue
		var gid: String = e.g
		var f := Moebel.flaeche(gid, r)
		if y == 0.0 and Moebel.hoehe(gid) > 0.15:
			feste_lokal.append(Rect2(p - f * 0.5, f).grow(-0.05))
		plaetze.append([gid, p, r, y])
	# Standpunkt je Möbel: vor der Vorderseite, sonst seitlich – Hauptsache frei und im Raum
	for pl in plaetze:
		var gid: String = pl[0]
		var p: Vector2 = pl[1]
		var r: float = pl[2]
		var f := Moebel.flaeche(gid, r)
		var vorne := Vector2(sin(deg_to_rad(r)), cos(deg_to_rad(r)))
		var steh := p + Vector2(0, -seite * 2.0)
		for richtung in [vorne, vorne.orthogonal(), -vorne.orthogonal(), -vorne, Vector2(0, -seite)]:
			var weit := absf(richtung.x) * f.x * 0.5 + absf(richtung.y) * f.y * 0.5 + 0.85
			var kand: Vector2 = p + richtung * weit
			if kand.x < x0 + 0.6 or kand.x > x1 - 0.6 or absf(kand.y) > MH_GANG + MH_TIEFE - Laeufer.RADIUS - 0.05:
				continue
			var frei := true
			for q in feste_lokal:
				if (q as Rect2).grow(Laeufer.RADIUS + 0.05).has_point(kand):
					frei = false
					break
			if frei:
				steh = kand
				break
		_ausstellen(gid, p, r, steh, n, pl[3])

# Grundfläche eines Deko-Modells (gedreht), einmal gemessen
static var _deko_groesse := {}
func _deko_flaeche(name: String, dreh: float, s: float) -> Vector2:
	if not _deko_groesse.has(name):
		var t := Node3D.new()
		_deko_groesse[name] = RaumBau.aabb(RaumBau.modell(t, "moebel/" + name, Vector3.ZERO, Moebel.MASS)).size
		t.free()
	var b: Vector3 = _deko_groesse[name] * s
	var a := deg_to_rad(dreh)
	return Vector2(absf(cos(a)) * b.x + absf(sin(a)) * b.z, absf(sin(a)) * b.x + absf(cos(a)) * b.z)

# Bild an der Trennwand (schaut nach +x): Rahmen + drei Farbflächen
func _bild(n: Node3D, p: Vector3, farben: Array) -> void:
	RaumBau.box(n, Vector3(0.04, 0.8, 1.15), p + Vector3(0.02, 0, 0), Bau.matt("2b2d33", 0.5))
	RaumBau.box(n, Vector3(0.02, 0.68, 1.03), p + Vector3(0.045, 0, 0), Bau.matt(farben[2], 0.8))
	RaumBau.box(n, Vector3(0.02, 0.4, 0.45), p + Vector3(0.055, 0.08, -0.22), Bau.matt(farben[0], 0.8))
	RaumBau.box(n, Vector3(0.02, 0.3, 0.38), p + Vector3(0.06, -0.12, 0.25), Bau.matt(farben[1], 0.8))

# Pendelleuchte von der Decke (nur Deko, das Licht kommt vom Raumlicht)
func _haengelampe(n: Node3D, p: Vector3, decke: float, farbe: String) -> void:
	RaumBau.zyl(n, 0.01, decke - 2.7, Vector3(p.x, 2.7 + (decke - 2.7) * 0.5, p.z), Bau.matt("2b2d33", 0.5), 6)
	RaumBau.zyl(n, 0.08, 0.3, Vector3(p.x, 2.6, p.z), Bau.matt(farbe, 0.4), 20, 0.32)
	RaumBau.zyl(n, 0.28, 0.02, Vector3(p.x, 2.46, p.z), RaumBau.leuchte("fff0d0", 2.5), 20)

func _ausstellen(gid: String, p: Vector2, dreh: float, steh: Vector2, n: Node3D, y := 0.0) -> void:
	var id := "moebel"
	var m := Moebel.modell(gid)
	m.position = Vector3(p.x, 0.08 + y, p.y)
	m.rotation.y = deg_to_rad(dreh)
	n.add_child(m)
	var g := wirtschaft.gegenstand(gid)
	var f := Moebel.flaeche(gid, dreh)
	if y == 0.0 and Moebel.hoehe(gid) > 0.15:
		_fest(id, p.x - f.x * 0.5 + 0.05, p.y - f.y * 0.5 + 0.05, p.x + f.x * 0.5 - 0.05, p.y + f.y * 0.5 - 0.05)
	var t := "%s · %s €" % [g.name, Hud.punkte(wirtschaft.gegenstand_preis(gid))]
	var bonus := "" if not g.has("bonus") else " · +%d %%" % int(round(wirtschaft.gegenstand_bonus(gid) * 100.0))
	_schild(n, t + bonus, Vector3(p.x, y + maxf(Moebel.hoehe(gid), 0.4) + 0.45, p.y), Color("fff6e0") if not g.has("bonus") else Color(Wirtschaft.SELTEN_FARBE[wirtschaft.seltenheit(gid)]).lightened(0.3))
	_station(id, "moebelhaus", gid, g.name, "E: %s ansehen (%s €)" % [g.name, Hud.punkte(wirtschaft.gegenstand_preis(gid))], steh, p)

# ---------------------------------------------------------------- Gondel-Werkstatt
func _werkstatt() -> void:
	var id := "werkstatt"
	var n := _innen(id)
	var h: float = DATEN[id].halb
	var iw := h - WAND
	# Gelbe Sicherheitslinien um die Hebebühne
	var gelb := Bau.matt("ffc531", 0.6)
	for s in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(6.4, 0.012, 0.12), Vector3(2.0, 0.07, s * 3.0), gelb)
		RaumBau.box(n, Vector3(0.12, 0.012, 6.0), Vector3(2.0 + s * 3.2, 0.07, 0), gelb)
	# Hebebühne mit Vorführ-Gondel (Rücken mit Blumenkästen zur Tür)
	var stahl := Bau.metall("6b7078", 0.4, 0.6)
	for s in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(0.35, 1.6, 0.35), Vector3(2.0, 0.8, s * 2.4), Bau.matt("e2483e", 0.5))
		_fest(id, 1.8, s * 2.4 - 0.2, 2.2, s * 2.4 + 0.2)
	RaumBau.box(n, Vector3(1.6, 0.15, 4.6), Vector3(2.0, 0.85, 0), stahl)
	var g := Node3D.new()
	g.position = Vector3(2.0, 1.0, 0)
	g.rotation.y = -PI / 2.0
	n.add_child(g)
	vorfuehr_mat = Bau.matt("ffc531", 0.5)
	GondelDeko.rumpf(g, vorfuehr_mat, stahl, false)
	vorfuehr_deko = Node3D.new()
	g.add_child(vorfuehr_deko)
	_fest(id, 1.2, -2.0, 2.8, 2.0)
	_station(id, "werkstatt", "", "Gondel-Werkstatt", "E: Gondel gestalten (Lack, Aufkleber, Blumen, Schirm, Radio)", Vector2(-0.4, 0), Vector2(2.0, 0))
	# Theke mit Mechaniker
	var tp := Vector2(-2.0, iw - 1.6)
	_theke(id, tp, 3.0, Bau.matt("2b2f36", 0.5), Bau.metall("35c8ff", 0.3, 0.5))
	_figur(id, "character-worker", Vector2(tp.x + 1.1, tp.y))
	_station(id, "werkstatt", "", "Gondel-Werkstatt", "E: Gondel gestalten (Lack, Aufkleber, Blumen, Schirm, Radio)", Vector2(tp.x - 1.3, tp.y), tp)
	# Werkzeugwand, Regale und Lackdosen
	RaumBau.box(n, Vector3(0.05, 2.0, 6.0), Vector3(iw - 0.04, 2.0, -5.0), Bau.matt("c9a46a", 0.8))
	var farben := ["e2483e", "35c8ff", "ffc531", "3fc29a", "ff4fb8", "b36bff", "2b2d33", "f4f4f4"]
	for i in 16:
		var c := RaumBau.zyl(n, 0.07, 0.24, Vector3(iw - 0.2, 1.3 + (i / 8) * 0.6, -7.6 + (i % 8) * 0.7), Bau.matt(farben[i % 8], 0.35), 12)
		c.position.y += 0.12
	for k in 2:
		RaumBau.box(n, Vector3(0.35, 0.04, 6.0), Vector3(iw - 0.2, 1.3 + k * 0.6, -5.0), Bau.matt("6b4a32", 0.7))
	_fest(id, iw - 0.45, -8.0, iw, -2.0)
	for k in 3:
		RaumBau.modell(n, "laden/shelf-boxes", Vector3(-6.0 + k * 3.0, 0.06, -iw + 0.5), Haendler.MINI)
	_fest(id, -7.2, -iw, 1.6, -iw + 1.2)
	# Ersatzteile: Kisten + ein zweites Gondelgeländer an der Wand
	for k in 3:
		RaumBau.modell(n, "moebel/cardboardBoxClosed", Vector3(-iw + 1.0, 0.06 + k * 0.5, 10.5), Moebel.MASS)
	_fest(id, -iw, 9.9, -iw + 1.6, 11.3)
	for ix in 2:
		for iz in 2:
			RaumBau.licht(n, Vector3(-4.0 + ix * 8.0, 5.6, -5.0 + iz * 10.0), "eef4ff", 1.2, 13.0)
	for ix in 3:
		RaumBau.box(n, Vector3(0.25, 0.06, 6.0), Vector3(-6.0 + ix * 5.0, DATEN[id].hoch - 0.06, 0), RaumBau.leuchte("eef4ff", 2.0))

# ---------------------------------------------------------------- Souvenirshop
const SV_PLAETZE := 12

func _souvenirshop() -> void:
	var id := "souvenir"
	var n := _innen(id)
	var h: float = DATEN[id].halb
	var iw := h - WAND
	var tp := Vector2(-4.0, -iw + 2.0)
	_theke(id, tp, 3.2, Bau.matt("8a5a3b", 0.6), Bau.matt("f1eee8", 0.3))
	_figur(id, "character-female-c", Vector2(tp.x + 1.1, tp.y))
	RaumBau.modell(n, "laden/cash-register", Vector3(tp.x, 1.1, tp.y + 0.6), Haendler.MINI * 0.7, -PI / 2.0)
	_station(id, "souvenir", "", "Souvenirshop", "E: Souvenirs ansehen", Vector2(tp.x - 1.3, tp.y), tp)
	# große Mini-Wüstennadel als Blickfang im Schaufenster
	for s in [-1.0, 1.0]:
		var deko := Andenken.bauen("nadel")
		deko.scale = Vector3.ONE * 2.2
		deko.position = Vector3(-iw + 0.9, 0.06, s * 5.0)
		n.add_child(deko)
		_fest(id, -iw, s * 5.0 - 0.6, -iw + 1.5, s * 5.0 + 0.6)
	var pk := Andenken.bauen("postkarten")
	pk.position = Vector3(-7.5, 0.06, 3.2)
	n.add_child(pk)
	_fest(id, -7.8, 2.9, -7.2, 3.5)
	_souvenir_knoten = Node3D.new()
	n.add_child(_souvenir_knoten)
	for k in 2:
		RaumBau.licht(n, Vector3(-3.0 + k * 7.0, 3.9, 0), "ffe9cf", 1.2, 11.0)
	# Plätze: 6 an der Rückwand, je 3 an den Seiten
	for i in SV_PLAETZE:
		var p := _sv_platz(i)
		_fest(id, p[0].x - 0.3, p[0].y - 0.3, p[0].x + 0.3, p[0].y + 0.3)

# [Lage, Standpunkt] des i-ten Souvenir-Sockels (lokal)
func _sv_platz(i: int) -> Array:
	var iw: float = DATEN.souvenir.halb - WAND
	if i < 6:
		var z := -7.5 + i * 3.0
		return [Vector2(iw - 0.6, z), Vector2(iw - 1.9, z)]
	var k := i - 6
	var s := 1.0 if k < 3 else -1.0
	var x := 0.0 + (k % 3) * 2.6
	if s < 0.0:
		x += 2.0          # Theke steht vorne links
	return [Vector2(x, s * (iw - 0.6)), Vector2(x, s * (iw - 1.9))]

func _souvenirs_aufbauen() -> void:
	var id := "souvenir"
	for c in _souvenir_knoten.get_children():
		_souvenir_knoten.remove_child(c)
		c.queue_free()
	stationen = stationen.filter(func(st): return not (st.laden == id and st.id != ""))
	var i := 0
	for gid in Wirtschaft.GEGENSTAENDE:
		var g: Dictionary = Wirtschaft.GEGENSTAENDE[gid]
		if g.quelle != "souvenir" or i >= SV_PLAETZE:
			continue
		var pl := _sv_platz(i)
		i += 1
		var p: Vector2 = pl[0]
		var sperre := wirtschaft.kauf_sperre(gid)
		_gesperrt[gid] = sperre == "gesperrt"
		var text := ""
		if sperre == "gesperrt":
			# verhüllter Sockel mit Fragezeichen
			RaumBau.box(_souvenir_knoten, Vector3(0.42, 0.86, 0.42), Vector3(p.x, 0.49, p.y), Bau.matt("f1eee8", 0.35))
			RaumBau.box(_souvenir_knoten, Vector3(0.36, 0.42, 0.36), Vector3(p.x, 1.13, p.y), Bau.matt("4a1a3a", 0.9))
			text = "?  " + _erfolg_text(str(g.erfolg))
		else:
			var m := Moebel.modell(gid)
			m.position = Vector3(p.x, 0.06, p.y)
			m.rotation.y = atan2(pl[1].x - p.x, pl[1].y - p.y)
			_souvenir_knoten.add_child(m)
			text = "%s · %s" % [g.name, "gekauft" if sperre == "besitz" else Hud.punkte(int(g.preis)) + " €"]
		_schild(_souvenir_knoten, text, Vector3(p.x, 1.75, p.y), Color("ffd6ee") if sperre == "" else Color(0.8, 0.82, 0.86))
		var hinweis := "E: %s ansehen" % g.name if sperre != "gesperrt" else "Noch gesperrt: %s" % _erfolg_text(str(g.erfolg))
		_station(id, "souvenir", gid, g.name, hinweis, pl[1], p)

static func _erfolg_text(eid: String) -> String:
	for e in Erfolge.LISTE:
		if e.id == eid:
			return e.text
	return eid

# ---------------------------------------------------------------- Goldschmuck-Laden
func _goldladen() -> void:
	var id := "gold"
	var n := _innen(id)
	var h: float = DATEN[id].halb
	var iw := h - WAND
	var gold := Andenken.gold()
	# Goldleisten an den Wänden + Kronleuchter-Lichter
	for s in [-1.0, 1.0]:
		RaumBau.box(n, Vector3(2.0 * iw, 0.06, 0.04), Vector3(0, 3.6, s * (iw - 0.02)), gold)
		RaumBau.box(n, Vector3(2.0 * iw, 0.1, 0.04), Vector3(0, 0.12, s * (iw - 0.02)), gold)
	RaumBau.box(n, Vector3(0.04, 0.06, 2.0 * iw), Vector3(iw - 0.02, 3.6, 0), gold)
	for k in 2:
		RaumBau.licht(n, Vector3(-3.0 + k * 6.5, 4.2, 0), "ffe2a8", 2.4, 13.0)
	# Theke + Verkäuferin
	var tp := Vector2(-2.0, -iw + 1.6)
	_theke(id, tp, 3.0, Bau.matt("0d0e12", 0.2), gold)
	_figur(id, "character-female-a", Vector2(tp.x + 1.1, tp.y))
	_station(id, "gold", "", "Goldschmuck", "E: Gold-Deko fürs Penthouse ansehen", Vector2(tp.x - 1.3, tp.y), tp)
	# Schaufenster: Vitrinen mit Schmuck (Ringe, Ketten) auf Samt, funkelnd
	for s in [-1.0, 1.0]:
		var vp := Vector2(-iw + 0.8, s * 4.5)
		RaumBau.box(n, Vector3(0.9, 0.9, 2.6), Vector3(vp.x, 0.45, vp.y), Bau.matt("0d0e12", 0.25))
		RaumBau.box(n, Vector3(0.8, 0.04, 2.5), Vector3(vp.x, 0.92, vp.y), Bau.matt("6a1030", 0.9))
		RaumBau.box(n, Vector3(0.86, 0.5, 2.56), Vector3(vp.x, 1.19, vp.y), RaumBau.glas("ffffff", 0.12))
		_fest(id, vp.x - 0.45, vp.y - 1.3, vp.x + 0.45, vp.y + 1.3)
		for k in 5:
			var rp := Vector3(vp.x, 1.0, vp.y - 1.0 + k * 0.5)
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.045 if k % 2 == 0 else 0.11
			tm.outer_radius = 0.06 if k % 2 == 0 else 0.125
			ring.mesh = tm
			ring.material_override = gold
			ring.position = rp + Vector3(0, 0.06 if k % 2 == 0 else 0.0, 0)
			ring.rotation.z = PI / 2.0 if k % 2 == 0 else 0.0
			n.add_child(ring)
			if k % 2 == 0:   # Edelstein auf dem Ring
				var stein := RaumBau.box(n, Vector3.ONE * 0.035, rp + Vector3(0, 0.125, 0), RaumBau.leuchte(["ff3f6a", "35c8ff", "7fe08a"][k / 2], 1.0))
				stein.rotation = Vector3(0.6, 0.6, 0)
		# Glitzer: kleine Sterne, die nacheinander aufblitzen
		for j in 10:
			var fm := RaumBau.leuchte("fff6d0", 0.0)
			_funkeln.append([fm, 1.5 + randf() * 2.5, randf() * TAU])
			var funke := RaumBau.box(n, Vector3(0.012, 0.06, 0.012), Vector3(vp.x + randf_range(-0.3, 0.3), 1.0 + randf() * 0.3, vp.y + randf_range(-1.1, 1.1)), fm)
			funke.rotation.x = PI / 4.0
		RaumBau.licht(n, Vector3(vp.x, 1.6, vp.y), "ffe8b0", 0.8, 3.5)
	_gold_knoten = Node3D.new()
	n.add_child(_gold_knoten)
	for i in 6:   # Sockel der Gold-Stücke sind fest
		var gp: Vector2 = _gold_platz(i)[0]
		_fest(id, gp.x - 1.0, gp.y - 1.0, gp.x + 1.0, gp.y + 1.0)

# Plätze für die sechs Gold-Stücke: drei an der Rückwand, je zwei an den Seiten (hinten)
func _gold_platz(i: int) -> Array:
	var iw: float = DATEN.gold.halb - WAND
	var plaetze := [
		[Vector2(iw - 1.3, -5.0), Vector2(iw - 3.0, -5.0)],
		[Vector2(iw - 1.4, 0.0), Vector2(iw - 3.3, 0.0)],
		[Vector2(iw - 1.3, 5.0), Vector2(iw - 3.0, 5.0)],
		[Vector2(3.0, iw - 1.2), Vector2(3.0, iw - 2.9)],
		[Vector2(3.0, -iw + 1.2), Vector2(3.0, -iw + 2.9)],
		[Vector2(-1.0, iw - 1.2), Vector2(-1.0, iw - 2.9)],
	]
	return plaetze[i % plaetze.size()]

func _gold_aufbauen() -> void:
	var id := "gold"
	for c in _gold_knoten.get_children():
		_gold_knoten.remove_child(c)
		c.queue_free()
	stationen = stationen.filter(func(st): return not (st.laden == id and st.id != ""))
	var i := 0
	for gid in Wirtschaft.GEGENSTAENDE:
		var g: Dictionary = Wirtschaft.GEGENSTAENDE[gid]
		if g.quelle != "gold":
			continue
		var pl := _gold_platz(i)
		i += 1
		var p: Vector2 = pl[0]
		RaumBau.zyl(_gold_knoten, 1.05, 0.12, Vector3(p.x, 0.12, p.y), Bau.matt("0d0e12", 0.15), 28)
		RaumBau.zyl(_gold_knoten, 1.08, 0.03, Vector3(p.x, 0.19, p.y), Andenken.gold(), 28)
		var m := Moebel.modell(gid)
		m.position = Vector3(p.x, 0.2, p.y)
		m.rotation.y = atan2(pl[1].x - p.x, pl[1].y - p.y)
		_gold_knoten.add_child(m)
		RaumBau.licht(_gold_knoten, Vector3(p.x, 3.6, p.y), "fff0c8", 0.7, 4.0)
		var sperre := wirtschaft.kauf_sperre(gid)
		var text := "%s · %s" % [g.name, "gehört dir" if sperre == "besitz" else Hud.punkte(int(g.preis)) + " €"]
		_schild(_gold_knoten, text + " · +%d %%" % int(round(wirtschaft.gegenstand_bonus(gid) * 100.0)), Vector3(p.x, Moebel.hoehe(gid) + 0.6, p.y), Color("ffe08a"))
		_station(id, "gold", gid, g.name, "E: %s ansehen (%s €)" % [g.name, Hud.punkte(int(g.preis))], pl[1], p)

# ---------------------------------------------------------------- Aktualisieren (nach Käufen/Erfolgen)
func aktualisieren() -> void:
	_souvenirs_aufbauen()
	_gold_aufbauen()
	var ka := wirtschaft.kosmetik_aktiv
	if vorfuehr_mat:
		GondelDeko.lack(vorfuehr_mat, wirtschaft.kosmetik(ka.gondel).farbe, ka.lack)
		var z := [ka.aufkleber, ka.blumen, ka.schirm, ka.radio]
		if z != _zubehoer:
			_zubehoer = z
			GondelDeko.zubehoer(vorfuehr_deko, z[0], z[1], z[2], z[3])

# Hat sich bei den Souvenirs etwas freigeschaltet? (nach neuen Erfolgen)
func souvenirs_geaendert() -> bool:
	for gid in _gesperrt:
		if _gesperrt[gid] != (wirtschaft.kauf_sperre(gid) == "gesperrt"):
			return true
	return false
