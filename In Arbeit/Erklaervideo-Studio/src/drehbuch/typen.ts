/* Das Drehbuch: eine JSON-Datei aus Szenen-Bausteinen.
   „bei“ verknüpft ein Element mit einem gesprochenen Wort der Szene → es erscheint genau dann.
   Schreibweise: "Katheten" (erstes Vorkommen in der Szene) oder "Quadrat#2" (zweites Vorkommen). */

export type Format = "hoch" | "quer";
export type Farbe = "a" | "b" | "c" | "akzent" | "text" | "gruen" | "rot" | "blau" | "lila";

export type Bei = { bei?: string };
export type Satz = { satz: string; pause?: number; tempo?: number };

type Basis = {
  sprecher: Satz[];
  kicker?: string;
  ueberschrift?: string;
};

export type SzTitel = Basis & { typ: "titel"; titel: string; unter?: string };
export type Punkt = { text: string; unter?: string; icon?: string } & Bei;
export type SzStichpunkte = Basis & { typ: "stichpunkte"; punkte: Punkt[] };
export type Seite = { titel: string; icon?: string; punkte: ({ text: string } & Bei)[] } & Bei;
export type SzVergleich = Basis & { typ: "vergleich"; links: Seite; rechts: Seite };
export type SzAblauf = Basis & {
  typ: "ablauf";
  form?: "kreis" | "kette";
  schritte: ({ text: string; icon?: string } & Bei)[];
  fehler?: { text: string } & Bei;
  erfolg?: { text: string } & Bei;
};
export type SzFormel = Basis & {
  typ: "formel";
  teile: ({ text: string; farbe?: Farbe } & Bei)[];
  schritte?: ({ text: string } & Bei)[];
  merke?: Bei;
};
export type SzGeometrie = Basis & {
  typ: "geometrie";
  a: number;
  b: number;
  beschriftung?: { a?: string; b?: string; c?: string };
  dreieck?: Bei; katheten?: Bei; hypotenuse?: Bei; quadrate?: Bei; raster?: Bei; werte?: Bei;
};
export type SzAbschluss = Basis & { typ: "abschluss"; text: string; unter?: string } & Bei;

export type Szene = SzTitel | SzStichpunkte | SzVergleich | SzAblauf | SzFormel | SzGeometrie | SzAbschluss;
export const SZENEN_TYPEN = ["titel", "stichpunkte", "vergleich", "ablauf", "formel", "geometrie", "abschluss"] as const;

export type Drehbuch = {
  titel: string;
  format: Format;
  thema?: "dunkel";
  stimme?: string;
  tempo?: number;
  musik?: boolean;
  szenen: Szene[];
};

/* Ergebnis der Ton-Pipeline (tools/ton.py) – oder eine geschätzte Variante ohne Stimme. */
export type Wort = { text: string; start: number; end: number; szene: number };
export type Timing = {
  fps: number;
  dauer: number;
  geschaetzt?: boolean;
  woerter: Wort[];
  szenen: { start: number; ende: number; bei: Record<string, number> }[];
};

export const STIMMEN: Record<string, { name: string; id: string }> = {
  ava: { name: "Ava", id: "en-US-AvaMultilingualNeural" },
  seraphina: { name: "Seraphina", id: "de-DE-SeraphinaMultilingualNeural" },
  florian: { name: "Florian", id: "de-DE-FlorianMultilingualNeural" },
  conrad: { name: "Conrad", id: "de-DE-ConradNeural" },
  katja: { name: "Katja", id: "de-DE-KatjaNeural" },
};
