class_name Wirtschaft
extends RefCounted
# Geld, Werkzeuge und Upgrades. Alle Zahlen zum Ausbalancieren stehen hier oben.

const LOHN_JE_ABSCHNITT := 1      # +1 € pro Fenster je 6 Stockwerke höher
const ABSCHNITT := 6              # Stockwerke pro Seilwinden-Stufe
const START_STOCKWERKE := 6       # so hoch geht es ohne Seilwinde

# rx/ry = Größe der Wisch-Fläche (Halbachsen in m). art: "wisch" = Maus reibt, "spray" = draufhalten
const WERKZEUGE := [
	{"id": "schwamm", "name": "Schwamm", "text": "Klein, aber gründlich.", "rx": 0.17, "ry": 0.17, "preis": 0, "art": "wisch"},
	{"id": "grossschwamm", "name": "Großer Schwamm", "text": "Mehr Fläche pro Wisch.", "rx": 0.26, "ry": 0.24, "preis": 20, "art": "wisch"},
	{"id": "abzieher", "name": "Abzieher", "text": "Breite Gummilippe – am besten waagerecht ziehen.", "rx": 0.42, "ry": 0.11, "preis": 120, "art": "wisch"},
	{"id": "doppel", "name": "Doppel-Abzieher", "text": "Zwei Lippen, fast doppelt so breit.", "rx": 0.62, "ry": 0.15, "preis": 700, "art": "wisch"},
	{"id": "hochdruck", "name": "Hochdruckreiniger", "text": "Einfach draufhalten – putzt auch aus der Entfernung.", "rx": 0.32, "ry": 0.32, "preis": 4000, "art": "spray"},
]

const UPGRADES := {
	"motor": {"name": "Gondel-Motor", "text": "Schneller fahren, seitlich und hoch (+50 % je Stufe).", "max": 5, "basis": 25, "faktor": 2.6},
	"arm": {"name": "Teleskoparm", "text": "Größere Reichweite zur Seite und nach oben.", "max": 3, "basis": 60, "faktor": 3.0},
	"winde": {"name": "Seilwinde", "text": "Längeres Seil: 6 Stockwerke höher fahren.", "max": 27, "basis": 40, "faktor": 1.32},
}

var geld := 0
var besitz := ["schwamm"]       # gekaufte Werkzeuge
var aktiv := "schwamm"
var stufen := {"motor": 0, "arm": 0, "winde": 0}
var album := {}                 # Szenen-Typ (als Text) -> wie oft entdeckt
var hoechster_abschnitt := 0     # für den Bonus beim ersten Erreichen einer neuen Höhe

func lohn(stockwerk: int) -> int:
	return 1 + LOHN_JE_ABSCHNITT * (stockwerk / ABSCHNITT)

func werkzeug(id := "") -> Dictionary:
	var gesucht := aktiv if id == "" else id
	for w in WERKZEUGE:
		if w.id == gesucht:
			return w
	return WERKZEUGE[0]

func upgrade_preis(id: String) -> int:
	var u: Dictionary = UPGRADES[id]
	return int(round(u.basis * pow(u.faktor, stufen[id])))

func upgrade_voll(id: String) -> bool:
	return stufen[id] >= UPGRADES[id].max

func kaufe_upgrade(id: String) -> bool:
	if upgrade_voll(id) or geld < upgrade_preis(id):
		return false
	geld -= upgrade_preis(id)
	stufen[id] += 1
	return true

func kaufe_werkzeug(id: String) -> bool:
	var w := werkzeug(id)
	if id in besitz or geld < int(w.preis):
		return false
	geld -= int(w.preis)
	besitz.append(id)
	aktiv = id
	return true

func ausruesten(id: String) -> bool:
	if id in besitz:
		aktiv = id
		return true
	return false

# ---------------------------------------------------------------- abgeleitete Werte
func tempo_faktor() -> float:
	return 1.0 + 0.5 * stufen.motor

func reichweite_seite() -> float:
	return 1.8 + 0.6 * stufen.arm

func reichweite_oben() -> float:
	return 2.9 + 0.5 * stufen.arm

func oberstes_stockwerk() -> int:
	return mini(Turm.STOCKWERKE, START_STOCKWERKE + ABSCHNITT * stufen.winde)

# ---------------------------------------------------------------- Speichern
func speichern() -> Dictionary:
	return {"geld": geld, "besitz": besitz, "aktiv": aktiv, "stufen": stufen, "album": album, "hoechster_abschnitt": hoechster_abschnitt}

func laden(d: Dictionary) -> void:
	geld = int(d.get("geld", 0))
	besitz = []
	for b in d.get("besitz", ["schwamm"]):
		besitz.append(str(b))
	if not "schwamm" in besitz:
		besitz.append("schwamm")
	aktiv = str(d.get("aktiv", "schwamm"))
	if not aktiv in besitz:
		aktiv = "schwamm"
	album = {}
	var al: Dictionary = d.get("album", {})
	for k in al:
		album[str(k)] = int(al[k])
	hoechster_abschnitt = int(d.get("hoechster_abschnitt", 0))
	var s: Dictionary = d.get("stufen", {})
	for k in stufen:
		stufen[k] = clampi(int(s.get(k, 0)), 0, UPGRADES[k].max)
