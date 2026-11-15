class_name Welt
extends Node3D
# Himmel, Licht, Wüste und die Stadt um den Turm.

const SONNE_DIR := Vector3(0.55, 0.5, 0.4)
const HORIZONT := Color("e9dcc4")

var rng := RandomNumberGenerator.new()
var env: Environment
var haeuser: Array = []        # Rect2 (x, z) aller Häuser – für die Kollision zu Fuß
var haeuser_hoehe: Array = []  # Höhe je Haus (Jetpack fliegt drüber)
var stellplaetze: Array = []    # {name, pos, rect} – freie Plätze für Späteres (zurzeit keiner)
var himmel: ShaderMaterial
var sonne: DirectionalLight3D
const STURM_FARBE := Color("c9955a")
const PLATZ_R := 100.0          # Radius des Platzes um den Turm (Boden-Shader: plaza_r)
const STAND_R := 74.0           # Händler-Stände: Abstand zur Turmmitte
const STAND_WINKEL := [-50.0, 75.0, 210.0, -10.0, -30.0, 105.0]   # in den Lücken zwischen den Turmflügeln (Reihenfolge wie Haendler.STAENDE)
const CASINO_WINKEL := 30.0     # hinter der Spitze eines Flügels, schon in der Stadt
const CASINO_R := 128.0
const CASINO_GROESSE := 30.0
var stand_orte: Array = []      # Vector3 je Händler-Stand
var casino_rect := Rect2()
var hindernisse: Array = []     # Rect2 kleiner Dinge (Palmen, Laternen) – für die Kollision zu Fuß
# See mit Fontänen am Turmfuß (wie die Dubai Fountain): abgerundetes Rechteck hinter dem Händler bei 210°
const SEE_WINKEL := 210.0
const SEE_NAH := 112.0          # vordere Kante (Abstand zur Turmmitte)
const SEE_HALB := Vector2(50.0, 85.0)   # halbe Größe: x = weg vom Turm, y = quer
const SEE_RUND := 35.0          # Eckenradius
const PROMENADE := 16.0         # gepflasterter Rand um den See (Boden-Shader)
# Straßen gibt es nur zwischen zwei „guten“ Kreuzungen – so endet jede Straße an einer Kreuzung (Boden-Shader macht dasselbe)
const RASTER := 75.0            # Straßen liegen bei 37,5 + 75·k
const KREUZ_PLATZ := 30.0       # Kreuzungen erst so weit hinter dem Platzrand
const KREUZ_SEE := 14.0         # … und so weit hinter der See-Promenade
const KREUZ_CASINO := 15.0      # … und nicht in der Nähe des Casinos
var boden_mat: ShaderMaterial

func _ready() -> void:
	rng.seed = 11
	_umgebung()
	_boden()
	_stellplaetze()   # zuerst, damit die Stadt das Casino-Grundstück frei lässt
	var cr := casino_rect.grow(KREUZ_CASINO)
	boden_mat.set_shader_parameter("casino", Vector4(cr.position.x, cr.position.y, cr.end.x, cr.end.y))
	_stadt()
	var details := StadtDetails.new()
	add_child(details)
	details.baue(self)
	var verkehr := Verkehr.new()
	add_child(verkehr)
	verkehr.baue(self)

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
	bm.set_shader_parameter("see_mitte", see_mitte())
	bm.set_shader_parameter("see_dir", _see_dir())
	bm.set_shader_parameter("see_halb", SEE_HALB)
	bm.set_shader_parameter("see_rund", SEE_RUND)
	bm.set_shader_parameter("promenade", PROMENADE)
	bm.set_shader_parameter("allee_r", StadtDetails.ALLEE_BIS)
	bm.set_shader_parameter("kreuz_platz", KREUZ_PLATZ)
	bm.set_shader_parameter("kreuz_see", KREUZ_SEE)
	boden_mat = bm
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

# Händler-Stände verteilt auf dem Platz (in den Lücken zwischen den Turmflügeln) + Grundstück für das Casino
func _stellplaetze() -> void:
	for w in STAND_WINKEL:
		var a := deg_to_rad(w)
		stand_orte.append(Vector3(cos(a), 0, sin(a)) * STAND_R)
	var ac := deg_to_rad(CASINO_WINKEL)
	var mitte := Vector2(cos(ac), sin(ac)) * CASINO_R
	casino_rect = Rect2(mitte - Vector2.ONE * CASINO_GROESSE * 0.5, Vector2.ONE * CASINO_GROESSE)
	var flaeche := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * CASINO_GROESSE
	flaeche.mesh = pm
	flaeche.material_override = Bau.matt("d9cfbd", 0.9)
	flaeche.position = Vector3(mitte.x, 0.03, mitte.y)
	add_child(flaeche)
	# Das Gebäude selbst baut casino.gd (im Spiel), hier liegt nur der helle Vorplatz.

func _stadt() -> void:
	var mats := [
		Bau.shader_mat(Bau.FASSADE_SHADER, {"glas": Color("6d8aa3"), "rahmen": Color("e6dccb"), "bruestung": Color("d8c9b0"), "stock": 3.5, "fenster_breite": 2.2, "dreckig": 0.0, "band_anteil": 0.35, "metall": 0.4}),
		Bau.shader_mat(Bau.FASSADE_SHADER, {"glas": Color("5c7f8f"), "rahmen": Color("c9b79a"), "bruestung": Color("bba78a"), "stock": 3.5, "fenster_breite": 2.6, "dreckig": 0.0, "band_anteil": 0.4, "metall": 0.3}),
		Bau.shader_mat(Bau.FASSADE_SHADER, {"glas": Color("8fb1c9"), "rahmen": Color("9aa3ad"), "bruestung": Color("8a929c"), "stock": 3.5, "fenster_breite": 1.8, "dreckig": 0.0, "metall": 0.7}),
	]
	var dach := Bau.matt("bdb3a3")
	var x := -1500.0
	while x <= 1500.0:
		var z := -1500.0
		while z <= 1500.0:
			var d := Vector2(x, z).length()
			var dichte := 0.85 if d < 600.0 else 0.55      # nah am Turm dichter bebaut
			if d > 100.0 and d < 1600.0 and rng.randf() < dichte:
				var bx := 25.0 + rng.randf() * 30.0
				var bz := 25.0 + rng.randf() * 30.0
				var hoch := int((4.0 + rng.randf() * 22.0) * (1.75 - d / 1600.0))
				if rng.randf() < (0.2 if d < 600.0 else 0.08):
					hoch += 25
				var poly := Bau.rechteck(bx, bz, x + (rng.randf() - 0.5) * 10.0, z + (rng.randf() - 0.5) * 10.0)
				var r := Rect2(poly[0], Vector2(bx, bz))
				# nicht auf den Platz um den Turm bauen
				var naechster := Vector2(clampf(0.0, r.position.x, r.end.x), clampf(0.0, r.position.y, r.end.y))
				var am_see := see_abstand(r.get_center()) - r.size.length() * 0.5 < PROMENADE + 2.0
				if naechster.length() < PLATZ_R + 6.0 or r.intersects(casino_rect.grow(6.0)) or am_see:
					z += 75.0
					continue
				haeuser.append(r)
				haeuser_hoehe.append(maxi(hoch, 2) * 3.5)
				var stw := []
				for k in maxi(hoch, 2):
					stw.append({"poly": poly, "y0": k * 3.5, "h": 3.5})
				add_child(Bau.baue(stw, mats[rng.randi() % 3], dach))
			z += 75.0
		x += 75.0

# ---------------------------------------------------------------- See (Lage + Form)
func _see_dir() -> Vector2:
	var a := deg_to_rad(SEE_WINKEL)
	return Vector2(cos(a), sin(a))

func see_mitte() -> Vector2:
	return _see_dir() * (SEE_NAH + SEE_HALB.x)

# See-Koordinaten (x weg vom Turm, y quer) → Welt (x, z)
func see_welt(l: Vector2) -> Vector2:
	var d := _see_dir()
	return see_mitte() + d * l.x + d.orthogonal() * l.y

# Abstand zum Seeufer (negativ = im Wasser)
func see_abstand(p: Vector2) -> float:
	var d := _see_dir()
	var rel := p - see_mitte()
	var l := Vector2(rel.dot(d), rel.dot(d.orthogonal()))
	var q := l.abs() - (SEE_HALB - Vector2.ONE * SEE_RUND)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - SEE_RUND

# Uferlinie, um "abstand" nach außen versetzt; gleiche Punktzahl bei gleichem "schritt"
func see_umriss(abstand: float, schritt := 4.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var e := SEE_HALB - Vector2.ONE * SEE_RUND
	var ecken := [Vector2(e.x, e.y), Vector2(-e.x, e.y), Vector2(-e.x, -e.y), Vector2(e.x, -e.y)]
	var bogen := 10
	for k in 4:
		var c: Vector2 = ecken[k]
		for j in bogen:
			var a := deg_to_rad(k * 90.0 + 90.0 * j / bogen)
			pts.append(see_welt(c + Vector2(cos(a), sin(a)) * (SEE_RUND + abstand)))
		var a2 := deg_to_rad((k + 1) * 90.0)
		var r2 := Vector2(cos(a2), sin(a2)) * (SEE_RUND + abstand)
		var nach: Vector2 = ecken[(k + 1) % 4]
		var von: Vector2 = c + r2
		var bis: Vector2 = nach + r2
		var n := maxi(1, int(ceil(c.distance_to(nach) / schritt)))
		for i in n:
			pts.append(see_welt(von.lerp(bis, float(i) / n)))
	return pts

# ---------------------------------------------------------------- Straßennetz
func kreuzung_ok(k: Vector2) -> bool:
	if k.length() < PLATZ_R + KREUZ_PLATZ:
		return false
	if see_abstand(k) < PROMENADE + KREUZ_SEE:
		return false
	return not casino_rect.grow(KREUZ_CASINO).has_point(k)

# Straßenstück zwischen zwei benachbarten Kreuzungen
func stueck_da(a: Vector2, b: Vector2) -> bool:
	return kreuzung_ok(a) and kreuzung_ok(b)

# Arme einer Kreuzung: [+x, −x, +z, −z]
func arme(k: Vector2) -> Array:
	var l := []
	for d in [Vector2(RASTER, 0), Vector2(-RASTER, 0), Vector2(0, RASTER), Vector2(0, -RASTER)]:
		l.append(kreuzung_ok(k) and stueck_da(k, k + d))
	return l

# Hat die Kreuzung Querverkehr zur Achse (0 = Straße entlang z, 1 = entlang x)?
func querverkehr(k: Vector2, achse: int) -> bool:
	var a := arme(k)
	return (a[0] or a[1]) if achse == 0 else (a[2] or a[3])
