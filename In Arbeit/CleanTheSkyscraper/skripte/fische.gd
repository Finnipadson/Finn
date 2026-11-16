class_name Fische
# Die 20 Fische aus Code (kein Modell-Paket nötig): Körper als „Loft“ entlang x (Schwanz −x, Kopf +x) mit Profil für
# Höhe und Breite, Muster über shader/fisch.gdshader, Flossen als flache Polygone, Sonderteile (Stacheln, Schnabel,
# Säge, Hörner …). modell() normiert auf 1 m Länge (Rochen: Spannweite) – also mit Wirtschaft.FISCHE.groesse skalieren.
# Bilder für Index/Fischladen rendert Symbole ("f_" + id, Umriss "fu_" + id).

# k/b = Profil für halbe Höhe/Breite [größter Wert, Lage des Maximums (0 Schwanz … 1 Kopf), Form (klein = stumpf), Stiel]
# kasten = Querschnitt (2 rund, 4 eckig), buckel = Stirnbeule, welle = Schlängeln (Muräne)
# schwanz = [Art, Länge, Höhe], ruecken/after = Flossen-Umriss [[x, Abstand über Rücken bzw. unter Bauch], …]
# fl = Flossenfarbe, auge = [x, Größe], extra = Sonderteile
const FORM := {
	"sergeant": {"k": [0.26, 0.55, 0.7, 0.22], "b": [0.085, 0.55, 0.8, 0.3], "farbe": "d6cf6a", "bauch": "eef0e4", "muster": 1, "mf": "1e2226", "anzahl": 6.5,
		"schwanz": ["gabel", 0.2, 0.2], "ruecken": [[-0.32, 0.0], [-0.27, 0.07], [0.12, 0.1], [0.2, 0.0]], "after": [[-0.3, 0.0], [-0.24, 0.08], [-0.02, 0.06], [0.02, 0.0]], "fl": "c8c06a", "auge": [0.34, 0.035]},
	"koffer": {"k": [0.2, 0.5, 0.35, 0.3], "b": [0.17, 0.5, 0.35, 0.3], "kasten": 4.0, "farbe": "f2cf2e", "bauch": "f6e27a", "muster": 2, "mf": "1a1a1a", "anzahl": 9.0,
		"schwanz": ["rund", 0.16, 0.12], "ruecken": [[-0.26, 0.0], [-0.22, 0.06], [-0.12, 0.05], [-0.1, 0.0]], "after": [[-0.26, 0.0], [-0.22, 0.05], [-0.12, 0.04], [-0.1, 0.0]], "fl": "f0c020", "auge": [0.3, 0.045]},
	"sohal": {"k": [0.28, 0.55, 0.8, 0.18], "b": [0.075, 0.55, 0.8, 0.3], "farbe": "6f8fae", "bauch": "b9c9d8", "muster": 3, "mf": "263446", "anzahl": 13.0,
		"schwanz": ["lyra", 0.22, 0.24], "ruecken": [[-0.34, 0.0], [-0.3, 0.06], [0.2, 0.07], [0.25, 0.0]], "after": [[-0.32, 0.0], [-0.27, 0.06], [0.05, 0.05], [0.1, 0.0]], "fl": "2a3a52", "auge": [0.35, 0.03]},
	"igel": {"k": [0.34, 0.5, 0.55, 0.15], "b": [0.3, 0.5, 0.55, 0.15], "farbe": "a78a5c", "bauch": "efe6d2", "muster": 2, "mf": "3a2c1c", "anzahl": 10.0,
		"schwanz": ["rund", 0.14, 0.12], "ruecken": [[-0.3, 0.0], [-0.27, 0.06], [-0.18, 0.05], [-0.16, 0.0]], "fl": "b9a070", "auge": [0.3, 0.06], "extra": ["stacheln"]},
	"wimpel": {"k": [0.4, 0.6, 0.7, 0.12], "b": [0.065, 0.6, 0.8, 0.3], "farbe": "f4f4f0", "bauch": "ffffff", "muster": 1, "mf": "1c1c1c", "anzahl": 3.3,
		"schwanz": ["gabel", 0.18, 0.18], "ruecken": [[-0.05, 0.0], [0.08, 0.14], [-0.55, 0.5], [-0.5, 0.42], [-0.15, 0.05], [-0.2, 0.0]], "after": [[-0.3, 0.0], [-0.2, 0.12], [0.05, 0.08], [0.1, 0.0]], "fl": "f0d23c", "auge": [0.36, 0.035]},
	"papagei": {"k": [0.23, 0.55, 0.8, 0.25], "b": [0.1, 0.55, 0.8, 0.3], "farbe": "3fae9a", "bauch": "86d6c3", "muster": 6, "mf": "e78bb0", "anzahl": 7.0,
		"schwanz": ["lyra", 0.2, 0.2], "ruecken": [[-0.33, 0.0], [-0.28, 0.06], [0.2, 0.06], [0.25, 0.0]], "after": [[-0.3, 0.0], [-0.25, 0.05], [-0.02, 0.05], [0.02, 0.0]], "fl": "e78bb0", "auge": [0.34, 0.03], "extra": ["lippen"]},
	"kaiser": {"k": [0.38, 0.55, 0.75, 0.15], "b": [0.07, 0.55, 0.8, 0.3], "farbe": "1f3f86", "bauch": "27408a", "muster": 4, "mf": "f2d33a", "fleck": [0.42, 0.62, 0.35, 0.92],
		"schwanz": ["rund", 0.16, 0.18], "ruecken": [[-0.25, 0.0], [-0.4, 0.2], [-0.48, 0.24], [-0.3, 0.06], [0.2, 0.06], [0.25, 0.0]], "after": [[-0.25, 0.0], [-0.42, 0.18], [-0.46, 0.2], [-0.25, 0.05], [0.05, 0.05], [0.08, 0.0]], "fl": "2b4fa6", "auge": [0.36, 0.03]},
	"trompete": {"k": [0.045, 0.5, 0.35, 0.6], "b": [0.04, 0.5, 0.35, 0.6], "farbe": "b08a4c", "bauch": "d8c08a", "muster": 3, "mf": "6d5a2e", "anzahl": 4.0,
		"schwanz": ["rund", 0.08, 0.05], "ruecken": [[-0.42, 0.0], [-0.38, 0.04], [-0.3, 0.035], [-0.28, 0.0]], "after": [[-0.42, 0.0], [-0.38, 0.035], [-0.3, 0.03], [-0.28, 0.0]], "fl": "c89c58", "auge": [0.38, 0.016],
		"extra": [["schnabel", 0.3, 0.012]]},
	"feuer": {"k": [0.22, 0.55, 0.8, 0.25], "b": [0.1, 0.55, 0.8, 0.3], "farbe": "c7442e", "bauch": "f0d8c8", "muster": 7, "mf": "f6ece0", "anzahl": 9.0,
		"schwanz": ["rund", 0.16, 0.15], "after": [[-0.3, 0.0], [-0.24, 0.08], [-0.05, 0.06], [0.0, 0.0]], "fl": "e9b8a8", "auge": [0.36, 0.03], "extra": ["feuer"]},
	"hornhecht": {"k": [0.07, 0.45, 0.6, 0.4], "b": [0.045, 0.45, 0.6, 0.4], "farbe": "3f7f6e", "bauch": "e2ece8", "muster": 0,
		"schwanz": ["gabel", 0.14, 0.12], "ruecken": [[-0.42, 0.0], [-0.38, 0.05], [-0.28, 0.04], [-0.26, 0.0]], "after": [[-0.4, 0.0], [-0.36, 0.05], [-0.27, 0.04], [-0.25, 0.0]], "fl": "5f9f8a", "auge": [0.4, 0.02],
		"extra": [["schnabel", 0.32, 0.01]]},
	"barrakuda": {"k": [0.11, 0.45, 0.8, 0.25], "b": [0.07, 0.45, 0.8, 0.3], "farbe": "6f7d88", "bauch": "dfe5ea", "muster": 1, "mf": "3c4650", "anzahl": 16.0,
		"schwanz": ["gabel", 0.18, 0.15], "ruecken": [[-0.25, 0.0], [-0.2, 0.08], [-0.12, 0.06], [-0.1, 0.0]], "after": [[-0.27, 0.0], [-0.22, 0.06], [-0.13, 0.04], [-0.11, 0.0]], "fl": "4f5c66", "auge": [0.38, 0.022]},
	"adlerrochen": {"k": [0.06, 0.62, 0.8, 0.05], "b": [0.75, 0.52, 0.9, 0.02], "farbe": "2c3440", "bauch": "f2f2f0", "muster": 2, "mf": "f6f6f6", "anzahl": 12.0,
		"schwanz": ["keine", 0.0, 0.0], "fl": "2c3440", "auge": [0.36, 0.03], "extra": [["peitsche", 1.3, 0.012], "kopf_rochen"]},
	"muraene": {"k": [0.055, 0.5, 0.35, 0.5], "b": [0.04, 0.5, 0.35, 0.5], "welle": 0.06, "farbe": "5a4a2c", "bauch": "8a7a4c", "muster": 6, "mf": "2a2416", "anzahl": 18.0,
		"schwanz": ["rund", 0.06, 0.05], "ruecken": [[-0.48, 0.0], [-0.45, 0.03], [0.3, 0.03], [0.33, 0.0]], "after": [[-0.48, 0.0], [-0.45, 0.025], [0.0, 0.025], [0.03, 0.0]], "fl": "4a3c22", "auge": [0.44, 0.014]},
	"gitarre": {"k": [0.085, 0.45, 0.7, 0.3], "b": [0.2, 0.75, 0.8, 0.22], "farbe": "b59f72", "bauch": "eee6d2", "muster": 2, "mf": "ece0c4", "anzahl": 14.0,
		"schwanz": ["hai", 0.2, 0.15], "ruecken": [[-0.05, 0.0], [-0.08, 0.13], [-0.14, 0.12], [-0.17, 0.0]], "fl": "a88f62", "auge": [0.3, 0.02],
		"extra": [["flosse2", -0.3, 0.09]]},
	"napoleon": {"k": [0.3, 0.55, 0.75, 0.2], "b": [0.12, 0.55, 0.8, 0.3], "buckel": 0.09, "farbe": "2f8a7a", "bauch": "6fb7a6", "muster": 6, "mf": "1f5f56", "anzahl": 10.0,
		"schwanz": ["rund", 0.2, 0.2], "ruecken": [[-0.33, 0.0], [-0.28, 0.07], [0.2, 0.06], [0.25, 0.0]], "after": [[-0.3, 0.0], [-0.25, 0.08], [-0.02, 0.06], [0.02, 0.0]], "fl": "2a7f70", "auge": [0.36, 0.025], "extra": ["lippen"]},
	"segel": {"k": [0.11, 0.5, 0.8, 0.25], "b": [0.06, 0.5, 0.8, 0.3], "farbe": "1f3f7a", "bauch": "d8e0ea", "muster": 1, "mf": "6f9fd6", "anzahl": 14.0,
		"schwanz": ["halbmond", 0.16, 0.22], "ruecken": [[-0.3, 0.0], [-0.2, 0.22], [0.15, 0.32], [0.3, 0.12], [0.32, 0.0]], "after": [[-0.3, 0.0], [-0.26, 0.06], [-0.16, 0.04], [-0.14, 0.0]], "fl": "2a5fa8", "auge": [0.4, 0.022],
		"extra": [["schnabel", 0.32, 0.016]]},
	"manta": {"k": [0.085, 0.6, 0.7, 0.05], "b": [1.0, 0.55, 0.9, 0.02], "farbe": "1e2228", "bauch": "f2f2f2", "muster": 0,
		"schwanz": ["keine", 0.0, 0.0], "fl": "1e2228", "auge": [0.42, 0.03], "extra": [["peitsche", 0.35, 0.015], "hoerner"]},
	"quaste": {"k": [0.21, 0.55, 0.7, 0.35], "b": [0.13, 0.55, 0.8, 0.35], "farbe": "283a5a", "bauch": "3f5272", "muster": 2, "mf": "c8d2e0", "anzahl": 10.0,
		"schwanz": ["drei", 0.22, 0.22], "ruecken": [[0.0, 0.0], [-0.04, 0.12], [-0.12, 0.1], [-0.14, 0.0]], "fl": "33496e", "auge": [0.36, 0.035], "extra": ["lappen"]},
	"saege": {"k": [0.09, 0.55, 0.75, 0.25], "b": [0.13, 0.65, 0.8, 0.25], "farbe": "8a8064", "bauch": "e8e2d2", "muster": 0,
		"schwanz": ["hai", 0.2, 0.16], "ruecken": [[0.05, 0.0], [0.0, 0.12], [-0.06, 0.11], [-0.1, 0.0]], "fl": "7a7058", "auge": [0.36, 0.018],
		"extra": [["saege", 0.42], ["flosse2", -0.28, 0.09]]},
	"walhai": {"k": [0.15, 0.55, 0.55, 0.22], "b": [0.15, 0.6, 0.5, 0.22], "farbe": "3c4c60", "bauch": "e6e8ea", "muster": 5, "mf": "f2f2f2", "anzahl": 22.0,
		"schwanz": ["hai", 0.26, 0.24], "ruecken": [[0.02, 0.0], [-0.04, 0.13], [-0.1, 0.12], [-0.14, 0.0]], "fl": "33414f", "auge": [0.42, 0.012],
		"extra": ["maul", ["flosse2", -0.32, 0.06]]},
}

const SCHWANZ := {
	"gabel": [[0, 0.15], [-1, 1], [-0.55, 0], [-1, -1], [0, -0.15]],
	"rund": [[0, 0.3], [-0.6, 0.8], [-1, 0.4], [-1, -0.4], [-0.6, -0.8], [0, -0.3]],
	"lyra": [[0, 0.15], [-1, 1.05], [-0.72, 0.45], [-0.68, 0], [-0.72, -0.45], [-1, -1.05], [0, -0.15]],
	"halbmond": [[0, 0.12], [-0.9, 1.1], [-0.45, 0.15], [-0.45, -0.15], [-0.9, -1.1], [0, -0.12]],
	"hai": [[0, 0.15], [-1, 1.1], [-0.72, 0.12], [-0.6, -0.2], [-0.72, -0.65], [0, -0.15]],
	"drei": [[0, 0.3], [-0.5, 0.9], [-0.55, 0.32], [-1, 0.16], [-1, -0.16], [-0.55, -0.32], [-0.5, -0.9], [0, -0.3]],
}

static var _cache := {}

static func daten(id: String) -> Dictionary:
	return Wirtschaft.fisch(id)

# Fertiges Modell (1 m lang, Mitte im Ursprung, Kopf nach +x). umriss = einfarbig dunkel (fehlende Fische im Index)
static func modell(id: String, umriss := false) -> Node3D:
	var f: Dictionary = FORM.get(id, FORM.sergeant)
	var wurzel := Node3D.new()
	wurzel.name = "Fisch_" + id
	var n := Node3D.new()
	wurzel.add_child(n)
	var koerper: Material
	var flossen: Material
	if umriss:
		var u := StandardMaterial3D.new()
		u.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		u.albedo_color = Color("2a3441")
		u.cull_mode = BaseMaterial3D.CULL_DISABLED
		koerper = u
		flossen = u
	else:
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shader/fisch.gdshader")
		sm.set_shader_parameter("farbe", Color(str(f.farbe)))
		sm.set_shader_parameter("bauch", Color(str(f.bauch)))
		sm.set_shader_parameter("muster_farbe", Color(str(f.get("mf", "000000"))))
		sm.set_shader_parameter("muster", int(f.get("muster", 0)))
		sm.set_shader_parameter("anzahl", float(f.get("anzahl", 5.0)))
		var fl: Array = f.get("fleck", [0.3, 0.7, 0.3, 1.0])
		sm.set_shader_parameter("fleck", Vector4(fl[0], fl[1], fl[2], fl[3]))
		koerper = sm
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(str(f.get("fl", f.farbe)))
		fm.roughness = 0.6
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		flossen = fm
	_rumpf(n, f, koerper)
	var sw: Array = f.get("schwanz", ["gabel", 0.2, 0.2])
	if SCHWANZ.has(sw[0]):
		var pts := PackedVector2Array()
		var stiel := _hoehe(f, 0.0)
		for q in SCHWANZ[sw[0]]:
			pts.append(Vector2(-0.49 + float(q[0]) * float(sw[1]), _mitte_y(f, 0.0) + float(q[1]) * maxf(float(sw[2]), stiel)))
		_flaeche_xy(n, pts, _welle(f, 0.0), flossen)
	for art in ["ruecken", "after"]:
		if f.has(art):
			var pts := PackedVector2Array()
			for q in f[art]:
				var x: float = q[0]
				var t := x + 0.5
				var rand := _mitte_y(f, t) + (_hoehe(f, t) - 0.01) * (1.0 if art == "ruecken" else -1.0)
				pts.append(Vector2(x, rand + float(q[1]) * (1.0 if art == "ruecken" else -1.0)))
			_flaeche_xy(n, pts, _welle(f, 0.5), flossen)
	# Brustflossen (außer Rochen)
	if float(f.b[0]) < 0.4:
		for s in [-1.0, 1.0]:
			var x0 := 0.2
			var t := x0 + 0.5
			var y0 := _mitte_y(f, t) - _hoehe(f, t) * 0.25
			var z0: float = s * _breite(f, t) * 0.85
			var g := 0.1 + _hoehe(f, t) * 0.3
			_dreieck(n, Vector3(x0 + 0.03, y0 + 0.02, z0), Vector3(x0 - g, y0 - g * 0.2, z0 + s * g * 0.55), Vector3(x0 - g * 0.6, y0 - g * 0.6, z0 + s * g * 0.2), flossen)
	# Augen
	var au: Array = f.get("auge", [0.35, 0.03])
	var ta: float = float(au[0]) + 0.5
	var ra: float = au[1]
	for s in [-1.0, 1.0]:
		var p := Vector3(au[0], _mitte_y(f, ta) + _hoehe(f, ta) * 0.3, s * _breite(f, ta) * 0.82)
		var weiss := Bau.matt("f4f4f0", 0.3) if not umriss else koerper
		var schwarz := Bau.matt("0c0d10", 0.15) if not umriss else koerper
		Andenken._kugel_mesh(n, ra, p, weiss, 8)
		Andenken._kugel_mesh(n, ra * 0.55, p + Vector3(ra * 0.2, 0, s * ra * 0.6), schwarz, 8)
	for e in f.get("extra", []):
		_extra(n, f, e, koerper if umriss else flossen, koerper)
	# auf 1 m normieren (größte waagerechte Ausdehnung), Mitte in den Ursprung
	var box := RaumBau.aabb(n)
	var gross := maxf(box.size.x, box.size.z)
	if gross > 0.0:
		n.scale = Vector3.ONE / gross
		n.position = -box.get_center() / gross
	return wurzel

# ---------------------------------------------------------------- Profil
static func _profil(t: float, p: Array) -> float:
	var tt := clampf(t, 0.0, 1.0)
	var q := log(0.5) / log(clampf(float(p[1]), 0.05, 0.95))
	var s := maxf(sin(PI * pow(tt, q)), 0.0)
	return float(p[0]) * (pow(s, float(p[2])) + float(p[3]) * (1.0 - smoothstep(0.0, 0.45, tt)) * (1.0 - pow(s, float(p[2]))))

static func _hoehe(f: Dictionary, t: float) -> float:
	return _profil(t, f.k)

static func _breite(f: Dictionary, t: float) -> float:
	return _profil(t, f.b)

static func _mitte_y(f: Dictionary, t: float) -> float:
	return float(f.get("buckel", 0.0)) * pow(maxf(0.0, sin(PI * clampf((t - 0.55) / 0.45, 0.0, 1.0))), 1.5)

static func _welle(f: Dictionary, t: float) -> float:
	return float(f.get("welle", 0.0)) * sin(t * TAU * 1.5)

# Körper: Ringe entlang x, Querschnitt Superellipse; flache Dreiecke (Low-Poly)
static func _rumpf(n: Node3D, f: Dictionary, m: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ringe := 30
	var seg := 16
	var e := 2.0 / float(f.get("kasten", 2.0))
	var ringe_p: Array = []
	for i in ringe + 1:
		var t := float(i) / ringe
		var hh := maxf(_hoehe(f, t), 0.0005)
		var bb := maxf(_breite(f, t), 0.0005)
		var r: Array = []
		for j in seg + 1:
			var a := TAU * j / seg
			var ca := cos(a)
			var sa := sin(a)
			var cy := signf(ca) * pow(absf(ca), e)
			var sz := signf(sa) * pow(absf(sa), e)
			r.append([Vector3(t - 0.5, _mitte_y(f, t) + cy * hh, _welle(f, t) + sz * bb), Vector2(t, (ca + 1.0) * 0.5)])
		ringe_p.append(r)
	for i in ringe:
		var mi := Vector3(float(i) / ringe - 0.5 + 0.5 / ringe, _mitte_y(f, (i + 0.5) / ringe), _welle(f, (i + 0.5) / ringe))
		for j in seg:
			var a: Array = ringe_p[i][j]
			var b: Array = ringe_p[i + 1][j]
			var c: Array = ringe_p[i + 1][j + 1]
			var d: Array = ringe_p[i][j + 1]
			_tri_uv(st, a, b, c, mi)
			_tri_uv(st, a, c, d, mi)
	# Deckel am Schwanzstiel
	var r0: Array = ringe_p[0]
	var mitte := [Vector3(-0.5, _mitte_y(f, 0.0), _welle(f, 0.0)), Vector2(0.0, 0.5)]
	for j in seg:
		_tri_uv(st, mitte, r0[j], r0[j + 1], Vector3(0.5, mitte[0].y, mitte[0].z))
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = m
	n.add_child(mesh)

# Dreieck mit Normale weg vom Punkt innen (Godot: Vorderseite im Uhrzeigersinn)
static func _tri_uv(st: SurfaceTool, a: Array, b: Array, c: Array, innen: Vector3) -> void:
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	var nrm := (pb - pa).cross(pc - pa)
	if nrm.length_squared() < 1e-12:
		return
	nrm = nrm.normalized()
	var raus := ((pa + pb + pc) / 3.0 - innen)
	if nrm.dot(raus) < 0.0:
		nrm = -nrm
	var ecken := [a, b, c] if (pc - pa).cross(pb - pa).dot(nrm) > 0.0 else [a, c, b]
	for v in ecken:
		st.set_normal(nrm)
		st.set_uv(v[1])
		st.add_vertex(v[0])

static func _flaeche_xy(n: Node3D, pts: PackedVector2Array, z: float, m: Material) -> void:
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		pts.reverse()
		idx = Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, idx.size(), 3):
		var a := Vector3(pts[idx[i]].x, pts[idx[i]].y, z)
		var b := Vector3(pts[idx[i + 1]].x, pts[idx[i + 1]].y, z)
		var c := Vector3(pts[idx[i + 2]].x, pts[idx[i + 2]].y, z)
		var ecken := [a, b, c] if (c - a).cross(b - a).dot(Vector3(0, 0, 1)) > 0.0 else [a, c, b]
		for v in ecken:
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	n.add_child(mi)

static func _dreieck(n: Node3D, a: Vector3, b: Vector3, c: Vector3, m: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nrm := (b - a).cross(c - a).normalized()
	var ecken := [a, b, c] if (c - a).cross(b - a).dot(nrm) > 0.0 else [a, c, b]
	for v in ecken:
		st.set_normal(nrm)
		st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	n.add_child(mi)

# Kegel/Zylinder von a nach b
static func _stab(n: Node3D, a: Vector3, b: Vector3, r_a: float, r_b: float, m: Material, seg := 6) -> void:
	var z := Bau.zylinder(r_b, r_a, a.distance_to(b), m, seg)
	var d := (b - a).normalized()
	var achse := Vector3.UP.cross(d)
	var basis := Basis.IDENTITY
	if achse.length() > 1e-4:
		basis = Basis(achse.normalized(), Vector3.UP.angle_to(d))
	elif d.y < 0.0:
		basis = Basis(Vector3.RIGHT, PI)
	z.transform = Transform3D(basis, (a + b) * 0.5)
	n.add_child(z)

static func _extra(n: Node3D, f: Dictionary, e: Variant, fl: Material, koerper: Material) -> void:
	var art: String = e if e is String else str(e[0])
	match art:
		"stacheln":
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for i in 70:
				var t := rng.randf_range(0.15, 0.92)
				var a := rng.randf() * TAU
				var hh := _hoehe(f, t)
				var bb := _breite(f, t)
				var p := Vector3(t - 0.5, cos(a) * hh, sin(a) * bb)
				var d := Vector3(0.15, cos(a), sin(a)).normalized()
				_stab(n, p - d * 0.01, p + d * 0.07, 0.012, 0.001, fl, 5)
		"feuer":
			var weiss := Bau.matt("f6ece0", 0.6)
			var rot := Bau.matt("b8341f", 0.6)
			for i in 12:   # lange Rückenstacheln mit Häutchen
				var x := 0.2 - i * 0.045
				var t := x + 0.5
				var top := _hoehe(f, t)
				var h := 0.18 + 0.06 * sin(i * 0.7)
				_dreieck(n, Vector3(x, top - 0.01, 0), Vector3(x - 0.08, top + h, 0), Vector3(x - 0.035, top + h * 0.35, 0), weiss if i % 2 == 0 else rot)
			for s in [-1.0, 1.0]:   # Fächer-Brustflossen
				for i in 7:
					var w := -0.9 + i * 0.3
					var basis := Vector3(0.18, -0.02, s * _breite(f, 0.68) * 0.8)
					var spitze := basis + Vector3(-0.26 * cos(w * 0.5), 0.2 * sin(w), s * 0.12)
					_dreieck(n, basis, spitze, basis + Vector3(-0.08, 0.04 * sin(w + 0.3), s * 0.03), weiss if i % 2 == 0 else rot)
		"schnabel":
			var y := _mitte_y(f, 1.0)
			_stab(n, Vector3(0.48, y, 0), Vector3(0.48 + float(e[1]), y, 0), float(e[2]), float(e[2]) * 0.25, koerper if fl == koerper else Bau.matt(str(f.get("fl", f.farbe)), 0.5), 6)
		"saege":
			var lang: float = e[1]
			var saege := Bau.matt("b7ad8c", 0.6)
			RaumBau.box(n, Vector3(lang, 0.012, 0.05), Vector3(0.48 + lang * 0.5, 0.0, 0), saege if fl != koerper else koerper)
			var k := 0
			var x := 0.52
			while x < 0.48 + lang - 0.01:
				for s in [-1.0, 1.0]:
					RaumBau.box(n, Vector3(0.008, 0.008, 0.024), Vector3(x, 0.0, s * 0.032), saege if fl != koerper else koerper)
				x += 0.024
				k += 1
		"hoerner":
			for s in [-1.0, 1.0]:
				var b := RaumBau.box(n, Vector3(0.14, 0.02, 0.05), Vector3(0.52, 0.0, s * 0.11), fl)
				b.rotation.x = s * 0.9
		"kopf_rochen":
			Andenken._kugel_mesh(n, 0.07, Vector3(0.47, 0.0, 0.0), koerper, 8)
		"peitsche":
			_stab(n, Vector3(-0.48, 0.0, 0.0), Vector3(-0.48 - float(e[1]), 0.0, 0.0), float(e[2]), 0.002, fl, 5)
		"lippen":
			var l := Andenken._kugel_mesh(n, _hoehe(f, 0.97) * 1.3 + 0.012, Vector3(0.49, _mitte_y(f, 0.98) - 0.01, 0), fl, 8)
			l.scale = Vector3(1.0, 0.7, 1.0)
		"maul":
			RaumBau.box(n, Vector3(0.03, 0.02, _breite(f, 0.97) * 1.5 + 0.03), Vector3(0.49, -0.02, 0), Bau.matt("1a1e24", 0.5) if fl != koerper else koerper)
		"lappen":
			for p in [Vector3(0.18, -0.12, 0.11), Vector3(0.18, -0.12, -0.11), Vector3(-0.12, -0.16, 0.06), Vector3(-0.12, -0.16, -0.06), Vector3(-0.2, 0.16, 0.0), Vector3(-0.22, -0.17, 0.0)]:
				var l := Andenken._kugel_mesh(n, 0.05, p, koerper, 8)
				l.scale = Vector3(1.6, 0.7, 0.6)
				_dreieck(n, p + Vector3(-0.05, 0, 0), p + Vector3(-0.14, 0.04 * signf(p.y + 0.001), 0), p + Vector3(-0.12, -0.05 * signf(p.y + 0.001), 0), fl)
		"flosse2":
			var x: float = e[1]
			var t := x + 0.5
			var top := _mitte_y(f, t) + _hoehe(f, t) - 0.01
			var h: float = e[2]
			_flaeche_xy(n, PackedVector2Array([Vector2(x + 0.03, top), Vector2(x - 0.02, top + h), Vector2(x - 0.06, top + h * 0.9), Vector2(x - 0.05, top)]), 0.0, fl)
