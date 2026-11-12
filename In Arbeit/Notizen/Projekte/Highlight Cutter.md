---
typ: app
status: idee
technik: offen (Vorschlag: C# WPF oder Python + FFmpeg)
erstellt: 2026-11-12
---

PC-App, in die man NVIDIA-Bildschirmaufnahmen (ShadowPlay/NVIDIA App) lädt und die daraus automatisch die Highlights wie Kills herausschneidet. *Name ist nur ein Arbeitstitel.*

- Datei/Ordner: noch keiner
- Bauplan: noch keiner (Vorlage *Spielplan* bzw. eigener Plan, wenn es losgeht)
- Verwandt: [[PC Aufräumer]] erkennt Spielaufnahmen schon beim Scan

## Ziele

- Aufnahme(n) per Drag & Drop oder Ordnerauswahl laden (Standard: `Videos\NVIDIA`)
- Highlights automatisch finden: Kills, Mehrfach-Kills, Siege/Runden-Ende …
- Gefundene Stellen als Liste mit Vorschau anzeigen, einzeln an- und abwählen, Start/Ende anpassen
- Export: einzelne Clips und/oder ein zusammengeschnittenes Highlight-Video

## Wie Highlights erkannt werden könnten

- **Kill-Feed/HUD erkennen**: Bildausschnitt (z. B. Kill-Feed oben rechts) pro Spiel auswerten, per Bildvergleich (Template-Matching) oder Texterkennung (OCR). Am genauesten, muss aber pro Spiel eingerichtet werden.
- **Ton auswerten**: Kill-Sounds, Schüsse und laute Stellen erkennen. Funktioniert spielübergreifend, ist aber ungenauer.
- **Kombination**: Ton als Vorfilter, Bild als Bestätigung.
- Schneiden mit **FFmpeg** (schnell und ohne Qualitätsverlust per Stream-Copy, genau auf den Frame nur mit Neu-Kodierung).

## Offene Fragen

- [ ] Für welche Spiele zuerst? (Davon hängt die Kill-Erkennung ab.)
- [ ] Wie viele Sekunden vor/nach einem Kill sollen in den Clip?
- [ ] Nur Clips oder auch fertiges Montage-Video (mit Musik, Übergängen)?
- [ ] Technik: C# WPF (wie PC Aufräumer) oder Python?
- [ ] NVIDIA hat für manche Spiele eine eigene „Highlights“-Funktion: Was soll die App besser machen?

## Notizen

-
