"""Spielprofil Apex Legends.

Genutzte HUD-Merkmale (in eigenen NVIDIA-Aufnahmen 2560×1440 geprüft):

- Kill-Zähler oben rechts (Zeile unter „N SQUADS LEFT“: Totenkopf + Kills, Handschlag + Assists,
  Squad-Wipes, Schaden). Die Zeile ist rechtsbündig, ihre x-Lage hängt von den Zahlen ab. Erkannt
  werden die großen weißen Ziffern (ca. 18 px hoch): erste Zahlengruppe = Kills, zweite = Assists.
  Steigt der Wert → so viele `kill`-Events. Die Zeile fehlt, solange Kills und Assists 0 sind.
  Beim Squad-Wipe werden Kills an Gegnern, die man vorher niedergeschlagen hat, gutgeschrieben
  (Zähler springt z. B. 0→2) – das sind laut Spiel eigene Kills.
- Meldung unter dem Fadenkreuz: „KNOCKED DOWN <Name> +150“ = eigener Knock. „ASSIST, KNOCKED DOWN …“
  (Knock eines Mitspielers mit eigener Beteiligung) zählt nicht. „ELIMINATED <Name>“ = eigener Kill
  (stützt den Zeitpunkt; ohne lesbaren Zähler auch allein).
- Reiter „LIVE | SUMMARY“ oben in der Mitte = Todes-Zusammenfassung / Zuschauen → `tod`; solange er
  sichtbar ist, werden Zähler und Meldungen ignoriert (man sieht dann das HUD eines Mitspielers).
- Banner „YOU ARE THE CHAMPION“ → `champion`.
- „SQUADS LEFT“ zeigt ein laufendes Match (Schießstand/Lobby haben es nicht) → nur dann Kill/Knock.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import cv2
import numpy as np

from ...schema import Event
from ..lesen import Bereich

NAME = "apex"
FPS = 4.0  # NVIDIA-Aufnahmen: Keyframe alle 0,25 s → genau diese werden dekodiert

VORLAGEN = Path(__file__).with_name("apex_vorlagen")

# Alle Pixelangaben beziehen sich auf 2560×1440 (lesen.REF_B/REF_H)
BEREICHE = [
    Bereich.px("zaehler", 1860, 40, 600, 92),            # „SQUADS LEFT“ + Kill-Zeile, volle Auflösung
    Bereich.px("mitte", 768, 880, 1024, 160, 0.5),       # Knock-/Kill-Meldung unter dem Fadenkreuz
    Bereich.px("oben", 1100, 10, 440, 80, 0.5),          # Reiter LIVE | SUMMARY
    Bereich.px("champion", 400, 480, 1760, 380, 0.25),   # Champion-Banner
]

# Schwellen (Template-Korrelation 0..1); Rauschen lag in den Tests bei ≤ 0,45
S_KNOCK = 0.58
S_ELIM = 0.62
S_ASSIST = 0.6
S_SUMMARY = 0.7
S_CHAMPION = 0.7
S_SQUADS = 0.6
S_ZIFFER = 0.6
ZEILE_Y = 48   # Kill-Zeile beginnt im Ausschnitt „zaehler“ bei y=48 (= 88 px im Vollbild)
# NVIDIA-DVR-Dateien beginnen mit kaputten bzw. veralteten Frames (z. B. eine längst vergangene
# Knock-Meldung im allerersten Bild). Ereignisse, die so früh beginnen, werden verworfen.
START_IGNORIEREN = 1.0


def _lade(name: str, skala: float = 1.0) -> np.ndarray:
    bild = cv2.imread(str(VORLAGEN / f"{name}.png"), cv2.IMREAD_GRAYSCALE)
    if bild is None:
        raise FileNotFoundError(VORLAGEN / f"{name}.png")
    if skala != 1.0:
        bild = cv2.resize(bild, None, fx=skala, fy=skala, interpolation=cv2.INTER_AREA)
    return bild


class _Vorlagen:
    def __init__(self) -> None:
        self.ziffern = [_lade(f"ziffer_{k}").astype(np.float32) for k in range(10)]
        self.knocked = _lade("knocked", 0.5)
        self.eliminated = _lade("eliminated", 0.5)
        self.assist = _lade("assist", 0.5)
        self.summary = _lade("summary", 0.5)
        self.champion = _lade("champion")
        self.squads = _lade("squads")


_V: _Vorlagen | None = None


def _vorlagen() -> _Vorlagen:
    global _V
    if _V is None:
        _V = _Vorlagen()
    return _V


def _grau(bild: np.ndarray) -> np.ndarray:
    """Weiße Schrift hervorheben: Minimum der Farbkanäle (Rot/Blau-Hintergründe werden dunkel)."""
    return bild.min(axis=2) if bild.ndim == 3 else bild


def _suche(bild: np.ndarray, vorlage: np.ndarray) -> tuple[float, tuple[int, int]]:
    if bild.shape[0] < vorlage.shape[0] or bild.shape[1] < vorlage.shape[1]:
        return 0.0, (0, 0)
    if float(bild.std()) < 2.0:          # einfarbig (z. B. schwarz) → keine Aussage
        return 0.0, (0, 0)
    r = cv2.matchTemplate(bild, vorlage, cv2.TM_CCOEFF_NORMED)
    _, m, _, ort = cv2.minMaxLoc(r)
    return float(m), ort


# ---------------------------------------------------------------- Kill-Zähler lesen

def lese_kills(zeile: np.ndarray) -> tuple[str, int | None, float]:
    """Kill-Zeile (BGR, 600×44 bei 1440p) → ("wert", n, güte) | ("leer", None, 0) | ("unklar", None, 0).

    "leer" = keine großen Ziffern im Kill-Bereich (Zeile nicht eingeblendet → 0 Kills und 0 Assists,
    sofern das HUD sichtbar ist; das prüft der Aufrufer über „SQUADS LEFT“).
    """
    g = _grau(zeile)
    th = cv2.morphologyEx(g, cv2.MORPH_TOPHAT, np.ones((15, 15), np.uint8))
    b = (th > 60).astype(np.uint8)
    n, _, st, _ = cv2.connectedComponentsWithStats(b)
    ziffern = []
    for i in range(1, n):
        x, y, w, h, _a = st[i]
        # einstellige Zahlen ~18 px hoch, zweistellige Kills kleiner (~14 px), Schaden ~14 px
        if 12 <= h <= 21 and 5 <= w <= 20 and 6 <= y <= 18 and h >= w * 0.85:
            ziffern.append((int(x), int(w), th[y:y + h, x:x + w]))
    ziffern.sort(key=lambda z: z[0])
    gruppen: list[list] = []
    for z in ziffern:
        if gruppen and z[0] - (gruppen[-1][-1][0] + gruppen[-1][-1][1]) < 6:
            gruppen[-1].append(z)
        else:
            gruppen.append([z])
    if not gruppen or gruppen[0][0][0] > 360 or len(gruppen[0]) >= 3:
        return "leer", None, 0.0   # nur die Schadensanzeige (3–4 Ziffern) oder gar nichts
    if len(gruppen) < 2:
        return "unklar", None, 0.0
    kills, assists = gruppen[0], gruppen[1]
    abstand = assists[0][0] - (kills[-1][0] + kills[-1][1])
    if not (55 <= abstand <= 95) or len(kills) > 2:
        return "unklar", None, 0.0
    V = _vorlagen()
    text, guete = "", 1.0
    for _x, _w, patch in kills:
        p = cv2.resize(patch.astype(np.float32), (14, 20), interpolation=cv2.INTER_AREA)
        werte = [float(cv2.matchTemplate(p, z, cv2.TM_CCOEFF_NORMED)[0, 0]) for z in V.ziffern]
        k = int(np.argmax(werte))
        zweit = sorted(werte)[-2]
        if werte[k] < S_ZIFFER or werte[k] - zweit < 0.04:
            return "unklar", None, 0.0
        text += str(k)
        guete = min(guete, werte[k])
    return "wert", int(text), guete


# ---------------------------------------------------------------- Auswertung

@dataclass
class _Frame:
    t: float
    zustand: str            # wert | leer | unklar
    kills: int | None
    squads: bool
    knock: float            # Korrelation „KNOCKED DOWN“ (0, wenn ASSIST davor)
    knock_x: int
    assist: bool
    name: np.ndarray | None   # Bildausschnitt rechts von „KNOCKED DOWN“ (Name + Schaden), zum Unterscheiden
    elim: float
    summary: bool
    champion: float


@dataclass
class Auswertung:
    frames: list[_Frame] = field(default_factory=list)

    # -------- pro Frame
    def frame(self, t: float, bilder: dict[str, np.ndarray]) -> None:
        V = _vorlagen()
        z = bilder["zaehler"]
        sq, _ = _suche(_grau(z[:ZEILE_Y]), V.squads)
        zustand, kills, _ = lese_kills(z[ZEILE_Y:])

        m = _grau(bilder["mitte"])
        kd, (kx, ky) = _suche(m, V.knocked)
        assist = False
        name = None
        if kd >= S_KNOCK:
            kw, kh = V.knocked.shape[1], V.knocked.shape[0]
            name = m[max(0, ky - 2):ky + kh + 10, kx + kw:kx + kw + 110].astype(np.float32)
            links = m[max(0, ky - 4):ky + V.knocked.shape[0] + 4, max(0, kx - 75):kx]
            a, _ = _suche(links, V.assist)
            assist = a >= S_ASSIST
        el, _ = _suche(m, V.eliminated)
        su, _ = _suche(_grau(bilder["oben"]), V.summary)
        ch, _ = _suche(_grau(bilder["champion"]), V.champion)
        self.frames.append(_Frame(t, zustand, kills, sq >= S_SQUADS, kd, kx, assist, name, el,
                                  su >= S_SUMMARY, ch))

    # -------- am Ende
    def ergebnis(self, dauer: float) -> list[Event]:
        f = [x for x in self.frames if x.t >= 0]
        if not f:
            return []
        events: list[Event] = []
        im_match = _match_maske(f)
        zuschauen = _zuschau_maske(f)
        events += _tode(f)
        events += _champion(f)
        events += _knocks(f, im_match, zuschauen)
        events += _kills(f, im_match, zuschauen)
        events = [e for e in events if e.t >= START_IGNORIEREN]
        events.sort(key=lambda e: (e.t, e.typ))
        return events


def _match_maske(f: list[_Frame], fenster: float = 45.0) -> list[bool]:
    """True, wenn „SQUADS LEFT“ höchstens `fenster` s entfernt sichtbar war (laufendes Match)."""
    zeiten = [x.t for x in f if x.squads]
    if not zeiten:
        return [False] * len(f)
    arr = np.array(zeiten)
    out = []
    for x in f:
        i = int(np.searchsorted(arr, x.t))
        naechst = min(abs(arr[j] - x.t) for j in (i - 1, i) if 0 <= j < len(arr))
        out.append(naechst <= fenster)
    return out


def _zuschau_maske(f: list[_Frame], nach: float = 2.0) -> list[bool]:
    """True während LIVE|SUMMARY sichtbar ist und kurz danach (fremdes HUD, Übergänge)."""
    out = [False] * len(f)
    letzte = -1e9
    for i, x in enumerate(f):
        if x.summary:
            letzte = x.t
        out[i] = x.summary or (x.t - letzte) <= nach
    return out


def _laeufe(werte: list[bool], zeiten: list[float], luecke: float = 0.6) -> list[tuple[int, int]]:
    """Zusammenhängende True-Abschnitte (Lücken bis `luecke` s werden überbrückt) → [(start, ende)]."""
    laeufe: list[tuple[int, int]] = []
    start = ende = None
    for i, w in enumerate(werte):
        if not w:
            continue
        if start is not None and zeiten[i] - zeiten[ende] <= luecke:
            ende = i
        else:
            if start is not None:
                laeufe.append((start, ende))
            start = ende = i
    if start is not None:
        laeufe.append((start, ende))
    return laeufe


def _tode(f: list[_Frame]) -> list[Event]:
    zeiten = [x.t for x in f]
    out = []
    for s, e in _laeufe([x.summary for x in f], zeiten, luecke=3.0):
        # Vorher muss normales Spiel zu sehen gewesen sein (sonst beginnt die Aufnahme schon im Tod)
        vorher = [x for x in f[:s] if x.t >= f[s].t - 10 and not x.summary and (x.squads or x.zustand == "wert")]
        if len(vorher) < 4 or e - s < 3:
            continue
        out.append(Event(round(f[s].t, 2), "tod", 0.8, "Todes-Zusammenfassung (LIVE | SUMMARY) erscheint"))
    return out


def _champion(f: list[_Frame]) -> list[Event]:
    zeiten = [x.t for x in f]
    out = []
    letzte = -1e9
    for s, e in _laeufe([x.champion >= S_CHAMPION for x in f], zeiten, luecke=2.0):
        if e - s < 1 or f[s].t - letzte < 60:
            continue
        letzte = f[s].t
        beste = max(x.champion for x in f[s:e + 1])
        out.append(Event(round(f[s].t, 2), "champion", round(min(1.0, beste), 2), "Banner „YOU ARE THE CHAMPION“"))
    return out


def _gleicher_name(a: _Frame, b: _Frame) -> bool:
    if a.name is None or b.name is None or a.name.shape != b.name.shape:
        return False
    if float(a.name.std()) < 2 or float(b.name.std()) < 2:
        return False
    return float(cv2.matchTemplate(a.name, b.name, cv2.TM_CCOEFF_NORMED)[0, 0]) >= 0.75


def _knocks(f: list[_Frame], im_match: list[bool], zuschauen: list[bool]) -> list[Event]:
    """Je Meldung „KNOCKED DOWN …“ ein Event.

    Folgen zwei Meldungen direkt aufeinander, wird der Text neu zentriert (x verschiebt sich) oder es
    gibt mindestens einen Frame ohne Meldung. Über eine solche Lücke wird nur zusammengefasst, wenn
    der Name daneben gleich aussieht (einzelner verdeckter Frame).
    """
    aktiv = [i for i, x in enumerate(f) if x.knock >= S_KNOCK and not zuschauen[i]]
    abschnitte: list[list[int]] = []
    for i in aktiv:
        if abschnitte:
            j = abschnitte[-1][-1]
            dt = f[i].t - f[j].t
            gleich_x = abs(f[i].knock_x - f[j].knock_x) <= 3
            if gleich_x and (dt <= 0.3 or (dt <= 1.0 and _gleicher_name(f[i], f[j]))):
                abschnitte[-1].append(i)
                continue
        abschnitte.append([i])

    out = []
    for abschnitt in abschnitte:
        assists = sum(f[j].assist for j in abschnitt)
        if assists * 2 >= len(abschnitt):       # „ASSIST, KNOCKED DOWN …“ → Knock eines Mitspielers
            continue
        j0 = abschnitt[0]
        if not im_match[j0]:
            continue
        beste = max(f[j].knock for j in abschnitt)
        if len(abschnitt) < 2 and beste < 0.65:  # einzelner schwacher Treffer → eher Zufall
            continue
        sicher = round(min(0.99, 0.55 + (beste - S_KNOCK) * 1.2 + 0.05 * min(len(abschnitt), 4)), 2)
        info = "Meldung „KNOCKED DOWN“" if beste >= 0.7 else "Meldung „KNOCKED DOWN“ (schwach, evtl. RE-KNOCKED)"
        out.append(Event(round(f[j0].t, 2), "knock", sicher, info))
    return out


def _kills(f: list[_Frame], im_match: list[bool], zuschauen: list[bool]) -> list[Event]:
    zeiten = [x.t for x in f]
    # ELIMINATED-Meldungen (Beginn jedes Laufs)
    elim_starts = [f[s].t for s, e in _laeufe([x.elim >= S_ELIM and not zuschauen[i] for i, x in enumerate(f)],
                                                zeiten, luecke=0.6) if e > s or f[s].elim >= 0.75]

    # Zählerstand entprellen: neuer Wert erst gültig, wenn er in 2 von 3 lesbaren Frames gleich ist
    out: list[Event] = []
    stand: int | None = None          # bestätigter Zählerstand
    leer_seit = 0                     # aufeinanderfolgende „leer“-Frames mit sichtbarem HUD
    kandidat: tuple[int, int] | None = None   # (wert, index erster Frame)
    kandidat_n = 0
    zaehler_zeiten: list[float] = []  # Zeiten, an denen ein Kill über den Zähler kam
    neu_einordnen = False             # nach dem Zuschauen: nächsten Wert nur übernehmen
    zuerst: dict[int, float] = {}     # erster Zeitpunkt, an dem ein Wert über dem Stand gelesen wurde
    for i, x in enumerate(f):
        if zuschauen[i]:
            kandidat, kandidat_n = None, 0
            leer_seit = 0
            neu_einordnen = True
            continue
        if x.zustand == "leer" and x.squads:
            leer_seit += 1
            if leer_seit >= 4 and stand is None:
                stand = 0
            continue
        if x.zustand != "wert" or x.kills is None:
            continue
        leer_seit = 0
        if stand is not None and x.kills > stand:
            zuerst.setdefault(x.kills, x.t)
        if kandidat and kandidat[0] == x.kills:
            kandidat_n += 1
        else:
            kandidat, kandidat_n = (x.kills, i), 1
        if kandidat_n < 2:
            continue
        wert, i0 = kandidat
        if stand is None or wert == stand or neu_einordnen:
            stand = wert
            neu_einordnen = False
            zuerst.clear()
            continue
        diff = wert - stand
        if 0 < diff <= 4 and im_match[i0]:
            t_neu = f[i0].t
            # Zwischenstände (z. B. 2→3→4→5 innerhalb einer Sekunde) behalten ihren eigenen Zeitpunkt
            zeiten_k = []
            for k in range(1, diff + 1):
                tk = zuerst.get(stand + k, t_neu)
                if tk < t_neu - 3.0:
                    tk = t_neu
                zeiten_k.append(tk)
            zeiten_k = [min(zeiten_k[j:]) for j in range(len(zeiten_k))]   # monoton steigend
            # Erscheint „ELIMINATED“ kurz vor dem ersten neuen Stand, gilt dieser Moment
            frueher = [te for te in elim_starts if zeiten_k[0] - 2.0 <= te <= zeiten_k[0] + 0.3]
            if frueher:
                zeiten_k[0] = min(frueher)
            for k, tk in enumerate(zeiten_k):
                out.append(Event(round(tk, 2), "kill", 0.95 if diff == 1 else 0.9,
                                 f"Kill-Zähler {stand + k}→{stand + k + 1}"))
                zaehler_zeiten.append(tk)
        # Abnahme oder unplausibler Sprung → neues Match / Fehllesung: nur neu einordnen
        stand = wert
        zuerst.clear()

    # ELIMINATED ohne Zähleränderung in der Nähe: nur übernehmen, wenn der Zähler dort nicht lesbar war
    for te in elim_starts:
        if any(abs(te - tz) <= 4.0 for tz in zaehler_zeiten):
            continue
        i = int(np.searchsorted(np.array(zeiten), te))
        if not im_match[min(i, len(f) - 1)]:
            continue
        umgebung = [x for x in f if te - 3 <= x.t <= te + 5 and x.zustand == "wert"]
        if len(umgebung) >= 4:
            continue   # Zähler war lesbar und hat sich nicht geändert → kein eigener Kill
        out.append(Event(round(te, 2), "kill", 0.7, "Meldung „ELIMINATED“ (Zähler nicht lesbar)"))
    return out


def neue_auswertung() -> Auswertung:
    return Auswertung()
