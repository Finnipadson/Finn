# Design-Bibliothek

Bewährte Design-Muster aus erfolgreichen Spielen – als **Inspiration, nicht zum Kopieren**. Übernommen wird das *Prinzip* (Hierarchie, Abstände, Farblogik, Timing), umgesetzt mit eigenen Formen, Farben und Texten.

**Für Claude:** Vor Design-Arbeit an einem Spiel diese Seite lesen, dann nur die 1–2 passenden Themen-Notizen und gezielt 2–3 Bilder daraus. Nicht alles auf einmal laden.

## Themen

| Notiz | Wofür |
|---|---|
| [[Game-Feel]] | Treffer, Schüsse, Sprünge: Screenshake, Hit-Stop, Partikel, Sound |
| [[UI-HUD]] | Lebensbalken, Munition, Schadenszahlen, Minimap, Lesbarkeit |
| [[Items-Loot]] | Seltenheit, Tooltips, Inventar, Belohnungsmomente |
| [[Gegner-Bosse]] | Ankündigen (Telegraphing), Phasen, Fairness |
| [[Menüs-Onboarding]] | Hauptmenü, Pause, Einstellungen, die ersten 60 Sekunden |
| [[Welt-Map]] | Map-Aufbau: Spawn, Hub, Wege, Zonen, Grundstücke, Maßstab |
| [[Objekte-Mechaniken]] | Objekte in der Welt: Laufbänder, Gehege, Stände, Portale, Sammelobjekte |
| [[Kreaturen-Pets]] | Aussehen von Haustieren/Begleitern: Stil, Farben, Seltenheit am Aussehen, Varianten |

Spiele zum Screenshot-Sammeln: [[Screenshot-Liste]]

## Bilder

- Ordner: `Design-Bibliothek/Bilder/<Thema>/` (z. B. `Bilder/UI-HUD/`)
- Dateiname: `spiel-was.jpg`, z. B. `hades2-boon-auswahl.jpg`
- **Ausschnitt** statt Vollbild, JPG, max. ~1280 px breit
- In der Themen-Notiz einbetten mit `![[hades2-boon-auswahl.jpg]]` + 2–3 Zeilen, *was* daran gut ist (Vorlage: *Design-Referenz*)
- Der Ordner `Bilder/` ist per `.gitignore` vom öffentlichen GitHub-Repo ausgeschlossen (fremde Screenshots nicht veröffentlichen). Gesichert bleibt er über OneDrive.

## Regeln

1. Eine Referenz ohne Notiz „warum gut“ ist wertlos – immer dazuschreiben.
2. Nach Thema sortieren, nicht nach Spiel.
3. Was sich in einem eigenen Projekt bewährt oder als Falle herausstellt → in die Themen-Notiz unter „Fallen“ bzw. „Bei uns umgesetzt“.
