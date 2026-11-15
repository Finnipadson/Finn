extends Node3D
# Startszene (Phase 0): Welt + Turm + freie Kamera zum Umschauen.
# Testbilder: godot --path . --write-movie bild.png --fixed-fps 30 --quit-after 15 -- --ansicht=N
#   1 = Turm von weitem, 2 = Fassade nah (mit Markierung eines Fensters), 3 = Aussicht von oben,
#   4 = Testfahrt an der Fassade (zum Messen von Flimmern). Grafik-Schalter zum Testen: --taa=0|1 --ssr=0|1 --ssil=0|1 --msaa=0..3 --smaa=0|1
#   (Standard: TAA an, MSAA 4x, SSR an, SSIL aus – gemessen am wenigsten Flimmern)

var welt: Welt
var turm: Turm
var cam: Camera3D
var yaw := 0.0
var pitch := 0.0
var info: Label
var ansicht := 0
var fahrt := Vector3.ZERO
var schalter := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ansicht="):
			ansicht = int(a.split("=")[1])
		for k in ["taa", "ssr", "ssil", "msaa", "smaa"]:
			if a.begins_with("--%s=" % k):
				schalter[k] = int(a.split("=")[1])
	welt = Welt.new()
	add_child(welt)
	turm = Turm.new()
	add_child(turm)
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
	vp.use_taa = schalter.get("taa", 1) == 1
	vp.msaa_3d = schalter.get("msaa", 2) as Viewport.MSAA
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if schalter.get("smaa", 0) == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
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
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.0022
		pitch = clampf(pitch - e.relative.y * 0.0022, -1.5, 1.5)
		cam.rotation = Vector3(pitch, yaw, 0)
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(dt: float) -> void:
	cam.position += fahrt * dt
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
