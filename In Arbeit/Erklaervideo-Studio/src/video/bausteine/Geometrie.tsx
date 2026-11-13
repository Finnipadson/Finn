import React from "react";
import { AbsoluteFill } from "remotion";
import type { SzGeometrie } from "../../drehbuch/typen";
import { Kopf, lerp, sp, T, useSzene } from "../kit";

/* Rechtwinkliges Dreieck (Katheten a senkrecht, b waagerecht) mit Quadraten auf allen Seiten. */
export const Geometrie: React.FC<{ sz: SzGeometrie }> = ({ sz }) => {
  const { f, hoch, bei, W, H } = useSzene();
  const { a, b } = sz;
  const c = Math.hypot(a, b);
  const t = {
    dreieck: bei(sz.dreieck?.bei, 10),
    katheten: bei(sz.katheten?.bei, Infinity),
    hypotenuse: bei(sz.hypotenuse?.bei, Infinity),
    quadrate: bei(sz.quadrate?.bei, Infinity),
    raster: bei(sz.raster?.bei, Infinity),
    werte: bei(sz.werte?.bei, Infinity),
  };
  // Platz: x von -a bis b+a, y von -b bis a+b (in Einheiten)
  const boxW = hoch ? 960 : 1100, boxH = hoch ? 1080 : 760;
  const U = Math.min(boxW / (2 * a + b), boxH / (a + 2 * b));
  const top = hoch ? 420 : 210;
  const x0 = (W - (2 * a + b) * U) / 2 + a * U; // Bildschirm-x des rechten Winkels
  const y0 = top + (a + b) * U;                  // Bildschirm-y des rechten Winkels
  const P = (x: number, y: number) => [x0 + x * U, y0 - y * U] as const;
  const [Ox, Oy] = P(0, 0), [Ax, Ay] = P(0, a), [Bx, By] = P(b, 0);
  const winkel = (Math.atan2(By - Ay, Bx - Ax) * 180) / Math.PI;

  const draw = lerp(f, t.dreieck, t.dreieck + 30, 0, 1);
  const legs = lerp(f, t.katheten, t.katheten + 10, 0, 1);
  const hyp = lerp(f, t.hypotenuse, t.hypotenuse + 10, 0, 1);
  const g = (d: number) => (isFinite(t.quadrate) ? sp(f - t.quadrate - d, 14) : 0);
  const sa = g(0), sb = g(8), sc = g(16);
  const rast = lerp(f, t.raster, t.raster + 20, 0, 1);
  const werte = f >= t.werte;
  const fmt = (n: number) => (Math.round(n * 100) / 100).toString().replace(".", ",");
  const lbl = { a: sz.beschriftung?.a ?? "a", b: sz.beschriftung?.b ?? "b", c: sz.beschriftung?.c ?? "c" };
  const total = (a + b + c) * U;
  const Raster: React.FC<{ n: number; size: number; col: string }> = ({ n, size, col }) => (
    <g opacity={rast}>
      {Number.isInteger(n) && n <= 12 && Array.from({ length: n - 1 }, (_, i) => {
        const p = ((i + 1) * size) / n;
        return <g key={i}><line x1={p} y1={0} x2={p} y2={size * rast} stroke={col} strokeWidth={3} opacity={0.7} /><line x1={0} y1={p} x2={size * rast} y2={p} stroke={col} strokeWidth={3} opacity={0.7} /></g>;
      })}
    </g>
  );
  const zahl = (x: number, y: number, txt: string, col: string) => (
    <g transform={`translate(${x} ${y}) scale(${sp(f - t.werte, 10)})`}>
      <circle r={Math.max(46, U * 0.62)} fill={T.bg} stroke={col} strokeWidth={5} />
      <text y={Math.max(16, U * 0.22)} textAnchor="middle" fontFamily={T.sans} fontWeight={900} fontSize={Math.max(44, U * 0.62)} fill={T.text}>{txt}</text>
    </g>
  );
  const fs = Math.max(40, U * 0.5);
  // c-Beschriftung: von der Hypotenusen-Mitte ein Stück Richtung rechter Winkel
  const mx = (Ax + Bx) / 2, my = (Ay + By) / 2;
  const il = Math.hypot(Ox - mx, Oy - my) || 1;
  const cLx = mx + ((Ox - mx) / il) * fs * 0.9, cLy = my + ((Oy - my) / il) * fs * 0.9 + fs * 0.35;
  return (
    <AbsoluteFill style={{ paddingTop: hoch ? 170 : 70 }}>
      <Kopf kicker={sz.kicker} titel={sz.ueberschrift} />
      <svg width={W} height={H} style={{ position: "absolute", left: 0, top: 0 }}>
        {/* Quadrate */}
        <g transform={`translate(${Ox} ${Ay}) scale(${-sa} 1)`}>
          <rect width={a * U} height={a * U} fill={T.a} fillOpacity={0.22} stroke={T.a} strokeWidth={5} />
          <Raster n={a} size={a * U} col={T.a} />
        </g>
        <g transform={`translate(${Ox} ${Oy}) scale(1 ${sb})`}>
          <rect width={b * U} height={b * U} fill={T.b} fillOpacity={0.22} stroke={T.b} strokeWidth={5} />
          <Raster n={b} size={b * U} col={T.b} />
        </g>
        <g transform={`translate(${Ax} ${Ay}) rotate(${winkel}) scale(1 ${-sc})`}>
          <rect width={c * U} height={c * U} fill={T.c} fillOpacity={0.22} stroke={T.c} strokeWidth={5} />
          <Raster n={c} size={c * U} col={T.c} />
        </g>
        {/* Dreieck */}
        <path d={`M ${Ox} ${Oy} L ${Bx} ${By} L ${Ax} ${Ay} Z`} fill="#fff" fillOpacity={0.05 * draw} stroke={T.text} strokeWidth={6}
          strokeLinejoin="round" strokeDasharray={total} strokeDashoffset={total * (1 - draw)} />
        <line x1={Ox} y1={Oy} x2={Ax} y2={Ay} stroke={T.a} strokeWidth={6 + 6 * legs} strokeLinecap="round" opacity={legs} />
        <line x1={Ox} y1={Oy} x2={Bx} y2={By} stroke={T.b} strokeWidth={6 + 6 * legs} strokeLinecap="round" opacity={legs} />
        <line x1={Ax} y1={Ay} x2={Bx} y2={By} stroke={T.c} strokeWidth={6 + 6 * hyp} strokeLinecap="round" opacity={hyp} />
        <g opacity={lerp(f, t.dreieck + 25, t.dreieck + 35, 0, 1)}>
          <path d={`M ${Ox} ${Oy - 34} L ${Ox + 34} ${Oy - 34} L ${Ox + 34} ${Oy}`} fill="none" stroke={T.text} strokeWidth={4} />
          <circle cx={Ox + 17} cy={Oy - 17} r={4} fill={T.text} />
        </g>
        {/* Beschriftungen */}
        {f >= t.katheten && (
          <>
            <text x={Ox + 18} y={(Oy + Ay) / 2 + fs * 0.35} fontFamily={T.sans} fontWeight={800} fontSize={fs} fill={T.a}>{werte ? `${lbl.a}=${fmt(a)}` : lbl.a}</text>
            <text x={(Ox + Bx) / 2} y={Oy - 16} textAnchor="middle" fontFamily={T.sans} fontWeight={800} fontSize={fs} fill={T.b}>{werte ? `${lbl.b}=${fmt(b)}` : lbl.b}</text>
          </>
        )}
        {f >= t.hypotenuse && (
          <text x={cLx} y={cLy} textAnchor="middle" fontFamily={T.sans} fontWeight={800} fontSize={fs} fill={werte ? T.gruen : T.c}>
            {werte ? `${lbl.c}=${fmt(c)}` : lbl.c}
          </text>
        )}
        {werte && isFinite(t.quadrate) && (
          <>
            {zahl(Ox - (a * U) / 2, Ay + (a * U) / 2, fmt(a * a), T.a)}
            {zahl(Ox + (b * U) / 2, Oy + (b * U) / 2, fmt(b * b), T.b)}
            {zahl((Ax + Bx) / 2 + (c * U / 2) * (a / c), (Ay + By) / 2 - (c * U / 2) * (b / c), fmt(c * c), T.c)}
          </>
        )}
      </svg>
    </AbsoluteFill>
  );
};
