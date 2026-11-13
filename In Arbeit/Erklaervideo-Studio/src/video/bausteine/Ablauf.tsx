import React from "react";
import { AbsoluteFill, Easing, interpolate } from "remotion";
import type { SzAblauf } from "../../drehbuch/typen";
import { clamp, FPS, Icon, Kopf, lerp, Pop, sp, T, useSzene } from "../kit";

/* Stationen im Kreis (Schleife) oder als Kette. Optional: Fehler bei der letzten Station → Extrarunde → Erfolg. */
export const Ablauf: React.FC<{ sz: SzAblauf }> = ({ sz }) => {
  const { f, hoch, bei, W, H } = useSzene();
  const n = sz.schritte.length;
  // streng steigend (interpolate verlangt das), auch wenn zwei Schritte auf dasselbe Wort zeigen
  const zeiten = sz.schritte.reduce<number[]>((acc, s, i) => {
    const t = bei(s.bei, 24 + i * 22);
    acc.push(i === 0 ? t : Math.max(t, acc[i - 1] + 1));
    return acc;
  }, []);
  const fehler = sz.fehler ? bei(sz.fehler.bei, zeiten[n - 1] + 60) : Infinity;
  const erfolg = sz.erfolg ? bei(sz.erfolg.bei, (isFinite(fehler) ? fehler : zeiten[n - 1]) + 90) : Infinity;
  const kaputt = f >= fehler + 6 && f < erfolg - 10;
  const gut = f >= erfolg - 10;
  // Fortschritt in „Stationen“ (0 … n-1), nach Fehler eine Extrarunde
  const pos = f < zeiten[0] ? 0
    : f < zeiten[n - 1] ? interpolate(f, zeiten, zeiten.map((_, i) => i), clamp)
    : !isFinite(fehler) || f < fehler + 20 ? n - 1
    : lerp(f, fehler + 20, Math.max(fehler + 40, erfolg - 10), n - 1, 2 * n - 1, Easing.inOut(Easing.quad));
  const farbeAktiv = gut ? T.gruen : T.akzent;
  const kreis = (sz.form ?? "kreis") === "kreis";

  // Positionen der Stationen
  const cx = W / 2, cy = hoch ? H * 0.47 : H * 0.53, R = hoch ? 330 : 245;
  const punkte = sz.schritte.map((_, i) => {
    if (kreis) {
      const a = -Math.PI / 2 + (i * 2 * Math.PI) / n;
      return { x: cx + Math.cos(a) * R, y: cy + Math.sin(a) * R };
    }
    return hoch
      ? { x: cx, y: 520 + (i * (H - 1000)) / Math.max(1, n - 1) }
      : { x: 260 + (i * (W - 520)) / Math.max(1, n - 1), y: cy };
  });
  const punktAuf = (p: number) => {
    if (kreis) {
      const a = -Math.PI / 2 + (p * 2 * Math.PI) / n;
      return { x: cx + Math.cos(a) * R, y: cy + Math.sin(a) * R };
    }
    const q = Math.min(n - 1, p % n), i = Math.floor(q), t = q - i;
    const A = punkte[i], B = punkte[Math.min(n - 1, i + 1)];
    return { x: A.x + (B.x - A.x) * t, y: A.y + (B.y - A.y) * t };
  };
  const dot = punktAuf(pos);
  const ringAnteil = pos >= n ? (pos - n) / (n - 1 || 1) : pos / n;
  const shake = kaputt ? Math.sin((f - fehler) * 1.3) * 8 * Math.exp(-(f - fehler) / 20) : 0;
  const kreisU = 2 * Math.PI * R;
  const kette = punkte.length > 1 ? `M ${punkte.map((p) => `${p.x} ${p.y}`).join(" L ")}` : "";
  const ketteLaenge = punkte.slice(1).reduce((s, p, i) => s + Math.hypot(p.x - punkte[i].x, p.y - punkte[i].y), 0);

  return (
    <AbsoluteFill style={{ paddingTop: hoch ? 170 : 70 }}>
      <Kopf kicker={sz.kicker} titel={sz.ueberschrift} />
      <svg width={W} height={H} style={{ position: "absolute", left: 0, top: 0 }}>
        {kreis ? (
          <>
            <circle cx={cx} cy={cy} r={R} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth={16} />
            <circle cx={cx} cy={cy} r={R} fill="none" stroke={farbeAktiv} strokeWidth={16} strokeLinecap="round"
              strokeDasharray={kreisU} strokeDashoffset={kreisU * (1 - Math.min(1, ringAnteil))} transform={`rotate(-90 ${cx} ${cy})`} />
          </>
        ) : (
          <>
            <path d={kette} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth={14} strokeLinecap="round" />
            <path d={kette} fill="none" stroke={farbeAktiv} strokeWidth={14} strokeLinecap="round"
              strokeDasharray={ketteLaenge} strokeDashoffset={ketteLaenge * (1 - Math.min(1, pos / (n - 1 || 1)))} />
          </>
        )}
        {f >= zeiten[0] && (
          <g>
            <circle cx={dot.x} cy={dot.y} r={30} fill={farbeAktiv} opacity={0.25} />
            <circle cx={dot.x} cy={dot.y} r={14} fill="#fff" />
          </g>
        )}
      </svg>
      {sz.schritte.map((s, i) => {
        const t = zeiten[i];
        const p = sp(f - t + 8);
        const letzte = i === n - 1;
        const col = letzte && kaputt ? T.rot : letzte && gut ? T.gruen : f >= t ? T.akzent : "#3a4060";
        const icon = letzte && kaputt ? "kreuz" : s.icon;
        const seitlich = !kreis && hoch;
        return (
          <div key={i} style={{
            position: "absolute", left: punkte[i].x - (seitlich ? 70 : 100), top: punkte[i].y - 70,
            width: seitlich ? 700 : 200, display: "flex", flexDirection: seitlich ? "row" : "column", alignItems: "center", gap: seitlich ? 30 : 10,
            opacity: 0.25 + 0.75 * p, transform: `translateX(${letzte ? shake : 0}px) scale(${0.85 + 0.15 * p})`,
          }}>
            <div style={{
              width: 140, height: 140, borderRadius: 70, background: T.panel2, border: `5px solid ${col}`, flexShrink: 0,
              display: "flex", alignItems: "center", justifyContent: "center", boxShadow: f >= t ? `0 0 40px ${col}66` : "none",
            }}>
              <Icon name={icon} size={64} color={col === "#3a4060" ? T.dim : col} width={2.2} />
            </div>
            <div style={{ fontFamily: T.sans, fontWeight: 700, fontSize: hoch ? 42 : 32, color: T.text, textAlign: seitlich ? "left" : "center" }}>{s.text}</div>
          </div>
        );
      })}
      <div style={{ position: "absolute", left: cx - 300, width: 600, top: kreis ? cy - 40 : hoch ? H - 420 : cy + 150, textAlign: "center", fontFamily: T.sans }}>
        {kaputt && sz.fehler && <Pop at={fehler + 6} from={20}><div style={{ fontSize: hoch ? 46 : 36, fontWeight: 800, color: T.rot }}>✗ {sz.fehler.text}</div></Pop>}
        {gut && sz.erfolg && <Pop at={erfolg - 10} from={20}><div style={{ fontSize: hoch ? 60 : 48, fontWeight: 900, color: T.gruen }}>✓ {sz.erfolg.text}</div></Pop>}
      </div>
      {gut && Array.from({ length: 26 }, (_, i) => {
        const t = (f - erfolg + 10) / FPS;
        const an = (i / 26) * Math.PI * 2, v = 380 + (i % 4) * 90;
        return <div key={i} style={{ position: "absolute", left: cx + Math.cos(an) * v * t, top: cy + Math.sin(an) * v * t + 300 * t * t, width: 12, height: 12, borderRadius: i % 2 ? 6 : 2, background: [T.gruen, T.gelb, T.akzent, T.teal][i % 4], opacity: Math.max(0, 1 - t * 1.1) }} />;
      })}
    </AbsoluteFill>
  );
};
