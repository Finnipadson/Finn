"""Kommandozeile:

  python -m cutter erkennen <video>            Phase 1: Events als JSON ausgeben
  python -m cutter clips <video>               Phase 1+2: Clips als JSON ausgeben
  python -m cutter machen <video...> [-o ziel] [--format 9:16] [--kein-cache]
                                               Phase 1-3: fertiges Highlight-Video
  python -m cutter server [--port 4720] [--kein-browser]
"""
from __future__ import annotations

import argparse
import json
import sys
import time

from . import pipeline
from .schema import Einstellungen


def _fortschritt():
    letzte = [0.0]

    def f(anteil: float, text: str) -> None:
        jetzt = time.monotonic()
        if jetzt - letzte[0] > 0.5 or anteil >= 1.0:
            letzte[0] = jetzt
            print(f"\r{anteil * 100:5.1f} %  {text[:70]:<70}", end="", file=sys.stderr, flush=True)
            if anteil >= 1.0:
                print(file=sys.stderr)
    return f


def main(argv: list[str] | None = None) -> int:
    for strom in (sys.stdout, sys.stderr):
        try:
            strom.reconfigure(encoding="utf-8")
        except AttributeError:
            pass
    p = argparse.ArgumentParser(prog="cutter")
    sub = p.add_subparsers(dest="befehl", required=True)
    for name in ("erkennen", "clips"):
        s = sub.add_parser(name)
        s.add_argument("video")
        s.add_argument("--kein-cache", action="store_true")
    s = sub.add_parser("machen")
    s.add_argument("videos", nargs="+")
    s.add_argument("-o", "--ziel")
    s.add_argument("--format", choices=["16:9", "9:16"], default="16:9")
    s.add_argument("--kein-cache", action="store_true")
    s = sub.add_parser("server")
    s.add_argument("--port", type=int, default=4720)
    s.add_argument("--kein-browser", action="store_true")
    a = p.parse_args(argv)

    if a.befehl == "server":
        from .server import starte
        starte(a.port, not a.kein_browser)
        return 0

    if a.befehl == "erkennen":
        analyse = pipeline.erkenne(a.video, cache=not a.kein_cache, fortschritt=_fortschritt())
        print(json.dumps(analyse.als_dict(), ensure_ascii=False, indent=1))
        return 0

    e = Einstellungen(format=getattr(a, "format", "16:9"))
    videos = [a.video] if a.befehl == "clips" else a.videos
    _, clips = pipeline.analysiere(videos, e, cache=not a.kein_cache, fortschritt=_fortschritt())
    if a.befehl == "clips":
        print(json.dumps([c.als_dict() for c in clips], ensure_ascii=False, indent=1))
        return 0
    if not clips:
        print("Keine Highlights gefunden.", file=sys.stderr)
        return 1
    ziel = pipeline.rendere(clips, e, a.ziel, fortschritt=_fortschritt())
    print(ziel)
    return 0


if __name__ == "__main__":
    sys.exit(main())
