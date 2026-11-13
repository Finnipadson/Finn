# Erklärvideo-Studio – Bauplan

Stand: 13.11.2026 · Status: Planung · Projektnotiz: `Notizen/Projekte/Erklärvideo-Studio.md`

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

### Phase 0 – Fundament
- Projektordner anlegen (Remotion + Express + Vite/React), `.gitignore`, `README.md` mit Start/Build
- Bestehenden `remotion`-Ordner mit den 4 Testvideos ins Repo übernehmen bzw. als Referenz sichern
- **Fertig, wenn:** `npm run dev` startet die (leere) App im eigenen Fenster, alles ist gepusht

### Phase 1 – Drehbuch → Video (ohne KI)
- JSON-Schema fürs Drehbuch + Prüfung (Fehler verständlich anzeigen)
- 6 Kern-Bausteine: `titel`, `stichpunkte`, `vergleich`, `ablauf`, `formel`, `abschluss`
- Ton-Pipeline als Modul (aus `audio.py`): liest das Drehbuch, erzeugt `mix.wav` + Wort-/Marken-Zeiten
- Eine generische Komposition rendert jedes Drehbuch
- **Fertig, wenn:** ein handgeschriebenes Drehbuch für „Satz des Pythagoras“ ein Video in der Qualität des Testvideos ergibt

### Phase 2 – Claude schreibt das Drehbuch
- Server ruft `claude -p` mit Anleitung + Schema + Beispiel-Drehbüchern auf, Ergebnis wird geprüft, bei Fehlern automatisch nachgebessert (max. 2 Versuche)
- Vorlagen als Anleitungs-Bausteine: Mathe/Schule, Tech-Erklärung, Produkt-Intro
- Sprechertext im „menschlichen“ Stil (kurze Sätze, direkte Ansprache, Pausen)
- **Fertig, wenn:** 3 verschiedene Themen ohne Handarbeit ein gültiges Drehbuch ergeben

### Phase 3 – Oberfläche
- Start-Seite: Thema-Feld, Vorlage, Format, Design-Thema
- Drehbuch-Editor: Szenenliste (umsortieren, löschen), Sprechertext bearbeiten
- **Live-Vorschau** mit `@remotion/player` (ohne Stimme sofort, mit Stimme nach Ton-Erzeugung)
- Sprecher-Auswahl mit Probehören (Ava, Seraphina, Florian, Conrad …), Musik an/aus, Tempo
- **Fertig, wenn:** der komplette Ablauf Thema → Drehbuch → Vorschau in der App klickbar ist

### Phase 4 – Rendern & Nacharbeiten
- Rendern mit Fortschrittsbalken (`@remotion/renderer`), Abbrechen möglich
- Export: MP4 + Cover-Bild (Thumbnail aus einer gewählten Szene)
- „Szene neu machen“: Freitext-Wunsch („Szene 3 langsamer“) → Claude ändert nur diese Szene
- Projekt speichern/öffnen (Drehbuch + Ton + Einstellungen in einem Ordner)
- **Fertig, wenn:** ein Video komplett in der App entsteht und gespeichert wird

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
