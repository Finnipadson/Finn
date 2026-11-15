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
- 1–5: Werkzeug wechseln
- **B: Sammelalbum** (entdeckte Szenen hinter den Fenstern)
- **E (ganz unten): Gondel verlassen**, zu Fuß: WASD, Shift rennen, Leertaste springen; an der Gondel E: einsteigen
- In der Werkstatt unter „Einstellungen“: Tauben, Sandsturm und Windböen an/aus
- **Händler** auf dem Platz: zu Fuß vor einen Stand gehen und **E** drücken (Putzmittel-Boosts, Mode & Farben, Snacks)
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
modelle/               Kenney-Modelle (CC0): laden/ (Mini Market), leute/ (Mini Characters), essen/ (Food Kit), stadt/ (City Kit Commercial) – je mit Textures/ und Lizenz
tools/messen.gd        Größen aller Modelle ausgeben: godot --path . --headless --script tools/messen.gd
skripte/haendler_menu.gd  Menü der Stände: Boosts kaufen, Aussehen kaufen/anziehen
skripte/album.gd       Sammelalbum (Taste B)
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
