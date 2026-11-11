# Plan: Speicherplatz-Karte, Programm-Updates, Downloads aufräumen

Grundregeln (wie bisher): Bestehende Funktionen bleiben unverändert. Nichts wird ohne
Bestätigung verändert, nichts wird gelöscht. Startet ohne Adminrechte.

## 1. Speicherplatz-Karte (neue Seite „Speicher“)

- Neuer Menüpunkt **Speicher** (nach „Ergebnisse“).
- Auswahl: Laufwerk (C:, D: …) oder „Ordner wählen …“, Knopf „Analysieren“, Abbrechen möglich.
- Scan im Hintergrund (`DiskMapService`): nur Ordner werden als Knoten gespeichert, pro Ordner
  die 40 größten Dateien einzeln, der Rest als „n weitere Dateien“ → wenig Speicherverbrauch
  auch bei Millionen Dateien. Verknüpfte Ordner (Junctions/Symlinks) werden nicht verfolgt
  (keine Doppelzählung). „Nur online“-Dateien von OneDrive zählen nicht als belegter Platz.
  Nicht lesbare Ordner werden gezählt und angezeigt.
- Anzeige: **Kachelkarte** (squarified Treemap, eigenes Steuerelement mit `OnRender`),
  Kachelgröße = Größe; Ordner farbig (Graphit-Töne), Dateien grau. Hover = Name + Größe,
  Klick auf Ordner = hineinzoomen, Pfadleiste („C:\ › Users › …“) zum Zurückgehen.
- Rechts: Liste der größten Einträge im aktuellen Ordner mit Größe, Anteil-Balken, Anzahl Dateien.
- Aktionen: „Im Explorer zeigen“. Kein Löschen auf dieser Seite (dafür gibt es Scan/Ergebnisse).

## 2. Programm-Updates (neuer Tab „Updates“ auf der Seite Programme)

- `WingetService`: ruft `winget upgrade --include-unknown` auf und liest die Tabelle
  (Spaltenpositionen aus der Kopfzeile, funktioniert auch mit deutscher winget-Ausgabe).
  Abgeschnittene IDs („…“) werden erkannt und nicht aktualisiert.
- Tabelle: Haken, Name, Installiert, Verfügbar, Quelle. **Standardmäßig nichts ausgewählt.**
- „Ausgewählte aktualisieren“ → Bestätigungsdialog (Hinweis: Programme vorher schließen,
  Installer können selbst nach Adminrechten fragen) → nacheinander
  `winget upgrade --id <Id> --exact --silent --accept-package-agreements --accept-source-agreements`.
  Fortschritt + Ergebnis pro Zeile, Eintrag im Protokoll.
- Ohne winget: verständlicher Hinweis statt Fehler.

## 3. Downloads aufräumen (neuer Menüpunkt „Downloads“)

- Gleiches Prinzip wie Desktop: lose Dateien im Downloads-Ordner (nicht in Unterordnern) per
  Ordnerregeln (Optionen → „Dateityp → Ordner“) in Unterordner sortieren.
- Vorhandene Unterordner werden erkannt (auch über Alias-Namen). Zielordner pro Datei änderbar.
- Liegen bleiben: laufende Downloads (.crdownload, .part, .partial, .download, .tmp),
  versteckte/System-Dateien (desktop.ini), gesperrte Dateien, optional zu neue Dateien
  (Auswahl „alle“ / „älter als 1 / 7 / 30 Tage“).
- Übernehmen mit Bestätigung, Verlauf + **Rückgängig** (eigener Verlauf „Downloads-Verlauf“,
  getrennt vom Desktop-Verlauf), Protokolleinträge.
- Technik: `DownloadsPlanner` nutzt die vorhandenen Ordnerregeln, `UniquePath` und den
  `DesktopApplier` (ohne Symbolansicht) – der Desktop-Verlauf bleibt unberührt.

## Navigation

- Seitenleiste bekommt zwei Einträge mehr → Navigation scrollt bei kleinen Fenstern, damit
  bei Mindesthöhe nichts abgeschnitten wird.

## Tests

- Treemap-Layout (Flächen proportional, nichts außerhalb, keine Überlappung).
- DiskMap-Scan in einem Testordner (Summen, Junction nicht verfolgt, kleine Dateien gebündelt).
- winget-Tabelle parsen (englisch, deutsch, abgeschnittene ID, Fortschrittszeichen davor).
- Downloads: Regeln, laufende Downloads bleiben, Altersfilter, vorhandene Ordner/Alias,
  Übernehmen + Rückgängig im Testordner, Desktop-Verlauf bleibt getrennt.
