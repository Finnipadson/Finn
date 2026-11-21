class_name Optionen
# Globale Einstellungen (Phase 5) – gelten für jeden Spielstand und schon im Hauptmenü:
# Lautstärke (Musik, Geräusche, Radio), Bildqualität, Maus und Tastenbelegung. Datei user://einstellungen.json.
# Spiel-Einstellungen (Tauben, Sandsturm, Wind) bleiben im Spielstand (Wirtschaft.einstellungen).
#
# Tasten umbelegen: Der Code fragt weiter die Standard-Tasten ab, aber über Optionen.k(e) / Optionen.gedrueckt(KEY_W).
# k(e) übersetzt die gedrückte Taste in die Standard-Taste ihrer Aktion, gedrueckt(KEY_W) prüft die belegte Taste.
# In Tests und beim Bot (aktiv = false) gilt immer die Standardbelegung.

const DATEI := "user://einstellungen.json"
const TESTDATEI := "user://einstellungen_test.json"

const STANDARD := {
	"musik": 0.6, "geraeusche": 0.8, "radio": 0.7,
	"qualitaet": 2,          # 0 Niedrig, 1 Mittel, 2 Hoch
	"ruhig": true,           # Ruhiges Bild: kein TAA (TAA glättet beim Fahren mehr, wackelt aber im Stand)
	"fps": 0,                # 0 = wie der Bildschirm (VSync), sonst Grenze; -1 = unbegrenzt
	"vollbild": false,
	"maus": 1.0,             # Empfindlichkeit (Umschauen)
	"maus_umkehren": false,  # Maus hoch = nach unten schauen
	"kamera_folgt": true,    # beim Putzen schwenkt der Blick mit, wenn das Werkzeug an den Bildrand kommt (21.11.2026)
	"fov": 75.0,             # Sichtfeld in Grad (zu Fuß; Gondel +3°), Wunsch des Users 20.11.2026
	"tasten": {},            # Aktion → Keycode (nur Abweichungen von der Standardbelegung)
}
const QUALITAET := ["Niedrig", "Mittel", "Hoch"]
const FPS := [[0, "Bildschirm"], [30, "30"], [60, "60"], [120, "120"], [144, "144"], [-1, "Frei"]]

# Umbelegbare Aktionen: [id, Standard-Taste, Name]
const AKTIONEN := [
	["vor", KEY_W, "Vorwärts / Gondel hoch"],
	["zurueck", KEY_S, "Rückwärts / Gondel runter"],
	["links", KEY_A, "Links"],
	["rechts", KEY_D, "Rechts"],
	["rennen", KEY_SHIFT, "Rennen / schneller"],
	["springen", KEY_SPACE, "Springen / Jetpack hoch"],
	["landen", KEY_CTRL, "Jetpack runter"],
	["benutzen", KEY_E, "Benutzen / Ein- und Aussteigen"],
	["werkstatt", KEY_TAB, "Werkstatt"],
	["album", KEY_B, "Album"],
	["karte", KEY_M, "Karte"],
	["penthouse", KEY_P, "Penthouse / Erfolge"],
	["radio", KEY_R, "Gondel-Radio an/aus"],
	["sender", KEY_T, "Radio: nächster Sender"],
	["chat", KEY_ENTER, "Mehrspieler: Chat"],
	["emote", KEY_G, "Mehrspieler: Emote-Rad"],
	["mithelfen", KEY_H, "Mehrspieler: auf einer anderen Seite mithelfen"],
]

static var d := {}
static var aktiv := true           # false: Standardbelegung (Tests, Bot)
static var _pfad := DATEI
static var _belegt := {}           # Standard-Taste → gedrückte Taste
static var _rueck := {}            # gedrückte Taste → Standard-Taste
static var _weg := {}              # Standard-Tasten, die jetzt woanders liegen
static var geaendert_fn: Callable  # wird nach jeder Änderung gerufen (Ton, Grafik)

static var _test_frisch := false

static func laden(test := false) -> void:
	_pfad = TESTDATEI if test else DATEI
	if test and not _test_frisch:   # Tests beginnen immer mit den Standardwerten (einmal je Programmstart)
		_test_frisch = true
		if FileAccess.file_exists(TESTDATEI):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TESTDATEI))
	d = STANDARD.duplicate(true)
	if FileAccess.file_exists(_pfad):
		var j = JSON.parse_string(FileAccess.get_file_as_string(_pfad))
		if j is Dictionary:
			for k in d:
				if j.has(k) and typeof(j[k]) in [TYPE_FLOAT, TYPE_INT, TYPE_BOOL, TYPE_DICTIONARY]:
					d[k] = j[k]
	d.qualitaet = clampi(int(d.qualitaet), 0, 2)
	d.fps = int(d.fps)
	_tasten_bauen()

static func speichern() -> void:
	var f := FileAccess.open(_pfad, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))

static func setzen(schl: String, wert, sichern := true) -> void:
	if d.is_empty():
		laden()
	d[schl] = wert
	if sichern:
		speichern()
	if schl == "tasten":
		_tasten_bauen()
	if geaendert_fn.is_valid():
		geaendert_fn.call(schl)

static func wert(schl: String):
	if d.is_empty():
		laden()
	return d.get(schl, STANDARD.get(schl))

# ---------------------------------------------------------------- Tasten
static func standard_taste(id: String) -> Key:
	for a in AKTIONEN:
		if a[0] == id:
			return a[1]
	return KEY_NONE

static func taste(id: String) -> Key:
	var t: Dictionary = wert("tasten")
	return int(t.get(id, standard_taste(id))) as Key

static func taste_name(id: String) -> String:
	var k := taste(id)
	return {KEY_SHIFT: "Shift", KEY_CTRL: "Strg", KEY_SPACE: "Leertaste", KEY_TAB: "Tab", KEY_ALT: "Alt"}.get(k, OS.get_keycode_string(k))

# Neue Taste für eine Aktion. Liegt die Taste schon auf einer anderen Aktion, tauschen beide.
static func belegen(id: String, k: Key) -> void:
	var t: Dictionary = (wert("tasten") as Dictionary).duplicate()
	var alt := taste(id)
	for a in AKTIONEN:
		if a[0] != id and taste(a[0]) == k:
			t[a[0]] = alt
	t[id] = k
	for a in AKTIONEN:   # Standard = kein Eintrag
		if t.has(a[0]) and int(t[a[0]]) == int(a[1]):
			t.erase(a[0])
	setzen("tasten", t)

static func _tasten_bauen() -> void:
	_belegt.clear()
	_rueck.clear()
	_weg.clear()
	var t: Dictionary = d.get("tasten", {})
	for a in AKTIONEN:
		var echt := int(t.get(a[0], a[1]))
		if echt != int(a[1]):
			_belegt[int(a[1])] = echt
			_rueck[echt] = int(a[1])
			_weg[int(a[1])] = true

# Gedrückte Taste → Standard-Taste ihrer Aktion (für alle Abfragen im Spiel statt e.keycode)
static func k(e: InputEventKey) -> Key:
	var c := int(e.keycode)
	if not aktiv or _rueck.is_empty():
		return c as Key
	if _rueck.has(c):
		return int(_rueck[c]) as Key
	if _weg.has(c):
		return KEY_NONE
	return c as Key

# Ist die Taste der Aktion (angegeben als Standard-Taste) gedrückt?
static func gedrueckt(standard: Key) -> bool:
	if not aktiv:
		return Input.is_key_pressed(standard)
	return Input.is_key_pressed(int(_belegt.get(int(standard), int(standard))) as Key)

# ---------------------------------------------------------------- Maus
# Sichtfeld (Grad) – zu Fuß direkt, in der Gondel 3° mehr (wie vorher 75/78)
const FOV_BEREICH := Vector2(60.0, 110.0)
static func fov() -> float:
	return clampf(float(wert("fov")), FOV_BEREICH.x, FOV_BEREICH.y)

static func maus_x() -> float:
	return float(wert("maus"))

static func maus_y() -> float:
	return float(wert("maus")) * (-1.0 if wert("maus_umkehren") else 1.0)
