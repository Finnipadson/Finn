import React from "react";
import { AbsoluteFill } from "remotion";
import type { SzStichpunkte } from "../../drehbuch/typen";
import { Icon, Karte, Kopf, Pop, T, useSzene } from "../kit";

const FARBEN = [T.blau, T.teal, T.lila, T.akzent, T.gelb];

export const Stichpunkte: React.FC<{ sz: SzStichpunkte }> = ({ sz }) => {
  const { hoch, bei } = useSzene();
  const n = sz.punkte.length;
  return (
    <AbsoluteFill style={{ paddingTop: hoch ? 170 : 70, alignItems: "center" }}>
      <Kopf kicker={sz.kicker} titel={sz.ueberschrift} />
      <div style={{
        marginTop: hoch ? 80 : 70, display: "flex", flexDirection: hoch ? "column" : "row",
        gap: hoch ? 34 : 40, padding: "0 60px", width: "100%", justifyContent: "center",
      }}>
        {sz.punkte.map((p, i) => {
          const col = FARBEN[i % FARBEN.length];
          return (
            <Pop key={i} at={bei(p.bei, 20 + i * 14)} style={{ flex: hoch ? undefined : `0 1 ${Math.min(440, 1700 / n)}px` }}>
              <Karte glow={col} style={hoch
                ? { display: "flex", alignItems: "center", gap: 34, padding: "34px 40px" }
                : { display: "flex", flexDirection: "column", alignItems: "center", gap: 18, padding: "44px 30px", height: 340, justifyContent: "center", textAlign: "center" }}>
                <div style={{ width: hoch ? 120 : 120, height: hoch ? 120 : 120, borderRadius: 60, background: `${col}22`, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                  <Icon name={p.icon} size={62} color={col} />
                </div>
                <div>
                  <div style={{ fontFamily: T.sans, fontWeight: 800, fontSize: hoch ? 58 : 44, color: T.text, lineHeight: 1.15 }}>{p.text}</div>
                  {p.unter && <div style={{ fontFamily: T.sans, fontSize: hoch ? 36 : 26, color: T.dim, marginTop: 8 }}>{p.unter}</div>}
                </div>
              </Karte>
            </Pop>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};
