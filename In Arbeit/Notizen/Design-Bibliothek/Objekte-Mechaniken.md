# Objekte-Mechaniken

Zurück: [[Design-Bibliothek]]

Gegenstände in der Welt, mit denen man etwas tut: Laufbänder, Gehege, Stände, Portale, Sammelobjekte. Was gerade in beliebten Roblox-Spielen funktioniert und wie man es baut.

## Bewährte Objekte

| Objekt | Wo gesehen | Was es tut | Worauf achten |
|---|---|---|---|
| **Fließband** | Steal a Brainrot | Bringt Waren oder Figuren vorbei, die man kaufen/schnappen muss | Richtung sichtbar (Streifen laufen mit), Geschwindigkeit gleichmäßig, seltene Dinge leuchten schon auf dem Band |
| **Laufband (Fitness)** | +1 Speed Keyboard Escape | Auf der Stelle rennen → Werte steigen; Bänder in Stufen mit Multiplikator | Stufe an Farbe/Größe erkennbar, Multiplikator-Schild darüber, fliegende Zahlen pro Schritt (siehe unten) |
| **Gehege / Grundstück** | Steal An Egg, Grow a Garden | Eigener Bereich für Tiere/Pflanzen, wächst mit Upgrades | Zaun + Eingang, Slots sichtbar (leer = Umriss), Besitzername darüber |
| **Ei / Kiste zum Öffnen** | Steal An Egg, Pet-Spiele | Belohnung mit Zufall | Schild „Bereit!“, Öffnen mit Licht + Teilen (siehe [[Game-Feel]]) |
| **Marktstand / Händler** | Grow a Garden | Kaufen/Verkaufen in der Welt | Markise in Funktionsfarbe, Schild, NPC, Prompt beim Näherkommen |
| **Portal / Tor zur Zone** | fast alle Simulatoren | Teleport ins nächste Gebiet | Name + Preis/Level als Schild, leuchtender Rand, Vorschau der Zone |
| **Upgrade-Knopf auf dem Boden** | Tycoons | Draufstellen = kaufen | Preis groß darüber, grün = leistbar, rot = zu teuer |
| **Sammelobjekte** | Speed-/Obby-Spiele | Münzen, Orbs auf dem Weg | Drehen + Glanz, Ton beim Aufsammeln, in Linien legen (führen den Weg) |
| **Geld-Generator** | Steal a Brainrot, Tycoons | Produziert pro Sekunde | Zahl schwebt hoch („+5 $“), Stapel wächst sichtbar |

## Allgemeine Regeln für Objekte

- **Funktion an der Form erkennbar:** Was man benutzen kann, sieht anders aus als Deko (leuchtet, bewegt sich, hat Schild oder Prompt).
- **ProximityPrompt / Taste-Hinweis** erscheint, wenn man nah genug ist – mit Verb („Öffnen“, „Verkaufen“).
- **Zustand sichtbar:** leer / bereit / läuft / fertig, z. B. durch Farbe, Schild oder Fortschrittsbalken über dem Objekt.
- **Objekte wachsen mit:** Upgrade = sichtbar größer, mehr Teile, andere Farbe. Man soll Fortschritt in der Welt sehen, nicht nur in einer Zahl.
- **Wenige, kräftige Farben** und dicke, einfache Formen (Handy-tauglich).

## Fallen

- Interaktive Objekte, die genauso aussehen wie Deko → keiner findet sie.
- Laufbänder ohne Bewegung in der Textur → wirken kaputt.

## Referenzen

### Steal An Egg – Gehege (Roblox)

![[stealanegg-gehege.jpg]]

- **Was ist gut:** Gehege der Spieler liegen **direkt nebeneinander**, nur durch einen niedrigen Holzzaun mit Lücke als Eingang getrennt. Man sieht über den Zaun die Tiere der Nachbarn → Ansporn und Ziel zum Klauen. Das Ei liegt mitten im eigenen Gehege mit Schild „Ei – Bereit!“. Im Hintergrund schon die nächsten Anlaufpunkte: Truhe mit „KOSTENLOS!“-Schild und ein Portal. Unten rechts ein Timer bis zur Nacht (Mond-Symbol).
- **Prinzip zum Übernehmen:** Grundstücke offen und einsehbar statt abgeschottet; Gratis-Belohnungen mit Schild in Sichtweite vom Spawn.

### +1 Speed Keyboard Escape – Laufbänder (Roblox)

![[keyboard-laufbaender.jpg]]
![[keyboard-laufband-nah.jpg]]

- **Was es ist:** Mehrere **Laufbänder (wie im Fitnessstudio) nebeneinander** in einer Reihe. Man stellt sich drauf und rennt auf der Stelle; jeder Schritt gibt Geschwindigkeit. Jedes Band hat eine **eigene Farbe und einen eigenen Multiplikator** (braun x1, gelb x3, blau höher …) – Schild „x3 Geschwindigkeit“ schwebt darüber. Bessere Bänder sind größer und auffälliger (blau mit Kristall-Muster).
- **Rückmeldung:** Bei jedem Schritt fliegen **lila Zahlen „+3.75T“ mit Schuh-Symbol** hoch, viele gleichzeitig → man sieht ständig, dass es vorangeht. Spieler hat eine leuchtende Aura.
- **HUD dazu:** unten Leiste mit Stufe, aktuellem Multiplikator und Kauf-Buttons für mehr Tempo; unten rechts Button „PLATZ Laufband“ (eigenes Laufband aufstellen).
- **Prinzip zum Übernehmen:** Die Kernaktion als stehendes Objekt in Stufen – man sieht an Farbe und Größe, welches Band besser ist, und spart auf das nächste. Jede Aktion erzeugt eine fliegende Zahl.

### +1 Speed Keyboard Escape – Laufband-Skins (Roblox)

![[keyboard-laufband-skins.jpg]]

- **Was ist gut:** Im Inventar gibt es einen eigenen Bereich für **persönliche Laufbänder** (Standard, Gold, Diamant …) neben Spuren, Auren und Outfits. Das Objekt aus der Welt wird so zum Sammel- und Angeber-Item.
- **Prinzip zum Übernehmen:** Das zentrale Objekt des Spiels in Skins anbieten.

### Blox Fruits – NPCs mit Leuchtring (Roblox)

![[bloxfruits-npc-ring.jpg]]
![[bloxfruits-questgeber.jpg]]

- **Was ist gut:** Jeder wichtige NPC steht in einem **leuchtenden Ring am Boden** (grün = Händler, gelb/gold = Quest). Über dem Händler ein großes grünes „$“ und „SHOP“, über dem Quest-Geber ein **riesiges gelbes „?“** mit „FRAGE“. Beim Ansprechen fährt die Kamera nah ran, unten erscheint ein Dialog mit Auswahl („Quest“, „Unbedingt“).
- **Prinzip zum Übernehmen:** NPC-Funktion an Farbe + Symbol über dem Kopf erkennbar, schon von Weitem. Die Leuchtringe zeigen auch, wo man stehen muss.

### 99 Nights in the Forest – Lagerfeuer als Fortschritts-Objekt (Roblox)

![[99nights-holz-anzuenden.jpg]]
![[99nights-feuer-fortschritt.jpg]]

- **Was es ist:** Das Lagerfeuer ist das Herz des Spiels. Bäume fällen → Holzstämme liegen herum → zum Feuer tragen → anzünden. Über dem Feuer ein **dicker Fortschrittsbalken „Level 1 Fortschritt: 86/100“** (rot bei wenig, grün bei viel). Ein **gelbes Dreieck** zeigt von oben auf das Objekt, mit dem man gerade etwas tun soll; gelbe Punkte markieren Bäume zum Fällen.
- **Rückmeldung:** Das Feuer wird sichtbar größer und heller, je weiter es ist; die Stämme liegen gut lesbar als dicke Zylinder herum.
- **Prinzip zum Übernehmen:** Ein Objekt in der Welt, das man gemeinsam „füttert“ und das dabei wächst – mit Fortschrittsbalken direkt darüber. Funktioniert super im Koop, weil jeder sieht, was der gemeinsame Beitrag bringt.

## Bei uns umgesetzt

-
