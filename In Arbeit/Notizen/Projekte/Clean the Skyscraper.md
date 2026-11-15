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
- [ ] Phase 5: Feinschliff (Sound, Effekte, Menü, .exe)
- [x] Ansicht: Ich-Ansicht aus der Gondel (15.11.2026)
- [x] Spielgefühl: komplett entspannt, kein Scheitern (15.11.2026)
- [x] Putzen durch Reiben mit der Maus, Gondel frei fahren, Texte auf Deutsch, Spieldauer 10–20 Stunden (15.11.2026)
- [x] Entschieden (15.11.2026): kein Idle-Fortschritt – Helfer putzen nur, solange man spielt

## Ideen (noch nicht entschieden)

Ausgewählte Ladenideen (15.11.2026) – die Läden sollen auf **verschiedene Hochhäuser** in der Stadt verteilt werden (jeder Laden in einem eigenen Tower, nicht alle an einem Ort):
- [ ] **Möbelhaus**: begehbarer Laden mit Ausstellungsräumen, Möbel fürs Penthouse ansehen und kaufen (statt nur Menü)
- [ ] **Gondel-Werkstatt**: Lackierungen, Aufkleber, Blumenkästen, Sonnenschirm, Radio für die Gondel
- [ ] **Souvenirshop**: Andenken für erreichte Meilensteine (Mini-Wüstennadel, Schneekugel …), im Penthouse aufstellen
- [ ] **Goldschmuck-Laden**: glitzerndes Schaufenster neben dem Casino, Luxus-Statussymbole (z. B. goldene Gondel)

## Notizen

- Turm ist erfunden (kein Burj-Khalifa-Nachbau: Name und Form sind geschützt)
- Blender bewusst weggelassen: echte Rahmen und Räume hinter den Fenstern bringen im Spiel mehr, fotorealistisch passt nicht zum Spiel
