extends SceneTree
# Prüft die Aufteilung des Turms in drei Seiten: Längen je Stockwerk, alle Fenster genau einer Seite zugeordnet.
# Aufruf: godot --path . --headless --script tools/seiten_test.gd
var turm: Turm
func _init() -> void:
	turm = Turm.new()
	root.add_child(turm)
func _process(_d: float) -> bool:
	var fehler := 0
	for f in [0, 17, 18, 60, 120, 150, 167]:
		var b: Array = turm.seiten[f]
		var summe := 0.0
		var zahl := 0
		for k in 3:
			summe += (b[k] as Vector2).y
			zahl += turm.spalten_der_seite(f, k).size()
		var doppelt := {}
		for k in 3:
			for c in turm.spalten_der_seite(f, k):
				if doppelt.has(c):
					fehler += 1
				doppelt[c] = k
		# Seite der Mitte jeder Seite stimmt?
		for k in 3:
			if turm.seite_bei(f, turm.seiten_mitte(f, k)) != k:
				fehler += 1
		print("TEST seiten f=%d umfang=%.1f summe=%.1f fenster=%d/%d laengen=%.0f/%.0f/%.0f" % [f, turm.umfaenge[f], summe, zahl, turm.fenster_pro_stock[f], b[0].y, b[1].y, b[2].y])
	print("TEST seiten fehler=%d" % fehler)
	quit()
	return true
