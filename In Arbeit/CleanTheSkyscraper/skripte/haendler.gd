class_name Haendler
extends Node3D
# Drei Marktstände auf dem Händler-Stellplatz, jeweils mit Verkäufer-Figur.
# Zu Fuß vor einen Stand gehen und E drücken → HaendlerMenu öffnet sich.

const STAENDE := [
	{"id": "putz", "name": "Putzmittel", "farbe": "2f86c8", "streifen": "ffffff", "figur": "2f86c8"},
	{"id": "mode", "name": "Mode & Farben", "farbe": "d84f9a", "streifen": "ffe3f1", "figur": "8a4fd8"},
	{"id": "snack", "name": "Snacks", "farbe": "e08a1e", "streifen": "fff3d6", "figur": "e2483e"},
]
const NAH := 2.6                 # so nah muss man vor dem Stand stehen

var vorne: Array = []            # Vector2: Punkt vor jedem Stand (zum Ansprechen)
var rechtecke: Array = []        # Rect2 für die Kollision zu Fuß
var figuren: Array = []          # Verkäufer (winken ein bisschen)

func setup(mitte: Vector3) -> void:
	var r := Vector2(mitte.x, mitte.z).normalized()      # von der Turmmitte nach außen
	var t := Vector2(-r.y, r.x)
	for i in STAENDE.size():
		var sp: Dictionary = STAENDE[i]
		var p2 := Vector2(mitte.x, mitte.z) + t * ((i - 1) * 6.0)
		var stand := _stand(sp)
		stand.position = Vector3(p2.x, 0, p2.y)
		stand.basis = Basis.looking_at(Vector3(-r.x, 0, -r.y), Vector3.UP)   # Front zum Turm
		add_child(stand)
		vorne.append(p2 - r * 2.0)
		rechtecke.append(Rect2(p2 - Vector2(2.0, 2.0), Vector2(4.0, 4.0)))

# Welcher Stand ist nah genug? (-1 = keiner)
func stand_bei(p: Vector2) -> int:
	for i in vorne.size():
		if p.distance_to(vorne[i]) < NAH:
			return i
	return -1

func _process(_dt: float) -> void:
	var zeit := Time.get_ticks_msec() / 1000.0
	for i in figuren.size():
		var arm: Node3D = figuren[i]
		arm.rotation.z = 2.4 + sin(zeit * 3.0 + i) * 0.35

# ---------------------------------------------------------------- Modell
func _box(eltern: Node3D, g: Vector3, p: Vector3, farbe: String, rau := 0.8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = g
	mi.mesh = bm
	mi.material_override = Bau.matt(farbe, rau)
	mi.position = p
	eltern.add_child(mi)
	return mi

func _stand(sp: Dictionary) -> Node3D:
	var n := Node3D.new()
	var holz := "a8794f"
	# Theke (vorne = -Z)
	_box(n, Vector3(3.4, 1.0, 1.0), Vector3(0, 0.5, -0.6), holz)
	_box(n, Vector3(3.5, 0.08, 1.1), Vector3(0, 1.04, -0.6), "d9b98a")
	_box(n, Vector3(3.4, 0.6, 0.04), Vector3(0, 0.55, -1.11), sp.farbe)
	# Pfosten + Rückwand
	for x in [-1.65, 1.65]:
		for z in [-1.05, 1.0]:
			_box(n, Vector3(0.12, 2.6, 0.12), Vector3(x, 1.3, z), holz)
	_box(n, Vector3(3.4, 1.4, 0.06), Vector3(0, 1.6, 1.0), "efe6d6")
	# gestreiftes Dach (leicht geneigt)
	var dach := Node3D.new()
	dach.position = Vector3(0, 2.7, -0.05)
	dach.rotation.x = 0.18
	n.add_child(dach)
	for k in 8:
		_box(dach, Vector3(0.44, 0.06, 2.6), Vector3(-1.54 + k * 0.44, 0, 0), sp.farbe if k % 2 == 0 else sp.streifen, 0.7)
	for k in 8:   # Zacken vorne
		var z := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.0
		cm.height = 0.28
		cm.radial_segments = 3
		z.mesh = cm
		z.material_override = Bau.matt(sp.farbe if k % 2 == 0 else sp.streifen, 0.7)
		z.position = Vector3(-1.54 + k * 0.44, -0.16, -1.3)
		dach.add_child(z)
	# Schild
	var schild := Label3D.new()
	schild.text = sp.name
	schild.font_size = 110
	schild.pixel_size = 0.005
	schild.outline_size = 22
	schild.modulate = Color(sp.farbe)
	schild.outline_modulate = Color.WHITE
	schild.position = Vector3(0, 3.25, -1.0)
	schild.rotation.y = PI
	n.add_child(schild)
	_waren(n, sp.id)
	_figur(n, sp.figur)
	return n

func _waren(n: Node3D, id: String) -> void:
	match id:
		"putz":
			for i in 7:
				var f := Bau.zylinder(0.07, 0.08, 0.32, Bau.matt(["2f86c8", "3fc29a", "ffd84a"][i % 3], 0.4), 10)
				f.position = Vector3(-1.4 + i * 0.4, 1.24, -0.75)
				n.add_child(f)
				_box(n, Vector3(0.05, 0.08, 0.05), Vector3(-1.4 + i * 0.4, 1.44, -0.75), "e2483e")
		"mode":
			for i in 6:
				_box(n, Vector3(0.36, 0.5, 0.06), Vector3(-1.3 + i * 0.52, 1.75, 0.9), ["e2483e", "3a86d4", "3fc29a", "ff4fb8", "e8b53a", "2b2d33"][i])
			for i in 4:
				var dose := Bau.zylinder(0.12, 0.12, 0.2, Bau.matt(["ff8a1e", "5ab8ff", "9a6ad6", "ffd84a"][i], 0.5), 12)
				dose.position = Vector3(-1.0 + i * 0.6, 1.18, -0.7)
				n.add_child(dose)
		"snack":
			for i in 4:
				var becher := Bau.zylinder(0.07, 0.055, 0.18, Bau.matt("f4ede2", 0.6), 10)
				becher.position = Vector3(-1.3 + i * 0.3, 1.17, -0.75)
				n.add_child(becher)
			for i in 3:
				var waffel := Bau.zylinder(0.07, 0.0, 0.22, Bau.matt("d9a35a", 0.7), 8)
				waffel.position = Vector3(0.4 + i * 0.35, 1.2, -0.75)
				n.add_child(waffel)
				var kugel := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.08
				sm.height = 0.16
				kugel.mesh = sm
				kugel.material_override = Bau.matt(["ff9ec4", "fff3d6", "8a5a3a"][i], 0.6)
				kugel.position = Vector3(0.4 + i * 0.35, 1.34, -0.75)
				n.add_child(kugel)
			var limo := Bau.zylinder(0.25, 0.25, 0.5, Bau.matt("f2e04a", 0.2), 16)
			limo.position = Vector3(1.4, 1.33, -0.3)
			n.add_child(limo)

func _figur(n: Node3D, farbe: String) -> void:
	var f := Node3D.new()
	f.position = Vector3(0.3, 0, 0.2)
	n.add_child(f)
	var haut := Bau.matt("f1c29b", 0.6)
	var koerper := MeshInstance3D.new()
	var km := CapsuleMesh.new()
	km.radius = 0.28
	km.height = 1.3
	koerper.mesh = km
	koerper.material_override = Bau.matt(farbe, 0.8)
	koerper.position = Vector3(0, 0.95, 0)
	f.add_child(koerper)
	var kopf := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	kopf.mesh = sm
	kopf.material_override = haut
	kopf.position = Vector3(0, 1.8, 0)
	f.add_child(kopf)
	var muetze := Bau.zylinder(0.19, 0.21, 0.14, Bau.matt("ffffff", 0.7), 14)
	muetze.position = Vector3(0, 1.98, 0)
	f.add_child(muetze)
	for s in [-1, 1]:
		var auge := MeshInstance3D.new()
		var am := SphereMesh.new()
		am.radius = 0.025
		am.height = 0.05
		auge.mesh = am
		auge.material_override = Bau.matt("222222", 0.4)
		auge.position = Vector3(0.07 * s, 1.84, -0.18)
		f.add_child(auge)
	# winkender Arm
	var schulter := Node3D.new()
	schulter.position = Vector3(-0.3, 1.35, 0)
	f.add_child(schulter)
	var arm := Bau.zylinder(0.06, 0.06, 0.55, Bau.matt(farbe, 0.8), 8)
	arm.position = Vector3(0, -0.27, 0)
	schulter.add_child(arm)
	figuren.append(schulter)
