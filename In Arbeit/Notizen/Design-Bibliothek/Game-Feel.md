# Game-Feel

Zurück: [[Design-Bibliothek]]

## Bewährte Muster

- **Hit-Stop:** bei einem Treffer 40–80 ms einfrieren (Boss oder Kill: 100–150 ms). Das gibt Wucht, ohne dass es ruckelt.
- **Screenshake:** kurz (100–250 ms), Stärke nach Ereignis staffeln (Schuss klein, Explosion groß), schnell abklingen. In den Einstellungen abschaltbar machen.
- **Treffer-Flash:** Gegner 1–2 Frames weiß einfärben, dazu etwas Rückstoß.
- **Partikel:** wenige, aber schnelle Partikel; Funken in Trefferrichtung, nicht gleichmäßig nach allen Seiten.
- **Sound:** kommt genau mit dem Treffer, nicht verzögert. Tonhöhe pro Treffer ±5–10 % variieren, sonst klingt es nach Maschinengewehr-Loop. Combos mit steigender Tonhöhe.
- **Squash & Stretch:** bei Sprung/Landung/Aufsammeln das Objekt 10–20 % stauchen oder strecken.
- **Coyote Time / Input-Puffer:** Sprung zählt noch ~100 ms nach der Kante; Eingaben 100–150 ms vorpuffern.
- **Zahlen fliegen:** Schadenszahlen springen hoch, werden kleiner und blenden aus; kritische Treffer größer und andersfarbig.

## Fallen

- Zu viel Shake auf einmal (mehrere Ereignisse addieren sich) → Stärke deckeln.
- Hit-Stop bei jedem kleinen Treffer in schnellen Spielen → wirkt wie Lag.

## Referenzen

<!-- Bilder hier einbetten: ![[datei.jpg]] + was daran gut ist -->

## Bei uns umgesetzt

-
