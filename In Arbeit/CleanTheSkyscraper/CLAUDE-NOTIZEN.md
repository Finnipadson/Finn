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
- Standard-AA 2× Supersampling + MSAA, kein TAA
- nach neuen `class_name`-Skripten erst `--headless --import`)
- Grafik-Grundlage `Games/In Arbeit/Grafiktest/godot-turm` (Turm aus Code: Grundriss pro Stockwerk, `shader/turm.gdshader` mit Interior Mapping, Rahmen als MultiMesh
- Testbilder per `--write-movie … -- --turm=1 --ansicht=N`)
- Godot-Pfad: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
- Weitere Grafik-Tests in `Grafiktest/` (`strand-test.html`, `godot-strand` mit Kenney-CC0-Modellen)
