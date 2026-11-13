import React from "react";
import { schaetzeTiming } from "../drehbuch/pruefen";
import type { Drehbuch, Timing } from "../drehbuch/typen";
import { STIMMEN } from "../drehbuch/typen";
import { api, dateiUrl, type Auftrag, type Eintrag } from "./api";

/* Schritt 5: Video rendern (MP4 + Cover), Fortschritt, Abbrechen, Ergebnis ansehen und herunterladen. */

const mb = (b: number) => `${(b / 1024 / 1024).toFixed(1)} MB`;
const zeit = (s: number) => `${Math.floor(s / 60)}:${String(Math.round(s % 60)).padStart(2, "0")}`;

export const Rendern: React.FC<{
  eintrag: Eintrag;
  drehbuch: Drehbuch;
  timing: Timing | null;
  geaendert: boolean;
  fehler: number;
  tonPasst: boolean;
  auftrag: Auftrag | null;
  andererLaeuft: string | null; // Name eines anderen Projekts, das gerade gerendert wird
  starte: (ohneTon: boolean) => void;
  abbrechen: () => void;
  zurVorschau: () => void;
}> = ({ eintrag, drehbuch, timing, geaendert, fehler, tonPasst, auftrag, andererLaeuft, starte, abbrechen, zurVorschau }) => {
  const laeuft = !!auftrag && !auftrag.fertig;
  const dauer = (timing ?? schaetzeTiming(drehbuch)).dauer;
  const v = eintrag.quelle === "projekt" ? eintrag.video : null;
  const beispiel = eintrag.quelle === "beispiel";

  return (
    <section className="card rendern">
      <div className="card-head">
        <h2>Video rendern</h2>
        {v && !laeuft && <span className={`badge ${v.veraltet || geaendert ? "" : "ok"}`}>{v.veraltet || geaendert ? "Video ist älter als das Drehbuch" : "Video ist aktuell"}</span>}
      </div>

      <div className="render-info">
        <div><span>Format</span><b>{drehbuch.format === "hoch" ? "Hoch 1080×1920" : "Quer 1920×1080"}</b></div>
        <div><span>Länge</span><b>{zeit(dauer)}{tonPasst ? "" : " (geschätzt)"}</b></div>
        <div><span>Sprecher</span><b>{STIMMEN[drehbuch.stimme ?? "ava"]?.name ?? drehbuch.stimme}{tonPasst ? "" : " – fehlt"}</b></div>
        <div><span>Qualität</span><b>60 fps · MP4</b></div>
      </div>

      {fehler > 0 && <div className="err"><b>Das Drehbuch hat noch {fehler} Fehler</b> – im Schritt „Drehbuch“ beheben.</div>}
      {fehler === 0 && !tonPasst && !laeuft && (
        <div className="hinweis">
          <span>Es gibt noch keine passende Stimme. Ohne Stimme wird das Video stumm (Zeiten geschätzt).</span>
          <button className="primary klein" onClick={zurVorschau}>Stimme erzeugen</button>
        </div>
      )}
      {(beispiel || geaendert) && !laeuft && fehler === 0 && (
        <div className="muted hint-line" style={{ marginBottom: 12 }}>
          {beispiel ? "Das Beispiel wird beim Rendern als eigenes Projekt gespeichert." : "Ungespeicherte Änderungen werden vor dem Rendern gespeichert."}
        </div>
      )}

      {andererLaeuft !== null && <div className="hinweis">Gerade wird „{andererLaeuft}“ gerendert. Bitte warten, bis es fertig ist.</div>}
      <div className="render-knoepfe">
        {!laeuft && andererLaeuft === null && (
          <>
            <button className="primary" disabled={fehler > 0 || !tonPasst} onClick={() => starte(false)}>
              {v ? "Neu rendern" : "Video rendern"}
            </button>
            {!tonPasst && <button className="ghost" disabled={fehler > 0} onClick={() => starte(true)}>Ohne Stimme rendern</button>}
          </>
        )}
        {laeuft && auftrag?.abbrechbar && <button className="ghost" onClick={abbrechen}>Abbrechen</button>}
      </div>

      {auftrag && (
        <div className={`status ${auftrag.fehler ? "bad" : auftrag.fertig && !auftrag.abgebrochen ? "ok" : ""}`}>
          {!auftrag.fertig && <span className="spinner" />}
          <span>{auftrag.status}</span>
          {!auftrag.fertig && auftrag.fortschritt !== undefined && <b style={{ marginLeft: "auto" }}>{Math.round(auftrag.fortschritt * 100)} %</b>}
          {!auftrag.fertig && auftrag.fortschritt !== undefined && <div className="balken"><div style={{ width: `${Math.round(auftrag.fortschritt * 100)}%` }} /></div>}
          {auftrag.fehler && <ul>{auftrag.fehler.map((f) => <li key={f}>{f}</li>)}</ul>}
        </div>
      )}
      {laeuft && <div className="muted hint-line">Du kannst währenddessen in den anderen Schritten weiterarbeiten – das Rendern läuft im Hintergrund weiter.</div>}

      {v && !laeuft && (
        <div className="ergebnis">
          <video key={v.zeit} controls src={dateiUrl(eintrag.name, "video", v.zeit)} poster={v.cover ? dateiUrl(eintrag.name, "cover", v.zeit) : undefined} />
          <div className="cover">
            {v.cover && <img src={dateiUrl(eintrag.name, "cover", v.zeit)} alt="Cover-Bild" />}
            <a className="primary klein" href={dateiUrl(eintrag.name, "video", v.zeit, true)}>MP4 herunterladen ({mb(v.bytes)})</a>
            {v.cover && <a className="ghost" href={dateiUrl(eintrag.name, "cover", v.zeit, true)}>Cover-Bild herunterladen</a>}
            <button className="ghost" onClick={() => api.zeigen(eintrag.name)}>Im Ordner zeigen</button>
            <div className="muted hint-line">Gerendert am {new Date(v.zeit).toLocaleString("de-DE", { dateStyle: "short", timeStyle: "short" })}</div>
          </div>
        </div>
      )}
    </section>
  );
};
