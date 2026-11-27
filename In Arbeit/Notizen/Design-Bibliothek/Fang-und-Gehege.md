# Fang-und-Gehege

Zurück: [[Design-Bibliothek]]

Genre-Vorlage für Roblox-Spiele nach dem Muster **trainieren → werfen/angeln → Tier fangen → ins Gehege → Geld pro Sekunde**. Stand Nov. 2026 eines der erfolgreichsten Genres (Throw Food For Animals: Spitze 2,5 Mio. Spieler gleichzeitig).

Gefilmt: **Throw Food For Animals**, **Ziehe einen Dino** und **Fische für geheime Tiere**. Weitere Details zu den letzten beiden: [[Objekte-Mechaniken]], [[Game-Feel]], [[Kreaturen-Pets]].

## Die Schleife (bei allen drei gleich)

1. **Trainieren** an einer Station (Bankdrücken, Klimmzugstange) → Kraft/Wurfstärke steigt. Balken „Stufe 11 – 5/6“, Button „HALTEN“, fliegende „+2 XP“, ab und zu ein „x2“-Kreis zum Antippen. Stufenaufstieg: „STUFE ERHÖHT! Wurfstärke +3“.
2. **Werfen/Auswerfen** von einer Plattform am Rand der Schlucht: senkrechter Kraftbalken, im richtigen Moment tippen → „PERFEKT!“. Gute Würfe in Serie geben mehr Glück.
3. **Flug durch Biome:** Die Kamera fliegt mit dem Wurfgegenstand eine **gerade Schlucht** entlang; der Boden wechselt die Zonen (Wald → Savanne → Wüste …), oben live Zonenname + **Glücks-Multiplikator** („2.21X → 5.26X → 9.61X Glück“). Je weiter, desto bessere Zone und Chance.
4. **Tier erscheint und wird enthüllt:** Name als Lückenwort („L_ON“, „_ANGAROO“), dann Name, Größe, Einkommen und „NEUER BESTER!“.
5. **Ins Gehege:** Tier wandert in den Rucksack/die Leiste unten, dann aufs eigene Grundstück. Mehr Tiere = mehr Geld pro Sekunde → besseres Wurfzeug kaufen → weiter werfen.

## Was Throw Food For Animals anders macht

![[futter-training.jpg]]
![[futter-wurf.jpg]]
![[futter-flug-wald.jpg]]
![[futter-flug-savanne.jpg]]

- **Man wirft Futter, kein Werkzeug:** Banane, Orange, Käse, Brotlaib … Das Futter landet, und **das Tier läuft herbei und frisst** – freundlicher als Speer/Harpune, passt für jüngere Spieler.
- **Futter = Ausrüstung mit Stufen:** Jedes Futter hat eine Stufe; besseres Futter bringt vermutlich mehr Weite oder seltenere Tiere (im Video nicht eindeutig zu sehen).

![[futter-kaenguru.jpg]]
![[futter-loewe-raetsel.jpg]]

- **Enthüllung:** Tier steht auf der Landestelle in einem Lichtkreis neben dem Futter; Name farbig („KANGARU“), darunter Größe („GROSS“) und Einkommen ($78,8K/s), Schild „NEUER BESTER!“. Tiere im gleichen Block-Stil wie überall (siehe [[Kreaturen-Pets]]), Größe als Variante.

![[futter-lebensmittelgeschaeft.jpg]]
![[futter-neues-essen-rucksack.jpg]]

- **Lebensmittelgeschäft:** Karten pro Futter mit Seltenheit (Gewöhnlich/Ungewöhnlich), Stufe und „AUSRÜSTEN / AUSGERÜSTET“. Neues Futter wird mit Popup angekündigt: „NEUES ESSEN FREIGESCHALTET! Du kannst jetzt kaufen: BROTLAIB – $12M – GESCHÄFT“.
- **Rucksack-Leiste:** Unten mittig die gerade gefangenen Tiere als kleine Kacheln mit $/s und Varianten-Schild (GOLD, DIAMANT).

![[futter-tiere-verkaufen.jpg]]
![[futter-gehege-meine-tiere.jpg]]
![[futter-tier-index.jpg]]

- **Meine Tiere / Verkaufen:** Liste mit Bild, Name, $/s und zwei Buttons „ABHOLEN“ (ins Gehege) und „VERKAUFEN“; Zähler „10/10“ für Gehege-Plätze; großer Button **„Rüste das Beste aus“** (stellt automatisch die besten Tiere ins Gehege). Verkaufen-Fenster mit Rucksackwert und „Alle verkaufen (7)“.
- **Gehege:** eingezäuntes Grundstück, Tiere laufen frei herum mit Schild ($/s). Meldung beim Ausbau: „Grundstück aufgewertet! Es beherbergt jetzt 12 Tiere“. Im Hintergrund riesige Tier-Statuen auf den Grundstücken anderer Spieler – man sieht, was andere haben.
- **Tier-Index:** pro Welt (Taiga, Eclipse Kingdom …) ein Raster mit Silhouetten nach Seltenheit, Gesamtzähler „Freigeschaltet: 4/176“, gesperrte Welten mit „GESPERRT“.

## Event „Feast“ (Throw Food For Animals, Nov. 2026)

![[futter-event-koch.jpg]]
![[futter-event-koch-text.jpg]]

- **Event-NPC:** Ein riesiger **Truthahn-Koch** (Kochmütze, weiße Jacke, Block-Stil) steht an einem gedeckten Tisch mit rot-weißer Decke, Glocke, Gewürzregal; an der Wand Event-Bestenlisten. Er erklärt das Event in einem Satz: „Every half hour I ring the dinner bell for the Feast. That's when animals can bring back ingredients from all over the map!“ Vor ihm ein leuchtender Abgabe-Kreis am Boden.
- **Rhythmus:** Das Event kommt **alle 30 Minuten** von selbst. Unten rechts ein Truthahn-Symbol mit Countdown („4:24“, „0:20“) – man weiß immer, wann das nächste Festmahl ist bzw. wie lange es noch läuft.

![[futter-event-roter-himmel.jpg]]

- **Die Welt verändert sich:** Während des Festmahls wird der **Himmel feuerrot-orange** und die ganze Schlucht in warmes Licht getaucht. Man sieht sofort: Jetzt ist Event.

![[futter-event-zutat.jpg]]

- **Event-Währung:** Gefangene Tiere bringen zusätzlich eine **Zutat** mit („+1 SWEET POTATO!“ beim Enthüllen). Oben links ein Korb-Symbol mit Zähler (1, 2, 4 …). Die Zutaten bringt man zum Koch.
- **Prinzip zum Übernehmen:** Wiederkehrendes Kurz-Event (feste Uhrzeit-Intervalle) mit eigener Währung, eigenem NPC und sichtbarer Weltveränderung. Kostet wenig (Licht/Himmel ändern, ein NPC, ein Zähler), gibt aber einen Grund, länger online zu bleiben. Passt zu [[System-Rezepte]] „Shop mit Restock-Timer“ (gleiche Uhrzeit-Rechnung für alle Server).

### Weitere Bilder aus dem Event-Video

![[futter-gorilla-raetsel.jpg]]
![[futter-gold-gorilla.jpg]]
![[futter-flug-dschungel.jpg]]
![[futter-neue-ausruestung.jpg]]

- Enthüllung mit Chance („Glück! 1 in 28“, „Superglücklich! 1 in 51“) über dem Tier und Lückenwort („GORILL_“).
- Varianten: „GOLT Gorilla“ ganz golden mit Glitzer, „Diamant Gorilla“ hellblau-weiß – gleiches Modell, anderes Material (siehe [[Kreaturen-Pets]]).
- Neues Biom **Dschungel** weiter hinten in der Schlucht mit bis zu ~10,5X Glück (Bambus, Palmen, Blumen).
- Popup „NEUE AUSRÜSTUNG! Du kannst jetzt kaufen: Obsidian-Bar“ – neue Trainings-Stange wird freigeschaltet und direkt beworben.

## Größe und Seltenheit

Tiere sind **Art × Größe × Material**: seltene Arten sind von Natur aus größer und haben mehr Animationen, „GROSS“ ist ein zusätzlicher Zufallswurf (Ziege ×4,3 Einkommen), dazu Gold/Diamant. Details mit Bildern: [[Kreaturen-Pets]] → „Größe: zwei getrennte Ebenen“.

## Vergleich der drei Spiele

| | Throw Food For Animals | Ziehe einen Dino | Fische für geheime Tiere |
|---|---|---|---|
| Training | Klimmzugstange | Bankdrücken (Dinos als Gewichte) | Klimmzugstange |
| Wurfgegenstand | Futter | Speer/Harpune | Angel + Köder |
| Strecke | Schlucht mit Biomen | Schlucht mit Zonen (Vulkan, Sumpf …) | Fluss, danach Tiefe nach unten |
| Zufall sichtbar | Glücks-Multiplikator im Flug | Multiplikator + Ziehung in Stufen | Glücksrad mit 3 Walzen + Tiefen-Skala |
| Extra | Tier frisst Futter | Silhouette → „Letzte Runde“ | Tiere reiten |

## Bauplan, falls wir so ein Spiel machen

- **Kern zuerst:** Trainings-Station + Wurfplattform + gerade Schlucht mit 3 Biomen + 10 Tiere + Gehege mit 6 Plätzen. Das reicht für eine spielbare Schleife.
- **Zahlen:** Einkommen und Preise wachsen pro Biom etwa x5–x10 (siehe [[Welt-Map]] „Zonen & Fortschritt“); große Zahlen mit K/M/B/T kürzen.
- **Systeme aus [[System-Rezepte]]:** Zufall mit Gewichtung (Tier ziehen), Grundstücke zuweisen, fliegende Zahlen, Sammelbuch, Login-Belohnung.
- **Eigener Twist nötig**, sonst nur Kopie: z. B. Himmels-Thema (vom Inselrand werfen, Tiere fliegen herbei), anderer Wurfgegenstand, Tiere mit Aufgabe im Gehege.
