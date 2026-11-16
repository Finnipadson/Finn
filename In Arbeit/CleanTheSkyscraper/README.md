# Clean the Skyscraper

3D-Spiel (Godot 4.7): alle rund 25.600 Fenster eines erfundenen Rekord-Turms aus der Gondel putzen. Bauplan und Phasenstand: [clean-the-skyscraper-plan.md](clean-the-skyscraper-plan.md).

## Starten

- Doppelklick auf **`start.bat`**: startet das Spiel
- `start.bat --editor`: öffnet das Projekt im Godot-Editor
- Godot 4.7 muss installiert sein (`winget install GodotEngine.GodotEngine`)

Steuerung (Phase 1, Gondel):
- Klick: Maus fangen
- Maus: umschauen
- **Linke Maustaste halten + Maus bewegen: putzen**
- A/D: an der Fassade entlang
- W/S: hoch/runter (so weit das Seil reicht, mit `--frei` alle)
- **Tab: Werkstatt** (Werkzeuge, Gondel-Upgrades, Seilwinde, Neues Spiel)
- 1–9 und 0: Werkzeug wechseln (6–0 sind die Profi-Werkzeuge vom Werkzeug-Kiosk)
- **B: Sammelalbum** (entdeckte Szenen hinter den Fenstern)
- **E (ganz unten): Gondel verlassen**, zu Fuß: WASD, Shift rennen, Leertaste springen; an der Gondel E: einsteigen
- In der Werkstatt unter „Einstellungen“: Tauben, Sandsturm und Windböen an/aus
- **Händler** auf dem Platz: zu Fuß vor einen Stand gehen und **E** drücken (Putzmittel-Boosts, Mode & Farben, Snacks)
- **Casino** (dunkles Gebäude mit Leuchtschrift hinter einer Flügelspitze): hineingehen, vor Blackjack-Tisch, Glücksrad, Banditen oder Rubbellos-Theke **E** drücken. Nur Spielgeld, Einsatz 10 € bis 10 % des Geldes (höchstens 5.000 €)
- **Sky-Lounge**: verglaster Eingang mit Vordach unten in der Turmecke zwischen zwei Flügeln, E drücken. Lounge (200 m), Restaurant (500 m) und Aussichtsplattform (800 m) sind frei, sobald das Seil so hoch reicht. Bars mit Spezial-Boosts, Designer- und Exklusiv-Möbel
- **Aufzug im Casino** (Aufzugskern hinten rechts, gegenüber dem Eingang): Arcade-Halle (1. Stock) und dein **Penthouse** (Dach)
- **Arcade**: Greifautomat (WASD/Pfeile Kralle bewegen, Leertaste greifen), Kapsel-Automat. Gewinne landen im Penthouse-Lager
- **Penthouse**: am Tablet Möbel kaufen und unter „Meine Sachen“ aufstellen; Vorschau mit der Blickrichtung zielen, R/Mausrad drehen, Klick abstellen, X ins Lager, Esc abbrechen; vor einem Möbel E = umstellen. Aufgestellte Gegenstände geben Boni (je seltener, desto stärker)
- **P: Erfolge und Statistik** (auch an der Vitrine im Penthouse). Jeder Erfolg gibt Geld und einen Pokal für die Vitrine
- Beim Putzen zusätzlich **rechte Maustaste halten: umschauen**, das Werkzeug bleibt am Glas
- Esc: Maus frei

Freie Kamera zum Anschauen: `--ansicht=1` bis `4` (WASD fliegen, Q/E runter/hoch, Shift schnell).

## Aufbau

```
project.godot          Projekt (Hauptszene szenen/haupt.tscn)
szenen/haupt.tscn      Startszene
skripte/bau.gd         Bau: Grundrisse, Fassaden-Mesh aus Stockwerken, Rahmen (MultiMesh), Materialien
skripte/turm.gd        Turm „Wüstennadel“: Form, Spitze, Fenster-Nummerierung, fassaden_punkt()
skripte/welt.gd        Welt: Himmel, Licht, Wüste, Stadt
skripte/haupt.gd       Startszene: Welt + Turm, Spiel (Gondel, Geld, Funkeln) oder freie Kamera/Testansichten
skripte/spieler.gd     Gondel mit Ich-Ansicht: fahren, umschauen, Schwamm reiben → _stempel()
skripte/fenster_zustand.gd  Dreck pro Fenster (Datentextur) + feine Wisch-Masken (Atlas, 64 Slots)
skripte/spiel.gd       Spiel-Logik: Geld, Funkeln, Werkstatt, Speichern/Laden (user://spielstand.json), Tests 5–10
skripte/wirtschaft.gd  Zahlen zum Ausbalancieren: Lohn, Werkzeuge, Upgrades, Preise
skripte/shop.gd        Werkstatt-Fenster
skripte/laeufer.gd     Zu Fuß am Boden: Laufen, Springen, Kollision mit Turm/Häusern/Gondel
skripte/haendler.gd    Drei moderne Glas-Kioske mit Verkäufern, verteilt zwischen den Turmflügeln
skripte/gondeln.gd     Drei Gondeln (eine je Turmseite): geparkte Modelle, Kaufen, Umsteigen
skripte/helfer.gd      Automatik: Putzkräfte, Putzroboter, Putzdrohnen
skripte/fahrzeuge.gd   Modelle für E-Scooter, Hoverboard, Jetpack
skripte/verkehr.gd     Straßenverkehr: ca. 720 Autos (Rechtsverkehr, halten an roten Ampeln und hinter dem Vordermann), Ampeln an allen Kreuzungen, grüne Schilderbrücken
shader/auto.gdshader   Kenney-Autos mit eigener Lackfarbe pro Auto (Lack-Feld der Farbpalette wird ersetzt)
tools/verkehr_test.gd  Verkehr ohne Bild prüfen: godot --path . --headless --script tools/verkehr_test.gd
skripte/stadtdetails.gd  Stadt im Dubai-Stil: See mit Fontänen-Show, Palmen (Platz, See, Mittelstreifen), Laternen – alles als MultiMesh
shader/wasser.gdshader, fontaene.gdshader, palme.gdshader  Wasser, Fontänen (Choreografie im Shader, 48 s), Palmen-Farben
modelle/               Kenney-Modelle (CC0): moebel/ (Furniture Kit), laden/ (Mini Market), leute/ (Mini Characters), essen/ (Food Kit), stadt/ (City Kit Commercial), natur/ (Palmen aus dem Pirate Kit), autos/ (Car Kit), strasse/ (City Kit Roads: Ampeln, Schilderbrücken) – je mit Textures/ und Lizenz
tools/messen.gd        Größen aller Modelle ausgeben: godot --path . --headless --script tools/messen.gd
skripte/haendler_menu.gd  Menü der Stände: Boosts kaufen, Aussehen kaufen/anziehen
skripte/casino.gd       Begehbares Casino (Gebäude, Innenraum, vier Stationen, Kollisions-Rechtecke)
skripte/casino_menu.gd  Spielfenster: Blackjack, Glücksrad, Einarmiger Bandit, Rubbellos
skripte/casino_regeln.gd  Regeln, Auszahlungen und Einsatzgrenzen der Casino-Spiele (zum Ausbalancieren)
skripte/album.gd       Sammelalbum (Taste B)
skripte/extras.gd      Steuerung der Extras: Ort (draußen, Lounge-Etagen, Arcade, Penthouse), Aufzugfahrt, Tasten E/P/R/X, Hinweise
skripte/skylounge.gd   Express-Aufzug am Turm + Sky-Lounge (Stockwerk 48), Restaurant (120), Aussichtsplattform (800 m)
skripte/penthouse.gd   Penthouse oben im Casino-Hochhaus: Glaswände, Vitrine mit Pokalen, Tablet, Möbel platzieren
skripte/arcade.gd      Arcade-Halle (1. Stock Casino-Hochhaus): Greifautomaten (Spiel mit eigener Kamera), Kapsel-Automaten
skripte/extras_menu.gd Menüs: Aufzüge, Möbel-Läden + Einrichten, Kapsel-Automat, Erfolge + Statistik
skripte/erfolge.gd     Liste der 32 Erfolge (Geld + Pokal) und Prüfung
skripte/moebel.gd      Modelle der Penthouse-Gegenstände (Kenney Furniture Kit), Einfärben, Seltenheits-Leuchten
skripte/raum_bau.gd    Bausteine für Innenräume (Boden/Decke/Glaswand aus Grundriss, Lichter, Schrift, Kenney-Modelle)
skripte/extras_test.gd Tests 24–28
skripte/laeden.gd      Vier begehbare Läden am Platz (Möbelhaus, Gondel-Werkstatt, Souvenirshop, Goldschmuck), Stationen, Kollision
skripte/andenken.gd    Souvenirs + Gold-Deko als Modelle aus Code ("code:…" in Wirtschaft.GEGENSTAENDE)
skripte/gondel_deko.gd Gondel-Rumpf, Lackierungs-Muster, Aufkleber, Blumenkästen, Sonnenschirm (Gondel-Werkstatt)
skripte/laeden_deko.gd Verschönerung der Läden: Markisen, Aufsteller, Bodenmuster, Leute, Lackierkabine, Modell-Stadt, Kronleuchter …
skripte/laeden_test.gd Tests 29 (Läden) und 30 (Testbilder)
skripte/kueste.gd      Küste hinter dem See: Meer, Strand (2 m tiefer), Ufermauer, Treppen, Palmen-Boulevard mit Kanal und Brücken, Steg mit Fischladen, Strandbar; Bodenhöhe + Sperren zu Fuß
skripte/strand_deko.gd Strand-Deko aus Code (Rettungstürme, Volleyball, Sandburgen, Möwen, Krabben, Bojen …) + Kenney-Modelle aus modelle/strand
skripte/strand.gd      Strand im Spiel: Stationen Strandbar/Fischladen/Yacht, Angeln zu Fuß und vom Boot, Ein-/Aussteigen Yacht
skripte/angeln.gd      Angel-Minispiel „Spannungsbalken“ (Wurf, Biss, Drill, Fang-Karte), Angel-Modelle
skripte/fische.gd      20 Fische aus Code (Körper-Loft, Flossen, Sonderteile), Muster über shader/fisch.gdshader
skripte/fisch_menu.gd  Fischladen: Fische verkaufen, Angeln kaufen
skripte/yacht.gd       Eigene Yacht (Modell aus Code, fahren, Kamera, Kielwasser)
skripte/karte.gd       Karte (Taste M), Ziel per Klick, Pfeil im Bild mit Wegsuche
skripte/strand_test.gd Tests 31 (Strand, Angeln, Yacht, Karte) und 32 (Testbilder)
shader/meer.gdshader   Meer (türkis → tiefblau, Schaum an der Wasserlinie), sand.gdshader Strand, wasserfall.gdshader Kanal-Wasserfall
tools/groessen.gd      Größen der Möbelhaus-Möbel ausgeben (zum Einrichten der Zimmer)
shader/seltenheit.gdshader  leuchtender Rand in der Farbe der Seltenheit (auch Vorschau grün/rot beim Platzieren)
skripte/ereignisse.gd  Tauben, Windböen, Sandsturm (Zeiten oben im Skript)
shader/boden.gdshader  Boden: Platz, Park, Straßenraster, Übergang in die Wüste
skripte/hud.gd         Anzeigen: saubere Fenster, Geld, Höhe, Fenster-Fortschritt, „+1 €“
shader/turm.gdshader   Glas des Turms: Räume hinter den Fenstern (Interior Mapping), Dreck, Ferne
shader/fassade.gdshader  einfache Fassade der Stadt
shader/himmel.gdshader   Himmel mit Comic-Wolken
```

**Fenster:**
- Ein Stockwerk ist `{poly, y0, h}`.
- Die Fassaden-UV ist in Metern: x ist der Weg entlang des Umfangs, y die Höhe.
- Fenster liegen alle `FENSTER_B` (1,5 m) entlang des Umfangs.
- `Turm.fenster_id(stockwerk, weg)` gibt die Nummer eines Fensters, `Turm.fenster_basis` die erste Nummer pro Stockwerk.

## Testbilder

```
godot --path . --write-movie bild.png --fixed-fps 30 --quit-after 15 -- --ansicht=N
```
- `--ansicht=1`: Turm von weitem
- `--ansicht=2`: Fassade nah, ein Fenster rot markiert. Damit lässt sich prüfen, ob die Nummerierung und die Fenster im Shader übereinstimmen.
- `--ansicht=3`: Aussicht aus Stockwerk 150
- `--ansicht=4`: Testfahrt an der Fassade (zum Messen von Flimmern)
- `--ansicht=5`: Spiel-Demo, der Schwamm putzt automatisch in Schlangenlinien
- `--ansicht=6`: Gondel-Testfahrt um die Flügelspitze und über die Stufe (mit `--frei`)
- `--ansicht=7`: waagerechte Testfahrt um Flügelspitzen und Innenecken (Flimmern an Kanten)
- `--ansicht=9 --geld=10000`: Shop-Test (Tab, echte Knöpfe, Werkzeugtasten, Hochdruck)
- `--ansicht=10 --geld=500`, danach `--ansicht=10`: Speichern und Laden (nur `user://spielstand_test.json`)
- `--ansicht=11`: alle 10 Szenen in den Fenstern vor der Gondel, Album-Test
- `--ansicht=16 --geld=10000`: Casino-Test (hineinlaufen, alle vier Spiele über die echten Knöpfe, Geld nachrechnen, Rückzahlung messen)
- `--ansicht=1 --kamera=x,y,z,zielx,ziely,zielz`: freie Kamera an eine feste Stelle (Testbilder), z. B. See von oben: `--kamera=-30,110,-18,-150,0,-95`
- `--ansicht=18`: Start zu Fuß neben der Gondel, einsteigen, Express-Fahrt zurück auf die letzte Höhe
- `--ansicht=19 --geld=1000`: Werkzeug-Kiosk (öffnen, Mikrofaser-Schwamm kaufen, Tasten 1 und 6)
- `--ansicht=20 --geld=5000`: Gondeln (Express nach unten, Gondel kaufen, umsteigen, auf der Seite bleiben)
- `--ansicht=21 --geld=100000`: Helfer kaufen und 45 s arbeiten lassen (Fenster + Geld nachrechnen)
- `--ansicht=22 --geld=20000`: Fahrzeuge, Hotbar, Mausrad, roter Werkzeug-Kiosk
- `godot --path . --headless --script tools/seiten_test.gd`: jedes Fenster gehört genau einer Turmseite
- `--ansicht=17`: Casino von außen, innen und vor jeder Station (Testbilder)
- `--ansicht=24 --geld=10000`: Erfolge + Statistik (Zählen, Geld, Speichern/Laden, Taste P)
- `--ansicht=25 --geld=200000`: Sky-Lounge (Aufzug mit Sperre, Glaswand, Bar-Boost, Designer-Laden, Restaurant, Plattform)
- `--ansicht=26 --geld=200000`: Penthouse (Möbel kaufen, aufstellen, drehen, Kollision, umstellen, Lager, Pokale)
- `--ansicht=27 --geld=200000`: Arcade (Greifautomat mit Tasten, Treffer/Daneben, Kapsel-Automat, Chancen)
- `--ansicht=31`: Strand (Boulevard, Kanal/Brücke, Mauer/Treppe/Meer, Strandbar, Fischladen, Angeln mit echter Maustaste, Riesen-Sperre, Verkaufen, Fisch-Index, Yacht fahren, Karte + Pfeil, Speichern)
- `--ansicht=32`: Testbilder Strand (`--nur-yacht`: nur die Yacht)
- Bot: `--headless --fixed-fps 20 -- --durchspielen --angeltest=30 [--angel=hochsee] [--abschnitt=N] [--drinks] [--boot] --stand=x` misst Angeln allein
- `--ansicht=28`: Testbilder der Extras (alle 1,5 s eine Ansicht, Bildnummern stehen als `BILD n frame=…` auf der Konsole)
- `--ansicht=15`: nacheinander vor jedem Kiosk, erst von weitem, dann von nah (Testbilder)
- `--ansicht=14 --geld=10000`: Händler-Test (alle Stände, echte Knöpfe, Wirkung der Boosts und Farben)
- `--ansicht=13`: Aussteigen, Laufen, Kollision, Einsteigen, Einstellungen-Knöpfe
- `--ansicht=12`: Taube, Windböe und Sandsturm sofort auslösen
- `--ansicht=8`: Maus-Test. Schickt echte Klicks und Mausbewegungen durch das Eingabesystem, putzt und schaut um, und gibt `TEST …` auf der Konsole aus.

**Wichtig:** Im Spiel steht die gefangene Maus immer in der Bildmitte. Jedes Control dort, das Klicks abfängt (`mouse_filter` = STOP, der Standard bei ColorRect und PanelContainer), schluckt alle Eingaben. Deshalb setzt `Hud._maus_durchlassen()` alles auf IGNORE.

Grafik-Schalter zum Vergleichen: `--taa=0|1 --msaa=0..3 --smaa=0|1 --scale=10..20 --fsr=0|1 --ssr=0|1 --ssil=0|1`, dazu `--fpstest=1` (gibt nach 6 s die FPS aus und beendet).

**Standard:** 2-faches Supersampling (`scale` 2,0) + MSAA 4x, **ohne TAA**, SSR an, SSIL aus.
- Gemessen gegen eine fein berechnete Referenz (3200×1800 mit 2-fachem Supersampling): Wie stark ändert sich der Fehler von Bild zu Bild?
- Ergebnis: TAA 3,3, nichts 2,4, MSAA 2,1, Supersampling + MSAA **1,6**.
- TAA wackelt das Bild absichtlich und wirkt dadurch unruhiger.
- Kosten: rund 190 FPS in 1440p auf einer RTX 5070 Ti.

**Gegen Flimmern gilt außerdem:**
- Im Glas-Shader gibt es keine harten `step()`-Kanten, sondern `sst()` über `fwidth`.
- Feine Muster wie die Jalousien blenden aus, sobald sie kleiner als ein Bildpunkt werden.
- Die Rahmen (`shader/rahmen.gdshader`) blenden mit der Entfernung auf die Fassadenfarbe über.

Mit `godot` ist die `…_console.exe` aus dem winget-Ordner gemeint (siehe `start.bat`). Neue Skripte mit `class_name` werden erst nach `--headless --import` erkannt.
