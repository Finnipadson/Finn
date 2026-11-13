import express from "express";
import { exec } from "node:child_process";
import { randomUUID } from "node:crypto";
import { ClaudeFehler, schreibeDrehbuch } from "./claude";
import { freierName, lade, liste, speichere } from "./projekte";
import { VORLAGEN } from "../src/drehbuch/anleitung";
import type { Drehbuch } from "../src/drehbuch/typen";

// Lokaler Server für das Erklärvideo-Studio: System-Check, Drehbuch von Claude, Projekte.
// Später: Stimme erzeugen + Rendern aus der App (Phase 4).

const PORT = 4710;
const app = express();
app.use(express.json({ limit: "2mb" }));

type Check = { name: string; ok: boolean; detail: string; hint?: string };

// Feste, interne Befehle (keine Benutzereingaben) → als eine Befehlszeile ausführen,
// damit Windows auch .cmd-Wrapper (z. B. npm-installierte Programme) findet.
const run = (command: string, timeoutMs = 15000) =>
  new Promise<{ ok: boolean; out: string; all: string }>((resolve) => {
    exec(command, { timeout: timeoutMs, windowsHide: true }, (err, stdout, stderr) => {
      const all = `${stdout ?? ""}${stderr ?? ""}`.trim();
      resolve({ ok: !err, out: all.split(/\r?\n/)[0] ?? "", all });
    });
  });

app.get("/api/health", async (_req, res) => {
  const [claude, auth, py, ff] = await Promise.all([
    run("claude --version"),
    run("claude auth status"),
    run(`python -c "import edge_tts, sys; print('Python', sys.version.split()[0], '+ edge-tts', edge_tts.__version__)"`),
    run("ffmpeg -version"),
  ]);
  let angemeldet = false, abo = "";
  try { const s = JSON.parse(auth.all); angemeldet = !!s.loggedIn; abo = s.subscriptionType ?? ""; } catch { /* ältere Version */ }
  const checks: Check[] = [
    { name: "Node.js", ok: true, detail: process.version },
    { name: "Claude Code", ok: claude.ok, detail: claude.ok ? claude.out : "nicht gefunden", hint: "Claude Code installieren." },
    { name: "Claude-Anmeldung", ok: angemeldet, detail: angemeldet ? `angemeldet${abo ? ` (${abo})` : ""}` : "nicht angemeldet", hint: "Im Terminal `claude auth login` ausführen." },
    { name: "Stimme (Python + edge-tts)", ok: py.ok, detail: py.ok ? py.out : "nicht gefunden", hint: "`python -m pip install edge-tts`" },
    { name: "FFmpeg", ok: ff.ok, detail: ff.ok ? ff.out.replace(/ Copyright.*/, "") : "nicht gefunden", hint: "`winget install Gyan.FFmpeg`" },
  ];
  res.json({ ok: checks.every((c) => c.ok), checks });
});

app.get("/api/vorlagen", (_req, res) => {
  res.json(Object.entries(VORLAGEN).map(([id, v]) => ({ id, name: v.name })));
});

/* ── Drehbuch schreiben lassen (dauert 30–120 s) → als Auftrag mit Status-Abfrage ── */
type Auftrag = { status: string; fertig: boolean; fehler?: string[]; fehlerArt?: string; projekt?: string };
const auftraege = new Map<string, Auftrag>();

app.post("/api/drehbuch", (req, res) => {
  const { thema, vorlage = "tech", format = "quer", stimme = "ava", sekunden = 45 } = req.body ?? {};
  if (typeof thema !== "string" || thema.trim().length < 3) return res.status(400).json({ fehler: "Bitte ein Thema eingeben (mindestens 3 Zeichen)." });
  const id = randomUUID();
  const a: Auftrag = { status: "Startet …", fertig: false };
  auftraege.set(id, a);
  schreibeDrehbuch({ thema: thema.trim(), vorlage, format: format === "hoch" ? "hoch" : "quer", stimme, sekunden: Number(sekunden) }, (s) => (a.status = s))
    .then((r) => {
      if (!r.drehbuch) {
        Object.assign(a, { fertig: true, status: `Kein gültiges Drehbuch nach ${r.versuche} Versuchen.`, fehler: r.fehler });
        return;
      }
      const name = freierName(r.drehbuch.titel || thema);
      speichere(name, r.drehbuch as Drehbuch, { name, thema, vorlage, erstellt: new Date().toISOString(), versuche: r.versuche, dauerMs: r.dauerMs });
      Object.assign(a, { fertig: true, status: `Fertig in ${(r.dauerMs / 1000).toFixed(0)} s (${r.versuche} Versuch${r.versuche > 1 ? "e" : ""}).`, projekt: name });
    })
    .catch((e) => {
      Object.assign(a, { fertig: true, status: "Fehler", fehler: [e instanceof Error ? e.message : String(e)], fehlerArt: e instanceof ClaudeFehler ? e.art : "unbekannt" });
    });
  res.json({ id });
});

app.get("/api/auftrag/:id", (req, res) => {
  const a = auftraege.get(req.params.id);
  if (!a) return res.status(404).json({ fehler: "Auftrag unbekannt" });
  res.json(a);
});

app.get("/api/projekte", (_req, res) => res.json(liste()));
app.get("/api/projekte/:name", (req, res) => {
  const p = lade(req.params.name);
  if (!p) return res.status(404).json({ fehler: "Projekt nicht gefunden" });
  res.json(p);
});

app.listen(PORT, () => {
  console.log(`Erklärvideo-Studio Server läuft auf http://localhost:${PORT}`);
});
