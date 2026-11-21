---
typ: website
status: entwurf fertig
technik: HTML/CSS/JS, eine Datei, keine Abhängigkeiten
erstellt: 2026-11-13
---

Professionelle Neufassung der Website-Demo für das Café Reitschule (München-Schwabing). Gedacht als Vorzeige-Beispiel, was mit Claude Code möglich ist.

- Neue Version: [[cafereitschule-v2.html]] (Ordner `In Arbeit/CafeReitschule/`)
- Alte Version zum Vergleich: `website/cafereitschule.html`
- Lokal ansehen: Server im Ordner `Games` starten, dann `http://localhost:8765/In%20Arbeit/CafeReitschule/cafereitschule-v2.html`

## Was neu ist (gegenüber v1)

- Ruhiges Vollbild-Hero mit Parallax statt Scroll-Sperre, Info-Leiste (Status, heutige Zeiten, Adresse, Telefon)
- Live-Öffnungsstatus (Münchner Zeit), heutiger Tag hervorgehoben, „Gerade jetzt“-Markierung bei den Tageszeiten
- Speisekarte mit Kategorien, Live-Suche über alle Kategorien, Kennzeichnung V / VG / Empfehlung
- Events & Räume (Orangerie, Lounge, Studio, Panorama-Terrasse) – „Anfrage stellen“ füllt das Formular vor
- Galerie mit Lightbox (Pfeiltasten, Wischen, Esc)
- Reservierungsformular mit Uhrzeit-Slots je nach Wochentag, Validierung, Bestätigungsansicht (Demo, sendet nichts)
- Handy: Burger-Menü, untere Leiste „Anrufen / Tisch reservieren“

## Redesign 2026-11-21 (Hallmark, Theme „Broadside“)

- Neues Design: Druck-/Plakat-Look wie eine Speisekarte: Buff-Papier, Holzlettern (Six Caps, Bevan) + Archivo Narrow, ein Zinnoberrot, Fotos schwarzweiß im Doppelrahmen
- Signatur: heutige Öffnungszeit live in roter Holzschrift unter der Überschrift
- Nav: schwarze Info-Leiste (Status, Adresse, Telefon) über der Menüleiste, fährt beim Scrollen weg
- Tageszeiten als Plakatspalten, Räume als Zeilen, Galerie und Gästestimmen als waagerechte Leisten, Reservierung auf rotem Band
- Entfernt (Theme ist „still“): Marquee, Parallax, Zähl-Animation, Scroll-Reveals, laufende Bewertungsspalten
- Unsplash-Bilder ersetzt durch frei lizenzierte Wikimedia-Platzhalter (Credits im Footer)
- Bestätigungsansicht ehrlich formuliert („es wurde nichts gesendet“), keine erfundene Vorgangsnummer mehr
- Alte Version gesichert: `CafeReitschule/.hallmark/cafereitschule-v2.before.html`, Vergleich: `.hallmark/compare.html`

## Offene Punkte

- [ ] Echte Fotos vom Café statt der Wikimedia-Platzhalter (Hero, Gastraum, 8 Galeriebilder)
- [ ] Echte Bewertungen statt Demo-Texten
- [ ] Reservierung an echtes System anbinden (z. B. OpenTable) oder per E-Mail
- [ ] Impressum/Datenschutz-Links füllen

## Notizen

- Bis 2026-11-21: Farben und Schriften wie v1 (Elfenbein, Grün, Terrakotta; DM Serif Display + Outfit), seitdem Broadside-Theme
- Holzschrift-Zeilen sind per CSS in `cqi` eingepasst (gemessene Werte). Ändert sich ein Text, muss der `--fit`-Wert neu gemessen werden
