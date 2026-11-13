import fs from "node:fs";
import { pruefeDrehbuch } from "../src/drehbuch/pruefen";

// Aufruf: npm run pruefen -- beispiele/pythagoras.json [weitere.json …]
const dateien = process.argv.slice(2);
if (dateien.length === 0) {
  console.error("Bitte eine oder mehrere Drehbuch-Dateien angeben.");
  process.exit(2);
}
let fehlerGesamt = 0;
for (const datei of dateien) {
  let fehler: string[];
  try {
    fehler = pruefeDrehbuch(JSON.parse(fs.readFileSync(datei, "utf8")));
  } catch (e) {
    fehler = [`Datei nicht lesbar oder kein gültiges JSON: ${(e as Error).message}`];
  }
  if (fehler.length === 0) console.log(`✓ ${datei}: in Ordnung`);
  else {
    console.log(`✗ ${datei}: ${fehler.length} Problem(e)`);
    for (const f of fehler) console.log(`   - ${f}`);
  }
  fehlerGesamt += fehler.length;
}
process.exit(fehlerGesamt ? 1 : 0);
