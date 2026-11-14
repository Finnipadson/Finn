"""Tests Phase 3 (Schnitt). Schnell mit synthetischen Videos; echte Aufnahmen nur per skipif.

Synthetische Quelle: schwarzes Bild, jede Sekunde bei x.5 s ein weißer Blitz (1/60 s) und
gleichzeitig ein 1-kHz-Piep (20 ms). Im Ergebnis müssen Blitz und Piep weiter zusammenfallen.
"""
from __future__ import annotations

import json
import os
import subprocess
import threading
import time
from pathlib import Path

import numpy as np
import pytest

from cutter.schema import Abgebrochen, Clip, Einstellungen
from cutter.schnitt import SchnittFehler, erster_sauberer_zeitpunkt, layout, quelle, render, vorschaubild

FFMPEG = "ffmpeg"
FFPROBE = "ffprobe"


# --------------------------------------------------------------------------- Hilfen

def _ffmpeg(*arg: str) -> None:
    subprocess.run([FFMPEG, "-hide_banner", "-v", "error", "-y", *arg], check=True)


def _blitz_quelle(pfad: Path, breite: int, hoehe: int, fps: int, dauer: int, ton: bool) -> Path:
    blitz = "between(mod(t\\,1)\\,0.5\\,0.5+1/60)"
    arg = ["-f", "lavfi", "-i",
           f"color=c=black:s={breite}x{hoehe}:r={fps}:d={dauer},"
           f"drawbox=x=0:y=0:w=iw:h=ih:color=white:t=fill:enable='{blitz}'"]
    if ton:
        arg += ["-f", "lavfi", "-i",
                f"aevalsrc=exprs='if(between(mod(t\\,1)\\,0.5\\,0.52)\\,0.8*sin(2*PI*1000*t)\\,0)'"
                f":s=48000:d={dauer}"]
    arg += ["-c:v", "libx264", "-preset", "ultrafast", "-g", str(fps), "-pix_fmt", "yuv420p"]
    if ton:
        arg += ["-c:a", "aac", "-b:a", "128k"]
    _ffmpeg(*arg, str(pfad))
    return pfad


def _probe(pfad: Path) -> dict:
    out = subprocess.run([FFPROBE, "-v", "error", "-count_frames", "-show_entries",
                          "format=duration:stream=codec_type,codec_name,width,height,r_frame_rate,"
                          "nb_read_frames,sample_rate,channels,duration",
                          "-of", "json", str(pfad)], capture_output=True, text=True, check=True).stdout
    d = json.loads(out)
    return {"format": d["format"],
            "v": next(s for s in d["streams"] if s["codec_type"] == "video"),
            "a": next((s for s in d["streams"] if s["codec_type"] == "audio"), None)}


def _blitze_und_pieps(pfad: Path, fps: int = 60) -> tuple[np.ndarray, np.ndarray]:
    roh = subprocess.run([FFMPEG, "-v", "error", "-i", str(pfad), "-vf", "scale=32:18,format=gray",
                          "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
    hell = np.frombuffer(roh, np.uint8).reshape(-1, 32 * 18).mean(axis=1)
    bilder = np.flatnonzero(hell > 100)
    # zusammenhängende Bilder = ein Blitz → Mitte
    blitze = [g.mean() / fps for g in np.split(bilder, np.flatnonzero(np.diff(bilder) > 1) + 1) if len(g)]
    pcm = subprocess.run([FFMPEG, "-v", "error", "-i", str(pfad), "-ac", "1", "-ar", "48000",
                          "-f", "s16le", "-"], capture_output=True, check=True).stdout
    s = np.abs(np.frombuffer(pcm, np.int16).astype(np.float32))
    huelle = np.convolve(s, np.ones(96) / 96, mode="same")
    an = np.flatnonzero(huelle > 4000)
    pieps = [g[0] / 48000 for g in np.split(an, np.flatnonzero(np.diff(an) > 480) + 1) if len(g)]
    return np.array(blitze), np.array(pieps)


@pytest.fixture(scope="session")
def quellen(tmp_path_factory) -> dict[str, Path]:
    d = tmp_path_factory.mktemp("quellen")
    return {
        # wie die echten Aufnahmen: 16:9, 120 fps, mit Ton (kleiner, damit schnell)
        "a": _blitz_quelle(d / "a.mp4", 1280, 720, 120, 30, True),
        # andere Auflösung, fps, Seitenverhältnis (4:3) und OHNE Ton
        "b": _blitz_quelle(d / "b.mp4", 640, 480, 50, 12, False),
    }


def _clips_blitz(quelle_a: Path, n: int) -> list[Clip]:
    # Start bei x.1 s, Länge 2,2 s → Blitze 0,4 s und 1,4 s nach Clipstart (nie in einer Überblendung)
    return [Clip(str(quelle_a), k + 0.1, k + 2.3, "Test") for k in range(0, 2 * n, 2)]


# --------------------------------------------------------------------------- Planung / Aufbau

def test_layout_groessen():
    a = layout.berechne("16:9", 1080, 2560, 1440)
    assert (a.breite, a.hoehe) == (1920, 1080) and a.nur_skalieren
    h = layout.berechne("9:16", 1080, 2560, 1440)
    assert (h.breite, h.hoehe) == (1080, 1920)
    assert (h.zw_breite, h.zw_hoehe, h.vg_breite, h.vg_hoehe) == (2400, 1350, 1080, 1350)
    w = layout.berechne("16:9", 1080, 3440, 1440)          # 21:9 → eingepasst + Hintergrund
    assert not w.nur_skalieren and w.zw_breite == 1920 and w.zw_hoehe < 1080
    for f in ("16:9", "9:16"):
        for src in ((1280, 720), (640, 480), (3440, 1440), (1080, 1920)):
            x = layout.berechne(f, 1080, *src)
            assert x.vg_breite <= x.breite and x.vg_hoehe <= x.hoehe
            assert all(v % 2 == 0 for v in (x.zw_breite, x.zw_hoehe, x.vg_breite, x.vg_hoehe))


def test_plane_kurze_und_inaktive_clips(monkeypatch):
    info = quelle.VideoInfo("x.mp4", 100.0, 1920, 1080, 120.0, True)
    monkeypatch.setattr(quelle, "info", lambda v: info)
    monkeypatch.setattr(quelle, "erster_sauberer_zeitpunkt", lambda v: 5.0)
    clips = [Clip("x.mp4", 0.0, 4.0, "ganz im kaputten Anfang"),
             Clip("x.mp4", 3.0, 13.0, "Anfang wird gekürzt"),
             Clip("x.mp4", 20.0, 20.4, "kürzer als 2×Übergang"),
             Clip("x.mp4", 30.0, 40.0, "abgewählt", aktiv=False),
             Clip("x.mp4", 50.0, 50.02, "1 Bild – zu kurz"),
             Clip("x.mp4", 95.0, 120.0, "übers Ende")]
    plan = render.plane(clips, Einstellungen(uebergang=0.3, fps=60))
    assert [t.clip.grund for t in plan.teile] == ["Anfang wird gekürzt", "kürzer als 2×Übergang", "übers Ende"]
    assert len(plan.uebersprungen) == 2
    a, b, c = plan.teile
    assert a.start == 5.0 and a.bilder == 480
    assert b.bilder == 24 and b.kopf == 12 and b.ende == 12 and b.mitte == 0   # Übergang halbiert
    assert a.ende == 12 and c.kopf == 12
    assert c.bilder == int(round((100.0 - 2 / 120 - 95.0) * 60))
    assert plan.bilder_gesamt == a.bilder + b.bilder + c.bilder - 24


# --------------------------------------------------------------------------- Rendern (synthetisch)

def test_sync_und_dauer_viele_clips(quellen, tmp_path):
    clips = _clips_blitz(quellen["a"], 12)
    e = Einstellungen(format="16:9", uebergang=0.3, fps=60)
    anteile: list[float] = []
    ziel = render.rendere(clips, tmp_path / "out.mp4", e, lambda a, t: anteile.append(a))
    p = _probe(ziel)
    plan = render.plane(clips, e)
    assert (p["v"]["width"], p["v"]["height"], p["v"]["r_frame_rate"]) == (1920, 1080, "60/1")
    assert int(p["v"]["nb_read_frames"]) == plan.bilder_gesamt == 12 * 132 - 11 * 18
    assert abs(float(p["format"]["duration"]) - plan.dauer) < 0.03
    assert p["a"]["codec_name"] == "aac" and p["a"]["channels"] == 2
    assert abs(float(p["a"]["duration"]) - plan.dauer) < 0.03
    # Fortschritt: monoton, endet bei 1
    assert anteile == sorted(anteile) and anteile[-1] == 1.0
    blitze, pieps = _blitze_und_pieps(ziel)
    assert len(blitze) == 24 and len(pieps) == 24
    versatz = pieps - blitze
    assert np.abs(versatz).max() < 0.02, versatz            # < 1/50 s, auch am Ende (keine Drift)
    assert not list(tmp_path.glob(".hc-*")) and not list(tmp_path.glob("*.teil.mp4"))


def test_hochkant_gemischte_quellen_ohne_ton(quellen, tmp_path):
    clips = [Clip(str(quellen["a"]), 1.0, 3.0, "a"), Clip(str(quellen["b"]), 2.0, 4.5, "b ohne Ton"),
             Clip(str(quellen["a"]), 10.0, 10.3, "a sehr kurz"), Clip(str(quellen["b"]), 0.0, 2.0, "b ab 0")]
    e = Einstellungen(format="9:16", uebergang=0.3, fps=60)
    ziel = render.rendere(clips, tmp_path / "hoch.mp4", e)
    p = _probe(ziel)
    plan = render.plane(clips, e)
    assert (p["v"]["width"], p["v"]["height"]) == (1080, 1920)
    assert int(p["v"]["nb_read_frames"]) == plan.bilder_gesamt
    assert p["a"] is not None and abs(float(p["a"]["duration"]) - plan.dauer) < 0.03


def test_harter_schnitt(quellen, tmp_path):
    clips = _clips_blitz(quellen["a"], 3)
    e = Einstellungen(uebergang=0.0, fps=60)
    ziel = render.rendere(clips, tmp_path / "hart.mp4", e)
    assert int(_probe(ziel)["v"]["nb_read_frames"]) == 3 * 132
    blitze, pieps = _blitze_und_pieps(ziel)
    assert len(blitze) == len(pieps) == 6 and np.abs(pieps - blitze).max() < 0.02


def test_abbruch_loescht_alles(quellen, tmp_path):
    clips = [Clip(str(quellen["a"]), k, k + 3.0, "x") for k in range(0, 27, 3)]
    abbrechen = threading.Event()
    gestartet = threading.Event()

    def fort(anteil: float, text: str) -> None:
        if anteil > 0.05:
            gestartet.set()

    fehler: list[BaseException] = []

    def lauf() -> None:
        try:
            render.rendere(clips, tmp_path / "abbruch.mp4", Einstellungen(format="9:16"), fort, abbrechen)
        except BaseException as e:   # noqa: BLE001
            fehler.append(e)

    t = threading.Thread(target=lauf)
    t.start()
    assert gestartet.wait(30)
    t0 = time.time()
    abbrechen.set()
    t.join(15)
    assert not t.is_alive() and time.time() - t0 < 5
    assert len(fehler) == 1 and isinstance(fehler[0], Abgebrochen)
    assert list(tmp_path.iterdir()) == []                  # keine Teil-/Temp-Dateien


def test_fehler_verstaendlich(tmp_path):
    with pytest.raises(SchnittFehler, match="Keine verwendbaren Clips"):
        render.rendere([Clip(str(tmp_path / "gibtsnicht.mp4"), 0, 5, "x")], tmp_path / "o.mp4", Einstellungen())
    with pytest.raises(SchnittFehler, match="keiner ausgewählt"):
        render.rendere([], tmp_path / "o.mp4", Einstellungen())
    from cutter.schnitt.ffmpeg_lauf import fuehre_aus
    with pytest.raises(SchnittFehler) as info:
        fuehre_aus(["-i", str(tmp_path / "fehlt.mp4"), "-f", "null", "-"], was="Test")
    text = str(info.value)
    assert "Test:" in text and "Letzte FFmpeg-Meldungen" in text and "fehlt.mp4" in text


def test_vorschaubild_schnell(quellen):
    vorschaubild(quellen["a"], 0.0)                         # Cache füllen
    t0 = time.time()
    jpg = vorschaubild(quellen["a"], 12.5, 320)
    assert time.time() - t0 < 1.0
    assert jpg[:2] == b"\xff\xd8" and len(jpg) > 500
    assert vorschaubild(quellen["b"], 999.0)[:2] == b"\xff\xd8"   # hinter dem Ende → letztes Bild


# --------------------------------------------------------------------------- echte Aufnahmen

_ORDNER = Path(os.path.expandvars(r"%USERPROFILE%\Videos\NVIDIA\Apex Legends"))
_KAPUTT = _ORDNER / "Apex Legends 2026.11.09 - 18.55.08.03.DVR.mp4"     # Müll bis ~48,7 s
_SAUBER = _ORDNER / "Apex Legends 2026.10.23 - 23.56.28.03.DVR.mp4"
_echt = pytest.mark.skipif(not (_KAPUTT.exists() and _SAUBER.exists()), reason="echte Aufnahmen fehlen")


@_echt
def test_echt_sauberer_anfang_erkannt():
    assert 48.0 < erster_sauberer_zeitpunkt(_KAPUTT) < 49.5
    assert erster_sauberer_zeitpunkt(_SAUBER) == 0.0


@_echt
def test_echt_clip_ab_null_ohne_kaputte_bilder(tmp_path):
    clips = [Clip(str(_KAPUTT), 0.0, 50.5, "ab 0 (kaputter Anfang)"), Clip(str(_SAUBER), 0.0, 1.5, "ab 0")]
    ziel = render.rendere(clips, tmp_path / "echt.mp4", Einstellungen(uebergang=0.3))
    roh = subprocess.run([FFMPEG, "-v", "error", "-i", str(ziel), "-vf", "scale=160:90",
                          "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    bilder = np.frombuffer(roh, np.uint8).reshape(-1, 90, 160, 3).astype(np.float32)
    assert len(bilder) == int(round((50.5 - erster_sauberer_zeitpunkt(_KAPUTT)) * 60)) + 90 - 18
    # Müllbilder sind fast einfarbig grau/grün → kaum Detail; echte Spielszenen haben viel Detail
    detail = np.abs(np.diff(bilder, axis=2)).mean(axis=(1, 2, 3))
    assert detail.min() > 2.0, detail.argmin()
