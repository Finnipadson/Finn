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

enum Typ {LEER, PARKPLATZ, PARK, BAUSTELLE, BRACHE, SPORT, RIESENRAD, TEICH, MARKT, TANKSTELLE, PARKHAUS, SPIELPLATZ, WOCHENMARKT, SKATEPARK, GARTEN, HUNDEWIESE, ZIRKUS, STADION}
const NAMEN := ["leer", "Parkplatz", "Park", "Baustelle", "Brache", "Sportplatz", "Riesenrad", "Teich", "Markt", "Tankstelle", "Parkhaus", "Spielplatz", "Wochenmarkt", "Skatepark", "Garten", "Hundewiese", "Zirkus", "Stadion"]
# Weniger Wiederholung (Wunsch des Users 19.11.2026): nur bis INNEN_D besondere Nutzungen, außen meist normale Häuser;
# Varianten je Art werden gleichmäßig verteilt, manche Arten haben eine Höchstzahl.
const INNEN_D := 900.0
const AUSSEN_HAUS := 0.85      # Anteil der äußeren freien Felder, die ein normales Haus bekommen
const VARIANTEN := {Typ.PARKPLATZ: 3, Typ.PARK: 4, Typ.SPORT: 3, Typ.BAUSTELLE: 3, Typ.BRACHE: 3}
const HOECHSTENS := {Typ.TEICH: 5, Typ.MARKT: 5, Typ.TANKSTELLE: 5, Typ.PARKHAUS: 5, Typ.RIESENRAD: 1, Typ.WOCHENMARKT: 4, Typ.SKATEPARK: 4, Typ.GARTEN: 5, Typ.HUNDEWIESE: 5, Typ.ZIRKUS: 1, Typ.STADION: 1}
const HIGHLIGHTS := [Typ.ZIRKUS, Typ.STADION]   # je einmal, 250–850 m vom Turm, nicht neben einem anderen Highlight
const HALB := 28.0            # nutzbare halbe Breite (Feld 75 m − Straße − Bordstein − 2,3 m Gehweg)
const RASTER := 75.0
const N := 41                 # Datentextur: Felder −1500 … 1500 m je Achse
const MAX_D := 1350.0
const KACHEL := 500.0
const GROSS_KACHEL := 1000.0
const AUTO_KACHEL := 250.0   # kleiner, damit die kurze Sichtweite der Autos genau greift
const KLEIN_WEIT := 700.0    # Kleinteile (Zaunplanen, Bäume, Container …) bis hier sichtbar
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
		if naechster.length() < Welt.PLATZ_R + 6.0 or w._trifft_gebaeude(r, 6.0):
			continue
		if w.see_abstand(c) - r.size.length() * 0.5 < Welt.PROMENADE + 2.0 or w._kuesten_haus(r) != r:
			continue
		if c.length() >= INNEN_D and c.length() <= MAX_D and rng.randf() < AUSSEN_HAUS:   # ganz außen (Stadtrand) bleibt frei wie vorher
			if w.haus_bauen(c, rng):
				zahl[Typ.LEER] = zahl.get(Typ.LEER, 0) + 1
				continue
		if c.length() > minf(MAX_D, w.stadt_r - 250.0):
			continue
		felder.append({"mitte": c, "typ": Typ.LEER, "dreh": rng.randi() % 4, "var": 0, "d": c.length()})
	_typen_waehlen()
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.85
	_mat.vertex_color_is_srgb = true   # Farben wie in den Hex-Werten (sonst blass)
	bodenlicht = Bodenlicht.new()
	bodenlicht.name = "grundstueck_leuchten"
	add_child(bodenlicht)
	var ohne_typ: PackedStringArray = []   # Mess-Schalter --gs-ohne-typ=Garten,Stadion (Art nicht bauen)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gs-ohne-typ="):
			ohne_typ = a.split("=")[1].split(",")
	for f in felder:
		zahl[f.typ] = zahl.get(f.typ, 0) + 1
		if NAMEN[int(f.typ)] in ohne_typ:
			continue
		match int(f.typ):
			Typ.PARKPLATZ: _parkplatz(f)
			Typ.PARK: _park(f)
			Typ.TEICH: _teich(f)
			Typ.BAUSTELLE: _baustelle(f)
			Typ.BRACHE: _brache(f)
			Typ.SPORT: _sport(f)
			Typ.RIESENRAD: _riesenrad(f)
			Typ.MARKT: _markt(f)
			Typ.TANKSTELLE: _tankstelle(f)
			Typ.PARKHAUS: _parkhaus(f)
			Typ.SPIELPLATZ: _spielplatz(f)
			Typ.WOCHENMARKT: _wochenmarkt(f)
			Typ.SKATEPARK: _skatepark(f)
			Typ.GARTEN: _garten(f)
			Typ.HUNDEWIESE: _hundewiese(f)
			Typ.ZIRKUS: _zirkus(f)
			Typ.STADION: _stadion(f)
	_licht_punkte_bauen()
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
	if "--gs-liste" in OS.get_cmdline_user_args():   # Liste aller Grundstücke (für Messorte)
		for f in felder:
			print("GS %s v%d bei %s d=%.0f dreh=%d" % [NAMEN[int(f.typ)], int(f.var), str(f.mitte), float(f.d), int(f.dreh)])
	print("Grundstücke: %d (%s), %d Kräne, %d neue Häuser außen" % [felder.size(), ", ".join(t), _kraene.size(), zahl.get(Typ.LEER, 0)])

# Farbe auf der Karte (M) je Nutzung
const KARTEN_FARBE := ["d6d0c4", "a3a6aa", "8fc06c", "c9a46c", "e3cf9e", "6f9fb8", "e9e2d2", "8fc06c", "e8b86b", "8c96a0", "9aa0a8", "a8d08a", "d9b98a", "c4c4c0", "9cc46a", "b0d48a", "e2483e", "5fae4a"]

# Erstes Feld einer Art (nächstes am Turm) – für Testbilder
func erstes(typ: int, variante := -1) -> Dictionary:
	var best := {}
	for f in felder:
		if f.typ == typ and (variante < 0 or int(f.var) == variante) and f.d > 180.0 and (best.is_empty() or f.d < best.d):
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
	var anzahl := {Typ.RIESENRAD: 1 if not kand.is_empty() else 0}
	for hl in HIGHLIGHTS:   # Zirkus, Stadion: je einmal, mit Abstand zu Riesenrad und einander
		var hk: Array = []
		for i in felder.size():
			var hf: Dictionary = felder[i]
			if hf.typ != Typ.LEER or hf.d < 250.0 or hf.d > 850.0:
				continue
			var frei := true
			for g in felder:
				if g.typ != Typ.LEER and int(g.typ) in [Typ.RIESENRAD, Typ.ZIRKUS, Typ.STADION] and (g.mitte as Vector2).distance_to(hf.mitte) < 3.5 * RASTER:
					frei = false
					break
			if frei:
				hk.append(i)
		if not hk.is_empty():
			felder[hk[rng.randi() % hk.size()]].typ = hl
			anzahl[hl] = 1
	for f in felder:
		if f.typ != Typ.LEER:
			continue
		var d: float = f.d
		var gew := {}
		if d >= INNEN_D:   # außen nur Brachen und Baustellen (die Stadt wächst)
			gew = {Typ.BRACHE: 3.0, Typ.BAUSTELLE: 2.0}
		else:
			gew = {
				Typ.PARKPLATZ: 2.2, Typ.PARK: 2.4, Typ.BAUSTELLE: 1.6, Typ.BRACHE: 0.8 if d < 500.0 else 1.4,
				Typ.SPORT: 1.5, Typ.TEICH: 0.8, Typ.MARKT: 1.0, Typ.TANKSTELLE: 1.0, Typ.PARKHAUS: 1.0, Typ.SPIELPLATZ: 1.2,
				Typ.WOCHENMARKT: 0.9, Typ.SKATEPARK: 0.9, Typ.GARTEN: 0.9, Typ.HUNDEWIESE: 0.9,
			}
		for k in HOECHSTENS:
			if gew.has(k) and anzahl.get(k, 0) >= HOECHSTENS[k]:
				gew[k] = 0.0
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
		anzahl[wahl] = anzahl.get(wahl, 0) + 1
	# Varianten gleichmäßig verteilen: jeweils die bisher seltenste (bei Gleichstand zufällig)
	var benutzt := {}
	for f in felder:
		var nv: int = VARIANTEN.get(int(f.typ), 1)
		if nv <= 1:
			continue
		if not benutzt.has(f.typ):
			var leer := []
			leer.resize(nv)
			leer.fill(0)
			benutzt[f.typ] = leer
		var zl: Array = benutzt[f.typ]
		var wenig: int = zl.min()
		var wahl_v: Array = []
		for i in nv:
			if zl[i] == wenig:
				wahl_v.append(i)
		var v: int = wahl_v[rng.randi() % wahl_v.size()]
		zl[v] += 1
		f.var = v

func _textur() -> void:
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for f in felder:
		var ij := _ij(f.mitte)
		if ij.x >= 0 and ij.y >= 0 and ij.x < N and ij.y < N:
			img.set_pixel(ij.x, ij.y, Color8(int(f.typ), int(f.dreh), int(f.var) * 60, 255))
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
	var ks := KACHEL if kat != "gross" else GROSS_KACHEL   # große Teile haben keine Sichtweite → wenige große Kacheln (weniger Zeichenaufrufe)
	var k := "%s|%s|%d|%d" % [form, kat, floori(xf.origin.x / ks), floori(xf.origin.z / ks)]
	if not _teile.has(k):
		_teile[k] = []
	_teile[k].append([xf, farbe])

func _box(kat: String, f: Dictionary, l: Vector2, y: float, g: Vector3, farbe: Color, gl := 0.0) -> void:
	_teil("box", kat, Transform3D(Basis(Vector3.UP, _gier(f, gl)) * Basis.from_scale(g), _pos(f, l, y + g.y * 0.5)), farbe)

func _zyl(kat: String, f: Dictionary, l: Vector2, y: float, r: float, h: float, farbe: Color) -> void:
	_teil("zyl", kat, Transform3D(Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), _pos(f, l, y + h * 0.5)), farbe)

func _kugel(kat: String, f: Dictionary, l: Vector2, y: float, g: Vector3, farbe: Color) -> void:
	_teil("kugel", kat, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(g), _pos(f, l, y)), farbe)

func _baum(f: Dictionary, l: Vector2, gross := 1.0) -> void:
	var s := rng.randf_range(0.8, 1.25) * gross
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
# Drei Varianten (gleich im Boden-Shader): 0 = Reihen, 1 = Schrägparker (60°), 2 = Reihen mit Baum-Inseln.
# Sechs Reihen wie im Shader, Einfahrt rechts, hinten ein Grünstreifen mit Büschen.
const REIHEN := [[-25.0, -1.0], [-13.5, 1.0], [-8.5, -1.0], [3.0, 1.0], [8.0, -1.0], [19.5, 1.0]]   # [Mitte z, Nase ±z]
var _auto_summe := 0
func _auto_neu(f: Dictionary, l: Vector2, gl: float, y := 0.0) -> void:
	if _auto_summe == 0:
		for a in AUTO_ANTEIL:
			_auto_summe += a
	var wahl := rng.randi_range(0, _auto_summe - 1)
	var m := 0
	while wahl >= AUTO_ANTEIL[m]:
		wahl -= AUTO_ANTEIL[m]
		m += 1
	var farbe := Color(Verkehr.LACKE[rng.randi() % Verkehr.LACKE.size()]) if AUTO_MODELLE[m] != "taxi" else Color(1, 1, 1, 0)
	var xf := Transform3D(Basis(Vector3.UP, _gier(f, gl)).scaled(Vector3.ONE * Verkehr.MASS), _pos(f, l, y))
	var kk := Vector2i(floori(xf.origin.x / AUTO_KACHEL), floori(xf.origin.z / AUTO_KACHEL))
	if not _autos.has(kk):
		var leer := []
		for i in AUTO_MODELLE.size():
			leer.append([])
		_autos[kk] = leer
	_autos[kk][m].append([xf, farbe])

func _parkplatz(f: Dictionary) -> void:
	var v := int(f.var)
	var belegt := rng.randf_range(0.3, 0.75)
	var breite := 3.0 if v == 1 else 2.6
	var anzahl := 15 if v == 1 else 17
	for r in REIHEN:
		var rz := float(r[0])
		var nase := float(r[1])
		var x0 := INF
		var x1 := -INF
		for k in anzahl:
			var x := -26.0 + breite * 0.5 + k * breite
			if v == 2 and k % 6 == 5:   # Baum-Insel (Doppelreihen bekommen einen Baum in der Mitte)
				if rz == -25.0 or rz == 19.5:
					_baum(f, Vector2(x, rz), 0.8)
				elif nase > 0.0:
					_baum(f, Vector2(x, rz + 2.5), 0.9)
				continue
			if rng.randf() > belegt:
				continue
			if v == 1:
				_auto_neu(f, Vector2(x, rz), (PI / 6.0 if nase > 0.0 else PI + PI / 6.0))
			else:
				_auto_neu(f, Vector2(x + rng.randf_range(-0.12, 0.12), rz + nase * rng.randf_range(0.0, 0.35)), (0.0 if nase > 0.0 else PI) + rng.randf_range(-0.04, 0.04))
			x0 = minf(x0, x - breite * 0.5)
			x1 = maxf(x1, x + breite * 0.5)
		if x1 > x0:   # eine Kollisions-Box je Reihe (statt je Auto)
			welt.hindernisse.append(_rect(f, Vector2((x0 + x1) * 0.5, rz), Vector2(x1 - x0, 4.6)))
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
# Varianten: 0 = Wegekreuz + Brunnen, 1 = Diagonalen + Brunnen, 2 = Blumenpark mit Ringweg + Skulptur, 3 = Picknickwiese
func _auf_weg(f: Dictionary, l: Vector2) -> bool:
	var v := int(f.var)
	if v == 3:
		return absf(l.y - 6.0 * sin(l.x * 0.12)) < 3.0 or l.distance_to(Vector2(16.0, -16.0)) < 7.0 or HALB - maxf(absf(l.x), absf(l.y)) < 2.0
	if l.length() < 9.5 or HALB - maxf(absf(l.x), absf(l.y)) < 5.2:
		return true
	if v == 0:
		return absf(l.x) < 3.0 or absf(l.y) < 3.0
	if v == 1:
		return absf(l.x - l.y) * 0.7071 < 3.0 or absf(l.x + l.y) * 0.7071 < 3.0
	return l.length() < 17.0 or absf(l.x) < 3.0 or absf(l.y) < 3.0   # Blumenpark: Bäume nur außen

func _park(f: Dictionary) -> void:
	var v := int(f.var)
	if v <= 1:
		# Brunnen in der Mitte: Steinbecken, Wasser, Säule mit Schale; Bänke dazwischen
		_zyl("gross", f, Vector2.ZERO, 0.0, 3.2, 0.55, STEIN)
		_zyl("klein", f, Vector2.ZERO, 0.0, 2.85, 0.5, Color("5b9bb0"))
		_zyl("klein", f, Vector2.ZERO, 0.0, 0.35, 1.6, STEIN)
		_zyl("klein", f, Vector2.ZERO, 1.45, 0.95, 0.22, STEIN)
		welt.hindernisse.append(_rect(f, Vector2.ZERO, Vector2(6.4, 6.4)))
		var w0 := PI * 0.25 if v == 0 else 0.0
		for k in 4:
			var a := w0 + k * PI * 0.5
			var d := Vector2(cos(a), sin(a))
			_bank(f, d * 8.2, -d)
			if k % 2 == 0:
				_eimer(f, d * 8.4 + Vector2(-d.y, d.x) * 1.6)
			bodenlicht.leuchte(_pos(f, Vector2(cos(a + PI * 0.25), sin(a + PI * 0.25)) * 7.6), 1.6)
	elif v == 2:
		# Skulptur: Sockel + drei gedrehte Würfel (weiß/gold); Bänke außen am Ringweg mit Blick auf die Beete
		_box("gross", f, Vector2.ZERO, 0.0, Vector3(2.4, 0.7, 2.4), STEIN)
		_box("gross", f, Vector2.ZERO, 0.7, Vector3(1.6, 1.6, 1.6), Color("ece8de"), 0.4)
		_box("gross", f, Vector2.ZERO, 2.3, Vector3(1.2, 1.2, 1.2), Color("d4a93c"), 1.1)
		_box("gross", f, Vector2.ZERO, 3.5, Vector3(0.8, 0.8, 0.8), Color("ece8de"), 0.2)
		welt.hindernisse.append(_rect(f, Vector2.ZERO, Vector2(2.6, 2.6)))
		for k in 8:
			var a := PI / 8.0 + k * PI * 0.25
			var d := Vector2(cos(a), sin(a))
			if k % 2 == 0:
				_bank(f, d * 15.7, -d)
			bodenlicht.leuchte(_pos(f, d * 14.0), 1.4)
		_eimer(f, Vector2(15.6, 2.2))
		_eimer(f, Vector2(-15.6, -2.2))
	else:
		# Picknickwiese: großer offener Rasen, Decken, ein Pavillon in der Ecke, wenige große Bäume
		var pv := Vector2(16.0, -16.0)
		_zyl("gross", f, pv, 0.0, 4.6, 0.25, STEIN)
		for k in 8:
			var a := TAU * k / 8.0
			_zyl("klein", f, pv + Vector2(cos(a), sin(a)) * 3.9, 0.25, 0.14, 2.9, Color("f2f2f0"))
		_teil("kegel", "gross", Transform3D(Basis.from_scale(Vector3(10.6, 2.2, 10.6)), _pos(f, pv, 3.15 + 1.1)), Color("d9644f"))
		_bank(f, pv + Vector2(-1.6, 0), Vector2(1, 0))
		_bank(f, pv + Vector2(1.6, 0), Vector2(-1, 0))
		var decken := [Color("d9644f"), Color("4f93c4"), Color("e8b33c"), Color("f2f2ee"), Color("62a85b")]
		for k in rng.randi_range(4, 7):
			var l := Vector2(rng.randf_range(-20.0, 10.0), rng.randf_range(-20.0, 20.0))
			if _auf_weg(f, l):
				continue
			var gl := rng.randf() * PI
			_box("klein", f, l, 0.0, Vector3(2.0, 0.03, 1.6), decken[rng.randi() % decken.size()], gl)
			if rng.randf() < 0.6:
				_box("klein", f, l + Vector2(0.5, 0.3), 0.03, Vector3(0.45, 0.3, 0.3), Color("a8744a"), gl)
	# Bäume und Palmen auf dem Rasen (Mindestabstand), Büsche
	var n := 0
	var versuche := 0
	_baum_orte.clear()
	var ziel := 16 if v <= 1 else (9 if v == 2 else 6)
	while n < ziel and versuche < 160:
		versuche += 1
		var l := Vector2(rng.randf_range(-22.0, 22.0), rng.randf_range(-22.0, 22.0))
		if _auf_weg(f, l) or not _platz_frei(l, 6.5 if v != 3 else 9.0):   # Mindestabstand (Bild des Users: Palme wuchs durch einen Baum)
			continue
		_baum_orte.append(l)
		if v == 3:
			_baum(f, l, rng.randf_range(1.4, 1.7))
		elif rng.randf() < 0.15:   # wenige Palmen (teuer), meist runde Bäume
			_palme(f, l)
		else:
			_baum(f, l)
		n += 1
	for k in (10 if v <= 2 else 4):
		var l := Vector2(rng.randf_range(-21.0, 21.0), rng.randf_range(-21.0, 21.0))
		if not _auf_weg(f, l) and _platz_frei(l, 3.5):
			_busch(f, l, rng.randf_range(2.6, 4.0))

# ---------------------------------------------------------------- Sportplatz
# Varianten: 0 = zwei Basketballfelder, 1 = zwei Tennisplätze (Sand), 2 = Kleinfeld-Fußball
func _sport(f: Dictionary) -> void:
	var v := int(f.var)
	if v == 0:
		for cx in [-9.0, 9.0]:
			for s in [-1.0, 1.0]:   # Korb: Mast hinter der Grundlinie, Ausleger, Brett, Ring
				_box("klein", f, Vector2(cx, s * 14.0), 0.0, Vector3(0.2, 3.5, 0.2), DUNKEL)
				_box("klein", f, Vector2(cx, s * 13.4), 3.3, Vector3(0.12, 0.12, 1.2), DUNKEL)
				_box("klein", f, Vector2(cx, s * 12.8), 2.75, Vector3(1.8, 1.05, 0.06), Color("f2f2f0"))
				_box("klein", f, Vector2(cx, s * 12.5), 3.05, Vector3(0.46, 0.04, 0.46), Color("e0652a"))
				welt.hindernisse.append(_rect(f, Vector2(cx, s * 14.0), Vector2(0.5, 0.5)))
	elif v == 1:
		for cx in [-7.0, 7.0]:   # Netz quer über den Platz: Pfosten, dunkles Netz, weißes Band
			for s in [-1.0, 1.0]:
				_box("klein", f, Vector2(cx + s * 6.4, 0.0), 0.0, Vector3(0.1, 1.07, 0.1), DUNKEL)
				welt.hindernisse.append(_rect(f, Vector2(cx + s * 6.4, 0.0), Vector2(0.3, 0.3)))
			_box("klein", f, Vector2(cx, 0.0), 0.1, Vector3(12.8, 0.82, 0.03), Color("2a3440"))
			_box("klein", f, Vector2(cx, 0.0), 0.9, Vector3(12.8, 0.07, 0.05), Color("f2f2f0"))
			welt.hindernisse.append(_rect(f, Vector2(cx, 0.0), Vector2(12.8, 0.3)))
	else:
		for s in [-1.0, 1.0]:   # Tore: weiße Pfosten + Latte, Netz hinten
			for px in [-2.5, 2.5]:
				_box("klein", f, Vector2(px, s * 23.0), 0.0, Vector3(0.12, 2.2, 0.12), Color("f2f2f0"))
				welt.hindernisse.append(_rect(f, Vector2(px, s * 23.0), Vector2(0.3, 0.3)))
			_box("klein", f, Vector2(0.0, s * 23.0), 2.14, Vector3(5.12, 0.12, 0.12), Color("f2f2f0"))
			_box("klein", f, Vector2(0.0, s * 24.0), 0.0, Vector3(5.0, 2.1, 0.03), Color("dfe3e0"))
	# Zaun: Pfosten alle 3 m und zwei Holme (dünn → nur nah sichtbar)
	var gruen := Color("2f4a3a")
	var hoehe := 3.6 if v != 2 else 4.6
	for seite in 4:
		var k := -27.0
		while k <= 27.01:
			var l := Vector2(k, -27.2) if seite == 0 else (Vector2(k, 27.2) if seite == 1 else (Vector2(-27.2, k) if seite == 2 else Vector2(27.2, k)))
			if not (seite == 3 and absf(k) < 2.0):
				_box("fein", f, l, 0.0, Vector3(0.09, hoehe, 0.09), gruen)
			k += 3.0
		var quer := seite >= 2
		for hy in [1.2, hoehe - 0.1]:
			var g := Vector3(0.06, 0.08, 54.4) if quer else Vector3(54.4, 0.08, 0.06)
			var lm := Vector2(0, -27.2) if seite == 0 else (Vector2(0, 27.2) if seite == 1 else (Vector2(-27.2, 0) if seite == 2 else Vector2(27.2, 0)))
			_box("fein", f, lm, hy, g, gruen)
	_rand_kollision(f, 27.2, 2.0)
	if v == 2:
		_bank(f, Vector2(-19.0, 0.0), Vector2(1, 0))
		_bank(f, Vector2(19.0, 0.0), Vector2(-1, 0))
		_eimer(f, Vector2(-19.0, 2.5))
	else:
		_bank(f, Vector2(0.0, -6.0), Vector2(1, 0))
		_bank(f, Vector2(0.0, 6.0), Vector2(-1, 0))
		_eimer(f, Vector2(0.0, 0.0))
	for s in [-1.0, 1.0]:
		bodenlicht.leuchte(_pos(f, Vector2(s * 25.5, 25.5)), 2.0)

# ---------------------------------------------------------------- Foodtruck-Markt
const TRUCK_FARBEN := [Color("d9644f"), Color("e8b33c"), Color("4f93c4"), Color("62a85b"), Color("9b7cc4"), Color("e58aa0"), Color("f2f2ee")]
const TRUCK_NAMEN := ["Tacos", "Falafel", "Eis", "Burger", "Crêpes", "Kaffee", "Pizza", "Saft", "Waffeln", "Sushi", "Döner", "Smoothies"]
var _licht_punkte: Array = []   # [Vector3, Color] – Lichterketten (nachts)
func _box_rot(kat: String, f: Dictionary, l: Vector2, y: float, g: Vector3, farbe: Color, gl: float, b: Basis) -> void:
	_teil("box", kat, Transform3D(Basis(Vector3.UP, _gier(f, gl)) * b * Basis.from_scale(g), _pos(f, l, y)), farbe)

func _rad_zyl(f: Dictionary, l: Vector2, y: float, r: float, breite: float, gl: float) -> void:   # Reifen, Achse quer
	_teil("zyl", "klein", Transform3D(Basis(Vector3.UP, _gier(f, gl)) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(r * 2.0, breite, r * 2.0)), _pos(f, l, y)), Color("26282c"))

# Foodtruck mit der Länge entlang Layout-x, Klappe zur Seite s (±1 in z)
func _foodtruck(f: Dictionary, l: Vector2, s: float, farbe: Color, name: String) -> void:
	_box("klein", f, l, 0.55, Vector3(5.6, 2.5, 2.3), farbe)
	_box("klein", f, l + Vector2(3.65, 0), 0.55, Vector3(1.7, 1.9, 2.2), farbe.darkened(0.12))
	_box("klein", f, l + Vector2(4.48, 0), 1.45, Vector3(0.05, 0.75, 1.9), Color("2a3440"))
	for wx in [-1.9, 1.9, 3.7]:
		for wz in [-1.06, 1.06]:   # Außenseite 6 cm vor der Wand (bei ±1,0 lag sie genau in der Wand → Räder flackerten, Video 20.11.2026)
			_rad_zyl(f, l + Vector2(wx, wz), 0.45, 0.45, 0.3, 0.0)
	_box("klein", f, l + Vector2(-0.3, s * 1.16), 1.45, Vector3(2.8, 1.15, 0.05), Color("2a3440"))
	_box("klein", f, l + Vector2(-0.3, s * 1.42), 1.4, Vector3(2.9, 0.08, 0.5), Color("e6e6e2"))
	_box_rot("klein", f, l + Vector2(-0.3, s * 1.75), 2.85, Vector3(3.2, 0.07, 1.2), Color("f2f2ee"), 0.0, Basis(Vector3.RIGHT, s * 0.28))
	_box("klein", f, l + Vector2(-0.3, 0), 3.05, Vector3(2.6, 0.7, 0.12), Color("f2f2ee"))
	_schrift(f, l + Vector2(-0.3, s * 0.08), 3.4, name, 0.0 if s > 0.0 else PI, 72, Color("27313d"))
	welt.hindernisse.append(_rect(f, l + Vector2(0.6, 0), Vector2(7.6, 2.5)))

func _lichterkette(f: Dictionary, a: Vector2, b: Vector2, h: float, durch: float) -> void:
	var lang := a.distance_to(b)
	var n := int(lang / 1.1)
	for i in range(1, n):
		var t := float(i) / n
		var c: Color = Color(1.0, 0.82, 0.55) if i % 3 != 0 else RAD_FARBEN[i % RAD_FARBEN.size()].lightened(0.35)
		_licht_punkte.append([_pos(f, a.lerp(b, t), h - durch * sin(PI * t)), c])

func _markt(f: Dictionary) -> void:
	var namen := TRUCK_NAMEN.duplicate()
	for i in range(namen.size() - 1, 0, -1):   # mischen (mit eigenem Zufall, gleich für alle)
		var j := rng.randi_range(0, i)
		var t: String = namen[i]
		namen[i] = namen[j]
		namen[j] = t
	var orte := [[Vector2(-15.0, -21.5), 1.0], [Vector2(0.5, -21.5), 1.0], [Vector2(15.5, -21.5), 1.0], [Vector2(-12.0, 21.5), -1.0], [Vector2(8.0, 21.5), -1.0]]
	for i in orte.size():
		_foodtruck(f, orte[i][0], orte[i][1], TRUCK_FARBEN[rng.randi() % TRUCK_FARBEN.size()], namen[i])
	# Tische mit Sonnenschirmen in der Mitte
	var schirm := [Color("d9644f"), Color("f2f2ee"), Color("4f93c4"), Color("e8b33c")]
	for ix in 3:
		for iz in 2:
			var l := Vector2(-10.0 + ix * 10.0 + rng.randf_range(-1.0, 1.0), -5.0 + iz * 10.0 + rng.randf_range(-1.0, 1.0))
			_zyl("klein", f, l, 0.0, 0.07, 0.75, DUNKEL)
			_zyl("klein", f, l, 0.75, 0.65, 0.05, Color("f2f2f0"))
			_zyl("klein", f, l, 0.8, 0.04, 1.7, Color("9aa3ad"))
			_teil("kegel", "klein", Transform3D(Basis.from_scale(Vector3(3.0, 0.55, 3.0)), _pos(f, l, 2.45)), schirm[(ix + iz) % schirm.size()])
			for k in 4:
				var a := TAU * k / 4.0 + 0.4
				_zyl("klein", f, l + Vector2(cos(a), sin(a)) * 1.0, 0.0, 0.2, 0.45, Color("a8744a"))
			welt.hindernisse.append(_rect(f, l, Vector2(2.4, 2.4)))
	# Masten mit Lichterketten über dem Platz (nachts bunt)
	var ecken := [Vector2(-17.0, -15.0), Vector2(17.0, -15.0), Vector2(17.0, 15.0), Vector2(-17.0, 15.0)]
	for e in ecken:
		_box("klein", f, e, 0.0, Vector3(0.18, 4.8, 0.18), DUNKEL)
		welt.hindernisse.append(_rect(f, e, Vector2(0.4, 0.4)))
	for i in 4:
		_lichterkette(f, ecken[i], ecken[(i + 1) % 4], 4.6, 0.6)
	_lichterkette(f, ecken[0], ecken[2], 4.6, 1.0)
	_lichterkette(f, ecken[1], ecken[3], 4.6, 1.0)
	_eimer(f, Vector2(-17.0, 0.0))
	_eimer(f, Vector2(17.0, 0.0))
	for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_baum(f, s * 25.0, 0.9)

# ---------------------------------------------------------------- Tankstelle
func _tankstelle(f: Dictionary) -> void:
	var marke: Color = [Color("2f5f9e"), Color("2e8b57"), Color("d9644f")][rng.randi() % 3]
	# Dach auf vier Stützen, farbige Blende ringsum
	_box("gross", f, Vector2(0, 0), 5.4, Vector3(28.0, 0.9, 16.0), Color("f2f2f0"))
	_box("gross", f, Vector2(0, 8.05), 5.35, Vector3(28.2, 1.0, 0.1), marke)
	_box("gross", f, Vector2(0, -8.05), 5.35, Vector3(28.2, 1.0, 0.1), marke)
	_box("gross", f, Vector2(14.05, 0), 5.35, Vector3(0.1, 1.0, 16.2), marke)
	_box("gross", f, Vector2(-14.05, 0), 5.35, Vector3(0.1, 1.0, 16.2), marke)
	for px in [-9.0, 9.0]:
		for pz in [-4.0, 4.0]:
			_box("gross", f, Vector2(px, pz), 0.0, Vector3(0.6, 5.4, 0.6), Color("d6d0c4"))
			welt.hindernisse.append(_rect(f, Vector2(px, pz), Vector2(0.8, 0.8)))
	# drei Zapfinseln mit je zwei Säulen
	for ix in 3:
		var x := -9.0 + ix * 9.0
		_box("klein", f, Vector2(x, 0), 0.0, Vector3(1.4, 0.2, 6.0), BETON)
		for s in [-1.0, 1.0]:
			_box("klein", f, Vector2(x, s * 1.6), 0.2, Vector3(0.6, 1.7, 0.9), Color("f2f2f0"))
			_box("klein", f, Vector2(x, s * 1.6), 1.6, Vector3(0.62, 0.3, 0.92), marke)
			_box("klein", f, Vector2(x + 0.31, s * 1.6), 1.1, Vector3(0.02, 0.35, 0.5), Color("2a3440"))
		welt.hindernisse.append(_rect(f, Vector2(x, 0), Vector2(1.6, 6.2)))
		if rng.randf() < 0.6:
			_auto_neu(f, Vector2(x + 2.6, rng.randf_range(-1.5, 1.5)), 0.0 if rng.randf() < 0.5 else PI)
		if rng.randf() < 0.4:
			_auto_neu(f, Vector2(x - 2.6, rng.randf_range(-1.5, 1.5)), 0.0 if rng.randf() < 0.5 else PI)
	# Shop hinten mit Glasfront
	_box("gross", f, Vector2(0, -21.0), 0.0, Vector3(20.0, 4.4, 10.0), Color("e6e6e2"))
	_box("gross", f, Vector2(0, -15.95), 0.4, Vector3(16.0, 3.0, 0.1), Color("3d5872"))
	_box("gross", f, Vector2(0, -16.0), 4.2, Vector3(20.2, 0.6, 0.2), marke)
	_schrift(f, Vector2(0, -15.88), 4.5, "SHOP", 0.0, 96, Color.WHITE)
	_haeuser.append([_rect(f, Vector2(0, -21.0), Vector2(20.0, 10.0)), 4.6])
	# Preismast vorn an der Straße
	_box("gross", f, Vector2(-24.0, 24.0), 0.0, Vector3(2.4, 8.0, 0.6), marke)
	_box("klein", f, Vector2(-24.0, 24.32), 2.0, Vector3(2.0, 4.0, 0.05), Color("f2f2f0"))
	_schrift(f, Vector2(-24.0, 24.36), 6.9, "TANKE", 0.0, 80, Color.WHITE)
	_schrift(f, Vector2(-24.0, 24.36), 5.1, "Super  1,79", 0.0, 44, Color("27313d"))
	_schrift(f, Vector2(-24.0, 24.36), 4.2, "Diesel 1,69", 0.0, 44, Color("27313d"))
	_schrift(f, Vector2(-24.0, 24.36), 3.3, "E-Laden 0,49", 0.0, 44, Color("27313d"))
	welt.hindernisse.append(_rect(f, Vector2(-24.0, 24.0), Vector2(2.6, 0.8)))
	# Luft/Wasser-Säule, Leuchten unter dem Dach, Büsche im Grünstreifen
	_box("klein", f, Vector2(20.0, -12.0), 0.0, Vector3(0.6, 1.3, 0.6), marke)
	for k in 4:
		bodenlicht.leuchte(_pos(f, Vector2(-10.5 + k * 7.0, 0.0)), 3.0)
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		_busch(f, Vector2(x, 25.6), 2.6)

# ---------------------------------------------------------------- Parkhaus
func _parkhaus(f: Dictionary) -> void:
	var decks := rng.randi_range(3, 5)
	var bx := 44.0
	var bz := 36.0
	var dh := 3.1
	var beton := Color("c9c4ba")
	for e in decks + 1:
		var y := e * dh
		if e > 0:
			_box("gross", f, Vector2.ZERO, y - 0.35, Vector3(bx, 0.35, bz), beton.darkened(0.05))
		# Brüstung ringsum (auf jeder Ebene, vorn unten Einfahrt)
		if e > 0:   # Brüstung ringsum (Erdgeschoss offen)
			for s in [-1.0, 1.0]:
				_box("gross", f, Vector2(0, s * (bz * 0.5 - 0.1)), y, Vector3(bx, 1.0, 0.2), beton)
				_box("gross", f, Vector2(s * (bx * 0.5 - 0.1), 0), y, Vector3(0.2, 1.0, bz), beton)
		# Autos auf dieser Ebene (zwei Doppelreihen, auch auf dem Dach – von oben sichtbar)
		var belegt := rng.randf_range(0.3, 0.8)
		for rz in [-12.5, -7.5, 7.5, 12.5]:
			for k in 15:
				if rng.randf() > belegt:
					continue
				_auto_neu(f, Vector2(-19.5 + k * 2.6, rz), 0.0 if (rz == -12.5 or rz == 7.5) else PI, y)
		if e == decks:
			break
		for ix in 6:
			for iz in 5:
				_box("klein", f, Vector2(-bx * 0.5 + 0.5 + ix * (bx - 1.0) / 5.0, -bz * 0.5 + 0.5 + iz * (bz - 1.0) / 4.0), y, Vector3(0.6, dh - 0.35, 0.6), beton)
	# Treppenhaus mit P-Schild
	var th := (decks + 1) * dh + 2.0
	_box("gross", f, Vector2(bx * 0.5 - 3.0, -bz * 0.5 + 3.0), 0.0, Vector3(6.0, th, 6.0), Color("b9b4aa"))
	_box("gross", f, Vector2(bx * 0.5 - 3.0, -bz * 0.5 + 6.06), th - 3.0, Vector3(3.0, 3.0, 0.12), Color("2f5f9e"))
	_schrift(f, Vector2(bx * 0.5 - 3.0, -bz * 0.5 + 6.14), th - 1.5, "P", 0.0, 220, Color.WHITE)
	_haeuser.append([_rect(f, Vector2.ZERO, Vector2(bx, bz)), th])
	for x in [-20.0, -10.0, 10.0, 20.0]:
		_baum(f, Vector2(x, 24.5), 0.85)

# ---------------------------------------------------------------- Spielplatz
func _spielplatz(f: Dictionary) -> void:
	var holz := Color("a8744a")
	var blau := Color("4f93c4")
	var rot := Color("d9644f")
	var gelb := Color("e8b33c")
	# Schaukel: zwei A-Gestelle, Querbalken, drei Sitze an Ketten (Ketten dünn → nah)
	var sm := Vector2(-11.0, -14.0)
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			_box_rot("klein", f, sm + Vector2(s * 4.5, t * 0.8), 1.25, Vector3(0.14, 2.7, 0.14), blau, 0.0, Basis(Vector3.RIGHT, -t * 0.33))
		welt.hindernisse.append(_rect(f, sm + Vector2(s * 4.5, 0), Vector2(0.5, 2.0)))
	_box("klein", f, sm, 2.5, Vector3(9.2, 0.16, 0.16), blau)
	for k in 3:
		var x := -2.8 + k * 2.8
		_box("klein", f, sm + Vector2(x, 0), 0.5, Vector3(0.5, 0.06, 0.25), [rot, gelb, Color("62a85b")][k])
		for kx in [-0.22, 0.22]:
			_box("fein", f, sm + Vector2(x + kx, 0), 0.55, Vector3(0.025, 1.95, 0.025), Color("9aa3ad"))
	# Turm mit Rutsche: Plattform auf Pfosten, Dach, Leiter, Rutsche
	var tm := Vector2(11.0, -12.0)
	for e in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		_box("klein", f, tm + e * 1.1, 0.0, Vector3(0.16, 3.4, 0.16), holz)
	_box("klein", f, tm, 1.5, Vector3(2.5, 0.12, 2.5), holz)
	for s in [-1.0, 1.0]:
		_box("klein", f, tm + Vector2(s * 1.2, 0), 1.62, Vector3(0.06, 0.7, 2.4), blau)
	_teil("kegel", "klein", Transform3D(Basis.from_scale(Vector3(3.4, 1.2, 3.4)), _pos(f, tm, 3.4 + 0.6)), rot)
	_box_rot("klein", f, tm + Vector2(0, 2.0), 0.75, Vector3(0.7, 0.08, 2.0), holz, 0.0, Basis(Vector3.RIGHT, 0.85))
	_box_rot("klein", f, tm + Vector2(0, -2.9), 0.8, Vector3(0.8, 0.08, 3.6), gelb, 0.0, Basis(Vector3.RIGHT, -0.42))
	welt.hindernisse.append(_rect(f, tm + Vector2(0, -0.5), Vector2(2.8, 6.0)))
	# Sandkasten mit Holzrand
	var km := Vector2(-11.0, 11.0)
	for s in [-1.0, 1.0]:
		_box("klein", f, km + Vector2(0, s * 4.3), 0.0, Vector3(8.8, 0.35, 0.3), holz)
		_box("klein", f, km + Vector2(s * 4.3, 0), 0.0, Vector3(0.3, 0.35, 8.8), holz)
	_kugel("klein", f, km + Vector2(1.2, -0.8), 0.0, Vector3(1.6, 0.5, 1.4), Color("d9c08a"))
	_box("klein", f, km + Vector2(-1.5, 1.0), 0.05, Vector3(0.4, 0.25, 0.4), rot, 0.3)
	# Wippe
	var wm := Vector2(12.0, 12.0)
	_box("klein", f, wm, 0.0, Vector3(0.4, 0.5, 0.6), DUNKEL)
	_box_rot("klein", f, wm, 0.55, Vector3(5.0, 0.12, 0.35), gelb, 0.0, Basis(Vector3.BACK, 0.18))
	welt.hindernisse.append(_rect(f, wm, Vector2(5.0, 0.8)))
	# Karussell
	var cm := Vector2(0.0, 1.0)
	_zyl("klein", f, cm, 0.0, 1.8, 0.2, blau)
	_zyl("klein", f, cm, 0.2, 0.08, 1.1, Color("9aa3ad"))
	for k in 4:
		var a := TAU * k / 4.0
		_box("klein", f, cm + Vector2(cos(a), sin(a)) * 0.9, 0.2, Vector3(0.06, 0.8, 0.06), Color("9aa3ad"))
	_zyl("klein", f, cm, 1.0, 1.0, 0.06, rot)
	welt.hindernisse.append(_rect(f, cm, Vector2(3.6, 3.6)))
	# Bänke für die Eltern, Mülleimer, Bäume am Rand, Leuchten
	_bank(f, Vector2(-22.5, 0.0), Vector2(1, 0))
	_bank(f, Vector2(22.5, 0.0), Vector2(-1, 0))
	_bank(f, Vector2(0.0, 22.5), Vector2(0, -1))
	_eimer(f, Vector2(-22.5, 2.6))
	for l in [Vector2(-22.0, -22.0), Vector2(22.0, -22.0), Vector2(-22.0, 22.0), Vector2(22.0, 22.0), Vector2(0.0, -22.5)]:
		_baum(f, l, rng.randf_range(0.9, 1.2))
	for l in [Vector2(-22.5, -8.0), Vector2(22.5, 8.0), Vector2(8.0, 22.5)]:
		bodenlicht.leuchte(_pos(f, l), 1.6)

func _licht_punkte_bauen() -> void:
	if _licht_punkte.is_empty():
		return
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	mm.instance_count = _licht_punkte.size()
	for i in _licht_punkte.size():
		mm.set_instance_transform(i, Transform3D(Basis(), _licht_punkte[i][0]))
		mm.set_instance_color(i, _licht_punkte[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var sh := Shader.new()
	sh.code = RAD_LICHT_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-3000, -100, -3000), Vector3(6000, 1200, 6000))
	add_child(mmi)

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
	# Varianten: 0 = Rohbau, 1 = Baugrube mit Fundament, 2 = fast fertig mit Gerüst
	var v := int(f.var)
	var bx := 30.0
	var bz := 22.0
	var bm := Vector2(-6.0, -5.0)
	var stock := 0
	if v == 1:
		_baugrube(f, bm, bx, bz)
	else:
		stock = rng.randi_range(2, 9) if v == 0 else rng.randi_range(7, 12)
		_rohbau(f, bm, bx, bz, stock, 2 if v == 0 else 1)
		if v == 2:
			_geruest(f, bm, bx, bz, stock)
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
	if v != 1 and rng.randf() < 0.6:
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
	var v := int(f.var)
	if v == 1:
		_lagerplatz(f)
		return
	if v == 2:
		_werbetafel(f)
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
	if v == 0 and rng.randf() < 0.6:   # Bauschild „Hier entsteht …“ an der Straßenseite
		var l := Vector2(rng.randf_range(-12.0, 12.0), 25.5)
		for s in [-1.6, 1.6]:
			_box("klein", f, l + Vector2(s, 0), 0.0, Vector3(0.16, 3.4, 0.16), Color("9aa3ad"))
		_box("klein", f, l, 1.7, Vector3(4.6, 2.2, 0.12), Color("f2f0ea"))
		_box("klein", f, l + Vector2(0, 0.07), 1.7, Vector3(4.6, 0.45, 0.02), Color("2f5f9e"))
		var nm: String = SCHILD_NAMEN[rng.randi() % SCHILD_NAMEN.size()]
		_schrift(f, l + Vector2(0, 0.08), 3.4, "Hier entsteht", 0.0, 40, Color("2f5f9e"))
		_schrift(f, l + Vector2(0, 0.08), 2.75, nm, 0.0, 56, Color("27313d"))
		welt.hindernisse.append(_rect(f, l, Vector2(3.6, 0.5)))

func _schrift(f: Dictionary, l: Vector2, y: float, text: String, gl: float, groesse: int, farbe: Color, weit := 220.0) -> void:
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
	lab.visibility_range_end = weit
	add_child(lab)

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

# ---------------------------------------------------------------- Baustelle: Varianten (Runde 2, 19.11.2026)
# 0 = Rohbau (untere Geschosse verglast), 1 = Baugrube mit Fundament + Betonmischer, 2 = fast fertig mit Gerüst
func _rohbau(f: Dictionary, bm: Vector2, bx: float, bz: float, stock: int, offen: int) -> void:
	for e in stock + 1:
		var y := e * 3.5
		var teil := e == stock   # oberste Ebene: nur halbe Decke (wird gerade gebaut)
		var dx := bx * (0.5 if teil else 1.0)
		var dm := bm + Vector2(-bx * 0.25 if teil else 0.0, 0.0)
		_box("gross", f, dm, y, Vector3(dx, 0.35, bz), BETON.darkened(0.04))
		if e == stock:
			break
		var verglast := e < stock - offen
		for ix in 5:
			for iz in 4:
				var l := bm + Vector2(-bx * 0.5 + 0.4 + ix * (bx - 0.8) / 4.0, -bz * 0.5 + 0.4 + iz * (bz - 0.8) / 3.0)
				if verglast and ix > 0 and ix < 4 and iz > 0 and iz < 3:
					continue
				_box("klein", f, l, y + 0.35, Vector3(0.5, 3.15, 0.5), BETON)   # Stützen ohne Schatten (Messung: viele Schattenteile kosten)
		if verglast:
			var gc := Color("6d8aa3")
			_box("gross", f, bm + Vector2(0, -bz * 0.5 + 0.1), y + 0.6, Vector3(bx - 1.0, 2.6, 0.1), gc)
			_box("gross", f, bm + Vector2(0, bz * 0.5 - 0.1), y + 0.6, Vector3(bx - 1.0, 2.6, 0.1), gc)
			_box("gross", f, bm + Vector2(-bx * 0.5 + 0.1, 0), y + 0.6, Vector3(0.1, 2.6, bz - 1.0), gc)
			_box("gross", f, bm + Vector2(bx * 0.5 - 0.1, 0), y + 0.6, Vector3(0.1, 2.6, bz - 1.0), gc)
	var kern := bm + Vector2(bx * 0.5 - 4.0, bz * 0.5 - 3.5)
	_box("gross", f, kern, 0.0, Vector3(5.0, stock * 3.5 + 3.2, 4.5), BETON.darkened(0.12))
	_haeuser.append([_rect(f, bm, Vector2(bx, bz)), stock * 3.5 + 3.2])

func _geruest(f: Dictionary, bm: Vector2, bx: float, bz: float, stock: int) -> void:
	var z := bm.y + bz * 0.5 + 1.3
	var h := stock * 3.5 + 1.5
	var x := bm.x - bx * 0.5
	while x <= bm.x + bx * 0.5 + 0.01:
		for dz in [-0.5, 0.5]:
			_box("fein", f, Vector2(x, z + dz), 0.0, Vector3(0.07, h, 0.07), Color("9aa3ad"))
		x += 2.5
	for e in range(1, stock + 1):
		_box("klein", f, Vector2(bm.x, z), e * 3.5 - 0.1, Vector3(bx, 0.08, 1.0), Color("a8744a"))
		_box("fein", f, Vector2(bm.x, z + 0.55), e * 3.5 + 0.9, Vector3(bx, 0.06, 0.06), Color("e0652a"))
	welt.hindernisse.append(_rect(f, Vector2(bm.x, z), Vector2(bx + 0.4, 1.4)))

func _baugrube(f: Dictionary, bm: Vector2, bx: float, bz: float) -> void:
	var stahl := Color("6f757c")
	# Spundwände ringsum (Lücke rechts = Rampe)
	_box("gross", f, bm + Vector2(0, -bz * 0.5), 0.0, Vector3(bx, 0.9, 0.3), stahl)
	_box("gross", f, bm + Vector2(0, bz * 0.5), 0.0, Vector3(bx, 0.9, 0.3), stahl)
	_box("gross", f, bm + Vector2(-bx * 0.5, 0), 0.0, Vector3(0.3, 0.9, bz), stahl)
	_box("gross", f, bm + Vector2(bx * 0.5, -bz * 0.25 - 1.5), 0.0, Vector3(0.3, 0.9, bz * 0.5 - 3.0), stahl)
	_box("gross", f, bm + Vector2(bx * 0.5, bz * 0.25 + 1.5), 0.0, Vector3(0.3, 0.9, bz * 0.5 - 3.0), stahl)
	for r in [[Vector2(0, -bz * 0.5), Vector2(bx, 0.5)], [Vector2(0, bz * 0.5), Vector2(bx, 0.5)], [Vector2(-bx * 0.5, 0), Vector2(0.5, bz)], [Vector2(bx * 0.5, -bz * 0.25 - 1.5), Vector2(0.5, bz * 0.5 - 3.0)], [Vector2(bx * 0.5, bz * 0.25 + 1.5), Vector2(0.5, bz * 0.5 - 3.0)]]:
		welt.hindernisse.append(_rect(f, bm + r[0], r[1]))
	# halbe Fundamentplatte mit Anschlusseisen, andere Hälfte: Bewehrungsmatten
	var pm := bm + Vector2(-bx * 0.25, 0)
	_box("gross", f, pm, 0.0, Vector3(bx * 0.5 - 1.0, 0.35, bz - 1.0), BETON)
	var rost := Color("8a5a44")
	var x := pm.x - bx * 0.25 + 1.5
	while x < pm.x + bx * 0.25 - 1.0:
		var z := -bz * 0.5 + 2.0
		while z < bz * 0.5 - 1.5:
			_box("fein", f, Vector2(x, bm.y + z), 0.35, Vector3(0.05, 1.3, 0.05), rost)
			z += 3.0
		x += 3.0
	var mm := bm + Vector2(bx * 0.25, 0)
	var k := -bz * 0.5 + 1.0
	while k < bz * 0.5 - 0.9:
		_box("fein", f, Vector2(mm.x, bm.y + k), 0.12, Vector3(bx * 0.5 - 2.0, 0.04, 0.04), rost)
		k += 0.9
	k = -bx * 0.25 + 1.0
	while k < bx * 0.25 - 0.9:
		_box("fein", f, Vector2(mm.x + k, bm.y), 0.16, Vector3(0.04, 0.04, bz - 2.0), rost)
		k += 0.9
	for i in 4:   # Schalungselemente gestapelt
		_box("klein", f, Vector2(4.0, 13.0 + i * 0.25), 0.0, Vector3(2.6, 0.2, 1.3), Color("a8744a"), 0.1 * i)
	_bagger(f, bm + Vector2(8.0, 4.0), rng.randf() * TAU)
	# Betonmischer am Tor
	var ml := Vector2(20.0, 0.0)
	_box("klein", f, ml, 0.5, Vector3(7.0, 0.4, 2.3), DUNKEL)
	_box("klein", f, ml + Vector2(3.0, 0), 0.9, Vector3(1.6, 2.0, 2.3), Color("f2f2ee"))
	_box("klein", f, ml + Vector2(3.82, 0), 1.9, Vector3(0.05, 0.8, 2.0), Color("2a3440"))
	_teil("zyl", "klein", Transform3D(Basis(Vector3.UP, _gier(f, 0.0)) * Basis(Vector3.BACK, PI * 0.5 - 0.25) * Basis.from_scale(Vector3(2.2, 4.4, 2.2)), _pos(f, ml + Vector2(-0.8, 0), 2.2)), Color("e0652a"))
	for wx in [-2.5, -1.2, 3.0]:
		for wz in [-1.06, 1.06]:
			_rad_zyl(f, ml + Vector2(wx, wz), 0.5, 0.5, 0.35, 0.0)
	welt.hindernisse.append(_rect(f, ml + Vector2(0.4, 0), Vector2(7.6, 2.6)))

# ---------------------------------------------------------------- Brache: Varianten
# 0 = Sand mit Büschen (+ halb Bauschild), 1 = Lagerplatz mit Containern, 2 = Werbetafel
const CONTAINER_FARBEN := [Color("b5533c"), Color("3b5f86"), Color("2e7d5b"), Color("d9a43c"), Color("8a929c"), Color("f2f2ee")]
const WERBUNG := [["SKY COLA", "Erfrischt bis ganz oben", "d9644f"], ["FENSTERKLAR", "Putzmittel für Profis", "4f93c4"], ["DÜNEN-BANK", "Ihr Geld in sicheren Händen", "2e7d5b"],
	["OASIS AIR", "Täglich nonstop ans Meer", "4fa3c4"], ["GOLDSAND", "Schmuck seit 1987", "c9a258"], ["TURBO-WISCH", "Der Schwamm der Zukunft", "9b7cc4"]]

func _lagerplatz(f: Dictionary) -> void:
	# Zaun (Pfosten + Holme), Tor rechts
	for seite in 4:
		var k := -27.0
		while k <= 27.01:
			var l := Vector2(k, -27.3) if seite == 0 else (Vector2(k, 27.3) if seite == 1 else (Vector2(-27.3, k) if seite == 2 else Vector2(27.3, k)))
			if not (seite == 3 and absf(k) < 4.0):
				_box("fein", f, l, 0.0, Vector3(0.08, 2.2, 0.08), Color("8a929c"))
			k += 3.0
	_rand_kollision(f, 27.3, 4.0)
	# Containerreihen, 1–3 hoch gestapelt
	for zr in [-20.0, -11.0, 8.0, 17.0]:
		var x := -22.0
		while x < 14.0:
			var lang := 6.1 if rng.randf() < 0.6 else 12.2
			if x + lang > 16.0:
				break
			var hoch := rng.randi_range(1, 3)
			var l := Vector2(x + lang * 0.5, zr)
			for h in hoch:
				_box("gross", f, l, h * 2.6, Vector3(lang, 2.6, 2.45), CONTAINER_FARBEN[rng.randi() % CONTAINER_FARBEN.size()])
			_haeuser.append([_rect(f, l, Vector2(lang, 2.45)), hoch * 2.6])
			x += lang + rng.randf_range(0.3, 1.5)
	# Paletten, Gabelstapler
	for i in rng.randi_range(3, 6):
		var l := Vector2(rng.randf_range(-20.0, 12.0), rng.randf_range(-4.0, 3.0))
		var n := rng.randi_range(1, 5)
		for h in n:
			_box("klein", f, l, h * 0.15, Vector3(1.2, 0.14, 0.8), Color("b08a5a"))
		welt.hindernisse.append(_rect(f, l, Vector2(1.3, 1.3)))
	var gl := rng.randf() * TAU
	var sl := Vector2(19.0, rng.randf_range(-6.0, 6.0))
	_box("klein", f, sl, 0.3, Vector3(1.2, 1.0, 2.2), GELB, gl)
	_box("klein", f, sl, 1.3, Vector3(1.1, 0.9, 1.0), Color("2a3440"), gl)
	_box("klein", f, sl + Vector2(sin(gl), cos(gl)) * 1.25, 0.0, Vector3(0.9, 2.6, 0.12), DUNKEL, gl)
	welt.hindernisse.append(_rect(f, sl, Vector2(2.6, 2.6)))

func _werbetafel(f: Dictionary) -> void:
	var w: Array = WERBUNG[rng.randi() % WERBUNG.size()]
	var l := Vector2(rng.randf_range(-8.0, 8.0), 23.5)
	for s in [-4.5, 4.5]:
		_box("gross", f, l + Vector2(s, 0), 0.0, Vector3(0.5, 7.2, 0.5), Color("8a929c"))
		welt.hindernisse.append(_rect(f, l + Vector2(s, 0), Vector2(0.7, 0.7)))
	_box("gross", f, l, 7.0, Vector3(14.4, 5.4, 0.35), DUNKEL)
	_box("gross", f, l + Vector2(0, 0.2), 7.2, Vector3(14.0, 5.0, 0.05), Color(str(w[2])))
	_box("klein", f, l + Vector2(0, 0.24), 7.3, Vector3(13.6, 1.3, 0.02), Color("f2f2ee"))
	_schrift(f, l + Vector2(0, 0.25), 10.4, str(w[0]), 0.0, 200, Color.WHITE, 700.0)
	_schrift(f, l + Vector2(0, 0.27), 7.95, str(w[1]), 0.0, 90, Color("27313d"), 700.0)
	for s in [-4.0, 0.0, 4.0]:   # Strahler oben
		_box("fein", f, l + Vector2(s, 0.9), 12.5, Vector3(0.3, 0.2, 0.5), DUNKEL)

# ---------------------------------------------------------------- Wochenmarkt
const OBST := [Color("d9483e"), Color("f0a03a"), Color("8fc04a"), Color("f2d24a"), Color("7a3f8f"), Color("5a8a3a")]
func _wochenmarkt(f: Dictionary) -> void:
	var dach_farben := [Color("d9644f"), Color("4f93c4"), Color("62a85b"), Color("e8b33c")]
	for zr in [-14.0, 0.0, 14.0]:
		for ix in 4:
			var l := Vector2(-16.5 + ix * 11.0, zr)
			if rng.randf() < 0.12:
				continue
			var df: Color = dach_farben[rng.randi() % dach_farben.size()]
			var s := 1.0 if zr < 0.0 else -1.0   # Verkaufsseite zum nächsten Gang
			if zr == 0.0:
				s = 1.0 if ix % 2 == 0 else -1.0
			_box("klein", f, l, 0.0, Vector3(4.0, 0.9, 1.6), Color("f2f2ee"))
			for px in [-1.9, 1.9]:
				for pz in [-0.9, 0.9]:
					_box("klein", f, l + Vector2(px, pz), 0.0, Vector3(0.07, 2.4, 0.07), Color("9aa3ad"))
			for k in 4:   # gestreifte Markise
				_box_rot("klein", f, l + Vector2(-1.65 + k * 1.1, s * 0.35), 2.45, Vector3(1.1, 0.05, 2.6), df if k % 2 == 0 else Color("f2f2ee"), 0.0, Basis(Vector3.RIGHT, s * 0.18))
			for k in 8:   # Kisten mit Obst und Gemüse
				var kl := l + Vector2(-1.6 + (k % 4) * 1.05, -0.35 + int(k / 4.0) * 0.7)
				_box("klein", f, kl, 0.9, Vector3(0.9, 0.18, 0.6), Color("b08a5a"))
				_kugel("klein", f, kl, 1.02, Vector3(0.8, 0.22, 0.5), OBST[rng.randi() % OBST.size()])
			welt.hindernisse.append(_rect(f, l, Vector2(4.2, 1.8)))
	_bank(f, Vector2(-24.0, -7.0), Vector2(1, 0))
	_bank(f, Vector2(24.0, 7.0), Vector2(-1, 0))
	_eimer(f, Vector2(-24.0, 7.0))
	for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_baum(f, s * 24.5, 0.9)

# ---------------------------------------------------------------- Skatepark
func _skatepark(f: Dictionary) -> void:
	var beton := Color("c9c6be")
	# Quarterpipe an der hinteren Kante: gebogene Fläche aus 5 Streifen + Plattform + Kante
	var r := 3.0
	for i in 5:
		var a0 := i * PI * 0.5 / 5.0
		var a1 := (i + 1) * PI * 0.5 / 5.0
		var am := (a0 + a1) * 0.5
		var p := Vector2(-6.0, -21.0 - r * sin(am))
		_box_rot("gross", f, p, r * (1.0 - cos(am)), Vector3(12.0, 0.25, r * (a1 - a0) + 0.05), beton, 0.0, Basis(Vector3.RIGHT, am))
	_box("gross", f, Vector2(-6.0, -25.5), 0.0, Vector3(12.0, r, 3.0), beton.darkened(0.06))
	_box("fein", f, Vector2(-6.0, -24.05), r - 0.05, Vector3(12.0, 0.1, 0.1), Color("9aa3ad"))
	_haeuser.append([_rect(f, Vector2(-6.0, -24.0), Vector2(12.0, 6.0)), r])
	# Funbox mit Schrägen, Rail, Ledge, Kicker
	_box("gross", f, Vector2(-8.0, 2.0), 0.0, Vector3(5.0, 0.9, 3.0), beton)
	for s in [-1.0, 1.0]:
		_box_rot("gross", f, Vector2(-8.0 + s * 3.6, 2.0), 0.45, Vector3(2.4, 0.2, 3.0), beton, 0.0, Basis(Vector3.BACK, -s * 0.38))
	welt.hindernisse.append(_rect(f, Vector2(-8.0, 2.0), Vector2(9.0, 3.2)))
	for px in [-3.5, 3.5]:
		_box("fein", f, Vector2(-8.0 + px, 9.0), 0.0, Vector3(0.08, 0.5, 0.08), Color("9aa3ad"))
	_box("klein", f, Vector2(-8.0, 9.0), 0.5, Vector3(8.0, 0.07, 0.07), Color("e8b33c"))
	_box("gross", f, Vector2(4.0, -6.0), 0.0, Vector3(6.0, 0.5, 1.2), beton.lightened(0.05))
	welt.hindernisse.append(_rect(f, Vector2(4.0, -6.0), Vector2(6.2, 1.4)))
	_box_rot("gross", f, Vector2(-16.0, 14.0), 0.35, Vector3(2.4, 0.2, 2.0), beton, 0.0, Basis(Vector3.BACK, 0.3))
	# Graffiti-Wände: Beton mit bunten Flächen
	for wl in [[Vector2(20.0, -14.0), PI * 0.5], [Vector2(-22.0, -4.0), PI * 0.5]]:
		var l: Vector2 = wl[0]
		_box("gross", f, l, 0.0, Vector3(10.0, 2.6, 0.3), beton.darkened(0.04), wl[1])
		var seite := 1.0 if l.x < 0.0 else -1.0
		for k in 6:
			var gc: Color = [Color("e2483e"), Color("f0c43a"), Color("3fa0e0"), Color("8a4fc4"), Color("4fc46a"), Color("f07ab0")][rng.randi() % 6]
			var dl := Vector2(seite * (0.16 + k * 0.004), rng.randf_range(-4.0, 4.0))
			_box("klein", f, l + dl, rng.randf_range(0.2, 1.4), Vector3(rng.randf_range(1.0, 2.6), rng.randf_range(0.5, 1.2), 0.01), gc, wl[1])
		welt.hindernisse.append(_rect(f, l, Vector2(0.5, 10.0)))
	_bank(f, Vector2(24.0, 10.0), Vector2(-1, 0))
	_bank(f, Vector2(24.0, 16.0), Vector2(-1, 0))
	_eimer(f, Vector2(24.0, 13.0))
	for l in [Vector2(-24.0, 24.0), Vector2(0.0, 24.5), Vector2(24.0, 24.0)]:
		_baum(f, l, 0.9)

# ---------------------------------------------------------------- Gemeinschaftsgarten
func _garten(f: Dictionary) -> void:
	var holz := Color("8a5f3c")
	var pflanzen := [Color("7cbf4a"), Color("4f8a3a"), Color("a0cf5a"), Color("5f9f45")]
	for ix in 5:
		for iz in 7:
			var l := Vector2(-20.5 + ix * 9.0, -19.25 + iz * 5.5)
			for s in [-1.0, 1.0]:
				_box("klein", f, l + Vector2(0, s * 1.1), 0.0, Vector3(6.2, 0.45, 0.12), holz)
				_box("klein", f, l + Vector2(s * 3.05, 0), 0.0, Vector3(0.12, 0.45, 2.2), holz)
			var art := rng.randi() % 4
			for k in 5:
				var pl := l + Vector2(-2.4 + k * 1.2, rng.randf_range(-0.3, 0.3))
				if art == 3:   # Tomaten an Stäben
					_box("fein", f, pl, 0.4, Vector3(0.04, 1.4, 0.04), Color("a8744a"))
					_kugel("klein", f, pl, 0.95, Vector3(0.6, 0.9, 0.6), pflanzen[1])
					_kugel("klein", f, pl + Vector2(0.15, 0.1), 1.0, Vector3(0.14, 0.14, 0.14), Color("d9483e"))
				elif art == 2:   # Sonnenblumen
					_box("fein", f, pl, 0.4, Vector3(0.05, 1.8, 0.05), Color("5f8a3a"))
					_teil("zyl", "klein", Transform3D(Basis(Vector3.RIGHT, 1.2) * Basis.from_scale(Vector3(0.6, 0.06, 0.6)), _pos(f, pl, 2.2)), Color("f2c43a"))
				else:
					_kugel("klein", f, pl, 0.45, Vector3(0.75, 0.45, 0.75), pflanzen[(art + k) % pflanzen.size()])
			welt.hindernisse.append(_rect(f, l, Vector2(6.3, 2.3)))
	# Gewächshaus, Gartenhütte, Regentonnen, Bank mit Tisch
	var gh := Vector2(23.5, -12.0)
	_box("gross", f, gh, 0.0, Vector3(5.0, 2.2, 8.0), Color("cfe3ea"))
	for s in [-1.0, 1.0]:
		_box_rot("gross", f, gh + Vector2(s * 1.25, 0), 2.6, Vector3(2.8, 0.06, 8.0), Color("dcebf0"), 0.0, Basis(Vector3.BACK, -s * 0.55))
	_haeuser.append([_rect(f, gh, Vector2(5.0, 8.0)), 3.4])
	var hu := Vector2(23.5, 4.0)
	_box("gross", f, hu, 0.0, Vector3(4.0, 2.4, 3.2), holz.lightened(0.1))
	_box_rot("gross", f, hu, 2.55, Vector3(4.6, 0.12, 3.8), Color("6f4a32"), 0.0, Basis(Vector3.RIGHT, 0.12))
	_haeuser.append([_rect(f, hu, Vector2(4.0, 3.2)), 2.8])
	for k in 2:
		_zyl("klein", f, hu + Vector2(-2.4, -1.0 + k * 1.1), 0.0, 0.4, 1.0, Color("2f6fae"))
	_bank(f, Vector2(-14.0, 22.0), Vector2(0, -1))
	_box("klein", f, Vector2(-11.0, 22.0), 0.0, Vector3(1.8, 0.75, 0.9), holz)
	_bank(f, Vector2(-8.0, 22.0), Vector2(0, -1))
	for l in [Vector2(10.0, 23.0), Vector2(22.5, 22.5)]:
		_baum(f, l, 1.0)

# ---------------------------------------------------------------- Hundewiese
func _hund(f: Dictionary, l: Vector2, gl: float, farbe: Color) -> void:
	var v := Vector2(sin(gl), cos(gl))
	var q := Vector2(v.y, -v.x)
	_box("klein", f, l, 0.32, Vector3(0.32, 0.3, 0.75), farbe, gl)
	_box("klein", f, l + v * 0.45, 0.5, Vector3(0.26, 0.26, 0.3), farbe, gl)
	_box("klein", f, l + v * 0.63, 0.5, Vector3(0.14, 0.12, 0.12), farbe.darkened(0.3), gl)
	_box_rot("klein", f, l - v * 0.42, 0.55, Vector3(0.06, 0.06, 0.3), farbe, gl, Basis(Vector3.RIGHT, 0.7))
	for a in [-0.25, 0.25]:
		for b in [-0.08, 0.08]:
			_box("klein", f, l + v * a + q * b * 1.4, 0.0, Vector3(0.07, 0.34, 0.07), farbe.darkened(0.1), gl)

func _hundewiese(f: Dictionary) -> void:
	# niedriger Zaun mit Tor
	for seite in 4:
		var k := -27.0
		while k <= 27.01:
			var l := Vector2(k, -27.3) if seite == 0 else (Vector2(k, 27.3) if seite == 1 else (Vector2(-27.3, k) if seite == 2 else Vector2(27.3, k)))
			if not (seite == 3 and absf(k) < 2.0):
				_box("fein", f, l, 0.0, Vector3(0.1, 1.2, 0.1), Color("6f4a32"))
			k += 2.0
		var lm := Vector2(0, -27.3) if seite == 0 else (Vector2(0, 27.3) if seite == 1 else (Vector2(-27.3, 0) if seite == 2 else Vector2(27.3, 0)))
		var g := Vector3(0.06, 0.08, 54.6) if seite >= 2 else Vector3(54.6, 0.08, 0.06)
		_box("fein", f, lm, 1.0, g, Color("6f4a32"))
	_rand_kollision(f, 27.3, 2.0)
	# Hürden, Tunnel, Slalom, A-Wand
	for i in 3:
		var hl := Vector2(-14.0 + i * 5.0, -14.0)
		for s in [-0.8, 0.8]:
			_box("klein", f, hl + Vector2(s, 0), 0.0, Vector3(0.08, 0.9, 0.08), Color("f2f2ee"))
		_box("klein", f, hl, 0.55, Vector3(1.6, 0.06, 0.06), Color("d9483e"))
	_teil("zyl", "klein", Transform3D(Basis(Vector3.UP, _gier(f, 0.0)) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.2, 5.0, 1.2)), _pos(f, Vector2(10.0, -12.0), 0.6)), Color("3f8fd0"))
	welt.hindernisse.append(_rect(f, Vector2(10.0, -12.0), Vector2(1.4, 5.0)))
	for i in 6:
		_box("fein", f, Vector2(-12.0 + i * 1.2, 6.0), 0.0, Vector3(0.05, 1.0, 0.05), Color("f2c43a") if i % 2 == 0 else Color("f2f2ee"))
	for s in [-1.0, 1.0]:
		_box_rot("klein", f, Vector2(10.0 + s * 1.3, 8.0), 0.85, Vector3(2.9, 0.1, 1.0), Color("e8b33c"), 0.0, Basis(Vector3.BACK, -s * 0.62))
	welt.hindernisse.append(_rect(f, Vector2(10.0, 8.0), Vector2(5.0, 1.2)))
	# Beutelspender, Bänke, Bäume, ein paar Hunde
	_box("klein", f, Vector2(24.0, 4.0), 0.0, Vector3(0.1, 1.3, 0.1), DUNKEL)
	_box("klein", f, Vector2(24.0, 4.0), 1.0, Vector3(0.35, 0.45, 0.2), Color("4f8a3a"))
	_eimer(f, Vector2(24.0, 5.0))
	_bank(f, Vector2(-23.0, 10.0), Vector2(1, 0))
	_bank(f, Vector2(-23.0, -2.0), Vector2(1, 0))
	_bank(f, Vector2(23.0, -10.0), Vector2(-1, 0))
	for l in [Vector2(-22.0, -22.0), Vector2(22.0, 22.0), Vector2(-20.0, 21.0), Vector2(0.0, 20.0)]:
		_baum(f, l, rng.randf_range(1.0, 1.3))
	var fell := [Color("c9a46c"), Color("3a3330"), Color("f2f2ee"), Color("8a5a3c")]
	for i in rng.randi_range(2, 4):
		_hund(f, Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-6.0, 16.0)), rng.randf() * TAU, fell[rng.randi() % fell.size()])

# ---------------------------------------------------------------- Zirkus (einmal)
# Gestreiftes Zelt als eigenes Mesh mit Vertexfarben (Wand + Kegeldach, rot/weiß), Wagen, Lichterketten von der Spitze
func _streifen_zelt(f: Dictionary, l: Vector2, r: float, wand: float, dach: float, a: Color, b: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	var spitze := Vector3(0, wand + dach, 0)
	for i in n:
		var w0 := TAU * i / n
		var w1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(w0) * r, 0, sin(w0) * r)
		var p1 := Vector3(cos(w1) * r, 0, sin(w1) * r)
		var c := a if i % 2 == 0 else b
		var nw := Vector3(cos((w0 + w1) * 0.5), 0, sin((w0 + w1) * 0.5))
		for v in [p0, p1 + Vector3.UP * wand, p1, p0, p0 + Vector3.UP * wand, p1 + Vector3.UP * wand]:
			st.set_color(c)
			st.set_normal(nw)
			st.add_vertex(v)
		var oben0 := p0 * 1.08 + Vector3.UP * wand
		var oben1 := p1 * 1.08 + Vector3.UP * wand
		var nd := (oben1 - oben0).cross(spitze - oben0).normalized()
		if nd.y < 0.0:
			nd = -nd
		for v in [oben0, spitze, oben1]:
			st.set_color(c)
			st.set_normal(nd)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	var mesh := st.commit()
	mi.mesh = mesh
	var m := _mat.duplicate() as StandardMaterial3D
	m.cull_mode = BaseMaterial3D.CULL_DISABLED   # Wicklung egal (beide Seiten)
	mi.material_override = m
	mi.position = _pos(f, l)
	add_child(mi)

func _zirkus(f: Dictionary) -> void:
	var rot := Color("d9483e")
	var weiss := Color("f2f2ee")
	_streifen_zelt(f, Vector2.ZERO, 11.0, 4.0, 8.0, rot, weiss)
	_zyl("gross", f, Vector2.ZERO, 0.0, 0.25, 14.5, Color("9aa3ad"))
	_box("klein", f, Vector2(0.6, 0.0), 13.6, Vector3(1.2, 0.7, 0.04), Color("f2c43a"))
	_box("klein", f, Vector2(0.0, 11.4), 0.0, Vector3(3.2, 3.2, 1.0), Color("2a3440"))   # Eingang
	_haeuser.append([_rect(f, Vector2.ZERO, Vector2(22.0, 22.0)), 12.0])
	for i in 8:   # Lichterketten von der Spitze nach außen
		var a := TAU * i / 8.0 + PI / 8.0
		var aussen := Vector2(cos(a), sin(a)) * 21.0
		_box("klein", f, aussen, 0.0, Vector3(0.15, 3.0, 0.15), DUNKEL)
		var n := 14
		for k in range(1, n):
			var t := float(k) / n
			var y := lerpf(12.0, 3.0, t) - 1.2 * sin(PI * t)
			var c: Color = RAD_FARBEN[(i + k) % RAD_FARBEN.size()].lightened(0.3) if k % 2 == 0 else Color(1.0, 0.85, 0.6)
			_licht_punkte.append([_pos(f, Vector2(cos(a), sin(a)) * lerpf(1.0, 21.0, t), y), c])
	# Zirkuswagen mit Rädern
	var wagen := [[Vector2(-20.0, -20.0), Color("2f5f9e")], [Vector2(-10.0, -23.5), Color("e8b33c")], [Vector2(12.0, -23.5), Color("62a85b")], [Vector2(21.0, -16.0), rot]]
	for w in wagen:
		var l: Vector2 = w[0]
		_box("klein", f, l, 0.6, Vector3(6.0, 2.6, 2.4), w[1])
		_box("klein", f, l, 3.2, Vector3(6.2, 0.2, 2.6), weiss)
		_box("klein", f, l + Vector2(0, 1.21), 1.6, Vector3(1.0, 0.8, 0.02), Color("2a3440"))
		for wx in [-2.0, 2.0]:
			for wz in [-1.0, 1.0]:
				_rad_zyl(f, l + Vector2(wx, wz), 0.55, 0.55, 0.15, 0.0)
		welt.hindernisse.append(_rect(f, l, Vector2(6.2, 2.6)))
	# Kassenhäuschen, Fahnen am Eingang
	_box("klein", f, Vector2(-5.0, 20.0), 0.0, Vector3(2.4, 2.4, 2.0), rot)
	_box("klein", f, Vector2(-5.0, 20.0), 2.4, Vector3(2.8, 0.3, 2.4), weiss)
	welt.hindernisse.append(_rect(f, Vector2(-5.0, 20.0), Vector2(2.6, 2.2)))
	for s in [-1.0, 1.0]:
		_box("fein", f, Vector2(s * 3.0, 17.0), 0.0, Vector3(0.08, 5.0, 0.08), Color("9aa3ad"))
		_box("klein", f, Vector2(s * 3.0 + 0.5, 17.0), 4.2, Vector3(1.0, 0.6, 0.03), Color("f2c43a") if s > 0.0 else rot)

# ---------------------------------------------------------------- Stadion (einmal)
func _stadion(f: Dictionary) -> void:
	var beton := Color("c9c4ba")
	var sitz := [Color("2f5f9e"), Color("f2f2ee")]
	# Tribünen: lange Seiten 6 Stufen, kurze Seiten 3 Stufen (Sitzreihen abwechselnd blau/weiß)
	for s in [-1.0, 1.0]:
		for k in 6:
			var x: float = s * (15.5 + k * 1.8)
			_box("gross", f, Vector2(x, 0), 0.0, Vector3(1.8, 0.8 * (k + 1), 40.0), beton)
			_box("klein", f, Vector2(x - s * 0.3, 0), 0.8 * (k + 1), Vector3(0.6, 0.35, 39.0), sitz[k % 2])
		_haeuser.append([_rect(f, Vector2(s * 20.0, 0), Vector2(11.0, 40.0)), 4.8])
		for k in 3:
			var z: float = s * (21.8 + k * 1.8)
			_box("gross", f, Vector2(0, z), 0.0, Vector3(28.0, 0.8 * (k + 1), 1.8), beton)
			_box("klein", f, Vector2(0, z - s * 0.3), 0.8 * (k + 1), Vector3(27.0, 0.35, 0.6), sitz[(k + 1) % 2])
		_haeuser.append([_rect(f, Vector2(0, s * 23.6), Vector2(28.0, 5.4)), 2.4])
	# Dach über der einen Längsseite
	_box("gross", f, Vector2(-21.0, 0), 8.0, Vector3(13.0, 0.4, 40.0), Color("e6e6e2"))
	for z in [-18.0, -6.0, 6.0, 18.0]:
		_box("gross", f, Vector2(-27.0, z), 0.0, Vector3(0.5, 8.0, 0.5), Color("9aa3ad"))
	# Tore
	for s in [-1.0, 1.0]:
		for px in [-3.66, 3.66]:
			_box("klein", f, Vector2(px, s * 19.5), 0.0, Vector3(0.12, 2.44, 0.12), Color("f2f2ee"))
		_box("klein", f, Vector2(0.0, s * 19.5), 2.38, Vector3(7.44, 0.12, 0.12), Color("f2f2ee"))
		_box("klein", f, Vector2(0.0, s * 20.6), 0.0, Vector3(7.3, 2.3, 0.03), Color("dfe3e0"))
	# Flutlichtmasten in den Ecken (nachts helle Lampenfelder)
	for e in [Vector2(-26.0, -26.0), Vector2(26.0, -26.0), Vector2(26.0, 26.0), Vector2(-26.0, 26.0)]:
		_box("gross", f, e, 0.0, Vector3(0.7, 24.0, 0.7), Color("9aa3ad"))
		var richtung: Vector2 = -(e as Vector2).normalized()
		var gl := atan2(richtung.x, richtung.y)
		_box_rot("gross", f, e + richtung * 0.4, 24.0, Vector3(3.6, 2.4, 0.3), DUNKEL, gl, Basis(Vector3.RIGHT, -0.5))
		for ix in 3:
			for iy in 2:
				var q := Vector2(richtung.y, -richtung.x)
				_licht_punkte.append([_pos(f, e + richtung * 0.75 + q * (ix - 1) * 1.1, 24.7 + iy * 0.9), Color(1.0, 0.97, 0.9)])
		welt.hindernisse.append(_rect(f, e, Vector2(0.9, 0.9)))
	# Anzeigetafel
	_box("gross", f, Vector2(0.0, -27.2), 4.8, Vector3(9.0, 3.6, 0.4), DUNKEL)
	_schrift(f, Vector2(0.0, -26.98), 7.0, "WÜSTENNADEL FC", 0.0, 70, Color("f2c43a"), 400.0)
	_schrift(f, Vector2(0.0, -26.98), 5.8, "2 : 1", 0.0, 140, Color.WHITE, 400.0)
	for l in [Vector2(-8.0, -21.0), Vector2(8.0, 21.0)]:
		bodenlicht.leuchte(_pos(f, l), 2.0)

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
		"kegel":
			var k := CylinderMesh.new()
			k.top_radius = 0.0
			k.bottom_radius = 0.5
			k.height = 1.0
			k.radial_segments = 12
			k.rings = 1
			m = k
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
