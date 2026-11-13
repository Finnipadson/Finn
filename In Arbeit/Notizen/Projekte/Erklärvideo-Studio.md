---
typ: app
status: idee
technik: Windows-App + Claude Code (Pro-Abo) + Remotion + edge-tts + FFmpeg
erstellt: 2026-11-13
---

Windows-App, die aus einer kurzen Beschreibung automatisch ein fertiges animiertes Erklärvideo macht: Sprecherstimme, Untertitel, Geräusche, Musik. *Name ist ein Arbeitstitel.*

- Herkunft: Idee „Text → animiertes Video“ in [[Ideen]] (Tests, Technik-Details, Qualitäts-Stufe stehen dort)
- Bisherige Testvideos (Code in `Desktop\Claude\remotion\src\…`, Videos in `remotion\out\`):
	- Erklaervideo Test („Bug-Küche EP 01“)
	- Satz des Pythagoras
	- Koch Szene HD (Qualitäts-Stufe, 60 fps)
	- Claude Code Erklaerung (Querformat, 7 Szenen, echte Screenshots)
- Bauplan: [[erklaervideo-studio-plan]] (Phasen 0–5, Drehbuch als JSON aus Szenen-Bausteinen)

## Ablauf in der App

1. **Thema eingeben** + Vorlage wählen (Mathe/Schule, Tech-Erklärung, Produkt-Intro)
2. **Drehbuch prüfen**: Sprechertext + Szenenliste anzeigen, Sätze ändern, Szenen löschen/umstellen
3. **Einstellungen**: Sprecher wählen + probehören (Standard Ava), Format (Hoch/Quer), Design-Thema (Tafel, Dunkel-Neon, Papier, Küche), Musik an/aus, Tempo
4. **Vorschau**, einzelne Szenen neu machen („Szene 3 langsamer“)
5. **Rendern**: MP4 + automatisches Cover-Bild

## Technik

- **Claude Code** schreibt Drehbuch + Animation, die App ruft es im Hintergrund auf (`claude -p "…"`) → läuft über das Pro-Abo (Weg 1). Nur für eigene Nutzung; zum Weitergeben bräuchte es einen API-Schlüssel
- **Szenen-Bibliothek**: fertige Bausteine (Titel, Formel, Diagramm, Vergleich, Schritt-Liste, Zeitstrahl, Fenster/Terminal, Screenshot-Karten), Claude setzt sie zusammen
- **Ton** (`audio.py`-Prinzip): Stimme per edge-tts satzweise mit Pausen, Wärme-EQ, Raumklang; Geräusche synthetisch; Musik mit Ducking; eine gemeinsame Zeitliste (`events.json`) für Bild + Ton
- **Remotion** rendert (React), 60 fps, CRF 16

## Grenzen

- Motion Graphics und Erklär-Animationen; kein Film-Look, keine realistischen Szenen (dafür bräuchte es z. B. Runway)

## Offene Punkte

- [x] Technik der Oberfläche: **lokale Web-App im eigenen Fenster** (React + Remotion-Player für Live-Vorschau), bestätigt 13.11.2026
- [x] Bauplan mit Phasen schreiben
- [ ] Szenen-Bibliothek aus den Testvideos herauslösen (wiederverwendbare Bausteine)
- [ ] Echte lizenzfreie Musik statt synthetischer Akkorde
- [ ] Remotion-Ordner auf GitHub sichern

## Notizen

-
