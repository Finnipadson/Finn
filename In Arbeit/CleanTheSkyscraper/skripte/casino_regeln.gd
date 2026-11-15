class_name CasinoRegeln
extends RefCounted
# Regeln und Zahlen der vier Casino-Spiele (ohne Oberfläche, damit man sie testen und ausbalancieren kann).
# Gespielt wird nur mit Spielgeld. Alle Spiele sind leicht zugunsten des Hauses (Rückzahlung rund 95 %).

const EINSATZ_MIN := 10
const EINSATZ_MAX := 5000
const ANTEIL := 0.1              # höchstens so viel vom eigenen Geld pro Runde
const STUFEN := [10, 20, 50, 100, 200, 500, 1000, 2000, 5000]

# Höchster erlaubter Einsatz (0 = zu wenig Geld zum Spielen)
static func max_einsatz(geld: int) -> int:
	if geld < EINSATZ_MIN:
		return 0
	return clampi(int(geld * ANTEIL) / 10 * 10, EINSATZ_MIN, EINSATZ_MAX)   # auf 10 € abgerundet

# ---------------------------------------------------------------- Glücksrad
# 32 gleich große Felder: 16× 0, 5× 0,5, 6× 1, 2× 2, 1× 3, 1× 5, 1× 10  → Rückzahlung 95,3 %
const RAD := [0.0, 1.0, 0.0, 0.5, 0.0, 2.0, 0.0, 1.0, 0.0, 0.5, 0.0, 3.0, 0.0, 1.0, 0.0, 0.5,
	0.0, 5.0, 0.0, 1.0, 0.0, 0.5, 0.0, 2.0, 0.0, 1.0, 0.0, 0.5, 0.0, 10.0, 0.0, 1.0]

static func rad_farbe(m: float) -> Color:
	if m >= 10.0: return Color("f2c230")
	if m >= 5.0: return Color("d84f9a")
	if m >= 3.0: return Color("e08a1e")
	if m >= 2.0: return Color("2e8b3d")
	if m >= 1.0: return Color("2f86c8")
	if m > 0.0: return Color("7a8aa0")
	return Color("2c3340")

static func mal(m: float) -> String:
	if m == 0.5:
		return "½×"
	return "%d×" % int(m)

# ---------------------------------------------------------------- Einarmiger Bandit
const SYMBOLE := ["schwamm", "eimer", "fenster", "gondel", "taube"]
const SYMBOL_NAMEN := {"schwamm": "Schwamm", "eimer": "Eimer", "fenster": "Fenster", "gondel": "Gondel", "taube": "Taube"}
const DREI := {"schwamm": 10.0, "eimer": 15.0, "fenster": 25.0, "gondel": 45.0, "taube": 0.0}
const ZWEI := 0.5                # zwei gleiche (keine Tauben): halber Einsatz zurück

# Auszahlung als Vielfaches des Einsatzes  → Rückzahlung 95,2 %
static func walzen_gewinn(a: int, b: int, c: int) -> float:
	if a == b and b == c:
		return float(DREI[SYMBOLE[a]])
	var paar := -1
	if a == b or a == c:
		paar = a
	elif b == c:
		paar = b
	if paar >= 0 and SYMBOLE[paar] != "taube":
		return ZWEI
	return 0.0

# ---------------------------------------------------------------- Rubbellos
const LOS_WERTE := [1.0, 2.0, 5.0, 10.0, 20.0, 50.0]
# Gewinnstufen [Vielfaches, Wahrscheinlichkeit]  → Rückzahlung 97 %, etwa 39 % der Lose gewinnen
const LOS_STUFEN := [[1.0, 0.2], [2.0, 0.12], [5.0, 0.05], [10.0, 0.018], [50.0, 0.002]]

# 9 Felder mit Beträgen (als Vielfaches des Lospreises). Drei gleiche = dieser Betrag ist gewonnen.
static func los(rng: RandomNumberGenerator) -> Dictionary:
	var gewinn := 0.0
	var w := rng.randf()
	for s in LOS_STUFEN:
		var p: float = s[1]
		if w < p:
			gewinn = s[0]
			break
		w -= p
	var felder: Array = []
	if gewinn > 0.0:
		for i in 3:
			felder.append(gewinn)
	var topf: Array = []          # alle anderen Beträge höchstens zweimal
	for v in LOS_WERTE:
		if v != gewinn:
			topf.append(v)
			topf.append(v)
	while felder.size() < 9:
		var k := rng.randi() % topf.size()
		felder.append(topf[k])
		topf.remove_at(k)
	for i in range(8, 0, -1):     # mischen
		var j := rng.randi() % (i + 1)
		var t = felder[i]
		felder[i] = felder[j]
		felder[j] = t
	return {"felder": felder, "gewinn": gewinn}

# ---------------------------------------------------------------- Blackjack
const RAENGE := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "B", "D", "K"]
const FARBEN := ["♠", "♥", "♦", "♣"]

static func karte(rng: RandomNumberGenerator) -> Dictionary:
	return {"rang": rng.randi() % 13, "farbe": rng.randi() % 4}

static func karten_text(k: Dictionary) -> String:
	return "%s%s" % [RAENGE[int(k.rang)], FARBEN[int(k.farbe)]]

# Wert einer Hand: Bilder 10, Ass 11 oder 1
static func wert(hand: Array) -> int:
	var summe := 0
	var asse := 0
	for k in hand:
		var r := int(k.rang)
		if r == 0:
			asse += 1
			summe += 11
		else:
			summe += mini(r + 1, 10)
	while summe > 21 and asse > 0:
		summe -= 10
		asse -= 1
	return summe

static func ist_blackjack(hand: Array) -> bool:
	return hand.size() == 2 and wert(hand) == 21

# Auszahlung als Vielfaches des Einsatzes (0 verloren, 1 unentschieden, 2 gewonnen, 2,5 Blackjack = 3:2)
static func bj_auszahlung(spieler: Array, geber: Array) -> float:
	var s := wert(spieler)
	var g := wert(geber)
	if s > 21:
		return 0.0
	if ist_blackjack(spieler):
		return 1.0 if ist_blackjack(geber) else 2.5
	if ist_blackjack(geber):
		return 0.0
	if g > 21 or s > g:
		return 2.0
	if s == g:
		return 1.0
	return 0.0

# Geber zieht, bis er 17 oder mehr hat
static func geber_zieht(geber: Array, rng: RandomNumberGenerator) -> void:
	while wert(geber) < 17:
		geber.append(karte(rng))

# ---------------------------------------------------------------- Rückzahlung messen (für Tests)
static func messen(spiel: String, runden: int, rng: RandomNumberGenerator) -> float:
	var summe := 0.0
	for i in runden:
		match spiel:
			"rad":
				summe += float(RAD[rng.randi() % RAD.size()])
			"bandit":
				summe += walzen_gewinn(rng.randi() % 5, rng.randi() % 5, rng.randi() % 5)
			"los":
				summe += float(los(rng).gewinn)
			"blackjack":      # einfache Spielweise: ziehen bis 17 (bei 12–16 gegen schwache Geberkarte stehen)
				var s: Array = [karte(rng), karte(rng)]
				var g: Array = [karte(rng), karte(rng)]
				if not ist_blackjack(s) and not ist_blackjack(g):
					var offen := mini(int(g[0].rang) + 1, 10)
					var grenze := 12 if (offen >= 2 and offen <= 6) else 17
					while wert(s) < grenze:
						s.append(karte(rng))
					if wert(s) <= 21:
						geber_zieht(g, rng)
				summe += bj_auszahlung(s, g)
	return summe / runden
