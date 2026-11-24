# Himmelsinseln – Roblox-Spiel (Notizen für Claude)

Roblox-RPG: Hub-Insel mit Portal in der Mitte, vier Elementinseln mit je einem Boss. Spieler leveln, sammeln/brüten Kreaturen aus Eiern (Begleiter, die mitkämpfen), Bosse im Koop.

## Arbeitsweise
- Gebaut direkt in Roblox Studio über den **Roblox-Studio-MCP** (`claude mcp add ... Roblox_Studio`, eingebauter Studio-MCP, unten rechts „MCP on“).
- Erst `list_roblox_studios` aufrufen – die `studio_id` ändert sich bei jedem Studio-Neustart.
- Bauen per `execute_luau` (Edit-DataModel), Kontrolle per `screen_capture` mit Kameraposition.
- Place-Datei: `himmelsinseln.rbxl` in diesem Ordner (vom User per Datei → Speichern unter angelegt).

## Welt-Layout (Studs)
- Hub: Mitte (0, 100, 0), Oberfläche Y = 100, Radius ~76, Voxel-Säulen 8×8 (Gras-Kappe + Fels darunter).
- Plaza Radius 34, Portal in der Mitte (Neon-Ring, ForceField-Kern, Lichtstrahl 600 hoch, Partikel), 4 Obelisken, 12 Laternen.
- Vier Wege + Holzbrücken auf den Diagonalen, Tor mit Neon-Schild am Inselrand (r = 72), Brücke r = 74…146:
  - Lava 225° (rot) – Boss Lavadrache
  - Eis 315° (hellblau) – Boss Steinwolf
  - Dschungel 135° (grün) – Boss Schlange (noch kein Modell)
  - Kristall 45° (lila) – Boss Skorpion
- Geplante Biom-Inseln: Mitte bei r ≈ 230, Radius ≈ 90.
- Wolkenmeer: Block-Wolken bei Y −25…+13 (Kugeln sahen wie Seifenblasen aus → nicht verwenden).
- Spawn: (0, 101, 26), unsichtbar. `FallenPartsDestroyHeight = -60`.
- Ordner im Explorer: `Workspace/Map/Hub/{Ground, Plaza, Wege, Deko}`, `Workspace/Map/Wolkenmeer`.

## Boss-Modelle
Steinwolf, Lavadrache, Skorpion existieren schon in Blender (`In Arbeit/Blender/`). Import nach Roblox: Skill `rbx-import-asset` (FBX über Open Cloud).

## Stand
- [x] Phase 1a: Hub-Insel mit Portal, Wegen, Brücken, Toren, Bäumen, Wasserfällen, Licht, Wolken (24.11.2026)
- [ ] Phase 1b: Lavainsel + Lavadrache als erster Boss
- [ ] Level-System (XP, Level-Anzeige), erste Gegner zum Farmen
- [ ] Eier/Begleiter
- [ ] Restliche drei Inseln + Bosse
