Ideen-Inbox für **neue** Sachen: ein neues Spiel, eine neue App, irgendwas, das noch kein eigenes Projekt hat. Im Zweifel einfach hier rein.

> **Idee zu einem bestehenden Projekt?** → in dessen Projektnotiz unter „Offene Punkte“, z. B. [[Burgwacht]] oder [[Nachtschicht]].
> **Wird eine Idee hier ernst?** → eigene Projektnotiz mit der Vorlage *Projekt* in `Notizen/Projekte` anlegen und hier abhaken.

## Spiele

- [ ] **Absurd riesige Fleißaufgabe** (15.11.2026)
	- Idee: Spiel, in dem man eine fast unmögliche Riesenaufgabe Stück für Stück erledigt; trotz der Größe befriedigend, weil man ständig kleine Fortschritte sieht
	- Vorbilder (nur als Genre, nicht nachbauen): „Drink The Ocean“ (TikTok @malakyemong), Mond vom Staub freifegen, alle Münzen aus einem Riesenpool sammeln, Nadel im Heuhaufen
	- Machbar als Single-File-Browserspiel (wie die anderen Spiele)
	- Was es gut macht:
		- Riesige Zahl, die langsam schrumpft („noch 1.332.000.000 km³“), Prozentanzeige
		- Upgrades in Wellen (z. B. Strohhalm → Schlauch → Pumpe → Riesenmaschine)
		- Zufällige Funde zwischendurch (Schiffswrack, Schatz, seltenes Tier …)
		- Speicherstand, damit man über Tage weiterspielt
	- **Grafik-Test** (15.11.2026): `In Arbeit/Grafiktest/strand-test.html` (Three.js, nur Code, keine Downloads) – Strand mit Palmen, Steg mit Pegel, Leuchtturm, Wasser mit Schaumrand und Lichtnetz, Wasserstand sinkt beim Schöpfen; Eimer, Riesen-Eimer, Saugpumpe mit Strudel; Funde (Riff, Truhe, Anker, Wrack) tauchen auf. Für mehr Details evtl. CC0-Modelle (Kenney, Quaternius) oder Godot
	- **Godot-Version** (15.11.2026): `In Arbeit/Grafiktest/godot-strand/` (Godot 4.7, Start: `start.bat`, Editor: `start.bat --editor`) – gleiche Szene, schöneres Licht/Wasser, dazu Kenney-Modelle (Pirate Kit + Nature Kit, CC0): Palmen, Felsen, Schiffswrack, Truhen, Kanonen, Bude, Piratenschiff und Ruderboot, die mit dem Wasser absinken. Deutlich näher am Vorbild als die Browser-Version → Favorit für das echte Spiel
	- **Variante „Fenster putzen“** (15.11.2026, Favorit): jedes Fenster des höchsten Turms der Welt putzen (Vorbild Burj Khalifa ≈ 24.000 Fenster). Eigener, erfundener Turm statt des echten (Name/Form des Burj Khalifa sind geschützt) – Fortschritt „Fenster X von Y“, man kommt immer höher, Aussicht als Belohnung; Werkzeuge Schwamm → Abzieher → Gondel → Putzroboter → Drohnen; Störungen (Tauben, Sandsturm, Wind); hinter den Fenstern passieren lustige Dinge
		- Turm-Test: `In Arbeit/Grafiktest/godot-turm/` (Godot, Turm komplett aus Code: Grundriss pro Stockwerk, Fenster + Dreck per Shader, Wüstenstadt drumherum, Gondel). 3 Varianten: 1 Wüstennadel (Y-Form, 895 m, ~25.600 Fenster), 2 Drehturm (gedreht, gold, 610 m, ~16.600), 3 Stapel-Riese (gestapelte Blöcke, 1.282 m, ~50.500). Vergleichsbild `turm-varianten.png`
	- Eigene Themen-Ideen: Wüste Sandkorn für Sandkorn sieben (irgendwo liegt ein Ring), alle Blätter eines Waldes rechen (Wind weht neue nach), den Himmel von Wolken freiwischen, einen Berg löffelweise abtragen

## Tools & Apps

- [x] **Text → animiertes Video** (12.11.2026) ✅ Ansatz getestet, Qualität passt → jetzt eigenes Projekt: [[Erklärvideo-Studio]]
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
- [ ] **Eigene Design-Sammlung** (14.11.2026)
	- Idee: App als persönliche Bibliothek für Website-Designs, App-Vorlagen (Templates), UI-Komponenten usw. – alles an einem Ort, durchsuchbar, mit Vorschau
	- Startmaterial ist schon da: `Desktop\Claude\Design-Referenzen` (5 Website-Templates, z. B. AUREAS, Dashdark X, Spacekit) und `Desktop\Claude\Website Components` (Accordion, Footer, Countdown, Suchfunktion, Bewertungen …)
	- Mögliche Funktionen (Vorschläge):
		- Kacheln mit Vorschaubild, Filter nach Art (Website, App, Komponente) und Stil (dunkel, hell, verspielt …), Tags + Suche
		- Live-Vorschau direkt in der App, auch in Handy-Breite
		- Neues hinzufügen per Ordner, Datei oder Screenshot; Vorschaubild automatisch erzeugen
		- „Für Projekt verwenden“: Vorlage bzw. Komponente in ein neues Projekt kopieren oder Claude als Vorlage geben
		- Farben und Schriften aus einem Design herauslesen (Farbpalette)
- [ ] **Datei-Austausch mit Kollegen** (14.11.2026)
	- Idee: Große Dateien (Videos, Clips, Ordner, Spiele-Mods …) schnell an Kollegen schicken, weil Discord nur kleine Dateien erlaubt
	- **Entschieden (14.11.2026): Direkt von PC zu PC (WebRTC)**
		- Webseite öffnen, Datei reinziehen, Link an den Kollegen schicken, die Datei geht direkt von Rechner zu Rechner
		- Keine Größengrenze, kein Speicherplatz auf einem Server nötig, kostenlos
		- Haken: Beide müssen gleichzeitig online sein (Seite offen lassen, bis die Übertragung fertig ist)
	- Verworfen: eigener Server auf dem PC (PC muss immer an sein), Cloud-Speicher (kostet ab einer gewissen Menge)
	- Mögliche Funktionen (Vorschläge):
		- Drag & Drop, ganze Ordner (automatisch als ZIP), Fortschrittsbalken mit Geschwindigkeit
		- Link mit Ablaufzeit und optionalem Passwort, Verschlüsselung
		- „Freunde“-Liste: Kollegen direkt auswählen statt Link kopieren
		- Link direkt in Discord teilen (z. B. per Bot oder Webhook)
		- Abgebrochene Übertragungen fortsetzen

## Sonstiges

-
