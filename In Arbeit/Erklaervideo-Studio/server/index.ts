import express from "express";
import { exec } from "node:child_process";

// Lokaler Server für das Erklärvideo-Studio.
// Phase 0: nur System-Check. Später: Claude (Drehbuch), Stimme (edge-tts), Rendern (Remotion).

const PORT = 4710;
const app = express();
app.use(express.json({ limit: "2mb" }));

type Check = { name: string; ok: boolean; detail: string; hint?: string };

// Feste, interne Befehle (keine Benutzereingaben) → als eine Befehlszeile ausführen,
// damit Windows auch .cmd-Wrapper (z. B. npm-installierte Programme) findet.
const run = (command: string, timeoutMs = 15000) =>
  new Promise<{ ok: boolean; out: string }>((resolve) => {
    exec(command, { timeout: timeoutMs, windowsHide: true }, (err, stdout, stderr) => {
      const out = `${stdout ?? ""}${stderr ?? ""}`.trim().split(/\r?\n/)[0] ?? "";
      resolve({ ok: !err, out });
    });
  });

app.get("/api/health", async (_req, res) => {
  const [claude, py, ff] = await Promise.all([
    run("claude --version"),
    run(`python -c "import edge_tts, sys; print('Python', sys.version.split()[0], '+ edge-tts', edge_tts.__version__)"`),
    run("ffmpeg -version"),
  ]);
  const checks: Check[] = [
    { name: "Node.js", ok: true, detail: process.version },
    { name: "Claude Code", ok: claude.ok, detail: claude.ok ? claude.out : "nicht gefunden", hint: "Claude Code installieren und einmal `claude` im Terminal starten (Anmeldung)." },
    { name: "Stimme (Python + edge-tts)", ok: py.ok, detail: py.ok ? py.out : "nicht gefunden", hint: "`python -m pip install edge-tts`" },
    { name: "FFmpeg", ok: ff.ok, detail: ff.ok ? ff.out.replace(/ Copyright.*/, "") : "nicht gefunden", hint: "`winget install Gyan.FFmpeg`" },
  ];
  res.json({ ok: checks.every((c) => c.ok), checks });
});

app.listen(PORT, () => {
  console.log(`Erklärvideo-Studio Server läuft auf http://localhost:${PORT}`);
});
