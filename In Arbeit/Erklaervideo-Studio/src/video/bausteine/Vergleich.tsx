import React from "react";
import { AbsoluteFill } from "remotion";
import type { Seite, SzVergleich } from "../../drehbuch/typen";
import { Icon, Karte, Kopf, Pop, T, sp, useSzene } from "../kit";

const Spalte: React.FC<{ s: Seite; gut: boolean; start: number }> = ({ s, gut, start }) => {
  const { hoch, bei, f } = useSzene();
  const col = gut ? T.gruen : T.rot;
  const at = bei(s.bei, start);
  const glow = gut ? sp(f - at - 10) : 0;
  return (
    <Pop at={at} style={{ flex: 1 }}>
      <Karte glow={gut ? T.gruen : undefined} style={{ padding: hoch ? "40px 44px" : "40px 44px", height: "100%", opacity: gut ? 1 : 0.85, boxShadow: gut ? `0 30px 60px rgba(0,0,0,.45), 0 0 ${60 * glow}px ${T.gruen}40` : undefined }}>
        <div style={{ display: "flex", alignItems: "center", gap: 18, marginBottom: 26 }}>
          <div style={{ width: 70, height: 70, borderRadius: 35, background: `${col}22`, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <Icon name={s.icon ?? (gut ? "haken" : "kreuz")} size={40} color={col} />
          </div>
          <div style={{ fontFamily: T.sans, fontWeight: 800, fontSize: hoch ? 54 : 46, color: T.text }}>{s.titel}</div>
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: hoch ? 22 : 26 }}>
          {s.punkte.map((p, i) => (
            <Pop key={i} at={bei(p.bei, at + 16 + i * 12)} from={20}>
              <div style={{ display: "flex", gap: 16, alignItems: "flex-start", fontFamily: T.sans, fontSize: hoch ? 42 : 38, color: gut ? T.text : T.dim, lineHeight: 1.3 }}>
                <div style={{ marginTop: hoch ? 8 : 4 }}><Icon name={gut ? "haken" : "kreuz"} size={hoch ? 36 : 30} color={col} width={2.6} /></div>
                {p.text}
              </div>
            </Pop>
          ))}
        </div>
      </Karte>
    </Pop>
  );
};

export const Vergleich: React.FC<{ sz: SzVergleich }> = ({ sz }) => {
  const { hoch } = useSzene();
  return (
    <AbsoluteFill style={{ paddingTop: hoch ? 170 : 70, alignItems: "center" }}>
      <Kopf kicker={sz.kicker} titel={sz.ueberschrift} />
      <div style={{ flex: 1, display: "flex", alignItems: "center", paddingBottom: hoch ? 300 : 140 }}>
      <div style={{
        display: "flex", flexDirection: hoch ? "column" : "row", gap: hoch ? 40 : 50,
        width: hoch ? 940 : 1640, height: hoch ? 1150 : 500,
      }}>
        <Spalte s={sz.links} gut={false} start={20} />
        <div style={{ alignSelf: "center", fontFamily: T.mono, fontSize: 34, color: T.dim, flexShrink: 0 }}>vs.</div>
        <Spalte s={sz.rechts} gut start={60} />
      </div>
      </div>
    </AbsoluteFill>
  );
};
