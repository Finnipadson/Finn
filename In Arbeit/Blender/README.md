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
├── Skorpion/
│   ├── skorpion.blend
│   └── Renders/
├── VoxelDrache/
│   ├── voxeldrache.blend
│   └── Renders/
└── VoxelBaum/            ← Deko für Bubble Safari (1 Einheit = 1 Stud)
    ├── voxelbaum_<biom>.blend / .fbx + palette_<biom>.png
    └── Renders/
```

**Neues Modell:** eigenen Ordner `<Name>/` mit `<name>.blend` und `Renders/` anlegen,
Render-Ausgabe der Szene auf `<Name>/Renders/Animation/` stellen.

## Modelle

| Modell | Inhalt | Animation |
|---|---|---|
| Steinwolf | Stein-/Lava-Wolf, Glüh-Risse, Spiralen, Energiebänder, Blitze | 300 Frames @ 60 fps, Atmen/Knurren, Angriffssprung |
| Lavadrache | Lava-Drache: glatter Metaball-Körper + Skelett, Flügel-Armatures, Schuppenreihen, Stacheln, Kristallkrallen | 300 Frames @ 60 fps, Flügelschlag, Schwanzwelle, Feuerspucken (Frame ~140–246) |
| Skorpion | Violetter Kristall-/Schatten-Skorpion: glatter Metaball-Körper + Skelett, Kristall-Sichelscheren, glühender Stachel, Panzerplatten, Ketten-Ringe, Splitter, Nebel, Runenkreis im Boden | 300 Frames @ 60 fps, Schwanz pendelt + Stich nach vorne über den Kopf (Frame ~170–250) mit Giftstrahl (207–234), Scheren-Schlag + Schockwelle im Boden (232–292), Scheren auf/zu, Beine tippeln, Ketten/Splitter kreisen. Daneben ein Ei: wackelt + Risse glühen (60–159), platzt bei Frame 160 auf (Stücke, Blitz, Funken), kleiner Skorpion (eigene Kopie `Skorpion_Baby`) hakt die Scheren über den Rand, zieht sich hoch, kippt raus und krabbelt weg |
| VoxelBaum | Runder Voxel-Baum (TVA-Stil) für Bubble Safari: 0,5-Stud-Würfel, Wolken-Krone aus Ballen + Rauschen, Stamm mit Wurzeln/Ast; Farben über 8×8-Paletten-Textur (Biome per Palette tauschbar), FBX für Roblox | – |
| VoxelDrache | Block-/Voxel-Drache (Roblox-Look): 7-cm-Würfel auf Raster, ein Block-Mesh pro Körperteil, Marine/Blau/Türkis, Panzerplatten, Klingen-Flossen, Kopfkamm, Krallen, gezackte Flügel, Gitterboden | 300 Frames @ 60 fps, Atmen, Flügelschlag, Schwanzpendeln, Kopf/Kiefer, Glühen pulsiert |

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
| `skorpion_gift.py` | Skorpion: Giftstrahl aus der Stachelspitze (Ladung, Strahl, Tropfen, Einschlag), Scheren-Schlag, Schockwelle + Runen-Blitz im Bodenmaterial; Steuerung über Properties `ladung/gift/glut/schlag/welle` an `Sk_Root` |
| `skorpion_ei.py` | Skorpion-Ei neben dem Skorpion: kantige Schale (eigene Material-Kopie `Sk_Ei_Schale`), Nest aus Steinen + Kristallen, Splitter |
| `skorpion_schluepfen.py` | Schlüpf-Animation: Schale zerteilen (Unterteil bleibt), Wackeln, Glühen, ballistische Stücke + Funken, Blitz, Baby = eigene Kopie aller „Skorpion“-Objekte (Bezüge umgehängt, eigene Krabbel-Drivers, Lücke im Nest); `build_hatch()` baut Ei + Animation komplett neu |
| `skorpion_fx.py` | Skorpion: Splitter, Ketten-Ringe (Array + Curve), Nebel-Volumen, Lichter, alle Animations-Drivers |
| `voxelbaum.py` | Voxel-Baum: SDF-Krone → Würfel-Mesh mit Paletten-UVs, Testszene (Terrasse) + Renders + FBX. Headless: `blender -b --factory-startup --python voxelbaum.py -- <Ordner> <wiese\|herbst\|schnee>` |
| `voxeldeko.py` | Voxel-Deko im Baum-Stil (0,75-Würfel): Fliegenpilz, brauner Pilz, Sonnenblume, Blumenbusch, Stein, Blumen-Büschel, Baumstamm, schwebende Insel – gemeinsame Paletten-Textur, FBX je Objekt nach `VoxelBaum/deko_*.fbx` |
| `voxelladen_seife.py` | Seifenladen für Bubble Safari als Voxel-Bau (Box-Helfer, Ziegel/Planken/Dachziegel-Färbung), 5 Teile in einer FBX (Haus, Schild, Flasche, Pumpe, Seife), gleiche Farbflächen per `dissolve_limit(delimit UV)` zusammengefasst |
| `voxelladen_basis.py` | Gemeinsame Helfer für Voxel-Läden (box/zyl/kapsel/scheibe, Mesh mit Paletten-UVs + Flächen zusammenfassen, Export/Renders) – per `exec` in die Laden-Skripte geladen |
| `voxelladen_index.py` / `voxelladen_verkauf.py` | Tier-Index (Sternwarte mit Teleskop) und Verkaufen (Marktstand mit Waage, Schalen, Glocke) |
| `voxel_wurfdeck.py` | Wurfdeck (Plattform, Treppe, Geländer, Laternen-Säulen, Banner), Blasenring, Wegelaterne, Blumenfass – eine FBX |
| `voxel_spawndeko.py` | Blasenstab (Wahrzeichen), Bestenliste (Tafelhaus mit Dach, Medaillen, Laternen, Truhe), Krone – eine FBX |
| `voxeldrache.py` | Voxel-Drache komplett: SDF-Formen → Würfel-Meshes (innere Flächen weg), Färbung pro Würfel, Klingen, Umgebung, Animation, Testrenders. Headless: `blender -b --factory-startup --python voxeldrache.py -- build <Bildordner>` |

Die Skripte sind auf die Lavadrache-Namen zugeschnitten (z. B. `Schwanz_J*`, `Drachenkoerper`) –
für neue Modelle als Vorlage kopieren und anpassen.
