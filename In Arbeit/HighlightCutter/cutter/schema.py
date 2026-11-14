"""Gemeinsame Datenformate aller Phasen. Nur hier ändern, nicht in den Teilmodulen.

Zeiten sind immer Sekunden (float) ab Beginn der jeweiligen Videodatei.
Alle Objekte lassen sich mit .als_dict() / .aus_dict() nach JSON und zurück wandeln.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Callable, Literal, Protocol

EventTyp = Literal["kill", "knock", "tod", "champion"]
Format = Literal["16:9", "9:16"]

# fortschritt(anteil 0..1, text) – darf None sein
Fortschritt = Callable[[float, str], None] | None


class Abbruch(Protocol):
    """Alles mit is_set(), z. B. threading.Event."""

    def is_set(self) -> bool: ...


class Abgebrochen(Exception):
    """Wird geworfen, wenn abbrechen.is_set() während einer Arbeit True wird."""


@dataclass
class Event:
    t: float                 # Zeitpunkt im Video (s)
    typ: EventTyp
    sicher: float = 1.0      # Konfidenz 0..1
    info: str = ""           # z. B. "Kill-Zähler 3→4"

    def als_dict(self) -> dict:
        return asdict(self)

    @staticmethod
    def aus_dict(d: dict) -> "Event":
        return Event(**d)


@dataclass
class Analyse:
    """Ergebnis von Phase 1 für EIN Video."""
    video: str               # absoluter Pfad
    dauer: float
    profil: str              # z. B. "apex"
    events: list[Event] = field(default_factory=list)

    def als_dict(self) -> dict:
        return {"video": self.video, "dauer": self.dauer, "profil": self.profil,
                "events": [e.als_dict() for e in self.events]}

    @staticmethod
    def aus_dict(d: dict) -> "Analyse":
        return Analyse(d["video"], d["dauer"], d["profil"], [Event.aus_dict(e) for e in d["events"]])


@dataclass
class Clip:
    """Ergebnis von Phase 2: ein Ausschnitt aus einem Video."""
    video: str               # absoluter Pfad
    start: float
    ende: float
    grund: str               # für die Anzeige, z. B. "3 Kills" oder "Knock → Kill"
    events: list[Event] = field(default_factory=list)  # die Events im Clip
    aktiv: bool = True       # in der Oberfläche abwählbar

    @property
    def dauer(self) -> float:
        return self.ende - self.start

    def als_dict(self) -> dict:
        return {"video": self.video, "start": self.start, "ende": self.ende, "grund": self.grund,
                "events": [e.als_dict() for e in self.events], "aktiv": self.aktiv}

    @staticmethod
    def aus_dict(d: dict) -> "Clip":
        return Clip(d["video"], d["start"], d["ende"], d["grund"],
                    [Event.aus_dict(e) for e in d.get("events", [])], d.get("aktiv", True))


@dataclass
class Einstellungen:
    format: Format = "16:9"
    eigene_tode: bool = False      # Clips um eigene Tode mit aufnehmen
    champion: bool = False         # Champion-Sieg mit aufnehmen
    uebergang: float = 0.3         # Überblendung zwischen Clips (s), 0 = harter Schnitt
    fallback_vorlauf: float = 7.0  # wenn kein Kampfbeginn gefunden: s vor dem ersten Event
    nachlauf: float = 3.0          # s nach dem letzten Event
    max_vorlauf: float = 25.0      # Kampfbeginn höchstens so weit vor dem ersten Event
    zusammenfassen: float = 10.0   # Events mit Abstand <= so viel s landen im selben Clip
    knock_bis_kill: float = 20.0   # Knock zählt nur, wenn innerhalb so vieler s ein Kill folgt
    hoehe: int = 1080              # Ausgabehöhe bei 16:9 (bei 9:16 ist das die Breite)
    fps: int = 60

    def als_dict(self) -> dict:
        return asdict(self)

    @staticmethod
    def aus_dict(d: dict) -> "Einstellungen":
        bekannt = Einstellungen.__dataclass_fields__.keys()
        return Einstellungen(**{k: v for k, v in d.items() if k in bekannt})


def melde(fortschritt: Fortschritt, anteil: float, text: str) -> None:
    if fortschritt:
        fortschritt(max(0.0, min(1.0, anteil)), text)


def pruefe_abbruch(abbrechen: Abbruch | None) -> None:
    if abbrechen is not None and abbrechen.is_set():
        raise Abgebrochen()
