import React, { useEffect, useRef, useState } from "react";
import { STIMMEN, STIMMUNGEN, type Drehbuch, type Format, type Stimmung } from "../drehbuch/typen";
import { api } from "./api";
import { THEMEN, themaVon, type ThemaId } from "../video/kit";

// Farbmuster für die Themen-Karten
const MUSTER: Record<ThemaId, string[]> = {
  dunkel: ["#0d1020", "#ff7a59", "#4fd1ff", "#8b7bff"],
  tafel: ["#1c3328", "#f5f2e6", "#ffb066", "#8fd8ff"],
  papier: ["#f3eee3", "#29241f", "#e0553a", "#1b8cc8"],
  kueche: ["#24160f", "#ff9a3c", "#ffd166", "#7fd6c4"],
};

/* Einstellungen: Titel, Format, Sprecher (mit Probehören), Tempo, Musik. */

const BESCHREIBUNG: Record<string, string> = {
  ava: "weiblich · klingt am natürlichsten",
  seraphina: "weiblich · ruhig, deutsch",
  florian: "männlich · freundlich, deutsch",
  conrad: "männlich · klar, klassisch",
  katja: "weiblich · klar, klassisch",
};

export const Einstellungen: React.FC<{ drehbuch: Drehbuch; setze: (d: Drehbuch) => void }> = ({ drehbuch, setze }) => {
  const [laedt, setLaedt] = useState<string | null>(null);
  const [fehler, setFehler] = useState("");
  const audio = useRef<HTMLAudioElement | null>(null);
  const stimme = drehbuch.stimme ?? "ava";
  const tempo = drehbuch.tempo ?? 0;
  const stimmung: Stimmung = drehbuch.stimmung ?? "ruhig";
  const [eigene, setEigene] = useState<{ ordner: string; eigene: Record<string, number> } | null>(null);
  useEffect(() => { api.musik().then(setEigene).catch(() => {}); }, []);

  const musikProbe = async () => {
    setFehler("");
    setLaedt("musik");
    try {
      const { url } = await api.musikprobe(stimmung);
      audio.current?.pause();
      audio.current = new Audio(url);
      await audio.current.play();
    } catch (e) {
      setFehler((e as Error).message);
    } finally {
      setLaedt(null);
    }
  };

  const probe = async (key: string) => {
    setFehler("");
    setLaedt(key);
    try {
      const { url } = await api.stimmprobe(key, tempo);
      audio.current?.pause();
      audio.current = new Audio(url);
      await audio.current.play();
    } catch (e) {
      setFehler((e as Error).message);
    } finally {
      setLaedt(null);
    }
  };

  return (
    <div className="einstellungen">
      <section className="card">
        <div className="card-head"><h2>Video</h2></div>
        <div className="felder">
          <label className="feld breit"><span>Titel</span>
            <input value={drehbuch.titel} maxLength={60} onChange={(e) => setze({ ...drehbuch, titel: e.target.value })} />
          </label>
          <label className="feld"><span>Format</span>
            <select value={drehbuch.format} onChange={(e) => setze({ ...drehbuch, format: e.target.value as Format })}>
              <option value="quer">Quer 16:9 (YouTube)</option>
              <option value="hoch">Hoch 9:16 (TikTok, Reels)</option>
            </select>
          </label>
        </div>
      </section>

      <section className="card">
        <div className="card-head"><h2>Design</h2></div>
        <div className="themen">
          {(Object.keys(THEMEN) as ThemaId[]).map((id) => (
            <div key={id} className={`thema-karte ${themaVon(drehbuch.thema) === id ? "an" : ""}`} onClick={() => setze({ ...drehbuch, thema: id })}>
              <div className="muster" style={{ background: MUSTER[id][0] }}>
                {MUSTER[id].slice(1).map((c) => <span key={c} style={{ background: c }} />)}
              </div>
              <div className="stimme-name">{THEMEN[id].name}</div>
              <div className="stimme-info">{THEMEN[id].info}</div>
            </div>
          ))}
        </div>
        <div className="muted hint-line">Das Design wirkt sofort in der Vorschau – die Stimme muss dafür nicht neu erzeugt werden.</div>
      </section>

      <section className="card">
        <div className="card-head"><h2>Sprecher</h2></div>
        <div className="stimmen">
          {Object.entries(STIMMEN).map(([key, s]) => (
            <div key={key} className={`stimme ${key === stimme ? "an" : ""}`} onClick={() => setze({ ...drehbuch, stimme: key })}>
              <div className="stimme-name">{s.name}{key === "ava" ? " ★" : ""}</div>
              <div className="stimme-info">{BESCHREIBUNG[key]}</div>
              <button className="mini-btn" onClick={(e) => { e.stopPropagation(); probe(key); }} disabled={laedt !== null}>
                {laedt === key ? "lädt …" : "▶ Probe"}
              </button>
            </div>
          ))}
        </div>
        {fehler && <div className="err">{fehler}</div>}
        <div className="felder" style={{ marginTop: 16 }}>
          <label className="feld breit"><span>Grundtempo: {tempo > 0 ? `+${tempo}` : tempo} %</span>
            <input type="range" min={-15} max={10} value={tempo} onChange={(e) => setze({ ...drehbuch, tempo: Number(e.target.value) })} />
          </label>
          <label className="feld"><span>Hintergrundmusik</span>
            <select value={drehbuch.musik === false ? "aus" : stimmung}
              onChange={(e) => setze(e.target.value === "aus" ? { ...drehbuch, musik: false } : { ...drehbuch, musik: true, stimmung: e.target.value as Stimmung })}>
              {(Object.keys(STIMMUNGEN) as Stimmung[]).map((s) => (
                <option key={s} value={s}>{STIMMUNGEN[s]}{eigene?.eigene[s] ? ` (${eigene.eigene[s]} eigene Datei${eigene.eigene[s] > 1 ? "en" : ""})` : ""}</option>
              ))}
              <option value="aus">aus</option>
            </select>
          </label>
          {drehbuch.musik !== false && (
            <button className="mini-btn" style={{ alignSelf: "flex-end", marginBottom: 6 }} onClick={musikProbe} disabled={laedt !== null}>
              {laedt === "musik" ? "lädt …" : "▶ Musik"}
            </button>
          )}
        </div>
        {drehbuch.musik !== false && (
          <div className="muted hint-line">
            Musik wird unter der Stimme automatisch leiser. Eigene lizenzfreie Musik: Dateien in <code>{eigene?.ordner ?? "musik"}\{stimmung}</code> legen (Anleitung: <code>musik/LIESMICH.txt</code>).
          </div>
        )}
        <div className="muted hint-line">Änderungen an Sprecher, Tempo oder Musik brauchen danach „Stimme erzeugen“ unter Vorschau. Die Hörprobe nutzt das eingestellte Tempo.</div>
      </section>
    </div>
  );
};
