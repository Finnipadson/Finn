class_name Grundstuecke
extends Node3D
# Leere Grundstücke (19.11.2026, Wunsch des Users: „überall leer stehende Grundstücke“). Die Stadt lässt Felder ohne Haus
# frei (Welt.leere_felder). Jedes freie Feld bekommt zufällig – mit festem Startwert, also für alle Mitspieler gleich –
# eine Nutzung im Stil der Stadt: Parkplatz, kleiner Park, Park mit Teich, Baustelle (oft mit Kran), Sandbrache,
# Sportplatz und einmal ein Riesenrad. Nachbarfelder bekommen nie dieselbe Nutzung.
# Den Bodenbelag (Asphalt mit Strichen, Rasen mit Wegen, Sand, Spielfeld, Platten) malt der Boden-Shader aus einer kleinen
# Datentextur (kein Flackern übereinanderliegender Flächen, kostet fast nichts). Darauf stehen einfache Kisten, Zylinder
# und Kugeln in wenigen MultiMeshes (Farbe je Instanz, Farben aus der Stadt), Kleinteile in Kacheln mit Sichtweite.
# Palmen, Büsche, Bänke und Mülleimer zeichnet StadtDetails mit (gleiche Modelle, Palmen bekommen dort ihre Bodenleuchte).

enum Typ {LEER, PARKPLATZ, PARK, BAUSTELLE, BRACHE, SPORT, RIESENRAD, TEICH}
const NAMEN := ["leer", "Parkplatz", "Park", "Baustelle", "Brache", "Sportplatz", "Riesenrad", "Teich"]
const HALB := 28.0            # nutzbare halbe Breite (Feld 75 m − Straße − Bordstein − 2,3 m Gehweg)
const RASTER := 75.0
const N := 41                 # Datentextur: Felder −1500 … 1500 m je Achse
const MAX_D := 1350.0
const KACHEL := 500.0
const AUTO_KACHEL := 250.0   # kleiner, damit die kurze Sichtweite der Autos genau greift
const KLEIN_WEIT := 1100.0    # Kleinteile (Zaunplanen, Bäume, Container …) bis hier sichtbar
const FEIN_WEIT := 420.0      # dünne Teile (Zaunstangen, Gitter, Seile) – weiter weg wären sie kleiner als ein Bildpunkt
const AUTO_WEIT := 380.0     # geparkte Autos (Messung 19.11.: sie kosteten am meisten)
const BAUM_WEIT := 750.0     # Bäume mit Schatten
const NAH_WEIT := 380.0       # Kran-Gitter / Riesenrad-Speichen: nah als Gitter, dahinter als einfache Form
const AUTO_MODELLE := ["sedan", "suv", "suv-luxury", "sedan-sports", "hatchback-sports", "van", "taxi"]
const AUTO_ANTEIL := [26, 18, 14, 8, 8, 8, 6]
const BETON := Color("b9b4aa")
const STEIN := Color("d6d0c4")
const GELB := Color("e3b52c")
const DUNKEL := Color("3a3e45")
const BAUM_GRUEN := [Color("4f7d3a"), Color("5b8a42"), Color("47723a"), Color("628f48")]
const SCHILD_NAMEN := ["Palm Residences", "Oasis Tower", "Dünenblick Living", "Sky Garden", "Marina Lofts", "Wüstenrose Plaza", "Sonnenhof", "Azure Heights", "Lagune Office Park", "Goldsand Suites"]

var welt: Welt
var rng := RandomNumberGenerator.new()
var felder: Array = []        # {mitte: Vector2, typ, dreh 0–3, var 0/1, d}
var zahl := {}                # Typ -> Anzahl
var palmen: Array = [[], []]  # Transform3D – gehen an StadtDetails
var buesche: Array = []
var baenke: Array = []
var eimer: Array = []
var _haeuser: Array = []      # [Rect2, Höhe]: Rohbauten, Kräne, Riesenrad (Kollision zu Fuß / Jetpack)
var _teile := {}              # "form|kat|kx|kz" -> [[Transform3D, Color]]
var _autos := {}              # Vector2i Kachel -> Array je Modell von [Transform3D, Color]
var _lichter: Array = []      # rote Warnlichter (Kräne)
var _kraene: Array = []       # {ausleger: Node3D, basis: float, phase: float}
var _rad: Node3D              # Riesenrad (dreht sich), Gondeln als MultiMesh
var _rad_mm: MultiMesh
var _rad_info := {}
var _zeit := 0.0
var _mat: StandardMaterial3D
var bodenlicht: Bodenlicht
var _formen := {}

# Baumkronen + Büsche (Wunsch des Users 19.11.: „der Baum braucht eine neue Textur“): Low-Poly-Facetten wie die
# Kenney-Modelle, Blätterbüschel als Zellmuster (Ränder dunkler, Büschel unterschiedlich hell), unten dunkler, oben
# heller. Muster im Modellraum (bleibt am Baum kleben), in der Ferne zur Mittelfarbe ausgeblendet (kein Flimmern).
const LAUB_SHADER := """
shader_type spatial;
varying vec3 lp;
varying vec3 farbe;
void vertex() {
	lp = VERTEX;
	farbe = pow(COLOR.rgb, vec3(2.2));
}
vec3 h3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}
void fragment() {
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));   // flache Facetten
	NORMAL = dot(fn, VERTEX) > 0.0 ? -fn : fn;               // immer zur Kamera
	vec3 p = lp * 5.5 + farbe * 13.0;
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 h = h3(i + o);
		vec3 r = o + h - f;
		float d = dot(r, r);
		if (d < d1) { d2 = d1; d1 = d; id = h.x; } else if (d < d2) { d2 = d; }
	}
	float rand = sqrt(d2) - sqrt(d1);                    // 0 an der Grenze zweier Büschel
	float fw = length(fwidth(p));
	float nah = 1.0 - smoothstep(0.35, 1.1, fw);
	float fuge = (1.0 - smoothstep(0.0, 0.14 + fw, rand)) * nah;
	vec3 c = farbe * mix(1.0, 0.78 + 0.44 * id, nah);
	c *= 1.0 - 0.22 * fuge;
	c *= mix(0.68, 1.12, smoothstep(-0.45, 0.45, lp.y));  // unten im Schatten der Krone
	ALBEDO = c;
	ROUGHNESS = 0.9;
	BACKLIGHT = c * 0.25;
}
"""
# Baumstamm: Rinde mit senkrechten Furchen und leichten Ringen, Farbe je Instanz
const RINDE_SHADER := """
shader_type spatial;
varying vec3 lp;
varying vec3 farbe;
void vertex() {
	lp = VERTEX;
	farbe = pow(COLOR.rgb, vec3(2.2));
}
float hs(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1, 0)), u.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), u.x), u.y);
}
void fragment() {
	float a = atan(lp.z, lp.x) / 6.2832 + 0.5;
	vec2 q = vec2(a * 10.0, lp.y * 6.0);
	float fw = length(fwidth(q));
	float nah = 1.0 - smoothstep(0.4, 1.2, fw);
	float furche = smoothstep(0.55, 0.9, vn(vec2(q.x * 1.6, q.y * 0.35)));
	float ring = smoothstep(0.75, 0.95, fract(q.y * 1.5 + vn(q) * 0.3));
	vec3 c = farbe * (1.0 - nah * (0.32 * furche + 0.12 * ring)) * mix(1.0, 0.9 + 0.2 * vn(q * 2.0), nah);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
"""
var _laub_mat: ShaderMaterial
var _rinde_mat: ShaderMaterial
var _baum_orte: Array = []   # Vector2 (Layout) der Bäume/Palmen im aktuellen Feld – Mindestabstand
func _platz_frei(l: Vector2, abstand: float) -> bool:
	for q in _baum_orte:
		if l.distance_to(q) < abstand:
			return false
	return true
var _ohne: PackedStringArray = []   # Mess-Schalter --gs-ohne=autos,schatten,schrift,kraene,teile,boden
var _arrays := {}

func baue(w: Welt) -> void:
	welt = w
	rng.seed = 1911
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gs-ohne="):
			_ohne = a.split("=")[1].split(",")
	for m in w.leere_felder:
		var c: Vector2 = m
		var r := Rect2(c - Vector2.ONE * HALB, Vector2.ONE * HALB * 2.0)
		var naechster := Vector2(clampf(0.0, r.position.x, r.end.x), clampf(0.0, r.position.y, r.end.y))
		if c.length() > minf(MAX_D, w.stadt_r - 250.0) or naechster.length() < Welt.PLATZ_R + 6.0 or w._trifft_gebaeude(r, 6.0):
			continue
		if w.see_abstand(c) - r.size.length() * 0.5 < Welt.PROMENADE + 2.0 or w._kuesten_haus(r) != r:
			continue
		felder.append({"mitte": c, "typ": Typ.LEER, "dreh": rng.randi() % 4, "var": rng.randi() % 2, "d": c.length()})
	_typen_waehlen()
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.85
	_mat.vertex_color_is_srgb = true   # Farben wie in den Hex-Werten (sonst blass)
	bodenlicht = Bodenlicht.new()
	bodenlicht.name = "grundstueck_leuchten"
	add_child(bodenlicht)
	for f in felder:
		zahl[f.typ] = zahl.get(f.typ, 0) + 1
		match int(f.typ):
			Typ.PARKPLATZ: _parkplatz(f)
			Typ.PARK: _park(f)
			Typ.TEICH: _teich(f)
			Typ.BAUSTELLE: _baustelle(f)
			Typ.BRACHE: _brache(f)
			Typ.SPORT: _sport(f)
			Typ.RIESENRAD: _riesenrad(f)
	if not "teile" in _ohne:
		_teile_bauen()
	if not "autos" in _ohne:
		_autos_bauen()
	_lichter_bauen()
	if not "licht" in _ohne:
		bodenlicht.fertig()
	if not "boden" in _ohne:
		_textur()
	var t := []
	for k in range(1, NAMEN.size()):
		t.append("%s %d" % [NAMEN[k], zahl.get(k, 0)])
	print("Grundstücke: %d (%s), %d Kräne" % [felder.size(), ", ".join(t), _kraene.size()])

# Farbe auf der Karte (M) je Nutzung
const KARTEN_FARBE := ["d6d0c4", "a3a6aa", "8fc06c", "c9a46c", "e3cf9e", "6f9fb8", "e9e2d2", "8fc06c"]

# Erstes Feld einer Art (nächstes am Turm) – für Testbilder
func erstes(typ: int) -> Dictionary:
	var best := {}
	for f in felder:
		if f.typ == typ and f.d > 180.0 and (best.is_empty() or f.d < best.d):
			best = f
	return best

func an_details(d: StadtDetails) -> void:
	if "details" in _ohne:
		return
	d.palmen_xf[0].append_array(palmen[0])
	d.palmen_xf[1].append_array(palmen[1])
	d.busch_xf.append_array(buesche)
	d.bank_xf.append_array(baenke)
	d.eimer_xf.append_array(eimer)

func haeuser_eintragen() -> void:
	for h in _haeuser:
		welt.haeuser.append(h[0])
		welt.haeuser_hoehe.append(h[1])

func _process(dt: float) -> void:
	_zeit += dt
	for k in _kraene:
		(k.ausleger as Node3D).rotation.y = float(k.basis) + 0.9 * sin(_zeit * 0.045 + float(k.phase))
	if _rad:
		_rad_drehen()

# ---------------------------------------------------------------- Auswahl
func _ij(c: Vector2) -> Vector2i:
	return Vector2i(roundi(c.x / RASTER) + 20, roundi(c.y / RASTER) + 20)

func _typen_waehlen() -> void:
	var index := {}
	for i in felder.size():
		index[_ij(felder[i].mitte)] = i
	var kand: Array = []   # Riesenrad: einmal, 220–650 m vom Turm (von der Gondel aus gut zu sehen)
	for i in felder.size():
		if felder[i].d > 220.0 and felder[i].d < 650.0:
			kand.append(i)
	if not kand.is_empty():
		felder[kand[rng.randi() % kand.size()]].typ = Typ.RIESENRAD
	var teiche := 0
	for f in felder:
		if f.typ != Typ.LEER:
			continue
		var d: float = f.d
		var gew := {
			Typ.PARKPLATZ: 3.0 if d < 1000.0 else 1.5,
			Typ.PARK: 3.0 if d < 800.0 else (1.2 if d < 1000.0 else 0.3),
			Typ.BAUSTELLE: 2.0 if d < 1000.0 else 2.5,
			Typ.BRACHE: 1.0 if d < 500.0 else (3.0 if d < 1000.0 else 4.5),
			Typ.SPORT: 1.3 if d < 1000.0 else 0.2,
			Typ.TEICH: 1.0 if d < 900.0 and teiche < 6 else 0.0,
		}
		for nb in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var j: int = index.get(_ij(f.mitte) + nb, -1)
			if j >= 0 and gew.has(felder[j].typ):
				gew[felder[j].typ] = 0.0
		var summe := 0.0
		for k in gew:
			summe += float(gew[k])
		var wahl := Typ.BRACHE
		var x := rng.randf() * summe
		for k in gew:
			x -= float(gew[k])
			if x < 0.0 and float(gew[k]) > 0.0:
				wahl = k
				break
		f.typ = wahl
		if wahl == Typ.TEICH:
			teiche += 1

func _textur() -> void:
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for f in felder:
		var ij := _ij(f.mitte)
		if ij.x >= 0 and ij.y >= 0 and ij.x < N and ij.y < N:
			img.set_pixel(ij.x, ij.y, Color8(int(f.typ), int(f.dreh), 255 if int(f.var) == 1 else 0, 255))
	welt.boden_mat.set_shader_parameter("felder", ImageTexture.create_from_image(img))

# ---------------------------------------------------------------- Lage im Feld (Layout-Koordinaten wie im Boden-Shader)
func _w(f: Dictionary, l: Vector2) -> Vector2:   # Richtung Layout → Welt (Umkehrung der Drehung im Shader)
	match int(f.dreh):
		1: return Vector2(-l.y, l.x)
		2: return -l
		3: return Vector2(l.y, -l.x)
	return l

func _pos(f: Dictionary, l: Vector2, y := 0.0) -> Vector3:
	var p: Vector2 = f.mitte + _w(f, l)
	return Vector3(p.x, y, p.y)

func _gier(f: Dictionary, gl := 0.0) -> float:   # Drehwinkel um Y: Layout-Winkel + Felddrehung
	return gl - float(f.dreh) * PI * 0.5

func _rect(f: Dictionary, l: Vector2, groesse: Vector2) -> Rect2:   # Layout-Rechteck → Welt-Rect2
	var g := groesse if int(f.dreh) % 2 == 0 else Vector2(groesse.y, groesse.x)
	var p: Vector2 = f.mitte + _w(f, l)
	return Rect2(p - g * 0.5, g)

func _teil(form: String, kat: String, xf: Transform3D, farbe: Color) -> void:
	var k := "%s|%s|%d|%d" % [form, kat, floori(xf.origin.x / KACHEL), floori(xf.origin.z / KACHEL)]
	if not _teile.has(k):
		_teile[k] = []
	_teile[k].append([xf, farbe])

func _box(kat: String, f: Dictionary, l: Vector2, y: float, g: Vector3, farbe: Color, gl := 0.0) -> void:
	_teil("box", kat, Transform3D(Basis(Vector3.UP, _gier(f, gl)) * Basis.from_scale(g), _pos(f, l, y + g.y * 0.5)), farbe)

func _zyl(kat: String, f: Dictionary, l: Vector2, y: float, r: float, h: float, farbe: Color) -> void:
	_teil("zyl", kat, Transform3D(Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), _pos(f, l, y + h * 0.5)), farbe)

func _kugel(kat: String, f: Dictionary, l: Vector2, y: float, g: Vector3, farbe: Color) -> void:
	_teil("kugel", kat, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(g), _pos(f, l, y)), farbe)

func _baum(f: Dictionary, l: Vector2) -> void:
	var s := rng.randf_range(0.8, 1.25)
	_zyl("baum", f, l, 0.0, 0.22 * s, 3.2 * s, Color("7a5a3c"))
	var gr: Color = BAUM_GRUEN[rng.randi() % BAUM_GRUEN.size()]
	_kugel("baum", f, l, 4.6 * s, Vector3(4.4, 4.0, 4.4) * s, gr)
	_kugel("baum", f, l + Vector2(0.7, -0.5) * s, 5.7 * s, Vector3(2.8, 2.6, 2.8) * s, gr.lightened(0.06))
	welt.hindernisse.append(_rect(f, l, Vector2(0.7, 0.7)))

func _palme(f: Dictionary, l: Vector2) -> void:
	var s := rng.randf_range(2.3, 3.0)
	var p := _pos(f, l)
	palmen[0 if rng.randf() < 0.55 else 1].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
	welt.hindernisse.append(_rect(f, l, Vector2(0.9, 0.9)))

# Busch: zwei flache Kugeln (Messung 19.11.: ~1.700 Kenney-Büsche mit Schatten kosteten ~4 % → eigene einfache Form ohne Schatten)
const BUSCH_GRUEN := [Color("3f6a2e"), Color("4a7a35"), Color("55803a")]
func _busch(f: Dictionary, l: Vector2, s := 2.5) -> void:
	var d := s * 0.5 * rng.randf_range(0.8, 1.2)
	var gr: Color = BUSCH_GRUEN[rng.randi() % BUSCH_GRUEN.size()]
	_kugel("busch", f, l, d * 0.3, Vector3(d, d * 0.75, d), gr)
	_kugel("busch", f, l + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4)) * d, d * 0.42, Vector3(d, d * 0.7, d) * 0.7, gr.lightened(0.05))

func _bank(f: Dictionary, l: Vector2, blick_l: Vector2) -> void:   # blick_l = Blickrichtung der Sitzenden (Layout)
	var b := _w(f, blick_l)
	baenke.append(Transform3D(Basis.looking_at(Vector3(b.x, 0, b.y), Vector3.UP), _pos(f, l)))
	welt.hindernisse.append(_rect(f, l, Vector2(1.6, 1.6)))

func _eimer(f: Dictionary, l: Vector2) -> void:
	eimer.append(Transform3D(Basis.IDENTITY, _pos(f, l)))
	welt.hindernisse.append(_rect(f, l, Vector2(0.6, 0.6)))

# ---------------------------------------------------------------- Parkplatz
# Sechs Reihen à 17 Stellplätze (2,6 × 5 m) wie im Shader, Einfahrt rechts, hinten ein Grünstreifen mit Büschen.
const REIHEN := [[-25.0, -1.0], [-13.5, 1.0], [-8.5, -1.0], [3.0, 1.0], [8.0, -1.0], [19.5, 1.0]]   # [Mitte z, Nase ±z]
func _parkplatz(f: Dictionary) -> void:
	var belegt := rng.randf_range(0.3, 0.75)
	var summe := 0
	for a in AUTO_ANTEIL:
		summe += a
	for r in REIHEN:
		var x0 := INF
		var x1 := -INF
		for k in 17:
			if rng.randf() > belegt:
				continue
			var x := -26.0 + 1.3 + k * 2.6
			var l := Vector2(x + rng.randf_range(-0.12, 0.12), float(r[0]) + float(r[1]) * rng.randf_range(0.0, 0.35))
			var wahl := rng.randi_range(0, summe - 1)
			var m := 0
			while wahl >= AUTO_ANTEIL[m]:
				wahl -= AUTO_ANTEIL[m]
				m += 1
			var farbe := Color(Verkehr.LACKE[rng.randi() % Verkehr.LACKE.size()]) if AUTO_MODELLE[m] != "taxi" else Color(1, 1, 1, 0)
			var gl := (0.0 if float(r[1]) > 0.0 else PI) + rng.randf_range(-0.04, 0.04)
			var xf := Transform3D(Basis(Vector3.UP, _gier(f, gl)).scaled(Vector3.ONE * Verkehr.MASS), _pos(f, l))
			var kk := Vector2i(floori(xf.origin.x / AUTO_KACHEL), floori(xf.origin.z / AUTO_KACHEL))
			if not _autos.has(kk):
				var leer := []
				for i in AUTO_MODELLE.size():
					leer.append([])
				_autos[kk] = leer
			_autos[kk][m].append([xf, farbe])
			x0 = minf(x0, x - 1.3)
			x1 = maxf(x1, x + 1.3)
		if x1 > x0:   # eine Kollisions-Box je Reihe (statt je Auto)
			welt.hindernisse.append(_rect(f, Vector2((x0 + x1) * 0.5, float(r[0])), Vector2(x1 - x0, 4.6)))
	# Kassenautomat + „P“-Schild an der Einfahrt, Büsche + Leuchten im Grünstreifen
	_box("klein", f, Vector2(24.5, -8.0), 0.0, Vector3(0.7, 1.7, 0.5), Color("8a929c"))
	_box("klein", f, Vector2(24.5, -8.0), 1.2, Vector3(0.5, 0.3, 0.52), Color("2f5f9e"))
	_box("fein", f, Vector2(26.6, 1.8), 0.0, Vector3(0.12, 3.2, 0.12), Color("9aa3ad"))
	_box("klein", f, Vector2(26.6, 1.8), 3.0, Vector3(1.3, 1.3, 0.12), Color("2f5f9e"), PI * 0.5)
	_schrift(f, Vector2(26.68, 1.8), 3.65, "P", 0.5 * PI, 96, Color.WHITE)
	welt.hindernisse.append(_rect(f, Vector2(24.5, -8.0), Vector2(0.8, 0.8)))
	var x := -24.0
	while x < 23.0:
		_busch(f, Vector2(x + rng.randf_range(-0.6, 0.6), 25.4), 3.0)
		if int(x) % 16 == 0:   # drei Leuchten je Parkplatz (nachts viele Lichtkreise kosten Füllrate)
			bodenlicht.leuchte(_pos(f, Vector2(x + 2.0, 23.6)), 1.4)
		x += 4.0

# ---------------------------------------------------------------- Park
func _auf_weg(f: Dictionary, l: Vector2) -> bool:
	if l.length() < 9.5 or HALB - maxf(absf(l.x), absf(l.y)) < 5.2:
		return true
	if int(f.var) == 0:
		return absf(l.x) < 3.0 or absf(l.y) < 3.0
	return absf(l.x - l.y) * 0.7071 < 3.0 or absf(l.x + l.y) * 0.7071 < 3.0

func _park(f: Dictionary) -> void:
	# Brunnen in der Mitte: Steinbecken, Wasser, Säule mit Schale
	_zyl("gross", f, Vector2.ZERO, 0.0, 3.2, 0.55, STEIN)
	_zyl("klein", f, Vector2.ZERO, 0.0, 2.85, 0.5, Color("5b9bb0"))
	_zyl("klein", f, Vector2.ZERO, 0.0, 0.35, 1.6, STEIN)
	_zyl("klein", f, Vector2.ZERO, 1.45, 0.95, 0.22, STEIN)
	welt.hindernisse.append(_rect(f, Vector2.ZERO, Vector2(6.4, 6.4)))
	# Bänke rund um den Platz (zwischen den Wegen), Blick zum Brunnen
	var w0 := PI * 0.25 if int(f.var) == 0 else 0.0
	for k in 4:
		var a := w0 + k * PI * 0.5
		var d := Vector2(cos(a), sin(a))
		_bank(f, d * 8.2, -d)
		if k % 2 == 0:
			_eimer(f, d * 8.4 + Vector2(-d.y, d.x) * 1.6)
	# Bäume und Palmen auf dem Rasen, Büsche am Rand
	var n := 0
	var versuche := 0
	_baum_orte.clear()
	while n < 16 and versuche < 160:
		versuche += 1
		var l := Vector2(rng.randf_range(-22.0, 22.0), rng.randf_range(-22.0, 22.0))
		if _auf_weg(f, l) or not _platz_frei(l, 6.5):   # Mindestabstand (Bild des Users: Palme wuchs durch einen Baum)
			continue
		_baum_orte.append(l)
		if rng.randf() < 0.15:   # wenige Palmen (teuer), meist runde Bäume
			_palme(f, l)
		else:
			_baum(f, l)
		n += 1
	for k in 10:
		var l := Vector2(rng.randf_range(-21.0, 21.0), rng.randf_range(-21.0, 21.0))
		if not _auf_weg(f, l) and _platz_frei(l, 3.5):
			_busch(f, l, rng.randf_range(2.6, 4.0))
	# Leuchten an den Wegen
	for k in 4:
		var a := w0 + PI * 0.25 + k * PI * 0.5
		bodenlicht.leuchte(_pos(f, Vector2(cos(a), sin(a)) * 7.6), 1.6)

# ---------------------------------------------------------------- Park mit Teich
func _teich(f: Dictionary) -> void:
	var rx := 14.0
	var rz := 11.0
	var innen := PackedVector2Array()
	var aussen := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		innen.append(Vector2(cos(a) * rx, sin(a) * rz))
		aussen.append(Vector2(cos(a) * (rx + 0.7), sin(a) * (rz + 0.7)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m := _pos(f, Vector2.ZERO, 0.32)
	for i in innen.size():
		var a := _pos(f, innen[i], 0.32)
		var b := _pos(f, innen[(i + 1) % innen.size()], 0.32)
		st.set_normal(Vector3.UP)
		for v in _vorn(m, a, b):
			st.add_vertex(v)
	var wasser := MeshInstance3D.new()
	wasser.mesh = st.commit()
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shader/wasser.gdshader")
	wasser.material_override = wm
	wasser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wasser)
	var kante := SurfaceTool.new()
	kante.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.5
	for i in innen.size():
		var j := (i + 1) % innen.size()
		var i0 := _pos(f, innen[i])
		var i1 := _pos(f, innen[j])
		var a0 := _pos(f, aussen[i])
		var a1 := _pos(f, aussen[j])
		var raus := (a0 - i0).normalized()
		var hy := Vector3.UP * h
		_viereck(kante, i0 + hy, i1 + hy, a1 + hy, a0 + hy, Vector3.UP)
		_viereck(kante, a0 + hy, a1 + hy, a1, a0, raus)
		_viereck(kante, i1 + hy, i0 + hy, i0, i1, -raus)
	var km := MeshInstance3D.new()
	km.mesh = kante.commit()
	km.material_override = Bau.matt("ddd2bd", 0.75)
	add_child(km)
	welt.hindernisse.append(_rect(f, Vector2.ZERO, Vector2(rx * 1.6, rz * 1.6)))
	# Seerosen, Enten
	for k in 7:
		var a := rng.randf() * TAU
		var l := Vector2(cos(a) * rx, sin(a) * rz) * rng.randf_range(0.55, 0.85)
		_zyl("klein", f, l, 0.33, rng.randf_range(0.35, 0.6), 0.03, Color("3f6a2e"))
	for k in 4:
		var a := rng.randf() * TAU
		var l := Vector2(cos(a) * rx, sin(a) * rz) * rng.randf_range(0.2, 0.6)
		var gl := rng.randf() * TAU
		_box("klein", f, l, 0.3, Vector3(0.28, 0.2, 0.42), Color("f2f2ee"), gl)
		_box("klein", f, l + Vector2(sin(gl), cos(gl)) * 0.18, 0.45, Vector3(0.14, 0.16, 0.16), Color("2f6b3a"), gl)
	# Bänke am Weg (Blick zum Wasser), Bäume außen herum und in den Ecken
	for k in 6:
		var a := TAU * (k + 0.5) / 6.0
		var d := Vector2(cos(a), sin(a))
		var l := Vector2(d.x * 21.3, d.y * 18.3)
		if absf(l.y) < 3.0 or absf(l.x) < 3.0:
			continue
		_bank(f, l, -d)
	var n := 0
	var versuche := 0
	_baum_orte.clear()
	while n < 12 and versuche < 160:
		versuche += 1
		var l := Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-24.0, 24.0))
		var r := (l / Vector2(19.5, 16.5)).length()
		if r < 1.25 or absf(l.x) < 3.0 or absf(l.y) < 3.0 or HALB - maxf(absf(l.x), absf(l.y)) < 2.5 or not _platz_frei(l, 6.5):
			continue
		_baum_orte.append(l)
		if rng.randf() < 0.2:
			_palme(f, l)
		else:
			_baum(f, l)
		n += 1
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		bodenlicht.leuchte(_pos(f, Vector2(cos(a) * 21.0, sin(a) * 18.0)), 1.5)

# Dreieck mit Vorderseite nach oben (Godot: Vorderseite im Uhrzeigersinn von oben gesehen)
func _vorn(a: Vector3, b: Vector3, c: Vector3) -> Array:
	return [a, b, c] if (b - a).cross(c - a).y < 0.0 else [a, c, b]

func _viereck(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	for tri in [[a, b, c], [a, c, d]]:
		var p0: Vector3 = tri[0]
		var p1: Vector3 = tri[1]
		var p2: Vector3 = tri[2]
		var ord := [p0, p1, p2] if (p1 - p0).cross(p2 - p0).dot(n) < 0.0 else [p0, p2, p1]
		for v in ord:
			st.set_normal(n)
			st.add_vertex(v)

# ---------------------------------------------------------------- Baustelle
func _baustelle(f: Dictionary) -> void:
	# Bauzaun ringsum (grüne Planen an hellen Pfosten, Betonfüße), Tor rechts
	for seite in 4:
		var k := -26.25
		while k < 26.3:
			var l: Vector2
			var gl := 0.0
			match seite:
				0: l = Vector2(k, -27.4)
				1: l = Vector2(k, 27.4)
				2:
					l = Vector2(-27.4, k)
					gl = PI * 0.5
				_:
					l = Vector2(27.4, k)
					gl = PI * 0.5
			k += 3.5
			if seite == 3 and absf(l.y) < 5.0:
				continue
			_box("klein", f, l, 0.15, Vector3(3.45, 1.85, 0.05), Color("4f6b57"), gl)
			_box("klein", f, l, 0.0, Vector3(0.6, 0.15, 0.25), BETON, gl)
	_rand_kollision(f, 27.4, 5.0)
	# Rohbau: Betondecken, Stützen, Treppenkern; untere Geschosse schon verglast
	var stock := rng.randi_range(2, 9)
	var bx := 30.0
	var bz := 22.0
	var bm := Vector2(-6.0, -5.0)
	for e in stock + 1:
		var y := e * 3.5
		var teil := e == stock   # oberste Ebene: nur halbe Decke (wird gerade gebaut)
		var dx := bx * (0.5 if teil else 1.0)
		var dm := bm + Vector2(-bx * 0.25 if teil else 0.0, 0.0)
		_box("gross", f, dm, y, Vector3(dx, 0.35, bz), BETON.darkened(0.04))
		if e == stock:
			break
		var verglast := e < stock - 2
		for ix in 5:
			for iz in 4:
				var l := bm + Vector2(-bx * 0.5 + 0.4 + ix * (bx - 0.8) / 4.0, -bz * 0.5 + 0.4 + iz * (bz - 0.8) / 3.0)
				if verglast and ix > 0 and ix < 4 and iz > 0 and iz < 3:
					continue
				_box("gross", f, l, y + 0.35, Vector3(0.5, 3.15, 0.5), BETON)
		if verglast:
			var gc := Color("6d8aa3")
			_box("gross", f, bm + Vector2(0, -bz * 0.5 + 0.1), y + 0.6, Vector3(bx - 1.0, 2.6, 0.1), gc)
			_box("gross", f, bm + Vector2(0, bz * 0.5 - 0.1), y + 0.6, Vector3(bx - 1.0, 2.6, 0.1), gc)
			_box("gross", f, bm + Vector2(-bx * 0.5 + 0.1, 0), y + 0.6, Vector3(0.1, 2.6, bz - 1.0), gc)
			_box("gross", f, bm + Vector2(bx * 0.5 - 0.1, 0), y + 0.6, Vector3(0.1, 2.6, bz - 1.0), gc)
	var kern := bm + Vector2(bx * 0.5 - 4.0, bz * 0.5 - 3.5)
	_box("gross", f, kern, 0.0, Vector3(5.0, stock * 3.5 + 3.2, 4.5), BETON.darkened(0.12))
	_haeuser.append([_rect(f, bm, Vector2(bx, bz)), stock * 3.5 + 3.2])
	# Container der Bauleitung, Toilette, Sandhaufen, Stahlträger
	var cl := Vector2(16.0, 19.0)
	_box("gross", f, cl, 0.0, Vector3(6.1, 2.6, 2.45), Color("e6e6e2"))
	_box("gross", f, cl + Vector2(0, 2.6), 0.0, Vector3(6.1, 2.6, 2.45), Color("3b5f86"))
	_box("gross", f, cl, 2.6, Vector3(6.1, 2.6, 2.45), Color("3b5f86"))
	for wx in [-1.8, 0.0, 1.8]:
		_box("klein", f, cl + Vector2(wx, -1.24), 1.1, Vector3(1.0, 0.8, 0.04), Color("2a3440"))
		_box("klein", f, cl + Vector2(wx, -1.24), 3.7, Vector3(1.0, 0.8, 0.04), Color("2a3440"))
	_haeuser.append([_rect(f, cl + Vector2(0, 1.3), Vector2(6.2, 5.1)), 5.2])
	_box("klein", f, Vector2(23.5, 23.5), 0.0, Vector3(1.2, 2.3, 1.2), Color("2f6fae"))
	welt.hindernisse.append(_rect(f, Vector2(23.5, 23.5), Vector2(1.3, 1.3)))
	for k in rng.randi_range(2, 3):
		var l := Vector2(rng.randf_range(-22.0, 4.0), rng.randf_range(18.0, 23.0))
		var s := rng.randf_range(3.0, 5.0)
		_kugel("klein", f, l, 0.0, Vector3(s * 1.4, s * 0.6, s * 1.2), Color("c9a46c"))
		welt.hindernisse.append(_rect(f, l, Vector2(s, s)))
	for k in 4:
		_box("klein", f, Vector2(8.0, 16.0 + k * 0.45), 0.0 + (k % 2) * 0.0, Vector3(9.0, 0.35, 0.3), Color("8a5a44"))
	welt.hindernisse.append(_rect(f, Vector2(8.0, 16.7), Vector2(9.2, 1.8)))
	if rng.randf() < 0.6:
		_bagger(f, Vector2(-8.0 + rng.randf_range(-4.0, 4.0), 13.5), rng.randf() * TAU)
	if rng.randf() < 0.55:
		_kran(f, bm + Vector2(bx * 0.5 + 4.5, -bz * 0.5 + 2.0), stock * 3.5 + rng.randf_range(16.0, 26.0))

func _rand_kollision(f: Dictionary, r: float, tor: float) -> void:
	welt.hindernisse.append(_rect(f, Vector2(0, -r), Vector2(r * 2.0, 0.4)))
	welt.hindernisse.append(_rect(f, Vector2(0, r), Vector2(r * 2.0, 0.4)))
	welt.hindernisse.append(_rect(f, Vector2(-r, 0), Vector2(0.4, r * 2.0)))
	var lang := r - tor
	welt.hindernisse.append(_rect(f, Vector2(r, -tor - lang * 0.5), Vector2(0.4, lang)))
	welt.hindernisse.append(_rect(f, Vector2(r, tor + lang * 0.5), Vector2(0.4, lang)))

func _bagger(f: Dictionary, l: Vector2, gl: float) -> void:
	var v := Vector2(sin(gl), cos(gl))
	var q := Vector2(v.y, -v.x)
	_box("klein", f, l + q * 1.1, 0.0, Vector3(0.7, 0.75, 3.6), DUNKEL, gl)
	_box("klein", f, l - q * 1.1, 0.0, Vector3(0.7, 0.75, 3.6), DUNKEL, gl)
	_box("klein", f, l, 0.75, Vector3(2.6, 1.1, 3.0), GELB, gl)
	_box("klein", f, l + q * 0.55 + v * 0.4, 1.85, Vector3(1.3, 1.5, 1.4), GELB.darkened(0.05), gl)
	_box("klein", f, l + q * 0.55 + v * 1.12, 2.05, Vector3(1.1, 1.0, 0.04), Color("2a3440"), gl)
	_box("klein", f, l - q * 0.5 + v * 2.6, 1.4, Vector3(0.4, 0.45, 3.6), GELB, gl)   # Ausleger (flach, vereinfacht)
	_box("klein", f, l - q * 0.5 + v * 4.3, 0.0, Vector3(0.9, 1.3, 0.9), DUNKEL, gl)  # Schaufel
	welt.hindernisse.append(_rect(f, l, Vector2(3.6, 3.6)))

# Turmdrehkran: Mast aus Gitter (nah) bzw. Kasten (fern), Ausleger dreht langsam hin und her, rote Lichter oben
func _kran(f: Dictionary, l: Vector2, hoehe: float) -> void:
	if "kraene" in _ohne:
		return
	var kran := Node3D.new()
	kran.position = _pos(f, l)
	add_child(kran)
	var mast_nah := []
	var mast_fern := []
	var b := 1.0   # halbe Mastbreite
	for ecke in [Vector2(-b, -b), Vector2(b, -b), Vector2(b, b), Vector2(-b, b)]:
		mast_nah.append([Transform3D(Basis.from_scale(Vector3(0.22, hoehe, 0.22)), Vector3(ecke.x, hoehe * 0.5, ecke.y)), GELB])
	var y := 2.5
	while y < hoehe:
		for s in 4:
			var basis := Basis(Vector3.UP, s * PI * 0.5)
			var vorn := basis * Vector3(0, 0, b)
			mast_nah.append([Transform3D(basis * Basis.from_scale(Vector3(b * 2.0, 0.14, 0.14)), vorn + Vector3.UP * y), GELB])
			var diag := Basis(Vector3.UP, s * PI * 0.5) * Basis(Vector3.BACK, atan2(2.5, b * 2.0) * (1.0 if s % 2 == 0 else -1.0))
			mast_nah.append([Transform3D(diag * Basis.from_scale(Vector3(sqrt(2.5 * 2.5 + 4.0 * b * b), 0.1, 0.1)), vorn + Vector3.UP * (y - 1.25)), GELB])
		y += 2.5
	mast_fern.append([Transform3D(Basis.from_scale(Vector3(b * 1.8, hoehe, b * 1.8)), Vector3.UP * hoehe * 0.5), GELB.darkened(0.08)])
	_mesh_knoten(kran, mast_nah, 0.0, NAH_WEIT)   # eigene Knoten: Sichtweite je Kran genau (Kräne kosten laut Messung ~0 %)
	_mesh_knoten(kran, mast_fern, NAH_WEIT, 0.0)
	# drehender Oberteil: Kabine, Turmspitze, Ausleger (40 m), Gegenausleger mit Betonballast
	var oben := Node3D.new()
	oben.position = Vector3.UP * hoehe
	kran.add_child(oben)
	var lang := 40.0
	var gegen := 12.0
	var nah := []
	var fern := []
	var fest := []
	fest.append([Transform3D(Basis.from_scale(Vector3(2.4, 2.4, 2.6)), Vector3(0, 1.2, 1.6)), Color("f0eee6")])
	fest.append([Transform3D(Basis.from_scale(Vector3(1.6, 0.5, 2.2)), Vector3(0, 1.4, 2.95)), Color("2a3440")])
	fest.append([Transform3D(Basis.from_scale(Vector3(1.2, 7.0, 1.2)), Vector3(0, 3.5, 0)), GELB])
	fest.append([Transform3D(Basis.from_scale(Vector3(2.4, 2.2, 3.0)), Vector3(0, 0.6, -gegen + 1.6)), BETON])
	fest.append([Transform3D(Basis.from_scale(Vector3(0.5, 0.5, 0.5)), Vector3(0, -0.2, lang * 0.62)), DUNKEL])   # Laufkatze
	for s in [-1.0, 1.0]:
		nah.append([Transform3D(Basis.from_scale(Vector3(0.16, 0.16, lang)), Vector3(s * 0.6, 0.0, lang * 0.5)), GELB])
		nah.append([Transform3D(Basis.from_scale(Vector3(0.16, 0.16, gegen)), Vector3(s * 0.8, 0.0, -gegen * 0.5)), GELB])
	nah.append([Transform3D(Basis.from_scale(Vector3(0.14, 0.14, lang)), Vector3(0, 1.4, lang * 0.5)), GELB])
	var z := 0.0
	while z < lang:
		nah.append([Transform3D(Basis.from_scale(Vector3(1.2, 0.1, 0.1)), Vector3(0, 0.0, z)), GELB])
		nah.append([Transform3D(Basis(Vector3.RIGHT, -atan2(1.4, 2.0)) * Basis.from_scale(Vector3(0.1, 0.1, sqrt(4.0 + 1.96))), Vector3(0, 0.7, z + 1.0)), GELB])
		z += 2.0
	# Abspannseile von der Spitze zu Ausleger und Gegenausleger
	for ziel in [Vector3(0, 0.7, lang * 0.7), Vector3(0, 0.3, -gegen + 0.5)]:
		var von := Vector3(0, 7.0, 0)
		var d: Vector3 = ziel - von
		nah.append([Transform3D(Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT) * Basis.from_scale(Vector3(0.08, 0.08, d.length())), von + d * 0.5), DUNKEL])
	nah.append([Transform3D(Basis.from_scale(Vector3(0.06, hoehe * 0.55, 0.06)), Vector3(0, -hoehe * 0.275, lang * 0.62)), DUNKEL])   # Seil zum Haken
	fern.append([Transform3D(Basis.from_scale(Vector3(1.2, 1.4, lang)), Vector3(0, 0.6, lang * 0.5)), GELB.darkened(0.08)])
	fern.append([Transform3D(Basis.from_scale(Vector3(1.4, 0.6, gegen)), Vector3(0, 0.0, -gegen * 0.5)), GELB.darkened(0.08)])
	_mesh_knoten(oben, fest + nah, 0.0, NAH_WEIT)   # nah: Gitter-Ausleger, fern: einfacher Kasten – je ein Mesh
	_mesh_knoten(oben, fest + fern, NAH_WEIT, 0.0)
	_lichter.append(kran.position + Vector3.UP * (hoehe + 7.4))
	var licht_spitze := Node3D.new()   # Licht an der Auslegerspitze dreht mit
	oben.add_child(licht_spitze)
	licht_spitze.position = Vector3(0, 0.4, lang)
	_kraene.append({"ausleger": oben, "basis": _gier(f, rng.randf() * TAU), "phase": rng.randf() * TAU, "spitze": licht_spitze})
	_haeuser.append([_rect(f, l, Vector2(2.4, 2.4)), hoehe + 8.0])

# ---------------------------------------------------------------- Sandbrache
func _brache(f: Dictionary) -> void:
	for k in rng.randi_range(12, 22):   # trockene Büsche
		var l := Vector2(rng.randf_range(-25.0, 25.0), rng.randf_range(-25.0, 25.0))
		var s := rng.randf_range(1.0, 2.2)
		_kugel("klein", f, l, 0.1, Vector3(1.6, 0.9, 1.5) * s, Color("8a8a52").lerp(Color("6f7a45"), rng.randf()))
	for k in rng.randi_range(3, 6):   # grüne Büsche (Kenney, wie in der Stadt)
		_busch(f, Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-24.0, 24.0)), rng.randf_range(2.5, 4.0))
	for k in rng.randi_range(2, 6):    # Felsbrocken
		var l := Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-24.0, 24.0))
		var s := rng.randf_range(1.2, 2.4)
		_kugel("klein", f, l, 0.0, Vector3(1.5, 0.9, 1.2) * s, Color("a39d92"))
		welt.hindernisse.append(_rect(f, l, Vector2(s, s)))
	for k in rng.randi_range(0, 2):    # Betonblöcke, manchmal gestapelt
		var l := Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0))
		var gl := rng.randf() * PI
		_box("klein", f, l, 0.0, Vector3(1.6, 0.8, 0.8), BETON, gl)
		if rng.randf() < 0.5:
			_box("klein", f, l, 0.8, Vector3(1.6, 0.8, 0.8), BETON.lightened(0.05), gl + 0.2)
		welt.hindernisse.append(_rect(f, l, Vector2(1.8, 1.8)))
	if rng.randf() < 0.5:   # Bauschild „Hier entsteht …“ an der Straßenseite
		var l := Vector2(rng.randf_range(-12.0, 12.0), 25.5)
		for s in [-1.6, 1.6]:
			_box("klein", f, l + Vector2(s, 0), 0.0, Vector3(0.16, 3.4, 0.16), Color("9aa3ad"))
		_box("klein", f, l, 1.7, Vector3(4.6, 2.2, 0.12), Color("f2f0ea"))
		_box("klein", f, l + Vector2(0, 0.07), 1.7, Vector3(4.6, 0.45, 0.02), Color("2f5f9e"))
		var nm: String = SCHILD_NAMEN[rng.randi() % SCHILD_NAMEN.size()]
		_schrift(f, l + Vector2(0, 0.08), 3.4, "Hier entsteht", 0.0, 40, Color("2f5f9e"))
		_schrift(f, l + Vector2(0, 0.08), 2.75, nm, 0.0, 56, Color("27313d"))
		welt.hindernisse.append(_rect(f, l, Vector2(3.6, 0.5)))

func _schrift(f: Dictionary, l: Vector2, y: float, text: String, gl: float, groesse: int, farbe: Color) -> void:
	if "schrift" in _ohne:
		return
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = groesse
	lab.pixel_size = 0.006
	lab.modulate = farbe
	lab.outline_size = 0
	lab.double_sided = false
	lab.position = _pos(f, l, y)
	lab.rotation.y = _gier(f, gl)
	lab.visibility_range_end = 220.0
	add_child(lab)

# ---------------------------------------------------------------- Sportplatz
func _sport(f: Dictionary) -> void:
	for cx in [-9.0, 9.0]:
		for s in [-1.0, 1.0]:   # Korb: Mast hinter der Grundlinie, Ausleger, Brett, Ring
			_box("klein", f, Vector2(cx, s * 14.0), 0.0, Vector3(0.2, 3.5, 0.2), DUNKEL)
			_box("klein", f, Vector2(cx, s * 13.4), 3.3, Vector3(0.12, 0.12, 1.2), DUNKEL)
			_box("klein", f, Vector2(cx, s * 12.8), 2.75, Vector3(1.8, 1.05, 0.06), Color("f2f2f0"))
			_box("klein", f, Vector2(cx, s * 12.5), 3.05, Vector3(0.46, 0.04, 0.46), Color("e0652a"))
			welt.hindernisse.append(_rect(f, Vector2(cx, s * 14.0), Vector2(0.5, 0.5)))
	# Zaun: Pfosten alle 3 m, Gitter als halbdurchsichtige Fläche wirkt teuer → nur Pfosten + zwei Holme (dünn → nah)
	var gruen := Color("2f4a3a")
	for seite in 4:
		var k := -27.0
		while k <= 27.01:
			var l := Vector2(k, -27.2) if seite == 0 else (Vector2(k, 27.2) if seite == 1 else (Vector2(-27.2, k) if seite == 2 else Vector2(27.2, k)))
			if not (seite == 3 and absf(k) < 2.0):
				_box("fein", f, l, 0.0, Vector3(0.09, 3.6, 0.09), gruen)
			k += 3.0
		var quer := seite >= 2
		for hy in [1.2, 3.5]:
			var g := Vector3(0.06, 0.08, 54.4) if quer else Vector3(54.4, 0.08, 0.06)
			var lm := Vector2(0, -27.2) if seite == 0 else (Vector2(0, 27.2) if seite == 1 else (Vector2(-27.2, 0) if seite == 2 else Vector2(27.2, 0)))
			_box("fein", f, lm, hy, g, gruen)
	_rand_kollision(f, 27.2, 2.0)
	_bank(f, Vector2(0.0, -6.0), Vector2(1, 0))
	_bank(f, Vector2(0.0, 6.0), Vector2(-1, 0))
	_eimer(f, Vector2(0.0, 0.0))
	for s in [-1.0, 1.0]:
		bodenlicht.leuchte(_pos(f, Vector2(0.0, s * 20.0)), 2.0)

# ---------------------------------------------------------------- Riesenrad
const RAD_R := 22.0
const RAD_NABE := 26.0
const RAD_GONDELN := 16
const RAD_FARBEN := [Color("d9644f"), Color("e8b33c"), Color("4f93c4"), Color("62a85b"), Color("9b7cc4"), Color("e58aa0")]
const RAD_LICHT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, world_vertex_coords;
global uniform float nacht;
varying vec3 farbe;
void vertex() {
	vec3 mitte = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(CAMERA_POSITION_WORLD - mitte);
	float groesse = max(0.75, dist * 0.003);
	vec3 r = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 u = normalize(INV_VIEW_MATRIX[1].xyz);
	vec2 ecke = vec2(UV.x - 0.5, 0.5 - UV.y);   // aus UV: das Rad ist gedreht, die Quad-Ecken in Weltkoordinaten nicht
	VERTEX = mitte + (r * ecke.x + u * ecke.y) * groesse;
	farbe = COLOR.rgb;
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = 1.0 - smoothstep(0.05, 1.0, d);
	ALBEDO = farbe * a * a * 3.0 * smoothstep(0.25, 0.6, nacht);
}
"""
func _riesenrad(f: Dictionary) -> void:
	# Sockel, Stützen (A-Form je Seite), Achse
	_box("gross", f, Vector2.ZERO, 0.0, Vector3(30.0, 0.45, 9.0), STEIN)
	var weiss := Color("f2f2f0")
	var stuetzen := []
	for sz in [-3.3, 3.3]:
		for sx in [-1.0, 1.0]:
			var unten := Vector3(sx * 12.0, 0.45, sz)
			var oben := Vector3(0, RAD_NABE, sz * 0.9)
			var d := oben - unten
			stuetzen.append([Transform3D(Basis.looking_at(d.normalized(), Vector3.FORWARD) * Basis.from_scale(Vector3(0.7, 0.7, d.length())), unten + d * 0.5), weiss])
		stuetzen.append([Transform3D(Basis.from_scale(Vector3(16.0, 0.5, 0.5)), Vector3(0, 9.0, sz * 0.97)), weiss])
	stuetzen.append([Transform3D(Basis.from_scale(Vector3(0.9, 0.9, 7.6)), Vector3(0, RAD_NABE, 0)), Color("9aa3ad")])
	var gestell := Node3D.new()
	gestell.position = _pos(f, Vector2.ZERO)
	gestell.rotation.y = _gier(f, 0.0)
	add_child(gestell)
	_mesh_knoten(gestell, stuetzen, 0.0, 0.0)
	# Rad (dreht sich um die Achse = lokale Z): zwei Felgen, Innenring, Speichen, Querstreben; nah fein, fern einfacher
	_rad = Node3D.new()
	_rad.position = Vector3(0, RAD_NABE, 0)
	gestell.add_child(_rad)
	var nah := []
	var fern := []
	var seg := 40
	for sz in [-1.5, 1.5]:
		for i in seg:
			var a := TAU * (i + 0.5) / seg
			var lang := TAU * RAD_R / seg + 0.15
			var b := Basis(Vector3.BACK, a + PI * 0.5)
			var p := Vector3(cos(a), sin(a), 0) * RAD_R + Vector3(0, 0, sz)
			nah.append([Transform3D(b * Basis.from_scale(Vector3(lang, 0.45, 0.35)), p), weiss])
			fern.append([Transform3D(b * Basis.from_scale(Vector3(lang, 0.9, 0.7)), p), weiss])
			var li := TAU * RAD_R * 0.55 / seg + 0.1
			nah.append([Transform3D(b * Basis.from_scale(Vector3(li, 0.25, 0.25)), Vector3(cos(a), sin(a), 0) * RAD_R * 0.55 + Vector3(0, 0, sz)), weiss])
		for i in RAD_GONDELN:
			var a := TAU * i / RAD_GONDELN
			var b := Basis(Vector3.BACK, a)
			nah.append([Transform3D(b * Basis.from_scale(Vector3(RAD_R, 0.22, 0.22)), Vector3(cos(a), sin(a), 0) * RAD_R * 0.5 + Vector3(0, 0, sz * 0.8)), weiss])
			fern.append([Transform3D(b * Basis.from_scale(Vector3(RAD_R, 0.6, 0.5)), Vector3(cos(a), sin(a), 0) * RAD_R * 0.5 + Vector3(0, 0, sz * 0.8)), weiss])
	for i in RAD_GONDELN:
		var a := TAU * i / RAD_GONDELN
		nah.append([Transform3D(Basis.from_scale(Vector3(0.3, 0.3, 3.4)), Vector3(cos(a), sin(a), 0) * RAD_R), weiss])
	var nabe := [[Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(3.0, 3.6, 3.0)), Vector3.ZERO), Color("c9ced4"), "zyl"]]
	_mesh_knoten(_rad, nah, 0.0, NAH_WEIT + 200.0)
	_mesh_knoten(_rad, fern, NAH_WEIT + 200.0, 0.0)
	_mesh_knoten(_rad, nabe, 0.0, 0.0)
	# Lichterketten auf den Felgen und Speichen (nachts), drehen mit dem Rad
	var licht := []
	for sz in [-1.75, 1.75]:
		for i in 64:
			var a := TAU * i / 64.0
			licht.append([Vector3(cos(a), sin(a), 0) * RAD_R + Vector3(0, 0, sz), Color(1.0, 0.86, 0.6) if i % 4 != 0 else RAD_FARBEN[int(i / 4.0) % RAD_FARBEN.size()].lightened(0.3)])
		for i in RAD_GONDELN:
			var a := TAU * i / RAD_GONDELN
			for k in range(1, 6):
				licht.append([Vector3(cos(a), sin(a), 0) * RAD_R * k / 6.0 + Vector3(0, 0, sz), Color(1.0, 0.8, 0.55)])
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var lm := MultiMesh.new()
	lm.transform_format = MultiMesh.TRANSFORM_3D
	lm.use_colors = true
	lm.mesh = q
	lm.instance_count = licht.size()
	for i in licht.size():
		lm.set_instance_transform(i, Transform3D(Basis(), licht[i][0]))
		lm.set_instance_color(i, licht[i][1])
	var lmi := MultiMeshInstance3D.new()
	lmi.multimesh = lm
	var sh := Shader.new()
	sh.code = RAD_LICHT_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	lmi.material_override = sm
	lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lmi.custom_aabb = AABB(Vector3(-40, -40, -10), Vector3(80, 80, 20))
	_rad.add_child(lmi)
	# Gondeln (bleiben beim Drehen aufrecht): MultiMesh im Gestell, Lage je Bild neu
	var g := []
	g.append([Transform3D(Basis.from_scale(Vector3(2.1, 1.9, 2.1)), Vector3(0, -2.6, 0)), Color(1, 1, 1)])
	g.append([Transform3D(Basis.from_scale(Vector3(2.16, 0.7, 2.16)), Vector3(0, -2.3, 0)), Color(0.25, 0.3, 0.36)])
	g.append([Transform3D(Basis.from_scale(Vector3(2.3, 0.25, 2.3)), Vector3(0, -1.55, 0)), Color(1, 1, 1)])
	g.append([Transform3D(Basis.from_scale(Vector3(0.12, 1.4, 0.12)), Vector3(0, -0.75, 0)), Color(0.6, 0.62, 0.66)])
	_rad_mm = MultiMesh.new()
	_rad_mm.transform_format = MultiMesh.TRANSFORM_3D
	_rad_mm.use_colors = true
	_rad_mm.mesh = _mesh_aus(g)
	_rad_mm.instance_count = RAD_GONDELN
	for i in RAD_GONDELN:
		_rad_mm.set_instance_color(i, RAD_FARBEN[i % RAD_FARBEN.size()])
	var gmi := MultiMeshInstance3D.new()
	gmi.multimesh = _rad_mm
	gmi.material_override = _mat
	gmi.custom_aabb = AABB(Vector3(-30, -10, -10), Vector3(60, 70, 20))
	gestell.add_child(gmi)
	_rad_info = {"winkel": rng.randf() * TAU}
	_rad_drehen()
	# Kassenhäuschen, Absperrung, Leuchten, Bäume in den Beeten
	_box("gross", f, Vector2(-17.5, 8.0), 0.0, Vector3(4.0, 2.8, 3.0), Color("e6dccb"))
	_box("gross", f, Vector2(-17.5, 8.0), 2.8, Vector3(4.6, 0.35, 3.6), RAD_FARBEN[0])
	_box("klein", f, Vector2(-15.45, 8.0), 1.0, Vector3(0.04, 0.9, 1.6), Color("2a3440"))
	welt.hindernisse.append(_rect(f, Vector2(-17.5, 8.0), Vector2(4.2, 3.2)))
	welt.hindernisse.append(_rect(f, Vector2.ZERO, Vector2(30.0, 9.0)))
	_haeuser.append([_rect(f, Vector2.ZERO, Vector2(2.0 * RAD_R + 3.0, 4.5)), RAD_NABE + RAD_R + 2.5])
	for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_palme(f, s * 25.0)
		_busch(f, s * 25.0 + Vector2(-s.x * 2.5, 0.0), 2.6)
	for k in 6:
		var x := -15.0 + k * 6.0
		bodenlicht.leuchte(_pos(f, Vector2(x, 6.2)), 1.5)
		bodenlicht.leuchte(_pos(f, Vector2(x, -6.2)), 1.5)
	print("Riesenrad bei ", f.mitte)

func _rad_drehen() -> void:
	var w: float = float(_rad_info.winkel) + _zeit * TAU / 240.0   # eine Runde in 4 Minuten
	_rad.rotation.z = w
	for i in RAD_GONDELN:
		var a := w + TAU * i / RAD_GONDELN
		_rad_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(cos(a) * RAD_R, RAD_NABE + sin(a) * RAD_R, 0)))

# ---------------------------------------------------------------- Meshes
func _form(name: String) -> Mesh:
	if _formen.has(name):
		return _formen[name]
	var m: Mesh
	match name:
		"zyl":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 14
			c.rings = 1
			m = c
		"kugel":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 12
			s.rings = 7
			m = s
		_:
			var b := BoxMesh.new()
			b.size = Vector3.ONE
			m = b
	_formen[name] = m
	return m

# Viele Einheits-Formen zu einem Mesh mit Vertexfarben ([Transform3D, Color, Form?])
func _mesh_aus(teile: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in teile:
		var form: String = t[2] if t.size() > 2 else "box"
		if not _arrays.has(form):
			_arrays[form] = _form(form).surface_get_arrays(0)
		var arr: Array = _arrays[form]
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var xf: Transform3D = t[0]
		var nb := xf.basis.inverse().transposed()
		var farbe: Color = t[1]
		for i in idx:
			st.set_color(farbe)
			st.set_normal((nb * n[i]).normalized())
			st.add_vertex(xf * v[i])
	return st.commit()

func _mesh_knoten(eltern: Node3D, teile: Array, von: float, bis: float) -> MeshInstance3D:
	if teile.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_aus(teile)
	mi.material_override = _mat
	if von > 0.0:
		mi.visibility_range_begin = von
		mi.visibility_range_begin_margin = 30.0
	if bis > 0.0:
		mi.visibility_range_end = bis
		mi.visibility_range_end_margin = 30.0
	if von > 0.0 or bis > 0.0:
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	eltern.add_child(mi)
	return mi

func _laub() -> ShaderMaterial:
	if _laub_mat == null:
		var sh := Shader.new()
		sh.code = LAUB_SHADER
		_laub_mat = ShaderMaterial.new()
		_laub_mat.shader = sh
	return _laub_mat

func _rinde() -> ShaderMaterial:
	if _rinde_mat == null:
		var sh := Shader.new()
		sh.code = RINDE_SHADER
		_rinde_mat = ShaderMaterial.new()
		_rinde_mat.shader = sh
	return _rinde_mat

func _teile_bauen() -> void:
	for k in _teile:
		var t: PackedStringArray = (k as String).split("|")
		var liste: Array = _teile[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _form(t[0])
		mm.instance_count = liste.size()
		for i in liste.size():
			mm.set_instance_transform(i, liste[i][0])
			mm.set_instance_color(i, liste[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mat
		if t[1] == "baum" or t[1] == "busch":
			mmi.material_override = _rinde() if t[0] == "zyl" else _laub()
		var weit := 0.0
		match t[1]:
			"klein", "busch": weit = KLEIN_WEIT
			"baum": weit = BAUM_WEIT
			"fein": weit = FEIN_WEIT
		if weit > 0.0:
			mmi.visibility_range_end = weit
			mmi.visibility_range_end_margin = 80.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# Schatten nur für große Teile und Bäume (Messung: Schatten der vielen Kleinteile kosteten 3–8 %)
		var schatten := (t[1] == "gross" or t[1] == "baum") and not "schatten" in _ohne
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if schatten else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

func _autos_bauen() -> void:
	if _autos.is_empty():
		return
	var hilfe := Verkehr.new()
	var tex: Texture2D = load("res://modelle/autos/Textures/colormap.png")
	var bild := tex.get_image()
	var shader: Shader = load("res://shader/auto.gdshader")
	for m in AUTO_MODELLE.size():
		var szene: Node3D = load("res://modelle/autos/%s.glb" % AUTO_MODELLE[m]).instantiate()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for teil in hilfe._meshes(szene, Transform3D.IDENTITY):
			var mesh: Mesh = teil.mesh
			for s in mesh.get_surface_count():
				st.append_from(mesh, s, teil.xf)
		szene.free()
		var mesh := st.commit()
		var sm := ShaderMaterial.new()
		sm.shader = shader
		sm.set_shader_parameter("farben", tex)
		sm.set_shader_parameter("zelle", hilfe._lack_zelle(mesh, bild))
		sm.set_shader_parameter("lichter", 0.0)
		for kk in _autos:
			var liste: Array = _autos[kk][m]
			if liste.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = liste.size()
			for i in liste.size():
				mm.set_instance_transform(i, liste[i][0])
				mm.set_instance_color(i, liste[i][1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = sm
			mmi.visibility_range_end = AUTO_WEIT
			mmi.visibility_range_end_margin = 80.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			if "schatten" in _ohne:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
	hilfe.free()

func _lichter_bauen() -> void:
	for k in _kraene:
		_lichter.append(k.spitze)
	if _lichter.is_empty():
		return
	var sh := Shader.new()
	sh.code = Daecher.LICHT_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var feste: Array = []
	for l in _lichter:
		if l is Vector3:
			feste.append(l)
		else:   # Licht an der Auslegerspitze: eigenes Mini-MultiMesh am drehenden Teil
			var mm1 := MultiMesh.new()
			mm1.transform_format = MultiMesh.TRANSFORM_3D
			mm1.use_custom_data = true
			mm1.mesh = q
			mm1.instance_count = 1
			mm1.set_instance_transform(0, Transform3D())
			mm1.set_instance_custom_data(0, Color(rng.randf(), 0, 0, 0))
			var mi1 := MultiMeshInstance3D.new()
			mi1.multimesh = mm1
			mi1.material_override = m
			mi1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi1.custom_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
			(l as Node3D).add_child(mi1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = feste.size()
	for i in feste.size():
		mm.set_instance_transform(i, Transform3D(Basis(), feste[i]))
		mm.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-3000, -100, -3000), Vector3(6000, 1200, 6000))
	add_child(mmi)
