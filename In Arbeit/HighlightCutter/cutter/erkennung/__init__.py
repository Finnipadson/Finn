"""Phase 1 – Ereignisse (Kill, Knock, eigener Tod, Champion) im Video erkennen. Bereich von Agent 1."""
from __future__ import annotations

import time
from pathlib import Path

from .. import medien
from ..schema import Abbruch, Analyse, Fortschritt, melde, pruefe_abbruch
from . import profile as _profile
from .lesen import lese_bereiche

PROFILE = _profile.PROFILE


def erkenne(video: str | Path, profil: str = "apex",
            fortschritt: Fortschritt = None, abbrechen: Abbruch | None = None,
            ab: float = 0.0) -> Analyse:
    """Analysiert ein Video und liefert alle Ereignisse, nach Zeit sortiert.

    - fortschritt(anteil, text) regelmäßig aufrufen (mind. alle ~2 s)
    - abbrechen.is_set() regelmäßig prüfen → Abgebrochen werfen (schema.pruefe_abbruch)
    - Typen: "kill", "knock", "tod" (eigener Tod), "champion"
    - ab: Frames davor werden nicht ausgewertet. NVIDIA-DVR-Dateien enthalten am Anfang oft kaputte
      Frames mit veralteten HUD-Resten aus dem Ringpuffer (z. B. den Kill-Stand vom Ende der Aufnahme);
      die würden den Zähler falsch vorbelegen und echte Kills später verschlucken.
    """
    video = Path(video).resolve()
    modul = _profile.lade(profil)
    pruefe_abbruch(abbrechen)
    melde(fortschritt, 0.0, "Video wird geöffnet")
    info = medien.info(video)
    dauer = max(info.dauer, 0.001)
    auswertung = modul.neue_auswertung()

    letzte_meldung = 0.0
    frames = lese_bereiche(video, modul.BEREICHE, fps=modul.FPS)
    try:
        for t, bilder in frames:
            pruefe_abbruch(abbrechen)
            if t >= ab:
                auswertung.frame(t, bilder)
            jetzt = time.monotonic()
            if jetzt - letzte_meldung >= 0.5:
                letzte_meldung = jetzt
                melde(fortschritt, 0.98 * t / dauer, f"Erkennung {_mmss(t)} / {_mmss(dauer)}")
    finally:
        frames.close()   # beendet FFmpeg auch bei Abbruch

    events = auswertung.ergebnis(dauer)
    melde(fortschritt, 1.0, f"{len(events)} Ereignisse erkannt")
    return Analyse(str(video), round(info.dauer, 3), profil, events)


def _mmss(s: float) -> str:
    s = int(max(0, s))
    return f"{s // 60}:{s % 60:02d}"
