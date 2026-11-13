import React, { useEffect, useMemo, useState } from "react";
import { Player } from "@remotion/player";
import { dauerInBildern, Erklaervideo } from "./video/Erklaervideo";
import { pruefeDrehbuch } from "./drehbuch/pruefen";
import type { Drehbuch, Timing } from "./drehbuch/typen";

type Check = { name: string; ok: boolean; detail: string; hint?: string };
type Health = { ok: boolean; checks: Check[] };

// Beispiel-Drehbücher + (falls erzeugt) ihre Zeitlisten aus dem Ordner beispiele/
const dateien = import.meta.glob("../beispiele/*.json", { eager: true, import: "default" }) as Record<string, unknown>;
const BEISPIELE = Object.entries(dateien)
  .filter(([p]) => !p.endsWith(".timing.json"))
  .map(([p, d]) => {
    const name = p.split("/").pop()!.replace(/\.json$/, "");
    const timing = (dateien[`../beispiele/${name}.timing.json`] as Timing | undefined) ?? null;
    return { name, drehbuch: d as Drehbuch, timing };
  });

const STEPS = [
  { n: 1, label: "Thema", phase: 2 },
  { n: 2, label: "Drehbuch", phase: 3 },
  { n: 3, label: "Einstellungen", phase: 3 },
  { n: 4, label: "Vorschau", phase: 1, aktiv: true },
  { n: 5, label: "Rendern", phase: 4 },
];

export const App: React.FC = () => {
  const [health, setHealth] = useState<Health | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [auswahl, setAuswahl] = useState(BEISPIELE[0]?.name ?? "");
  const [mitTon, setMitTon] = useState(true);
  const [tonDa, setTonDa] = useState(false);

  const loadHealth = () => {
    setHealth(null);
    setError(null);
    fetch("/api/health")
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`Server antwortet mit ${r.status}`))))
      .then(setHealth)
      .catch(() => setError("Der lokale Server läuft nicht. Bitte über start.bat starten."));
  };
  useEffect(loadHealth, []);

  const bsp = BEISPIELE.find((b) => b.name === auswahl);
  useEffect(() => {
    setTonDa(false);
    if (!bsp) return;
    fetch(`/ton/${bsp.name}.wav`, { method: "HEAD" }).then((r) => setTonDa(r.ok && (r.headers.get("content-type") ?? "").includes("audio"))).catch(() => setTonDa(false));
  }, [bsp?.name]);

  const fehler = useMemo(() => (bsp ? pruefeDrehbuch(bsp.drehbuch) : []), [bsp]);
  const nutzeTon = mitTon && tonDa && !!bsp?.timing;
  const props = bsp ? { drehbuch: bsp.drehbuch, timing: nutzeTon ? bsp.timing : null, audio: nutzeTon ? `ton/${bsp.name}.wav` : null } : null;
  const hoch = bsp?.drehbuch.format === "hoch";

  return (
    <div className="app">
      <header className="top">
        <div className="logo"><span className="play" />Erklärvideo-Studio</div>
        <div className="phase">Phase 1 · Drehbuch → Video</div>
      </header>

      <nav className="steps">
        {STEPS.map((s) => (
          <div key={s.n} className={`step ${s.aktiv ? "aktiv" : ""}`} title={s.aktiv ? "" : `kommt in Phase ${s.phase}`}>
            <span className="num">{s.n}</span>
            <span>{s.label}</span>
            {!s.aktiv && <span className="soon">Phase {s.phase}</span>}
          </div>
        ))}
      </nav>

      <main className="main">
        <section className="card preview">
          <div className="card-head">
            <h2>Vorschau</h2>
            <div className="row">
              <select value={auswahl} onChange={(e) => setAuswahl(e.target.value)}>
                {BEISPIELE.map((b) => <option key={b.name} value={b.name}>{b.drehbuch.titel} ({b.drehbuch.format})</option>)}
              </select>
              <label className="toggle" title={tonDa ? "" : "Noch kein Ton erzeugt: npm run ton -- beispiele/<name>.json"}>
                <input type="checkbox" checked={mitTon} disabled={!tonDa} onChange={(e) => setMitTon(e.target.checked)} /> mit Stimme
              </label>
            </div>
          </div>
          {props && fehler.length === 0 && (
            <div className={`player-wrap ${hoch ? "hoch" : "quer"}`}>
              <Player
                key={`${auswahl}-${nutzeTon}`}
                component={Erklaervideo}
                inputProps={props}
                durationInFrames={dauerInBildern(props.drehbuch, props.timing)}
                fps={60}
                compositionWidth={hoch ? 1080 : 1920}
                compositionHeight={hoch ? 1920 : 1080}
                style={{ width: "100%", height: "100%" }}
                controls
              />
            </div>
          )}
          {fehler.length > 0 && (
            <div className="err">
              <b>Das Drehbuch hat Fehler:</b>
              <ul>{fehler.map((f) => <li key={f}>{f}</li>)}</ul>
            </div>
          )}
          <div className="muted hint-line">
            {nutzeTon ? "Mit echter Stimme, Geräuschen und Musik." : "Ohne Stimme: Zeiten sind geschätzt (Ton erzeugen mit npm run ton)."}
            {bsp && <> · {bsp.drehbuch.szenen.length} Szenen: {bsp.drehbuch.szenen.map((s) => s.typ).join(" → ")}</>}
          </div>
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
              {health.ok ? "Alles bereit." : "Bitte die rot markierten Punkte beheben."}
            </div>
          )}
        </section>
      </main>
    </div>
  );
};
