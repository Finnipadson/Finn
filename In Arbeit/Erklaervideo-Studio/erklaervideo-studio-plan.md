# Erklärvideo-Studio – Bauplan

Stand: 13.11.2026 · Status: **Phase 4 fertig**, als Nächstes Phase 5 · Projektnotiz: `Notizen/Projekte/Erklärvideo-Studio.md`

**Ziel:** Thema eingeben → Drehbuch prüfen → Vorschau → fertiges animiertes Erklärvideo (MP4) mit Stimme, Untertiteln, Geräuschen und Musik. Nur für die eigene Nutzung, KI läuft über Claude Code (Pro-Abo).

---

## Entscheidungen

| Thema | Entscheidung | Warum |
|---|---|---|
| Oberfläche ✅ | **Lokale Web-App** (React), geöffnet in eigenem Fenster (`msedge --app=…`), Start per Verknüpfung | Die Videos sind schon React (Remotion). So gibt es eine **Live-Vorschau ohne Rendern** (`@remotion/player`) und alles bleibt eine Sprache. WPF müsste die Vorschau erst rendern. |
| Server | Node.js (Express) im selben Projekt | ruft `claude -p`, die Ton-Pipeline und `@remotion/renderer` auf |
| KI | `claude -p` (Claude Code, Pro-Abo) | kein API-Schlüssel nötig; nur eigene Nutzung |
| Video | Remotion 4 (wie bisher), 60 fps, CRF 16 | bewährt aus den 4 Testvideos |
| Stimme | edge-tts (Python), Standard Ava Multilingual | kostenlos, beste Qualität bisher |
| Ton | FFmpeg (Effekte, Geräusche, Musik-Ducking) | bewährt aus `audio.py` |
| Speicherort | `Games/In Arbeit/Erklaervideo-Studio/` (Git), `node_modules`, Renders und Ton-Zwischendateien per `.gitignore` raus | Projektregel: alles in `In Arbeit/`, auf GitHub gesichert |

**Kernidee: das Drehbuch als Datei.** Claude schreibt keinen freien Animations-Code mehr, sondern ein **Drehbuch im JSON-Format** aus fertigen Szenen-Bausteinen. Das ist zuverlässiger, schneller, einheitlicher – und im Editor bearbeitbar.

```json
{
  "titel": "Satz des Pythagoras",
  "format": "hoch",            // hoch | quer
  "thema": "tafel",            // tafel | dunkel-neon | papier | kueche
  "stimme": "ava", "tempo": 0, "musik": true,
  "szenen": [
    { "typ": "titel", "text": "Satz des Pythagoras", "unter": "einfach erklärt",
      "sprecher": [{ "satz": "Okay, pass auf.", "pause": 0.35 }] },
    { "typ": "formel", "formel": "a² + b² = c²", "aufbau": ["a²", "+ b²", "= c²"],
      "sprecher": [{ "satz": "Also: a Quadrat plus b Quadrat gleich c Quadrat.", "pause": 0.6,
                     "marken": { "plus": "+ b²", "gleich": "= c²" } }] }
  ]
}
```

`marken` verknüpfen ein gesprochenes Wort mit einem Animations-Schritt → Bild und Ton bleiben synchron (Prinzip aus `events.json`).

---

## Szenen-Bausteine (Bibliothek)

Herausgelöst aus den Testvideos, jeder Baustein mit festen Parametern:

| Baustein | Inhalt | Vorbild |
|---|---|---|
| `titel` | großer Titel, Buchstaben-Animation, Untertitel | Claude Code Erklaerung, Szene 1 |
| `stichpunkte` | 2–5 Punkte mit Icon, erscheinen auf Stichwort | Szene 6 (Beschreiben/Prüfen/Entscheiden) |
| `vergleich` | zwei Spalten A vs. B | Szene 2 (Chat vs. Claude Code) |
| `schleife` / `ablauf` | Stationen im Kreis oder als Kette, Fortschrittspunkt | Szene 3 |
| `formel` | Formel baut sich Teil für Teil auf, Rechenschritte darunter | Satz des Pythagoras |
| `geometrie` | Dreieck/Formen zeichnen sich, Beschriftungen | Satz des Pythagoras |
| `fenster` | Terminal/Code/Chat-Fenster mit Tipp-Effekt, Diff-Ansicht | Szene 1, 2, 4 |
| `bilder` | Screenshot-Karten (Hero → Reihe) | Szene 5 |
| `zeitstrahl` | Ereignisse auf einer Linie | neu |
| `figur` | Koch-Figur mit Lippen-Sync (optional, aufwendig) | Koch Szene HD |
| `abschluss` | Merksatz / Danke-Karte | Szene 7 |

Jeder Baustein funktioniert in **Hoch- und Querformat** und in jedem **Design-Thema** (Farben, Schriften, Hintergrund als Token).

---

## Phasen

### Phase 0 – Fundament ✅ (13.11.2026)
- Projektordner anlegen (Remotion + Express + Vite/React), `.gitignore`, `README.md` mit Start/Build
- Bestehenden `remotion`-Ordner mit den 4 Testvideos ins Repo übernehmen bzw. als Referenz sichern
- **Fertig, wenn:** `npm run dev` startet die (leere) App im eigenen Fenster, alles ist gepusht
- **Ergebnis:** `start.bat` startet Server (4710) + Oberfläche (5173) und öffnet Edge im App-Modus. Oberfläche mit Schritt-Leiste (Platzhalter), **Live-Vorschau** per `@remotion/player` (Hoch/Quer umschaltbar, Titel live änderbar) und **System-Check** (Node, Claude Code, Python + edge-tts, FFmpeg). Testvideos als Referenz in `referenz/`.

### Phase 1 – Drehbuch → Video (ohne KI) ✅ (13.11.2026)
- JSON-Schema fürs Drehbuch + Prüfung (Fehler verständlich anzeigen)
- 6 Kern-Bausteine: `titel`, `stichpunkte`, `vergleich`, `ablauf`, `formel`, `abschluss`
- Ton-Pipeline als Modul (aus `audio.py`): liest das Drehbuch, erzeugt `mix.wav` + Wort-/Marken-Zeiten
- Eine generische Komposition rendert jedes Drehbuch
- **Fertig, wenn:** ein handgeschriebenes Drehbuch für „Satz des Pythagoras“ ein Video in der Qualität des Testvideos ergibt
- **Ergebnis:** Typen + Prüfung (`src/drehbuch/`, `npm run pruefen`), **7 Bausteine** (zusätzlich `geometrie` – für Pythagoras nötig, aus Phase 5 vorgezogen), Ton-Pipeline `tools/ton.py` (Stimme satzweise, Geräusche je `bei`, Musik mit Ducking, `<name>.timing.json`), generische Komposition `Erklaervideo` (Hoch/Quer per `calculateMetadata`, Szenenwechsel mit Blur, Wort-Untertitel), `npm run render`. Statt „Marken“ gibt es **`bei`**: ein Element erscheint beim gesprochenen Wort. Ohne Ton: geschätzte Zeiten für die Sofort-Vorschau. Zwei Beispiele: `beispiele/pythagoras.json` (hoch, 51 s) und `beispiele/claude-code-kurz.json` (quer, 41 s). App-Vorschau zeigt beide.
- **Gelernt:** optionale Zeitpunkte sind „Infinity“ → Animations-Helfer (`lerp`, `sp`) müssen das abfangen; `interpolate` braucht streng steigende Zeiten.

### Phase 2 – Claude schreibt das Drehbuch ✅ (13.11.2026)
- Server ruft `claude -p` mit Anleitung + Schema + Beispiel-Drehbüchern auf, Ergebnis wird geprüft, bei Fehlern automatisch nachgebessert (max. 2 Versuche)
- Vorlagen als Anleitungs-Bausteine: Mathe/Schule, Tech-Erklärung, Produkt-Intro
- Sprechertext im „menschlichen“ Stil (kurze Sätze, direkte Ansprache, Pausen)
- **Fertig, wenn:** 3 verschiedene Themen ohne Handarbeit ein gültiges Drehbuch ergeben
- **Ergebnis:** `server/claude.ts` (`claude -p --output-format json --tools "" --no-session-persistence`, cwd = Temp-Ordner, Prompt über stdin; Fehlerarten Anmeldung/nicht gefunden/Zeit/Antwort), Anleitung + 3 Vorlagen in `src/drehbuch/anleitung.ts`, Projekte in `projekte/<name>/`, CLI `npm run drehbuch`, Server-Aufträge (`POST /api/drehbuch` + Status-Abfrage), Thema-Eingabe in der App. Prüfung lehnt jetzt Symbole im Sprechertext ab. **Test:** Prozentrechnung (Mathe, hoch), Akku (Tech, quer), Kopfsache-Intro (Produkt, hoch) – alle 3 auf Anhieb gültig (je 1 Versuch, 2–3 Min. bei parallelem Lauf); Akku als Video gerendert.
- **Gelernt:** Claude erfand beim Produkt-Intro Fakten („App“, „kostenlos“) → Regel 8 „nur behaupten, was im Thema steht“, danach sauber. `claude auth status` meldet „angemeldet“, obwohl der Token abgelaufen sein kann → echter Fehler kommt erst beim Aufruf, die App zeigt dann „`claude auth login` ausführen“.

### Phase 3 – Oberfläche ✅ (13.11.2026)
- Start-Seite: Thema-Feld, Vorlage, Format, Design-Thema
- Drehbuch-Editor: Szenenliste (umsortieren, löschen), Sprechertext bearbeiten
- **Live-Vorschau** mit `@remotion/player` (ohne Stimme sofort, mit Stimme nach Ton-Erzeugung)
- Sprecher-Auswahl mit Probehören (Ava, Seraphina, Florian, Conrad …), Musik an/aus, Tempo
- **Fertig, wenn:** der komplette Ablauf Thema → Drehbuch → Vorschau in der App klickbar ist
- **Ergebnis:** klickbare Schritt-Navigation (gesperrt ohne Projekt); Start mit Thema-Eingabe, Projekt- und Beispiel-Karten, System-Check; **Editor** mit Szenenliste (↑↓✕, neue Szene je Baustein-Typ mit Startwerten), Formular für alle 7 Bausteine, Sprechertext (Pause/Tempo je Satz), „bei“ als Dropdown der gesprochenen Wörter (mit #2), Live-Prüfung, Live-Vorschau mit Sprung zur Szene, JSON-Modus; **Einstellungen** (Titel, Format, 5 Sprecher mit Hörprobe, Tempo-Regler, Musik); **Vorschau** mit „Stimme erzeugen“ (Fortschritt pro Satz) und Status „mit Stimme / Stimme veraltet“; Speichern (Beispiel → automatische Kopie), Warnung bei ungespeicherten Änderungen. Server: `PUT/POST /api/projekte`, `POST /api/projekte/:name/ton`, `GET /api/stimmprobe` (Proben zwischengespeichert). Design-Thema-Auswahl → Phase 5 (es gibt bisher nur ein Thema).
- **Getestet (im Browser):** Akku öffnen → Satz ändern → Speichern → „Stimme veraltet“ → Stimme erzeugen → „mit Stimme“; Beispiel bearbeiten → „Als Kopie speichern“; Hörprobe Seraphina (erstes Mal ca. 11 s, danach sofort).
- **Gelernt:** Python puffert die Ausgabe bei Umleitung → `python -u`, sonst kommt kein Fortschritt an. Geänderte Tondatei braucht Cache-Schutz in der URL (`?v=<Änderungszeit>`); `staticFile()` dafür umgehen.

### Phase 4 – Rendern & Nacharbeiten ✅ (13.11.2026)
- Rendern mit Fortschrittsbalken (`@remotion/renderer`), Abbrechen möglich
- Export: MP4 + Cover-Bild (Thumbnail aus einer gewählten Szene)
- „Szene neu machen“: Freitext-Wunsch („Szene 3 langsamer“) → Claude ändert nur diese Szene
- Projekt speichern/öffnen (Drehbuch + Ton + Einstellungen in einem Ordner)
- **Fertig, wenn:** ein Video komplett in der App entsteht und gespeichert wird
- **Ergebnis:** `server/render.ts` rendert direkt im Server (`@remotion/bundler` + `@remotion/renderer`): Fortschritt mit Bildzähler und Restzeit, **Abbrechen** (Temp-Datei, altes Video bleibt), danach **Cover-Bild** (Ende der Titel-Szene, ohne Untertitel). Video + Cover liegen in `projekte/<name>/<name>.mp4` bzw. `<name>-cover.png`. Seite **Rendern**: Infos (Format, Länge, Sprecher), „Video rendern“/„Ohne Stimme rendern“, Video-Player mit Ergebnis, Download MP4/Cover, „Im Ordner zeigen“, Hinweis „Video ist älter als das Drehbuch“; Render läuft beim Wechsel der Schritte weiter (Prozent in der Navigation), immer nur einer gleichzeitig. **„Szene neu machen“** im Editor: Wunsch eintippen (oder Vorschlag-Chip) → Claude überarbeitet nur diese Szene (ganzes Drehbuch als Kontext, Prüfung + bis zu 2 Korrekturrunden) → Szene wird ersetzt, „↶ Rückgängig“. Speichern/Öffnen gab es schon seit Phase 3. **Test:** Akku-Video in der App gerendert (48 s Video in 51 s), Abbrechen geprüft, Szene 2 „kürzer und lockerer“ in 45 s neu gemacht + rückgängig.
- **Gelernt:** Remotion rendert CSS-/SVG-Weichzeichner ohne Grafikkarte extrem langsam → `chromiumOptions: { gl: "angle" }` (8× schneller: 442 s → 51 s; Rückfall auf normal, falls es scheitert). `renderStill`/`renderMedia` nehmen die Props aus `composition.props`, nicht aus `inputProps` → abweichende Props (Cover) dort setzen. Zwei Renders gleichzeitig → „Page crashed“; ein Fehlversuch beim Status-Abruf darf die Abfrage nicht beenden (PC ist beim Rendern ausgelastet).

### Phase 5 – Feinschliff
- 4 Design-Themen ausgearbeitet, weitere Bausteine (`geometrie`, `fenster`, `bilder`, `zeitstrahl`)
- Echte lizenzfreie Musik (Ordner mit Stimmungen), Lautstärke automatisch
- Fehlerbehandlung (kein Internet für edge-tts, Claude nicht angemeldet, Render-Fehler)
- Desktop-Verknüpfung mit Icon
- Optional: `figur`-Baustein (Koch mit Lippen-Sync)

---

## Risiken & Gegenmittel

| Risiko | Gegenmittel |
|---|---|
| Claude liefert ungültiges Drehbuch | Schema-Prüfung + automatischer Korrektur-Versuch mit Fehlermeldung |
| edge-tts liefert mal nichts (kostenloser Dienst) | Wiederholversuche (schon in `audio.py`), Hinweis bei fehlendem Internet |
| Stimme spricht Wörter anders (z. B. „3 mal 3“ als Block) | zeichengenaue Wort-Zuordnung (schon gelöst) |
| Lange Renderzeiten (60 fps) | Vorschau ohne Rendern; Rendern im Hintergrund mit Fortschritt; optional 30 fps |
| Pro-Abo-Limit | Drehbuch statt freiem Code spart viel; Szenen einzeln neu statt alles |

## Offene Fragen

- [x] Oberfläche als lokale Web-App im eigenen Fenster – **bestätigt am 13.11.2026** (statt WPF)
- [ ] Welche Vorlage zuerst richtig gut machen? (Vorschlag: Mathe/Schule)
- [ ] Soll die Koch-Figur (aufwendig) früh rein oder erst in Phase 5?
