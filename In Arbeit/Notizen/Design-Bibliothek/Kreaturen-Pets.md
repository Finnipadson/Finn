# Kreaturen-Pets

Zurück: [[Design-Bibliothek]]

Wie Haustiere, Begleiter und sammelbare Kreaturen in Roblox-Hits **aussehen** (Mechanik dazu: [[Items-Loot]], [[Objekte-Mechaniken]]). Für die Begleiter in [[Himmelsinseln]] und Modelle aus [[Blender-Modelle]].

## Was alle erfolgreichen Spiele gemeinsam haben

- **Voxel-/Block-Stil:** Fast alle Pets sind aus sichtbaren Würfeln gebaut (wie Minecraft), keine glatten, detaillierten Modelle. Wenig Dreiecke, läuft auf jedem Handy, Dutzende gleichzeitig auf dem Bildschirm.
- **Kopf groß, Körper kurz:** Kindchenschema – großer Kopf, große Augen (oft weiße Quadrate mit schwarzem Punkt), kurze Beine. Selbst Raubtiere (T-Rex, Wolf) wirken eher niedlich.
- **Ein Tier = eine Hauptfarbe:** Jede Kreatur hat eine klare Grundfarbe (Ente grün/braun, Magma-Ankylo rot, Pachy lila) plus 1–2 Akzentfarben. An der Silhouette + Farbe sofort erkennbar, auch klein im Gehege.
- **Echte Tiere als Basis, ein Twist dazu:** Ente, Frosch, Dinosaurier, Löwe, Vogel – bekannte Tiere, die jeder sofort erkennt, und dann ein Zusatz: Laterne auf dem Kopf (Laternen-Frosch), Krone und Umhang (königlicher Löwe), Zaubererhut (Fuchs), Lava-Risse (Magma-Ankylo).
- **Name sagt Element + Tier:** „Magma Ankylo“, „Inferno-Spino“, „Kristall-…“, „Gold-…“ – das Element im Namen passt zu Farbe und Deko.

## Seltenheit am Aussehen

| Seltenheit | Wie man es sieht |
|---|---|
| Gewöhnlich / Ungewöhnlich | normales Tier, natürliche Farben, keine Effekte |
| Selten / Episch | kräftigere Fantasiefarbe (lila, türkis), kleine Deko (Hut, Muster) |
| Legendär | Element-Thema mit Glühen (Lava, Feuer, Kristall), Kronen, Rüstung |
| Mythisch / Divine / Geheim | riesig, eigene Form, Aura oder Partikel, Regenbogen-Rahmen im Shop |

## Varianten statt neuer Modelle

- **Gold-, Regenbogen-, Ruby-Varianten** desselben Tiers: gleiches Modell, nur Material/Farbe getauscht („GOLD Allosaurus“, „RAINBOW LEGENDARY Red Planet Rex“). Spart enorm viel Modellier-Arbeit und vervielfacht die Sammelliste.
- **Größe als Variante:** „Big“, „Huge“, „Unendlich“ – dasselbe Tier, nur skaliert, mit mehr Wert.
- Name + Wert schweben über jedem Tier im Gehege („GOLD Allosaurus $360/s“).

## Referenzen

### Steal An Egg

![[stealanegg-ei-shop.jpg]]
![[stealanegg-vogel.jpg]]

- Ei-Shop zeigt die Stufen gut: gewöhnliche Tiere (Tier im Narrenkostüm, Wolf in Ritterrüstung, Bison) in Naturfarben → Zauberer-Fuchs mit Hut (12 %) → Schneeleopard mit Eis-Kristallen (6,5 %) → **königlicher Löwe mit Krone, roter Mähne und Gold-Rüstung (0,5 %, DIVINE)**. Je seltener, desto mehr Kostüm und Gold.
- Frisch geschlüpfter Vogel: einfarbig gelb, ganz aus kleinen Blöcken, läuft direkt hinter dem Spieler her.

### Ziehe einen Dino

![[dino-pachy-episch.jpg]]
![[dino-magma-ankylo.jpg]]
![[dino-gold-varianten.jpg]]

- Pachycephalosaurus (episch): ganz in **Lila** statt Naturfarbe – Seltenheit durch Fantasiefarbe.
- Magma Ankylo (ungewöhnlich): rot-orange, eckig wie ein Block, Stacheln oben – Element Lava in Farbe und Name.
- Im Gehege: viele **Gold-Varianten** (Gold-Protoceratops, Gold-Allosaurus) neben normalen Dinos in Rot, Blau, Lila.

### Fische für geheime Tiere

![[geheimtiere-ente.jpg]]
![[geheimtiere-laternenfrosch.jpg]]
![[geheimtiere-goldriese.jpg]]

- Ente (Common, $5/s): klassische Stockente in Grün/Braun, große Würfel-Augen.
- Frosch mit **leuchtender Laterne an einem Stab** (wie ein Anglerfisch) – bekanntes Tier + witziger Twist; Name als Lückenwort.
- Seltener Fang (1 in 3.242): riesige **goldene Statue-Kreatur**, viel größer als normale Tiere – Seltenheit durch Größe + Gold.

### Silhouetten im Index (Steal An Egg, Ziehe einen Dino)

![[stealanegg-index-tempel.jpg]]

- Noch nicht gefundene Tiere erscheinen als **schwarze Silhouette** – und trotzdem erkennt man Flügel, Hörner, Schwanz. Ein gutes Pet muss also **schon als Schattenriss eindeutig** sein (Test: Modell komplett schwarz einfärben – erkennt man noch, was es ist?).

## Checkliste: neues Pet entwerfen

1. **Basis-Tier**, das jeder kennt (Ente, Frosch, Wolf, Dino, Eule …).
2. **Ein Twist** passend zu Element/Gebiet (Laterne, Lava-Risse, Eis-Kristalle, Krone).
3. **Hauptfarbe + 1–2 Akzente** festlegen; Hauptfarbe darf sich nicht mit anderen Pets im selben Gebiet doppeln.
4. **Proportionen:** Kopf ca. ⅓–½ der Gesamthöhe, große Augen, kurze Beine.
5. **Silhouetten-Test** (schwarz einfärben) bestehen.
6. **Blockig/Low-Poly** halten: für Roblox grob unter ~2.000 Dreiecke pro Pet anpeilen (viele gleichzeitig sichtbar). (Richtwert von uns, nicht offiziell.)
7. **Seltenheit** über Farbe/Deko/Größe/Effekt ausdrücken (Tabelle oben), nicht nur über den Namen.
8. **Varianten** gleich mitdenken: Gold, Regenbogen, Groß – gleiches Modell, anderes Material/Skalierung.
9. **Name** = Element + Tier, kurz und auf Deutsch aussprechbar.
10. Bewegung: einfaches **Hüpfen/Watscheln** beim Folgen reicht (siehe [[System-Rezepte]] „Haustier folgt“).

## Für Himmelsinseln (Ideen)

- Begleiter pro Element-Insel: bekanntes Tier + Element-Twist (Lava-Salamander, Eis-Eule, Kristall-Käfer, Dschungel-Frosch).
- Gold-/Regenbogen-Varianten statt vieler neuer Modelle.
- Stil: Bosse dürfen detailliert sein (Blender-Modelle), **Begleiter sollten einfach und blockig** bleiben – es laufen viele gleichzeitig herum.
