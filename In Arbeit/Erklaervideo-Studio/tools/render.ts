import fs from "node:fs";
import path from "node:path";
import { spawn } from "node:child_process";
import { pruefeDrehbuch } from "../src/drehbuch/pruefen";

/* Rendert ein Drehbuch zu einem MP4.
   Aufruf: npm run render -- beispiele/pythagoras.json [--ohne-ton]
   Voraussetzung (mit Ton): vorher `npm run ton -- <drehbuch>` ausführen. */

const args = process.argv.slice(2);
const datei = args.find((a) => !a.startsWith("--"));
const ohneTon = args.includes("--ohne-ton");
if (!datei) {
  console.error("Bitte ein Drehbuch angeben, z. B.: npm run render -- beispiele/pythagoras.json");
  process.exit(2);
}
const name = path.basename(datei, ".json");
const drehbuch = JSON.parse(fs.readFileSync(datei, "utf8"));
const fehler = pruefeDrehbuch(drehbuch);
if (fehler.length) {
  console.error(`✗ Drehbuch fehlerhaft:\n${fehler.map((f) => `   - ${f}`).join("\n")}`);
  process.exit(1);
}
const timingDatei = path.join(path.dirname(datei), `${name}.timing.json`);
const tonDatei = path.join("public", "ton", `${name}.wav`);
let timing = null, audio = null;
if (!ohneTon) {
  if (!fs.existsSync(timingDatei) || !fs.existsSync(tonDatei)) {
    console.error(`✗ Kein Ton gefunden. Erst ausführen:  npm run ton -- ${datei}\n  (oder ohne Stimme rendern: --ohne-ton)`);
    process.exit(1);
  }
  timing = JSON.parse(fs.readFileSync(timingDatei, "utf8"));
  audio = `ton/${name}.wav`;
}
fs.mkdirSync("out", { recursive: true });
const propsDatei = path.join("out", `${name}.props.json`);
fs.writeFileSync(propsDatei, JSON.stringify({ drehbuch, timing, audio }));
const ziel = path.join("out", `${name}.mp4`);
console.log(`Rendere ${datei} → ${ziel} …`);
const p = spawn(
  "npx",
  ["remotion", "render", "src/video/index.ts", "Erklaervideo", ziel, `--props=${propsDatei}`, "--crf=16", "--audio-bitrate=256k"],
  { stdio: "inherit", shell: process.platform === "win32" },
);
p.on("exit", (code) => {
  if (code === 0) console.log(`✓ Fertig: ${ziel}`);
  process.exit(code ?? 1);
});
