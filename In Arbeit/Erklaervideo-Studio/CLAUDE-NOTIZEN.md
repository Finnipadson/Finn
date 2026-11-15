# Arbeitsnotizen für Claude – Erklaervideo-Studio

Wird vor der Arbeit an diesem Projekt gelesen (Verweis in der Haupt-`CLAUDE.md`). Neue Projektdetails hier eintragen, nicht in der Haupt-`CLAUDE.md`.

- App „Erklärvideo-Studio“ (lokale Web-App: Vite/React + Express-Server Port 4710 + Remotion 4.0.438, Oberfläche Port 5173): Thema → Drehbuch (JSON aus Szenen-Bausteinen, von `claude -p` geschrieben) → Remotion-Video mit edge-tts-Stimme
- Start `start.bat` (Edge im App-Modus), Dev `npm run dev`, Prüfung `npm run typecheck`
- Drehbuch von Claude: `npm run drehbuch -- "Thema" --vorlage mathe|tech|produkt --format hoch|quer` bzw. in der App (→ `projekte/<name>/drehbuch.json`, gitignored
- Anleitung `src/drehbuch/anleitung.ts`, Aufruf `server/claude.ts` mit `claude -p --tools ""`
- bei 401 `claude auth login`)
- Drehbuch-Werkzeuge: `npm run pruefen|ton|render -- beispiele/<name>.json` (Format + Bausteine in `README.md`
- Bausteine in `src/video/bausteine/`, Helfer `src/video/kit.tsx` – `lerp`/`sp` fangen Infinity ab)
- Oberfläche in `src/ui/` (Editor, Einstellungen, ThemaAnsicht, api.ts)
- Server-Endpunkte `/api/projekte` (GET/POST/PUT), `/api/projekte/:name/ton`, `/api/projekte/:name/rendern` (→ `projekte/<name>/<name>.mp4` + `-cover.png`, `server/render.ts`, `gl: "angle"`), `/api/szene` („Szene neu machen“), `/api/stimmprobe`, `/api/drehbuch`, `/api/auftrag/:id` (+ `/abbrechen`)
- Remotion: abweichende Props für `renderStill` in `composition.props` setzen
- Python-Kindprozesse mit `-u` starten (sonst kein Fortschritt)
- Bauplan + Phasenstand: `erklaervideo-studio-plan.md` (alle 5 Phasen fertig)
- Design-Themen (`thema`: dunkel/tafel/papier/kueche) über `setzeThema()` in `src/video/kit.tsx` – Bausteine lesen `T` erst beim Rendern (keine Modul-Konstanten mit Farben)
- Musik-Stimmungen in `tools/ton.py` (`STIMMUNGEN`), eigene Musik in `musik/<stimmung>/` (gitignored)
- Fehlertexte in `server/fehler.ts`
- Icon `tools/icon.py`, Verknüpfung `verknuepfung.ps1`
- Code der 4 Testvideos als Vorlage in `referenz/` (Original-Arbeitsordner `Desktop/Claude/remotion`, nicht im Repo)
- Remotion-Versionen müssen exakt gleich sein
- `@types/react-dom` passend zu `@types/react` festsetzen
- Preview: `.claude/launch.json` → `erklaervideo-studio`
