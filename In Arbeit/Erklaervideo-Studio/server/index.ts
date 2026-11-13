import express from "express";
import fs from "node:fs";
import path from "node:path";
import { exec, spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { ClaudeFehler, schreibeDrehbuch, ueberarbeiteSzene } from "./claude";
import { aktualisiere, coverDatei, freierName, lade, liste, PROJEKTE, ROOT, speichere, videoDatei } from "./projekte";
import { Abgebrochen, starteRender } from "./render";
import { VORLAGEN } from "../src/drehbuch/anleitung";
import { pruefeDrehbuch } from "../src/drehbuch/pruefen";
import { STIMMEN, type Drehbuch } from "../src/drehbuch/typen";

// Lokaler Server für das Erklärvideo-Studio: System-Check, Drehbuch von Claude, Projekte, Stimme,
// „Szene neu machen“, Rendern (MP4 + Cover).

const PORT = 4710;
const app = express();
app.use(express.json({ limit: "4mb" }));

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

/* ── Aufträge (dauern länger) → Status-Abfrage über /api/auftrag/:id ── */
type Auftrag = {
  status: string; fertig: boolean; fehler?: string[]; fehlerArt?: string; projekt?: string; fortschritt?: number;
  szene?: unknown;                 // „Szene neu machen“: die neue Szene
  abbrechbar?: boolean; abgebrochen?: boolean;
  ergebnis?: { dauerMs: number; bytes: number; sekunden: number };
};
const abbrecher = new Map<string, () => void>();
const auftraege = new Map<string, Auftrag>();
const neuerAuftrag = () => {
  const id = randomUUID();
  const a: Auftrag = { status: "Startet …", fertig: false };
  auftraege.set(id, a);
  return { id, a };
};
app.get("/api/auftrag/:id", (req, res) => {
  const a = auftraege.get(req.params.id);
  if (!a) return res.status(404).json({ fehler: "Auftrag unbekannt" });
  res.json(a);
});
app.post("/api/auftrag/:id/abbrechen", (req, res) => {
  const stop = abbrecher.get(req.params.id);
  if (!stop) return res.status(404).json({ fehler: "Dieser Auftrag kann nicht (mehr) abgebrochen werden." });
  stop();
  res.json({ ok: true });
});

/* Drehbuch von Claude schreiben lassen (30–180 s) */
app.post("/api/drehbuch", (req, res) => {
  const { thema, vorlage = "tech", format = "quer", stimme = "ava", sekunden = 45 } = req.body ?? {};
  if (typeof thema !== "string" || thema.trim().length < 3) return res.status(400).json({ fehler: "Bitte ein Thema eingeben (mindestens 3 Zeichen)." });
  const { id, a } = neuerAuftrag();
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

/* ── Projekte ── */
app.get("/api/projekte", (_req, res) => res.json(liste()));
app.get("/api/projekte/:name", (req, res) => {
  const p = lade(req.params.name);
  if (!p) return res.status(404).json({ fehler: "Projekt nicht gefunden" });
  res.json(p);
});
// Neues Projekt aus einem vorhandenen Drehbuch (z. B. Kopie eines Beispiels)
app.post("/api/projekte", (req, res) => {
  const d = req.body?.drehbuch as Drehbuch | undefined;
  if (!d || typeof d !== "object") return res.status(400).json({ fehler: "Kein Drehbuch übergeben." });
  const name = freierName(req.body?.name ?? d.titel ?? "video");
  speichere(name, d, { name, thema: d.titel ?? name, vorlage: "kopie", erstellt: new Date().toISOString(), versuche: 0, dauerMs: 0 });
  res.json({ name, fehler: pruefeDrehbuch(d) });
});
app.put("/api/projekte/:name", (req, res) => {
  const d = req.body?.drehbuch as Drehbuch | undefined;
  if (!d || typeof d !== "object") return res.status(400).json({ fehler: "Kein Drehbuch übergeben." });
  const r = aktualisiere(req.params.name, d);
  if (!r) return res.status(404).json({ fehler: "Projekt nicht gefunden" });
  res.json({ ...r, fehler: pruefeDrehbuch(d) });
});

/* ── Stimme für ein Projekt erzeugen (tools/ton.py) ── */
app.post("/api/projekte/:name/ton", (req, res) => {
  const p = lade(req.params.name);
  if (!p) return res.status(404).json({ fehler: "Projekt nicht gefunden" });
  const fehler = pruefeDrehbuch(p.drehbuch);
  if (fehler.length) return res.status(400).json({ fehler: `Das Drehbuch hat noch ${fehler.length} Fehler – bitte erst beheben.` });
  const { id, a } = neuerAuftrag();
  const gesamt = p.drehbuch.szenen.reduce((n, s) => n + s.sprecher.length, 0);
  let fertigeSaetze = 0;
  a.status = "Stimme wird erzeugt …";
  a.fortschritt = 0;
  // -u: ungepuffert, sonst kommen die Fortschritts-Zeilen erst ganz am Ende an
  const proc = spawn("python", ["-u", "tools/ton.py", path.join("projekte", p.name, "drehbuch.json")], {
    cwd: ROOT, windowsHide: true, env: { ...process.env, PYTHONIOENCODING: "utf-8" },
  });
  let fehlerText = "";
  proc.stdout.on("data", (d: Buffer) => {
    for (const zeile of d.toString("utf8").split(/\r?\n/)) {
      const m = zeile.match(/^\s+Szene (\d+):/);
      if (m) {
        fertigeSaetze++;
        a.fortschritt = Math.min(0.95, fertigeSaetze / Math.max(1, gesamt));
        a.status = `Stimme: Satz ${fertigeSaetze} von ${gesamt} (Szene ${m[1]}) …`;
      } else if (zeile.startsWith("Fertig:")) a.status = "Geräusche und Musik werden gemischt …";
    }
  });
  proc.stderr.on("data", (d: Buffer) => (fehlerText += d.toString("utf8")));
  proc.on("error", (e) => Object.assign(a, { fertig: true, status: "Fehler", fehler: [`Python nicht gefunden: ${e.message}`] }));
  proc.on("close", (code) => {
    if (code === 0) Object.assign(a, { fertig: true, fortschritt: 1, status: "Stimme fertig.", projekt: p.name });
    else Object.assign(a, { fertig: true, status: "Fehler", fehler: [fehlerText.trim().split(/\r?\n/).slice(-3).join(" ") || `ton.py endete mit Code ${code}`] });
  });
  res.json({ id });
});

/* ── „Szene neu machen“: Claude überarbeitet eine Szene nach Wunsch (Ergebnis ersetzt sie erst in der App) ── */
app.post("/api/szene", (req, res) => {
  const { drehbuch, index, wunsch } = req.body ?? {};
  const d = drehbuch as Drehbuch | undefined;
  if (!d || !Array.isArray(d.szenen)) return res.status(400).json({ fehler: "Kein Drehbuch übergeben." });
  if (!Number.isInteger(index) || index < 0 || index >= d.szenen.length) return res.status(400).json({ fehler: "Ungültige Szene." });
  if (typeof wunsch !== "string" || wunsch.trim().length < 3) return res.status(400).json({ fehler: "Bitte beschreiben, was anders werden soll." });
  const { id, a } = neuerAuftrag();
  ueberarbeiteSzene(d, index, wunsch.trim().slice(0, 600), (s) => (a.status = s))
    .then((r) => {
      if (!r.szene) Object.assign(a, { fertig: true, status: `Keine gültige Szene nach ${r.versuche} Versuchen.`, fehler: r.fehler });
      else Object.assign(a, { fertig: true, status: `Fertig in ${(r.dauerMs / 1000).toFixed(0)} s.`, szene: r.szene });
    })
    .catch((e) => Object.assign(a, { fertig: true, status: "Fehler", fehler: [e instanceof Error ? e.message : String(e)], fehlerArt: e instanceof ClaudeFehler ? e.art : "unbekannt" }));
  res.json({ id });
});

/* ── Rendern: MP4 + Cover in projekte/<name>/ (immer nur ein Render gleichzeitig) ── */
let renderLaeuft: string | null = null;
app.post("/api/projekte/:name/rendern", (req, res) => {
  const p = lade(req.params.name);
  if (!p) return res.status(404).json({ fehler: "Projekt nicht gefunden" });
  if (renderLaeuft) return res.status(409).json({ fehler: "Es wird gerade schon ein Video gerendert." });
  const fehler = pruefeDrehbuch(p.drehbuch);
  if (fehler.length) return res.status(400).json({ fehler: `Das Drehbuch hat noch ${fehler.length} Fehler – bitte erst beheben.` });
  const ohneTon = req.body?.ohneTon === true;
  if (!ohneTon && (!p.ton || !p.timing)) return res.status(400).json({ fehler: "Es gibt noch keine Stimme – bitte erst „Stimme erzeugen“ (Schritt Vorschau)." });
  const { id, a } = neuerAuftrag();
  renderLaeuft = p.name;
  Object.assign(a, { abbrechbar: true, fortschritt: 0, projekt: p.name });
  const r = starteRender(
    { drehbuch: p.drehbuch, timing: ohneTon ? null : p.timing, audio: ohneTon ? null : `ton/${p.name}.wav`, video: videoDatei(p.name), cover: coverDatei(p.name) },
    (status, fortschritt) => { a.status = status; a.fortschritt = fortschritt; },
  );
  abbrecher.set(id, r.abbrechen);
  r.fertig
    .then((e) => Object.assign(a, { fertig: true, fortschritt: 1, status: `Fertig in ${Math.round(e.dauerMs / 1000)} s.`, ergebnis: e }))
    .catch((e) => e instanceof Abgebrochen
      ? Object.assign(a, { fertig: true, abgebrochen: true, status: "Abgebrochen – das vorherige Video (falls vorhanden) ist unverändert." })
      : Object.assign(a, { fertig: true, status: "Fehler beim Rendern", fehler: [e instanceof Error ? e.message.split(/\r?\n/).slice(0, 3).join(" ") : String(e)] }))
    .finally(() => { renderLaeuft = null; abbrecher.delete(id); a.abbrechbar = false; });
  res.json({ id });
});

/* Fertiges Video / Cover ausliefern (für Vorschau und Download) */
app.get("/api/projekte/:name/datei/:art", (req, res) => {
  const p = lade(req.params.name);
  const datei = !p ? null : req.params.art === "video" ? videoDatei(p.name) : req.params.art === "cover" ? coverDatei(p.name) : null;
  if (!datei || !fs.existsSync(datei)) return res.status(404).json({ fehler: "Datei nicht gefunden" });
  if (req.query.download !== undefined) return res.download(datei);
  res.sendFile(datei);
});

/* Projektordner im Explorer zeigen (Video markiert) */
app.post("/api/projekte/:name/zeigen", (req, res) => {
  const p = lade(req.params.name);
  if (!p) return res.status(404).json({ fehler: "Projekt nicht gefunden" });
  const v = videoDatei(p.name);
  const args = fs.existsSync(v) ? `/select,"${v}"` : `"${path.dirname(v)}"`;
  spawn("explorer.exe", [args], { windowsVerbatimArguments: true, detached: true, stdio: "ignore" }).unref();
  res.json({ ok: true });
});

/* ── Hörprobe einer Stimme (wird zwischengespeichert) ── */
app.get("/api/stimmprobe", async (req, res) => {
  const key = String(req.query.stimme ?? "ava");
  const tempo = Math.max(-30, Math.min(30, Math.round(Number(req.query.tempo ?? 0)) || 0));
  const s = STIMMEN[key];
  if (!s) return res.status(400).json({ fehler: "Unbekannte Stimme" });
  const ordner = path.join(ROOT, "public", "ton", "_proben");
  fs.mkdirSync(ordner, { recursive: true });
  const datei = `probe-${key}-${tempo}.mp3`;
  const ziel = path.join(ordner, datei);
  if (!fs.existsSync(ziel)) {
    const ok = await new Promise<boolean>((resolve) => {
      const p = spawn("python", ["tools/probe.py", s.id, String(tempo), ziel], { cwd: ROOT, windowsHide: true });
      p.on("error", () => resolve(false));
      p.on("close", (code) => resolve(code === 0 && fs.existsSync(ziel)));
    });
    if (!ok) return res.status(502).json({ fehler: "Hörprobe konnte nicht erzeugt werden (Internet?)." });
  }
  res.json({ url: `/ton/_proben/${datei}` });
});

fs.mkdirSync(PROJEKTE, { recursive: true });
app.listen(PORT, () => {
  console.log(`Erklärvideo-Studio Server läuft auf http://localhost:${PORT}`);
});
