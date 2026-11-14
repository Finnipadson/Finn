"""Phase 2 – aus den Ereignissen Clips festlegen. Bereich von Agent 2.

Ablauf von plane_clips():
1. Events filtern: Kill immer; Knock nur, wenn innerhalb `knock_bis_kill` s ein Kill folgt;
   `tod`/`champion` nur mit eingeschaltetem Schalter.
2. Gruppieren: Abstand ≤ `zusammenfassen` s → selber Clip. Ein Knock hält seine Gruppe offen,
   bis sein Kill kommt (Knock → Kill landen immer im selben Clip).
3. Je Gruppe den Kampfbeginn im Ton suchen (ton.kampfbeginn, höchstens `max_vorlauf` s vor dem
   ersten Event); nichts gefunden → `fallback_vorlauf`. Ende = letztes Event + `nachlauf`.
4. Auf [0, dauer] begrenzen, überlappende Clips zusammenlegen, nach Start sortieren.
"""
from __future__ import annotations

from ..schema import (Abbruch, Analyse, Clip, Einstellungen, Event, Fortschritt, melde,
                      pruefe_abbruch)
from . import ton

# Mindestens so viel Vorlauf vor dem ersten Event, auch wenn der Ton den Kampf erst kurz
# vorher findet (sonst beginnt der Clip abrupt mitten im Kill)
MIN_VORLAUF = 3.0


def filtere_events(events: list[Event], e: Einstellungen) -> list[Event]:
    """Nur Events, die ein Highlight ergeben (nach Zeit sortiert)."""
    evs = sorted(events, key=lambda x: x.t)
    kills = [x.t for x in evs if x.typ == "kill"]
    behalten: list[Event] = []
    for ev in evs:
        if ev.typ == "kill":
            behalten.append(ev)
        elif ev.typ == "knock":
            if any(ev.t < k <= ev.t + e.knock_bis_kill for k in kills):
                behalten.append(ev)
        elif ev.typ == "tod":
            if e.eigene_tode:
                behalten.append(ev)
        elif ev.typ == "champion":
            if e.champion:
                behalten.append(ev)
    return behalten


def gruppiere(events: list[Event], e: Einstellungen) -> list[list[Event]]:
    """Events (gefiltert, sortiert) zu Gruppen zusammenfassen."""
    kills = [x.t for x in events if x.typ == "kill"]
    gruppen: list[list[Event]] = []
    offen_bis = float("-inf")    # bis hierhin gehört alles zur aktuellen Gruppe
    for ev in events:
        if gruppen and ev.t <= offen_bis:
            gruppen[-1].append(ev)
        else:
            gruppen.append([ev])
            offen_bis = float("-inf")
        offen_bis = max(offen_bis, ev.t + e.zusammenfassen)
        if ev.typ == "knock":
            folge = [k for k in kills if ev.t < k <= ev.t + e.knock_bis_kill]
            if folge:
                offen_bis = max(offen_bis, folge[0])
    return gruppen


def grund_text(events: list[Event]) -> str:
    """Kurzer deutscher Anzeigetext für einen Clip."""
    n_kill = sum(1 for x in events if x.typ == "kill")
    hat_knock = any(x.typ == "knock" for x in events)
    teile: list[str] = []
    if n_kill == 1:
        teile.append("Knock → Kill" if hat_knock and events[0].typ == "knock" else "Kill")
    elif n_kill == 2:
        teile.append("Doppel-Kill")
    elif n_kill >= 3:
        teile.append(f"{n_kill} Kills")
    if any(x.typ == "champion" for x in events):
        teile.append("Champion")
    if any(x.typ == "tod" for x in events):
        teile.append("Eigener Tod")
    return " + ".join(teile) if teile else "Highlight"


def _clip_grenzen(video: str, gruppe: list[Event], e: Einstellungen, dauer: float,
                  beginn_finden) -> tuple[float, float]:
    erstes, letztes = gruppe[0].t, gruppe[-1].t
    beginn = None
    if e.max_vorlauf > 0:
        try:
            beginn = beginn_finden(video, erstes, e.max_vorlauf)
        except Exception:   # Ton nicht lesbar, Datei fehlt … → Fallback, Planung nicht abbrechen
            beginn = None
    if beginn is None:
        start = erstes - e.fallback_vorlauf
    else:
        start = min(beginn, erstes - min(MIN_VORLAUF, e.fallback_vorlauf))
    ende = letztes + e.nachlauf
    start = max(0.0, start)
    if dauer > 0:
        ende = min(ende, dauer)
        start = min(start, ende)
    return start, ende


def _ton_beginn(video: str, t: float, max_vorlauf: float) -> float | None:
    return ton.kampfbeginn(video, t, max_vorlauf).t


def plane_clips(analyse: Analyse, einstellungen: Einstellungen,
                fortschritt: Fortschritt = None, abbrechen: Abbruch | None = None,
                beginn_finden=_ton_beginn) -> list[Clip]:
    """Legt aus den Events einer Analyse die Clips fest (nach Startzeit sortiert, ohne Überlappung).

    Regeln: siehe SCHNITTSTELLEN.md, Abschnitt Phase 2.
    Liest analyse.video (Tonspur, nur den Bereich vor jedem Clip) für den Kampfbeginn.
    beginn_finden(video, t_event, max_vorlauf) -> float | None ist austauschbar (Tests).
    """
    e = einstellungen
    pruefe_abbruch(abbrechen)
    gruppen = gruppiere(filtere_events(analyse.events, e), e)
    if not gruppen:
        melde(fortschritt, 1.0, "Keine Highlights gefunden")
        return []

    roh: list[tuple[float, float, list[Event]]] = []
    for i, gruppe in enumerate(gruppen):
        pruefe_abbruch(abbrechen)
        melde(fortschritt, i / len(gruppen), f"Kampfbeginn suchen ({i + 1}/{len(gruppen)})")
        start, ende = _clip_grenzen(analyse.video, gruppe, e, analyse.dauer, beginn_finden)
        roh.append((start, ende, list(gruppe)))

    # Überlappende (oder sich berührende) Clips zusammenlegen
    roh.sort(key=lambda r: r[0])
    zusammen: list[tuple[float, float, list[Event]]] = []
    for start, ende, evs in roh:
        if zusammen and start <= zusammen[-1][1]:
            s0, e0, ev0 = zusammen[-1]
            zusammen[-1] = (s0, max(e0, ende), sorted(ev0 + evs, key=lambda x: x.t))
        else:
            zusammen.append((start, ende, evs))

    clips = [Clip(analyse.video, round(float(s), 3), round(float(en), 3), grund_text(evs), evs)
             for s, en, evs in zusammen if en > s]
    melde(fortschritt, 1.0, f"{len(clips)} Clips geplant")
    return clips
