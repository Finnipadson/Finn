class_name SkyLounge
extends Node3D
# Sky-Lounge im Turm: Express-Aufzug unten (in der Lücke zwischen zwei Flügeln, Richtung +Z) und drei Etagen:
# Lounge (Stockwerk 48, ~200 m) mit Sky-Bar, Restaurant (Stockwerk 120, ~500 m) mit Restaurant-Theke und Designer-Möbeln,
# Aussichtsplattform (800 m) als Glas-Ring um die Turmspitze mit Gipfel-Bar und Exklusiv-Laden.
# Eine Etage ist frei, sobald das Seil (Wirtschaft.oberstes_stockwerk) bis dorthin reicht.
# Die Räume liegen im echten Turm: Boden + Decke + Glaswände entlang des Grundrisses; der Turm-Shader lässt die Fassade
# im Höhenband weg, solange man drin ist (Turm.glas „innen_band“).

const ETAGEN := [
	{"id": "lounge", "name": "Sky-Lounge", "stock": 48, "text": "Lounge mit Sky-Bar"},
	{"id": "restaurant", "name": "Restaurant", "stock": 120, "text": "Restaurant und Designer-Möbel"},
	{"id": "plattform", "name": "Aussichtsplattform", "stock": 168, "hoehe": 800.0, "text": "Gipfel-Bar und Exklusiv-Laden in der Turmspitze"},
]
const PLATT_R := 12.0          # Radius der Aussichtsplattform
const KERN_R := 3.2            # Aufzugskern in der Mitte jeder Etage
const NAH := 2.4

var turm: Turm
var etagen := {}               # id -> {id, name, boden, raum, ankunft, yaw, band, knoten, stationen, meter}
var unten_pos := Vector2.ZERO  # vor der Aufzugstür unten (Welt x, z)
var unten_ziel := Vector2.ZERO
var unten_rect := Rect2()      # Umriss der Lobby (nur für Tests/Bilder)
var unten_poly := PackedVector2Array()   # Kollision der Lobby (Dreieck in der Turmecke)
var _leucht: Array = []

func setup(t: Turm) -> void:
	turm = t
	_aufzug_unten()
	for e in ETAGEN:
		if e.id == "plattform":
			_plattform(e)
		else:
			_etage(e)

func _process(_dt: float) -> void:
	var tt := Time.get_ticks_msec() * 0.001
	for i in _leucht.size():
		(_leucht[i] as StandardMaterial3D).emission_energy_multiplier = 1.8 + sin(tt * 1.5 + i) * 0.6

# Höhe in Metern zum Anzeigen
static func meter(e: Dictionary) -> int:
	return int(e.get("hoehe", e.stock * Turm.STOCK_H))

# ---------------------------------------------------------------- Aufzug unten
func _aufzug_unten() -> void:
	# Verglaste Lobby in der Innenecke zwischen den Flügeln bei 30° und 150° (Lücke bei 90° = Richtung +Z):
	# Grundriss = Dreieck aus Ecke und den beiden Flügelwänden, Glasfront über zwei Stockwerke im Fensterraster
	# des Turms (1,5 m breit, 4,2 m hoch), Alurahmen wie am Turm, Vordach mit Spots, dahinter Aufzugstüren.
	var r_ecke := 13.5 / sin(PI / 3.0)
	var ecke := Vector2(0, r_ecke)
	var l := 6.0
	var a := ecke + Vector2(cos(PI / 6.0), sin(PI / 6.0)) * l            # an der Wand des Flügels bei 30°
	var b := ecke + Vector2(-cos(PI / 6.0), sin(PI / 6.0)) * l           # an der Wand des Flügels bei 150°
	var vorn := a.y
	var hoch := 2.0 * Turm.STOCK_H
	var k := Node3D.new()
	add_child(k)
	var alu := Bau.metall("c9ced4", 0.35, 0.6)
	var gl := RaumBau.glas("a9cbe6", 0.28)
	var weiss := Bau.matt("eef0f2", 0.3)
	# Boden + Decke der Lobby
	var drei := PackedVector2Array([ecke, a, b])
	RaumBau.flaeche(k, drei, 0.03, Bau.matt("d8d2c8", 0.3))
	RaumBau.flaeche(k, drei, hoch - 0.05, weiss, false)
	# Glasfront mit Rahmen: senkrecht alle 1,5 m, waagerecht bei 4,2 m (Stockwerk) und oben
	var breite := a.x - b.x
	RaumBau.box(k, Vector3(breite, hoch, 0.03), Vector3(0, hoch * 0.5, vorn), gl)
	var n := int(round(breite / Turm.FENSTER_B))
	for i in n + 1:
		var x := b.x + breite * i / n
		var dick := 0.14 if i == 0 or i == n else 0.07
		RaumBau.box(k, Vector3(dick, hoch, 0.12), Vector3(x, hoch * 0.5, vorn), alu)
	for y in [0.06, Turm.STOCK_H, hoch - 0.06]:
		RaumBau.box(k, Vector3(breite, 0.12, 0.14), Vector3(0, y, vorn), alu)
	# Glas-Schiebetür in der Mitte (zwei Felder breit), leicht geöffnet
	var tb := 2.0 * breite / n
	for sx in [-1.0, 1.0]:
		var tuer := Node3D.new()
		tuer.position = Vector3(sx * (tb * 0.25 + 0.25), 0, vorn + 0.09)
		k.add_child(tuer)
		RaumBau.box(tuer, Vector3(tb * 0.5, 2.9, 0.03), Vector3(0, 1.5, 0), RaumBau.glas("cfe8ff", 0.18))
		for y in [0.08, 2.92]:
			RaumBau.box(tuer, Vector3(tb * 0.5, 0.08, 0.06), Vector3(0, y, 0), alu)
		for x in [-tb * 0.25, tb * 0.25]:
			RaumBau.box(tuer, Vector3(0.06, 2.9, 0.06), Vector3(x, 1.5, 0), alu)
		RaumBau.box(tuer, Vector3(0.03, 0.6, 0.05), Vector3(-sx * (tb * 0.25 - 0.12), 1.1, 0.05), Bau.metall("e8ecf0", 0.2, 0.9))
	RaumBau.box(k, Vector3(tb + 0.2, 0.12, 0.16), Vector3(0, 3.0, vorn + 0.05), alu)
	# Vordach: flache weiße Platte mit Alukante, Spots darunter, Schrift an der Kante
	var dach_t := 3.2
	RaumBau.box(k, Vector3(breite + 1.6, 0.32, dach_t), Vector3(0, hoch - 2.1, vorn + dach_t * 0.5), weiss)
	RaumBau.box(k, Vector3(breite + 1.64, 0.06, dach_t + 0.04), Vector3(0, hoch - 2.27, vorn + dach_t * 0.5), alu)
	var spot := RaumBau.leuchte("fff4e0", 2.2)
	for ix in 5:
		for iz in 2:
			var sp := RaumBau.zyl(k, 0.09, 0.02, Vector3(-4.0 + ix * 2.0, hoch - 2.28, vorn + 0.9 + iz * 1.4), spot, 16)
			sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	RaumBau.licht(k, Vector3(0, hoch - 2.8, vorn + 1.6), "fff1dc", 1.2, 8.0)
	var titel := RaumBau.schrift(k, "SKY LOUNGE", Vector3(0, hoch - 2.1, vorn + dach_t + 0.02), 0.0, 96, 0.0075, Color("2b3440"), false)
	titel.outline_size = 0
	RaumBau.schrift(k, "EXPRESS-AUFZUG  ·  200 m  ·  500 m  ·  800 m", Vector3(0, Turm.STOCK_H + 0.42, vorn + 0.08), 0.0, 44, 0.0055, Color("2b3440"), false)
	# Lobby hinter dem Glas: je Flügelwand eine Aufzugstür aus gebürstetem Stahl, warmes Licht
	var stahl := Bau.metall("b9bec6", 0.22, 0.9)
	for seite in [-1.0, 1.0]:
		var d := Vector2(seite * cos(PI / 6.0), sin(PI / 6.0))          # entlang der Wand von der Ecke weg
		var nrm: Vector2 = Vector2(-d.y, d.x) * seite                        # zeigt in die Lobby
		# Steinverkleidung über die ganze Wand (verdeckt die Turmfenster hinter der Lobby), mit feinen Fugen
		var wm: Vector2 = ecke + d * 2.93 + nrm * 0.15
		var wn := Node3D.new()
		wn.position = Vector3(wm.x, 0, wm.y)
		wn.rotation.y = atan2(nrm.x, nrm.y)
		k.add_child(wn)
		RaumBau.box(wn, Vector3(5.85, hoch - 0.08, 0.06), Vector3(0, (hoch - 0.08) * 0.5, 0), Bau.matt("e2dccf", 0.5))
		for fy in [1.4, 2.8, Turm.STOCK_H, 5.6, 7.0]:
			RaumBau.box(wn, Vector3(5.85, 0.02, 0.064), Vector3(0, fy, 0), Bau.matt("c9c1b2", 0.6))
		var m: Vector2 = ecke + d * 3.3 + nrm * 0.21
		var tn := Node3D.new()
		tn.position = Vector3(m.x, 0, m.y)
		tn.rotation.y = atan2(nrm.x, nrm.y)
		k.add_child(tn)
		RaumBau.box(tn, Vector3(2.2, 3.0, 0.08), Vector3(0, 1.53, 0), Bau.matt("2b2f36", 0.4))
		for sx in [-1.0, 1.0]:
			RaumBau.box(tn, Vector3(0.94, 2.7, 0.05), Vector3(sx * 0.48, 1.4, 0.05), stahl)
		RaumBau.box(tn, Vector3(0.5, 0.14, 0.04), Vector3(0, 2.85, 0.06), RaumBau.leuchte("ffcf6a", 1.6))
	RaumBau.licht(k, Vector3(0, 3.6, r_ecke + 1.6), "ffe2b8", 1.4, 6.0)
	RaumBau.zyl(k, 0.5, 0.04, Vector3(0, hoch - 0.08, r_ecke + 1.6), RaumBau.leuchte("fff1d6", 1.6), 24)
	unten_poly = PackedVector2Array([ecke - Vector2(0, 1.0), a + Vector2(0.4, 0.3), b + Vector2(-0.4, 0.3)])
	unten_rect = Rect2(Vector2(b.x, ecke.y), Vector2(breite, vorn - ecke.y))
	unten_pos = Vector2(0, vorn + 1.9)
	unten_ziel = Vector2(0, vorn)

# ---------------------------------------------------------------- Etage im Turm (Lounge, Restaurant)
func _etage(e: Dictionary) -> void:
	var f: int = e.stock
	var boden := f * Turm.STOCK_H + 0.04
	var decke := (f + 1) * Turm.STOCK_H - 0.3
	var poly: PackedVector2Array = turm.stockwerke[f].poly
	var innen := RaumBau.verschieben(poly, -0.12)
	var k := Node3D.new()
	k.visible = false
	add_child(k)
	var bm := Bau.matt("cfc7ba", 0.35) if e.id == "lounge" else Bau.matt("b89f80", 0.5)
	RaumBau.flaeche(k, innen, boden, bm)
	RaumBau.flaeche(k, innen, decke, Bau.matt("2a2f3a", 0.8), false)
	RaumBau.waende(k, innen, boden, decke, RaumBau.glas("cfe8ff", 0.08))
	# Sockelleiste + Lichtband unter der Decke entlang der Glasfront
	RaumBau.waende(k, RaumBau.verschieben(innen, -0.05), boden, boden + 0.12, Bau.matt("3a3f48", 0.5))
	# Aufzugskern
	var stein := Bau.matt("f1ede6", 0.4)
	RaumBau.zyl(k, KERN_R, decke - boden, Vector3(0, (boden + decke) * 0.5, 0), stein, 40)
	_aufzugstuer(k, boden, KERN_R)
	var st := []
	st.append({"art": "aufzug", "name": "Aufzug", "hinweis": "E: Aufzug", "pos": Vector2(0, KERN_R + 1.6), "ziel": Vector2(0, 0)})
	var raum := {"poly": RaumBau.verschieben(poly, -0.7), "rechtecke": [], "kreise": [[Vector2.ZERO, KERN_R]], "boden": boden}
	# Lichter: Mitte + je Flügel
	RaumBau.licht(k, Vector3(0, decke - 0.6, 6.0), "ffe6c4", 1.6, 16.0)
	for w in 3:
		var d := _dir(w)
		for r in [12.0, 24.0, 36.0]:
			if Geometry2D.is_point_in_polygon(d * (r + 2.0), poly):
				RaumBau.licht(k, Vector3(d.x * r, decke - 0.6, d.y * r), "ffe6c4", 1.3, 13.0)
				RaumBau.box(k, Vector3(2.4, 0.04, 2.4), Vector3(d.x * r, decke - 0.03, d.y * r), RaumBau.leuchte("fff1d6", 1.2))
	if e.id == "lounge":
		_lounge(k, boden, decke, st, raum)
	else:
		_restaurant(k, boden, decke, st, raum)
	etagen[e.id] = {"id": e.id, "name": e.name, "boden": boden, "raum": raum, "ankunft": Vector2(0, KERN_R + 1.6), "yaw": PI,
		"band": Vector2(boden - 0.5, decke + 0.6), "knoten": k, "stationen": st, "meter": meter(e)}

func _dir(w: int) -> Vector2:
	var a := TAU * w / 3.0 - PI / 2.0
	return Vector2(cos(a), sin(a))

# Punkt im Flügel w: r entlang der Achse, q quer dazu (Welt x, z)
func _im_fluegel(w: int, r: float, q: float) -> Vector2:
	var d := _dir(w)
	return d * r + Vector2(-d.y, d.x) * q

func _yaw_zu(von: Vector2, nach: Vector2) -> float:
	var d := nach - von
	return atan2(-d.x, -d.y)

func _aufzugstuer(k: Node3D, boden: float, r: float) -> void:
	var stahl := Bau.metall("c9ced4", 0.25, 0.85)
	for s in [-1.0, 1.0]:
		RaumBau.box(k, Vector3(0.95, 2.6, 0.06), Vector3(s * 0.49, boden + 1.3, r + 0.02), stahl)
	RaumBau.box(k, Vector3(2.3, 0.14, 0.1), Vector3(0, boden + 2.68, r + 0.03), Bau.matt("2a2f3a", 0.5))
	RaumBau.box(k, Vector3(0.1, 0.1, 0.04), Vector3(1.3, boden + 1.3, r + 0.05), RaumBau.leuchte("ffcf6a", 2.5))

# Theke mit Person dahinter und Regal (Bar, Restaurant, Laden). Gibt die Station zurück.
func _theke(k: Node3D, boden: float, w: int, r: float, art: String, name: String, hinweis: String, figur: String, farbe: String, raum: Dictionary) -> Dictionary:
	var d := _dir(w)
	var dreh := atan2(d.x, d.y)
	var mitte := d * r
	var holz := Bau.matt("2c2420", 0.45)
	var platte := Bau.matt("f4f1ec", 0.15)
	var t := Node3D.new()
	t.position = Vector3(mitte.x, boden, mitte.y)
	t.rotation.y = dreh
	k.add_child(t)
	RaumBau.box(t, Vector3(6.0, 1.1, 0.8), Vector3(0, 0.55, 0), holz)
	RaumBau.box(t, Vector3(6.2, 0.07, 1.0), Vector3(0, 1.13, 0), platte)
	var lm := RaumBau.leuchte(farbe, 1.8)
	_leucht.append(lm)
	RaumBau.box(t, Vector3(6.0, 0.06, 0.04), Vector3(0, 0.25, -0.42), lm)
	RaumBau.box(t, Vector3(5.6, 2.4, 0.35), Vector3(0, 1.4, 2.6), Bau.matt("20242c", 0.4))
	for j in 3:
		RaumBau.box(t, Vector3(5.4, 0.05, 0.36), Vector3(0, 0.9 + j * 0.65, 2.42), RaumBau.leuchte("ffcf8a", 0.9))
	RaumBau.schrift(t, name.to_upper(), Vector3(0, 2.95, 2.4), PI, 96, 0.006, Color(farbe))
	RaumBau.modell(t, "leute/" + figur, Vector3(1.7, 0, 1.3), 2.5, PI)
	var gl := ["essen/glass", "essen/soda-bottle", "essen/cup-coffee", "essen/mug"]
	for j in 8:
		RaumBau.modell(t, gl[j % gl.size()], Vector3(-2.4 + j * 0.65, 1.0 + (j % 3) * 0.65, 2.35), 1.2)
	raum.rechtecke.append(_rect_um(mitte, d, Vector2(3.3, 0.6)))
	raum.rechtecke.append(_rect_um(d * (r + 2.6), d, Vector2(3.0, 0.4)))
	var steh := d * (r - 1.9)
	return {"art": art, "name": name, "hinweis": hinweis, "pos": steh, "ziel": mitte}

# Achsparalleles Rechteck um ein gedrehtes Rechteck (halb: halbe Breite quer, halbe Tiefe entlang d)
func _rect_um(m: Vector2, d: Vector2, halb: Vector2) -> Rect2:
	var q := Vector2(-d.y, d.x)
	var ex := absf(q.x) * halb.x + absf(d.x) * halb.y
	var ez := absf(q.y) * halb.x + absf(d.y) * halb.y
	return Rect2(m - Vector2(ex, ez), Vector2(ex, ez) * 2.0)

# Möbel aus dem Furniture Kit an einen Punkt (Flügel-Koordinaten), mit Kollision
func _moebel(k: Node3D, raum: Dictionary, boden: float, name: String, p: Vector2, dreh: float, s := Moebel.MASS, kollision := true) -> void:
	if not RaumBau.modell_da("moebel/" + name):
		return
	var n := RaumBau.mittig(k, "moebel/" + name, Vector3(p.x, boden, p.y), s, dreh)
	if kollision:
		var b := RaumBau.aabb(n)
		if b.size.y > 0.2:
			raum.rechtecke.append(Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z)).grow(-0.05))

func _lounge(k: Node3D, boden: float, decke: float, st: Array, raum: Dictionary) -> void:
	st.append(_theke(k, boden, 1, 30.0, "bar", "Sky-Bar", "E: Sky-Bar (Spezial-Boosts)", "character-male-b", "35c8ff", raum))
	# Barhocker vor der Theke
	for j in 5:
		_moebel(k, raum, boden, "stoolBar", _im_fluegel(1, 28.6, -2.4 + j * 1.2), 0.0, Moebel.MASS, false)
	# Sitzecken im linken und unteren Flügel
	for w in [0, 2]:
		for r in [20.0, 32.0]:
			var m := _im_fluegel(w, r, 0.0)
			var d := _dir(w)
			var dreh := atan2(d.x, d.y)
			_moebel(k, raum, boden, "rugRound", m, 0.0, Moebel.MASS * 1.8, false)
			_moebel(k, raum, boden, "loungeDesignSofa", m + d * 2.2, dreh + PI)
			_moebel(k, raum, boden, "loungeDesignChair", m - d * 2.2 + Vector2(-d.y, d.x) * 1.0, dreh)
			_moebel(k, raum, boden, "loungeDesignChair", m - d * 2.2 - Vector2(-d.y, d.x) * 1.0, dreh)
			_moebel(k, raum, boden, "tableCoffeeGlass", m, dreh)
			_moebel(k, raum, boden, "pottedPlant", _im_fluegel(w, r, 8.5), 0.0)
			_moebel(k, raum, boden, "pottedPlant", _im_fluegel(w, r, -8.5), 0.0)
	# Gäste
	RaumBau.modell(k, "leute/character-female-c", Vector3(_im_fluegel(2, 25.0, 3.0).x, boden, _im_fluegel(2, 25.0, 3.0).y), 2.5, 0.8)
	RaumBau.modell(k, "leute/character-male-e", Vector3(_im_fluegel(1, 24.0, -5.0).x, boden, _im_fluegel(1, 24.0, -5.0).y), 2.5, 2.0)
	RaumBau.schrift(k, "SKY LOUNGE · 200 m", Vector3(0, decke - 0.7, -KERN_R - 0.02), PI, 80, 0.006, Color("e8f1fa"))

func _restaurant(k: Node3D, boden: float, decke: float, st: Array, raum: Dictionary) -> void:
	st.append(_theke(k, boden, 1, 19.5, "restaurant", "Restaurant", "E: Restaurant (Menüs mit Boosts)", "character-male-e", "ffb03a", raum))
	st.append(_designer(k, boden, 2, 19.0, "designer", "Designer-Möbel", "E: Designer-Möbel ansehen", raum))
	# Tische mit Essen im dritten Flügel und am Kern
	var essen := ["essen/croissant", "essen/sundae", "essen/donut-sprinkles", "essen/ice-cream", "essen/frappe"]
	var i := 0
	for p in [_im_fluegel(0, 13.0, -4.5), _im_fluegel(0, 13.0, 4.5), _im_fluegel(0, 20.0, -4.0), _im_fluegel(0, 20.0, 4.0), _im_fluegel(1, 9.0, 6.0), _im_fluegel(2, 9.0, -6.0)]:
		_moebel(k, raum, boden, "tableRound", p, 0.0)
		for a in 4:
			var o := Vector2(cos(a * PI * 0.5), sin(a * PI * 0.5)) * 1.05
			_moebel(k, raum, boden, "chairCushion", p + o, atan2(-o.x, -o.y), Moebel.MASS, false)
		RaumBau.modell(k, essen[i % essen.size()], Vector3(p.x, boden + 0.78, p.y), 1.3)
		i += 1
	RaumBau.schrift(k, "RESTAURANT · 500 m", Vector3(0, decke - 0.7, -KERN_R - 0.02), PI, 80, 0.006, Color("e8f1fa"))

# Laden mit Podesten, auf denen die Möbel der Quelle (designer/exklusiv) stehen
func _designer(k: Node3D, boden: float, w: int, r: float, quelle: String, name: String, hinweis: String, raum: Dictionary) -> Dictionary:
	var st := _theke(k, boden, w, r + 3.0, quelle, name, hinweis, "character-female-a", "b36bff", raum)
	var ids := []
	for id in Wirtschaft.GEGENSTAENDE:
		if Wirtschaft.GEGENSTAENDE[id].quelle == quelle:
			ids.append(id)
	for j in ids.size():
		var q := -6.0 + 12.0 * j / maxf(ids.size() - 1, 1)
		var p := _im_fluegel(w, r - 4.0, q)
		RaumBau.zyl(k, 1.1, 0.25, Vector3(p.x, boden + 0.125, p.y), Bau.matt("f4f1ec", 0.2), 32)
		var n := Moebel.modell(ids[j])
		n.position = Vector3(p.x, boden + 0.25, p.y)
		n.rotation.y = atan2(_dir(w).x, _dir(w).y) + PI
		k.add_child(n)
		raum.kreise.append([p, 1.1])
	return st

# ---------------------------------------------------------------- Aussichtsplattform um die Spitze (800 m)
func _plattform(e: Dictionary) -> void:
	var boden: float = e.hoehe
	var decke := boden + 3.6
	var k := Node3D.new()
	add_child(k)
	var weiss := Bau.matt("f1ede6", 0.35)
	var stahl := Bau.metall("c9ced4", 0.25, 0.85)
	var r := PLATT_R
	RaumBau.zyl(k, r, 0.5, Vector3(0, boden - 0.25, 0), weiss, 48)
	RaumBau.zyl(k, r, 5.0, Vector3(0, boden - 3.0, 0), stahl, 48, 3.0)        # Unterseite als Kegel
	RaumBau.zyl(k, r + 0.3, 0.4, Vector3(0, decke + 0.2, 0), stahl, 48)
	RaumBau.zyl(k, r - 1.0, 1.6, Vector3(0, decke + 1.2, 0), weiss, 48, r)     # Dach als flacher Kegel
	var gl := Bau.zylinder(r - 0.05, r - 0.05, decke - boden, RaumBau.glas("cfe8ff", 0.1), 48)
	(gl.mesh as CylinderMesh).cap_top = false
	(gl.mesh as CylinderMesh).cap_bottom = false
	gl.position.y = (boden + decke) * 0.5
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	k.add_child(gl)
	for j in 16:
		var a := TAU * j / 16.0
		RaumBau.box(k, Vector3(0.12, decke - boden, 0.12), Vector3(cos(a) * (r - 0.05), (boden + decke) * 0.5, sin(a) * (r - 0.05)), stahl)
	var lm := RaumBau.leuchte("35c8ff", 2.0)
	_leucht.append(lm)
	var ring := Bau.zylinder(r + 0.35, r + 0.35, 0.12, lm, 48)
	ring.position.y = boden - 0.45
	k.add_child(ring)
	var innen := Node3D.new()
	innen.visible = false
	k.add_child(innen)
	RaumBau.flaeche(innen, RaumBau.kreis(r - 0.06, 48), decke - 0.01, Bau.matt("2a2f3a", 0.8), false)
	RaumBau.zyl(innen, KERN_R, decke - boden, Vector3(0, (boden + decke) * 0.5, 0), weiss, 40)
	_aufzugstuer(innen, boden, KERN_R)
	RaumBau.licht(innen, Vector3(0, decke - 0.5, 6.0), "ffe6c4", 1.4, 12.0)
	RaumBau.licht(innen, Vector3(0, decke - 0.5, -6.0), "ffe6c4", 1.4, 12.0)
	var raum := {"poly": RaumBau.kreis(r - 0.8, 48), "rechtecke": [], "kreise": [[Vector2.ZERO, KERN_R]], "boden": boden}
	var st := [{"art": "aufzug", "name": "Aufzug", "hinweis": "E: Aufzug", "pos": Vector2(0, KERN_R + 1.6), "ziel": Vector2.ZERO}]
	# Bar und Laden: Theken quer zur Blickrichtung nach außen (Winkel 30° bzw. 150°)
	st.append(_theke_ring(innen, boden, deg_to_rad(30.0), "gipfel", "Gipfel-Bar", "E: Gipfel-Bar", "character-male-b", "ffc531", raum))
	st.append(_theke_ring(innen, boden, deg_to_rad(150.0), "exklusiv", "Exklusiv-Möbel", "E: Exklusiv-Möbel ansehen", "character-female-a", "b36bff", raum))
	var ids := []
	for id in Wirtschaft.GEGENSTAENDE:
		if Wirtschaft.GEGENSTAENDE[id].quelle == "exklusiv":
			ids.append(id)
	for j in ids.size():
		var a := deg_to_rad(-60.0 - 35.0 * j)
		var p := Vector2(cos(a), sin(a)) * 7.8
		RaumBau.zyl(innen, 1.2, 0.25, Vector3(p.x, boden + 0.125, p.y), weiss, 32)
		var n := Moebel.modell(ids[j])
		n.position = Vector3(p.x, boden + 0.25, p.y)
		n.rotation.y = -a + PI * 0.5
		innen.add_child(n)
		raum.kreise.append([p, 1.2])
	RaumBau.schrift(innen, "800 m", Vector3(0, decke - 0.8, -KERN_R - 0.02), PI, 110, 0.006, Color("e8f1fa"))
	etagen[e.id] = {"id": e.id, "name": e.name, "boden": boden, "raum": raum, "ankunft": Vector2(0, KERN_R + 1.6), "yaw": PI,
		"band": Vector2(-1, -1), "knoten": innen, "stationen": st, "meter": meter(e)}

func _theke_ring(k: Node3D, boden: float, a: float, art: String, name: String, hinweis: String, figur: String, farbe: String, raum: Dictionary) -> Dictionary:
	var d := Vector2(cos(a), sin(a))
	var mitte := d * 8.0
	var t := Node3D.new()
	t.position = Vector3(mitte.x, boden, mitte.y)
	t.rotation.y = atan2(d.x, d.y)
	k.add_child(t)
	RaumBau.box(t, Vector3(4.0, 1.1, 0.7), Vector3(0, 0.55, 0), Bau.matt("2c2420", 0.45))
	RaumBau.box(t, Vector3(4.2, 0.07, 0.9), Vector3(0, 1.13, 0), Bau.matt("f4f1ec", 0.15))
	var lm := RaumBau.leuchte(farbe, 1.8)
	_leucht.append(lm)
	RaumBau.box(t, Vector3(4.0, 0.06, 0.04), Vector3(0, 0.25, -0.37), lm)
	RaumBau.modell(t, "leute/" + figur, Vector3(1.2, 0, 1.1), 2.5, PI)
	RaumBau.schrift(t, name.to_upper(), Vector3(0, 1.6, -0.36), PI, 60, 0.006, Color(farbe))
	raum.rechtecke.append(_rect_um(mitte, d, Vector2(2.2, 0.5)))
	raum.rechtecke.append(_rect_um(d * 9.1, d, Vector2(1.0, 0.5)))
	return {"art": art, "name": name, "hinweis": hinweis, "pos": d * 6.2, "ziel": mitte}
