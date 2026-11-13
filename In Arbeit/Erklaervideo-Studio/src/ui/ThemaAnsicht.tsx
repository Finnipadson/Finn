import React, { useEffect, useRef, useState } from "react";
import type { Format } from "../drehbuch/typen";
import { api, warteAuf, type Auftrag, type Eintrag, type Health } from "./api";
import { TYP_NAMEN } from "./szenenVorlagen";

/* Start: Thema eingeben (Claude schreibt) oder ein vorhandenes Drehbuch öffnen. Dazu der System-Check. */
export const ThemaAnsicht: React.FC<{
  projekte: Eintrag[]; beispiele: Eintrag[]; aktivId?: string;
  oeffne: (id: string) => void; nachNeu: (name: string) => Promise<void>;
  health: Health | null; healthFehler: string | null; pruefeHealth: () => void;
}> = ({ projekte, beispiele, aktivId, oeffne, nachNeu, health, healthFehler, pruefeHealth }) => {
  const [vorlagen, setVorlagen] = useState<{ id: string; name: string }[]>([]);
  const [thema, setThema] = useState("");
  const [vorlage, setVorlage] = useState("tech");
  const [format, setFormat] = useState<Format>("quer");
  const [sekunden, setSekunden] = useState(45);
  const [auftrag, setAuftrag] = useState<Auftrag | null>(null);
  const [laeuft, setLaeuft] = useState(false);
  const [sek, setSek] = useState(0);
  const start = useRef(0);

  useEffect(() => { api.vorlagen().then(setVorlagen).catch(() => {}); }, []);
  useEffect(() => {
    if (!laeuft) return;
    const t = setInterval(() => setSek(Math.round((Date.now() - start.current) / 1000)), 1000);
    return () => clearInterval(t);
  }, [laeuft]);

  const schreiben = async () => {
    setLaeuft(true);
    start.current = Date.now();
    setSek(0);
    setAuftrag({ status: "Startet …", fertig: false });
    try {
      const { id } = await api.drehbuchSchreiben({ thema, vorlage, format, sekunden });
      const a = await warteAuf(id, setAuftrag);
      if (a.projekt) await nachNeu(a.projekt);
    } catch (e) {
      setAuftrag({ status: "Fehler", fertig: true, fehler: [(e as Error).message] });
    } finally {
      setLaeuft(false);
    }
  };

  const Karte = ({ e }: { e: Eintrag }) => (
    <button className={`projekt ${e.id === aktivId ? "an" : ""}`} onClick={() => oeffne(e.id)}>
      <div className="projekt-titel">{e.drehbuch.titel}</div>
      <div className="projekt-info">{e.drehbuch.format === "hoch" ? "Hoch" : "Quer"} · {e.drehbuch.szenen.length} Szenen · {e.ton ? "mit Stimme" : "ohne Stimme"}</div>
      <div className="projekt-typen">{e.drehbuch.szenen.map((s) => TYP_NAMEN[s.typ]).join(" → ")}</div>
    </button>
  );

  return (
    <div className="thema-ansicht">
      <div className="stack">
        <section className="card">
          <div className="card-head"><h2>Neues Video: Thema</h2></div>
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
              <span>{auftrag.status}{laeuft ? ` (${sek} s – dauert meist 1–3 Minuten)` : ""}</span>
              {auftrag.fehler && <ul>{auftrag.fehler.map((f) => <li key={f}>{f}</li>)}</ul>}
            </div>
          )}
        </section>

        <section className="card">
          <div className="card-head"><h2>Meine Drehbücher</h2></div>
          {projekte.length === 0 && <div className="muted">Noch keine. Schreib oben eins oder öffne ein Beispiel.</div>}
          <div className="projekte">{projekte.map((e) => <Karte key={e.id} e={e} />)}</div>
        </section>

        <section className="card">
          <div className="card-head"><h2>Beispiele</h2><span className="muted">Beim Speichern wird automatisch eine Kopie angelegt.</span></div>
          <div className="projekte">{beispiele.map((e) => <Karte key={e.id} e={e} />)}</div>
        </section>
      </div>

      <section className="card checks">
        <div className="card-head">
          <h2>System-Check</h2>
          <button className="ghost" onClick={pruefeHealth}>Neu prüfen</button>
        </div>
        {healthFehler && <div className="err">{healthFehler}</div>}
        {!health && !healthFehler && <div className="muted">Prüfe …</div>}
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
        {health && <div className={`summary ${health.ok ? "ok" : "bad"}`}>{health.ok ? "Alles bereit." : "Bitte die rot markierten Punkte beheben."}</div>}
      </section>
    </div>
  );
};
