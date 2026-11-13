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
		- Stimme kostenlos per `edge-tts`. `voice.py` im Video-Ordner erzeugt `voice.mp3` + `words.json` (Zeitstempel je Wort); Untertitel und Animationen richten sich danach → Text ändern, `voice.py` neu ausführen, neu rendern
		- **Menschlicher klingen (Favorit: Version C, 12.11.2026)**: gesprächiger Text (kurze Sätze, direkte Ansprache, „Okay, pass auf.“), Satz für Satz vertont mit unterschiedlich langen Pausen, Tempo pro Satz, Wärme-EQ + leichter Raumklang + Kompression, leiser Musik-Teppich ca. 15 dB unter der Stimme. Hörproben: `remotion/out/Stimmproben/Vorher-Nachher`
		- Beste Stimme bisher: Ava Multilingual (`en-US-AvaMultilingualNeural`), klingt am wenigsten nach KI
		- Gut machbar: Motion Graphics, Erklärvideos, animierte Texte/Formen/Diagramme, Intros, Social-Media-Clips
		- Nicht machbar ohne KI-Video-Dienst (z. B. Runway, kostet extra): realistische Szenen, Zeichentrick-Figuren, Film-Look
		- Vorbild-Stil: TikTok @dannie_bei „AI Levels“ (Hochformat, flache Vektorgrafik, Wort-für-Wort-Untertitel, Sprecher)
	- **Tests**
		- `remotion/src/Erklaervideo Test` → „Bug-Küche EP 01“, 16 s → `remotion/out/Erklaervideo Test.mp4`
		- `remotion/src/Satz des Pythagoras` → Mathe-Erklärvideo, 48 s → `remotion/out/Satz des Pythagoras.mp4`
		- `remotion/src/Koch Szene HD` → Qualitäts-Test (13.11.2026), 18,6 s, 60 fps → `remotion/out/Koch Szene HD.mp4`
		- `remotion/src/Claude Code Erklaerung` → Erklärvideo für Papa (13.11.2026), Querformat 1920×1080, 97 s, 60 fps, 7 Szenen (Was ist es, Chat vs. Claude Code, Arbeitsschleife, Kontrolle, eigene Projekte mit echten Screenshots, was man selbst können muss, Ausblick Ideenliste) → `remotion/out/Claude Code Erklaerung.mp4`
	- **Qualitäts-Stufe (aus Koch Szene HD)**
		- Figur: Licht/Schatten-Verläufe statt flacher Farben, Augen mit Glanzpunkt und Blickrichtung, Blinzeln, Mund synchron zur Stimme (Lautstärke pro Bild), Arme mit Gelenken (inverse Kinematik), Mütze schwingt nach, Atmen
		- Szene: Küche mit Tiefenschärfe (unscharfer Hintergrund), Lampe mit Lichtkegel, Gasflammen, Dampf, Funken, Schattenwurf
		- Kamera: langsame Fahrt, Zoom-Ruck bei wichtigen Momenten, Wackler beim Stempel; Vignette + Filmkorn; 60 fps
		- Ton: `audio.py` erzeugt Stimme (Ava, satzweise), Geräusche (Plopp, Klick, Brutzeln, Stempel, Ding), Musik mit automatischem Leiserwerden unter der Stimme – alles aus **einer** Zeitliste (`events.json`), die auch die Animation steuert
	- **App (Weg 1)**
		- Eigene Windows-App: Eingabefeld, Vorlagen (Mathe/Schule, Tech, Produkt-Intro), Format (Hoch/Quer) wählen, Vorschau, Rendern
		- **Sprecher-Auswahl**: Liste der Stimmen (z. B. Ava, Seraphina, Florian, Conrad …) mit Probehören-Knopf, Standard = Ava; dazu Schalter „Musik an/aus“ und evtl. Tempo-Regler
		- **Szenen-Bibliothek**: wiederverwendbare Bausteine (Titel-Intro, Formel-Aufbau, Diagramm, Vergleich A vs. B, Schritt-für-Schritt-Liste, Zeitstrahl …), Claude setzt sie zusammen statt alles neu zu schreiben → einheitlicher und schneller
		- **Design-Themen**: z. B. „Tafel“, „Dunkel-Neon“, „Papier & Bleistift“, „Küche“, ein Klick wechselt Farben, Schriften, Hintergrund
		- **Drehbuch-Schritt**: vor dem Rendern Sprechertext + Szenenliste anzeigen, Sätze ändern, Szenen löschen, erst dann bauen
		- **Szenen einzeln neu machen**: z. B. „Szene 3 langsamer“, nur diese Szene wird neu erzeugt
		- **Cover-Bild**: automatisches Vorschaubild (Thumbnail) aus dem Video
		- Ruft im Hintergrund Claude Code auf (`claude -p "…"`) → läuft über das Pro-Abo, Stimme + Rendern kostenlos
		- Nur für eigene Nutzung; zum Weitergeben/Verkaufen bräuchte es einen API-Schlüssel (Kosten pro Video)
	- **Noch offen:** Musik, schönere Figuren

## Sonstiges

-
