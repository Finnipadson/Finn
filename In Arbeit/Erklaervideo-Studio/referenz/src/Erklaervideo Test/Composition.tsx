import React from "react";
import {
  AbsoluteFill, Audio, Sequence, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig,
} from "remotion";
import WORDS from "./words.json";

// ── Timing: alles richtet sich nach der Sprecherstimme (words.json aus voice.py) ──
export const FPS = 30;
const VOICE_DELAY = 15; // Stimme startet nach 0,5 s
type Word = { text: string; start: number; end: number };
const words = WORDS as Word[];
const sec = (s: number) => Math.round(s * FPS) + VOICE_DELAY;
const wordAt = (text: string, nth = 0) => {
  const bare = (s: string) => s.replace(/[.,:!?]+$/, "");
  const hits = words.filter((w) => bare(w.text) === bare(text));
  const w = hits[nth];
  if (!w) throw new Error(`Wort "${text}" fehlt in words.json`);
  return { start: sec(w.start), end: sec(w.end) };
};

const T = {
  chipStack: wordAt("Stacktrace").start,
  chipLogs: wordAt("Logs").start,
  chipTests: wordAt("Test").start,
  dialStart: wordAt("Aufwand").start,
  dialEnd: wordAt("hochdrehen.").end,
  price: wordAt("Fünf").start,
  thumbs: wordAt("Fix").start,
  stamp: wordAt("serviert!").start,
};
export const DURATION_IN_FRAMES = sec(words[words.length - 1].end) + 45;

// ── Farben ─────────────────────────────────────────────
const C = {
  wall: "#23252a",
  brick: "#2c2f35",
  brickLine: "#1c1e22",
  counter: "#1b1d21",
  counterTop: "#3b3f46",
  paper: "#f3efe4",
  paperLine: "#ddd6c4",
  white: "#f5f5f3",
  outline: "#1a1a1a",
  skin: "#c98b5a",
  skinDark: "#a86f43",
  cheek: "#e08a7a",
  accent: "#4fd1ff",
  yellow: "#f2c94c",
  red: "#ff6b5b",
  green: "#3ecf8e",
  mono: "Consolas, 'Courier New', monospace",
  sans: "'Segoe UI', Arial, sans-serif",
};

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const lerp = (f: number, a: number, b: number, from: number, to: number) =>
  interpolate(f, [a, b], [from, to], clamp);

// ── Untertitel: Zeilen à max. 5 Wörter, Umbruch nach Satzzeichen ──
type Line = { words: { text: string; at: number }[]; from: number; to: number };
const LINES: Line[] = (() => {
  const lines: { text: string; at: number }[][] = [];
  let cur: { text: string; at: number }[] = [];
  for (const w of words) {
    cur.push({ text: w.text, at: sec(w.start) });
    const chars = cur.map((x) => x.text).join(" ").length;
    if ((/[.,:!?]$/.test(w.text) && cur.length >= 2) || cur.length >= 5 || chars > 26) {
      lines.push(cur);
      cur = [];
    }
  }
  if (cur.length) lines.push(cur);
  const lastEnd = sec(words[words.length - 1].end) + 25;
  return lines.map((l, i) => ({ words: l, from: l[0].at, to: i + 1 < lines.length ? lines[i + 1][0].at : lastEnd }));
})();

const Captions: React.FC<{ frame: number }> = ({ frame }) => {
  const line = LINES.find((l) => frame >= l.from && frame < l.to);
  if (!line) return null;
  const visible = line.words.filter((w) => frame >= w.at);
  const current = visible[visible.length - 1];
  return (
    <div style={{
      position: "absolute", left: 60, right: 60, top: 1600, display: "flex",
      flexWrap: "wrap", justifyContent: "center", gap: "0 22px",
      fontFamily: C.sans, fontWeight: 800, fontSize: 84, lineHeight: 1.2,
      textShadow: "0 6px 0 rgba(0,0,0,0.45)",
    }}>
      {visible.map((w) => (
        <span key={w.text + w.at} style={{
          color: w === current ? C.accent : C.white,
          transform: `scale(${lerp(frame, w.at, w.at + 5, 0.6, 1)})`, display: "inline-block",
        }}>{w.text}</span>
      ))}
    </div>
  );
};

// ── Koch ───────────────────────────────────────────────
const Chef: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const rise = spring({ frame: frame - 5, fps, config: { damping: 11, mass: 0.8 } });
  const y = (1 - rise) * 700 + Math.sin(frame / 9) * 4;

  const t = frame % 95;
  const eyeRy = t > 88 && t < 93 ? 1.5 : 13;

  const stir = frame > T.chipStack && frame < T.dialStart ? Math.sin(frame / 4) * 8 : 0;
  const thumbs = spring({ frame: frame - T.thumbs, fps, config: { damping: 10 } });
  const rightArm = stir - thumbs * 140;

  const brow = frame < T.stamp ? lerp(frame, T.dialStart, T.dialStart + 20, 0, -10) : 0;

  return (
    <g transform={`translate(600 ${1250 + y})`}>
      <g transform="rotate(14 -150 -290)">
        <rect x={-205} y={-300} width={70} height={210} rx={35} fill={C.white} stroke={C.outline} strokeWidth={5} />
        <circle cx={-170} cy={-85} r={30} fill={C.skin} stroke={C.outline} strokeWidth={5} />
      </g>

      <rect x={-160} y={-340} width={320} height={360} rx={70} fill={C.white} stroke={C.outline} strokeWidth={6} />
      <path d="M -70 -335 L 0 -255 L 70 -335" fill={C.yellow} stroke={C.outline} strokeWidth={5} />
      <circle cx={-30} cy={-150} r={9} fill={C.outline} />
      <circle cx={30} cy={-150} r={9} fill={C.outline} />

      <rect x={-115} y={-230} width={230} height={62} rx={8} fill={C.paper} stroke={C.outline} strokeWidth={4} />
      <text x={0} y={-190} textAnchor="middle" fontFamily={C.mono} fontWeight={700} fontSize={30} fill={C.outline}>DEV-KOCH</text>

      <g transform={`rotate(${rightArm} 150 -290)`}>
        <rect x={135} y={-300} width={70} height={210} rx={35} fill={C.white} stroke={C.outline} strokeWidth={5} />
        <rect x={160} y={-150} width={14} height={150} rx={6} fill="#8a8f98" stroke={C.outline} strokeWidth={4}
          transform="rotate(-25 167 -90)" opacity={1 - thumbs} />
        <circle cx={170} cy={-85} r={30} fill={C.skin} stroke={C.outline} strokeWidth={5} />
        <rect x={160} y={-140} width={22} height={40} rx={10} fill={C.skin} stroke={C.outline} strokeWidth={4} opacity={thumbs} />
      </g>

      <rect x={-40} y={-380} width={80} height={60} fill={C.skinDark} />
      <circle cx={-112} cy={-450} r={24} fill={C.skin} stroke={C.outline} strokeWidth={5} />
      <circle cx={112} cy={-450} r={24} fill={C.skin} stroke={C.outline} strokeWidth={5} />
      <circle cx={0} cy={-460} r={115} fill={C.skin} stroke={C.outline} strokeWidth={6} />

      <path d={`M -70 ${-505 + brow} Q -45 ${-520 + brow} -20 ${-505 + brow}`} stroke={C.outline} strokeWidth={8} fill="none" strokeLinecap="round" />
      <path d={`M 20 ${-505 + brow} Q 45 ${-520 + brow} 70 ${-505 + brow}`} stroke={C.outline} strokeWidth={8} fill="none" strokeLinecap="round" />
      <ellipse cx={-45} cy={-470} rx={11} ry={eyeRy} fill={C.outline} />
      <ellipse cx={45} cy={-470} rx={11} ry={eyeRy} fill={C.outline} />
      <circle cx={-75} cy={-425} r={16} fill={C.cheek} opacity={0.6} />
      <circle cx={75} cy={-425} r={16} fill={C.cheek} opacity={0.6} />
      <path d="M -45 -410 Q 0 -370 45 -410" stroke={C.outline} strokeWidth={7} fill="none" strokeLinecap="round" />

      <circle cx={-70} cy={-610} r={58} fill={C.white} stroke={C.outline} strokeWidth={5} />
      <circle cx={70} cy={-610} r={58} fill={C.white} stroke={C.outline} strokeWidth={5} />
      <circle cx={0} cy={-645} r={75} fill={C.white} stroke={C.outline} strokeWidth={5} />
      <rect x={-105} y={-595} width={210} height={70} rx={10} fill={C.white} stroke={C.outline} strokeWidth={5} />
      <rect x={-102} y={-592} width={204} height={30} fill={C.white} />
    </g>
  );
};

// ── Bestellzettel ──────────────────────────────────────
const Ticket: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const h = lerp(frame, 0, 30, 0, 560);
  const stamp = spring({ frame: frame - T.stamp, fps, config: { damping: 9 } });
  const zig = Array.from({ length: 13 }, (_, i) => `${i * 22} ${i % 2 === 0 ? 0 : 16}`).join(" L ");
  return (
    <g transform="translate(80 318)">
      <clipPath id="ticketClip"><rect x={0} y={0} width={270} height={h + 20} /></clipPath>
      <g clipPath="url(#ticketClip)">
        <rect x={0} y={0} width={264} height={560} fill={C.paper} />
        {Array.from({ length: 14 }, (_, i) => (
          <line key={i} x1={16} x2={248} y1={150 + i * 28} y2={150 + i * 28} stroke={C.paperLine} strokeWidth={3} />
        ))}
        <text x={24} y={60} fontFamily={C.mono} fontSize={34} fill="#555">#01</text>
        <text x={24} y={110} fontFamily={C.mono} fontWeight={700} fontSize={38} fill={C.outline}>LOGIN-BUG</text>
        <path d={`M ${zig}`} transform="translate(0 552)" fill={C.paper} />
      </g>
      {stamp > 0.01 && (
        <g transform={`translate(132 330) rotate(-14) scale(${2.2 - stamp * 1.2})`} opacity={Math.min(1, stamp * 1.5)}>
          <rect x={-120} y={-48} width={240} height={96} rx={12} fill="none" stroke={C.green} strokeWidth={9} />
          <text x={0} y={18} textAnchor="middle" fontFamily={C.sans} fontWeight={900} fontSize={52} fill={C.green}>GEFIXT ✓</text>
        </g>
      )}
    </g>
  );
};

// ── Zutaten-Chips, die beim Aussprechen in die Pfanne fallen ──
const CHIPS = [
  { label: "Stacktrace", at: T.chipStack, x: 470 },
  { label: "console.log", at: T.chipLogs, x: 640 },
  { label: "Tests", at: T.chipTests, x: 800 },
];

const Chips: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => (
  <>
    {CHIPS.map((c) => {
      if (frame < c.at) return null;
      const drop = spring({ frame: frame - c.at, fps, config: { damping: 12 } });
      const sink = lerp(frame, T.dialStart - 20, T.dialStart, 1, 0);
      const y = -120 + drop * 1255;
      const x = c.x + (1 - sink) * (640 - c.x);
      const w = c.label.length * 21 + 40;
      return (
        <g key={c.label} transform={`translate(${x} ${y}) scale(${sink})`}>
          <rect x={-w / 2} y={-34} width={w} height={68} rx={12} fill={C.white} stroke={C.outline} strokeWidth={4} />
          <text x={0} y={12} textAnchor="middle" fontFamily={C.mono} fontWeight={700} fontSize={34} fill={C.outline}>{c.label}</text>
        </g>
      );
    })}
  </>
);

// ── Theke, Pfanne, Regler ──────────────────────────────
const Counter: React.FC<{ frame: number }> = ({ frame }) => {
  const mid = (T.dialStart + T.dialEnd) / 2;
  const angle = interpolate(frame, [T.dialStart, mid, T.dialEnd], [-120, 0, 120], clamp);
  const level = angle < -60 ? "LOW" : angle < 60 ? "MEDIUM" : "HIGH";
  const levelColor = level === "LOW" ? C.accent : level === "MEDIUM" ? C.yellow : C.red;
  const heat = ((angle + 120) / 240) * (0.55 + Math.sin(frame / 3) * 0.08);
  return (
    <g>
      <g transform="translate(640 1215)">
        <rect x={150} y={-12} width={170} height={24} rx={12} fill="#2a2c31" stroke={C.outline} strokeWidth={4} />
        <ellipse cx={0} cy={0} rx={170} ry={40} fill="#2a2c31" stroke={C.outline} strokeWidth={5} />
        <ellipse cx={0} cy={-6} rx={140} ry={26} fill="#3a3d44" />
        <ellipse cx={0} cy={-6} rx={140} ry={26} fill="#ff8a3d" opacity={heat} />
      </g>

      <rect x={0} y={1250} width={1080} height={330} fill={C.counter} />
      <rect x={0} y={1250} width={1080} height={22} fill={C.counterTop} />

      <g transform="translate(230 1420)">
        <circle r={86} fill="#2a2c31" stroke={C.outline} strokeWidth={6} />
        <circle r={62} fill="#e9e9e6" stroke={C.outline} strokeWidth={5} />
        <g transform={`rotate(${angle})`}>
          <rect x={-10} y={-58} width={20} height={58} rx={8} fill={C.outline} />
        </g>
        {[-120, 0, 120].map((a) => (
          <circle key={a} cx={Math.sin((a * Math.PI) / 180) * 104} cy={-Math.cos((a * Math.PI) / 180) * 104} r={8}
            fill={Math.abs(a - angle) < 5 ? levelColor : "#555"} />
        ))}
      </g>
      <g transform="translate(360 1385)">
        <rect width={250} height={70} rx={35} fill="#2a2c31" stroke={levelColor} strokeWidth={4} />
        <text x={125} y={47} textAnchor="middle" fontFamily={C.mono} fontWeight={700} fontSize={36} fill={levelColor}>{level}</text>
      </g>
    </g>
  );
};

// ── Dampf ──────────────────────────────────────────────
const Steam: React.FC<{ frame: number }> = ({ frame }) => {
  const start = T.dialStart + 15;
  if (frame < start) return null;
  return (
    <g>
      {[-60, 0, 60].map((dx, i) => {
        const p = ((frame - start + i * 12) % 45) / 45;
        return (
          <path key={dx} d="M 0 0 q 18 -30 0 -60 q -18 -30 0 -60"
            transform={`translate(${640 + dx} ${1180 - p * 120})`}
            stroke="#8f99a6" strokeWidth={10} fill="none" strokeLinecap="round" opacity={(1 - p) * 0.8} />
        );
      })}
    </g>
  );
};

// ── Preisschild ────────────────────────────────────────
const PriceTag: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  if (frame < T.price) return null;
  const s = spring({ frame: frame - T.price, fps, config: { damping: 6, mass: 0.7 } });
  return (
    <g transform={`translate(830 318) rotate(${(1 - s) * 50})`}>
      <line x1={0} y1={0} x2={0} y2={60} stroke="#888" strokeWidth={4} />
      <rect x={-130} y={60} width={260} height={140} rx={10} fill={C.paper} stroke={C.outline} strokeWidth={4} />
      <text x={0} y={135} textAnchor="middle" fontFamily={C.sans} fontWeight={900} fontSize={60} fill={C.outline}>5 MIN</text>
      <text x={0} y={180} textAnchor="middle" fontFamily={C.mono} fontSize={26} fill="#555">BIS ZUM FIX</text>
    </g>
  );
};

// ── Szene ──────────────────────────────────────────────
export const ErklaervideoTest: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const outro = lerp(frame, durationInFrames - 15, durationInFrames, 1, 0);

  return (
    <AbsoluteFill style={{ backgroundColor: C.wall, opacity: outro }}>
      <Sequence from={VOICE_DELAY}>
        <Audio src={staticFile("erklaervideo-test/voice.mp3")} />
      </Sequence>
      <svg viewBox="0 0 1080 1920" width={1080} height={1920}>
        <defs>
          <pattern id="bricks" width={180} height={90} patternUnits="userSpaceOnUse">
            <rect width={180} height={90} fill={C.brickLine} />
            <rect x={4} y={4} width={172} height={37} rx={4} fill={C.brick} />
            <rect x={-86} y={49} width={172} height={37} rx={4} fill={C.brick} />
            <rect x={94} y={49} width={172} height={37} rx={4} fill={C.brick} />
          </pattern>
        </defs>
        <rect width={1080} height={1250} fill="url(#bricks)" />

        <text x={60} y={200} fontFamily={C.mono} fontSize={34} letterSpacing={4} fill="#b8bcc4" opacity={lerp(frame, 0, 15, 0, 1)}>
          BUG-KÜCHE · EP 01
        </text>

        <rect x={40} y={300} width={1000} height={20} rx={6} fill="#3a3d43" stroke={C.outline} strokeWidth={3} />
        <circle cx={1010} cy={310} r={6} fill={C.green} />

        <Ticket frame={frame} fps={fps} />
        <PriceTag frame={frame} fps={fps} />
        <Chef frame={frame} fps={fps} />
        <Steam frame={frame} />
        <Counter frame={frame} />
        <Chips frame={frame} fps={fps} />
      </svg>
      <Captions frame={frame} />
    </AbsoluteFill>
  );
};
