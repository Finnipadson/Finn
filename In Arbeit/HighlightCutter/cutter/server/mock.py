"""Platzhalter für Phase 1–3, solange diese noch NotImplementedError werfen (oder HC_MOCK=1).

Liefert plausible Clips mit echten Videopfaden und Zeiten, einen langsamen Fake-Fortschritt
und einen Mini-Export (wenige Sekunden, kleine Auflösung) – es wird nichts Großes kopiert.
Die Original-Aufnahmen werden nur gelesen.
"""
from __future__ import annotations

import os
import random
import subprocess
import time
from datetime import datetime
from pathlib import Path

from .. import medien, pipeline
from ..schema import Abbruch, Analyse, Clip, Einstellungen, Event, Fortschritt, melde, pruefe_abbruch

PAUSE = float(os.environ.get("HC_MOCK_PAUSE", "0.25"))   # s pro Fake-Schritt (Tests setzen das klein)
SCHRITTE_ANALYSE = 16
SCHRITTE_EXPORT = 20

genutzt = False   # wurde der Platzhalter schon einmal verwendet? (für das Demo-Abzeichen)


def erzwungen() -> bool:
    return os.environ.get("HC_MOCK", "") == "1"


def _dauer(video: str) -> float:
    try:
        return medien.info(video).dauer
    except Exception:  # noqa: BLE001 – Platzhalter, Hauptsache plausibel
        return 900.0


def _grund(events: list[Event]) -> str:
    kills = sum(e.typ == "kill" for e in events)
    if any(e.typ == "champion" for e in events):
        return "Champion"
    if kills == 0 and any(e.typ == "tod" for e in events):
        return "Eigener Tod"
    if kills == 1 and any(e.typ == "knock" for e in events):
        return "Knock → Kill"
    if kills == 1:
        return "Kill"
    if kills == 2:
        return "Doppel-Kill"
    return f"{kills} Kills"


def _erfinde_events(dauer: float, rnd: random.Random, e: Einstellungen) -> list[Event]:
    events: list[Event] = []
    if dauer < 40:
        mitte = dauer * 0.6
        return [Event(round(mitte, 2), "kill", 0.9, "Demo")]
    kaempfe = rnd.randint(2, 6) if dauer > 300 else rnd.randint(1, 2)
    zeiten = sorted(rnd.uniform(35, dauer - 25) for _ in range(kaempfe))
    for t in zeiten:
        muster = rnd.choice(["kill", "kill", "doppel", "knock_kill", "drei"])
        if muster == "kill":
            events.append(Event(round(t, 2), "kill", round(rnd.uniform(0.8, 1), 2), "Demo"))
        elif muster == "doppel":
            events += [Event(round(t, 2), "kill", 0.95, "Demo"),
                       Event(round(t + rnd.uniform(2, 6), 2), "kill", 0.9, "Demo")]
        elif muster == "knock_kill":
            events += [Event(round(t, 2), "knock", 0.9, "Demo"),
                       Event(round(t + rnd.uniform(3, 9), 2), "kill", 0.92, "Demo")]
        else:
            events += [Event(round(t + d, 2), "kill", 0.9, "Demo") for d in (0, 3.1, 6.4)]
    if rnd.random() < 0.5:
        events.append(Event(round(min(dauer - 8, max(zeiten) + 40), 2), "tod", 0.9, "Demo"))
    elif rnd.random() < 0.6:
        events.append(Event(round(dauer - 12, 2), "champion", 0.95, "Demo"))
    return sorted((ev for ev in events if 0 < ev.t < dauer), key=lambda ev: ev.t)


def _plane(analyse: Analyse, e: Einstellungen, rnd: random.Random) -> list[Clip]:
    erlaubt = {"kill", "knock"} | ({"tod"} if e.eigene_tode else set()) | ({"champion"} if e.champion else set())
    gruppen: list[list[Event]] = []
    for ev in analyse.events:
        if ev.typ not in erlaubt:
            continue
        if gruppen and ev.t - gruppen[-1][-1].t <= e.zusammenfassen:
            gruppen[-1].append(ev)
        else:
            gruppen.append([ev])
    clips: list[Clip] = []
    for g in gruppen:
        if all(ev.typ == "knock" for ev in g):
            continue
        start = max(2.0, g[0].t - rnd.uniform(e.fallback_vorlauf, min(e.max_vorlauf, 18)))
        ende = min(analyse.dauer, g[-1].t + e.nachlauf)
        if clips and start <= clips[-1].ende:
            clips[-1].ende = ende
            clips[-1].events += g
            clips[-1].grund = _grund(clips[-1].events)
            continue
        if ende - start >= 1:
            clips.append(Clip(analyse.video, round(start, 2), round(ende, 2), _grund(g), list(g)))
    return clips


def analysiere(videos: list[str], e: Einstellungen, fortschritt: Fortschritt = None,
               abbrechen: Abbruch | None = None) -> tuple[list[Analyse], list[Clip]]:
    global genutzt
    genutzt = True
    analysen: list[Analyse] = []
    alle: list[Clip] = []
    n = max(1, len(videos))
    for i, video in enumerate(videos):
        video = str(Path(video).resolve())
        name = Path(video).name
        dauer = _dauer(video)
        for s in range(SCHRITTE_ANALYSE):
            pruefe_abbruch(abbrechen)
            minute = dauer * s / SCHRITTE_ANALYSE / 60
            melde(fortschritt, (i + s / SCHRITTE_ANALYSE) / n,
                  f"{name}: Suche Kill-Meldungen … Minute {minute:.0f} von {dauer / 60:.0f} (Demo)")
            time.sleep(PAUSE)
        rnd = random.Random(name)
        a = Analyse(video, dauer, "apex", _erfinde_events(dauer, rnd, e))
        analysen.append(a)
        alle += _plane(a, e, rnd)
    melde(fortschritt, 1.0, f"{len(alle)} Clips gefunden (Demo)")
    return analysen, alle


def _mock_ziel(e: Einstellungen) -> Path:
    zusatz = " hochkant" if e.format == "9:16" else ""
    return pipeline.DATEN / "mock-export" / f"Highlights DEMO {datetime.now():%Y-%m-%d %H-%M-%S}{zusatz}.mp4"


def rendere(clips: list[Clip], e: Einstellungen, fortschritt: Fortschritt = None,
            abbrechen: Abbruch | None = None) -> Path:
    """Fake-Export: langsamer Fortschritt, dann ein 4-s-Mini-Video aus dem ersten Clip (640 px)."""
    global genutzt
    genutzt = True
    aktive = [c for c in clips if c.aktiv]
    if not aktive:
        raise ValueError("Kein Clip ausgewählt.")
    for s in range(SCHRITTE_EXPORT):
        pruefe_abbruch(abbrechen)
        nr = min(len(aktive), 1 + s * len(aktive) // SCHRITTE_EXPORT)
        melde(fortschritt, s / SCHRITTE_EXPORT * 0.95, f"Schneide Clip {nr} von {len(aktive)} … (Demo)")
        time.sleep(PAUSE)
    if os.environ.get("HC_MOCK_FEHLER") == "export":
        raise RuntimeError("FFmpeg hat beim Zusammenfügen aufgehört (Demo-Fehler zum Testen).")
    ziel = _mock_ziel(e)
    ziel.parent.mkdir(parents=True, exist_ok=True)
    teil = ziel.with_suffix(".teil.mp4")
    c = aktive[0]
    vf = "scale=-2:640,crop=360:640" if e.format == "9:16" else "scale=640:-2"
    melde(fortschritt, 0.97, "Schreibe Demo-Video …")
    try:
        subprocess.run(
            [medien.FFMPEG, "-y", "-v", "error", "-ss", f"{c.start:.3f}", "-i", c.video, "-t", "4",
             "-vf", vf, "-r", "30", "-c:v", "libx264", "-preset", "ultrafast", "-crf", "30",
             "-c:a", "aac", "-b:a", "96k", str(teil)],
            check=True, capture_output=True, text=True, timeout=60, creationflags=medien.FENSTERLOS)
        teil.replace(ziel)
    finally:
        teil.unlink(missing_ok=True)
    melde(fortschritt, 1.0, "Fertig (Demo)")
    return ziel


def vorschaubild(video: str, t: float, breite: int = 320) -> bytes:
    """Echtes Standbild per FFmpeg; wenn das nicht klappt, ein dunkles Platzhalterbild."""
    try:
        out = subprocess.run(
            [medien.FFMPEG, "-v", "error", "-ss", f"{max(0.0, t):.3f}", "-i", str(video), "-frames:v", "1",
             "-vf", f"scale={breite}:-2", "-q:v", "4", "-f", "image2", "-c:v", "mjpeg", "pipe:1"],
            check=True, capture_output=True, timeout=20, creationflags=medien.FENSTERLOS).stdout
        if out:
            return out
    except Exception:  # noqa: BLE001
        pass
    import cv2
    import numpy as np
    hoehe = breite * 9 // 16
    bild = np.full((hoehe, breite, 3), (28, 22, 18), np.uint8)
    cv2.putText(bild, "kein Bild", (breite // 2 - 50, hoehe // 2 + 6), cv2.FONT_HERSHEY_SIMPLEX, 0.6,
                (120, 110, 100), 1, cv2.LINE_AA)
    return cv2.imencode(".jpg", bild)[1].tobytes()
