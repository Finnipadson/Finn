class_name Synth
# Alle Geräusche und Instrumente aus Code (Phase 5): kleine Klang-Rezepte → AudioStreamWAV (22.050 Hz, mono, 16 Bit).
# Ton.gd ruft erzeugen() einmal beim Start in einem Hintergrund-Thread auf. Echte Dateien im Ordner „ton/“
# ersetzen einzelne Klänge (siehe Ton.ersatz_laden). Schleifen sind nahtlos (Anfang und Ende überblendet).

const R := 22050.0
static var rng := RandomNumberGenerator.new()

# Name → Schleife? (Funktion _name erzeugt den Klang)
const REZEPTE := {
	# Putzen + Geld + Menü
	"wisch_nass": true, "wisch_gummi": true, "spruehen": true,
	"quietschen": false, "glanz": false, "geld": false, "kaufen": false, "klick": false, "erfolg": false, "ding": false,
	# Gondel, Wetter, Stadt
	"motor": true, "wind": true, "sandsturm": true, "stadt": true, "hupe": false, "brunnen": true, "meer": true, "moewe": false,
	"gurren": false, "fluegel": false,
	# Casino + Arcade
	"casino": true, "automat": false, "karte": false, "jackpot": false, "tick": false, "chips": false,
	"arcade": true, "piep": false, "arcade_gewinn": false,
	# Angeln + Fahrzeuge
	"wurf": false, "platsch": false, "biss": false, "rolle": true, "yacht": true, "scooter": true, "hover": true, "jetpack": true,
	# Feier
	"knall": false,
	# Instrumente (Musik + Radio): Grundton steht in Musik.GRUNDTON
	"i_ep": false, "i_bass": false, "i_pad": false, "i_kick": false, "i_snare": false, "i_rim": false, "i_hat": false,
	"i_hat_offen": false, "i_shaker": false, "i_klatsch": false, "i_chip": false, "i_pluck": false, "i_klavier": false,
	"i_knistern": true, "i_glocke": false,
}

# Reihenfolge beim Erzeugen: Instrumente und Menü-Klänge zuerst (Musik im Hauptmenü startet früh)
static func reihenfolge() -> Array:
	var l: Array = REZEPTE.keys().filter(func(n): return n.begins_with("i_"))
	l.append_array(["klick", "geld", "glanz", "quietschen", "wisch_nass", "wind", "stadt"])
	for n in REZEPTE:
		if not n in l:
			l.append(n)
	return l

static func eins(name: String) -> AudioStreamWAV:
	var s: PackedFloat32Array = Synth.new().call("_" + name)
	return wav(s, REZEPTE[name])

# ---------------------------------------------------------------- Werkzeuge
static func leer(sek: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(sek * R))
	s.fill(0.0)
	return s

static func rauschen(sek: float, staerke := 1.0) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var n := int(sek * R)
	s.resize(n)
	for i in n:
		s[i] = rng.randf_range(-staerke, staerke)
	return s

# Braunes Rauschen (tiefes Grollen)
static func braun(sek: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var n := int(sek * R)
	s.resize(n)
	var y := 0.0
	for i in n:
		y = (y + rng.randf_range(-1.0, 1.0) * 0.05) * 0.996
		s[i] = y
	return normal(s, 0.9)

static func tiefpass(s: PackedFloat32Array, fc: float, stufen := 1) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * fc / R)
	for k in stufen:
		var y := 0.0
		for i in s.size():
			y += a * (s[i] - y)
			s[i] = y
	return s

static func hochpass(s: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * fc / R)
	var y := 0.0
	for i in s.size():
		y += a * (s[i] - y)
		s[i] = s[i] - y
	return s

# Bandpass (State-Variable-Filter). q klein = breit, groß = schmal/resonant. fc_fn(t) optional für Filterfahrten.
static func bandpass(s: PackedFloat32Array, fc: float, q := 1.0, fc_fn := Callable()) -> PackedFloat32Array:
	var tief := 0.0
	var band := 0.0
	var d := 1.0 / maxf(q, 0.3)
	var f := 2.0 * sin(PI * fc / R)
	for i in s.size():
		if fc_fn.is_valid() and i % 32 == 0:
			f = 2.0 * sin(PI * minf(float(fc_fn.call(i / R)), 7000.0) / R)
		tief += f * band
		var hoch := s[i] - tief - d * band
		band += f * hoch
		s[i] = band
	return s

static func normal(s: PackedFloat32Array, spitze := 0.9) -> PackedFloat32Array:
	var m := 0.0001
	for v in s:
		m = maxf(m, absf(v))
	var g := spitze / m
	for i in s.size():
		s[i] *= g
	return s

static func mischen(ziel: PackedFloat32Array, quelle: PackedFloat32Array, ab: float, gain := 1.0) -> PackedFloat32Array:
	var o := int(ab * R)
	for i in quelle.size():
		if o + i >= ziel.size():
			break
		if o + i >= 0:
			ziel[o + i] += quelle[i] * gain
	return ziel

# Hüllkurve: Anschlag (s) + exponentielles Abklingen (s)
static func huelle(s: PackedFloat32Array, an: float, ab: float) -> PackedFloat32Array:
	for i in s.size():
		var t := i / R
		s[i] *= (t / an if t < an else exp(-(t - an) / ab))
	return s

# Nahtlose Schleife: die letzten „blende“ Sekunden werden über den Anfang geblendet, danach abgeschnitten
static func schleife(s: PackedFloat32Array, blende: float) -> PackedFloat32Array:
	var b := int(blende * R)
	var n := s.size() - b
	for i in b:
		var k := float(i) / b
		s[i] = s[i] * k + s[n + i] * (1.0 - k)
	s.resize(n)
	return s

static func wav(s: PackedFloat32Array, schleife_an: bool) -> AudioStreamWAV:
	var b := PackedByteArray()
	b.resize(s.size() * 2)
	for i in s.size():
		b.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(R)
	w.stereo = false
	w.data = b
	if schleife_an:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w

# Glocke/Metall: Teiltöne [Verhältnis, Stärke, Abklingen-Anteil]
static func glocke(ziel: PackedFloat32Array, ab: float, f: float, dauer: float, gain := 1.0, teile := [[1.0, 1.0, 1.0], [2.76, 0.45, 0.45], [5.4, 0.22, 0.25], [8.93, 0.1, 0.12]]) -> PackedFloat32Array:
	var o := int(ab * R)
	var n := mini(int(dauer * 3.0 * R), ziel.size() - o)
	for i in n:
		var t := i / R
		var v := 0.0
		for p in teile:
			var ff: float = f * float(p[0])
			if ff < 10000.0:
				v += sin(TAU * ff * t) * float(p[1]) * exp(-t / (dauer * float(p[2])))
		ziel[o + i] += v * gain * minf(1.0, t * 400.0)
	return ziel

# Gleitender Sinus/Obertöne: f_fn(t) → Frequenz, a_fn(t) → Lautstärke
static func ton(sek: float, f_fn: Callable, a_fn: Callable, obertoene := [1.0]) -> PackedFloat32Array:
	var s := leer(sek)
	var ph := 0.0
	for i in s.size():
		var t := i / R
		ph += float(f_fn.call(t)) / R
		var v := 0.0
		for k in obertoene.size():
			v += sin(TAU * ph * (k + 1)) * float(obertoene[k])
		s[i] = v * float(a_fn.call(t))
	return s

# ---------------------------------------------------------------- Putzen
static func _wisch_nass() -> PackedFloat32Array:
	var s := tiefpass(rauschen(2.2), 1400.0, 2)
	var b := bandpass(rauschen(2.2), 650.0, 2.5)
	for i in s.size():
		var t := i / R
		var zug := 0.55 + 0.45 * sin(TAU * 2.5 * t) ** 2    # Reib-Züge
		s[i] = (s[i] * 1.6 + b[i] * 0.9) * zug
	return normal(schleife(s, 0.2), 0.7)

static func _wisch_gummi() -> PackedFloat32Array:
	var s := bandpass(rauschen(2.2), 2600.0, 2.0)
	var ph := 0.0
	for i in s.size():
		var t := i / R
		var zug := 0.5 + 0.5 * sin(TAU * 2.0 * t) ** 2
		ph += (1350.0 + sin(TAU * 7.0 * t) * 60.0) / R
		var quietsch := sin(TAU * ph) * 0.18 * maxf(0.0, sin(TAU * 1.0 * t + 0.4)) ** 6   # ab und zu leises Quietschen
		s[i] = (s[i] * 0.9) * zug + quietsch
	return normal(schleife(s, 0.2), 0.6)

static func _spruehen() -> PackedFloat32Array:
	var s := tiefpass(hochpass(rauschen(2.4), 1800.0), 8000.0)
	for i in s.size():
		var t := i / R
		s[i] *= 0.85 + 0.15 * sin(TAU * 11.0 * t) * sin(TAU * 0.5 * t)
	return normal(schleife(s, 0.3), 0.6)

static func _quietschen() -> PackedFloat32Array:
	# Gummi auf sauberem Glas: zwei kurze hohe Quietscher
	var s := leer(0.42)
	for k in 2:
		var ab := 0.03 + k * 0.17
		var q := ton(0.14, func(t): return 1900.0 + 700.0 * sin(PI * t / 0.14) + sin(TAU * 38.0 * t) * 120.0,
			func(t): return sin(PI * t / 0.14) ** 0.6 * (1.0 - 0.3 * k), [1.0, 0.35, 0.12])
		s = mischen(s, q, ab, 0.7)
	return normal(s, 0.55)

static func _glanz() -> PackedFloat32Array:
	# helles „Pling“ mit Funkeln, wenn ein Fenster fertig ist
	var s := leer(1.2)
	s = glocke(s, 0.0, 1975.5, 0.35, 0.8)
	s = glocke(s, 0.07, 2637.0, 0.3, 0.55)
	s = glocke(s, 0.13, 3951.0, 0.18, 0.3)
	return normal(s, 0.6)

static func _geld() -> PackedFloat32Array:
	var s := leer(0.6)
	var teile := [[1.0, 1.0, 1.0], [2.4, 0.5, 0.5], [4.1, 0.25, 0.3]]
	s = glocke(s, 0.0, 2637.0, 0.12, 0.8, teile)
	s = glocke(s, 0.065, 3520.0, 0.16, 0.9, teile)
	return normal(s, 0.6)

static func _kaufen() -> PackedFloat32Array:
	var s := leer(1.0)
	var klick := huelle(bandpass(rauschen(0.05), 3200.0, 1.5), 0.001, 0.008)
	s = mischen(s, klick, 0.0, 1.2)
	var schub := huelle(bandpass(rauschen(0.12), 1500.0, 0.8), 0.01, 0.03)
	s = mischen(s, schub, 0.03, 0.8)
	s = glocke(s, 0.08, 1760.0, 0.4, 0.7)
	s = glocke(s, 0.08, 2217.0, 0.35, 0.5)
	for k in 4:
		s = glocke(s, 0.16 + k * 0.045 + rng.randf() * 0.02, rng.randf_range(2800.0, 4200.0), 0.07, 0.25, [[1.0, 1.0, 1.0], [2.4, 0.5, 0.5]])
	return normal(s, 0.65)

static func _klick() -> PackedFloat32Array:
	var s := ton(0.05, func(_t): return 1700.0, func(t): return exp(-t / 0.006), [1.0, 0.2])
	var r := huelle(hochpass(rauschen(0.05), 3000.0), 0.0005, 0.003)
	return normal(mischen(s, r, 0.0, 0.5), 0.45)

static func _erfolg() -> PackedFloat32Array:
	var s := leer(2.2)
	var noten := [523.25, 659.25, 783.99, 1046.5]
	for k in noten.size():
		s = glocke(s, k * 0.1, noten[k], 0.5, 0.6, [[1.0, 1.0, 1.0], [2.0, 0.3, 0.6], [3.0, 0.12, 0.3], [5.4, 0.08, 0.2]])
	for f in [1046.5, 1318.5, 1568.0]:
		s = glocke(s, 0.42, f, 0.8, 0.35, [[1.0, 1.0, 1.0], [2.0, 0.25, 0.5]])
	return normal(s, 0.7)

static func _ding() -> PackedFloat32Array:
	var s := leer(1.8)
	s = glocke(s, 0.0, 880.0, 0.7, 0.8, [[1.0, 1.0, 1.0], [2.0, 0.35, 0.6], [3.0, 0.15, 0.4], [4.2, 0.07, 0.25]])
	s = glocke(s, 0.35, 698.46, 0.8, 0.7, [[1.0, 1.0, 1.0], [2.0, 0.35, 0.6], [3.0, 0.15, 0.4]])
	return normal(s, 0.6)

# ---------------------------------------------------------------- Gondel, Wetter, Stadt
static func _motor() -> PackedFloat32Array:
	# Elektromotor + Seilwinde: tiefes Brummen (ganzzahlige Perioden in 1 s → nahtlos) + Zahnrad-Singen + Rauschen
	var s := leer(1.15)
	for i in s.size():
		var t := i / R
		var v := 0.0
		for k in range(1, 9):
			v += sin(TAU * 60.0 * k * t) / k * (0.6 if k % 2 == 0 else 1.0)
		v += sin(TAU * 420.0 * t) * 0.25 + sin(TAU * 840.0 * t) * 0.08
		s[i] = v * (0.85 + 0.15 * sin(TAU * 4.0 * t))
	var r := tiefpass(rauschen(1.15), 900.0)
	for i in s.size():
		s[i] += r[i] * 0.5
	s = tiefpass(s, 2200.0)
	return normal(schleife(s, 0.15), 0.6)

static func _wind_bau(sek: float, mitte: float, breite: float, boe: float) -> PackedFloat32Array:
	var s := rauschen(sek + 0.5)
	var lfo := func(t): return mitte + breite * (0.5 * sin(TAU * t / sek) + 0.3 * sin(TAU * 2.0 * t / sek + 1.3) + 0.2 * sin(TAU * 5.0 * t / sek + 0.4))
	s = bandpass(s, mitte, 1.6, lfo)
	var tief := tiefpass(rauschen(sek + 0.5), 180.0, 2)
	for i in s.size():
		var t := i / R
		var g := 0.6 + boe * (0.5 * sin(TAU * 2.0 * t / sek + 0.7) + 0.25 * sin(TAU * 3.0 * t / sek))
		s[i] = (s[i] * 1.0 + tief[i] * 2.2) * maxf(0.15, g)
	return normal(schleife(s, 0.5), 0.75)

static func _wind() -> PackedFloat32Array:
	return _wind_bau(7.0, 520.0, 380.0, 0.5)

static func _sandsturm() -> PackedFloat32Array:
	var s := _wind_bau(6.0, 750.0, 450.0, 0.35)
	var sand := hochpass(rauschen(s.size() / R), 4000.0)
	for i in s.size():
		var k := rng.randf()
		s[i] = s[i] * 0.8 + sand[i] * (0.35 + (0.4 if k > 0.97 else 0.0))   # körniges Prasseln
	return normal(s, 0.75)

static func _stadt() -> PackedFloat32Array:
	var sek := 8.0
	var s := tiefpass(braun(sek + 0.5), 260.0)
	var zisch := bandpass(rauschen(sek + 0.5), 900.0, 0.9)
	for i in s.size():
		var t := i / R
		# vorbeifahrende Autos: langsame Lautstärke-Wellen
		var vorbei := maxf(0.0, sin(TAU * 3.0 * t / sek + 0.5)) ** 3 + 0.6 * maxf(0.0, sin(TAU * 5.0 * t / sek + 2.0)) ** 4
		s[i] = s[i] * 1.2 + zisch[i] * (0.15 + 0.5 * vorbei)
	return normal(schleife(s, 0.5), 0.7)

static func _hupe() -> PackedFloat32Array:
	var s := leer(0.55)
	for i in s.size():
		var t := i / R
		var v := 0.0
		for k in [1, 3, 5, 7]:
			v += (sin(TAU * 415.0 * k * t) + sin(TAU * 494.0 * k * t)) / k
		var a := minf(1.0, t / 0.02) * (1.0 if t < 0.38 else exp(-(t - 0.38) / 0.04))
		s[i] = v * a
	return normal(tiefpass(s, 1800.0), 0.6)

static func _brunnen() -> PackedFloat32Array:
	var sek := 3.5
	var s := tiefpass(hochpass(rauschen(sek + 0.3), 900.0), 5000.0)
	for i in s.size():
		s[i] *= 0.5
	for k in 220:   # Tropfen
		var f := rng.randf_range(900.0, 3500.0)
		var tr := ton(0.03, func(t): return f * (1.0 + t * 12.0), func(t): return exp(-t / 0.007), [1.0])
		s = mischen(s, tr, rng.randf() * sek, rng.randf_range(0.1, 0.35))
	return normal(schleife(s, 0.3), 0.7)

static func _meer() -> PackedFloat32Array:
	var sek := 9.0
	var s := rauschen(sek + 0.6)
	var welle := func(t: float) -> float:
		var p := fmod(t / (sek / 2.0), 1.0)   # zwei Wellen
		return (p / 0.25) ** 2 if p < 0.25 else exp(-(p - 0.25) / 0.25)
	s = bandpass(s, 600.0, 0.5, func(t): return 300.0 + 2600.0 * welle.call(t))
	var tief := tiefpass(braun(sek + 0.6), 200.0)
	for i in s.size():
		var t := i / R
		s[i] = s[i] * (0.15 + 0.85 * welle.call(t)) + tief[i] * 0.6
	s = normal(s, 1.0)
	for i in s.size():   # sanft verdichten: Brandung bleibt hörbar, Spitzen werden weicher
		s[i] = tanh(s[i] * 2.2)
	return normal(schleife(s, 0.6), 0.75)

static func _moewe() -> PackedFloat32Array:
	var s := leer(1.0)
	var n := 2 + rng.randi() % 2
	for k in n:
		var lang := 0.2 - k * 0.02
		var schrei := ton(lang, func(t): return 1500.0 - 650.0 * (t / lang) + sin(TAU * 26.0 * t) * 40.0,
			func(t): return sin(PI * t / lang) ** 0.5, [1.0, 0.6, 0.45, 0.3, 0.2, 0.1])
		schrei = bandpass(schrei, 2300.0, 1.2)
		s = mischen(s, schrei, 0.03 + k * 0.26, 1.0 - k * 0.15)
	return normal(s, 0.6)

static func _gurren() -> PackedFloat32Array:
	# „Ruu-gu-guu“: tiefes Gurren mit Luft
	var s := leer(1.3)
	var silben := [[0.0, 0.38, 390.0, 330.0], [0.45, 0.14, 360.0, 350.0], [0.64, 0.5, 380.0, 300.0]]
	for sb in silben:
		var lang: float = sb[1]
		var f0: float = sb[2]
		var f1: float = sb[3]
		var g := ton(lang, func(t): return lerpf(f0, f1, t / lang) + sin(TAU * 18.0 * t) * 12.0,
			func(t): return sin(PI * t / lang) ** 0.8, [1.0, 0.5, 0.15])
		s = mischen(s, g, sb[0], 0.9)
	var luft := tiefpass(rauschen(1.3), 700.0)
	for i in s.size():
		s[i] += luft[i] * absf(s[i]) * 0.8
	return normal(tiefpass(s, 1500.0), 0.6)

static func _fluegel() -> PackedFloat32Array:
	var s := leer(0.7)
	for k in 7:
		var b := huelle(tiefpass(rauschen(0.08), 1600.0), 0.01, 0.025)
		s = mischen(s, b, k * 0.085, 1.0 - k * 0.11)
	return normal(s, 0.6)

# ---------------------------------------------------------------- Casino + Arcade
const PENTA := [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.7, 1318.5]

static func _casino() -> PackedFloat32Array:
	var sek := 8.0
	var s := bandpass(rauschen(sek + 0.5), 420.0, 0.7)   # Gemurmel
	for i in s.size():
		var t := i / R
		s[i] *= 0.6 + 0.4 * sin(TAU * 3.0 * t / sek + 1.0) * sin(TAU * 7.0 * t / sek)
	for k in 26:   # ferne Automaten-Melodien
		var f: float = PENTA[rng.randi() % PENTA.size()]
		var tt := ton(0.12, func(_t): return f, func(t): return exp(-t / 0.05), [1.0, 0.0, 0.3])
		s = mischen(s, tt, rng.randf() * sek, rng.randf_range(0.04, 0.12))
	for k in 6:
		s = glocke(s, rng.randf() * sek, rng.randf_range(2600.0, 3800.0), 0.06, 0.08)
	return normal(schleife(s, 0.5), 0.6)

static func _automat() -> PackedFloat32Array:
	# Walzen drehen (Ratschen werden langsamer), drei Stopps
	var s := leer(1.5)
	var t := 0.0
	var abst := 0.035
	while t < 1.05:
		var k := huelle(bandpass(rauschen(0.02), 2500.0, 2.0), 0.0005, 0.004)
		s = mischen(s, k, t, 0.5)
		t += abst
		abst *= 1.02
	for k in 3:
		var stopp := 0.75 + k * 0.2
		var dumpf := ton(0.08, func(tt): return 140.0 - tt * 600.0, func(tt): return exp(-tt / 0.03), [1.0, 0.3])
		s = mischen(s, dumpf, stopp, 0.9)
		s = mischen(s, huelle(bandpass(rauschen(0.03), 1800.0, 1.5), 0.0005, 0.008), stopp, 0.7)
	return normal(s, 0.6)

static func _karte() -> PackedFloat32Array:
	var s := huelle(bandpass(rauschen(0.12), 3000.0, 0.9), 0.001, 0.012)
	var w := huelle(tiefpass(rauschen(0.12), 1200.0), 0.02, 0.02)
	return normal(mischen(s, w, 0.0, 0.5), 0.5)

static func _jackpot() -> PackedFloat32Array:
	var s := leer(2.8)
	for r in 3:
		for k in PENTA.size():
			s = glocke(s, r * 0.36 + k * 0.045, PENTA[k] * (1.0 + r * 0.5 * 0.0), 0.18, 0.45, [[1.0, 1.0, 1.0], [2.0, 0.3, 0.5]])
	for k in 40:   # Münzregen
		s = glocke(s, 0.3 + rng.randf() * 2.0, rng.randf_range(2500.0, 4500.0), 0.05, 0.25, [[1.0, 1.0, 1.0], [2.4, 0.5, 0.5]])
	return normal(s, 0.75)

static func _tick() -> PackedFloat32Array:
	return normal(huelle(bandpass(rauschen(0.03), 2200.0, 2.5), 0.0003, 0.003), 0.45)

static func _chips() -> PackedFloat32Array:
	var s := leer(0.4)
	for k in 3:
		s = mischen(s, huelle(bandpass(rauschen(0.05), rng.randf_range(4000.0, 5500.0), 4.0), 0.0005, 0.01), k * 0.07 + rng.randf() * 0.02, 1.0)
	return normal(s, 0.5)

static func _quadrat(f: float, t: float) -> float:
	return 1.0 if fmod(f * t, 1.0) < 0.5 else -1.0

static func _arcade() -> PackedFloat32Array:
	var sek := 6.0
	var s := bandpass(rauschen(sek + 0.4), 500.0, 0.7)
	for i in s.size():
		s[i] *= 0.35
	for k in 34:
		var f: float = PENTA[rng.randi() % PENTA.size()] * (0.5 if rng.randf() < 0.5 else 1.0)
		var b := leer(0.09)
		for i in b.size():
			var t := i / R
			b[i] = _quadrat(f * (1.0 + t * 3.0), t) * exp(-t / 0.04)
		s = mischen(s, b, rng.randf() * sek, rng.randf_range(0.03, 0.09))
	return normal(schleife(tiefpass(s, 6000.0), 0.4), 0.55)

static func _piep() -> PackedFloat32Array:
	var s := leer(0.16)
	var ph := 0.0
	for i in s.size():
		var t := i / R
		ph += (600.0 + 4000.0 * t) / R
		s[i] = (1.0 if fmod(ph, 1.0) < 0.5 else -1.0) * exp(-t / 0.08)
	return normal(tiefpass(s, 5000.0), 0.4)

static func _arcade_gewinn() -> PackedFloat32Array:
	var s := leer(1.1)
	var noten := [523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0]
	for k in noten.size():
		var b := leer(0.16 if k < 5 else 0.4)
		for i in b.size():
			var t := i / R
			b[i] = _quadrat(noten[k], t) * exp(-t / (0.08 if k < 5 else 0.25))
		s = mischen(s, b, k * 0.09, 0.8)
	return normal(tiefpass(s, 5500.0), 0.5)

# ---------------------------------------------------------------- Angeln, Yacht, Fahrzeuge
static func _wurf() -> PackedFloat32Array:
	var s := bandpass(rauschen(0.7), 800.0, 1.2, func(t): return 500.0 + 2500.0 * sin(PI * minf(t / 0.35, 1.0)))
	s = huelle(s, 0.12, 0.15)
	var t := 0.1
	while t < 0.6:   # Rolle surrt
		s = mischen(s, huelle(bandpass(rauschen(0.01), 3000.0, 2.0), 0.0003, 0.002), t, 0.25)
		t += 0.016
	return normal(s, 0.55)

static func _platsch() -> PackedFloat32Array:
	var s := huelle(tiefpass(rauschen(0.7), 2200.0), 0.004, 0.09)
	for k in 7:
		var f0 := rng.randf_range(300.0, 600.0)
		var bl := ton(0.05, func(t): return f0 + t * 9000.0, func(t): return sin(PI * t / 0.05), [1.0])
		s = mischen(s, bl, 0.05 + rng.randf() * 0.3, 0.25)
	return normal(s, 0.6)

static func _biss() -> PackedFloat32Array:
	var s := ton(0.06, func(t): return 260.0 + t * 8000.0, func(t): return sin(PI * t / 0.06), [1.0, 0.2])
	var sp := huelle(tiefpass(rauschen(0.25), 2500.0), 0.002, 0.04)
	return normal(mischen(sp, s, 0.0, 1.5), 0.55)

static func _rolle() -> PackedFloat32Array:
	var s := leer(0.5)
	var t := 0.0
	while t < 0.5:   # 32 Klicks je halbe Sekunde
		s = mischen(s, huelle(bandpass(rauschen(0.012), 3400.0, 3.0), 0.0003, 0.0025), t, 0.8)
		t += 0.5 / 32.0
	return normal(s, 0.45)

static func _yacht() -> PackedFloat32Array:
	var sek := 3.0
	var s := leer(sek + 0.3)
	for i in s.size():
		var t := i / R
		var v := 0.0
		for k in range(1, 7):
			v += sin(TAU * 42.0 * k * t) / k
		s[i] = v * (0.8 + 0.2 * sin(TAU * 7.0 * t))
	var wasser := tiefpass(rauschen(sek + 0.3), 1200.0)
	for i in s.size():
		var t := i / R
		s[i] = s[i] * 0.7 + wasser[i] * (1.0 + 0.6 * sin(TAU * t / sek * 2.0))
	return normal(schleife(tiefpass(s, 1500.0), 0.3), 0.65)

static func _scooter() -> PackedFloat32Array:
	var s := leer(1.2)
	for i in s.size():
		var t := i / R
		s[i] = sin(TAU * 310.0 * t) * 0.6 + sin(TAU * 620.0 * t) * 0.2 + sin(TAU * 1240.0 * t) * 0.06
	var rollen := tiefpass(rauschen(1.2), 500.0)
	for i in s.size():
		s[i] += rollen[i] * 0.9
	return normal(schleife(s, 0.2), 0.5)

static func _hover() -> PackedFloat32Array:
	var s := leer(2.2)
	for i in s.size():
		var t := i / R
		s[i] = sin(TAU * 110.0 * t) * 0.5 + sin(TAU * 110.5 * t) * 0.5 + sin(TAU * 220.0 * t) * 0.25 \
			+ sin(TAU * 880.0 * t + sin(TAU * 3.0 * t) * 2.0) * 0.08
	return normal(schleife(s, 0.2), 0.5)

static func _jetpack() -> PackedFloat32Array:
	var s := tiefpass(rauschen(2.3), 700.0, 2)
	var hiss := hochpass(rauschen(2.3), 3000.0)
	for i in s.size():
		var knack := 0.8 if rng.randf() > 0.995 else 0.0
		s[i] = s[i] * 2.5 + hiss[i] * 0.3 + knack * rng.randf_range(-1.0, 1.0)
	return normal(schleife(s, 0.3), 0.7)

static func _knall() -> PackedFloat32Array:
	var s := huelle(tiefpass(rauschen(1.6), 900.0), 0.003, 0.18)
	for k in 60:   # Knistern danach
		s = mischen(s, huelle(hochpass(rauschen(0.01), 2500.0), 0.0005, 0.003), 0.2 + rng.randf() * 1.2, rng.randf_range(0.1, 0.4))
	return normal(s, 0.8)

# ---------------------------------------------------------------- Instrumente (Grundton C)
static func _i_ep() -> PackedFloat32Array:
	# E-Piano (FM): Träger und Modulator 1:1, Index klingt ab, dazu ein kurzer „Tine“-Anschlag
	var f := 261.63
	var s := leer(3.2)
	for i in s.size():
		var t := i / R
		var idx := 1.6 * exp(-t / 0.3) + 0.35
		var a := minf(1.0, t / 0.004) * exp(-t / 1.1)
		s[i] = sin(TAU * f * t + idx * sin(TAU * f * t)) * a + sin(TAU * f * 14.0 * t) * 0.12 * exp(-t / 0.03)
	return normal(s, 0.8)

static func _i_bass() -> PackedFloat32Array:
	var f := 65.41
	var s := leer(1.8)
	for i in s.size():
		var t := i / R
		var a := minf(1.0, t / 0.006) * (0.35 + 0.65 * exp(-t / 0.18)) * exp(-t / 1.4)
		s[i] = (sin(TAU * f * t) + 0.35 * sin(TAU * 2.0 * f * t) + 0.12 * sin(TAU * 3.0 * f * t)) * a
	return normal(tiefpass(s, 900.0), 0.85)

static func _i_pad() -> PackedFloat32Array:
	var f := 130.81
	var s := leer(5.0)
	var p := [0.0, 0.33, 0.66]
	var df := [1.0, 1.004, 0.996]
	for i in s.size():
		var t := i / R
		var v := 0.0
		for k in 3:
			p[k] = fmod(p[k] + f * df[k] / R, 1.0)
			v += p[k] * 2.0 - 1.0
		var a := minf(1.0, t / 0.9) * (1.0 if t < 3.6 else exp(-(t - 3.6) / 0.4))
		s[i] = v * a
	return normal(tiefpass(s, 1100.0, 2), 0.7)

static func _i_kick() -> PackedFloat32Array:
	var s := leer(0.4)
	var ph := 0.0
	for i in s.size():
		var t := i / R
		ph += (45.0 + 80.0 * exp(-t / 0.035)) / R
		s[i] = sin(TAU * ph) * exp(-t / 0.22) * minf(1.0, t / 0.002)
	return normal(s, 0.9)

static func _i_snare() -> PackedFloat32Array:
	# weicher Besen-Schlag
	var s := huelle(bandpass(rauschen(0.35), 2400.0, 0.8), 0.006, 0.09)
	var k := ton(0.08, func(t): return 300.0 - t * 400.0, func(t): return exp(-t / 0.025), [1.0])
	return normal(mischen(s, k, 0.0, 0.4), 0.7)

static func _i_rim() -> PackedFloat32Array:
	var s := ton(0.06, func(_t): return 1650.0, func(t): return exp(-t / 0.01), [1.0, 0.3])
	return normal(mischen(s, huelle(hochpass(rauschen(0.06), 2000.0), 0.0005, 0.006), 0.0, 0.6), 0.6)

static func _i_hat() -> PackedFloat32Array:
	return normal(huelle(hochpass(hochpass(rauschen(0.08), 6000.0), 6000.0), 0.0008, 0.018), 0.5)

static func _i_hat_offen() -> PackedFloat32Array:
	return normal(huelle(hochpass(hochpass(rauschen(0.4), 6000.0), 6000.0), 0.002, 0.11), 0.5)

static func _i_shaker() -> PackedFloat32Array:
	return normal(huelle(bandpass(rauschen(0.14), 5500.0, 1.5), 0.015, 0.04), 0.45)

static func _i_klatsch() -> PackedFloat32Array:
	var s := leer(0.35)
	for k in 3:
		s = mischen(s, huelle(bandpass(rauschen(0.03), 1300.0, 1.0), 0.0005, 0.006), k * 0.011, 0.8)
	s = mischen(s, huelle(bandpass(rauschen(0.3), 1200.0, 0.8), 0.001, 0.07), 0.03, 0.6)
	return normal(s, 0.7)

static func _i_chip() -> PackedFloat32Array:
	var f := 523.25
	var s := leer(0.6)
	for i in s.size():
		var t := i / R
		var puls := 0.5 if t < 0.05 else 0.25
		s[i] = (1.0 if fmod(f * t, 1.0) < puls else -1.0) * minf(1.0, t / 0.003) * exp(-t / 0.22)
	return normal(hochpass(tiefpass(s, 6000.0), 40.0), 0.55)

static func _i_pluck() -> PackedFloat32Array:
	var f := 261.63
	var s := leer(0.9)
	var ph := 0.0
	var y := 0.0
	var y2 := 0.0
	for i in s.size():
		var t := i / R
		ph = fmod(ph + f / R, 1.0)
		var fc := 350.0 + 3200.0 * exp(-t / 0.09)
		var a := 1.0 - exp(-TAU * fc / R)
		y += a * ((ph * 2.0 - 1.0) - y)
		y2 += a * (y - y2)
		s[i] = y2 * minf(1.0, t / 0.002) * exp(-t / 0.35)
	return normal(s, 0.7)

static func _i_klavier() -> PackedFloat32Array:
	var f := 261.63
	var s := leer(3.6)
	var teile := [[1.0, 1.0, 1.6], [2.001, 0.5, 1.1], [3.004, 0.3, 0.8], [4.008, 0.18, 0.55], [5.013, 0.1, 0.4], [6.02, 0.06, 0.3], [7.03, 0.04, 0.22]]
	for i in s.size():
		var t := i / R
		var v := 0.0
		for p in teile:
			v += sin(TAU * f * float(p[0]) * t) * float(p[1]) * exp(-t / float(p[2]))
		s[i] = v * minf(1.0, t / 0.003)
	var hammer := huelle(bandpass(rauschen(0.05), 2000.0, 1.0), 0.0005, 0.008)
	return normal(mischen(s, hammer, 0.0, 0.3), 0.8)

static func _i_knistern() -> PackedFloat32Array:
	# Schallplatten-Knistern fürs Klassik-Radio
	var s := tiefpass(rauschen(4.3), 3000.0)
	for i in s.size():
		s[i] *= 0.05
	for k in 90:
		s = mischen(s, huelle(hochpass(rauschen(0.004), 1500.0), 0.0002, 0.0012), rng.randf() * 4.3, rng.randf_range(0.2, 0.9))
	return normal(schleife(s, 0.3), 0.4)

static func _i_glocke() -> PackedFloat32Array:
	var s := leer(2.5)
	return normal(glocke(s, 0.0, 523.25, 0.9, 1.0, [[1.0, 1.0, 1.0], [2.0, 0.4, 0.6], [3.0, 0.2, 0.35], [4.16, 0.1, 0.2]]), 0.7)
