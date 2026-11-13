# Erklärvideo-Studio

Lokale Web-App: Thema eingeben → Drehbuch prüfen → Vorschau → animiertes Erklärvideo (MP4) mit Stimme, Untertiteln, Geräuschen und Musik.

**Stand:** Phase 5 (fertig) – alles in der App: Thema → Drehbuch bearbeiten (auch „Szene neu machen“ mit Claude) → Einstellungen (4 Designs, 5 Sprecher, 3 Musik-Stimmungen) → Vorschau mit Stimme → Rendern (MP4 + Cover). Bauplan: [`erklaervideo-studio-plan.md`](erklaervideo-studio-plan.md)

## So benutzt du die App

1. **Thema** – Thema eingeben, Vorlage/Format/Länge wählen, „Drehbuch schreiben“. Oder ein vorhandenes Drehbuch bzw. Beispiel öffnen.
2. **Drehbuch** – links die Szenen (umsortieren ↑↓, löschen ✕, neue Szene einfügen), in der Mitte das Formular der Szene (Texte, Icons, Farben, Sprechertext mit Pause/Tempo, „bei“ als Auswahl aus den gesprochenen Wörtern), rechts die Live-Vorschau (Klick auf eine Szene springt dorthin). Fehler werden sofort angezeigt. Für Profis: „JSON bearbeiten“.
   **✨ Szene neu machen:** Wunsch eintippen („kürzer und lockerer“, „als Vergleich“) → Claude überarbeitet nur diese Szene (30–60 s). Mit „↶ Rückgängig“ zurück.
3. **Einstellungen** – Titel, Format, **Design** (Dunkel-Neon, Tafel, Papier, Küche – wirkt sofort, ohne neue Stimme), Sprecher mit **▶ Probe**, Grundtempo, **Musik** (ruhig / fröhlich / spannend / aus, mit **▶ Musik**). Eigene lizenzfreie Musik: Dateien nach `musik/ruhig|froh|spannend/` legen (siehe `musik/LIESMICH.txt`) – die Lautstärke wird automatisch angeglichen.
4. **Vorschau** – „Stimme erzeugen“ (speichert vorher automatisch, zeigt Fortschritt), danach Vorschau mit echter Stimme, Geräuschen und Musik.
5. **Rendern** – „Video rendern“ (speichert vorher automatisch) mit Fortschritt, Restzeit und **Abbrechen**. Danach: Video ansehen, **MP4** und **Cover-Bild** herunterladen, „Im Ordner zeigen“. Dateien: `projekte/<name>/<name>.mp4` und `<name>-cover.png`. Rendern nutzt die Grafikkarte (ca. 1 Minute für 50 s Video) und läuft weiter, wenn du andere Schritte öffnest.

Oben rechts: **Speichern** (gelber Punkt = ungespeicherte Änderungen). Ein bearbeitetes **Beispiel** wird beim Speichern automatisch als eigenes Projekt kopiert. Ändert sich Sprechertext, „bei“, Stimme, Tempo oder Musik, verwirft der Server die alte Stimme – die Vorschau zeigt dann „Stimme veraltet“.

## Starten

Doppelklick auf die Desktop-Verknüpfung **Erklaervideo-Studio** (eigenes Icon) oder auf **`start.bat`**.
Verknüpfung neu anlegen: Rechtsklick auf `verknuepfung.ps1` → „Mit PowerShell ausführen“. Icon neu erzeugen: `python tools/icon.py`.
Läuft das Studio schon, öffnet `start.bat` nur ein weiteres Fenster.
- beim ersten Mal werden die Pakete installiert (`npm install`)
- startet Server (Port 4710) + Oberfläche (Port 5173) in einem minimierten Fenster „Erklaervideo-Studio (Server)“
- öffnet die App in einem eigenen Fenster (Edge im App-Modus)

Beenden: das Fenster „Erklaervideo-Studio (Server)“ schließen.

## Vom Thema zum Drehbuch (Phase 2)

In der App: **Thema** eingeben, Vorlage (Mathe/Schule, Tech-Erklärung, Produkt-Intro), Format und Länge wählen → „Drehbuch schreiben“ (dauert 1–3 Minuten). Das Ergebnis landet in `projekte/<name>/drehbuch.json` und erscheint in der Vorschau unter „Meine Drehbücher“.

Oder im Terminal:

```bash
npm run drehbuch -- "Wie funktioniert ein Akku?" --vorlage tech --format quer --sekunden 45 --name akku
```

Claude Code läuft dabei im Hintergrund (`claude -p`, ohne Werkzeuge, über das eigene Abo). Jedes Drehbuch wird geprüft; bei Fehlern korrigiert Claude automatisch (max. 2 Runden). Die Anleitung für Claude steht in `src/drehbuch/anleitung.ts`.

**Fehler „nicht angemeldet / Token abgelaufen“:** im Terminal `claude auth login` ausführen. (Achtung: `claude auth status` kann „angemeldet“ melden, obwohl der Token abgelaufen ist.)

## Vom Drehbuch zum Video (Kommandozeile, Alternative zur App)

```bash
npm run pruefen -- beispiele/pythagoras.json   # Drehbuch prüfen (verständliche Fehlermeldungen)
npm run ton -- beispiele/pythagoras.json       # Stimme + Geräusche + Musik + Zeitliste erzeugen
npm run render -- beispiele/pythagoras.json    # MP4 nach out/pythagoras.mp4 (60 fps)
npm run render -- beispiele/x.json --ohne-ton  # ohne Stimme, Zeiten geschätzt
npm run ton -- projekte/akku/drehbuch.json     # funktioniert genauso für eigene Projekte
```

In der App zeigt **Vorschau** jedes Beispiel aus `beispiele/` sofort – mit echter Stimme, sobald `npm run ton` gelaufen ist, sonst mit geschätzten Zeiten.

## Das Drehbuch

```json
{
  "titel": "Satz des Pythagoras", "format": "hoch", "stimme": "ava", "tempo": -3, "musik": true, "stimmung": "ruhig", "thema": "tafel",
  "szenen": [
    { "typ": "titel", "titel": "Satz des Pythagoras", "unter": "einfach erklärt",
      "sprecher": [{ "satz": "Okay, pass auf.", "pause": 0.35 }] },
    { "typ": "formel",
      "teile": [{ "text": "a²", "farbe": "a", "bei": "a" }, { "text": "+", "bei": "plus" }],
      "sprecher": [{ "satz": "Also: a Quadrat plus b Quadrat gleich c Quadrat." }] }
  ]
}
```

- **`sprecher`**: Sätze der Szene, je mit `pause` (Sekunden danach) und optional `tempo` (Prozent, zusätzlich zum Grundtempo).
- **`bei`**: verknüpft ein Element mit einem gesprochenen Wort dieser Szene – es erscheint genau dann. `"Quadrat#2"` = zweites Vorkommen. Ohne `bei` erscheinen Elemente nacheinander am Szenenanfang.
- **Stimmen**: `ava` (Standard), `seraphina`, `florian`, `conrad`, `katja`.
- **Formate**: `hoch` (1080×1920) oder `quer` (1920×1080).
- **Design** (`thema`): `dunkel` (Standard), `tafel`, `papier`, `kueche`. Mathe-Drehbücher von Claude bekommen automatisch `tafel`.
- **Musik**: `musik` (true/false) und `stimmung`: `ruhig` (Standard), `froh`, `spannend`.

### Szenen-Bausteine

| `typ` | Felder | |
|---|---|---|
| `titel` | `titel`, `unter?`, `kicker?` | großer Titel, Buchstaben-Animation |
| `stichpunkte` | `punkte[]`: `text`, `unter?`, `icon?`, `bei?` (1–5) | Karten mit Icons |
| `vergleich` | `links`/`rechts`: `titel`, `icon?`, `bei?`, `punkte[]` | links „schlecht“, rechts „gut“ |
| `ablauf` | `schritte[]` (2–6), `form`: `kreis`/`kette`, `fehler?`, `erfolg?` | Stationen mit laufendem Punkt; Fehler → Extrarunde → Erfolg |
| `formel` | `teile[]`: `text`, `farbe?`, `bei?`; `schritte[]?`; `merke?` | Formel baut sich auf, Rechenschritte darunter |
| `geometrie` | `a`, `b`, `beschriftung?`, `dreieck?`/`katheten?`/`hypotenuse?`/`quadrate?`/`raster?`/`werte?` (je `{ "bei" }`) | rechtwinkliges Dreieck mit Quadraten |
| `zeitstrahl` | `ereignisse[]` (2–6): `zeit`, `text`, `icon?`, `bei?` | Linie wächst von Ereignis zu Ereignis |
| `fenster` | `art`: `terminal`/`chat`, `titel?`, `zeilen[]` (1–6): `text`, `rolle`: `ich`/`antwort`, `bei?` | Programmfenster; „ich“ wird getippt, Antworten erscheinen |
| `abschluss` | `text`, `unter?`, `bei?` | Merksatz mit Rahmen |

Alle Szenen können zusätzlich `kicker` und `ueberschrift` haben.
Farben: `a`, `b`, `c`, `akzent`, `text`, `gruen`, `rot`, `blau`, `lila`.
Icons: `chat`, `datei`, `stift`, `terminal`, `haken`, `kreuz`, `idee`, `buch`, `karte`, `lupe`, `wegweiser`, `schild`, `stern`, `person`, `blitz`, `herz`, `zahnrad`, `uhr`, `rakete`, `ziel`.

## Voraussetzungen

| Was | Wofür | Prüfen |
|---|---|---|
| Node.js 20+ | App, Server, Remotion | `node -v` |
| Claude Code (angemeldet, Pro-Abo) | schreibt ab Phase 2 das Drehbuch | `claude --version` |
| Python + `edge-tts` | Sprecherstimme | `python -m pip install edge-tts` |
| FFmpeg | Ton-Effekte, Geräusche, Musik | `winget install Gyan.FFmpeg` |

Die App zeigt das alles im **System-Check** an.

## Aufbau

```
src/drehbuch/          Typen, Prüfung, geschätztes Timing, Anleitung + Vorlagen für Claude
server/claude.ts       Claude-Aufruf (claude -p), JSON herauslösen, prüfen, Korrektur-Runden
server/projekte.ts     Projekte speichern/laden (projekte/<name>/), alte Stimme bei Text-Änderung verwerfen
server/render.ts       Rendern im Server (@remotion/renderer, Grafikkarte), Abbrechen, Cover-Bild
src/ui/                Oberfläche: ThemaAnsicht, Editor (+ Felder, SzeneNeu), Einstellungen, VorschauPlayer, Rendern, api.ts
src/video/             Remotion: Erklaervideo.tsx (spielt jedes Drehbuch), kit.tsx (Farben, Icons, Helfer)
src/video/bausteine/   die 9 Szenen-Bausteine
tools/                 drehbuch.ts, pruefen.ts, ton.py (Ton-Pipeline + Musik-Stimmungen), probe.py (Hörprobe), render.ts, icon.py
server/fehler.ts       übersetzt technische Fehler in verständliche Meldungen
musik/                 eigene Hintergrundmusik je Stimmung (Dateien nicht im Repo)
assets/                App-Icon (icon.ico für die Verknüpfung)
beispiele/             Beispiel-Drehbücher (+ erzeugte .timing.json)
server/index.ts        Lokaler Server (Express): System-Check, Claude, Projekte, Stimme, Szene neu machen, Rendern
referenz/              Die 4 Testvideos (Code + Ton-Skripte) als Vorlage
```

## Hinweise

- Nur für die eigene Nutzung: Die KI läuft über das eigene Claude-Code-Abo (`claude -p`), nicht über einen API-Schlüssel.
- `projekte/` (inkl. fertiger Videos), `public/ton/` (Ton-Dateien) und `out/` (Videos aus der Kommandozeile) sind per `.gitignore` vom Repo ausgeschlossen – alles neu erzeugbar.
- edge-tts braucht Internet; bei Aussetzern wird automatisch bis zu 4× wiederholt.
