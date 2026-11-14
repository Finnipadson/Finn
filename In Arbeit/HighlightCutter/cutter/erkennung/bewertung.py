"""Erkannte Events mit einer Referenzliste (Ground Truth) vergleichen."""
from __future__ import annotations

from ..schema import Event


def vergleiche(erkannt: list[Event], soll: list[dict], typen: list[str],
               toleranz: float = 1.5) -> dict[str, dict]:
    """Je Typ: treffer, soll, falsch + Zeiten der verpassten/falschen Events (1:1-Zuordnung)."""
    out = {}
    for typ in typen:
        s = sorted(e["t"] for e in soll if e["typ"] == typ)
        e = sorted(x.t for x in erkannt if x.typ == typ)
        frei = list(e)
        verpasst = []
        for ts in s:
            passend = [x for x in frei if abs(x - ts) <= toleranz]
            if passend:
                frei.remove(min(passend, key=lambda x: abs(x - ts)))
            else:
                verpasst.append(ts)
        out[typ] = {"treffer": len(s) - len(verpasst), "soll": len(s), "falsch": len(frei),
                    "verpasst_t": verpasst, "falsch_t": frei}
    return out
