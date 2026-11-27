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

### Ziehe einen Dino – Spielschleife aus 3 Stationen (Roblox)

Kreislauf: **Bankdrücken** (Kraft sammeln) → **Speer werfen** (je weiter, desto bessere Zone und Glück) → **Dino ziehen** (Zufall mit Chancen) → Dino kommt aufs **Grundstück** und bringt Geld pro Sekunde → besserer Speer / mehr Kraft → wieder werfen.

![[dino-bankdruecken.jpg]]

- **Bankdrücken:** Die Hantel hat **Dinos als Gewichte** an den Enden („Heben: Compy“) – das Gesammelte wird selbst zum Trainingsgerät. Jeder Druck gibt „+1 EP“ als fliegende Zahl, unten Balken „Stufe 4 – 8/11“, Buttons „HALT“ (rot) und „AUTO 99 R$“. Bei Stufenaufstieg groß „STÄRKER! LEVELAUFSTIEG! Wurfkraft +20“; ab und zu ein „x2“-Kreis zum Anklicken.

![[dino-wurfplattform.jpg]]

- **Wurfplattform:** runde Plattform mit orangen Kacheln, Speer in der Hand, **senkrechter Kraftbalken** daneben (+598), Text „Klicke, um zu werfen!“. Treffer im richtigen Moment = „PERFECT!“; Serien von guten Würfen geben mehr Glück („Serie x5 · +135 % Glück“). Ein „SUPER-Wurf“ garantiert „legendär oder besser“.

![[dino-grundstueck.jpg]]

- **Grundstück:** eingezäunt, großes Holzschild „biggfishh0's Grundstück“, darüber „8 / 10“ Dinos und das Einkommen „2.9K/s“ als riesige Zahl. Die Dinos laufen frei im Gehege herum. Ist es voll: Meldung „Dein Grundstück ist voll! Verbessere es am Schild“ – Upgrade direkt am Schild.
- **Prinzip zum Übernehmen:** Jede Station ist ein Objekt in der Welt mit eigenem Balken und eigener Rückmeldung; das Gesammelte taucht an mehreren Stationen wieder auf (Hantel, Gehege). Ausbau-Upgrade direkt am Objekt, das ausgebaut wird.

### Fische für geheime Tiere – gleiche Schleife, anderes Thema (Roblox)

![[geheimtiere-klimmzug.jpg]]
![[geheimtiere-gehege-upgrade.jpg]]
![[geheimtiere-reiten.jpg]]

- **Gleiches Muster wie „Ziehe einen Dino“:** Trainings-Station (hier **Klimmzugstange** auf rundem Feld, „Drücke STOP, wenn du fertig bist!“, „+4 XP“, „Level 1 – 36/40“) → Angel auswerfen → Tier ziehen → Tier ins Gehege. Das Erfolgsrezept wird also von mehreren Spielen kopiert – ein starkes Zeichen, dass es funktioniert.
- **Gehege-Ausbau:** großes Holzschild „UPGRADE PEN – 6 > 8 SLOTS – $1.7K“ direkt am Gehege, daneben ein Nest-Haufen.
- **Haustier reiten:** Gefangene Tiere kann man **reiten** und damit übers Wasser fahren (Hinweis „Sprich mit dem Fischer, um dein Haustier zu reiten“). Unten Buttons „Zurück an Land“, „Fisch“ (grün, groß), „AUTO“, darüber der aktuelle Köder („Köder: Wurm“).
- **Prinzip zum Übernehmen:** Gesammelte Tiere bekommen eine zweite Funktion (Reittier) → mehr Wert pro Tier. Für [[Himmelsinseln]]: fliegende Begleiter als Reittier zwischen den Inseln.

### Pet Simulator 99 – Zerbrechliche Gegenstände, die Pets abbauen (Roblox)

![[petsim-zerbrechliche.jpg]]

- **Was es ist:** Jede Zone ist **übersät mit zerbrechlichen Dingen** – Holzkisten voller Münzen, Geschenkboxen, Münzhaufen, Tresore. Man klickt eins an, und **alle eigenen Pets laufen hin und greifen es an** (Schadenszahlen über dem Objekt, kleiner Lebensbalken). Beim Zerbrechen spritzen Münzen und Diamanten heraus, ab und zu „BONUS!“. Die Dinge spawnen ständig nach.
- **Prinzip zum Übernehmen:** Pets haben eine sichtbare Aufgabe (abbauen/kämpfen), mehr Pets = schneller. Das Feld ist nie leer, es gibt immer etwas zu tun. Für [[Himmelsinseln]]: Begleiter greifen Gegner oder Kristall-Brocken an, auf die man zeigt.

### Pet Simulator 99 – Riesen-Ei (Roblox)

![[petsim-riesen-ei.jpg]]

- **Was es ist:** Zwischendurch liegt ein **übergroßes Ei** im Feld; „Klicken zum Öffnen!“ – es blitzt weiß auf, Funken fliegen, ein Pet erscheint. Belohnung mitten in der Welt statt im Menü.

## Bei uns umgesetzt

-
