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

### Ziehe einen Dino – Wurf und Dino-Ziehung (Roblox)

![[dino-wurf-zonen.jpg]]

- **Flug:** Die Kamera fliegt mit dem Speer (rosa Leuchtspur) durch eine Schlucht. Links eine **senkrechte Zonen-Leiste** (Vulkan · Tar · Sumpf · Mud) – die aktuelle Zone leuchtet. Oben groß der Glücks-Multiplikator „36.08X“, die Zone „SWAMP I“ und die Weite „369 m“, die live mitzählen.

![[dino-letzte-runde.jpg]]
![[dino-legendaer.jpg]]

- **Ziehung:** Erst ein dunkler Bildschirm mit **schwarzer Silhouette** und „Chancen 1 in 3“, ein Wort zieht sich Buchstabe für Buchstabe zusammen, „Letzte Runde…“ in Rot. Dann die Enthüllung: Konfetti, Strahlen, Titel je nach Seltenheit („Toll! 1 in 10“, „Glück! 1 in 32“, „Super-Glück! 1 in 140“, „VERRÜCKTES GLÜCK! 1 in 430“), Stempel „★ GROSS ★“, darunter Seltenheit, Name, Einkommen „$60K/s“ und Schild „NEU!“.
- **Prinzip zum Übernehmen:** Der Weg (Flug durch Zonen) entscheidet sichtbar über die Chance. Die Ziehung baut Spannung in Stufen auf (Silhouette → „Letzte Runde“ → Enthüllung). Die **Überschrift wächst mit der Seltenheit** – man spürt sofort, wie gut der Zug war.

### Fische für geheime Tiere – Geheimes Cast, Tiefe, Enthüllung (Roblox)

![[geheimtiere-slot-cast.jpg]]

- **Geheimes Cast:** Ein **Glücksrad mit 3 Walzen** – „Seltenheit“ (Rare, Legendär, Mythisch), „Größe“ (Big, Huge, Unendlich) und „Mutation“ (Regenbogen, Ruby, Allmächtig). „Klicke, um zu stoppen!“, Überschrift „Was du drehst, ist das, was du fängst!“. Goldener Rahmen um den ganzen Bildschirm, solange es läuft.

![[geheimtiere-tiefe.jpg]]

- **Tiefe:** Nach dem Wurf sinkt der Köder ins dunkle Wasser, rechts eine **Tiefen-Skala**, auf der die Seltenheiten von oben nach unten stehen (Gewöhnlich → Uncommon → Rare → Epic → Legendär → Mythisch → Geheimnis → Divine), Meter-Anzeige „17 m“, oben die aktuelle Chance „1 in 2“. Je tiefer, desto seltener – man sieht live, wie die Chancen besser werden.

![[geheimtiere-enthuellung.jpg]]

- **Enthüllung:** Das Tier taucht aus dem Wasser auf, oben die Chance („1 in 3,242“), unten der Name als **Lückenwort, das sich Buchstabe für Buchstabe füllt** („_ _ _ A _“) – wie bei der Dino-Ziehung.
- **Prinzip zum Übernehmen:** Zufall sichtbar machen (Walzen, Tiefe) statt nur auszuwürfeln – der Spieler hat das Gefühl, mitzuentscheiden. Name als Rätsel enthüllen hält die Spannung ein paar Sekunden länger.

### The Strongest Battlegrounds – Trefferwucht im Nahkampf (Roblox) → für Bosse in [[Himmelsinseln]]

![[tsb-treffer-funken.jpg]]
![[tsb-hochschlag.jpg]]

- **Treffer-Funken:** Jeder Schlag erzeugt einen **weißen Stern aus spitzen Strahlen** genau am Trefferpunkt, dazu kleine blaue Funken. Weiß auf grauem Boden ist immer sichtbar.
- **Hochschlag:** Getroffene fliegen **als Ragdoll** (schlaffe Puppe) durch die Luft und überschlagen sich. Fähigkeiten haben eine farbige Aura (hier blaue Blitze) um den Angreifer.

![[tsb-ablauf-schwerer-treffer.jpg]]

- **Ablauf eines schweren Treffers (3 s, 4 Bilder pro Sekunde):** Gegner lädt mit blauer Aura auf → packt den Spieler und reißt ihn hoch → schmettert ihn in den Boden → **der Boden zerbricht in große Betonplatten**, die hochklappen und herumfliegen, Staubwolke → **roter Bildschirmrand** beim Getroffenen → Platten bleiben als Trümmer liegen.

![[tsb-krater.jpg]]
![[tsb-krater-gras.jpg]]

- **Krater bleiben liegen:** Nach dem Aufprall bleibt ein **Ring aus hochgeklappten Bodenplatten** zurück (auf Gras braune Erdplatten, auf Beton graue), dazu kleine Bruchstücke ringsum. Die Arena zeigt so den Kampfverlauf.
- **Prinzip zum Übernehmen:** Wucht = Licht am Trefferpunkt + Ragdoll-Flug + Boden reagiert. Die Bodenplatten sind einfache Blöcke in der Farbe des Untergrunds – billig zu bauen, sehr wirkungsvoll. Für den Lavadrachen: Stampfen und Meteoriten lassen Lavaboden-Platten hochklappen; roter Rand beim Spieler, wenn er getroffen wird.

## Bei uns umgesetzt

-
