"""Quell-Videos prüfen: Ab wann ist der Videostrom einer NVIDIA-DVR-Aufnahme sauber?

NVIDIA-Instant-Replay-Dateien (`*.DVR.mp4`) beginnen oft mit Datenmüll: Die Pakete der ersten
Sekunden (gemessen: bis ~50 s) zeigen auf falsche Bytes, viele sind im mp4-Index fälschlich als
Keyframe markiert. Ein Decoder, der diesen Müll sieht, liefert graue/grüne/verschmierte Bilder –
und kann danach dauerhaft kaputt bleiben (falsche SPS übernommen). `-ss` springt zum letzten
„Keyframe“ vor dem Ziel – im Müllbereich ist das ein falscher.

Lösung: Die NAL-Header der Pakete direkt lesen (ffprobe liefert Position + Größe), den letzten
kaputten Paket-Zeitpunkt finden und das erste echte IDR-Bild danach suchen. Clips beginnen nie
vor diesem Zeitpunkt; der Seek landet dann garantiert auf einem echten IDR ohne Müll davor.
"""
from __future__ import annotations

import json
import subprocess
import threading
from pathlib import Path

from .. import medien
from ..medien import FENSTERLOS, FFPROBE, VideoInfo

# NAL-Typen, die am Anfang eines gültigen H.264-Zugriffs stehen dürfen
_GUELTIGE_ERSTE_NAL = {1, 5, 6, 7, 8, 9}
_FENSTER = (60.0, 120.0, 300.0, None)          # Sekunden, die nacheinander gescannt werden (None = alles)
_SICHERHEIT = 10.0                       # so viele s sauberer Strom am Fensterende = fertig

# Kein langes Stream-Probing: Bei DVR-Dateien würde FFmpeg dabei den Müll am Anfang decodieren
# (~1 s pro Aufruf). Bei mp4 stehen alle Stream-Daten ohnehin im moov-Atom.
KURZ_PROBEN = ["-analyzeduration", "0", "-probesize", "32768"]

_cache: dict[tuple, float] = {}
_sperre = threading.Lock()


def _schluessel(pfad: Path) -> tuple:
    st = pfad.stat()
    return (str(pfad), st.st_size, int(st.st_mtime))


def _pakete(pfad: Path, bis: float | None) -> list[tuple[float, int, int]]:
    """(pts, pos, size) aller Videopakete bis `bis` s."""
    befehl = [FFPROBE, "-v", "quiet", *KURZ_PROBEN, "-select_streams", "v:0",
              "-show_entries", "packet=pts_time,pos,size", "-of", "compact=p=0"]
    if bis is not None:
        befehl += ["-read_intervals", f"%+{bis}"]
    out = subprocess.run(befehl + [str(pfad)], capture_output=True, text=True,
                         creationflags=FENSTERLOS).stdout
    pakete = []
    for zeile in out.splitlines():
        werte = dict(teil.partition("=")[::2] for teil in zeile.split("|"))
        try:
            pakete.append((float(werte["pts_time"]), int(werte["pos"]), int(werte["size"])))
        except (KeyError, ValueError):
            continue    # pts N/A o. ä.
    return pakete


def _nal_typen(f, pos: int, groesse: int) -> list[int] | None:
    """NAL-Typen eines AVCC-Pakets (4-Byte-Längen). None = ungültig.

    Gültig heißt: Die NAL-Längen ergeben zusammen exakt die Paketgröße, kein Forbidden-Bit,
    erster NAL-Typ plausibel. Zufälliger Datenmüll besteht diese Prüfung praktisch nie.
    """
    typen: list[int] = []
    i = 0
    while i < groesse:
        if i + 5 > groesse or len(typen) > 64:
            return None
        f.seek(pos + i)
        kopf = f.read(5)
        if len(kopf) < 5:
            return None
        laenge = int.from_bytes(kopf[:4], "big")
        if laenge <= 0 or i + 4 + laenge > groesse or kopf[4] & 0x80:
            return None
        typen.append(kopf[4] & 0x1F)
        i += 4 + laenge
    if not typen or typen[0] not in _GUELTIGE_ERSTE_NAL:
        return None
    return typen


def _analysiere(pfad: Path, bis: float | None) -> tuple[float, bool]:
    """→ (erster sauberer IDR-Zeitpunkt, sicher). sicher=False → Fenster zu klein."""
    pakete = _pakete(pfad, bis)
    if not pakete:
        return 0.0, True
    letzter_kaputt = -1
    idr: list[int] = []
    with open(pfad, "rb") as f:
        for n, (_, pos, groesse) in enumerate(pakete):
            typen = _nal_typen(f, pos, groesse)
            if typen is None:
                letzter_kaputt = n
            elif 5 in typen:
                idr.append(n)
    if letzter_kaputt < 0:
        return 0.0, True
    t_kaputt = pakete[letzter_kaputt][0]
    danach = [n for n in idr if n > letzter_kaputt]
    ende = pakete[-1][0]
    if not danach or (bis is not None and ende - t_kaputt < _SICHERHEIT):
        return ende, False
    return pakete[danach[0]][0], True


def erster_sauberer_zeitpunkt(video: str | Path) -> float:
    """Sekunde, ab der der Videostrom sauber decodierbar ist (0.0 bei normalen Dateien).

    Ergebnis wird pro Datei (Pfad, Größe, Änderungszeit) zwischengespeichert.
    Dauer: ~0,3–1 s beim ersten Aufruf je Datei.
    """
    pfad = Path(video).resolve()
    schluessel = _schluessel(pfad)
    with _sperre:
        if schluessel in _cache:
            return _cache[schluessel]
    t = 0.0
    for bis in _FENSTER:
        t, sicher = _analysiere(pfad, bis)
        if sicher:
            break
    with _sperre:
        _cache[schluessel] = t
    return t


_info_cache: dict[tuple, VideoInfo] = {}


def info(video: str | Path) -> VideoInfo:
    """Wie `medien.info`, aber ohne langes Probing (DVR-Dateien: ~0,1 s statt ~1,3 s) und
    zwischengespeichert. Fällt bei Problemen auf `medien.info` zurück."""
    pfad = Path(video).resolve()
    schluessel = _schluessel(pfad)
    with _sperre:
        if schluessel in _info_cache:
            return _info_cache[schluessel]
    try:
        out = subprocess.run(
            [FFPROBE, "-v", "error", *KURZ_PROBEN, "-show_entries",
             "format=duration:stream=codec_type,width,height,avg_frame_rate",
             "-of", "json", str(pfad)],
            capture_output=True, text=True, check=True, creationflags=FENSTERLOS).stdout
        d = json.loads(out)
        v = next(s for s in d["streams"] if s.get("codec_type") == "video")
        z, _, n = v.get("avg_frame_rate", "0/1").partition("/")
        fps = float(z) / float(n) if float(n or 0) else 0.0
        ergebnis = VideoInfo(pfad=str(pfad), dauer=float(d["format"]["duration"]),
                             breite=int(v["width"]), hoehe=int(v["height"]), fps=fps,
                             hat_ton=any(s.get("codec_type") == "audio" for s in d["streams"]))
        if ergebnis.breite <= 0 or ergebnis.hoehe <= 0 or ergebnis.dauer <= 0:
            raise ValueError("unvollständig")
    except (subprocess.CalledProcessError, StopIteration, KeyError, ValueError, ZeroDivisionError):
        ergebnis = medien.info(pfad)
    with _sperre:
        _info_cache[schluessel] = ergebnis
    return ergebnis
