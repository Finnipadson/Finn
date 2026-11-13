import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { Drehbuch } from "../src/drehbuch/typen";

/* Gespeicherte Video-Projekte: projekte/<name>/drehbuch.json (+ meta.json, drehbuch.timing.json). */

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const PROJEKTE = path.join(ROOT, "projekte");

export const slug = (s: string) =>
  s.toLowerCase()
    .replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue").replace(/ß/g, "ss")
    .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40) || "video";

export const freierName = (basis: string) => {
  let name = slug(basis), i = 2;
  while (fs.existsSync(path.join(PROJEKTE, name))) name = `${slug(basis)}-${i++}`;
  return name;
};

export type Meta = { name: string; thema: string; vorlage: string; erstellt: string; versuche: number; dauerMs: number };

export const speichere = (name: string, drehbuch: Drehbuch, meta: Meta) => {
  const dir = path.join(PROJEKTE, name);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, "drehbuch.json"), JSON.stringify(drehbuch, null, 2), "utf8");
  fs.writeFileSync(path.join(dir, "meta.json"), JSON.stringify(meta, null, 2), "utf8");
  return dir;
};

export const liste = () => {
  if (!fs.existsSync(PROJEKTE)) return [];
  return fs.readdirSync(PROJEKTE, { withFileTypes: true })
    .filter((d) => d.isDirectory() && fs.existsSync(path.join(PROJEKTE, d.name, "drehbuch.json")))
    .map((d) => lade(d.name)!)
    .sort((a, b) => (b.meta?.erstellt ?? "").localeCompare(a.meta?.erstellt ?? ""));
};

export const lade = (name: string) => {
  const dir = path.join(PROJEKTE, path.basename(name));
  const lies = (f: string) => (fs.existsSync(path.join(dir, f)) ? JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")) : null);
  const drehbuch = lies("drehbuch.json") as Drehbuch | null;
  if (!drehbuch) return null;
  return {
    name: path.basename(name),
    drehbuch,
    meta: lies("meta.json") as Meta | null,
    timing: lies("drehbuch.timing.json"),
    ton: fs.existsSync(path.join(ROOT, "public", "ton", `${path.basename(name)}.wav`)),
  };
};
