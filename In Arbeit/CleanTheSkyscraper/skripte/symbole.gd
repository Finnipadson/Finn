class_name Symbole
extends Node
# Bilder für Hotbar und Menüs: jedes Werkzeug und Fahrzeug wird beim Start einmal in einem kleinen
# „Fotostudio“ (SubViewport mit eigener Welt, Licht, schräger Blick) gerendert. Ergebnis: Symbole.bilder[id] = Texture2D.
# "" (zu Fuß) zeigt die Arbeiter-Figur.

const GROESSE := 128
static var bilder := {}

signal fertig

func erzeugen() -> void:
	var auftraege := []
	for w in Wirtschaft.WERKZEUGE:
		auftraege.append([w.id, Spieler.werkzeug_modell(w), 0.62 if w.get("modell", "") == "schwamm" else 0.0])
	for f in Wirtschaft.FAHRZEUGE:
		var m := Fahrzeuge.modell(f.id)
		for c in m.get_children():
			if c.name.begins_with("flamme"):
				c.visible = false
		auftraege.append([f.id, m, 0.0])
	for id in Wirtschaft.GEGENSTAENDE:   # Penthouse-Gegenstände (Möbel, Arcade-Gewinne): Bild-ID "g_" + id
		auftraege.append(["g_" + id, Moebel.modell(id), 0.0])
	var figur: Node3D = load("res://modelle/leute/character-worker.glb").instantiate()
	auftraege.append(["", figur, 0.0])
	var studios := []
	for a in auftraege:
		studios.append(_studio(a[0], a[1], a[2]))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for st in studios:
		var vp: SubViewport = st[1]
		var img := vp.get_texture().get_image()
		if img:
			bilder[st[0]] = ImageTexture.create_from_image(img)
		vp.queue_free()
	fertig.emit()

# fest > 0: fester Bildausschnitt (Schwämme: so sieht man, welcher größer ist)
func _studio(id: String, modell: Node3D, fest: float) -> Array:
	var vp := SubViewport.new()
	vp.size = Vector2i(GROESSE, GROESSE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.9, 1.0)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var licht := DirectionalLight3D.new()
	licht.light_energy = 1.3
	vp.add_child(licht)
	licht.look_at_from_position(Vector3(2, 4, 3), Vector3.ZERO, Vector3.UP)
	vp.add_child(modell)
	# Rahmen: Größe des Modells messen, schräg von vorne oben mit Parallel-Kamera ausfüllen
	var box := _aabb(modell, Transform3D.IDENTITY)
	var mitte := box.get_center()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = fest if fest > 0.0 else maxf(box.size.length() * 0.82, 0.05)
	cam.near = 0.01
	cam.far = 100.0
	vp.add_child(cam)
	var blick := Vector3(0.9, 0.75, -1.2).normalized() if id != "" else Vector3(0.5, 0.25, 1.0).normalized()
	cam.look_at_from_position(mitte + blick * 10.0, mitte, Vector3.UP)
	cam.current = true
	return [id, vp]

func _aabb(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var erst := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		box = t * (n as MeshInstance3D).mesh.get_aabb()
		erst = false
	for c in n.get_children():
		var cb := _aabb(c, t)
		if cb.size != Vector3.ZERO:
			box = cb if erst else box.merge(cb)
			erst = false
	return box
