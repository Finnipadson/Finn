"""Gemeinsame FFmpeg-Helfer. Nur hier ändern, nicht in den Teilmodulen."""
from __future__ import annotations

import json
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

FFMPEG = shutil.which("ffmpeg") or "ffmpeg"
FFPROBE = shutil.which("ffprobe") or "ffprobe"

# Unter Windows kein Konsolenfenster für Kindprozesse öffnen
FENSTERLOS = getattr(subprocess, "CREATE_NO_WINDOW", 0)


@dataclass
class VideoInfo:
    pfad: str
    dauer: float
    breite: int
    hoehe: int
    fps: float
    hat_ton: bool


def info(pfad: str | Path) -> VideoInfo:
    """Grunddaten eines Videos per ffprobe."""
    pfad = str(Path(pfad).resolve())
    out = subprocess.run(
        [FFPROBE, "-v", "error", "-show_entries",
         "format=duration:stream=codec_type,width,height,avg_frame_rate",
         "-of", "json", pfad],
        capture_output=True, text=True, check=True, creationflags=FENSTERLOS,
    ).stdout
    d = json.loads(out)
    video = next(s for s in d["streams"] if s.get("codec_type") == "video")
    zaehler, _, nenner = video.get("avg_frame_rate", "0/1").partition("/")
    fps = float(zaehler) / float(nenner or 1) if float(nenner or 1) else 0.0
    return VideoInfo(
        pfad=pfad,
        dauer=float(d["format"]["duration"]),
        breite=int(video["width"]),
        hoehe=int(video["height"]),
        fps=fps,
        hat_ton=any(s.get("codec_type") == "audio" for s in d["streams"]),
    )


def ist_video(pfad: str | Path) -> bool:
    return Path(pfad).suffix.lower() in {".mp4", ".mkv", ".mov"}


NVIDIA_ORDNER = Path.home() / "Videos" / "NVIDIA"
