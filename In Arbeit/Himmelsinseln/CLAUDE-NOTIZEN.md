# Himmelsinseln – Roblox-Spiel (Notizen für Claude)

Roblox-RPG: Hub-Insel mit Portal in der Mitte, vier Elementinseln mit je einem Boss. Spieler leveln, sammeln/brüten Kreaturen aus Eiern (Begleiter, die mitkämpfen), Bosse im Koop.

## Arbeitsweise
- **Vorher lesen:** `Notizen/Roblox-Wissen/Roblox-Wissen.md` (Architektur, Speichern, System-Rezepte, Fallen) und für das Aussehen `Notizen/Design-Bibliothek/Design-Bibliothek.md`.
- Gebaut direkt in Roblox Studio über den **Roblox-Studio-MCP** (`claude mcp add ... Roblox_Studio`, eingebauter Studio-MCP, unten rechts „MCP on“).
- Erst `list_roblox_studios` aufrufen – die `studio_id` ändert sich bei jedem Studio-Neustart.
- Bauen per `execute_luau` (Edit-DataModel), Kontrolle per `screen_capture` mit Kameraposition. Große Bauten zeilenweise mit `task.wait()`, sonst Timeout.
- Boden-Säulen (`Ground`) und Wolken sind `Locked = true`, damit der User sie nicht versehentlich zieht. Zum Bearbeiten per Skript entsperren.
- Place liegt in der **Roblox-Cloud** (Team Create): „biggfishh0's Ort: 11242026_1“, placeId 100233884488413, universeId 10778898895. Speichern per `save_place` (erzeugt eine Version).
- MCP-Permissions (vom User gesetzt): `asset:read`, `asset:write`, Upload-Ordner `Himmelsinseln/Export`.

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
Steinwolf, Lavadrache, Skorpion existieren in Blender (`In Arbeit/Blender/`). Import-Weg (Skill `rbx-import-asset`):
1. Headless exportieren (nie `open_mainfile` im Live-Blender): `blender.exe -b <datei>.blend --python Export/export_drache.py` – nimmt eine Pose (FRAME), backt Rig-Verformung ein, gruppiert nach Material, überspringt FX-Materialien, dezimiert auf ~60k (max. 19k pro Mesh, Roblox-Limit 20k), schreibt GLB nach `Export/`. Für andere Modelle Root-Namen + SKIP_MATS anpassen.
2. Upload `POST /assets/v1/assets` (Model, userId 9969523614), Operation pollen, dann `insert_asset`.
3. Importiert kommt alles **grau** (Blender-Materialien sind prozedural) und **1 m = 1 Stud** (zu klein) → in Studio Farbe/Material je MeshPart setzen, skalieren, verankern, drehen.
4. Ist ein Package: Änderungen gelten nur für diese Kopie.

### Lavadrache (Rig mit Skelett, Skin und Animation) – aktuell
- Export: `Export/export_drache_rig.py` (headless). Baut EIN Rig: 34 Skelett-Knochen + Flügel-Rigs (Präfix `WL_`/`WR_`) + `Kiefer`; Ruhelage = Pose Frame 100. Starre Teile (Krallen, Hörner, Stacheln, Zähne) hängen per Bewegungsvergleich über 4 Frames am passenden Knochen (Gewicht 1). 3 Meshes `Drache_Vorne/Hinten/Fluegel` (18,5k/18,5k/15k Dreiecke), Smart-UV, Cycles-Bake (Selected→Active, Kurven als temporäre Mesh-Kopien) → `drache_color_*.png` + `drache_emissive_*.png` (2048). Bake dauert ~40 min.
- Assets: Rig **112074245532582**; Farbe vorne/hinten/flügel 128319781998618 / 131479757513267 / 81129183016308; Glühen 97707548132093 / 140052499849874 / 136229445760186. Alte statische Version 116836643030172 wird nicht mehr benutzt.
- In Studio: `Map/Lava/Arena/Lavadrache` (Package), SurfaceAppearance mit ColorMapContent + EmissiveMaskContent (EmissiveTint orange), 40 Studs hoch, ~82 breit, Kopf Richtung Treppe, `ModelStreamingMode = Persistent` (sonst fehlen die Knochen im Client, wenn der Spieler am Hub spawnt). Knochen liegen unter `RootPart`.
- Körperfarbe wirkt im Spiel recht dunkel (Bake-Farbe), Glüh-Risse gut sichtbar.

## Bosskampf (Skripte in `Scripts/`, in Studio eingespielt)
- `BossServer.server.lua` → ServerScriptService. Zustand als Attribute am Boss: State, StateStart, HP, MaxHP, Phase. Kampf startet, sobald ein Spieler in der Arena ist (r < 96). HP 2500 + 1500 je weiterem Spieler. Dreht sich zum Ziel (Modell-Yaw um Arena-Mitte).
  - Angriffe mit rotem Warnfeld (SmoothPlastic, nicht Neon – Neon wirkte wie massiver Block): Feueratem (Kegel 80 Studs, 9 Schaden/0,25 s), Schwanzhieb (Kreis r 50, 30 + Rückstoß), Stampfen (Ring-Schockwelle, drüberspringen, 25), ab 50 % Phase 2 „wütend“: Meteorregen (9 Einschläge, 35), schneller.
  - Sieg: State Dead, 500 XP (leaderstats „XP“, noch ohne Level-System), Respawn nach 45 s.
- `Schwert.server.lua` → Tool `Schwert` in StarterPack (Klick, 25 Schaden, Reichweite 18 um Knochenpunkte inkl. Pfoten/Schwanz). Griff: GripForward (1,0,0), GripUp (0,0,-1), GripPos (0,0,0.4).
- `DracheAnim.client.lua` → StarterPlayerScripts: Bone.Transform je Zustand; Achsen aus Geometrie (vorne/oben/seitlich), Flügelachse so, dass + die Spitze hebt. Glühen pulsiert (EmissiveStrength), beim Tod kippen + ausblenden (LocalTransparencyModifier).
- `BossHUD.client.lua` → StarterGui/BossHUD: Lebensbalken, Meldungen, Rückstoß (Client setzt Velocity).
- Änderungen in Studio immer auch in die Dateien hier übernehmen (Quelle der Wahrheit = Dateien).
- Getestet (Playtest per MCP): Start, Feuer/Schwanz/Stampfen/Meteor, Schaden an Spieler (Spawn-ForceField blockt die ersten 10 s), Schwert-Treffer, Phase 2, Sieg + XP, Respawn.

## Stand
- [x] Hub-Insel 300 Studs mit Portal, Wegen, Brücken, Toren, Bäumen, Wasserfällen, Licht, Wolken (24.11.2026)
- [x] Lavainsel 1200 Studs: Ebene, Plateau, Vulkan mit Treppe, Boss-Tor, Arena (24.11.2026)
- [ ] Lava macht Schaden, Boss-Tor prüft Level (Tor ist bis dahin begehbar, CanCollide aus)
- [ ] Level-System (XP, Level-Anzeige), erste Gegner zum Farmen in GegnerZone_1/2
- [x] Lavadrache importiert und in der Arena platziert (statisch, 24.11.2026)
- [x] Lavadrache als Rig mit Glüh-Haut, 40 Studs, Animationen + kompletter Bosskampf (24.11.2026)
- [ ] Eier/Begleiter
- [ ] Restliche drei Inseln + Bosse
