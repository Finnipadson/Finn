# UI-HUD

Zurück: [[Design-Bibliothek]]

## Bewährte Muster

- **Ecken-Prinzip:** wichtig und dauernd sichtbar (Leben) unten links, Waffe/Munition unten rechts, Karte oder Ziel oben. Die Bildmitte bleibt frei.
- **Weniger ist mehr:** Anzeigen nur einblenden, wenn sie sich ändern oder knapp werden (Ausdauer, Munition), sonst ausblenden oder halbtransparent.
- **Lebensbalken mit Verzögerung:** Der verlorene Teil bleibt kurz hell stehen und läuft dann nach. So sieht man, wie viel ein Treffer gekostet hat.
- **2–3 Akzentfarben,** der Rest neutral. Rot = Gefahr/Leben, Gelb/Gold = Belohnung, Blau = Mana/Schild.
- **Lesbarkeit:** Text immer mit Schatten oder dunkler Platte hinterlegt; Mindestgröße am PC ~14 px, am Handy ~16 px, Touch-Buttons mindestens 44 px.
- **Kompass statt Minimap,** wenn das Spiel Erkunden belohnen soll.
- **Schaden der Richtung nach anzeigen** (roter Rand-Bogen), statt nur den Bildschirm rot zu färben.

## Fallen

- Alles gleich groß und gleich hell → nichts fällt auf.
- Wichtige Infos genau dort, wo am Handy der Daumen liegt.

## Referenzen

### Steal An Egg – HUD mit Ziel (Roblox)

![[stealanegg-hud-ziel.jpg]]

- **Was ist gut:** Das aktuelle Ziel steht groß oben mittig („Das Ei ausbrüten!“). Links mittig nur 2 beschriftete Buttons (Geschäft, Index), rechts eine Spalte mit Symbol-Buttons ohne Text. Unten links die Währungen mit Symbol, unten rechts ein Timer bis zum nächsten Ereignis. Die Bildmitte bleibt komplett frei. Über dem Ei schwebt ein Status-Schild („Ei – Bereit!“).
- **Prinzip zum Übernehmen:** Ziel oben, Navigation an den Seitenrändern (Daumen am Handy), Werte in den unteren Ecken. Statusschilder direkt an Objekten in der Welt statt im HUD.

### Steal An Egg – Fenster-Stil allgemein (Roblox)

Alle Fenster (siehe [[Items-Loot]]) folgen einem Baukasten: Titelleiste in einer **eigenen Farbe pro Fenster-Art** (Grün = Shop/Verkaufen, Lila = Trails/Maschine, Hellblau = Index) mit schrägen Glanzstreifen, dicke weiße Schrift mit dunkler Kontur, rotes „X“ immer oben rechts, dunkler Hintergrund mit Noppen-Muster. Dadurch sieht man sofort, wo man ist, und alles wirkt wie aus einem Guss.

### Rivals – Lobby (Roblox)

![[rivals-lobby.jpg]]

- **Was ist gut:** Die Lobby ist eine begehbare 3D-Szene statt eines Menüs. Links eine kompakte Liste „Tägliche Aufgaben“ mit Fortschrittsbalken und grünen Haken, darunter ein Button „Zu Duellen“. Unten mittig eine Leiste aus 5 Symbol-Buttons (Waffen, Aufgaben, Shop, Pass, Einstellungen) mit **roten Zahlen-Badges**, wo etwas Neues wartet. Darüber ein großer grüner „Spielen“-Button und ein roter Hinweis „Schalte deine neue Waffe jetzt frei!“. Countdown bis zur neuen Map groß auf dem Boden der Welt.
- **Prinzip zum Übernehmen:** Ein Haupt-Button (Spielen) klar hervorgehoben, alles andere klein in einer Leiste. Rote Badges führen den Spieler zu dem, was er als Nächstes tun soll.

### Rivals – Schießen (Roblox)

![[rivals-schiessen.jpg]]

- **Was ist gut:** Sehr reduziertes Shooter-HUD: Lebensbalken unten links (grün, mit Zahl), Waffe mit Name und Munition unten rechts, kleine Tastenhinweise ganz unten. Die Mitte gehört komplett der Waffe und dem Ziel. Die Aufgabenliste bleibt auch im Spiel links sichtbar.
- **Prinzip zum Übernehmen:** Shooter-HUD nach dem Ecken-Prinzip; Ziele (rote Scheiben) haben eine knallige Farbe, die sich klar von der grauen Umgebung abhebt. Gut als Vorlage für [[Nachtschicht]].

### Grow a Garden – HUD (Roblox)

![[growagarden-hud.jpg]]

- **Was ist gut:** Oben mittig 3 große Reiter **Samen · GARTEN · VERKAUFEN** – das sind Teleports zu den 3 wichtigsten Orten, nicht Menüs. Jeder in eigener Farbe (Blau, Holzbraun, Rot). Links 3 Buttons (Geschäft, Handel, Pass) mit Symbol. Unten links Geld („20¢“) und „Freund-Boost +0 %“ mit Plus-Button (lädt zum Einladen ein). Pfeile auf dem Boden zeigen, wohin es geht.
- **Prinzip zum Übernehmen:** Die Kern-Schleife des Spiels (kaufen → anbauen → verkaufen) steht als 3 Teleport-Buttons oben. In [[Himmelsinseln]] ginge das als Hub · Insel · Händler.

### Blox Fruits – RPG-HUD und Statistiken (Roblox)

![[bloxfruits-statistiken.jpg]]

- **Was ist gut:** Links unten ein kompakter Block: 4 gelbe Buttons (Statistiken, Items, Schließen, Shop), darunter Geld grün, Stufe „St. 6“ mit lila XP-Balken, Leben grün, Energie blau – alles mit Zahl im Balken. Rechts unten Kampfstil-Box („KOMBAT“, Mastery-Stufe, Fähigkeiten mit Taste [Z], [X]). Statistiken-Fenster: 5 Werte (Nahkampf, Verteidigung, Schwert, Waffe, Blox Fruit) je in eigener Farbe mit „+“-Button und „Verfügbare Punkte“ – pro Level Punkte frei verteilen.
- **Prinzip zum Übernehmen:** Pro Level Punkte verteilen = einfache, motivierende RPG-Progression. Für [[Himmelsinseln]]: Werte passend zu den Elementen (Feuer, Eis …).

### The Strongest Battlegrounds – Fähigkeiten-Leiste (Roblox)

![[tsb-faehigkeiten-leiste.jpg]]

- **Was ist gut:** Unten mittig, sehr klein und schlicht: ein Balken für die Spezial-Fähigkeit („ERSTAUNLICHES MODE“, füllt sich rot mit Treffern), darunter **4 Kästchen mit Nummer 1–4 und Namen** („Normaler Schlag“, „Aufeinanderfolgende Schläge“, „Schieben“, „Kinnhaken“). Die gerade abklingende Fähigkeit ist rot gefüllt. Lebensbalken klein oben rechts, Kill-Liste darunter. Sonst kein HUD – die Mitte gehört komplett dem Kampf.
- **Prinzip zum Übernehmen:** 4 Fähigkeiten auf Zahlentasten mit Klartext-Namen; Ulti-Balken, der sich durch Treffen füllt. Passt für Kampf in [[Himmelsinseln]] (Handy: 4 runde Buttons rechts unten).

## Bei uns umgesetzt

-
