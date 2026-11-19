class_name Daecher
extends Node3D
# Dachaufbauten der Stadthäuser (Grafik, 19.11.2026, Wunsch des Users): Dachkante (Attika), Aufzugshäuschen, Klimaanlagen,
# Wassertanks, Solarfelder auf niedrigen Häusern, Antennen und Hubschrauber-Landeplätze auf hohen, nachts blinkende rote
# Warnlichter. Alles in wenigen MultiMeshes (Farbe je Instanz). Kleinteile (Klimaanlagen) liegen in Kacheln und werden ab
# ~1,3 km ausgeblendet (spart Leistung, nichts wird so klein, dass es flimmert). Warnlichter sind Leucht-Punkte, die nie
# kleiner als ~2 Bildpunkte werden (sonst blitzen sie in der Ferne unruhig).

const KACHEL := 750.0
const KLEIN_WEIT := 1300.0
const LICHT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, world_vertex_coords;
global uniform float nacht;
uniform vec3 farbe : source_color = vec3(1.0, 0.12, 0.08);
varying float blink;
void vertex() {
	// Billboard: Größe wächst mit der Entfernung, damit der Punkt nie unter ~2 Bildpunkte fällt
	vec3 mitte = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(CAMERA_POSITION_WORLD - mitte);
	float groesse = max(1.8, dist * 0.0042);
	vec3 r = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 u = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 ecke = VERTEX - mitte;   // Quad-Ecke (Instanz ohne Drehung/Skalierung)
	VERTEX = mitte + (r * ecke.x + u * ecke.y) * groesse;
	float ph = INSTANCE_CUSTOM.x;
	blink = smoothstep(0.55, 0.62, fract(TIME * 0.5 + ph)) * (1.0 - smoothstep(0.86, 0.93, fract(TIME * 0.5 + ph)));
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = (1.0 - smoothstep(0.1, 1.0, d)) * mix(0.35, 1.0, blink) * smoothstep(0.2, 0.55, nacht);
	ALBEDO = farbe * a * 4.0;
}
"""

var rng := RandomNumberGenerator.new()
var _gross: Array = []        # [Transform3D, Color]
var _zyl: Array = []
var _solar: Array = []
var _klein := {}              # Kachel -> Array
var _lichter: Array = []      # Vector3
var anzahl := 0

func baue(welt: Node3D) -> void:
	rng.seed = 4711
	var haeuser: Array = welt.haeuser
	var hoehen: Array = welt.haeuser_hoehe
	for i in haeuser.size():
		_dach(haeuser[i], float(hoehen[i]))
	_multimesh(_gross, _box_mesh(), _mat(0.85), true)
	_multimesh(_zyl, _zyl_mesh(), _mat(0.6), true)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("1c2c46")
	sm.metallic = 0.6
	sm.roughness = 0.25
	_multimesh(_solar, _box_mesh(), sm, false)
	for k in _klein:
		var mmi := _multimesh(_klein[k], _box_mesh(), _mat(0.85), false)
		mmi.visibility_range_end = KLEIN_WEIT
		mmi.visibility_range_end_margin = 150.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_licht_bauen()
	var nk := 0
	for k in _klein:
		nk += (_klein[k] as Array).size()
	print("Dächer: %d Häuser, %d Teile (groß %d, Zylinder %d, Solar %d, Klimaanlagen %d, Warnlichter %d)" % [haeuser.size(), anzahl, _gross.size(), _zyl.size(), _solar.size(), nk, _lichter.size()])

func _mat(rau: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rau
	return m

func _box_mesh() -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	return b

func _zyl_mesh() -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.5
	c.bottom_radius = 0.5
	c.height = 1.0
	c.radial_segments = 14
	c.rings = 1
	return c

func _kiste(liste: Array, mitte: Vector3, groesse: Vector3, farbe: Color, dreh := 0.0) -> void:
	var b := Basis(Vector3.UP, dreh) * Basis.from_scale(groesse)   # erst skalieren, dann drehen
	liste.append([Transform3D(b, mitte + Vector3.UP * groesse.y * 0.5), farbe])
	anzahl += 1

func _zylinder(mitte: Vector3, r: float, h: float, farbe: Color) -> void:
	_zyl.append([Transform3D(Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), mitte + Vector3.UP * h * 0.5), farbe])
	anzahl += 1

func _dach(r: Rect2, h: float) -> void:
	var y := h
	var c := r.get_center()
	var sx := r.size.x
	var sz := r.size.y
	var hell := Color("d9d1c3").lerp(Color("bfc4c9"), rng.randf())
	# Attika rundum
	var t := 0.4
	var ah := 0.9
	_kiste(_gross, Vector3(c.x, y, r.position.y + t * 0.5), Vector3(sx, ah, t), hell)
	_kiste(_gross, Vector3(c.x, y, r.end.y - t * 0.5), Vector3(sx, ah, t), hell)
	_kiste(_gross, Vector3(r.position.x + t * 0.5, y, c.y), Vector3(t, ah, sz - 2.0 * t), hell)
	_kiste(_gross, Vector3(r.end.x - t * 0.5, y, c.y), Vector3(t, ah, sz - 2.0 * t), hell)
	var innen := Rect2(r.position + Vector2(2.5, 2.5), r.size - Vector2(5.0, 5.0))
	if innen.size.x < 4.0 or innen.size.y < 4.0:
		return
	var frei: Array = []   # belegte Flächen auf dem Dach (Rect2), damit nichts ineinander steht
	var platz := func(gr: Vector2) -> Vector2:
		for versuch in 12:
			var p := Vector2(innen.position.x + gr.x * 0.5 + rng.randf() * maxf(0.0, innen.size.x - gr.x),
				innen.position.y + gr.y * 0.5 + rng.randf() * maxf(0.0, innen.size.y - gr.y))
			var rr := Rect2(p - gr * 0.5 - Vector2(0.6, 0.6), gr + Vector2(1.2, 1.2))
			var ok := true
			for f in frei:
				if (f as Rect2).intersects(rr):
					ok = false
					break
			if ok:
				frei.append(rr)
				return p
		return Vector2.INF
	var hoch := h > 60.0
	# Hubschrauber-Landeplatz auf manchen hohen Häusern (Mitte)
	if hoch and minf(innen.size.x, innen.size.y) > 17.0 and rng.randf() < 0.35:
		frei.append(Rect2(c - Vector2(9.0, 9.0), Vector2(18.0, 18.0)))
		_zylinder(Vector3(c.x, y, c.y), 8.2, 0.35, Color("e8e4dc"))
		_zylinder(Vector3(c.x, y, c.y), 7.6, 0.42, Color("3a3f45"))
		var w := Color("f2efe8")
		_kiste(_gross, Vector3(c.x - 1.6, y + 0.42, c.y), Vector3(0.7, 0.04, 5.0), w)
		_kiste(_gross, Vector3(c.x + 1.6, y + 0.42, c.y), Vector3(0.7, 0.04, 5.0), w)
		_kiste(_gross, Vector3(c.x, y + 0.42, c.y), Vector3(3.2, 0.04, 0.7), w)
		_lichter.append(Vector3(r.position.x + 0.5, y + 1.2, r.position.y + 0.5))
		_lichter.append(Vector3(r.end.x - 0.5, y + 1.2, r.end.y - 0.5))
	# Aufzugs-/Treppenhaus
	if rng.randf() < 0.85:
		var gr := Vector2(6.0 + rng.randf() * 3.5, 4.5 + rng.randf() * 3.0)
		var p: Vector2 = platz.call(gr)
		if p != Vector2.INF:
			_kiste(_gross, Vector3(p.x, y, p.y), Vector3(gr.x, 3.8 + rng.randf() * 1.4, gr.y), hell.darkened(0.12 + rng.randf() * 0.1))
			# Technik-Aufsatz obendrauf (Lüftung)
			if rng.randf() < 0.5:
				_kiste(_gross, Vector3(p.x + (rng.randf() - 0.5) * gr.x * 0.4, y + 3.8, p.y), Vector3(gr.x * 0.45, 1.2, gr.y * 0.5), Color("a9afb5"))
	# Wassertank
	if rng.randf() < 0.35:
		var p: Vector2 = platz.call(Vector2(3.6, 3.6))
		if p != Vector2.INF:
			_zylinder(Vector3(p.x, y, p.y), 1.6, 2.6 + rng.randf(), Color("e1e3e5") if rng.randf() < 0.6 else Color("9aa3ab"))
	# Solarfeld auf niedrigen Häusern (Reihen schräger Paneele)
	if h < 35.0 and rng.randf() < 0.45:
		var reihen := mini(6, int(innen.size.y / 3.2))
		var lang := innen.size.x * 0.7
		var p0: Vector2 = platz.call(Vector2(lang, reihen * 3.2))
		if p0 != Vector2.INF:
			for k in reihen:
				var z := p0.y - reihen * 1.6 + k * 3.2 + 1.6
				var b := Basis(Vector3.RIGHT, -0.45) * Basis.from_scale(Vector3(lang, 0.08, 2.0))
				_solar.append([Transform3D(b, Vector3(p0.x, y + 0.8, z)), Color.WHITE])
				anzahl += 1
	# Klimaanlagen (Kleinteile, in Kacheln mit Sichtweite)
	var kk := Vector2i(floori(c.x / KACHEL), floori(c.y / KACHEL))
	if not _klein.has(kk):
		_klein[kk] = []
	for k in rng.randi_range(3, 8):
		var gr := Vector2(2.5, 1.7)
		var p: Vector2 = platz.call(gr)
		if p == Vector2.INF:
			break
		var dreh := 0.0 if rng.randf() < 0.5 else PI * 0.5
		_kiste(_klein[kk], Vector3(p.x, y, p.y), Vector3(2.5, 1.6, 1.7), Color("d3d7db").lerp(Color("a7aeb5"), rng.randf()), dreh)
	# Lüftungsrohre
	for k in rng.randi_range(1, 4):
		var p: Vector2 = platz.call(Vector2(0.9, 0.9))
		if p == Vector2.INF:
			break
		_zylinder(Vector3(p.x, y, p.y), 0.35, 1.0 + rng.randf() * 0.8, Color("b9bec3"))
	# Antenne mit Warnlicht auf hohen Häusern
	if hoch and rng.randf() < 0.6:
		var p: Vector2 = platz.call(Vector2(1.2, 1.2))
		if p != Vector2.INF:
			var mh := 9.0 + rng.randf() * 14.0
			_zylinder(Vector3(p.x, y, p.y), 0.22, mh, Color("b8bcc0"))
			_zylinder(Vector3(p.x, y + mh * 0.55, p.y), 0.32, 0.6, Color("c8322a"))
			_lichter.append(Vector3(p.x, y + mh + 0.3, p.y))
	elif hoch:
		_lichter.append(Vector3(c.x, y + 1.2, c.y))

func _multimesh(liste: Array, mesh: Mesh, mat: Material, schatten: bool) -> MultiMeshInstance3D:
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
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if schatten else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi

func _licht_bauen() -> void:
	if _lichter.is_empty():
		return
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var sh := Shader.new()
	sh.code = LICHT_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = _lichter.size()
	for i in _lichter.size():
		mm.set_instance_transform(i, Transform3D(Basis(), _lichter[i]))
		mm.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-3000, -100, -3000), Vector3(6000, 1200, 6000))   # Billboards wachsen im Shader
	add_child(mmi)
	anzahl += _lichter.size()
