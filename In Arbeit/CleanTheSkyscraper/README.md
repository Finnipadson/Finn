# Clean the Skyscraper

3D-Spiel (Godot 4.7): alle rund 25.600 Fenster eines erfundenen Rekord-Turms aus der Gondel putzen. Bauplan und Phasenstand: [clean-the-skyscraper-plan.md](clean-the-skyscraper-plan.md).

## Starten

- Doppelklick auf **`start.bat`**: startet das Spiel
- `start.bat --editor`: öffnet das Projekt im Godot-Editor
- Godot 4.7 muss installiert sein (`winget install GodotEngine.GodotEngine`)

Steuerung im Moment (Phase 0, freie Kamera):
- Klick: Maus fangen
- WASD: fliegen
- Q/E: runter/hoch
- Shift: schnell
- Esc: Maus wieder frei

## Aufbau

```
project.godot          Projekt (Hauptszene szenen/haupt.tscn)
szenen/haupt.tscn      Startszene
skripte/bau.gd         Bau: Grundrisse, Fassaden-Mesh aus Stockwerken, Rahmen (MultiMesh), Materialien
skripte/turm.gd        Turm „Wüstennadel“: Form, Spitze, Fenster-Nummerierung, fassaden_punkt()
skripte/welt.gd        Welt: Himmel, Licht, Wüste, Stadt
skripte/haupt.gd       Startszene: Welt + Turm + Kamera, Testansichten
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

Mit `godot` ist die `…_console.exe` aus dem winget-Ordner gemeint (siehe `start.bat`). Neue Skripte mit `class_name` werden erst nach `--headless --import` erkannt.
