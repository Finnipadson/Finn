/* Das Drehbuch: eine JSON-Datei aus Szenen-Bausteinen.
   „bei“ verknüpft ein Element mit einem gesprochenen Wort der Szene → es erscheint genau dann.
   Schreibweise: "Katheten" (erstes Vorkommen in der Szene) oder "Quadrat#2" (zweites Vorkommen). */

export type Format = "hoch" | "quer";
export type Stimmung = "ruhig" | "froh" | "spannend";
export const STIMMUNGEN: Record<Stimmung, string> = { ruhig: "Ruhig", froh: "Fröhlich", spannend: "Spannend" };
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
export type SzZeitstrahl = Basis & {
  typ: "zeitstrahl";
  ereignisse: ({ zeit: string; text: string; icon?: string } & Bei)[];  // 2–6, z. B. zeit "1991"
};
export type SzFenster = Basis & {
  typ: "fenster";
  art: "terminal" | "chat";
  titel?: string;                                                     // Text in der Titelleiste
  zeilen: ({ text: string; rolle: "ich" | "antwort" } & Bei)[];       // 1–6; "ich" wird getippt
};
export type SzAbschluss = Basis & { typ: "abschluss"; text: string; unter?: string } & Bei;

export type Szene = SzTitel | SzStichpunkte | SzVergleich | SzAblauf | SzFormel | SzGeometrie | SzZeitstrahl | SzFenster | SzAbschluss;
export const SZENEN_TYPEN = ["titel", "stichpunkte", "vergleich", "ablauf", "formel", "geometrie", "zeitstrahl", "fenster", "abschluss"] as const;

export type Drehbuch = {
  titel: string;
  format: Format;
  thema?: "dunkel" | "tafel" | "papier" | "kueche";  // Design-Thema (Standard: dunkel)
  stimme?: string;
  tempo?: number;
  musik?: boolean;
  stimmung?: Stimmung;   // Musik-Stimmung (Standard: ruhig)
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
