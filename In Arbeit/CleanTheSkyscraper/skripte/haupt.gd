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
		for k in ["taa", "ssr", "ssil", "msaa", "smaa", "scale", "fsr", "fpstest", "ssao", "schatten", "glow", "agx", "volnebel", "spiegel"]:
			if a.begins_with("--%s=" % k):
				schalter[k] = int(a.split("=")[1])
	# Globale Einstellungen (Phase 5): in Tests und beim Bot eigene Datei + Standardtasten
	var test := ansicht != 0 or "--durchspielen" in OS.get_cmdline_user_args()
	Optionen.laden(test)
	Optionen.aktiv = not test
	Optionen.geaendert_fn = _optionen_geaendert
	var ton := Ton.new()
	add_child(ton)
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
		# Mehrspieler (7a): --host[=PORT] sofort Gastgeber, --join=ADRESSE sofort beitreten (nur beim ersten Start)
		var host_arg := ""
		var join_arg := ""
		for a in OS.get_cmdline_user_args():
			if a == "--host-internet":
				host_arg = "internet"
			elif a == "--host" or a.begins_with("--host="):
				host_arg = a.substr(7) if a.length() > 6 else "-"
			elif a.begins_with("--join="):
				join_arg = a.substr(7)
			elif a.begins_with("--join-code="):
				join_arg = "code:" + a.substr(12)
		if host_arg != "" and Netz.modus == "":
			if host_arg == "internet":   # 7g: Internet-Spiel (EOS) erstellen, Code steht dann im Log und in der Spielerliste
				_internet_host()
			else:
				var fehler := Netz.host_starten(int(host_arg) if host_arg.is_valid_int() else Netz.PORT)
				if fehler != "":
					print("NETZ ", fehler)
		if join_arg != "" and Netz.modus == "" and Netz.gast_stand.is_empty() and Netz.menue_meldung == "":
			if join_arg.begins_with("code:"):
				Netz.beitreten_code(join_arg.substr(5))   # Internet (EOS)
			else:
				Netz.beitreten(join_arg)
		# Hauptmenü mit Kameraflug (nicht beim Bot, nicht nach „Neues Spiel“, nicht mit --direkt); Test 35
		var menue := ansicht == 0 and not s.durchlauf and not "--direkt" in OS.get_cmdline_user_args() and not Hauptmenue.ueberspringen
		menue = menue and host_arg == "" and (join_arg == "" or Netz.menue_meldung != "")
		Hauptmenue.ueberspringen = false
		if menue or ansicht == 35:
			hauptmenue_zeigen()
		return
	cam = Camera3D.new()
	cam.far = 40000.0
	cam.fov = 60.0
	add_child(cam)
	_grafik()
	_hud()
	_startansicht()

func hauptmenue_zeigen() -> Hauptmenue:
	var m := Hauptmenue.new()
	add_child(m)
	m.setup(spiel_knoten)
	return m

func _internet_host() -> void:
	var f: String = await Netz.host_starten_internet()
	print("NETZ Internet-Spiel: ", f if f != "" else "Code " + Netz.code)

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

# Kantenglättung, Bildqualität und Licht-Effekte (Einstellungen + Test-Schalter)
func _optionen_geaendert(k: String) -> void:
	if k in ["qualitaet", "ruhig", "fps", "vollbild"]:
		_grafik()

func _grafik() -> void:
	var vp := get_viewport()
	# Standard (Hoch): 2-faches Supersampling + MSAA 4x, kein TAA. Das Flimmern beheben die Shader selbst (gefilterte
	# Muster). TAA (Einstellung „Ruhiges Bild“ aus) glättet beim Fahren noch etwas mehr, lässt aber das Bild
	# im Stand an Pfosten und Schmutz sichtbar wackeln (gemessen mit tools/flimmern.py, Orte schmutz_25/60).
	if spiel_knoten and spiel_knoten.wirtschaft.einstellungen.get("taa", false) and not FileAccess.file_exists(Optionen.DATEI) and ansicht == 0:
		Optionen.d.ruhig = false   # alte Werkstatt-Einstellung übernehmen
		Optionen.speichern()
	var q := int(Optionen.wert("qualitaet"))
	var ruhig := bool(Optionen.wert("ruhig"))
	if schalter.has("taa"):
		ruhig = schalter.taa != 1
	vp.use_taa = not ruhig
	vp.msaa_3d = schalter.get("msaa", 2 if q >= 1 else 1) as Viewport.MSAA
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if schalter.get("smaa", 0) == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	# Supersampling: intern höher rendern (scale in Zehnteln, 20 = 2-fach); FSR2 bringt eigene Glättung mit
	var stufe: int = ([10, 13, 17] if not ruhig else [10, 15, 20])[q]
	vp.scaling_3d_scale = schalter.get("scale", stufe) / 10.0
	if schalter.get("fsr", 0) == 1:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		vp.use_taa = false
	# SSR aus (15.11.2026): spiegelt den Boden verschmiert in die Brüstungen am Turmfuß, sonst kaum sichtbar
	welt.env.ssr_enabled = schalter.get("ssr", 0) == 1
	welt.env.ssil_enabled = schalter.get("ssil", 0) == 1
	welt.env.ssao_enabled = q >= 1
	RenderingServer.directional_shadow_atlas_set_size(2048 if q == 0 else 4096, true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][q])
	# Bildrate + Vollbild
	var fps := int(Optionen.wert("fps"))
	Engine.max_fps = maxi(fps, 0)
	var vs := DisplayServer.VSYNC_ENABLED if fps == 0 else DisplayServer.VSYNC_DISABLED
	if DisplayServer.window_get_vsync_mode() != vs:
		DisplayServer.window_set_vsync_mode(vs)
	var modus := DisplayServer.WINDOW_MODE_FULLSCREEN if Optionen.wert("vollbild") else DisplayServer.WINDOW_MODE_WINDOWED
	var jetzt := DisplayServer.window_get_mode()
	if ansicht == 0 and (modus == DisplayServer.WINDOW_MODE_FULLSCREEN) != (jetzt == DisplayServer.WINDOW_MODE_FULLSCREEN or jetzt == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN):
		DisplayServer.window_set_mode(modus)
	# Test-Schalter (Flimmer-Suche): Umgebungsverdeckung, Sonnenschatten, Glühen abschaltbar
	if schalter.has("ssao"):
		welt.env.ssao_enabled = schalter.ssao == 1
	if schalter.has("schatten"):
		welt.sonne.shadow_enabled = schalter.schatten == 1
	if schalter.has("glow"):
		welt.env.glow_enabled = schalter.glow == 1
	# Grafik-Test (19.11.2026, Vorschläge für den User): --agx=1 --volnebel=1 --spiegel=1 (--ssil=1 gibt es schon)
	if schalter.get("agx", 0) == 1:
		welt.env.tonemap_mode = Environment.TONE_MAPPER_AGX
		welt.belichtung_faktor = 1.55
	if schalter.get("volnebel", 0) == 1 and not welt.env.volumetric_fog_enabled:
		var e := welt.env
		e.volumetric_fog_enabled = true
		e.volumetric_fog_density = 0.0009
		e.volumetric_fog_albedo = Color(1.0, 0.93, 0.82)
		e.volumetric_fog_anisotropy = 0.75
		e.volumetric_fog_length = 600.0
		e.volumetric_fog_detail_spread = 2.5
		e.volumetric_fog_ambient_inject = 0.15
		e.volumetric_fog_sky_affect = 0.0
		welt.sonne.light_volumetric_fog_energy = 1.4
	# Spiegelglas (19.11.2026, Wunsch des Users): ab Qualität „Mittel“ spiegelt sich die Stadt im sauberen Turmglas
	welt.spiegel_an(schalter.get("spiegel", 1 if q >= 1 else 0) == 1, turm, turm.spitze)

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
