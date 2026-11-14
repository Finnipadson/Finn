"""Tests Phase 1 (Erkennung). Schnell; Tests mit echten Aufnahmen werden übersprungen, wenn sie fehlen."""
from __future__ import annotations

import json
import threading
from pathlib import Path

import cv2
import numpy as np
import pytest

from cutter.erkennung import erkenne
from cutter.erkennung.bewertung import vergleiche
from cutter.erkennung.lesen import Bereich
from cutter.erkennung.profile import apex, lade
from cutter.erkennung.profile.apex import _Frame, _kills, _knocks, _tode, lese_kills
from cutter.medien import NVIDIA_ORDNER
from cutter.schema import Abgebrochen, Event

DATEN = Path(__file__).parent / "daten"
GT = json.loads((DATEN / "apex_ground_truth.json").read_text(encoding="utf-8"))
APEX = NVIDIA_ORDNER / "Apex Legends"
DESKTOP = NVIDIA_ORDNER / "Desktop"


# ---------------------------------------------------------------- Kill-Zähler (kleine Ausschnitte)

@pytest.mark.parametrize("name, zustand, wert", [
    ("6", "wert", 6),            # Totenkopf-Helm-Symbol, Zeile normal
    ("2_rot", "wert", 2),        # rotes Aufblinken beim Spieler-Tod
    ("9", "wert", 9),
    ("18", "wert", 18),          # zweistellig → kleinere Schrift, ohne Squad-Wipe-Spalte
    ("leer", "leer", None),      # nur Schadensanzeige, noch keine Kills/Assists
])
def test_kill_zaehler(name, zustand, wert):
    bild = cv2.imread(str(DATEN / f"apex_zaehler_{name}.png"))
    z, w, _ = lese_kills(bild)
    assert (z, w) == (zustand, wert)


# ---------------------------------------------------------------- Auswertungslogik mit erfundenen Frames

def _f(t, kills=None, zustand=None, knock=0.0, x=100, assist=False, elim=0.0, summary=False, squads=True,
       name=None):
    if zustand is None:
        zustand = "wert" if kills is not None else "unklar"
    return _Frame(t, zustand, kills, squads, knock, x, assist, name, elim, summary, 0.0)


def _name(seed):
    return np.random.default_rng(seed).integers(0, 255, (20, 110)).astype(np.float32)


def _zeiten(n, start=0.0):
    return [start + i * 0.25 for i in range(n)]


def test_zaehler_erhoehung_ergibt_je_kill_ein_event():
    f = [_f(t, 3) for t in _zeiten(20)] + [_f(t, 5) for t in _zeiten(20, 5.0)]
    ev = _kills(f, [True] * len(f), [False] * len(f))
    assert [e.t for e in ev] == [5.0, 5.0]
    assert ev[0].info == "Kill-Zähler 3→4" and ev[1].info == "Kill-Zähler 4→5"


def test_einzelne_fehllesung_loest_nichts_aus():
    f = [_f(t, 3) for t in _zeiten(20)]
    f[10] = _f(f[10].t, 8)
    assert _kills(f, [True] * len(f), [False] * len(f)) == []


def test_zeile_erscheint_nach_leer_zaehlt_ab_null():
    f = [_f(t, zustand="leer") for t in _zeiten(12)] + [_f(t, 1) for t in _zeiten(8, 3.0)]
    ev = _kills(f, [True] * len(f), [False] * len(f))
    assert [(e.t, e.typ) for e in ev] == [(3.0, "kill")]


def test_beim_zuschauen_keine_kills():
    f = ([_f(t, 2) for t in _zeiten(8)] + [_f(t, summary=True) for t in _zeiten(20, 2.0)]
         + [_f(t, 7) for t in _zeiten(8, 7.0)])
    zuschauen = [x.summary for x in f]
    assert _kills(f, [True] * len(f), zuschauen) == []


def test_assist_knock_zaehlt_nicht():
    f = [_f(t, knock=0.85, assist=True) for t in _zeiten(8)]
    assert _knocks(f, [True] * len(f), [False] * len(f)) == []


def test_zwei_knock_meldungen_hintereinander():
    f = [_f(t, knock=0.85, x=232) for t in _zeiten(6)] + [_f(t, knock=0.85, x=260) for t in _zeiten(6, 1.5)]
    ev = _knocks(f, [True] * len(f), [False] * len(f))
    assert [e.t for e in ev] == [0.0, 1.5]


def test_knock_luecke_neuer_name_gleicher_name():
    # gleiche Textlage, ein Frame ohne Meldung: anderer Name → 2 Knocks, gleicher Name → 1 Knock
    a = [_f(t, knock=0.8, x=102, name=_name(1)) for t in _zeiten(8)]
    b = [_f(t, knock=0.8, x=102, name=_name(2)) for t in _zeiten(8, 2.25)]
    luecke = [_f(2.0)]
    f = a + luecke + b
    assert [e.t for e in _knocks(f, [True] * len(f), [False] * len(f))] == [0.0, 2.25]
    c = [_f(t, knock=0.8, x=102, name=_name(1)) for t in _zeiten(8, 2.25)]
    f = a + luecke + c
    assert [e.t for e in _knocks(f, [True] * len(f), [False] * len(f))] == [0.0]


def test_zwischenstaende_behalten_zeitpunkt():
    f = ([_f(t, 2) for t in _zeiten(8)] + [_f(2.0, 3), _f(2.25, 4)] + [_f(t, 5) for t in _zeiten(8, 2.5)])
    ev = _kills(f, [True] * len(f), [False] * len(f))
    assert [e.t for e in ev] == [2.0, 2.25, 2.5]


def test_knock_ausserhalb_eines_matches_zaehlt_nicht():
    f = [_f(t, knock=0.85, squads=False) for t in _zeiten(8)]
    assert _knocks(f, [False] * len(f), [False] * len(f)) == []


def test_tod_nur_nach_normalem_spiel():
    # Aufnahme beginnt schon in der Todes-Zusammenfassung → kein Tod
    assert _tode([_f(t, summary=True) for t in _zeiten(40)]) == []
    f = [_f(t, 1) for t in _zeiten(20)] + [_f(t, summary=True) for t in _zeiten(20, 5.0)]
    assert [e.t for e in _tode(f)] == [5.0]


def test_vergleiche():
    erkannt = [Event(10.0, "kill"), Event(30.0, "kill"), Event(50.0, "knock")]
    soll = [{"t": 10.5, "typ": "kill"}, {"t": 20.0, "typ": "kill"}, {"t": 50.2, "typ": "knock"}]
    r = vergleiche(erkannt, soll, ["kill", "knock"])
    assert r["kill"]["treffer"] == 1 and r["kill"]["verpasst_t"] == [20.0] and r["kill"]["falsch_t"] == [30.0]
    assert r["knock"] == {"treffer": 1, "soll": 1, "falsch": 0, "verpasst_t": [], "falsch_t": []}


def test_profil_und_bereiche():
    assert lade("apex") is apex
    with pytest.raises(ValueError):
        lade("gibtsnicht")
    for b in apex.BEREICHE:
        assert 0 <= b.x < 1 and 0 <= b.y < 1 and b.x + b.b <= 1 and b.y + b.h <= 1
    assert Bereich.px("a", 0, 0, 2560, 1440, 0.5).ziel() == (1280, 720)


# ---------------------------------------------------------------- echte Aufnahmen

def _gt(datei):
    return next(v for v in GT["videos"] if v["datei"] == datei)


GT_SCHNELL = ["Apex Legends 2026.06.30 - 20.08.54.02.DVR.mp4",
              "Apex Legends 2026.05.22 - 15.49.20.03.DVR.mp4"]


@pytest.mark.parametrize("datei", GT_SCHNELL)
@pytest.mark.skipif(not APEX.exists(), reason="keine Apex-Aufnahmen")
def test_ground_truth(datei):
    pfad = APEX / datei
    if not pfad.exists():
        pytest.skip("Aufnahme fehlt")
    v = _gt(datei)
    meldungen = []
    a = erkenne(pfad, fortschritt=lambda x, t: meldungen.append(x))
    r = vergleiche(a.events, v["events"], v["geprueft"])
    for typ, x in r.items():
        assert x["verpasst_t"] == [] and x["falsch_t"] == [], (typ, x)
    assert [e.t for e in a.events] == sorted(e.t for e in a.events)
    assert meldungen and meldungen[-1] == 1.0
    assert a.profil == "apex" and 149 < a.dauer < 151


@pytest.mark.skipif(not DESKTOP.exists() or not any(DESKTOP.glob("*.mp4")), reason="keine Desktop-Aufnahme")
def test_ohne_apex_keine_events():
    pfad = sorted(DESKTOP.glob("*.mp4"), key=lambda p: p.stat().st_size)[0]
    assert erkenne(pfad).events == []


@pytest.mark.skipif(not (APEX / GT_SCHNELL[0]).exists(), reason="Aufnahme fehlt")
def test_abbrechen():
    stopp = threading.Event()

    def fortschritt(anteil, _text):
        if anteil > 0.2:
            stopp.set()

    with pytest.raises(Abgebrochen):
        erkenne(APEX / GT_SCHNELL[0], fortschritt=fortschritt, abbrechen=stopp)


def test_lesen_ohne_dichte_keyframes(tmp_path):
    """Video mit seltenen Keyframes → normal dekodieren und per fps-Filter ausdünnen."""
    import subprocess

    from cutter.erkennung.lesen import keyframe_abstand, lese_bereiche
    from cutter.medien import FFMPEG

    video = tmp_path / "test.mp4"
    subprocess.run([FFMPEG, "-v", "error", "-f", "lavfi", "-i", "testsrc=size=640x360:rate=30:duration=6",
                    "-c:v", "libx264", "-g", "300", "-pix_fmt", "yuv420p", str(video)], check=True)
    assert keyframe_abstand(video) > 1
    bereiche = [Bereich("links", 0, 0, 0.5, 0.5, 0.25), Bereich("rechts", 0.5, 0.5, 0.5, 0.5, 0.125)]
    frames = list(lese_bereiche(video, bereiche, fps=4))
    assert 22 <= len(frames) <= 26
    zeiten = [t for t, _ in frames]
    assert zeiten == sorted(zeiten) and zeiten[-1] > 5
    _, bilder = frames[0]
    assert bilder["links"].shape == (180, 320, 3) and bilder["rechts"].shape == (90, 160, 3)
