Ideen-Inbox für **neue** Sachen: ein neues Spiel, eine neue App, irgendwas, das noch kein eigenes Projekt hat. Im Zweifel einfach hier rein.

> **Idee zu einem bestehenden Projekt?** → in dessen Projektnotiz unter „Offene Punkte“, z. B. [[Burgwacht]] oder [[Nachtschicht]].
> **Wird eine Idee hier ernst?** → eigene Projektnotiz mit der Vorlage *Projekt* in `Notizen/Projekte` anlegen und hier abhaken.

## Spiele

-

## Tools & Apps

- [ ] **Text → animiertes Video** (12.11.2026): detaillierte Beschreibung eingeben, daraus entsteht automatisch ein animiertes Video
	- Weg: Claude schreibt aus der Beschreibung Remotion-Code (React), Remotion rendert ein MP4. Remotion ist schon eingerichtet (`Desktop\Claude\remotion`)
	- Gut machbar: Motion Graphics, Erklärvideos, animierte Texte/Formen/Icons/Diagramme, Intros, Social-Media-Clips
	- Nicht machbar ohne KI-Video-Dienst (kostet extra): realistische Szenen, Zeichentrick-Figuren, Film-Look
	- Variante A (mit Pro-Abo): als Workflow/Skill in Claude Code, kein Extra-Geld
	- Variante B (eigene App): braucht API-Schlüssel mit Abrechnung, zahlt pro Nutzung
	- Offen: Sprecherstimme, Musik, Bilder einbinden?
	- Vorbild-Stil: TikTok @dannie_bei „AI Levels“ (Hochformat, flache 2D-Vektorgrafik, Küchen-Metapher mit Köchen als KI-Modelle, Preisschilder/Bestellzettel, Wort-für-Wort-Untertitel, Sprecher). Machbar mit Remotion + SVG-Figuren; dazu braucht es Sprecherstimme (eigene oder KI-Stimme), Untertitel per Whisper (lokal, kostenlos) und Musik
	- Erster Test (12.11.2026): `remotion/src/Erklaervideo Test` → „Bug-Küche EP 01“, 16 s, 1080×1920, mit Stimme. Video: `remotion/out/Erklaervideo Test.mp4`
	- Stimme: kostenlos per `edge-tts` (Microsoft-Neural-Stimme de-DE-ConradNeural), Skript `voice.py` im Video-Ordner erzeugt `voice.mp3` + `words.json` (Zeitstempel je Wort). Untertitel und alle Animationen richten sich automatisch nach den Wörtern → Text ändern, `voice.py` neu ausführen, neu rendern
	- Zweites Video (12.11.2026): `remotion/src/Satz des Pythagoras` → Mathe-Erklärvideo, 48 s, mit Stimme. Dreieck zeichnet sich, Quadrate wachsen auf den Seiten, Beispiel 3-4-5 mit Kästchen-Raster, Formel + Rechenschritte synchron zur Stimme. Video: `remotion/out/Satz des Pythagoras.mp4`
	- `voice.py` ordnet Wörter jetzt zeichengenau zu (die Stimme fasst z. B. „3 mal 3“ zu einem Block zusammen)
	- Noch offen: Musik, schönere Figuren

## Sonstiges

-
