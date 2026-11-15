class_name Welt
extends Node3D
# Himmel, Licht, Wüste und die Stadt um den Turm.

const SONNE_DIR := Vector3(0.55, 0.5, 0.4)
const HORIZONT := Color("e9dcc4")

var rng := RandomNumberGenerator.new()
var env: Environment
var haeuser: Array = []        # Rect2 (x, z) aller Häuser – für die Kollision zu Fuß
var stellplaetze: Array = []    # {name, pos, rect} – Plätze für spätere Händler/Casino
var himmel: ShaderMaterial
var sonne: DirectionalLight3D
const STURM_FARBE := Color("c9955a")

func _ready() -> void:
	rng.seed = 11
	_umgebung()
	_boden()
	_stadt()
	_stellplaetze()

func _umgebung() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	himmel = sm
	sm.shader = load("res://shader/himmel.gdshader")
	sm.set_shader_parameter("sonne", SONNE_DIR.normalized())
	sm.set_shader_parameter("horizont", HORIZONT)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.68
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssr_enabled = true
	env.ssr_max_steps = 96
	env.ssil_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.fog_enabled = true
	env.fog_light_color = HORIZONT
	env.fog_density = 0.00011
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sonne = DirectionalLight3D.new()
	sonne.light_color = Color("ffe6bf")
	sonne.light_energy = 1.4
	sonne.shadow_enabled = true
	sonne.directional_shadow_max_distance = 3000.0
	add_child(sonne)
	sonne.basis = Basis.looking_at(-SONNE_DIR.normalized(), Vector3.UP)

# Sandsturm: 0 = klar, 1 = voll. Nebel wird dicht und orange, Sonne und Himmel trüb.
func sandsturm(k: float) -> void:
	env.fog_density = lerpf(0.00011, 0.012, k * k)
	env.fog_light_color = HORIZONT.lerp(STURM_FARBE, k)
	env.fog_sky_affect = lerpf(0.0, 0.9, k)
	sonne.light_energy = lerpf(1.4, 0.55, k)
	himmel.set_shader_parameter("horizont", HORIZONT.lerp(STURM_FARBE, k))
	himmel.set_shader_parameter("oben", Color(0.165, 0.47, 0.84).lerp(Color("b49b78"), k * 0.85))

func _boden() -> void:
	var sand := Bau.matt("d9b47a", 1.0)
	var pm := PlaneMesh.new()
	pm.size = Vector2(60000, 60000)
	var b := MeshInstance3D.new()
	b.mesh = pm
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shader/boden.gdshader")
	b.material_override = bm   # Platz, Park, Straßenraster, weicher Übergang in die Wüste
	add_child(b)
	for i in 40: # Dünen am Horizont
		var a := rng.randf() * TAU
		var d := 4000.0 + rng.randf() * 9000.0
		var duene := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		duene.mesh = sm
		duene.material_override = sand
		duene.position = Vector3(cos(a) * d, -20, sin(a) * d)
		duene.scale = Vector3(500 + rng.randf() * 900, 60 + rng.randf() * 120, 400 + rng.randf() * 700)
		duene.rotation.y = rng.randf() * TAU
		add_child(duene)

# Markierte Flächen auf dem Platz, auf denen später Händler oder ein Casino stehen sollen
func _stellplaetze() -> void:
	for sp in [["Händler", 35.0], ["Casino", 155.0]]:
		var a := deg_to_rad(sp[1])
		var mitte := Vector2(cos(a), sin(a)) * 150.0
		var flaeche := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(18, 18)
		flaeche.mesh = pm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("d9cfbd")
		m.roughness = 0.9
		flaeche.material_override = m
		flaeche.position = Vector3(mitte.x, 0.03, mitte.y)
		add_child(flaeche)
		for k in 4:   # gelbe Randmarkierung
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(18.4, 0.04, 0.3) if k < 2 else Vector3(0.3, 0.04, 18.4)
			b.mesh = bm
			b.material_override = Bau.matt("f2c230", 0.6)
			var o := Vector3(0, 0, 9.0 * (1 if k == 0 else -1)) if k < 2 else Vector3(9.0 * (1 if k == 2 else -1), 0, 0)
			b.position = Vector3(mitte.x, 0.05, mitte.y) + o
			add_child(b)
		var pfahl := Bau.zylinder(0.06, 0.06, 2.2, Bau.matt("5b5f66"), 8)
		pfahl.position = Vector3(mitte.x, 1.1, mitte.y)
		add_child(pfahl)
		var schild := Label3D.new()
		schild.text = "Demnächst:
%s" % sp[0]
		schild.font_size = 96
		schild.pixel_size = 0.006
		schild.outline_size = 18
		schild.modulate = Color("1f5fae")
		schild.outline_modulate = Color.WHITE
		schild.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		schild.position = Vector3(mitte.x, 2.7, mitte.y)
		add_child(schild)
		stellplaetze.append({"name": sp[0], "pos": Vector3(mitte.x, 0, mitte.y), "rect": Rect2(mitte - Vector2(0.15, 0.15), Vector2(0.3, 0.3))})

func _stadt() -> void:
	var mats := [
		Bau.shader_mat(Bau.FASSADE_SHADER, {"glas": Color("6d8aa3"), "rahmen": Color("e6dccb"), "bruestung": Color("d8c9b0"), "stock": 3.5, "fenster_breite": 2.2, "dreckig": 0.2, "band_anteil": 0.35, "metall": 0.4}),
		Bau.shader_mat(Bau.FASSADE_SHADER, {"glas": Color("5c7f8f"), "rahmen": Color("c9b79a"), "bruestung": Color("bba78a"), "stock": 3.5, "fenster_breite": 2.6, "dreckig": 0.2, "band_anteil": 0.4, "metall": 0.3}),
		Bau.shader_mat(Bau.FASSADE_SHADER, {"glas": Color("8fb1c9"), "rahmen": Color("9aa3ad"), "bruestung": Color("8a929c"), "stock": 3.5, "fenster_breite": 1.8, "dreckig": 0.1, "metall": 0.7}),
	]
	var dach := Bau.matt("bdb3a3")
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
				var poly := Bau.rechteck(bx, bz, x + (rng.randf() - 0.5) * 10.0, z + (rng.randf() - 0.5) * 10.0)
				haeuser.append(Rect2(poly[0], Vector2(bx, bz)))
				var stw := []
				for k in maxi(hoch, 2):
					stw.append({"poly": poly, "y0": k * 3.5, "h": 3.5})
				add_child(Bau.baue(stw, mats[rng.randi() % 3], dach))
			z += 75.0
		x += 75.0
