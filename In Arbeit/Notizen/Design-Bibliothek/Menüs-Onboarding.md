# Menüs-Onboarding

Zurück: [[Design-Bibliothek]]

## Bewährte Muster

- **Hauptmenü:** „Weiterspielen“ ganz oben und hervorgehoben, wenn ein Spielstand existiert. Höchstens 4–5 Einträge; Hintergrund lebendig (Szene, leichte Bewegung).
- **Ins Spiel in unter 30 Sekunden:** keine langen Intros vor dem ersten Steuern.
- **Tutorial durch Tun:** eine Mechanik pro Moment einführen, in einer sicheren Situation, mit einem kurzen Tastenhinweis direkt am Ort statt einer Textwand.
- **Einstellungen:** Lautstärke getrennt (Musik/Effekte), Screenshake an/aus, Tastenbelegung, Textgröße. Änderungen sofort sichtbar.
- **Pause-Menü:** Spiel friert wirklich ein; „Fortsetzen“ liegt auf Esc und ist der oberste Eintrag.
- **Rückmeldung bei jedem Button:** Hover, Klick und Sound. Übergänge 150–300 ms, nie länger.

## Fallen

- Bestätigungsdialog für alles → nur bei Dingen, die sich nicht rückgängig machen lassen.
- Tutorial-Popups, die das Spiel anhalten, obwohl der Spieler es schon kann.

## Referenzen

### Steal An Egg – Verkaufen-Fenster (Roblox)

![[stealanegg-verkaufen.jpg]]

- **Was ist gut:** Links Sortierung (Gewicht/Wert) und „Alle auswählen“, der aktive Sortierknopf ist grün. Unten eine feste Leiste mit dem **Gesamtwert** groß (Geldbündel-Symbol) und dem „Verkaufen“-Button rechts. Der Button bleibt grau, solange nichts ausgewählt ist.
- **Prinzip zum Übernehmen:** Bei Massenaktionen den Gesamtwert live zeigen, bevor man bestätigt; deaktivierte Buttons grau statt versteckt.

### Rivals – Waffe ausprobieren (Roblox)

![[rivals-waffenwahl.jpg]]

- **Was ist gut:** Im Übungsbereich darf man **jede Waffe gratis ausprobieren** („Hier kannst du eine beliebige Waffe umsonst ausprobieren!“). Raster aus Waffenbildern mit Namen, oben ein „Zufällig“-Feld. Der Hintergrund bleibt unscharf sichtbar, das Menü schwebt ohne Rahmen darüber.
- **Prinzip zum Übernehmen:** Vor dem Kauf ausprobieren lassen, das senkt die Hemmschwelle. Für Onboarding: Übungsraum mit Zielen, bevor es ins echte Duell geht.

### Grow a Garden – Wegweiser-Linie (Roblox)

![[growagarden-wegweiser.jpg]]

- **Was ist gut:** Eine leuchtend grüne, gepunktete Linie auf dem Boden führt vom Spieler direkt zum Laden, an dem die nächste Aufgabe wartet. Kein Text, kein Pfeil-Popup – man läuft einfach der Linie nach.
- **Prinzip zum Übernehmen:** Tutorial-Führung über eine Linie in der Welt. Einfach und funktioniert auch für Kinder, die nicht lesen. Ideal für die ersten Minuten in [[Himmelsinseln]].

### Grow a Garden – Verkaufsstand (Roblox)

![[growagarden-verkaufsstand.jpg]]

- **Was ist gut:** Läden sind echte Marktstände mit gestreiften Markisen (Blau = Samen kaufen, Rot = verkaufen) und Holzschildern, beide nebeneinander am Spawn. Beim Händler erscheinen Dialog-Optionen als nummerierte Sätze („#1 Ich möchte mein Inventar verkaufen“).
- **Prinzip zum Übernehmen:** Orte farblich kodieren, passend zu den HUD-Reitern (Rot = Verkaufen überall). Die wichtigsten Händler direkt nebeneinander am Startpunkt.

### +1 Speed Keyboard Escape – Ladebildschirm (Roblox)

![[keyboard-ladebildschirm.jpg]]

- **Was ist gut:** Großes Logo mit Figur und „+1“-Zahlen, ein Tipp („CHECK THE GIFT CHEST!“), dicker Ladebalken mit Prozent und unten der Name der Welt („CANDY & CHOCOLATE“). Der Hintergrund zeigt das Welt-Thema.
- **Prinzip zum Übernehmen:** Ladezeit für einen Tipp und den Namen des Gebiets nutzen.

### Blox Fruits – Seite wählen (Roblox)

![[bloxfruits-seite-waehlen.jpg]]

- **Was ist gut:** Die allererste Entscheidung: **Piraten vs. Marines**, zwei große Karten mit Figur, Farbe (Rot gegen Blau), Name und 2–3 Sätzen, was die Seite ausmacht. Im Hintergrund schon die Stadt, in der man startet. Danach geht es direkt ins Spiel, ohne Tutorial-Text.
- **Prinzip zum Übernehmen:** Eine einzige, spannende Wahl am Anfang gibt Identität. Für [[Himmelsinseln]] z. B. Start-Element oder Start-Begleiter wählen.

### Fisch – Tutorial mit Zielkreis (Roblox)

![[fisch-tutorial-zielkreis.jpg]]

- **Was ist gut:** Oben mittig ein kleiner Auftrag mit Schritt-Zähler („Fange 3 Fische – Schritt 1/9“). Das Ziel ist ein **großer grün gestreifter Kreis auf dem Wasser mit Lichtsäule** und Pfeil darüber, unten der Tastenhinweis „HOLD“. Nach jedem Schritt eine kurze Meldung, was jetzt freigeschaltet ist („Du kannst jetzt die Training Rod in Moosewood kaufen!“).
- **Prinzip zum Übernehmen:** Tutorial als Kette kleiner Aufträge mit Zähler; Ziel als leuchtende Markierung in der Welt statt Text. Passt zur Wegweiser-Linie von Grow a Garden.

## Bei uns umgesetzt

-
