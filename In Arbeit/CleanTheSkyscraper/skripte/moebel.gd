class_name Moebel
# Modelle der Penthouse-Gegenstände (Kenney Furniture Kit in modelle/moebel, CC0): laden, einfärben,
# Seltenheit leuchten lassen. Fehlt ein Modell, steht eine Kiste in der Farbe der Seltenheit da.

const MASS := 2.1              # Furniture Kit → Meter (Tür im Kit 1,01 hoch = 2,1 m)
static var _glow := {}

static func modell(id: String) -> Node3D:
	var g: Dictionary = Wirtschaft.GEGENSTAENDE.get(id, {})
	var stufe := int(g.get("seltenheit", 0))
	var wurzel := Node3D.new()
	var name := "moebel/" + str(g.get("modell", ""))
	var n: Node3D
	if RaumBau.modell_da(name):
		n = RaumBau.modell(wurzel, name, Vector3.ZERO, MASS * float(g.get("s", 1.0)))
	else:
		n = Node3D.new()
		wurzel.add_child(n)
		RaumBau.box(n, Vector3(0.7, 0.7, 0.7), Vector3(0, 0.35, 0), Bau.matt(Wirtschaft.SELTEN_FARBE[stufe], 0.5))
	var farbe := str(g.get("farbe", ""))
	if farbe == "gold":
		RaumBau.faerben(n, Bau.metall("e8b53a", 0.22, 0.95))
	elif farbe != "":
		_toenen(n, Color(farbe))
	if stufe > 0 and g.get("quelle", "") == "arcade":
		RaumBau.faerben(n, glow(stufe), true)
	# Ursprung der Kenney-Modelle liegt teils an einer Ecke: Mitte der Grundfläche auf (0, 0), Unterkante auf 0
	var b := RaumBau.aabb(wurzel)
	n.position -= Vector3(b.get_center().x, b.position.y, b.get_center().z)
	return wurzel

# Leuchtrand je Seltenheit (geteiltes Material)
static func glow(stufe: int) -> ShaderMaterial:
	if not _glow.has(stufe):
		var m := ShaderMaterial.new()
		m.shader = load("res://shader/seltenheit.gdshader")
		m.set_shader_parameter("farbe", Color(Wirtschaft.SELTEN_FARBE[stufe]))
		m.set_shader_parameter("kraft", [0.0, 0.8, 1.1, 1.4][stufe])
		_glow[stufe] = m
	return _glow[stufe]

# Farbe mischen, Textur/Schattierung bleibt (jede Fläche bekommt eine eigene Kopie ihres Materials)
static func _toenen(n: Node, c: Color) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var alt := mi.get_active_material(i)
			if alt is StandardMaterial3D:
				var neu := (alt as StandardMaterial3D).duplicate() as StandardMaterial3D
				neu.albedo_color = neu.albedo_color.lerp(c, 0.65)
				mi.set_surface_override_material(i, neu)
	for k in n.get_children():
		_toenen(k, c)

# Größe (AABB) je Gegenstand, einmal gemessen
static var _groesse := {}
static func groesse(id: String) -> Vector3:
	if not _groesse.has(id):
		var n := modell(id)
		_groesse[id] = RaumBau.aabb(n).size
		n.queue_free()
	return _groesse[id]

# Grundfläche (x, z) des Modells, gedreht um dreh (Grad) – für Kollision und Platzieren
static func flaeche(id: String, dreh: float) -> Vector2:
	var b := groesse(id)
	var a := deg_to_rad(dreh)
	var ex := absf(cos(a)) * b.x + absf(sin(a)) * b.z
	var ez := absf(sin(a)) * b.x + absf(cos(a)) * b.z
	return Vector2(ex, ez)

static func hoehe(id: String) -> float:
	return groesse(id).y
