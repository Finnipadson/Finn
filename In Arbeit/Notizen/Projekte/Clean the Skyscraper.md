---
typ: spiel
status: in Arbeit (Phase 4 + Extras fertig, als Nächstes Phase 5 Feinschliff)
technik: Godot 4.7, GDScript, Turm komplett aus Code
erstellt: 2026-11-15
---

Fleißaufgaben-Spiel: jedes der rund 25.600 Fenster des höchsten Turms der Welt putzen, aus einer Gondel heraus, Stockwerk für Stockwerk bis zur Spitze.

- Herkunft: Idee „Absurd riesige Fleißaufgabe“ → Variante „Fenster putzen“ in [[Ideen]]
- Bauplan: [[clean-the-skyscraper-plan]] (Phasen 0–5)
- Ordner: `CleanTheSkyscraper/`, starten mit **`start.bat`**, Aufbau in [[CleanTheSkyscraper/README|README]]
- Grafik-Grundlage: `Grafiktest/godot-turm` (Turm-Variante 1 „Wüstennadel“, Vergleichsbilder `turm-varianten.png` und `vorher-nachher.png`)

## Ziele

- Klarer Fortschritt: „Fenster X von 25.638“, Höhenmeter, Aussicht als Belohnung
- Werkzeuge in Stufen: Schwamm → Abzieher → Hochdruckreiniger → Helfer → Roboter → Drohnen
- Leben hinter dem Glas (Szenen sammeln), Störungen (Tauben, Wind, Sandsturm)
- Leicht stilisierter Look, nicht fotorealistisch

## Offene Punkte

- [x] Phase 0: Projekt aufsetzen (Godot-Projekt, Turm mit Fenster-Nummerierung, Welt, freie Kamera; Start `start.bat`)
- [x] Phase 1: Spielbarer Kern (Gondel fahren, Fenster mit der Maus sauber reiben, Zähler, Geld, Funkeln; bis Stockwerk 18)
- [x] Phase 2: Fortschritt und Wirtschaft (Werkstatt mit Tab, 5 Werkzeuge, Motor/Teleskoparm/Seilwinde, Speichern + Laden)
- [ ] Balance testen (Ziel 10–20 h), Zahlen in `wirtschaft.gd`
- [x] Phase 3: Leben am Turm (10 Szenen + Sammelalbum mit B, Tauben, Windböen, Sandsturm, Straßen + Platz, Höhenbonus); dazu Rechtsklick beim Putzen = umschauen
- [x] Tauben/Sandsturm/Wind an- und ausschaltbar (Werkstatt → Einstellungen)
- [x] Gondel unten verlassen (E) und auf dem Platz herumlaufen, Stellplätze für Händler/Casino markiert
- [x] Händler: drei Marktstände (Putzmittel-Boosts, Mode & Farben, Snacks mit Effekt), mit E ansprechen
- [x] Casino (15.11.2026): begehbares Gebäude hinter einer Flügelspitze mit Blackjack, Glücksrad, einarmigem Banditen und Rubbellosen (mit E an der Station) – nur Spielgeld, Einsatz 10 € bis 10 % des Geldes, höchstens 5.000 €
- [x] Stadt im Dubai-Stil, Teil 1 (15.11.2026): See mit Fontänen-Show am Turmfuß, ca. 860 Palmen, Laternen, Mittelstreifen und Zebrastreifen
- [x] Stadt Teil 2 (15.11.2026): ca. 720 fahrende Autos mit Ampeln an allen Kreuzungen, grüne Schilderbrücken
- [x] Rückmeldung zur Stadt (15.11.2026): Straßen enden an Kreuzungen, Autos wenden, neuer Steinboden, Bänke/Kübel/Leute, saubere Hochhaus-Fenster, Casino im Hochhaus-Sockel, Start zu Fuß mit Express-Gondel, Werkzeug-Kiosk mit 5 Profi-Werkzeugen
- [x] Phase 4 (15.11.2026): Helfer (Putzkraft, Roboter, Drohne – Kauf + Lohn-Anteil, nur beim Spielen), drei Gondeln (eine je Turmseite), Werkzeug- und Fahrzeug-Kioske, Hotbar, E-Scooter/Hoverboard/Jetpack
- [x] Extras (15.11.2026): Sky-Lounge mit Express-Aufzug (Lounge 200 m mit Sky-Bar, Restaurant 500 m mit Designer-Möbeln, Aussichtsplattform 800 m um die Spitze), Penthouse oben im Casino-Hochhaus (Möbel frei aufstellen, Boni, Pokal-Vitrine), Arcade-Halle im 1. Stock (Greifautomat, Kapsel-Automat; Seltenheit +2/5/10/20 %), 29 Erfolge (Geld + Pokal) + Statistik mit Rekorden (Taste P)
- [x] Flimmern verringert (15.11.2026): Fenster-Raster der Stadthäuser, Boden (Fugen, Linien, Zebrastreifen, Platten, Blumen), Turm-Räume/Schlieren und Palmen weich gefiltert; Spiegelungen (SSR) aus, weil sie den Boden verschmiert in die Brüstungen am Turmfuß gespiegelt haben. TAA ist nur noch eine Einstellung (Werkstatt → Einstellungen, Standard aus), weil es das Bild im Stand wackeln lässt. Gemessen: beim Drehen über der Stadt ca. 65 % weniger Flimmern, Turm aus der Ferne ca. 65 % weniger, Boden 25–60 % weniger, im Stand kein Wackeln; FPS etwas höher als vorher. Danach noch: Palmen/Laternen standen auf Kreuzungen (behoben), Brüstungen als durchgehendes Band, Fensterpfosten waren gespiegelt und flackerten mit dem Glas (behoben) – vom User abgenommen: „sieht perfekt aus“
- [x] Vier Läden (16.11.2026) rund um den Platz, je im Erdgeschoss eines eigenen Hochhauses, zu Fuß begehbar: Möbelhaus (6 Ausstellungsräume, 18 neue Möbel, E am Möbelstück = ansehen + kaufen; Tablet bleibt), Gondel-Werkstatt (Lackierungen, Aufkleber, Blumenkästen, Sonnenschirm – nur Optik, Vorführ-Gondel zeigt die Ausstattung), Souvenirshop (12 Andenken, je nach einem Erfolg freigeschaltet, dann einmal kaufbar, kleine Boni), Goldschmuck neben dem Casino (6 legendäre Gold-Deko-Stücke 20.000–500.000 €, je +20 %)
- [x] Läden verschönert (16.11.2026, Rückmeldung „lieblos“): Markisen, Aufsteller, Bodenmuster, Leute, Pflanzen; Möbelhaus mit echt eingerichteten Zimmern, Empfang und Einkaufswagen; Werkstatt mit Rolltor, Schweißer und Lackierkabine; Souvenirshop mit Regalen voller Kleinkram, Modell-Stadt und Lichterketten; Gold-Laden mit Spiegelwand, rotem Teppich, großem Kronleuchter und Lichtkegeln
- [ ] Phase 5: Feinschliff (Sound, Effekte, Menü, .exe) – dabei auch das Radio für die Gondel (vom User auf Phase 5 verschoben)
- [x] Ansicht: Ich-Ansicht aus der Gondel (15.11.2026)
- [x] Spielgefühl: komplett entspannt, kein Scheitern (15.11.2026)
- [x] Putzen durch Reiben mit der Maus, Gondel frei fahren, Texte auf Deutsch, Spieldauer 10–20 Stunden (15.11.2026)
- [x] Entschieden (15.11.2026): kein Idle-Fortschritt – Helfer putzen nur, solange man spielt

## Ideen (noch nicht entschieden)

Ausgewählte Ladenideen (15.11.2026) – jeder Laden in einem eigenen Hochhaus, **gebaut am 16.11.2026** (rund um den Platz):
- [x] **Möbelhaus**: begehbarer Laden mit Ausstellungsräumen, Möbel fürs Penthouse ansehen und kaufen (statt nur Menü)
- [x] **Gondel-Werkstatt**: Lackierungen, Aufkleber, Blumenkästen, Sonnenschirm (Radio → Phase 5, wenn es Ton gibt)
- [x] **Souvenirshop**: Andenken für erreichte Meilensteine (Mini-Wüstennadel, Schneekugel …), im Penthouse aufstellen
- [x] **Goldschmuck-Laden**: glitzerndes Schaufenster neben dem Casino, Gold-Deko fürs Penthouse (goldene Gondel/Werkzeuge/Schmuck vom User abgewählt)

Strand, Angeln und Karte (16.11.2026, Wünsche des Users – **alles entschieden, bereit zum Bauen**):
- [ ] **Meer mit Strand hinter dem See mit den Fontänen**: Auf dieser Seite endet die Stadt nach ~600 m an einer Strandpromenade, dahinter Meer bis zum Horizont (wie Dubai). Zu Fuß ~1 min, mit Hoverboard ~30 s; auch von oben aus der Gondel als Aussicht zu sehen
- [ ] **Strandbar** mit Sonnenschirmen, Liegen, Bar-Hütte und **eigenen Strand-Drinks mit Angel-Wirkung** (z. B. Kokos-Shake: Fische zappeln langsamer, Mango-Smoothie: seltene Fische beißen öfter), dazu ein paar der bekannten Cocktails
- [ ] **Angeln**: am Steg oder Strand Angel auswerfen, Fische fangen und verkaufen (kleiner Zusatzverdienst). **20 Fischarten**, jede seltener als die vorige; die **letzten 3 unter 0,5 %** Wahrscheinlichkeit
- [ ] **Fisch-Index im Album (Taste B)**: zweiter Reiter „Szenen | Fische“, gefangene Fische mit Bild, fehlende als Umriss
- [ ] **Belohnung für den vollen Index: eigene Yacht** – frei übers Meer fahren und **vom Boot aus angeln** (draußen beißen seltene Fische etwas öfter), Liegeplatz am Steg
- [ ] **Karte mit Taste M**: Übersicht über Stadt, Turm, Kioske, Läden, Casino, Strand, Steg und die eigene Position; **Klick auf einen Ort setzt ein Ziel**, ein Pfeil im Bild zeigt den Weg
- [ ] **Weg zum Strand: Palmen-Boulevard mit Kanal** (entschieden 16.11.2026): breite Fußgänger-Allee vom See bis zum Meer, in der Mitte ein schmaler Wasserkanal (verbindet See und Meer) mit kleinen Fontänen (passt zum See), Palmen, Bänke, Laternen, Schilder „Strand →“, am Ende eine große Treppe hinunter zum Sand. Zu Fuß ~1 min, mit Hoverboard ~30 s
- [ ] **Großer Steg mit Fischladen** (entschieden): dort kauft man die Angel und verkauft alle Fische – je seltener, desto mehr Geld. Angeln bleibt eine **Nebenaufgabe** (kleiner Zusatzverdienst, nicht schneller als Fenster putzen)
- [ ] **Angeln als Geschicklichkeitsspiel – Spannungsbalken** (entschieden): Der Fisch zappelt in einem senkrechten Balken auf und ab, mit gedrückter Maustaste hält man einen Fangkasten über ihm; bleibt er lange genug drin, ist er gefangen. Seltene Fische zappeln schneller und wilder
- [ ] **3 Angel-Stufen im Fischladen** (entschieden): Bambus-Angel (billig), Carbon-Angel (größerer Fangkasten), Hochsee-Angel (seltene Fische beißen öfter, nötig für die Riesen ab Segelfisch)
- **Fisch-Vorschlag** (echte Arten aus Golf/Arabischem Meer, keine Standard-Fische, je seltener desto größer; **final**): 1 Sergeant-Fisch 15 cm 17 % · 2 Kofferfisch 20 cm 15 % · 3 Sohal-Doktorfisch 30 cm 12,5 % · 4 Igelfisch 30 cm 10,5 % · 5 Wimpelfisch 20 cm 8,5 % · 6 Papageifisch 40 cm 7 % · 7 Arabischer Kaiserfisch 40 cm 6 % · 8 Trompetenfisch 60 cm 5 % · 9 Rotfeuerfisch 35 cm 4 % · 10 Hornhecht 70 cm 3,3 % · 11 Barrakuda 1,2 m 2,7 % · 12 Adlerrochen 1,5 m 2,2 % · 13 Riesenmuräne 2 m 1,7 % · 14 Gitarrenrochen 2,5 m 1,3 % · 15 Napoleon-Lippfisch 2 m 1 % · 16 Segelfisch 3 m 0,8 % · 17 Riesenmanta 6 m 0,6 % · 18 Quastenflosser 2 m 0,4 % · 19 Sägefisch 5 m 0,3 % · 20 Walhai 10 m 0,2 %. Alle 20 lassen sich normal verkaufen, auch die Riesen (entschieden). Modelle: Quaternius „Lowpoly Animated Fish“ (CC0, Stil vorher prüfen), Sonderformen aus Code
- Fisch-Preise und Angel-Preise legt Claude beim Bauen fest: Angeln bleibt ein kleiner Zusatzverdienst (mit dem Durchspiel-Bot nachmessen)

Ideen aus dem Durchspiel-Test (16.11.2026, Vorschläge von Claude, noch nicht entschieden):
- [ ] **Endlos-Modus / zweiter Turm** nach allen Fenstern: Dreck kommt langsam zurück oder ein neuer Turm, damit das Geld am Ende (100.000 € und mehr) noch etwas bringt
- [ ] **Kundenaufträge** mit Zeitlimit (z. B. „Stockwerk 70 bis 18 Uhr für eine Hochzeit“) gegen die eintönige Mitte (2–3 h mit demselben Werkzeug)
- [ ] **Besondere Fenster**: goldene Fenster (10× Lohn), Graffiti (mehrmals reiben), Glaser-Auftrag
- [ ] **Belohnungen an den Terrassen** (Andenken, Aussichts-Szene) statt nur Geld
- [ ] **Werkzeuge ohne Sinn aufwerten**: Mikrofaser-Schwamm (nicht besser als der billigere Abzieher) und Hochdruckreiniger (langsamer als der Doppel-Abzieher) eine eigene Stärke geben, z. B. Tauben-Dreck sofort weg bzw. putzt beim Fahren mit
- [ ] **Boosts per Tablet in die Gondel bestellen** (Lieferdrohne, etwas teurer) – der Bot musste für fast jeden Boost runterfahren und laufen
- [ ] **Helfer verbessern und zuweisen**: schneller, weniger Lohn-Anteil, Seite/Stockwerke festlegen, Namen und Kleidung
- [ ] **Seltene Szenen** nur hoch oben oder nur nachts (Album ist nach 1–2 h voll)
- [ ] **Positives Ereignis**, z. B. „Goldene Taube“, die eine Münze fallen lässt
- [ ] **Kapsel-Automat**: doppelte Gewinne sollen den Bonus nicht stapeln (sonst leicht +100 %)

Mehrspielermodus (15.11.2026, Wünsche des Users):
- [ ] **Koop**: bis zu **4 Spieler** putzen gemeinsam **denselben Turm**, jedes Fenster zählt für alle
- [ ] **Verbinden per Code**: einer erstellt das Spiel und schickt Freunden einen Code, die anderen geben ihn ein (übers Internet)
- [ ] **Gemeinsame Kasse**: ein Spielstand beim Gastgeber – Geld, Fenster und alles Gekaufte gehören allen
- Technik-Notiz: machbar mit Godot-Netzwerk (Multiplayer-API); für „Code eingeben“ übers Internet braucht es einen kleinen Vermittlungs-/Relay-Dienst. Größter Umbau bisher (Fenster-Zustand, Geld, Helfer, Gondeln, Menüs abgleichen) – am besten nach dem Feinschliff als eigene Phase

## Notizen

- **Durchspiel-Test (16.11.2026):** Ein Bot hat das ganze Spiel durchgespielt – alle Fenster nach 4–5,5 h Spielzeit (Mensch geschätzt 6–8 h, Ziel waren 10–20 h). Zwei Fehler behoben (Gondel neben dem Sky-Lounge-Aufzug ließ sich nicht betreten). Danach umgesetzt: Boosts stapeln sich nicht mehr, Gondeln/Motor teurer ; danach Sprühgeräte stärker, aber teurer (20.000 / 60.000 €), Gold-Deko halb so teuer → Bot 6–7,5 h, Mensch geschätzt 9–10,5 h. Für noch länger: Seilwinde teurer (Bauplan 4i)
- Turm ist erfunden (kein Burj-Khalifa-Nachbau: Name und Form sind geschützt)
- Blender bewusst weggelassen: echte Rahmen und Räume hinter den Fenstern bringen im Spiel mehr, fotorealistisch passt nicht zum Spiel
