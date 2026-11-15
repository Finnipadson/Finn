class_name Wirtschaft
extends RefCounted
# Geld, Werkzeuge und Upgrades. Alle Zahlen zum Ausbalancieren stehen hier oben.

const LOHN_JE_ABSCHNITT := 1      # +1 € pro Fenster je 6 Stockwerke höher
const ABSCHNITT := 6              # Stockwerke pro Seilwinden-Stufe
const START_STOCKWERKE := 6       # so hoch geht es ohne Seilwinde

# rx/ry = Größe der Wisch-Fläche (Halbachsen in m). art: "wisch" = Maus reibt, "spray" = draufhalten
# modell: wie das Werkzeug aussieht (schwamm / abzieher / spray), groesse: Maßstab des Modells
# haendler = true: gibt es nur beim Werkzeug-Kiosk auf dem Platz (nicht in der Werkstatt)
# Tasten: 1–9 und 0 wählen das Werkzeug in dieser Reihenfolge
const WERKZEUGE := [
	{"id": "schwamm", "name": "Schwamm", "text": "Klein, aber gründlich.", "rx": 0.17, "ry": 0.17, "preis": 0, "art": "wisch", "modell": "schwamm", "groesse": 1.0},
	{"id": "grossschwamm", "name": "Großer Schwamm", "text": "Mehr Fläche pro Wisch.", "rx": 0.26, "ry": 0.24, "preis": 20, "art": "wisch", "modell": "schwamm", "groesse": 1.45},
	{"id": "abzieher", "name": "Abzieher", "text": "Breite Gummilippe – am besten waagerecht ziehen.", "rx": 0.42, "ry": 0.11, "preis": 120, "art": "wisch", "modell": "abzieher"},
	{"id": "doppel", "name": "Doppel-Abzieher", "text": "Zwei Lippen, fast doppelt so breit.", "rx": 0.62, "ry": 0.15, "preis": 700, "art": "wisch", "modell": "abzieher", "doppel": true},
	{"id": "hochdruck", "name": "Hochdruckreiniger", "text": "Einfach draufhalten – putzt auch aus der Entfernung.", "rx": 0.32, "ry": 0.32, "preis": 4000, "art": "spray", "modell": "spray", "groesse": 1.0},
	{"id": "mikro", "name": "Mikrofaser-Schwamm", "text": "Weich und riesig – schafft fast doppelt so viel wie der große Schwamm.", "rx": 0.34, "ry": 0.3, "preis": 350, "art": "wisch", "modell": "schwamm", "groesse": 1.9, "haendler": true, "farbe": "6ac7e8"},
	{"id": "profi", "name": "Profi-Schwamm XXL", "text": "So groß wie ein Kissen. Ein Wisch, halbes Fenster.", "rx": 0.48, "ry": 0.4, "preis": 1800, "art": "wisch", "modell": "schwamm", "groesse": 2.7, "haendler": true, "farbe": "ffb03a"},
	{"id": "teleskop", "name": "Teleskop-Abzieher", "text": "1,80 m breite Lippe – zieht ein ganzes Fenster auf einmal ab.", "rx": 0.9, "ry": 0.16, "preis": 3500, "art": "wisch", "modell": "abzieher", "doppel": true, "haendler": true},
	{"id": "dampf", "name": "Dampfreiniger", "text": "Heißer Dampf löst jeden Dreck – breiter als der Hochdruckreiniger.", "rx": 0.5, "ry": 0.5, "preis": 9000, "art": "spray", "modell": "spray", "groesse": 1.3, "haendler": true},
	{"id": "lanze", "name": "Wasserlanze Turbo", "text": "Das Beste vom Besten: riesiger Strahl, putzt im Vorbeifahren.", "rx": 0.75, "ry": 0.7, "preis": 25000, "art": "spray", "modell": "spray", "groesse": 1.6, "haendler": true},
]

const UPGRADES := {
	"motor": {"name": "Gondel-Motor", "text": "Schneller fahren, seitlich und hoch (+50 % je Stufe).", "max": 5, "basis": 25, "faktor": 2.6},
	"arm": {"name": "Teleskoparm", "text": "Größere Reichweite zur Seite und nach oben.", "max": 3, "basis": 60, "faktor": 3.0},
	"winde": {"name": "Seilwinde", "text": "Längeres Seil: 6 Stockwerke höher fahren.", "max": 27, "basis": 40, "faktor": 1.32},
}

# Händler: Boosts wirken eine Zeit lang (Sekunden), Preise steigen mit der erreichten Höhe
const BOOSTS := {
	"glanzspray": {"name": "Glanzspray", "text": "5 Minuten lang wischt jedes Werkzeug 50 % mehr Fläche.", "dauer": 300, "preis": 60, "stand": "putz"},
	"goldpolitur": {"name": "Goldpolitur", "text": "5 Minuten lang doppeltes Geld pro Fenster.", "dauer": 300, "preis": 150, "stand": "putz"},
	"kaffee": {"name": "Kaffee", "text": "4 Minuten lang fährt die Gondel 60 % schneller.", "dauer": 240, "preis": 25, "stand": "snack"},
	"eis": {"name": "Eis", "text": "4 Minuten lang größere Reichweite (+0,8 m).", "dauer": 240, "preis": 30, "stand": "snack"},
	"limo": {"name": "Zitronenlimo", "text": "5 Minuten lang bleiben die Tauben weg – sie mögen den Geruch nicht.", "dauer": 300, "preis": 20, "stand": "snack"},
}
# Aussehen: nur Optik. art = gondel / kleidung / schwamm
const KOSMETIK := [
	{"id": "gondel_gelb", "art": "gondel", "name": "Gondel: Signalgelb", "farbe": "ffc531", "preis": 0},
	{"id": "gondel_rot", "art": "gondel", "name": "Gondel: Feuerrot", "farbe": "e2483e", "preis": 80},
	{"id": "gondel_blau", "art": "gondel", "name": "Gondel: Himmelblau", "farbe": "3a86d4", "preis": 80},
	{"id": "gondel_gruen", "art": "gondel", "name": "Gondel: Mintgrün", "farbe": "3fc29a", "preis": 120},
	{"id": "gondel_pink", "art": "gondel", "name": "Gondel: Neonpink", "farbe": "ff4fb8", "preis": 200},
	{"id": "gondel_gold", "art": "gondel", "name": "Gondel: Gold", "farbe": "e8b53a", "preis": 1500},
	{"id": "kleid_blau", "art": "kleidung", "name": "Jacke: Arbeitsblau", "farbe": "3a86d4", "preis": 0},
	{"id": "kleid_orange", "art": "kleidung", "name": "Jacke: Warnorange", "farbe": "ff8a1e", "preis": 60},
	{"id": "kleid_gruen", "art": "kleidung", "name": "Overall: Grün", "farbe": "3f9d5a", "preis": 60},
	{"id": "kleid_schwarz", "art": "kleidung", "name": "Anzug: Schwarz", "farbe": "2b2d33", "preis": 250},
	{"id": "schwamm_gelb", "art": "schwamm", "name": "Schwamm: Klassisch", "farbe": "ffd84a", "preis": 0},
	{"id": "schwamm_pink", "art": "schwamm", "name": "Schwamm: Pink", "farbe": "ff7ab8", "preis": 40},
	{"id": "schwamm_blau", "art": "schwamm", "name": "Schwamm: Ozean", "farbe": "5ab8ff", "preis": 40},
	{"id": "schwamm_lila", "art": "schwamm", "name": "Schwamm: Lila", "farbe": "9a6ad6", "preis": 40},
]

var geld := 0
var besitz := ["schwamm"]       # gekaufte Werkzeuge
var aktiv := "schwamm"
var stufen := {"motor": 0, "arm": 0, "winde": 0}
var album := {}                 # Szenen-Typ (als Text) -> wie oft entdeckt
var hoechster_abschnitt := 0     # für den Bonus beim ersten Erreichen einer neuen Höhe
var einstellungen := {"tauben": true, "sandsturm": true, "wind": true}
var boosts := {}                                        # Boost-ID -> verbleibende Sekunden
var kosmetik_besitz := ["gondel_gelb", "kleid_blau", "schwamm_gelb"]
var kosmetik_aktiv := {"gondel": "gondel_gelb", "kleidung": "kleid_blau", "schwamm": "schwamm_gelb"}

# ---------------------------------------------------------------- Händler
func boost_preis(id: String) -> int:
	return int(round(BOOSTS[id].preis * (1.0 + 0.35 * hoechster_abschnitt)))

func kaufe_boost(id: String) -> bool:
	var p := boost_preis(id)
	if geld < p:
		return false
	geld -= p
	boosts[id] = float(boosts.get(id, 0.0)) + BOOSTS[id].dauer   # nochmal kaufen verlängert
	return true

func boost_aktiv(id: String) -> bool:
	return float(boosts.get(id, 0.0)) > 0.0

func boosts_takt(dt: float) -> void:
	for id in boosts.keys():
		boosts[id] = float(boosts[id]) - dt
		if boosts[id] <= 0.0:
			boosts.erase(id)

func kosmetik(id: String) -> Dictionary:
	for k in KOSMETIK:
		if k.id == id:
			return k
	return KOSMETIK[0]

func kaufe_kosmetik(id: String) -> bool:
	var k := kosmetik(id)
	if id in kosmetik_besitz or geld < int(k.preis):
		return false
	geld -= int(k.preis)
	kosmetik_besitz.append(id)
	kosmetik_aktiv[k.art] = id
	return true

func nutze_kosmetik(id: String) -> bool:
	if not id in kosmetik_besitz:
		return false
	kosmetik_aktiv[kosmetik(id).art] = id
	return true

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
	return {"geld": geld, "besitz": besitz, "aktiv": aktiv, "stufen": stufen, "album": album, "hoechster_abschnitt": hoechster_abschnitt, "einstellungen": einstellungen, "boosts": boosts, "kosmetik_besitz": kosmetik_besitz, "kosmetik_aktiv": kosmetik_aktiv}

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
	var e: Dictionary = d.get("einstellungen", {})
	for k in einstellungen:
		einstellungen[k] = bool(e.get(k, true))
	boosts = {}
	var bo: Dictionary = d.get("boosts", {})
	for k in bo:
		if BOOSTS.has(str(k)):
			boosts[str(k)] = float(bo[k])
	kosmetik_besitz = []
	for k in d.get("kosmetik_besitz", []):
		kosmetik_besitz.append(str(k))
	for k in ["gondel_gelb", "kleid_blau", "schwamm_gelb"]:
		if not k in kosmetik_besitz:
			kosmetik_besitz.append(k)
	var ka: Dictionary = d.get("kosmetik_aktiv", {})
	for art in kosmetik_aktiv:
		var id := str(ka.get(art, kosmetik_aktiv[art]))
		if id in kosmetik_besitz:
			kosmetik_aktiv[art] = id
	var s: Dictionary = d.get("stufen", {})
	for k in stufen:
		stufen[k] = clampi(int(s.get(k, 0)), 0, UPGRADES[k].max)
