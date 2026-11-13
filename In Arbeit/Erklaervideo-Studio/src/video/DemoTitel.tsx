import React from "react";
import { AbsoluteFill, Easing, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";

// Platzhalter-Szene für Phase 0: zeigt, dass die Live-Vorschau (Remotion-Player) funktioniert.
// Ab Phase 1 wird hier das Drehbuch aus Szenen-Bausteinen gerendert.

export type DemoTitelProps = { titel: string; unter: string };

export const DemoTitel: React.FC<DemoTitelProps> = ({ titel, unter }) => {
  const f = useCurrentFrame();
  const { fps, width, height, durationInFrames } = useVideoConfig();
  const hoch = height > width;
  const out = interpolate(f, [durationInFrames - 20, durationInFrames], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const drift = interpolate(f, [0, durationInFrames], [1, 1.04], { easing: Easing.inOut(Easing.quad) });
  return (
    <AbsoluteFill style={{ background: "radial-gradient(1200px 900px at 50% 40%, #1b2142 0%, #0d1020 70%)", opacity: out }}>
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", transform: `scale(${drift})` }}>
        <div style={{ textAlign: "center", fontFamily: "'Segoe UI', Arial, sans-serif" }}>
          <div style={{ fontWeight: 900, fontSize: hoch ? 130 : 150, color: "#eef0f7", letterSpacing: -2 }}>
            {titel.split("").map((ch, i) => {
              const p = spring({ frame: f - 6 - i * 3, fps, config: { damping: 12, mass: 0.8 } });
              return (
                <span key={i} style={{ display: "inline-block", opacity: p, transform: `translateY(${(1 - p) * 60}px)` }}>
                  {ch === " " ? " " : ch}
                </span>
              );
            })}
          </div>
          <div style={{
            fontFamily: "'Cascadia Code', Consolas, monospace", fontSize: hoch ? 34 : 36, letterSpacing: 8, color: "#ff7a59",
            opacity: spring({ frame: f - 40, fps }), marginTop: 10,
          }}>
            {unter.toUpperCase()}
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
