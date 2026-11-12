---
typ: spiel
status: fertig
technik: HTML5, vanilla JS (Single-File)
speicher: localStorage kopfsache_v1
---

Denkspiel: Sudoku, Kopfrechnen, Schachrätsel und Form-Puzzle zufällig gemischt. Welten à 10 Level (Level 10 = Boss mit 3 Rätseln), Daily, Training, Erfolge.

- Spiel: [[kopfsache.html]]
- Modus darin: [[Burgwacht]] (im Kopfsache-Menü verlinkt)
- Schachrätsel-Sammlung (`CHESS_BANK`) wird mit Node-Skripten in `Games/Games/tools/kopfsache/` erzeugt/geprüft

## Offene Punkte

- [ ] **Neuer Rätseltyp: Farben sortieren (Röhren/Gläser)**, Idee vom 12.11.2026
	- Mehrere Röhren mit gemischten Farbschichten, dazu 1–2 leere Röhren
	- Antippen = oberste Schicht nehmen, zweites Antippen = drauflegen. Geht nur auf die gleiche Farbe oder in eine leere Röhre, solange Platz ist
	- Ziel: jede Röhre enthält nur noch eine Farbe
	- Schwierigkeit über Anzahl Farben/Röhren und Füllhöhe; Level-Generator muss garantiert lösbare Rätsel erzeugen (z. B. vom gelösten Zustand rückwärts mischen)
	- Passt in die gemischten Welten, ins Daily und ins Training wie die anderen Rätseltypen
	- Ideen: Rückgängig-Knopf, Zugzähler mit Sternen, Boss-Variante mit verdeckten Schichten

## Notizen

-
