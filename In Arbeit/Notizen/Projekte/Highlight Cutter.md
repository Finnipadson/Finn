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

## Notizen

-
