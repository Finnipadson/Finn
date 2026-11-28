# Bubble Safari – Roblox-Spiel (Notizen für Claude)

Fang-und-Gehege-Spiel: Blasebalg treten → Seifenblase pusten → Blase treibt durchs Tal (8 Biome mit Glücks-Multiplikator) → Tier springt hinein → Gehege → Geld pro Sekunde. Extra: Mischkessel (3 gleiche Tiere → Gold → Diamant → Regenbogen). Enthüllung: erst Tier-Sicht (Ich-Perspektive des Tiers, Fischauge + Vignette, läuft auf die Blase zu), dann Bodenkamera an der Blase (Tier läuft vorbei hinein) – Vorbild Clip des Users vom 27.11.2026; die Blase dehnt sich für große Tiere.

**Stand:** Phase 1 fertig (27.11.), Phase 2 weitgehend fertig (28.11.2026): 21 Tiere (je Biom 7), GROSS/RIESIG, Silhouette + Strahlenkranz + Blase dehnt sich in Stößen, Gehege-Ausbau mit Animation (Server baut Gehege), Index mit Belohnung, x2-Blase, Einführung (Wegweiser), Option „Schnelle Enthüllung“. Offen: x2-Klick im Test nicht sicher bestätigt; Test-Spielstand enthält Test-Tiere (zurücksetzen?); Detail-Runde Biome 1–3. Studio-Testschalter: Attribute TestArt/TestGroesse am Spieler (nur Studio). Als Nächstes Phase 2 (Sammeln: alle Arten Biom 1–3, GROSS/RIESIG, Titel-Effekte, Gehege-Ausbau mit Animation, Index, x2-Blase, Onboarding). Bauplan: `bubblesafari-plan.md` (Zahlen, Tierliste, Phasen).

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
- Roblox-Cloud (Team Create): „biggfishh0's Ort: 11272026_1“, placeId 90918630565426, universeId 10779421839. Speichern per `save_place`.
- Spieleinstellungen: Studio-API-Zugriff ist an (DataStore im Test). **Offen:** Max. Spieler auf 4 stellen (Game Settings, nicht per Skript möglich).

## Skripte einspielen (schnell, ohne Code doppelt zu schicken)
- Dateien in `Scripts/` sind die Quelle: `ReplicatedStorage/Daten.lua`, `TierModelle.lua`, `ServerScriptService/Spieldaten.lua`, `Server.server.lua`, `StarterPlayerScripts/Client.client.lua`, `Bauen/Map.lua` (Welt einmalig bauen), `Bauen/Deploy.lua`.
- Lokalen Server im Ordner `Scripts/` starten (Hintergrund): `python -m http.server 8765 --bind 127.0.0.1`. Domain `127.0.0.1:8765` steht in der MCP-HTTP-Allowlist (vom User freigegeben).
- Einspielen: `execute_luau` (Edit) → `return loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8765/Bauen/Deploy.lua?t="..os.clock()))()` – prüft Syntax und setzt alle Sources.
- Welt neu bauen: gleich mit `Bauen/Map.lua` (löscht `Workspace/Map` und baut neu).

## Aufbau (Phase 1)
- Kessel + Schlucht (seit 28.11.2026), Boden überall Y=0, Klippen bis Y=45: Kessel X −150…150, Z −200…0; Grundstücke X −108/−36/36/108 bei Z −150 (66×80); Spawn (0, −85); Laden (−70, −60), Brunnen (70, −60); **Wurfplatz** `Map/Wurfplatz/Platte` bei (0, −12), 26×18; Schlucht X −50…50 (100 breit), Z 0…2420 (Wiese 0–600, Pilzwald 600–1400, Sumpf 1400–2420); unsichtbare Sperre bei Z 2. Client-Konstante `SB = 50` muss zu `Map.lua` passen.
- Grundstück: `GehegeFlaeche`, `TrainKreis`, `BlasebalgAnker` (Server baut `Blasebalg`), `AufwertenSchild` (ProximityPrompt), `SchildAnker` (Name + $/s), `GehegeTiere` (Server legt Modelle an, Client lässt sie herumlaufen).
- Server entscheidet beim Pusten sofort Weite/Biom/Glück/Tier und speichert; Client spielt Flug → Tier-Sicht → Bodenkamera → Ergebnis ab und versteckt das neue Tier bis dahin im Rucksack (`versteckAb`).
- Speichern: eigener UpdateAsync + Session-Lock (`Spieldaten.lua`), Store `BubbleSafari_v1`. `SeifenBesitz` mit String-Schlüsseln (DataStore mag keine Lücken in Arrays).
- Holz-Blasebalg ist gratis (Plan sagte 50 $), damit neue Spieler sofort trainieren können.

## Test-Fallen (MCP)
- `screen_capture` ist verkleinert: Viewport war 2092×1153, Bild 1920×1058 → Klick-Koordinaten über `AbsolutePosition` des Knopfs ermitteln, nicht aus dem Bild ablesen.
- `require` in `execute_luau` lädt eine eigene Modul-Kopie → Spielerdaten des laufenden Servers sind darüber nicht erreichbar.
- ProximityPrompts sind auf `screen_capture`-Bildern nicht zu sehen; Auslösen per `user_keyboard_input` E klappt.

## Phase 2b (28.11.2026): Karte im Stil der Vorbild-Karte
- Vorlage: `Notizen/Design-Bibliothek/Welt-Map.md` → „Ziehe einen Dino – Stil der ganzen Karte“ (45 Standbilder ausgewertet).
- Kessel: Grün-Schachbrett 10er-Kacheln, oranger Kachelweg (Hauptweg x −6…6, z −104…−32; Querweg z −110…−100), Holz-**Wurfdeck** `Map/Wurfplatz/Platte` (28×24, Oberkante y 2,6, Treppe Richtung Kessel), Blasen-Start (0, 9, 0).
- Ladenstraße: `Hub/Seifenladen`, `Hub/VerkaufStand` (öffnet Tiere), `Hub/IndexStand` (öffnet Index) – je `Theke` mit ProximityPrompt; `Hub/Bestenliste/Tafel` (Server schreibt Top 5 nach $/s alle 5 s); Laternen; Wahrzeichen Blasenstab + Seifenflasche.
- Grundstück: `Boden` ist unsichtbar (nur Bezugspunkt), `NamensSchild` (SurfaceGui vom Server), `SchildAnker` (große Zahlen „x / y“ + $/s), Trainingsplatz `Steinmatte` + Holz-`TrainKreis` mit Zackenring, `AufwertenSchild` = gelbe Scheibe; Gehege + Holzzaun baut der Server.
- Schlucht: Holzbogen mit Biom-Namen, Baumstämme/Steine (`Kleinkram`). Flug: Zonenleiste links (`zonenLeiste()` im Client).
- **Voxel-Umbau (28.11., Vorlage `Bauen/Probe.lua` bei X=1000 + TVA-Video):** Kessel und Schlucht haben 3 Terrassen nach außen (`terrasse()` in `Map.lua`, T=16 tief, Höhen 27/54/81, `RAND`=81, `AUSSEN`=48), Noppen (`SurfaceType.Studs` auf Plastic) auf Böden/Gras, Voxel-Bäume/Pilze/Sonnenblumen auf jeder Stufe, Biom-Stil je Schluchtabschnitt, schwebende Inseln. Rand-Deko/Wahrzeichen stehen hinter `SB+AUSSEN`. ~25k Teile.
- **Flacker-Falle:** Teile mit gleicher Außenfläche dürfen sich nicht überlappen (Z-Fighting). Flecken haben eigene Höhenzeilen, Tropfen eigene 4-Stud-Plätze, Gras-Überhang wird an Ecken gekürzt (`trimA/trimB`). Prüfskript: Boxen von Fleck/Tropfen/TerrasseGras paarweise auf Überlappung + gleiche Fläche testen.
- Offen aus 2b: Tier-Details (Bewegung, Aura).