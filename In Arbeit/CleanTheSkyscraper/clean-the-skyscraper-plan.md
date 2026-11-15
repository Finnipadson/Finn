# Clean the Skyscraper – Bauplan

Status: **Phase 3 fertig**, als Nächstes Phase 4

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
     - `skripte/fenster_zustand.gd`: Dreck pro Fenster als Datentextur (RG8, R = Dreck, G = Wisch-Slot) und 64 feine Wisch-Masken (64×128 px) in einem Atlas, nur für die Fenster, an denen gerade geputzt wird; ab 95 % gewischt ist ein Fenster sauber.
     - `skripte/spieler.gd`: Gondel mit Ich-Ansicht. A/D fährt entlang des Umfangs, auch um die runden Flügelspitzen; W/S fährt hoch und runter, an einer Stufe springt die Gondel an die neue Fassade. Maus schaut um; linke Maustaste halten + Maus bewegen reibt den Schwamm über das Glas, die Striche werden lückenlos gestempelt, auch über Fenstergrenzen.
     - `skripte/hud.gd`: Zähler „X / 25.638“, Geld, Höhe, Fortschrittsbalken des Fensters unter dem Schwamm, „+1 €“ beim Fertigwerden; Funkeln am Fenster.
     - Lohn: 1 € + 1 € je 10 Stockwerke. Phase 1 reicht bis Stockwerk 18 (erste Stufe), `--frei` hebt die Sperre auf.
     - Testansichten: `--ansicht=5` (Schwamm fährt automatisch Schlangenlinien, über denselben Code wie mit der Maus), `--ansicht=6` (Testfahrt um die Flügelspitze und über die Stufe).
   - **Noch offen / aufgefallen:** Der Arm ist eine lange Stange, wenn der Schwamm weit weg ist (später als Teleskopstange gestalten). Es gibt noch kein Speichern (Phase 2) und keinen Ton (Phase 5). Mit dem kleinen Schwamm dauert ein Fenster je nach Tempo etwa 5–10 s.
   - **Nach dem ersten Spieltest des Users (15.11.2026)** – drei Probleme behoben:
     - *Schwamm und Umschauen gingen nicht:* Das Fadenkreuz (ColorRect, `mouse_filter` STOP) lag genau dort, wo die gefangene Maus steht, und hat alle Klicks und Bewegungen geschluckt. Jetzt lässt der ganze HUD die Maus durch. Neu ist ein Maus-Test (`--ansicht=8`), der echte Eingaben schickt; die Demos davor hatten den Schwamm direkt gesteuert und das nicht gemerkt.
     - *Frei umschauen:* Man kann rundum schauen (360°) und fast senkrecht nach oben oder unten.
     - *Flimmern an den Turmkanten:* Die Gondel richtet sich am Mittel der Fassaden-Normalen ±2 m aus und dreht weich (`lerp_angle` statt `slerp`; `slerp` hatte Fehlermeldungen wegen nicht normierter Achse geworfen). Die Rahmen glänzen weniger. Gemessen an der Ecke 3,4 → 1,9.
     - Dazu doppelt so feine Wisch-Masken (64×128 px), die Kanten des Wisch-Strichs sind jetzt glatt.
2. [x] **Fortschritt und Wirtschaft:** Terrassen als Shop und Etappenziel, Werkzeuge, Gondel-Upgrades, Abschnitte freischalten, Speichern und Laden
   - **Ergebnis (15.11.2026):**
     - **Bewusste Abweichungen vom Plan (mit dem User besprochen):** Höher fahren kauft man als **Seilwinde** (+6 Stockwerke je Stufe, Start bis Stockwerk 6) statt über eine 90-%-Regel, weil ein Abschnitt unten über 1.000 Fenster hat. Die **Werkstatt** öffnet man überall mit **Tab** statt auf den Terrassen; die Terrassen bekommen in Phase 3 eine Rolle.
     - `skripte/wirtschaft.gd`: alle Zahlen zum Ausbalancieren an einer Stelle. Lohn 1 € + 1 € je 6 Stockwerke. Werkzeuge: Schwamm, Großer Schwamm (20 €), Abzieher (120 €, breit und flach), Doppel-Abzieher (700 €), Hochdruckreiniger (4.000 €, draufhalten statt reiben, Reichweite 9 m). Upgrades: Gondel-Motor (5 Stufen, +50 % Tempo), Teleskoparm (3 Stufen, mehr Reichweite), Seilwinde (27 Stufen).
     - `skripte/shop.gd`: Werkstatt-Fenster mit Kaufen, Nehmen und „Neues Spiel“ (mit Nachfrage). Werkzeugwechsel auch mit den Tasten 1–5.
     - `skripte/spiel.gd`: Spiel-Logik aus `haupt.gd` herausgezogen. Speichern als JSON in `user://spielstand.json` (Geld, Werkzeuge, Stufen, saubere Fenster als Base64, Position): alle 20 s, nach jedem Kauf und beim Beenden. Halb gewischte Fenster werden nicht gespeichert. Tests schreiben nur in `spielstand_test.json`.
     - Werkzeug-Modelle: Schwamm, Abzieher mit Gummilippe, Spritzpistole mit Wasserstrahl. Meldung, wenn das Seil zu kurz ist; Begrüßung beim ersten Start.
     - Tests: `--ansicht=9 --geld=10000` (Shop mit Tab öffnen, über die echten Knöpfe kaufen, Taste 3/5, Hochdruck), `--ansicht=10 --geld=500` und danach `--ansicht=10` (Speichern und Laden). Alles bestanden.
   - **Noch offen:** Balance nicht über Stunden getestet (Ziel 10–20 h) → nach Rückmeldung des Users in `wirtschaft.gd` nachjustieren.
3. [x] **Leben am Turm:** Szenen hinter den Fenstern und Sammelalbum, Tauben, Wind, Sandsturm, schönere Stadt
   - **Vorab (Wunsch des Users):** Beim Putzen zusätzlich die rechte Maustaste halten → umschauen, das Werkzeug bleibt am Glas.
   - **Ergebnis (15.11.2026):**
     - **Szenen:** Etwa jedes 35. Fenster hat eine von 10 Szenen: Winkende Person, Katze, Party (mit Disco-Licht und Luftballons), Büro, Fitness, Geburtstag (Kerzen flackern), Liebesbrief (Herz auf dem Glas), Dschungel, Aquarium (Fische schwimmen), Hund (wedelt). Gezeichnet im Glas-Shader als 2D-Formen auf einer Ebene hinter dem Glas, also mit echter Tiefe/Parallaxe und animiert. Der Szenen-Typ steht im B-Kanal der Zustands-Textur (jetzt RGBA8), festgelegt von `FensterZustand`.
     - **Sammelalbum** (`skripte/album.gd`, Taste B): 10 Plätze, Zähler pro Szene. Eine neue Szene bringt 10× Lohn als Bonus.
     - **Störungen** (`skripte/ereignisse.gd`, alle Zahlen oben im Skript):
       - Tauben alle 45–100 s: Eine fliegt zu einem sauberen Fenster nahe der Gondel, setzt sich aufs Sims und bekleckert es.
       - Windböen alle 80–170 s für 12–20 s: Die Gondel schaukelt und kippt leicht, Putzen wird etwas ungenauer; stärker in der Höhe.
       - Sandsturm nach 8 min, dann alle 12–20 min: 15 s Vorwarnung, 28 s orange Dunst mit Sandpartikeln, danach sind 25 % der sauberen Fenster ±4 Stockwerke um die Gondel eingestaubt.
       - Nichts davon kostet Geld.
     - **Stadt:** `shader/boden.gdshader` mit Straßenraster zwischen den Blöcken, gestrichelten Mittellinien, Platz aus Platten mit Grünring um den Turm und unregelmäßigem, weichem Übergang in die Wüste. Der Kreisrand ist weg.
     - **Terrassen/Höhen:** Beim ersten Erreichen eines neuen Abschnitts (je 6 Stockwerke) gibt es einen Höhenbonus von 25× Lohn mit Meldung. Gespeichert werden `album` und `hoechster_abschnitt`.
     - Tests: `--ansicht=11` (alle 10 Szenen vor der Gondel), `--ansicht=12` (Taube, Böe, Sandsturm sofort). Alle alten Tests (8, 9, 10) laufen weiter, rund 160 FPS in 1440p.
   - **Nachtrag (Wünsche des Users, 15.11.2026):**
     - **Einstellungen** in der Werkstatt: Tauben, Sandsturm und Windböen einzeln an/aus, mitgespeichert (`wirtschaft.einstellungen`). Ausschalten beendet einen laufenden Sturm sofort, ohne Einstauben.
     - **Zu Fuß am Boden** (`skripte/laeufer.gd`): Ist die Gondel ganz unten, steigt man mit **E** aus. Danach WASD, Shift rennen, Leertaste springen, Maus umschauen. Turm, Häuser und die geparkte Gondel sind fest (Turm-Grundriss + Häuser-Rechtecke aus `welt.haeuser`). Zurück an der Gondel (≤ 4 m) steigt man mit **E** wieder ein. Der HUD zeigt „E: Gondel verlassen / einsteigen“ und wechselt die Steuerungshilfe.
     - **Stellplätze** auf dem Platz (`welt.stellplaetze`): zwei markierte Flächen mit Schild „Demnächst: Händler“ und „Demnächst: Casino“ – dort kommen später Händler/Casinos hin (Idee des Users, noch nicht geplant).
     - **Stadt näher am Turm** (Wunsch des Users): Platz nur noch 125 m Radius (`Welt.PLATZ_R`, Boden-Shader `plaza_r`), Häuser ab dort, nah am Turm dichter (85 %) und höher, Stellplätze auf 104 m.
     - Test `--ansicht=13`: aussteigen, weglaufen, Einsteigen zu weit weg wird abgelehnt, an der Gondel stoppen, einsteigen, Einstellungen über die echten Knöpfe ausschalten. Alles bestanden.
   - **Noch offen:** Die Taube landet manchmal knapp außerhalb des Bildes (man sieht sie anfliegen). Die Terrassen selbst sind noch schlichte Dächer ohne Deko.
4. [ ] **Automatik:** Helfer, Putzroboter, Drohnen – **nur während man spielt, kein Idle-Fortschritt** (Entscheidung des Users, 15.11.2026)
   - Vorschlag: Putzkräfte (früh, günstig) → Putzroboter (fährt eine Spalte ab) → Drohnenschwarm (spät, auch über den Wolken). Helfer putzen nur in schon erreichten Stockwerken, damit Selberputzen der Hauptteil bleibt. HUD-Anzeige „Helfer: +N Fenster/Minute“.
4b. [x] **Am Boden: Händler und Casino** (Entscheidungen des Users, 15.11.2026) – **Händler und Casino fertig**
   - **Händler** auf dem Stellplatz „Händler“: Stände mit Figur, hingehen und E drücken öffnet ein Menü.
     - *Putzmittel-Boosts:* zum Beispiel Glanzspray (eine Zeit lang schneller putzen) und Goldpolitur (eine Zeit lang doppeltes Geld pro Fenster).
     - *Aussehen:* Farben für Gondel und Werkzeug, Arbeitskleidung/Helm. Nur Optik.
     - *Snacks mit Effekt:* Kaffee (Gondel fährt eine Zeit lang schneller), Eis (mehr Reichweite) und Ähnliches.
   - **Casino** als **begehbares Gebäude** auf dem Stellplatz „Casino“: Man geht hinein, drinnen stehen die Spiele einzeln, jeweils mit E an der Station.
     - Blackjack-Tisch
     - Glücksrad
     - Einarmiger Bandit (Putz-Symbole: Schwamm, Eimer, Fenster, Taube …)
     - Rubbellose (passt zum Reiben)
   - **Händler – Ergebnis (15.11.2026):**
     - `skripte/haendler.gd`: drei Marktstände nebeneinander auf dem Händler-Stellplatz mit Front zum Turm, jeweils mit gestreiftem Dach, Schild, Waren und einer winkenden Verkäufer-Figur.
     - `skripte/haendler_menu.gd`: Menü, das man mit E vor dem Stand öffnet.
     - **Putzmittel:** Glanzspray (5 min, Wisch-Fläche +50 %), Goldpolitur (5 min, doppeltes Geld pro Fenster).
     - **Snacks:** Kaffee (4 min, Gondel +60 % schneller), Eis (4 min, Reichweite +0,8 m), Zitronenlimo (5 min, keine Tauben).
     - Boosts: Nochmal kaufen verlängert sie. Der Preis steigt mit der erreichten Höhe (+35 % je Abschnitt). Die Restzeit steht unter dem Geld und wird gespeichert.
     - **Mode & Farben:** 6 Gondelfarben (Gold glänzt metallisch), 4 Jacken/Overalls (Farbe des Arms), 4 Schwammfarben. Kaufen, danach jederzeit „Anziehen“. Nur Optik, wird gespeichert.
     - Alle Zahlen stehen in `wirtschaft.gd` (`BOOSTS`, `KOSMETIK`).
     - **Umbau nach Rückmeldung des Users (15.11.2026):** Stadt noch näher (Platz 100 m), Stände verteilt in den drei Lücken zwischen den Turmflügeln (`Welt.STAND_WINKEL`), Casino-Grundstück hinter einer Flügelspitze in der Stadt (`Welt.CASINO_*`).
     - **Moderne Kioske statt Marktständen:** Das zuerst gefundene Fantasy Town Kit ist mittelalterlich und passt nicht zur modernen Stadt (Wunsch des Users: vorher prüfen). Deshalb aus Code ein Glas-Kiosk mit Flachdach, farbigem Leuchtschild, Deckenlicht und Theke. Einrichtung und Figuren aus Kenney-Paketen (CC0, Vorschaubilder geprüft), in `modelle/` mit eigenen Textur-Ordnern:
       - `laden/`: Mini Market – Regale, Kasse, Kleiderständer, Schaufensterpuppen, Kühlschrank, Eistruhe, Brot-Auslage
       - `leute/`: Mini Characters – Verkäufer
       - `essen/`: Food Kit – Kaffee, Eis, Limo, Donut, Zitrone …
       - `stadt/`: City Kit Commercial – Sonnenschirme mit Tisch vor dem Snack-Kiosk
     - Kenney-Mini-Modelle werden ×2,25 skaliert, Figuren stehen auf einem Podest und sind um 180° gedreht (sie schauen von Haus aus nach +Z). Größen misst `tools/messen.gd`. Testbilder: `--ansicht=15`.
     - Test `--ansicht=14 --geld=10000`: an alle drei Stände gehen, mit E öffnen, über die echten Knöpfe kaufen, Wirkung prüfen. Bestanden.
   - Bezahlt wird nur mit Spielgeld, es gibt nie Käufe mit echtem Geld. Einsatzgrenzen, damit man sich nicht in einer Minute alles verspielt.
   - **Casino – Ergebnis (15.11.2026):**
     - `skripte/casino.gd`: begehbares Gebäude (26 × 26 m, 6,5 m hoch) auf `Welt.casino_rect`, komplett aus Code: dunkle Fassade mit goldenen Lisenen, Glasband, Vordach, roter Teppich mit Absperrpfosten, Leuchtschrift „CASINO“ auf dem Dach (zur Turmseite) und an den Seiten, blinkende Leuchtstreifen. Tür-Öffnung (5 m) zur Turmseite (−X).
     - Innen: Teppich mit Rautenmuster (Textur aus Code), weinrote Wände mit Holzsockel und Goldleiste, Decke mit Lichtfeldern, 5 OmniLights + je eins pro Station, vier Säulen, Bar (nur Deko), Gäste und Personal aus den Kenney-Paketen (`leute/`, `laden/`, `essen/`).
     - Kollision zu Fuß: Wände (Tür frei), Säulen, Stationen, Bar als `Rect2` in `casino.rechtecke` → `laeufer.hindernisse`.
     - Vier Stationen (`Casino.STATIONEN`), davor stehen und **E** drücken (`casino.station_bei()`), HUD zeigt „E: Blackjack spielen“ usw.
     - `skripte/casino_menu.gd`: Spielfenster (Maus frei, E/Esc schließt). Einsatz mit −/+/Max wählbar. Der Einsatz wird beim Start der Runde abgezogen, der Gewinn am Ende gutgeschrieben, danach wird gespeichert. Wer mitten in einer Runde schließt, bekommt das Ergebnis sofort.
       - **Blackjack:** Austeilen, Karte ziehen, Stehen bleiben. Geber zieht bis 17, Blackjack zahlt 3:2, Unentschieden = Einsatz zurück.
       - **Glücksrad:** 32 gleich große Felder (16× 0, 5× ½, 6× 1, 2× 2, 1× 3, 1× 5, 1× 10), dreht sich etwa 4 Sekunden.
       - **Einarmiger Bandit:** 3 Walzen mit gezeichneten Putz-Symbolen. 3× Gondel 45×, 3× Fenster 25×, 3× Eimer 15×, 3× Schwamm 10×, zwei gleiche = halber Einsatz zurück, Tauben bringen nichts.
       - **Rubbellos:** Los kaufen (Preis = Einsatz), mit gedrückter Maustaste die Dreckschicht wegrubbeln (oder „Alles aufdecken“). 9 Felder, drei gleiche Beträge = dieser Betrag ist gewonnen (1×, 2×, 5×, 10×, 50×).
     - `skripte/casino_regeln.gd`: alle Regeln und Zahlen ohne Oberfläche. **Einsatzgrenzen:** mindestens 10 €, höchstens 10 % des Geldes (auf 10 € abgerundet), nie mehr als 5.000 €. Rückzahlung gemessen (je 200.000 Runden): Blackjack 96 %, Glücksrad 95 %, Bandit 94 %, Rubbellos 96 % – also leicht zugunsten des Hauses.
     - Nebenbei behoben: Zu Fuß hat ein Klick in ein offenes Menü die Maus wieder gefangen (betraf auch die Händler-Menüs). `Laeufer.gesperrt` verhindert das jetzt.
     - Test `--ansicht=16 --geld=10000`: durch die Tür laufen, Wand prüfen, an jeder Station mit E öffnen, über die echten Knöpfe spielen (Rubbeln mit echten Mausbewegungen), Geld nachrechnen, Rückzahlung messen. Bestanden (0 Fehler). Testbilder: `--ansicht=17`.
   - Offen: Preise und Dauer der Boosts noch festlegen; im Casino gibt es noch keine Geräusche (kommt mit Phase 5).
4c. [x] **Stadt im Dubai-Stil** (Wunsch des Users, 15.11.2026) – **fertig**
   - **See mit Fontänen** am Turmfuß hinter dem Kiosk bei 210° (`Welt.SEE_*`, `see_abstand()`, `see_umriss()`): spiegelndes Wasser (`shader/wasser.gdshader`), Steinkante, Promenade im Boden-Shader. 74 Fontänen (Bogen, niedrige Reihe, Ring, große Mittelfontäne bis 85 m) mit Strahl, Gischt und Schaum; die Show (4 Bilder, 48 s) rechnet `shader/fontaene.gdshader` selbst, kostet also kaum Leistung.
   - **Palmen** (Kenney Pirate Kit, CC0, Farben über `shader/palme.gdshader` entsättigt): Ring am Platzrand, Promenade um den See, Mittelstreifen aller Straßen bis 540 m (`StadtDetails.ALLEE_BIS`) – zusammen ca. 860 Palmen.
   - **Laternen** mit zwei Auslegern auf den Mittelstreifen und am See (ca. 390, aus Code).
   - **Straßen** im Boden-Shader: Mittelstreifen mit Rasen + Bordstein, Randlinien, Zebrastreifen vor den Kreuzungen.
   - Zu Fuß: Palmen und Laternen sind Hindernisse (`welt.hindernisse`), in den See kommt man nicht (`laeufer.polygone`).
   - Leistung: 133–160 FPS in 1440p (vorher ca. 150).
   - **Teil 2 – Verkehr** (`skripte/verkehr.gd`, Kenney Car Kit + City Kit Roads, CC0, Vorschaubilder auf Stil geprüft: nur moderne Stadtautos, keine Traktoren/Karts):
     - ca. 720 Autos (Limousine, SUV, Luxus-SUV, Sportwagen, Taxi, Lieferwagen, Polizei …) auf allen Straßen bis 620 m, Rechtsverkehr. Lackfarben wie in Dubai (viel Weiß, Silber, Schwarz) über `shader/auto.gdshader`.
     - Ampeln an jeder Kreuzung (Takt: 11 s grün, 2,5 s gelb, 1,5 s alle rot); die Lampen leuchten wirklich. Autos halten vor dem Zebrastreifen und hinter dem Vordermann (`Verkehr.HALTELINIE`, `ABSTAND`).
     - Sechs grüne Schilderbrücken mit Zielen („Wüstennadel ↑ Innenstadt“ …), `Verkehr.SCHILDER`; darunter stehen keine Palmen.
     - Alle Autos eines Modells sind ein MultiMesh, die Lagen werden jedes Bild als Puffer geschrieben (ca. 1,3 ms pro Bild). Straßenstücke enden mitten im Block, dort tauchen die Autos weich auf und ab.
     - Test `tools/verkehr_test.gd` (60 s ohne Bild): nie Autos beider Richtungen gleichzeitig auf einer Kreuzung, niemand fährt bei Rot – bestanden.
     - Leistung danach: 120–170 FPS in 1440p.
     - Autos fahren durch Fußgänger hindurch (keine Kollision mit dem Läufer).
4d. [x] **Rückmeldung des Users zur Stadt (15.11.2026)** – fertig
   - **Straßen enden an Kreuzungen:** Eine Straße gibt es nur zwischen zwei „guten“ Kreuzungen (`Welt.kreuzung_ok`, `stueck_da`, `arme`, `querverkehr`; der Boden-Shader rechnet genauso). Kreuzungen erst 30 m hinter dem Platz, 14 m hinter der See-Promenade und nicht am Casino. Was früher als Stummel zum Turm oder zum See lief, ist jetzt Fußgängerzone.
   - **Verkehr als Ringe:** Jede Spur fährt hin, wendet auf der End-Kreuzung (nur bei Grün) und fährt zurück – keine Autos tauchen mehr auf oder ab. Test `tools/verkehr_test.gd` bestanden.
   - **Palmen** auf den Mittelstreifen erst 20 m nach der Kreuzung (vorher 11 m, standen fast auf der Kreuzung).
   - **Boden:** Platz und Promenade mit polierten Steinplatten in Ringen um den Turm (Granitbänder), Gehwege mit 0,75-m-Platten und Bordstein, Blumenbeete mit einzelnen Blüten im Grünring.
   - **Mehr Details** (`StadtDetails`): ca. 140 Bänke, 100 Pflanzkübel (mit Palmen oder Büschen aus dem Kenney Nature Kit, CC0), 34 Mülleimer, 33 Leute (Kenney Mini Characters) auf dem Platz und an der Promenade; Fußgängerzonen mit Kübeln und Bänken.
   - **Hochhäuser der Stadt mit sauberen Fenstern** (`dreckig` = 0).
   - **Casino im Sockel eines Hochhauses:** Glasfassade außen wie die anderen Türme (`_verkleidung()`), 34 Stockwerke darüber (`_turm_drauf()`), Leuchtschrift an der Fassade über dem Eingang. Innen unverändert.
   - **Start zu Fuß:** Man startet neben der Gondel unten. Die Gondel merkt sich die letzte Höhe und fährt beim Einsteigen mit 30 m/s dorthin zurück (`Spiel.letzte_hoehe`, `express`). Test `--ansicht=18`.
   - **Werkzeug-Kiosk** (grün, vierter Kiosk) mit fünf neuen Profi-Werkzeugen: Mikrofaser-Schwamm 350 €, Profi-Schwamm XXL 1.800 €, Teleskop-Abzieher 3.500 €, Dampfreiniger 9.000 €, Wasserlanze Turbo 25.000 € (`Wirtschaft.WERKZEUGE` mit `haendler: true`). Tasten 1–9 und 0. Die Werkstatt zeigt sie erst nach dem Kauf; ihre Liste scrollt jetzt. Test `--ansicht=19 --geld=1000`.
5. [ ] **Feinschliff:** Sound und Musik, Funkel-Effekte, Menü und Einstellungen, Tageszeiten, Export als .exe

## Offene Fragen

- ~~Gibt es Fortschritt, während man nicht spielt (Idle)?~~ Entschieden 15.11.2026: **Nein**, Helfer arbeiten nur, solange man spielt.

## Stand

- 15.11.2026: Idee und Grafik-Tests fertig (`Grafiktest/godot-turm`: 3 Turm-Varianten, Vorher-Nachher mit echten Rahmen und Räumen hinter den Fenstern). Variante 1 und Name „Clean the Skyscraper“ gewählt.
