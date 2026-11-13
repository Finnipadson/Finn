import path from "node:path";
import { ClaudeFehler, schreibeDrehbuch } from "../server/claude";
import { freierName, speichere } from "../server/projekte";
import { VORLAGEN } from "../src/drehbuch/anleitung";
import type { Format } from "../src/drehbuch/typen";

/* Claude schreibt ein Drehbuch zu einem Thema.
   Aufruf: npm run drehbuch -- "Wie funktioniert ein Akku?" --vorlage tech --format quer --sekunden 45 [--name akku]
   Ergebnis: projekte/<name>/drehbuch.json (+ meta.json). Danach: npm run ton / npm run render. */

const args = process.argv.slice(2);
const opt = (k: string) => { const i = args.indexOf(`--${k}`); return i >= 0 ? args[i + 1] : undefined; };
const thema = args.find((a, i) => !a.startsWith("--") && !args[i - 1]?.startsWith("--"));
if (!thema) {
  console.error(`Bitte ein Thema angeben, z. B.: npm run drehbuch -- "Wie funktioniert ein Akku?" --vorlage tech --format quer
Vorlagen: ${Object.entries(VORLAGEN).map(([k, v]) => `${k} (${v.name})`).join(", ")}`);
  process.exit(2);
}
const vorlage = opt("vorlage") ?? "tech";
const format = (opt("format") === "hoch" ? "hoch" : "quer") as Format;
const sekunden = Number(opt("sekunden") ?? 45);
const name = freierName(opt("name") ?? thema);

console.log(`Thema: ${thema}\nVorlage: ${VORLAGEN[vorlage]?.name ?? vorlage} · Format: ${format} · ca. ${sekunden} s`);
try {
  const r = await schreibeDrehbuch({ thema, vorlage, format, sekunden, stimme: opt("stimme") }, (s) => console.log(`… ${s}`));
  if (!r.drehbuch) {
    console.error(`✗ Kein gültiges Drehbuch nach ${r.versuche} Versuchen:\n${r.fehler.map((f) => `   - ${f}`).join("\n")}`);
    process.exit(1);
  }
  const dir = speichere(name, r.drehbuch, { name, thema, vorlage, erstellt: new Date().toISOString(), versuche: r.versuche, dauerMs: r.dauerMs });
  const d = r.drehbuch;
  const woerter = d.szenen.reduce((n, s) => n + s.sprecher.reduce((m, x) => m + x.satz.split(/\s+/).length, 0), 0);
  console.log(`✓ „${d.titel}“: ${d.szenen.length} Szenen (${d.szenen.map((s) => s.typ).join(" → ")}), ${woerter} Wörter, ${r.versuche} Versuch(e), ${(r.dauerMs / 1000).toFixed(0)} s`);
  console.log(`  gespeichert: ${path.relative(process.cwd(), dir)}${path.sep}drehbuch.json`);
  console.log(`  weiter: npm run ton -- projekte/${name}/drehbuch.json  &&  npm run render -- projekte/${name}/drehbuch.json`);
} catch (e) {
  console.error(`✗ ${e instanceof ClaudeFehler ? e.message : String(e)}`);
  process.exit(1);
}
