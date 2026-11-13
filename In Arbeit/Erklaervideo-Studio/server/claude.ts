import { spawn } from "node:child_process";
import os from "node:os";
import { baueAnleitung, baueKorrektur } from "../src/drehbuch/anleitung";
import { pruefeDrehbuch } from "../src/drehbuch/pruefen";
import { STIMMEN, type Drehbuch, type Format } from "../src/drehbuch/typen";

/* Lässt Claude Code (über das eigene Abo, `claude -p`) ein Drehbuch schreiben,
   prüft es und lässt Fehler automatisch korrigieren (max. 2 Korrektur-Runden). */

export class ClaudeFehler extends Error {
  constructor(message: string, public art: "anmeldung" | "nicht-gefunden" | "zeit" | "antwort") {
    super(message);
  }
}

/** Ein einzelner Aufruf: Prompt über stdin, ohne Werkzeuge, ohne Projekt-Kontext (cwd = Temp-Ordner). */
export const frageClaude = (prompt: string, timeoutMs = 5 * 60_000) =>
  new Promise<string>((resolve, reject) => {
    const p = spawn("claude", ["-p", "--output-format", "json", "--tools", "", "--no-session-persistence"], {
      cwd: os.tmpdir(), windowsHide: true, shell: false,
    });
    let out = "", err = "";
    const timer = setTimeout(() => { p.kill(); reject(new ClaudeFehler("Claude hat nicht rechtzeitig geantwortet (5 Minuten).", "zeit")); }, timeoutMs);
    p.stdout.on("data", (d) => (out += d));
    p.stderr.on("data", (d) => (err += d));
    p.on("error", (e: NodeJS.ErrnoException) => {
      clearTimeout(timer);
      reject(e.code === "ENOENT"
        ? new ClaudeFehler("Claude Code wurde nicht gefunden. Ist es installiert?", "nicht-gefunden")
        : e);
    });
    p.on("close", () => {
      clearTimeout(timer);
      let r: { is_error?: boolean; result?: string; api_error_status?: number };
      try { r = JSON.parse(out); } catch {
        return reject(new ClaudeFehler(`Unerwartete Antwort von Claude Code: ${(out || err).slice(0, 300)}`, "antwort"));
      }
      if (r.is_error) {
        const text = r.result ?? "";
        if (r.api_error_status === 401 || /authenticat|login|token has expired/i.test(text)) {
          return reject(new ClaudeFehler("Claude Code ist nicht (mehr) angemeldet. Bitte im Terminal einmal `claude auth login` ausführen.", "anmeldung"));
        }
        return reject(new ClaudeFehler(`Claude Code meldet einen Fehler: ${text.slice(0, 300)}`, "antwort"));
      }
      resolve(r.result ?? "");
    });
    p.stdin.end(prompt, "utf8");
  });

/** JSON-Objekt aus der Antwort holen (auch wenn doch ```json … ``` drumherum steht). */
export const holeJson = (text: string): { json: unknown; roh: string } => {
  const ohne = text.replace(/```(?:json)?/gi, "");
  const a = ohne.indexOf("{"), b = ohne.lastIndexOf("}");
  if (a < 0 || b <= a) throw new ClaudeFehler("Die Antwort enthält kein JSON-Objekt.", "antwort");
  const roh = ohne.slice(a, b + 1);
  try { return { json: JSON.parse(roh), roh }; } catch (e) {
    return { json: null, roh: `${roh}\n/* JSON-Fehler: ${(e as Error).message} */` };
  }
};

export type DrehbuchAuftrag = { thema: string; vorlage: string; format: Format; stimme?: string; sekunden?: number };
export type DrehbuchErgebnis = { drehbuch: Drehbuch | null; fehler: string[]; versuche: number; dauerMs: number };

export const schreibeDrehbuch = async (a: DrehbuchAuftrag, status: (s: string) => void = () => {}): Promise<DrehbuchErgebnis> => {
  const t0 = Date.now();
  const stimme = a.stimme && STIMMEN[a.stimme] ? a.stimme : "ava";
  const sekunden = Math.min(150, Math.max(20, a.sekunden ?? 45));
  status("Claude schreibt das Drehbuch …");
  let antwort = await frageClaude(baueAnleitung({ thema: a.thema, vorlage: a.vorlage, format: a.format, stimme, sekunden }));
  for (let versuch = 1; ; versuch++) {
    const { json, roh } = holeJson(antwort);
    let fehler: string[];
    if (json && typeof json === "object") {
      // Vorgaben aus der App haben Vorrang
      Object.assign(json, { format: a.format, stimme });
      fehler = pruefeDrehbuch(json);
    } else {
      fehler = ["Das JSON ist nicht gültig (Syntaxfehler)."];
    }
    if (fehler.length === 0) return { drehbuch: json as Drehbuch, fehler: [], versuche: versuch, dauerMs: Date.now() - t0 };
    if (versuch > 2) return { drehbuch: null, fehler, versuche: versuch, dauerMs: Date.now() - t0 };
    status(`${fehler.length} Problem(e) gefunden – Claude korrigiert (Runde ${versuch}) …`);
    antwort = await frageClaude(baueKorrektur(json ? JSON.stringify(json, null, 1) : roh, fehler));
  }
};
