"""Verbindet die Phasen. Server und CLI rufen nur diese Funktionen auf."""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
from datetime import datetime
from pathlib import Path

from . import clips as _clips
from . import erkennung as _erkennung
from . import schnitt as _schnitt
from .schema import Abbruch, Analyse, Clip, Einstellungen, Fortschritt, melde, pruefe_abbruch

PROJEKT = Path(__file__).resolve().parent.parent
DATEN = Path(os.environ.get("HC_DATADIR", PROJEKT / "daten"))   # Cache + Einstellungen, gitignored
CACHE = DATEN / "cache"
AUSGABE = Path.home() / "Videos" / "Highlights"

# Erhöhen, wenn sich die Erkennung ändert → alte Cache-Einträge werden ignoriert
ERKENNUNG_VERSION = 3   # 3: kaputter DVR-Anfang wird bei der Erkennung übersprungen


def _cache_datei(video: Path, profil: str) -> Path:
    st = video.stat()
    schluessel = f"{video}|{st.st_size}|{int(st.st_mtime)}|{profil}|{ERKENNUNG_VERSION}"
    return CACHE / (hashlib.sha1(schluessel.encode()).hexdigest()[:16] + ".json")


def erkenne(video: str | Path, profil: str = "apex", cache: bool = True,
            fortschritt: Fortschritt = None, abbrechen: Abbruch | None = None) -> Analyse:
    video = Path(video).resolve()
    datei = _cache_datei(video, profil)
    if cache and datei.exists():
        melde(fortschritt, 1.0, "Aus Zwischenspeicher")
        return Analyse.aus_dict(json.loads(datei.read_text(encoding="utf-8")))
    try:
        sauber = _schnitt.erster_sauberer_zeitpunkt(str(video))
    except Exception:   # noqa: BLE001 – Prüfung ist nur eine Verbesserung
        sauber = 0.0
    analyse = _erkennung.erkenne(video, profil, fortschritt, abbrechen, ab=sauber)
    CACHE.mkdir(parents=True, exist_ok=True)
    datei.write_text(json.dumps(analyse.als_dict(), ensure_ascii=False, indent=1), encoding="utf-8")
    return analyse


def _ohne_kaputten_anfang(clips: list[Clip], video: str | Path) -> list[Clip]:
    """Manche DVR-Dateien sind am Anfang bis zu ~1 min unlesbar: Clips dort kürzen/weglassen,
    damit Oberfläche und Export dieselben Grenzen zeigen."""
    if not clips or clips[0].start > 120:
        return clips
    try:
        sauber = _schnitt.erster_sauberer_zeitpunkt(str(Path(video).resolve()))
    except Exception:   # noqa: BLE001 – Prüfung ist nur eine Verbesserung
        return clips
    if sauber <= 0:
        return clips
    ergebnis = []
    for c in clips:
        if c.ende - 1.0 <= sauber:
            continue
        c.start = max(c.start, round(sauber, 3))
        ergebnis.append(c)
    return ergebnis


def analysiere(videos: list[str | Path], einstellungen: Einstellungen, profil: str = "apex",
               cache: bool = True, fortschritt: Fortschritt = None,
               abbrechen: Abbruch | None = None) -> tuple[list[Analyse], list[Clip]]:
    """Phase 1 + 2 für mehrere Videos. Clips in Video-Reihenfolge, je Video nach Zeit."""
    analysen: list[Analyse] = []
    alle_clips: list[Clip] = []
    n = max(1, len(videos))
    for i, video in enumerate(videos):
        name = Path(video).name

        def teil(anteil: float, text: str, i=i, name=name) -> None:
            melde(fortschritt, (i + anteil) / n, f"{name}: {text}" if n > 1 else text)

        a = erkenne(video, profil, cache, lambda x, t: teil(0.9 * x, t), abbrechen)
        pruefe_abbruch(abbrechen)
        c = _clips.plane_clips(a, einstellungen, lambda x, t: teil(0.9 + 0.1 * x, t), abbrechen)
        c = _ohne_kaputten_anfang(c, video)
        analysen.append(a)
        alle_clips.extend(c)
    melde(fortschritt, 1.0, f"{len(alle_clips)} Clips gefunden")
    return analysen, alle_clips


def standard_ziel(einstellungen: Einstellungen) -> Path:
    zusatz = " hochkant" if einstellungen.format == "9:16" else ""
    return AUSGABE / f"Highlights {datetime.now():%Y-%m-%d %H-%M-%S}{zusatz}.mp4"


def rendere(clips: list[Clip], einstellungen: Einstellungen, ziel: str | Path | None = None,
            fortschritt: Fortschritt = None, abbrechen: Abbruch | None = None) -> Path:
    ziel = Path(ziel) if ziel else standard_ziel(einstellungen)
    ziel.parent.mkdir(parents=True, exist_ok=True)
    pfad = Path(_schnitt.rendere(clips, ziel, einstellungen, fortschritt, abbrechen))
    try:
        speichere_kapitel(pfad, _schnitt.kapitel(clips, einstellungen))
    except Exception:   # noqa: BLE001 – Kill-Momente sind nur ein Extra für Thumbnail-Vorschläge
        pass
    return pfad


# --------------------------------------------------------------------------- Meine Videos
# Die Kapitel stehen im MP4 selbst. Zusätzlich merkt sich die App je Video die Kill-Momente
# (für Thumbnail-Vorschläge) in daten/videos/<Dateigröße>.json – die Größe bleibt beim Kopieren
# und Umbenennen gleich.

def _kapitel_datei(groesse: int) -> Path:
    return DATEN / "videos" / f"{groesse}.json"


def speichere_kapitel(video: str | Path, kapitel: list[dict]) -> None:
    video = Path(video)
    datei = _kapitel_datei(video.stat().st_size)
    datei.parent.mkdir(parents=True, exist_ok=True)
    datei.write_text(json.dumps({"name": video.name, "kapitel": kapitel}, ensure_ascii=False, indent=1),
                     encoding="utf-8")


def _gespeicherte_kapitel(video: Path) -> list[dict]:
    try:
        d = json.loads(_kapitel_datei(video.stat().st_size).read_text(encoding="utf-8"))
        return list(d.get("kapitel") or [])
    except (OSError, ValueError, AttributeError):
        return []


_details_cache: dict[tuple, dict] = {}


def video_details(video: str | Path) -> dict:
    """Dauer, Bildgröße und Kapitel eines fertigen Videos (ffprobe, zwischengespeichert)."""
    video = Path(video).resolve()
    st = video.stat()
    schluessel = (str(video), st.st_size, int(st.st_mtime))
    if schluessel in _details_cache:
        return _details_cache[schluessel]
    from .medien import FENSTERLOS, FFPROBE
    out = subprocess.run(
        [FFPROBE, "-v", "error", "-show_chapters", "-show_entries",
         "format=duration:stream=codec_type,width,height", "-of", "json", str(video)],
        capture_output=True, text=True, encoding="utf-8", check=True, timeout=30, creationflags=FENSTERLOS,
    ).stdout
    d = json.loads(out or "{}")
    v = next((s for s in d.get("streams", []) if s.get("codec_type") == "video"), {})
    kapitel = []
    for k in d.get("chapters", []):
        titel = (k.get("tags") or {}).get("title", "")
        kapitel.append({"start": round(float(k.get("start_time", 0)), 3),
                        "ende": round(float(k.get("end_time", 0)), 3), "titel": titel})
    ergebnis = {"dauer": round(float((d.get("format") or {}).get("duration") or 0), 3),
                "breite": int(v.get("width") or 0), "hoehe": int(v.get("height") or 0), "kapitel": kapitel}
    _details_cache[schluessel] = ergebnis
    return ergebnis


def _ist_highlight_video(p: Path) -> bool:
    return (p.is_file() and p.suffix.lower() == ".mp4" and not p.name.lower().endswith(".teil.mp4")
            and not any(teil.startswith(".hc-schnitt-") for teil in p.parts))


def thumbnail_pfad(video: Path) -> Path:
    return video.with_name(f"{video.stem} - Thumbnail.jpg")


def meine_videos() -> list[dict]:
    """Alle fertigen Highlight-Videos im Ausgabeordner (inkl. Unterordner), neueste zuerst."""
    if not AUSGABE.is_dir():
        return []
    liste = []
    for p in AUSGABE.rglob("*.mp4"):
        if not _ist_highlight_video(p):
            continue
        st = p.stat()
        try:
            det = video_details(p)
        except (OSError, subprocess.SubprocessError, ValueError):
            det = {"dauer": 0.0, "breite": 0, "hoehe": 0, "kapitel": []}
        ordner = p.parent.relative_to(AUSGABE).as_posix()
        thumb = thumbnail_pfad(p)
        liste.append({
            "pfad": str(p), "name": p.stem, "ordner": "" if ordner == "." else ordner,
            "datum": datetime.fromtimestamp(st.st_mtime).isoformat(timespec="seconds"),
            "groesse": st.st_size, "dauer": det["dauer"], "breite": det["breite"], "hoehe": det["hoehe"],
            "format": "9:16" if det["hoehe"] > det["breite"] else "16:9",
            "kapitel": len(det["kapitel"]), "thumbnail": str(thumb) if thumb.is_file() else None,
        })
    liste.sort(key=lambda v: v["datum"], reverse=True)
    return liste


def kapitel(video: str | Path) -> dict:
    """Kapitel aus dem MP4 + gemerkte Kill-Momente: {kapitel: [{start, ende, titel, kills}], kills: [s…]}."""
    video = Path(video).resolve()
    det = video_details(video)
    gemerkt = _gespeicherte_kapitel(video)
    kap = [dict(k, kills=[]) for k in det["kapitel"]]
    if gemerkt and (not kap or len(gemerkt) == len(kap)):
        if not kap:
            kap = [{"start": g["start"], "ende": g["ende"], "titel": f"#{i} {g.get('titel', '')}", "kills": []}
                   for i, g in enumerate(gemerkt, 1)]
        for k, g in zip(kap, gemerkt):
            k["kills"] = [t for t in g.get("kills", []) if 0 <= t <= det["dauer"]]
    return {"dauer": det["dauer"], "kapitel": kap, "kills": sorted(t for k in kap for t in k["kills"])}


def thumbnail_vorschlaege(video: str | Path, anzahl: int = 4) -> list[dict]:
    """Bis zu `anzahl` Zeitpunkte für ein Thumbnail: Kill-Momente aus den Clips mit den meisten
    Kills zuerst (je Clip einer); ohne Kill-Daten gleichmäßig verteilte Standbilder."""
    k = kapitel(video)
    dauer = k["dauer"]
    vorschlaege: list[dict] = []
    mit_kills = sorted((x for x in k["kapitel"] if x["kills"]), key=lambda x: (-len(x["kills"]), x["start"]))
    for x in mit_kills:
        # kurz nach dem letzten Kill: Meldung „ELIMINATED“/Zähler sind dann sichtbar
        t = min(x["kills"][-1] + 0.4, x["ende"] - 0.1, dauer - 0.1)
        n = len(x["kills"])
        vorschlaege.append({"t": round(max(0.0, t), 2), "grund": f"{x['titel']} · {n} Kill{'s' if n != 1 else ''}"})
        if len(vorschlaege) >= anzahl:
            return vorschlaege
    abstand = min(2.0, dauer / 8)          # bei kurzen Videos dürfen Vorschläge näher beieinander liegen
    for anteil in (0.2, 0.4, 0.6, 0.8, 0.1, 0.9, 0.3, 0.7, 0.5):
        if len(vorschlaege) >= anzahl:
            break
        t = round(dauer * anteil, 2)
        if all(abs(t - v["t"]) > abstand for v in vorschlaege):
            vorschlaege.append({"t": t, "grund": f"Standbild bei {int(t // 60)}:{int(t % 60):02d}"})
    return vorschlaege


def speichere_thumbnail(video: str | Path, t: float) -> Path:
    """Standbild bei t als JPEG neben dem Video: 16:9 → 1280×720 (YouTube), 9:16 → 1080×1920 (Shorts)."""
    from .medien import FENSTERLOS, FFMPEG
    video = Path(video).resolve()
    det = video_details(video)
    w, h = (1080, 1920) if det["hoehe"] > det["breite"] else (1280, 720)
    t = min(max(0.0, float(t)), max(0.0, det["dauer"] - 0.05))
    ziel = thumbnail_pfad(video)
    teil = ziel.with_name(ziel.stem + ".teil.jpg")
    try:
        subprocess.run(
            [FFMPEG, "-y", "-v", "error", "-ss", f"{t:.3f}", "-i", str(video), "-frames:v", "1",
             "-vf", f"scale={w}:{h}:force_original_aspect_ratio=increase,crop={w}:{h}", "-q:v", "2", str(teil)],
            capture_output=True, check=True, timeout=60, creationflags=FENSTERLOS)
        os.replace(teil, ziel)
    finally:
        teil.unlink(missing_ok=True)
    return ziel


def vorschaubild(video: str | Path, t: float, breite: int = 320) -> bytes:
    return _schnitt.vorschaubild(video, t, breite)
