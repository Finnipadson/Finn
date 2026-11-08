# Burgwacht – Bauplan

Turmverteidigung als eigener Modus von **Kopfsache**. Spielerisch komplett eigenständig (keine Rätsel, keine Sterne aus der Weltenkarte), eigener Look.

Pixel-Art-Entwürfe für Karte, Gegner und Türme: [burgwacht-prototypen.html](burgwacht-prototypen.html)

## Entscheidungen

| Thema | Entscheidung |
|---|---|
| Name | Burgwacht |
| Einbindung | Eigene Datei `In Arbeit/burgwacht.html`, Knopf im Kopfsache-Hauptmenü verlinkt dorthin |
| Look | Pixel-Art von oben im Stil gemütlicher Farm-/Abenteuerspiele: sattes Grün, gezeichnete Laubbäume und Tannen, warme Erdwege, Wasser mit Sandufer. Alles prozedural im Code gezeichnet, keine Bilddateien, keine kopierten Assets |
| Rundenlänge | 1–5 Minuten pro Karte |
| Spielgefühl | Mischung aus Planen und Tempo |
| Modi | Kampagne (Level mit 1–3 Sternen) **und** Endlosmodus (Highscore = erreichte Welle) |
| Karten | 6–10 handgebaute Karten mit **mehreren Wegen** / Startpunkten |
| Schwierigkeit | Wählbar pro Karte: Leicht / Normal / Schwer (Schwer = besonderer Sternrahmen) |
| Wellen | Zwischen Wellen Pause bis Knopfdruck („Nächste Welle“) |
| Während Welle | **Bauen unter Druck**: Welle läuft beim Bauen weiter. Pause möglich, dann ist Bauen gesperrt |
| Bauen | Turm per **Drag & Drop aus der Leiste** aufs Feld ziehen (Maus + Touch) |
| Turm antippen | Menü am Turm: Ausbauen (Kosten), Verkaufen (70 %), Zielwahl (Erster/Stärkster/Nächster) |
| Ausbau | 3 Stufen, Turm wird kurz eingerüstet und schießt dann nicht. Optik: Holz → Steinsockel + Dach → Stein mit Gold, Banner, Effekten |
| Fähigkeiten | Aktive Fähigkeiten mit Abklingzeit, über die Kampagne **freischaltbar** |
| Sterne | Nach Burg-Leben: 3 = kein Gegner durch, 2 = über halbe Leben, 1 = geschafft |
| Klang | Mittelalterlich-gemütlich: Laute-/Flötenmelodie, Trommeln bei Bossen, holzige Effekte (Web Audio, synthetisiert) |
| Tasten (PC) | 1–8 Turm wählen, Leertaste nächste Welle, P/Esc Pause, Q/W/E Fähigkeiten, F Tempo 2× |
| Speichern | `localStorage` Key `burgwacht_v1` |

## Türme (8, je 3 Stufen)

| Turm | Rolle | Stufe 2 | Stufe 3 |
|---|---|---|---|
| Bogenschütze | günstig, schnell, trifft Flieger | mehr Reichweite | 3 Schützen, 3 Ziele gleichzeitig |
| Kanone | Flächenschaden, trifft keine Flieger | größerer Radius | Doppelkanone, Rückstoß |
| Frostmagier | verlangsamt | stärker verlangsamen | friert manchmal komplett ein |
| Armbrust | große Reichweite, hoher Einzelschaden | mehr Schaden | durchschlägt Schild und Rüstung |
| Giftküche | Schaden über Zeit, stoppt Heilung | Gift länger | Giftwolke bleibt auf dem Weg |
| Ballista | nur Luft, sehr stark | schneller nachladen | Dreifachbolzen |
| Glockenturm | verstärkt Nachbartürme, deckt Schatten auf | größerer Bereich | ganzer Bereich sichtbar + Tempo-Bonus |
| Goldmine | Gold pro Welle | mehr Gold | Bonusgold für Abschüsse in der Nähe |

## Gegner

| Gegner | Besonderheit | Konter | Ab |
|---|---|---|---|
| Kobold | schnell, schwach, Gruppen | Bogenschütze | Karte 1 |
| Oger | langsam, gepanzert | Armbrust, Gift | Karte 1 |
| Fledermaus | fliegt direkt zur Burg | Ballista, Bogenschütze | Karte 1 |
| Schamane | heilt Gegner in der Nähe | Armbrust (Ziel: Stärkster), Gift | Karte 2 |
| Schildträger | blockt Schüsse von vorn | Seite/hinten, Kanone im Bogen | Karte 2 |
| Schleim | zerfällt in 2 kleine | Kanone, Frost | Karte 2 |
| Schatten | getarnt, nur nahe Glocken sichtbar | Glockenturm | Karte 3 |

**Bosse:** Trollhäuptling (betäubt nahe Türme, Karte 3), Hexe (verwandelt Turm kurz in Kürbis), Nekromant (erweckt Besiegte als Skelette), Steingolem (zerfällt bei halbem Leben in 3 kleine Golems).

## Karten (erste drei)

1. **Mühlbach** – Start A links (über Brücke), Start B oben, vereinen sich vor der Burg rechts unten. Flieger diagonal von links oben.
2. **Dreiweg** – Starts links, oben, rechts treffen sich am Dorfplatz, dann gemeinsam zur Burg unten. Anhöhe = Reichweitenbonus, Häuser/See nicht bebaubar.
3. **Moorpfade** – Start A gabelt sich in oberen/unteren Pfad, Start B stößt unten dazu, Wiedervereinigung vor der Burg rechts. Moortümpel nicht bebaubar. Troll-Boss.

Weitere Kartenideen (Phase 3): Brücke einreißen, Nebel, Fluss mit Fähre, Burg in der Mitte mit 4 Startpunkten.

## Phasen

Stand: Phase 1 fertig (`burgwacht.html`). Balance per simuliertem Spieler geprüft: Leicht und Normal auf allen 3 Karten gewonnen, Schwer auf Karte 1 und 2 knapp gewonnen, Schwer auf Karte 3 vom einfachen Testspieler nicht geschafft (bewusst knackig).

1. ✅ **Spielbarer Kern** – Karten 1–3, Raster/Wege/Hindernisse, Wellen-System, Gold, Burg-Leben, Drag-&-Drop-Bauen, Turm-Menü, 8 Türme × 3 Stufen, alle 7 Gegner, Troll-Boss, Sterne, Schwierigkeit wählbar, Pause, Tempo 2×, Tasten. Canvas mit Fixed Timestep.
2. ✅ **Fähigkeiten & Fortschritt** – umgesetzt: Freischaltung über Sterne (Feuerregen 1★, Eiszeit 3★, Steuer 6★, Mauer 10★, Burg heilen 15★; Sterne zählen pro Karte und Schwierigkeit, max. 27), bis zu 3 auf Q/W/E ausrüstbar auf der Kampagnenkarte; neu freigeschaltete werden einmalig automatisch eingesetzt. „Früher rufen“ geht, sobald alle Gegner einer Welle erschienen sind (Wellenbonus sofort + Extragold). Ursprünglicher Plan: – Feuerregen, Eiszeit, Steuer, Mauer, Burg heilen (freischaltbar), Kampagnen-Karte, Bonusgold.
3. ✅ **Kampagne & Endlos** – Karten 4–8 (Fährfurt: Furt bremst; Nebelhain: Nebel −30 % Reichweite, Glocken lichten ihn; Hexenweiher: Matsch, 3 Wege; Steinbrücke: Schlucht mit 3 Brücken; Königsburg: Winter, 4 Wege zum Burgplatz, alle Bosse), Hexe (Kürbis-Fluch), Nekromant (Skelette aus Gräbern), Steingolem (zerfällt in 3 Splitter), Endlosmodus pro Karte und Schwierigkeit mit Rekord, Boss alle 10 Wellen.
4. ✅ **Feinschliff** – Statistik, Fortschritt zurücksetzen, Kartenhinweise, Schatten-Regel entschärft (sichtbar auch direkt an Türmen und 3 s nach Treffer), Balance per simuliertem Spieler (inkl. Fähigkeiten).

### Balance-Stand (simulierter Spieler mit Feuerregen/Eiszeit/Mauer)

| Karte | Leicht | Normal | Schwer |
|---|---|---|---|
| Mühlbach | 30/30 | 20/20 | 10/12 |
| Dreiweg | 30/30 | 20/20 | 10/12 |
| Moorpfade | 30/30 | 20/20 | 12/12 |
| Fährfurt | 30/30 | 20/20 | 9/12 |
| Nebelhain | 30/30 | 18/20 | 9/12 |
| Hexenweiher | 30/30 | 20/20 | 9/12 |
| Steinbrücke | 30/30 | 17/20 | 8/12 |
| Königsburg | 40/40 | 19/30 | 1/22 |

Endlos: gute Läufe enden bei etwa 24–30 Wellen.
