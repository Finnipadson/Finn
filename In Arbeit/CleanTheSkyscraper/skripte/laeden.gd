class_name Laeden
extends Node3D
# Vier begehbare Läden rund um den Platz, je im Erdgeschoss eines eigenen Hochhauses (Grundstücke Welt.LAEDEN):
#   Möbelhaus (Ausstellungsräume, E am Möbelstück = ansehen + kaufen), Gondel-Werkstatt (Vorführ-Gondel zeigt deine
#   Ausstattung), Souvenirshop (Andenken für Meilensteine) und Goldschmuck-Laden (neben dem Casino, Gold-Deko).
# Jeder Laden: Node3D am Grundstück, gedreht in 90°-Schritten, damit die Tür (lokal −X) zum Turm zeigt.
# Kollision zu Fuß: rechtecke (Welt). Stationen: {art "laden", menue, id, name, hinweis, pos, ziel} → Extras.

const WAND := 0.4
const SICHT := 130.0     # Innenräume nur zeichnen, wenn die Kamera so nah ist
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
			(laeden[id].innen as Node3D).visible = c.distance_to(laeden[id].mitte) < SICHT and cam.global_position.y < 60.0
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
	# Rückwand + Seiten (außen Stein, innen Farbe des Ladens)
	RaumBau.box(haus, Vector3(WAND, hoch, h * 2.0), Vector3(mw, hoch * 0.5, 0), stein)
	RaumBau.box(innen, Vector3(0.02, hoch, h * 2.0 - 0.8), Vector3(mw - WAND * 0.5 - 0.01, hoch * 0.5, 0), innen_mat)
	_fest(id, h - WAND, -h, h, h)
	for s in [-1.0, 1.0]:
		RaumBau.box(haus, Vector3(h * 2.0, hoch, WAND), Vector3(0, hoch * 0.5, s * mw), stein)
		RaumBau.box(innen, Vector3(h * 2.0 - 0.8, hoch, 0.02), Vector3(0, hoch * 0.5, s * (mw - WAND * 0.5 - 0.01)), innen_mat)
		_fest(id, -h, s * mw - WAND * 0.5, h, s * mw + WAND * 0.5)
	# Vorderseite: Tür in der Mitte, daneben große Schaufenster mit Brüstung, darüber das Schild-Band
	var glas := RaumBau.glas("cfe8ff", 0.16)
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
	bm.albedo_color = Color(d.boden)
	bm.roughness = 0.35 if id in ["gold", "werkstatt"] else 0.7
	bm.metallic = 0.2 if id == "gold" else 0.0
	RaumBau.flaeche(innen, poly, 0.06, bm, true, 0.25)
	# Pflanzkübel neben der Tür
	for s in [-1.0, 1.0]:
		RaumBau.box(haus, Vector3(1.0, 0.8, 1.0), Vector3(-h - 0.9, 0.4, s * (tuer * 0.5 + 1.6)), Bau.matt("2a2d38", 0.5))
		RaumBau.modell(haus, "natur/plant_bushLarge", Vector3(-h - 0.9, 0.8, s * (tuer * 0.5 + 1.6)), 1.1)
		_fest(id, -h - 1.4, s * (tuer * 0.5 + 1.6) - 0.5, -h - 0.4, s * (tuer * 0.5 + 1.6) + 0.5)

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
			var zw1: float = seite * innen_w
			RaumBau.box(n, Vector3(0.2, 2.8, innen_w - MH_GANG), Vector3(x0 - 0.1, 1.4, (zw0 + zw1) * 0.5), trenn)
			RaumBau.box(n, Vector3(0.24, 0.08, innen_w - MH_GANG), Vector3(x0 - 0.1, 2.84, (zw0 + zw1) * 0.5), leiste)
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
			RaumBau.licht(n, Vector3((x0 + x1) * 0.5, 4.6, seite * 10.0), "fff0dc", 1.2, 11.0)
			_raum_moebel(r.id, x0, x1, seite)
			# Deko-Teppich in der Mitte (nicht zu kaufen, nur Ausstellung)
			if r.id != "wohnen":
				RaumBau.mittig(n, "moebel/rugRectangle", Vector3((x0 + x1) * 0.5, 0.08, seite * (MH_GANG + (innen_w - MH_GANG) * 0.5)), Moebel.MASS * 1.5, PI * 0.5)
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

# Möbel eines Ausstellungsraums an die drei Wände stellen (Rücken zur Wand), flache Teppiche in die Mitte.
func _raum_moebel(raum: String, x0: float, x1: float, seite: float) -> void:
	var id := "moebel"
	var n := _innen(id)
	var innen_w: float = DATEN[id].halb - WAND
	var ids := []
	var flach := []
	for gid in Wirtschaft.GEGENSTAENDE:
		if wirtschaft.moebel_raum(gid) == raum:
			if Moebel.hoehe(gid) <= 0.15:
				flach.append(gid)
			else:
				ids.append(gid)
	var tiefe := innen_w - MH_GANG
	# Plätze: [x, z, dreh, wand] wand: 0 = Rückwand, 1 = links (x0), 2 = rechts (x1)
	var plaetze := []
	for f in [1.0 / 6.0, 0.5, 5.0 / 6.0]:
		plaetze.append([lerpf(x0, x1, f), 0.0, 180.0 if seite > 0.0 else 0.0, 0])
	for f in [0.14, 0.42]:
		plaetze.append([0.0, seite * (MH_GANG + tiefe * f + 1.2), 90.0, 1])
		plaetze.append([0.0, seite * (MH_GANG + tiefe * f + 1.2), 270.0, 2])
	for f in [0.7]:
		plaetze.append([0.0, seite * (MH_GANG + tiefe * f + 0.6), 90.0, 1])
		plaetze.append([0.0, seite * (MH_GANG + tiefe * f + 0.6), 270.0, 2])
	for i in mini(ids.size(), plaetze.size()):
		var gid: String = ids[i]
		var pl: Array = plaetze[i]
		var dreh: float = pl[2]
		var f := Moebel.flaeche(gid, dreh)
		var p: Vector2 = Vector2(pl[0], pl[1])
		var steh := Vector2.ZERO
		match int(pl[3]):
			0:
				p.y = seite * (innen_w - 0.15 - f.y * 0.5)
				steh = Vector2(p.x, p.y - seite * (f.y * 0.5 + 0.9))
			1:
				p.x = x0 + 0.15 + f.x * 0.5
				steh = Vector2(p.x + f.x * 0.5 + 0.9, p.y)
			2:
				p.x = x1 - 0.15 - f.x * 0.5
				steh = Vector2(p.x - f.x * 0.5 - 0.9, p.y)
		_ausstellen(gid, p, dreh, steh, n)
	for i in flach.size():
		var gid2: String = flach[i]
		var p2 := Vector2((x0 + x1) * 0.5, seite * (MH_GANG + tiefe * 0.45))
		_ausstellen(gid2, p2, 0.0, p2 - Vector2(0, seite * 1.6), n)

func _ausstellen(gid: String, p: Vector2, dreh: float, steh: Vector2, n: Node3D) -> void:
	var id := "moebel"
	var m := Moebel.modell(gid)
	m.position = Vector3(p.x, 0.08, p.y)
	m.rotation.y = deg_to_rad(dreh)
	n.add_child(m)
	var g := wirtschaft.gegenstand(gid)
	var f := Moebel.flaeche(gid, dreh)
	if Moebel.hoehe(gid) > 0.15:
		_fest(id, p.x - f.x * 0.5 + 0.05, p.y - f.y * 0.5 + 0.05, p.x + f.x * 0.5 - 0.05, p.y + f.y * 0.5 - 0.05)
	var t := "%s · %s €" % [g.name, Hud.punkte(wirtschaft.gegenstand_preis(gid))]
	var bonus := "" if not g.has("bonus") else " · +%d %%" % int(round(wirtschaft.gegenstand_bonus(gid) * 100.0))
	_schild(n, t + bonus, Vector3(p.x, maxf(Moebel.hoehe(gid), 0.4) + 0.45, p.y), Color("fff6e0") if not g.has("bonus") else Color(Wirtschaft.SELTEN_FARBE[wirtschaft.seltenheit(gid)]).lightened(0.3))
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
	_station(id, "werkstatt", "", "Gondel-Werkstatt", "E: Gondel gestalten (Lack, Aufkleber, Blumen, Schirm)", Vector2(-0.4, 0), Vector2(2.0, 0))
	# Theke mit Mechaniker
	var tp := Vector2(-2.0, iw - 1.6)
	_theke(id, tp, 3.0, Bau.matt("2b2f36", 0.5), Bau.metall("35c8ff", 0.3, 0.5))
	_figur(id, "character-worker", Vector2(tp.x + 1.1, tp.y))
	_station(id, "werkstatt", "", "Gondel-Werkstatt", "E: Gondel gestalten (Lack, Aufkleber, Blumen, Schirm)", Vector2(tp.x - 1.3, tp.y), tp)
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
		RaumBau.modell(n, "moebel/cardboardBoxClosed", Vector3(iw - 1.0, 0.06 + k * 0.5, 5.5), Moebel.MASS)
	_fest(id, iw - 1.6, 4.9, iw, 6.3)
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
	pk.position = Vector3(-2.0, 0.06, 4.0)
	n.add_child(pk)
	_fest(id, -2.3, 3.7, -1.7, 4.3)
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
		RaumBau.zyl(n, 0.6, 0.08, Vector3(-3.0 + k * 6.5, 4.85, 0), gold, 20)
		for j in 8:
			var a := j * TAU / 8.0
			RaumBau.box(n, Vector3(0.03, 0.35, 0.03), Vector3(-3.0 + k * 6.5 + sin(a) * 0.5, 4.6, cos(a) * 0.5), RaumBau.glas("ffffff", 0.4))
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
		var z := [ka.aufkleber, ka.blumen, ka.schirm]
		if z != _zubehoer:
			_zubehoer = z
			GondelDeko.zubehoer(vorfuehr_deko, z[0], z[1], z[2])

# Hat sich bei den Souvenirs etwas freigeschaltet? (nach neuen Erfolgen)
func souvenirs_geaendert() -> bool:
	for gid in _gesperrt:
		if _gesperrt[gid] != (wirtschaft.kauf_sperre(gid) == "gesperrt"):
			return true
	return false
