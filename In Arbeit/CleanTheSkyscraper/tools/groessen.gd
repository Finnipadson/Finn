extends SceneTree
# Gibt die Größe (x, y, z in m) der Möbelhaus-Möbel aus: godot --headless --script tools/groessen.gd
func _init() -> void:
	var w := Wirtschaft.new()
	for id in Wirtschaft.GEGENSTAENDE:
		if w.moebel_raum(id) != "":
			var g := Moebel.groesse(id)
			print("%s %s %.2f %.2f %.2f" % [w.moebel_raum(id), id, g.x, g.y, g.z])
	for m in ["rugRectangle", "rugRound", "bathroomMirror", "computerScreen", "laptop", "lampRoundTable", "plantSmall2", "sideTable", "books", "kitchenCabinet", "kitchenCabinetUpper", "kitchenMicrowave", "kitchenCoffeeMachine", "lampSquareCeiling", "pillowBlue", "rugDoormat", "bench", "chairModernCushion", "cardboardBoxOpen", "speakerSmall"]:
		var n := Node3D.new()
		var k := RaumBau.modell(n, "moebel/" + m, Vector3.ZERO, Moebel.MASS)
		var b := RaumBau.aabb(k)
		print("deko %s %.2f %.2f %.2f" % [m, b.size.x, b.size.y, b.size.z])
	quit()
