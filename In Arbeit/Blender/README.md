# Blender-Modelle

Alle Blender-Szenen, die per Blender-MCP gebaut werden. Blender 5.3, Eevee.

## Ordnerstruktur

```
Blender/
├── README.md            ← diese Datei
├── .gitignore           ← ignoriert Blender-Backups (*.blend1)
├── _Skripte/            ← wiederverwendbare Python-Bauskripte (für neue Modelle)
├── Steinwolf/
│   ├── steinwolf.blend
│   └── Renders/         ← Testbilder; Animationen landen in Renders/Animation/
├── Lavadrache/
│   ├── lavadrache.blend
│   └── Renders/
└── Skorpion/
    ├── skorpion.blend
    └── Renders/
```

**Neues Modell:** eigenen Ordner `<Name>/` mit `<name>.blend` und `Renders/` anlegen,
Render-Ausgabe der Szene auf `<Name>/Renders/Animation/` stellen.

## Modelle

| Modell | Inhalt | Animation |
|---|---|---|
| Steinwolf | Stein-/Lava-Wolf, Glüh-Risse, Spiralen, Energiebänder, Blitze | 300 Frames @ 60 fps, Atmen/Knurren, Angriffssprung |
| Lavadrache | Lava-Drache: glatter Metaball-Körper + Skelett, Flügel-Armatures, Schuppenreihen, Stacheln, Kristallkrallen | 300 Frames @ 60 fps, Flügelschlag, Schwanzwelle, Feuerspucken (Frame ~140–246) |
| Skorpion | Violetter Kristall-/Schatten-Skorpion: glatter Metaball-Körper + Skelett, Kristall-Sichelscheren, glühender Stachel, Panzerplatten, Ketten-Ringe, Splitter, Nebel, Runenkreis im Boden | 300 Frames @ 60 fps, Schwanz pendelt + Stich (Frame ~170–250), Scheren auf/zu, Beine tippeln, Ketten/Splitter kreisen |

## Skripte (`_Skripte/`)

In Blender ausführen mit `exec(open(r"...\_Skripte\<datei>.py", encoding="utf-8").read())`.

| Datei | Zweck |
|---|---|
| `wolf_helpers.py` | Grundbausteine: `frustum`, `ico`, `cone`, `empty`, `curve_obj`, `driver` |
| `dragon_helpers.py` | Erweiterung: geglättete Boxen/Blobs/Stacheln, Hörner per Kurve, Gelenke, `keep_parent` |
| `dragon_materials.py` | Materialien: Stein mit Glüh-Rissen, Panzer, Kristall, Flügelhaut, Glühen |
| `dragon_smooth.py` | Glatter Körper aus Metaballs (PCA-Anpassung an Teile, Capsules, rounded Cubes) |
| `rebuild_skel.py` | Skelett neu aus den Gelenk-Empties (CHILD_OF-Constraints) |
| `dragon_rebuild2.py` | Körper neu bauen + Smooth/Displace einbacken + an Skelett binden |
| `dragon_details.py` | Wirbelsäulen-Pfad + Raycast-Helfer für Schuppen/Stacheln/Bauchplatten |
| `fps60.py` | Szene von 24 auf 60 fps umstellen (Drivers + Keyframes), headless nutzbar |
| `skorpion_env.py` | Skorpion: Umgebung (Boden mit Runenkreis im Material, Wand, Himmel, Bloom) + violette Materialien |
| `skorpion_body.py` | Skorpion: Gelenk-Empties, glatter Metaball-Körper direkt aus Capsules/Ellipsoiden, Skelett + Bindung |
| `skorpion_details.py` | Skorpion: Sichelklingen (Kurve mit Profil-Objekt), Stachel, Augen, Krone, Panzerplatten, Dornen (Raycast nur gegen den Körper) |
| `skorpion_fx.py` | Skorpion: Splitter, Ketten-Ringe (Array + Curve), Nebel-Volumen, Lichter, alle Animations-Drivers |

Die Skripte sind auf die Lavadrache-Namen zugeschnitten (z. B. `Schwanz_J*`, `Drachenkoerper`) –
für neue Modelle als Vorlage kopieren und anpassen.
