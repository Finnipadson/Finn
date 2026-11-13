import React, { useEffect, useState } from "react";
import { Player } from "@remotion/player";
import { DemoTitel } from "./video/DemoTitel";

type Check = { name: string; ok: boolean; detail: string; hint?: string };
type Health = { ok: boolean; checks: Check[] };

const STEPS = [
  { n: 1, label: "Thema", phase: 2 },
  { n: 2, label: "Drehbuch", phase: 3 },
  { n: 3, label: "Einstellungen", phase: 3 },
  { n: 4, label: "Vorschau", phase: 3 },
  { n: 5, label: "Rendern", phase: 4 },
];

export const App: React.FC = () => {
  const [health, setHealth] = useState<Health | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [format, setFormat] = useState<"hoch" | "quer">("quer");
  const [titel, setTitel] = useState("Erklärvideo");

  const loadHealth = () => {
    setHealth(null);
    setError(null);
    fetch("/api/health")
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`Server antwortet mit ${r.status}`))))
      .then(setHealth)
      .catch(() => setError("Der lokale Server läuft nicht. Bitte über start.bat starten."));
  };
  useEffect(loadHealth, []);

  const hoch = format === "hoch";
  return (
    <div className="app">
      <header className="top">
        <div className="logo"><span className="play" />Erklärvideo-Studio</div>
        <div className="phase">Phase 0 · Fundament</div>
      </header>

      <nav className="steps">
        {STEPS.map((s) => (
          <div key={s.n} className="step" title={`kommt in Phase ${s.phase}`}>
            <span className="num">{s.n}</span>
            <span>{s.label}</span>
            <span className="soon">Phase {s.phase}</span>
          </div>
        ))}
      </nav>

      <main className="main">
        <section className="card preview">
          <div className="card-head">
            <h2>Live-Vorschau</h2>
            <div className="seg">
              <button className={!hoch ? "on" : ""} onClick={() => setFormat("quer")}>Quer 16:9</button>
              <button className={hoch ? "on" : ""} onClick={() => setFormat("hoch")}>Hoch 9:16</button>
            </div>
          </div>
          <div className={`player-wrap ${hoch ? "hoch" : "quer"}`}>
            <Player
              component={DemoTitel}
              inputProps={{ titel: titel || " ", unter: "Studio · Phase 0" }}
              durationInFrames={180}
              fps={60}
              compositionWidth={hoch ? 1080 : 1920}
              compositionHeight={hoch ? 1920 : 1080}
              style={{ width: "100%", height: "100%" }}
              controls
              loop
              autoPlay
            />
          </div>
          <label className="field">
            <span>Titel (Test der Live-Vorschau)</span>
            <input value={titel} maxLength={24} onChange={(e) => setTitel(e.target.value)} />
          </label>
        </section>

        <section className="card checks">
          <div className="card-head">
            <h2>System-Check</h2>
            <button className="ghost" onClick={loadHealth}>Neu prüfen</button>
          </div>
          {error && <div className="err">{error}</div>}
          {!health && !error && <div className="muted">Prüfe …</div>}
          {health?.checks.map((c) => (
            <div key={c.name} className={`check ${c.ok ? "ok" : "bad"}`}>
              <span className="dot" />
              <div>
                <div className="name">{c.name}</div>
                <div className="detail">{c.detail}</div>
                {!c.ok && c.hint && <div className="hint">{c.hint}</div>}
              </div>
            </div>
          ))}
          {health && (
            <div className={`summary ${health.ok ? "ok" : "bad"}`}>
              {health.ok ? "Alles bereit für Phase 1." : "Bitte die rot markierten Punkte beheben."}
            </div>
          )}
        </section>
      </main>
    </div>
  );
};
