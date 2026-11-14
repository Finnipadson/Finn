"""Tests für „Meine Videos“: Liste, Kapitel, Thumbnail-Vorschläge/-Speichern, Kopieren, Löschen."""
from __future__ import annotations

import shutil
import subprocess
import sys
import time
from pathlib import Path

import pytest

from cutter import medien, pipeline
from cutter.server import app as app_modul
from cutter.server import dateien

pytestmark = pytest.mark.skipif(shutil.which("ffmpeg") is None, reason="FFmpeg fehlt")


def _video(ziel: Path, breite: int, hoehe: int, dauer: int,
           kapitel: list[tuple[float, float, str]] | None = None) -> Path:
    ziel.parent.mkdir(parents=True, exist_ok=True)
    arg = [medien.FFMPEG, "-y", "-v", "error",
           "-f", "lavfi", "-i", f"testsrc=size={breite}x{hoehe}:rate=30:duration={dauer}",
           "-f", "lavfi", "-i", f"sine=frequency=440:duration={dauer}"]
    meta = ziel.with_suffix(".txt")
    if kapitel:
        zeilen = [";FFMETADATA1"]
        for s, e, t in kapitel:
            zeilen += ["[CHAPTER]", "TIMEBASE=1/1000", f"START={int(s * 1000)}", f"END={int(e * 1000)}", f"title={t}"]
        meta.write_text("\n".join(zeilen) + "\n", encoding="utf-8")
        arg += ["-f", "ffmetadata", "-i", str(meta), "-map_chapters", "2", "-map", "0:v", "-map", "1:a"]
    arg += ["-shortest", "-c:v", "libx264", "-preset", "ultrafast", "-c:a", "aac", str(ziel)]
    subprocess.run(arg, check=True, capture_output=True)
    meta.unlink(missing_ok=True)
    return ziel


@pytest.fixture(scope="module")
def vorlagen(tmp_path_factory) -> dict[str, Path]:
    d = tmp_path_factory.mktemp("vorlagen")
    return {
        "kapitel": _video(d / "mit.mp4", 320, 180, 9,
                          [(0, 3, "\\#1 Kill"), (3, 6, "\\#2 3× Kill"), (6, 9, "\\#3 Kill")]),
        "hoch": _video(d / "hoch.mp4", 180, 320, 4),
    }


@pytest.fixture
def umgebung(tmp_path, monkeypatch, vorlagen):
    ausgabe = tmp_path / "Highlights"
    mit = ausgabe / "Highlights 2026-01-02 20-00-00.mp4"
    hoch = ausgabe / "Unterordner" / "Highlights 2026-01-01 20-00-00 hochkant.mp4"
    hoch.parent.mkdir(parents=True)
    shutil.copy(vorlagen["kapitel"], mit)
    shutil.copy(vorlagen["hoch"], hoch)
    # darf nicht in der Liste auftauchen: halbe Exportdatei + Zwischenordner
    (ausgabe / "x.teil.mp4").write_bytes(b"0")
    (ausgabe / ".hc-schnitt-abc").mkdir()
    shutil.copy(vorlagen["hoch"], ausgabe / ".hc-schnitt-abc" / "m000.mp4")
    monkeypatch.setattr(pipeline, "AUSGABE", ausgabe)
    monkeypatch.setattr(pipeline, "DATEN", tmp_path / "daten")
    monkeypatch.setenv("HC_VIDEOS", str(tmp_path / "nvidia"))
    pipeline._details_cache.clear()
    app = app_modul.erstelle_app()
    app.testing = True
    return {"client": app.test_client(), "mit": mit, "hoch": hoch, "ausgabe": ausgabe, "tmp": tmp_path}


def test_liste(umgebung):
    d = umgebung["client"].get("/api/meine-videos").get_json()
    assert len(d["videos"]) == 2
    mit = next(v for v in d["videos"] if v["pfad"] == str(umgebung["mit"]))
    hoch = next(v for v in d["videos"] if v["pfad"] == str(umgebung["hoch"]))
    assert (mit["format"], mit["kapitel"], mit["breite"], mit["thumbnail"]) == ("16:9", 3, 320, None)
    assert (hoch["format"], hoch["kapitel"], hoch["ordner"]) == ("9:16", 0, "Unterordner")
    assert abs(mit["dauer"] - 9) < 0.2


def test_kapitel_und_vorschlaege_mit_kill_daten(umgebung):
    c, mit = umgebung["client"], umgebung["mit"]
    pipeline.speichere_kapitel(mit, [
        {"start": 0, "ende": 3, "titel": "Kill", "kills": [1.0]},
        {"start": 3, "ende": 6, "titel": "3× Kill", "kills": [4.0, 4.5, 5.0]},
        {"start": 6, "ende": 9, "titel": "Kill", "kills": [7.5]},
    ])
    k = c.get("/api/kapitel", query_string={"pfad": str(mit)}).get_json()
    assert [x["titel"] for x in k["kapitel"]] == ["#1 Kill", "#2 3× Kill", "#3 Kill"]
    assert k["kapitel"][1]["kills"] == [4.0, 4.5, 5.0] and k["kills"] == [1.0, 4.0, 4.5, 5.0, 7.5]
    v = c.get("/api/thumbnail-vorschlaege", query_string={"pfad": str(mit)}).get_json()
    assert len(v) == 4
    assert v[0]["t"] == pytest.approx(5.4) and "3 Kills" in v[0]["grund"]   # meiste Kills zuerst
    assert {round(x["t"], 1) for x in v[1:3]} == {1.4, 7.9}


def test_vorschlaege_ohne_kill_daten(umgebung):
    v = umgebung["client"].get("/api/thumbnail-vorschlaege", query_string={"pfad": str(umgebung["hoch"])}).get_json()
    assert len(v) == 4 and all(0 < x["t"] < 4 for x in v)


def test_thumbnail_speichern(umgebung):
    import cv2
    c = umgebung["client"]
    for video, groesse in ((umgebung["mit"], (720, 1280)), (umgebung["hoch"], (1920, 1080))):
        d = c.post("/api/thumbnail", json={"pfad": str(video), "t": 2.0}).get_json()
        bild = cv2.imread(d["pfad"])
        assert bild.shape[:2] == groesse and d["name"].endswith(" - Thumbnail.jpg")
    liste = c.get("/api/meine-videos").get_json()["videos"]
    assert all(v["thumbnail"] for v in liste)
    assert c.get("/api/thumbnail-bild", query_string={"pfad": str(umgebung["mit"])}).status_code == 200
    assert not list(umgebung["ausgabe"].rglob("*.teil.jpg"))


def test_schreiben_nur_im_highlights_ordner(umgebung):
    fremd = _video(umgebung["tmp"] / "woanders" / "fremd.mp4", 160, 90, 2)
    c = umgebung["client"]
    assert c.post("/api/thumbnail", json={"pfad": str(fremd), "t": 1}).status_code == 403
    assert c.post("/api/loeschen", json={"pfad": str(fremd)}).status_code == 403
    assert fremd.is_file()


def test_loeschen_mit_thumbnail(umgebung, monkeypatch):
    weg: list[Path] = []
    monkeypatch.setattr(dateien, "in_papierkorb", lambda p: weg.append(p))
    c, mit = umgebung["client"], umgebung["mit"]
    c.post("/api/thumbnail", json={"pfad": str(mit), "t": 1})
    assert c.post("/api/loeschen", json={"pfad": str(mit)}).status_code == 200
    assert weg == [mit.resolve(), pipeline.thumbnail_pfad(mit.resolve())]


@pytest.mark.skipif(sys.platform != "win32", reason="nur Windows")
def test_papierkorb_echt(tmp_path):
    """Echter Papierkorb-Aufruf mit einer winzigen Datei."""
    p = tmp_path / "hc-papierkorb-test.mp4"
    p.write_bytes(b"0" * 10)
    dateien.in_papierkorb(p)
    assert not p.exists()


def test_speichern_unter(umgebung, monkeypatch):
    c, mit = umgebung["client"], umgebung["mit"]
    ziel = umgebung["tmp"] / "Kopien" / "meine kopie.mp4"
    monkeypatch.setattr(dateien, "waehle_speicherort", lambda v: ziel)
    d = c.post("/api/speichern-unter", json={"pfad": str(mit)}).get_json()
    ende = time.time() + 20
    while time.time() < ende:
        a = c.get(f"/api/auftrag/{d['id']}").get_json()
        if a["status"] != "laeuft":
            break
        time.sleep(0.05)
    assert a["status"] == "fertig" and a["ergebnis"]["pfad"] == str(ziel)
    assert ziel.read_bytes() == mit.read_bytes()
    assert not list(ziel.parent.glob("*.teil"))
    # Dialog abgebrochen / gleiche Datei gewählt
    monkeypatch.setattr(dateien, "waehle_speicherort", lambda v: None)
    assert c.post("/api/speichern-unter", json={"pfad": str(mit)}).get_json() == {"abgebrochen": True}
    monkeypatch.setattr(dateien, "waehle_speicherort", lambda v: mit)
    assert c.post("/api/speichern-unter", json={"pfad": str(mit)}).status_code == 400
