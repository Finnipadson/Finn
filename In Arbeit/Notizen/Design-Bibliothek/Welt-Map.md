# Welt-Map

Zurück: [[Design-Bibliothek]]

Wie eine Map aufgebaut ist: Spawn, Wege, Zonen, Orientierung. Schwerpunkt Roblox ([[Himmelsinseln]]), gilt aber auch für 3D-Spiele wie [[Clean the Skyscraper]].

## Bewährte Muster

### Spawn & Hub
- **Alles Wichtige in 10 Sekunden Laufweite vom Spawn:** Shop, Verkaufen, Upgrades, Portal zum ersten Gebiet. Grow a Garden: Saat- und Verkaufsstand direkt nebeneinander am Spawn.
- **Spawn schaut auf das Ziel:** Die Kamera beim Spawnen zeigt auf das erste Ziel (Shop oder Weg), nicht auf eine Wand.
- **Hub ist kompakt und rund/symmetrisch,** Gebiete gehen sternförmig davon ab. Jedes Gebiet ist vom Hub aus sichtbar (Portal, Torbogen, Insel am Horizont).

### Wege & Führung
- **Wege sind heller/glatter als die Umgebung** – man folgt ihnen automatisch.
- **Wegweiser in der Welt:** leuchtende Linie zum nächsten Ziel (Grow a Garden), Pfeile auf dem Boden, Schilder mit Symbol.
- **Landmarken:** pro Gebiet ein großes, von überall sichtbares Objekt (Turm, Baum, Vulkan). Daran orientiert man sich ohne Minimap.
- **Weenie-Prinzip (Disney):** etwas Großes, Interessantes am Ende eines Weges zieht den Spieler dorthin.

### Zonen & Fortschritt
- **Gebiete in einer Reihe oder einem Ring,** jedes mit eigener Farbe, eigenem Boden und eigener Musik (Wald grün, Wüste gelb, Lava rot …). Man erkennt an der Farbe, wo man ist.
- **Sperren sichtbar machen:** Das nächste Gebiet ist hinter einer Wand/einem Tor mit Preis oder Level-Schild schon zu sehen („Wüste – 5.000 $“). Das ist das Ziel, auf das man spart.
- **Jedes neue Gebiet = höhere Zahlen:** Gegner, Belohnungen und Preise steigen pro Zone deutlich (oft x5–x10).

### Spieler-Grundstücke (Tycoon/Simulator)
- **Pro Spieler ein gleich großes Grundstück** (Beet, Gehege, Basis), im Kreis oder in Reihen um den Hub angeordnet. Name des Besitzers auf einem Schild darüber.
- Grundstücke **einsehbar für andere** – man sieht, was andere schon haben (Ansporn) und kann beim Klauen-Spielen (Steal a Brainrot, Steal An Egg) hinein.
- Klare **Grenze** (Zaun, Laser, Farbwechsel am Boden) und ein Eingang.

### Maßstab (Roblox)
- Spielfigur ~5 Studs hoch. Türen mind. 8 Studs, Wege mind. 10–12 Studs breit (mehrere Spieler gleichzeitig).
- Große Freiflächen vermeiden: Zwischen zwei interessanten Dingen nicht mehr als ~10 s laufen.
- Für Handy: Objekte groß und farbig, wenig feine Details – alles muss auf kleinem Bildschirm lesbar sein.

## Fallen

- Spawn in der Mitte eines leeren Platzes → Spieler weiß nicht, wohin.
- Zu viele Wege mit gleichem Aussehen → man verläuft sich.
- Alles in einem Gebiet in einer Farbe → Wege, Objekte und Gegner verschwimmen.

## Referenzen

<!-- Bilder hier einbetten: ![[datei.jpg]] + was daran gut ist. Am besten: Übersicht von oben / Spawn-Blick -->

## Bei uns umgesetzt

-
