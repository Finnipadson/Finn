import React from "react";
import { AbsoluteFill } from "remotion";
import type { SzAbschluss } from "../../drehbuch/typen";
import { Kopf, sp, T, useSzene } from "../kit";

export const Abschluss: React.FC<{ sz: SzAbschluss }> = ({ sz }) => {
  const { f, hoch, bei } = useSzene();
  const at = bei(sz.bei, 12);
  const p = f >= at ? sp(f - at, 11) : 0;
  return (
    <AbsoluteFill style={{ paddingTop: hoch ? 170 : 70, alignItems: "center" }}>
      <Kopf kicker={sz.kicker} titel={sz.ueberschrift} />
      <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", paddingBottom: hoch ? 260 : 100 }}>
        <div style={{ textAlign: "center", opacity: p, transform: `scale(${0.85 + 0.15 * p})` }}>
          <div style={{
            fontFamily: T.sans, fontWeight: 900, fontSize: hoch ? 110 : 120, color: T.text, lineHeight: 1.1,
            padding: "24px 60px", borderRadius: 34, border: `6px solid ${T.gruen}`, boxShadow: `0 0 60px ${T.gruen}55`,
            maxWidth: hoch ? 980 : 1600,
          }}>{sz.text}</div>
          {sz.unter && <div style={{ fontFamily: T.mono, fontSize: hoch ? 38 : 32, letterSpacing: 6, color: T.dim, marginTop: 34, opacity: sp(f - at - 20) }}>{sz.unter.toUpperCase()}</div>}
        </div>
      </div>
    </AbsoluteFill>
  );
};
