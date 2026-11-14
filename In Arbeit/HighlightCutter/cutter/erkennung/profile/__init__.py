"""Spielprofile: je Spiel ein Modul mit NAME, FPS, BEREICHE und neue_auswertung()."""
from __future__ import annotations

import importlib
from types import ModuleType

PROFILE = ["apex"]


def lade(name: str) -> ModuleType:
    if name not in PROFILE:
        raise ValueError(f"Unbekanntes Spielprofil: {name!r} (vorhanden: {', '.join(PROFILE)})")
    return importlib.import_module(f"{__name__}.{name}")
