class_name Angeln
extends Node
# Angeln am Steg, am Strand oder von der Yacht: Klick wirft aus (Angel in der Hand, Schnur, Pose auf dem Wasser),
# nach ein paar Sekunden beißt ein Fisch (Wirtschaft.fisch_ziehen), dann der „Spannungsbalken“: der Fisch zappelt in
# einem senkrechten Balken, mit gedrückter Maustaste steigt der grüne Fangkasten, losgelassen sinkt er. Ist der Fisch
# im Kasten, füllt sich der Fortschritt, sonst leert er sich. Voll = gefangen, leer = entwischt.
# Seltene Fische zappeln schneller und wilder und brauchen länger. Zustände: "", wurf, warten, biss, drill, fertig.

signal gefangen(id: String, laenge: float, neu: bool)

const WURF_ZEIT := 0.55
const START := 0.3              # Fortschritt am Anfang des Drills

var spiel: Spiel
var w: Wirtschaft
var zustand := ""
var halten := false             # Maustaste gedrückt (über _input bzw. Strand.maus)
var ziel := Vector3.ZERO        # Pose auf dem Wasser
var draussen := false           # weit draußen mit der Yacht: seltene öfter
var fisch_id := ""
var fisch_nr := 0
var t := 0.0
var warte := 0.0
# Spannungsbalken (0 = unten, 1 = oben)
var fp := 0.5                   # Fisch
var ft := 0.5                   # Ziel des Fischs
var f_pause := 0.0
var kp := 0.0                   # Unterkante Fangkasten
var kv := 0.0
var kasten_g := 0.22            # Größe des Kastens
var fortschritt := START
var wild := 0.0
var drill_zeit := 0.0
var test_fisch := ""            # Tests: diesen Fisch beißen lassen
# Bild
var rute: Node3D
var pose: Node3D
var schnur: MeshInstance3D
var schnur_mesh: ImmediateMesh
var _wurf_von := Vector3.ZERO
# Oberfläche
var ui: CanvasLayer
var balken: Control
var kasten_r: ColorRect
var wasser_r: ColorRect
var fisch_r: TextureRect
var fort: ProgressBar
var info: Label
var fang_karte: PanelContainer
var fang_bild: TextureRect
var _karte_zeit := 0.0

func setup(s: Spiel) -> void:
	spiel = s
	w = s.wirtschaft
	schnur_mesh = ImmediateMesh.new()
	schnur = MeshInstance3D.new()
	schnur.mesh = schnur_mesh
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.95, 0.95, 0.95, 0.85)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	schnur.material_override = sm
	schnur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	schnur.visible = false
	s.add_child(schnur)
	pose = Node3D.new()
	Andenken._kugel_mesh(pose, 0.09, Vector3(0, 0.05, 0), Bau.matt("e2483e", 0.4), 10)
	Andenken._kugel_mesh(pose, 0.085, Vector3(0, -0.02, 0), Bau.matt("f4f4f0", 0.4), 10)
	RaumBau.zyl(pose, 0.012, 0.22, Vector3(0, 0.2, 0), Bau.matt("ffc531", 0.4), 6)
	pose.visible = false
	s.add_child(pose)
	_ui()

func _ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 8
	add_child(ui)
	balken = PanelContainer.new()
	(balken as PanelContainer).add_theme_stylebox_override("panel", UiGlas.box(UiGlas.GLAS, UiGlas.RAND, 14, 12))
	balken.anchor_left = 0.5
	balken.anchor_right = 0.5
	balken.anchor_top = 0.5
	balken.anchor_bottom = 0.5
	balken.offset_left = 330
	balken.offset_right = 460
	balken.offset_top = -230
	balken.offset_bottom = 230
	balken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(balken)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balken.add_child(vb)
	info = UiGlas.text("", 13, UiGlas.TEXT, true)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(106, 34)
	vb.add_child(info)
	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hb)
	var wasser := ColorRect.new()
	wasser.color = Color("0d4f6e")
	wasser.custom_minimum_size = Vector2(64, 0)
	wasser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wasser.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wasser.clip_contents = true
	hb.add_child(wasser)
	wasser_r = wasser
	kasten_r = ColorRect.new()
	kasten_r.color = Color(0.37, 0.9, 0.55, 0.55)
	kasten_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wasser.add_child(kasten_r)
	fisch_r = TextureRect.new()
	fisch_r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fisch_r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fisch_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wasser.add_child(fisch_r)
	fort = ProgressBar.new()
	fort.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	fort.show_percentage = false
	fort.custom_minimum_size = Vector2(16, 0)
	fort.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fort.max_value = 1.0
	fort.step = 0.0
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("ffc531")
	fg.set_corner_radius_all(5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(5)
	fort.add_theme_stylebox_override("fill", fg)
	fort.add_theme_stylebox_override("background", bg)
	fort.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(fort)
	balken.visible = false
	# Fang-Karte oben in der Mitte
	fang_karte = PanelContainer.new()
	fang_karte.add_theme_stylebox_override("panel", UiGlas.box(UiGlas.GLAS, Color(UiGlas.AKZENT, 0.5), 14, 14))
	fang_karte.anchor_left = 0.5
	fang_karte.anchor_right = 0.5
	fang_karte.offset_left = -110
	fang_karte.offset_right = 110
	fang_karte.offset_top = 120
	fang_karte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fang_bild = TextureRect.new()
	fang_bild.custom_minimum_size = Vector2(190, 120)
	fang_bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fang_bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fang_bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fang_karte.add_child(fang_bild)
	fang_karte.visible = false
	ui.add_child(fang_karte)

# ---------------------------------------------------------------- Angel aus Code (auch für Symbole: "a_" + id)
# Länge entlang +y (Griff unten bei 0, Spitze bei laenge())
static func laenge(id: String) -> float:
	return {"bambus": 2.1, "carbon": 2.3, "hochsee": 2.0}.get(id, 2.1)

static func modell(id: String) -> Node3D:
	var n := Node3D.new()
	var l := laenge(id)
	var griff := Bau.matt("c49a6c", 0.9)
	var stange: Material
	var rolle := Bau.metall("c9ced4", 0.3, 0.8)
	match id:
		"carbon": stange = Bau.metall("2b2d33", 0.25, 0.4)
		"hochsee": stange = Bau.metall("1f6fb0", 0.25, 0.5)
		_: stange = Bau.matt("d7b36a", 0.6)
	var dick := 1.6 if id == "hochsee" else 1.0
	RaumBau.zyl(n, 0.022 * dick, 0.45, Vector3(0, 0.225, 0), griff, 8)
	RaumBau.zyl(n, 0.004 * dick, l - 0.45, Vector3(0, 0.45 + (l - 0.45) * 0.5, 0), stange, 6, 0.014 * dick)
	if id == "bambus":   # Knoten
		for k in 5:
			RaumBau.zyl(n, 0.013 - k * 0.0015, 0.025, Vector3(0, 0.65 + k * 0.32, 0), Bau.matt("a8844a", 0.7), 6)
	var r := RaumBau.zyl(n, 0.045 * dick, 0.05 * dick, Vector3(0, 0.38, 0.055 * dick), rolle, 12)
	r.rotation.z = PI * 0.5
	RaumBau.box(n, Vector3(0.012, 0.012, 0.05 * dick), Vector3(0, 0.38, 0.03 * dick), rolle)
	for k in 4:   # Ringe
		RaumBau.zyl(n, 0.012, 0.004, Vector3(0, 0.8 + k * (l - 0.9) / 4.0, 0.016), rolle, 8)
	return n

# ---------------------------------------------------------------- Ablauf
func aktiv() -> bool:
	return zustand != ""

# Auswerfen: Angel an eltern (Kamera oder Yacht) mit xf, Pose fliegt nach ziel
func werfen(eltern: Node3D, xf: Transform3D, z: Vector3, weit_draussen: bool) -> void:
	var a := w.angel()
	if a == "" or zustand != "":
		return
	draussen = weit_draussen
	if rute:
		rute.queue_free()
	rute = modell(a)
	rute.transform = xf
	eltern.add_child(rute)
	ziel = z
	_wurf_von = _spitze()
	zustand = "wurf"
	t = 0.0
	halten = false
	pose.visible = true
	schnur.visible = true
	warte = randf_range(4.0, 9.0) * (1.0 - clampf(w.boost_wirkung("biss"), 0.0, 0.8))

func _spitze() -> Vector3:
	if rute == null or not rute.is_inside_tree():
		return ziel
	return rute.global_transform * Vector3(0, laenge(w.angel()), 0)

# Angel einholen (abbrechen oder fertig). text = Meldung
func einholen(text := "") -> void:
	if text != "":
		spiel.hud.meldung(text, 2.5)
	zustand = ""
	halten = false
	balken.visible = false
	pose.visible = false
	schnur.visible = false
	if rute:
		rute.queue_free()
		rute = null

func selten() -> float:
	return float(Wirtschaft.angel_daten(w.angel()).get("selten", 0.0)) + w.boost_wirkung("selten") + (Wirtschaft.YACHT_SELTEN if draussen else 0.0)

func _biss() -> void:
	fisch_id = test_fisch if test_fisch != "" else Wirtschaft.fisch_ziehen(selten(), randf())
	fisch_nr = Wirtschaft.fisch_nr(fisch_id)
	zustand = "biss"
	t = 0.0
	if fisch_nr >= Wirtschaft.RIESEN_AB and not Wirtschaft.angel_daten(w.angel()).get("riesen", false):
		zustand = "fertig"
		t = 0.0
		spiel.hud.meldung("Ein riesiger Fisch hat angebissen – und die Schnur ist gerissen!\nFür die Riesen ab dem Segelfisch brauchst du die Hochsee-Angel (Fischladen).", 4.5)

func _drill_start() -> void:
	zustand = "drill"
	t = 0.0
	drill_zeit = 0.0
	var rang := float(fisch_nr) / (Wirtschaft.FISCHE.size() - 1)
	wild = 0.1 + 0.85 * pow(rang, 0.85)
	kasten_g = float(Wirtschaft.angel_daten(w.angel()).get("kasten", 0.22)) * (1.0 + w.boost_wirkung("kasten"))
	fortschritt = START
	fp = randf_range(0.3, 0.6)
	ft = fp
	f_pause = 0.4
	kp = clampf(fp - kasten_g * 0.5, 0.0, 1.0 - kasten_g)
	kv = 0.0
	balken.visible = true
	var bekannt := w.fisch_index.has(fisch_id)
	fisch_r.texture = Symbole.bilder.get(("f_" if bekannt else "fu_") + fisch_id)
	info.text = ["Klein, aber flink!", "Ein guter Fang?", "Etwas Großes!", "Riesig!"][mini(3, fisch_nr / 5)] + "\nMaustaste halten"

func _process(dt: float) -> void:
	if zustand != "":
		w.statistik.angel_zeit = float(w.statistik.angel_zeit) + dt
	if _karte_zeit > 0.0:
		_karte_zeit -= dt
		fang_karte.visible = _karte_zeit > 0.0
	if zustand == "":
		return
	t += dt
	var welle := sin(Time.get_ticks_msec() * 0.003) * 0.03
	match zustand:
		"wurf":
			var k := clampf(t / WURF_ZEIT, 0.0, 1.0)
			pose.global_position = _wurf_von.lerp(ziel, k) + Vector3(0, sin(k * PI) * 3.0, 0)
			if k >= 1.0:
				zustand = "warten"
				t = 0.0
		"warten":
			pose.global_position = ziel + Vector3(0, welle, 0)
			if t >= warte:
				_biss()
		"biss":
			pose.global_position = ziel + Vector3(0, -0.18 + sin(t * 40.0) * 0.05, 0)
			if t > 0.45:
				_drill_start()
		"drill":
			_drill(dt)
			pose.global_position = ziel + Vector3(sin(t * 7.0) * 0.4 * wild, -0.12 + welle, cos(t * 5.0) * 0.4 * wild)
		"fertig":
			pose.global_position = ziel + Vector3(0, welle, 0)
			if t > 0.8:
				einholen()
				return
	_schnur_zeichnen()

func _drill(dt: float) -> void:
	drill_zeit += dt
	# Fisch: springt in Pausen zu neuen Zielen, seltene weiter und schneller
	var z := clampf(1.0 - w.boost_wirkung("zappeln"), 0.3, 1.0)
	f_pause -= dt
	if f_pause <= 0.0:
		f_pause = lerpf(1.5, 0.35, wild) * randf_range(0.6, 1.4) / z
		ft = clampf(fp + randf_range(-1.0, 1.0) * lerpf(0.25, 0.85, wild), 0.04, 0.96)
	fp = lerpf(fp, ft, clampf(dt * lerpf(1.6, 8.0, wild) * z, 0.0, 1.0))
	fp = clampf(fp + sin(drill_zeit * 13.0) * 0.004 * wild * z, 0.0, 1.0)
	# Kasten: Maustaste hebt, loslassen sinkt, unten federt er
	kv += (2.1 if halten else -2.2) * dt
	kv = clampf(kv, -1.3, 1.3)
	kp += kv * dt
	if kp < 0.0:
		kp = 0.0
		kv = -kv * 0.25
	if kp > 1.0 - kasten_g:
		kp = 1.0 - kasten_g
		kv = 0.0
	var drin := fp >= kp and fp <= kp + kasten_g
	var fuellen := lerpf(0.34, 0.12, wild)
	var leeren := lerpf(0.14, 0.26, wild)
	fortschritt = clampf(fortschritt + (fuellen if drin else -leeren) * dt, 0.0, 1.0)
	# Anzeige
	var hoch := wasser_r.size.y
	var breit := wasser_r.size.x
	kasten_r.position = Vector2(0, (1.0 - kp - kasten_g) * hoch)
	kasten_r.size = Vector2(breit, kasten_g * hoch)
	kasten_r.color = Color(0.37, 0.9, 0.55, 0.65) if drin else Color(0.37, 0.9, 0.55, 0.35)
	var fs := 46.0
	fisch_r.size = Vector2(fs, fs)
	fisch_r.position = Vector2((breit - fs) * 0.5, (1.0 - fp) * hoch - fs * 0.5)
	fisch_r.rotation = sin(drill_zeit * (6.0 + wild * 10.0)) * 0.15
	fort.value = fortschritt
	if fortschritt >= 1.0:
		_fang()
	elif fortschritt <= 0.0:
		zustand = "fertig"
		t = 0.0
		balken.visible = false
		spiel.hud.meldung("Entwischt! Der Fisch war schneller.", 2.0)

func _fang() -> void:
	var f := Wirtschaft.fisch(fisch_id)
	var laenge := float(f.groesse) * randf_range(0.82, 1.18)
	var neu := w.fisch_gefangen(fisch_id, laenge)
	zustand = "fertig"
	t = 0.0
	balken.visible = false
	var txt := "Gefangen: %s · %s\nWert im Fischladen: %s €" % [f.name, Fische.laenge_text(laenge), Hud.punkte(w.fisch_preis(fisch_id))]
	if neu:
		txt += "\nNeu im Fisch-Index! (%d / %d) – B: Album" % [w.fisch_index.size(), Wirtschaft.FISCHE.size()]
	spiel.hud.meldung(txt, 3.5)
	fang_bild.texture = Symbole.bilder.get("f_" + fisch_id)
	fang_karte.visible = fang_bild.texture != null
	_karte_zeit = 3.5
	gefangen.emit(fisch_id, laenge, neu)

func _schnur_zeichnen() -> void:
	var a := _spitze()
	var b := pose.global_position + Vector3(0, 0.25, 0)
	schnur_mesh.clear_surfaces()
	schnur_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var straff := 0.15 if zustand == "drill" else 1.0
	for i in 17:
		var k := i / 16.0
		var p := a.lerp(b, k)
		p.y -= sin(k * PI) * a.distance_to(b) * 0.06 * straff
		schnur_mesh.surface_add_vertex(p)
	schnur_mesh.surface_end()
