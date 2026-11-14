"""Phase 3 – Clips ausschneiden und zu einem Video zusammenfügen. Bereich von Agent 3."""
from __future__ import annotations

from pathlib import Path

from ..schema import Abbruch, Clip, Einstellungen, Fortschritt


def rendere(clips: list[Clip], ziel: str | Path, einstellungen: Einstellungen,
            fortschritt: Fortschritt = None, abbrechen: Abbruch | None = None) -> Path:
    """Schneidet alle aktiven Clips (in Listenreihenfolge) aus und fügt sie zu EINEM mp4 zusammen.

    Clips dürfen aus verschiedenen Videos (auch mit verschiedener Auflösung/fps) stammen.
    Gibt den Pfad der fertigen Datei zurück. Bei Abbruch keine halbe Zieldatei liegen lassen.
    """
    raise NotImplementedError("Phase 3 noch nicht gebaut")


def vorschaubild(video: str | Path, t: float, breite: int = 320) -> bytes:
    """JPEG-Bild des Videos bei Sekunde t (für die Clipliste in der Oberfläche)."""
    raise NotImplementedError("Phase 3 noch nicht gebaut")
