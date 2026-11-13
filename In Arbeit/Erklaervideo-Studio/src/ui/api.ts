import type { Drehbuch, Szene, Timing } from "../drehbuch/typen";

/* Verbindung zum lokalen Server + gemeinsame Typen der Oberfläche. */

export type Check = { name: string; ok: boolean; detail: string; hint?: string };
export type Health = { ok: boolean; checks: Check[] };
export type Auftrag = {
  status: string; fertig: boolean; fehler?: string[]; fehlerArt?: string; projekt?: string; fortschritt?: number;
  szene?: Szene; abbrechbar?: boolean; abgebrochen?: boolean;
  ergebnis?: { dauerMs: number; bytes: number; sekunden: number };
};
/** Fertig gerendertes Video eines Projekts */
export type VideoInfo = { bytes: number; zeit: number; veraltet: boolean; cover: boolean };

export type Eintrag = {
  id: string;                 // "p:<name>" (eigenes Projekt) oder "b:<name>" (Beispiel)
  name: string;
  quelle: "projekt" | "beispiel";
  drehbuch: Drehbuch;
  timing: Timing | null;
  ton: string | null;         // URL der Tonspur für die Vorschau (mit Cache-Schutz) oder null
  video: VideoInfo | null;    // fertiges MP4 (nur eigene Projekte)
};

type ProjektAntwort = { name: string; drehbuch: Drehbuch; timing: Timing | null; ton: boolean; tonVersion: number; video: VideoInfo | null };

const json = async <T,>(r: Response): Promise<T> => {
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error((j as { fehler?: string }).fehler ?? `Server antwortet mit ${r.status}`);
  return j as T;
};

export const api = {
  health: () => fetch("/api/health").then((r) => json<Health>(r)),
  vorlagen: () => fetch("/api/vorlagen").then((r) => json<{ id: string; name: string }[]>(r)),
  projekte: () =>
    fetch("/api/projekte").then((r) => json<ProjektAntwort[]>(r)).then((l) =>
      l.map<Eintrag>((p) => ({
        id: `p:${p.name}`, name: p.name, quelle: "projekt", drehbuch: p.drehbuch, timing: p.timing,
        ton: p.ton ? `/ton/${p.name}.wav?v=${p.tonVersion}` : null, video: p.video,
      })),
    ),
  drehbuchSchreiben: (b: { thema: string; vorlage: string; format: string; sekunden: number }) =>
    fetch("/api/drehbuch", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(b) }).then((r) => json<{ id: string }>(r)),
  neu: (drehbuch: Drehbuch) =>
    fetch("/api/projekte", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ drehbuch }) }).then((r) => json<{ name: string }>(r)),
  speichern: (name: string, drehbuch: Drehbuch) =>
    fetch(`/api/projekte/${name}`, { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ drehbuch }) }).then((r) => json<{ tonVeraltet: boolean }>(r)),
  tonErzeugen: (name: string) => fetch(`/api/projekte/${name}/ton`, { method: "POST" }).then((r) => json<{ id: string }>(r)),
  stimmprobe: (stimme: string, tempo: number) => fetch(`/api/stimmprobe?stimme=${stimme}&tempo=${tempo}`).then((r) => json<{ url: string }>(r)),
  musik: () => fetch("/api/musik").then((r) => json<{ ordner: string; eigene: Record<string, number> }>(r)),
  musikprobe: (stimmung: string) => fetch(`/api/musikprobe?stimmung=${stimmung}`).then((r) => json<{ url: string }>(r)),
  auftrag: (id: string) => fetch(`/api/auftrag/${id}`).then((r) => json<Auftrag>(r)),
  abbrechen: (id: string) => fetch(`/api/auftrag/${id}/abbrechen`, { method: "POST" }).then((r) => json<{ ok: boolean }>(r)),
  szeneNeu: (drehbuch: Drehbuch, index: number, wunsch: string) =>
    fetch("/api/szene", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ drehbuch, index, wunsch }) }).then((r) => json<{ id: string }>(r)),
  rendern: (name: string, ohneTon: boolean) =>
    fetch(`/api/projekte/${name}/rendern`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ ohneTon }) }).then((r) => json<{ id: string }>(r)),
  zeigen: (name: string) => fetch(`/api/projekte/${name}/zeigen`, { method: "POST" }).then((r) => json<{ ok: boolean }>(r)),
};

/** Adressen von fertigem Video + Cover (v = Cache-Schutz nach neuem Rendern) */
export const dateiUrl = (name: string, art: "video" | "cover", v: number, download = false) =>
  `/api/projekte/${name}/datei/${art}?v=${v}${download ? "&download" : ""}`;

/** Auftrag abfragen, bis er fertig ist; meldet Zwischenstände.
    Einzelne Aussetzer (z. B. wenn der PC beim Rendern voll ausgelastet ist) werden übergangen. */
export const warteAuf = async (id: string, melde: (a: Auftrag) => void) => {
  let aussetzer = 0;
  for (;;) {
    await new Promise((r) => setTimeout(r, 1200));
    let a: Auftrag;
    try {
      a = await api.auftrag(id);
      aussetzer = 0;
    } catch (e) {
      if (++aussetzer >= 15) throw new Error(`Keine Verbindung zum Server (${(e as Error).message}). Läuft start.bat noch?`);
      continue;
    }
    melde(a);
    if (a.fertig) return a;
  }
};

export const klon = <T,>(x: T): T => JSON.parse(JSON.stringify(x));
