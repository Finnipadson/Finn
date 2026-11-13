import React from "react";
import {
  AbsoluteFill, Audio, Easing, interpolate, spring, staticFile, useCurrentFrame,
} from "remotion";
import WORDS from "./words.json";
import EVENTS from "./events.json";
import AMPS from "./amps.json";

/* ════════════════════════════════════════════════════════════════════
   Koch-Szene in hoher Qualität (60 fps, 1080×1920)
   Alle Zeitpunkte kommen aus audio.py (events.json / words.json / amps.json),
   damit Bild, Stimme und Geräusche exakt zusammenpassen.
   ════════════════════════════════════════════════════════════════════ */

export const FPS = 60;
const S = (s: number) => Math.round(s * FPS);
const E = {
  ticket: S(EVENTS.ticket), lookTicket: S(EVENTS.lookTicket),
  chip1: S(EVENTS.chip1), chip2: S(EVENTS.chip2), chip3: S(EVENTS.chip3),
  heat: S(EVENTS.heat), toss: S(EVENTS.toss), done: S(EVENTS.done), ding: S(EVENTS.ding),
};
export const DURATION_IN_FRAMES = S(EVENTS.duration);
const words = WORDS as { text: string; start: number; end: number }[];
const amps = AMPS as number[];

// ── Helfer ───────────────────────────────────────────────────────────
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const lerp = (f: number, a: number, b: number, from: number, to: number, ease = Easing.inOut(Easing.cubic)) =>
  interpolate(f, [a, b], [from, to], { ...clamp, easing: ease });
const sp = (f: number, damping = 12, mass = 1, stiffness = 120) =>
  spring({ frame: f, fps: FPS, config: { damping, mass, stiffness } });
const rnd = (i: number) => { const x = Math.sin(i * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); };
const wob = (f: number, seed: number) =>
  Math.sin(f / 23 + seed) * 0.5 + Math.sin(f / 9.7 + seed * 2.1) * 0.3 + Math.sin(f / 4.3 + seed * 3.7) * 0.2;
const deg = (r: number) => (r * 180) / Math.PI;

// Zwei-Gelenk-Arm (Schulter → Ellbogen → Hand) per inverser Kinematik
const ik = (sx: number, sy: number, tx: number, ty: number, l1: number, l2: number, bend: number) => {
  const dx = tx - sx, dy = ty - sy;
  const d = Math.min(Math.hypot(dx, dy), l1 + l2 - 0.5);
  const base = Math.atan2(dy, dx);
  const A = Math.acos(Math.max(-1, Math.min(1, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))));
  const a1 = base + bend * A;
  const ex = sx + Math.cos(a1) * l1, ey = sy + Math.sin(a1) * l1;
  const hx = sx + Math.cos(base) * d, hy = sy + Math.sin(base) * d;
  return { a1, a2: Math.atan2(hy - ey, hx - ex), ex, ey, hx, hy };
};

// ── Farben ───────────────────────────────────────────────────────────
const C = {
  line: "#2a1d17",
  skin: "#d39a68", skinDark: "#a86c41", skinLight: "#ecc092",
  coat: "#f7f6f2", coatShade: "#d9d8d0",
  hair: "#3a2a20",
  red: "#ff5d4f", blue: "#4fb8ff", green: "#3ddc97", yellow: "#ffd34d",
  sans: "'Segoe UI', Arial, sans-serif",
  mono: "Consolas, 'Courier New', monospace",
};

// ── Stimme → Mund (geglättet) ────────────────────────────────────────
const mouthOpen = (f: number) => {
  const a = (i: number) => amps[Math.max(0, Math.min(amps.length - 1, i))] ?? 0;
  const v = a(f - 2) * 0.15 + a(f - 1) * 0.25 + a(f) * 0.35 + a(f + 1) * 0.25;
  return Math.pow(Math.max(0, Math.min(1, (v - 0.08) / 0.7)), 0.8);
};

// ── Blickrichtung (−1…1) ─────────────────────────────────────────────
const LOOK: [number, number, number][] = (() => {
  const k: [number, number, number][] = [[0, 0, 0.1]];
  const hold = (t: number, len: number, x: number, y: number) => {
    k.push([t, k[k.length - 1][1], k[k.length - 1][2]]);
    k.push([t + 9, x, y]);
    k.push([t + len, x, y]);
    k.push([t + len + 12, 0, 0.1]);
  };
  hold(E.lookTicket, 70, -1, -0.35);
  hold(E.chip1 - 6, 34, 0.25, 1);
  hold(E.chip2 - 6, 34, 0.25, 1);
  hold(E.chip3 - 6, 34, 0.25, 1);
  hold(E.heat + 4, 50, 0.2, 1);
  hold(E.toss - 4, 46, 0.3, 0.9);
  return k.sort((p, q) => p[0] - q[0]).filter((p, i, arr) => i === 0 || p[0] > arr[i - 1][0]);
})();
const lookAt = (f: number) => ({
  x: interpolate(f, LOOK.map((p) => p[0]), LOOK.map((p) => p[1]), clamp),
  y: interpolate(f, LOOK.map((p) => p[0]), LOOK.map((p) => p[2]), clamp),
});

// ── Blinzeln ─────────────────────────────────────────────────────────
const BLINKS = [40, 230, 400, 590, 735, 905, 1060].map((b) => b);
const blinkAt = (f: number) => Math.max(0, ...BLINKS.map((b) => 1 - Math.abs(f - b) / 5));

/* ════════════════════════════ DEFS ═════════════════════════════════ */
const Defs: React.FC<{ frame: number }> = ({ frame }) => (
  <defs>
    <radialGradient id="skin" cx="0.38" cy="0.32" r="0.8">
      <stop offset="0" stopColor={C.skinLight} />
      <stop offset="0.55" stopColor={C.skin} />
      <stop offset="1" stopColor={C.skinDark} />
    </radialGradient>
    <radialGradient id="hand" cx="0.35" cy="0.3" r="0.8">
      <stop offset="0" stopColor={C.skinLight} />
      <stop offset="1" stopColor={C.skinDark} />
    </radialGradient>
    <linearGradient id="coat" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stopColor="#ffffff" />
      <stop offset="0.6" stopColor={C.coat} />
      <stop offset="1" stopColor={C.coatShade} />
    </linearGradient>
    <linearGradient id="sleeve" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stopColor="#ffffff" />
      <stop offset="0.7" stopColor={C.coat} />
      <stop offset="1" stopColor="#cfcdc4" />
    </linearGradient>
    <radialGradient id="hat" cx="0.35" cy="0.3" r="0.85">
      <stop offset="0" stopColor="#ffffff" />
      <stop offset="0.7" stopColor="#f1f0ea" />
      <stop offset="1" stopColor="#d3d1c8" />
    </radialGradient>
    <linearGradient id="scarf" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stopColor="#ffb547" />
      <stop offset="1" stopColor="#f07b22" />
    </linearGradient>
    <radialGradient id="iris" cx="0.4" cy="0.35" r="0.7">
      <stop offset="0" stopColor="#7a5236" />
      <stop offset="1" stopColor="#2e1c12" />
    </radialGradient>
    <linearGradient id="sclera" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stopColor="#e6e3dc" />
      <stop offset="0.35" stopColor="#ffffff" />
    </linearGradient>
    <linearGradient id="wallLight" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stopColor="#0d1016" stopOpacity="0.75" />
      <stop offset="0.45" stopColor="#0d1016" stopOpacity="0.05" />
      <stop offset="1" stopColor="#0d1016" stopOpacity="0.65" />
    </linearGradient>
    <linearGradient id="cone" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stopColor="#ffe3b3" stopOpacity="0.32" />
      <stop offset="1" stopColor="#ffe3b3" stopOpacity="0" />
    </linearGradient>
    <linearGradient id="steel" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stopColor="#6c727c" />
      <stop offset="0.08" stopColor="#4c5159" />
      <stop offset="0.6" stopColor="#353940" />
      <stop offset="1" stopColor="#1e2125" />
    </linearGradient>
    <linearGradient id="lip" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stopColor="#9aa1ab" />
      <stop offset="1" stopColor="#5a6069" />
    </linearGradient>
    <linearGradient id="panSide" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stopColor="#3d424a" />
      <stop offset="1" stopColor="#14161a" />
    </linearGradient>
    <radialGradient id="panIn" cx="0.5" cy="0.55" r="0.6">
      <stop offset="0" stopColor="#2c3037" />
      <stop offset="1" stopColor="#15171b" />
    </radialGradient>
    <linearGradient id="flame" x1="0" y1="1" x2="0" y2="0">
      <stop offset="0" stopColor="#bfe3ff" />
      <stop offset="0.18" stopColor="#5aa8ff" />
      <stop offset="0.35" stopColor="#ffe08a" />
      <stop offset="0.7" stopColor="#ff8a2a" />
      <stop offset="1" stopColor="#ff5a1f" stopOpacity="0" />
    </linearGradient>
    <radialGradient id="knob" cx="0.35" cy="0.3" r="0.8">
      <stop offset="0" stopColor="#f4f5f7" />
      <stop offset="1" stopColor="#9aa0a8" />
    </radialGradient>
    <radialGradient id="heatGlow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stopColor="#ff9a3c" stopOpacity="0.55" />
      <stop offset="1" stopColor="#ff9a3c" stopOpacity="0" />
    </radialGradient>
    <radialGradient id="bulb" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stopColor="#fff6dc" />
      <stop offset="1" stopColor="#ffd38a" stopOpacity="0" />
    </radialGradient>
    <radialGradient id="vignette" cx="0.5" cy="0.45" r="0.75">
      <stop offset="0.55" stopColor="#000" stopOpacity="0" />
      <stop offset="1" stopColor="#000" stopOpacity="0.62" />
    </radialGradient>
    <linearGradient id="paper" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stopColor="#fffaf0" />
      <stop offset="1" stopColor="#ece4d2" />
    </linearGradient>
    <pattern id="tiles" width={120} height={60} patternUnits="userSpaceOnUse">
      <rect width={120} height={60} fill="#262c36" />
      <rect x={3} y={3} width={114} height={26} rx={5} fill="#3a4351" />
      <rect x={-57} y={33} width={114} height={26} rx={5} fill="#38404d" />
      <rect x={63} y={33} width={114} height={26} rx={5} fill="#38404d" />
      <rect x={8} y={5} width={100} height={4} rx={2} fill="#ffffff" opacity={0.06} />
    </pattern>
    <pattern id="brushed" width={1080} height={6} patternUnits="userSpaceOnUse">
      <rect width={1080} height={1} y={2} fill="#ffffff" opacity={0.035} />
    </pattern>
    <pattern id="towel" width={36} height={36} patternUnits="userSpaceOnUse">
      <rect width={36} height={36} fill="#f3eee6" />
      <rect width={18} height={36} fill="#d64545" opacity={0.85} />
      <rect width={36} height={18} fill="#d64545" opacity={0.45} />
    </pattern>
    <filter id="bgBlur" x="-5%" y="-5%" width="110%" height="110%"><feGaussianBlur stdDeviation={3.2} /></filter>
    <filter id="soft" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation={16} /></filter>
    <filter id="steamBlur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation={12} /></filter>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation={7} result="b" />
      <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
    </filter>
    <filter id="drop" x="-20%" y="-20%" width="140%" height="160%">
      <feDropShadow dx={0} dy={10} stdDeviation={9} floodColor="#000" floodOpacity={0.45} />
    </filter>
    <filter id="grain" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency={0.9} numOctaves={2} seed={frame % 9} />
      <feColorMatrix type="saturate" values="0" />
    </filter>
  </defs>
);

/* ═══════════════════════════ HINTERGRUND ═══════════════════════════ */
const Background: React.FC<{ frame: number }> = ({ frame }) => (
  <g filter="url(#bgBlur)">
    <rect width={1080} height={1310} fill="url(#tiles)" />
    {/* Regal rechts mit Gläsern */}
    <g>
      <rect x={660} y={600} width={420} height={18} rx={4} fill="#6b4a33" />
      <rect x={660} y={618} width={420} height={8} fill="#4b3222" />
      {[[700, "#d9a441", 70], [790, "#9fc7a8", 92], [880, "#c96f4a", 60], [960, "#e6dcc8", 84]].map(([x, col, h], i) => (
        <g key={i}>
          <rect x={x as number} y={600 - (h as number)} width={62} height={h as number} rx={10} fill={col as string} opacity={0.85} />
          <rect x={(x as number) - 3} y={590 - (h as number)} width={68} height={14} rx={4} fill="#555c66" />
          <rect x={(x as number) + 8} y={610 - (h as number)} width={8} height={(h as number) - 26} rx={4} fill="#fff" opacity={0.25} />
        </g>
      ))}
      <rect x={700} y={430} width={300} height={16} rx={4} fill="#6b4a33" />
      <ellipse cx={780} cy={415} rx={60} ry={14} fill="#8a8f98" />
      <rect x={720} y={360} width={120} height={56} rx={10} fill="#7d838c" />
      <ellipse cx={930} cy={418} rx={44} ry={10} fill="#b8743f" />
      <rect x={888} y={378} width={84} height={42} rx={8} fill="#c4824a" />
    </g>
    {/* Hängende Utensilien links */}
    <g>
      <rect x={40} y={600} width={330} height={10} rx={5} fill="#7d838c" />
      {[90, 180, 270].map((x, i) => {
        const sway = Math.sin(frame / 50 + i) * 2;
        return (
          <g key={x} transform={`rotate(${sway} ${x} 605)`}>
            <line x1={x} y1={605} x2={x} y2={760} stroke="#9aa1ab" strokeWidth={8} strokeLinecap="round" />
            {i === 0 && <ellipse cx={x} cy={790} rx={32} ry={36} fill="#9aa1ab" />}
            {i === 1 && <rect x={x - 30} y={760} width={60} height={70} rx={10} fill="#9aa1ab" />}
            {i === 2 && <ellipse cx={x} cy={800} rx={26} ry={48} fill="none" stroke="#9aa1ab" strokeWidth={6} />}
          </g>
        );
      })}
    </g>
    <rect width={1080} height={1310} fill="url(#wallLight)" />
  </g>
);

const Lamp: React.FC<{ frame: number }> = ({ frame }) => {
  const sway = Math.sin(frame / 70) * 1.2;
  return (
    <g transform={`rotate(${sway} 560 0)`}>
      <polygon points="470,250 650,250 990,1310 130,1310" fill="url(#cone)" style={{ mixBlendMode: "screen" }} />
      <line x1={560} y1={0} x2={560} y2={170} stroke="#15181d" strokeWidth={6} />
      <path d="M 450 250 Q 455 175 560 168 Q 665 175 670 250 Z" fill="#2f5b4f" stroke={C.line} strokeWidth={4} />
      <path d="M 470 236 Q 480 190 540 182" stroke="#ffffff" strokeOpacity={0.25} strokeWidth={6} fill="none" strokeLinecap="round" />
      <ellipse cx={560} cy={252} rx={70} ry={22} fill="url(#bulb)" filter="url(#glow)" />
      <ellipse cx={560} cy={250} rx={110} ry={10} fill="#1b3a32" />
    </g>
  );
};

/* ═════════════════════════════ BON ═════════════════════════════════ */
const Ticket: React.FC<{ frame: number }> = ({ frame }) => {
  const t = frame - E.ticket;
  const slide = lerp(frame, E.ticket, E.ticket + 28, -340, 70, Easing.out(Easing.cubic));
  const swing = t < 0 ? 0 : Math.sin(t / 6) * 18 * Math.exp(-t / 22);
  const stamp = sp(frame - E.done, 9, 0.8, 160);
  const checks = [E.chip1, E.chip2, E.chip3];
  return (
    <g>
      <rect x={30} y={318} width={460} height={20} rx={8} fill="url(#lip)" stroke={C.line} strokeWidth={3} />
      <g transform={`translate(${slide} 336) rotate(${swing} 125 0)`} filter="url(#drop)">
        <path d={`M 0 0 H 250 V 420 ${Array.from({ length: 11 }, (_, i) => `L ${250 - (i + 1) * 22.7} ${i % 2 ? 420 : 404}`).join(" ")} Z`} fill="url(#paper)" />
        <rect x={0} y={0} width={250} height={14} fill="#c9c1ae" />
        <text x={22} y={62} fontFamily={C.mono} fontSize={30} fill="#7a7468">#01</text>
        <rect x={160} y={36} width={70} height={34} rx={17} fill={C.red} />
        <text x={195} y={60} textAnchor="middle" fontFamily={C.sans} fontWeight={900} fontSize={20} fill="#fff">HOT</text>
        <text x={22} y={112} fontFamily={C.mono} fontWeight={700} fontSize={36} fill="#1d1b18">LOGIN-BUG</text>
        <line x1={22} y1={134} x2={228} y2={134} stroke="#d7cfbd" strokeWidth={3} />
        {["Stacktrace", "Logs", "Test"].map((label, i) => {
          const c = sp(frame - checks[i] - 18, 10, 0.6, 200);
          return (
            <g key={label} transform={`translate(22 ${178 + i * 56})`}>
              <rect x={0} y={-26} width={30} height={30} rx={6} fill="none" stroke="#8d8676" strokeWidth={3} />
              <path d="M 5 -11 L 13 -3 L 27 -22" fill="none" stroke={C.green} strokeWidth={5} strokeLinecap="round"
                strokeLinejoin="round" strokeDasharray={40} strokeDashoffset={40 * (1 - c)} />
              <text x={44} y={0} fontFamily={C.mono} fontSize={28} fill="#3b372f">{label}</text>
            </g>
          );
        })}
        {stamp > 0.01 && (
          <g transform={`translate(125 330) rotate(-12) scale(${2.4 - 1.4 * stamp})`} opacity={Math.min(1, stamp * 1.6)}>
            <rect x={-112} y={-44} width={224} height={88} rx={12} fill="#3ddc97" fillOpacity={0.12} stroke={C.green} strokeWidth={8} />
            <text x={0} y={17} textAnchor="middle" fontFamily={C.sans} fontWeight={900} fontSize={48} fill={C.green}>GEFIXT ✓</text>
          </g>
        )}
      </g>
    </g>
  );
};

/* ═════════════════════════════ KOCH ════════════════════════════════ */
const Eye: React.FC<{ x: number; frame: number; happy: number; lx: number; ly: number; id: string }> = ({ x, frame, happy, lx, ly, id }) => {
  const blink = Math.max(blinkAt(frame), happy);
  return (
    <g>
      <clipPath id={id}><ellipse cx={x} cy={-600} rx={21} ry={24} /></clipPath>
      <g opacity={1 - happy}>
        <ellipse cx={x} cy={-600} rx={21} ry={24} fill="url(#sclera)" />
        <g clipPath={`url(#${id})`}>
          <circle cx={x + lx * 7} cy={-598 + ly * 7} r={13} fill="url(#iris)" />
          <circle cx={x + lx * 7.5} cy={-598 + ly * 7.5} r={6.5} fill="#0d0805" />
          <circle cx={x + lx * 7 + 4.5} cy={-604 + ly * 7} r={4} fill="#fff" />
          <circle cx={x + lx * 7 - 4} cy={-593 + ly * 7} r={1.8} fill="#fff" opacity={0.8} />
          <rect x={x - 24} y={-626} width={48} height={50 * blink} fill="url(#skin)" />
          {blink > 0.05 && <line x1={x - 22} x2={x + 22} y1={-626 + 50 * blink} y2={-626 + 50 * blink} stroke={C.line} strokeWidth={4} />}
        </g>
        <path d={`M ${x - 22} -606 Q ${x} -630 ${x + 22} -606`} fill="none" stroke={C.line} strokeWidth={4.5} strokeLinecap="round" />
      </g>
      {happy > 0.01 && (
        <path d={`M ${x - 20} -596 Q ${x} -622 ${x + 20} -596`} fill="none" stroke={C.line} strokeWidth={7} strokeLinecap="round" opacity={happy} />
      )}
    </g>
  );
};

const Mouth: React.FC<{ m: number; smile: number }> = ({ m, smile }) => {
  const w = 76 - m * 16, h = 3 + m * 40, lift = 6 + smile * 8;
  const d = `M ${-w / 2} ${-lift} Q 0 ${4 + smile * 4} ${w / 2} ${-lift} Q 0 ${h + 10 + smile * 6} ${-w / 2} ${-lift} Z`;
  return (
    <g transform="translate(0 -518)">
      <clipPath id="mouthClip"><path d={d} /></clipPath>
      <path d={d} fill="#4a1619" />
      <g clipPath="url(#mouthClip)">
        <rect x={-w / 2} y={-lift - 2} width={w} height={6 + 9 * Math.min(1, m * 2)} fill="#fbf8f2" />
        <ellipse cx={0} cy={h + 6} rx={w * 0.32} ry={6 + h * 0.3} fill="#d4646a" />
      </g>
      <path d={d} fill="none" stroke={C.line} strokeWidth={4.5} strokeLinejoin="round" />
      <path d={`M ${-w / 2 - 4} ${-lift - 2} Q ${-w / 2 - 8} ${-lift + 4} ${-w / 2 - 3} ${-lift + 8}`} stroke={C.skinDark} strokeWidth={3} fill="none" opacity={0.6} />
      <path d={`M ${w / 2 + 4} ${-lift - 2} Q ${w / 2 + 8} ${-lift + 4} ${w / 2 + 3} ${-lift + 8}`} stroke={C.skinDark} strokeWidth={3} fill="none" opacity={0.6} />
    </g>
  );
};

const ArmSeg: React.FC<{ x: number; y: number; a: number; len: number; r: number }> = ({ x, y, a, len, r }) => (
  <g transform={`translate(${x} ${y}) rotate(${deg(a)})`}>
    <rect x={-r} y={-r} width={len + 2 * r} height={2 * r} rx={r} fill="url(#sleeve)" stroke={C.line} strokeWidth={4.5} />
  </g>
);

const Chef: React.FC<{ frame: number; heat: number; toss: number }> = ({ frame, heat, toss }) => {
  const m = mouthOpen(frame);
  const look = lookAt(frame);
  const happy = lerp(frame, E.done + 4, E.done + 14, 0, 1) * (frame < E.ding + 70 ? 1 : lerp(frame, E.ding + 70, E.ding + 85, 1, 0));
  const breathe = 1 + Math.sin(frame / 38) * 0.006;
  const bobY = Math.sin(frame / 38) * 3 + m * 3;
  const tilt = look.x * 3 + wob(frame, 1) * 1.2 + m * 1.5 * Math.sin(frame / 7);
  const hatLag = -tilt * 0.6 + Math.sin(frame / 38 - 0.8) * 1.2;
  const browUp = Math.max(sp(frame - E.heat, 10) * (frame < E.heat + 70 ? 1 : lerp(frame, E.heat + 70, E.heat + 90, 1, 0)), happy * 0.6);
  const smile = 0.3 + happy * 0.7 + heat * 0.15;

  return (
    <g>
      {/* Schatten an der Wand */}
      <ellipse cx={70} cy={-360} rx={230} ry={330} fill="#000" opacity={0.28} filter="url(#soft)" />

      {/* Oberkörper */}
      <g transform={`scale(1 ${breathe})`}>
        <path d="M -150 -430 C -205 -425 -215 -370 -212 -300 L -200 40 L 200 40 L 212 -300 C 215 -370 205 -425 150 -430 Z"
          fill="url(#coat)" stroke={C.line} strokeWidth={5} />
        <path d="M 118 -426 C 205 -418 214 -360 212 -300 L 200 40 L 150 40 C 168 -120 172 -300 118 -426 Z" fill={C.coatShade} opacity={0.55} />
        <path d="M -185 -380 C -200 -330 -202 -200 -196 -60" stroke="#fff" strokeWidth={6} fill="none" opacity={0.7} strokeLinecap="round" />
        {[-310, -235, -160, -85].map((y) => [-46, 46].map((x) => (
          <g key={`${x}${y}`}>
            <circle cx={x} cy={y} r={9.5} fill="#ecebe5" stroke="#8f8d84" strokeWidth={3} />
            <circle cx={x - 3} cy={y - 3} r={3} fill="#fff" />
          </g>
        )))}
        <g transform="translate(-160 -292)">
          <rect width={112} height={44} rx={8} fill="#fffaf0" stroke={C.line} strokeWidth={3} />
          <text x={56} y={29} textAnchor="middle" fontFamily={C.mono} fontWeight={700} fontSize={19} fill="#1d1b18">DEV-KOCH</text>
          <circle cx={56} cy={-2} r={5} fill="#c0392b" />
        </g>
        <path d="M -62 -432 L 0 -352 L 62 -432 Z" fill="url(#scarf)" stroke={C.line} strokeWidth={4} strokeLinejoin="round" />
        <path d="M -98 -430 L -60 -432 L -14 -372 L -70 -398 Z" fill="#ffffff" stroke={C.line} strokeWidth={4} strokeLinejoin="round" />
        <path d="M 98 -430 L 60 -432 L 14 -372 L 70 -398 Z" fill={C.coat} stroke={C.line} strokeWidth={4} strokeLinejoin="round" />
      </g>

      {/* Hals + Kopf */}
      <rect x={-40} y={-490} width={80} height={70} fill={C.skinDark} />
      <g transform={`translate(0 ${bobY}) rotate(${tilt} 0 -470)`}>
        <ellipse cx={0} cy={-470} rx={70} ry={18} fill="#000" opacity={0.18} />
        {[-1, 1].map((s) => (
          <g key={s}>
            <circle cx={s * 116} cy={-585} r={27} fill="url(#skin)" stroke={C.line} strokeWidth={4.5} />
            <path d={`M ${s * 110} -596 Q ${s * 124} -585 ${s * 112} -572`} stroke={C.skinDark} strokeWidth={4} fill="none" />
          </g>
        ))}
        <circle cx={0} cy={-590} r={120} fill="url(#skin)" stroke={C.line} strokeWidth={5} />
        <path d="M 60 -500 Q 110 -540 112 -610 Q 118 -520 40 -478 Z" fill={C.skinDark} opacity={0.22} />
        <path d={`M -112 -655 Q -118 -610 -100 -590 L -92 -640 Z`} fill={C.hair} />
        <path d={`M 112 -655 Q 118 -610 100 -590 L 92 -640 Z`} fill={C.hair} />
        {[-1, 1].map((s) => <circle key={s} cx={s * 70} cy={-548} r={26} fill="#ff8f7a" opacity={0.28 + happy * 0.15} />)}

        <Eye x={-44} frame={frame} happy={happy} lx={look.x} ly={look.y} id="eyeL" />
        <Eye x={44} frame={frame} happy={happy} lx={look.x} ly={look.y} id="eyeR" />
        {[-1, 1].map((s) => (
          <path key={s} transform={`translate(${s * 46} ${-646 - browUp * 12}) rotate(${s * (-6 + browUp * 8)})`}
            d="M -27 6 Q 0 -10 27 3" stroke="#3a281d" strokeWidth={10} fill="none" strokeLinecap="round" />
        ))}
        <path d="M -6 -582 Q 4 -552 16 -562" stroke={C.skinDark} strokeWidth={5} fill="none" strokeLinecap="round" />
        <circle cx={-2} cy={-578} r={4} fill="#fff" opacity={0.35} />
        <Mouth m={m} smile={smile} />

        {/* Kochmütze mit Nachschwingen */}
        <g transform={`rotate(${hatLag} 0 -700)`}>
          {[[-80, -772, 62], [80, -772, 62], [-34, -828, 58], [36, -826, 60], [0, -800, 78]].map(([x, y, r], i) => (
            <circle key={i} cx={x} cy={y} r={r} fill="url(#hat)" stroke={C.line} strokeWidth={4.5} />
          ))}
          <circle cx={0} cy={-790} r={70} fill="url(#hat)" />
          <path d="M -40 -760 Q -30 -800 -10 -820 M 30 -760 Q 34 -790 50 -812" stroke="#cfcdc4" strokeWidth={5} fill="none" strokeLinecap="round" />
          <rect x={-110} y={-742} width={220} height={78} rx={14} fill="url(#hat)" stroke={C.line} strokeWidth={4.5} />
          <path d="M -60 -738 V -668 M 0 -738 V -668 M 60 -738 V -668" stroke="#d8d6ce" strokeWidth={4} />
          <rect x={-106} y={-682} width={212} height={14} rx={6} fill="#000" opacity={0.08} />
        </g>
      </g>

      {/* Herd + Flammen */}
      <g>
        <ellipse cx={40} cy={-12} rx={135} ry={16} fill="#1a1c20" stroke={C.line} strokeWidth={3} />
        <g filter="url(#glow)">
          {Array.from({ length: 11 }, (_, i) => {
            const fx = 40 - 165 + i * 33;
            const H = (12 + heat * 58) * (0.75 + 0.35 * Math.abs(wob(frame * 1.8, i * 1.7)));
            return (
              <path key={i} d={`M ${fx - 13} -16 Q ${fx - 16} ${-16 - H * 0.55} ${fx + wob(frame, i) * 4} ${-16 - H} Q ${fx + 16} ${-16 - H * 0.55} ${fx + 13} -16 Z`}
                fill="url(#flame)" opacity={0.95} />
            );
          })}
        </g>
        {/* Topfrost, auf dem die Pfanne steht */}
        {[-100, 180].map((x) => (
          <rect key={x} x={x} y={-56} width={12} height={50} rx={4} fill="#2b2e33" stroke={C.line} strokeWidth={3} />
        ))}
        <rect x={-120} y={-60} width={320} height={10} rx={5} fill="#2b2e33" stroke={C.line} strokeWidth={3} />
      </g>
    </g>
  );
};

/* ════════════════════════ PFANNE + INHALT ══════════════════════════ */
const BITS = [
  { t: E.chip1, label: "{ }", col: C.red },
  { t: E.chip2, label: "log", col: C.blue },
  { t: E.chip3, label: "✓", col: C.green },
];
const Pan: React.FC<{ frame: number; heat: number; toss: number }> = ({ frame, heat, toss }) => {
  const cx = 40, cy = -100 - toss * 55;
  const ang = -toss * 9;
  return (
    <g transform={`rotate(${ang} 360 ${-108})`}>
      <g transform={`rotate(-5 ${cx + 175} ${cy})`}>
        <rect x={cx + 170} y={cy - 13} width={240} height={26} rx={13} fill="#24272c" stroke={C.line} strokeWidth={4} />
        <rect x={cx + 185} y={cy - 9} width={200} height={5} rx={2.5} fill="#fff" opacity={0.18} />
        <circle cx={cx + 388} cy={cy} r={6} fill="#0f1114" />
      </g>
      <path d={`M ${cx - 192} ${cy} A 192 46 0 0 0 ${cx + 192} ${cy} L ${cx + 172} ${cy + 42} A 172 30 0 0 1 ${cx - 172} ${cy + 42} Z`}
        fill="url(#panSide)" stroke={C.line} strokeWidth={4.5} />
      <ellipse cx={cx} cy={cy} rx={192} ry={46} fill="#4b5059" stroke={C.line} strokeWidth={4.5} />
      <ellipse cx={cx} cy={cy + 3} rx={176} ry={38} fill="url(#panIn)" />
      <ellipse cx={cx} cy={cy + 3} rx={176} ry={38} fill="#ff7a2a" opacity={heat * 0.32 * (0.85 + 0.15 * Math.sin(frame / 5))} />
      <clipPath id="panClip"><ellipse cx={cx} cy={cy + 3} rx={172} ry={36} /></clipPath>
      <g clipPath="url(#panClip)">
        {BITS.map((b, i) => {
          const appear = sp(frame - b.t - 22, 10);
          if (frame < b.t + 22) return null;
          const jump = toss > 0 ? toss * (60 + i * 18) : 0;
          const jig = heat * Math.sin(frame / 3 + i * 2) * 4;
          const bx = cx - 90 + i * 85, by = cy + 6 - jump + jig;
          return (
            <g key={i} transform={`translate(${bx} ${by}) scale(${appear})`} filter="url(#glow)">
              <rect x={-36} y={-20} width={72} height={40} rx={12} fill={b.col} opacity={0.9} />
              <text y={11} textAnchor="middle" fontFamily={C.mono} fontWeight={700} fontSize={26} fill="#101216">{b.label}</text>
            </g>
          );
        })}
      </g>
      <path d={`M ${cx - 170} ${cy - 18} A 192 46 0 0 1 ${cx + 60} ${cy - 45}`} stroke="#fff" strokeOpacity={0.3} strokeWidth={5} fill="none" strokeLinecap="round" />
    </g>
  );
};

const Arms: React.FC<{ frame: number; toss: number }> = ({ frame, toss }) => {
  const thumbs = sp(frame - E.done - 6, 11, 0.8, 140);
  const stirring = frame > E.chip1 - 10 && frame < E.done;
  const st = frame / 9;
  const spatX = stirring ? -30 + Math.cos(st) * 42 : -40;
  const spatY = stirring ? -180 + Math.sin(st) * 12 : -200;
  // Daumen-hoch-Pose seitlich neben der Schulter, Ellbogen bleibt außerhalb des Gesichts
  const lT = { x: spatX * (1 - thumbs) + -360 * thumbs, y: spatY * (1 - thumbs) + -430 * thumbs };
  const L = ik(-168, -395, lT.x, lT.y, 200, 190, 1);
  const R = ik(168, -395, 360, -108 - toss * 70, 205, 200, -1);
  const spatAngle = deg(Math.atan2(-75 - L.hy, 30 - L.hx));
  return (
    <g>
      {/* rechter Arm hält die Pfanne */}
      <ArmSeg x={168} y={-395} a={R.a1} len={205} r={36} />
      <ArmSeg x={R.ex} y={R.ey} a={R.a2} len={200} r={31} />
      <g transform={`translate(${R.hx} ${R.hy}) rotate(${deg(R.a2)})`}>
        <rect x={-46} y={-33} width={24} height={66} rx={8} fill="#e8e6de" stroke={C.line} strokeWidth={4} />
      </g>
      <circle cx={R.hx} cy={R.hy} r={31} fill="url(#hand)" stroke={C.line} strokeWidth={4.5} />
      <path d={`M ${R.hx - 18} ${R.hy - 8} Q ${R.hx} ${R.hy - 20} ${R.hx + 20} ${R.hy - 6}`} stroke={C.skinDark} strokeWidth={4} fill="none" />

      {/* linker Arm mit Pfannenwender bzw. Daumen hoch */}
      <ArmSeg x={-168} y={-395} a={L.a1} len={200} r={36} />
      <ArmSeg x={L.ex} y={L.ey} a={L.a2} len={190} r={31} />
      <g opacity={1 - thumbs} transform={`translate(${L.hx} ${L.hy}) rotate(${spatAngle})`}>
        <rect x={0} y={-7} width={150} height={14} rx={7} fill="#8a5a35" stroke={C.line} strokeWidth={3.5} />
        <rect x={140} y={-24} width={70} height={48} rx={8} fill="#b9c0c9" stroke={C.line} strokeWidth={3.5} />
        <path d="M 156 -12 H 198 M 156 0 H 198 M 156 12 H 198" stroke="#7d848e" strokeWidth={3} />
      </g>
      <g transform={`translate(${L.hx} ${L.hy}) rotate(${deg(L.a2)})`}>
        <rect x={-46} y={-33} width={24} height={66} rx={8} fill="#e8e6de" stroke={C.line} strokeWidth={4} />
      </g>
      <circle cx={L.hx} cy={L.hy} r={31} fill="url(#hand)" stroke={C.line} strokeWidth={4.5} />
      {thumbs > 0.02 && (
        <rect x={L.hx - 11} y={L.hy - 30 - 34 * thumbs} width={22} height={34 * thumbs + 10} rx={11}
          fill="url(#hand)" stroke={C.line} strokeWidth={4} />
      )}
    </g>
  );
};

/* ═══════════════════ THEKE, REGLER, TUCH (vorne) ═══════════════════ */
const Counter: React.FC<{ frame: number; dial: number; heat: number }> = ({ frame, dial, heat }) => {
  const angle = -120 + dial * 240;
  const level = dial < 0.34 ? "LOW" : dial < 0.67 ? "MEDIUM" : "HIGH";
  const col = level === "LOW" ? C.blue : level === "MEDIUM" ? C.yellow : C.red;
  const towelSway = Math.sin(frame / 45) * 2 + heat * Math.sin(frame / 6) * 0.8;
  return (
    <g>
      <rect x={0} y={1296} width={1080} height={18} fill="url(#lip)" />
      <rect x={0} y={1296} width={1080} height={3} fill="#fff" opacity={0.35} />
      <rect x={0} y={1314} width={1080} height={360} fill="url(#steel)" />
      <rect x={0} y={1314} width={1080} height={360} fill="url(#brushed)" />
      <rect x={0} y={1314} width={1080} height={26} fill="#000" opacity={0.25} />
      {/* Regler */}
      <g transform="translate(230 1480)">
        <circle r={84} fill="#2a2d32" stroke={C.line} strokeWidth={5} />
        {Array.from({ length: 13 }, (_, i) => {
          const a = ((-120 + i * 20) * Math.PI) / 180;
          return <line key={i} x1={Math.sin(a) * 96} y1={-Math.cos(a) * 96} x2={Math.sin(a) * 108} y2={-Math.cos(a) * 108}
            stroke={i * 20 <= dial * 240 ? col : "#59606a"} strokeWidth={i % 6 === 0 ? 6 : 3} strokeLinecap="round" />;
        })}
        <g transform={`rotate(${angle})`} filter="url(#drop)">
          <circle r={60} fill="url(#knob)" stroke={C.line} strokeWidth={4} />
          {Array.from({ length: 16 }, (_, i) => (
            <rect key={i} x={-2.5} y={-60} width={5} height={10} fill="#7a8089" transform={`rotate(${i * 22.5})`} />
          ))}
          <rect x={-8} y={-54} width={16} height={46} rx={8} fill="#22252a" />
        </g>
      </g>
      <g transform="translate(345 1446)">
        <rect width={240} height={68} rx={34} fill="#191c20" stroke={col} strokeWidth={4} />
        <text x={120} y={46} textAnchor="middle" fontFamily={C.mono} fontWeight={700} fontSize={34} fill={col} filter="url(#glow)">{level}</text>
      </g>
      {/* Geschirrtuch */}
      <g transform={`rotate(${towelSway} 860 1320)`}>
        <rect x={800} y={1316} width={130} height={210} rx={10} fill="url(#towel)" stroke={C.line} strokeWidth={4} />
        <rect x={800} y={1316} width={130} height={24} fill="#000" opacity={0.18} />
        <rect x={800} y={1496} width={130} height={30} fill="#000" opacity={0.12} />
      </g>
    </g>
  );
};

/* ══════════════════ ZUTATEN, DAMPF, FUNKEN (vorne) ══════════════════ */
const CHIPS = [
  { t: E.chip1, label: "Stacktrace", col: C.red, x: 380 },
  { t: E.chip2, label: "Logs", col: C.blue, x: 610 },
  { t: E.chip3, label: "Test", col: C.green, x: 800 },
];
const PAN_X = 600, PAN_Y = 1210;
const Chips: React.FC<{ frame: number }> = ({ frame }) => (
  <g>
    {CHIPS.map((c, i) => {
      const t = frame - c.t;
      if (t < 0 || t > 40) return null;
      const fall = lerp(frame, c.t, c.t + 17, 0, 1, Easing.in(Easing.quad));
      const x = c.x + (PAN_X - 90 + i * 85 - c.x) * fall;
      const y = -120 + (PAN_Y + 10 - -120) * fall;
      const s = t < 17 ? 1 : lerp(frame, c.t + 17, c.t + 26, 1, 0);
      const rot = (1 - fall) * (i % 2 ? 14 : -14) + Math.sin(t / 3) * 4 * (1 - fall);
      const w = c.label.length * 21 + 70;
      return (
        <g key={c.label} transform={`translate(${x} ${y}) rotate(${rot}) scale(${s})`} filter="url(#drop)">
          <rect x={-w / 2} y={-36} width={w} height={72} rx={18} fill="#fffdf8" stroke={C.line} strokeWidth={4} />
          <circle cx={-w / 2 + 30} cy={0} r={12} fill={c.col} />
          <text x={14} y={12} textAnchor="middle" fontFamily={C.mono} fontWeight={700} fontSize={34} fill="#1d1b18">{c.label}</text>
        </g>
      );
    })}
  </g>
);

const Steam: React.FC<{ frame: number; heat: number }> = ({ frame, heat }) => (
  <g filter="url(#steamBlur)" style={{ mixBlendMode: "screen" }}>
    {Array.from({ length: 9 }, (_, i) => {
      const period = 100 + (i % 3) * 17;
      const p = ((frame + i * 37) % period) / period;
      const x = PAN_X - 120 + rnd(i) * 240 + Math.sin(frame / 20 + i) * 22 + p * (rnd(i + 9) - 0.5) * 80;
      const y = PAN_Y - 30 - p * (260 + heat * 160);
      const r = 18 + p * (50 + heat * 40);
      const o = Math.sin(p * Math.PI) * (0.07 + heat * 0.22);
      return <circle key={i} cx={x} cy={y} r={r} fill="#ffffff" opacity={o} />;
    })}
  </g>
);

const Sparks: React.FC<{ frame: number; heat: number }> = ({ frame, heat }) => {
  if (frame < E.heat) return null;
  return (
    <g filter="url(#glow)">
      {Array.from({ length: 34 }, (_, i) => {
        const life = 42;
        const born = E.heat + Math.floor(rnd(i) * 30) + Math.floor((frame - E.heat - rnd(i) * 30) / life) * life;
        const t = frame - born;
        if (t < 0 || t > life) return null;
        const seed = i * 13 + Math.floor((frame - E.heat) / life) * 7;
        const vx = (rnd(seed) - 0.5) * 9, vy = -(7 + rnd(seed + 1) * 9);
        const x = PAN_X - 150 + rnd(seed + 2) * 300 + vx * t;
        const y = PAN_Y - 30 + vy * t + 0.22 * t * t;
        const o = (1 - t / life) * heat;
        return <line key={i} x1={x} y1={y} x2={x - vx * 2.2} y2={y - (vy + 0.44 * t) * 2.2} stroke="#ffd27a" strokeWidth={3.5} strokeLinecap="round" opacity={o} />;
      })}
    </g>
  );
};

/* ═══════════════════════════ UNTERTITEL ════════════════════════════ */
type Line = { words: { text: string; at: number }[]; from: number; to: number };
const LINES: Line[] = (() => {
  const lines: { text: string; at: number }[][] = [];
  let cur: { text: string; at: number }[] = [];
  for (const w of words) {
    cur.push({ text: w.text, at: S(w.start) });
    const chars = cur.map((x) => x.text).join(" ").length;
    if (/[.!?]$/.test(w.text) || cur.length >= 5 || chars > 24) { lines.push(cur); cur = []; }
  }
  if (cur.length) lines.push(cur);
  const last = S(words[words.length - 1].end) + 50;
  return lines.map((l, i) => ({ words: l, from: l[0].at, to: i + 1 < lines.length ? lines[i + 1][0].at : last }));
})();
const Captions: React.FC<{ frame: number }> = ({ frame }) => {
  const line = LINES.find((l) => frame >= l.from && frame < l.to);
  if (!line) return null;
  const visible = line.words.filter((w) => frame >= w.at);
  const cur = visible[visible.length - 1];
  return (
    <div style={{
      position: "absolute", left: 50, right: 50, top: 1712, display: "flex", flexWrap: "wrap",
      justifyContent: "center", gap: "8px 14px", fontFamily: C.sans, fontWeight: 900, fontSize: 70,
    }}>
      {visible.map((w) => {
        const pop = sp(frame - w.at, 11, 0.6, 220);
        const active = w === cur;
        return (
          <span key={w.text + w.at} style={{
            display: "inline-block", padding: "2px 16px", borderRadius: 18,
            background: active ? C.yellow : "transparent", color: active ? "#1a1a1a" : "#fff",
            textShadow: active ? "none" : "0 4px 0 rgba(0,0,0,.55), 0 0 18px rgba(0,0,0,.5)",
            transform: `scale(${0.7 + 0.3 * pop}) translateY(${(1 - pop) * 14}px)`,
          }}>{w.text}</span>
        );
      })}
    </div>
  );
};

/* ═════════════════════════════ SZENE ═══════════════════════════════ */
export const KochSzeneHD: React.FC = () => {
  const frame = useCurrentFrame();

  const dial = interpolate(sp(frame - E.heat, 9, 0.9, 110), [0, 1], [0, 1]);
  const heat = 0.22 + 0.78 * Math.min(1.1, dial);
  const tossT = (frame - E.toss) / 38;
  const toss = tossT > 0 && tossT < 1 ? Math.sin(tossT * Math.PI) * (1 - tossT * 0.3) : 0;

  // Kamera: langsame Fahrt + Ruck bei „Hitze hoch“ + Wackler beim Stempel
  const th = frame - E.heat;
  const punch = th > 0 ? 0.055 * (1 - Math.exp(-th * 0.22)) * Math.exp(-th * 0.025) : 0;
  const zoom = 1 + 0.045 * (frame / DURATION_IN_FRAMES) + punch;
  const td = frame - E.done - 4;
  const shake = td > 0 ? Math.exp(-td / 7) * 9 : 0;
  const camX = Math.sin(frame / 97) * 5 + Math.sin(frame / 41) * 2 + Math.sin(frame * 1.7) * shake;
  const camY = Math.sin(frame / 83) * 4 + Math.cos(frame * 1.9) * shake;
  const fadeIn = lerp(frame, 0, 18, 0, 1);
  const fadeOut = lerp(frame, DURATION_IN_FRAMES - 24, DURATION_IN_FRAMES, 1, 0);

  return (
    <AbsoluteFill style={{ backgroundColor: "#0e1015" }}>
      <Audio src={staticFile("koch-szene-hd/mix.wav")} />
      <AbsoluteFill style={{ opacity: fadeIn * fadeOut }}>
        <svg viewBox="0 0 1080 1920" width={1080} height={1920}>
          <Defs frame={frame} />
          <g transform={`translate(${540 + camX} ${1000 + camY}) scale(${zoom}) translate(-540 -1000)`}>
            <Background frame={frame} />
            <Lamp frame={frame} />
            <Ticket frame={frame} />
            <g transform="translate(560 1305)">
              <Chef frame={frame} heat={heat} toss={toss} />
              <Pan frame={frame} heat={heat} toss={toss} />
              <Arms frame={frame} toss={toss} />
            </g>
            <ellipse cx={PAN_X} cy={PAN_Y + 10} rx={420} ry={300} fill="url(#heatGlow)" opacity={heat * 0.7}
              style={{ mixBlendMode: "screen" }} />
            <Counter frame={frame} dial={dial} heat={heat} />
            <Chips frame={frame} />
            <Steam frame={frame} heat={heat} />
            <Sparks frame={frame} heat={heat} />
            <rect x={0} y={1674} width={1080} height={300} fill="#0e1015" />
          </g>
          <rect width={1080} height={1920} fill="url(#vignette)" />
          <rect width={1080} height={1920} filter="url(#grain)" opacity={0.07} style={{ mixBlendMode: "overlay" }} />
          {/* Kopfzeile */}
          <g transform="translate(48 120)" opacity={lerp(frame, 6, 24, 0, 1)}>
            <rect width={392} height={62} rx={31} fill="#000" opacity={0.45} />
            <circle cx={34} cy={31} r={9} fill={C.red} opacity={0.6 + 0.4 * Math.sin(frame / 10)} />
            <text x={56} y={42} fontFamily={C.mono} fontSize={28} letterSpacing={3} fill="#e8e6e0">BUG-KÜCHE · EP 01</text>
          </g>
        </svg>
        <Captions frame={frame} />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
