"""Flask-App mit der HTTP-API aus SCHNITTSTELLEN.md (Phase 4). Ruft nur cutter.pipeline auf
(und den Platzhalter mock.py, solange Phase 1–3 noch nicht fertig sind)."""
from __future__ import annotations

import json
import math
import os
import threading
from collections import OrderedDict
from pathlib import Path

from flask import Flask, Response, jsonify, request, send_file, send_from_directory

from .. import medien, pipeline
from ..schema import Clip, Einstellungen
from . import auftraege, dateien, mock

WEB = pipeline.PROJEKT / "web"

MIMETYPEN = {".mp4": "video/mp4", ".mov": "video/quicktime", ".mkv": "video/x-matroska"}

# Grenzen für Einstellungen (Werte außerhalb werden auf den Rand gesetzt)
GRENZEN = {"uebergang": (0.0, 2.0), "fallback_vorlauf": (1.0, 60.0), "nachlauf": (0.0, 30.0),
           "max_vorlauf": (0.0, 120.0), "zusammenfassen": (0.0, 60.0), "knock_bis_kill": (0.0, 120.0)}


class Ungueltig(Exception):
    """Fehler in der Anfrage → HTTP 400 mit lesbarem Text."""

    def __init__(self, text: str, code: int = 400) -> None:
        super().__init__(text)
        self.code = code


# ---------------------------------------------------------------- Einstellungen
def einstellungen_datei() -> Path:
    return pipeline.DATEN / "einstellungen.json"


def bereinige(d: dict | None) -> Einstellungen:
    basis = Einstellungen().als_dict()
    if d:
        if not isinstance(d, dict):
            raise Ungueltig("Einstellungen müssen ein Objekt sein.")
        basis.update({k: v for k, v in d.items() if k in basis})
    try:
        e = Einstellungen.aus_dict(basis)
        e.format = e.format if e.format in ("16:9", "9:16") else "16:9"
        e.eigene_tode = bool(e.eigene_tode)
        e.champion = bool(e.champion)
        for feld, (lo, hi) in GRENZEN.items():
            wert = float(getattr(e, feld))
            if not math.isfinite(wert):
                raise ValueError(feld)
            setattr(e, feld, round(min(hi, max(lo, wert)), 2))
        e.hoehe = int(e.hoehe) if int(e.hoehe) in (720, 1080, 1440, 2160) else 1080
        e.fps = int(min(120, max(24, int(e.fps))))
    except (TypeError, ValueError) as exc:
        raise Ungueltig(f"Ungültiger Wert in den Einstellungen ({exc}).") from exc
    return e


def lade_einstellungen() -> Einstellungen:
    try:
        return bereinige(json.loads(einstellungen_datei().read_text(encoding="utf-8")))
    except (OSError, ValueError, Ungueltig):
        return Einstellungen()


def speichere_einstellungen(e: Einstellungen) -> None:
    datei = einstellungen_datei()
    datei.parent.mkdir(parents=True, exist_ok=True)
    tmp = datei.with_suffix(".tmp")
    tmp.write_text(json.dumps(e.als_dict(), ensure_ascii=False, indent=1), encoding="utf-8")
    tmp.replace(datei)


# ---------------------------------------------------------------- Hilfen
def video_pfad(roh: object, pruefe_video: bool = True) -> Path:
    if not roh or not isinstance(roh, str):
        raise Ungueltig("Kein Dateipfad angegeben.")
    p = Path(roh)
    if not p.is_absolute():
        raise Ungueltig("Der Pfad muss vollständig sein (z. B. C:\\…).")
    if pruefe_video and not medien.ist_video(p):
        raise Ungueltig("Das ist keine Videodatei (erlaubt: .mp4, .mkv, .mov).", 403)
    if not p.is_file():
        raise Ungueltig(f"Datei nicht gefunden: {p.name}", 404)
    return p.resolve()


def json_body() -> dict:
    d = request.get_json(silent=True)
    if not isinstance(d, dict):
        raise Ungueltig("Anfrage ohne gültige JSON-Daten.")
    return d


# ---------------------------------------------------------------- Vorschaubilder
_bilder: "OrderedDict[tuple, bytes]" = OrderedDict()
_bilder_lock = threading.Lock()
_ffmpeg_platz = threading.BoundedSemaphore(3)   # nicht 30 FFmpegs gleichzeitig starten


def vorschaubild(p: Path, t: float, breite: int) -> bytes:
    schluessel = (str(p), p.stat().st_mtime, round(t, 1), breite)
    with _bilder_lock:
        if schluessel in _bilder:
            _bilder.move_to_end(schluessel)
            return _bilder[schluessel]
    with _ffmpeg_platz:
        bild = None
        if not mock.erzwungen():
            try:
                bild = pipeline.vorschaubild(p, t, breite)
            except NotImplementedError:
                bild = None
        if bild is None:
            bild = mock.vorschaubild(str(p), t, breite)
    with _bilder_lock:
        _bilder[schluessel] = bild
        while len(_bilder) > 300:
            _bilder.popitem(last=False)
    return bild


# ---------------------------------------------------------------- Aufträge
def _analyse_arbeit(videos: list[str], e: Einstellungen):
    def arbeit(a: auftraege.Auftrag) -> dict:
        if mock.erzwungen():
            a.mock = True
            analysen, clips = mock.analysiere(videos, e, a.melde, a.abbrechen)
        else:
            try:
                analysen, clips = pipeline.analysiere(videos, e, fortschritt=a.melde, abbrechen=a.abbrechen)
            except NotImplementedError:
                a.mock = True
                a.melde(0.0, "Erkennung ist noch nicht fertig – zeige Demo-Daten")
                analysen, clips = mock.analysiere(videos, e, a.melde, a.abbrechen)
        return {"clips": [c.als_dict() for c in clips], "analysen": [x.als_dict() for x in analysen]}
    return arbeit


def _export_arbeit(clips: list[Clip], e: Einstellungen, ziel: str | None):
    def arbeit(a: auftraege.Auftrag) -> dict:
        if mock.erzwungen():
            a.mock = True
            pfad = mock.rendere(clips, e, a.melde, a.abbrechen)
        else:
            try:
                pfad = pipeline.rendere(clips, e, ziel, fortschritt=a.melde, abbrechen=a.abbrechen)
            except NotImplementedError:
                a.mock = True
                a.melde(0.0, "Schnitt ist noch nicht fertig – erstelle ein Demo-Video")
                pfad = mock.rendere(clips, e, a.melde, a.abbrechen)
        pfad = Path(pfad)
        groesse = pfad.stat().st_size if pfad.is_file() else 0
        return {"pfad": str(pfad), "name": pfad.name, "ordner": str(pfad.parent), "groesse": groesse}
    return arbeit


def lese_clips(roh: object) -> list[Clip]:
    if not isinstance(roh, list) or not roh:
        raise Ungueltig("Keine Clips übergeben.")
    clips = []
    for i, d in enumerate(roh, 1):
        try:
            c = Clip.aus_dict(d)
            c.start, c.ende, c.aktiv = float(c.start), float(c.ende), bool(c.aktiv)
        except (TypeError, KeyError, ValueError) as exc:
            raise Ungueltig(f"Clip {i} ist fehlerhaft ({exc}).") from exc
        if not (math.isfinite(c.start) and math.isfinite(c.ende)) or c.start < 0 or c.ende - c.start < 0.5:
            raise Ungueltig(f"Clip {i} („{c.grund}“) ist kürzer als eine halbe Sekunde oder hat ungültige Zeiten.")
        if c.aktiv:
            c.video = str(video_pfad(c.video))
        clips.append(c)
    if not any(c.aktiv for c in clips):
        raise Ungueltig("Alle Clips sind ausgeschaltet – schalte mindestens einen an.")
    return clips


# ---------------------------------------------------------------- App
def erstelle_app() -> Flask:
    app = Flask(__name__, static_folder=str(WEB), static_url_path="/static-unused")
    app.config["SEND_FILE_MAX_AGE_DEFAULT"] = 0
    app.json.ensure_ascii = False  # type: ignore[attr-defined]

    @app.errorhandler(Ungueltig)
    def _ungueltig(exc: Ungueltig):
        return jsonify(fehler=str(exc)), exc.code

    @app.errorhandler(404)
    def _nicht_da(_exc):
        if request.path.startswith("/api/"):
            return jsonify(fehler="Diese Adresse gibt es nicht."), 404
        return "Nicht gefunden", 404

    @app.errorhandler(Exception)
    def _fehler(exc: Exception):
        from werkzeug.exceptions import HTTPException
        if isinstance(exc, HTTPException):
            return exc
        import traceback
        traceback.print_exc()
        return jsonify(fehler=auftraege.menschlich(exc)), 500

    # --- Oberfläche
    @app.get("/")
    def index():
        return send_from_directory(WEB, "index.html")

    @app.get("/<path:datei>")
    def web_datei(datei: str):
        if datei.startswith("api/"):
            return jsonify(fehler="Diese Adresse gibt es nicht."), 404
        return send_from_directory(WEB, datei)

    # --- API
    @app.get("/api/info")
    def info():
        return jsonify(app="highlight-cutter", mock=mock.erzwungen() or mock.genutzt,
                       nvidia_ordner=str(dateien.nvidia_ordner()), ausgabe=str(pipeline.AUSGABE))

    @app.get("/api/videos")
    def videos():
        return jsonify(dateien.liste_videos())

    @app.post("/api/dateien-finden")
    def dateien_finden():
        d = json_body()
        gesucht = d.get("dateien")
        if not isinstance(gesucht, list):
            raise Ungueltig("Liste „dateien“ fehlt.")
        return jsonify(dateien.finde_dateien(gesucht[:50]))

    @app.post("/api/pfad-waehlen")
    def pfad_waehlen():
        try:
            return jsonify(videos=dateien.waehle_pfade())
        except dateien.DialogBelegt:
            raise Ungueltig("Der Dateidialog ist schon offen (evtl. hinter diesem Fenster).", 409)

    @app.post("/api/analyse")
    def analyse():
        d = json_body()
        roh = d.get("videos")
        if not isinstance(roh, list) or not roh:
            raise Ungueltig("Bitte mindestens eine Aufnahme auswählen.")
        videos = []
        for v in roh:
            p = str(video_pfad(v))
            if p not in videos:
                videos.append(p)
        e = bereinige(d["einstellungen"]) if d.get("einstellungen") else lade_einstellungen()
        a = auftraege.starte("analyse", _analyse_arbeit(videos, e))
        return jsonify(id=a.id)

    @app.post("/api/export")
    def export():
        d = json_body()
        clips = lese_clips(d.get("clips"))
        e = bereinige(d["einstellungen"]) if d.get("einstellungen") else lade_einstellungen()
        ziel = d.get("ziel") or None
        if ziel is not None:
            if not isinstance(ziel, str) or not Path(ziel).is_absolute() or Path(ziel).suffix.lower() != ".mp4":
                raise Ungueltig("Das Ziel muss ein vollständiger Pfad auf .mp4 sein.")
            if dateien.nvidia_ordner() in Path(ziel).resolve().parents:
                raise Ungueltig("In den NVIDIA-Aufnahmeordner wird nichts geschrieben – bitte anderes Ziel wählen.")
        a = auftraege.starte("export", _export_arbeit(clips, e, ziel))
        return jsonify(id=a.id)

    @app.get("/api/auftrag/<auftrag_id>")
    def auftrag(auftrag_id: str):
        a = auftraege.hole(auftrag_id)
        if not a:
            raise Ungueltig("Diesen Auftrag gibt es nicht (mehr). Wurde die App neu gestartet?", 404)
        return jsonify(a.als_dict())

    @app.post("/api/auftrag/<auftrag_id>/abbrechen")
    def abbrechen(auftrag_id: str):
        a = auftraege.hole(auftrag_id)
        if not a:
            raise Ungueltig("Diesen Auftrag gibt es nicht (mehr).", 404)
        a.abbrechen.set()
        if a.status == "laeuft":
            a.melde(a.anteil, "Wird abgebrochen …")
        return jsonify(a.als_dict())

    @app.get("/api/video")
    def video():
        p = video_pfad(request.args.get("pfad"))
        antwort = send_file(p, mimetype=MIMETYPEN.get(p.suffix.lower(), "video/mp4"), conditional=True,
                            max_age=0, etag=True)
        antwort.headers["Accept-Ranges"] = "bytes"
        return antwort

    @app.get("/api/bild")
    def bild():
        p = video_pfad(request.args.get("pfad"))
        try:
            t = float(request.args.get("t", "0"))
            breite = int(request.args.get("breite", "320"))
        except ValueError:
            raise Ungueltig("t und breite müssen Zahlen sein.")
        if not math.isfinite(t):
            raise Ungueltig("t muss eine Zahl sein.")
        breite = min(1280, max(64, breite - breite % 2))
        return Response(vorschaubild(p, max(0.0, t), breite), mimetype="image/jpeg",
                        headers={"Cache-Control": "max-age=86400"})

    @app.get("/api/einstellungen")
    def einstellungen_laden():
        return jsonify(lade_einstellungen().als_dict())

    @app.put("/api/einstellungen")
    def einstellungen_speichern():
        neu = json_body()
        e = bereinige({**lade_einstellungen().als_dict(), **neu})
        speichere_einstellungen(e)
        return jsonify(e.als_dict())

    @app.post("/api/oeffnen")
    def oeffnen():
        d = json_body()
        roh = d.get("pfad")
        if isinstance(roh, str) and roh.lower().endswith(" - thumbnail.jpg") and d.get("aktion") != "abspielen":
            p = Path(roh)   # gespeichertes Thumbnail im Ordner zeigen (nur im Highlights-Ordner)
            if not p.is_absolute() or not p.is_file() or pipeline.AUSGABE.resolve() not in p.resolve().parents:
                raise Ungueltig("Thumbnail nicht gefunden.", 404)
            dateien.zeige_im_ordner(p.resolve())
            return jsonify(ok=True)
        p = video_pfad(roh)
        if d.get("aktion") == "abspielen":
            dateien.abspielen(p)
        else:
            dateien.zeige_im_ordner(p)
        return jsonify(ok=True)

    # --- Meine Videos
    @app.get("/api/meine-videos")
    def meine_videos():
        return jsonify(ordner=str(pipeline.AUSGABE), videos=pipeline.meine_videos())

    @app.get("/api/kapitel")
    def kapitel():
        return jsonify(pipeline.kapitel(video_pfad(request.args.get("pfad"))))

    @app.get("/api/thumbnail-vorschlaege")
    def thumbnail_vorschlaege():
        return jsonify(pipeline.thumbnail_vorschlaege(video_pfad(request.args.get("pfad"))))

    @app.get("/api/thumbnail-bild")
    def thumbnail_bild():
        p = highlight_pfad(request.args.get("pfad"))
        bild = pipeline.thumbnail_pfad(p)
        if not bild.is_file():
            raise Ungueltig("Für dieses Video gibt es noch kein Thumbnail.", 404)
        return send_file(bild, mimetype="image/jpeg", max_age=0)

    @app.post("/api/thumbnail")
    def thumbnail():
        d = json_body()
        p = highlight_pfad(d.get("pfad"))
        try:
            t = float(d.get("t", 0))
        except (TypeError, ValueError):
            raise Ungueltig("t muss eine Zahl sein.")
        if not math.isfinite(t):
            raise Ungueltig("t muss eine Zahl sein.")
        ziel = pipeline.speichere_thumbnail(p, t)
        return jsonify(pfad=str(ziel), name=ziel.name)

    @app.post("/api/speichern-unter")
    def speichern_unter():
        p = video_pfad(json_body().get("pfad"))
        try:
            ziel = dateien.waehle_speicherort(p)
        except dateien.DialogBelegt:
            raise Ungueltig("Ein Dateidialog ist schon offen (evtl. hinter diesem Fenster).", 409)
        if ziel is None:
            return jsonify(abgebrochen=True)
        if ziel.resolve() == p:
            raise Ungueltig("Das ist dieselbe Datei – bitte einen anderen Ort oder Namen wählen.")
        if dateien.nvidia_ordner() in ziel.resolve().parents:
            raise Ungueltig("In den NVIDIA-Aufnahmeordner wird nichts geschrieben – bitte anderen Ort wählen.")
        a = auftraege.starte("kopie", _kopie_arbeit(p, ziel))
        return jsonify(id=a.id, ziel=str(ziel))

    @app.post("/api/loeschen")
    def loeschen():
        p = highlight_pfad(json_body().get("pfad"))
        thumb = pipeline.thumbnail_pfad(p)
        dateien.in_papierkorb(p)
        if thumb.is_file():
            try:
                dateien.in_papierkorb(thumb)   # zugehöriges Thumbnail gleich mit
            except OSError:
                pass
        return jsonify(ok=True, name=p.name)

    return app


def highlight_pfad(roh: object) -> Path:
    """Wie video_pfad, aber nur für Videos im Ausgabeordner (dort darf die App schreiben/löschen)."""
    p = video_pfad(roh)
    if pipeline.AUSGABE.resolve() not in p.parents:
        raise Ungueltig("Das geht nur mit Videos im Highlights-Ordner.", 403)
    return p


def _kopie_arbeit(quelle: Path, ziel: Path):
    def arbeit(a: auftraege.Auftrag) -> dict:
        from ..schema import pruefe_abbruch
        gesamt = max(1, quelle.stat().st_size)
        ziel.parent.mkdir(parents=True, exist_ok=True)
        teil = ziel.with_name(ziel.name + ".teil")
        kopiert = 0
        try:
            with open(quelle, "rb") as ein, open(teil, "wb") as aus:
                while stueck := ein.read(8 * 1024 * 1024):
                    pruefe_abbruch(a.abbrechen)
                    aus.write(stueck)
                    kopiert += len(stueck)
                    a.melde(kopiert / gesamt, f"Kopiere {kopiert / 1e6:.0f} von {gesamt / 1e6:.0f} MB …")
            os.replace(teil, ziel)
        finally:
            teil.unlink(missing_ok=True)
        return {"pfad": str(ziel), "name": ziel.name}
    return arbeit
