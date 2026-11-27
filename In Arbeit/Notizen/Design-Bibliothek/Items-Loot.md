# Items-Loot

Zurück: [[Design-Bibliothek]]

## Bewährte Muster

- **Seltenheit in 5 Stufen** mit gelernten Farben: Grau (gewöhnlich) · Grün · Blau · Lila · Orange/Gold (legendär). Häufigkeit ungefähr 60 / 25 / 10 / 4 / 1 %.
- **Seltene Drops feiern:** eigener Sound, Lichtstrahl oder Leuchten, kurzes Innehalten. Je seltener, desto mehr Aufwand.
- **Vergleichs-Tooltip:** Neues Item neben dem ausgerüsteten, Unterschiede grün (+) oder rot (−).
- **Auswahl aus 3:** Bei Upgrades 3 Optionen anbieten (Roguelite-Standard). Bei 2 gibt es zu wenig Wahl, ab 4 wird es zu viel zum Lesen.
- **Symbol + Farbe + Rahmen:** Ein Item muss schon am Umriss erkennbar sein, die Farbe zeigt die Seltenheit.
- **Belohnung vorher zeigen:** Symbol an der Tür oder dem Pfad, was dort wartet. Der Spieler entscheidet dann bewusst.
- **Shop:** Preis immer sichtbar; was man sich nicht leisten kann, ausgrauen statt verstecken (macht Lust aufs Sparen).

## Fallen

- Werte steigen pro Stufe zu stark → alte Items sind sofort Müll und das Sammeln fühlt sich sinnlos an.
- Zu viele Währungen auf einmal (max. 2–3).

## Referenzen

### Steal An Egg – Ei-Shop (Roblox)

![[stealanegg-ei-shop.jpg]]

- **Was ist gut:** Alle möglichen Inhalte sind direkt mit **Prozentzahlen** sichtbar und von links nach rechts nach Seltenheit sortiert. Das seltenste Tier (0,5 %) ist am größten dargestellt, hat einen Regenbogenrahmen und das Etikett „DIVINE“. Countdown oben rechts plus „Begrenzte Zeit!“ erzeugen Dringlichkeit. Mengenrabatt in 4 Stufen (1/3/10/50); beim größten Paket steht der alte Preis durchgestrichen daneben. Neben jedem Preis ein Geschenk-Button.
- **Prinzip zum Übernehmen:** Die Chancen offen zeigen und den Hauptpreis groß als Köder rechts platzieren. Kaufbuttons alle gleich groß in einer Reihe, die Menge klein darunter.

### Steal An Egg – Trail-Shop (Roblox)

![[stealanegg-trail-shop.jpg]]

- **Was ist gut:** Die **ganze Karte** ist in der Seltenheitsfarbe eingefärbt (Grau → Grün → Blau → …), nicht nur der Rahmen. Darunter Name + Seltenheit als Wort, der Effekt als eine klare Zahl („x2 Geschwindigkeit“). Zwei Preise nebeneinander: Spielgeld grün, Robux lila. Die nächste Karte schaut rechts angeschnitten herein → zeigt, dass man scrollen kann.
- **Prinzip zum Übernehmen:** pro Karte nur ein Effekt und eine Zahl; Werte steigen gleichmäßig (x1,5 / x2 / x2,5), Preise dagegen stark (100 / 5K / 75K).

### Steal An Egg – Verschmelzmaschine (Roblox)

![[stealanegg-verschmelzen.jpg]]

- **Was ist gut:** 3 leere Slots mit großem grünem „+“, Rohre führen sichtbar zur Mitte zum Ergebnis (Silhouette). Ein kleines Erklärbild „3 kleine ≈ 1 großes“ mit „Okay!“ statt Text. Unten der Zähler „3 Haustiere übrig“.
- **Prinzip zum Übernehmen:** Mechanik als Bild erklären (Eingänge → Ergebnis), nicht als Absatz Text. Doppelte Items bekommen so einen Nutzen.

### Steal An Egg – Haustier-Index (Roblox)

![[stealanegg-index-wald.jpg]]
![[stealanegg-index-tempel.jpg]]

- **Was ist gut:** Unbekannte Tiere als **Silhouette mit „???“**, der Hintergrund verrät aber schon die Seltenheitsfarbe → macht neugierig. Pro Gebiet eine Seite mit Gebietsbild links, Fortschrittsbalken „1/8“ und einer Belohnung fürs Vervollständigen (Geld + Tempo). Großer Button „Alle beanspruchen!“, wenn etwas abzuholen ist.
- **Prinzip zum Übernehmen:** Sammelbuch pro Welt mit Belohnung pro Fund und für 8/8. Passt direkt zum Fisch-Index in [[Clean the Skyscraper]] und als Bestiarium pro Insel in [[Himmelsinseln]].

### Rivals – Shop-Startseite (Roblox)

![[rivals-shop.jpg]]

- **Was ist gut:** Reiter oben als Symbol + Wort (Home, Bündel, Lackierungen, Täglich, Schlüssel, Mehr). Kisten links in einem 3×2-Raster, jede in eigener Farbe, Preis in einem gelben Schild darunter. Großes Banner für den Saison-Pass mit Auge-Button („ansehen“). Das Spezialangebot zeigt, wenn leer, ein Symbol mit „Komm später wieder!“ statt einer leeren Fläche. Punkte unten zeigen weitere Seiten an.
- **Prinzip zum Übernehmen:** leere Zustände immer gestalten (Symbol + Satz), nie nur ein leeres Feld.

### Rivals – Login-Belohnungen 7 Tage (Roblox)

![[rivals-login-belohnung.jpg]]

- **Was ist gut:** Tage 1–6 als kleine Kacheln in einem Raster, **Tag 7 doppelt so groß** mit „Großer Preis!“. Der heutige Tag ist hell hervorgehoben mit „Jetzt beanspruchen!“. Die Belohnungen steigen langsam (x1, x1, x3, x2, x3, x5).
- **Prinzip zum Übernehmen:** Der letzte Tag ist das Ziel und wird visuell größer gemacht. Gibt einen Grund, jeden Tag wiederzukommen.

### Rivals – Schlüssel-Pakete (Roblox)

![[rivals-schluessel-pakete.jpg]]

- **Was ist gut:** 5 Pakete, Menge riesig als „+10 … +1.100“, Preis klein in grünem Schild. Die Kacheln werden nach rechts unten breiter und das teuerste ist **rot statt gelb**. Oben die Bestätigung „Login-Belohnung – Du hast ×1 Schlüssel verdient!“ als Toast.
- **Prinzip zum Übernehmen:** Die Menge ist das Wichtigste, der Preis zweitrangig. Das beste Paket bekommt eine eigene Farbe.

### Rivals – Waffe mit Stufe (Roblox)

![[rivals-waffen-stufe.jpg]]

- **Was ist gut:** Die Waffe groß in 3D in der Mitte. Rechts eine Spalte: Name, Stufe als Balken (28), „Jetzt aufsteigen“, nächste **Belohnung auf Stufe 50** sichtbar, darunter Verträge, Überblick, Statistik. Unten Aktionen als Symbol-Buttons (Verlassen, Aussehen, Einpacken, Zauber).
- **Prinzip zum Übernehmen:** Jede Waffe hat ihren eigenen Fortschritt mit sichtbarem nächstem Ziel. Das motiviert, eine Waffe weiterzuspielen.

### Grow a Garden – Zeitlich begrenzter Shop (Roblox)

![[growagarden-zeitshop.jpg]]

- **Was ist gut:** Fast gleicher Aufbau wie der Ei-Shop von Steal An Egg: Zeile pro Angebot mit „NEU!“, „Endet in 3 Tagen“, Inhalte mit Prozenten, 3 Mengenstufen mit durchgestrichenem Preis beim größten Paket und Geschenk-Button daneben. Die seltensten Inhalte zeigen ein „?“ statt des Bildes. Die Zeilen sind in der Farbe des Themas eingefärbt (Regenbogen, Blau).
- **Prinzip zum Übernehmen:** Dass zwei Top-Spiele das identisch machen, zeigt: Das ist ein gelernter Standard für Roblox-Shops.

### Grow a Garden – Saat-Laden mit Restock (Roblox)

![[growagarden-saatladen.jpg]]
![[growagarden-saat-kaufen.jpg]]

- **Was ist gut:** Oben groß der Countdown **„New seeds in 1m 31s“** und ein Button „RESTOCK“ (vermutlich sofort auffüllen gegen Robux). Jede Saat als Zeile: Bild, Name, **begrenzter Vorrat** („X9 Stock“), Preis grün, Seltenheit als Schild. Antippen klappt die Zeile auf: großer grüner Button mit Spielgeld-Preis, lila Button mit Robux-Preis, Geschenk-Button. Ist eine Saat ausverkauft, muss man auf den nächsten Restock warten.
- **Prinzip zum Übernehmen (gilt auch für den Artikel-Shop unten):** Begrenzter Vorrat + Countdown bis zum Auffüllen = Grund, alle paar Minuten wieder in den Laden zu schauen. Aufklappen statt eines eigenen Kaufdialogs.

### +1 Speed Keyboard Escape – Artikel-Shop (Roblox)

![[keyboard-artikel-shop.jpg]]

- **Was ist gut:** 4 Karten nebeneinander, Kopfzeile in Seltenheitsfarbe (Gewöhnlich grau, Ungewöhnlich grün, Selten blau, Episch lila), dazu Vorrat („1/1“, „2/2“), der Effekt klein („+5 % Geschwindigkeit“) und zwei Preise (Trophäen gelb, Robux grün + Geschenk). Oben der Restock-Timer, beim Auffüllen eine Meldung „Artikel-Shop wieder aufgefüllt!“ quer über den Bildschirm. Die Items passen zum Welt-Thema (Karamell-Schleife, Cupcake, Milchshake, Donut-Schild).
- **Prinzip zum Übernehmen:** Shop-Items thematisch zur aktuellen Welt; Restock wird aktiv angesagt.

### Blox Fruits – Frucht-Shop (Roblox)

![[bloxfruits-frucht-shop.jpg]]

- **Was ist gut:** Kleines Fenster mitten im Spiel (Welt bleibt sichtbar). Oben 2 große Kacheln für die besten Früchte mit Bild + Preis, darunter eine Reihe kleiner Kacheln für die billigeren. Jede Frucht hat ein eigenes, sofort erkennbares Symbol mit Farbe des Elements (Flamme orange, Magma rot …).
- **Prinzip zum Übernehmen:** Fähigkeiten als sammelbare Gegenstände mit klarer Element-Farbe – passt zu den Element-Inseln in [[Himmelsinseln]].

### Ziehe einen Dino – Dino-Index (Roblox)

![[dino-index.jpg]]

- **Was ist gut:** Wie der Haustier-Index von Steal An Egg: pro Zone (z. B. „Sumpf“) eine Reihe mit Silhouetten und „???“, Kachelfarbe = Seltenheit, Fortschritt „3/8“ und Bonus fürs Vervollständigen („+10 % Geld“). Unten die Gesamtregeln in einer Zeile: „Unlocked 9/695 · Complete a zone: +10 % money · Exotics: +0 % luck“. Zweiter Reiter „Top Collectors“ als Bestenliste.
- **Prinzip zum Übernehmen:** Sammelbuch ist inzwischen Standard in Roblox-Sammelspielen; Belohnung pro vollständiger Zone + Bestenliste für Sammler.

## Bei uns umgesetzt

-
