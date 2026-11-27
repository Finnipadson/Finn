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

### Steal An Egg – Ei schlüpft (Roblox)

![[stealanegg-schluepfen.jpg]]

- **Ablauf (Video, ~6 s):** Ei abstellen → Schild „Ei – Bereit!“ → Schale platzt in Blockstücke auseinander, die wegfliegen → weißer Lichtkegel und Funkeln → Haustier springt heraus und läuft direkt hinter dem Spieler her.
- **Prinzip zum Übernehmen:** Belohnung in 3 Takten: Vorfreude (Bereit-Schild), Explosion (Stücke + Licht), Ergebnis (Figur bleibt sichtbar beim Spieler). Bei seltenen Tieren sollte die Explosion größer und farbiger werden.

### Fisch – Angel-Minispiel in 3 Schritten (Roblox) → für Angeln in [[Clean the Skyscraper]]

![[fisch-auswerfen.jpg]]
![[fisch-grossartig.jpg]]
![[fisch-einholen.jpg]]
![[fisch-fang.jpg]]

1. **Auswerfen:** Maustaste halten („HOLD“), ein senkrechter Balken füllt sich, loslassen („RELEASE“) im richtigen Moment. Bewertung als Wort über dem Spieler („Großartig!“).
2. **Anbiss / Schütteln:** kurzer Reaktionsmoment, Zahl zählt hoch.
3. **Einholen:** unten ein **waagerechter Balken mit weißer Zone**; der Fisch zieht die Zone hin und her, man hält sie mit Klicken über dem Fisch-Marker. Darunter ein kleiner Fortschrittsbalken, wie weit der Fisch schon eingeholt ist.
- **Fang:** Text direkt über dem Spieler mit Spannung („Es ist!.. Oh.. Seetang“), dazu Meldung „Bestiarium: Neuer Fang! Neues Höchstgewicht“ mit Gewicht.
- **Prinzip zum Übernehmen:** Kurzes Geschicklichkeits-Minispiel mit 3 klaren Phasen, jede mit eigener Rückmeldung. Die Pause „Es ist!.. Oh..“ vor dem Ergebnis baut Spannung auf wie beim Ei-Schlüpfen.

### Fisch – Fänge der anderen sehen (Roblox)

![[fisch-andere-spieler.jpg]]

- **Was ist gut:** Am Steg angeln viele Spieler nebeneinander. Was jemand fängt, erscheint als **Sprechblase über seinem Kopf** („Wow, ein Sockeye-Lachs!“, „Wow! Eine Kiste“). Man sieht ständig, was es zu fangen gibt, und vergleicht sich.
- **Prinzip zum Übernehmen:** Erfolge der anderen in der Welt sichtbar machen (nicht nur im Chat) = Ansporn + lebendige Atmosphäre.

## Bei uns umgesetzt

-
