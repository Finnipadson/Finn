class_name Tageszeit
extends Node
# Tag und Nacht (Phase 5): ein Tag dauert 20 Minuten (ca. 14 min hell, 6 min Abend + Nacht).
# phase 0..1 → Uhrzeit → Sonnenstand → Himmel, Licht, Nebel und der globale Shader-Wert „nacht“ (0 Tag … 1 Nacht),
# mit dem Stadtfenster, Turm, Laternen, Autos und Fontänen nachts leuchten. Welt mischt den Sandsturm darüber.
# phase < 0 = aus (feste Nachmittagssonne wie vor Phase 5, für alte Tests und Testbilder).

const TAG := 1200.0          # Sekunden je Tag
const HELL := 0.7            # Anteil 6:30–19:00 (14 min)
const ABEND := 0.8           # bis 20:30 Dämmerung
const MORGEN := 0.97         # ab 5:30 Morgendämmerung

static var lampen: Array = []      # [StandardMaterial3D, Grundstärke]: leuchten nachts heller (Laternen, Steg)

var phase := -1.0
var laeuft := false          # nur im Spiel; Tests stellen die Zeit fest ein
var welt: Welt
var innen := false           # Kamera in einem Innenraum: Umgebungslicht bleibt hell
var werte := {}
var _innen_k := 0.0

# Uhrzeit (Stunden) zur Phase – der helle Tag ist gedehnt, die Nacht kurz
static func uhr(p: float) -> float:
	p = fposmod(p, 1.0)
	if p < HELL:
		return 6.5 + p / HELL * 12.5
	if p < ABEND:
		return 19.0 + (p - HELL) / (ABEND - HELL) * 1.5
	if p < MORGEN:
		return fmod(20.5 + (p - ABEND) / (MORGEN - ABEND) * 9.0, 24.0)
	return 5.5 + (p - MORGEN) / (1.0 - MORGEN) * 1.0

static func phase_zu(stunde: float) -> float:
	# Umkehrung von uhr() (für --uhr=HH und Tests)
	if stunde >= 6.5 and stunde < 19.0:
		return (stunde - 6.5) / 12.5 * HELL
	if stunde >= 19.0 and stunde < 20.5:
		return HELL + (stunde - 19.0) / 1.5 * (ABEND - HELL)
	if stunde >= 5.5 and stunde < 6.5:
		return MORGEN + (stunde - 5.5) * (1.0 - MORGEN)
	var h := stunde if stunde >= 20.5 else stunde + 24.0
	return ABEND + (h - 20.5) / 9.0 * (MORGEN - ABEND)

static func uhr_text(p: float) -> String:
	var h := uhr(p)
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]

# Sonnenhöhe (Grad) und Richtung zur Uhrzeit: Aufgang 6:30 im Osten, Mittag 12:45 hoch im Süden, Untergang 19:00 im Westen
static func sonne(stunde: float) -> Vector3:
	var t := (stunde - 6.5) / 12.5           # 0 = Aufgang, 1 = Untergang
	var hoehe := sin(t * PI) * 62.0
	if t < 0.0 or t > 1.0:                    # Nacht: unter dem Horizont
		var tn := fposmod(stunde - 19.0, 24.0) / 11.5
		hoehe = -sin(clampf(tn, 0.0, 1.0) * PI) * 30.0 - 0.5
	# Richtung in der x/z-Ebene: um 16:30 (t = 0,8) steht sie wie die feste Sonne vor Phase 5 (Welt.SONNE_DIR)
	var az := deg_to_rad(-124.0 + 200.0 * clampf(t, -0.15, 1.15))
	var e := deg_to_rad(hoehe)
	return Vector3(cos(az) * cos(e), sin(e), sin(az) * cos(e)).normalized()

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--uhr="):   # Testbilder zu einer festen Uhrzeit
			phase = phase_zu(float(a.split("=")[1]))

func _process(dt: float) -> void:
	if laeuft and phase >= 0.0:
		phase = fposmod(phase + dt / TAG, 1.0)
	_innen_k = move_toward(_innen_k, 1.0 if innen else 0.0, dt * 1.5)
	if phase >= 0.0:
		werte = berechnen(phase)
		werte.ambient = lerpf(werte.ambient, 0.55, _innen_k)
		werte.belichtung = lerpf(werte.belichtung, 0.68, _innen_k * 0.6)
		welt.licht(werte)
		var nacht: float = werte.nacht
		for l in lampen:
			(l[0] as StandardMaterial3D).emission_energy_multiplier = float(l[1]) * (1.0 + 7.0 * nacht)

static func _mix3(a: Color, b: Color, k: float) -> Color:
	return a.lerp(b, clampf(k, 0.0, 1.0))

# Alle Werte für eine Phase (rein rechnerisch, auch für Tests)
static func berechnen(p: float) -> Dictionary:
	var h := uhr(p)
	var sd := sonne(h)
	var e := rad_to_deg(asin(clampf(sd.y, -1.0, 1.0)))
	var tag := smoothstep(-5.0, 8.0, e)          # 0 Nacht … 1 Tag
	var gold := smoothstep(22.0, 2.0, e) * smoothstep(-6.0, 1.0, e)   # tiefe Sonne: warm
	var nacht := 1.0 - smoothstep(-7.0, 3.0, e)
	var oben := _mix3(Color(0.012, 0.025, 0.07), Color(0.165, 0.47, 0.84), tag)
	oben = _mix3(oben, Color(0.22, 0.3, 0.6), gold * 0.55)
	var horiz := _mix3(Color(0.05, 0.08, 0.16), Welt.HORIZONT, tag)
	horiz = _mix3(horiz, Color(1.0, 0.62, 0.38), gold * 0.8)
	# Licht: Sonne am Tag, Mond in der Nacht (Wechsel, wenn beide fast aus sind → kein Sprung)
	var licht_dir := sd
	var farbe := _mix3(Color("ffe6bf"), Color("ff9a55"), gold)
	var kraft := 1.4 * smoothstep(-4.0, 6.0, e) * (1.0 - 0.35 * gold)
	var mond := Vector3(-sd.x, 0.62, -sd.z).normalized()
	if e < -4.0:
		licht_dir = mond
		farbe = Color("9db8ff")
		kraft = 0.14 * smoothstep(-4.0, -12.0, e)
	var wolken := _mix3(Color(0.09, 0.1, 0.16), Color(1, 1, 1), tag)
	wolken = _mix3(wolken, Color(1.0, 0.72, 0.55), gold * 0.7)
	return {
		"uhr": h, "sonne_hoehe": e, "sonne": sd, "mond": mond, "licht_dir": licht_dir, "licht_farbe": farbe,
		"licht_kraft": kraft, "oben": oben, "horizont": horiz, "wolken": wolken, "nacht": nacht, "tag": tag,
		"ambient": lerpf(0.22, 0.55, tag), "belichtung": lerpf(1.0, 0.68, tag), "glow": lerpf(0.75, 0.3, tag),
	}
