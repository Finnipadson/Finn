extends SceneTree
# Gibt die Größe (AABB) aller Modelle in res://modelle aus.

func _aabb(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var erst := true
	var t := xf
	if n is Node3D:
		t = xf * n.transform
	if n is MeshInstance3D and n.mesh:
		var b: AABB = t * n.mesh.get_aabb()
		box = b
		erst = false
	for c in n.get_children():
		var cb := _aabb(c, t)
		if cb.size != Vector3.ZERO:
			box = cb if erst else box.merge(cb)
			erst = false
	return box

func _init() -> void:
	var d := DirAccess.open("res://modelle")
	for f in d.get_files():
		if f.ends_with(".glb"):
			var n: Node = load("res://modelle/" + f).instantiate()
			var b := _aabb(n, Transform3D.IDENTITY)
			print("%-32s size=(%.2f, %.2f, %.2f) pos=(%.2f, %.2f, %.2f)" % [f, b.size.x, b.size.y, b.size.z, b.position.x, b.position.y, b.position.z])
			n.free()
	quit()
