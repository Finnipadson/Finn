import React from "react";
import { AbsoluteFill } from "remotion";
import type { SzTitel } from "../../drehbuch/typen";
import { sp, T, useSzene } from "../kit";

export const Titel: React.FC<{ sz: SzTitel }> = ({ sz }) => {
  const { f, hoch } = useSzene();
  const groesse = Math.min(hoch ? 150 : 170, (hoch ? 1900 : 2600) / Math.max(6, sz.titel.length));
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", padding: 60 }}>
      <div style={{ textAlign: "center", fontFamily: T.titel }}>
        {sz.kicker && <div style={{ fontFamily: T.mono, fontSize: hoch ? 32 : 28, letterSpacing: 8, color: T.dim, opacity: sp(f - 2), marginBottom: 16 }}>{sz.kicker.toUpperCase()}</div>}
        <div style={{ fontWeight: 900, fontSize: groesse, lineHeight: 1.05, color: T.text, letterSpacing: -2 }}>
          {sz.titel.split(" ").map((wort, wi, arr) => (
            <span key={wi} style={{ display: "inline-block", whiteSpace: "nowrap" }}>
              {wort.split("").map((ch, i) => {
                const idx = arr.slice(0, wi).join(" ").length + i + wi;
                const p = sp(f - 6 - idx * 2.5, 12);
                return <span key={i} style={{ display: "inline-block", opacity: p, transform: `translateY(${(1 - p) * 60}px)`, color: wi === arr.length - 1 && arr.length > 1 ? T.akzent : T.text }}>{ch}</span>;
              })}
              {wi < arr.length - 1 && <span>&nbsp;</span>}
            </span>
          ))}
        </div>
        {sz.unter && (
          <div style={{ fontFamily: T.mono, fontSize: hoch ? 38 : 34, letterSpacing: 8, color: T.akzent, opacity: sp(f - 40), marginTop: 22 }}>
            {sz.unter.toUpperCase()}
          </div>
        )}
      </div>
    </AbsoluteFill>
  );
};
