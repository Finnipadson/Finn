import React, { useState } from "react";
import type { Drehbuch, Szene } from "../drehbuch/typen";
import { api, warteAuf, type Auftrag } from "./api";

/* „Szene neu machen“: Wunsch in eigenen Worten → Claude überarbeitet nur diese Szene.
   Das Ergebnis ersetzt die Szene im Entwurf (noch nicht gespeichert) und lässt sich rückgängig machen. */

const BEISPIELE = ["Kürzer und lockerer", "Ein Rechenbeispiel mit anderen Zahlen", "Als Vergleich statt Stichpunkte", "Mehr Spannung am Anfang"];

export const SzeneNeu: React.FC<{ drehbuch: Drehbuch; index: number; ersetze: (index: number, s: Szene) => void }> = ({ drehbuch, index, ersetze }) => {
  const [offen, setOffen] = useState(false);
  const [wunsch, setWunsch] = useState("");
  const [auftrag, setAuftrag] = useState<Auftrag | null>(null);
  const [vorher, setVorher] = useState<{ index: number; szene: Szene } | null>(null);
  const laeuft = !!auftrag && !auftrag.fertig;

  const los = async () => {
    const alt = drehbuch.szenen[index];
    setAuftrag({ status: "Startet …", fertig: false });
    try {
      const { id } = await api.szeneNeu(drehbuch, index, wunsch);
      const a = await warteAuf(id, setAuftrag);
      if (a.szene) {
        setVorher({ index, szene: alt });
        ersetze(index, a.szene);
        setAuftrag({ ...a, status: `${a.status} Szene ersetzt – noch nicht gespeichert.` });
        setWunsch("");
      }
    } catch (e) {
      setAuftrag({ status: "Fehler", fertig: true, fehler: [(e as Error).message] });
    }
  };

  return (
    <div className={`szene-neu ${offen ? "offen" : ""}`}>
      <div className="szene-neu-kopf">
        <button className="ghost klein" onClick={() => setOffen(!offen)}>✨ Szene neu machen {offen ? "▴" : "▾"}</button>
        {vorher && vorher.index === index && !laeuft && (
          <button className="ghost klein" onClick={() => { ersetze(vorher.index, vorher.szene); setVorher(null); setAuftrag(null); }}>↶ Rückgängig</button>
        )}
      </div>
      {offen && (
        <>
          <textarea rows={2} value={wunsch} disabled={laeuft} placeholder="Was soll anders werden? z. B. „Kürzer und mit einem Beispiel aus dem Alltag“"
            onChange={(e) => setWunsch(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter" && (e.ctrlKey || e.metaKey) && wunsch.trim().length >= 3) los(); }} />
          <div className="row wrap-chips">
            {BEISPIELE.map((b) => <button key={b} className="chip" disabled={laeuft} onClick={() => setWunsch(b)}>{b}</button>)}
            <button className="primary klein" disabled={laeuft || wunsch.trim().length < 3} onClick={los}>{laeuft ? "Claude arbeitet …" : "Neu machen"}</button>
          </div>
          {auftrag && (
            <div className={`status ${auftrag.fehler ? "bad" : auftrag.fertig ? "ok" : ""}`}>
              {!auftrag.fertig && <span className="spinner" />}
              <span>{auftrag.status}</span>
              {auftrag.fehler && <ul>{auftrag.fehler.map((f) => <li key={f}>{f}</li>)}</ul>}
            </div>
          )}
        </>
      )}
    </div>
  );
};
