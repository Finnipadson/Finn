extends Node3D
# Startszene: Welt + Turm. Normal = Spiel (Gondel, Putzen). Mit --ansicht=1..4 freie Kamera / Testansichten.
# Testbilder: godot --path . --write-movie bild.png --fixed-fps 30 --quit-after 15 -- --ansicht=N
#   1 = Turm von weitem, 2 = Fassade nah (Fenster markiert), 3 = Aussicht von oben, 4 = Testfahrt (Flimmern),
#   5 = Spiel-Demo (automatisch geputzte Fenster, Schwamm am Glas). --frei: alle Stockwerke ohne Sperre
#   Grafik-Schalter: --taa=0|1 --ssr=0|1 --ssil=0|1 --msaa=0..3 --smaa=0|1 --scale=10..20 --fsr=0|1 --fpstest=1

var welt: Welt
var turm: Turm
var cam: Camera3D
var yaw := 0.0
var pitch := 0.0
var info: Label
var ansicht := 0
var fahrt := Vector3.ZERO
var schalter := {}
var frei := false
# Spiel
var spiel := false
var zustand: FensterZustand
var spieler: Spieler
var hud: Hud
var geld := 0
var demo_zeit := 0.0
const ERSTER_ABSCHNITT := 18   # Phase 1: nur bis zur ersten Stufe (Stockwerk 18)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ansicht="):
			ansicht = int(a.split("=")[1])
		if a == "--frei":
			frei = true
		for k in ["taa", "ssr", "ssil", "msaa", "smaa", "scale", "fsr", "fpstest"]:
			if a.begins_with("--%s=" % k):
				schalter[k] = int(a.split("=")[1])
	welt = Welt.new()
	add_child(welt)
	turm = Turm.new()
	add_child(turm)
	if ansicht == 0 or ansicht >= 5:
		_spiel_starten()
		return
	cam = Camera3D.new()
	cam.far = 40000.0
	cam.fov = 60.0
	add_child(cam)
	_grafik()
	_hud()
	_startansicht()

func _startansicht() -> void:
	var text := ""
	match ansicht:
		2:
			# Fassade nah: Fenster in Stockwerk 50 markieren → prüft, ob Nummerierung und Shader-Fenster übereinstimmen
			var f := 50
			var spalte := 37
			var weg := spalte * Turm.FENSTER_B + Turm.FENSTER_B * 0.5
			var y := f * Turm.STOCK_H + Turm.STOCK_H * 0.6
			var p := turm.fassaden_punkt(f, weg, y)
			var mark := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.25
			sm.height = 0.5
			mark.mesh = sm
			var mm := StandardMaterial3D.new()
			mm.albedo_color = Color("ff3b30")
			mm.emission_enabled = true
			mm.emission = Color("ff3b30")
			mark.material_override = mm
			mark.position = p.pos + p.normal * 0.4
			add_child(mark)
			cam.position = p.pos + p.normal * 9.0 + p.tangente * 3.0 + Vector3.UP * -1.5
			cam.look_at(p.pos + Vector3.UP * 1.0)
			text = "Markiert: Fenster Nr. %s (Stockwerk %d, Spalte %d)" % [_punkte(turm.fenster_id(f, weg) + 1), f + 1, spalte + 1]
		4:
			var p := turm.fassaden_punkt(40, 120.0, 40 * Turm.STOCK_H)
			cam.position = p.pos + p.normal * 7.0 + Vector3.UP * -1.0
			cam.look_at(p.pos + Vector3.UP * 1.0)
			fahrt = p.tangente * 1.5
			text = "Testfahrt an der Fassade"
		3:
			var p := turm.fassaden_punkt(150, 10.0, 150 * Turm.STOCK_H)
			cam.position = p.pos + p.normal * 6.0
			cam.look_at(cam.position + p.normal * 100.0 + Vector3.DOWN * 32.0)
			text = "Aussicht aus Stockwerk 150 (%d m)" % int(150 * Turm.STOCK_H)
		_:
			cam.fov = 52.0
			var dist := turm.spitze * 1.3
			cam.position = Vector3(-dist * 0.55, turm.spitze * 0.28, dist * 0.84)
			cam.look_at(Vector3(0, turm.spitze * 0.47, 0))
	var r := cam.rotation
	yaw = r.y
	pitch = r.x
	info.text = "Clean the Skyscraper · Phase 0\n%d m hoch · %d Stockwerke · %s Fenster\n%s\nKlick: Maus fangen · WASD fliegen · Q/E runter/hoch · Shift schnell · Esc Maus frei" % [int(turm.spitze), Turm.STOCKWERKE, _punkte(turm.fenster_gesamt), text]

# Kantenglättung und Licht-Effekte (Standard + Test-Schalter)
func _grafik() -> void:
	var vp := get_viewport()
	# Standard (gemessen gegen eine fein berechnete Referenz): 2-faches Supersampling + MSAA 4x, kein TAA
	# (TAA wackelt das Bild minimal und wirkt dadurch unruhiger)
	vp.use_taa = schalter.get("taa", 0) == 1
	vp.msaa_3d = schalter.get("msaa", 2) as Viewport.MSAA
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if schalter.get("smaa", 0) == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	# Supersampling: intern höher rendern (scale in Zehnteln, 20 = 2-fach); FSR2 bringt eigene Glättung mit
	vp.scaling_3d_scale = schalter.get("scale", 20) / 10.0
	if schalter.get("fsr", 0) == 1:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		vp.use_taa = false
	welt.env.ssr_enabled = schalter.get("ssr", 1) == 1
	welt.env.ssil_enabled = schalter.get("ssil", 0) == 1

func _hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	info = Label.new()
	var ls := LabelSettings.new()
	ls.font_size = 24
	ls.font_color = Color.WHITE
	ls.outline_size = 8
	ls.outline_color = Color("123a6b")
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI Black", "Arial Black"])
	ls.font = f
	info.label_settings = ls
	info.position = Vector2(24, 18)
	cl.add_child(info)

# ---------------------------------------------------------------- freie Kamera
func _unhandled_input(e: InputEvent) -> void:
	if spiel:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.0022
		pitch = clampf(pitch - e.relative.y * 0.0022, -1.5, 1.5)
		cam.rotation = Vector3(pitch, yaw, 0)
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

var fps_zeit := 0.0

# ---------------------------------------------------------------- Spiel
func _spiel_starten() -> void:
	spiel = true
	zustand = FensterZustand.new(turm)
	zustand.verbinde(turm.glas)
	turm.glas.set_shader_parameter("mit_zustand", true)
	spieler = Spieler.new()
	add_child(spieler)
	var oberste := (Turm.STOCKWERKE if frei else ERSTER_ABSCHNITT) * Turm.STOCK_H - 2.6
	spieler.setup(turm, zustand, 2, 236.0, oberste)
	spieler.fenster_sauber.connect(_fenster_sauber)
	hud = Hud.new()
	add_child(hud)
	_grafik()
	if ansicht >= 5:
		spieler.gesperrt = true
		spieler.yaw = 0.25
		spieler.pitch = 0.05

func _fenster_sauber(f: int, spalte: int) -> void:
	var lohn := 1 + f / 10
	geld += lohn
	hud.pop("+%d €" % lohn)
	_funkeln(spieler.fenster_mitte(f, spalte))

func _funkeln(p: Vector3) -> void:
	var t := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.95, 0.75)
	m.albedo_texture = _funkel_textur()
	qm.material = m
	t.mesh = qm
	t.amount = 28
	t.one_shot = true
	t.explosiveness = 0.85
	t.lifetime = 0.9
	t.direction = Vector3.UP
	t.spread = 180.0
	t.gravity = Vector3.ZERO
	t.initial_velocity_min = 0.6
	t.initial_velocity_max = 1.6
	t.scale_amount_min = 0.5
	t.scale_amount_max = 1.3
	t.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	t.emission_box_extents = Vector3(0.6, 1.2, 0.05)
	t.position = p
	add_child(t)
	t.emitting = true
	get_tree().create_timer(1.5).timeout.connect(t.queue_free)

var _funkel_tex: Texture2D
func _funkel_textur() -> Texture2D:
	if _funkel_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 64
		gt.height = 64
		_funkel_tex = gt
	return _funkel_tex

func _spiel_takt(dt: float) -> void:
	if ansicht == 5:
		_demo(dt)
	elif ansicht == 6:
		# Testfahrt: seitlich um die Flügelspitze und nach oben über eine Stufe
		spieler.weg += 5.0 * dt
		spieler.y = minf(spieler.y + 6.0 * dt, 30 * Turm.STOCK_H)
	hud.zeige(zustand.sauber_zahl, turm.fenster_gesamt, geld, spieler.y, spieler.stock)
	if spieler.wischt:
		var u := fposmod(spieler.weg + spieler.schwamm_off.x * spieler.richtung, turm.umfaenge[spieler.stock]) / Turm.FENSTER_B
		var f := turm.stockwerk_bei(spieler.y + spieler.schwamm_off.y)
		hud.fortschritt(zustand.fortschritt(f, int(u)), true)
	else:
		hud.fortschritt(0.0, false)

# Testbild: der Schwamm fährt automatisch in Schlangenlinien über die Fenster vor der Gondel –
# genau derselbe Weg wie beim Putzen mit der Maus (Spieler._wischen → _stempel → FensterZustand)
func _demo(dt: float) -> void:
	demo_zeit += dt
	spieler.wischt = true
	var reihen := 14
	var dauer := 0.32                       # Sekunden pro Reihe
	var r := mini(int(demo_zeit / dauer), reihen - 1)
	var t := fmod(demo_zeit, dauer) / dauer
	if r % 2 == 1:
		t = 1.0 - t
	spieler.schwamm_off = Vector2(lerpf(-1.7, 1.2, t), lerpf(0.35, 2.5, float(r) / (reihen - 1)))

func _process(dt: float) -> void:
	if spiel:
		_spiel_takt(dt)
		if schalter.has("fpstest"):
			fps_zeit += dt
			if fps_zeit > 6.0:
				print("FPS: %d" % Engine.get_frames_per_second())
				get_tree().quit()
		return
	cam.position += fahrt * dt
	if schalter.has("fpstest"):
		fps_zeit += dt
		if fps_zeit > 6.0:
			print("FPS: %d bei %s" % [Engine.get_frames_per_second(), get_viewport().get_visible_rect().size])
			get_tree().quit()
	var d := Vector3.ZERO
	var b := cam.global_basis
	if Input.is_key_pressed(KEY_W): d -= b.z
	if Input.is_key_pressed(KEY_S): d += b.z
	if Input.is_key_pressed(KEY_A): d -= b.x
	if Input.is_key_pressed(KEY_D): d += b.x
	if Input.is_key_pressed(KEY_E): d += Vector3.UP
	if Input.is_key_pressed(KEY_Q): d -= Vector3.UP
	if d != Vector3.ZERO:
		cam.position += d.normalized() * (150.0 if Input.is_key_pressed(KEY_SHIFT) else 20.0) * dt

func _punkte(n: int) -> String:
	var s := str(n)
	var aus := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			aus += "."
		aus += s[i]
	return aus
