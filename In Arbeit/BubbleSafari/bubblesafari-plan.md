# Bubble Safari – Bauplan

Roblox-Spiel im Genre [[Fang-und-Gehege]]: **Blasebalg treten → Riesen-Seifenblase pusten → Blase treibt durchs Tal → ein Tier springt hinein → Tier ins Gehege → Geld pro Sekunde → bessere Seife und Blasebalg kaufen → weiter pusten.**

Eigener Twist gegenüber den Vorbildern: kein Werfen, keine Waffe – **Seifenblasen**. Das Tier wird nicht gefangen, sondern *schwebt in einer Blase* zum eigenen Gehege. Dazu der **Mischkessel**: zwei gleiche Tiere → eine wertvollere Variante.

- Zielgruppe: alle Altersgruppen (niedlich und bunt, aber mit Sammel-Tiefe). Handy zuerst, PC/Konsole auch.
- Stil: Block-/Voxel-Stil, Kopf groß, Körper kurz (siehe [[Kreaturen-Pets]]). Kräftige Pastellfarben, Seifenblasen schillernd.
- Sprache: Texte zuerst Deutsch, Englisch per LocalizationTable in Phase 5.
- Alle Zahlen hier sind **Startwerte** – im Spieltest anpassen und hier nachtragen.

---

## 1. Die Spielschleife

1. **Trainieren** am **Blasebalg** auf dem eigenen Grundstück → XP → Stufe → **Pustkraft** steigt.
2. **Pusten** am eigenen Pustplatz an der Talkante: senkrechter Puste-Balken, im richtigen Moment tippen → „PERFEKT!“.
3. **Flug:** Die Blase treibt mit dem Wind das Tal entlang, die Kamera fliegt mit. Oben live: Biom-Name, Weite, **Glücks-Multiplikator**.
4. **Fang:** Wo die Blase langsamer wird, springt ein Tier hinein. **Enthüllung** mit hochzählender Chance und Lückenwort.
5. **Zurück:** Die Blase mit Tier schwebt zurück (Kamera springt zurück, Blase kommt am Grundstück an) → Tier landet im **Rucksack**.
6. **Gehege:** Tier aufs Grundstück stellen → $/s. Oder verkaufen oder im **Mischkessel** kombinieren.
7. Geld → bessere **Seife** (weiter + mehr Glück), besserer **Blasebalg** (mehr XP), **mehr Gehege-Plätze**.

Eine Runde (pusten bis Tier im Rucksack) dauert **8–15 Sekunden**.

---

## 2. Welt-Aufbau

```
          Hub (Seifenladen, Event-NPC, Bestenliste, Spawn)
                         |
  [G1][G2][G3][G4][G5][G6][G7][G8]   <- 8 Grundstücke in einer Reihe
  ===P1==P2==P3==P4==P5==P6==P7==P8=== <- Talkante mit 8 Pustplätzen
  \                                     /
   \___ Tal, 10.400 Studs lang, 8 Biome ___  ->
```

- **8 Grundstücke nebeneinander** an der Talkante, jedes direkt hinter seinem Pustplatz → kein Laufweg zwischen Pusten, Gehege und Training.
- **Hub** mittig hinter der Reihe: Spawn (schaut aufs Tal), **Seifenladen**, Event-NPC, Bestenliste, Index-Tafel. Alles in ≤ 10 s Laufweite.
- **Tal** gerade, ~300 Studs breit, Seitenwände als Block-Klippen mit Erdschichten. Jedes Biom eigener Boden, eigene Deko, eigene Landmarke (riesiger Pilz, Kaktus, Vulkan …), Schild mit Biom-Name am Übergang.
- Server-Max-Spieler = 8. Maßstab nach [[Welt-Map]]: Wege ≥ 12 Studs, Figur ~5 Studs.
- **Streaming:** Tal-Biome als Modelle mit `ModelStreamingMode = Persistent` nur für Landmarken; Rest normal streamen. Kamera-Flug lädt voraus (`RequestStreamAroundAsync` am Zielpunkt beim Pusten). Siehe [[Roblox-Fallen]].

---

## 3. Training: der Blasebalg

Riesiger Block-Blasebalg auf einem Kreis am Boden. Spieler stellt sich drauf → Figur tritt in Schleife drauf, Luft pufft als Schaumwölkchen raus, fliegende „+2 XP“. HUD unten: Balken „Stufe 6 – 15/56“, rot **HALT**, gelb **AUTO** (Gamepass). Alle 20–40 s eine **x2-Blase** an zufälliger Bildschirmstelle: antippen → 10 s doppelte XP (sie platzt mit Plopp).

Aufstufen an Ort und Stelle: Preis schwebt über dem Kreis; hineinlaufen mit genug Geld → „Auf Kupfer-Blasebalg verbessert!“, sonst „Nicht genug Geld!“. Gleiche Form, nur **Material/Farbe** wechselt.

| Stufe | Blasebalg | Preis | XP pro Tritt |
|---|---|---|---|
| 1 | Holz | 50 | 2 |
| 2 | Kupfer | 2.500 | 8 |
| 3 | Lila Samt | 60K | 20 |
| 4 | Kristall | 1,5M | 50 |
| 5 | Obsidian mit Glut | 40M | 120 |
| 6 | Regenbogen-Schaum | 1B | 300 |

- Ein Tritt alle **0,8 s**.
- XP-Bedarf für Spielerstufe L: **`L² + 5·L`** (L1 → 6, L10 → 150, L50 → 2.750).
- **Pustkraft(L) = 10 + 2·(L−1) + 0,05·(L−1)²** (L1 → 10, L20 → 66, L50 → 228).
- Stufenaufstieg: „STUFE ERHÖHT! Pustkraft +3“ (konkreten Gewinn nennen), Konfetti aus Seifenblasen.
- Hinweis „Zu leicht!“ neben dem Blasebalg, wenn ein Tritt < 1 % des XP-Bedarfs gibt → schubst zum nächsten Kauf.

---

## 4. Pusten

- Pustplatz = runde Plattform an der Talkante mit Blasenring-Gestell. Draufstellen → Figur hält einen Blasenstab, Text „Tippe zum Pusten!“.
- **Puste-Balken** senkrecht, Zeiger fährt hoch/runter. Zonen: Schwach (×0,7), Gut (×1,0), **PERFEKT (×1,15)** – Perfekt-Zone schmal, oben.
- **Serie:** Jeder PERFEKT-Puster in Folge → +10 % Glück (max. +50 % bei Serie 5). Anzeige „Serie x3 · +30 % Glück“.
- **Weite (Studs) = Pustkraft × 10 × Seifen-Weite × Pust-Qualität.**
- Die Blase wächst beim Pusten sichtbar an (0,5 s), löst sich, steigt leicht und treibt los. Farbe/Schimmer = ausgerüstete Seife.

**Server-Sicherheit:** Server schickt Startzeit + Geschwindigkeit des Zeigers; Client meldet nur den Tipp-Zeitpunkt; Server rechnet die Qualität selbst (±100 ms Toleranz). Weite, Biom, Glück und Tier werden **sofort beim Pusten auf dem Server** gezogen; der Flug ist nur Anzeige. Abklingzeit pro Spieler = Flugdauer.

---

## 5. Seifen (Ausrüstung)

Kauf im **Seifenladen** (Hub): Karten mit Seife, Seltenheit, Werten, „AUSRÜSTEN / AUSGERÜSTET“. Neue Seife freigeschaltet → Popup „NEUE SEIFE! Du kannst jetzt kaufen: Glitzerseife – 400K – LADEN“.

| # | Seife | Preis | Weite | Glück-Bonus | Blasen-Look |
|---|---|---|---|---|---|
| 1 | Kernseife | gratis | ×1,0 | – | durchsichtig, leicht weiß |
| 2 | Honigseife | 500 | ×1,3 | – | goldgelb |
| 3 | Minzseife | 15K | ×1,7 | +10 % | mintgrün |
| 4 | Glitzerseife | 400K | ×2,2 | +25 % | Glitzerpartikel |
| 5 | Lavendelseife | 10M | ×2,8 | +50 % | lila, Duftwölkchen |
| 6 | Sternenseife | 250M | ×3,6 | +100 % | dunkelblau mit Sternen |
| 7 | Regenbogenseife | 6B | ×4,6 | +200 % | schillernd bunt |
| 8 | Wolkenschaum | 150B | ×6,0 | +400 % | weiß-golden, Lichtspur |

---

## 6. Biome und Glück

Glück wächst innerhalb jedes Bioms linear vom Start- zum End-Wert. Hinter dem Tal-Ende (ab 10.400) steigt Glück langsam weiter: +1X pro 500 Studs, max. 60X (Ziel für Endlos-Spieler).

| # | Biom | Weite (Studs) | Glück | Stimmung / Landmarke | Phase |
|---|---|---|---|---|---|
| 1 | Blumenwiese | 0–600 | 1X → 2X | rosa-grün, Riesen-Gänseblümchen | 1 |
| 2 | Pilzwald | 600–1.400 | 2X → 4X | dämmrig, leuchtende Riesenpilze | 1 |
| 3 | Sumpf | 1.400–2.400 | 4X → 7X | Nebel, Seerosen, krumme Bäume | 1 |
| 4 | Wüste | 2.400–3.600 | 7X → 11X | Dünen, Riesenkaktus, Oase | 3 |
| 5 | Schneeberge | 3.600–5.000 | 11X → 16X | Schneefall, Eiskristall-Turm | 3 |
| 6 | Vulkan | 5.000–6.600 | 16X → 22X | dunkler Himmel, Lavafälle | 3 |
| 7 | Korallenriff | 6.600–8.400 | 22X → 30X | **Blase taucht unter**: alles blau, Neon-Korallen, Lichtstrahlen | 4 |
| 8 | Wolkenreich | 8.400–10.400 | 30X → 40X | **Blase steigt auf**: über den Wolken, Regenbogenbrücken | 4 |

- Spätere Biome wechseln die **ganze Stimmung** (unter Wasser, über den Wolken), nicht nur die Farbe.
- **Flug-HUD:** oben mittig „PILZWALD · 3,21X Glück“, darunter Weite „1.050 m“; Biom-Wechsel mit kurzem Banner.
- **Flugdauer = 3 + 7·√(Weite / 10.400) s** (max. 10 s); Blase wird schneller, je weiter sie fliegt.

---

## 7. Tiere

### Seltenheit und Chance

| Seltenheit | Grundgewicht | Namensfarbe | Aussehen |
|---|---|---|---|
| Gewöhnlich | 2 × 30 | weiß | Naturfarben, keine Effekte |
| Ungewöhnlich | 25 | grün | kleine Deko |
| Selten | 10 | blau | Fantasiefarbe, Hut/Muster |
| Episch | 4 | lila | Element-Deko, leichtes Glühen |
| Legendär | 0,9 | gold | groß, Glühen, 1 Extra-Animation |
| Mythisch | 0,1 | rot-pink, schimmernd | riesig, Aura + Partikel, 2 Extra-Animationen |

**Glück anwenden:** Gewicht von Selten und höher × Glück, Ungewöhnlich × √Glück; Gewöhnlich bekommt den Rest (mindestens 10 %, sonst alles anteilig skalieren). Gezogen wird nur auf dem Server ([[System-Rezepte]] „Zufall mit Gewichtung“). Angezeigt wird „1 in N“ für die Kombination aus Art × Größe × Material.

### Größe (eigener Zufallswurf)

| Größe | Chance | Skalierung | Einkommen |
|---|---|---|---|
| normal | 90 % | ×1 | ×1 |
| **GROSS** | 8,5 % | ×1,6 | ×4 |
| **RIESIG** | 1,5 % | ×2,6 | ×9 |

Glück erhöht GROSS/RIESIG leicht (× √Glück, max. 25 % / 5 %). Seltene Arten sind schon in Normalgröße größer als gewöhnliche.

### Material (Mischkessel)

| Material | Natürlich gefangen | Durch Mischen | Einkommen |
|---|---|---|---|
| Normal | Rest | – | ×1 |
| **Gold** | 2 % | 2 × Normal | ×3 |
| **Diamant** | 0,2 % | 2 × Gold | ×8 |
| **Regenbogen** | nie | 2 × Diamant | ×20 |

- **Mischkessel** auf jedem Grundstück: zwei Tiere gleicher **Art + Größe + Material** hineinlegen → 3 s Blubbern, Kessel schäumt über → eine Stufe höher. Mischen lohnt sich immer (Gold ×3 > 2 × ×1 usw.).
- Gleiches Modell, nur Material/Farbe + Partikel: Gold = golden mit Funkeln, Diamant = hellblau-durchscheinend, Regenbogen = Farbverlauf, der wandert.

### Einkommen

**$/s = Biom-Basis × Seltenheit × Größe × Material**

- Biom-Basis: Wiese 1 · Pilzwald 6 · Sumpf 40 · Wüste 250 · Schnee 1.600 · Vulkan 10K · Riff 65K · Wolken 400K
- Seltenheit: Gewöhnlich ×1 · Ungewöhnlich ×2 · Selten ×5 · Episch ×12 · Legendär ×30 · Mythisch ×100
- Beispiel: Rosenpfau (Wiese, Legendär) GROSS Gold = 1 × 30 × 4 × 3 = **360 $/s**.

### Tierliste (7 pro Biom = 56 Arten)

Echte Tiere + Biom-Twist, Block-Stil. **Phase 1 = die ersten 4 jedes Bioms 1–3 (12 Arten).**

| Biom | Gewöhnlich | Gewöhnlich | Ungewöhnlich | Selten | Episch | Legendär | Mythisch |
|---|---|---|---|---|---|---|---|
| Blumenwiese | Wiesenhase (Gänseblümchen am Ohr) | Blütenlamm (Blumenkranz) | Blumenigel (Blüten statt Stacheln) | Pusteblumen-Fuchs (Schweif aus Löwenzahn-Flaum) | Blütenhirsch (Geweih mit Blüten) | Rosenpfau (Rad aus Rosen) | Frühlings-Einhorn (Blumenmähne) |
| Pilzwald | Moosmaus | Fliegenpilz-Kröte | Pilzhut-Waschbär | Moos-Dachs | Glimmer-Eule (leuchtende Pilze an den Flügeln) | Pilzkönig-Bär (Pilzkappe als Krone) | Wurzelgeist-Elch (Geweih aus Wurzeln, Sporen-Aura) |
| Sumpf | Seerosen-Frosch | Schilf-Ente | Moos-Schildkröte | Nebelotter | Seerosen-Krokodil | Irrlicht-Reiher (Lichtkugeln am Schnabel) | Nebelschlange (halb durchsichtig) |
| Wüste | Kaktus-Springmaus | Sandechse | Kaktus-Schildkröte | Sandschal-Fennek | Oasen-Kamel (Palme auf dem Höcker) | Sonnenmähnen-Löwe | Sand-Sphinxkatze |
| Schneeberge | Schneehase | Mützen-Pinguin | Eisrobbe | Schal-Polarfuchs | Eiszapfen-Yak | Polarlicht-Wolf (Mähne in Polarlicht-Farben) | Gletscher-Greif |
| Vulkan | Glut-Salamander | Ascheziege | Magma-Schnecke | Lava-Nashorn | Obsidian-Gürteltier | Phönix | Vulkandrache |
| Korallenriff | Korallen-Krabbe | Seepferdchen | Korallenhut-Kugelfisch | Riff-Meeresschildkröte (Korallen auf dem Panzer) | Leucht-Rochen | Perlen-Oktopus | Riff-Wal (ganzes Riff auf dem Rücken) |
| Wolkenreich | Wolkenschaf | Regenbogen-Spatz | Gewitter-Wiesel | Sternen-Katze | Wind-Pegasus | Sonnen-Koi (fliegt) | Himmelsdrache aus Seifenschaum |

**Geheim (Phase 4):** 3 Geheim-Tiere (z. B. „Blubber-Qualle“ aus purem Schaum), nur mit Regenbogenseife oder besser + PERFEKT-Serie 5, Chance ~1 in 50.000, in jedem Biom ab Vulkan.

**Bau der Modelle:** Ein gemeinsamer Grundkörper pro Körperform (Vierbeiner klein/groß, Vogel, Fisch, Schlange) per Skript aus Blöcken; Art entsteht durch Farbe + 2–4 Anbauteile (Ohren, Hut, Blüten). Gewöhnlich: nur hüpfen/laufen. Legendär/Mythisch: +Flügelschlag/Schweif/Glühen. Größe per `Model:ScaleTo()`.

---

## 8. Enthüllung

Ablauf (~3 s normal, bis ~6 s bei sehr seltenen):

1. Blase wird langsam, ein **Schatten springt hinein** – drinnen nur Silhouette. Blase **schimmert in der Seltenheitsfarbe** und wackelt (je seltener, desto stärker).
2. Oben „1 in 5“, **der Zähler klettert live**, während sich das Lückenwort füllt („P_U_TEBL_MEN-FUCHS“).
3. Überschrift steigert sich mit (eigene Titel): – → **„Glück!“** (orange) → **„Riesenglück!“** (pink, Strahlenkranz) → **„Blasenwahn!“** (türkis, Schaumflocken regnen) → **„Regenbogenglück!!“** (alles schillert, Ring-Schockwelle).
4. Plopp-Effekt, Silhouette wird farbig: Name in Seltenheitsfarbe, darüber Material („GOLD“), darunter Größe („RIESIG“) und $/s. Schild **„NEU!“** (erstes Mal) oder **„NEUER BESTER!“**.
5. Sehr seltene Fänge (ab 1 in 500) werden **zu Hause zweimal gefeiert**: große Karte oben „DU HAST GEFANGEN – …“ + Server-Meldung im Chat für alle.

---

## 9. Grundstück, Gehege, Rucksack

**Grundstück** (gleich für alle): Zaun + Eingang, Holzschild „<Name>s Safari“, darüber schwebend **Avatar + Name + $/s** (soziale Bestenliste in der Welt). Darauf: Blasebalg, Mischkessel, Gehege-Fläche, Ausbau-Schild.

- **Gehege-Plätze:** Start 6. Ausbau-Schild am Zaun „6 > 8 PLÄTZE – 1K“.

| Ausbau | 6→8 | →10 | →12 | →14 | →16 | →18 | →20 |
|---|---|---|---|---|---|---|---|
| Preis | 1K | 25K | 500K | 10M | 200M | 4B | 80B |

- Tiere laufen frei herum (Client-seitig bewegt), Schild mit Name + $/s, RIESIGE überragen den Zaun → Aushängeschild.
- **Geld:** fließt automatisch aufs Konto (kein Einsammeln), fliegende „+$12“ über dem Gehege alle 5 s.
- **Rucksack:** 10 Plätze (später +5 per Ausbau), Leiste unten mittig mit Kacheln (Bild, $/s, Material-Schild). Voll → „Rucksack voll! Stelle Tiere ins Gehege oder verkaufe sie.“
- **Menü „Meine Tiere“:** Liste mit Bild, Name, $/s, Knöpfe **INS GEHEGE / RAUS / VERKAUFEN / MISCHEN**, Zähler „6/8“, großer Knopf **„Beste aufstellen“**, „Alle Gewöhnlichen verkaufen“. Verkaufspreis = 30 × $/s.

---

## 10. Shop, Event, Extras

- **Seifenladen** (Hub, Markise in Seifenblau, NPC Seifenhändlerin): Seifen, später Rucksack-Ausbau.
- **Event „Schaumparty“:** alle 30 Min für 5 Min (Uhrzeit-Rechnung wie [[System-Rezepte]] „Shop mit Restock-Timer“ → alle Server gleich). Countdown-Symbol unten rechts. Während der Party: Himmel pink-violett, Schaum rieselt, Musik schneller; jedes gefangene Tier bringt **Schaumperlen** mit („+1 SCHAUMPERLE!“). Event-NPC **Bademeister-Walross** am Hub tauscht Perlen gegen Glückstränke, Event-Seife und ein Event-Tier.
- **Glückstrank:** 5 Min ×2 Glück (aus Event, Login-Belohnung oder Robux).
- **Tägliche Login-Belohnung** (7 Tage), **Tier-Index** pro Biom mit Silhouetten + Belohnung bei vollem Biom ([[System-Rezepte]] „Sammelbuch“).
- **Robux (fair, Phase 5):** Gamepässe AUTO-Training, AUTO-Pusten, ×2 Geld, +5 Rucksack; Developer Products Glückstrank, Super-Puster (garantiert Episch oder besser). Siehe [[Monetarisierung]].

---

## 11. UI

| Bereich | Inhalt |
|---|---|
| Oben links | Geld (groß) + $/s, Schaumperlen (nur im Event) |
| Links | Knöpfe: Tiere, Seifen, Index, Shop, Einstellungen |
| Unten mittig | Rucksack-Leiste; beim Training Balken + HALT/AUTO; beim Pusten Puste-Balken |
| Oben mittig | im Flug: Biom + Glück + Weite; sonst Meldungen |
| Unten rechts | Event-Countdown, Glückstrank-Zeit |

Große Knöpfe, kurze Texte, Zahlen gekürzt (K, M, B, T, Qa). Erste 60 Sekunden: Pfeil zum Blasebalg → 10 s trainieren → Pfeil zum Pustplatz → erster Puster ist garantiert ein Wiesenhase → Pfeil „Ins Gehege“ ([[Menüs-Onboarding]]).

---

## 12. Technik

- Neuer, eigener Place (nicht Himmelsinseln). Gebaut über den Roblox-Studio-MCP, Skripte als Dateien in `BubbleSafari/Scripts/` = Quelle der Wahrheit ([[Architektur]]).
- Daten-Tabellen zentral in `ReplicatedStorage/Daten`: `Biome`, `Tiere`, `Seifen`, `Blasebaelge`, `Ausbau`.
- Speichern mit ProfileStore + Session-Lock ([[Daten-Speichern]]). Spielerdaten: Geld, XP, Stufe, Seife(n), Blasebalg-Stufe, Gehege-Plätze, Tiere (Liste mit Art, Größe, Material, im Gehege ja/nein), Index, Login, Schaumperlen.
- Tier im Datensatz: `{ art = "Rosenpfau", groesse = 2, material = 1, gehege = true, id = "…" }`.
- Blase + Flug + Enthüllung nur Client; Server schickt Ergebnis vorab, Client spielt ab. Gehege-Tiere Client-seitig bewegt.

---

## 13. Bauphasen

**Phase 1 – spielbarer Kern** (Ziel: 15 Minuten Spielspaß)
- Map: Hub-Platz + 4 Grundstücke + 4 Pustplätze + Tal mit Biomen 1–3 (einfach, je 1 Landmarke)
- Blasebalg Stufe 1–3 mit XP, Stufen, fliegenden Zahlen, HALT
- Pusten mit Balken + PERFEKT, Blasenflug mit Kamera + Flug-HUD
- 12 Tiere (je 4 aus Wiese, Pilzwald, Sumpf), Ziehen mit Glück, einfache Enthüllung (Name, $/s)
- Rucksack + Gehege (6 Plätze) + Geld pro Sekunde; Seifen 1–3 im Laden
- Speichern
- **Fertig, wenn:** man vom Wiesenhasen bis in den Sumpf kommt und das Speichern hält.

**Phase 2 – Sammeln macht Spaß**
- Biome 1–3 mit allen 7 Arten, Größen GROSS/RIESIG, Enthüllung mit Live-Zähler + Titeln + Silhouette
- „Meine Tiere“-Menü, Verkaufen, Beste aufstellen, Gehege-Ausbau, Index, PERFEKT-Serie, x2-Blase, Onboarding

**Phase 3 – Mischkessel und Mittelteil**
- Mischkessel + Gold/Diamant/Regenbogen, Biome 4–6 mit Tieren, Seifen 4–6, Blasebalg 4–5, alle 8 Grundstücke

**Phase 4 – Stimmungswechsel und Event**
- Korallenriff (Unterwasser) + Wolkenreich, Seifen 7–8, Blasebalg 6, Geheim-Tiere, Endlos-Glück hinter dem Tal
- Event „Schaumparty“ + Walross-NPC, Login-Belohnung, Bestenliste am Hub, Doppelt-Feiern seltener Fänge

**Phase 5 – Veröffentlichen**
- Ton + Musik, Handy-Feinschliff, Englisch, Robux-Angebote, Balance-Runden, Spiel-Symbol + Vorschaubilder, öffentlich stellen

---

## Offene Punkte

- [ ] **Name prüfen:** „Bubble Safari“ war schon ein bekanntes Facebook-Spiel (Zynga, 2012, Blasen-Schießen). Vor dem Veröffentlichen auf Roblox klären oder leicht abwandeln (z. B. „Bubble Safari Zoo“).
- [ ] Zahlen nach Phase 1 im Spieltest prüfen (Zeit bis Pilzwald ~5 Min, bis Sumpf ~15 Min als Ziel).
