class_name Welt
extends Node3D
# Himmel, Licht, Wüste und die Stadt um den Turm.

const SONNE_DIR := Vector3(0.55, 0.5, 0.4)
const HORIZONT := Color("e9dcc4")

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 11
	_umgebung()
	_boden()
	_stadt()

func _umgebung() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
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
	var sonne := DirectionalLight3D.new()
	sonne.light_color = Color("ffe6bf")
	sonne.light_energy = 1.4
	sonne.shadow_enabled = true
	sonne.directional_shadow_max_distance = 3000.0
	add_child(sonne)
	sonne.basis = Basis.looking_at(-SONNE_DIR.normalized(), Vector3.UP)

func _boden() -> void:
	var sand := Bau.matt("d9b47a", 1.0)
	var pm := PlaneMesh.new()
	pm.size = Vector2(60000, 60000)
	var b := MeshInstance3D.new()
	b.mesh = pm
	b.material_override = sand
	add_child(b)
	var platz := Bau.zylinder(1700.0, 1700.0, 0.2, Bau.matt("b9ad9c", 0.95), 64)
	platz.position.y = 0.05
	add_child(platz)
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
				var stw := []
				for k in maxi(hoch, 2):
					stw.append({"poly": poly, "y0": k * 3.5, "h": 3.5})
				add_child(Bau.baue(stw, mats[rng.randi() % 3], dach))
			z += 75.0
		x += 75.0
