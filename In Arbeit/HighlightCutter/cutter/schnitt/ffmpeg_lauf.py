"""FFmpeg starten, Fortschritt lesen, abbrechen, Fehler verständlich machen."""
from __future__ import annotations

import collections
import queue
import re
import subprocess
import threading
import time
from typing import Callable

from ..medien import FENSTERLOS, FFMPEG
from ..schema import Abbruch, Abgebrochen

# Meldungen, die bei den NVIDIA-DVR-Dateien massenhaft kommen und nichts bedeuten
# (sie stammen vom Stream-Probing über den kaputten Dateianfang)
_RAUSCHEN = re.compile(
    r"error while decoding MB|no frame!|missing picture|Frame num change|illegal POC|out of range|"
    r"Clipping illegal|Failed to parse header of NALU|concealing|decode_slice_header error|"
    r"non-existing PPS|reference picture missing|mmco: unref|Fontconfig")


class SchnittFehler(RuntimeError):
    """Verständlicher Fehler beim Schneiden (deutsch, mit den letzten FFmpeg-Zeilen)."""


def _erklaere(stderr: str) -> str:
    s = stderr.lower()
    if "no space left" in s or "not enough space" in s:
        return "Auf dem Ziellaufwerk ist nicht genug Speicherplatz frei."
    if "permission denied" in s:
        return "Keine Schreib- oder Leserechte (Datei vielleicht in einem anderen Programm geöffnet)."
    if "no such file" in s:
        return "Eine Datei wurde nicht gefunden."
    if "nvenc" in s or "cuda" in s or "nvdec" in s or "cuvid" in s:
        return "Die Grafikkarten-Beschleunigung (NVENC/CUDA) ist fehlgeschlagen."
    if "invalid data found" in s or "moov atom not found" in s:
        return "Ein Quellvideo ist beschädigt oder kein gültiges Video."
    return "FFmpeg ist mit einem Fehler abgebrochen."


def _beende(proc: subprocess.Popen) -> None:
    """FFmpeg unter Windows sauber beenden: erst 'q' (regulärer Stopp), dann hart."""
    if proc.poll() is not None:
        return
    try:
        if proc.stdin:
            proc.stdin.write(b"q")
            proc.stdin.flush()
    except OSError:
        pass
    try:
        proc.wait(timeout=2)
        return
    except subprocess.TimeoutExpired:
        pass
    proc.kill()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass


def fuehre_aus(argumente: list[str], *, dauer: float = 0.0,
               fortschritt: Callable[[float], None] | None = None,
               abbrechen: Abbruch | None = None, was: str = "FFmpeg") -> None:
    """Startet FFmpeg mit `argumente` (ohne das Programm selbst).

    dauer: erwartete Ausgabedauer in s, damit `out_time` aus `-progress` in einen Anteil 0..1
    umgerechnet werden kann. Wirft `Abgebrochen` (Prozess beendet) oder `SchnittFehler`.
    """
    befehl = [FFMPEG, "-hide_banner", "-nostats", "-y", "-progress", "pipe:1", *argumente]
    try:
        proc = subprocess.Popen(befehl, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, creationflags=FENSTERLOS)
    except OSError as e:
        raise SchnittFehler(f"{was}: FFmpeg konnte nicht gestartet werden ({e}). "
                            f"Ist FFmpeg installiert und im PATH?") from e
    letzte = collections.deque(maxlen=40)
    zeilen: queue.Queue[str | None] = queue.Queue()

    def lies_stderr() -> None:
        for roh in proc.stderr:  # type: ignore[union-attr]
            zeile = roh.decode("utf-8", "replace").rstrip()
            if zeile and not _RAUSCHEN.search(zeile):
                letzte.append(zeile)

    def lies_stdout() -> None:
        for roh in proc.stdout:  # type: ignore[union-attr]
            zeilen.put(roh.decode("utf-8", "replace").strip())
        zeilen.put(None)

    leser = [threading.Thread(target=lies_stderr, daemon=True),
             threading.Thread(target=lies_stdout, daemon=True)]
    for t in leser:
        t.start()

    try:
        fertig = False
        while not fertig:
            if abbrechen is not None and abbrechen.is_set():
                _beende(proc)
                raise Abgebrochen()
            try:
                zeile = zeilen.get(timeout=0.1)
            except queue.Empty:
                continue
            if zeile is None:
                fertig = True
                continue
            if fortschritt and dauer > 0 and zeile.startswith("out_time_us="):
                try:
                    us = int(zeile.split("=", 1)[1])
                except ValueError:
                    continue
                fortschritt(max(0.0, min(1.0, us / 1e6 / dauer)))
        proc.wait()
    except BaseException:
        _beende(proc)
        raise
    finally:
        for t in leser:
            t.join(timeout=2)
        for strom in (proc.stdin, proc.stdout, proc.stderr):
            try:
                if strom:
                    strom.close()
            except OSError:
                pass

    if proc.returncode != 0:
        if abbrechen is not None and abbrechen.is_set():
            raise Abgebrochen()
        rest = "\n".join(list(letzte)[-8:])
        raise SchnittFehler(f"{was}: {_erklaere(rest)}\n\nLetzte FFmpeg-Meldungen:\n{rest}")
    if fortschritt:
        fortschritt(1.0)


def loesche_sicher(pfad) -> None:
    """Datei löschen; unter Windows kurz nach Prozessende evtl. noch gesperrt → wiederholen."""
    from pathlib import Path
    p = Path(pfad)
    for _ in range(20):
        try:
            p.unlink(missing_ok=True)
            return
        except PermissionError:
            time.sleep(0.1)
