import React, { useEffect, useMemo, useRef, useState } from "react";
import { Player } from "@remotion/player";
import { dauerInBildern, Erklaervideo } from "./video/Erklaervideo";
import { pruefeDrehbuch } from "./drehbuch/pruefen";
import type { Drehbuch, Format, Timing } from "./drehbuch/typen";

type Check = { name: string; ok: boolean; detail: string; hint?: string };
type Health = { ok: boolean; checks: Check[] };
type Eintrag = { id: string; name: string; titel: string; drehbuch: Drehbuch; timing: Timing | null; ton: boolean | null; quelle: "projekt" | "beispiel" };
type Auftrag = { status: string; fertig: boolean; fehler?: string[]; fehlerArt?: string; projekt?: string };

// Beispiel-Drehbücher + (falls erzeugt) ihre Zeitlisten aus dem Ordner beispiele/
const dateien = import.meta.glob("../beispiele/*.json", { eager: true, import: "default" }) as Record<string, unknown>;
const BEISPIELE: Eintrag[] = Object.entries(dateien)
  .filter(([p]) => !p.endsWith(".timing.json"))
  .map(([p, d]) => {
    const name = p.split("/").pop()!.replace(/\.json$/, "");
    const drehbuch = d as Drehbuch;
    return { id: `b:${name}`, name, titel: drehbuch.titel, drehbuch, timing: (dateien[`../beispiele/${name}.timing.json`] as Timing | undefined) ?? null, ton: null, quelle: "beispiel" };
  });

const STEPS = [
  { n: 1, label: "Thema", phase: 2, aktiv: true },
  { n: 2, label: "Drehbuch", phase: 3 },
  { n: 3, label: "Einstellungen", phase: 3 },
  { n: 4, label: "Vorschau", phase: 1, aktiv: true },
  { n: 5, label: "Rendern", phase: 4 },
];

export const App: React.FC = () => {
  const [health, setHealth] = useState<Health | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [vorlagen, setVorlagen] = useState<{ id: string; name: string }[]>([]);
  const [projekte, setProjekte] = useState<Eintrag[]>([]);
  const [auswahl, setAuswahl] = useState(BEISPIELE[0]?.id ?? "");
  const [mitTon, setMitTon] = useState(true);
  const [tonDa, setTonDa] = useState(false);
  // Thema-Eingabe
  const [thema, setThema] = useState("");
  const [vorlage, setVorlage] = useState("tech");
  const [format, setFormat] = useState<Format>("quer");
  const [sekunden, setSekunden] = useState(45);
  const [auftrag, setAuftrag] = useState<Auftrag | null>(null);
  const [laeuft, setLaeuft] = useState(false);
  const startZeit = useRef(0);
  const [sek, setSek] = useState(0);

  const loadHealth = () => {
    setHealth(null);
    setError(null);
    fetch("/api/health")
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`Server antwortet mit ${r.status}`))))
      .then(setHealth)
      .catch(() => setError("Der lokale Server läuft nicht. Bitte über start.bat starten."));
  };
  const loadProjekte = () =>
    fetch("/api/projekte").then((r) => (r.ok ? r.json() : [])).then((list: { name: string; drehbuch: Drehbuch; timing: Timing | null; ton: boolean }[]) => {
      const e = list.map<Eintrag>((p) => ({ id: `p:${p.name}`, name: p.name, titel: p.drehbuch.titel, drehbuch: p.drehbuch, timing: p.timing, ton: p.ton, quelle: "projekt" }));
      setProjekte(e);
      return e;
    }).catch(() => []);
  useEffect(() => {
    loadHealth();
    loadProjekte();
    fetch("/api/vorlagen").then((r) => (r.ok ? r.json() : [])).then(setVorlagen).catch(() => {});
  }, []);

  const alle = [...projekte, ...BEISPIELE];
  const eintrag = alle.find((b) => b.id === auswahl) ?? alle[0];
  useEffect(() => {
    setTonDa(false);
    if (!eintrag) return;
    fetch(`/ton/${eintrag.name}.wav`, { method: "HEAD" })
      .then((r) => setTonDa(r.ok && (r.headers.get("content-type") ?? "").includes("audio")))
      .catch(() => setTonDa(false));
  }, [eintrag?.id]);

  // Drehbuch schreiben lassen + Status abfragen
  const schreiben = async () => {
    setLaeuft(true);
    setAuftrag({ status: "Startet …", fertig: false });
    startZeit.current = Date.now();
    try {
      const r = await fetch("/api/drehbuch", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ thema, vorlage, format, sekunden }) });
      const j = await r.json();
      if (!r.ok) throw new Error(j.fehler ?? "Fehler beim Start");
      for (;;) {
        await new Promise((res) => setTimeout(res, 1500));
        const a: Auftrag = await (await fetch(`/api/auftrag/${j.id}`)).json();
        setAuftrag(a);
        if (a.fertig) {
          if (a.projekt) { await loadProjekte(); setAuswahl(`p:${a.projekt}`); }
          break;
        }
      }
    } catch (e) {
      setAuftrag({ status: "Fehler", fertig: true, fehler: [(e as Error).message] });
    } finally {
      setLaeuft(false);
    }
  };
  useEffect(() => {
    if (!laeuft) return;
    const t = setInterval(() => setSek(Math.round((Date.now() - startZeit.current) / 1000)), 1000);
    return () => clearInterval(t);
  }, [laeuft]);

  const fehler = useMemo(() => (eintrag ? pruefeDrehbuch(eintrag.drehbuch) : []), [eintrag]);
  const nutzeTon = mitTon && tonDa && !!eintrag?.timing;
  const props = eintrag ? { drehbuch: eintrag.drehbuch, timing: nutzeTon ? eintrag.timing : null, audio: nutzeTon ? `ton/${eintrag.name}.wav` : null } : null;
  const hoch = eintrag?.drehbuch.format === "hoch";
  const pfad = eintrag ? (eintrag.quelle === "projekt" ? `projekte/${eintrag.name}/drehbuch.json` : `beispiele/${eintrag.name}.json`) : "";

  return (
    <div className="app">
      <header className="top">
        <div className="logo"><span className="play" />Erklärvideo-Studio</div>
        <div className="phase">Phase 2 · Claude schreibt das Drehbuch</div>
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
        <div className="stack">
          <section className="card">
            <div className="card-head"><h2>Thema</h2></div>
            <textarea className="thema" rows={2} placeholder="z. B. „Wie funktioniert ein Akku?“ oder „Prozentrechnung für die 7. Klasse“"
              value={thema} maxLength={300} onChange={(e) => setThema(e.target.value)} disabled={laeuft} />
            <div className="row wrap">
              <label className="mini">Vorlage
                <select value={vorlage} onChange={(e) => setVorlage(e.target.value)} disabled={laeuft}>
                  {vorlagen.map((v) => <option key={v.id} value={v.id}>{v.name}</option>)}
                </select>
              </label>
              <label className="mini">Format
                <select value={format} onChange={(e) => setFormat(e.target.value as Format)} disabled={laeuft}>
                  <option value="quer">Quer 16:9 (YouTube)</option>
                  <option value="hoch">Hoch 9:16 (TikTok)</option>
                </select>
              </label>
              <label className="mini">Länge
                <select value={sekunden} onChange={(e) => setSekunden(Number(e.target.value))} disabled={laeuft}>
                  {[30, 45, 60, 90].map((s) => <option key={s} value={s}>ca. {s} s</option>)}
                </select>
              </label>
              <button className="primary" disabled={laeuft || thema.trim().length < 3} onClick={schreiben}>
                {laeuft ? "Claude schreibt …" : "Drehbuch schreiben"}
              </button>
            </div>
            {auftrag && (
              <div className={`status ${auftrag.fehler ? "bad" : auftrag.fertig ? "ok" : ""}`}>
                {!auftrag.fertig && <span className="spinner" />}
                <span>{auftrag.status}{laeuft ? ` (${sek} s)` : ""}</span>
                {auftrag.fehler && <ul>{auftrag.fehler.map((f) => <li key={f}>{f}</li>)}</ul>}
              </div>
            )}
          </section>

          <section className="card preview">
            <div className="card-head">
              <h2>Vorschau</h2>
              <div className="row">
                <select value={eintrag?.id ?? ""} onChange={(e) => setAuswahl(e.target.value)}>
                  {projekte.length > 0 && <optgroup label="Meine Drehbücher">{projekte.map((b) => <option key={b.id} value={b.id}>{b.titel} ({b.drehbuch.format})</option>)}</optgroup>}
                  <optgroup label="Beispiele">{BEISPIELE.map((b) => <option key={b.id} value={b.id}>{b.titel} ({b.drehbuch.format})</option>)}</optgroup>
                </select>
                <label className="toggle" title={tonDa ? "" : "Noch kein Ton erzeugt"}>
                  <input type="checkbox" checked={mitTon} disabled={!tonDa} onChange={(e) => setMitTon(e.target.checked)} /> mit Stimme
                </label>
              </div>
            </div>
            {props && fehler.length === 0 && (
              <div className={`player-wrap ${hoch ? "hoch" : "quer"}`}>
                <Player
                  key={`${eintrag?.id}-${nutzeTon}`}
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
              {nutzeTon ? "Mit echter Stimme, Geräuschen und Musik." : "Ohne Stimme: Zeiten sind geschätzt."}
              {eintrag && <> · {eintrag.drehbuch.szenen.length} Szenen: {eintrag.drehbuch.szenen.map((s) => s.typ).join(" → ")}</>}
            </div>
            {eintrag && !nutzeTon && (
              <div className="muted hint-line">Stimme + Video erzeugen (bis Phase 4 per Terminal): <code>npm run ton -- {pfad}</code> · <code>npm run render -- {pfad}</code></div>
            )}
          </section>
        </div>

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
