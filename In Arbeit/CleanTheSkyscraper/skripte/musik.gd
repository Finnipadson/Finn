class_name Musik
extends Node
# Musik aus Code (Phase 5): kleiner Sequenzer, der die Instrumente aus Synth (i_…) per Tonhöhe abspielt.
# Stile: „lounge“ (Hintergrundmusik + Radio Lounge FM), „funk“, „retro“, „klassik“ (Gondel-Radio).
# Liegen echte Musikdateien in ton/ (musik_*.ogg bzw. radio_<stil>_*.ogg), spielt er stattdessen diese der Reihe nach.

const BASIS := {"i_ep": 60, "i_pluck": 60, "i_klavier": 60, "i_chip": 72, "i_bass": 36, "i_pad": 48, "i_glocke": 72}
const SENDER := [["lounge", "Lounge FM"], ["funk", "Wüsten-Funk"], ["retro", "Retro-Welle 88"], ["klassik", "Klassik am Abend"]]

# Akkorde: [Bass (MIDI), Akkordtöne …]
const LOUNGE_A := [[38, 54, 57, 61, 64], [35, 57, 61, 62, 66], [40, 55, 59, 62, 66], [45, 55, 59, 61, 66]]   # Dmaj9 Bm9 Em9 A13
const LOUNGE_B := [[43, 54, 57, 59, 62], [42, 57, 61, 64, 52], [40, 55, 59, 62, 66], [45, 55, 62, 64, 59]]   # Gmaj9 F#m7 Em9 A7sus
const LOUNGE_SKALA := [62, 64, 66, 69, 71, 74, 76, 78, 81]
const FUNK := [[45, 55, 59, 60, 64], [38, 54, 60, 64, 57], [41, 52, 57, 60, 64], [40, 56, 62, 67, 59]]       # Am9 D9 Fmaj7 E7#9
const FUNK_SKALA := [57, 60, 62, 64, 67, 69, 72, 74, 76]
const RETRO := [[45, 57, 60, 64], [41, 57, 60, 65], [48, 55, 60, 64], [43, 55, 59, 62]]                       # Am F C G
const RETRO_SKALA := [69, 72, 74, 76, 79, 81, 84, 86, 88]
const KLASSIK := [[36, 48, 55, 60, 64], [45, 45, 52, 57, 60], [41, 41, 53, 57, 60], [43, 43, 50, 55, 59], [40, 40, 52, 55, 59], [41, 41, 48, 53, 57], [43, 43, 50, 53, 59], [36, 48, 55, 60, 64]]
const KLASSIK_SKALA := [72, 74, 76, 77, 79, 81, 83, 84]

var bus := "Musik"
var stil := ""
var an := true
var stimmen: Array = []
var _frei := 0
var _naechster := -1.0
var schritt := 0
var takt := 0
var _warte: Array = []        # [zeit, instrument, midi, db]
var rng := RandomNumberGenerator.new()
var _uhr := 0.0               # Spielzeit (folgt dt, passt auch bei --write-movie)
var _mel := 4                 # Melodie: Index in der Skala
var _datei: AudioStreamPlayer # echte Musikdateien statt Sequenzer
var _liste: Array = []
var _li := 0
var knistern: AudioStreamPlayer

func _ready() -> void:
	for i in 28:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		stimmen.append(p)
	_datei = AudioStreamPlayer.new()
	_datei.bus = bus
	_datei.finished.connect(_naechste_datei)
	add_child(_datei)
	knistern = AudioStreamPlayer.new()
	knistern.bus = bus
	knistern.volume_db = -22.0
	add_child(knistern)

func stil_setzen(s: String) -> void:
	if s == stil and an:
		return
	stil = s
	schritt = 0
	takt = 0
	_warte.clear()
	_naechster = -1.0
	for p in stimmen:
		(p as AudioStreamPlayer).stop()
	_liste = Ton.ersatz_musik(stil, bus == "Radio")
	_li = rng.randi() % maxi(1, _liste.size())
	_datei.stop()
	if not _liste.is_empty() and an:
		_naechste_datei()

func anschalten(ja: bool) -> void:
	if an == ja:
		return
	an = ja
	if not ja:
		for p in stimmen:
			(p as AudioStreamPlayer).stop()
		_datei.stop()
		knistern.stop()
		_warte.clear()
	else:
		_naechster = -1.0
		_liste = Ton.ersatz_musik(stil, bus == "Radio")
		if not _liste.is_empty():
			_naechste_datei()

func _naechste_datei() -> void:
	if not an or _liste.is_empty():
		return
	_datei.stream = _liste[_li % _liste.size()]
	_li += 1
	_datei.play()

func _bpm() -> float:
	return {"lounge": 78.0, "funk": 100.0, "retro": 118.0, "klassik": 70.0}.get(stil, 80.0)

func _swing() -> float:
	return {"lounge": 0.14, "funk": 0.08, "retro": 0.0, "klassik": 0.05}.get(stil, 0.0)

func _process(dt: float) -> void:
	_uhr += dt
	if not an or not _liste.is_empty() or not Ton.da("i_ep"):
		return
	if stil == "klassik" and not knistern.playing and Ton.da("i_knistern"):
		knistern.stream = Ton.klang("i_knistern")
		knistern.play()
	elif stil != "klassik" and knistern.playing:
		knistern.stop()
	var jetzt := _uhr
	if _naechster < 0.0 or jetzt - _naechster > 0.5:   # Start oder nach einem Hänger: neu einrasten
		_naechster = jetzt
	var n := 0
	while jetzt >= _naechster and n < 8:
		_schritt(jetzt - _naechster)
		var d := 60.0 / _bpm() / 4.0
		_naechster += d * (1.0 + _swing() if schritt % 2 == 0 else 1.0 - _swing())
		schritt += 1
		if schritt % 16 == 0:
			takt += 1
		n += 1
	var i := 0
	while i < _warte.size():
		var w: Array = _warte[i]
		if jetzt >= float(w[0]):
			_spielen(w[1], w[2], w[3], jetzt - float(w[0]))
			_warte.remove_at(i)
		else:
			i += 1

# Note spielen (verz = später, in Sekunden)
func note(instr: String, midi: int, db := 0.0, verz := 0.0, spaet := 0.0) -> void:
	if verz > 0.0:
		_warte.append([_uhr + verz, instr, midi, db])
		return
	_spielen(instr, midi, db, spaet)

func _spielen(instr: String, midi: int, db: float, spaet: float) -> void:
	if not Ton.da(instr):
		return
	var p: AudioStreamPlayer = stimmen[_frei]
	_frei = (_frei + 1) % stimmen.size()
	p.stream = Ton.klang(instr)
	p.pitch_scale = pow(2.0, (midi - int(BASIS.get(instr, 60))) / 12.0)
	p.volume_db = db + rng.randf_range(-1.5, 0.5)
	p.play(minf(spaet, 0.05))

func _zufall(p: float) -> bool:
	return rng.randf() < p

# ---------------------------------------------------------------- Muster je Stil (ein Schritt = Sechzehntel)
func _schritt(spaet: float) -> void:
	var s := schritt % 16
	match stil:
		"lounge": _lounge(s, spaet)
		"funk": _funk(s, spaet)
		"retro": _retro(s, spaet)
		"klassik": _klassik(s, spaet)

func _lounge(s: int, sp: float) -> void:
	var teil := (takt / 8) % 4
	var akk: Array = (LOUNGE_A if teil < 2 else LOUNGE_B)[takt % 4]
	var intro := takt < 4
	var pause := teil == 3 and takt % 8 >= 4       # kurzer Teil ohne Schlagzeug
	if s == 0:
		for k in range(1, akk.size()):
			note("i_pad", akk[k], -17.0, 0.0, sp)
	if not intro:
		if s == 0: note("i_bass", akk[0], -3.0, 0.0, sp)
		if s == 7 and _zufall(0.6): note("i_bass", akk[0] + 7, -7.0, 0.0, sp)
		if s == 10 and _zufall(0.45): note("i_bass", akk[0] + 12, -8.0, 0.0, sp)
		if s == 14 and _zufall(0.5): note("i_bass", akk[0] + (2 if _zufall(0.5) else -1), -8.0, 0.0, sp)
	# E-Piano: Akkord leicht gebrochen, synkopiert
	if (s == 0 and not intro and _zufall(0.6)) or (s == 2 and _zufall(0.5)) or (s == 6 and _zufall(0.6)) or (s == 11 and _zufall(0.35)):
		for k in range(1, akk.size()):
			if k == 1 or _zufall(0.85):
				note("i_ep", akk[k], -9.0 - k * 0.5, 0.012 * k)
	if not intro and not pause:
		if s == 0 or (s == 10 and _zufall(0.7)) or (s == 8 and _zufall(0.15)): note("i_kick", 60, -6.0, 0.0, sp)
		if s == 4 or s == 12: note("i_rim", 60, -15.0, 0.0, sp)
		if s % 2 == 0: note("i_hat", 60, -17.0 if s % 4 == 0 else -21.0, 0.0, sp)
		if _zufall(0.5): note("i_shaker", 60, -26.0, 0.0, sp)
		if s == 14 and _zufall(0.2): note("i_hat_offen", 60, -21.0, 0.0, sp)
	# Melodie: kleine Läufe in der Pentatonik, nicht ständig
	if s % 2 == 0 and teil % 2 == 1 and _zufall(0.28):
		_mel = clampi(_mel + rng.randi_range(-2, 2), 0, LOUNGE_SKALA.size() - 1)
		note("i_ep", LOUNGE_SKALA[_mel] + 12, -12.0, 0.0, sp)

func _funk(s: int, sp: float) -> void:
	var akk: Array = FUNK[(takt / 2) % 4]
	for b in [0, 3, 6, 8, 11, 14]:
		if s == b and (b == 0 or _zufall(0.75)):
			note("i_bass", akk[0] + (12 if b in [3, 11] else 0), -4.0 if b == 0 else -7.0, 0.0, sp)
	if s in [2, 6, 10, 14] and _zufall(0.8):
		for k in range(1, akk.size()):
			note("i_pluck", akk[k], -12.0, 0.004 * k)
	if s == 0 or s == 8 or (s == 6 and _zufall(0.4)): note("i_kick", 60, -5.0, 0.0, sp)
	if s == 4 or s == 12: note("i_klatsch", 60, -10.0, 0.0, sp)
	note("i_hat", 60, -16.0 if s % 2 == 0 else -22.0, 0.0, sp)
	if s % 4 == 2 and _zufall(0.3): note("i_hat_offen", 60, -20.0, 0.0, sp)
	if (takt / 4) % 2 == 1 and s % 2 == 0 and _zufall(0.3):
		_mel = clampi(_mel + rng.randi_range(-2, 2), 0, FUNK_SKALA.size() - 1)
		note("i_ep", FUNK_SKALA[_mel] + 12, -11.0, 0.0, sp)

func _retro(s: int, sp: float) -> void:
	var akk: Array = RETRO[takt % 4]
	if s % 4 == 0: note("i_kick", 60, -5.0, 0.0, sp)
	if s == 4 or s == 12: note("i_snare", 60, -9.0, 0.0, sp)
	if s % 4 == 2: note("i_hat", 60, -16.0, 0.0, sp)
	if s % 2 == 0: note("i_bass", akk[0] + (12 if s % 4 == 2 else 0), -6.0, 0.0, sp)
	note("i_chip", akk[1 + s % (akk.size() - 1)] + 12, -19.0, 0.0, sp)   # Arpeggio
	if s % 2 == 0 and (takt / 4) % 2 == 1 and _zufall(0.55):
		_mel = clampi(_mel + rng.randi_range(-2, 2), 0, RETRO_SKALA.size() - 1)
		note("i_chip", RETRO_SKALA[_mel], -12.0, 0.0, sp)
	if s == 0:
		for k in range(1, akk.size()):
			note("i_pad", akk[k], -20.0, 0.0, sp)

func _klassik(s: int, sp: float) -> void:
	var akk: Array = KLASSIK[takt % KLASSIK.size()]
	if s == 0: note("i_bass", akk[0], -8.0, 0.0, sp)
	if s % 2 == 0:   # gebrochener Akkord in Achteln
		var muster := [1, 2, 3, 4, 3, 2, 3, 4]
		note("i_klavier", akk[muster[(s / 2) % 8]], -9.0, 0.0, sp)
	if s % 4 == 0 and _zufall(0.45):
		_mel = clampi(_mel + rng.randi_range(-1, 1), 0, KLASSIK_SKALA.size() - 1)
		note("i_klavier", KLASSIK_SKALA[_mel], -8.0, 0.0, sp)
