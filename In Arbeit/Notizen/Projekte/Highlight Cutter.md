---
typ: app
status: fertig (v1, Apex)
technik: Python + FFmpeg + OpenCV, lokale Web-Oberfläche
erstellt: 2026-11-12
---

PC-App, in die man NVIDIA-Bildschirmaufnahmen (ShadowPlay/NVIDIA App) lädt und die daraus automatisch die Highlights wie Kills herausschneidet. *Name ist nur ein Arbeitstitel.*

- Datei/Ordner: `In Arbeit/HighlightCutter/`
- Bauplan: `HighlightCutter/highlight-cutter-plan.md` (alle 5 Phasen fertig, 2026-11-14; bekannte Grenzen dort)
- Start: `HighlightCutter/start.bat` (Desktop-Icon per `verknuepfung.ps1`), fertige Videos landen in `Videos\Highlights`
- Verwandt: [[PC Aufräumer]] erkennt Spielaufnahmen schon beim Scan

## Ziele

- Aufnahme(n) per Drag & Drop oder Ordnerauswahl laden (Standard: `Videos\NVIDIA`)
- Highlights automatisch finden: Kills, Mehrfach-Kills, Siege/Runden-Ende …
- Gefundene Stellen als Liste mit Vorschau anzeigen, einzeln an- und abwählen, Start/Ende anpassen
- Export: einzelne Clips und/oder ein zusammengeschnittenes Highlight-Video

## Wie Highlights erkannt werden könnten

- **Kill-Feed/HUD erkennen**: Bildausschnitt (z. B. Kill-Feed oben rechts) pro Spiel auswerten, per Bildvergleich (Template-Matching) oder Texterkennung (OCR). Am genauesten, muss aber pro Spiel eingerichtet werden.
- **Ton auswerten**: Kill-Sounds, Schüsse und laute Stellen erkennen. Funktioniert spielübergreifend, ist aber ungenauer.
- **Kombination**: Ton als Vorfilter, Bild als Bestätigung.
- Schneiden mit **FFmpeg** (schnell und ohne Qualitätsverlust per Stream-Copy, genau auf den Frame nur mit Neu-Kodierung).

## Entscheidungen (2026-11-14)

- [x] Spiel: zuerst **Apex Legends**, später weitere Spiele (Erkennung pro Spiel als austauschbares „Spielprofil“)
- [x] Clip-Länge: Standard ca. 10 s um den Kill, die App darf aber selbst entscheiden: Kampfbeginn (erste Schüsse/Treffer) bis kurz nach dem letzten Kill; nahe Kills werden zu einem Clip zusammengefasst
- [x] Ergebnis: Highlights aus den Aufnahmen schneiden und zu **einem Video** zusammenfügen
- [x] Technik: **Python + FFmpeg + OpenCV** (Bild- und Tonauswertung geht dort am besten), Bedienung als lokale Web-Oberfläche
- [x] Mehrwert gegenüber NVIDIA: Aufnahmen von 2–30 min, in denen die Hälfte der Zeit nichts passiert, auf die Action eindampfen

## Ist-Stand der Aufnahmen (geprüft 2026-11-14)

- Ordner `Videos\NVIDIA\Apex Legends\`, Dateien `… .DVR.mp4` (Instant Replay)
- 2560×1440, 120 fps, H.264, eine AAC-Stereospur (Spiel + evtl. Mikro gemischt)
- ca. 85 Mbit/s → 2,5 min ≈ 1,6 GB
- Anfang der DVR-Dateien hat kaputte Frames (normal bei Instant Replay), Schnitt muss das abfangen
- FFmpeg 8.1 und Python 3.14 sind installiert

- [x] Knocks: nur wenn danach ein Kill kommt
- [x] Eigene Tode / Champion: optional (Schalter in der App)
- [x] Montage: keine Musik, kurze Übergänge
- [x] Format: 16:9 oder 9:16, in der App wählbar
- [x] Mikro: eigenes nicht, aber Stimmen von Kollegen möglich → Ton nur als Hilfe, Bild entscheidet

## Offene Fragen

- keine

## Offene Punkte / Ideen

- [x] **Übersicht „Meine Videos“ in der App** *(erledigt 2026-11-14: Bereich „Videos“ mit Galerie, Speichern unter, Löschen in den Papierkorb)*
- [x] **Clips direkt in der App anschauen** *(erledigt 2026-11-14: Player mit Kapiteln je Clip, ←/→, Vollbild F; Kapitel stehen im MP4)*
- [ ] **Clip-Bewertung / Best-of**: jeder Clip bekommt Punkte (Anzahl Kills, Squad-Wipe, Champion, Schaden) → Option „nur die besten X Minuten“ *(Idee 2026-11-14)*
- [ ] **Kill-Einblendung**: kurzer Text wie „3 KILLS“ oder „SQUAD WIPE“ am Anfang des Clips *(Idee 2026-11-14)*
- [ ] **Kampfbeginn auch übers Bild**: Trefferanzeige/Schadenszahlen zusätzlich zum Ton auswerten, damit lange Gefechte mit Pausen > 10 s komplett im Clip landen *(Idee 2026-11-14)*
- [x] **Thumbnail vorschlagen** *(erledigt 2026-11-14: 4 Vorschläge aus Kill-Momenten oder aktuelles Bild → `<Video> - Thumbnail.jpg`)*
- [ ] **Weitere Spiele**: neue Spielprofile (z. B. Valorant, Fortnite, CS2); welche Spiele, ist noch offen *(Idee 2026-11-14)*
- [ ] **Echte .exe zum Weitergeben**: App per PyInstaller als Windows-Programm packen, FFmpeg gleich mit dabei → Kollegen müssen nichts installieren (kein Python, kein FFmpeg). Nachteile: Datei ca. 200–300 MB, Windows warnt beim ersten Start bei unsignierter .exe *(Idee 2026-11-14)*
- [ ] **Eigenes App-Fenster statt Edge**: Oberfläche per `pywebview` (nutzt das in Windows eingebaute WebView2) in einem eigenen Fenster öffnen → kein Konsolenfenster, eigenes Icon in der Taskleiste, wirkt wie ein normales Windows-Programm. Passt gut zusammen mit der .exe *(Idee 2026-11-14)*

## Notizen

- 2026-11-14: Oberfläche neu im Editor-Layout (Vorbild: Dribbble-Shot „ClipPilot“ von Potara Studio): Icon-Leiste, Clip-Raster links, große Vorschau mit Scrub-Leiste, Clip-Details rechts (Feinschnitt, Momente), Montage-Zeitleiste unten (Clip-Enden dort ziehbar). Farben neutral schwarz + Blau, Icon blau. Entwürfe in `HighlightCutter/design-entwurf/`.
- 2026-11-14: Fix: kaputter DVR-Anfang wird bei der Erkennung übersprungen (veraltete HUD-Reste verschluckten echte Kills); FFmpeg-Wachhund (60 s ohne Bild → Neustart).
