import React from "react";
import {
  AbsoluteFill, Audio, Easing, Img, interpolate, spring, staticFile, useCurrentFrame,
} from "remotion";
import WORDS from "./words.json";
import EVENTS from "./events.json";

/* ════════════════════════════════════════════════════════════════════
   „Claude Code – kurz erklärt“  ·  1920×1080 · 60 fps
   Alle Zeitpunkte kommen aus audio.py (events.json / words.json).
   ════════════════════════════════════════════════════════════════════ */

export const FPS = 60;
const S = (s: number) => Math.round(s * FPS);
const EV = EVENTS as Record<string, number>;
const E = (k: string) => S(EV[k]);
export const DURATION_IN_FRAMES = S(EV.duration);
const words = WORDS as { text: string; start: number; end: number; scene: number }[];
const bare = (s: string) => s.replace(/[.,:!?]+$/, "");
const W = (text: string, nth = 0) => {
  const w = words.filter((x) => bare(x.text) === text)[nth];
  if (!w) throw new Error(`Wort fehlt: ${text} #${nth}`);
  return S(w.start);
};

// ── Helfer ───────────────────────────────────────────────────────────
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const lerp = (f: number, a: number, b: number, from: number, to: number, ease = Easing.inOut(Easing.cubic)) =>
  interpolate(f, [a, b], [from, to], { ...clamp, easing: ease });
const sp = (f: number, damping = 13, mass = 0.8, stiffness = 140) =>
  spring({ frame: f, fps: FPS, config: { damping, mass, stiffness } });
const typed = (text: string, f: number, start: number, cps = 38) =>
  text.slice(0, Math.max(0, Math.floor(((f - start) / FPS) * cps)));

const C = {
  bg: "#0d1020", panel: "#161a2e", panel2: "#1d2238", line: "rgba(255,255,255,0.12)",
  text: "#eef0f7", dim: "#9aa1b9", coral: "#ff7a59", teal: "#3dd6c4", violet: "#8b7bff",
  yellow: "#ffd34d", green: "#3ddc97", red: "#ff5d6c", blue: "#5aa9ff",
  sans: "'Segoe UI', Arial, sans-serif",
  mono: "'Cascadia Code', Consolas, 'Courier New', monospace",
};

// ── kleine Bausteine ─────────────────────────────────────────────────
const ICONS: Record<string, string> = {
  chat: "M4 5h16v10H9l-5 4z",
  file: "M6 3h8l4 4v14H6z M14 3v4h4",
  pencil: "M4 20l4-1 11-11-3-3L5 16z",
  terminal: "M4 6l6 6-6 6 M12 18h8",
  check: "M5 12l4 4 10-10",
  bulb: "M9 18h6 M10 21h4 M12 3a6 6 0 0 0-4 10c1 1 1 2 1 3h6c0-1 0-2 1-3a6 6 0 0 0-4-10z",
  book: "M4 5h7v14H4z M13 5h7v14h-7z",
  map: "M4 6l5-2 6 2 5-2v14l-5 2-6-2-5 2z M9 4v14 M15 6v14",
  search: "M11 4a7 7 0 1 0 0 14a7 7 0 1 0 0-14z M16 16l5 5",
  sign: "M12 3v18 M5 7h11l3 3-3 3H5z",
  shield: "M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6z",
  x: "M6 6l12 12 M18 6L6 18",
  spark: "M12 3l2 6 6 2-6 2-2 6-2-6-6-2 6-2z",
  user: "M12 4a4 4 0 1 0 0 8a4 4 0 1 0 0-8z M4 21c0-4 4-6 8-6s8 2 8 6",
};
const Icon: React.FC<{ name: string; size?: number; color?: string; width?: number }> = ({ name, size = 28, color = C.text, width = 2 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block" }}>
    <path d={ICONS[name]} fill="none" stroke={color} strokeWidth={width} strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

const Win: React.FC<{ title: string; w: number; h: number; children?: React.ReactNode; glow?: string; style?: React.CSSProperties }> = ({ title, w, h, children, glow, style }) => (
  <div style={{
    width: w, height: h, borderRadius: 22, background: `linear-gradient(160deg, ${C.panel2}, ${C.panel})`,
    border: `1.5px solid ${glow ?? C.line}`, overflow: "hidden", position: "relative",
    boxShadow: `0 30px 70px rgba(0,0,0,.55)${glow ? `, 0 0 50px ${glow}55` : ""}`, ...style,
  }}>
    <div style={{ height: 44, display: "flex", alignItems: "center", gap: 9, padding: "0 18px", borderBottom: `1px solid ${C.line}`, background: "rgba(255,255,255,0.03)" }}>
      {["#ff5f57", "#febc2e", "#28c840"].map((c) => <div key={c} style={{ width: 13, height: 13, borderRadius: 7, background: c }} />)}
      <div style={{ marginLeft: 12, fontFamily: C.sans, fontSize: 18, color: C.dim }}>{title}</div>
    </div>
    {children}
  </div>
);

const Pop: React.FC<{ f: number; at: number; children: React.ReactNode; style?: React.CSSProperties; from?: number }> = ({ f, at, children, style, from = 40 }) => {
  const p = sp(f - at);
  if (f < at) return null;
  return <div style={{ opacity: Math.min(1, p * 1.4), transform: `translateY(${(1 - p) * from}px) scale(${0.92 + 0.08 * p})`, ...style }}>{children}</div>;
};

const Heading: React.FC<{ f: number; at: number; kicker: string; title: string }> = ({ f, at, kicker, title }) => {
  const p = sp(f - at, 16);
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: 70, textAlign: "center", opacity: p, transform: `translateY(${(1 - p) * -20}px)` }}>
      <div style={{ fontFamily: C.mono, fontSize: 22, letterSpacing: 6, color: C.coral }}>{kicker}</div>
      <div style={{ fontFamily: C.sans, fontWeight: 800, fontSize: 58, color: C.text, marginTop: 6 }}>{title}</div>
    </div>
  );
};

/* ═════════════════════════ HINTERGRUND ═════════════════════════════ */
const Backdrop: React.FC<{ f: number }> = ({ f }) => (
  <AbsoluteFill>
    <AbsoluteFill style={{ background: `radial-gradient(1200px 800px at 50% 40%, #171c38 0%, ${C.bg} 70%)` }} />
    <svg width={1920} height={1080} style={{ position: "absolute" }}>
      <defs>
        <filter id="blob"><feGaussianBlur stdDeviation={90} /></filter>
        <pattern id="dots" width={48} height={48} patternUnits="userSpaceOnUse">
          <circle cx={2} cy={2} r={1.6} fill="#ffffff" opacity={0.07} />
        </pattern>
      </defs>
      <g filter="url(#blob)" opacity={0.55}>
        <circle cx={420 + Math.sin(f / 240) * 120} cy={300 + Math.cos(f / 300) * 80} r={260} fill={C.violet} opacity={0.45} />
        <circle cx={1520 + Math.cos(f / 260) * 140} cy={720 + Math.sin(f / 220) * 90} r={300} fill={C.coral} opacity={0.32} />
        <circle cx={1100 + Math.sin(f / 330) * 160} cy={200 + Math.sin(f / 280) * 60} r={200} fill={C.teal} opacity={0.25} />
      </g>
      <rect width={1920} height={1080} fill="url(#dots)" transform={`translate(${(f * 0.15) % 48} 0)`} />
    </svg>
  </AbsoluteFill>
);

/* ═════════════════════════ SZENE 1: Titel ══════════════════════════ */
const Scene1: React.FC<{ f: number }> = ({ f }) => {
  const title = "Claude Code";
  const up = lerp(f, W("Kurz") - 10, W("Kurz") + 20, 0, 1);
  const term = E("terminal");
  const chipsOut = lerp(f, term - 10, term + 10, 1, 0);
  const tp = sp(f - term + 4, 15);
  const lines = [
    { t: term + 4, txt: "> Baue mir ein Denkspiel mit Sudoku", col: C.text },
    { t: term + 24, txt: "● Lese Projektordner …", col: C.dim },
    { t: term + 38, txt: "● Erstelle kopfsache.html", col: C.teal },
    { t: term + 52, txt: "● Teste im Browser … ✓", col: C.green },
  ];
  return (
    <AbsoluteFill>
      <div style={{ position: "absolute", left: 0, right: 0, top: 360 - up * 250, textAlign: "center", transform: `scale(${1 - up * 0.42})` }}>
        <div style={{ fontFamily: C.sans, fontWeight: 900, fontSize: 170, color: C.text, letterSpacing: -2 }}>
          {title.split("").map((ch, i) => {
            const p = sp(f - 6 - i * 3, 12);
            return <span key={i} style={{ display: "inline-block", opacity: p, transform: `translateY(${(1 - p) * 60}px)`, color: i >= 7 ? C.coral : C.text }}>{ch === " " ? " " : ch}</span>;
          })}
        </div>
        <div style={{ fontFamily: C.mono, fontSize: 34, letterSpacing: 8, color: C.dim, opacity: sp(f - 40) }}>KURZ ERKLÄRT</div>
      </div>
      <div style={{ position: "absolute", top: 400, left: 0, right: 0, display: "flex", justifyContent: "center", gap: 40, opacity: chipsOut }}>
        <Pop f={f} at={W("Fragen")}>
          <div style={{ display: "flex", alignItems: "center", gap: 16, padding: "26px 38px", borderRadius: 26, background: C.panel2, border: `1.5px solid ${C.line}`, fontFamily: C.sans, fontSize: 38, color: C.dim }}>
            <Icon name="chat" size={40} color={C.dim} /> Fragen beantworten
          </div>
        </Pop>
        <Pop f={f} at={W("Projekt")}>
          <div style={{ display: "flex", alignItems: "center", gap: 16, padding: "26px 38px", borderRadius: 26, background: `linear-gradient(135deg, ${C.coral}33, ${C.violet}33)`, border: `1.5px solid ${C.coral}`, fontFamily: C.sans, fontWeight: 700, fontSize: 38, color: C.text, boxShadow: `0 0 40px ${C.coral}44` }}>
            <Icon name="terminal" size={40} color={C.coral} /> Selbst am Projekt arbeiten
          </div>
        </Pop>
      </div>
      {f >= term - 4 && (
        <div style={{ position: "absolute", left: 460, top: 330, opacity: tp, transform: `translateY(${(1 - tp) * 80}px)` }}>
          <Win title="Terminal — claude" w={1000} h={380} glow={C.coral}>
            <div style={{ padding: "26px 32px", fontFamily: C.mono, fontSize: 30, lineHeight: 1.7 }}>
              {lines.map((l) => <div key={l.t} style={{ color: l.col }}>{typed(l.txt, f, l.t, 110)}{f >= l.t && f < l.t + 18 && Math.floor(f / 10) % 2 === 0 ? "▍" : ""}</div>)}
            </div>
          </Win>
        </div>
      )}
    </AbsoluteFill>
  );
};

/* ═══════════════════ SZENE 2: Chat vs. Claude Code ═════════════════ */
const Scene2: React.FC<{ f: number }> = ({ f }) => {
  const chat = E("chat"), cc = E("cc"), read = E("read"), write = E("write"), run = E("run"), check = E("check");
  const hop = (f - chat) / 50;
  const carry = f > chat + 20 && f < cc + 120 ? Math.sin(hop * Math.PI) : 0;
  const files = ["src/", "  kopfsache.html", "  style.css", "tests/", "  logik.test.js", "CLAUDE.md"];
  const code = [
    { t: "function pruefeSudoku(feld) {", c: C.text },
    { t: "  for (const zeile of feld) {", c: C.text },
    { t: "    if (!gueltig(zeile)) return false;", c: C.text, del: true },
    { t: "    if (!gueltig(zeile)) return melde(zeile);", c: C.text, add: true },
    { t: "  }", c: C.text },
    { t: "  return true;", c: C.text },
    { t: "}", c: C.text },
  ];
  const wp = sp(f - write, 14);
  const ok = f >= check + 10;
  return (
    <AbsoluteFill>
      <Heading f={f} at={E("scene2")} kicker="DER UNTERSCHIED" title="Chatbot oder Claude Code?" />
      {/* links: normaler Chat */}
      <div style={{ position: "absolute", left: 110, top: 250 }}>
        <Pop f={f} at={chat}>
          <Win title="Normaler Chat" w={700} h={560}>
            <div style={{ padding: 26, display: "flex", flexDirection: "column", gap: 16, fontFamily: C.sans, fontSize: 25 }}>
              <div style={{ alignSelf: "flex-end", background: C.blue, color: "#fff", padding: "12px 20px", borderRadius: "20px 20px 4px 20px" }}>Wie behebe ich den Fehler?</div>
              <div style={{ alignSelf: "flex-start", background: C.panel, border: `1px solid ${C.line}`, padding: "14px 20px", borderRadius: "20px 20px 20px 4px", color: C.text, width: 520 }}>
                Ersetze Zeile 3 durch:
                <div style={{ fontFamily: C.mono, fontSize: 21, marginTop: 10, background: "#0b0e1a", padding: "10px 14px", borderRadius: 10, color: C.teal }}>return melde(zeile);</div>
              </div>
            </div>
            <div style={{ position: "absolute", left: 30, right: 30, bottom: 30, height: 150, borderRadius: 16, border: `1.5px dashed ${C.line}`, display: "flex", alignItems: "center", justifyContent: "center", fontFamily: C.sans, fontSize: 24, color: C.dim }}>
              dein Editor
            </div>
            {f > chat + 20 && (
              <div style={{
                position: "absolute", left: 210 + carry * 30, top: 275 + (hop % 2 < 1 ? carry : -carry) * 120 + 60 * (Math.floor(hop) % 2),
                fontFamily: C.mono, fontSize: 20, background: C.yellow, color: "#1a1a1a", padding: "8px 14px", borderRadius: 10,
                boxShadow: "0 10px 25px rgba(0,0,0,.5)", transform: `rotate(${carry * 6}deg)`,
              }}>Strg+C → Strg+V</div>
            )}
          </Win>
          <div style={{ textAlign: "center", marginTop: 18, fontFamily: C.sans, fontSize: 28, color: C.dim }}>Code hin und her kopieren</div>
        </Pop>
      </div>
      {/* rechts: Claude Code */}
      <div style={{ position: "absolute", left: 900, top: 250 }}>
        <Pop f={f} at={cc}>
          <Win title="Projektordner — Claude Code" w={910} h={560} glow={ok ? C.green : C.coral}>
            <div style={{ display: "flex", height: 516 }}>
              <div style={{ width: 250, borderRight: `1px solid ${C.line}`, padding: "18px 14px", fontFamily: C.mono, fontSize: 20, lineHeight: 1.9 }}>
                {files.map((fl) => {
                  const hot = fl.includes("kopfsache") && f >= read && f < run + 30;
                  return <div key={fl} style={{ color: hot ? "#111" : C.dim, background: hot ? C.yellow : "transparent", borderRadius: 6, padding: "0 6px", whiteSpace: "pre" }}>{fl}</div>;
                })}
              </div>
              <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
                <div style={{ flex: 1, padding: "18px 20px", fontFamily: C.mono, fontSize: 20, lineHeight: 1.75 }}>
                  {code.map((l, i) => {
                    if (l.add && f < write) return null;
                    const bg = l.del && f >= write ? `rgba(255,93,108,${0.25 * wp})` : l.add ? `rgba(61,220,151,${0.25 * wp})` : "transparent";
                    return (
                      <div key={i} style={{ background: bg, color: l.c, whiteSpace: "pre", textDecoration: l.del && f >= write ? "line-through" : "none", opacity: l.add ? wp : 1 }}>
                        <span style={{ color: "#58607c", marginRight: 14 }}>{l.del && f >= write ? "-" : l.add ? "+" : " "}</span>{l.t}
                      </div>
                    );
                  })}
                </div>
                <div style={{ height: 150, borderTop: `1px solid ${C.line}`, background: "#0b0e1a", padding: "14px 20px", fontFamily: C.mono, fontSize: 21, lineHeight: 1.7 }}>
                  {f >= read && <div style={{ color: C.dim }}>{typed("● Lese kopfsache.html", f, read, 50)}</div>}
                  {f >= run && <div style={{ color: C.text }}>{typed("$ npm test", f, run, 30)}</div>}
                  {ok && <div style={{ color: C.green }}>✓ 12 Tests bestanden</div>}
                </div>
              </div>
            </div>
          </Win>
          <div style={{ display: "flex", justifyContent: "center", gap: 18, marginTop: 18 }}>
            {[["Lesen", "file", read], ["Schreiben", "pencil", write], ["Ausführen", "terminal", run], ["Prüfen", "check", check]].map(([l, ic, t]) => {
              const on = f >= (t as number);
              return (
                <div key={l as string} style={{ display: "flex", alignItems: "center", gap: 10, padding: "8px 18px", borderRadius: 30, fontFamily: C.sans, fontSize: 24, color: on ? "#111" : C.dim, background: on ? C.teal : "rgba(255,255,255,0.05)", transform: `scale(${on ? 1 + 0.08 * (1 - sp(f - (t as number))) : 1})` }}>
                  <Icon name={ic as string} size={24} color={on ? "#111" : C.dim} /> {l as string}
                </div>
              );
            })}
          </div>
        </Pop>
      </div>
    </AbsoluteFill>
  );
};

/* ═══════════════════════ SZENE 3: Die Schleife ═════════════════════ */
const STATIONS = [
  { k: "st1", label: "Verstehen", icon: "bulb" },
  { k: "st2", label: "Lesen", icon: "book" },
  { k: "st3", label: "Planen", icon: "map" },
  { k: "st4", label: "Ändern", icon: "pencil" },
  { k: "st5", label: "Testen", icon: "check" },
];
const Scene3: React.FC<{ f: number }> = ({ f }) => {
  const cx = 960, cy = 540, R = 300;
  const ang = (i: number) => -Math.PI / 2 + (i * 2 * Math.PI) / 5;
  const fail = E("fail"), retry = E("retry"), success = E("success");
  // Position des Punkts auf dem Ring (in Stationen)
  const pos = (() => {
    if (f < E("st1")) return 0;
    if (f < E("st5")) {
      const ts = STATIONS.map((s) => E(s.k));
      return interpolate(f, ts, [0, 1, 2, 3, 4], clamp);
    }
    if (f < retry) return 4;
    return lerp(f, retry, success - 10, 4, 9, Easing.inOut(Easing.quad));
  })();
  const a = -Math.PI / 2 + (pos * 2 * Math.PI) / 5;
  const failed = f >= fail + 6 && f < success - 10;
  const won = f >= success - 10;
  const shake = failed ? Math.sin((f - fail) * 1.3) * 8 * Math.exp(-(f - fail) / 20) : 0;
  const ringProg = Math.min(1, pos / 5);
  return (
    <AbsoluteFill>
      <Heading f={f} at={E("scene3")} kicker="SO ARBEITET CLAUDE CODE" title="Eine Schleife bis es läuft" />
      <svg width={1920} height={1080} style={{ position: "absolute" }}>
        <circle cx={cx} cy={cy + 40} r={R} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth={16} />
        <circle cx={cx} cy={cy + 40} r={R} fill="none" stroke={won ? C.green : C.coral} strokeWidth={16} strokeLinecap="round"
          strokeDasharray={2 * Math.PI * R} strokeDashoffset={2 * Math.PI * R * (1 - (pos >= 5 ? (pos - 5) / 4 : ringProg))}
          transform={`rotate(-90 ${cx} ${cy + 40})`} opacity={0.9} />
        {f >= E("st1") && (
          <g>
            <circle cx={cx + Math.cos(a) * R} cy={cy + 40 + Math.sin(a) * R} r={30} fill={won ? C.green : C.coral} opacity={0.25} />
            <circle cx={cx + Math.cos(a) * R} cy={cy + 40 + Math.sin(a) * R} r={14} fill="#fff" />
          </g>
        )}
      </svg>
      {STATIONS.map((s, i) => {
        const t = E(s.k);
        const p = sp(f - t + 8);
        const x = cx + Math.cos(ang(i)) * R, y = cy + 40 + Math.sin(ang(i)) * R;
        const isTest = i === 4;
        const col = isTest && failed ? C.red : isTest && won ? C.green : f >= t ? C.coral : "#3a4060";
        return (
          <div key={s.k} style={{ position: "absolute", left: x - 85, top: y - 85, width: 170, textAlign: "center", opacity: 0.25 + 0.75 * p, transform: `translateX(${isTest ? shake : 0}px) scale(${0.85 + 0.15 * p})` }}>
            <div style={{ width: 120, height: 120, margin: "0 auto", borderRadius: 60, background: C.panel2, border: `4px solid ${col}`, display: "flex", alignItems: "center", justifyContent: "center", boxShadow: f >= t ? `0 0 40px ${col}66` : "none" }}>
              <Icon name={isTest && failed ? "x" : s.icon} size={52} color={col === "#3a4060" ? C.dim : col} width={2.2} />
            </div>
            <div style={{ fontFamily: C.sans, fontWeight: 700, fontSize: 28, color: C.text, marginTop: 10 }}>{s.label}</div>
          </div>
        );
      })}
      <div style={{ position: "absolute", left: cx - 230, top: cy - 20, width: 460, textAlign: "center", fontFamily: C.sans }}>
        {failed && (
          <Pop f={f} at={fail + 6} from={20}>
            <div style={{ fontSize: 34, fontWeight: 800, color: C.red }}>✗ 1 Test fehlgeschlagen</div>
            {f >= retry && <div style={{ fontSize: 26, color: C.dim, marginTop: 10 }}>Fehler suchen → nochmal</div>}
          </Pop>
        )}
        {won && (
          <Pop f={f} at={success - 10} from={20}>
            <div style={{ fontSize: 46, fontWeight: 900, color: C.green }}>✓ Funktioniert</div>
          </Pop>
        )}
      </div>
      {won && Array.from({ length: 26 }, (_, i) => {
        const t = (f - success + 10) / FPS;
        const an = (i / 26) * Math.PI * 2;
        const v = 380 + (i % 4) * 90;
        return <div key={i} style={{ position: "absolute", left: cx + Math.cos(an) * v * t, top: cy + 40 + Math.sin(an) * v * t + 300 * t * t, width: 12, height: 12, borderRadius: i % 2 ? 6 : 2, background: [C.green, C.yellow, C.coral, C.teal][i % 4], opacity: Math.max(0, 1 - t * 1.1) }} />;
      })}
    </AbsoluteFill>
  );
};

/* ═════════════════════════ SZENE 4: Kontrolle ══════════════════════ */
const Scene4: React.FC<{ f: number }> = ({ f }) => {
  const dialog = E("dialog"), diff = E("diff"), git = E("git"), md = E("claudemd"), rule = E("rule");
  const click = sp(f - dialog - 70, 14);
  const undo = lerp(f, git + 30, git + 70, 0, 1);
  const mdLines = [
    "## Qualitätssicherung",
    "- Auf Fehler prüfen (Logik, Syntax)",
    "- Gefundene Fehler sofort beheben",
    "",
    "### Git Workflow",
    "After completing any meaningful unit",
    "of work, commit and push to GitHub",
    "immediately.",
  ];
  return (
    <AbsoluteFill>
      <Heading f={f} at={E("scene4")} kicker="SICHERHEIT" title="Du behältst die Kontrolle" />
      <div style={{ position: "absolute", top: 330, left: 70, right: 70, display: "flex", gap: 40, justifyContent: "center" }}>
        <Pop f={f} at={dialog}>
          <Win title="Nachfrage" w={560} h={330}>
            <div style={{ padding: "24px 28px", fontFamily: C.sans, color: C.text }}>
              <div style={{ display: "flex", alignItems: "center", gap: 12, fontSize: 27, fontWeight: 700 }}><Icon name="shield" size={34} color={C.yellow} /> Claude möchte ausführen:</div>
              <div style={{ fontFamily: C.mono, fontSize: 22, background: "#0b0e1a", padding: "12px 16px", borderRadius: 10, marginTop: 16, color: C.yellow }}>Datei löschen: alte-version.html</div>
              <div style={{ display: "flex", gap: 16, marginTop: 26 }}>
                <div style={{ flex: 1, textAlign: "center", padding: "12px 0", borderRadius: 12, background: `rgba(61,220,151,${0.2 + 0.6 * click})`, color: click > 0.5 ? "#111" : C.green, fontSize: 24, fontWeight: 700, border: `2px solid ${C.green}`, transform: `scale(${1 - 0.06 * Math.sin(click * Math.PI)})` }}>Erlauben</div>
                <div style={{ flex: 1, textAlign: "center", padding: "12px 0", borderRadius: 12, border: `2px solid ${C.line}`, color: C.dim, fontSize: 24 }}>Ablehnen</div>
              </div>
            </div>
          </Win>
          <div style={{ textAlign: "center", marginTop: 16, fontFamily: C.sans, fontSize: 26, color: C.dim }}>Fragt vor riskanten Aktionen</div>
        </Pop>
        <Pop f={f} at={diff}>
          <Win title="Änderungen" w={560} h={330}>
            <div style={{ padding: "18px 0", fontFamily: C.mono, fontSize: 21, lineHeight: 1.75 }}>
              {[["  const max = 9;", ""], ["- if (!gueltig(z)) return false;", "del"], ["+ if (!gueltig(z)) return melde(z);", "add"], ["  return true;", ""]].map(([t, k], i) => (
                <div key={i} style={{ padding: "0 24px", whiteSpace: "pre", color: k === "del" ? "#ffb3bb" : k === "add" ? "#a8f5cf" : C.dim, background: k === "del" ? "rgba(255,93,108,.16)" : k === "add" ? "rgba(61,220,151,.16)" : "transparent" }}>{t}</div>
              ))}
            </div>
            {f >= git && (
              <div style={{ position: "absolute", left: 24, right: 24, bottom: 22, height: 80, opacity: sp(f - git) }}>
                <svg width={512} height={80}>
                  <line x1={30} y1={40} x2={480} y2={40} stroke="#4a5170" strokeWidth={4} />
                  {[30, 180, 330, 480].map((x, i) => (
                    <circle key={x} cx={x} cy={40} r={13} fill={i === 3 && undo > 0.5 ? C.panel : i === 2 && undo > 0.5 ? C.green : C.violet} stroke={i === 3 ? C.violet : "none"} strokeWidth={3} strokeDasharray={i === 3 && undo > 0.5 ? "4 4" : "none"} />
                  ))}
                  <path d="M 470 20 Q 405 -6 340 20" fill="none" stroke={C.green} strokeWidth={4} strokeDasharray={160} strokeDashoffset={160 * (1 - undo)} markerEnd="" />
                  <text x={256} y={76} textAnchor="middle" fontFamily={C.mono} fontSize={18} fill={C.dim}>git: alles zurückdrehbar</text>
                </svg>
              </div>
            )}
          </Win>
          <div style={{ textAlign: "center", marginTop: 16, fontFamily: C.sans, fontSize: 26, color: C.dim }}>Jede Änderung sichtbar</div>
        </Pop>
        <Pop f={f} at={md}>
          <Win title="CLAUDE.md" w={560} h={330} glow={f >= rule ? C.yellow : undefined}>
            <div style={{ padding: "16px 24px", fontFamily: C.mono, fontSize: 20, lineHeight: 1.6 }}>
              {mdLines.map((l, i) => {
                const hot = i >= 5 && f >= rule;
                return <div key={i} style={{ minHeight: 30, whiteSpace: "pre", color: l.startsWith("#") ? C.coral : hot ? "#111" : C.text, background: hot ? `rgba(255,211,77,${0.9 * sp(f - rule)})` : "transparent", borderRadius: 4 }}>{l}</div>;
              })}
            </div>
          </Win>
          <div style={{ textAlign: "center", marginTop: 16, fontFamily: C.sans, fontSize: 26, color: C.dim }}>Eigene Regeln (Auszug, gekürzt)</div>
        </Pop>
      </div>
    </AbsoluteFill>
  );
};

/* ════════════════════════ SZENE 5: Projekte ════════════════════════ */
const Scene5: React.FC<{ f: number }> = ({ f }) => {
  const kopf = E("kopfsache"), burg = E("burgwacht"), pca = E("pca"), vid = E("video");
  const grid = sp(f - burg + 6, 16);
  // Kopfsache: erst groß (Hero), dann in die Reihe
  const hero = { x: 760, y: 250, w: 980 };
  const cards = [
    { at: kopf, img: "kopfsache.png", label: "Kopfsache", sub: "Denkspiel", gx: 70, gy: 330, gw: 470, rot: -2.5 },
    { at: burg, img: "burgwacht.png", label: "Burgwacht", sub: "Tower Defense", gx: 570, gy: 300, gw: 470, rot: 1.5 },
    { at: pca, img: "pcaufraeumer.png", label: "PC Aufräumer", sub: "Windows-App", gx: 1070, gy: 330, gw: 470, rot: -1.5, ratio: 0.6 },
    { at: vid, img: "kochvideo.png", label: "Dieses Video", sub: "Remotion + KI-Stimme", gx: 1590, gy: 250, gw: 250, rot: 3, ratio: 1920 / 1080 },
  ];
  const checks = [["gebaut", W("gebaut")], ["im Browser getestet", W("getestet")], ["Fehler selbst behoben", W("behoben")]] as const;
  return (
    <AbsoluteFill>
      <Heading f={f} at={E("scene5")} kicker="PRAXIS" title="Was ich damit gebaut habe" />
      {/* Prompt-Blase + Checkliste für Kopfsache */}
      <div style={{ position: "absolute", left: 90, top: 290, width: 600, opacity: 1 - grid }}>
        <Pop f={f} at={kopf - 20}>
          <div style={{ fontFamily: C.sans, fontSize: 22, color: C.dim, marginBottom: 10, display: "flex", alignItems: "center", gap: 10 }}><Icon name="user" size={26} color={C.dim} /> Meine Beschreibung</div>
          <div style={{ background: C.blue, color: "#fff", fontFamily: C.sans, fontSize: 29, lineHeight: 1.4, padding: "20px 26px", borderRadius: "24px 24px 24px 6px", boxShadow: "0 20px 40px rgba(0,0,0,.4)" }}>
            {typed("Ich will ein Denkspiel: Sudoku, Kopfrechnen, Schachrätsel und Form-Puzzle, zufällig gemischt, Level für Level.", f, kopf - 10, 34)}
          </div>
        </Pop>
        <div style={{ marginTop: 34, display: "flex", flexDirection: "column", gap: 14 }}>
          {checks.map(([t, at]) => (
            <Pop key={t} f={f} at={at} from={20}>
              <div style={{ display: "flex", alignItems: "center", gap: 14, fontFamily: C.sans, fontSize: 32, color: C.text }}>
                <div style={{ width: 44, height: 44, borderRadius: 22, background: C.green, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name="check" size={28} color="#0d1020" width={3} /></div>
                {t}
              </div>
            </Pop>
          ))}
        </div>
      </div>
      {cards.map((c, i) => {
        if (f < c.at - 6) return null;
        const p = sp(f - c.at + 6, 15);
        const ratio = c.ratio ?? 900 / 1600;
        const isHero = i === 0;
        const x = isHero ? hero.x + (c.gx - hero.x) * grid : c.gx;
        const y = isHero ? hero.y + (c.gy - hero.y) * grid : c.gy;
        const w = isHero ? hero.w + (c.gw - hero.w) * grid : c.gw;
        const rot = isHero ? c.rot * grid : c.rot;
        return (
          <div key={c.label} style={{ position: "absolute", left: x, top: y + (1 - p) * 120, width: w, opacity: p, transform: `rotate(${rot}deg)` }}>
            <div style={{ borderRadius: 16, overflow: "hidden", border: `1.5px solid ${C.line}`, boxShadow: "0 30px 60px rgba(0,0,0,.55)", background: C.panel }}>
              <div style={{ height: 30, display: "flex", alignItems: "center", gap: 7, padding: "0 12px", background: C.panel2 }}>
                {["#ff5f57", "#febc2e", "#28c840"].map((col) => <div key={col} style={{ width: 10, height: 10, borderRadius: 5, background: col }} />)}
              </div>
              <Img src={staticFile(`claude-code-erklaerung/shots/${c.img}`)} style={{ width: w, height: w * ratio, objectFit: "cover", objectPosition: "top", display: "block" }} />
            </div>
            <div style={{ marginTop: 14, textAlign: "center", fontFamily: C.sans, opacity: isHero ? Math.max(grid, f >= c.at ? 1 : 0) : 1 }}>
              <div style={{ fontSize: 30, fontWeight: 800, color: C.text }}>{c.label}</div>
              <div style={{ fontSize: 22, color: C.dim }}>{c.sub}</div>
            </div>
          </div>
        );
      })}
    </AbsoluteFill>
  );
};

/* ═════════════════════ SZENE 6: Mensch + KI ════════════════════════ */
const Scene6: React.FC<{ f: number }> = ({ f }) => {
  const items = [
    { at: E("describe"), icon: "chat", t: "Beschreiben", s: "klar sagen, was man will", col: C.blue },
    { at: E("verify"), icon: "search", t: "Prüfen", s: "Ergebnisse kontrollieren", col: C.teal },
    { at: E("decide"), icon: "sign", t: "Entscheiden", s: "Richtung vorgeben", col: C.violet },
  ];
  const team = E("team");
  return (
    <AbsoluteFill>
      <Heading f={f} at={E("scene6")} kicker="EHRLICH GESAGT" title="Was man selbst können muss" />
      <div style={{ position: "absolute", top: 330, left: 0, right: 0, display: "flex", justifyContent: "center", gap: 50 }}>
        {items.map((it) => (
          <Pop key={it.t} f={f} at={it.at}>
            <div style={{ width: 430, height: 330, borderRadius: 28, background: `linear-gradient(160deg, ${C.panel2}, ${C.panel})`, border: `1.5px solid ${it.col}88`, boxShadow: `0 30px 60px rgba(0,0,0,.45), 0 0 50px ${it.col}22`, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 18 }}>
              <div style={{ width: 120, height: 120, borderRadius: 60, background: `${it.col}22`, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name={it.icon} size={64} color={it.col} width={2} /></div>
              <div style={{ fontFamily: C.sans, fontWeight: 800, fontSize: 44, color: C.text }}>{it.t}</div>
              <div style={{ fontFamily: C.sans, fontSize: 26, color: C.dim }}>{it.s}</div>
            </div>
          </Pop>
        ))}
      </div>
      <div style={{ position: "absolute", top: 730, left: 0, right: 0, display: "flex", justifyContent: "center", gap: 30 }}>
        <Pop f={f} at={team} from={30}>
          <div style={{ display: "flex", gap: 26, alignItems: "center", fontFamily: C.sans, fontSize: 36, fontWeight: 700 }}>
            <div style={{ padding: "16px 30px", borderRadius: 40, background: `${C.green}22`, border: `2px solid ${C.green}`, color: C.green, display: "flex", gap: 12, alignItems: "center" }}><Icon name="user" size={34} color={C.green} /> Schneller Kollege ✓</div>
            <div style={{ padding: "16px 30px", borderRadius: 40, background: `${C.red}14`, border: `2px solid ${C.red}66`, color: `${C.red}cc`, display: "flex", gap: 12, alignItems: "center", textDecoration: "line-through" }}><Icon name="spark" size={34} color={`${C.red}cc`} /> Zauberknopf</div>
          </div>
        </Pop>
      </div>
    </AbsoluteFill>
  );
};

/* ════════════════════════ SZENE 7: Ausblick ════════════════════════ */
const Scene7: React.FC<{ f: number }> = ({ f }) => {
  const ideas = E("ideas");
  const list = ["Text → animiertes Video", "Highlight Cutter für NVIDIA-Aufnahmen", "Farben-Sortier-Rätsel für Kopfsache"];
  const end = DURATION_IN_FRAMES;
  const outro = lerp(f, end - 110, end - 70, 0, 1);
  return (
    <AbsoluteFill>
      <div style={{ position: "absolute", left: 360, top: 170, opacity: 1 - outro, transform: `scale(${1 - outro * 0.05})` }}>
        <Pop f={f} at={E("scene7")}>
          <Win title="Obsidian — Notizen/Ideen.md" w={1200} h={620} glow={C.violet}>
            <div style={{ display: "flex", height: 576 }}>
              <div style={{ width: 260, borderRight: `1px solid ${C.line}`, padding: 22, fontFamily: C.sans, fontSize: 24, lineHeight: 2, color: C.dim }}>
                <div>Start</div><div>▾ Notizen</div><div style={{ color: C.text, background: `${C.violet}33`, borderRadius: 8, paddingLeft: 10 }}>  Ideen</div><div>  Projekte</div><div>  Vorlagen</div>
              </div>
              <div style={{ flex: 1, padding: "34px 44px", fontFamily: C.sans }}>
                <div style={{ fontSize: 50, fontWeight: 800, color: C.text }}>Ideen</div>
                <div style={{ fontSize: 26, color: C.violet, marginTop: 18 }}>## Tools & Apps</div>
                <div style={{ marginTop: 18, display: "flex", flexDirection: "column", gap: 18 }}>
                  {list.map((t, i) => (
                    <Pop key={t} f={f} at={ideas + i * 14} from={20}>
                      <div style={{ display: "flex", gap: 16, alignItems: "center", fontSize: 32, color: C.text }}>
                        <div style={{ width: 30, height: 30, borderRadius: 7, border: `3px solid ${C.violet}` }} /> {t}
                      </div>
                    </Pop>
                  ))}
                </div>
              </div>
            </div>
          </Win>
        </Pop>
      </div>
      {outro > 0 && (
        <div style={{ position: "absolute", left: 0, right: 0, top: 400, textAlign: "center", opacity: outro, transform: `scale(${0.94 + 0.06 * outro})` }}>
          <div style={{ fontFamily: C.sans, fontWeight: 900, fontSize: 120, color: C.text }}>Claude <span style={{ color: C.coral }}>Code</span></div>
          <div style={{ fontFamily: C.mono, fontSize: 30, letterSpacing: 8, color: C.dim, marginTop: 10 }}>DANKE FÜRS ZUSCHAUEN</div>
        </div>
      )}
    </AbsoluteFill>
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
    if (/[.!?:]$/.test(w.text) || (/,$/.test(w.text) && chars > 22) || cur.length >= 12 || chars > 58) { lines.push(cur); cur = []; }
  }
  if (cur.length) lines.push(cur);
  const last = S(words[words.length - 1].end) + 40;
  return lines.map((l, i) => ({ words: l, from: l[0].at, to: i + 1 < lines.length ? Math.min(lines[i + 1][0].at, S(words.find((w) => S(w.start) === l[l.length - 1].at)!.end) + 50) : last }));
})();
const Captions: React.FC<{ f: number }> = ({ f }) => {
  const line = LINES.find((l) => f >= l.from && f < l.to);
  if (!line) return null;
  const vis = line.words.filter((w) => f >= w.at);
  const cur = vis[vis.length - 1];
  return (
    <div style={{ position: "absolute", left: 160, right: 160, top: 948, display: "flex", flexWrap: "wrap", justifyContent: "center", gap: "6px 10px", fontFamily: C.sans, fontWeight: 800, fontSize: 46 }}>
      {vis.map((w) => {
        const pop = sp(f - w.at, 12, 0.6, 220);
        const active = w === cur;
        return (
          <span key={w.text + w.at} style={{
            display: "inline-block", padding: "1px 12px", borderRadius: 12,
            background: active ? C.yellow : "rgba(0,0,0,0.35)", color: active ? "#141414" : "#fff",
            transform: `scale(${0.75 + 0.25 * pop}) translateY(${(1 - pop) * 10}px)`,
          }}>{w.text}</span>
        );
      })}
    </div>
  );
};

/* ═════════════════════════════ GESAMT ══════════════════════════════ */
const SCENES: { n: number; C: React.FC<{ f: number }> }[] = [
  { n: 1, C: Scene1 }, { n: 2, C: Scene2 }, { n: 3, C: Scene3 }, { n: 4, C: Scene4 },
  { n: 5, C: Scene5 }, { n: 6, C: Scene6 }, { n: 7, C: Scene7 },
];

export const ClaudeCodeErklaerung: React.FC = () => {
  const f = useCurrentFrame();
  const fadeIn = lerp(f, 0, 20, 0, 1);
  const fadeOut = lerp(f, DURATION_IN_FRAMES - 30, DURATION_IN_FRAMES, 1, 0);
  return (
    <AbsoluteFill style={{ backgroundColor: C.bg }}>
      <Audio src={staticFile("claude-code-erklaerung/mix.wav")} />
      <AbsoluteFill style={{ opacity: fadeIn * fadeOut }}>
        <Backdrop f={f} />
        {SCENES.map(({ n, C: Comp }, i) => {
          const start = n === 1 ? 0 : E(`scene${n}`);
          const end = i + 1 < SCENES.length ? E(`scene${SCENES[i + 1].n}`) : DURATION_IN_FRAMES + 30;
          if (f < start - 2 || f > end + 24) return null;
          const inP = n === 1 ? 1 : lerp(f, start, start + 22, 0, 1);
          const outP = lerp(f, end - 4, end + 20, 0, 1);
          const drift = 1 + 0.025 * ((f - start) / Math.max(1, end - start));
          return (
            <AbsoluteFill key={n} style={{
              opacity: inP * (1 - outP),
              transform: `scale(${drift * (0.97 + 0.03 * inP) * (1 + 0.04 * outP)})`,
              filter: outP > 0.01 || inP < 0.99 ? `blur(${(1 - inP) * 10 + outP * 10}px)` : undefined,
            }}>
              <Comp f={f} />
            </AbsoluteFill>
          );
        })}
        <AbsoluteFill style={{ background: "radial-gradient(1400px 900px at 50% 45%, transparent 60%, rgba(0,0,0,.55) 100%)" }} />
        <Captions f={f} />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
