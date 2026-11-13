import React from "react";
import { AbsoluteFill } from "remotion";
import type { SzFenster } from "../../drehbuch/typen";
import { Icon, Karte, Kopf, Pop, sp, T, useSzene } from "../kit";

/* Programm-Fenster: Terminal (Befehle werden getippt, Ausgaben erscheinen) oder Chat (Sprechblasen).
   rolle "ich" = Eingabe / eigene Nachricht (wird getippt), "antwort" = Ausgabe / Antwort. */
const TIPP = 1.6; // Bilder pro Zeichen beim Tippen

export const Fenster: React.FC<{ sz: SzFenster }> = ({ sz }) => {
  const { f, hoch, bei } = useSzene();
  const chat = sz.art === "chat";
  // Startzeiten: beim „bei“-Wort, aber nie bevor die Zeile davor fertig getippt ist
  const zeiten = sz.zeilen.reduce<number[]>((acc, z, i) => {
    const frei = i === 0 ? 0 : acc[i - 1] + (sz.zeilen[i - 1].rolle === "ich" ? sz.zeilen[i - 1].text.length * TIPP : 6) + 4;
    acc.push(Math.max(bei(z.bei, 20 + i * 30), frei));
    return acc;
  }, []);
  const cursorAn = Math.floor(f / 18) % 2 === 0;
  const fs = hoch ? 44 : 38;

  return (
    <AbsoluteFill style={{ paddingTop: hoch ? 170 : 70, alignItems: "center" }}>
      <Kopf kicker={sz.kicker} titel={sz.ueberschrift} />
      <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", width: "100%", padding: hoch ? "0 50px 300px" : "0 0 140px" }}>
        <Pop at={4} style={{ width: hoch ? "100%" : 1240 }}>
          <Karte style={{ overflow: "hidden" }}>
            {/* Titelleiste */}
            <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "18px 24px", borderBottom: `1.5px solid ${T.line}`, background: T.spur }}>
              {[T.rot, T.gelb, T.gruen].map((c, i) => <span key={i} style={{ width: 18, height: 18, borderRadius: 9, background: c, opacity: 0.85 }} />)}
              <span style={{ width: 12 }} />
              <Icon name={chat ? "chat" : "terminal"} size={28} color={T.dim} />
              <span style={{ fontFamily: T.mono, fontSize: hoch ? 30 : 24, color: T.dim }}>{sz.titel || (chat ? "Chat" : "Terminal")}</span>
            </div>
            <div style={{ padding: hoch ? "34px 34px" : "30px 40px", minHeight: hoch ? 640 : 400, display: "flex", flexDirection: "column", gap: chat ? 22 : 14 }}>
              {sz.zeilen.map((z, i) => {
                const t = zeiten[i];
                if (f < t) return null;
                const ich = z.rolle === "ich";
                const text = ich ? z.text.slice(0, Math.max(0, Math.floor((f - t) / TIPP))) : z.text;
                const tippt = ich && text.length < z.text.length;
                const letzte = i === sz.zeilen.length - 1 || f < zeiten[i + 1];
                const p = sp(f - t, 14);
                if (chat) {
                  const denkt = !ich && f - t < 36; // Antwort: erst „•••“
                  return (
                    <div key={i} style={{ alignSelf: ich ? "flex-end" : "flex-start", maxWidth: "80%", opacity: Math.min(1, p * 1.5), transform: `translateY(${(1 - p) * 20}px)` }}>
                      <div style={{
                        fontFamily: T.sans, fontSize: fs, lineHeight: 1.3, padding: "16px 24px", borderRadius: 26,
                        borderBottomRightRadius: ich ? 6 : 26, borderBottomLeftRadius: ich ? 26 : 6,
                        background: ich ? T.akzent : T.panel2, color: ich ? "#fff" : T.text, border: ich ? "none" : `1.5px solid ${T.line}`,
                      }}>
                        {denkt ? <span style={{ letterSpacing: 6, color: T.dim }}>{"•••".slice(0, 1 + (Math.floor((f - t) / 8) % 3))}</span> : text}
                        {tippt && cursorAn && <span style={{ opacity: 0.7 }}>|</span>}
                      </div>
                    </div>
                  );
                }
                return (
                  <div key={i} style={{ fontFamily: T.mono, fontSize: fs, lineHeight: 1.35, color: ich ? T.text : T.gruen, whiteSpace: "pre-wrap", wordBreak: "break-word", opacity: ich ? 1 : Math.min(1, p * 1.5) }}>
                    {ich && <span style={{ color: T.akzent }}>{"> "}</span>}
                    {text}
                    {letzte && ich && (
                      <span style={{ display: "inline-block", width: fs * 0.55, height: fs, marginLeft: 4, verticalAlign: "text-bottom", background: tippt || cursorAn ? T.text : "transparent" }} />
                    )}
                  </div>
                );
              })}
            </div>
          </Karte>
        </Pop>
      </div>
    </AbsoluteFill>
  );
};
