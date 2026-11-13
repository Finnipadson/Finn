import React, { createContext, useContext } from "react";
import { Easing, interpolate, spring } from "remotion";
import type { Farbe } from "../drehbuch/typen";

/* Gemeinsame Bausteine für alle Szenen: Farben, Icons, Animations-Helfer, Szenen-Kontext. */

export const T = {
  bg: "#0d1020", panel: "#161a2e", panel2: "#1d2238", line: "rgba(255,255,255,0.12)",
  text: "#eef0f7", dim: "#9aa1b9", akzent: "#ff7a59", teal: "#3dd6c4", lila: "#8b7bff",
  gelb: "#ffd34d", gruen: "#3ddc97", rot: "#ff5d6c", blau: "#5aa9ff",
  a: "#4fd1ff", b: "#f2c94c", c: "#ff6b5b",
  sans: "'Segoe UI', Arial, sans-serif",
  mono: "'Cascadia Code', Consolas, 'Courier New', monospace",
};
export const farbe = (f?: Farbe) => ({
  a: T.a, b: T.b, c: T.c, akzent: T.akzent, text: T.text, gruen: T.gruen, rot: T.rot, blau: T.blau, lila: T.lila,
}[f ?? "text"]);

export const FPS = 60;
export const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
// Zeitpunkte können „Infinity“ sein (optionales Element ohne „bei“ = tritt nie ein) → dann bleibt der Startwert.
export const lerp = (f: number, a: number, b: number, from: number, to: number, ease = Easing.inOut(Easing.cubic)) => {
  if (!Number.isFinite(a)) return from;
  if (!Number.isFinite(b) || b <= a) return f >= a ? to : from;
  return interpolate(f, [a, b], [from, to], { ...clamp, easing: ease });
};
export const sp = (f: number, damping = 13, mass = 0.8, stiffness = 140) =>
  !Number.isFinite(f) ? (f > 0 ? 1 : 0) : spring({ frame: f, fps: FPS, config: { damping, mass, stiffness } });

/* ── Szenen-Kontext: lokales Bild, Dauer, „bei“-Zeitpunkte, Format ── */
export type SzenenKontext = {
  f: number;            // Bild seit Szenenbeginn
  dauer: number;        // Szenenlänge in Bildern
  hoch: boolean;
  W: number; H: number;
  bei: (wert: string | undefined, ersatz: number) => number;  // lokales Bild, an dem „bei“ eintritt
};
export const Ctx = createContext<SzenenKontext | null>(null);
export const useSzene = () => {
  const c = useContext(Ctx);
  if (!c) throw new Error("useSzene außerhalb einer Szene");
  return c;
};

/* ── Icons (24×24, Linien) ── */
const ICONS: Record<string, string> = {
  chat: "M4 5h16v10H9l-5 4z",
  datei: "M6 3h8l4 4v14H6z M14 3v4h4",
  stift: "M4 20l4-1 11-11-3-3L5 16z",
  terminal: "M4 6l6 6-6 6 M12 18h8",
  haken: "M5 12l4 4 10-10",
  kreuz: "M6 6l12 12 M18 6L6 18",
  idee: "M9 18h6 M10 21h4 M12 3a6 6 0 0 0-4 10c1 1 1 2 1 3h6c0-1 0-2 1-3a6 6 0 0 0-4-10z",
  buch: "M4 5h7v14H4z M13 5h7v14h-7z",
  karte: "M4 6l5-2 6 2 5-2v14l-5 2-6-2-5 2z M9 4v14 M15 6v14",
  lupe: "M11 4a7 7 0 1 0 0 14a7 7 0 1 0 0-14z M16 16l5 5",
  wegweiser: "M12 3v18 M5 7h11l3 3-3 3H5z",
  schild: "M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6z",
  stern: "M12 3l2 6 6 2-6 2-2 6-2-6-6-2 6-2z",
  person: "M12 4a4 4 0 1 0 0 8a4 4 0 1 0 0-8z M4 21c0-4 4-6 8-6s8 2 8 6",
  blitz: "M13 2L4 14h7l-1 8 9-12h-7z",
  herz: "M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.5-7 10-7 10z",
  zahnrad: "M12 8a4 4 0 1 0 0 8a4 4 0 1 0 0-8z M12 2v3 M12 19v3 M2 12h3 M19 12h3 M5 5l2 2 M17 17l2 2 M5 19l2-2 M17 7l2-2",
  uhr: "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18z M12 7v5l3 3",
  rakete: "M12 2c4 3 5 8 3 13H9C7 10 8 5 12 2z M9 15l-3 4 4-1 M15 15l3 4-4-1",
  ziel: "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18z M12 8a4 4 0 1 0 0 8a4 4 0 1 0 0-8z",
};
export const ICON_NAMEN = Object.keys(ICONS);
export const Icon: React.FC<{ name?: string; size?: number; color?: string; width?: number }> = ({ name = "stern", size = 28, color = T.text, width = 2 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block", flexShrink: 0 }}>
    <path d={ICONS[name] ?? ICONS.stern} fill="none" stroke={color} strokeWidth={width} strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

/* ── Einblenden mit Feder ── */
export const Pop: React.FC<{ at: number; children: React.ReactNode; style?: React.CSSProperties; from?: number }> = ({ at, children, style, from = 40 }) => {
  const { f } = useSzene();
  if (f < at) return <div style={{ ...style, visibility: "hidden" }}>{children}</div>;
  const p = sp(f - at);
  return <div style={{ opacity: Math.min(1, p * 1.4), transform: `translateY(${(1 - p) * from}px) scale(${0.92 + 0.08 * p})`, ...style }}>{children}</div>;
};

/* ── Überschrift oben ── */
export const Kopf: React.FC<{ kicker?: string; titel?: string }> = ({ kicker, titel }) => {
  const { f, hoch } = useSzene();
  if (!kicker && !titel) return null;
  const p = sp(f - 4, 16);
  return (
    <div style={{ textAlign: "center", opacity: p, transform: `translateY(${(1 - p) * -20}px)`, padding: "0 60px" }}>
      {kicker && <div style={{ fontFamily: T.mono, fontSize: hoch ? 30 : 22, letterSpacing: 6, color: T.akzent }}>{kicker.toUpperCase()}</div>}
      {titel && <div style={{ fontFamily: T.sans, fontWeight: 800, fontSize: hoch ? 76 : 58, lineHeight: 1.1, color: T.text, marginTop: 8 }}>{titel}</div>}
    </div>
  );
};

/* ── Karte mit Verlauf ── */
export const Karte: React.FC<{ children: React.ReactNode; glow?: string; style?: React.CSSProperties }> = ({ children, glow, style }) => (
  <div style={{
    borderRadius: 28, background: `linear-gradient(160deg, ${T.panel2}, ${T.panel})`,
    border: `1.5px solid ${glow ? `${glow}aa` : T.line}`,
    boxShadow: `0 30px 60px rgba(0,0,0,.45)${glow ? `, 0 0 50px ${glow}2a` : ""}`, ...style,
  }}>{children}</div>
);
