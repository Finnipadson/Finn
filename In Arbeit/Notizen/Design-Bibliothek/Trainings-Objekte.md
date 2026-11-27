# Trainings-Objekte

Zurück: [[Design-Bibliothek]] · Genre: [[Fang-und-Gehege]] · Code-Muster: [[System-Rezepte]]

Die Stationen, an denen man **stärker wird** (Bankdrücken, Klimmzugstange, Laufband). Ausgewertet aus 4 Roblox-Spielen: **Ziehe einen Dino** (Bankdrücken), **Fische für geheime Tiere** (Klimmzug), **Throw Food For Animals** (Klimmzug) und **+1 Speed Keyboard Escape** (Laufbänder). Zahlen sind aus den Videos abgelesen.

## Grundaufbau einer Station (bei allen gleich)

1. **Kreis am Boden** (weiß, gestrichelt oder als Ring aus Kacheln) markiert, wo man sich hinstellt. Ein gelber Pfeil zeigt beim ersten Mal drauf, Text „Auf den Kreis treten“.
2. **Das Gerät** steht in der Mitte des Kreises: Hantelbank, Klimmzugstange, Laufband. Einfache Block-Formen, gut lesbar.
3. **Schwebendes Preisschild** über dem Kreis, solange man die Station noch nicht hat: Preis groß in Rot/Grün („$50“, „$600K“), darunter klein der Ertrag („+2 XP / Reputation“, „+128 XP / rep“).
4. **Betreten = Training startet automatisch:** Die Figur macht die Übung in Schleife (Animation), jede Wiederholung gibt eine **fliegende Zahl** („+1 EP“, „+8 XP“, „+16 XP“).
5. **HUD während des Trainings** (unten mittig): Fortschrittsbalken „Stufe 6 – 15/16“, darüber ein roter Knopf **„HALT“ / „STOP“ / „HALTEN“** zum Aufhören und ein gelber **„AUTO 99 R$“** (automatisch weitertrainieren gegen Robux). Oben ein Satz, was gerade passiert („Bankdrücken! Hebe, um weiter zu werfen“, „Drücke STOP, wenn du fertig bist!“).
6. **Stufenaufstieg:** großer Text mitten im Bild „STÄRKER! LEVELAUFSTIEG!“ / „LEVEL UP!“ / „STUFE ERHÖHT!“ und darunter der **konkrete Gewinn** („Wurfkraft +28“). Konfetti.

## Die Stationen im Vergleich

### Ziehe einen Dino – Bankdrücken mit Dinos als Gewichten

![[dino-bank-holz-x2.jpg]]
![[dino-bank-kristall.jpg]]
![[dino-bank-lava.jpg]]

- **Stufen am Material erkennbar:** Holzbank auf brauner Plattform (Gewicht „Compy“, grüne Dinos, **+1 EP**) → Kristall-Bank auf hellblauer Eis-Plattform („Crystal Rex“, lila Dinos, **+8 EP**) → Lava-Bank auf schwarzer Lavagestein-Plattform („Fire Rex“, orange Dinos, **+12 EP**). Plattform, Stange und Gewichte wechseln zusammen die Farbe.
- **Das Gewicht ist ein Dino** aus dem eigenen Spiel: Oben steht „Heben: Compy / Crystal Rex / Fire Rex“. Gesammeltes wird zum Trainingsgerät.

![[dino-bank-x2-training.jpg]]
![[dino-bank-levelaufstieg.jpg]]

- **x2-Blase:** Alle paar Sekunden erscheint an einer zufälligen Stelle ein großer **oranger Kreis mit Muskel-Symbol und „X2“**. Anklicken → „🔥 X2 TRAINING! 🔥“ mit kleinem Ablauf-Balken. Hält die Hände/Maus beschäftigt, obwohl das Training von selbst läuft.
- **„Leichtes Gewicht!“** erscheint schräg neben der Hantel, wenn die Station zu leicht für die eigene Stufe ist → Hinweis, die nächste Bank zu kaufen.
- XP pro Stufe (abgelesen): Stufe 5 → 14, 6 → 16, 13 → 34, 19 → 50, 28 → 78, 30 → 85 – also ungefähr **2,8 × Stufe**.

### Fische für geheime Tiere – Klimmzugstange

![[geheimtiere-stange-grau.jpg]]
![[geheimtiere-stange-lila-levelup.jpg]]

- Graue Stein-Stange (Level 4, **+8 XP**) → lila Stange (Level 24, **+64 XP**, mit Bonus „+128 XP / rep“). Nächste Stufe schwebt als Preis über der Station („$67K“).
- Neben der Station eine kleine **Upgrade-Matte** (gelb/blau) mit Tastenhinweis.
- „LEVEL UP! Wurfkraft +36“ (Level 24) → „+57“ (Level 31): **der Gewinn pro Stufe wächst mit**.
- XP pro Stufe: Level 4 → 45, 24 → 190, 31 → 310 – wächst schneller als linear (grob 0,37·L² − 3·L + 51).

### Throw Food For Animals – Klimmzugstange

![[futter-station-kaufen.jpg]]
![[futter-station-aufstufen.jpg]]
![[futter-stange-lila-x2.jpg]]

- Erste Station: zwei Holzpfosten, Kreis am Boden, Pfeil, „$50 – +2 XP / Reputation“. Daneben ein Schild mit Gehege-Plätzen („10 > 12 – $40M“).
- **Aufstufen an Ort und Stelle:** Hineinlaufen mit genug Geld → Meldung „Zum Violetten Bar aufgestuft!“; sonst rot „Nicht genug Geld!“ und Preis „$600K“. Die Station wird ersetzt, nicht neu aufgestellt.
- Lila Stange: **+16 XP** (mit x2: „+32 XP / Reputation“ groß unten). x2 hier als lila **Hand-Symbol „x2“** zum Antippen.
- XP pro Stufe: Stufe 11 → 6, 59 → 82, 65 → 134.

### +1 Speed Keyboard Escape – Laufbänder

![[keyboard-laufbaender.jpg]]

- Mehrere Laufbänder nebeneinander, jedes mit eigener Farbe und **Multiplikator-Schild** („x1“, „x3 Geschwindigkeit“). Statt einer Station, die man aufstuft, stehen **alle Stufen nebeneinander** – man sieht sofort, worauf man spart. Mehr in [[Objekte-Mechaniken]].

## Was man daraus lernt

- **Ein Gerät, viele Stufen:** Form bleibt gleich, nur **Material/Farbe** wechselt (Holz → Stein → Lila → Kristall → Lava/Obsidian). Spart Modellier-Arbeit, Fortschritt ist trotzdem sichtbar.
- **Ertrag pro Wiederholung springt pro Stufe stark** (Dino: 1 → 8 → 12; geheime Tiere: 8 → 64; Futter: 2 → 16), Preise noch stärker ($50 → $600K). Das neue Gerät fühlt sich sofort spürbar besser an.
- **Das Training läuft von selbst**, der Spieler wird aber beschäftigt gehalten: x2-Blasen anklicken, Zahlen fliegen, Balken füllt sich. AUTO gegen Robux für die, die nicht klicken wollen.
- **Stufenaufstieg nennt immer den konkreten Nutzen** („Wurfkraft +28“) – Training ist nur Mittel zum Zweck (weiter werfen).
- **„Leichtes Gewicht!“-Hinweis** schubst zum nächsten Kauf, ohne Menü.
- **Stationen stehen auf dem eigenen Grundstück / direkt am Gehege**, also dort, wo man sowieso ständig ist.

## Bauplan für Roblox (eigenes Spiel)

**Station (Modell):** `Kreis` (flacher Zylinder, Neon/halbtransparent, mit Attributen `Stufe`, `XPProWdh`, `Preis`, `NaechsteStufe`), `Geraet` (Modell je Stufe in `ServerStorage/Stationen/1..n`, gleiche Form, anderes Material), `Preisschild` (BillboardGui).

**Ablauf Server:**
1. Spieler betritt Kreis (Abstand prüfen, z. B. alle 0,2 s mit `GetPartBoundsInBox`) → Attribut `TrainiertAn = Station` setzen, Figur verankern/positionieren.
2. Schleife pro Spieler: alle **~0,8 s eine Wiederholung** → `XP += XPProWdh * Bonus` (x2 aktiv? Gamepass? Freunde-Boost?), bei `XP >= Bedarf(Stufe)` → Stufe +1, Stat (z. B. `Wurfkraft`) erhöhen, Event an Client.
3. HALT-Knopf (RemoteEvent) oder Kreis verlassen → Training beenden.
4. Kauf/Aufstufen: beim Betreten mit genug Geld → Geld abziehen, Gerät gegen nächste Stufe tauschen, Meldung „Zum … aufgestuft!“; sonst „Nicht genug Geld!“.

**Ablauf Client:** Übungs-Animation, fliegende Zahl pro Wiederholung, Balken + HALT/AUTO-Knöpfe einblenden, Stufenaufstieg-Text mit Konfetti, x2-Blase alle ~20–40 s an zufälliger Bildschirmstelle (Klick → RemoteEvent → Server gibt x2 für ~10 s).

**Startwerte (Vorschlag, im Spieltest anpassen):**

| Stufe Gerät | Material | Preis | XP pro Wdh |
|---|---|---|---|
| 1 | Holz | 50 | 2 |
| 2 | Stein | 2.500 | 8 |
| 3 | Lila | 60.000 | 20 |
| 4 | Kristall | 1,5 Mio. | 50 |
| 5 | Lava/Obsidian | 40 Mio. | 120 |

XP-Bedarf pro Spielerstufe: anfangs etwa `3 × Stufe`, später quadratisch steigen lassen (z. B. `0,3 × Stufe² + 5`), damit die nächste Geräte-Stufe sich lohnt.
