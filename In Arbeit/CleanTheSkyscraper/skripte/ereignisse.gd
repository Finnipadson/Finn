class_name Ereignisse
extends Node3D
# Leben am Turm: Tauben bekleckern saubere Fenster, Windböen schaukeln die Gondel, ab und zu ein Sandsturm.
# Alles bleibt entspannt: Es kostet nie Geld, nur ein paar Fenster werden wieder dreckig.

const TAUBE_ABSTAND := Vector2(45.0, 100.0)    # Sekunden zwischen zwei Tauben
const WIND_RUHE := Vector2(80.0, 170.0)         # Sekunden ohne Wind
const WIND_BOE := Vector2(12.0, 20.0)           # Dauer einer Böe
const STURM_ERSTER := 480.0                     # erster Sandsturm nach 8 Minuten
const STURM_ABSTAND := Vector2(720.0, 1200.0)   # danach alle 12–20 Minuten
const STURM_WARNUNG := 15.0
const STURM_DAUER := 28.0
const STURM_ANTEIL := 0.25                      # so viele saubere Fenster in der Nähe werden eingestaubt

var spieler: Spieler
var zustand: FensterZustand
var turm: Turm
var welt: Welt
var hud: Hud
var rng := RandomNumberGenerator.new()

var taube_zeit := 0.0
var tauben: Array = []          # {knoten, fluegel, phase, t, start, ziel, f, spalte}
var wind := 0.0                 # aktuelle Windstärke 0..1 (geglättet)
var wind_ziel := 0.0
var wind_zeit := 0.0
var sturm_zeit := STURM_ERSTER
var sturm_phase := 0            # 0 ruhig, 1 Warnung, 2 Sturm
var sturm_staerke := 0.0
var sand: CPUParticles3D

func setup(s: Spieler, z: FensterZustand, t: Turm, w: Welt, h: Hud) -> void:
	spieler = s
	zustand = z
	turm = t
	welt = w
	hud = h
	rng.randomize()
	taube_zeit = rng.randf_range(TAUBE_ABSTAND.x, TAUBE_ABSTAND.y) * 0.5
	wind_zeit = rng.randf_range(WIND_RUHE.x, WIND_RUHE.y)
	_sand_bauen()

# ---------------------------------------------------------------- Takt
func takt(dt: float) -> void:
	_tauben(dt)
	_wind(dt)
	_sturm(dt)

# ---------------------------------------------------------------- Tauben
func taube_jetzt() -> bool:
	# sucht ein sauberes Fenster nahe der Gondel und schickt eine Taube hin
	var kandidaten := []
	for df in [-1, 0, 1]:
		var f: int = spieler.stock + df
		if f < 0 or f >= Turm.STOCKWERKE or not turm.gleicher_grundriss(f, spieler.stock):
			continue
		var mitte := int(spieler.weg / Turm.FENSTER_B)
		for ds in range(-6, 7):
			var sp := mitte + ds
			if sp >= 0 and sp < turm.fenster_pro_stock[f] and zustand.ist_sauber(f, sp):
				kandidaten.append(Vector2i(sp, f))
	if kandidaten.is_empty():
		return false
	var k: Vector2i = kandidaten[rng.randi() % kandidaten.size()]
	var fy := k.y * Turm.STOCK_H + Turm.STOCK_H * Turm.BAND_ANTEIL
	var p := turm.fassaden_punkt(k.y, (k.x + 0.5) * Turm.FENSTER_B, fy)
	var ziel: Vector3 = p.pos + p.normal * 0.22
	var start: Vector3 = ziel + p.normal * 18.0 + Vector3.UP * 9.0 + p.tangente * rng.randf_range(-15.0, 15.0)
	var t := _taube_bauen()
	t.position = start
	tauben.append({"knoten": t, "phase": 0, "t": 0.0, "start": start, "ziel": ziel, "f": k.y, "spalte": k.x, "normal": p.normal})
	return true

func _tauben(dt: float) -> void:
	taube_zeit -= dt
	if taube_zeit <= 0.0:
		taube_zeit = rng.randf_range(TAUBE_ABSTAND.x, TAUBE_ABSTAND.y)
		taube_jetzt()
	for tb in tauben.duplicate():
		var n: Node3D = tb.knoten
		tb.t += dt
		var fl: Array = n.get_meta("fluegel")
		match tb.phase:
			0:  # anfliegen
				var k: float = minf(1.0, tb.t / 3.5)
				var e := k * k * (3.0 - 2.0 * k)
				n.position = tb.start.lerp(tb.ziel, e) + Vector3.UP * sin(e * PI) * 2.0
				_schau(n, tb.ziel + (tb.ziel - tb.start) * 0.1)
				_flattern(fl, tb.t * 18.0, 0.7)
				if k >= 1.0:
					tb.phase = 1
					tb.t = 0.0
					_schau(n, n.position + Vector3(tb.normal.x, 0, tb.normal.z))
			1:  # sitzen, dann kleckern
				_flattern(fl, 0.0, 0.05)
				n.rotation.x = sin(tb.t * 6.0) * 0.08
				if tb.t > 1.2 and not tb.has("geklecks"):
					tb.geklecks = true
					if zustand.verschmutzen(tb.f, tb.spalte, 0.4):
						hud.meldung("Eine Taube hat ein Fenster bekleckert!", 2.5)
				if tb.t > 4.0:
					tb.phase = 2
					tb.t = 0.0
					tb.start = n.position
					tb.ziel = n.position + Vector3(tb.normal.x, 0, tb.normal.z) * 20.0 + Vector3.UP * 14.0
			2:  # wegfliegen
				var k2: float = minf(1.0, tb.t / 3.0)
				n.position = tb.start.lerp(tb.ziel, k2 * k2)
				_schau(n, tb.ziel)
				_flattern(fl, tb.t * 20.0, 0.8)
				if k2 >= 1.0:
					n.queue_free()
					tauben.erase(tb)

func _schau(n: Node3D, ziel: Vector3) -> void:
	if n.position.distance_to(ziel) > 0.01:
		n.look_at(ziel, Vector3.UP)

func _flattern(fl: Array, phase: float, staerke: float) -> void:
	for i in fl.size():
		var piv: Node3D = fl[i]
		piv.rotation.z = (1.0 if i == 0 else -1.0) * (0.2 + sin(phase) * staerke)

func _taube_bauen() -> Node3D:
	var t := Node3D.new()
	add_child(t)
	var grau := Bau.matt("8a8f98", 0.8)
	var hell := Bau.matt("c9cdd3", 0.8)
	var koerper := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	koerper.mesh = sm
	koerper.material_override = hell
	koerper.scale = Vector3(1.0, 0.9, 1.6)
	t.add_child(koerper)
	var kopf := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.065
	km.height = 0.13
	kopf.mesh = km
	kopf.material_override = grau
	kopf.position = Vector3(0, 0.1, -0.17)
	t.add_child(kopf)
	var schnabel := Bau.zylinder(0.0, 0.015, 0.05, Bau.matt("e0a030"), 6)
	schnabel.rotation.x = -PI / 2.0
	schnabel.position = Vector3(0, 0.09, -0.24)
	t.add_child(schnabel)
	var fl := []
	for seite in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.position = Vector3(0.05 * seite, 0.04, 0.0)
		t.add_child(piv)
		var fluegel := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.26, 0.02, 0.16)
		fluegel.mesh = bm
		fluegel.material_override = grau
		fluegel.position = Vector3(0.13 * seite, 0, 0)
		piv.add_child(fluegel)
		fl.append(piv)
	t.set_meta("fluegel", fl)
	return t

# ---------------------------------------------------------------- Wind
func boe_jetzt(staerke := -1.0) -> void:
	var hoehe := clampf(spieler.y / 500.0, 0.0, 1.0)
	wind_ziel = staerke if staerke >= 0.0 else rng.randf_range(0.35, 0.7) + 0.3 * hoehe
	wind_zeit = rng.randf_range(WIND_BOE.x, WIND_BOE.y)
	hud.meldung("Windböe! Die Gondel schaukelt.", 2.0)

func _wind(dt: float) -> void:
	wind_zeit -= dt
	if wind_zeit <= 0.0:
		if wind_ziel > 0.0:
			wind_ziel = 0.0
			wind_zeit = rng.randf_range(WIND_RUHE.x, WIND_RUHE.y)
		else:
			boe_jetzt()
	wind = move_toward(wind, wind_ziel, dt * 0.25)
	spieler.wind = wind

# ---------------------------------------------------------------- Sandsturm
func sturm_jetzt() -> void:
	sturm_phase = 1
	sturm_zeit = STURM_WARNUNG
	hud.meldung("Ein Sandsturm zieht auf! Keine Sorge – danach sind nur ein paar Fenster staubig.", 4.0)

func _sturm(dt: float) -> void:
	sturm_zeit -= dt
	match sturm_phase:
		0:
			if sturm_zeit <= 0.0:
				sturm_jetzt()
		1:
			if sturm_zeit <= 0.0:
				sturm_phase = 2
				sturm_zeit = STURM_DAUER
		2:
			if sturm_zeit <= 0.0:
				sturm_phase = 0
				sturm_zeit = rng.randf_range(STURM_ABSTAND.x, STURM_ABSTAND.y)
				var n := _einstauben()
				if n > 0:
					hud.meldung("Der Sandsturm ist vorbei. %d Fenster in deiner Nähe sind eingestaubt." % n, 4.0)
				else:
					hud.meldung("Der Sandsturm ist vorbei.", 3.0)
	var ziel := 1.0 if sturm_phase == 2 else 0.0
	sturm_staerke = move_toward(sturm_staerke, ziel, dt * 0.15)
	welt.sandsturm(sturm_staerke)
	sand.emitting = sturm_staerke > 0.15
	sand.global_position = spieler.cam.global_position
	if sturm_phase == 2:
		wind = maxf(wind, sturm_staerke * 0.8)
		spieler.wind = wind

func _einstauben() -> int:
	var n := 0
	for df in range(-4, 5):
		var f: int = spieler.stock + df
		if f < 0 or f >= Turm.STOCKWERKE:
			continue
		for sp in turm.fenster_pro_stock[f]:
			if zustand.ist_sauber(f, sp) and rng.randf() < STURM_ANTEIL:
				if zustand.verschmutzen(f, sp, 0.3):
					n += 1
	return n

func _sand_bauen() -> void:
	sand = CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.7, 0.45, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = m
	sand.mesh = qm
	sand.amount = 900
	sand.lifetime = 1.6
	sand.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sand.emission_box_extents = Vector3(14, 6, 14)
	sand.direction = Vector3(1, -0.1, 0.3)
	sand.spread = 12.0
	sand.gravity = Vector3.ZERO
	sand.initial_velocity_min = 9.0
	sand.initial_velocity_max = 16.0
	sand.local_coords = false
	sand.emitting = false
	add_child(sand)
