"""Phase 1 – Ereignisse (Kill, Knock, eigener Tod, Champion) im Video erkennen. Bereich von Agent 1."""
from __future__ import annotations

from pathlib import Path

from ..schema import Abbruch, Analyse, Fortschritt

PROFILE = ["apex"]


def erkenne(video: str | Path, profil: str = "apex",
            fortschritt: Fortschritt = None, abbrechen: Abbruch | None = None) -> Analyse:
    """Analysiert ein Video und liefert alle Ereignisse, nach Zeit sortiert.

    - fortschritt(anteil, text) regelmäßig aufrufen (mind. alle ~2 s)
    - abbrechen.is_set() regelmäßig prüfen → Abgebrochen werfen (schema.pruefe_abbruch)
    - Typen: "kill", "knock", "tod" (eigener Tod), "champion"
    """
    raise NotImplementedError("Phase 1 noch nicht gebaut")
