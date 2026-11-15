# Arbeitsnotizen für Claude – HighlightCutter

Wird vor der Arbeit an diesem Projekt gelesen (Verweis in der Haupt-`CLAUDE.md`). Neue Projektdetails hier eintragen, nicht in der Haupt-`CLAUDE.md`.

- PC-App „Highlight Cutter“ (Python + FFmpeg + OpenCV, lokale Web-Oberfläche): NVIDIA-Aufnahmen (Apex zuerst, `Videos\NVIDIA`, 1440p/120 fps H.264) → Kills erkennen → Highlight-Video mit kurzen Übergängen, 16:9 oder 9:16
- Bauplan + Phasenstand: `highlight-cutter-plan.md` (alle 5 Phasen fertig)
- Vertrag zwischen den Modulen: `SCHNITTSTELLEN.md` (`cutter/erkennung` → `clips` → `schnitt`, `server`+`web`
- nur `cutter/pipeline.py` verbindet sie, Analyse-Cache in `daten/`, bei Erkennungsänderung `ERKENNUNG_VERSION` erhöhen)
- Start `start.bat`, CLI `python -m cutter erkennen|clips|machen|server`, Tests `.venv\Scripts\python.exe -m pytest`
- Manche DVR-Dateien sind am Anfang bis ~1 min kaputt → `schnitt.erster_sauberer_zeitpunkt` (auch die Erkennung startet erst dort – der kaputte Teil enthält veraltete HUD-Reste)
- Bereich „Meine Videos“: Galerie von `Videos\Highlights`, Player mit Kapiteln (stehen per FFMETADATA im MP4), Thumbnail-Vorschläge aus Kill-Momenten (`daten/videos/<Größe>.json`), Löschen nur in den Papierkorb
- Preview: `.claude/launch.json` → `highlight-cutter`
