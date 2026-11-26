# Roblox-Fallen

Zurück: [[Roblox-Wissen]]

Was bei uns schon Zeit gekostet hat. Neue Fallen hier ergänzen (mit Datum).

## Import aus Blender (Himmelsinseln, 24.11.2026)

- Importe kommen **1 m = 1 Stud** (viel zu klein) und als **Package** → skalieren, verankern, drehen; Änderungen gelten nur für diese Kopie.
- Prozedurale Blender-Materialien kommen **grau** an → in Blender per Cycles backen (Selected→Active) und als `SurfaceAppearance` (ColorMap + EmissiveMask) setzen.
- Max. **20k Dreiecke pro Mesh** → vor dem Export dezimieren/aufteilen.
- Animation mit Skelett: EIN Armature + skinned Meshes als GLB. Bones landen unter `RootPart`; Animation per `Bone.Transform` im Client (wird nicht repliziert → Server setzt nur Zustands-Attribute).

## Welt & Streaming

- Große Modelle weit weg vom Spawn fehlen im Client (StreamingEnabled) → `ModelStreamingMode = Persistent`, sonst Skriptfehler „index nil“.
- Wolken aus Kugeln sehen aus wie Seifenblasen → Block-Wolken.
- Atmosphere zu dicht → alles bläulich (gut: Density 0.18, Haze 0.6).
- Warnfelder in `Neon` wirken wie massive Blöcke → `SmoothPlastic` mit Transparenz 0.6.
- Wichtige Bauteile `Locked = true`, damit man sie im Studio nicht aus Versehen verschiebt.

## Testen

- Spawn-ForceField blockt die ersten ~10 s jeden Schaden → kein Bug.
- DataStore im Studio nur mit „Studio Access to API Services“.
- Große Bau-Skripte per MCP ohne `task.wait()` laufen in einen Timeout.

## Allgemein bekannte Fallen

- Client-Werte ungeprüft übernehmen → Cheater geben sich Geld (siehe [[Architektur]]).
- `wait()` / `spawn()` sind veraltet → `task.wait()` / `task.spawn()`.
- Verbindungen (`:Connect`) bei entfernten Objekten/Spielern nicht getrennt → Speicher läuft voll.
