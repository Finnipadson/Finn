class_name Laeufer
extends Node3D
# Zu Fuß am Boden: Ich-Ansicht, WASD laufen, Shift rennen, Leertaste springen, Maus umschauen.
# Turm und Häuser sind fest (einfache Kollision: Turm-Grundriss + Rechtecke der Häuser).
# Fahrzeuge (Hotbar): E-Scooter, Hoverboard (schneller), Jetpack (fliegen: Leertaste hoch, Strg runter, über die Häuser).

const AUGE := 1.7
const TEMPO := 4.5
const RENNEN := 9.0
const RADIUS := 0.45
const GRENZE := 1850.0        # weiter weg geht es nicht (Rand der Stadt)
const MAUS := 0.0022

var cam: Camera3D
var aktiv := false
var gesperrt := false         # ein Menü ist offen: Maus nicht fangen, nicht umschauen
var laufen_aus := false       # beim Angeln: nicht laufen/springen, aber umschauen (19.11.2026)
var yaw := 0.0
var pitch := 0.0
var hoch := 0.0              # Sprunghöhe
var vy := 0.0
var bob := 0.0
var turm_rand: PackedVector2Array      # Turm-Grundriss unten, etwas vergrößert
var haeuser: Array = []                 # Rect2 der Häuser (x, z)
var hindernisse: Array = []             # weitere Rect2 (z. B. Stände)
var polygone: Array = []                # PackedVector2Array, in die man nicht darf (z. B. der See)
var gondel_pos := Vector2(INF, INF)     # die geparkte Gondel ist auch fest
const GONDEL_R := 1.9
var weitere_gondeln: Array = []          # Vector2 der geparkten Gondeln
var haeuser_hoehe: Array = []            # Höhe je Haus (für das Jetpack)
var bloecke: Array = []                  # [Rect2, Höhe]: hohe Klötze, die nur in der Luft zählen (Casino-Hochhaus)
var fahrzeug := ""                       # "" = zu Fuß, sonst Wirtschaft.FAHRZEUGE-id
var fz_tempo := 0.0
var fz_fliegt := false
var fz_modell: Node3D
const FLUG_HOCH := 120.0
const FLUG_TEMPO_V := 8.0
const KLEIN_BIS := 3.0                   # kleine Hindernisse (Bänke, Palmen, Stände) nur bis zu dieser Höhe
# Innenraum (Sky-Lounge, Arcade, Penthouse): {poly = begehbare Fläche, rechtecke, kreise [Vector2, r], boden = Höhe (y)}.
# Leer = draußen am Boden.
var raum := {}
var gelaufen := 0.0                      # Meter zu Fuß/mit Fahrzeug (Statistik)
# Draußen an der Küste (Kueste): Bodenhöhe (Strand 2 m tiefer, Treppen, Brücken) und zusätzliche Sperren
# (Kanal, Ufermauer, Meer). boden_fn(p: Vector2) -> float, sperre_fn(p: Vector2, fuss_y: float) -> bool (true = frei)
var boden_fn: Callable
var sperre_fn: Callable

func setup(t: Turm, w: Welt) -> void:
	cam = Camera3D.new()
	cam.fov = Optionen.fov()
	cam.near = 0.05
	cam.far = 40000.0
	add_child(cam)
	var unten: PackedVector2Array = t.stockwerke[0].poly
	var gross := Geometry2D.offset_polygon(unten, RADIUS + 0.3)
	turm_rand = gross[0] if gross.size() > 0 else unten
	haeuser = w.haeuser
	haeuser_hoehe = w.haeuser_hoehe

func aktivieren(pos: Vector3, blick_yaw: float, gondel: Vector3 = Vector3.INF) -> void:
	gondel_pos = Vector2(gondel.x, gondel.z) if gondel != Vector3.INF else Vector2(INF, INF)
	raum = {}
	position = Vector3(pos.x, 0.0, pos.z)
	if boden_fn.is_valid():
		position.y = boden_fn.call(Vector2(pos.x, pos.z))
	yaw = blick_yaw
	pitch = 0.0
	hoch = 0.0
	vy = 0.0
	aktiv = true
	cam.current = true
	visible = true

func deaktivieren() -> void:
	aktiv = false

func _input(e: InputEvent) -> void:
	if not aktiv or gesperrt:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw = wrapf(yaw - e.relative.x * MAUS * Optionen.maus_x(), -PI, PI)
		pitch = clampf(pitch - e.relative.y * MAUS * Optionen.maus_y(), -1.5, 1.5)
	elif e is InputEventKey and e.pressed and not e.echo:
		if Optionen.k(e) == KEY_SPACE and hoch <= 0.001 and not fz_fliegt and not laufen_aus:
			vy = 4.5
		elif Optionen.k(e) == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# In einen Innenraum wechseln (Aufzug) bzw. zurück nach draußen (r leer)
func raum_setzen(r: Dictionary, pos: Vector2, blick_yaw: float) -> void:
	raum = r
	position = Vector3(pos.x, float(r.get("boden", 0.0)), pos.y)
	if r.is_empty() and boden_fn.is_valid():
		position.y = boden_fn.call(pos)
	yaw = blick_yaw
	pitch = 0.0
	hoch = 0.0
	vy = 0.0

func _raum_frei(p: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(p, raum.poly):
		return false
	for r in raum.get("rechtecke", []):
		if (r as Rect2).grow(RADIUS).has_point(p):
			return false
	for k in raum.get("kreise", []):
		if p.distance_to(k[0]) < float(k[1]) + RADIUS:
			return false
	return true

func frei(p: Vector2) -> bool:
	if not raum.is_empty():
		return _raum_frei(p)
	if p.length() > GRENZE:
		return false
	if Geometry2D.is_point_in_polygon(p, turm_rand):
		return false
	for i in haeuser.size():   # Häuser: nur so hoch, wie sie sind (Jetpack fliegt drüber)
		if hoch < (float(haeuser_hoehe[i]) + 0.5 if i < haeuser_hoehe.size() else 1e9) and (haeuser[i] as Rect2).grow(RADIUS).has_point(p):
			return false
	if hoch < KLEIN_BIS:
		if gondel_pos.x != INF and p.distance_to(gondel_pos) < GONDEL_R:
			return false
		for g in weitere_gondeln:
			if p.distance_to(g) < GONDEL_R:
				return false
		for r in hindernisse:
			if r.grow(RADIUS).has_point(p):
				return false
		for pg in polygone:
			if Geometry2D.is_point_in_polygon(p, pg):
				return false
		if sperre_fn.is_valid() and not sperre_fn.call(p, position.y):
			return false
	else:
		for b in bloecke:
			if hoch < float(b[1]) and (b[0] as Rect2).grow(RADIUS).has_point(p):
				return false
	return true

# Fahrzeug wechseln ("" = zu Fuß). Modell unter den Füßen, Tempo, Fliegen.
func fahrzeug_setzen(id: String) -> void:
	fahrzeug = id
	if fz_modell:
		fz_modell.queue_free()
		fz_modell = null
	var daten := {}
	for f in Wirtschaft.FAHRZEUGE:
		if f.id == id:
			daten = f
	fz_tempo = float(daten.get("tempo", 0.0))
	fz_fliegt = bool(daten.get("fliegt", false))
	if id != "":
		fz_modell = Fahrzeuge.modell(id)
		add_child(fz_modell)
	if not fz_fliegt and hoch > 0.0:
		vy = 0.0   # Jetpack ab: runterfallen

func _process(dt: float) -> void:
	if not aktiv:
		return
	var vor := Vector3(-sin(yaw), 0, -cos(yaw))
	var rechts := Vector3(cos(yaw), 0, -sin(yaw))
	var d := Vector3.ZERO
	if laufen_aus:
		pass
	elif Optionen.gedrueckt(KEY_W): d += vor
	if Optionen.gedrueckt(KEY_S): d -= vor
	if Optionen.gedrueckt(KEY_D): d += rechts
	if Optionen.gedrueckt(KEY_A): d -= rechts
	var laeuft := d.length_squared() > 0.0
	if laeuft:
		var tempo := RENNEN if Optionen.gedrueckt(KEY_SHIFT) else TEMPO
		if fahrzeug != "":
			tempo = fz_tempo * (1.25 if Optionen.gedrueckt(KEY_SHIFT) else 1.0)
		d = d.normalized() * tempo * dt
		# an Hindernissen entlanggleiten: x und z getrennt prüfen
		var vorher := position
		if frei(Vector2(position.x + d.x, position.z)):
			position.x += d.x
		if frei(Vector2(position.x, position.z + d.z)):
			position.z += d.z
		gelaufen += Vector2(position.x - vorher.x, position.z - vorher.z).length()
		bob += dt * (13.0 if Optionen.gedrueckt(KEY_SHIFT) else 9.0)
	if raum.is_empty() and boden_fn.is_valid():   # Bodenhöhe draußen (auch nach Teleport im Stand)
		position.y = boden_fn.call(Vector2(position.x, position.z))
	if fz_fliegt and not gesperrt and raum.is_empty():
		# Jetpack: Leertaste hoch, Strg runter, sonst in der Luft stehen bleiben
		var v := 0.0
		if Optionen.gedrueckt(KEY_SPACE): v += FLUG_TEMPO_V
		if Optionen.gedrueckt(KEY_CTRL): v -= FLUG_TEMPO_V
		var neu := clampf(hoch + v * dt, 0.0, FLUG_HOCH)
		var alt := hoch
		hoch = neu
		if not frei(Vector2(position.x, position.z)):   # nicht in ein Hausdach hineinsinken
			hoch = alt
		vy = 0.0
	else:
		vy -= 13.0 * dt
		var alt2 := hoch
		hoch = maxf(0.0, hoch + vy * dt)
		if hoch < alt2 and not frei(Vector2(position.x, position.z)):   # auf einem Dach landen
			hoch = alt2
			vy = 0.0
		if hoch == 0.0:
			vy = 0.0
	var schweben := 0.22 + sin(bob * 0.5 + Time.get_ticks_msec() * 0.003) * 0.03 if fahrzeug == "hoverboard" else (0.12 if fahrzeug == "scooter" else 0.0)
	if fz_modell:
		fz_modell.position = Vector3(0, hoch + (schweben - 0.12 if fahrzeug == "hoverboard" else 0.0), 0)
		fz_modell.rotation.y = yaw
		for n in ["flamme0", "flamme1"]:
			var fl := fz_modell.get_node_or_null(n) as Node3D
			if fl:
				fl.visible = hoch > 0.05
				fl.scale = Vector3.ONE * (0.8 + randf() * 0.4)
	cam.position = Vector3(0, AUGE + hoch + schweben + (sin(bob) * 0.04 if laeuft and fahrzeug == "" else 0.0), 0)
	cam.rotation = Vector3(pitch, yaw, 0)
