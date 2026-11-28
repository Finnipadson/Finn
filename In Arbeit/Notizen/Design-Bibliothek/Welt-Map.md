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

### Ziehe einen Dino – Stil der ganzen Karte (Auswertung von 45 Standbildern, 28.11.2026)

![[dino-weg-zum-deck.jpg]]
![[dino-wurfdeck.jpg]]
![[dino-ladenstrasse-2.jpg]]
![[dino-hub-tor.jpg]]
![[dino-training-platz.jpg]]

- **Boden:** sattes, helles Grün als großes Schachbrett (zwei Grüntöne, Kacheln ~8 Studs), ganz glatt, kein Gras-Material. Wirkt sauber und spielzeughaft.
- **Hauptweg:** breiter **orange-gelber Kachelweg** (Schachbrett Orange/Hellorange, dunklerer Randstreifen) vom Grundstück über die Ladenstraße bis zur Wurfplattform. Man folgt ihm automatisch.
- **Ladenstraße am Weg:** Stände mit gestreiften Markisen (Blau/Weiß, Rot/Weiß), riesige bunte Schilder in eigener Schriftfarbe, ein Stand mit Regenbogen-Bogen und Wolken. Dazwischen **Holz-Laternen** (Pfosten mit gelb leuchtendem Würfel), Bestenlisten-Tafeln im Holzrahmen mit **gelber Krone** obendrauf, Glücksrad, Event-Tor mit Countdown am Ende.
- **Wurfplattform:** erhöhtes **Holzdeck aus Planken** mit Treppe davor, dicken dunkelbraunen Holzgeländern links/rechts, in der Mitte eine **gelbe runde Scheibe** mit gestricheltem Ring aus orangen Kacheln, darüber schwebend „HIER WERFEN!“ in Gelb.
- **Schlucht:** rotbraune Felswände mit **runden Felsbrocken** (Kugeln) darin, oben Grasrand mit **runden Wolken-Bäumen** (mehrere Kugeln), unten Baumstämme, Steine, Knochen. Jede Zone eigener Boden/Nebel (Sumpf: grünlicher Nebel, Pilze, Rohrkolben, Baumstümpfe, Seerosen-Teiche).
- **Zonenleiste im Flug:** links senkrecht Symbole aller Zonen (Mud → Sumpf → Tar → Vulkan), die aktuelle groß mit Rahmen und Unterstufen „I II III“; oben groß Glück + Zonenname + Meter.
- **Grundstück:** **braune Holzzäune** (dicke Pfosten, zwei Latten), großes schräges Holzschild „Name's Grundstück“, riesige Zahlen „8 / 10“ und „$2.9K/s“ schweben über dem Eingang, Avatar-Kopf daneben; Ausbau-Pfeilschild „10 ▶ 11 – $2.5K“ am Zaun.
- **Training:** Gerät auf rundem Holz-/Blau-Teller mit **Zackenring** (rosa/weiße Zähne) auf grauer Steinmatte; daneben gelbe runde Kauf-Scheibe; darüber schwebend „$600K – Nächstes: … – +12 XP / Rep“.
- **Licht:** sonnig, warm, leichte Überstrahlung (Bloom), kräftige Sättigung.
- **Prinzip zum Übernehmen:** Alles ist **ein Spielplatz aus einfachen, sauberen Formen in kräftigen Farben**; Holz für alles „Gebaute“ (Zäune, Deck, Schilder, Laternen), Orange für den Weg, Grün-Schachbrett für den Rest. Wichtiges hat riesige schwebende Schrift. **Bei uns umgesetzt:** [[Bubble Safari]] Phase 2b (eigene Formen und Texte, kein Nachbau).

### Voxel-Wurfspiel von „TVA Studios“ (TikTok-Teaser, 28.11.2026) – Zielbild für Bubble Safari

![[tva-terrassen-schlucht.jpg]]
![[tva-wurf-start.jpg]]
![[tva-schwebende-inseln.jpg]]
![[tva-hub-training.jpg]]
![[tva-kristall-biom.jpg]]
![[tva-neon-biom.jpg]]

Warum das „echt“ wirkt und unser erster Versuch nach „KI-Einheitsbrei“ aussah:
- **Terrassen statt Wand:** Die Schlucht steigt in **3–5 Stufen** nach außen an, jede Stufe mit Gras-Kante und Erdschicht. Dadurch Tiefe und Staffelung; eine glatte senkrechte Wand wirkt billig.
- **Pixel-Textur überall:** Erde, Gras und Holz haben ein **Voxel-/Pixelmuster** (helle und dunkle Würfelchen), der Boden hat Noppen-Kacheln. Glatte einfarbige Flächen (SmoothPlastic) sind das Hauptproblem.
- **Sehr viel kleine Deko:** buschige **Voxel-Bäume aus vielen Würfeln**, rote Pilze mit Punkten, Sonnenblumen, Blumen, Zuckerstangen – auf **jeder** Terrasse, dicht an dicht.
- **Himmel lebt:** **schwebende Inseln** mit Gras und Erde unten, Wolken, ein leuchtender Ring am Ende der Strecke; Dunst Richtung Horizont.
- **Biome wechseln die ganze Welt:** Kristall-Biom (lila Wände, leuchtende Kristalle, Glitzer), Neon-Stadt (Hochhäuser mit Leuchtstreifen) – nicht nur andere Bodenfarbe.
- **Objekte als Pixel-Kunst:** Trainings-Gerät, Shop, Verzauberer sind aus vielen kleinen Würfeln mit Muster gebaut, mit Leuchtteilen.
- **Licht:** starke Sättigung, Bloom, weiche Schatten.

### Wurfspiel von „n1tro_camdem“ (TikTok, 28.11.2026) – zweites Zielbild

![[n1tro-wurf.jpg]]
![[n1tro-wueste.jpg]]
![[n1tro-winter.jpg]]
![[n1tro-ruinen-lava.jpg]]
![[n1tro-fantasy.jpg]]
![[n1tro-gehege.jpg]]

- **Wände mit Muster:** Schluchtwände als großes **Schachbrett aus zwei Steintönen** (Wüste: Sand/Beige, Ruinen: dunkelgrau mit Lava-Kante, Fantasy: Lila), oben Gras- oder Schnee-Kante mit Würfel-Überhang. Kein glattes Einfarb.
- **Boden mit Noppen-/Kachelmuster** und kleinen Kacheln; Wurfplatz aus orangen Noppen-Kacheln.
- **Viele kleine Voxel-Objekte am Rand:** Bäume aus Würfeln, Windrad (Wüste), Laternen, Tannen mit Schnee, tote Bäume und Feuerschalen (Ruinen), leuchtende Pilze/Blumen (Fantasy).
- **Stimmung pro Biom über Licht und Nebel:** Winter blaugrau und neblig, Ruinen dunkel mit orangem Glühen, Fantasy lila mit dicken Comic-Wolken.
- **Gehege:** Noppen-Rasen, Holzzäune in Gelb/Braun, riesige Tiere mit Glitzer-Aura.
- Gemeinsam mit dem TVA-Video: **Muster statt glatter Flächen, Staffelung/Tiefe, dichte kleine Deko, Licht/Nebel pro Biom.**

### „Throw a Seed“ (TikTok von vnsaroblox, 28.11.2026) – drittes Beispiel, User findet die beiden davor besser

![[vnsa-tiefsee.jpg]]
![[vnsa-wolken-schachbrett.jpg]]
![[vnsa-sand.jpg]]

- Ebenfalls **Schachbrett-Wände** in zwei Tönen (Blau/Weiß, Sand), Burgtürme und Regenbogen aus Würfeln am Rand, Tiefsee-Biom mit Seetang. Wirkt etwas blasser/heller als TVA und n1tro – als Vorbild zweitrangig.

### Pet Simulator 99 – Zonen hintereinander (Roblox)

![[petsim-zonen-tor.jpg]]
![[petsim-obby-portal.jpg]]

- **Aufbau:** Die Welt ist eine **Kette von Zonen** (Räume zwischen hohen Felswänden), jede mit eigenem Thema und eigener Bodenfarbe (Herbst orange, Bauernhof gelb, Blumenwiese grün). Am Ende jeder Zone ein Tor mit **riesigem Preis „400k“ und Button „Kaufen“**, oben „Nächstes Gebiet – 400k“ mit Balken, wie weit man ist.
- **Nebenattraktionen:** In der Zone stehen Extras wie ein **Regenbogen-Portal „Klassisches Obby“** (Hindernislauf für Belohnungen) und ein Ei-Automat.
- **Prinzip zum Übernehmen:** Lineare Zonen-Kette mit Preisschild am Tor ist die einfachste Fortschritts-Map. Jede Zone ist klein und voll, statt groß und leer.

### Steal a Brainrot – Basen am Teppich, Plaza in der Mitte (Roblox)

![[brainrot-your-base.jpg]]
![[brainrot-trade-plaza.jpg]]

- **Aufbau:** Die Basen der Spieler stehen in einer Reihe links und rechts des roten Lauf-Teppichs (Name auf großem Schild, „wqweryn16's Base“). Die eigene Basis hat am Eingang ein großes Schild **„YOUR BASE – $13.4B/s“**, so findet man sie sofort.
- **Mitte:** Zwischen den Basen ein Platz mit den Extras: blaues **Trade-Plaza-Portal** (Hände-Symbol), ein grünes **Glücksrad „Hacker Wheel – Free Spin in 29s“**, ein Stand „Robux Shop“. Alles mit schwebender Beschriftung in eigener Farbe.
- **Prinzip zum Übernehmen:** Basen entlang eines zentralen Wegs, auf dem die Action passiert; eigene Basis deutlich markiert; Extras gebündelt in der Mitte.

### Throw Food For Animals – Grundstücke von oben (Roblox)

![[futter-grundstuecke-uebersicht.jpg]]

- **Aufbau:** Alle Grundstücke liegen **nebeneinander in einer großen Senke**, umgeben von Gras-Klippen mit sichtbaren Erdschichten (Block-Stil). Jedes Grundstück ist ein eingezäuntes Rechteck mit gleicher Ausstattung: Trainings-Stange mit weißem Kreis, Stand mit blau-weißer Markise, rosa Herz-Torbogen.
- **Bestenliste in der Welt:** Über jedem Grundstück schwebt das **Avatar-Bild des Besitzers mit Name und Einkommen** („biggfishh0 $12,2T/s“, „linchen_amdeus $37M/s“, „minnilite7 $1,66M/s“, „Gerneoo $124/s“). Man sieht sofort, wer wie weit ist – ohne Menü.
- **Die besten Tiere sind der Status:** Das RIESIGE Mammut überragt das ganze Gelände (etwa 10× so hoch wie ein Spieler), daneben Tanuki und geflügelte Caladrius. Auf den Nachbar-Grundstücken stehen kleine Tiere (Pferd, Tiger, Qualle). Wer neu ist, sieht direkt, worauf er hinarbeiten kann.
- **Wegführung:** Gelbe Pfeil-Kacheln am Boden führen vom Wurfbereich zur eigenen Trainings-Station.
- **Prinzip zum Übernehmen:** Grundstücke dicht nebeneinander und von überall einsehbar; Einkommen als schwebendes Schild = soziale Bestenliste; riesige seltene Tiere als Aushängeschild des Besitzers. Siehe auch [[Kreaturen-Pets]] (Größenstufen) und [[Trainings-Objekte]].

### Was auf den Terrassen steht (TVA + n1tro, Nahaufnahmen 28.11.2026)

Bilder: `Bilder/Welt-Map/stufen-*.jpg` (TVA: pilze-boden, pilze-wand, wiese-inseln, dschungel-herbst, schnee, wueste, kristall, uebersicht; n1tro: wald). Collagen in `BubbleSafari/Probe-Bilder/vorbild-stufen-1/2.jpg`.

- **Viele schmale Stufen statt weniger hoher:** TVA hat 5–7 Stufen, jede nur etwa 1,5–3 Spielerhöhen hoch und leicht zurückversetzt. Die Wand wirkt dadurch wie ein Hang.
- **Erde mit feiner Pixel-Struktur:** dunkle Einzelpixel und waagrechte Farbbänder (dunkelbraun/rotbraun), dazu einzelne grüne Moos-Pixel mitten in der Wand. Keine großen Flecken.
- **Gras-Kante:** dünne Grasdecke, darunter unregelmäßig herabhängende Gras-Pixel in vielen Längen, sehr dicht.
- **Deko auf jeder Stufe, dicht und groß:**
  - **Riesen-Fliegenpilze** (rot mit weißen Pixel-Punkten, runde gestufte Kappe, dicker heller Stiel), oft größer als Bäume. Einige braune Pilze dazwischen.
  - **Runde Voxel-Bäume:** Krone wie eine Kugel aus Würfeln (nicht lose Würfel), dazu Palmen mit Fächerblättern weiter hinten.
  - **Goldene Ringe / Sonnenblumen** als Sammel-Optik, kleine Blumen (blau, lila, rot) und Kakteen-artige Pflanzen am Boden.
  - Am Schluchtboden vor der Wand: kleine Bäume, Pilze, Steine mit Moos.
- **Biom-Wechsel nur über Farben + Deko:** Wüste (Sand-/Orangebänder, Kakteen, Sonnenschirme), Schnee (blau-weiße Wand, Tannen mit Schnee, Schneemänner), Herbst/Dschungel (Laubbäume orange/gelb/rot, Palmen), Kristall (lila Wand, Kristallspitzen). Form der Terrassen bleibt gleich.
- **Schwebende Inseln** mit Palme oder Pilz oben, Erd-Pyramide unten, auf mehreren Höhen über der Schlucht.
- **n1tro:** große kantige Würfel-Kronen mit Noppen, ein Baum mit leuchtenden Augen (Gesicht im Stamm), Wand als braun/rotes Schachbrett; Gras-Kappe stark überhängend.

### Shops im TVA-Video (Standbilder 28.11.2026, Video bei 6–11 s)

Bilder: `Bilder/Welt-Map/shop-tva-*.jpg` (uebersicht, dice-shop, dice-shop-nah, enchanter-a/b). Collage `BubbleSafari/Probe-Bilder/vorbild-shops.jpg`.

- **Kleines Häuschen im Voxel-Stil**, ca. 2 Spielerhöhen, auf einem **leuchtenden Kreis am Boden** (Dice Shop gelb-orange, Enchanter hellblau) – zeigt „hier ist ein Laden“ schon von weitem.
- **Dice Shop:** dunkelrotes Ziegeldach, darauf **drei große weiße Würfel** (Ware als Dachschmuck), Holzschild mit Pixel-Schrift „DICE SHOP“, rot-gelb gestreifte Markise, dunkelblaue Steinwände, weitere Würfel neben dem Eingang, kleine Fackeln am Dachrand.
- **Enchanter:** blaues Dach mit hellen Türmchen an den Ecken, Pixel-Schild „ENCHANTER“ mit orangem Rahmen, Ornament (Kristall/Rune) über der Tür und am Boden davor. **Über dem Dach schwebt ein leuchtender weißer Würfel**, umkreist von kleinen lila Würfeln + Glitzer/Nebel (animiert: dreht/schwebt, Partikel).
- **Prinzip zum Übernehmen:** Laden = Mini-Gebäude mit dem, was er verkauft, groß als Dachschmuck; ein animiertes Objekt (schwebend/drehend + Partikel) als Blickfang; farbiger Bodenring als Eingangszone.

## Bei uns umgesetzt

- Bubble Safari (28.11.2026): 3 Terrassen à 27 Studs (Kessel + Schlucht), Noppen-Boden, Voxel-Bäume/Pilze/Sonnenblumen, Biom-Farben je Abschnitt, schwebende Inseln (`Bauen/Map.lua`, `terrasse()`).
