class_name Wirtschaft
extends RefCounted
# Geld, Werkzeuge und Upgrades. Alle Zahlen zum Ausbalancieren stehen hier oben.

const LOHN_JE_ABSCHNITT := 1      # +1 € pro Fenster je 6 Stockwerke höher
const ABSCHNITT := 6              # Stockwerke pro Seilwinden-Stufe
const START_STOCKWERKE := 6       # so hoch geht es ohne Seilwinde

# rx/ry = Größe der Wisch-Fläche (Halbachsen in m). art: "wisch" = Maus reibt, "spray" = draufhalten
# modell: wie das Werkzeug aussieht (schwamm / abzieher / spray), groesse: Maßstab des Modells
# Alle Werkzeuge gibt es an den Kiosken: Grundwerkzeuge am roten Kiosk „Werkzeuge“, profi = true am grünen „Profi-Werkzeuge“
# Tasten: 1–9 und 0 wählen das Werkzeug in dieser Reihenfolge
const WERKZEUGE := [
	{"id": "schwamm", "name": "Schwamm", "text": "Klein, aber gründlich.", "rx": 0.17, "ry": 0.17, "preis": 0, "art": "wisch", "modell": "schwamm", "groesse": 1.0},
	{"id": "grossschwamm", "name": "Großer Schwamm", "text": "Mehr Fläche pro Wisch.", "rx": 0.26, "ry": 0.24, "preis": 20, "art": "wisch", "modell": "schwamm", "groesse": 1.45},
	{"id": "abzieher", "name": "Abzieher", "text": "Breite Gummilippe – am besten waagerecht ziehen.", "rx": 0.42, "ry": 0.11, "preis": 120, "art": "wisch", "modell": "abzieher"},
	{"id": "doppel", "name": "Doppel-Abzieher", "text": "Zwei Lippen, fast doppelt so breit.", "rx": 0.62, "ry": 0.15, "preis": 700, "art": "wisch", "modell": "abzieher", "doppel": true},
	{"id": "hochdruck", "name": "Hochdruckreiniger", "text": "Einfach draufhalten – putzt auch aus der Entfernung.", "rx": 0.32, "ry": 0.32, "preis": 4000, "art": "spray", "modell": "spray", "groesse": 1.0},
	{"id": "mikro", "name": "Mikrofaser-Schwamm", "text": "Weich und riesig – schafft fast doppelt so viel wie der große Schwamm.", "rx": 0.34, "ry": 0.3, "preis": 350, "art": "wisch", "modell": "schwamm", "groesse": 1.9, "profi": true, "farbe": "6ac7e8"},
	{"id": "profi", "name": "Profi-Schwamm XXL", "text": "So groß wie ein Kissen. Ein Wisch, halbes Fenster.", "rx": 0.48, "ry": 0.4, "preis": 1800, "art": "wisch", "modell": "schwamm", "groesse": 2.7, "profi": true, "farbe": "ffb03a"},
	{"id": "teleskop", "name": "Teleskop-Abzieher", "text": "1,80 m breite Lippe – zieht ein ganzes Fenster auf einmal ab.", "rx": 0.9, "ry": 0.16, "preis": 3500, "art": "wisch", "modell": "abzieher", "doppel": true, "profi": true},
	{"id": "dampf", "name": "Dampfreiniger", "text": "Heißer Dampf löst jeden Dreck – breiter als der Hochdruckreiniger.", "rx": 0.9, "ry": 0.9, "preis": 20000, "art": "spray", "modell": "spray", "groesse": 1.3, "profi": true},
	{"id": "lanze", "name": "Wasserlanze Turbo", "text": "Das Beste vom Besten: riesiger Strahl, putzt im Vorbeifahren.", "rx": 1.5, "ry": 1.5, "preis": 60000, "art": "spray", "modell": "spray", "groesse": 1.6, "profi": true},
]

# Gondeln: eine je Turmseite. Die erste ist gratis, die zweite und dritte kosten (Preis nach Anzahl schon gekaufter).
const GONDEL_PREISE := [0, 1000, 5000]

# Helfer putzen nur, solange man spielt, und nur bis zur Seil-Grenze. Kaufpreis steigt je Stück (basis · faktor^Anzahl),
# dazu bekommen sie einen Anteil vom Fensterlohn (anteil). sekunden = Zeit pro Fenster.
# Rechnung (grob, siehe Bauplan): Putzkraft unten ~4 Fenster/min → nach ~20 min bezahlt, Roboter ~10/min, Drohne ~20/min.
const HELFER := {
	"putzkraft": {"name": "Putzkraft", "text": "Fährt mit einer kleinen Gondel an einer Turmseite und putzt Fenster für Fenster (~4 pro Minute). Bekommt 30 % vom Fensterlohn.", "max": 6, "basis": 120, "faktor": 1.6, "anteil": 0.3, "sekunden": 15.0},
	"roboter": {"name": "Putzroboter", "text": "Klettert eine Fensterspalte nach oben und schrubbt sie ab (~10 pro Minute). Bekommt 25 % vom Fensterlohn (Strom).", "max": 3, "basis": 1000, "faktor": 1.9, "anteil": 0.25, "sekunden": 6.0},
	"drohne": {"name": "Putzdrohne", "text": "Fliegt um den ganzen Turm und sprüht Fenster sauber (~20 pro Minute). Bekommt 20 % vom Fensterlohn.", "max": 6, "basis": 6000, "faktor": 1.7, "anteil": 0.2, "sekunden": 3.0},
}

# Fahrzeuge am Boden (Kiosk „Fahrzeuge“), in der Hotbar wählen. tempo in m/s (zu Fuß 4,5, rennen 9)
const FAHRZEUGE := [
	{"id": "scooter", "name": "E-Scooter", "text": "Fährt 13 m/s – fast anderthalbmal so schnell wie Rennen.", "preis": 250, "tempo": 13.0, "farbe": "e2483e"},
	{"id": "hoverboard", "name": "Hoverboard", "text": "Schwebt lautlos über den Platz, 20 m/s.", "preis": 1200, "tempo": 20.0, "farbe": "35c8ff"},
	{"id": "jetpack", "name": "Jetpack", "text": "Fliegen! Leertaste hoch, Strg runter, bis 120 m – über die Häuser hinweg.", "preis": 8000, "tempo": 16.0, "farbe": "ffb03a", "fliegt": true},
]

const UPGRADES := {
	"motor": {"name": "Gondel-Motor", "text": "Schneller fahren, seitlich und hoch (+50 % je Stufe).", "max": 5, "basis": 25, "faktor": 3.2},
	"arm": {"name": "Teleskoparm", "text": "Größere Reichweite zur Seite und nach oben.", "max": 3, "basis": 60, "faktor": 3.0},
	"winde": {"name": "Seilwinde", "text": "Längeres Seil: 6 Stockwerke höher fahren.", "max": 27, "basis": 40, "faktor": 1.32},
}

# Händler: Boosts wirken eine Zeit lang (Sekunden), Preise steigen mit der erreichten Höhe.
# wirkung: lohn/flaeche/tempo/reich/helfer (Anteile, +0,5 = +50 %), tauben = Tauben bleiben weg.
# Laufen mehrere Boosts mit derselben Wirkung, zählt nur der stärkste (Durchspiel-Test: addiert gab es bis zu 11-fachen Lohn).
const BOOSTS := {
	"glanzspray": {"name": "Glanzspray", "text": "5 Minuten lang wischt jedes Werkzeug 50 % mehr Fläche.", "dauer": 300, "preis": 60, "stand": "putz", "wirkung": {"flaeche": 0.5}},
	"goldpolitur": {"name": "Goldpolitur", "text": "5 Minuten lang doppeltes Geld pro Fenster.", "dauer": 300, "preis": 150, "stand": "putz", "wirkung": {"lohn": 1.0}},
	"kaffee": {"name": "Kaffee", "text": "4 Minuten lang fährt die Gondel 60 % schneller.", "dauer": 240, "preis": 25, "stand": "snack", "wirkung": {"tempo": 0.6}},
	"eis": {"name": "Eis", "text": "4 Minuten lang größere Reichweite (+0,8 m).", "dauer": 240, "preis": 30, "stand": "snack", "wirkung": {"reich": 0.8}},
	"limo": {"name": "Zitronenlimo", "text": "5 Minuten lang bleiben die Tauben weg – sie mögen den Geruch nicht.", "dauer": 300, "preis": 20, "stand": "snack", "wirkung": {"tauben": 1.0}},
	# Sky-Lounge: stärkere Spezial-Boosts. wirkung: lohn/flaeche/tempo/reich/helfer (Anteile, +0,5 = +50 %), tauben = Tauben bleiben weg
	"cocktail": {"name": "Sky-Cocktail", "text": "10 Minuten lang +50 % Geld pro Fenster.", "dauer": 600, "preis": 220, "stand": "bar", "wirkung": {"lohn": 0.5}},
	"mojito": {"name": "Minz-Mojito", "text": "10 Minuten lang +80 % Wischfläche.", "dauer": 600, "preis": 160, "stand": "bar", "wirkung": {"flaeche": 0.8}},
	"espresso": {"name": "Espresso doppio", "text": "8 Minuten lang fährt die Gondel doppelt so schnell und die Helfer putzen 50 % schneller.", "dauer": 480, "preis": 140, "stand": "bar", "wirkung": {"tempo": 1.0, "helfer": 0.5}},
	"mittag": {"name": "Mittagsmenü", "text": "15 Minuten: +50 % Wischfläche, +60 % Tempo, +0,8 m Reichweite und keine Tauben.", "dauer": 900, "preis": 380, "stand": "restaurant", "wirkung": {"flaeche": 0.5, "tempo": 0.6, "reich": 0.8, "tauben": 1.0}},
	"chefmenue": {"name": "Menü des Küchenchefs", "text": "15 Minuten lang doppeltes Geld pro Fenster und +50 % Wischfläche.", "dauer": 900, "preis": 700, "stand": "restaurant", "wirkung": {"lohn": 1.0, "flaeche": 0.5}},
	"champagner": {"name": "Gipfel-Champagner", "text": "20 Minuten lang dreifaches Geld pro Fenster, Helfer doppelt so schnell.", "dauer": 1200, "preis": 1500, "stand": "gipfel", "wirkung": {"lohn": 2.0, "helfer": 1.0}},
	# Strandbar: Angel-Wirkungen zappeln (Fisch zappelt langsamer), selten (seltene beißen öfter), kasten (Fangkasten größer),
	# biss (Wartezeit kürzer), fischpreis (mehr Geld beim Verkaufen) – plus bekannte Cocktails
	"kokos": {"name": "Kokos-Shake", "text": "10 Minuten lang zappeln die Fische 30 % langsamer.", "dauer": 600, "preis": 30, "stand": "strandbar", "wirkung": {"zappeln": 0.3}},
	"mango": {"name": "Mango-Smoothie", "text": "10 Minuten lang beißen seltene Fische viel öfter.", "dauer": 600, "preis": 45, "stand": "strandbar", "wirkung": {"selten": 0.6}},
	"ananas": {"name": "Ananas-Eistee", "text": "10 Minuten lang ist der Fangkasten 25 % größer.", "dauer": 600, "preis": 30, "stand": "strandbar", "wirkung": {"kasten": 0.25}},
	"limette": {"name": "Limetten-Soda", "text": "10 Minuten lang beißen die Fische doppelt so schnell an.", "dauer": 600, "preis": 25, "stand": "strandbar", "wirkung": {"biss": 0.5}},
	"pina": {"name": "Piña Colada", "text": "15 Minuten: Fische zappeln 20 % langsamer, Fangkasten 20 % größer.", "dauer": 900, "preis": 80, "stand": "strandbar", "wirkung": {"zappeln": 0.2, "kasten": 0.2}},
	"lagoon": {"name": "Blue Lagoon", "text": "15 Minuten: seltene Fische beißen öfter, Wartezeit 30 % kürzer.", "dauer": 900, "preis": 90, "stand": "strandbar", "wirkung": {"selten": 0.4, "biss": 0.3}},
	"sunrise": {"name": "Tequila Sunrise", "text": "15 Minuten lang zahlt der Fischladen 50 % mehr.", "dauer": 900, "preis": 70, "stand": "strandbar", "wirkung": {"fischpreis": 0.5}},
	"caipi": {"name": "Caipirinha", "text": "10 Minuten lang +30 % Geld pro Fenster – für den Rückweg zum Turm.", "dauer": 600, "preis": 120, "stand": "strandbar", "wirkung": {"lohn": 0.3}},
}

# ---------------------------------------------------------------- Angeln (Steg + Fischladen am Strand)
# 20 Fische (Golf/Arabisches Meer), je seltener desto größer; chance in %, preis = Grundpreis (steigt mit der Höhe wie
# die Boosts). Angeln ist ein kleiner Zusatzverdienst – nie lohnender als Fenster putzen (mit dem Durchspiel-Bot gemessen).
const FISCHE := [
	{"id": "sergeant", "name": "Sergeant-Fisch", "groesse": 0.15, "chance": 17.0, "preis": 1, "text": "Fünf schwarze Streifen wie ein Uniform-Ärmel."},
	{"id": "koffer", "name": "Kofferfisch", "groesse": 0.2, "chance": 15.0, "preis": 1, "text": "Eckig wie ein kleiner Koffer – schwimmt trotzdem."},
	{"id": "sohal", "name": "Sohal-Doktorfisch", "groesse": 0.3, "chance": 12.5, "preis": 1, "text": "Hat am Schwanz ein scharfes „Skalpell“."},
	{"id": "igel", "name": "Igelfisch", "groesse": 0.3, "chance": 10.5, "preis": 1, "text": "Bläst sich bei Gefahr zur Stachelkugel auf."},
	{"id": "wimpel", "name": "Wimpelfisch", "groesse": 0.2, "chance": 8.5, "preis": 1, "text": "Trägt eine lange weiße Fahne auf dem Rücken."},
	{"id": "papagei", "name": "Papageifisch", "groesse": 0.4, "chance": 7.0, "preis": 1, "text": "Knabbert Korallen – und macht daraus Sand."},
	{"id": "kaiser", "name": "Arabischer Kaiserfisch", "groesse": 0.4, "chance": 6.0, "preis": 2, "text": "Dunkelblau mit einem großen gelben Fleck."},
	{"id": "trompete", "name": "Trompetenfisch", "groesse": 0.6, "chance": 5.0, "preis": 2, "text": "Lang und dünn – saugt seine Beute ein."},
	{"id": "feuer", "name": "Rotfeuerfisch", "groesse": 0.35, "chance": 4.0, "preis": 2, "text": "Prächtige Flossen voller Giftstacheln."},
	{"id": "hornhecht", "name": "Hornhecht", "groesse": 0.7, "chance": 3.3, "preis": 3, "text": "Springt über die Wellen, Schnabel voller Zähne."},
	{"id": "barrakuda", "name": "Barrakuda", "groesse": 1.2, "chance": 2.7, "preis": 4, "text": "Der Torpedo des Riffs."},
	{"id": "adlerrochen", "name": "Adlerrochen", "groesse": 1.5, "chance": 2.2, "preis": 5, "text": "Fliegt mit weißen Punkten durchs Wasser."},
	{"id": "muraene", "name": "Riesenmuräne", "groesse": 2.0, "chance": 1.7, "preis": 6, "text": "Wohnt in Felsspalten und schaut grimmig."},
	{"id": "gitarre", "name": "Gitarrenrochen", "groesse": 2.5, "chance": 1.3, "preis": 8, "text": "Vorne Rochen, hinten Hai."},
	{"id": "napoleon", "name": "Napoleon-Lippfisch", "groesse": 2.0, "chance": 1.0, "preis": 10, "text": "Riesig, mit Beule auf der Stirn."},
	{"id": "segel", "name": "Segelfisch", "groesse": 3.0, "chance": 0.8, "preis": 15, "text": "Schnellster Fisch der Welt, mit Riesensegel."},
	{"id": "manta", "name": "Riesenmanta", "groesse": 6.0, "chance": 0.6, "preis": 25, "text": "Sechs Meter Spannweite – sanft wie ein Drache."},
	{"id": "quaste", "name": "Quastenflosser", "groesse": 2.0, "chance": 0.4, "preis": 40, "text": "Ein lebendes Fossil aus der Urzeit."},
	{"id": "saege", "name": "Sägefisch", "groesse": 5.0, "chance": 0.3, "preis": 60, "text": "Trägt eine Säge vor der Nase."},
	{"id": "walhai", "name": "Walhai", "groesse": 10.0, "chance": 0.2, "preis": 100, "text": "Der größte Fisch der Welt – und ganz friedlich."},
]
const RIESEN_AB := 15            # ab dem Segelfisch (Index 15) braucht man die Hochsee-Angel
# kasten = Größe des Fangkastens (Anteil des Balkens), selten = seltene Fische beißen öfter
const ANGELN := [
	{"id": "bambus", "name": "Bambus-Angel", "text": "Einfach und billig. Kleiner Fangkasten.", "preis": 150, "kasten": 0.22, "selten": 0.0},
	{"id": "carbon", "name": "Carbon-Angel", "text": "Leicht und stark: größerer Fangkasten.", "preis": 1500, "kasten": 0.3, "selten": 0.0},
	{"id": "hochsee", "name": "Hochsee-Angel", "text": "Seltene Fische beißen öfter. Nötig für die Riesen ab dem Segelfisch.", "preis": 8000, "kasten": 0.3, "selten": 0.4, "riesen": true},
]
const YACHT_SELTEN := 0.3        # draußen auf dem Meer mit der Yacht: seltene Fische beißen öfter

# ---------------------------------------------------------------- Penthouse: Möbel + Arcade-Gegenstände
# Seltenheit 0–3: gewöhnlich, selten, episch, legendär. Bonus wirkt nur, wenn der Gegenstand im Penthouse steht.
const SELTENHEIT := ["Gewöhnlich", "Selten", "Episch", "Legendär"]
const SELTEN_FARBE := ["c9d3dd", "4aa8ff", "b36bff", "ffc531"]
const SELTEN_BONUS := [0.02, 0.05, 0.10, 0.20]
const BONUS_MAX := 1.0                     # alle Gegenstände zusammen höchstens +100 % je Art
const BONUS_ARTEN := {"lohn": "Geld pro Fenster", "flaeche": "Wischfläche", "tempo": "Gondel-Tempo", "helfer": "Helfer-Tempo", "boost": "Boost-Dauer"}
# quelle: katalog (Tablet im Penthouse), designer (Restaurant 500 m), exklusiv (Plattform 800 m), arcade (Automaten)
# modell = Datei in modelle/moebel, s = Maßstab, farbe = Einfärbung (Arcade-Plüsch), bonus = Art, wert = Stärke (sonst aus der Seltenheit)
const GEGENSTAENDE := {
	"sofa": {"name": "Sofa", "modell": "loungeSofa", "quelle": "katalog", "preis": 400},
	"sofa_ecke": {"name": "Ecksofa", "modell": "loungeSofaCorner", "quelle": "katalog", "preis": 650},
	"sessel": {"name": "Sessel", "modell": "loungeChair", "quelle": "katalog", "preis": 220},
	"couchtisch": {"name": "Couchtisch aus Glas", "modell": "tableCoffeeGlass", "quelle": "katalog", "preis": 180},
	"esstisch": {"name": "Esstisch", "modell": "tableCloth", "quelle": "katalog", "preis": 300},
	"stuhl": {"name": "Stuhl", "modell": "chairCushion", "quelle": "katalog", "preis": 80},
	"bett": {"name": "Doppelbett", "modell": "bedDouble", "quelle": "katalog", "preis": 900, "bonus": "boost"},
	"fernseher": {"name": "Fernseher", "modell": "televisionModern", "quelle": "katalog", "preis": 700, "bonus": "helfer"},
	"tv_schrank": {"name": "TV-Schrank", "modell": "cabinetTelevision", "quelle": "katalog", "preis": 250},
	"regal": {"name": "Bücherregal", "modell": "bookcaseOpen", "quelle": "katalog", "preis": 300, "bonus": "flaeche"},
	"stehlampe": {"name": "Stehlampe", "modell": "lampRoundFloor", "quelle": "katalog", "preis": 120},
	"pflanze": {"name": "Zimmerpflanze", "modell": "pottedPlant", "quelle": "katalog", "preis": 90},
	"teppich": {"name": "Runder Teppich", "modell": "rugRound", "quelle": "katalog", "preis": 150},
	"schreibtisch": {"name": "Schreibtisch", "modell": "desk", "quelle": "katalog", "preis": 350, "bonus": "lohn"},
	"buerostuhl": {"name": "Bürostuhl", "modell": "chairDesk", "quelle": "katalog", "preis": 160},
	"kueche": {"name": "Küchenzeile", "modell": "kitchenFridgeLarge", "quelle": "katalog", "preis": 800, "bonus": "tempo"},
	"bar_hocker": {"name": "Barhocker", "modell": "stoolBar", "quelle": "katalog", "preis": 70},
	"design_sofa": {"name": "Designer-Sofa", "modell": "loungeDesignSofa", "quelle": "designer", "preis": 6000, "seltenheit": 1, "bonus": "lohn"},
	"design_sessel": {"name": "Designer-Sessel", "modell": "loungeDesignChair", "quelle": "designer", "preis": 3500, "seltenheit": 1, "bonus": "tempo"},
	"design_tisch": {"name": "Glastisch quadratisch", "modell": "tableCoffeeGlassSquare", "quelle": "designer", "preis": 2500, "seltenheit": 1, "bonus": "flaeche"},
	"design_lampe": {"name": "Designer-Leuchte", "modell": "lampSquareFloor", "quelle": "designer", "preis": 2000, "seltenheit": 1, "bonus": "boost"},
	"design_bett": {"name": "Himmelbett", "modell": "bedDouble", "quelle": "exklusiv", "preis": 40000, "seltenheit": 2, "bonus": "helfer", "farbe": "e8e2d4"},
	"gold_sofa": {"name": "Goldenes Ecksofa", "modell": "loungeDesignSofaCorner", "quelle": "exklusiv", "preis": 60000, "seltenheit": 2, "bonus": "lohn", "farbe": "e8b53a"},
	"gold_fluegel": {"name": "Weißer Konzertflügel-Tisch", "modell": "tableRound", "quelle": "exklusiv", "preis": 30000, "seltenheit": 2, "bonus": "flaeche", "farbe": "f4f4f4"},
	# Arcade (Greifautomat + Kapsel-Automat) – je Seltenheit jede Bonus-Art einmal
	"teddy": {"name": "Teddy", "modell": "bear", "quelle": "arcade", "seltenheit": 0, "bonus": "lohn", "s": 0.85},
	"kissen": {"name": "Kuschelkissen", "modell": "pillow", "quelle": "arcade", "seltenheit": 0, "bonus": "boost", "s": 1.3, "farbe": "ff9ad5"},
	"radio": {"name": "Kofferradio", "modell": "radio", "quelle": "arcade", "seltenheit": 0, "bonus": "tempo", "s": 0.7},
	"pflanze_klein": {"name": "Mini-Kaktus", "modell": "plantSmall1", "quelle": "arcade", "seltenheit": 0, "bonus": "flaeche", "s": 1.7},
	"tischlampe": {"name": "Tischlampe", "modell": "lampRoundTable", "quelle": "arcade", "seltenheit": 0, "bonus": "helfer", "s": 1.0},
	"teddy_blau": {"name": "Blauer Teddy", "modell": "bear", "quelle": "arcade", "seltenheit": 1, "bonus": "lohn", "s": 1.06, "farbe": "4aa8ff"},
	"retro_tv": {"name": "Retro-Fernseher", "modell": "televisionVintage", "quelle": "arcade", "seltenheit": 1, "bonus": "helfer"},
	"lautsprecher": {"name": "Lautsprecher", "modell": "speaker", "quelle": "arcade", "seltenheit": 1, "bonus": "tempo"},
	"bonsai": {"name": "Bonsai", "modell": "plantSmall3", "quelle": "arcade", "seltenheit": 1, "bonus": "flaeche", "s": 2.0},
	"kissen_blau": {"name": "Riesenkissen", "modell": "pillowBlueLong", "quelle": "arcade", "seltenheit": 1, "bonus": "boost", "s": 1.3},
	"teddy_lila": {"name": "Riesen-Teddy Lila", "modell": "bear", "quelle": "arcade", "seltenheit": 2, "bonus": "lohn", "s": 1.7, "farbe": "b36bff"},
	"neon_lampe": {"name": "Neon-Stehlampe", "modell": "lampSquareFloor", "quelle": "arcade", "seltenheit": 2, "bonus": "flaeche", "farbe": "ff4fb8"},
	"relax_sessel": {"name": "Relax-Sessel", "modell": "loungeChairRelax", "quelle": "arcade", "seltenheit": 2, "bonus": "tempo", "farbe": "35c8ff"},
	"hifi": {"name": "Hi-Fi-Turm", "modell": "speaker", "quelle": "arcade", "seltenheit": 2, "bonus": "helfer", "s": 1.2, "farbe": "2b2d33"},
	"ottomane": {"name": "Samt-Ottomane", "modell": "loungeSofaOttoman", "quelle": "arcade", "seltenheit": 2, "bonus": "boost", "farbe": "7a1428"},
	"teddy_gold": {"name": "Goldener Teddy", "modell": "bear", "quelle": "arcade", "seltenheit": 3, "bonus": "lohn", "s": 1.27, "farbe": "gold"},
	"palme_gold": {"name": "Goldene Palme", "modell": "pottedPlant", "quelle": "arcade", "seltenheit": 3, "bonus": "flaeche", "s": 1.6, "farbe": "gold"},
	"thron": {"name": "Goldener Thron", "modell": "chairRounded", "quelle": "arcade", "seltenheit": 3, "bonus": "tempo", "s": 1.4, "farbe": "gold"},
	"gold_tv": {"name": "Goldener Fernseher", "modell": "televisionModern", "quelle": "arcade", "seltenheit": 3, "bonus": "helfer", "farbe": "gold"},
	"gold_uhr": {"name": "Goldene Stehlampe", "modell": "lampRoundFloor", "quelle": "arcade", "seltenheit": 3, "bonus": "boost", "s": 1.3, "farbe": "gold"},
	# Möbelhaus (begehbar, Ausstellungsräume): zusätzlich zu den Katalog-Möbeln. raum = Ausstellungsraum (MOEBELHAUS_RAEUME)
	"sofa_lang": {"name": "Langes Sofa", "modell": "loungeSofaLong", "quelle": "moebelhaus", "preis": 750, "raum": "wohnen", "bonus": "boost"},
	"beistelltisch": {"name": "Beistelltisch", "modell": "sideTableDrawers", "quelle": "moebelhaus", "preis": 140, "raum": "wohnen"},
	"glastisch": {"name": "Glas-Esstisch", "modell": "tableGlass", "quelle": "moebelhaus", "preis": 480, "raum": "kueche"},
	"designstuhl": {"name": "Designerstuhl", "modell": "chairModernFrameCushion", "quelle": "moebelhaus", "preis": 160, "raum": "kueche"},
	"einzelbett": {"name": "Einzelbett", "modell": "bedSingle", "quelle": "moebelhaus", "preis": 450, "raum": "schlafen"},
	"nachttisch": {"name": "Nachttisch", "modell": "cabinetBedDrawerTable", "quelle": "moebelhaus", "preis": 110, "raum": "schlafen"},
	"kleiderschrank": {"name": "Kleiderschrank", "modell": "bookcaseClosedDoors", "quelle": "moebelhaus", "preis": 520, "raum": "schlafen", "bonus": "helfer"},
	"etagenbett": {"name": "Etagenbett", "modell": "bedBunk", "quelle": "moebelhaus", "preis": 600, "raum": "schlafen"},
	"herd": {"name": "Herd", "modell": "kitchenStove", "quelle": "moebelhaus", "preis": 650, "raum": "kueche", "bonus": "tempo"},
	"spuele": {"name": "Spüle", "modell": "kitchenSink", "quelle": "moebelhaus", "preis": 420, "raum": "kueche"},
	"kuechenbar": {"name": "Kücheninsel", "modell": "kitchenBar", "quelle": "moebelhaus", "preis": 380, "raum": "kueche"},
	"badewanne": {"name": "Whirlpool-Wanne", "modell": "bathtub", "quelle": "moebelhaus", "preis": 4500, "raum": "bad", "seltenheit": 1, "bonus": "boost"},
	"dusche": {"name": "Regendusche", "modell": "shower", "quelle": "moebelhaus", "preis": 1400, "raum": "bad", "bonus": "flaeche"},
	"waschbecken": {"name": "Waschtisch", "modell": "bathroomSinkSquare", "quelle": "moebelhaus", "preis": 360, "raum": "bad"},
	"toilette": {"name": "Toilette", "modell": "toiletSquare", "quelle": "moebelhaus", "preis": 300, "raum": "bad"},
	"waschturm": {"name": "Waschmaschine + Trockner", "modell": "washerDryerStacked", "quelle": "moebelhaus", "preis": 900, "raum": "bad"},
	"eckschreibtisch": {"name": "Eck-Schreibtisch", "modell": "deskCorner", "quelle": "moebelhaus", "preis": 3200, "raum": "buero", "seltenheit": 1, "bonus": "lohn"},
	"aktenschrank": {"name": "Aktenschrank", "modell": "bookcaseClosedWide", "quelle": "moebelhaus", "preis": 450, "raum": "buero"},
	"garderobe": {"name": "Garderobe", "modell": "coatRackStanding", "quelle": "moebelhaus", "preis": 100, "raum": "licht"},
	# Souvenirshop: je ein Andenken pro Meilenstein (erfolg = Erfolg-ID), erst danach kaufbar, nur einmal. Modelle aus Code (Andenken)
	"sv_postkarten": {"name": "Postkarten-Ständer", "modell": "code:postkarten", "quelle": "souvenir", "preis": 50, "erfolg": "fenster_10", "einmal": true},
	"sv_schneekugel": {"name": "Schneekugel Wüstennadel", "modell": "code:schneekugel", "quelle": "souvenir", "preis": 120, "erfolg": "fenster_100", "einmal": true, "bonus": "boost"},
	"sv_taube": {"name": "Porzellan-Taube", "modell": "code:taube", "quelle": "souvenir", "preis": 90, "erfolg": "album_1", "einmal": true, "bonus": "helfer"},
	"sv_nadel": {"name": "Mini-Wüstennadel", "modell": "code:nadel", "quelle": "souvenir", "preis": 200, "erfolg": "hoehe_100", "einmal": true, "bonus": "lohn"},
	"sv_wuerfel": {"name": "Casino-Würfel", "modell": "code:wuerfel", "quelle": "souvenir", "preis": 150, "erfolg": "casino_1", "einmal": true},
	"sv_fontaene": {"name": "Fontänen-Modell", "modell": "code:fontaene", "quelle": "souvenir", "preis": 250, "erfolg": "lounge", "einmal": true, "bonus": "flaeche"},
	"sv_gondel": {"name": "Mini-Gondel", "modell": "code:gondel", "quelle": "souvenir", "preis": 300, "erfolg": "gondeln", "einmal": true, "bonus": "tempo"},
	"sv_sanduhr": {"name": "Wüstensand-Uhr", "modell": "code:sanduhr", "quelle": "souvenir", "preis": 300, "erfolg": "zeit_1h", "einmal": true},
	"sv_wolken": {"name": "Wolken-Schneekugel", "modell": "code:wolkenkugel", "quelle": "souvenir", "preis": 400, "erfolg": "hoehe_300", "einmal": true, "seltenheit": 1, "bonus": "flaeche"},
	"sv_schwamm": {"name": "Goldener Schwamm", "modell": "code:schwamm", "quelle": "souvenir", "preis": 600, "erfolg": "fenster_1000", "einmal": true, "seltenheit": 1, "bonus": "lohn"},
	"sv_rahmen": {"name": "Szenen-Bilderrahmen", "modell": "code:rahmen", "quelle": "souvenir", "preis": 700, "erfolg": "album_alle", "einmal": true, "seltenheit": 1, "bonus": "helfer"},
	"sv_kristall": {"name": "Kristall-Nadel", "modell": "code:kristall", "quelle": "souvenir", "preis": 800, "erfolg": "hoehe_oben", "einmal": true, "seltenheit": 1, "bonus": "tempo"},
	# Goldschmuck-Laden neben dem Casino: legendäre Gold-Deko fürs Penthouse, je nur einmal (Preise nach dem Durchspiel-Test halbiert: insgesamt verdient man ~0,5 Mio. €)
	"gold_barren": {"name": "Goldbarren-Stapel", "modell": "code:barren", "quelle": "gold", "preis": 10000, "seltenheit": 3, "bonus": "lohn", "einmal": true},
	"gold_leuchter": {"name": "Goldener Kandelaber", "modell": "code:leuchter", "quelle": "gold", "preis": 22000, "seltenheit": 3, "bonus": "boost", "einmal": true},
	"gold_statue": {"name": "Statue „Der Fensterputzer“", "modell": "code:statue", "quelle": "gold", "preis": 40000, "seltenheit": 3, "bonus": "helfer", "einmal": true},
	"gold_nadel": {"name": "Goldene Wüstennadel", "modell": "code:goldnadel", "quelle": "gold", "preis": 75000, "seltenheit": 3, "bonus": "tempo", "einmal": true},
	"gold_globus": {"name": "Goldener Globus", "modell": "code:globus", "quelle": "gold", "preis": 125000, "seltenheit": 3, "bonus": "flaeche", "einmal": true},
	"gold_brunnen": {"name": "Goldener Springbrunnen", "modell": "code:brunnen", "quelle": "gold", "preis": 250000, "seltenheit": 3, "bonus": "lohn", "einmal": true},
}
# Möbelhaus: Ausstellungsräume (Reihenfolge = Lage im Laden). Katalog-Möbel bekommen ihren Raum über KATALOG_RAUM.
const MOEBELHAUS_RAEUME := [
	{"id": "wohnen", "name": "Wohnzimmer", "farbe": "c9a27a"},
	{"id": "schlafen", "name": "Schlafzimmer", "farbe": "9fb4d6"},
	{"id": "kueche", "name": "Küche & Essen", "farbe": "e4d3b0"},
	{"id": "bad", "name": "Badezimmer", "farbe": "b8dfe0"},
	{"id": "buero", "name": "Arbeitszimmer", "farbe": "a7b79a"},
	{"id": "licht", "name": "Licht & Pflanzen", "farbe": "e9c9a8"},
]
const KATALOG_RAUM := {"sofa": "wohnen", "sofa_ecke": "wohnen", "sessel": "wohnen", "couchtisch": "wohnen", "teppich": "wohnen",
	"fernseher": "wohnen", "tv_schrank": "wohnen", "esstisch": "kueche", "stuhl": "kueche", "kueche": "kueche", "bar_hocker": "kueche",
	"bett": "schlafen", "regal": "buero", "schreibtisch": "buero", "buerostuhl": "buero", "stehlampe": "licht", "pflanze": "licht"}
# Arcade: Preise steigen mit der erreichten Höhe (wie die Boosts). Kapsel-Chancen je Seltenheit.
const ARCADE := {
	"greif": {"name": "Greifautomat", "preis": 40},
	"kapsel": {"name": "Kapsel-Automat", "preis": 100},
}
const KAPSEL_CHANCE := [0.70, 0.22, 0.07, 0.01]
const VERKAUF_ANTEIL := 0.25               # doppelte Gegenstände: so viel vom Wert gibt es beim Verkaufen
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
	# Gondel-Werkstatt (nur Optik): Lackierung (Muster über der Gondelfarbe), Aufkleber, Blumenkästen, Sonnenschirm
	{"id": "lack_uni", "art": "lack", "name": "Einfarbig", "text": "Nur die Grundfarbe.", "farbe": "c9d3dd", "preis": 0},
	{"id": "lack_streifen", "art": "lack", "name": "Rennstreifen", "text": "Zwei weiße Streifen der Länge nach.", "farbe": "ffffff", "preis": 300},
	{"id": "lack_punkte", "art": "lack", "name": "Tupfen", "text": "Weiße Punkte auf der Grundfarbe.", "farbe": "ff9ad5", "preis": 250},
	{"id": "lack_karo", "art": "lack", "name": "Zielflagge", "text": "Schwarz-weißes Karomuster wie im Rennsport.", "farbe": "2b2d33", "preis": 600},
	{"id": "lack_tarn", "art": "lack", "name": "Wüstentarn", "text": "Sandfarbene Flecken – passt zur Wüste.", "farbe": "c9955a", "preis": 900},
	{"id": "lack_karbon", "art": "lack", "name": "Karbon", "text": "Schwarzes Kohlefaser-Geflecht, glänzt leicht.", "farbe": "3a3d44", "preis": 1800},
	{"id": "lack_chrom", "art": "lack", "name": "Spiegel-Chrom", "text": "Hochglanz-Metall in der Grundfarbe.", "farbe": "e6eef5", "preis": 3500},
	{"id": "kleber_keine", "art": "aufkleber", "name": "Keine Aufkleber", "text": "", "farbe": "c9d3dd", "preis": 0},
	{"id": "kleber_herz", "art": "aufkleber", "name": "Herzen", "text": "Rote Herzen an den Seitenwänden.", "farbe": "e2483e", "preis": 80},
	{"id": "kleber_stern", "art": "aufkleber", "name": "Sterne", "text": "Goldene Sterne an den Seitenwänden.", "farbe": "ffc531", "preis": 80},
	{"id": "kleber_blitz", "art": "aufkleber", "name": "Blitze", "text": "Blitze für die schnellste Gondel am Turm.", "farbe": "35c8ff", "preis": 120},
	{"id": "kleber_smiley", "art": "aufkleber", "name": "Smileys", "text": "Gute Laune an der Fassade.", "farbe": "ffd84a", "preis": 120},
	{"id": "kleber_palme", "art": "aufkleber", "name": "Palmen", "text": "Urlaubsgefühl in 500 m Höhe.", "farbe": "3fc29a", "preis": 200},
	{"id": "kleber_logo", "art": "aufkleber", "name": "Wüstennadel-Logo", "text": "Das offizielle Logo des Turms mit Schriftzug.", "farbe": "b36bff", "preis": 300},
	{"id": "blumen_keine", "art": "blumen", "name": "Keine Blumenkästen", "text": "", "farbe": "c9d3dd", "preis": 0},
	{"id": "blumen_rot", "art": "blumen", "name": "Rote Blumen", "text": "Zwei Kästen mit roten Blüten am hinteren Geländer.", "farbe": "e2483e", "preis": 150},
	{"id": "blumen_lila", "art": "blumen", "name": "Lavendel", "text": "Lila Blüten, duften nach Urlaub.", "farbe": "b36bff", "preis": 150},
	{"id": "blumen_bunt", "art": "blumen", "name": "Bunte Mischung", "text": "Rot, Gelb und Lila durcheinander.", "farbe": "ffc531", "preis": 250},
	{"id": "blumen_gruen", "art": "blumen", "name": "Grüne Büsche", "text": "Kleine Buchsbäume in Kästen.", "farbe": "3f9d5a", "preis": 120},
	{"id": "blumen_palme", "art": "blumen", "name": "Mini-Palmen", "text": "Zwei kleine Palmen in Kübeln – Dubai-Stil.", "farbe": "7fe08a", "preis": 900},
	{"id": "schirm_keiner", "art": "schirm", "name": "Kein Sonnenschirm", "text": "", "farbe": "c9d3dd", "preis": 0},
	{"id": "schirm_streifen", "art": "schirm", "name": "Strandschirm gestreift", "text": "Rot-weiß gestreift, an der Seitenwand befestigt.", "farbe": "e2483e", "preis": 400},
	{"id": "schirm_uni", "art": "schirm", "name": "Sonnenschirm Sand", "text": "Schlicht und modern.", "farbe": "e4d3b0", "preis": 300},
	{"id": "schirm_gold", "art": "schirm", "name": "Goldener Schirm", "text": "Glänzt in der Sonne – für echte Profis.", "farbe": "e8b53a", "preis": 2500},
]
const KOSMETIK_START := ["gondel_gelb", "kleid_blau", "schwamm_gelb", "lack_uni", "kleber_keine", "blumen_keine", "schirm_keiner"]

var geld := 0
var besitz := ["schwamm"]       # gekaufte Werkzeuge
var aktiv := "schwamm"
var stufen := {"motor": 0, "arm": 0, "winde": 0}
var album := {}                 # Szenen-Typ (als Text) -> wie oft entdeckt
var hoechster_abschnitt := 0     # für den Bonus beim ersten Erreichen einer neuen Höhe
var einstellungen := {"tauben": true, "sandsturm": true, "wind": true, "taa": false}
var boosts := {}                                        # Boost-ID -> verbleibende Sekunden
var kosmetik_besitz: Array = KOSMETIK_START.duplicate()
var kosmetik_aktiv := {"gondel": "gondel_gelb", "kleidung": "kleid_blau", "schwamm": "schwamm_gelb", "lack": "lack_uni", "aufkleber": "kleber_keine", "blumen": "blumen_keine", "schirm": "schirm_keiner"}
var helfer := {"putzkraft": 0, "roboter": 0, "drohne": 0}
var fahrzeuge: Array = []                               # gekaufte Fahrzeug-IDs
var fahrzeug := ""                                      # "" = zu Fuß
# Gondeln je Seite: gekauft, Weg (Parkplatz unten) und Höhe, auf der man zuletzt war (Express-Fahrt beim Einsteigen)
var gondeln: Array = [{"gekauft": false, "weg": -1.0, "hoehe": 0.0}, {"gekauft": false, "weg": -1.0, "hoehe": 0.0}, {"gekauft": false, "weg": -1.0, "hoehe": 0.0}]
var aktive_gondel := -1                                 # Seite der Gondel, in der man sitzt (-1 = noch keine)
# Penthouse: jeder Gegenstand einzeln {id, steht, x, z, dreh} (x/z im Penthouse, dreh in Grad)
var moebel: Array = []
var erfolge := {}                                       # Erfolg-ID -> true
var besucht: Array = []                                 # besuchte Orte (lounge, restaurant, plattform, arcade, penthouse)
var statistik := {"spielzeit": 0.0, "fenster_selbst": 0, "fenster_helfer": 0, "verdient": 0, "hoechste": 0.0, "rekord_minute": 0,
	"sitzung_rekord": 0.0, "gelaufen": 0.0, "casino_spiele": 0, "casino_bilanz": 0, "casino_rekord": 0, "arcade_spiele": 0,
	"arcade_gewinne": 0, "boosts": 0, "erfolg_geld": 0, "fische": 0, "fisch_geld": 0, "angel_zeit": 0.0}
var angeln: Array = []                                  # gekaufte Angeln (ANGELN-ids)
var fischkiste := {}                                    # Fisch-ID -> Anzahl (noch nicht verkauft)
var fisch_index := {}                                   # Fisch-ID -> {n = so oft gefangen, max = größte Länge in m}
var yacht := false                                      # Belohnung für alle 20 Fische

# ---------------------------------------------------------------- Angeln
static func fisch(id: String) -> Dictionary:
	for f in FISCHE:
		if f.id == id:
			return f
	return {}

static func fisch_nr(id: String) -> int:
	for i in FISCHE.size():
		if FISCHE[i].id == id:
			return i
	return -1

static func angel_daten(id: String) -> Dictionary:
	for a in ANGELN:
		if a.id == id:
			return a
	return {}

# beste gekaufte Angel ("" = keine)
func angel() -> String:
	var beste := ""
	for a in ANGELN:
		if a.id in angeln:
			beste = a.id
	return beste

func kaufe_angel(id: String) -> bool:
	var a := angel_daten(id)
	if a.is_empty() or id in angeln or geld < int(a.preis):
		return false
	geld -= int(a.preis)
	angeln.append(id)
	return true

func fisch_preis(id: String) -> int:
	return maxi(1, int(round(float(fisch(id).get("preis", 1)) * (1.0 + 0.35 * hoechster_abschnitt) * (1.0 + boost_wirkung("fischpreis")))))

# Chancen (Summe 1) mit „seltene beißen öfter“: Gewicht wächst mit dem Rang (der seltenste bekommt den vollen Zuschlag)
static func fisch_chancen(selten: float) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	var summe := 0.0
	for i in FISCHE.size():
		var w: float = float(FISCHE[i].chance) * (1.0 + selten * pow(float(i) / (FISCHE.size() - 1), 1.5))
		g.append(w)
		summe += w
	for i in g.size():
		g[i] /= summe
	return g

static func fisch_ziehen(selten: float, r: float) -> String:
	var g := fisch_chancen(selten)
	var s := 0.0
	for i in g.size():
		s += g[i]
		if r < s:
			return FISCHE[i].id
	return FISCHE[0].id

# Fang eintragen: Kiste + Index (größte Länge). true = neue Art
func fisch_gefangen(id: String, laenge: float) -> bool:
	fischkiste[id] = int(fischkiste.get(id, 0)) + 1
	var neu := not fisch_index.has(id)
	var e: Dictionary = fisch_index.get(id, {"n": 0, "max": 0.0})
	fisch_index[id] = {"n": int(e.n) + 1, "max": maxf(float(e.max), laenge)}
	statistik.fische = int(statistik.fische) + 1
	return neu

func fische_in_kiste() -> int:
	var n := 0
	for id in fischkiste:
		n += int(fischkiste[id])
	return n

# Fische einer Art verkaufen (anzahl < 0 = alle); gibt den Erlös zurück
func verkaufe_fisch(id: String, anzahl := -1) -> int:
	var da := int(fischkiste.get(id, 0))
	var n := da if anzahl < 0 else mini(anzahl, da)
	if n <= 0:
		return 0
	var erloes := n * fisch_preis(id)
	fischkiste[id] = da - n
	if int(fischkiste[id]) <= 0:
		fischkiste.erase(id)
	verdienen(erloes)
	statistik.fisch_geld = int(statistik.fisch_geld) + erloes
	return erloes

func verkaufe_alle_fische() -> int:
	var s := 0
	for id in fischkiste.keys():
		s += verkaufe_fisch(str(id))
	return s

func index_voll() -> bool:
	return fisch_index.size() >= FISCHE.size()

# ---------------------------------------------------------------- Händler
func boost_preis(id: String) -> int:
	return int(round(BOOSTS[id].preis * (1.0 + 0.35 * hoechster_abschnitt)))

func kaufe_boost(id: String) -> bool:
	var p := boost_preis(id)
	if geld < p:
		return false
	geld -= p
	boosts[id] = float(boosts.get(id, 0.0)) + BOOSTS[id].dauer * (1.0 + bonus("boost"))   # nochmal kaufen verlängert
	statistik.boosts = int(statistik.boosts) + 1
	return true

func boost_aktiv(id: String) -> bool:
	return float(boosts.get(id, 0.0)) > 0.0

# Wirkung (lohn, flaeche, tempo, reich, helfer, tauben) der laufenden Boosts: nur der stärkste zählt, nichts addiert sich
func boost_wirkung(art: String) -> float:
	var s := 0.0
	for id in boosts:
		s = maxf(s, float((BOOSTS[id].get("wirkung", {}) as Dictionary).get(art, 0.0)))
	return s

# ---------------------------------------------------------------- Penthouse-Gegenstände
func gegenstand(id: String) -> Dictionary:
	return GEGENSTAENDE.get(id, {})

func seltenheit(id: String) -> int:
	return int(gegenstand(id).get("seltenheit", 0))

# Bonus eines Gegenstands als Anteil (0,05 = +5 %), 0 = nur Deko
func gegenstand_bonus(id: String) -> float:
	var g := gegenstand(id)
	if not g.has("bonus"):
		return 0.0
	return float(g.get("wert", SELTEN_BONUS[int(g.get("seltenheit", 0))]))

# Summe der Boni aller aufgestellten Gegenstände einer Art (höchstens BONUS_MAX)
func bonus(art: String) -> float:
	var s := 0.0
	for m in moebel:
		if m.steht and str(gegenstand(m.id).get("bonus", "")) == art:
			s += gegenstand_bonus(m.id)
	return minf(s, BONUS_MAX)

func gegenstand_preis(id: String) -> int:
	return int(gegenstand(id).get("preis", 0))

# Darf man den Gegenstand gerade kaufen? "" = ja, sonst der Grund (Souvenir noch gesperrt, schon gekauft)
func kauf_sperre(id: String) -> String:
	var g := gegenstand(id)
	if g.is_empty():
		return "unbekannt"
	if g.has("erfolg") and not erfolge.has(str(g.erfolg)):
		return "gesperrt"
	if g.get("einmal", false) and anzahl_gegenstand(id) > 0:
		return "besitz"
	return ""

# Ausstellungsraum im Möbelhaus ("" = nicht im Möbelhaus)
func moebel_raum(id: String) -> String:
	return str(gegenstand(id).get("raum", KATALOG_RAUM.get(id, "")))

func kaufe_gegenstand(id: String) -> bool:
	var p := gegenstand_preis(id)
	if kauf_sperre(id) != "" or geld < p:
		return false
	geld -= p
	moebel.append({"id": id, "steht": false, "x": 0.0, "z": 0.0, "dreh": 0.0})
	return true

func bekomme_gegenstand(id: String) -> void:
	moebel.append({"id": id, "steht": false, "x": 0.0, "z": 0.0, "dreh": 0.0})

func anzahl_gegenstand(id: String) -> int:
	var n := 0
	for m in moebel:
		if m.id == id:
			n += 1
	return n

# Wert beim Verkaufen eines Gegenstands (Arcade-Sachen nach Seltenheit)
func verkaufswert(id: String) -> int:
	var p := float(gegenstand_preis(id))
	if p == 0.0:
		p = [100.0, 400.0, 1500.0, 6000.0][seltenheit(id)] * (1.0 + 0.35 * hoechster_abschnitt)
	return int(round(p * VERKAUF_ANTEIL))

func arcade_preis(id: String) -> int:
	return int(round(ARCADE[id].preis * (1.0 + 0.35 * hoechster_abschnitt)))

# Zufälliger Arcade-Gegenstand einer Seltenheit
func zufall_gegenstand(stufe: int) -> String:
	var l := []
	for id in GEGENSTAENDE:
		if GEGENSTAENDE[id].quelle == "arcade" and int(GEGENSTAENDE[id].seltenheit) == stufe:
			l.append(id)
	return l[randi() % l.size()]

func kapsel_stufe(r: float) -> int:
	var summe := 0.0
	for i in KAPSEL_CHANCE.size():
		summe += KAPSEL_CHANCE[i]
		if r < summe:
			return i
	return 0

# ---------------------------------------------------------------- Statistik
func verdienen(betrag: int) -> void:
	geld += betrag
	statistik.verdient = int(statistik.verdient) + betrag

func casino_runde(einsatz: int, auszahlung: int) -> void:
	statistik.casino_spiele = int(statistik.casino_spiele) + 1
	statistik.casino_bilanz = int(statistik.casino_bilanz) + auszahlung - einsatz
	statistik.casino_rekord = maxi(int(statistik.casino_rekord), auszahlung - einsatz)

func besuchen(ort: String) -> bool:
	if ort in besucht:
		return false
	besucht.append(ort)
	return true

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

# ---------------------------------------------------------------- Gondeln, Helfer, Fahrzeuge
func gondeln_gekauft() -> int:
	var n := 0
	for g in gondeln:
		if g.gekauft:
			n += 1
	return n

func gondel_preis() -> int:
	return GONDEL_PREISE[mini(gondeln_gekauft(), GONDEL_PREISE.size() - 1)]

func kaufe_gondel(seite: int) -> bool:
	if gondeln[seite].gekauft or geld < gondel_preis():
		return false
	geld -= gondel_preis()
	gondeln[seite].gekauft = true
	return true

func helfer_preis(id: String) -> int:
	var h: Dictionary = HELFER[id]
	return int(round(h.basis * pow(h.faktor, helfer[id])))

func helfer_voll(id: String) -> bool:
	return helfer[id] >= HELFER[id].max

func kaufe_helfer(id: String) -> bool:
	if helfer_voll(id) or geld < helfer_preis(id):
		return false
	geld -= helfer_preis(id)
	helfer[id] += 1
	return true

func fahrzeug_daten(id: String) -> Dictionary:
	for f in FAHRZEUGE:
		if f.id == id:
			return f
	return {}

func kaufe_fahrzeug(id: String) -> bool:
	var f := fahrzeug_daten(id)
	if f.is_empty() or id in fahrzeuge or geld < int(f.preis):
		return false
	geld -= int(f.preis)
	fahrzeuge.append(id)
	fahrzeug = id
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
	return {"geld": geld, "besitz": besitz, "aktiv": aktiv, "stufen": stufen, "album": album, "hoechster_abschnitt": hoechster_abschnitt, "einstellungen": einstellungen, "boosts": boosts, "kosmetik_besitz": kosmetik_besitz, "kosmetik_aktiv": kosmetik_aktiv, "helfer": helfer, "fahrzeuge": fahrzeuge, "fahrzeug": fahrzeug, "gondeln": gondeln, "aktive_gondel": aktive_gondel, "moebel": moebel, "erfolge": erfolge, "besucht": besucht, "statistik": statistik,
		"angeln": angeln, "fischkiste": fischkiste, "fisch_index": fisch_index, "yacht": yacht}

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
		einstellungen[k] = bool(e.get(k, einstellungen[k]))
	boosts = {}
	var bo: Dictionary = d.get("boosts", {})
	for k in bo:
		if BOOSTS.has(str(k)):
			boosts[str(k)] = float(bo[k])
	kosmetik_besitz = []
	for k in d.get("kosmetik_besitz", []):
		if kosmetik(str(k)).id == str(k):
			kosmetik_besitz.append(str(k))
	for k in KOSMETIK_START:
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
	var he: Dictionary = d.get("helfer", {})
	for k in helfer:
		helfer[k] = clampi(int(he.get(k, 0)), 0, HELFER[k].max)
	fahrzeuge = []
	for f in d.get("fahrzeuge", []):
		if not fahrzeug_daten(str(f)).is_empty():
			fahrzeuge.append(str(f))
	fahrzeug = str(d.get("fahrzeug", ""))
	if not fahrzeug in fahrzeuge:
		fahrzeug = ""
	var gl: Array = d.get("gondeln", [])
	for i in mini(gl.size(), 3):
		var g: Dictionary = gl[i]
		gondeln[i] = {"gekauft": bool(g.get("gekauft", false)), "weg": float(g.get("weg", -1.0)), "hoehe": float(g.get("hoehe", 0.0))}
	aktive_gondel = int(d.get("aktive_gondel", -1))
	moebel = []
	for m in d.get("moebel", []):
		if m is Dictionary and GEGENSTAENDE.has(str(m.get("id", ""))):
			moebel.append({"id": str(m.id), "steht": bool(m.get("steht", false)), "x": float(m.get("x", 0.0)), "z": float(m.get("z", 0.0)), "dreh": float(m.get("dreh", 0.0))})
	erfolge = {}
	for k in d.get("erfolge", {}):
		erfolge[str(k)] = true
	besucht = []
	for o in d.get("besucht", []):
		besucht.append(str(o))
	var st: Dictionary = d.get("statistik", {})
	for k in statistik:
		if st.has(k):
			statistik[k] = float(st[k]) if statistik[k] is float else int(st[k])
	angeln = []
	for a in d.get("angeln", []):
		if not angel_daten(str(a)).is_empty() and not str(a) in angeln:
			angeln.append(str(a))
	fischkiste = {}
	var fk: Dictionary = d.get("fischkiste", {})
	for k in fk:
		if not fisch(str(k)).is_empty() and int(fk[k]) > 0:
			fischkiste[str(k)] = int(fk[k])
	fisch_index = {}
	var fi: Dictionary = d.get("fisch_index", {})
	for k in fi:
		if not fisch(str(k)).is_empty() and fi[k] is Dictionary:
			fisch_index[str(k)] = {"n": int(fi[k].get("n", 1)), "max": float(fi[k].get("max", 0.0))}
	yacht = bool(d.get("yacht", false)) or index_voll()
