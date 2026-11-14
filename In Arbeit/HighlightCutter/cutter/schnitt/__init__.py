"""Phase 3 – Clips ausschneiden und zu einem Video zusammenfügen. Bereich von Agent 3.

Öffentlich: `rendere`, `vorschaubild`. Außerdem nützlich für andere Teile:
`erster_sauberer_zeitpunkt(video)` – ab wann eine NVIDIA-DVR-Aufnahme sauber decodierbar ist.
Fehler: `SchnittFehler` (RuntimeError, deutscher Text mit den letzten FFmpeg-Zeilen).
"""
from __future__ import annotations

import subprocess
from pathlib import Path

from ..medien import FENSTERLOS, FFMPEG
from ..schema import Abbruch, Clip, Einstellungen, Fortschritt
from .ffmpeg_lauf import SchnittFehler
from .quelle import KURZ_PROBEN, erster_sauberer_zeitpunkt
from .render import kapitel as _kapitel
from .render import rendere as _rendere

__all__ = ["rendere", "kapitel", "vorschaubild", "erster_sauberer_zeitpunkt", "SchnittFehler"]

# Vorschaubilder unterhalb dieser Sekunde auf den sauberen Dateianfang schieben
# (darüber wurde bei keiner Aufnahme ein kaputter Anfang gemessen; spart den Scan)
_VORSCHAU_SCAN_BIS = 120.0


def rendere(clips: list[Clip], ziel: str | Path, einstellungen: Einstellungen,
            fortschritt: Fortschritt = None, abbrechen: Abbruch | None = None) -> Path:
    """Schneidet alle aktiven Clips (in Listenreihenfolge) aus und fügt sie zu EINEM mp4 zusammen.

    Clips dürfen aus verschiedenen Videos (auch mit verschiedener Auflösung/fps) stammen.
    Gibt den Pfad der fertigen Datei zurück. Bei Abbruch keine halbe Zieldatei liegen lassen.
    """
    return _rendere(clips, ziel, einstellungen, fortschritt, abbrechen)


def kapitel(clips: list[Clip], einstellungen: Einstellungen) -> list[dict]:
    """Kapitel (ein Kapitel je aktivem Clip) so, wie `rendere` sie ins MP4 schreibt:
    [{start, ende, titel, kills: [s…], quelle, quelle_start}] – Zeiten im fertigen Video."""
    return _kapitel(clips, einstellungen)


def vorschaubild(video: str | Path, t: float, breite: int = 320) -> bytes:
    """JPEG-Bild des Videos bei Sekunde t (für die Clipliste in der Oberfläche)."""
    video = str(Path(video).resolve())
    t = max(0.0, float(t))
    if t < _VORSCHAU_SCAN_BIS:
        t = max(t, erster_sauberer_zeitpunkt(video))
    breite = max(16, int(breite) // 2 * 2)
    befehl = [FFMPEG, "-hide_banner", "-v", "error", "-nostdin", *KURZ_PROBEN,
              "-ss", f"{t:.3f}", "-i", video, "-frames:v", "1", "-an",
              "-vf", f"scale={breite}:-2:flags=bilinear", "-c:v", "mjpeg", "-q:v", "4",
              "-f", "image2pipe", "pipe:1"]
    r = subprocess.run(befehl, capture_output=True, timeout=30, creationflags=FENSTERLOS)
    if not r.stdout:
        # t hinter dem Dateiende → Bild kurz vor dem Ende nehmen
        i = befehl.index("-ss")
        befehl[i:i + 2] = ["-sseof", "-0.5"]
        r = subprocess.run(befehl, capture_output=True, timeout=30, creationflags=FENSTERLOS)
    if not r.stdout:
        rest = r.stderr.decode("utf-8", "replace").strip().splitlines()[-3:]
        raise SchnittFehler(f"Vorschaubild bei {t:.1f} s konnte nicht erzeugt werden.\n" + "\n".join(rest))
    return r.stdout
