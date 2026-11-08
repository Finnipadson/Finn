# Nachtschicht – Bauplan

3D-Grusel-Shooter im Browser, eigenständiges Spiel (`In Arbeit/nachtschicht.html`).

## Entscheidungen (aus der Fragerunde)

| Thema | Entscheidung |
|---|---|
| Stil | Echtes Low-Poly-3D mit Three.js (r128 von cdnjs, braucht Internet beim Laden), Pixel-Texturen aus Canvas |
| Geräte | Nur PC: Maus (Pointer Lock) + WASD, Shift sprinten |
| Grusel | Mit Schreckmomenten (Licht fällt aus, Gegner tauchen auf, laute Akzente) |
| Kampf | Normale Shooter-Action, genug Munition |
| Gegner | Schattenwesen (dunkel, leuchtende Augen), Puppen/Statuen (bewegen sich nur, wenn man nicht hinsieht), Kriecher (klein, schnell) |
| Orte | Wechselt pro Level |
| Level | 6 handgebaute Level, feste Reihenfolge, je 2–5 Minuten: Schlüssel finden, Ausgang erreichen |
| Waffen | 4 klassische, nacheinander gefunden: Pistole, Schrotflinte, Gewehr, etwas Starkes fürs Finale |
| Geschichte | Kurz und geheimnisvoll über Notizen und Funksprüche |
| Einordnung | Eigenes Spiel |

## Geschichte (Gerüst)

Du übernimmst die Nachtschicht als Wachmann im Anwesen Falkenried. Der Kollege der Tagschicht meldet sich nicht mehr. Notizen und Funksprüche erzählen von einer Puppensammlung, Stromausfällen und „Schatten, die dem Strom folgen“.

## Level (geplant)

1. Herrenhaus (Phase 1)
2. Keller und Katakomben
3. Nebliger Wald mit Hütte
4. Bunker mit Notbeleuchtung
5. Puppenwerkstatt
6. Finale

## Technik

- Level als ASCII-Raster (Zelle 2 m, Wandhöhe 3 m): `#` Wand, `.` Boden, `S` Start, `E` Ausgang, `D` Tür, `R` rote Tür (Schlüssel), `k` roter Schlüssel, `a` Munition, `h` Medizin, `g` Waffe, `n` Notiz, `l` Lampe, `x` Schreckmoment, `s`/`p`/`c` Gegner.
- Wände als InstancedMesh, Kollision über das Raster, Sichtlinie per Raster-DDA, Gegner-Wegfindung per BFS-Distanzfeld.
- Taschenlampe = SpotLight an der Kamera, Lampen = PointLights mit Flackern, dichter Nebel.
- Alle Sounds per Web Audio synthetisiert.
- Speichern in `localStorage` unter `nachtschicht_v1`.

## Phasen

1. ✅ **Spielbarer Kern** (fertig, getestet: Schatten 3 Schüsse, Puppe friert ein wenn angesehen / 5 Schüsse, Kriecher 2 Schüsse, Schreckmoment spawnt 2 Schatten hinter dem Spieler, rote Tür nur mit Schlüssel, Ausgang + Abschlussbildschirm). Debug-Schnittstelle `window.NS` für automatisierte Tests (Maus-Fangen geht im Testbrowser nicht). – Bewegung, Taschenlampe, Pistole + Schrotflinte, 3 Gegnertypen, Schreckmoment-Auslöser, HUD, Sounds, Level 1 komplett.
2. **Alle 6 Level** – Gewehr + Finalwaffe, Geschichte, inszenierte Schreckmomente pro Level.
3. **Feinschliff** – Menü mit Einstellungen (Maus, Lautstärke, Helligkeit), Speichern, Balance.
