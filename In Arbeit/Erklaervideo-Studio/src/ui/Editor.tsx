import React, { useMemo, useRef, useState } from "react";
import type { PlayerRef } from "@remotion/player";
import type { Drehbuch, Farbe, Satz, Seite, Szene } from "../drehbuch/typen";
import { beiOptionen, pruefeDrehbuch, schaetzeTiming } from "../drehbuch/pruefen";
import { ICON_NAMEN } from "../video/kit";
import { Auswahl, Bei, Feld, Liste, Text, Zahl } from "./Felder";
import { neueSzene, TYP_NAMEN } from "./szenenVorlagen";
import { VorschauPlayer } from "./VorschauPlayer";

/* Drehbuch-Editor: Szenenliste | Formular der Szene | Live-Vorschau. */

const FARBEN: Farbe[] = ["a", "b", "c", "akzent", "text", "gruen", "rot", "blau", "lila"];
const ICONS = ICON_NAMEN.map((n) => n);

const SprecherEditor: React.FC<{ saetze: Satz[]; setze: (s: Satz[]) => void }> = ({ saetze, setze }) => (
  <Liste titel="Sprechertext" eintraege={saetze} setze={setze} min={1} max={10}
    neu={() => ({ satz: "Neuer Satz.", pause: 0.35 })}
    render={(s, setzeS) => (
      <div className="satz">
        <textarea rows={2} value={s.satz} onChange={(e) => setzeS({ ...s, satz: e.target.value })} />
        <div className="satz-opt">
          <label title="Pause nach dem Satz in Sekunden">Pause <Zahl wert={s.pause ?? 0.35} schritt={0.05} min={0} max={2} setze={(v) => setzeS({ ...s, pause: v })} /></label>
          <label title="Tempo dieses Satzes in Prozent (zusätzlich zum Grundtempo)">Tempo <Zahl wert={s.tempo ?? 0} min={-30} max={30} setze={(v) => setzeS({ ...s, tempo: v || undefined })} /></label>
        </div>
      </div>
    )} />
);

const SeitenEditor: React.FC<{ s: Seite; setze: (s: Seite) => void; w: string[]; titel: string }> = ({ s, setze, w, titel }) => (
  <div className="gruppe">
    <div className="gruppe-titel">{titel}</div>
    <div className="felder">
      <Feld label="Titel"><Text wert={s.titel} setze={(v) => setze({ ...s, titel: v })} /></Feld>
      <Feld label="Icon"><Auswahl wert={s.icon} setze={(v) => setze({ ...s, icon: v || undefined })} optionen={ICONS} leer="(Standard)" /></Feld>
      <Feld label="erscheint bei"><Bei wert={s.bei} setze={(v) => setze({ ...s, bei: v })} woerter={w} /></Feld>
    </div>
    <Liste titel="Punkte" eintraege={s.punkte} setze={(p) => setze({ ...s, punkte: p })} min={1} max={4} neu={() => ({ text: "Neuer Punkt" })}
      render={(p, sp) => (
        <div className="felder">
          <Feld label="Text" breit><Text wert={p.text} setze={(v) => sp({ ...p, text: v })} /></Feld>
          <Feld label="bei"><Bei wert={p.bei} setze={(v) => sp({ ...p, bei: v })} woerter={w} /></Feld>
        </div>
      )} />
  </div>
);

const SzenenFormular: React.FC<{ sz: Szene; setze: (s: Szene) => void }> = ({ sz, setze }) => {
  const w = beiOptionen(sz);
  const set = <K extends string>(k: K, v: unknown) => setze({ ...sz, [k]: v } as Szene);
  const moment = (k: "dreieck" | "katheten" | "hypotenuse" | "quadrate" | "raster" | "werte", label: string) => sz.typ === "geometrie" && (
    <Feld label={label}><Bei wert={sz[k]?.bei} setze={(v) => set(k, v ? { bei: v } : undefined)} woerter={w} /></Feld>
  );
  return (
    <div className="formular">
      <div className="felder">
        {sz.typ !== "titel" && sz.typ !== "abschluss" && <Feld label="Überschrift" breit><Text wert={sz.ueberschrift} setze={(v) => set("ueberschrift", v || undefined)} /></Feld>}
        <Feld label="Kicker (kleine Zeile)"><Text wert={sz.kicker} setze={(v) => set("kicker", v || undefined)} max={40} /></Feld>
      </div>

      {sz.typ === "titel" && (
        <div className="felder">
          <Feld label="Titel" breit><Text wert={sz.titel} setze={(v) => set("titel", v)} max={40} /></Feld>
          <Feld label="Untertitel"><Text wert={sz.unter} setze={(v) => set("unter", v || undefined)} max={40} /></Feld>
        </div>
      )}

      {sz.typ === "abschluss" && (
        <div className="felder">
          <Feld label="Merksatz" breit><Text wert={sz.text} setze={(v) => set("text", v)} max={50} /></Feld>
          <Feld label="Untertitel"><Text wert={sz.unter} setze={(v) => set("unter", v || undefined)} max={40} /></Feld>
          <Feld label="erscheint bei"><Bei wert={sz.bei} setze={(v) => set("bei", v)} woerter={w} /></Feld>
        </div>
      )}

      {sz.typ === "stichpunkte" && (
        <Liste titel="Punkte" eintraege={sz.punkte} setze={(p) => set("punkte", p)} min={1} max={5} neu={() => ({ text: "Neuer Punkt", icon: "stern" })}
          render={(p, sp) => (
            <div className="felder">
              <Feld label="Text"><Text wert={p.text} setze={(v) => sp({ ...p, text: v })} max={30} /></Feld>
              <Feld label="Unterzeile"><Text wert={p.unter} setze={(v) => sp({ ...p, unter: v || undefined })} max={40} /></Feld>
              <Feld label="Icon"><Auswahl wert={p.icon} setze={(v) => sp({ ...p, icon: v || undefined })} optionen={ICONS} leer="(Stern)" /></Feld>
              <Feld label="bei"><Bei wert={p.bei} setze={(v) => sp({ ...p, bei: v })} woerter={w} /></Feld>
            </div>
          )} />
      )}

      {sz.typ === "vergleich" && (
        <>
          <SeitenEditor titel="Links (vorher / schlecht)" s={sz.links} setze={(s) => set("links", s)} w={w} />
          <SeitenEditor titel="Rechts (nachher / gut)" s={sz.rechts} setze={(s) => set("rechts", s)} w={w} />
        </>
      )}

      {sz.typ === "ablauf" && (
        <>
          <div className="felder">
            <Feld label="Form"><Auswahl wert={sz.form ?? "kreis"} setze={(v) => set("form", v)} optionen={[["kreis", "Kreis (Schleife)"], ["kette", "Kette (nacheinander)"]]} /></Feld>
          </div>
          <Liste titel="Schritte" eintraege={sz.schritte} setze={(s) => set("schritte", s)} min={2} max={6} neu={() => ({ text: "Schritt", icon: "stern" })}
            render={(s, ss) => (
              <div className="felder">
                <Feld label="Text"><Text wert={s.text} setze={(v) => ss({ ...s, text: v })} max={24} /></Feld>
                <Feld label="Icon"><Auswahl wert={s.icon} setze={(v) => ss({ ...s, icon: v || undefined })} optionen={ICONS} leer="(Stern)" /></Feld>
                <Feld label="bei"><Bei wert={s.bei} setze={(v) => ss({ ...s, bei: v })} woerter={w} /></Feld>
              </div>
            )} />
          <div className="felder">
            <Feld label="Fehler-Text (optional)"><Text wert={sz.fehler?.text} setze={(v) => set("fehler", v ? { ...sz.fehler, text: v } : undefined)} max={30} /></Feld>
            {sz.fehler && <Feld label="Fehler bei"><Bei wert={sz.fehler.bei} setze={(v) => set("fehler", { ...sz.fehler!, bei: v })} woerter={w} /></Feld>}
            <Feld label="Erfolg-Text (optional)"><Text wert={sz.erfolg?.text} setze={(v) => set("erfolg", v ? { ...sz.erfolg, text: v } : undefined)} max={30} /></Feld>
            {sz.erfolg && <Feld label="Erfolg bei"><Bei wert={sz.erfolg.bei} setze={(v) => set("erfolg", { ...sz.erfolg!, bei: v })} woerter={w} /></Feld>}
          </div>
        </>
      )}

      {sz.typ === "formel" && (
        <>
          <Liste titel="Formel-Teile" eintraege={sz.teile} setze={(t) => set("teile", t)} min={1} max={9} neu={() => ({ text: "x" })}
            render={(t, st) => (
              <div className="felder">
                <Feld label="Text"><Text wert={t.text} setze={(v) => st({ ...t, text: v })} max={12} /></Feld>
                <Feld label="Farbe"><Auswahl wert={t.farbe} setze={(v) => st({ ...t, farbe: (v || undefined) as Farbe | undefined })} optionen={FARBEN} leer="(weiß)" /></Feld>
                <Feld label="bei"><Bei wert={t.bei} setze={(v) => st({ ...t, bei: v })} woerter={w} /></Feld>
              </div>
            )} />
          <Liste titel="Rechenschritte (optional)" eintraege={sz.schritte ?? []} setze={(s) => set("schritte", s.length ? s : undefined)} max={6} neu={() => ({ text: "1 + 1 = 2" })}
            render={(s, ss) => (
              <div className="felder">
                <Feld label="Text" breit><Text wert={s.text} setze={(v) => ss({ ...s, text: v })} max={30} /></Feld>
                <Feld label="bei"><Bei wert={s.bei} setze={(v) => ss({ ...s, bei: v })} woerter={w} /></Feld>
              </div>
            )} />
          <div className="felder">
            <Feld label="Rahmen „Merke“ bei"><Bei wert={sz.merke?.bei} setze={(v) => set("merke", v ? { bei: v } : undefined)} woerter={w} /></Feld>
          </div>
        </>
      )}

      {sz.typ === "geometrie" && (
        <>
          <div className="felder">
            <Feld label="Kathete a"><Zahl wert={sz.a} schritt={0.5} min={0.5} max={20} setze={(v) => set("a", v)} /></Feld>
            <Feld label="Kathete b"><Zahl wert={sz.b} schritt={0.5} min={0.5} max={20} setze={(v) => set("b", v)} /></Feld>
          </div>
          <div className="felder">
            {moment("dreieck", "Dreieck zeichnen bei")}
            {moment("katheten", "Katheten bei")}
            {moment("hypotenuse", "Hypotenuse bei")}
            {moment("quadrate", "Quadrate bei")}
            {moment("raster", "Kästchen bei")}
            {moment("werte", "Zahlen bei")}
          </div>
        </>
      )}

      <SprecherEditor saetze={sz.sprecher} setze={(s) => set("sprecher", s)} />
    </div>
  );
};

export const Editor: React.FC<{ drehbuch: Drehbuch; setze: (d: Drehbuch) => void; timingFuerVorschau: Parameters<typeof VorschauPlayer>[0]["timing"]; audio: string | null }> = ({ drehbuch, setze, timingFuerVorschau, audio }) => {
  const [aktiv, setAktiv] = useState(0);
  const [neuTyp, setNeuTyp] = useState<Szene["typ"]>("stichpunkte");
  const [jsonModus, setJsonModus] = useState(false);
  const [jsonText, setJsonText] = useState("");
  const [jsonFehler, setJsonFehler] = useState("");
  const player = useRef<PlayerRef>(null);
  const k = Math.min(aktiv, drehbuch.szenen.length - 1);
  const fehler = useMemo(() => pruefeDrehbuch(drehbuch), [drehbuch]);
  const fehlerVon = (i: number) => fehler.filter((f) => f.startsWith(`Szene ${i + 1}:`) || f.startsWith(`Szene ${i + 1} (`));
  const allgemein = fehler.filter((f) => !/^Szene \d+/.test(f));
  const timing = timingFuerVorschau ?? schaetzeTiming(drehbuch);

  const springe = (i: number) => {
    setAktiv(i);
    const s = timing.szenen[i];
    if (s && player.current) player.current.seekTo(Math.round((i === 0 ? 0 : s.start + 0.4) * 60));
  };
  const setSzenen = (szenen: Szene[]) => setze({ ...drehbuch, szenen });
  const verschiebe = (i: number, d: number) => {
    const l = [...drehbuch.szenen];
    [l[i], l[i + d]] = [l[i + d], l[i]];
    setSzenen(l);
    setAktiv(i + d);
  };

  return (
    <div className="editor">
      <div className="szenen-liste card">
        <div className="card-head"><h2>Szenen</h2></div>
        {drehbuch.szenen.map((s, i) => (
          <div key={i} className={`szene-item ${i === k ? "an" : ""} ${fehlerVon(i).length ? "mit-fehler" : ""}`} onClick={() => springe(i)}>
            <div className="szene-nr">{i + 1}</div>
            <div className="szene-text">
              <div className="szene-typ">{TYP_NAMEN[s.typ]}{fehlerVon(i).length ? " ⚠" : ""}</div>
              <div className="szene-satz">{s.sprecher[0]?.satz}</div>
            </div>
            <div className="szene-btns" onClick={(e) => e.stopPropagation()}>
              <button className="mini-btn" disabled={i === 0} onClick={() => verschiebe(i, -1)} title="nach oben">↑</button>
              <button className="mini-btn" disabled={i === drehbuch.szenen.length - 1} onClick={() => verschiebe(i, 1)} title="nach unten">↓</button>
              <button className="mini-btn rot" disabled={drehbuch.szenen.length <= 1} title="Szene löschen"
                onClick={() => { setSzenen(drehbuch.szenen.filter((_, j) => j !== i)); setAktiv(Math.max(0, i - 1)); }}>✕</button>
            </div>
          </div>
        ))}
        <div className="neu-szene">
          <select value={neuTyp} onChange={(e) => setNeuTyp(e.target.value as Szene["typ"])}>
            {Object.entries(TYP_NAMEN).map(([t, n]) => <option key={t} value={t}>{n}</option>)}
          </select>
          <button className="mini-btn" onClick={() => { const l = [...drehbuch.szenen]; l.splice(k + 1, 0, neueSzene(neuTyp)); setSzenen(l); setAktiv(k + 1); }}>+ Szene</button>
        </div>
        <button className="ghost voll" onClick={() => { setJsonText(JSON.stringify(drehbuch, null, 2)); setJsonFehler(""); setJsonModus(!jsonModus); }}>
          {jsonModus ? "Formular" : "JSON bearbeiten"}
        </button>
      </div>

      <div className="card szene-formular">
        {jsonModus ? (
          <>
            <div className="card-head"><h2>Drehbuch als JSON</h2>
              <button className="primary klein" onClick={() => {
                try { setze(JSON.parse(jsonText)); setJsonFehler(""); setJsonModus(false); } catch (e) { setJsonFehler((e as Error).message); }
              }}>Übernehmen</button>
            </div>
            {jsonFehler && <div className="err">JSON-Fehler: {jsonFehler}</div>}
            <textarea className="json" value={jsonText} onChange={(e) => setJsonText(e.target.value)} spellCheck={false} />
          </>
        ) : drehbuch.szenen[k] && (
          <>
            <div className="card-head"><h2>Szene {k + 1}: {TYP_NAMEN[drehbuch.szenen[k].typ]}</h2></div>
            {[...allgemein, ...fehlerVon(k)].length > 0 && (
              <div className="err"><ul>{[...allgemein, ...fehlerVon(k)].map((f) => <li key={f}>{f.replace(/^Szene \d+( \([^)]*\))?: /, "")}</li>)}</ul></div>
            )}
            <SzenenFormular sz={drehbuch.szenen[k]} setze={(s) => setSzenen(drehbuch.szenen.map((x, j) => (j === k ? s : x)))} />
          </>
        )}
      </div>

      <div className="card editor-vorschau">
        <div className="card-head"><h2>Live-Vorschau</h2></div>
        {fehler.length === 0
          ? <VorschauPlayer drehbuch={drehbuch} timing={timingFuerVorschau} audio={audio} playerRef={player} maxHoehe="62vh" />
          : <div className="muted">Vorschau erscheint, sobald das Drehbuch fehlerfrei ist ({fehler.length} Fehler).</div>}
        <div className="muted hint-line">{audio ? "Mit Stimme." : "Ohne Stimme (Zeiten geschätzt) – Stimme erzeugen unter „Vorschau“."} Klick auf eine Szene springt dorthin.</div>
      </div>
    </div>
  );
};

