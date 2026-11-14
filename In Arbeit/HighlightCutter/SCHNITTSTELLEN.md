# Schnittstellen – Highlight Cutter

Verbindlicher Vertrag zwischen den Teilen. Gemeinsame Dateien (`cutter/schema.py`, `cutter/medien.py`,
`cutter/pipeline.py`, `cutter/__main__.py`, diese Datei) ändert **nur der Koordinator**. Braucht ein Teil
dort etwas Neues: im Abschlussbericht beschreiben, nicht selbst ändern.

## Umgebung

- Python: `.venv\Scripts\python.exe` (numpy, opencv-python-headless, scipy, flask, pytest sind installiert). Neue Pakete nur, wenn unvermeidbar – dann in `requirements.txt` + Bericht.
- FFmpeg/ffprobe 8.1 im PATH (`cutter.medien.FFMPEG`/`FFPROBE`), GPU RTX 5070 Ti → `h264_nvenc`, `-hwaccel cuda` verfügbar.
- Aufnahmen: `%USERPROFILE%\Videos\NVIDIA\Apex Legends\*.mp4` (77 Dateien, 2560×1440, 120 fps, H.264, 1× AAC stereo, ~85 Mbit/s; DVR-Dateien `*.DVR.mp4` haben am Anfang kaputte Frames). **Nur lesen, nie verändern, verschieben oder löschen.**
- Arbeitsdateien jedes Teils nach `arbeit/<bereich>/` (gitignored). Tests in `tests/test_<bereich>.py` (pytest, schnell, < 60 s; Tests mit echten Aufnahmen per `pytest.mark.skipif`, wenn Datei fehlt).
- Kein `git commit`, kein Push – macht der Koordinator.

## Datenformate (`cutter/schema.py`)

- `Event(t, typ, sicher, info)` – typ ∈ `kill | knock | tod | champion`
- `Analyse(video, dauer, profil, events)` – Ergebnis Phase 1 für ein Video
- `Clip(video, start, ende, grund, events, aktiv)` – Ergebnis Phase 2
- `Einstellungen(format, eigene_tode, champion, uebergang, fallback_vorlauf, nachlauf, max_vorlauf, zusammenfassen, knock_bis_kill, hoehe, fps)`
- Fortschritt: `fortschritt(anteil 0..1, text)`, Abbruch: `abbrechen.is_set()` → `schema.pruefe_abbruch()` wirft `Abgebrochen`

## Phase 1 – `cutter/erkennung/` (Agent 1)

`erkenne(video, profil="apex", fortschritt, abbrechen, ab=0.0) -> Analyse`

- `ab`: Frames davor nicht auswerten. `pipeline` übergibt `schnitt.erster_sauberer_zeitpunkt(video)` – kaputte DVR-Anfänge enthalten veraltete HUD-Reste (z. B. den Kill-Stand vom Ende), die sonst den Zähler falsch vorbelegen.

- Spielprofile in `cutter/erkennung/profile/<spiel>.py`, Apex zuerst. HUD-Bereiche **relativ** zur Bildgröße angeben (andere Auflösungen).
- Nur kleine Bildausschnitte auswerten, nicht ganze 1440p-Frames → Ziel: 30 min Aufnahme in < 3 min analysiert.
- Events: `kill` (eigener Kill), `knock` (eigener Knock), `tod` (eigener Tod / niedergeschlagen und ausgeschieden), `champion` (Sieg). Zeitpunkt = Moment, in dem die Meldung erscheint.
- Pro Kill **ein** Event (keine Doppelten, wenn eine Meldung mehrere Frames sichtbar ist).

## Phase 2 – `cutter/clips/` (Agent 2)

`plane_clips(analyse, einstellungen, fortschritt, abbrechen) -> list[Clip]`

- Kill → immer Highlight.
- Knock → nur, wenn innerhalb `knock_bis_kill` s ein Kill folgt (dann gehören beide in denselben Clip). Knock ohne Kill wird verworfen.
- `tod` nur wenn `eigene_tode`, `champion` nur wenn `champion` = True.
- Events mit Abstand ≤ `zusammenfassen` s → ein Clip.
- Clip-Start = Kampfbeginn: rückwärts ab erstem Event nach Schüssen/Treffern suchen (Ton; in der Aufnahme können **Stimmen von Kollegen** sein → robust gegen Sprache), höchstens `max_vorlauf` s. Nichts gefunden → `fallback_vorlauf` s vorher. Ende = letztes Event + `nachlauf`.
- Clips innerhalb [0, dauer], keine Überlappung (überlappende zusammenlegen), nach Start sortiert.
- `grund` deutsch und kurz: „Kill“, „Doppel-Kill“, „3 Kills“, „Knock → Kill“, „Champion“, „Eigener Tod“.

## Phase 3 – `cutter/schnitt/` (Agent 3)

`rendere(clips, ziel, einstellungen, fortschritt, abbrechen) -> Path`, `vorschaubild(video, t, breite=320) -> bytes` (JPEG)

- Nur `aktiv`-Clips, in Listenreihenfolge, können aus verschiedenen Videos stammen.
- Überblendung `uebergang` s (Bild + Ton), 0 = harter Schnitt. Keine Musik.
- 16:9: Höhe `hoehe` (1080), 9:16: 1080×1920 (Mitte ausschneiden, dahinter unscharfer Hintergrund – oder sinnvollere Lösung, im Bericht begründen).
- `fps` Ausgabe (60), H.264 per `h264_nvenc` (Fallback `libx264`), AAC. Gute Qualität (etwa CQ 19–21).
- Kaputte Frames am Dateianfang dürfen nicht im Ergebnis landen (genau schneiden → neu kodieren).
- Fortschritt aus FFmpeg `-progress` lesen. Bei Abbruch FFmpeg beenden, Teildateien löschen. Erst in Temp-Datei schreiben, dann umbenennen.

## Phase 4 – `cutter/server/` + `web/` (Agent 4)

`starte(port=4720, browser_oeffnen=True)` – Flask auf **127.0.0.1**, liefert `web/` aus. Ruft **nur `cutter.pipeline`** auf.

HTTP-API (JSON):

| Methode + Pfad | Zweck |
|---|---|
| `GET /api/videos` | Aufnahmen in `Videos\NVIDIA` (rekursiv): `[{pfad, name, spiel, groesse, datum}]`, neueste zuerst |
| `POST /api/analyse` `{videos:[pfad], einstellungen}` | startet Auftrag Phase 1+2 → `{id}` |
| `POST /api/export` `{clips:[Clip], einstellungen, ziel?}` | startet Auftrag Phase 3 → `{id}` |
| `GET /api/auftrag/<id>` | `{status: laeuft\|fertig\|fehler\|abgebrochen, anteil, text, ergebnis, fehler}` – Ergebnis Analyse: `{clips:[Clip], analysen:[Analyse]}`, Export: `{pfad}` |
| `POST /api/auftrag/<id>/abbrechen` | Auftrag abbrechen |
| `GET /api/video?pfad=` | Video mit HTTP-Range (Vorschau), nur Videodateien |
| `GET /api/bild?pfad=&t=` | Vorschaubild (JPEG) |
| `GET/PUT /api/einstellungen` | Einstellungen laden/speichern (`pipeline.DATEN/einstellungen.json`) |
| `POST /api/oeffnen {pfad}` | Datei im Explorer zeigen |
| `POST /api/pfad-waehlen` | optional: Windows-Dateidialog für Videos außerhalb von `Videos\NVIDIA` |

Solange Phase 1–3 noch `NotImplementedError` werfen: Platzhalter in `cutter/server/mock.py` (Umgebungsvariable `HC_MOCK=1`).
