class_name Bau
# Werkzeugkasten zum Bauen aus Code: Grundrisse, Fassaden-Mesh aus Stockwerken, Rahmen, Materialien.
# Ein Stockwerk ist ein Dictionary {poly: PackedVector2Array (x,z, beliebige Drehrichtung), y0: float, h: float}.
# Fassaden-UV ist in Metern: x = Weg entlang des Umfangs, y = Höhe. TANGENT zeigt in Richtung wachsender UV.x.

const TURM_SHADER := preload("res://shader/turm.gdshader")
const FASSADE_SHADER := preload("res://shader/fassade.gdshader")

# ---------------------------------------------------------------- Materialien
static func shader_mat(shader: Shader, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

static func metall(farbe: String, rau := 0.3, met := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(farbe)
	m.metallic = met
	m.roughness = rau
	return m

static func matt(farbe: String, rau := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(farbe)
	m.roughness = rau
	return m

# ---------------------------------------------------------------- Grundrisse
# Y-Form: drei Flügel (Richtung -90°, 30°, 150°) mit runden Enden um einen Kern.
static func y_grundriss(laengen: Array, breite: float, kern: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var r_innen := (breite * 0.5) / sin(PI / 3.0)
	for k in 3:
		var a := TAU * k / 3.0 - PI / 2.0
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x)
		var l := maxf(float(laengen[k]), kern)
		if l > kern + 1.0:
			var m := dir * (l - breite * 0.5)
			for j in 9:
				var t := -PI / 2.0 + PI * j / 8.0
				p.append(m + (dir * cos(t) + perp * sin(t)) * breite * 0.5)
		else:
			for j in 5:
				var t := a - PI / 3.0 + (2.0 * PI / 3.0) * j / 4.0
				p.append(Vector2(cos(t), sin(t)) * kern)
		var am := a + PI / 3.0
		p.append(Vector2(cos(am), sin(am)) * maxf(r_innen, kern * 0.92))
	return p

static func kreis(r: float, n := 24, dreh := 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for j in n:
		var t := dreh + TAU * j / n
		p.append(Vector2(cos(t), sin(t)) * r)
	return p

static func rechteck(bx: float, bz: float, mx := 0.0, mz := 0.0, dreh := 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for e in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		p.append(Vector2(e.x * bx * 0.5, e.y * bz * 0.5).rotated(dreh) + Vector2(mx, mz))
	return p

static func mitte(p: PackedVector2Array) -> Vector2:
	var m := Vector2.ZERO
	for v in p:
		m += v
	return m / p.size()

static func umfang(p: PackedVector2Array) -> float:
	var u := 0.0
	for k in p.size():
		u += p[k].distance_to(p[(k + 1) % p.size()])
	return u

# Außen-Normale einer Kante a→b (zeigt vom Grundriss weg)
static func aussen(a: Vector2, b: Vector2, m: Vector2) -> Vector2:
	var n := Vector2(b.y - a.y, -(b.x - a.x)).normalized()
	return -n if n.dot((a + b) * 0.5 - m) < 0.0 else n

# ---------------------------------------------------------------- Fassade + Dächer
static func baue(stw: Array, wand: Material, dach: Material) -> Node3D:
	var w := SurfaceTool.new()
	w.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := SurfaceTool.new()
	d.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in stw.size():
		var s: Dictionary = stw[i]
		var p: PackedVector2Array = s.poly
		var y0: float = s.y0
		var y1: float = s.y0 + s.h
		var m := mitte(p)
		var weg := 0.0
		for k in p.size():
			var a := p[k]
			var b := p[(k + 1) % p.size()]
			var lang := a.distance_to(b)
			var n2 := aussen(a, b, m)
			var n := Vector3(n2.x, 0, n2.y)
			var tg := Vector3(b.x - a.x, 0, b.y - a.y).normalized()
			for e in [[a, weg, y0], [b, weg + lang, y0], [b, weg + lang, y1], [a, weg, y0], [b, weg + lang, y1], [a, weg, y1]]:
				w.set_normal(n)
				w.set_tangent(Plane(tg, 1.0))
				w.set_uv(Vector2(e[1], e[2]))
				w.add_vertex(Vector3(e[0].x, e[2], e[0].y))
			weg += lang
		var naechste: PackedVector2Array = stw[i + 1].poly if i + 1 < stw.size() else PackedVector2Array()
		if naechste != p:
			for t in Geometry2D.triangulate_polygon(p):
				d.set_normal(Vector3.UP)
				d.set_uv(p[t] * 0.1)
				d.add_vertex(Vector3(p[t].x, y1, p[t].y))
	var knoten := Node3D.new()
	var mw := MeshInstance3D.new()
	mw.mesh = w.commit()
	mw.material_override = wand
	knoten.add_child(mw)
	var md := MeshInstance3D.new()
	md.mesh = d.commit()
	md.material_override = dach
	knoten.add_child(md)
	return knoten

# Echte Rahmen: Pfosten an jeder Fenstergrenze + vorstehendes Band je Stockwerk (MultiMesh)
static func rahmen(stw: Array, fb: float, band_anteil: float, m: Material) -> MultiMeshInstance3D:
	var xf: Array[Transform3D] = []
	for s in stw:
		var p: PackedVector2Array = s.poly
		var y0: float = s.y0
		var h: float = s.h
		var bh := h * band_anteil
		var mi := mitte(p)
		var weg := 0.0
		for k in p.size():
			var a := p[k]
			var b := p[(k + 1) % p.size()]
			var lang := a.distance_to(b)
			if lang < 0.01:
				continue
			var d2 := (b - a) / lang
			var n2 := aussen(a, b, mi)
			var dx := Vector3(d2.x, 0, d2.y)
			var nz := Vector3(n2.x, 0, n2.y)
			var mb := a + (b - a) * 0.5 + n2 * 0.17
			xf.append(Transform3D(Basis(dx * (lang + 0.12), Vector3.UP * bh, nz * 0.36), Vector3(mb.x, y0 + bh * 0.5, mb.y)))
			for j in range(int(ceil(weg / fb)), int(floor((weg + lang) / fb)) + 1):
				var q := a + d2 * (j * fb - weg) + n2 * 0.13
				xf.append(Transform3D(Basis(dx * 0.16, Vector3.UP * (h - bh), nz * 0.26), Vector3(q.x, y0 + bh + (h - bh) * 0.5, q.y)))
			weg += lang
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	return mmi

static func zylinder(r_oben: float, r_unten: float, hoehe: float, m: Material, seg := 24) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_oben
	cm.bottom_radius = r_unten
	cm.height = hoehe
	cm.radial_segments = seg
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = m
	return mi
