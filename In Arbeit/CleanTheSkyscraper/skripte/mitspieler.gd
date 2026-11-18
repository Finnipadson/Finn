class_name Mitspieler
extends Node3D
# Mehrspieler (Phase 7a): zeigt die anderen Spieler. Zu Fuß als Figur (Kenney Mini Characters) mit Farbring und
# Namensschild, in der Gondel nur das Namensschild an der Gondel (Gondel-Figur kommt in 7c). Die Lage kommt
# 20× pro Sekunde über Netz.lage(); dazwischen wird weich nachgeführt. Dazu die Spielerliste oben rechts.
# Lage-Array (Spiel.lage_daten): [modus 0 = zu Fuß / 1 = Gondel / 2 = Yacht, x, y, z, yaw, innen, fahrzeug]

const FIGUREN := ["character-male-b", "character-female-a", "character-male-e", "character-female-c", "character-worker"]
const MASS := 2.8                 # wie die Leute an der Küste (≈ 1,55 m)
const SCHILD_BIS := 400.0         # Namensschild bis zu dieser Entfernung

var spiel: Spiel
var figuren := {}                 # peer_id -> {knoten, figur, ring, schild, ap, anim, lage, pos, yaw, tempo}
var liste_ebene: CanvasLayer
var liste_box: VBoxContainer

func setup(s: Spiel) -> void:
	spiel = s
	liste_ebene = CanvasLayer.new()
	liste_ebene.layer = 5
	add_child(liste_ebene)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiGlas.box(Color(UiGlas.GLAS, 0.72), UiGlas.RAND, 12, 12))
	pc.anchor_left = 1.0
	pc.anchor_right = 1.0
	pc.anchor_top = 0.3
	pc.anchor_bottom = 0.3
	pc.offset_left = -16
	pc.offset_right = -16
	pc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	liste_ebene.add_child(pc)
	liste_box = VBoxContainer.new()
	liste_box.add_theme_constant_override("separation", 3)
	liste_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(liste_box)
	Netz.spieler_geaendert.connect(_liste)
	_liste()

func _exit_tree() -> void:
	if Netz.spieler_geaendert.is_connected(_liste):
		Netz.spieler_geaendert.disconnect(_liste)

# ---------------------------------------------------------------- Spielerliste oben rechts
func _liste() -> void:
	if not is_instance_valid(liste_box):
		return
	for c in liste_box.get_children():
		liste_box.remove_child(c)
		c.queue_free()
	liste_ebene.visible = Netz.aktiv()
	if not Netz.aktiv():
		return
	liste_box.add_child(UiGlas.text("Mehrspieler · %d/%d" % [Netz.spieler.size(), Netz.MAX_SPIELER], 13, UiGlas.TEXT_LEISE))
	var ids := Netz.spieler.keys()
	ids.sort()
	for id in ids:
		var t := "● %s" % Netz.name_von(id)
		if id == 1:
			t += "  (Gastgeber)"
		if id == Netz.meine_id():
			t += "  – du"
		var l := UiGlas.text(t, 15, Netz.farbe(id))
		l.name = "spieler_%d" % id
		liste_box.add_child(l)

# ---------------------------------------------------------------- Lage empfangen
func lage(id: int, l: Array) -> void:
	if l.size() < 7:
		return
	if not figuren.has(id):
		_figur_bauen(id)
	var f: Dictionary = figuren[id]
	var neu := Vector3(float(l[1]), float(l[2]), float(l[3]))
	if f.lage.is_empty() or int(f.lage[0]) != int(l[0]) or (f.pos as Vector3).distance_to(neu) > 60.0:
		f.pos = neu           # Moduswechsel/Teleport (Aufzug): springen statt gleiten
		f.yaw = float(l[4])
	f.lage = l
	f.ziel = neu

func ort_von(id: int) -> Dictionary:
	if not figuren.has(id) or (figuren[id].lage as Array).is_empty():
		return {}
	var l: Array = figuren[id].lage
	if int(l[0]) != 0:
		return {}
	return {"modus": "fuss", "x": float(l[1]), "z": float(l[3]), "yaw": float(l[4]), "pitch": 0.0, "innen": str(l[5])}

# Für Tests: wo steht die Figur von id gerade (Weltposition der Füße)?
func figur_pos(id: int) -> Vector3:
	return (figuren[id].knoten as Node3D).global_position if figuren.has(id) else Vector3.INF

func figur_sichtbar(id: int) -> bool:
	return figuren.has(id) and (figuren[id].figur as Node3D).is_visible_in_tree()

func _figur_bauen(id: int) -> void:
	var k := Node3D.new()
	k.name = "mitspieler_%d" % id
	add_child(k)
	var fa := int((Netz.spieler.get(id, {}) as Dictionary).get("farbe", 0))
	var figur := RaumBau.modell(k, "leute/" + FIGUREN[fa % FIGUREN.size()], Vector3.ZERO, MASS, PI)
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.55
	cm.height = 0.02
	ring.mesh = cm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(Netz.farbe(id), 0.55)
	ring.material_override = rm
	ring.position.y = 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	k.add_child(ring)
	var schild := Label3D.new()
	schild.text = Netz.name_von(id)
	schild.font_size = 48
	schild.pixel_size = 0.005
	schild.outline_size = 12
	schild.outline_modulate = Color(0.02, 0.04, 0.08, 0.9)
	schild.modulate = Netz.farbe(id)
	schild.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	schild.fixed_size = false
	schild.position.y = 2.45
	k.add_child(schild)
	var ap := figur.find_child("AnimationPlayer", true, false) as AnimationPlayer
	figuren[id] = {"knoten": k, "figur": figur, "ring": ring, "schild": schild, "ap": ap, "anim": "", "lage": [], "pos": Vector3.ZERO, "ziel": Vector3.ZERO, "yaw": 0.0, "tempo": 0.0}

func _anim(f: Dictionary, art: String) -> void:
	var ap: AnimationPlayer = f.ap
	if ap == null or f.anim == art:
		return
	for a in ap.get_animation_list():
		if art in a.to_lower():
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
			ap.play(a, 0.2)
			f.anim = art
			return

# ---------------------------------------------------------------- Nachführen
func _process(dt: float) -> void:
	# Figuren von Spielern entfernen, die weg sind
	for id in figuren.keys():
		if not Netz.spieler.has(id) or not Netz.aktiv():
			(figuren[id].knoten as Node3D).queue_free()
			figuren.erase(id)
	if figuren.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var mein_innen: String = spiel.extras.ort if spiel.extras else ""
	for id in figuren:
		var f: Dictionary = figuren[id]
		var l: Array = f.lage
		var k: Node3D = f.knoten
		if l.is_empty():
			k.visible = false
			continue
		var alt: Vector3 = f.pos
		f.pos = alt.lerp(f.ziel, minf(1.0, dt * 12.0))
		f.yaw = lerp_angle(float(f.yaw), float(l[4]), minf(1.0, dt * 10.0))
		var tempo := Vector2(f.pos.x - alt.x, f.pos.z - alt.z).length() / maxf(dt, 0.001)
		f.tempo = lerpf(float(f.tempo), tempo, minf(1.0, dt * 8.0))
		var modus := int(l[0])
		var innen := str(l[5])
		k.visible = innen == mein_innen and (modus == 0 or modus == 1)
		k.position = f.pos
		(f.figur as Node3D).visible = modus == 0
		(f.ring as Node3D).visible = modus == 0
		var schild: Label3D = f.schild
		schild.position.y = 2.45 if modus == 0 else 2.8
		if cam:
			schild.visible = cam.global_position.distance_to(k.global_position) < SCHILD_BIS
		if modus == 0:
			k.rotation.y = float(f.yaw)
			_anim(f, "sprint" if f.tempo > 6.5 else ("walk" if f.tempo > 0.6 else "idle"))
