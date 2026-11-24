# Himmelsinseln – Roblox-Spiel (Notizen für Claude)

Roblox-RPG: Hub-Insel mit Portal in der Mitte, vier Elementinseln mit je einem Boss. Spieler leveln, sammeln/brüten Kreaturen aus Eiern (Begleiter, die mitkämpfen), Bosse im Koop.

## Arbeitsweise
- Gebaut direkt in Roblox Studio über den **Roblox-Studio-MCP** (`claude mcp add ... Roblox_Studio`, eingebauter Studio-MCP, unten rechts „MCP on“).
- Erst `list_roblox_studios` aufrufen – die `studio_id` ändert sich bei jedem Studio-Neustart.
- Bauen per `execute_luau` (Edit-DataModel), Kontrolle per `screen_capture` mit Kameraposition. Große Bauten zeilenweise mit `task.wait()`, sonst Timeout.
- Boden-Säulen (`Ground`) und Wolken sind `Locked = true`, damit der User sie nicht versehentlich zieht. Zum Bearbeiten per Skript entsperren.
- Place-Datei: `himmelsinseln.rbxl` in diesem Ordner (vom User per Datei → Speichern unter angelegt).

## Welt-Layout (Studs, User-Vorgabe: Hub 300 breit, Biom-Inseln 1200 breit)
- Hub: Mitte (0, 100, 0), Oberfläche Y = 100, Radius 150, Voxel-Säulen 8×8 (Gras-Kappe + Fels).
- Plaza Radius 52, Portal in der Mitte (Ring r 12, ForceField-Kern, Lichtstrahl 800 hoch, Partikel), 4 Obelisken r 25, 16 Laternen r 48, Spawn (0, 101, 40).
- 4 Teiche mit Wasserfällen auf 0/90/180/270°, 130 Bäume.
- Wege + Tore (r 140) + Holzbrücken (r 146 → 304, 2 Steinpfeiler) auf den Diagonalen:
  - Lava 225° (rot) – Boss Lavadrache – **gebaut**, Brücke bis r 352 verlängert (Inselrand im Korridor bei ~346)
  - Eis 315° (hellblau) – Boss Steinwolf
  - Dschungel 135° (grün) – Boss Schlange (noch kein Modell)
  - Kristall 45° (lila) – Boss Skorpion
- Biom-Inseln: Mitte 900 Studs vom Ursprung auf der Diagonalen, Radius ~600 (Rand mit Rauschen ±50 → Brücke jeweils bis zum echten Rand verlängern!).
- Wolkenmeer: Block-Wolken bei Y −180…−50 bis Radius 2000 (Kugeln sahen wie Seifenblasen aus → nicht verwenden).
- `FallenPartsDestroyHeight = -250`. Atmosphere Density 0.18 / Haze 0.6 (mehr → alles bläulich).

## Lavainsel (`Workspace/Map/Lava`, Attribut `Center` = (-636.4, 0, -636.4))
- Voxel-Säulen 16×16, ~4000 Säulen. Kappen tragen Attribut `Zone`.
- Zone 1 (d > 400): Ebene Y 100, Lavaflüsse (Neon, Name `LavaPool`), tote Bäume, Felsen, Glutkristalle. Marker `Deko/GegnerZone_1`.
- Zone 2 (250 < d < 400): Plateau Y 140, Klippe mit Treppe (20 Stufen, d 462→400). Marker `GegnerZone_2`.
- Vulkan (d < 250): gestufter Kegel, Rand Y ~286, Krater-Arena Y 270 (Radius 94, Glutring, 8 Feuersäulen, Rauch). `Arena/BossSpawn` in der Mitte.
- Weg: Korridor Richtung Hub; Schlucht durch den Vulkan mit 65 Stufen (d 332→116) und Fackeln.
- Boss-Tor bei d 338 (`Weg/BossTor`, ForceField, Attribut `BenoetigtLevel` = 15, Schild „LAVADRACHE“) – noch ohne Funktion.
- Lavaströme den Vulkan hinunter, 4–5 Lavafälle über den Inselrand.

## Boss-Modelle
Steinwolf, Lavadrache, Skorpion existieren schon in Blender (`In Arbeit/Blender/`). Import nach Roblox: Skill `rbx-import-asset` (FBX über Open Cloud).

## Stand
- [x] Hub-Insel 300 Studs mit Portal, Wegen, Brücken, Toren, Bäumen, Wasserfällen, Licht, Wolken (24.11.2026)
- [x] Lavainsel 1200 Studs: Ebene, Plateau, Vulkan mit Treppe, Boss-Tor, Arena (24.11.2026)
- [ ] Lava macht Schaden, Boss-Tor prüft Level
- [ ] Level-System (XP, Level-Anzeige), erste Gegner zum Farmen in GegnerZone_1/2
- [ ] Lavadrache importieren + Bosskampf
- [ ] Eier/Begleiter
- [ ] Restliche drei Inseln + Bosse
