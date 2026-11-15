extends Node3D
# Startszene: Welt + Turm. Normal = Spiel (Gondel, Putzen). Mit --ansicht=1..4 freie Kamera / Testansichten.
# Testbilder: godot --path . --write-movie bild.png --fixed-fps 30 --quit-after 15 -- --ansicht=N
#   1 = Turm von weitem, 2 = Fassade nah (Fenster markiert), 3 = Aussicht von oben, 4 = Testfahrt (Flimmern),
#   5..10 = Spiel-Tests (siehe spiel.gd). --frei: alle Stockwerke ohne Sperre, --geld=N: Startgeld (Tests)
#   Grafik-Schalter: --taa=0|1 --ssr=0|1 --ssil=0|1 --msaa=0..3 --smaa=0|1 --scale=10..20 --fsr=0|1 --fpstest=1

var welt: Welt
var turm: Turm
var cam: Camera3D
var yaw := 0.0
var pitch := 0.0
var info: Label
var ansicht := 0
var fahrt := Vector3.ZERO
var dreh := 0.0
var schalter := {}
var frei := false
var spiel := false
var test_geld := -1
var spiel_knoten: Spiel

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ansicht="):
			ansicht = int(a.split("=")[1])
		if a == "--frei":
			frei = true
		if a.begins_with("--geld="):
			test_geld = int(a.split("=")[1])
		for k in ["taa", "ssr", "ssil", "msaa", "smaa", "scale", "fsr", "fpstest", "ssao", "schatten", "glow"]:
			if a.begins_with("--%s=" % k):
				schalter[k] = int(a.split("=")[1])
	welt = Welt.new()
	add_child(welt)
	turm = Turm.new()
	add_child(turm)
	if ansicht == 0 or ansicht >= 5:
		spiel = true
		var s := Spiel.new()
		spiel_knoten = s
		add_child(s)
		s.starten(turm, welt, ansicht, frei, test_geld)
		_grafik()
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
			var abstand := 7.0   # --abstand=m: Entfernung zur Fassade (Flimmer-Tests)
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--abstand="):
					abstand = float(arg.split("=")[1])
			cam.position = p.pos + p.normal * abstand + Vector3.UP * -1.0
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
	# --kamera=x,y,z,zielx,ziely,zielz: freie Kamera an eine Stelle setzen (für Testbilder)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kamera="):
			var w := arg.split("=")[1].split_floats(",")
			if w.size() == 6:
				cam.position = Vector3(w[0], w[1], w[2])
				cam.look_at(Vector3(w[3], w[4], w[5]))
		# --fahrt=dx,dy,dz: Kamera gleichmäßig bewegen (m/s) – für Flimmer-Messungen (tools/flimmern.py)
		if arg.begins_with("--fahrt="):
			var v := arg.split("=")[1].split_floats(",")
			if v.size() == 3:
				fahrt = Vector3(v[0], v[1], v[2])
		# --tempo=f: Testfahrt (z. B. Ansicht 4) langsamer/schneller
		if arg.begins_with("--tempo="):
			fahrt *= float(arg.split("=")[1])
		# --dreh=grad_pro_s: Kamera langsam um die Hochachse drehen
		if arg.begins_with("--dreh="):
			dreh = deg_to_rad(float(arg.split("=")[1]))
	var r := cam.rotation
	yaw = r.y
	pitch = r.x
	info.text = "Clean the Skyscraper · Phase 0\n%d m hoch · %d Stockwerke · %s Fenster\n%s\nKlick: Maus fangen · WASD fliegen · Q/E runter/hoch · Shift schnell · Esc Maus frei" % [int(turm.spitze), Turm.STOCKWERKE, _punkte(turm.fenster_gesamt), text]

# Kantenglättung und Licht-Effekte (Standard + Test-Schalter)
func _grafik() -> void:
	var vp := get_viewport()
	# Standard: 2-faches Supersampling + MSAA 4x, kein TAA. Das Flimmern beheben die Shader selbst (gefilterte
	# Muster). TAA (Einstellung „taa“, Standard aus) glättet beim Fahren noch etwas mehr, lässt aber das Bild
	# im Stand an Pfosten und Schmutz sichtbar wackeln (gemessen mit tools/flimmern.py, Orte schmutz_25/60).
	var ruhig := false
	if spiel_knoten:
		ruhig = spiel_knoten.wirtschaft.einstellungen.get("taa", false)
	if schalter.has("taa"):
		ruhig = schalter.taa == 1
	vp.use_taa = ruhig
	vp.msaa_3d = schalter.get("msaa", 2) as Viewport.MSAA
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if schalter.get("smaa", 0) == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	# Supersampling: intern höher rendern (scale in Zehnteln, 20 = 2-fach); FSR2 bringt eigene Glättung mit
	vp.scaling_3d_scale = schalter.get("scale", 17 if ruhig else 20) / 10.0
	if schalter.get("fsr", 0) == 1:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		vp.use_taa = false
	# SSR aus (15.11.2026): spiegelt den Boden verschmiert in die Brüstungen am Turmfuß, sonst kaum sichtbar
	welt.env.ssr_enabled = schalter.get("ssr", 0) == 1
	welt.env.ssil_enabled = schalter.get("ssil", 0) == 1
	# Test-Schalter (Flimmer-Suche): Umgebungsverdeckung, Sonnenschatten, Glühen abschaltbar
	if schalter.has("ssao"):
		welt.env.ssao_enabled = schalter.ssao == 1
	if schalter.has("schatten"):
		welt.sonne.shadow_enabled = schalter.schatten == 1
	if schalter.has("glow"):
		welt.env.glow_enabled = schalter.glow == 1

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

func _process(dt: float) -> void:
	if spiel:
		if schalter.has("fpstest"):
			fps_zeit += dt
			if fps_zeit > 6.0:
				print("FPS: %d" % Engine.get_frames_per_second())
				get_tree().quit()
		return
	cam.position += fahrt * dt
	if dreh != 0.0:
		cam.rotate_y(dreh * dt)
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
