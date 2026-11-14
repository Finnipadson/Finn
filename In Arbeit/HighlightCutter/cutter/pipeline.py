"""Verbindet die Phasen. Server und CLI rufen nur diese Funktionen auf."""
from __future__ import annotations

import hashlib
import json
import os
from datetime import datetime
from pathlib import Path

from . import clips as _clips
from . import erkennung as _erkennung
from . import schnitt as _schnitt
from .schema import Abbruch, Analyse, Clip, Einstellungen, Fortschritt, melde, pruefe_abbruch

PROJEKT = Path(__file__).resolve().parent.parent
DATEN = Path(os.environ.get("HC_DATADIR", PROJEKT / "daten"))   # Cache + Einstellungen, gitignored
CACHE = DATEN / "cache"
AUSGABE = Path.home() / "Videos" / "Highlights"

# Erhöhen, wenn sich die Erkennung ändert → alte Cache-Einträge werden ignoriert
ERKENNUNG_VERSION = 3   # 3: kaputter DVR-Anfang wird bei der Erkennung übersprungen


def _cache_datei(video: Path, profil: str) -> Path:
    st = video.stat()
    schluessel = f"{video}|{st.st_size}|{int(st.st_mtime)}|{profil}|{ERKENNUNG_VERSION}"
    return CACHE / (hashlib.sha1(schluessel.encode()).hexdigest()[:16] + ".json")


def erkenne(video: str | Path, profil: str = "apex", cache: bool = True,
            fortschritt: Fortschritt = None, abbrechen: Abbruch | None = None) -> Analyse:
    video = Path(video).resolve()
    datei = _cache_datei(video, profil)
    if cache and datei.exists():
        melde(fortschritt, 1.0, "Aus Zwischenspeicher")
        return Analyse.aus_dict(json.loads(datei.read_text(encoding="utf-8")))
    try:
        sauber = _schnitt.erster_sauberer_zeitpunkt(str(video))
    except Exception:   # noqa: BLE001 – Prüfung ist nur eine Verbesserung
        sauber = 0.0
    analyse = _erkennung.erkenne(video, profil, fortschritt, abbrechen, ab=sauber)
    CACHE.mkdir(parents=True, exist_ok=True)
    datei.write_text(json.dumps(analyse.als_dict(), ensure_ascii=False, indent=1), encoding="utf-8")
    return analyse


def _ohne_kaputten_anfang(clips: list[Clip], video: str | Path) -> list[Clip]:
    """Manche DVR-Dateien sind am Anfang bis zu ~1 min unlesbar: Clips dort kürzen/weglassen,
    damit Oberfläche und Export dieselben Grenzen zeigen."""
    if not clips or clips[0].start > 120:
        return clips
    try:
        sauber = _schnitt.erster_sauberer_zeitpunkt(str(Path(video).resolve()))
    except Exception:   # noqa: BLE001 – Prüfung ist nur eine Verbesserung
        return clips
    if sauber <= 0:
        return clips
    ergebnis = []
    for c in clips:
        if c.ende - 1.0 <= sauber:
            continue
        c.start = max(c.start, round(sauber, 3))
        ergebnis.append(c)
    return ergebnis


def analysiere(videos: list[str | Path], einstellungen: Einstellungen, profil: str = "apex",
               cache: bool = True, fortschritt: Fortschritt = None,
               abbrechen: Abbruch | None = None) -> tuple[list[Analyse], list[Clip]]:
    """Phase 1 + 2 für mehrere Videos. Clips in Video-Reihenfolge, je Video nach Zeit."""
    analysen: list[Analyse] = []
    alle_clips: list[Clip] = []
    n = max(1, len(videos))
    for i, video in enumerate(videos):
        name = Path(video).name

        def teil(anteil: float, text: str, i=i, name=name) -> None:
            melde(fortschritt, (i + anteil) / n, f"{name}: {text}" if n > 1 else text)

        a = erkenne(video, profil, cache, lambda x, t: teil(0.9 * x, t), abbrechen)
        pruefe_abbruch(abbrechen)
        c = _clips.plane_clips(a, einstellungen, lambda x, t: teil(0.9 + 0.1 * x, t), abbrechen)
        c = _ohne_kaputten_anfang(c, video)
        analysen.append(a)
        alle_clips.extend(c)
    melde(fortschritt, 1.0, f"{len(alle_clips)} Clips gefunden")
    return analysen, alle_clips


def standard_ziel(einstellungen: Einstellungen) -> Path:
    zusatz = " hochkant" if einstellungen.format == "9:16" else ""
    return AUSGABE / f"Highlights {datetime.now():%Y-%m-%d %H-%M-%S}{zusatz}.mp4"


def rendere(clips: list[Clip], einstellungen: Einstellungen, ziel: str | Path | None = None,
            fortschritt: Fortschritt = None, abbrechen: Abbruch | None = None) -> Path:
    ziel = Path(ziel) if ziel else standard_ziel(einstellungen)
    ziel.parent.mkdir(parents=True, exist_ok=True)
    return _schnitt.rendere(clips, ziel, einstellungen, fortschritt, abbrechen)


def vorschaubild(video: str | Path, t: float, breite: int = 320) -> bytes:
    return _schnitt.vorschaubild(video, t, breite)
