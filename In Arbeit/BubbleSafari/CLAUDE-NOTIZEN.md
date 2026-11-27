# Bubble Safari – Roblox-Spiel (Notizen für Claude)

Fang-und-Gehege-Spiel: Blasebalg treten → Seifenblase pusten → Blase treibt durchs Tal (8 Biome mit Glücks-Multiplikator) → Tier springt hinein → Gehege → Geld pro Sekunde. Extra: Mischkessel (3 gleiche Tiere → Gold → Diamant → Regenbogen). Enthüllung: erst Tier-Sicht (Ich-Perspektive des Tiers, Fischauge + Vignette, läuft auf die Blase zu), dann Bodenkamera an der Blase (Tier läuft vorbei hinein) – Vorbild Clip des Users vom 27.11.2026; die Blase dehnt sich für große Tiere.

**Stand:** Plan vom User abgesegnet (27.11.2026), noch nichts gebaut. Als Nächstes Phase 1. Bauplan: `bubblesafari-plan.md` (Zahlen, Tierliste, Phasen).

## Arbeitsweise
- **Vorher lesen:** `Notizen/Roblox-Wissen/Roblox-Wissen.md` (+ passende Notiz) und für das Aussehen `Notizen/Design-Bibliothek/Fang-und-Gehege.md`, `Kreaturen-Pets.md`, `Trainings-Objekte.md`.
- Eigenes, separates Projekt – **nicht** im Place von Himmelsinseln bauen. Neuen Place anlegen, Name/placeId hier eintragen.
- Gebaut über den Roblox-Studio-MCP: zuerst `list_roblox_studios` (ID wechselt bei jedem Neustart), `list_roblox_skills` + passende Skills laden, bauen per `execute_luau`, prüfen per `screen_capture`.
- Skripte als Dateien in `BubbleSafari/Scripts/` = Quelle der Wahrheit; Änderungen in Studio immer zurückschreiben.
- Daten-Tabellen (Biome, Tiere, Seifen, Blasebälge, Ausbau) nur einmal zentral in `ReplicatedStorage/Daten`; Werte aus dem Plan übernehmen und Änderungen im Plan nachtragen.
- Server entscheidet alles (Weite, Glück, Tier, Geld) beim Pusten; Flug + Enthüllung nur Client-Anzeige.

## Design-Regeln
- Kein Nachbau der Vorbilder: keine fremden Namen, Figuren, Titel-Texte oder Memes. Eigene Titel: Glück! → Riesenglück! → Blasenwahn! → Regenbogenglück!!
- Block-Stil, Kopf groß; Art = gemeinsamer Grundkörper + Farbe + Anbauteile; Größe per `ScaleTo`, Material als Variante.
- Name „Bubble Safari“ vor Veröffentlichung prüfen (älteres Zynga-Spiel gleichen Namens).

## Place
- (noch nicht angelegt)
