"""Phase 2 – aus den Ereignissen Clips festlegen. Bereich von Agent 2."""
from __future__ import annotations

from ..schema import Abbruch, Analyse, Clip, Einstellungen, Fortschritt


def plane_clips(analyse: Analyse, einstellungen: Einstellungen,
                fortschritt: Fortschritt = None, abbrechen: Abbruch | None = None) -> list[Clip]:
    """Legt aus den Events einer Analyse die Clips fest (nach Startzeit sortiert, ohne Überlappung).

    Regeln: siehe SCHNITTSTELLEN.md, Abschnitt Phase 2.
    Darf analyse.video lesen (z. B. Tonspur für den Kampfbeginn).
    """
    raise NotImplementedError("Phase 2 noch nicht gebaut")
