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

### +1 Speed Keyboard Escape – Hub (Roblox)

![[keyboard-hub.jpg]]

- **Was ist gut:** Der Hub ist eine große Halle, deren **Boden komplett aus riesigen Tastatur-Tasten** besteht – das Thema ist sofort klar und der Boden selbst ist die Deko. An der Wand **Bestenlisten** („TOP LEVEL“, „TOP WINS“) als große Tafeln. Vor dem Start ein Schild „Stufe 1“ und eine Reihe nummerierter Felder 1–8 auf dem Boden (Stufenauswahl zum Draufstellen).
- **Prinzip zum Übernehmen:** Ein einziges starkes Bau-Motiv (hier Tasten) für Boden und Wände. Bestenlisten als Wandtafeln im Hub = sozialer Ansporn ohne Menü.

### +1 Speed Keyboard Escape – Blick in die nächste Welt (Roblox)

![[keyboard-fenster-naechste-welt.jpg]]
![[keyboard-schneewelt.jpg]]

- **Was ist gut:** Am Ende der Süßigkeiten-Halle ist eine **große Öffnung, durch die man die nächste Welt (Schnee) schon sieht**. Die Schneewelt nutzt dasselbe Tasten-Motiv, aber in Mint/Weiß mit Tannen – gleiche Bauweise, neue Farbe und Deko. Die Wände der Halle sind mit übergroßen Süßigkeiten beklebt (Bonbons, Lollis, Kekse), so wirkt sie voll, ohne dass Objekte im Weg stehen.
- **Prinzip zum Übernehmen:** Nächstes Gebiet sichtbar machen (Weenie). Neue Welt = gleiche Bauteile, neue Palette + neue Deko → spart viel Bauzeit. Deko an die Wände, Lauffläche frei lassen.

### +1 Speed Keyboard Escape – Welten-Portal (Roblox)

![[keyboard-welten-portal.jpg]]

- **Was ist gut:** Ein rosa leuchtender Torbogen mit Schild „WELTEN“ und Info zur nächsten Welt („Welt 2 benötigt Level …“), links daneben die Bestenliste, davor die nummerierten Stufenfelder. Alle Ziele liegen in einer Blickachse.
- **Prinzip zum Übernehmen:** Portal mit Anforderung direkt auf dem Schild; das Portal in der Hauptblickrichtung vom Spawn platzieren.

### Blox Fruits – Startinsel (Roblox) → wichtigste Vorlage für [[Himmelsinseln]]

![[bloxfruits-startinsel.jpg]]
![[bloxfruits-kampfplatz.jpg]]

- **Was ist gut:** Die Startinsel ist **klein und überschaubar**: ein Dorf mit Fachwerkhäusern und Windmühlen am Rand, in der Mitte eine **große freie Grasfläche** und ein **Sandplatz als Kampfzone**, wo die Gegner stehen. Helle Sandwege verbinden alles, Holzzäune trennen Bereiche. Vom Kampfplatz aus sieht man über das Meer schon die **nächste Insel am Horizont** (schemenhaft im Dunst).
- **Farben:** knallig und einfach – sattes Grün, hellbrauner Sand, türkis-blaues Wasser mit weißer Schaum-Kante am Ufer, orange/rote Dächer. Wenig Details, große Flächen → läuft und liest sich gut am Handy.
- **Prinzip zum Übernehmen:** Insel = Dorf (sicher, Händler) + offene Kampffläche + Hafen. Unten mittig steht „Sichere Zone – PvP deaktiviert“ → Zonen werden im HUD angesagt. Nächstes Ziel immer am Horizont sichtbar lassen.

### Blox Fruits – Hafen und Boot (Roblox)

![[bloxfruits-hafen.jpg]]
![[bloxfruits-boot.jpg]]

- **Was ist gut:** Am Inselrand ein **Holzsteg** mit Bootshändler (grüner Ring, Schild „SHOP“). Man kauft ein Segelboot und fährt **frei übers Meer** zur nächsten Insel, die schon vom Steg aus zu sehen ist. Das Wasser ist hell und flach am Ufer, dunkler weiter draußen → man sieht, wo das offene Meer beginnt.
- **Prinzip zum Übernehmen:** Reisen zwischen Inseln als eigenes Erlebnis (Boot) statt nur Teleport. Für [[Himmelsinseln]]: Luftschiff oder fliegendes Reittier statt Boot, Wolkenmeer statt Wasser; Anlegestelle mit Händler am Inselrand.

### Fisch – Dorf und Strand (Roblox)

![[fisch-dorf.jpg]]
![[fisch-strand.jpg]]

- **Was ist gut:** Ganz anderer Stil als Blox Fruits: **gedeckte, realistische Farben**, grauer Himmel, Nebel über dem Meer, Felsen und Holzhütten → ruhige, etwas raue Fischerdorf-Stimmung. Betritt man einen Ort, steht sein **Name oben mittig** („• Moosewood Dorf •“). Der Boden wechselt sichtbar zwischen Sand, Kies und Holzplanken, das zeigt Wege ohne Schilder. Der Steg ist der zentrale Treffpunkt, an dem alle angeln.
- **Prinzip zum Übernehmen:** Ortsnamen beim Betreten einblenden. Stimmung über Licht, Nebel und gedeckte Farben – zeigt, dass Roblox nicht immer knallbunt sein muss. Ein zentraler Ort (Steg), an dem sich alle für die Hauptaktion treffen.

### 99 Nights in the Forest – Lager in der Mitte, Nebel drumherum (Roblox)

![[99nights-lagerfeuer-start.jpg]]
![[99nights-lager.jpg]]
![[99nights-karte-erweitert.jpg]]

- **Aufbau:** Man startet an einer **leeren Feuerstelle mitten auf einer Lichtung**. Ringsum ein Wald aus einfachen Block-Bäumen, dahinter dichter **grauer Nebel**, der die Sicht begrenzt. Das Lager wächst sichtbar: gedeckter Tisch mit Stühlen, Schild „Gäste kommen in 6 Tagen“, Werkbank. Am Rand eine Tafel „Verlorene Kinder-Standorte“ mit leeren Feldern – das langfristige Ziel hängt sichtbar im Lager.
- **Map öffnet sich:** Hat das Feuer 100 % erreicht, kommt die Meldung „Das Feuer hat 100 % erreicht. Die Karte ist …“ (erweitert) – der Nebel weicht zurück und neue Teile des Waldes (Teich, Felsen) werden erreichbar.
- **Stil:** sehr einfache Formen (Block-Bäume, flache Wasserflächen in kräftigem Blau), aber durch Nebel und grauen Himmel trotzdem bedrohlich.
- **Prinzip zum Übernehmen:** Ein Zentrum, um das alles kreist; die Welt wird durch Fortschritt am Zentrum größer statt durch Portale. Nebel als natürliche Grenze statt unsichtbarer Wände. Für [[Himmelsinseln]] denkbar: Leuchtfeuer auf jeder Insel, das Wolken zurückdrängt.

### Ziehe einen Dino – Ladenstraße (Roblox)

![[dino-ladenstrasse.jpg]]

- **Was ist gut:** Vom Grundstück führt eine **breite orange Straße** zur Wurf-Schlucht. Links und rechts **Marktstände mit gestreiften Markisen** und großen Schildern („Spuren“, „Harpunen“, „Verkaufen“), jeder in eigener Farbe; ein Regenbogen-Stand lockt mit Glitzer. Am Ende ein großes leuchtendes Tor mit Countdown („Christmas Update 00:21:34“). Blaue Pfeil-Kacheln auf dem Boden zeigen den Weg (Tutorial „Schritt 5/5 – Wieder werfen!“ oben).
- **Prinzip zum Übernehmen:** Die Läden liegen **auf dem Weg** zwischen den beiden Hauptorten (Grundstück ↔ Aktion), man kommt bei jedem Durchgang daran vorbei. Event-Countdown als großes Tor in der Welt.

### Pet Simulator 99 – Zonen hintereinander (Roblox)

![[petsim-zonen-tor.jpg]]
![[petsim-obby-portal.jpg]]

- **Aufbau:** Die Welt ist eine **Kette von Zonen** (Räume zwischen hohen Felswänden), jede mit eigenem Thema und eigener Bodenfarbe (Herbst orange, Bauernhof gelb, Blumenwiese grün). Am Ende jeder Zone ein Tor mit **riesigem Preis „400k“ und Button „Kaufen“**, oben „Nächstes Gebiet – 400k“ mit Balken, wie weit man ist.
- **Nebenattraktionen:** In der Zone stehen Extras wie ein **Regenbogen-Portal „Klassisches Obby“** (Hindernislauf für Belohnungen) und ein Ei-Automat.
- **Prinzip zum Übernehmen:** Lineare Zonen-Kette mit Preisschild am Tor ist die einfachste Fortschritts-Map. Jede Zone ist klein und voll, statt groß und leer.

## Bei uns umgesetzt

-
