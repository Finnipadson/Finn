class_name Erfolge
extends RefCounted
# Erfolge: jeder gibt einmalig Geld und einen Pokal (Bronze/Silber/Gold) in der Vitrine des Penthouses.
# wert = Schlüssel aus werte(), ziel = ab diesem Wert ist der Erfolg geschafft.

const POKAL := ["Bronze", "Silber", "Gold"]
const POKAL_FARBE := ["c8814a", "c9d1da", "f2c14e"]

const LISTE := [
	{"id": "fenster_10", "name": "Durchblick", "text": "10 Fenster sauber", "wert": "fenster", "ziel": 10, "geld": 100, "pokal": 0},
	{"id": "fenster_100", "name": "Fleißig", "text": "100 Fenster sauber", "wert": "fenster", "ziel": 100, "geld": 500, "pokal": 0},
	{"id": "fenster_1000", "name": "Glasklar", "text": "1.000 Fenster sauber", "wert": "fenster", "ziel": 1000, "geld": 2500, "pokal": 1},
	{"id": "fenster_5000", "name": "Fassaden-Profi", "text": "5.000 Fenster sauber", "wert": "fenster", "ziel": 5000, "geld": 10000, "pokal": 1},
	{"id": "fenster_alle", "name": "Die Wüstennadel glänzt", "text": "Alle Fenster des Turms sauber", "wert": "alle", "ziel": 1, "geld": 50000, "pokal": 2},
	{"id": "hoehe_100", "name": "Schwindelfrei", "text": "100 m Höhe erreicht", "wert": "hoehe", "ziel": 100, "geld": 300, "pokal": 0},
	{"id": "hoehe_300", "name": "Über den Wolken", "text": "300 m Höhe erreicht", "wert": "hoehe", "ziel": 300, "geld": 3000, "pokal": 1},
	{"id": "hoehe_oben", "name": "Ganz oben", "text": "Mit der Gondel bis unters Dach (700 m)", "wert": "hoehe", "ziel": 700, "geld": 25000, "pokal": 2},
	{"id": "geld_10k", "name": "Erstes Erspartes", "text": "10.000 € verdient", "wert": "verdient", "ziel": 10000, "geld": 1000, "pokal": 0},
	{"id": "geld_100k", "name": "Gut im Geschäft", "text": "100.000 € verdient", "wert": "verdient", "ziel": 100000, "geld": 5000, "pokal": 1},
	{"id": "geld_1m", "name": "Millionär", "text": "1.000.000 € verdient", "wert": "verdient", "ziel": 1000000, "geld": 30000, "pokal": 2},
	{"id": "album_1", "name": "Neugierig", "text": "Die erste Szene hinter einem Fenster entdeckt", "wert": "album", "ziel": 1, "geld": 200, "pokal": 0},
	{"id": "album_alle", "name": "Sammler", "text": "Alle Szenen im Sammelalbum", "wert": "album", "ziel": 10, "geld": 10000, "pokal": 2},
	{"id": "casino_1", "name": "Glückspilz", "text": "Im Casino eine Runde gewonnen", "wert": "casino_rekord", "ziel": 1, "geld": 200, "pokal": 0},
	{"id": "casino_gross", "name": "Jackpot", "text": "5.000 € auf einmal im Casino gewonnen", "wert": "casino_rekord", "ziel": 5000, "geld": 2000, "pokal": 1},
	{"id": "arcade_1", "name": "Erwischt!", "text": "Den ersten Gewinn aus einem Arcade-Automaten", "wert": "arcade", "ziel": 1, "geld": 300, "pokal": 0},
	{"id": "arcade_legende", "name": "Legendär", "text": "Einen legendären Gegenstand gewonnen", "wert": "legendaer", "ziel": 1, "geld": 10000, "pokal": 2},
	{"id": "lounge", "name": "Sky-Lounge", "text": "Mit dem Express-Aufzug in die Sky-Lounge (200 m)", "wert": "lounge", "ziel": 1, "geld": 1000, "pokal": 0},
	{"id": "restaurant", "name": "Dinner mit Aussicht", "text": "Das Restaurant auf 500 m besucht", "wert": "restaurant", "ziel": 1, "geld": 5000, "pokal": 1},
	{"id": "plattform", "name": "Auf der Nadelspitze", "text": "Die Aussichtsplattform auf 800 m besucht", "wert": "plattform", "ziel": 1, "geld": 20000, "pokal": 2},
	{"id": "moebel_5", "name": "Eingerichtet", "text": "5 Gegenstände im Penthouse aufgestellt", "wert": "moebel", "ziel": 5, "geld": 1000, "pokal": 0},
	{"id": "moebel_20", "name": "Traumwohnung", "text": "20 Gegenstände im Penthouse aufgestellt", "wert": "moebel", "ziel": 20, "geld": 5000, "pokal": 1},
	{"id": "helfer_1", "name": "Chef", "text": "Den ersten Helfer eingestellt", "wert": "helfer", "ziel": 1, "geld": 500, "pokal": 0},
	{"id": "helfer_alle", "name": "Großunternehmen", "text": "Alle 15 Helfer eingestellt", "wert": "helfer", "ziel": 15, "geld": 20000, "pokal": 2},
	{"id": "gondeln", "name": "Drei Seiten", "text": "Alle drei Gondeln gekauft", "wert": "gondeln", "ziel": 3, "geld": 1500, "pokal": 1},
	{"id": "jetpack", "name": "Abheben", "text": "Das Jetpack gekauft", "wert": "jetpack", "ziel": 1, "geld": 3000, "pokal": 1},
	{"id": "werkzeuge", "name": "Voll ausgerüstet", "text": "Alle 10 Werkzeuge gekauft", "wert": "werkzeuge", "ziel": 10, "geld": 15000, "pokal": 2},
	{"id": "zeit_1h", "name": "Dranbleiben", "text": "1 Stunde gespielt", "wert": "spielzeit", "ziel": 3600, "geld": 1000, "pokal": 0},
	{"id": "zeit_10h", "name": "Turm-Veteran", "text": "10 Stunden gespielt", "wert": "spielzeit", "ziel": 36000, "geld": 10000, "pokal": 1},
	{"id": "fisch_1", "name": "Petri Heil", "text": "Den ersten Fisch gefangen", "wert": "fischarten", "ziel": 1, "geld": 100, "pokal": 0},
	{"id": "fisch_10", "name": "Fischkenner", "text": "10 Fischarten im Fisch-Index", "wert": "fischarten", "ziel": 10, "geld": 1500, "pokal": 1},
	{"id": "fisch_alle", "name": "Meister-Angler", "text": "Alle 20 Fische gefangen (die Yacht gehört dir)", "wert": "fischarten", "ziel": 20, "geld": 10000, "pokal": 2},
]

# Alle Werte, die Erfolge prüfen (sauber/gesamt kommen aus dem Fenster-Zustand)
static func werte(w: Wirtschaft, sauber: int, gesamt: int) -> Dictionary:
	var st := w.statistik
	var legendaer := 0
	var steht := 0
	for m in w.moebel:
		if w.seltenheit(m.id) == 3 and w.gegenstand(m.id).quelle == "arcade":
			legendaer += 1
		if m.steht:
			steht += 1
	var helfer := 0
	for k in w.helfer:
		helfer += int(w.helfer[k])
	return {
		"fenster": int(st.fenster_selbst) + int(st.fenster_helfer),
		"alle": 1 if sauber >= gesamt and gesamt > 0 else 0,
		"hoehe": float(st.hoechste),
		"verdient": int(st.verdient),
		"album": w.album.size(),
		"casino_rekord": int(st.casino_rekord),
		"arcade": int(st.arcade_gewinne),
		"legendaer": legendaer,
		"lounge": 1 if "lounge" in w.besucht else 0,
		"restaurant": 1 if "restaurant" in w.besucht else 0,
		"plattform": 1 if "plattform" in w.besucht else 0,
		"moebel": steht,
		"helfer": helfer,
		"gondeln": w.gondeln_gekauft(),
		"jetpack": 1 if "jetpack" in w.fahrzeuge else 0,
		"werkzeuge": w.besitz.size(),
		"spielzeit": float(st.spielzeit),
		"fischarten": w.fisch_index.size(),
	}

# Neu geschaffte Erfolge: eintragen, Geld gutschreiben, Liste zurückgeben
static func pruefen(w: Wirtschaft, sauber: int, gesamt: int) -> Array:
	var v := werte(w, sauber, gesamt)
	var neu := []
	for e in LISTE:
		if w.erfolge.has(e.id):
			continue
		if float(v[e.wert]) >= float(e.ziel):
			w.erfolge[e.id] = true
			w.geld += int(e.geld)
			w.statistik.erfolg_geld = int(w.statistik.erfolg_geld) + int(e.geld)
			neu.append(e)
	return neu

static func daten(id: String) -> Dictionary:
	for e in LISTE:
		if e.id == id:
			return e
	return {}
