"""Hintergrund-Aufträge (Analyse, Export) mit Fortschritt, Abbrechen und verständlichen Fehlertexten."""
from __future__ import annotations

import errno
import subprocess
import threading
import time
import traceback
import uuid
from collections import OrderedDict
from typing import Any, Callable

from ..schema import Abgebrochen

MAX_AUFTRAEGE = 30


class Auftrag:
    def __init__(self, art: str) -> None:
        self.id = uuid.uuid4().hex[:12]
        self.art = art                      # "analyse" | "export"
        self.status = "laeuft"              # laeuft | fertig | fehler | abgebrochen
        self.anteil = 0.0
        self.text = "Startet …"
        self.ergebnis: Any = None
        self.fehler: str | None = None
        self.mock = False
        self.abbrechen = threading.Event()
        self.gestartet = time.time()
        self.beendet: float | None = None
        self._lock = threading.Lock()

    def melde(self, anteil: float, text: str) -> None:
        with self._lock:
            self.anteil = max(0.0, min(1.0, float(anteil)))
            if text:
                self.text = text

    def als_dict(self) -> dict:
        with self._lock:
            return {"id": self.id, "art": self.art, "status": self.status, "anteil": round(self.anteil, 4),
                    "text": self.text, "ergebnis": self.ergebnis, "fehler": self.fehler, "mock": self.mock,
                    "sekunden": round((self.beendet or time.time()) - self.gestartet, 1)}


_auftraege: "OrderedDict[str, Auftrag]" = OrderedDict()
_lock = threading.Lock()


def starte(art: str, arbeit: Callable[[Auftrag], Any]) -> Auftrag:
    """Startet arbeit(auftrag) in einem Thread. Rückgabewert landet in auftrag.ergebnis."""
    a = Auftrag(art)
    with _lock:
        _auftraege[a.id] = a
        while len(_auftraege) > MAX_AUFTRAEGE:
            alt_id, alt = next(iter(_auftraege.items()))
            if alt.status == "laeuft":
                break
            _auftraege.pop(alt_id)

    def lauf() -> None:
        try:
            ergebnis = arbeit(a)
            with a._lock:
                a.ergebnis = ergebnis
                a.anteil = 1.0
                a.status = "fertig"
        except Abgebrochen:
            with a._lock:
                a.status = "abgebrochen"
                a.text = "Abgebrochen"
        except BaseException as exc:  # noqa: BLE001 – alles in einen Fehlertext übersetzen
            if a.abbrechen.is_set():
                with a._lock:
                    a.status = "abgebrochen"
                    a.text = "Abgebrochen"
            else:
                traceback.print_exc()
                with a._lock:
                    a.status = "fehler"
                    a.fehler = menschlich(exc)
        finally:
            a.beendet = time.time()

    threading.Thread(target=lauf, name=f"auftrag-{art}-{a.id}", daemon=True).start()
    return a


def hole(auftrag_id: str) -> Auftrag | None:
    with _lock:
        return _auftraege.get(auftrag_id)


def alle_abbrechen() -> None:
    with _lock:
        for a in _auftraege.values():
            a.abbrechen.set()


def menschlich(exc: BaseException) -> str:
    """Übersetzt eine Ausnahme in einen Satz, mit dem ein Mensch etwas anfangen kann."""
    if isinstance(exc, FileNotFoundError):
        name = getattr(exc, "filename", None)
        if name and str(name).lower().endswith(("ffmpeg", "ffprobe", "ffmpeg.exe", "ffprobe.exe")):
            return "FFmpeg wurde nicht gefunden. Bitte FFmpeg installieren (z. B. „winget install Gyan.FFmpeg“) und die App neu starten."
        return f"Datei nicht gefunden: {name or exc}. Wurde sie verschoben oder gelöscht?"
    if isinstance(exc, PermissionError):
        return f"Kein Zugriff auf {getattr(exc, 'filename', '') or 'eine Datei'}. Ist sie gerade in einem anderen Programm geöffnet?"
    if isinstance(exc, OSError) and exc.errno == errno.ENOSPC:
        return "Auf dem Laufwerk ist kein Platz mehr frei. Bitte Speicher freimachen und nochmal versuchen."
    if isinstance(exc, subprocess.CalledProcessError):
        rest = (exc.stderr or "") if isinstance(exc.stderr, str) else ""
        letzte = rest.strip().splitlines()[-1:] if rest else []
        zusatz = f" ({letzte[0][:160]})" if letzte else ""
        return f"FFmpeg konnte die Datei nicht verarbeiten{zusatz}. Ist die Aufnahme vielleicht beschädigt?"
    if isinstance(exc, subprocess.TimeoutExpired):
        return "FFmpeg hat zu lange nicht reagiert und wurde beendet."
    if isinstance(exc, MemoryError):
        return "Zu wenig Arbeitsspeicher. Bitte andere Programme schließen und nochmal versuchen."
    if isinstance(exc, NotImplementedError):
        return f"Dieser Teil der App ist noch nicht fertig gebaut ({exc})."
    text = str(exc).strip()
    if isinstance(exc, (ValueError, RuntimeError)) and text:
        return text
    return f"Unerwarteter Fehler ({type(exc).__name__}{': ' + text[:200] if text else ''}). Details stehen im Konsolenfenster."
