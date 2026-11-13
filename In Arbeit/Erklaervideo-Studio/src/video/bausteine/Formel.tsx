import React from "react";
import { AbsoluteFill } from "remotion";
import type { SzFormel } from "../../drehbuch/typen";
import { farbe, Kopf, lerp, sp, T, useSzene } from "../kit";

/* Formel baut sich Teil für Teil auf; darunter Rechenschritte (neuester hervorgehoben); „merke“ rahmt die Formel ein. */
export const Formel: React.FC<{ sz: SzFormel }> = ({ sz }) => {
  const { f, hoch, bei } = useSzene();
  const zeiten = sz.teile.map((t, i) => bei(t.bei, 16 + i * 10));
  const schritte = (sz.schritte ?? []).map((s, i) => ({ ...s, t: bei(s.bei, zeiten[zeiten.length - 1] + 40 + i * 50) }));
  const sichtbar = schritte.filter((s) => f >= s.t);
  const merke = sz.merke ? bei(sz.merke.bei, Infinity) : Infinity;
  const box = lerp(f, merke, merke + 14, 0, 1);
  const gross = 1 + sp(f - merke, 9) * 0.12 * (isFinite(merke) && f >= merke ? 1 : 0);
  const fs = hoch ? 120 : 130;
  return (
    <AbsoluteFill style={{ paddingTop: hoch ? 170 : 70, alignItems: "center" }}>
      <Kopf kicker={sz.kicker} titel={sz.ueberschrift} />
      <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: hoch ? 70 : 50, paddingBottom: hoch ? 260 : 120 }}>
        <div style={{
          display: "flex", gap: 28, alignItems: "baseline", flexWrap: "wrap", justifyContent: "center",
          fontFamily: T.sans, fontWeight: 900, fontSize: fs, padding: "10px 50px", borderRadius: 30,
          border: `6px solid rgba(61,220,151,${box})`, boxShadow: `0 0 ${50 * box}px rgba(61,220,151,${0.45 * box})`,
          transform: `scale(${gross})`, maxWidth: hoch ? 1000 : 1700,
        }}>
          {sz.teile.map((t, i) => {
            const p = sp(f - zeiten[i], 12);
            return (
              <span key={i} style={{ color: farbe(t.farbe), opacity: f >= zeiten[i] ? p : 0, transform: `translateY(${(1 - p) * 30}px)`, display: "inline-block" }}>
                {t.text}
              </span>
            );
          })}
        </div>
        {sichtbar.length > 0 && (
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 16 }}>
            {sichtbar.slice(-4).map((s, i, arr) => {
              const neu = i === arr.length - 1;
              const p = sp(f - s.t, 14);
              return (
                <div key={s.text} style={{
                  fontFamily: T.mono, fontWeight: 700, fontSize: neu ? (hoch ? 64 : 60) : (hoch ? 44 : 40),
                  color: neu ? (s === schritte[schritte.length - 1] ? T.gruen : T.text) : T.dim,
                  opacity: neu ? p : 0.7, transform: `translateY(${(1 - p) * 20}px)`,
                }}>{s.text}</div>
              );
            })}
          </div>
        )}
      </div>
    </AbsoluteFill>
  );
};
