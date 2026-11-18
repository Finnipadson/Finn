class_name Ton
extends Node
# Ton-Zentrale (Phase 5): Kanäle Musik / Geraeusche / Radio, Klänge (aus Synth oder echten Dateien in ton/),
# kurze Geräusche (spielen/spielen_bei), Schleifen (Wind, Stadt, Meer, Motor …) und Musik + Gondel-Radio.
# Die Umgebung wird jedes Bild aus dem Spielzustand berechnet (Höhe der Kamera, Ort, Ereignisse), Ereignisse wie
# Kaufen, Erfolge, Tauben, Angeln erkennt Ton an Zustandsänderungen – so braucht der restliche Code kaum Aufrufe.
# Ohne Grafik (headless: Tests, Bot) ist alles stumm und es wird nichts erzeugt.
#
# Echte Klänge statt der erzeugten: Datei <name>.ogg/.wav/.mp3 in den Ordner „ton/“ legen (im Projekt bzw. neben der
# .exe), z. B. ton/moewe.ogg. Musik: ton/musik_*.ogg (Hintergrund) und ton/radio_<lounge|funk|retro|klassik>_*.ogg.

static var i: Ton
static var _cache := {}              # Name → AudioStream (bleibt beim Neuladen der Szene erhalten)
static var _fertige: Array = []      # vom Thread erzeugt, noch nicht im Cache
static var _mx := Mutex.new()
static var _aufgabe := -1
static var _abbrechen := false

const BUSSE := ["Musik", "Geraeusche", "Radio"]

var aus := false                     # stumm (headless)
var spiel: Spiel
var menue := false                   # Hauptmenü: Musik voll, Kamerafahrt
var musik: Musik
var radio: Musik
var radio_an := false
var _pool: Array = []
var _pi := 0
var _pool3d: Array = []
var _p3i := 0
var _loops := {}                     # Name → {p, ziel, laut, pitch, pziel}
var _musik_laut := 0.0
var _radio_laut := 0.0
# Zustand fürs Erkennen von Ereignissen
var _geld := -1
var _erfolge := -1
var _tauben := 0
var _angel := ""
var _ort := ""
var _letzt := {}                     # Drosselung: Name → Zeit
var _uhr := 0.0
var _alt_cam := Vector3.ZERO
var _alt_off := Vector2.ZERO
var _alt_weg := 0.0
var _alt_y := 0.0
var _alt_lauf := Vector3.ZERO
var _naechste_hupe := 8.0
var _naechste_moewe := 4.0

func _ready() -> void:
	i = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless" or "--stumm" in OS.get_cmdline_user_args():
		aus = true
		return
	for b in BUSSE:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
			if b == "Radio":   # klingt wie ein kleiner Lautsprecher
				var hp := AudioEffectHighPassFilter.new()
				hp.cutoff_hz = 220.0
				AudioServer.add_bus_effect(idx, hp)
				var lp := AudioEffectLowPassFilter.new()
				lp.cutoff_hz = 6500.0
				AudioServer.add_bus_effect(idx, lp)
	for k in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "Geraeusche"
		add_child(p)
		_pool.append(p)
	for k in 8:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "Geraeusche"
		p3.unit_size = 14.0
		p3.max_distance = 500.0
		p3.attenuation_filter_cutoff_hz = 9000.0
		add_child(p3)
		_pool3d.append(p3)
	musik = Musik.new()
	musik.bus = "Musik"
	add_child(musik)
	musik.stil_setzen("lounge")
	radio = Musik.new()
	radio.bus = "Radio"
	add_child(radio)
	radio.an = false
	radio.rng.seed = 99
	get_tree().node_added.connect(_knoten_neu)
	for b in BUSSE:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(b), -80.0)
	if _aufgabe < 0 and _cache.size() < Synth.REZEPTE.size():
		_abbrechen = false
		_aufgabe = WorkerThreadPool.add_task(_erzeugen, false, "Klänge erzeugen")

static func _erzeugen() -> void:
	for n in Synth.reihenfolge():
		if _abbrechen:
			return
		if _cache.has(n):
			continue
		var st: AudioStream = ersatz_laden(n)
		if st == null:
			st = Synth.eins(n)
		_mx.lock()
		_fertige.append([n, st])
		_mx.unlock()

func _exit_tree() -> void:
	if i == self:
		i = null
	# Thread anhalten und abwarten (Beenden oder Neuladen der Szene); das neue Ton erzeugt den Rest weiter
	_abbrechen = true
	if _aufgabe >= 0:
		WorkerThreadPool.wait_for_task_completion(_aufgabe)
		_aufgabe = -1

static func da(name: String) -> bool:
	return _cache.has(name)

static func klang(name: String) -> AudioStream:
	return _cache.get(name)

# ---------------------------------------------------------------- echte Dateien (ersetzen die erzeugten)
static func ordner() -> Array:
	var l := []
	var dev := ProjectSettings.globalize_path("res://ton")
	if dev != "" and DirAccess.dir_exists_absolute(dev):
		l.append(dev)
	var exe := OS.get_executable_path().get_base_dir().path_join("ton")
	if DirAccess.dir_exists_absolute(exe) and not exe in l:
		l.append(exe)
	return l

static func _datei_laden(pfad: String, schleife: bool) -> AudioStream:
	match pfad.get_extension().to_lower():
		"ogg":
			var o := AudioStreamOggVorbis.load_from_file(pfad)
			if o:
				o.loop = schleife
			return o
		"wav":
			var w := AudioStreamWAV.load_from_file(pfad)
			if w and schleife:
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = int(w.get_length() * w.mix_rate)
			return w
		"mp3":
			var m := AudioStreamMP3.new()
			m.data = FileAccess.get_file_as_bytes(pfad)
			m.loop = schleife
			return m
	return null

static func ersatz_laden(name: String) -> AudioStream:
	if name.begins_with("i_"):
		return null   # Instrumente bleiben erzeugt (Tonhöhe muss stimmen)
	for o in ordner():
		for ext in ["ogg", "wav", "mp3"]:
			var p: String = (o as String).path_join(name + "." + ext)
			if FileAccess.file_exists(p):
				var st := _datei_laden(p, bool(Synth.REZEPTE.get(name, false)))
				if st:
					return st
	return null

static func ersatz_musik(stil: String, ist_radio: bool) -> Array:
	var l := []
	var vorn := ("radio_%s_" % stil) if ist_radio else "musik_"
	for o in ordner():
		for f in DirAccess.get_files_at(o):
			if f.begins_with(vorn) and f.get_extension().to_lower() in ["ogg", "wav", "mp3"]:
				var st := _datei_laden((o as String).path_join(f), false)
				if st:
					l.append(st)
	return l

# ---------------------------------------------------------------- kurze Geräusche
static func spielen(name: String, db := 0.0, tonhoehe := 1.0) -> void:
	if i == null or i.aus or not _cache.has(name):
		return
	var p: AudioStreamPlayer = i._pool[i._pi]
	i._pi = (i._pi + 1) % i._pool.size()
	p.stream = _cache[name]
	p.volume_db = db
	p.pitch_scale = tonhoehe
	p.play()

static func spielen_bei(name: String, pos: Vector3, db := 0.0, tonhoehe := 1.0) -> void:
	if i == null or i.aus or not _cache.has(name):
		return
	var p: AudioStreamPlayer3D = i._pool3d[i._p3i]
	i._p3i = (i._p3i + 1) % i._pool3d.size()
	p.stream = _cache[name]
	p.volume_db = db
	p.pitch_scale = tonhoehe
	p.global_position = pos
	p.play()

# höchstens alle „abstand“ Sekunden
static func gedrosselt(name: String, abstand: float, db := 0.0, tonhoehe := 1.0) -> void:
	if i == null or i.aus:
		return
	if i._uhr - float(i._letzt.get(name, -99.0)) < abstand:
		return
	i._letzt[name] = i._uhr
	spielen(name, db, tonhoehe)

static func klick() -> void:
	gedrosselt("klick", 0.04, -8.0, randf_range(0.95, 1.05))

# Ein Knopf irgendwo im Spiel → Klick-Geräusch
func _knoten_neu(n: Node) -> void:
	if n is BaseButton and not n.has_meta("ton"):
		n.set_meta("ton", true)
		(n as BaseButton).pressed.connect(func(): Ton.klick())

# Schleife für dieses Bild anfordern (laut 0..1). Nicht angeforderte Schleifen blenden aus.
func schleife(name: String, laut: float, tonhoehe := 1.0) -> void:
	if aus:
		return
	if not _loops.has(name):
		if not _cache.has(name):
			return
		var p := AudioStreamPlayer.new()
		p.bus = "Geraeusche"
		p.stream = _cache[name]
		add_child(p)
		_loops[name] = {"p": p, "ziel": 0.0, "laut": 0.0, "pitch": tonhoehe, "pziel": tonhoehe}
	var l: Dictionary = _loops[name]
	l.ziel = maxf(float(l.ziel), clampf(laut, 0.0, 1.0))
	l.pziel = tonhoehe

func _schleifen(dt: float) -> void:
	for name in _loops:
		var l: Dictionary = _loops[name]
		var p: AudioStreamPlayer = l.p
		l.laut = move_toward(float(l.laut), float(l.ziel), dt * 2.2)
		l.pitch = lerpf(float(l.pitch), float(l.pziel), minf(1.0, dt * 4.0))
		if float(l.laut) < 0.003:
			if p.playing:
				p.stop()
		else:
			if not p.playing:
				p.play(randf() * p.stream.get_length() * 0.9)
			p.volume_db = linear_to_db(float(l.laut))
			p.pitch_scale = clampf(float(l.pitch), 0.3, 3.0)
		l.ziel = 0.0

# ---------------------------------------------------------------- Ablauf
func _process(dt: float) -> void:
	if aus:
		return
	_uhr += dt
	_mx.lock()
	for f in _fertige:
		_cache[f[0]] = f[1]
	_fertige.clear()
	_mx.unlock()
	var cam := get_viewport().get_camera_3d()
	var h := cam.global_position.y if cam else 0.0
	var drinnen := false
	if spiel and not menue:
		drinnen = _welt(dt, cam)
	elif cam:
		_umgebung(cam.global_position, false, 0.0, 0.0)
	_schleifen(dt)
	# Kanäle: Musik leiser, je höher man ist (und aus, solange das Radio spielt)
	var radio_spielt := radio.an
	var mz := float(Optionen.wert("musik"))
	if not menue:
		mz *= lerpf(1.0, 0.3, clampf(h / 900.0, 0.0, 1.0)) * (0.6 if drinnen else 1.0)
		if radio_spielt:
			mz = 0.0
	_musik_laut = move_toward(_musik_laut, mz, dt * 0.5)
	_radio_laut = move_toward(_radio_laut, float(Optionen.wert("radio")) if radio_spielt else 0.0, dt * 1.5)
	_bus("Musik", _musik_laut)
	_bus("Radio", _radio_laut)
	_bus("Geraeusche", float(Optionen.wert("geraeusche")))
	musik.anschalten(_musik_laut > 0.001 or mz > 0.001)

func _bus(name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(name)
	AudioServer.set_bus_mute(idx, v < 0.002)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))

# Wind, Stadt, Brunnen, Meer, Möwen, Hupen – nur nach Ort und Höhe
func _umgebung(p: Vector3, drinnen: bool, wind: float, sturm: float) -> void:
	var h := p.y
	var innen := 0.15 if drinnen else 1.0
	schleife("wind", (clampf(0.06 + h / 520.0, 0.0, 0.85) + wind * 0.4) * innen, 0.9 + minf(h / 2500.0, 0.3))
	var kueste := p.x - Kueste.UFER_X
	var stadt := clampf(1.0 - h / 320.0, 0.0, 1.0) * 0.5 * (0.2 if drinnen else 1.0) * clampf(kueste / 150.0, 0.25, 1.0)
	schleife("stadt", stadt)
	if spiel:
		var d := spiel.welt.see_abstand(Vector2(p.x, p.z))
		var b := clampf(1.0 - d / 70.0, 0.0, 1.0) * clampf(1.0 - h / 120.0, 0.0, 1.0) * 0.5
		if absf(p.z - Kueste.BOUL_Z) < 12.0 and p.x < Kueste.BOUL_X0 and p.x > Kueste.UFER_X and h < 20.0:
			b = maxf(b, 0.22)   # Kanal mit Fontänen am Boulevard
		schleife("brunnen", b * innen)
	var meer := clampf(1.0 - kueste / 320.0, 0.0, 1.0) * 0.7 * clampf(1.0 - h / 450.0, 0.15, 1.0) * (0.3 if drinnen else 1.0)
	schleife("meer", meer)
	schleife("sandsturm", sturm * (0.2 if drinnen else 0.9))
	if _uhr > _naechste_hupe:
		_naechste_hupe = _uhr + randf_range(6.0, 18.0)
		if stadt > 0.25:
			var a := randf() * TAU
			spielen_bei("hupe", Vector3(p.x + cos(a) * randf_range(50.0, 160.0), 1.0, p.z + sin(a) * randf_range(50.0, 160.0)), -8.0, randf_range(0.85, 1.15))
	if _uhr > _naechste_moewe:
		_naechste_moewe = _uhr + randf_range(5.0, 14.0)
		if meer > 0.2 and not drinnen:
			var a2 := randf() * TAU
			spielen_bei("moewe", p + Vector3(cos(a2) * randf_range(15.0, 50.0), randf_range(8.0, 25.0), sin(a2) * randf_range(15.0, 50.0)), -4.0, randf_range(0.9, 1.15))

# Ganze Klangwelt im Spiel. Gibt zurück, ob man drinnen ist (Musik etwas leiser).
func _welt(dt: float, cam: Camera3D) -> bool:
	var s := spiel
	if cam == null or s.spieler == null or s.laeufer == null:
		return false
	var p := cam.global_position
	var lp := Vector2(s.laeufer.position.x, s.laeufer.position.z)
	var im_casino := s.laeufer.aktiv and s.extras.ort == "" and s.welt.casino_rect.has_point(lp) and p.y < 12.0
	var drinnen := s.extras.drinnen() or (s.laeufer.aktiv and not s.laeufer.raum.is_empty()) or im_casino
	_umgebung(p, drinnen, s.ereignisse.wind if s.spieler.aktiv else 0.0, s.ereignisse.sturm_staerke)
	if im_casino or s.cmenu.offen:
		schleife("casino", 0.5)
	if s.extras.ort == "arcade":
		schleife("arcade", 0.45)
	var sp := s.spieler
	var tdt := maxf(dt, 0.001)
	if sp.aktiv:
		# Motor: je schneller, desto lauter und höher
		var v := (absf(sp.y - _alt_y) + absf(sp.weg - _alt_weg) * 0.6) / tdt
		if absf(sp.weg - _alt_weg) > 50.0:
			v = 0.0   # Sprung über den Umfang
		var k := clampf(v / 3.0, 0.0, 1.0)
		schleife("motor", 0.08 + 0.42 * k if v > 0.05 else 0.04, 0.75 + 0.55 * k)
		# Putzen je Werkzeug
		if sp.wischt:
			if sp.wz_art == "spray":
				if sp.spray_trifft:
					schleife("spruehen", 0.5, 0.9 if sp.wz_id == "hochdruck" else (1.1 if sp.wz_id == "lanze" else 1.0))
			else:
				var w := clampf(sp.schwamm_off.distance_to(_alt_off) / tdt / 1.4, 0.0, 1.0)
				var gummi := str(sp.wz.get("modell", "schwamm")) == "abzieher"
				schleife("wisch_gummi" if gummi else "wisch_nass", 0.65 * w, 0.9 + 0.25 * w)
	_alt_y = sp.y
	_alt_weg = sp.weg
	_alt_off = sp.schwamm_off
	# Fahrzeuge
	var la := s.laeufer
	if la.aktiv and la.fahrzeug != "":
		var lv := clampf(la.position.distance_to(_alt_lauf) / tdt / maxf(la.fz_tempo, 1.0), 0.0, 1.2)
		match la.fahrzeug:
			"scooter": schleife("scooter", 0.06 + 0.4 * lv, 0.6 + 0.6 * lv)
			"hoverboard": schleife("hover", 0.15 + 0.3 * lv, 0.85 + 0.3 * lv)
			"jetpack":
				var fliegt := la.hoch > 0.2
				schleife("jetpack", (0.55 if Optionen.gedrueckt(KEY_SPACE) else 0.3) if fliegt else 0.05, 1.0 + 0.2 * lv)
	_alt_lauf = la.position
	var y := s.strand.yacht
	if y and y.an_bord:
		var yv := clampf(absf(y.tempo) / 12.0, 0.0, 1.0)
		schleife("yacht", 0.22 + 0.45 * yv, 0.8 + 0.4 * yv)
	var an := s.strand.angeln
	if an.zustand == "drill" and an.halten:
		schleife("rolle", 0.55, 1.0 + 0.3 * float(an.wild))
	_ereignisse(s)
	_radio(s)
	return drinnen

# Zustandsänderungen → kurze Geräusche
func _ereignisse(s: Spiel) -> void:
	var w := s.wirtschaft
	if _geld >= 0 and w.geld < _geld and not s.cmenu.offen:
		gedrosselt("kaufen", 0.25, -3.0)
	_geld = w.geld
	var e := w.erfolge.size()
	if _erfolge >= 0 and e > _erfolge:
		spielen("erfolg", -2.0)
	_erfolge = e
	var t := s.ereignisse.tauben.size()
	if t > _tauben:
		var tb: Dictionary = s.ereignisse.tauben[t - 1]
		var pos: Vector3 = (tb.knoten as Node3D).global_position if tb.has("knoten") else Vector3.ZERO
		spielen_bei("fluegel", pos, 0.0)
		spielen_bei("gurren", pos, 2.0, randf_range(0.92, 1.08))
	_tauben = t
	var az := s.strand.angeln.zustand
	if az != _angel:
		match az:
			"wurf": spielen("wurf", -3.0)
			"warten": spielen("platsch", -6.0, 1.15)
			"biss": spielen("biss", -2.0)
			"fertig":
				if _angel == "drill":
					spielen("platsch", -2.0, 0.85)
	_angel = az
	if s.extras.ort != _ort:
		spielen("ding", -6.0)
	_ort = s.extras.ort

# ---------------------------------------------------------------- Gondel-Radio
func radio_besitz() -> bool:
	return spiel != null and str(spiel.wirtschaft.kosmetik_aktiv.get("radio", "gradio_keins")) != "gradio_keins"

func _radio(s: Spiel) -> void:
	var soll := radio_besitz() and bool(s.wirtschaft.radio.get("an", false)) and s.spieler.aktiv and not menue
	if soll:
		var st: String = Musik.SENDER[int(s.wirtschaft.radio.get("sender", 0)) % Musik.SENDER.size()][0]
		if radio.stil != st or not radio.an:
			radio.an = true
			radio.stil = ""
			radio.stil_setzen(st)
	elif radio.an:
		radio.anschalten(false)

# Taste R (an/aus) bzw. T (nächster Sender). Gibt den Text für die Meldung zurück.
func radio_taste(naechster: bool) -> String:
	if spiel == null:
		return ""
	if not radio_besitz():
		return "Kein Radio in der Gondel – das gibt es in der Gondel-Werkstatt (Reiter Radio)."
	var r: Dictionary = spiel.wirtschaft.radio
	if naechster:
		r.sender = (int(r.get("sender", 0)) + 1) % Musik.SENDER.size()
		r.an = true
	else:
		r.an = not bool(r.get("an", false))
	spielen("tick", -4.0)
	if not r.an:
		return "Radio aus"
	return "Radio: %s  (T = nächster Sender)" % Musik.SENDER[int(r.sender)][1]
