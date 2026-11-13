import React from "react";
import { AbsoluteFill, Audio, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import type { Drehbuch, Szene, Timing } from "../drehbuch/typen";
import { schaetzeTiming } from "../drehbuch/pruefen";
import { Ctx, lerp, sp, T } from "./kit";
import { Titel } from "./bausteine/Titel";
import { Stichpunkte } from "./bausteine/Stichpunkte";
import { Vergleich } from "./bausteine/Vergleich";
import { Ablauf } from "./bausteine/Ablauf";
import { Formel } from "./bausteine/Formel";
import { Geometrie } from "./bausteine/Geometrie";
import { Abschluss } from "./bausteine/Abschluss";

/* Spielt ein beliebiges Drehbuch ab. Ohne Timing (noch keine Stimme) wird geschätzt. */

export type ErklaervideoProps = {
  drehbuch: Drehbuch;
  timing: Timing | null;
  audio: string | null; // Pfad im public-Ordner, z. B. "ton/pythagoras.wav"
};

const Baustein: React.FC<{ sz: Szene }> = ({ sz }) => {
  switch (sz.typ) {
    case "titel": return <Titel sz={sz} />;
    case "stichpunkte": return <Stichpunkte sz={sz} />;
    case "vergleich": return <Vergleich sz={sz} />;
    case "ablauf": return <Ablauf sz={sz} />;
    case "formel": return <Formel sz={sz} />;
    case "geometrie": return <Geometrie sz={sz} />;
    case "abschluss": return <Abschluss sz={sz} />;
  }
};

const Hintergrund: React.FC<{ f: number; W: number; H: number }> = ({ f, W, H }) => (
  <AbsoluteFill>
    <AbsoluteFill style={{ background: `radial-gradient(${W * 0.65}px ${H * 0.75}px at 50% 40%, #171c38 0%, ${T.bg} 70%)` }} />
    <svg width={W} height={H} style={{ position: "absolute" }}>
      <defs>
        <filter id="blob"><feGaussianBlur stdDeviation={90} /></filter>
        <pattern id="punkte" width={48} height={48} patternUnits="userSpaceOnUse"><circle cx={2} cy={2} r={1.6} fill="#fff" opacity={0.07} /></pattern>
      </defs>
      <g filter="url(#blob)" opacity={0.55}>
        <circle cx={W * 0.22 + Math.sin(f / 240) * 120} cy={H * 0.28 + Math.cos(f / 300) * 80} r={Math.min(W, H) * 0.25} fill={T.lila} opacity={0.45} />
        <circle cx={W * 0.8 + Math.cos(f / 260) * 140} cy={H * 0.68 + Math.sin(f / 220) * 90} r={Math.min(W, H) * 0.28} fill={T.akzent} opacity={0.3} />
        <circle cx={W * 0.58 + Math.sin(f / 330) * 160} cy={H * 0.18 + Math.sin(f / 280) * 60} r={Math.min(W, H) * 0.19} fill={T.teal} opacity={0.25} />
      </g>
      <rect width={W} height={H} fill="url(#punkte)" transform={`translate(${(f * 0.15) % 48} 0)`} />
    </svg>
  </AbsoluteFill>
);

const Untertitel: React.FC<{ f: number; timing: Timing; hoch: boolean }> = ({ f, timing, hoch }) => {
  const S = (s: number) => Math.round(s * timing.fps);
  // Zeilen bilden: Umbruch nach Satzende, langem Komma-Teil oder zu vielen Zeichen
  const zeilen: { w: { text: string; at: number }[]; von: number; bis: number }[] = [];
  let cur: { text: string; at: number; end: number }[] = [];
  const maxZ = hoch ? 26 : 52;
  for (const w of timing.woerter) {
    cur.push({ text: w.text, at: S(w.start), end: S(w.end) });
    const len = cur.map((x) => x.text).join(" ").length;
    if (/[.!?:]$/.test(w.text) || (/,$/.test(w.text) && len > maxZ * 0.45) || len > maxZ) {
      zeilen.push({ w: cur, von: cur[0].at, bis: cur[cur.length - 1].end + 45 });
      cur = [];
    }
  }
  if (cur.length) zeilen.push({ w: cur, von: cur[0].at, bis: cur[cur.length - 1].end + 45 });
  zeilen.forEach((z, i) => { if (i + 1 < zeilen.length) z.bis = Math.min(z.bis, zeilen[i + 1].von); });
  const z = zeilen.find((x) => f >= x.von && f < x.bis);
  if (!z) return null;
  const sichtbar = z.w.filter((w) => f >= w.at);
  const aktiv = sichtbar[sichtbar.length - 1];
  return (
    <div style={{
      position: "absolute", left: hoch ? 50 : 160, right: hoch ? 50 : 160, top: hoch ? 1640 : 948,
      display: "flex", flexWrap: "wrap", justifyContent: "center", gap: hoch ? "10px 12px" : "6px 10px",
      fontFamily: T.sans, fontWeight: 800, fontSize: hoch ? 66 : 46,
    }}>
      {sichtbar.map((w) => {
        const pop = sp(f - w.at, 12, 0.6, 220);
        const an = w === aktiv;
        return (
          <span key={w.text + w.at} style={{
            display: "inline-block", padding: "1px 12px", borderRadius: 14,
            background: an ? T.gelb : "rgba(0,0,0,0.38)", color: an ? "#141414" : "#fff",
            transform: `scale(${0.75 + 0.25 * pop}) translateY(${(1 - pop) * 10}px)`,
          }}>{w.text}</span>
        );
      })}
    </div>
  );
};

export const Erklaervideo: React.FC<ErklaervideoProps> = ({ drehbuch, timing, audio }) => {
  const f = useCurrentFrame();
  const { width: W, height: H, durationInFrames } = useVideoConfig();
  const tm = timing ?? schaetzeTiming(drehbuch);
  const S = (s: number) => Math.round(s * tm.fps);
  const hoch = drehbuch.format === "hoch";
  const fadeIn = lerp(f, 0, 20, 0, 1);
  const fadeOut = lerp(f, durationInFrames - 30, durationInFrames, 1, 0);

  return (
    <AbsoluteFill style={{ backgroundColor: T.bg }}>
      {/* "ton/x.wav" → aus public/ (Rendern); "/ton/x.wav?v=…" → direkt (App-Vorschau, mit Cache-Schutz) */}
      {audio && <Audio src={audio.startsWith("/") || audio.startsWith("http") ? audio : staticFile(audio)} />}
      <AbsoluteFill style={{ opacity: fadeIn * fadeOut }}>
        <Hintergrund f={f} W={W} H={H} />
        {drehbuch.szenen.map((sz, i) => {
          const info = tm.szenen[i];
          if (!info) return null;
          const start = i === 0 ? 0 : S(info.start);
          const ende = S(info.ende);
          if (f < start - 2 || f > ende + 24) return null;
          const inP = i === 0 ? 1 : lerp(f, start, start + 22, 0, 1);
          const outP = i === drehbuch.szenen.length - 1 ? 0 : lerp(f, ende - 4, ende + 20, 0, 1);
          const drift = 1 + 0.025 * ((f - start) / Math.max(1, ende - start));
          const beiFn = (wert: string | undefined, ersatz: number) => {
            if (wert && info.bei[wert] !== undefined) return S(info.bei[wert]) - start;
            return ersatz;
          };
          return (
            <AbsoluteFill key={i} style={{
              opacity: inP * (1 - outP),
              transform: `scale(${drift * (0.97 + 0.03 * inP) * (1 + 0.04 * outP)})`,
              filter: outP > 0.01 || inP < 0.99 ? `blur(${(1 - inP) * 10 + outP * 10}px)` : undefined,
            }}>
              <Ctx.Provider value={{ f: f - start, dauer: ende - start, hoch, W, H, bei: beiFn }}>
                <Baustein sz={sz} />
              </Ctx.Provider>
            </AbsoluteFill>
          );
        })}
        <AbsoluteFill style={{ background: `radial-gradient(${W * 0.75}px ${H * 0.85}px at 50% 45%, transparent 60%, rgba(0,0,0,.55) 100%)` }} />
        <Untertitel f={f} timing={tm} hoch={hoch} />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

export const dauerInBildern = (d: Drehbuch, t: Timing | null) => Math.ceil((t ?? schaetzeTiming(d)).dauer * 60);
