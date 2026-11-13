# Erklärvideo-Studio

Lokale Web-App: Thema eingeben → Drehbuch prüfen → Vorschau → animiertes Erklärvideo (MP4) mit Stimme, Untertiteln, Geräuschen und Musik.

**Stand:** Phase 0 (Fundament) – App startet, Live-Vorschau (Remotion-Player) und System-Check funktionieren. Bauplan: [`erklaervideo-studio-plan.md`](erklaervideo-studio-plan.md)

## Starten

Doppelklick auf **`start.bat`**
- beim ersten Mal werden die Pakete installiert (`npm install`)
- startet Server (Port 4710) + Oberfläche (Port 5173) in einem minimierten Fenster „Erklaervideo-Studio (Server)“
- öffnet die App in einem eigenen Fenster (Edge im App-Modus)

Beenden: das Fenster „Erklaervideo-Studio (Server)“ schließen.

Für die Entwicklung:

```bash
npm run dev        # Server + Oberfläche (mit automatischem Neuladen)
npm run typecheck  # TypeScript prüfen
npm run studio     # Remotion-Studio für die Video-Bausteine
```

## Voraussetzungen

| Was | Wofür | Prüfen |
|---|---|---|
| Node.js 20+ | App, Server, Remotion | `node -v` |
| Claude Code (angemeldet, Pro-Abo) | schreibt später das Drehbuch | `claude --version` |
| Python + `edge-tts` | Sprecherstimme | `python -m pip install edge-tts` |
| FFmpeg | Ton-Effekte, Geräusche, Musik | `winget install Gyan.FFmpeg` |

Die App zeigt das alles im **System-Check** an.

## Aufbau

```
server/index.ts        Lokaler Server (Express): System-Check; später Claude, Stimme, Rendern
src/App.tsx            Oberfläche
src/video/             Remotion: Video-Bausteine + Kompositionen (index.ts = Einstieg fürs Rendern)
referenz/              Die 4 Testvideos (Code + Ton-Skripte) als Vorlage für die Szenen-Bausteine
```

## Hinweise

- Nur für die eigene Nutzung: Die KI läuft über das eigene Claude-Code-Abo (`claude -p`), nicht über einen API-Schlüssel.
- `projekte/`, Renders und Ton-Zwischendateien sind per `.gitignore` vom Repo ausgeschlossen.
