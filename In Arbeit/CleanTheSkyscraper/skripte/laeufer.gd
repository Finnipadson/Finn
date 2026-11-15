class_name Laeufer
extends Node3D
# Zu Fuß am Boden: Ich-Ansicht, WASD laufen, Shift rennen, Leertaste springen, Maus umschauen.
# Turm und Häuser sind fest (einfache Kollision: Turm-Grundriss + Rechtecke der Häuser).

const AUGE := 1.7
const TEMPO := 4.5
const RENNEN := 9.0
const RADIUS := 0.45
const GRENZE := 1850.0        # weiter weg geht es nicht (Rand der Stadt)
const MAUS := 0.0022

var cam: Camera3D
var aktiv := false
var gesperrt := false         # ein Menü ist offen: Maus nicht fangen, nicht umschauen
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

func setup(t: Turm, w: Welt) -> void:
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	cam.far = 40000.0
	add_child(cam)
	var unten: PackedVector2Array = t.stockwerke[0].poly
	var gross := Geometry2D.offset_polygon(unten, RADIUS + 0.3)
	turm_rand = gross[0] if gross.size() > 0 else unten
	haeuser = w.haeuser

func aktivieren(pos: Vector3, blick_yaw: float, gondel: Vector3 = Vector3.INF) -> void:
	gondel_pos = Vector2(gondel.x, gondel.z) if gondel != Vector3.INF else Vector2(INF, INF)
	position = Vector3(pos.x, 0.0, pos.z)
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
		yaw = wrapf(yaw - e.relative.x * MAUS, -PI, PI)
		pitch = clampf(pitch - e.relative.y * MAUS, -1.5, 1.5)
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_SPACE and hoch <= 0.001:
			vy = 4.5
		elif e.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func frei(p: Vector2) -> bool:
	if p.length() > GRENZE:
		return false
	if Geometry2D.is_point_in_polygon(p, turm_rand):
		return false
	if gondel_pos.x != INF and p.distance_to(gondel_pos) < GONDEL_R:
		return false
	for r in haeuser + hindernisse:
		if r.grow(RADIUS).has_point(p):
			return false
	for pg in polygone:
		if Geometry2D.is_point_in_polygon(p, pg):
			return false
	return true

func _process(dt: float) -> void:
	if not aktiv:
		return
	var vor := Vector3(-sin(yaw), 0, -cos(yaw))
	var rechts := Vector3(cos(yaw), 0, -sin(yaw))
	var d := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): d += vor
	if Input.is_key_pressed(KEY_S): d -= vor
	if Input.is_key_pressed(KEY_D): d += rechts
	if Input.is_key_pressed(KEY_A): d -= rechts
	var laeuft := d.length_squared() > 0.0
	if laeuft:
		var tempo := RENNEN if Input.is_key_pressed(KEY_SHIFT) else TEMPO
		d = d.normalized() * tempo * dt
		# an Hindernissen entlanggleiten: x und z getrennt prüfen
		if frei(Vector2(position.x + d.x, position.z)):
			position.x += d.x
		if frei(Vector2(position.x, position.z + d.z)):
			position.z += d.z
		bob += dt * (13.0 if Input.is_key_pressed(KEY_SHIFT) else 9.0)
	vy -= 13.0 * dt
	hoch = maxf(0.0, hoch + vy * dt)
	if hoch == 0.0:
		vy = 0.0
	cam.position = Vector3(0, AUGE + hoch + (sin(bob) * 0.04 if laeuft else 0.0), 0)
	cam.rotation = Vector3(pitch, yaw, 0)
