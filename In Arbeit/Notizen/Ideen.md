Ideen-Inbox für **neue** Sachen: ein neues Spiel, eine neue App, irgendwas, das noch kein eigenes Projekt hat. Im Zweifel einfach hier rein.

> **Idee zu einem bestehenden Projekt?** → in dessen Projektnotiz unter „Offene Punkte“, z. B. [[Burgwacht]] oder [[Nachtschicht]].
> **Wird eine Idee hier ernst?** → eigene Projektnotiz mit der Vorlage *Projekt* in `Notizen/Projekte` anlegen und hier abhaken.

## Spiele

-

## Tools & Apps

- [ ] **Text → animiertes Video** (12.11.2026) ✅ Ansatz getestet, Qualität passt
	- Idee: Thema/Beschreibung eingeben → fertiges animiertes Erklärvideo (MP4)
	- **So funktioniert's**
		- Claude schreibt Sprechertext + Remotion-Code (React), Remotion rendert das MP4 (`Desktop\Claude\remotion`)
		- Stimme kostenlos per `edge-tts` (de-DE-ConradNeural). `voice.py` im Video-Ordner erzeugt `voice.mp3` + `words.json` (Zeitstempel je Wort); Untertitel und Animationen richten sich danach → Text ändern, `voice.py` neu ausführen, neu rendern
		- Gut machbar: Motion Graphics, Erklärvideos, animierte Texte/Formen/Diagramme, Intros, Social-Media-Clips
		- Nicht machbar ohne KI-Video-Dienst (z. B. Runway, kostet extra): realistische Szenen, Zeichentrick-Figuren, Film-Look
		- Vorbild-Stil: TikTok @dannie_bei „AI Levels“ (Hochformat, flache Vektorgrafik, Wort-für-Wort-Untertitel, Sprecher)
	- **Tests**
		- `remotion/src/Erklaervideo Test` → „Bug-Küche EP 01“, 16 s → `remotion/out/Erklaervideo Test.mp4`
		- `remotion/src/Satz des Pythagoras` → Mathe-Erklärvideo, 48 s → `remotion/out/Satz des Pythagoras.mp4`
	- **App (Weg 1)**
		- Eigene Windows-App: Eingabefeld, Vorlagen (Mathe/Schule, Tech, Produkt-Intro), Stimme + Format (Hoch/Quer) wählen, Vorschau, Rendern
		- Ruft im Hintergrund Claude Code auf (`claude -p "…"`) → läuft über das Pro-Abo, Stimme + Rendern kostenlos
		- Nur für eigene Nutzung; zum Weitergeben/Verkaufen bräuchte es einen API-Schlüssel (Kosten pro Video)
	- **Noch offen:** Musik, schönere Figuren

## Sonstiges

-
