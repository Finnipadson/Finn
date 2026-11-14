"""Bildausschnitte schnell aus einem Video lesen (FFmpeg → Pipe → NumPy).

Es werden nur kleine HUD-Ausschnitte erzeugt. Liegen die Keyframes dicht genug (NVIDIA-Aufnahmen:
alle 0,25 s), dekodiert FFmpeg nur diese (`-skip_frame nokey`) – das ist etwa 30× schneller als
jedes Bild zu dekodieren. Sonst wird normal dekodiert und per `fps`-Filter ausgedünnt.
"""
from __future__ import annotations

import re
import subprocess
import threading
import time
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator

import numpy as np

from ..medien import FENSTERLOS, FFMPEG, FFPROBE

# Bezugsgröße: alle Pixelangaben der Profile beziehen sich auf ein 2560×1440-Bild
REF_B, REF_H = 2560, 1440
# So lange darf FFmpeg ohne ein einziges Bild bleiben, bevor der Lauf als hängend gilt (s)
WACHHUND_S = 60.0


@dataclass(frozen=True)
class Bereich:
    """Rechteck relativ zur Bildgröße (0..1) + Skalierung gegenüber der Bezugsgröße 2560×1440."""
    name: str
    x: float
    y: float
    b: float
    h: float
    skala: float = 1.0

    @staticmethod
    def px(name: str, x: int, y: int, b: int, h: int, skala: float = 1.0) -> "Bereich":
        """Bequem in Pixeln eines 2560×1440-Bildes angeben."""
        return Bereich(name, x / REF_B, y / REF_H, b / REF_B, h / REF_H, skala)

    def ziel(self) -> tuple[int, int]:
        """Ausgabegröße in Pixeln (gerade Zahlen)."""
        w = max(2, int(round(self.b * REF_B * self.skala / 2)) * 2)
        h = max(2, int(round(self.h * REF_H * self.skala / 2)) * 2)
        return w, h


def keyframe_abstand(video: str | Path, sekunden: float = 20.0) -> float:
    """Mittlerer Abstand der Keyframes (s) in einem Stück aus der Dateimitte; inf, wenn unklar."""
    try:
        dauer = float(subprocess.run(
            [FFPROBE, "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(video)],
            capture_output=True, text=True, creationflags=FENSTERLOS, timeout=30).stdout.strip() or 0)
        start = max(0.0, dauer / 2 - sekunden / 2)
        out = subprocess.run(
            [FFPROBE, "-v", "error", "-select_streams", "v:0", "-read_intervals", f"{start}%+{sekunden}",
             "-show_entries", "packet=pts_time,flags", "-of", "csv=p=0", str(video)],
            capture_output=True, text=True, creationflags=FENSTERLOS, timeout=60).stdout
    except (subprocess.SubprocessError, ValueError, OSError):
        return float("inf")
    zeiten = sorted(float(z.split(",")[0]) for z in out.splitlines()
                    if "K" in z.split(",")[-1] and z.split(",")[0] not in ("", "N/A"))
    if len(zeiten) < 3:
        return float("inf")
    return (zeiten[-1] - zeiten[0]) / (len(zeiten) - 1)


_PTS = re.compile(rb"pts_time:\s*(-?[\d.]+)")


def lese_bereiche(video: str | Path, bereiche: list[Bereich], fps: float = 4.0,
                  nur_keyframes: bool | None = None, hwaccel: str | None = "d3d11va",
                  dauer: float | None = None, max_neustarts: int = 300,
                  ) -> Iterator[tuple[float, dict[str, np.ndarray]]]:
    """Liefert (t, {name: BGR-Bild}) für jeden ausgewerteten Frame, zeitlich aufsteigend.

    nur_keyframes=None → automatisch: wenn Keyframes höchstens 1/fps·1,6 s auseinanderliegen.

    Manche NVIDIA-Aufnahmen enthalten mitten im Strom kaputte Pakete (Frames mit unsinniger Größe);
    FFmpeg bricht dort mit „Error reinitializing filters“ ab. Endet FFmpeg vor dem Dateiende, wird
    deshalb hinter der letzten gelesenen Stelle neu angesetzt (-ss, Zeitstempel bleiben erhalten),
    dann ohne Hardware-Dekodierung.
    """
    video = str(video)
    if nur_keyframes is None:
        nur_keyframes = keyframe_abstand(video) <= 1.6 / fps
    if dauer is None:
        dauer = _dauer(video)
    start = 0.0
    letzte = -1.0
    abstand = 0.8 / fps     # nie dichter als fps ausgeben
    hw = hwaccel
    for _ in range(max_neustarts + 1):
        neu = 0
        zu_dicht = False
        roh: deque[float] = deque()
        lauf = _ein_lauf(video, bereiche, fps, nur_keyframes, hw, start)
        try:
            for t, bilder in lauf:
                if nur_keyframes:
                    # Kaputte Stellen: der Decoder liefert plötzlich (fast) jedes Bild, meist grau/schwarz.
                    roh.append(t)
                    while roh and roh[0] < t - 2.0:
                        roh.popleft()
                    if len(roh) > 3 * fps * 2:
                        zu_dicht = True
                        break
                if t < letzte + abstand:
                    continue            # zu dicht bzw. nach einem Neustart doppelt geliefert
                letzte = t
                neu += 1
                yield t, bilder
        finally:
            lauf.close()
        ende = roh[-1] if (zu_dicht and roh) else max(letzte, start)
        if not zu_dicht and (dauer <= 0 or ende >= dauer - 1.0):
            return
        # vorzeitig beendet oder Datenmüll → dahinter neu ansetzen (-ss). Die Datei ist beschädigt:
        # d3d11va liefert dort teils schwarze Bilder → ab jetzt per CPU dekodieren.
        if zu_dicht:
            start = ende + 1.0
        else:
            start = (letzte + 0.05) if neu else start + 1.0
        if dauer > 0 and start >= dauer - 0.5:
            return
        hw = None


def _dauer(video: str) -> float:
    try:
        out = subprocess.run([FFPROBE, "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", video],
                             capture_output=True, text=True, creationflags=FENSTERLOS, timeout=30).stdout
        return float(out.strip() or 0)
    except (subprocess.SubprocessError, ValueError, OSError):
        return 0.0


def _ein_lauf(video: str, bereiche: list[Bereich], fps: float, nur_keyframes: bool,
              hwaccel: str | None, start: float) -> Iterator[tuple[float, dict[str, np.ndarray]]]:
    groessen = [b.ziel() for b in bereiche]
    breite = max(w for w, _ in groessen)
    hoehe = sum(h for _, h in groessen)

    teile = [f"[0:v]{'' if nur_keyframes else f'fps={fps},'}split={len(bereiche)}"
             + "".join(f"[s{i}]" for i in range(len(bereiche)))]
    for i, (b, (w, h)) in enumerate(zip(bereiche, groessen)):
        teile.append(
            f"[s{i}]crop=trunc(iw*{b.b:.6f}):trunc(ih*{b.h:.6f}):trunc(iw*{b.x:.6f}):trunc(ih*{b.y:.6f}),"
            f"scale={w}:{h}:flags=area,pad={breite}:{h}[p{i}]")
    # showinfo ganz am Ende: genau eine Zeitstempel-Zeile je ausgegebenem Bild
    teile.append("".join(f"[p{i}]" for i in range(len(bereiche)))
                 + (f"vstack=inputs={len(bereiche)}," if len(bereiche) > 1 else "null,") + "showinfo[aus]")

    cmd = [FFMPEG, "-hide_banner", "-nostdin", "-loglevel", "info", "-max_error_rate", "1"]
    if hwaccel:
        cmd += ["-hwaccel", hwaccel]
    if nur_keyframes:
        cmd += ["-skip_frame", "nokey"]
    if start > 0:
        cmd += ["-ss", f"{start:.3f}", "-copyts"]
    cmd += ["-i", video, "-an", "-sn", "-filter_complex", ";".join(teile), "-map", "[aus]",
            "-fps_mode", "passthrough", "-f", "rawvideo", "-pix_fmt", "bgr24", "pipe:1"]

    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            stdin=subprocess.DEVNULL, creationflags=FENSTERLOS, bufsize=0)
    zeiten: deque[float] = deque()
    zeiten_da = threading.Condition()
    fertig = [False]

    def stderr_lesen() -> None:
        assert proc.stderr is not None
        for zeile in proc.stderr:
            if b"Parsed_showinfo" in zeile and b"pts_time" in zeile:
                m = _PTS.search(zeile)
                if m:
                    with zeiten_da:
                        zeiten.append(float(m.group(1)))
                        zeiten_da.notify()
        with zeiten_da:
            fertig[0] = True
            zeiten_da.notify()

    leser = threading.Thread(target=stderr_lesen, daemon=True)
    leser.start()

    # Wachhund: An kaputten Stellen bleibt FFmpeg manchmal einfach stehen (kein Bild, keine CPU-Last).
    # Kommt WACHHUND_S lang kein Bild, wird der Lauf beendet; lese_bereiche setzt dahinter neu an.
    aktiv = [time.monotonic()]
    ende_signal = threading.Event()

    def wachhund() -> None:
        while not ende_signal.wait(1.0):
            if proc.poll() is not None:
                return
            if time.monotonic() - aktiv[0] > WACHHUND_S:
                proc.kill()
                return

    threading.Thread(target=wachhund, daemon=True).start()
    groesse = breite * hoehe * 3
    assert proc.stdout is not None
    try:
        while True:
            puffer = _lese_genau(proc.stdout, groesse)
            if puffer is None:
                break
            aktiv[0] = time.monotonic()
            with zeiten_da:
                while not zeiten and not fertig[0]:
                    zeiten_da.wait(5)
                if not zeiten:
                    break
                t = zeiten.popleft()
            bild = np.frombuffer(puffer, np.uint8).reshape(hoehe, breite, 3)
            teile_out: dict[str, np.ndarray] = {}
            y = 0
            for b, (w, h) in zip(bereiche, groessen):
                teile_out[b.name] = bild[y:y + h, :w]
                y += h
            yield t, teile_out
    finally:
        ende_signal.set()
        if proc.poll() is None:
            proc.kill()      # auch bei Abbruch durch den Aufrufer (generator.close())
        proc.wait()
        leser.join(timeout=5)


def _lese_genau(strom, n: int) -> bytes | None:
    teile = []
    rest = n
    while rest > 0:
        stueck = strom.read(rest)
        if not stueck:
            return None
        teile.append(stueck)
        rest -= len(stueck)
    return b"".join(teile)
