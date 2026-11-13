import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { tonSchluessel } from "../src/drehbuch/pruefen";
import type { Drehbuch } from "../src/drehbuch/typen";

/* Gespeicherte Video-Projekte: projekte/<name>/drehbuch.json (+ meta.json, drehbuch.timing.json).
   Der Ton liegt in public/ton/<name>.wav (damit Vorschau und Rendern ihn finden). */

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const PROJEKTE = path.join(ROOT, "projekte");
export const tonDatei = (name: string) => path.join(ROOT, "public", "ton", `${name}.wav`);

export const slug = (s: string) =>
  s.toLowerCase()
    .replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue").replace(/ß/g, "ss")
    .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40) || "video";

export const freierName = (basis: string) => {
  let name = slug(basis), i = 2;
  while (fs.existsSync(path.join(PROJEKTE, name))) name = `${slug(basis)}-${i++}`;
  return name;
};

export type Meta = { name: string; thema: string; vorlage: string; erstellt: string; versuche: number; dauerMs: number; geaendert?: string };

const sicher = (name: string) => path.basename(name).replace(/[^a-z0-9-]/gi, "");
const dir = (name: string) => path.join(PROJEKTE, sicher(name));

export const speichere = (name: string, drehbuch: Drehbuch, meta: Meta) => {
  const d = dir(name);
  fs.mkdirSync(d, { recursive: true });
  fs.writeFileSync(path.join(d, "drehbuch.json"), JSON.stringify(drehbuch, null, 2), "utf8");
  fs.writeFileSync(path.join(d, "meta.json"), JSON.stringify(meta, null, 2), "utf8");
  return d;
};

/** Drehbuch aktualisieren. Hat sich etwas am Ton geändert (Text, „bei“, Stimme …), wird der alte Ton verworfen. */
export const aktualisiere = (name: string, drehbuch: Drehbuch) => {
  const alt = lade(name);
  if (!alt) return null;
  const tonVeraltet = tonSchluessel(alt.drehbuch) !== tonSchluessel(drehbuch);
  fs.writeFileSync(path.join(dir(name), "drehbuch.json"), JSON.stringify(drehbuch, null, 2), "utf8");
  if (alt.meta) fs.writeFileSync(path.join(dir(name), "meta.json"), JSON.stringify({ ...alt.meta, geaendert: new Date().toISOString() }, null, 2), "utf8");
  if (tonVeraltet) {
    fs.rmSync(path.join(dir(name), "drehbuch.timing.json"), { force: true });
    fs.rmSync(tonDatei(sicher(name)), { force: true });
  }
  return { tonVeraltet };
};

export const liste = () => {
  if (!fs.existsSync(PROJEKTE)) return [];
  return fs.readdirSync(PROJEKTE, { withFileTypes: true })
    .filter((d) => d.isDirectory() && fs.existsSync(path.join(PROJEKTE, d.name, "drehbuch.json")))
    .map((d) => lade(d.name)!)
    .sort((a, b) => (b.meta?.geaendert ?? b.meta?.erstellt ?? "").localeCompare(a.meta?.geaendert ?? a.meta?.erstellt ?? ""));
};

export const lade = (name: string) => {
  const d = dir(name);
  const lies = (f: string) => (fs.existsSync(path.join(d, f)) ? JSON.parse(fs.readFileSync(path.join(d, f), "utf8")) : null);
  const drehbuch = lies("drehbuch.json") as Drehbuch | null;
  if (!drehbuch) return null;
  const ton = tonDatei(sicher(name));
  return {
    name: sicher(name),
    drehbuch,
    meta: lies("meta.json") as Meta | null,
    timing: lies("drehbuch.timing.json"),
    ton: fs.existsSync(ton),
    tonVersion: fs.existsSync(ton) ? Math.round(fs.statSync(ton).mtimeMs) : 0,
  };
};
