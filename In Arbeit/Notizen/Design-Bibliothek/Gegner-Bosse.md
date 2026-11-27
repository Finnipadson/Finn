# Gegner-Bosse

Zurück: [[Design-Bibliothek]]

## Bewährte Muster

- **Telegraphing:** Jeder starke Angriff wird angekündigt (Aufleuchten, Ausholen, Bodenmarkierung, Sound), etwa 0,4–1 s vorher. Je stärker der Angriff, desto länger die Ankündigung.
- **Absicht zeigen:** Symbol über dem Gegner, was er als Nächstes tut (Angriff, Block, Zauber).
- **Gegner an der Silhouette erkennen:** Jeder Typ hat einen eigenen Umriss und eine eigene Farbe, auch im Chaos.
- **Boss-Intro:** Name und Titel groß eingeblendet, kurze Kamerafahrt, eigene Musik.
- **Boss-Lebensbalken** groß unten oder oben mittig, mit Markierungen für die Phasen.
- **Phasen:** 2–3 Phasen; bei jedem Wechsel ein neuer Angriff und eine kurze Atempause (Unverwundbarkeit plus Animation).
- **Fairness:** Nach einem großen Angriff ein Fenster zum Zurückschlagen. Der Spieler soll beim Tod denken: „Hätte ich sehen können.“

## Fallen

- Angriffe aus dem Off ohne Ankündigung.
- Neue Phase = nur mehr Leben und mehr Schaden, ohne neues Verhalten.

## Referenzen

### 99 Nights in the Forest – Wolf aus dem Nebel (Roblox)

![[99nights-wolf-nebel.jpg]]

- **Was ist gut:** Der Wolf ist ein simples Block-Modell, wirkt aber bedrohlich, weil er **aus dem Nebel** kommt, wo man ihn erst spät sieht. Über ihm ein kleiner grüner Lebensbalken. Gefahr steigt mit Entfernung vom Lager.
- **Prinzip zum Übernehmen:** Bedrohung durch Sichtweite (Nebel, Dunkelheit) statt durch komplizierte Gegner – einfaches Modell reicht. Sicherer Bereich in der Mitte, Gefahr am Rand.

## Bei uns umgesetzt

-
