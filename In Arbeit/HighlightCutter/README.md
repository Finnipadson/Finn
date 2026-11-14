# Highlight Cutter

Schneidet aus NVIDIA-Aufnahmen (zuerst Apex Legends) automatisch die Kills heraus und fügt sie zu einem Highlight-Video zusammen.

## Start

- **Doppelklick auf `start.bat`**: Beim ersten Mal wird die Python-Umgebung `.venv` angelegt und `requirements.txt` installiert. Danach startet der Server und die App öffnet sich in Edge als eigenes Fenster (`http://127.0.0.1:4720`). Konsolenfenster schließen = App beenden.
- **Desktop-Verknüpfung**: `powershell -ExecutionPolicy Bypass -File verknuepfung.ps1` (optional `-Ziel <Ordner>`).
- Voraussetzungen: Windows, Python 3.12+, FFmpeg im PATH (`winget install Gyan.FFmpeg`).
- Ohne Browser: `.venv\Scripts\python.exe -m cutter server --kein-browser [--port 4720]`. Wird die App doppelt gestartet, öffnet der zweite Start nur das Fenster.

## Bedienung

1. **Aufnahmen**: Liste aus `Videos\NVIDIA`, nach Spiel gruppiert. Runden anklicken (mehrere gehen, im Video kommt die älteste zuerst). Eigene Videos per *Datei auswählen …* oder per Drag & Drop (die App sucht die Datei anhand von Name und Größe in Videos, Desktop, Downloads).
2. **Highlights finden**: Fortschrittsbalken, jederzeit abbrechbar. Schon analysierte Aufnahmen kommen aus dem Zwischenspeicher.
3. **Highlights bearbeiten**: Vorschaubild anklicken = Clip abspielen (stoppt am Ende). Schalter = Clip rein/raus. Start/Ende mit ±0,5 s oder in der Zeitleiste ziehen (Griffe = Start/Ende, Balken = ganzen Clip verschieben, Spur anklicken = dorthin springen). Weiße Striche sind Kills, orange Knocks. Reihenfolge per ▲▼ oder am Griff links ziehen. *Alle nacheinander* spielt die Montage ab. Leertaste = Play/Pause.
4. **Einstellungen** (rechts, werden gemerkt): Format 16:9 / 9:16, eigene Tode, Champion-Sieg, Übergang, Feinschliff. Tode/Champion/Feinschliff wirken erst nach *Neu berechnen*.
5. **Video erstellen**: fertiges Video landet in `Videos\Highlights`, danach *Im Ordner zeigen* oder abspielen.

## Aufbau

| Teil | Inhalt |
|---|---|
| `cutter/erkennung/` | Phase 1: Kills/Knocks/Tod/Champion im Bild erkennen |
| `cutter/clips/` | Phase 2: aus Events Clips festlegen |
| `cutter/schnitt/` | Phase 3: Clips schneiden + zusammenfügen (FFmpeg/NVENC) |
| `cutter/pipeline.py` | verbindet die Phasen, Zwischenspeicher in `daten/` |
| `cutter/server/` | Phase 4: Flask-Server (nur 127.0.0.1), Aufträge in Threads, Platzhalter `mock.py` |
| `web/` | Oberfläche (Vanilla JS, keine Build-Schritte) |
| `SCHNITTSTELLEN.md` | verbindlicher Vertrag inkl. HTTP-API |

**Demo-Modus:** Solange Phase 1–3 noch `NotImplementedError` werfen (oder mit `HC_MOCK=1`), liefert `cutter/server/mock.py` erfundene Clips mit echten Zeiten und ein 4-s-Mini-Video in `daten/mock-export/`. Oben rechts steht dann „DEMO-DATEN“. `HC_MOCK_FEHLER=export` erzwingt einen Exportfehler zum Testen.

Weitere Umgebungsvariablen: `HC_DATADIR` (Daten-/Einstellungsordner), `HC_VIDEOS` (anderer Aufnahmeordner, z. B. für Tests), `HC_MOCK_PAUSE` (Tempo des Demo-Fortschritts).

## Prüfen

```
.venv\Scripts\python.exe -m pytest tests -q
```
