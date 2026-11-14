# Highlight Cutter – Bauplan

PC-App: NVIDIA-Aufnahmen (Apex Legends zuerst) rein → Kills automatisch finden → ein zusammengeschnittenes Highlight-Video raus.
Projektnotiz: `Notizen/Projekte/Highlight Cutter.md`

## Technik

- **Python 3.14** (Analyse + Server), **FFmpeg 8.1** (Lesen, Schneiden, Kodieren mit NVENC), **OpenCV/NumPy** (Bilderkennung), Ton-Auswertung mit NumPy/SciPy
- Oberfläche: lokale Web-Seite (kleiner Python-Server, Start per `start.bat`, Edge im App-Modus)
- Erkennung pro Spiel als **Spielprofil** (`profile/apex.py`): wo liegt was im HUD, wie sieht ein Kill aus. Weitere Spiele = neues Profil.

## Regeln (vom User festgelegt)

| Thema | Regel |
|---|---|
| Kill | Immer Highlight |
| Knock | Nur Highlight, wenn danach ein Kill folgt (Knock → Kill wird ein Clip) |
| Eigener Tod / Champion | Optional, Schalter in der App (Standard aus) |
| Clip-Länge | Kampfbeginn bis kurz nach dem letzten Kill; Fallback ca. 10 s; nahe Kills → ein Clip |
| Montage | Keine Musik, kurze Übergänge (ca. 0,3 s Überblendung) |
| Format | In der App wählbar: 16:9 oder 9:16 (hochkant) |
| Ton | Stimmen von Kollegen (Discord) können in der Aufnahme sein → Erkennung stützt sich aufs Bild, Ton nur als Hilfe |

## Phasen

### Phase 1 – Apex-Kills erkennen
- Projekt anlegen, Testbilder aus den eigenen Aufnahmen ziehen und die HUD-Stellen festlegen (Kill-Zähler, Knock-/Kill-Meldung in der Mitte)
- Nur diese kleinen Bildausschnitte auswerten (ca. 4× pro Sekunde, per FFmpeg verkleinert) → schnell auch bei 1440p/120 fps
- Ergebnis: Liste aller Kills und Knocks mit Zeitstempel (JSON), Kontrollbilder zum Prüfen
- Fertig, wenn: in 3 echten Aufnahmen alle Kills gefunden werden, ohne Fehlalarme
- Prüfen: `python -m cutter erkennen <video>`

### Phase 2 – Clips festlegen („die App entscheidet“)
- Knock → Kill verbinden, Knocks ohne Kill verwerfen
- Kampfbeginn finden: rückwärts vom Kill nach Schüssen/Treffern suchen (Ton-Spitzen im Schuss-Frequenzbereich + Treffer-Anzeige im Bild), robust gegen Sprache
- Kills mit kleinem Abstand zu einem Clip zusammenfassen, Vor-/Nachlauf, Fallback 10 s
- Kaputte Frames am Anfang von DVR-Dateien überspringen
- Ergebnis: Clipliste (Start, Ende, Grund)

### Phase 3 – Schneiden und Zusammenfügen (erstes fertiges Video)
- Clips mit FFmpeg ausschneiden und mit kurzen Überblendungen (Bild + Ton) verbinden
- Kodieren per NVENC (Grafikkarte, schnell), Ausgabe 16:9 oder 9:16 (hochkant: Mitte ausschneiden, Hintergrund unscharf)
- Ergebnis: `python -m cutter machen <video>` → fertiges Highlight-Video
- Fertig, wenn: eine 30-min-Aufnahme in wenigen Minuten zu einem sauberen Video wird

### Phase 4 – Oberfläche
- Videos per Drag & Drop oder aus `Videos\NVIDIA` auswählen (mehrere Aufnahmen → ein Video)
- Fortschritt beim Analysieren, Abbrechen möglich
- Clipliste mit Vorschau: an-/abwählen, Start/Ende verschieben, Reihenfolge ändern
- Einstellungen: Format 16:9/9:16, eigene Tode, Champion, Übergangslänge
- Export-Knopf, fertiges Video öffnen
- `start.bat` + Desktop-Verknüpfung

### Phase 5 – Extras
- Eigene Tode und Champion-Sieg erkennen (für die Schalter aus Phase 4)
- Einstellungen merken, Analyse zwischenspeichern (zweites Öffnen sofort)
- Weitere Spiele als Spielprofile vorbereiten

## Stand

Gebaut 2026-11-14 von 4 parallelen Agenten (Phase 5 auf Agent 1 + 4 verteilt), danach zusammengefügt.

- [x] Phase 1 – Kill-Zähler oben rechts (Ziffern-Templates) + „KNOCKED DOWN“/„ELIMINATED“ + Todes-Zusammenfassung + Champion-Banner. Ground Truth: 15/15 Kills, 18/18 Knocks, 0 Fehlalarme. Nur Keyframes (4/s) → ~4 s pro 150-s-Aufnahme
- [x] Phase 2 – Regeln + Kampfbeginn über Ton (Schuss-Salven, Sprache aussortiert). 6/7 Gefechte im Sollbereich
- [x] Phase 3 – NVENC, je Clip eigener Lauf, Überblendungen einzeln, ~6× Echtzeit. Hochkant = 4:5-Ausschnitt + unscharfer Hintergrund. Erkennt kaputten DVR-Anfang (`erster_sauberer_zeitpunkt`)
- [x] Phase 4 – Flask-Server + Web-Oberfläche, `start.bat`, `verknuepfung.ps1`
- [x] Phase 5 – Tod/Champion-Erkennung, Einstellungen gemerkt, Analyse-Cache (`daten/cache`)
- [x] Gesamttest: 87 pytest grün; 3 echte Aufnahmen → 6 Clips → 16:9 und 9:16 (65 s für beide); Oberfläche mit echter Erkennung durchgeklickt

## Bekannte Grenzen / Ideen

- Lange Gefechte mit Pausen > 10 s: nur die letzte Phase wird als Kampfbeginn erkannt
- Schwellen für Ton aus 4 Aufnahmen, echte Discord-Stimmen ungetestet
- Ziffern-Templates 6–9 aus je nur 1 Beispiel; andere Modi (TDM) und Auflösungen ungetestet
- Tod/Champion-Zeitpunkt = Erscheinen der Zusammenfassung/des Banners
- Keine echte 30-min-Aufnahme vorhanden (alle DVR-Clips ≤ 150 s), Geschwindigkeit hochgerechnet
- Option: Feld `start_quelle` (Ton/geschätzt) im Clip für die Oberfläche
