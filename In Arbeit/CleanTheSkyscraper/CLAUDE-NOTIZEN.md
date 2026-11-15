# Arbeitsnotizen für Claude – CleanTheSkyscraper

Wird vor der Arbeit an diesem Projekt gelesen (Verweis in der Haupt-`CLAUDE.md`). Neue Projektdetails hier eintragen, nicht in der Haupt-`CLAUDE.md`.

- 3D-Spiel „Clean the Skyscraper“ (Godot 4.7, PC): alle ~25.600 Fenster eines erfundenen Rekord-Turms aus der Gondel putzen
- Bauplan + Phasenstand: `clean-the-skyscraper-plan.md` (Phase 3 fertig: Szenen im Glas-Shader über B-Kanal der Zustands-Textur, Album `album.gd` Taste B, Tauben/Wind/Sandsturm in `ereignisse.gd`, Boden-Shader
- Tests `--ansicht=11` Szenen, `12` Ereignisse, `13` zu Fuß
- Zu Fuß: `laeufer.gd` (E unten aus-/einsteigen, Kollision Turm/`welt.haeuser`/Gondel), Händler fertig (`haendler.gd` moderne Glas-Kioske mit Kenney-Modellen aus `modelle/laden|leute|essen|stadt` – Mini-Modelle ×2,25, Figuren um PI drehen
- vor dem Auswählen von Asset-Paketen Vorschaubilder auf Stil prüfen, `haendler_menu.gd`, Boosts/Kosmetik in `wirtschaft.gd` `BOOSTS`/`KOSMETIK`, Test `--ansicht=14 --geld=10000`), Stadt im Dubai-Stil Teil 1 fertig: `stadtdetails.gd` (See mit Fontänen `Welt.SEE_*`/`see_abstand()`, Palmen aus `modelle/natur` + Laternen als MultiMesh, Hindernisse in `welt.hindernisse`, See-Kollision `laeufer.polygone`
- Shader `wasser`/`fontaene`/`palme`), Testbilder `--ansicht=1 --kamera=x,y,z,zx,zy,zz`
- Teil 2 Verkehr fertig: `verkehr.gd` (Autos aus `modelle/autos` als MultiMesh-Puffer, Ampeln/Schilderbrücken aus `modelle/strasse`, Lack über `shader/auto.gdshader`, Prüfung `--headless --script tools/verkehr_test.gd`
- Spuren sind Ringe mit Wenden an der End-Kreuzung)
- Straßennetz: nur zwischen zwei `Welt.kreuzung_ok`-Kreuzungen (Boden-Shader rechnet gleich)
- Start zu Fuß + Express-Gondel (`--ansicht=18`), Werkzeug-Kiosk mit Profi-Werkzeugen (`profi: true` in `WERKZEUGE`, `--ansicht=19`), Casino im Hochhaus-Sockel
- Phase 4 fertig: Turmseiten `Turm.seiten`/`seite_bei`/`weg_auf_seite` (Test `tools/seiten_test.gd`), drei Gondeln `gondeln.gd` (Daten `Wirtschaft.gondeln`, Express runter/hoch), Helfer `helfer.gd` (`Wirtschaft.HELFER`, Signal `geputzt`), Fahrzeuge `fahrzeuge.gd` + Läufer (Jetpack mit `welt.haeuser_hoehe`), Hotbar `Hud.hotbar`, 6 Kioske
- Tests `--ansicht=20|21|22`
- Begehbares Casino fertig: `casino.gd` Gebäude + vier Stationen auf `Welt.casino_rect`, `casino_menu.gd` Spielfenster Blackjack/Glücksrad/Bandit/Rubbellos, `casino_regeln.gd` Regeln + Einsatzgrenzen, Tests `--ansicht=16 --geld=10000` Spiele und `17` Bilder
- Menüs zu Fuß setzen `laeufer.gesperrt`
- Einstellungen Tauben/Sandsturm/Wind in `wirtschaft.einstellungen`
- Davor Phase 2: Werkstatt mit Tab, Werkzeuge, Seilwinde, Speichern in `user://spielstand.json`
- Spiel-Logik in `spiel.gd`, Balance-Zahlen in `wirtschaft.gd`
- Tests `--ansicht=8` Maus, `9 --geld=10000` Shop, `10` Speichern)
- Start `start.bat`, Aufbau in `README.md` (`skripte/bau.gd` Bauteile als statische Funktionen, `turm.gd` mit `fenster_id()`/`fassaden_punkt()`/`naechster_weg()`, `fenster_zustand.gd` Dreck-Datentextur + Wisch-Atlas, `spieler.gd` Gondel + Putzen, `hud.gd`, `welt.gd`, `haupt.gd`
- Testbilder `--write-movie … -- --ansicht=1..6` (5 = Putz-Demo, 6 = Fahrtest mit `--frei`)
- Standard-AA: 2× Supersampling + MSAA 4x, kein TAA, SSR aus (`--ssr=1` an). Einstellung „Extra-Kantenglättung (TAA)“ (`wirtschaft.einstellungen.taa`, Standard aus) = TAA + 1,7× Supersampling; `haupt._grafik()` liest sie, `--taa=0|1` überschreibt. TAA war kurz Standard, aber der User sah das Wackeln im Stand (Schmutz/Pfosten am Turm, gemessen Ort `schmutz_25`: 1,02 mit TAA, 0,00 ohne) → aus. SSR spiegelte den Boden verschmiert in die Brüstungen am Turmfuß und brachte sonst kaum sichtbar etwas (+~15 % FPS ohne)
- Turm-Brüstungen: `Bau.rahmen` baut das Band pro Stockwerk als ein Mesh mit Gehrungs-Ecken (`BAND_AUSSEN`/`BAND_INNEN`); überlappende Kästen flackerten an den Ecken. Pfosten auf einer Ecke nur einmal. Allee-Palmen je Straßenstück bei 22,5/37,5/52,5 m (`StadtDetails.ALLEE_ORTE`, Mitte = Laterne) – früher stand die Formel verkehrt herum und die Palmen auf Kreuzungen
- Flimmern messen (Orte u. a. `schmutz_25/60` = Kamera steht vor dem Turm, zeigt TAA-Wackeln; Ansicht 4 kennt `--abstand=m`): `python tools/flimmern.py AUSGABE [--orte=a,b] [--name=x] [--projekt=alter_stand] [-- godot-schalter]` – nimmt je Ort 16 Bilder bei langsam bewegter Kamera auf (`--fahrt=dx,dy,dz` m/s, `--dreh=grad/s`, `--tempo=f` für Ansicht 4) und misst die zweite zeitliche Ableitung (gleichmäßige Bewegung ≈ 0, Flimmern groß). Kamera muss langsam sein (nächstes Objekt < 0,5 px/Bild), sonst misst man nur Bewegungskanten; Autos/Wind zählen mit. Weitere Test-Schalter `--ssao=0 --schatten=0 --glow=0`
- Gegen Flimmern in Shadern: keine harten `step`/`fract`-Kanten – gefilterte Streifen (`streifen()`/`band_k()` in `boden.gdshader`/`fassade.gdshader`, Breite = `fwidth`×1,25) und Zufall pro Zelle/feines Rauschen per `fwidth` auf Mittelwert ausblenden, bevor die Zelle < ~4 Bildpunkte ist. MSAA/Supersampling glätten Shader-Muster kaum. Geprüft ohne Wirkung: SSR/SSAO/Schatten aus, Rahmen-Normalen biegen (schlechter); FSR2 nativ deutlich schlechter. Z-Fighting gab es nicht (Godot 4.7 Reverse-Z)
- nach neuen `class_name`-Skripten erst `--headless --import`)
- Grafik-Grundlage `Games/In Arbeit/Grafiktest/godot-turm` (Turm aus Code: Grundriss pro Stockwerk, `shader/turm.gdshader` mit Interior Mapping, Rahmen als MultiMesh
- Testbilder per `--write-movie … -- --turm=1 --ansicht=N`)
- Godot-Pfad: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
- Weitere Grafik-Tests in `Grafiktest/` (`strand-test.html`, `godot-strand` mit Kenney-CC0-Modellen)
- Menü-Stil „Glas modern“ in `skripte/ui_glas.gd` (UiGlas.fenster/knopf/reiter/karte) – neue Menüs damit bauen; Werkstatt baut alle Reiter (versteckt), damit Tests Knöpfe per Name finden; alte Knöpfe mit `remove_child` sofort entfernen (sonst bekommen neue Knöpfe andere Namen). Menü-Testbilder `--ansicht=23`
- Palmen-Shader `shader/palme.gdshader`: Stamm (Ringe/Schuppen) vs. Blatt an der Palettenfarbe erkannt, Wind im Vertex-Shader. Büsche in Kübeln mit grünem Material statt Kenney-Türkis
- Extras (4g) fertig: `extras.gd` steuert Ort + Aufzüge (Blende, `_teleport`), Innenräume über `Laeufer.raum` {poly, rechtecke, kreise, boden} (leer = draußen); Turm-/Casino-Fassade hat `innen_band` (Höhenband weglassen, solange die Kamera drin ist). `skylounge.gd` (Stockwerke 48/120 + Ring 800 m), `penthouse.gd` + `arcade.gd` auf `Welt.casino_rect` (Aufzug im Casino `casino.aufzug_pos`), Gegenstände/Boni/Statistik/Erfolge in `wirtschaft.gd` (`GEGENSTAENDE`, `bonus()`, `boost_wirkung()`, `statistik`, `erfolge`, `moebel`), Erfolge in `erfolge.gd`, Menüs `extras_menu.gd`, Tests `extras_test.gd` (24–28, Bilder per `BILD n frame=`). Lohn immer über `Spiel.lohn_mit_boni()`, Einnahmen über `wirtschaft.verdienen()`. Möbel-Modelle `modelle/moebel` (Kenney Furniture Kit), Bild-IDs `Symbole.bilder["g_" + id]`
- Bilder für Hotbar/Menüs: `skripte/symbole.gd` rendert beim Start jedes Werkzeug (`Spieler.werkzeug_modell`, statisch) und Fahrzeug in einem SubViewport → `Symbole.bilder[id]`; `UiGlas.karte(..., bild)` und `Hud.hotbar` (Eintrag `bild`) zeigen sie
