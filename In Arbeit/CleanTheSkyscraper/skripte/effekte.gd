class_name Effekte
extends Node3D
# Funkel-Effekte (Phase 5): Glanz-Streifen + Sternchen auf frisch geputzten Fenstern, Seifenblasen/Tropfen beim Wischen,
# Sprühnebel bei Sprühgeräten, fliegende Münzen ins Geld-Feld des HUD. Alles weich gefiltert (kein Flimmern).

const GLANZ_DAUER := 0.9

var spiel: Spiel
var _glanz_shader: Shader
var _stern_tex: Texture2D
var _blasen: CPUParticles3D
var _nebel: CPUParticles3D
var _tropfen: CPUParticles3D
var _muenz_tex: Texture2D
var _muenz_zeit := 0.0
var _alt_off := Vector2.ZERO
var aktiv_glanz: Array = []         # [MeshInstance3D, ShaderMaterial, Zeit]

func setup(s: Spiel) -> void:
	spiel = s
	_glanz_shader = Shader.new()
	_glanz_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float t = 0.0;
void fragment() {
	// schräger, weicher Lichtstreifen wandert einmal über das Glas, dazu ein leichter Schein im ganzen Fenster
	float d = UV.x * 0.8 + (1.0 - UV.y) * 0.55;
	float pos = mix(-0.35, 1.7, t);
	float streifen = exp(-pow((d - pos) * 6.0, 2.0)) + 0.45 * exp(-pow((d - pos + 0.16) * 14.0, 2.0));
	float rand = smoothstep(0.0, 0.04, UV.x) * smoothstep(1.0, 0.96, UV.x) * smoothstep(0.0, 0.04, UV.y) * smoothstep(1.0, 0.96, UV.y);
	float schein = 0.12 * sin(t * 3.14159);
	ALBEDO = vec3(1.0, 0.97, 0.9) * (streifen * 0.75 + schein) * rand * (1.0 - t * 0.4);
}
"""
	_stern_tex = _stern()
	_muenz_tex = _muenze()
	_blasen = _partikel(Color(1, 1, 1, 0.55), 0.035, 0.065, 0.9, 40)
	_blasen.gravity = Vector3(0, -0.6, 0)
	_blasen.initial_velocity_min = 0.1
	_blasen.initial_velocity_max = 0.45
	_blasen.spread = 70.0
	_nebel = _partikel(Color(0.85, 0.93, 1.0, 0.35), 0.06, 0.16, 0.6, 60)
	_nebel.gravity = Vector3(0, -0.4, 0)
	_nebel.initial_velocity_min = 0.3
	_nebel.initial_velocity_max = 1.4
	_nebel.spread = 85.0
	_tropfen = _partikel(Color(0.8, 0.92, 1.0, 0.6), 0.02, 0.035, 1.6, 24)
	_tropfen.gravity = Vector3(0, -2.5, 0)
	_tropfen.initial_velocity_min = 0.0
	_tropfen.initial_velocity_max = 0.1

# Weiche runde Partikel (Billboard), werden per emitting an/aus geschaltet
func _partikel(farbe: Color, g0: float, g1: float, leben: float, menge: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * (g0 + g1) * 0.5   # Größe steckt im Mesh (Skalierung der Partikel nur ±)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _rund()
	qm.material = m
	p.mesh = qm
	p.amount = menge
	p.lifetime = leben
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3(0, 0, 1)
	p.scale_amount_min = 2.0 * g0 / (g0 + g1)
	p.scale_amount_max = 2.0 * g1 / (g0 + g1)
	p.color = farbe
	var verlauf := Gradient.new()
	verlauf.set_color(0, Color(1, 1, 1, 1))
	verlauf.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = verlauf
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.06
	add_child(p)
	return p

static var _rund_tex: Texture2D
static func _rund() -> Texture2D:
	if _rund_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.55, Color(1, 1, 1, 0.55))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 32
		gt.height = 32
		_rund_tex = gt
	return _rund_tex

# Vierstrahliger Stern mit Glühen (für das Funkeln)
func _stern() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
			var strahl := maxf(exp(-absf(p.x) * 26.0) * (1.0 - absf(p.y)), exp(-absf(p.y) * 26.0) * (1.0 - absf(p.x)))
			var kern := exp(-p.length_squared() * 30.0)
			var a := clampf(strahl * 0.9 + kern, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# Goldene Münze (für die HUD-Münzen)
func _muenze() -> Texture2D:
	var n := 40
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
			var r := p.length()
			var a := clampf((1.0 - r) * 14.0, 0.0, 1.0)
			var c := Color("f5c542").lerp(Color("c98d14"), clampf(p.y * 0.5 + 0.5, 0.0, 1.0))
			if r > 0.78 and r < 0.88:
				c = Color("ffe48a")
			if p.distance_to(Vector2(-0.3, -0.35)) < 0.18:
				c = c.lerp(Color(1, 1, 0.9), 0.7)
			img.set_pixel(x, y, Color(c, a))
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- frisch geputztes Fenster
func fenster_glanz(f: int, spalte: int) -> void:
	var turm := spiel.turm
	var glas_h := Turm.STOCK_H * (1.0 - Turm.BAND_ANTEIL)
	var yy := f * Turm.STOCK_H + Turm.STOCK_H * Turm.BAND_ANTEIL + glas_h * 0.5
	var p := turm.fassaden_punkt(f, (spalte + 0.5) * Turm.FENSTER_B, yy)
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(Turm.FENSTER_B * 0.97, glas_h * 0.97)
	mi.mesh = qm
	var m := ShaderMaterial.new()
	m.shader = _glanz_shader
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var n: Vector3 = p.normal
	var x := Vector3.UP.cross(n).normalized()   # rechts beim Blick auf die Fassade (Basis rechtshändig)
	mi.global_transform = Transform3D(Basis(x, Vector3.UP, n), p.pos + n * 0.03)
	aktiv_glanz.append([mi, m, 0.0])
	# ein paar Sternchen, die kurz aufblitzen
	for k in 3:
		var st := Sprite3D.new()
		st.texture = _stern_tex
		st.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		st.shaded = false
		st.transparent = true
		st.modulate = Color(1, 0.97, 0.85, 0.0)
		st.pixel_size = 0.006
		st.no_depth_test = false
		add_child(st)
		st.global_position = p.pos + n * 0.06 + x * randf_range(-0.6, 0.6) * Turm.FENSTER_B * 0.5 + Vector3.UP * randf_range(-0.45, 0.45) * glas_h
		var tw := st.create_tween()
		tw.tween_interval(0.12 + k * 0.16)
		tw.set_parallel(true)
		tw.tween_property(st, "modulate:a", 1.0, 0.12)
		tw.tween_property(st, "pixel_size", 0.011, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(st, "modulate:a", 0.0, 0.35)
		tw.tween_callback(st.queue_free)

# ---------------------------------------------------------------- Münzen ins Geld-Feld
func muenzen(anzahl := 3) -> void:
	if _muenz_zeit > 0.0:
		return
	_muenz_zeit = 0.18
	var hud := spiel.hud
	var ziel := hud.geld.get_global_rect().get_center()
	var start := hud.get_viewport().get_visible_rect().size * 0.5
	for k in anzahl:
		var tr := TextureRect.new()
		tr.texture = _muenz_tex
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.size = Vector2(26, 26)
		tr.position = start + Vector2(randf_range(-50, 50), randf_range(-30, 30)) - tr.size * 0.5
		tr.modulate.a = 0.0
		hud.wurzel.add_child(tr)
		var tw := tr.create_tween()
		tw.tween_interval(k * 0.07)
		tw.tween_property(tr, "modulate:a", 1.0, 0.08)
		var von := tr.position
		var mitte := von.lerp(ziel, 0.5) + Vector2(randf_range(-60, 60), -80)
		var bahn := func(u: float) -> void:   # Bogen (quadratische Bézierkurve) zum Geld-Feld
			tr.position = von.lerp(mitte, u).lerp(mitte.lerp(ziel - tr.size * 0.5, u), u)
		tw.tween_method(bahn, 0.0, 1.0, 0.55).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			hud.geld_puls()
			tr.queue_free())

func _process(dt: float) -> void:
	_muenz_zeit = maxf(0.0, _muenz_zeit - dt)
	var i := 0
	while i < aktiv_glanz.size():
		var g: Array = aktiv_glanz[i]
		g[2] = float(g[2]) + dt / GLANZ_DAUER
		(g[1] as ShaderMaterial).set_shader_parameter("t", g[2])
		if float(g[2]) >= 1.0:
			(g[0] as Node).queue_free()
			aktiv_glanz.remove_at(i)
		else:
			i += 1
	# Seifenblasen und Tropfen am Schwamm/Abzieher, Sprühnebel am Auftreffpunkt
	var sp := spiel.spieler
	var wischt := sp.aktiv and sp.wischt
	var tempo := sp.schwamm_off.distance_to(_alt_off) / maxf(dt, 0.001)
	_alt_off = sp.schwamm_off
	var punkt := sp.glas_punkt + sp.rechts * sp.schwamm_off.x + Vector3.UP * sp.schwamm_off.y + sp.normal * 0.08
	var wisch := wischt and sp.wz_art == "wisch" and tempo > 0.15
	_blasen.emitting = wisch
	_tropfen.emitting = wisch and str(sp.wz.get("modell", "")) == "abzieher"
	_nebel.emitting = wischt and sp.wz_art == "spray" and sp.spray_trifft
	for p in [_blasen, _tropfen, _nebel]:
		(p as CPUParticles3D).global_position = punkt
		(p as CPUParticles3D).direction = sp.normal
