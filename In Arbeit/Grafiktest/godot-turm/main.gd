extends Node3D
# Turm-Varianten für die Idee „Fenster putzen am höchsten Turm der Welt“.
# Alles wird aus Code erzeugt: Grundriss pro Stockwerk → Fassade + Dächer, Fenster per Shader.
# Bilder: godot --path . --write-movie bild.png --fixed-fps 30 --quit-after 20 -- --turm=1 --ansicht=1

const SONNE_DIR := Vector3(0.55, 0.5, 0.4)
var turm := 1
var ansicht := 1
var rng := RandomNumberGenerator.new()
var fassade_shader: Shader
var stockwerke: Array = []   # [{poly, y0, h}]
var oben := 0.0               # Dachhöhe ohne Spitze
var spitze := 0.0             # Höhe inkl. Spitze
var fenster_zahl := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--turm="):
			turm = int(a.split("=")[1])
		if a.begins_with("--ansicht="):
			ansicht = int(a.split("=")[1])
	rng.seed = 11
	fassade_shader = load("res://shader/fassade.gdshader")
	_umgebung()
	_boden()
	match turm:
		1: _wuestennadel()
		2: _drehturm()
		_: _stapelriese()
	_stadt()
	_kamera()
	_beschriftung()

# ---------------------------------------------------------------- Welt
func _umgebung() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shader/himmel.gdshader")
	sm.set_shader_parameter("sonne", SONNE_DIR.normalized())
	sm.set_shader_parameter("horizont", Color("e9dcc4"))
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.68
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.fog_enabled = true
	env.fog_light_color = Color("e9dcc4")
	env.fog_density = 0.00011
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sonne := DirectionalLight3D.new()
	sonne.light_color = Color("ffe6bf")
	sonne.light_energy = 1.4
	sonne.shadow_enabled = true
	sonne.directional_shadow_max_distance = 3000.0
	add_child(sonne)
	sonne.basis = Basis.looking_at(-SONNE_DIR.normalized(), Vector3.UP)

func _boden() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(60000, 60000)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("d9b47a")
	m.roughness = 1.0
	var b := MeshInstance3D.new()
	b.mesh = pm
	b.material_override = m
	add_child(b)
	# Stadtfläche + Platz um den Turm
	var platz := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1700.0
	cm.bottom_radius = 1700.0
	cm.height = 0.2
	cm.radial_segments = 64
	platz.mesh = cm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color("b9ad9c")
	pmat.roughness = 0.95
	platz.material_override = pmat
	platz.position.y = 0.05
	add_child(platz)
	# Dünen am Horizont
	for i in 40:
		var a := rng.randf() * TAU
		var d := 4000.0 + rng.randf() * 9000.0
		var duene := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		duene.mesh = sm
		duene.material_override = m
		duene.position = Vector3(cos(a) * d, -20, sin(a) * d)
		duene.scale = Vector3(500 + rng.randf() * 900, 60 + rng.randf() * 120, 400 + rng.randf() * 700)
		duene.rotation.y = rng.randf() * TAU
		add_child(duene)

func fassade(params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = fassade_shader
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

# ---------------------------------------------------------------- Mesh aus Stockwerken
# stockwerke: Array von {poly: PackedVector2Array (x,z), y0, h}
func baue(stw: Array, wand: Material, dach: Material) -> Node3D:
	var w := SurfaceTool.new()
	w.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := SurfaceTool.new()
	d.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in stw.size():
		var s: Dictionary = stw[i]
		var p: PackedVector2Array = s.poly
		var y0: float = s.y0
		var y1: float = s.y0 + s.h
		var mitte := Vector2.ZERO
		for v in p:
			mitte += v
		mitte /= p.size()
		var weg := 0.0
		for k in p.size():
			var a := p[k]
			var b := p[(k + 1) % p.size()]
			var lang := a.distance_to(b)
			var n2 := Vector2(b.y - a.y, -(b.x - a.x)).normalized()
			if n2.dot((a + b) * 0.5 - mitte) < 0.0:
				n2 = -n2
			var n := Vector3(n2.x, 0, n2.y)
			var ecken := [[a, weg, y0], [b, weg + lang, y0], [b, weg + lang, y1], [a, weg, y0], [b, weg + lang, y1], [a, weg, y1]]
			for e in ecken:
				w.set_normal(n)
				w.set_uv(Vector2(e[1], e[2]))
				w.add_vertex(Vector3(e[0].x, e[2], e[0].y))
			weg += lang
		var naechste: PackedVector2Array = stw[i + 1].poly if i + 1 < stw.size() else PackedVector2Array()
		if naechste != p:
			var tri := Geometry2D.triangulate_polygon(p)
			for t in tri:
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
	add_child(knoten)
	return knoten

func zaehle_fenster(stw: Array, breite: float) -> int:
	var n := 0
	for s in stw:
		var p: PackedVector2Array = s.poly
		var umfang := 0.0
		for k in p.size():
			umfang += p[k].distance_to(p[(k + 1) % p.size()])
		n += int(umfang / breite)
	return n

func betonmat(farbe := "c9c4bb") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(farbe)
	m.roughness = 0.8
	return m

# ---------------------------------------------------------------- Grundrisse
func y_grundriss(laengen: Array, breite: float, kern: float) -> PackedVector2Array:
	# Y-Form: drei Flügel (0°, 120°, 240°) mit runden Enden, verbunden um einen Kern
	var p := PackedVector2Array()
	var r_innen := (breite * 0.5) / sin(PI / 3.0)
	for k in 3:
		var a := TAU * k / 3.0 - PI / 2.0
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x)
		var l := maxf(float(laengen[k]), kern)
		if l > kern + 1.0:
			var spitze_m := dir * (l - breite * 0.5)
			for j in 9:
				var t := -PI / 2.0 + PI * j / 8.0
				p.append(spitze_m + (dir * cos(t) + perp * sin(t)) * breite * 0.5)
		else:
			for j in 5:
				var t := a - PI / 3.0 + (2.0 * PI / 3.0) * j / 4.0
				p.append(Vector2(cos(t), sin(t)) * kern)
		var am := a + PI / 3.0
		p.append(Vector2(cos(am), sin(am)) * maxf(r_innen, kern * 0.92))
	return p

func kreis(r: float, n := 24, dreh := 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for j in n:
		var t := dreh + TAU * j / n
		p.append(Vector2(cos(t), sin(t)) * r)
	return p

func runde_ecken_quadrat(seite: float, dreh: float, n := 40, haerte := 5.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for j in n:
		var t := TAU * j / n
		var c := absf(cos(t))
		var s := absf(sin(t))
		var r := seite * 0.5 / pow(pow(c, haerte) + pow(s, haerte), 1.0 / haerte)
		p.append(Vector2(cos(t + dreh), sin(t + dreh)) * r)
	return p

func rechteck(bx: float, bz: float, mx := 0.0, mz := 0.0, dreh := 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for e in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		p.append(Vector2(e.x * bx * 0.5, e.y * bz * 0.5).rotated(dreh) + Vector2(mx, mz))
	return p

# ---------------------------------------------------------------- Variante 1: Wüstennadel (Y-Form, Spirale aus Stufen)
func _wuestennadel() -> void:
	var h := 4.2
	var laengen := [60.0, 60.0, 60.0]
	var breite := 27.0
	var kern := 15.0
	var n := 168
	for f in n:
		if f >= 18 and (f - 18) % 6 == 0:
			var w := ((f - 18) / 6) % 3
			laengen[w] = maxf(kern, laengen[w] - 5.5)
		var b := breite * (1.0 - f / 420.0)
		var poly: PackedVector2Array
		if laengen.max() <= kern + 0.5:
			poly = kreis(kern * (1.0 - (f - 140) / 120.0), 24)
		else:
			poly = y_grundriss(laengen, b, kern)
		stockwerke.append({"poly": poly, "y0": f * h, "h": h})
	oben = n * h
	var glas := fassade({"glas": Color("35587a"), "rahmen": Color("b4bac2"), "bruestung": Color("8c96a1"), "stock": h, "fenster_breite": 1.5, "metall": 0.5})
	baue(stockwerke, glas, betonmat())
	fenster_zahl = zaehle_fenster(stockwerke, 1.5)
	var nadel := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 9.0
	cm.height = 190.0
	nadel.mesh = cm
	nadel.material_override = fassade({"glas": Color("9fb4c8"), "rahmen": Color("e2e4e8"), "bruestung": Color("c9ced4"), "stock": 6.0, "fenster_breite": 3.0, "dreckig": 0.0})
	nadel.position.y = oben + 95.0
	add_child(nadel)
	spitze = oben + 190.0

# ---------------------------------------------------------------- Variante 2: Drehturm (gedreht + verjüngt, goldenes Glas)
func _drehturm() -> void:
	var h := 4.0
	var n := 135
	for f in n:
		var t := float(f) / n
		var seite := lerpf(78.0, 38.0, t)
		stockwerke.append({"poly": runde_ecken_quadrat(seite, deg_to_rad(f * 1.1), 40, 14.0), "y0": f * h, "h": h})
	oben = n * h
	var glas := fassade({"glas": Color("b8924e"), "rahmen": Color("2e2d2d"), "bruestung": Color("5a5148"), "schmutz_farbe": Color("6b5a44"), "stock": h, "fenster_breite": 1.8, "metall": 0.8, "band_anteil": 0.15})
	baue(stockwerke, glas, betonmat("4a4744"))
	fenster_zahl = zaehle_fenster(stockwerke, 1.8)
	var krone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 38.0 * 0.62
	cm.height = 70.0
	cm.radial_segments = 4
	krone.mesh = cm
	krone.material_override = fassade({"glas": Color("e0c27a"), "rahmen": Color("3b3a3a"), "stock": 5.0, "fenster_breite": 2.5, "dreckig": 0.0, "metall": 0.9})
	krone.position.y = oben + 35.0
	krone.rotation.y = -deg_to_rad((n - 1) * 1.1) + PI / 4.0
	add_child(krone)
	spitze = oben + 70.0

# ---------------------------------------------------------------- Variante 3: Stapel-Riese (absurd hoch, gestapelte Blöcke)
func _stapelriese() -> void:
	var h := 3.8
	var f := 0
	var dreh := 0.0
	for blk in 26:
		var t := float(blk) / 26.0
		var bx := lerpf(85.0, 34.0, t) * (0.65 + rng.randf() * 0.7)
		var bz := lerpf(60.0, 28.0, t) * (0.8 + rng.randf() * 0.4)
		var mx := (rng.randf() - 0.5) * 34.0 * (1.0 - t * 0.6)
		var mz := (rng.randf() - 0.5) * 34.0 * (1.0 - t * 0.6)
		dreh += deg_to_rad([0.0, 15.0, -15.0, 30.0][blk % 4])
		var poly := rechteck(bx, bz, mx, mz, dreh)
		var stock_n := 10 + rng.randi() % 5
		for k in stock_n:
			stockwerke.append({"poly": poly, "y0": f * h, "h": h})
			f += 1
	oben = f * h
	var glas := fassade({"glas": Color("2f7476"), "rahmen": Color("c2603e"), "bruestung": Color("a84f33"), "stock": h, "fenster_breite": 1.3, "metall": 0.4, "band_anteil": 0.28})
	baue(stockwerke, glas, betonmat("8a4a33"))
	fenster_zahl = zaehle_fenster(stockwerke, 1.3)
	var antenne := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 2.5
	cm.height = 110.0
	antenne.mesh = cm
	antenne.material_override = betonmat("d8d8d8")
	antenne.position.y = oben + 55.0
	add_child(antenne)
	var lampe := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.0
	sm.height = 4.0
	lampe.mesh = sm
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("ff3b30")
	lm.emission_enabled = true
	lm.emission = Color("ff3b30")
	lm.emission_energy_multiplier = 4.0
	lampe.material_override = lm
	lampe.position.y = oben + 111.0
	add_child(lampe)
	spitze = oben + 112.0

# ---------------------------------------------------------------- Stadt drumherum
func _stadt() -> void:
	var mats := [
		fassade({"glas": Color("6d8aa3"), "rahmen": Color("e6dccb"), "bruestung": Color("d8c9b0"), "stock": 3.5, "fenster_breite": 2.2, "dreckig": 0.2, "band_anteil": 0.35, "metall": 0.4}),
		fassade({"glas": Color("5c7f8f"), "rahmen": Color("c9b79a"), "bruestung": Color("bba78a"), "stock": 3.5, "fenster_breite": 2.6, "dreckig": 0.2, "band_anteil": 0.4, "metall": 0.3}),
		fassade({"glas": Color("8fb1c9"), "rahmen": Color("9aa3ad"), "bruestung": Color("8a929c"), "stock": 3.5, "fenster_breite": 1.8, "dreckig": 0.1, "metall": 0.7}),
	]
	var dach := betonmat("bdb3a3")
	var x := -1500.0
	while x <= 1500.0:
		var z := -1500.0
		while z <= 1500.0:
			var d := Vector2(x, z).length()
			if d > 230.0 and d < 1600.0 and rng.randf() < 0.55:
				var bx := 25.0 + rng.randf() * 30.0
				var bz := 25.0 + rng.randf() * 30.0
				var hoch := int((4.0 + rng.randf() * 22.0) * (1.4 - d / 1600.0))
				if rng.randf() < 0.08:
					hoch += 25
				var poly := rechteck(bx, bz, x + (rng.randf() - 0.5) * 10.0, z + (rng.randf() - 0.5) * 10.0)
				var stw := []
				for k in maxi(hoch, 2):
					stw.append({"poly": poly, "y0": k * 3.5, "h": 3.5})
				baue(stw, mats[rng.randi() % 3], dach)
			z += 75.0
		x += 75.0

# ---------------------------------------------------------------- Kamera + Infos
func _kamera() -> void:
	var cam := Camera3D.new()
	cam.far = 40000.0
	add_child(cam)
	if ansicht == 1:
		cam.fov = 52.0
		var dist := spitze * 1.3
		cam.position = Vector3(-dist * 0.55, spitze * 0.28, dist * 0.84)
		cam.look_at(Vector3(0, spitze * 0.47, 0))
	else:
		# Nahansicht an der Fassade mit Putz-Gondel
		cam.fov = 62.0
		var y := oben * 0.32
		var fi := clampi(int(y / float(stockwerke[0].h)), 0, stockwerke.size() - 1)
		var p: PackedVector2Array = stockwerke[fi].poly
		var dir := Vector2(1.0, 0.35).normalized()
		var weit := 0.0
		for v in p:
			weit = maxf(weit, v.dot(dir))
		var tan := Vector2(-dir.y, dir.x)
		var ziel := dir * weit
		cam.position = Vector3(ziel.x + dir.x * 13.0 + tan.x * 7.0, y - 2.5, ziel.y + dir.y * 13.0 + tan.y * 7.0)
		cam.look_at(Vector3(ziel.x, y + 4.0, ziel.y))
		_gondel(Vector3(ziel.x + dir.x * 1.6, y, ziel.y + dir.y * 1.6), atan2(-tan.y, tan.x))

func _gondel(p: Vector3, dreh: float) -> void:
	var g := Node3D.new()
	g.position = p
	g.rotation.y = dreh
	add_child(g)
	var gelb := StandardMaterial3D.new()
	gelb.albedo_color = Color("ffc531")
	gelb.roughness = 0.5
	var grau := betonmat("5b5f66")
	var boden := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(7.0, 0.25, 1.3)
	boden.mesh = bm
	boden.material_override = gelb
	g.add_child(boden)
	for seite in [-0.6, 0.6]:
		var gel := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(7.0, 0.12, 0.08)
		gel.mesh = gm
		gel.material_override = gelb
		gel.position = Vector3(0, 1.1, seite)
		g.add_child(gel)
	for x in [-3.4, 3.4]:
		var pf := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.1, 1.1, 1.3)
		pf.mesh = pm
		pf.material_override = gelb
		pf.position = Vector3(x, 0.55, 0)
		g.add_child(pf)
		var seil := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.03
		sm.bottom_radius = 0.03
		sm.height = 400.0
		seil.mesh = sm
		seil.material_override = grau
		seil.position = Vector3(x * 0.9, 200.0, -0.2)
		g.add_child(seil)
	# Putzkraft (einfach): Körper + Kopf + Helm
	var koerper := MeshInstance3D.new()
	var km := CapsuleMesh.new()
	km.radius = 0.3
	km.height = 1.6
	koerper.mesh = km
	var blau := StandardMaterial3D.new()
	blau.albedo_color = Color("2f7fd6")
	koerper.material_override = blau
	koerper.position = Vector3(-1.0, 0.9, 0.1)
	g.add_child(koerper)
	var kopf := MeshInstance3D.new()
	var kk := SphereMesh.new()
	kk.radius = 0.22
	kk.height = 0.44
	kopf.mesh = kk
	kopf.material_override = betonmat("f1c29b")
	kopf.position = Vector3(-1.0, 1.9, 0.1)
	g.add_child(kopf)
	var helm := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.25
	hm.height = 0.3
	helm.mesh = hm
	helm.material_override = gelb
	helm.position = Vector3(-1.0, 2.05, 0.1)
	g.add_child(helm)

func _beschriftung() -> void:
	var namen := {1: "Wüstennadel", 2: "Drehturm", 3: "Stapel-Riese"}
	var cl := CanvasLayer.new()
	add_child(cl)
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = 34
	ls.font_color = Color.WHITE
	ls.outline_size = 10
	ls.outline_color = Color("123a6b")
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI Black", "Arial Black"])
	ls.font = f
	l.label_settings = ls
	l.position = Vector2(28, 20)
	l.text = "%d · %s\n%d m hoch · %d Stockwerke · ca. %s Fenster" % [turm, namen.get(turm, "?"), int(spitze), stockwerke.size(), _punkte(fenster_zahl)]
	cl.add_child(l)

func _punkte(n: int) -> String:
	var s := str(n)
	var aus := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			aus += "."
		aus += s[i]
	return aus
