extends Node3D
# Grafik-Test „Meer leer schöpfen“ – Godot-Version.
# Alles wird hier im Code aufgebaut: Gelände, Wasser, Himmel, Modelle (Kenney, CC0), Hand + Werkzeuge, HUD.
# Testbilder: godot --path . --write-movie bild.png --fixed-fps 30 --quit-after 45 -- --ansicht=2

const MIN_LEVEL := -56.0
const GROESSE := 800.0
const SEG := 320
const KM3 := 1.335e9
const HORIZONT := Color("c4e4f6")
const SONNE_DIR := Vector3(-0.35, 0.72, -0.6)

var level := 0.0
var ziel := 0.0
var grund := PackedFloat32Array()
var sand_mat: ShaderMaterial
var wasser_mats: Array[ShaderMaterial] = []
var cam: Camera3D
var rig: Node3D
var sonne: DirectionalLight3D
var yaw := 0.08
var pitch := -0.22
var spieler := Vector3(6, 0, 136)
var sprung := 0.0
var vy := 0.0
var bob := 0.0
var maus := false
var wz := 0
var werkzeuge: Array = []
var anim := {"an": false, "t": 0.0, "dauer": 1.0, "ziel": Vector3.ZERO, "fertig": false}
var funde: Array = []
var gefunden := {}
var staerke := 0.0
var strudel: MeshInstance3D
var strahl: CPUParticles3D
var pegel_pfeil: Node3D
var ui := {}
var rng := RandomNumberGenerator.new()
var mat_cache := {}
var banner_tween: Tween
var schwimmer: Array = []

# ---------------------------------------------------------------- Rauschen
func h2(x: float, z: float) -> float:
	var s := sin(x * 127.1 + z * 311.7) * 43758.5453
	return s - floor(s)

func vn(x: float, z: float) -> float:
	var xi := floorf(x)
	var zi := floorf(z)
	var xf := x - xi
	var zf := z - zi
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := zf * zf * (3.0 - 2.0 * zf)
	var a := h2(xi, zi)
	var b := h2(xi + 1.0, zi)
	var c := h2(xi, zi + 1.0)
	var d := h2(xi + 1.0, zi + 1.0)
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v

func fbm(x: float, z: float, o: int) -> float:
	var s := 0.0
	var a := 0.5
	var f := 1.0
	for i in o:
		s += a * vn(x * f, z * f)
		f *= 2.03
		a *= 0.5
	return s

func ss(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

# ---------------------------------------------------------------- Gelände
func kueste(x: float) -> float:
	return 105.0 + 12.0 * sin(x * 0.018 + 1.0) + 6.0 * sin(x * 0.051) \
		- 75.0 * exp(-pow((x + 165.0) / 50.0, 2.0)) - 65.0 * exp(-pow((x - 175.0) / 42.0, 2.0))

func felsig(x: float) -> float:
	return exp(-pow((x + 165.0) / 45.0, 2.0)) + exp(-pow((x - 175.0) / 38.0, 2.0))

func H(x: float, z: float) -> float:
	var d := z - kueste(x)
	var h := 0.0
	if d >= 0.0:
		h = 2.8 * (1.0 - exp(-d / 14.0))
		h += (fbm(x * 0.02, z * 0.02, 3) - 0.5) * 3.0 * minf(1.0, d / 20.0)
		h += ss(40.0, 90.0, d) * 5.0 * fbm(x * 0.01 + 5.0, z * 0.01, 2)
		h += felsig(x) * minf(d, 30.0) * 0.12 * (0.6 + fbm(x * 0.06, z * 0.06, 2))
	else:
		var s := -d
		h = -s * 0.07 - maxf(0.0, s - 35.0) * 0.11 - maxf(0.0, s - 160.0) * 0.06
		h = maxf(h, -54.0)
		h += (fbm(x * 0.015, z * 0.015, 4) - 0.5) * 6.0 * minf(1.0, s / 30.0)
		h += 1.6 * exp(-pow((s - 72.0) / 12.0, 2.0))
		h -= 7.0 * exp(-pow((x - 20.0) / 30.0, 2.0)) * ss(60.0, 120.0, s)
	var rand := ss(320.0, 395.0, maxf(absf(x), absf(z)))
	return h * (1.0 - rand) - 57.0 * rand

func boden_farbe(x: float, z: float, h: float) -> Color:
	var t: Color
	if h >= 0.0:
		t = Color("e3bf80")
		var g := ss(3.4, 4.6, h + (fbm(x * 0.05, z * 0.05, 2) - 0.5) * 2.5)
		t = t.lerp(Color("89c45a"), g)
		t = t.lerp(Color("5aa246"), g * fbm(x * 0.09 + 3.0, z * 0.09, 2) * 0.8)
		t = t.lerp(Color("b9ab95"), minf(1.0, felsig(x)) * ss(1.5, 5.0, h) * 0.6)
	else:
		t = Color("d4ae72").lerp(Color("b8955f"), ss(-3.0, -35.0, h))
	return t.srgb_to_linear()

func _ready() -> void:
	rng.seed = 7
	_umgebung()
	_gelaende()
	_wasser()
	_objekte()
	_spieler()
	_hud()
	_demo()
	waehle(wz, false)

# ---------------------------------------------------------------- Himmel, Licht, Nachbearbeitung
func _umgebung() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shader/himmel.gdshader")
	sm.set_shader_parameter("sonne", SONNE_DIR.normalized())
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.78
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.03
	env.fog_enabled = true
	env.fog_light_color = HORIZONT
	env.fog_density = 0.0007
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sonne = DirectionalLight3D.new()
	sonne.light_color = Color("ffe9c4")
	sonne.light_energy = 1.3
	sonne.shadow_enabled = true
	sonne.directional_shadow_max_distance = 160.0
	sonne.shadow_blur = 1.4
	add_child(sonne)
	sonne.basis = Basis.looking_at(-SONNE_DIR.normalized(), Vector3.UP)

# ---------------------------------------------------------------- Boden + Wasser
func _gitter(n: int, hoehen: bool) -> Dictionary:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uv := PackedVector2Array()
	verts.resize(n * n)
	norms.resize(n * n)
	uv.resize(n * n)
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var k := 0
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx[k] = a; idx[k + 1] = a + 1; idx[k + 2] = a + n
			idx[k + 3] = a + 1; idx[k + 4] = a + n + 1; idx[k + 5] = a + n
			k += 6
	return {"v": verts, "n": norms, "uv": uv, "i": idx}

func _gelaende() -> void:
	var n := SEG + 1
	var schritt := GROESSE / SEG
	var g := _gitter(n, true)
	var verts: PackedVector3Array = g.v
	var norms: PackedVector3Array = g.n
	var cols := PackedColorArray()
	cols.resize(n * n)
	grund.resize(n * n)
	for j in n:
		var z := -GROESSE / 2.0 + j * schritt
		for i in n:
			var x := -GROESSE / 2.0 + i * schritt
			var h := H(x, z)
			var k := j * n + i
			grund[k] = h
			verts[k] = Vector3(x, h, z)
			cols[k] = boden_farbe(x, z, h)
	for j in n:
		for i in n:
			var hl := grund[j * n + maxi(i - 1, 0)]
			var hr := grund[j * n + mini(i + 1, n - 1)]
			var hd := grund[maxi(j - 1, 0) * n + i]
			var hu := grund[mini(j + 1, n - 1) * n + i]
			norms[j * n + i] = Vector3(hl - hr, 2.0 * schritt, hd - hu).normalized()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = g.i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	sand_mat = ShaderMaterial.new()
	sand_mat.shader = load("res://shader/sand.gdshader")
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = sand_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var fern := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(9000, 9000)
	fern.mesh = pm
	fern.material_override = mat("b8955f")
	fern.position.y = -57.5
	add_child(fern)

func _wasser_netz(groesse: float, seg: int, hoehen: PackedFloat32Array, fest: float) -> ArrayMesh:
	var n := seg + 1
	var schritt := groesse / seg
	var g := _gitter(n, false)
	var verts: PackedVector3Array = g.v
	var norms: PackedVector3Array = g.n
	var uv: PackedVector2Array = g.uv
	var uv2 := PackedVector2Array()
	uv2.resize(n * n)
	for j in n:
		for i in n:
			var k := j * n + i
			verts[k] = Vector3(-groesse / 2.0 + i * schritt, 0.0, -groesse / 2.0 + j * schritt)
			norms[k] = Vector3.UP
			uv[k] = Vector2(float(i) / seg, float(j) / seg)
			uv2[k] = Vector2(hoehen[k] if hoehen.size() > 0 else fest, 0.0)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = g.i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

func _wasser() -> void:
	for modus in [0, 1]:
		var m := ShaderMaterial.new()
		m.shader = load("res://shader/wasser.gdshader")
		m.set_shader_parameter("modus", float(modus))
		wasser_mats.append(m)
		var mi := MeshInstance3D.new()
		var gr := GROESSE if modus == 0 else 9000.0
		mi.mesh = _wasser_netz(GROESSE, SEG, grund, 0.0) if modus == 0 else _wasser_netz(9000.0, 48, PackedFloat32Array(), -57.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-gr / 2.0, -60.0, -gr / 2.0), Vector3(gr, 70.0, gr))
		add_child(mi)

# ---------------------------------------------------------------- Bauteile
func mat(hex: String, rough := 0.85, metal := 0.0, extra := {}) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [hex, rough, metal, extra]
	if mat_cache.has(key):
		return mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = rough
	m.metallic = metal
	if extra.has("beidseitig"):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if extra.has("leucht"):
		m.emission_enabled = true
		m.emission = Color(extra.leucht)
		m.emission_energy_multiplier = 1.5
	mat_cache[key] = m
	return m

func teil(mesh: Mesh, m: Material, p: Vector3, eltern: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = p
	eltern.add_child(mi)
	return mi

func box(gr: Vector3, hex: String, p: Vector3, eltern: Node3D) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = gr
	return teil(bm, mat(hex), p, eltern)

func zyl(r_oben: float, r_unten: float, hoehe: float, hex: String, p: Vector3, eltern: Node3D, seg := 12) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_oben
	cm.bottom_radius = r_unten
	cm.height = hoehe
	cm.radial_segments = seg
	return teil(cm, mat(hex), p, eltern)

func kugel(r: float, m: Material, p: Vector3, eltern: Node3D) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 10
	return teil(sm, m, p, eltern)

func zwischen(mi: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	mi.position = a + d * 0.5
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(x, y, x.cross(y).normalized())

func schatten(n: Node, an := true) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if an else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		schatten(c, an)

func modell(name: String, p: Vector3, rot := 0.0, s := 1.0) -> Node3D:
	var pfad := "res://modelle/%s.glb" % name
	if not ResourceLoader.exists(pfad):
		return null
	var n: Node3D = load(pfad).instantiate()
	n.position = p
	n.rotation.y = rot
	n.scale = Vector3.ONE * s
	add_child(n)
	schatten(n)
	return n

func auf_boden(name: String, x: float, z: float, rot := 0.0, s := 1.0, tiefer := 0.1) -> Node3D:
	return modell(name, Vector3(x, H(x, z) - tiefer, z), rot, s)

# ---------------------------------------------------------------- Objekte
func _objekte() -> void:
	# Steg
	var steg := Node3D.new()
	add_child(steg)
	steg.position = Vector3(-30, 0, 0)
	var z := 48.0
	while z <= 116.0:
		var p := box(Vector3(3.2, 0.13, 0.5), "b98a57" if int(z / 0.55) % 2 == 0 else "a97a49", Vector3(0, 1.7, z), steg)
		p.rotation.y = (h2(z, 3.0) - 0.5) * 0.04
		z += 0.55
	for sx in [-1.45, 1.45]:
		box(Vector3(0.25, 0.3, 68.0), "7b5533", Vector3(sx, 1.48, 82.0), steg)
		z = 48.3
		while z <= 116.0:
			var boden := H(-30.0 + sx, z)
			var lang := 2.7 - boden + 1.0
			zyl(0.19, 0.22, lang, "80593a", Vector3(sx, 2.7 - lang / 2.0, z), steg, 8)
			z += 5.0
	schatten(steg)
	# Pegel-Latte
	var latte := Node3D.new()
	add_child(latte)
	latte.position = Vector3(-32.1, 0, 48.6)
	latte.rotation.y = 0.35
	box(Vector3(1.0, 10.0, 0.18), "f6efe2", Vector3(0, -3, 0), latte)
	var m := 2.0
	while m >= -8.0:
		var ganz := is_equal_approx(m, roundf(m))
		box(Vector3(0.38 if ganz else 0.22, 0.05, 0.2), "4a2f1a", Vector3(-0.28 if ganz else -0.36, m, 0.02), latte)
		if ganz and m <= 0.0 and m > -8.0:
			var l := Label3D.new()
			l.text = "0 m" if m == 0.0 else str(int(m))
			l.font_size = 64
			l.pixel_size = 0.004
			l.modulate = Color("4a2f1a")
			l.outline_size = 0
			l.position = Vector3(0.22, m, 0.1)
			latte.add_child(l)
		m -= 0.5
	schatten(latte)
	pegel_pfeil = zyl(0.0, 0.22, 0.6, "e8443a", Vector3(-31.35, 0, 48.85), self, 4)
	pegel_pfeil.rotation.z = PI / 2.0

	# Leuchtturm
	var lt := Node3D.new()
	add_child(lt)
	lt.position = Vector3(172, H(172, 52) - 0.3, 52)
	for i in 4:
		zyl(2.0 - (i + 1) * 0.15, 2.0 - i * 0.15, 3.5, "e2483e" if i % 2 else "f7f3ea", Vector3(0, 1.75 + i * 3.5, 0), lt, 20)
	zyl(1.9, 1.9, 0.35, "3b3f46", Vector3(0, 14.2, 0), lt, 20)
	teil(_zylmesh(1.0, 1.0, 1.8), mat("fff3b0", 0.3, 0.0, {"leucht": "ffd860"}), Vector3(0, 15.3, 0), lt)
	zyl(0.0, 1.5, 1.6, "e2483e", Vector3(0, 17.0, 0), lt, 12)
	schatten(lt)

	# --- Modelle aus den Kenney-Paketen (CC0): Pirate Kit + Nature Kit (n_...) ---
	rng.seed = 3
	var felsen := ["rocks-a", "rocks-b", "rocks-c", "n_rock_tallA", "n_rock_tallB", "n_rock_largeD"]
	var fels_s := [1.6, 1.4, 1.6, 6.0, 6.5, 7.0]
	for i in 30: # linke Landzunge
		var x := -215.0 + rng.randf() * 90.0
		var zz := 25.0 + rng.randf() * 85.0
		if H(x, zz) > -3.0:
			var k := i % felsen.size()
			auf_boden(felsen[k], x, zz, rng.randf() * TAU, fels_s[k] * (0.8 + rng.randf() * 0.8), 0.4)
	for i in 20: # rechte Landzunge
		var x := 140.0 + rng.randf() * 75.0
		var zz := rng.randf() * 90.0
		if H(x, zz) > -3.0:
			var k := i % felsen.size()
			auf_boden(felsen[k], x, zz, rng.randf() * TAU, fels_s[k] * (0.8 + rng.randf() * 0.6), 0.4)
	for i in 16: # Felsen auf dem Meeresboden
		var x := (rng.randf() - 0.5) * 300.0
		var zz := 60.0 - rng.randf() * 160.0
		auf_boden(["rocks-sand-a", "rocks-sand-b", "rocks-sand-c"][i % 3], x, zz, rng.randf() * TAU, 0.8 + rng.randf() * 0.9, 0.3)
	for p in [[34, 112, 0.7], [40, 116, 0.45], [-58, 120, 0.6], [70, 104, 0.9]]:
		auf_boden("rocks-sand-c", float(p[0]), float(p[1]), rng.randf() * TAU, float(p[2]), 0.2)
	var i_p := 0
	for p in [[-40, 162, 1.1], [-12, 175, 1.25], [18, 160, 1.0], [46, 150, 1.15], [72, 168, 1.05], [-70, 150, 1.0], [105, 150, 1.2], [-95, 165, 1.1], [30, 195, 1.2], [-55, 200, 1.0], [130, 135, 1.0], [60, 128, 0.9], [-36, 136, 0.95], [88, 140, 1.0], [-120, 150, 1.1]]:
		auf_boden(["palm-detailed-bend", "palm-detailed-straight", "palm-bend"][i_p % 3], float(p[0]), float(p[1]), rng.randf() * TAU, float(p[2]) * 2.4, 0.2)
		i_p += 1
	for i in 70: # Büsche, Blumen, Gras auf der Insel
		var x := (rng.randf() - 0.5) * 320.0
		var zz := 140.0 + rng.randf() * 130.0
		var h := H(x, zz)
		if h > 3.4:
			var art: String = ["n_plant_bushDetailed", "n_plant_bushLarge", "n_flower_redA", "n_grass_large", "n_plant_bush", "n_flower_yellowA", "grass-plant"][i % 7]
			auf_boden(art, x, zz, rng.randf() * TAU, (1.4 if art == "grass-plant" else 6.0) * (0.8 + rng.randf() * 0.5), 0.05)
		elif h > 1.0 and i % 3 == 0:
			auf_boden("grass-patch", x, zz, rng.randf() * TAU, 1.6, 0.05)
	# Strandlager bei der Bude
	var bude := auf_boden("structure-roof", -24, 150, 0.35, 1.7, 0.0)
	auf_boden("barrel", -19.5, 146, 0.4, 0.85, 0.0)
	auf_boden("barrel", -18.4, 147.4, 1.2, 0.85, 0.0)
	auf_boden("crate-bottles", -27.5, 145.5, 0.3, 0.95, 0.0)
	auf_boden("crate", -28.2, 147.2, 1.1, 0.95, 0.0)
	auf_boden("flag-pirate-high", -20, 154, 0.2, 1.5, 0.0)
	auf_boden("cannon-mobile", 14, 132, 2.6, 1.0, 0.0)
	auf_boden("barrel", 12, 128, 0.7, 0.85, 0.0)
	auf_boden("flag-high-pennant", -30.5, 117, 0.0, 1.2, -1.6)
	# Boot am Steg und Schiff draußen: schwimmen auf dem Wasser und sinken mit ab
	schwimmer.append({"n": modell("boat-row-large", Vector3(-26.8, 0, 70), 0.2, 1.1), "x": -26.8, "z": 70.0, "tief": 0.25})
	schwimmer.append({"n": modell("ship-pirate-medium", Vector3(-150, 0, -160), 2.2, 2.2), "x": -150.0, "z": -160.0, "tief": 1.6})

	# Funde unter Wasser
	var wrack := auf_boden("ship-wreck", 40, -38, 0.6, 2.2, 1.2)
	if wrack:
		wrack.rotation.z = 0.22
	funde.append({"name": "Schiffswrack", "text": "Hier ist wohl jemand zu tief gesegelt.", "oben": H(40, -38) + 7.0})
	var truhe := auf_boden("chest", -72, 8, 0.8, 1.0, 0.1)
	auf_boden("bottle", -70.5, 9.5, 1.0, 1.0, 0.0)
	auf_boden("cannon-ball", -73.5, 9.2, 0.0, 1.0, -0.2)
	funde.append({"name": "Schatztruhe", "text": "Voll mit … nassem Sand. Und Gold!", "oben": H(-72, 8) + 1.1, "glanz": truhe})
	auf_boden("cannon", 126, -66, 2.0, 1.2, 0.2)
	auf_boden("chest", 128, -70, 2.0, 1.0, 0.1)
	funde.append({"name": "Kanone + Truhe", "text": "Da lag wohl ein ganzer Piratenschatz.", "oben": H(128, -70) + 1.0})
	var oben := -99.0
	rng.seed = 77
	for i in 40:
		var x := 85.0 + rng.randf() * 55.0
		var zz := 30.0 + rng.randf() * 34.0
		var y := H(x, zz)
		if y > -2.5:
			continue
		var art: String = ["n_plant_bushSmall", "n_plant_flatTall", "n_flower_purpleA", "n_flower_yellowA", "n_mushroom_redGroup", "n_flower_redA"][i % 6]
		auf_boden(art, x, zz, rng.randf() * TAU, 6.0 + rng.randf() * 3.0, 0.0)
		oben = maxf(oben, y + 1.2)
	funde.append({"name": "Korallengarten", "text": "Bunt. Und plötzlich ziemlich trocken.", "oben": oben})

	# Ferne Inseln
	for p in [[-700, -1300, 130], [950, -1700, 180], [-1700, -2300, 220], [1800, -600, 150]]:
		var ins := Node3D.new()
		add_child(ins)
		ins.position = Vector3(p[0], 0, p[1])
		var r := float(p[2])
		zyl(r * 1.15, r * 1.3, 60.0, "e8cf9a", Vector3(0, -28, 0), ins, 24)
		var berg := zyl(0.0, r, r * 0.45, "5f9e58", Vector3(0, r * 0.22 + 2.0, 0), ins, 9)
		berg.scale.z = 0.7

func _zylmesh(a: float, b: float, h: float) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = a
	cm.bottom_radius = b
	cm.height = h
	return cm

# ---------------------------------------------------------------- Spieler, Hand, Werkzeuge
func _faust(eltern: Node3D) -> void:
	var haut := mat("f1c29b", 0.6)
	kugel(0.06, haut, Vector3(0, 0.035, 0.01), eltern).scale = Vector3(1.35, 0.95, 1.1)
	for i in 4:
		var cm := CapsuleMesh.new()
		cm.radius = 0.02
		cm.height = 0.075
		var f := teil(cm, haut, Vector3(-0.045 + i * 0.03, 0.005, -0.045), eltern)
		f.rotation.x = 0.5
	var dm := CapsuleMesh.new()
	dm.radius = 0.022
	dm.height = 0.08
	teil(dm, haut, Vector3(-0.07, 0.03, 0.0), eltern).rotation.x = PI / 2.0
	kugel(0.05, haut, Vector3(0.02, 0.07, 0.07), eltern)
	var arm := zyl(0.052, 0.062, 0.6, "3a86d4", Vector3.ZERO, eltern, 14)
	zwischen(arm, Vector3(0.03, 0.09, 0.1), Vector3(0.2, -0.2, 0.6))
	var saum := zyl(0.058, 0.058, 0.04, "ffffff", Vector3.ZERO, eltern, 14)
	zwischen(saum, Vector3(0.03, 0.09, 0.1), Vector3(0.046, 0.063, 0.15))

func _eimer(s: float, farbe: String) -> Node3D:
	var halter := Node3D.new()
	var g := Node3D.new()
	halter.add_child(g)
	g.position.y = -0.418 * s
	var cm := _zylmesh(0.168 * s, 0.12 * s, 0.25 * s)
	cm.cap_top = false
	teil(cm, mat(farbe, 0.45, 0.0, {"beidseitig": true}), Vector3(0, 0.125 * s, 0), g)
	var rand := TorusMesh.new()
	rand.inner_radius = 0.158 * s
	rand.outer_radius = 0.176 * s
	teil(rand, mat("ffffff", 0.4), Vector3(0, 0.25 * s, 0), g)
	var streifen := _zylmesh(0.15 * s, 0.145 * s, 0.03 * s)
	streifen.cap_top = false
	streifen.cap_bottom = false
	teil(streifen, mat("ffffff", 0.4), Vector3(0, 0.19 * s, 0), g)
	for i in 10: # Henkel als Halbkreis aus kleinen Stücken
		var a1 := PI * i / 10.0
		var a2 := PI * (i + 1) / 10.0
		var st := zyl(0.006 * s, 0.006 * s, 1.0, "9aa0a8", Vector3.ZERO, g, 6)
		var p1 := Vector3(cos(a1) * 0.168 * s, 0.25 * s + sin(a1) * 0.168 * s, 0)
		var p2 := Vector3(cos(a2) * 0.168 * s, 0.25 * s + sin(a2) * 0.168 * s, 0)
		zwischen(st, p1, p2)
		st.scale.y = p1.distance_to(p2)
	var wasser := teil(_kreis(0.15 * s), mat("4fd6d0", 0.15, 0.0, {"leucht": "0d5a7a"}), Vector3(0, 0.21 * s, 0), g)
	wasser.visible = false
	halter.set_meta("wasser", wasser)
	_faust(halter)
	return halter

func _kreis(r: float) -> CylinderMesh:
	var cm := _zylmesh(r, r, 0.005)
	cm.radial_segments = 24
	return cm

func _pumpe() -> Node3D:
	var g := Node3D.new()
	zyl(0.03, 0.035, 0.13, "33363d", Vector3(0, -0.02, 0), g)
	var rohr := zyl(0.05, 0.055, 0.5, "ffc531", Vector3(0, 0.05, -0.22), g, 16)
	rohr.rotation.x = PI / 2.0
	var kopf := zyl(0.075, 0.05, 0.1, "e2483e", Vector3(0, 0.05, -0.5), g, 16)
	kopf.rotation.x = PI / 2.0
	var spitze := Node3D.new()
	spitze.position = Vector3(0, 0.05, -0.56)
	g.add_child(spitze)
	g.set_meta("spitze", spitze)
	var kurve := Curve3D.new()
	for p in [Vector3(0, 0.05, 0.03), Vector3(0.02, -0.05, 0.15), Vector3(0.15, -0.35, 0.3), Vector3(0.3, -0.8, 0.5)]:
		kurve.add_point(p)
	var pts := kurve.tessellate(4, 4)
	for i in pts.size() - 1:
		var st := zyl(0.035, 0.035, 1.0, "2c6d73", Vector3.ZERO, g, 10)
		zwischen(st, pts[i], pts[i + 1])
		st.scale.y = pts[i].distance_to(pts[i + 1]) * 1.1
	_faust(g)
	return g

func _spieler() -> void:
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 6000.0
	add_child(cam)
	rig = Node3D.new()
	cam.add_child(rig)
	rig.position = Vector3(0.36, -0.2, -0.72)
	werkzeuge = [
		{"name": "Eimer", "text": "Ein ganz normaler Eimer. Viel Glück.", "pro_klick": 0.04, "reich": 7.0, "dauer": 0.85, "modell": _eimer(1.0, "2f7fd6")},
		{"name": "Riesen-Eimer", "text": "Doppelt so groß und golden. Macht trotzdem Muskelkater.", "pro_klick": 0.45, "reich": 10.0, "dauer": 1.1, "modell": _eimer(1.7, "f2b632")},
		{"name": "Saugpumpe", "text": "Gedrückt halten. Zieht einen Strudel aus dem Meer.", "pro_sek": 1.4, "reich": 120.0, "halten": true, "modell": _pumpe()},
	]
	for w in werkzeuge:
		rig.add_child(w.modell)
		schatten(w.modell, false)
		w.modell.visible = false
	# Strudel + Wasserstrahl der Pumpe
	strudel = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	strudel.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shader/strudel.gdshader")
	strudel.material_override = sm
	strudel.visible = false
	add_child(strudel)
	strahl = _partikel(260, 0.35, Color("bff3f5"))
	strahl.emitting = false
	strahl.one_shot = false
	strahl.amount = 220
	strahl.lifetime = 0.7
	strahl.direction = Vector3.UP
	strahl.spread = 18.0
	strahl.initial_velocity_min = 9.0
	strahl.initial_velocity_max = 15.0
	strahl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	strahl.emission_sphere_radius = 2.0
	add_child(strahl)

func _partikel(anzahl: int, groesse: float, farbe: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = groesse * 0.5
	sm.height = groesse
	sm.radial_segments = 8
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = farbe
	m.roughness = 0.2
	m.emission_enabled = true
	m.emission = farbe
	m.emission_energy_multiplier = 0.3
	sm.material = m
	p.mesh = sm
	p.amount = anzahl
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	return p

func spritz(p: Vector3, menge: int, kraft: float) -> void:
	var s := _partikel(menge, 0.16, Color("e9fbff"))
	s.one_shot = true
	s.explosiveness = 0.9
	s.lifetime = 1.0
	s.direction = Vector3.UP
	s.spread = 35.0
	s.initial_velocity_min = 2.0 * kraft
	s.initial_velocity_max = 5.0 * kraft
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	s.emission_sphere_radius = 0.5
	s.position = Vector3(p.x, level + 0.05, p.z)
	add_child(s)
	s.emitting = true
	get_tree().create_timer(1.5).timeout.connect(s.queue_free)

# ---------------------------------------------------------------- HUD
func _karte(eltern: Control) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.99, 0.97, 0.93)
	sb.border_color = Color("1f5fae")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0.07, 0.23, 0.42, 0.35)
	sb.shadow_offset = Vector2(0, 6)
	sb.shadow_size = 1
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	pc.add_theme_stylebox_override("panel", sb)
	eltern.add_child(pc)
	return pc

func _text(eltern: Node, t: String, groesse: int, farbe: String, fett := true) -> Label:
	var l := Label.new()
	l.text = t
	var ls := LabelSettings.new()
	ls.font_size = groesse
	ls.font_color = Color(farbe)
	if fett:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI Black", "Arial Black", "Segoe UI"])
		f.font_weight = 900
		ls.font = f
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eltern.add_child(l)
	return l

func _hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)
	# Meer-Zähler oben
	var oz := _karte(root)
	_platz(oz, 0.5, 0.0, 0, 16)
	oz.custom_minimum_size = Vector2(400, 0)
	var vb := VBoxContainer.new()
	oz.add_child(vb)
	_text(vb, "NOCH IM MEER", 15, "1f5fae")
	ui.zahl = _text(vb, "", 34, "123a6b")
	ui.balken = ProgressBar.new()
	ui.balken.show_percentage = false
	ui.balken.custom_minimum_size = Vector2(0, 10)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("d9ecf7")
	bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("2f9fd6")
	fg.set_corner_radius_all(6)
	ui.balken.add_theme_stylebox_override("background", bg)
	ui.balken.add_theme_stylebox_override("fill", fg)
	vb.add_child(ui.balken)
	ui.prozent = _text(vb, "", 13, "2b5b8f")
	# Wasserstand links
	var st := _karte(root)
	_platz(st, 0.0, 0.0, 16, 16)
	var vb2 := VBoxContainer.new()
	st.add_child(vb2)
	_text(vb2, "Wasserstand", 15, "123a6b")
	ui.stand = _text(vb2, "", 24, "1f5fae")
	# Funde rechts
	var fu := _karte(root)
	_platz(fu, 1.0, 0.0, -16, 16)
	fu.custom_minimum_size = Vector2(220, 0)
	var vb3 := VBoxContainer.new()
	fu.add_child(vb3)
	_text(vb3, "FUNDE", 17, "1f5fae")
	ui.funde = _text(vb3, "", 14, "123a6b")
	ui.funde.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Werkzeugleiste unten
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	root.add_child(hb)
	_platz(hb, 0.5, 1.0, 0, -20)
	ui.wz = []
	for i in werkzeuge.size():
		var k := _karte(hb)
		_text(k, "%d  %s" % [i + 1, werkzeuge[i].name], 16, "2b5b8f")
		ui.wz.append(k)
	# Fadenkreuz
	var kreuz := ColorRect.new()
	kreuz.color = Color.WHITE
	kreuz.size = Vector2(6, 6)
	root.add_child(kreuz)
	_platz(kreuz, 0.5, 0.5, 0, 0)
	kreuz.custom_minimum_size = Vector2(6, 6)
	# Banner
	var ban := VBoxContainer.new()
	ban.custom_minimum_size = Vector2(600, 0)
	ban.alignment = BoxContainer.ALIGNMENT_CENTER
	ban.pivot_offset = Vector2(300, 60)
	ban.modulate.a = 0.0
	root.add_child(ban)
	_platz(ban, 0.5, 0.0, 0, 140)
	ui.banner = ban
	ui.b_klein = _text(ban, "", 18, "1f5fae")
	var gross := PanelContainer.new()
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color("1f5fae")
	gsb.set_corner_radius_all(14)
	gsb.shadow_color = Color("123a6b")
	gsb.shadow_offset = Vector2(0, 7)
	gsb.content_margin_left = 30
	gsb.content_margin_right = 30
	gross.add_theme_stylebox_override("panel", gsb)
	ban.add_child(gross)
	ui.b_gross = _text(gross, "", 58, "ffffff")
	ui.b_gross.label_settings.shadow_color = Color("123a6b")
	ui.b_gross.label_settings.shadow_offset = Vector2(0, 4)
	ui.b_gross.label_settings.shadow_size = 0
	var tk := _karte(ban)
	ui.b_text = _text(tk, "", 18, "123a6b")
	# Hilfe
	var hi := _karte(root)
	_platz(hi, 0.0, 1.0, 16, -16)
	var ht := _text(hi, "WASD laufen · Shift rennen · Leertaste springen\nKlick schöpfen (Pumpe: gedrückt halten)\n1–3 Werkzeug · T Turbo (Test) · R zurücksetzen", 12, "2b5b8f")
	ht.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ui.meldung = _text(root, "", 18, "123a6b")
	_platz(ui.meldung, 0.5, 1.0, 0, -110)
	ui.meldung.custom_minimum_size = Vector2(600, 0)
	ui.meldung.label_settings.outline_size = 8
	ui.meldung.label_settings.outline_color = Color(1, 1, 1, 0.9)
	_fundliste()

func _platz(c: Control, ax: float, ay: float, ox: float, oy: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH if ax == 0.5 else (Control.GROW_DIRECTION_BEGIN if ax == 1.0 else Control.GROW_DIRECTION_END)
	c.grow_vertical = Control.GROW_DIRECTION_BOTH if ay == 0.5 else (Control.GROW_DIRECTION_BEGIN if ay == 1.0 else Control.GROW_DIRECTION_END)

func _fundliste() -> void:
	var t := ""
	for f in funde:
		t += ("✔ " + f.name) if gefunden.has(f.name) else "?  ???"
		t += "\n"
	ui.funde.text = t.strip_edges()

func banner(klein: String, gross: String, text: String, dauer := 2.6) -> void:
	ui.b_klein.text = klein
	ui.b_gross.text = gross
	ui.b_text.text = text
	if banner_tween:
		banner_tween.kill()
	var b: Control = ui.banner
	b.scale = Vector2(0.6, 0.6)
	banner_tween = create_tween()
	banner_tween.set_parallel(true)
	banner_tween.tween_property(b, "modulate:a", 1.0, 0.2)
	banner_tween.tween_property(b, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.chain().tween_interval(dauer)
	banner_tween.chain().tween_property(b, "modulate:a", 0.0, 0.3)

func meldung(t: String) -> void:
	ui.meldung.text = t
	get_tree().create_timer(1.8).timeout.connect(_meldung_weg.bind(t))

func _meldung_weg(t: String) -> void:
	if ui.meldung.text == t:
		ui.meldung.text = ""

func pop(t: String) -> void:
	var l := _text(ui.banner.get_parent(), t, 26, "ffffff")
	l.label_settings.outline_size = 8
	l.label_settings.outline_color = Color("1f5fae")
	l.custom_minimum_size = Vector2(300, 0)
	_platz(l, 0.5, 0.5, randf_range(-40, 40), -60)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "offset_top", -140.0, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "offset_bottom", -140.0, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)

func waehle(i: int, zeigen := true) -> void:
	wz = i
	anim.an = false
	for k in werkzeuge.size():
		werkzeuge[k].modell.visible = k == i
		var sb: StyleBoxFlat = ui.wz[k].get_theme_stylebox("panel").duplicate()
		sb.border_color = Color("1f5fae") if k == i else Color("b9d3ea")
		ui.wz[k].add_theme_stylebox_override("panel", sb)
	if zeigen:
		banner("NEUES WERKZEUG", werkzeuge[i].name.to_upper() + "!", werkzeuge[i].text)

# ---------------------------------------------------------------- Steuerung
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.0022
		pitch = clampf(pitch - e.relative.y * 0.0022, -1.45, 1.45)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif e.pressed:
			maus = true
			aktion()
		else:
			maus = false
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_1: waehle(0)
			KEY_2: waehle(1)
			KEY_3: waehle(2)
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_SPACE:
				if sprung <= 0.001:
					vy = 5.2
			KEY_R:
				ziel = 0.0
				level = 0.0
				gefunden.clear()
				_fundliste()
				spieler = Vector3(6, 0, 136)
				meldung("Alles wieder voll Wasser.")

func ziel_wasser(maxd: float, suchen := false) -> Variant:
	var dir := -cam.global_basis.z
	if dir.y > -0.01:
		return null
	var t := (level - cam.global_position.y) / dir.y
	if t < 0.0 or t > maxd:
		return null
	var p := cam.global_position + dir * t
	if H(p.x, p.z) <= level - 0.15:
		return p
	if not suchen:
		return null
	var r := Vector3(dir.x, 0, dir.z).normalized()
	for k in range(1, 81):
		var q := p + r * k * 2.0
		if H(q.x, q.z) < level - 0.4:
			return q
	return null

func aktion() -> void:
	var w: Dictionary = werkzeuge[wz]
	if w.get("halten", false) or anim.an:
		return
	var p = ziel_wasser(w.reich)
	if p == null:
		meldung("Das Meer ist leer!" if level <= MIN_LEVEL + 0.01 else "Schau aufs Wasser – und geh nah genug ran!")
		return
	anim = {"an": true, "t": 0.0, "dauer": w.dauer, "ziel": p, "fertig": false}

func wasser_weg(meter: float) -> float:
	var vorher := ziel
	ziel = maxf(MIN_LEVEL, ziel - meter)
	return (vorher - ziel) / -MIN_LEVEL * KM3

func fmt(n: float) -> String:
	var s := str(int(round(n)))
	var aus := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		aus = s[i] + aus
		c += 1
		if c % 3 == 0 and i > 0 and s[i - 1] != "-":
			aus = "." + aus
	return aus

# ---------------------------------------------------------------- Spielschleife
func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	var t := Time.get_ticks_msec() / 1000.0
	var laeuft := _bewegen(dt)
	var w: Dictionary = werkzeuge[wz]
	var m: Node3D = w.modell
	rig.position = Vector3(0.36 + (cos(bob * 0.5) * 0.012 if laeuft else 0.0), -0.2 + (absf(sin(bob * 0.5)) * 0.012 if laeuft else sin(t * 1.6) * 0.004), -0.72)
	m.position = Vector3.ZERO
	m.rotation = Vector3.ZERO
	if anim.an and not w.get("halten", false):
		anim.t += dt / anim.dauer
		var k: float = anim.t
		if k < 0.3:
			var e := ss(0, 0.3, k)
			m.position = Vector3(-0.04 * e, -0.2 * e, -0.3 * e)
			m.rotation.x = -0.9 * e
		elif k < 0.55:
			var e := 1.0 - ss(0.3, 0.55, k)
			m.position = Vector3(-0.04 * e, -0.2 * e, -0.3 * e)
			m.rotation.x = -0.9 * e
		elif k < 0.82:
			var e := ss(0.55, 0.82, k)
			m.position = Vector3(0.18 * e, 0.3 * e, 0.12 * e)
			m.rotation = Vector3(1.3 * e, 0, -0.7 * e)
		else:
			var e := 1.0 - ss(0.82, 1.0, k)
			m.position = Vector3(0.18 * e, 0.3 * e, 0.12 * e)
			m.rotation = Vector3(1.3 * e, 0, -0.7 * e)
		m.get_meta("wasser").visible = k > 0.3 and k < 0.7
		if k >= 0.3 and not anim.fertig:
			anim.fertig = true
			var km := wasser_weg(w.pro_klick)
			spritz(anim.ziel, 70 if wz == 1 else 35, 1.4 if wz == 1 else 1.0)
			if km > 0.0:
				pop("−" + fmt(km) + " km³")
		if k >= 1.0:
			anim.an = false
	var pumpt := false
	if w.get("halten", false) and maus and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var p = ziel_wasser(w.reich, true)
		if p != null:
			pumpt = true
			staerke = minf(1.0, staerke + dt * 0.9)
			strudel.position = Vector3(p.x, level + 0.12, p.z)
			strahl.position = Vector3(p.x, level + 0.3, p.z)
			var km := wasser_weg(w.pro_sek * dt * staerke)
			if randf() < dt * 4.0 and km > 0.0:
				pop("−" + fmt(km * 4.0) + " km³")
			m.position = Vector3(randf_range(-0.003, 0.003), randf_range(-0.003, 0.003), 0.01 * staerke)
	if not pumpt:
		staerke = maxf(0.0, staerke - dt * 2.0)
	strahl.emitting = pumpt
	strudel.visible = staerke > 0.01
	strudel.material_override.set_shader_parameter("staerke", staerke)
	strudel.scale = Vector3.ONE * (1.0 + staerke * 6.0)
	if Input.is_key_pressed(KEY_T):
		wasser_weg(6.0 * dt)

	level += (ziel - level) * minf(1.0, dt * 3.0)
	sand_mat.set_shader_parameter("wasser", level)
	for wm in wasser_mats:
		wm.set_shader_parameter("wasser", level)
	pegel_pfeil.position.y = maxf(-7.8, level)
	for sw in schwimmer:
		if sw.n:
			var boden := H(sw.x, sw.z)
			var schwimmt: bool = level - sw.tief > boden
			sw.n.position.y = (level - sw.tief + sin(t * 1.3 + sw.x) * 0.08) if schwimmt else boden - 0.3
			sw.n.rotation.z = sin(t * 0.9 + sw.z) * 0.03 if schwimmt else 0.12

	for f in funde:
		if not gefunden.has(f.name) and level < f.oben - 0.2:
			gefunden[f.name] = true
			_fundliste()
			banner("FUND!", f.name.to_upper(), f.text, 3.2)

	var rest := (level - MIN_LEVEL) / -MIN_LEVEL
	ui.zahl.text = fmt(rest * KM3) + " km³"
	ui.balken.value = (1.0 - rest) * 100.0
	ui.prozent.text = ("%.3f" % ((1.0 - rest) * 100.0)).replace(".", ",") + " % geschafft"
	ui.stand.text = ("%.2f" % level).replace(".", ",") + " m"

func _bewegen(dt: float) -> bool:
	var vor := Vector3(-sin(yaw), 0, -cos(yaw))
	var rechts := Vector3(cos(yaw), 0, -sin(yaw))
	var d := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): d += vor
	if Input.is_key_pressed(KEY_S): d -= vor
	if Input.is_key_pressed(KEY_D): d += rechts
	if Input.is_key_pressed(KEY_A): d -= rechts
	var laeuft := d.length_squared() > 0.0
	if laeuft:
		var renn := Input.is_key_pressed(KEY_SHIFT)
		d = d.normalized() * (12.0 if renn else 6.0) * dt
		if _frei(spieler.x + d.x, spieler.z):
			spieler.x += d.x
		if _frei(spieler.x, spieler.z + d.z):
			spieler.z += d.z
		bob += dt * (14.0 if renn else 9.0)
	vy -= 14.0 * dt
	sprung = maxf(0.0, sprung + vy * dt)
	if sprung == 0.0:
		vy = 0.0
	var g := H(spieler.x, spieler.z)
	spieler.y += (g + 1.7 - spieler.y) * minf(1.0, dt * 12.0)
	cam.position = Vector3(spieler.x, spieler.y + sprung + (sin(bob) * 0.05 if laeuft else 0.0), spieler.z)
	cam.rotation = Vector3(pitch, yaw, 0)
	return laeuft

func _frei(x: float, z: float) -> bool:
	return absf(x) < 370.0 and absf(z) < 370.0 and level - H(x, z) < 1.1

# ---------------------------------------------------------------- Testansichten (für Bilder)
func _demo() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ansicht="):
			var n := int(a.split("=")[1])
			var ansichten := {
				1: [Vector3(6, 0, 136), 0.08, -0.22, 0.0],
				2: [Vector3(30, 0, 30), 0.1, -0.3, -20.0],
				3: [Vector3(25, 0, 20), 0.3, -0.25, -30.0],
				4: [Vector3(10, 0, 128), PI + 0.5, 0.02, 0.0],
				5: [Vector3(0, 0, 112), 0.1, -0.35, 0.0],
				6: [Vector3(-60, 0, 30), -0.6, -0.15, -14.0],
				7: [Vector3(-10, 0, 138), 2.28, -0.05, 0.0],
			}
			var v: Array = ansichten.get(n, ansichten[1])
			spieler = v[0]
			spieler.y = H(spieler.x, spieler.z) + 1.7
			yaw = v[1]
			pitch = v[2]
			level = v[3]
			ziel = v[3]
