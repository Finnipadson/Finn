import React from "react";
import {
  AbsoluteFill, Audio, Sequence, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig,
} from "remotion";
import WORDS from "./words.json";

// ── Timing: alles richtet sich nach der Sprecherstimme (words.json aus voice.py) ──
export const FPS = 30;
const VOICE_DELAY = 15;
type Word = { text: string; start: number; end: number };
const words = WORDS as Word[];
const sec = (s: number) => Math.round(s * FPS) + VOICE_DELAY;
const bare = (s: string) => s.replace(/[.,:!?]+$/, "");
const at = (text: string, nth = 0) => {
  const w = words.filter((x) => bare(x.text) === text)[nth];
  if (!w) throw new Error(`Wort "${text}" (#${nth}) fehlt in words.json`);
  return sec(w.start);
};

const T = {
  triangle: at("rechtwinklige"),
  katheten: at("Katheten"),
  labelA: at("a"),
  labelB: at("b"),
  hyp: at("Hypotenuse"),
  labelC: at("c"),
  squares: at("Quadrat"),
  pulseAB: at("zusammen"),
  pulseC: at("große"),
  formula: at("Also"),
  plus: at("plus"),
  equals: at("gleich"),
  example: at("Beispiel"),
  a3: at("3"),
  b4: at("4"),
  gridA: at("mal", 0),
  nine: at("9"),
  gridB: at("mal", 1),
  sixteen: at("16"),
  sum: at("9", 1),
  gridC: at("25"),
  root: at("Wurzel"),
  five: at("5"),
  merke: at("Merke"),
};
export const DURATION_IN_FRAMES = sec(words[words.length - 1].end) + 60;

// ── Farben ─────────────────────────────────────────────
const C = {
  bg: "#171a24",
  grid: "#222736",
  text: "#f2f2ee",
  dim: "#8a91a3",
  a: "#4fd1ff",
  b: "#f2c94c",
  c: "#ff6b5b",
  ok: "#3ecf8e",
  sans: "'Segoe UI', Arial, sans-serif",
  mono: "Consolas, 'Courier New', monospace",
};

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const lerp = (f: number, a: number, b: number, from: number, to: number) =>
  interpolate(f, [a, b], [from, to], clamp);
const pulse = (f: number, start: number) =>
  f < start ? 1 : 1 + Math.sin(Math.min(1, (f - start) / 18) * Math.PI) * 0.08;

// ── Geometrie: 3-4-5-Dreieck, 1 Einheit = 80 px ───────
const U = 80;
const P = (x: number, y: number) => [380 + x * U, 860 - y * U] as const;
const [Ox, Oy] = P(0, 0);   // rechter Winkel
const [Ax, Ay] = P(0, 3);   // oben (Kathete a, senkrecht)
const [Bx, By] = P(4, 0);   // rechts (Kathete b, waagerecht)
const HYP_ANGLE = (Math.atan2(By - Ay, Bx - Ax) * 180) / Math.PI; // ≈ 36,87°

// ── Untertitel ─────────────────────────────────────────
type Line = { words: { text: string; at: number }[]; from: number; to: number };
const LINES: Line[] = (() => {
  const lines: { text: string; at: number }[][] = [];
  let cur: { text: string; at: number }[] = [];
  for (const w of words) {
    cur.push({ text: w.text, at: sec(w.start) });
    const chars = cur.map((x) => x.text).join(" ").length;
    if ((/[.,:!?]$/.test(w.text) && cur.length >= 2) || cur.length >= 6 || chars > 26) {
      lines.push(cur);
      cur = [];
    }
  }
  if (cur.length) lines.push(cur);
  const lastEnd = sec(words[words.length - 1].end) + 30;
  return lines.map((l, i) => ({ words: l, from: l[0].at, to: i + 1 < lines.length ? lines[i + 1][0].at : lastEnd }));
})();

const Captions: React.FC<{ frame: number }> = ({ frame }) => {
  const line = LINES.find((l) => frame >= l.from && frame < l.to);
  if (!line) return null;
  const visible = line.words.filter((w) => frame >= w.at);
  const current = visible[visible.length - 1];
  return (
    <div style={{
      position: "absolute", left: 60, right: 60, top: 1610, display: "flex",
      flexWrap: "wrap", justifyContent: "center", gap: "0 20px",
      fontFamily: C.sans, fontWeight: 800, fontSize: 76, lineHeight: 1.2,
      textShadow: "0 5px 0 rgba(0,0,0,0.5)",
    }}>
      {visible.map((w) => (
        <span key={w.text + w.at} style={{
          color: w === current ? C.a : C.text,
          transform: `scale(${lerp(frame, w.at, w.at + 5, 0.6, 1)})`, display: "inline-block",
        }}>{w.text}</span>
      ))}
    </div>
  );
};

// ── Quadrate auf den Seiten ────────────────────────────
const GridLines: React.FC<{ n: number; size: number; color: string; progress: number }> = ({ n, size, color, progress }) => (
  <g opacity={progress}>
    {Array.from({ length: n - 1 }, (_, i) => {
      const p = ((i + 1) * size) / n;
      return (
        <g key={i}>
          <line x1={p} y1={0} x2={p} y2={size * progress} stroke={color} strokeWidth={3} opacity={0.7} />
          <line x1={0} y1={p} x2={size * progress} y2={p} stroke={color} strokeWidth={3} opacity={0.7} />
        </g>
      );
    })}
  </g>
);

const Squares: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const g = (d: number) => spring({ frame: frame - T.squares - d, fps, config: { damping: 14 } });
  const sa = g(0), sb = g(8), sc = g(16);
  const pa = pulse(frame, T.pulseAB) * pulse(frame, T.merke);
  const pc = pulse(frame, T.pulseC) * pulse(frame, T.merke + 10);
  const ga = lerp(frame, T.gridA, T.gridA + 15, 0, 1);
  const gb = lerp(frame, T.gridB, T.gridB + 15, 0, 1);
  const gc = lerp(frame, T.gridC, T.gridC + 15, 0, 1);
  const num = (t: number) => spring({ frame: frame - t, fps, config: { damping: 10 } });
  const cA = [Ox - 1.5 * U, Oy - 1.5 * U];
  const cB = [Ox + 2 * U, Oy + 2 * U];
  const cC = [(Ax + Bx) / 2 + 2.5 * U * 0.6, (Ay + By) / 2 - 2.5 * U * 0.8];

  return (
    <g>
      {/* a² links an der senkrechten Kathete */}
      <g transform={`translate(${cA[0]} ${cA[1]}) scale(${pa}) translate(${-cA[0]} ${-cA[1]})`}>
        <g transform={`translate(${Ox} ${Ay}) scale(${-sa} 1)`}>
          <rect width={3 * U} height={3 * U} fill={C.a} fillOpacity={0.22} stroke={C.a} strokeWidth={5} />
          <GridLines n={3} size={3 * U} color={C.a} progress={ga} />
        </g>
      </g>
      {/* b² unter der waagerechten Kathete */}
      <g transform={`translate(${cB[0]} ${cB[1]}) scale(${pa}) translate(${-cB[0]} ${-cB[1]})`}>
        <g transform={`translate(${Ox} ${Oy}) scale(1 ${sb})`}>
          <rect width={4 * U} height={4 * U} fill={C.b} fillOpacity={0.22} stroke={C.b} strokeWidth={5} />
          <GridLines n={4} size={4 * U} color={C.b} progress={gb} />
        </g>
      </g>
      {/* c² außen an der Hypotenuse */}
      <g transform={`translate(${cC[0]} ${cC[1]}) scale(${pc}) translate(${-cC[0]} ${-cC[1]})`}>
        <g transform={`translate(${Ax} ${Ay}) rotate(${HYP_ANGLE}) scale(1 ${-sc})`}>
          <rect width={5 * U} height={5 * U} fill={C.c} fillOpacity={0.22} stroke={C.c} strokeWidth={5} />
          <GridLines n={5} size={5 * U} color={C.c} progress={gc} />
        </g>
      </g>

      {/* Flächen-Zahlen */}
      {[
        { t: T.nine, txt: "9", p: cA, col: C.a },
        { t: T.sixteen, txt: "16", p: cB, col: C.b },
        { t: T.gridC, txt: "25", p: cC, col: C.c },
      ].map(({ t, txt, p, col }) => {
        const s = num(t);
        if (frame < t) return null;
        return (
          <g key={txt} transform={`translate(${p[0]} ${p[1]}) scale(${s})`}>
            <circle r={62} fill={C.bg} stroke={col} strokeWidth={5} />
            <text y={24} textAnchor="middle" fontFamily={C.sans} fontWeight={900} fontSize={66} fill={C.text}>{txt}</text>
          </g>
        );
      })}
    </g>
  );
};

// ── Dreieck mit Beschriftung ───────────────────────────
const Triangle: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const draw = lerp(frame, T.triangle, T.triangle + 30, 0, 1);
  const legs = lerp(frame, T.katheten, T.katheten + 10, 0, 1);
  const hyp = lerp(frame, T.hyp, T.hyp + 10, 0, 1);
  const lbl = (t: number) => spring({ frame: frame - t, fps, config: { damping: 11 } });
  const total = 3 * U + 4 * U + 5 * U;
  const thick = (on: number) => 6 + on * 6;
  const aTxt = frame >= T.a3 ? "a=3" : "a";
  const bTxt = frame >= T.b4 ? "b=4" : "b";
  const cTxt = frame >= T.five ? "c=5" : frame >= T.example ? "c=?" : "c";
  return (
    <g>
      <path d={`M ${Ox} ${Oy} L ${Bx} ${By} L ${Ax} ${Ay} Z`} fill="#ffffff" fillOpacity={0.05 * draw}
        stroke={C.text} strokeWidth={6} strokeLinejoin="round"
        strokeDasharray={total} strokeDashoffset={total * (1 - draw)} />
      {/* farbige Seiten */}
      <line x1={Ox} y1={Oy} x2={Ax} y2={Ay} stroke={C.a} strokeWidth={thick(legs)} strokeLinecap="round" opacity={legs} />
      <line x1={Ox} y1={Oy} x2={Bx} y2={By} stroke={C.b} strokeWidth={thick(legs)} strokeLinecap="round" opacity={legs} />
      <line x1={Ax} y1={Ay} x2={Bx} y2={By} stroke={C.c} strokeWidth={thick(hyp)} strokeLinecap="round" opacity={hyp} />
      {/* rechter Winkel */}
      <g opacity={lerp(frame, T.triangle + 25, T.triangle + 35, 0, 1)}>
        <path d={`M ${Ox} ${Oy - 34} L ${Ox + 34} ${Oy - 34} L ${Ox + 34} ${Oy}`} fill="none" stroke={C.text} strokeWidth={4} />
        <circle cx={Ox + 17} cy={Oy - 17} r={4} fill={C.text} />
      </g>
      {/* Beschriftungen */}
      {frame >= T.labelA && (
        <text x={Ox + 18} y={Oy - 105} fontFamily={C.sans} fontWeight={800} fontSize={44} fill={C.a}
          transform={`translate(${Ox + 18} ${Oy - 105}) scale(${lbl(T.labelA)}) translate(${-(Ox + 18)} ${-(Oy - 105)})`}>{aTxt}</text>
      )}
      {frame >= T.labelB && (
        <text x={Ox + 150} y={Oy - 18} fontFamily={C.sans} fontWeight={800} fontSize={44} fill={C.b}
          transform={`translate(${Ox + 150} ${Oy - 18}) scale(${lbl(T.labelB)}) translate(${-(Ox + 150)} ${-(Oy - 18)})`}>{bTxt}</text>
      )}
      {frame >= T.labelC && (
        <text x={Ox + 115} y={Oy - 60} fontFamily={C.sans} fontWeight={800} fontSize={44} fill={frame >= T.five ? C.ok : C.c}
          transform={`translate(${Ox + 115} ${Oy - 60}) scale(${lbl(T.labelC)}) translate(${-(Ox + 115)} ${-(Oy - 60)})`}>{cTxt}</text>
      )}
    </g>
  );
};

// ── Formel + Rechnung ──────────────────────────────────
const Formula: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  if (frame < T.formula) return null;
  const s = (t: number) => spring({ frame: frame - t, fps, config: { damping: 12 } });
  const big = 1 + spring({ frame: frame - T.merke, fps, config: { damping: 9 } }) * 0.18;
  const box = lerp(frame, T.merke, T.merke + 12, 0, 1);
  const Sq = ({ ch, col }: { ch: string; col: string }) => (
    <span style={{ color: col }}>{ch}<sup style={{ fontSize: "0.55em" }}>2</sup></span>
  );
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: 1235, display: "flex", justifyContent: "center" }}>
      <div style={{
        fontFamily: C.sans, fontWeight: 900, fontSize: 96, color: C.text, padding: "6px 40px",
        borderRadius: 26, border: `6px solid rgba(62,207,142,${box})`, boxShadow: `0 0 ${40 * box}px rgba(62,207,142,${0.5 * box})`,
        transform: `scale(${big})`, display: "flex", gap: 26, alignItems: "baseline",
      }}>
        <span style={{ opacity: s(T.formula), display: "inline-block" }}><Sq ch="a" col={C.a} /></span>
        <span style={{ opacity: s(T.plus) }}>+</span>
        <span style={{ opacity: s(T.plus) }}><Sq ch="b" col={C.b} /></span>
        <span style={{ opacity: s(T.equals) }}>=</span>
        <span style={{ opacity: s(T.equals) }}><Sq ch="c" col={C.c} /></span>
      </div>
    </div>
  );
};

const Calc: React.FC<{ frame: number }> = ({ frame }) => {
  const steps = [
    { t: T.a3, txt: "a = 3,  b = 4" },
    { t: T.nine, txt: "3² = 9" },
    { t: T.sixteen, txt: "3² = 9,  4² = 16" },
    { t: T.sum, txt: "9 + 16 = 25" },
    { t: T.root, txt: "c = √25 = 5" },
  ];
  const cur = [...steps].reverse().find((s) => frame >= s.t);
  if (!cur || frame >= T.merke) return null;
  const o = lerp(frame, cur.t, cur.t + 8, 0, 1);
  return (
    <div style={{
      position: "absolute", left: 0, right: 0, top: 1420, textAlign: "center",
      fontFamily: C.mono, fontWeight: 700, fontSize: 66, color: cur.t === T.root ? C.ok : C.text,
      opacity: o, transform: `translateY(${(1 - o) * 20}px)`,
    }}>{cur.txt}</div>
  );
};

// ── Szene ──────────────────────────────────────────────
export const SatzDesPythagoras: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const outro = lerp(frame, durationInFrames - 20, durationInFrames, 1, 0);
  const titleOut = lerp(frame, T.triangle - 15, T.triangle, 1, 0);
  const titleIn = spring({ frame, fps, config: { damping: 14 } });
  const header = lerp(frame, T.triangle, T.triangle + 15, 0, 1);

  return (
    <AbsoluteFill style={{ backgroundColor: C.bg, opacity: outro }}>
      <Sequence from={VOICE_DELAY}>
        <Audio src={staticFile("pythagoras/voice.mp3")} />
      </Sequence>
      <svg viewBox="0 0 1080 1920" width={1080} height={1920}>
        <defs>
          <pattern id="paper" width={40} height={40} patternUnits="userSpaceOnUse">
            <path d="M 40 0 L 0 0 0 40" fill="none" stroke={C.grid} strokeWidth={2} />
          </pattern>
        </defs>
        <rect width={1080} height={1920} fill="url(#paper)" />
        <text x={60} y={190} fontFamily={C.mono} fontSize={34} letterSpacing={4} fill={C.dim} opacity={header}>
          MATHE KURZ · SATZ DES PYTHAGORAS
        </text>
        <Squares frame={frame} fps={fps} />
        <Triangle frame={frame} fps={fps} />
      </svg>

      {/* Titel am Anfang */}
      <div style={{
        position: "absolute", left: 0, right: 0, top: 640, textAlign: "center", opacity: titleOut,
        transform: `scale(${0.8 + titleIn * 0.2})`, fontFamily: C.sans,
      }}>
        <div style={{ fontSize: 60, fontWeight: 700, color: C.dim, letterSpacing: 6 }}>DER SATZ DES</div>
        <div style={{ fontSize: 150, fontWeight: 900, color: C.text, lineHeight: 1.05 }}>Pythagoras</div>
        <div style={{ fontSize: 90, fontWeight: 900, marginTop: 30 }}>
          <span style={{ color: C.a }}>a²</span><span style={{ color: C.text }}> + </span>
          <span style={{ color: C.b }}>b²</span><span style={{ color: C.text }}> = </span>
          <span style={{ color: C.c }}>c²</span>
        </div>
      </div>

      <Formula frame={frame} fps={fps} />
      <Calc frame={frame} />
      <Captions frame={frame} />
    </AbsoluteFill>
  );
};
