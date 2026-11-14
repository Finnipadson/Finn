"""Tests Phase 2 (cutter.clips): Regeln mit synthetischen Events + Kampfbeginn an echten Aufnahmen."""
from __future__ import annotations

import json
import subprocess
import sys
import threading
import time
import wave
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from cutter.clips import grund_text, plane_clips, ton  # noqa: E402
from cutter.schema import Abgebrochen, Analyse, Einstellungen, Event  # noqa: E402

DATEN = Path(__file__).resolve().parent / "daten"
ORDNER = Path.home() / "Videos" / "NVIDIA" / "Apex Legends"
WAHRHEIT = json.loads((DATEN / "clips_wahrheit.json").read_text(encoding="utf-8"))


def ohne_ton(video, t, max_vorlauf):
    return None          # → immer fallback_vorlauf


def fest(vorlauf):
    return lambda video, t, max_vorlauf: t - min(vorlauf, max_vorlauf)


def plane(events, dauer=600.0, finder=ohne_ton, **einst):
    a = Analyse("x.mp4", dauer, "apex", [Event(t, typ) for t, typ in events])
    return plane_clips(a, Einstellungen(**einst), beginn_finden=finder)


# ---------------------------------------------------------------- Regeln

def test_leere_liste():
    assert plane([]) == []


def test_einzelner_kill_mit_fallback():
    (c,) = plane([(100, "kill")])
    assert (c.start, c.ende, c.grund) == (93.0, 103.0, "Kill")
    assert [x.typ for x in c.events] == ["kill"]


def test_knock_ohne_kill_wird_verworfen():
    assert plane([(50, "knock")]) == []
    # Kill kommt zu spät (> knock_bis_kill)
    clips = plane([(50, "knock"), (80, "kill")])
    assert len(clips) == 1 and [x.typ for x in clips[0].events] == ["kill"]


def test_knock_dann_kill_ein_clip_auch_ueber_zusammenfassen_hinaus():
    # 15 s Abstand > zusammenfassen (10), aber < knock_bis_kill (20) → ein Clip
    (c,) = plane([(50, "knock"), (65, "kill")])
    assert c.grund == "Knock → Kill"
    assert c.start == 43.0 and c.ende == 68.0
    assert [x.typ for x in c.events] == ["knock", "kill"]


def test_drei_kills_in_15_s():
    (c,) = plane([(100, "kill"), (107, "kill"), (115, "kill")])
    assert c.grund == "3 Kills" and c.start == 93.0 and c.ende == 118.0


def test_doppel_kill_und_getrennte_clips():
    clips = plane([(100, "kill"), (104, "kill"), (200, "kill")])
    assert [c.grund for c in clips] == ["Doppel-Kill", "Kill"]
    assert clips[0].ende < clips[1].start


def test_ueberlappung_wird_zusammengelegt():
    # Abstand 8 s > zusammenfassen (5), aber Clip 2 beginnt (Fallback 7 s) vor Ende von Clip 1 (+3 s)
    clips = plane([(100, "kill"), (108, "kill")], zusammenfassen=5)
    assert len(clips) == 1 and clips[0].grund == "Doppel-Kill"
    assert (clips[0].start, clips[0].ende) == (93.0, 111.0)
    # mit langem Ton-Vorlauf überlappen auch weiter entfernte Kills
    clips = plane([(100, "kill"), (120, "kill")], finder=fest(20))
    assert len(clips) == 1 and (clips[0].start, clips[0].ende) == (80.0, 123.0)


def test_keine_ueberlappung_und_sortiert():
    zeiten = [5, 31, 33, 60, 90, 95, 140, 141, 300]
    clips = plane([(t, "kill") for t in reversed(zeiten)], finder=fest(15))
    assert all(a.ende <= b.start for a, b in zip(clips, clips[1:]))
    assert [c.start for c in clips] == sorted(c.start for c in clips)
    assert sum(len(c.events) for c in clips) == len(zeiten)


def test_raender_0_und_dauer():
    (c,) = plane([(2, "kill")], dauer=50)
    assert c.start == 0.0 and c.ende == 5.0
    (c,) = plane([(49, "kill")], dauer=50)
    assert c.start == 42.0 and c.ende == 50.0
    (c,) = plane([(1, "kill")], dauer=50, finder=fest(20))
    assert c.start == 0.0


def test_schalter_tod_und_champion():
    ev = [(100, "kill"), (200, "tod"), (300, "champion")]
    assert [c.grund for c in plane(ev)] == ["Kill"]
    assert [c.grund for c in plane(ev, eigene_tode=True)] == ["Kill", "Eigener Tod"]
    assert [c.grund for c in plane(ev, champion=True)] == ["Kill", "Champion"]
    (c,) = plane([(100, "kill"), (104, "champion")], champion=True)
    assert c.grund == "Kill + Champion"
    # Tod allein ohne Schalter → nichts
    assert plane([(50, "tod"), (60, "champion")]) == []


def test_ton_beginn_und_mindestvorlauf():
    # Ton findet Beginn 15 s vorher → Start dort
    (c,) = plane([(100, "kill")], finder=fest(15))
    assert c.start == 85.0
    # Ton findet Beginn nur 0,5 s vorher → mindestens MIN_VORLAUF
    (c,) = plane([(100, "kill")], finder=fest(0.5))
    assert c.start == 97.0


def test_tonfehler_fuehrt_zu_fallback():
    def kaputt(video, t, mv):
        raise RuntimeError("kein Ton")
    (c,) = plane([(100, "kill")], finder=kaputt)
    assert c.start == 93.0


def test_grund_texte():
    k = lambda t, typ="kill": Event(t, typ)  # noqa: E731
    assert grund_text([k(1)]) == "Kill"
    assert grund_text([k(1, "knock"), k(2)]) == "Knock → Kill"
    assert grund_text([k(1), k(2)]) == "Doppel-Kill"
    assert grund_text([k(1, "knock"), k(2), k(3), k(4)]) == "3 Kills"
    assert grund_text([k(1, "champion")]) == "Champion"
    assert grund_text([k(1, "tod")]) == "Eigener Tod"


def test_fortschritt_und_abbruch():
    meldungen = []
    a = Analyse("x.mp4", 600, "apex", [Event(t, "kill") for t in (50, 150, 250)])
    plane_clips(a, Einstellungen(), lambda x, t: meldungen.append((x, t)), beginn_finden=ohne_ton)
    assert meldungen[-1][0] == 1.0 and len(meldungen) == 4
    assert all(0 <= x <= 1 for x, _ in meldungen)
    stopp = threading.Event()
    stopp.set()
    with pytest.raises(Abgebrochen):
        plane_clips(a, Einstellungen(), None, stopp, beginn_finden=ohne_ton)


def test_als_dict_rundreise():
    from cutter.schema import Clip
    (c,) = plane([(50, "knock"), (55, "kill")])
    assert Clip.aus_dict(json.loads(json.dumps(c.als_dict()))) == c


# ---------------------------------------------------------------- reine Ton-Logik

def test_beginn_aus_kampf():
    f = ton.beginn_aus_kampf
    assert f([], 100, 25) is None
    assert f([80.0], 100, 25) is None                      # letzter Kampflärm zu lange her
    assert f([95.0, 96.0, 99.0], 100, 25) == 94.0          # erster Schuss − Puffer
    assert f([80.0, 89.0, 95.0, 99.0], 100, 25) == 79.0    # Lücken ≤ 10 s werden überbrückt
    assert f([60.0, 95.0, 99.0], 100, 25) == 94.0          # Lücke > 10 s trennt
    assert f([70.0, 78.0, 86.0, 94.0, 99.0], 100, 25) == 75.0   # Gefecht reicht weiter → max_vorlauf
    assert f([60.0, 78.0, 86.0, 94.0, 99.0], 100, 25) == 77.0   # Gefecht beginnt innerhalb
    assert f([0.3, 2.0, 5.0], 6.5, 25) == 0.0              # nie vor Dateianfang


def test_salve_und_knall():
    S = ton.Spitze
    leise = [S(t, -16, -10) for t in (1.0, 1.3)]              # nur 2 Spitzen → keine Salve
    assert ton.kampf_zeitpunkte(leise) == []
    salve = [S(t, -16, -10) for t in (1.0, 1.2, 1.5, 3.0)]
    assert ton.kampf_zeitpunkte(salve) == [1.0, 1.2, 1.5]
    knall = [S(5.0, -8, -5)]
    assert ton.kampf_zeitpunkte(knall) == [5.0]


def test_rauschen_und_sinus_sind_kein_kampf():
    rng = np.random.default_rng(1)
    x = (rng.normal(0, 0.01, ton.SR * 20)).astype(np.float32)
    t = np.arange(len(x)) / ton.SR
    x += 0.3 * np.sin(2 * np.pi * 220 * t).astype(np.float32) * (np.sin(2 * np.pi * 3 * t) > 0)
    m = ton.merkmale(x, 0)
    assert ton.kampf_zeitpunkte(ton.finde_spitzen(x, m)) == []


def test_kuenstliche_salve_wird_gefunden():
    rng = np.random.default_rng(2)
    x = rng.normal(0, 0.003, ton.SR * 30).astype(np.float32)
    for k in range(12):                                   # 12 Schüsse ab 20 s, 8 pro Sekunde
        a = int((20 + k * 0.125) * ton.SR)
        n = int(0.06 * ton.SR)
        tn = np.arange(n) / ton.SR
        huelle = np.exp(-tn / 0.012).astype(np.float32)
        knall = rng.normal(0, 1, n) + 4 * np.sin(2 * np.pi * 90 * tn)   # Rauschen + Bass-Wumms
        x[a:a + n] += 0.4 * knall.astype(np.float32) * huelle
    m = ton.merkmale(x, 0)
    kampf = ton.kampf_zeitpunkte(ton.finde_spitzen(x, m))
    assert kampf and 19.9 < kampf[0] < 20.2
    assert ton.beginn_aus_kampf(kampf, 22.0, 25) == pytest.approx(kampf[0] - ton.PUFFER_S)


# ---------------------------------------------------------------- echte Aufnahmen

def _kaempfe():
    for v in WAHRHEIT["videos"]:
        for k in v["kaempfe"]:
            yield pytest.param(v["datei"], k, id=f"{v['datei'][13:29]}@{k['erstes_event']}")


def _ruhige():
    for v in WAHRHEIT["videos"]:
        for r in v["ruhig"]:
            yield pytest.param(v["datei"], r["t"], id=f"{v['datei'][13:29]}@{r['t']}")


TOLERANZ_S = 4.0   # Abstand zum akzeptierten Bereich


@pytest.mark.parametrize("datei,kampf", list(_kaempfe()))
def test_kampfbeginn_echt(datei, kampf):
    pfad = ORDNER / datei
    if not pfad.exists():
        pytest.skip("Aufnahme fehlt")
    t0 = time.perf_counter()
    b = ton.kampfbeginn(str(pfad), kampf["erstes_event"], 25.0)
    assert time.perf_counter() - t0 < 1.5
    assert b.t is not None, "kein Kampf gefunden"
    abw = 0.0 if kampf["frueh"] <= b.t <= kampf["spaet"] else min(abs(b.t - kampf["frueh"]), abs(b.t - kampf["spaet"]))
    assert abw <= TOLERANZ_S, f"Beginn {b.t:.2f}, erwartet {kampf['frueh']}..{kampf['spaet']}"


@pytest.mark.parametrize("datei,t", list(_ruhige()))
def test_ruhige_stelle_echt(datei, t):
    pfad = ORDNER / datei
    if not pfad.exists():
        pytest.skip("Aufnahme fehlt")
    assert ton.kampfbeginn(str(pfad), t, 25.0).t is None


def test_plane_clips_echtes_video():
    v = WAHRHEIT["videos"][0]
    pfad = ORDNER / v["datei"]
    if not pfad.exists():
        pytest.skip("Aufnahme fehlt")
    events = [Event(**e) for e in v["events"]]
    # Phase 1 würde die Knocks 82,5–92,5 und 110,5–116,5 mit Kills abschließen; hier simuliert
    events += [Event(93.5, "kill"), Event(117.0, "kill")]
    a = Analyse(str(pfad), 150.2, "apex", events)
    meldungen = []
    t0 = time.perf_counter()
    clips = plane_clips(a, Einstellungen(), lambda x, t: meldungen.append(t))
    dauer = time.perf_counter() - t0
    assert dauer < 1.0 * len(clips) + 0.5
    assert [c.grund for c in clips] == ["Knock → Kill"] * 3
    erwartet = [k for k in v["kaempfe"]]
    for c, k in zip(clips, erwartet):
        assert k["frueh"] - TOLERANZ_S <= c.start <= k["spaet"] + TOLERANZ_S
    assert clips[0].ende == pytest.approx(54.5)
    assert all(a.ende <= b.start for a, b in zip(clips, clips[1:]))


def _tts(ziel: Path) -> bool:
    """Deutsche Testsprache mit der Windows-Sprachausgabe erzeugen (Ersatz für Discord-Stimmen)."""
    skript = (
        "Add-Type -AssemblyName System.Speech;"
        "$s=New-Object System.Speech.Synthesis.SpeechSynthesizer;"
        "$f=New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(24000,"
        "[System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,[System.Speech.AudioFormat.AudioChannel]::Mono);"
        f"$s.SetOutputToWaveFile('{ziel}',$f);"
        "$s.Speak('Achtung, da rechts im Gebaeude sind zwei Leute. Ich habe einen angeschossen, der hat keinen "
        "Schild mehr. Pass auf, die kommen von hinten! Schnell, heil dich, ich mache Deckung. Siehst du den "
        "Sniper auf dem Dach? Okay, ich lade nach, gib mir zwei Sekunden. Wir muessen in die Zone.');$s.Dispose()")
    try:
        subprocess.run(["powershell", "-NoProfile", "-Command", skript], check=True, timeout=60,
                       capture_output=True)
    except Exception:
        return False
    return ziel.exists() and ziel.stat().st_size > 10000


def test_sprache_ist_kein_kampf(tmp_path):
    """Laute Sprache über einer ruhigen Stelle darf keinen Kampfbeginn erzeugen."""
    v = WAHRHEIT["videos"][0]
    pfad = ORDNER / v["datei"]
    if not pfad.exists():
        pytest.skip("Aufnahme fehlt")
    wav = tmp_path / "sprache.wav"
    if not _tts(wav):
        pytest.skip("Windows-Sprachausgabe nicht verfügbar")
    with wave.open(str(wav)) as w:
        sp = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float32) / 32768
    for t_ruhig in (43.0, 142.0):
        t0 = t_ruhig - 30
        x = ton.lese_ton(str(pfad), t0, 40)
        for gain_db in (0, 10):            # Sprache so laut wie das Spiel bzw. 10 dB lauter
            s = sp * (np.sqrt(np.mean(x ** 2)) / np.sqrt(np.mean(sp ** 2))) * 10 ** (gain_db / 20)
            y = x.copy()
            a = max(0, int(30 * ton.SR) - len(s))
            s = s[:len(y) - a]
            y[a:a + len(s)] += s
            y = np.clip(y, -1, 1)
            kampf = ton.kampf_zeitpunkte(ton.finde_spitzen(y, ton.merkmale(y, t0)))
            assert ton.beginn_aus_kampf(kampf, t_ruhig, 25) is None, (t_ruhig, gain_db)
