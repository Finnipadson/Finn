import type { Format } from "./typen";
import beispiel from "../../beispiele/pythagoras.json";

/* Anleitung für Claude: wie ein Drehbuch aussieht und wie der Sprechertext klingen soll. */

export const VORLAGEN: Record<string, { name: string; hinweis: string }> = {
  mathe: {
    name: "Mathe / Schule",
    hinweis: "Erkläre für Schülerinnen und Schüler der 7. bis 10. Klasse. Beginne mit einer Frage oder einem Alltagsbezug, erkläre die Idee anschaulich, zeige ein konkretes Rechenbeispiel mit kleinen, glatten Zahlen (Baustein „formel“ mit „schritte“; bei rechtwinkligen Dreiecken auch „geometrie“) und ende mit einem Merksatz.",
  },
  tech: {
    name: "Tech-Erklärung",
    hinweis: "Erkläre ein Technik-Thema für interessierte Laien. Starte mit dem Problem, zeige den Unterschied zum Bekannten (Baustein „vergleich“), erkläre den Ablauf in Schritten (Baustein „ablauf“), nenne die wichtigsten Punkte (Baustein „stichpunkte“) und schließe mit einer klaren Kernaussage. Bei Software, Apps oder KI zeigt der Baustein „fenster“ (Chat oder Terminal), wie es aussieht; bei Entwicklungen über die Zeit passt „zeitstrahl“.",
  },
  produkt: {
    name: "Produkt-Intro",
    hinweis: "Stelle ein Produkt, eine App oder ein Projekt vor: Problem → Lösung → drei Vorteile (Baustein „stichpunkte“) → wie es funktioniert (Baustein „ablauf“, Form „kette“) → Abschluss mit Aufforderung. Begeisternd, aber ehrlich, keine Superlative ohne Grund. Nur Eigenschaften nennen, die im Thema stehen.",
  },
};

const BAUSTEINE = `
Szenen-Bausteine („typ“) und ihre Felder. Alle Szenen haben „sprecher“ (Pflicht) und optional „kicker“ (kleine Überzeile) und „ueberschrift“.
- "titel": "titel" (2–4 Wörter), "unter" (optional, kurz). Immer die erste Szene.
- "stichpunkte": "punkte": 1–5 Einträge mit "text" (max. 3 Wörter), "unter" (max. 5 Wörter), "icon", "bei".
- "vergleich": "links" (das Alte/Schlechte) und "rechts" (das Neue/Gute), je mit "titel", "icon", "bei", "punkte" (2–3 Einträge mit "text" max. 5 Wörter und "bei").
- "ablauf": "schritte": 2–6 Einträge mit "text" (1–2 Wörter), "icon", "bei"; "form": "kreis" (Schleife) oder "kette" (nacheinander); optional "fehler" {"text","bei"} und "erfolg" {"text","bei"} für „klappt erst nicht, dann doch“.
- "formel": "teile": Formel in Stücken mit "text" (Symbole erlaubt, z. B. "a²", "+", "=") , "farbe", "bei"; optional "schritte": Rechenschritte mit "text" und "bei"; optional "merke": {"bei"} rahmt die Formel ein.
- "geometrie": NUR für rechtwinklige Dreiecke. "a", "b" (Zahlen, Katheten), optional "beschriftung" {"a","b","c"}; Momente als Objekte mit "bei": "dreieck", "katheten", "hypotenuse", "quadrate", "raster", "werte".
- "zeitstrahl": "ereignisse": 2–6 Einträge mit "zeit" (z. B. "1991", "Früher", "Schritt 1"; max. 12 Zeichen), "text" (max. 4 Wörter), "icon" (optional), "bei". Für Geschichte, Entwicklungen, Reihenfolgen über die Zeit.
- "fenster": "art": "terminal" (Befehle eintippen, Ausgaben erscheinen) oder "chat" (Sprechblasen), "titel" (Titelleiste, optional), "zeilen": 1–6 Einträge mit "text" (max. 60 Zeichen), "rolle": "ich" (Eingabe/eigene Nachricht, wird getippt) oder "antwort" (Ausgabe/Antwort), "bei". Für Software, Apps, KI, Programmieren.
- "abschluss": "text" (Merksatz oder Kernaussage, max. 6 Wörter), "unter" (optional), "bei". Immer die letzte Szene.
Icons: chat, datei, stift, terminal, haken, kreuz, idee, buch, karte, lupe, wegweiser, schild, stern, person, blitz, herz, zahnrad, uhr, rakete, ziel.
Farben (für "farbe"): a (cyan), b (gelb), c (rot), akzent, text, gruen, rot, blau, lila.`;

const REGELN = (format: Format, sekunden: number) => `
Regeln:
1. Antworte NUR mit dem JSON-Objekt. Kein Markdown, keine Erklärung davor oder danach.
2. Felder oben: "titel", "format": "${format}", "stimme", "tempo" (Zahl, meist -3 bis 0), "musik": true, "szenen".
3. ${sekunden <= 40 ? "4–5" : sekunden <= 70 ? "5–7" : "6–9"} Szenen, Gesamtlänge etwa ${sekunden} Sekunden (≈ ${Math.round(sekunden * 2.2)} gesprochene Wörter insgesamt).
4. Sprechertext („sprecher“): Liste von Sätzen {"satz", "pause" (0.2–0.7 Sekunden danach), optional "tempo" (z. B. -5 für einen wichtigen Satz)}.
   - Klingt wie ein Mensch, der es einem Freund erklärt: kurze Sätze (höchstens 12 Wörter), direkte Ansprache mit „du“, auch mal eine Frage, natürliche Übergänge („Okay“, „Und jetzt“, „Also“).
   - NUR Wörter und normale Ziffern. Keine Symbole oder Formeln im gesprochenen Text: schreibe „a Quadrat“ statt „a²“, „Wurzel aus 25“ statt „√25“, „Prozent“ statt „%“, „plus“/„gleich“ statt „+“/„=“.
   - Keine Abkürzungen mit Punkt (schreibe „zum Beispiel“ statt „z. B.“), keine einzelnen Gedankenstriche, keine Emojis.
   - Kommazahlen als Wort („zwei Komma fünf“) oder vermeiden.
5. „bei“ koppelt ein Bild-Element an ein gesprochenes Wort DERSELBEN Szene: genau EIN Wort, so geschrieben wie im Satz, ohne Satzzeichen. Kommt das Wort mehrmals vor: "Wort#2" für das zweite Vorkommen. Wähle das Wort, bei dem das Element inhaltlich drankommt. Jedes Element einer Szene sollte ein „bei“ haben.
6. Bildschirmtexte sind kurz und knackig (siehe Bausteine), der Sprechertext erklärt die Details.
7. Fachlich korrekt. Keine erfundenen Zahlen oder Fakten.
8. Bei Produkten, Apps, Spielen oder Projekten: Behaupte NUR, was im Thema steht. Erfinde keine Plattform („App“, „im Store“), keinen Preis („kostenlos“), keine Verfügbarkeit, Nutzerzahlen oder Bewertungen. Fehlt etwas, lass es weg oder formuliere neutral („Probier es aus“).`;

export const baueAnleitung = (opts: { thema: string; vorlage: string; format: Format; stimme: string; sekunden: number }) => {
  const v = VORLAGEN[opts.vorlage] ?? VORLAGEN.tech;
  return `Du schreibst Drehbücher für kurze animierte Erklärvideos (Motion Graphics, deutsche Sprecherstimme, Wort-für-Wort-Untertitel).
Ein Programm macht aus deinem Drehbuch automatisch das Video. Deshalb muss das JSON exakt dem Format entsprechen.

Thema: ${opts.thema}
Stil-Vorlage: ${v.name}. ${v.hinweis}
Format: ${opts.format === "hoch" ? "Hochformat 9:16 (TikTok/Reels)" : "Querformat 16:9 (YouTube)"} · Stimme: "${opts.stimme}"
${BAUSTEINE}
${REGELN(opts.format, opts.sekunden)}

Beispiel für ein gutes Drehbuch (anderes Thema, nur zur Orientierung für Aufbau, Ton und „bei“):
${JSON.stringify(beispiel)}

Schreibe jetzt das Drehbuch zum Thema „${opts.thema}“. Nur das JSON.`;
};

export const baueKorrektur = (vorher: string, fehler: string[]) =>
  `Das folgende Drehbuch hat Fehler, die das Programm nicht verarbeiten kann:
${fehler.map((f) => `- ${f}`).join("\n")}

Korrigiere genau diese Fehler und gib das vollständige, korrigierte Drehbuch zurück. Nur das JSON, nichts sonst.
Tipp: Jedes „bei“ muss exakt ein Wort aus dem Sprechertext derselben Szene sein; im Sprechertext keine Symbole.

Drehbuch:
${vorher}`;

/** Nur EINE Szene überarbeiten („Szene neu machen“): Claude bekommt das ganze Drehbuch als Kontext. */
export const baueSzenenAnleitung = (d: { titel: string; format: Format; szenen: unknown[] }, index: number, wunsch: string) =>
  `Du überarbeitest EINE Szene in einem Drehbuch für ein kurzes animiertes Erklärvideo (Motion Graphics, deutsche Sprecherstimme).
Ein Programm macht aus dem Drehbuch automatisch das Video. Deshalb muss das JSON exakt dem Format entsprechen.
${BAUSTEINE}

Regeln:
1. Antworte NUR mit dem JSON-Objekt der EINEN neuen Szene (mit "typ", "sprecher" usw.). Kein Markdown, keine Erklärung, nicht das ganze Drehbuch.
2. Setze den Wunsch um. Alles, was der Wunsch nicht betrifft, bleibt möglichst wie bisher. Den Baustein-Typ nur wechseln, wenn der Wunsch es verlangt.
3. Die Szene muss zu den Szenen davor und danach passen (Übergänge, keine Wiederholungen).
4. Sprechertext: kurze Sätze (höchstens 12 Wörter), Ansprache mit „du“, NUR Wörter und normale Ziffern, keine Symbole („a Quadrat“ statt „a²“, „Prozent“ statt „%“), keine Abkürzungen mit Punkt, keine einzelnen Gedankenstriche, keine Emojis. Jeder Satz: {"satz", "pause" (0.2–0.7), optional "tempo"}.
5. „bei“ = genau EIN Wort aus dem Sprechertext DIESER Szene, ohne Satzzeichen; bei Wiederholung "Wort#2". Jedes Element sollte ein „bei“ haben.
6. Fachlich korrekt, nichts erfinden (keine Preise, Plattformen, Zahlen, die nicht im Drehbuch stehen).

Ganzes Drehbuch (Format: ${d.format === "hoch" ? "Hochformat" : "Querformat"}):
${JSON.stringify(d)}

Zu überarbeiten: Szene ${index + 1} von ${d.szenen.length}:
${JSON.stringify(d.szenen[index], null, 1)}

Wunsch: ${wunsch}

Gib jetzt nur das JSON-Objekt der neuen Szene ${index + 1} zurück.`;

export const baueSzenenKorrektur = (vorher: string, fehler: string[]) =>
  `Diese Szene hat Fehler, die das Programm nicht verarbeiten kann:
${fehler.map((f) => `- ${f}`).join("\n")}

Korrigiere genau diese Fehler und gib die vollständige, korrigierte Szene zurück. Nur das JSON-Objekt der Szene, nichts sonst.
Tipp: Jedes „bei“ muss exakt ein Wort aus dem Sprechertext dieser Szene sein; im Sprechertext keine Symbole.

Szene:
${vorher}`;
