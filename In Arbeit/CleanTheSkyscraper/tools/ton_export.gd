extends SceneTree
# Alle aus Code erzeugten Klänge als WAV speichern (zum Anhören und Vergleichen mit echten Sound-Packs):
#   godot --headless --path . --script tools/ton_export.gd   → export/ton_erzeugt/<name>.wav
# Eine Datei mit gleichem Namen (.ogg/.wav/.mp3) im Ordner ton/ ersetzt den erzeugten Klang im Spiel.

func _init() -> void:
	var ziel := ProjectSettings.globalize_path("res://export/ton_erzeugt")
	DirAccess.make_dir_recursive_absolute(ziel)
	var n := 0
	for name in Synth.reihenfolge():
		var w := Synth.eins(name)
		w.save_to_wav(ziel.path_join(name + ".wav"))
		n += 1
	print("%d Klänge gespeichert in %s" % [n, ziel])
	quit()
