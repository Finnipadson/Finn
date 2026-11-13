import { SZENEN_TYPEN, STIMMEN, type Drehbuch, type Szene, type Timing, type Wort } from "./typen";

/* Prüft ein Drehbuch und liefert verständliche Fehlermeldungen (leer = alles ok). */

export const norm = (s: string) => s.toLowerCase().replace(/[^\p{L}\p{N}]/gu, "");

/** Alle „bei“-Angaben einer Szene (rekursiv), mit Pfad für Fehlermeldungen. */
export const alleBei = (sz: unknown, pfad = ""): { pfad: string; wert: string }[] => {
  const out: { pfad: string; wert: string }[] = [];
  const walk = (v: unknown, p: string) => {
    if (Array.isArray(v)) v.forEach((x, i) => walk(x, `${p}[${i}]`));
    else if (v && typeof v === "object") {
      for (const [k, x] of Object.entries(v)) {
        if (k === "sprecher") continue;
        if (k === "bei" && typeof x === "string") out.push({ pfad: `${p}.bei`, wert: x });
        else walk(x, p ? `${p}.${k}` : k);
      }
    }
  };
  walk(sz, pfad);
  return out;
};

const tokens = (sz: Szene) => sz.sprecher.flatMap((s) => s.satz.split(/\s+/).filter(Boolean));

/** Findet ein „bei“-Wort ("Wort" oder "Wort#2") in einer Wortliste, gibt den Index zurück oder -1. */
export const findeBei = (woerter: string[], bei: string) => {
  const [wort, nr] = bei.split("#");
  const n = Math.max(1, Number(nr ?? 1) || 1);
  let treffer = 0;
  for (let i = 0; i < woerter.length; i++) {
    if (norm(woerter[i]) === norm(wort) && ++treffer === n) return i;
  }
  return -1;
};

export const pruefeDrehbuch = (d: unknown): string[] => {
  const f: string[] = [];
  if (!d || typeof d !== "object") return ["Das Drehbuch ist kein JSON-Objekt."];
  const db = d as Partial<Drehbuch>;
  if (!db.titel) f.push("Es fehlt der Titel („titel“).");
  if (db.format !== "hoch" && db.format !== "quer") f.push("„format“ muss \"hoch\" oder \"quer\" sein.");
  if (db.stimme && !STIMMEN[db.stimme]) f.push(`Unbekannte Stimme „${db.stimme}“ (möglich: ${Object.keys(STIMMEN).join(", ")}).`);
  if (!Array.isArray(db.szenen) || db.szenen.length === 0) return [...f, "Es gibt keine Szenen („szenen“)."];

  db.szenen.forEach((sz, i) => {
    const wo = `Szene ${i + 1}`;
    if (!sz || typeof sz !== "object") return f.push(`${wo}: ist kein Objekt.`);
    if (!SZENEN_TYPEN.includes(sz.typ as never)) return f.push(`${wo}: unbekannter Typ „${String(sz.typ)}“ (möglich: ${SZENEN_TYPEN.join(", ")}).`);
    if (!Array.isArray(sz.sprecher) || sz.sprecher.length === 0) return f.push(`${wo} (${sz.typ}): Es fehlt der Sprechertext („sprecher“).`);
    sz.sprecher.forEach((s, j) => {
      if (!s?.satz?.trim()) f.push(`${wo}: Satz ${j + 1} ist leer.`);
      else if (s.satz.split(/\s+/).some((t) => t && !norm(t))) f.push(`${wo}: Satz ${j + 1} enthält ein „Wort“ ohne Buchstaben (z. B. einzelner Gedankenstrich) – bitte entfernen.`);
      else if (/[²³√=+×÷%<>{}[\]|^~*/\\#]/.test(s.satz)) f.push(`${wo}: Satz ${j + 1} („${s.satz}“) enthält Symbole – im Sprechertext nur Wörter und Ziffern (z. B. „a Quadrat“ statt „a²“).`);
    });
    const need = (ok: unknown, was: string) => { if (!ok) f.push(`${wo} (${sz.typ}): ${was}`); };
    switch (sz.typ) {
      case "titel": need(sz.titel, "Es fehlt „titel“."); break;
      case "stichpunkte": need(Array.isArray(sz.punkte) && sz.punkte.length >= 1 && sz.punkte.length <= 5, "„punkte“ braucht 1–5 Einträge."); break;
      case "vergleich": need(sz.links?.titel && sz.rechts?.titel, "„links“ und „rechts“ brauchen je einen „titel“."); break;
      case "ablauf": need(Array.isArray(sz.schritte) && sz.schritte.length >= 2 && sz.schritte.length <= 6, "„schritte“ braucht 2–6 Einträge."); break;
      case "formel": need(Array.isArray(sz.teile) && sz.teile.length >= 1, "„teile“ braucht mindestens einen Eintrag."); break;
      case "geometrie": need(sz.a > 0 && sz.b > 0, "„a“ und „b“ müssen positive Zahlen sein."); break;
      case "abschluss": need(sz.text, "Es fehlt „text“."); break;
    }
    const w = tokens(sz as Szene);
    for (const b of alleBei(sz)) {
      if (findeBei(w, b.wert) < 0) f.push(`${wo}: „bei“: "${b.wert}" (${b.pfad}) kommt im Sprechertext dieser Szene nicht vor.`);
    }
  });
  return f;
};

/** Alles, was den Ton beeinflusst. Ändert sich das, muss die Stimme neu erzeugt werden. */
export const tonSchluessel = (d: Drehbuch) =>
  JSON.stringify({
    stimme: d.stimme ?? "ava", tempo: d.tempo ?? 0, musik: d.musik ?? true,
    szenen: d.szenen.map((s) => ({ sprecher: s.sprecher, bei: alleBei(s).map((b) => b.wert) })),
  });

/** Wörter einer Szene als Auswahl für „bei“ ("Wort" bzw. "Wort#2" bei Wiederholung). */
export const beiOptionen = (sz: Szene) => {
  const zaehler = new Map<string, number>();
  const out: string[] = [];
  for (const tok of sz.sprecher.flatMap((s) => s.satz.split(/\s+/).filter(Boolean))) {
    const wort = tok.replace(/^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$/gu, "");
    if (!norm(wort)) continue;
    const n = (zaehler.get(norm(wort)) ?? 0) + 1;
    zaehler.set(norm(wort), n);
    out.push(n === 1 ? wort : `${wort}#${n}`);
  }
  return out;
};

/** Geschätztes Timing ohne Stimme – für die sofortige Vorschau. */
export const schaetzeTiming = (d: Drehbuch, fps = 60): Timing => {
  const woerter: Wort[] = [];
  const szenen: Timing["szenen"] = [];
  let t = 0.6;
  d.szenen.forEach((sz, k) => {
    const start = k === 0 ? 0 : t - 0.4;
    const eigene: Wort[] = [];
    for (const s of sz.sprecher) {
      for (const tok of s.satz.split(/\s+/).filter(Boolean)) {
        const dauer = 0.12 + norm(tok).length * 0.055;
        eigene.push({ text: tok, start: t, end: t + dauer, szene: k });
        t += dauer + 0.04;
      }
      t += s.pause ?? 0.35;
    }
    t += 0.5;
    const bei: Record<string, number> = {};
    for (const b of alleBei(sz)) {
      const i = findeBei(eigene.map((x) => x.text), b.wert);
      if (i >= 0) bei[b.wert] = eigene[i].start;
    }
    woerter.push(...eigene);
    szenen.push({ start, ende: 0, bei });
  });
  szenen.forEach((s, k) => { s.ende = k + 1 < szenen.length ? szenen[k + 1].start : t + 1.2; });
  return { fps, dauer: t + 1.2, geschaetzt: true, woerter, szenen };
};

/** Gutes Bild für das Cover: kurz vor Ende der Titel-Szene (alles eingeblendet, noch kein Übergang). */
export const coverBild = (d: Drehbuch, t: Timing | null) => {
  const tm = t ?? schaetzeTiming(d);
  const s0 = tm.szenen[0];
  if (!s0) return 0;
  return Math.max(0, Math.round((s0.ende - 0.35) * tm.fps));
};
