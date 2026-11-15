# Clean the Skyscraper – Bauplan

Status: **Phase 1 fertig**, als Nächstes Phase 2

## Idee

Jedes einzelne Fenster des höchsten Turms der Welt putzen, rund **25.600 Fenster**. Man startet unten mit einem Schwamm und arbeitet sich Stockwerk für Stockwerk bis zur Spitze hoch. Was das Spiel besonders macht:
- **Klarer Fortschritt:** „Fenster 1.234 von 25.638“, dazu Höhenmeter und Prozent.
- **Die Aussicht als Belohnung:** Je höher man kommt, desto spektakulärer wird der Blick, erst über die Stadt, dann über die Wolken.
- **Werkzeuge in Stufen:** Schwamm → Abzieher → Doppel-Abzieher → Hochdruckreiniger → Helfer → Putzroboter → Drohnenschwarm.
- **Leben hinter dem Glas:** Büros, Partys, eine Katze, jemand winkt. Kleine Szenen, die man sammeln kann.
- **Störungen:** Tauben machen Fenster wieder dreckig, Wind schaukelt die Gondel, ein Sandsturm verstaubt ganze Stockwerke.

Der Turm ist erfunden (Name „Wüstennadel“, Arbeitstitel) und kein Nachbau des Burj Khalifa: eigene Form, eigener Name.

## Entscheidungen

- **Technik:** Godot 4.7, GDScript. Der Turm wird komplett aus Code erzeugt: Grundriss pro Stockwerk, Glas mit Räumen dahinter (Interior Mapping), echte Rahmen als MultiMesh. Grundlage ist der Grafik-Test `Grafiktest/godot-turm` (Variante 1).
- **Turm:** Variante 1 „Wüstennadel“, Y-Grundriss mit spiralförmigen Stufen, 168 Stockwerke, ca. 935 m inklusive Spitze.
- **Plattform:** PC (Windows), Maus und Tastatur, Export als .exe.
- **Ansicht:** Ich-Ansicht aus der Gondel (entschieden 15.11.2026): eigene Hände mit Werkzeug im Bild wie im Strand-Test, Blick frei nach links/rechts/unten (Tiefe sehen!), Fenster direkt vor einem.
- **Spielgefühl:** komplett entspannt, man kann nicht scheitern (entschieden 15.11.2026). Wind, Tauben und Sandsturm stören nur (Gondel schaukelt, Fenster werden wieder dreckig), kosten aber nichts.
- **Putzen:** Reiben mit gedrückter Maus, der Dreck verschwindet dort, wo man wischt (entschieden 15.11.2026).
- **Gondel:** frei fahren mit A/D und W/S, stufenlos an der Fassade entlang (entschieden).
- **Sprache:** Deutsch, nur der Titel bleibt „Clean the Skyscraper“ (entschieden).
- **Spieldauer:** etwa 10 bis 20 Stunden bis alle Fenster sauber sind (entschieden); Werkzeuge und Upgrades machen einen immer schneller.
- **Look:** leicht stilisiert, nicht fotorealistisch (bewusst so entschieden, 15.11.2026).
- **Speichern:** JSON in `user://` (Godot-Benutzerordner).
- **Prüfen:** Testbilder per `--write-movie` mit festen Ansichten (`--ansicht=N`), wie im Grafik-Test.

## Spielmechanik (Vorschlag)

- **Gondel:** Man steht in einer Gondel vor der Fassade. Mit A/D fährt sie seitlich an der Fassade entlang, auch um die runden Flügelspitzen herum, mit W/S rauf und runter. Anfangs geht das nur langsam und nur in freigeschalteten Höhen.
- **Putzen:** Mit gedrückter Maus wischt man über das Fenster. Jedes Fenster hat eine eigene Dreck-Maske, die beim Wischen verschwindet. Ab etwa 95 % sauber zählt das Fenster: Es funkelt, gibt Geld, und der Zähler springt hoch.
- **Daten:** Pro Fenster wird nur ein Sauberkeitswert gespeichert, als eine Datentextur mit einem Pixel pro Fenster. Die genaue Wisch-Maske gibt es nur für die Fenster direkt vor der Gondel, deshalb bleibt das auch bei 25.000 Fenstern schnell.
- **Geld und Shop:** Jedes saubere Fenster bringt Geld, höhere Stockwerke bringen mehr. Gekauft wird auf den Terrassen an den Stufen, die gleichzeitig Etappenziele und Speicherpunkte sind.
- **Freischalten nach oben:** Ein Abschnitt (zwischen zwei Terrassen) muss zu etwa 90 % sauber sein, dann fährt die Gondel höher.
- **Ziel:** die Spitze erreichen und alle Fenster sauber haben. Danach gibt es einen Endlos-Modus, in dem Dreck langsam zurückkommt.

## Inhalte (Vorschlag)

- **Werkzeuge:** Schwamm (klein), Abzieher (breit), Doppel-Abzieher, Hochdruckreiniger (putzt aus Entfernung), Seifenkanone (mehrere Fenster auf einmal)
- **Gondel-Upgrades:** Tempo, Breite (zwei Fenster nebeneinander), doppelte Höhe (zwei Stockwerke), Windschutz
- **Automatik:** Helfer-Putzkräfte, Putzroboter (fährt eine Spalte ab), Drohnenschwarm (spät im Spiel)
- **Störungen:** Tauben, Wind (Gondel schaukelt, Wischen wird ungenauer), Sandsturm-Ereignis, Regen (hinterlässt Wasserflecken)
- **Szenen hinter den Fenstern:** Büro, Party, Katze, Fitnessstudio, Geburtstag, jemand winkt, Liebesbrief am Fenster … als Sammelalbum
- **Aussicht:** Stadt, Wüste, Wolkendecke ab etwa 600 m, Sonnenuntergang

## Phasen

0. [x] **Projekt aufsetzen:** Turm-Generator aus `Grafiktest/godot-turm` übernehmen und aufräumen, Ordnerstruktur anlegen, `start.bat`, Testbild-Ansichten
   - **Ergebnis (15.11.2026):** eigenes Godot-Projekt mit `skripte/bau.gd` (Grundrisse, Fassaden-Mesh, Rahmen), `turm.gd` (Wüstennadel, 168 Stockwerke, 935 m, **25.638 Fenster**, Fenster-Nummerierung `fenster_id()` + `fassaden_punkt()` für die Gondel), `welt.gd` (Himmel, Licht, Wüste, Stadt), `haupt.gd` (freie Kamera, Testansichten 1–3). Testbild 2 markiert ein Fenster per Nummer, und die Markierung sitzt genau in einem Shader-Fenster. Aufgefallen: Der Rand der Stadtfläche ist in der Aussicht von oben als Kreis sichtbar (→ Phase 3, schönere Stadt).
   - **Flimmer-Fix (15.11.2026):** Der User hat Flimmern bemerkt. Gemessen per Testfahrt (`--ansicht=4`, Bild-zu-Bild-Änderung der feinen Details): weiche Kanten im Glas-Shader, Rahmen blenden mit der Entfernung über, SSIL aus. Zweite, richtige Messung gegen eine fein berechnete Referenz: **TAA ist unruhiger** (3,3) als gar nichts (2,4), am besten ist **2-faches Supersampling + MSAA 4x** (1,6), bei rund 190 FPS in 1440p → Standard. Später (Phase 5) als Einstellung „Bildqualität“ wählbar machen.
1. [x] **Spielbarer Kern:** Gondel fahren, Fenster mit der Maus wischen (Dreck-Maske), Sauberkeit pro Fenster, Zähler „X von Y“, Geld
   - **Ergebnis (15.11.2026):**
     - `skripte/fenster_zustand.gd`: Dreck pro Fenster als Datentextur (RG8, R = Dreck, G = Wisch-Slot) und 64 feine Wisch-Masken (32×64 px) in einem Atlas, nur für die Fenster, an denen gerade geputzt wird; ab 95 % gewischt ist ein Fenster sauber.
     - `skripte/spieler.gd`: Gondel mit Ich-Ansicht. A/D fährt entlang des Umfangs, auch um die runden Flügelspitzen; W/S fährt hoch und runter, an einer Stufe springt die Gondel an die neue Fassade. Maus schaut um; linke Maustaste halten + Maus bewegen reibt den Schwamm über das Glas, die Striche werden lückenlos gestempelt, auch über Fenstergrenzen.
     - `skripte/hud.gd`: Zähler „X / 25.638“, Geld, Höhe, Fortschrittsbalken des Fensters unter dem Schwamm, „+1 €“ beim Fertigwerden; Funkeln am Fenster.
     - Lohn: 1 € + 1 € je 10 Stockwerke. Phase 1 reicht bis Stockwerk 18 (erste Stufe), `--frei` hebt die Sperre auf.
     - Testansichten: `--ansicht=5` (Schwamm fährt automatisch Schlangenlinien, über denselben Code wie mit der Maus), `--ansicht=6` (Testfahrt um die Flügelspitze und über die Stufe).
   - **Noch offen / aufgefallen:** Der Arm ist eine lange Stange, wenn der Schwamm weit weg ist (später als Teleskopstange gestalten). Es gibt noch kein Speichern (Phase 2) und keinen Ton (Phase 5). Mit dem kleinen Schwamm dauert ein Fenster je nach Tempo etwa 5–10 s.
2. [ ] **Fortschritt und Wirtschaft:** Terrassen als Shop und Etappenziel, Werkzeuge, Gondel-Upgrades, Abschnitte freischalten, Speichern und Laden
3. [ ] **Leben am Turm:** Szenen hinter den Fenstern und Sammelalbum, Tauben, Wind, Sandsturm, schönere Stadt
4. [ ] **Automatik:** Helfer, Putzroboter, Drohnen, eventuell Fortschritt auch während man nicht spielt
5. [ ] **Feinschliff:** Sound und Musik, Funkel-Effekte, Menü und Einstellungen, Tageszeiten, Export als .exe

## Offene Fragen

- Gibt es Fortschritt, während man nicht spielt (Idle), oder nur durch eigenes Putzen?

## Stand

- 15.11.2026: Idee und Grafik-Tests fertig (`Grafiktest/godot-turm`: 3 Turm-Varianten, Vorher-Nachher mit echten Rahmen und Räumen hinter den Fenstern). Variante 1 und Name „Clean the Skyscraper“ gewählt.
