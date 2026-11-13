import React, { useCallback, useEffect, useMemo, useState } from "react";
import { pruefeDrehbuch, tonSchluessel } from "./drehbuch/pruefen";
import type { Drehbuch, Timing } from "./drehbuch/typen";
import { api, klon, warteAuf, type Auftrag, type Eintrag, type Health } from "./ui/api";
import { ThemaAnsicht } from "./ui/ThemaAnsicht";
import { Editor } from "./ui/Editor";
import { Einstellungen } from "./ui/Einstellungen";
import { VorschauPlayer } from "./ui/VorschauPlayer";
import { Rendern } from "./ui/Rendern";

// Beispiel-Drehbücher + (falls erzeugt) ihre Zeitlisten aus dem Ordner beispiele/
const dateien = import.meta.glob("../beispiele/*.json", { eager: true, import: "default" }) as Record<string, unknown>;
const BEISPIELE_ROH: Eintrag[] = Object.entries(dateien)
  .filter(([p]) => !p.endsWith(".timing.json"))
  .map(([p, d]) => {
    const name = p.split("/").pop()!.replace(/\.json$/, "");
    return { id: `b:${name}`, name, quelle: "beispiel", drehbuch: d as Drehbuch, timing: (dateien[`../beispiele/${name}.timing.json`] as Timing | undefined) ?? null, ton: null, video: null };
  });

type Ansicht = "thema" | "drehbuch" | "einstellungen" | "vorschau" | "rendern";
const SCHRITTE: { id: Ansicht; label: string; brauchtProjekt: boolean }[] = [
  { id: "thema", label: "Thema", brauchtProjekt: false },
  { id: "drehbuch", label: "Drehbuch", brauchtProjekt: true },
  { id: "einstellungen", label: "Einstellungen", brauchtProjekt: true },
  { id: "vorschau", label: "Vorschau", brauchtProjekt: true },
  { id: "rendern", label: "Rendern", brauchtProjekt: true },
];

export const App: React.FC = () => {
  const [health, setHealth] = useState<Health | null>(null);
  const [healthFehler, setHealthFehler] = useState<string | null>(null);
  const [projekte, setProjekte] = useState<Eintrag[]>([]);
  const [beispiele, setBeispiele] = useState<Eintrag[]>(BEISPIELE_ROH);
  const [aktivId, setAktivId] = useState<string | undefined>();
  const [entwurf, setEntwurf] = useState<Drehbuch | null>(null);
  const [ansicht, setAnsicht] = useState<Ansicht>("thema");
  const [speichertGerade, setSpeichertGerade] = useState(false);
  const [meldung, setMeldung] = useState("");
  const [tonAuftrag, setTonAuftrag] = useState<Auftrag | null>(null);
  const [renderAuftrag, setRenderAuftrag] = useState<(Auftrag & { id?: string }) | null>(null);

  const pruefeHealth = useCallback(() => {
    setHealth(null);
    setHealthFehler(null);
    api.health().then(setHealth).catch(() => setHealthFehler("Der lokale Server läuft nicht. Bitte über start.bat starten."));
  }, []);
  const ladeProjekte = useCallback(() => api.projekte().then((p) => { setProjekte(p); return p; }).catch(() => [] as Eintrag[]), []);

  useEffect(() => {
    pruefeHealth();
    ladeProjekte();
    // Haben die Beispiele schon Ton? (public/ton/<name>.wav)
    Promise.all(BEISPIELE_ROH.map((b) => fetch(`/ton/${b.name}.wav`, { method: "HEAD" })
      .then((r) => ({ ...b, ton: r.ok && (r.headers.get("content-type") ?? "").includes("audio") ? `/ton/${b.name}.wav` : null }))
      .catch(() => b))).then(setBeispiele);
  }, []);

  const alle = useMemo(() => [...projekte, ...beispiele], [projekte, beispiele]);
  const eintrag = alle.find((e) => e.id === aktivId);
  const geaendert = !!(eintrag && entwurf && JSON.stringify(eintrag.drehbuch) !== JSON.stringify(entwurf));
  const fehler = useMemo(() => (entwurf ? pruefeDrehbuch(entwurf) : []), [entwurf]);
  // Stimme passt nur, solange sich nichts Ton-Relevantes geändert hat
  const tonPasst = !!(eintrag?.ton && eintrag.timing && entwurf && tonSchluessel(entwurf) === tonSchluessel(eintrag.drehbuch));
  const timing = tonPasst ? eintrag!.timing : null;
  const audio = tonPasst ? eintrag!.ton : null;

  useEffect(() => {
    const warn = (e: BeforeUnloadEvent) => { if (geaendert) e.preventDefault(); };
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [geaendert]);

  const oeffne = (id: string, zu: Ansicht = "drehbuch", liste = alle) => {
    if (geaendert && !confirm("Es gibt ungespeicherte Änderungen. Trotzdem wechseln?")) return;
    const e = liste.find((x) => x.id === id);
    if (!e) return;
    setAktivId(id);
    setEntwurf(klon(e.drehbuch));
    setMeldung("");
    setTonAuftrag(null);
    setRenderAuftrag((r) => (r && !r.fertig ? r : null)); // ein laufender Render läuft weiter
    setAnsicht(zu);
  };

  /** Speichern; ein Beispiel wird dabei zu einem eigenen Projekt kopiert. Gibt den Projektnamen zurück. */
  const speichern = async (): Promise<string | null> => {
    if (!entwurf || !eintrag) return null;
    setSpeichertGerade(true);
    try {
      let name = eintrag.name;
      if (eintrag.quelle === "beispiel") {
        name = (await api.neu(entwurf)).name;
        setMeldung(`Als eigenes Projekt „${name}“ gespeichert.`);
      } else {
        const r = await api.speichern(name, entwurf);
        setMeldung(r.tonVeraltet ? "Gespeichert. Die Stimme passt nicht mehr zum Text – bitte neu erzeugen." : "Gespeichert.");
      }
      const liste = await ladeProjekte();
      const neu = liste.find((p) => p.name === name);
      if (neu) { setAktivId(neu.id); setEntwurf(klon(neu.drehbuch)); }
      return name;
    } catch (e) {
      setMeldung(`Speichern fehlgeschlagen: ${(e as Error).message}`);
      return null;
    } finally {
      setSpeichertGerade(false);
    }
  };

  const stimmeErzeugen = async () => {
    if (fehler.length) return;
    const name = geaendert || eintrag?.quelle === "beispiel" ? await speichern() : eintrag?.name;
    if (!name) return;
    setTonAuftrag({ status: "Startet …", fertig: false, fortschritt: 0 });
    try {
      const { id } = await api.tonErzeugen(name);
      await warteAuf(id, setTonAuftrag);
      const liste = await ladeProjekte();
      const neu = liste.find((p) => p.name === name);
      if (neu) { setAktivId(neu.id); setEntwurf(klon(neu.drehbuch)); }
    } catch (e) {
      setTonAuftrag({ status: "Fehler", fertig: true, fehler: [(e as Error).message] });
    }
  };

  const tonLaeuft = !!tonAuftrag && !tonAuftrag.fertig;
  const renderLaeuft = !!renderAuftrag && !renderAuftrag.fertig;

  const rendern = async (ohneTon: boolean) => {
    if (fehler.length || renderLaeuft) return;
    const name = geaendert || eintrag?.quelle === "beispiel" ? await speichern() : eintrag?.name;
    if (!name) return;
    setRenderAuftrag({ status: "Startet …", fertig: false, fortschritt: 0, projekt: name });
    try {
      const { id } = await api.rendern(name, ohneTon);
      setRenderAuftrag((a) => ({ ...a!, id }));
      await warteAuf(id, (a) => setRenderAuftrag({ ...a, id }));
      await ladeProjekte();
    } catch (e) {
      setRenderAuftrag({ status: "Fehler", fertig: true, fehler: [(e as Error).message], projekt: name });
    }
  };

  return (
    <div className="app">
      <header className="top">
        <div className="logo"><span className="play" />Erklärvideo-Studio</div>
        {entwurf && (
          <div className="projekt-kopf">
            <span className="projekt-name">{entwurf.titel}{eintrag?.quelle === "beispiel" ? " (Beispiel)" : ""}</span>
            {geaendert && <span className="punkt" title="ungespeicherte Änderungen" />}
            {meldung && <span className="meldung">{meldung}</span>}
            <button className="primary klein" disabled={!geaendert || speichertGerade} onClick={speichern}>
              {speichertGerade ? "Speichert …" : eintrag?.quelle === "beispiel" && geaendert ? "Als Kopie speichern" : "Speichern"}
            </button>
          </div>
        )}
        <div className={`status-punkt ${health ? (health.ok ? "ok" : "bad") : ""}`} title={health ? (health.ok ? "System bereit" : "Bitte System-Check ansehen") : "prüfe …"} onClick={() => setAnsicht("thema")} />
      </header>

      <nav className="steps">
        {SCHRITTE.map((s, i) => {
          const gesperrt = s.brauchtProjekt && !entwurf;
          return (
            <button key={s.id} className={`step ${ansicht === s.id ? "aktiv" : ""} ${gesperrt ? "gesperrt" : ""}`} disabled={gesperrt}
              title={gesperrt ? "Erst ein Drehbuch schreiben oder öffnen" : ""} onClick={() => setAnsicht(s.id)}>
              <span className="num">{i + 1}</span>
              <span>{s.label}</span>
              {s.id === "rendern" && renderLaeuft && <span className="soon">{Math.round((renderAuftrag?.fortschritt ?? 0) * 100)} %</span>}
            </button>
          );
        })}
      </nav>

      <main className="main-voll">
        {ansicht === "thema" && (
          <ThemaAnsicht projekte={projekte} beispiele={beispiele} aktivId={aktivId} oeffne={(id) => oeffne(id)}
            nachNeu={async (name) => { const l = await ladeProjekte(); oeffne(`p:${name}`, "drehbuch", [...l, ...beispiele]); }}
            health={health} healthFehler={healthFehler} pruefeHealth={pruefeHealth} />
        )}

        {ansicht === "drehbuch" && entwurf && (
          <Editor drehbuch={entwurf} setze={setEntwurf} timingFuerVorschau={timing} audio={audio} />
        )}

        {ansicht === "einstellungen" && entwurf && <Einstellungen drehbuch={entwurf} setze={setEntwurf} />}

        {ansicht === "vorschau" && entwurf && (
          <div className="vorschau-ansicht">
            <section className="card">
              <div className="card-head">
                <h2>Vorschau</h2>
                <div className="row">
                  {tonPasst
                    ? <span className="badge ok">mit Stimme</span>
                    : <span className="badge">{eintrag?.ton ? "Stimme veraltet" : "ohne Stimme"}</span>}
                  <button className="primary klein" disabled={tonLaeuft || fehler.length > 0} onClick={stimmeErzeugen}>
                    {tonLaeuft ? "Erzeuge …" : tonPasst ? "Stimme neu erzeugen" : "Stimme erzeugen"}
                  </button>
                </div>
              </div>
              {tonAuftrag && (
                <div className={`status ${tonAuftrag.fehler ? "bad" : tonAuftrag.fertig ? "ok" : ""}`}>
                  {!tonAuftrag.fertig && <span className="spinner" />}
                  <span>{tonAuftrag.status}</span>
                  {tonAuftrag.fortschritt !== undefined && !tonAuftrag.fertig && (
                    <div className="balken"><div style={{ width: `${Math.round(tonAuftrag.fortschritt * 100)}%` }} /></div>
                  )}
                  {tonAuftrag.fehler && <ul>{tonAuftrag.fehler.map((f) => <li key={f}>{f}</li>)}</ul>}
                </div>
              )}
              {fehler.length === 0
                ? <VorschauPlayer key={`${aktivId}-${audio ?? "ohne"}`} drehbuch={entwurf} timing={timing} audio={audio} maxHoehe="72vh" />
                : <div className="err"><b>Das Drehbuch hat noch {fehler.length} Fehler</b> – im Schritt „Drehbuch“ beheben.</div>}
              <div className="muted hint-line">
                {tonPasst ? "Mit echter Stimme, Geräuschen und Musik." : "Ohne Stimme sind die Zeiten geschätzt. „Stimme erzeugen“ speichert vorher automatisch."}
                {eintrag?.quelle === "beispiel" && " Bei einem Beispiel wird dabei eine eigene Kopie angelegt."}
              </div>
            </section>
          </div>
        )}

        {ansicht === "rendern" && entwurf && eintrag && (
          <Rendern eintrag={eintrag} drehbuch={entwurf} timing={timing} geaendert={geaendert} fehler={fehler.length} tonPasst={tonPasst}
            auftrag={renderAuftrag && (renderAuftrag.projekt === eintrag.name || !renderAuftrag.projekt) ? renderAuftrag : null}
            andererLaeuft={renderLaeuft && renderAuftrag?.projekt !== eintrag.name ? renderAuftrag?.projekt ?? "" : null}
            starte={rendern} abbrechen={() => renderAuftrag?.id && api.abbrechen(renderAuftrag.id).catch(() => {})}
            zurVorschau={() => setAnsicht("vorschau")} />
        )}
      </main>
    </div>
  );
};
