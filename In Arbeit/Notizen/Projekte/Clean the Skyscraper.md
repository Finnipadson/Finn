---
typ: spiel
status: in Arbeit (Phase 3 fertig: Szenen, Album, Tauben, Wind, Sandsturm)
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
- [ ] Händler und Casinos auf den Stellplätzen (Idee des Users, genauer besprechen)
- [ ] Phase 4: Automatik (Helfer, Roboter, Drohnen)
- [ ] Phase 5: Feinschliff (Sound, Effekte, Menü, .exe)
- [x] Ansicht: Ich-Ansicht aus der Gondel (15.11.2026)
- [x] Spielgefühl: komplett entspannt, kein Scheitern (15.11.2026)
- [x] Putzen durch Reiben mit der Maus, Gondel frei fahren, Texte auf Deutsch, Spieldauer 10–20 Stunden (15.11.2026)
- [ ] Offene Frage (vor Phase 4): Fortschritt, während man nicht spielt (Idle)?

## Notizen

- Turm ist erfunden (kein Burj-Khalifa-Nachbau: Name und Form sind geschützt)
- Blender bewusst weggelassen: echte Rahmen und Räume hinter den Fenstern bringen im Spiel mehr, fotorealistisch passt nicht zum Spiel
