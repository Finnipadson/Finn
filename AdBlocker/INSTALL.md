# YT AdBlocker — Installation (Firefox)

## Schritt 1: Icons erstellen

1. Öffne `generate_icons.html` im Browser
2. Klick auf "Download icon48.png" → speichere die Datei im `AdBlocker/` Ordner
3. Klick auf "Download icon96.png" → speichere die Datei im `AdBlocker/` Ordner

## Schritt 2: Extension in Firefox laden

1. Öffne Firefox
2. Gib in der Adressleiste ein: `about:debugging`
3. Klick links auf **"Dieser Firefox"**
4. Klick auf **"Temporäre Erweiterung laden..."**
5. Navigiere zum `AdBlocker/` Ordner
6. Wähle die Datei **`manifest.json`** aus
7. Fertig — das Extension-Icon erscheint oben rechts in Firefox

## Hinweis

Die Extension bleibt nur bis zum nächsten Firefox-Neustart aktiv (temporäre Installation).
Für permanente Installation ohne Firefox Developer Edition:
→ Die Extension als `.zip` verpacken und als selbst-signierte Extension installieren.

## Was die Extension macht

- Blockiert Netzwerk-Requests an bekannte Ad-Domains (Google Ads, DoubleClick, etc.)
- Entfernt Ad-Elemente aus dem YouTube-DOM (Banner, Overlays, Feed-Ads)
- Überspringt Video-Ads automatisch (Skip-Button oder ans Ende spulen)
- Zählt wie viele Ads geblockt wurden (persistent über Browser-Neustarts)
- Toggle zum Ein-/Ausschalten im Popup
