import React, { useRef, useState } from "react";
import { STIMMEN, type Drehbuch, type Format } from "../drehbuch/typen";
import { api } from "./api";

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
            <select value={drehbuch.musik === false ? "aus" : "an"} onChange={(e) => setze({ ...drehbuch, musik: e.target.value === "an" })}>
              <option value="an">an (wird unter der Stimme leiser)</option>
              <option value="aus">aus</option>
            </select>
          </label>
        </div>
        <div className="muted hint-line">Änderungen an Sprecher, Tempo oder Musik brauchen danach „Stimme erzeugen“ unter Vorschau. Die Hörprobe nutzt das eingestellte Tempo.</div>
      </section>
    </div>
  );
};
