import React from "react";
import { AbsoluteFill } from "remotion";
import type { SzZeitstrahl } from "../../drehbuch/typen";
import { Icon, Kopf, lerp, Pop, sp, T, useSzene } from "../kit";

/* Zeitstrahl: eine Linie wächst von Ereignis zu Ereignis; jedes erscheint bei seinem Wort.
   Quer: waagerecht, Texte abwechselnd oben/unten. Hoch: senkrecht, Texte rechts. */
export const Zeitstrahl: React.FC<{ sz: SzZeitstrahl }> = ({ sz }) => {
  const { f, hoch, bei, W, H } = useSzene();
  const n = sz.ereignisse.length;
  const zeiten = sz.ereignisse.reduce<number[]>((acc, e, i) => {
    const t = bei(e.bei, 24 + i * 26);
    acc.push(i === 0 ? t : Math.max(t, acc[i - 1] + 1));
    return acc;
  }, []);
  // Positionen entlang der Linie
  const von = hoch ? 470 : 200, bis = hoch ? H - 420 : W - 200;
  const pos = (i: number) => von + ((bis - von) * (i + 0.5)) / n;
  // Linie wächst bis zum zuletzt erschienenen Ereignis, am Ende bis zum Rand
  let ende = von;
  zeiten.forEach((t, i) => { ende = Math.max(ende, lerp(f, t - 14, t + 10, i === 0 ? von : pos(i - 1), pos(i))); });
  ende = Math.max(ende, lerp(f, zeiten[n - 1] + 10, zeiten[n - 1] + 50, pos(n - 1), bis));
  const linie = hoch ? W * 0.22 : H * 0.56;

  return (
    <AbsoluteFill style={{ paddingTop: hoch ? 170 : 70 }}>
      <Kopf kicker={sz.kicker} titel={sz.ueberschrift} />
      <svg width={W} height={H} style={{ position: "absolute", left: 0, top: 0 }}>
        {hoch ? (
          <>
            <line x1={linie} y1={von} x2={linie} y2={bis} stroke={T.spur} strokeWidth={10} strokeLinecap="round" />
            <line x1={linie} y1={von} x2={linie} y2={ende} stroke={T.akzent} strokeWidth={10} strokeLinecap="round" />
          </>
        ) : (
          <>
            <line x1={von} y1={linie} x2={bis} y2={linie} stroke={T.spur} strokeWidth={10} strokeLinecap="round" />
            <line x1={von} y1={linie} x2={ende} y2={linie} stroke={T.akzent} strokeWidth={10} strokeLinecap="round" />
          </>
        )}
      </svg>
      {sz.ereignisse.map((e, i) => {
        const t = zeiten[i];
        const p = sp(f - t, 12);
        const da = f >= t;
        const aktiv = da && (i === n - 1 || f < zeiten[i + 1]);
        const x = hoch ? linie : pos(i), y = hoch ? pos(i) : linie;
        const oben = !hoch && i % 2 === 0;
        const groesse = hoch ? 70 : 62;
        return (
          <React.Fragment key={i}>
            {/* Punkt auf der Linie */}
            <div style={{
              position: "absolute", left: x - groesse / 2, top: y - groesse / 2, width: groesse, height: groesse, borderRadius: groesse,
              background: da ? T.akzent : T.bg, border: `5px solid ${da ? T.akzent : T.aus}`, boxSizing: "border-box",
              transform: `scale(${da ? 0.6 + 0.4 * p : 0.6})`,
              boxShadow: aktiv ? `0 0 34px ${T.akzent}` : "none", display: "flex", alignItems: "center", justifyContent: "center",
            }}>
              {e.icon && da && <Icon name={e.icon} size={groesse * 0.5} color={T.bg} width={2.6} />}
            </div>
            {/* Zeitpunkt + Text */}
            <Pop at={t} from={hoch ? 0 : oben ? -30 : 30} style={hoch
              ? { position: "absolute", left: linie + 70, top: y - 62, right: 60 }
              : { position: "absolute", left: x - 200, width: 400, textAlign: "center", ...(oben ? { bottom: H - y + 56 } : { top: y + 56 }) }}>
              <div style={{ fontFamily: T.titel, fontWeight: 900, fontSize: hoch ? 66 : 56, color: aktiv ? T.akzent : T.text, lineHeight: 1.05 }}>{e.zeit}</div>
              <div style={{ fontFamily: T.sans, fontSize: hoch ? 42 : 32, color: T.dim, marginTop: 6, lineHeight: 1.2 }}>{e.text}</div>
            </Pop>
          </React.Fragment>
        );
      })}
    </AbsoluteFill>
  );
};
