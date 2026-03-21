# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Allgemein

### Qualitätssicherung

Bevor ein fertiges Ergebnis (Code, Datei, Lösung) an den User übergeben wird:
- Auf Fehler prüfen (Logikfehler, Syntaxfehler, fehlende Teile)
- Gefundene Fehler sofort selbstständig beheben — ohne nachzufragen
- Erst dann das Ergebnis liefern

### Git Workflow

After completing any meaningful unit of work, commit and push to GitHub immediately. Never leave progress uncommitted at the end of a session.

- Commit after each logical change (feature added, bug fixed, config tuned) — not in bulk at the end
- Write clear, specific commit messages: `Add dash trail effect to rusher enemy`, not `update shooter.html`
- Always push after committing: `git add -A && git commit -m "message" && git push`

### Session-Ende

Am Ende jeder Session: Alle geänderten oder neu erstellten Dateien in den Ordner `In Arbeit/` im Repo verschieben (falls noch nicht dort) und pushen. So ist immer der aktuelle Arbeitsstand auf GitHub gespeichert.

---

## Projektstruktur

Alle Spiele liegen im Unterordner `Games/`. Das Git-Repo ist ebenfalls dort (`Games/.git`), nicht im Root.

| Datei | Beschreibung |
|-------|-------------|
| `Games/shooter.html` | Top-Down-Shooter (5 Level, 5 Enemy-Types) |
| `Games/tictactoe.html` | Tic-Tac-Toe-Spiel |

---

## Projektspezifisch — shooter.html

### Projekt

`shooter.html` ist ein selbstenthaltenes, Single-File Top-Down-Shooter-Spiel mit vanilla HTML5 Canvas und JavaScript. Kein Build-Step, keine Dependencies — Datei direkt im Browser öffnen.

### Architektur

Everything lives in one `<script>` block, organized into clearly labeled sections:

- **CONFIG** — all tunable constants (speeds, sizes, colors, level/wave definitions, enemy stats). This is the first place to look when adjusting gameplay balance.
- **STATE** — global mutable variables (`gameState`, `score`, `player`, `enemies`, `playerBullets`, `enemyBullets`, `particles`). `gameState` drives which update/render path runs: `MENU → PLAYING → LEVEL_COMPLETE → PLAYING → ... → GAME_OVER`.
- **Classes** — `Particle`, `Player`, `Bullet`, `Enemy`. All share a `update(dt)` / `draw()` interface. `Enemy` handles all five types (`grunt`, `rusher`, `tank`, `shooter`, `boss`) via type-specific branches inside its methods.
- **Level/Wave manager** — `spawnWave()` reads `CONFIG.LEVELS[currentLevel].waves[currentWave]` and instantiates enemies from edge spawn positions. `checkWaveComplete()` advances the wave or transitions to `LEVEL_COMPLETE`.
- **Collision** — `circleCollide(a, b)` is used for all hit detection (player bullets vs enemies, enemy bullets vs player, enemy contact vs player).
- **Game loop** — `requestAnimationFrame`-driven; `dt` is capped at 50 ms to prevent tunneling on tab-hidden resumption.

### Level Structure

Five levels defined in `CONFIG.LEVELS`, each with an array of wave objects and a score `multiplier`. Wave objects map enemy type names to spawn counts (e.g. `{grunt:5, rusher:3}`). Level 5 ends with a boss wave.

### Enemy Types

| Type    | Notable behavior |
|---------|-----------------|
| grunt   | Walks toward player with sine wobble |
| rusher  | Periodically dashes at 3.5× speed |
| tank    | Slow, 4 HP, shows HP bar |
| shooter | Keeps distance, fires single bullets |
| boss    | 40 HP, fires 5-bullet spread, shows HP bar |

### High Score Persistence

Stored in `localStorage` under the key `shooterHighScore`.
