import type { Szene } from "../drehbuch/typen";

/* Startwerte für neu eingefügte Szenen + deutsche Namen der Bausteine. */

export const TYP_NAMEN: Record<Szene["typ"], string> = {
  titel: "Titel", stichpunkte: "Stichpunkte", vergleich: "Vergleich", ablauf: "Ablauf",
  formel: "Formel", geometrie: "Geometrie", abschluss: "Abschluss",
};

export const neueSzene = (typ: Szene["typ"]): Szene => {
  switch (typ) {
    case "titel":
      return { typ, titel: "Neuer Abschnitt", unter: "kurz erklärt", sprecher: [{ satz: "Jetzt kommt ein neuer Abschnitt.", pause: 0.4 }] };
    case "stichpunkte":
      return {
        typ, ueberschrift: "Das Wichtigste",
        punkte: [{ text: "Erstens", icon: "stern", bei: "Erstens" }, { text: "Zweitens", icon: "idee", bei: "Zweitens" }],
        sprecher: [{ satz: "Erstens ist das wichtig.", pause: 0.3 }, { satz: "Zweitens auch das.", pause: 0.4 }],
      };
    case "vergleich":
      return {
        typ, ueberschrift: "Vorher und nachher",
        links: { titel: "Vorher", icon: "kreuz", bei: "Vorher", punkte: [{ text: "umständlich" }] },
        rechts: { titel: "Nachher", icon: "haken", bei: "Nachher", punkte: [{ text: "ganz einfach" }] },
        sprecher: [{ satz: "Vorher war es umständlich.", pause: 0.3 }, { satz: "Nachher ist es ganz einfach.", pause: 0.4 }],
      };
    case "ablauf":
      return {
        typ, ueberschrift: "So geht es", form: "kette",
        schritte: [{ text: "Start", icon: "rakete", bei: "Start" }, { text: "Ziel", icon: "ziel", bei: "Ziel" }],
        sprecher: [{ satz: "Vom Start bis zum Ziel.", pause: 0.4 }],
      };
    case "formel":
      return {
        typ, teile: [{ text: "a", farbe: "a", bei: "a" }, { text: "+", bei: "plus" }, { text: "b", farbe: "b", bei: "plus" }],
        sprecher: [{ satz: "Also a plus b.", pause: 0.4 }],
      };
    case "geometrie":
      return {
        typ, a: 3, b: 4, dreieck: { bei: "Dreieck" }, quadrate: { bei: "Quadrate" },
        sprecher: [{ satz: "Ein rechtwinkliges Dreieck mit Quadraten.", pause: 0.4 }],
      };
    case "abschluss":
      return { typ, text: "Das Wichtigste", unter: "Merke", bei: "Merke", sprecher: [{ satz: "Merke dir das.", pause: 0.3 }] };
  }
};
