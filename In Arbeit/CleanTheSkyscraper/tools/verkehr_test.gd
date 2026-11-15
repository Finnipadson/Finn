extends SceneTree
# Prüft den Verkehr ohne Bild: 60 s simulieren und zählen,
# ob Autos aus beiden Richtungen gleichzeitig auf einer Kreuzung sind und ob an Rot gewartet wird.
# Aufruf: godot --path . --headless --script tools/verkehr_test.gd

var welt: Welt
var fertig := false

func _init() -> void:
	welt = Welt.new()
	root.add_child(welt)

func _process(_d: float) -> bool:
	if fertig:
		return true
	fertig = true
	var v: Verkehr = null
	for c in welt.get_children():
		if c is Verkehr:
			v = c
	v.set_process(false)
	var zusammen := 0
	var max_warten := 0
	var bei_rot_drin := 0
	var schnitt_tempo := 0.0
	var schritte := 60 * 30
	for schritt in schritte:
		v._process(1.0 / 30.0)
		var auf_kreuzung := {}   # Kreuzung → Bitmaske der Achsen
		var warten := 0
		var summe := 0.0
		for a in v.autos:
			var p: Vector3 = a.pos
			var sp: Dictionary = v.spuren[a.spur]
			summe += float(a.v)
			if float(a.v) < 0.3:
				warten += 1
			var kx := Verkehr.RASTER * (floorf(p.x / Verkehr.RASTER - 0.5) + 0.5)
			var kz := Verkehr.RASTER * (floorf(p.y / Verkehr.RASTER - 0.5) + 0.5)
			for dx in [0.0, Verkehr.RASTER]:
				for dz in [0.0, Verkehr.RASTER]:
					var k := Vector2(kx + dx, kz + dz)
					if absf(p.x - k.x) < 6.5 and absf(p.y - k.y) < 6.5:
						auf_kreuzung[k] = int(auf_kreuzung.get(k, 0)) | (1 << int(sp.achse))
						var t := fposmod(v.zeit + (0.0 if sp.achse == 0 else (Verkehr.GRUEN + Verkehr.GELB + Verkehr.ALLE_ROT)), 2.0 * (Verkehr.GRUEN + Verkehr.GELB + Verkehr.ALLE_ROT))
						if t > Verkehr.GRUEN + Verkehr.GELB + Verkehr.ALLE_ROT and schritt > 150:   # spätestens nach „alle rot“ muss die Kreuzung frei sein
							bei_rot_drin += 1
		for k in auf_kreuzung:
			if auf_kreuzung[k] == 3 and schritt > 150:
				zusammen += 1
		max_warten = maxi(max_warten, warten)
		schnitt_tempo += summe / v.autos.size()
	print("TEST verkehr: autos=%d  beide_achsen_auf_kreuzung=%d  bei_rot_auf_kreuzung=%d  max_wartend=%d  tempo=%.1f m/s" % [v.autos.size(), zusammen, bei_rot_drin, max_warten, schnitt_tempo / schritte])
	quit()
	return false
