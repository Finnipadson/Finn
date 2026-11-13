import React from "react";

/* Kleine Formular-Bausteine für den Editor. */

export const Feld: React.FC<{ label: string; children: React.ReactNode; breit?: boolean }> = ({ label, children, breit }) => (
  <label className={`feld ${breit ? "breit" : ""}`}><span>{label}</span>{children}</label>
);

export const Text: React.FC<{ wert?: string; setze: (v: string) => void; platz?: string; max?: number }> = ({ wert, setze, platz, max = 80 }) => (
  <input value={wert ?? ""} placeholder={platz} maxLength={max} onChange={(e) => setze(e.target.value)} />
);

export const Zahl: React.FC<{ wert?: number; setze: (v: number) => void; schritt?: number; min?: number; max?: number }> = ({ wert, setze, schritt = 1, min, max }) => (
  <input type="number" value={wert ?? 0} step={schritt} min={min} max={max} onChange={(e) => setze(Number(e.target.value))} />
);

export const Auswahl: React.FC<{ wert?: string; setze: (v: string) => void; optionen: (string | [string, string])[]; leer?: string }> = ({ wert, setze, optionen, leer }) => (
  <select value={wert ?? ""} onChange={(e) => setze(e.target.value)}>
    {leer !== undefined && <option value="">{leer}</option>}
    {optionen.map((o) => {
      const [v, l] = Array.isArray(o) ? o : [o, o];
      return <option key={v} value={v}>{l}</option>;
    })}
  </select>
);

/** „bei“-Auswahl: Wörter des Sprechertexts der Szene. Unbekannte Werte bleiben sichtbar (rot). */
export const Bei: React.FC<{ wert?: string; setze: (v: string | undefined) => void; woerter: string[] }> = ({ wert, setze, woerter }) => {
  const fehlt = !!wert && !woerter.includes(wert);
  return (
    <select className={fehlt ? "falsch" : ""} value={wert ?? ""} title="Erscheint, wenn dieses Wort gesprochen wird"
      onChange={(e) => setze(e.target.value || undefined)}>
      <option value="">(automatisch)</option>
      {fehlt && <option value={wert}>{wert} – nicht im Text!</option>}
      {woerter.map((w) => <option key={w} value={w}>{w}</option>)}
    </select>
  );
};

/** Liste mit Hinzufügen / Entfernen / Verschieben. */
export function Liste<T>({ titel, eintraege, setze, neu, render, min = 0, max = 8 }: {
  titel: string; eintraege: T[]; setze: (l: T[]) => void; neu: () => NoInfer<T>;
  render: (e: T, setzeE: (e: T) => void, i: number) => React.ReactNode; min?: number; max?: number;
}) {
  return (
    <div className="liste">
      <div className="liste-kopf"><span>{titel}</span>
        {eintraege.length < max && <button className="mini-btn" onClick={() => setze([...eintraege, neu()])}>+ hinzufügen</button>}
      </div>
      {eintraege.map((e, i) => (
        <div key={i} className="liste-zeile">
          <div className="liste-inhalt">{render(e, (n) => setze(eintraege.map((x, j) => (j === i ? n : x))), i)}</div>
          <div className="liste-aktionen">
            <button className="mini-btn" disabled={i === 0} title="nach oben" onClick={() => { const l = [...eintraege]; [l[i - 1], l[i]] = [l[i], l[i - 1]]; setze(l); }}>↑</button>
            <button className="mini-btn" disabled={i === eintraege.length - 1} title="nach unten" onClick={() => { const l = [...eintraege]; [l[i + 1], l[i]] = [l[i], l[i + 1]]; setze(l); }}>↓</button>
            <button className="mini-btn rot" disabled={eintraege.length <= min} title="entfernen" onClick={() => setze(eintraege.filter((_, j) => j !== i))}>✕</button>
          </div>
        </div>
      ))}
    </div>
  );
}
