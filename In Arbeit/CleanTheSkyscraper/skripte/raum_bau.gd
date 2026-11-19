class_name RaumBau
# Bausteine für die Innenräume (Sky-Lounge, Arcade, Penthouse): Klötze, Zylinder, Leuchtflächen, Lichter, Schrift,
# Böden/Decken/Glaswände aus einem Grundriss und Kenney-Modelle (Möbel aus modelle/moebel).

static func box(eltern: Node3D, g: Vector3, p: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = g
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	eltern.add_child(mi)
	return mi

static func zyl(eltern: Node3D, r: float, h: float, p: Vector3, m: Material, seg := 24, r_unten := -1.0) -> MeshInstance3D:
	var z := Bau.zylinder(r, r if r_unten < 0.0 else r_unten, h, m, seg)
	z.position = p
	eltern.add_child(z)
	return z

static func leuchte(farbe: String, kraft := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(farbe)
	m.emission_enabled = true
	m.emission = Color(farbe)
	m.emission_energy_multiplier = kraft
	return m

static func glas(farbe := "bfe3ff", alpha := 0.12) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(Color(farbe), alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.2
	m.roughness = 0.05
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shadow_to_opacity = false
	return m

static func licht(eltern: Node3D, p: Vector3, farbe: String, kraft: float, weit: float, schatten := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = Color(farbe)
	l.light_energy = kraft
	l.omni_range = weit
	l.shadow_enabled = schatten
	eltern.add_child(l)
	return l

static func schrift(eltern: Node3D, t: String, p: Vector3, dreh: float, groesse: int, pixel: float, farbe: Color, dick := true) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font_size = groesse
	l.pixel_size = pixel
	l.outline_size = 0
	l.modulate = farbe
	l.shaded = false
	l.position = p
	l.rotation.y = dreh
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI Black", "Arial Black", "Segoe UI"] if dick else ["Segoe UI Semibold", "Segoe UI"])
	f.font_weight = 900 if dick else 600
	f.generate_mipmaps = true   # Schrift aus der Entfernung gefiltert (vorher flimmerte z. B. die Kreidetafel im Fischladen)
	l.font = f
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	eltern.add_child(l)
	return l

# Waagerechte Fläche aus einem Grundriss (Boden: nach oben, Decke: nach unten)
static func flaeche(eltern: Node3D, poly: PackedVector2Array, y: float, m: Material, nach_oben := true, uv_mass := 0.25) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(poly)
	var n := Vector3.UP if nach_oben else Vector3.DOWN
	for i in range(0, idx.size(), 3):
		var tri := [idx[i], idx[i + 1], idx[i + 2]] if nach_oben else [idx[i], idx[i + 2], idx[i + 1]]
		# Godot: Vorderseite im Uhrzeigersinn – Reihenfolge prüfen und notfalls drehen
		var a := Vector3(poly[tri[0]].x, y, poly[tri[0]].y)
		var b := Vector3(poly[tri[1]].x, y, poly[tri[1]].y)
		var c := Vector3(poly[tri[2]].x, y, poly[tri[2]].y)
		if (c - a).cross(b - a).dot(n) < 0.0:
			tri = [tri[0], tri[2], tri[1]]
		for k in tri:
			st.set_normal(n)
			st.set_uv(poly[k] * uv_mass)
			st.add_vertex(Vector3(poly[k].x, y, poly[k].y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	eltern.add_child(mi)
	return mi

# Senkrechte Wand entlang eines geschlossenen Grundrisses von y0 bis y1 (beidseitig sichtbar über das Material)
static func waende(eltern: Node3D, poly: PackedVector2Array, y0: float, y1: float, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var weg := 0.0
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var lang := a.distance_to(b)
		var n2 := (b - a).normalized().orthogonal()
		var n := Vector3(n2.x, 0, n2.y)
		for e in [[a, weg, y0], [b, weg + lang, y0], [b, weg + lang, y1], [a, weg, y0], [b, weg + lang, y1], [a, weg, y1]]:
			st.set_normal(n)
			st.set_uv(Vector2(e[1], e[2]))
			st.add_vertex(Vector3(e[0].x, e[2], e[0].y))
		weg += lang
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eltern.add_child(mi)
	return mi

static func kreis(r: float, n := 40) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		p.append(Vector2(cos(a), sin(a)) * r)
	return p

static func verschieben(poly: PackedVector2Array, um: float) -> PackedVector2Array:
	var l := Geometry2D.offset_polygon(poly, um)
	return l[0] if l.size() > 0 else poly

# ---------------------------------------------------------------- Zusammenfassen
# Alle MeshInstance3D mit material_override unter wurzel (außer in den Knoten aus ausser) zu je einem Mesh pro
# gleich aussehendem Material verschmelzen. Kenney-Modelle (ohne material_override) und Label3D bleiben, ebenso
# Materialien, die sich ändern (leuchten mit Stärke 0 = Glitzer, der aufblitzt).
static func verschmelzen(wurzel: Node3D, ausser: Array = []) -> void:
	var gruppen := {}     # Schlüssel -> [Material, SurfaceTool]
	var weg: Array = []
	_sammeln(wurzel, Transform3D.IDENTITY, gruppen, weg, ausser)
	for c in weg:
		c.get_parent().remove_child(c)
		c.queue_free()
	for k in gruppen:
		var mi := MeshInstance3D.new()
		mi.mesh = (gruppen[k][1] as SurfaceTool).commit()
		mi.material_override = gruppen[k][0]
		wurzel.add_child(mi)

static func _sammeln(n: Node, xf: Transform3D, gruppen: Dictionary, weg: Array, ausser: Array) -> void:
	for c in n.get_children():
		if c in ausser or not (c is Node3D) or c is Label3D:
			continue
		var t: Transform3D = xf * (c as Node3D).transform
		if c is MeshInstance3D and c.get_child_count() == 0:
			var mi := c as MeshInstance3D
			var m := mi.material_override
			if mi.mesh == null or m == null or not (m is StandardMaterial3D) or mi.material_overlay != null:
				continue
			var sm := m as StandardMaterial3D
			if sm.emission_enabled and sm.emission_energy_multiplier == 0.0:
				continue
			var k := "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [sm.albedo_color, sm.metallic, sm.roughness, sm.emission_enabled, sm.emission, sm.emission_energy_multiplier,
				sm.transparency, sm.albedo_texture, sm.shading_mode, sm.blend_mode, sm.cull_mode, sm.uv1_triplanar]
			if not gruppen.has(k):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				gruppen[k] = [sm, st]
			for s in mi.mesh.get_surface_count():
				(gruppen[k][1] as SurfaceTool).append_from(mi.mesh, s, t)
			weg.append(mi)
		elif not (c is MeshInstance3D) and c.get_child_count() > 0 and c.find_child("AnimationPlayer", true, false) == null:
			_sammeln(c, t, gruppen, weg, ausser)

# ---------------------------------------------------------------- Kenney-Modelle
static func modell_da(name: String) -> bool:
	return ResourceLoader.exists("res://modelle/%s.glb" % name)

# Kenney-Modell laden (Figuren spielen ihre Ruhe-Animation). Fehlt es, kommt ein leerer Knoten zurück.
static func modell(eltern: Node3D, name: String, p: Vector3, s: float, dreh := 0.0) -> Node3D:
	var pfad := "res://modelle/%s.glb" % name
	if not ResourceLoader.exists(pfad):
		var leer := Node3D.new()
		eltern.add_child(leer)
		return leer
	var n: Node3D = load(pfad).instantiate()
	n.position = p
	n.rotation.y = dreh
	n.scale = Vector3.ONE * s
	eltern.add_child(n)
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		var namen := ap.get_animation_list()
		var wahl := ""
		for a in namen:
			if "idle" in a.to_lower():
				wahl = a
				break
		if wahl == "" and namen.size() > 0:
			wahl = namen[0]
		if wahl != "":
			ap.get_animation(wahl).loop_mode = Animation.LOOP_LINEAR
			ap.play(wahl)
	return n

# Wie modell(), aber mit der Mitte der Grundfläche auf p (Kenney-Möbel haben den Ursprung teils an einer Ecke)
static func mittig(eltern: Node3D, name: String, p: Vector3, s: float, dreh := 0.0) -> Node3D:
	var w := Node3D.new()
	w.position = p
	w.rotation.y = dreh
	eltern.add_child(w)
	var n := modell(w, name, Vector3.ZERO, s)
	var b := aabb(n)
	n.position -= Vector3(b.get_center().x, b.position.y, b.get_center().z)
	return w

static func aabb(n: Node, xf := Transform3D.IDENTITY) -> AABB:
	var box := AABB()
	var erst := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		box = t * (n as MeshInstance3D).mesh.get_aabb()
		erst = false
	for c in n.get_children():
		var cb := aabb(c, t)
		if cb.size != Vector3.ZERO:
			box = cb if erst else box.merge(cb)
			erst = false
	return box

# Alle Meshes eines Modells mit einem Material überziehen (Einfärben) bzw. ein Overlay setzen (Seltenheits-Leuchten)
static func faerben(n: Node, m: Material, overlay := false) -> void:
	if n is MeshInstance3D:
		if overlay:
			(n as MeshInstance3D).material_overlay = m
		else:
			(n as MeshInstance3D).material_override = m
	for c in n.get_children():
		faerben(c, m, overlay)
