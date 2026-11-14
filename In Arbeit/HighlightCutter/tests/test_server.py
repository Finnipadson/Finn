"""Tests für Phase 4 (Server-API) mit Flask-Testclient und Platzhalter (mock)."""
from __future__ import annotations

import json
import shutil
import subprocess
import time
from pathlib import Path

import pytest

from cutter import medien, pipeline
from cutter.server import app as app_modul
from cutter.server import dateien, mock

HAT_FFMPEG = shutil.which("ffmpeg") is not None


@pytest.fixture(scope="session")
def testvideo(tmp_path_factory) -> Path:
    """Kleines echtes Video (20 s, 320×180, mit Ton) – oder eine Fake-Datei, wenn FFmpeg fehlt."""
    ordner = tmp_path_factory.mktemp("videos") / "Apex Legends"
    ordner.mkdir()
    ziel = ordner / "Apex Legends 2026.01.01 - 20.00.00.01.mp4"
    if HAT_FFMPEG:
        subprocess.run([medien.FFMPEG, "-y", "-v", "error", "-f", "lavfi", "-i", "testsrc=size=320x180:rate=30:duration=20",
                        "-f", "lavfi", "-i", "sine=frequency=440:duration=20", "-shortest",
                        "-c:v", "libx264", "-preset", "ultrafast", "-c:a", "aac", str(ziel)],
                       check=True, capture_output=True)
    else:
        ziel.write_bytes(bytes(range(256)) * 400)
    (ordner.parent / "Valorant").mkdir()
    (ordner.parent / "Valorant" / "runde.mkv").write_bytes(b"x" * 1000)
    (ordner.parent / "Valorant" / "notiz.txt").write_text("kein Video")
    return ziel


@pytest.fixture
def client(tmp_path, monkeypatch, testvideo):
    monkeypatch.setattr(pipeline, "DATEN", tmp_path / "daten")
    monkeypatch.setenv("HC_VIDEOS", str(testvideo.parent.parent))
    monkeypatch.setenv("HC_MOCK", "1")
    monkeypatch.delenv("HC_MOCK_FEHLER", raising=False)
    monkeypatch.setattr(mock, "PAUSE", 0.02)
    app = app_modul.erstelle_app()
    app.testing = True
    return app.test_client()


def warte(client, auftrag_id: str, timeout: float = 20) -> dict:
    ende = time.time() + timeout
    while time.time() < ende:
        d = client.get(f"/api/auftrag/{auftrag_id}").get_json()
        if d["status"] != "laeuft":
            return d
        time.sleep(0.05)
    raise AssertionError("Auftrag wurde nicht fertig")


# ---------------------------------------------------------------- Grundlagen
def test_oberflaeche_wird_ausgeliefert(client):
    r = client.get("/")
    assert r.status_code == 200 and b"Highlight Cutter" in r.data
    assert client.get("/app.js").status_code == 200
    assert client.get("/style.css").status_code == 200


def test_info(client):
    d = client.get("/api/info").get_json()
    assert d["app"] == "highlight-cutter" and d["mock"] is True


def test_videos_liste(client, testvideo):
    d = client.get("/api/videos").get_json()
    namen = {v["name"]: v for v in d}
    assert testvideo.name in namen and "runde.mkv" in namen and "notiz.txt" not in namen
    v = namen[testvideo.name]
    assert v["spiel"] == "Apex Legends" and v["groesse"] > 0 and v["pfad"] == str(testvideo)
    assert namen["runde.mkv"]["spiel"] == "Valorant"
    assert [x["datum"] for x in d] == sorted((x["datum"] for x in d), reverse=True)


def test_videos_ohne_ordner(client, monkeypatch, tmp_path):
    monkeypatch.setenv("HC_VIDEOS", str(tmp_path / "gibtsnicht"))
    assert client.get("/api/videos").get_json() == []


def test_dateien_finden(client, testvideo):
    d = client.post("/api/dateien-finden", json={"dateien": [
        {"name": testvideo.name, "groesse": testvideo.stat().st_size},
        {"name": "fehlt.mp4", "groesse": 5}]}).get_json()
    assert d[0]["video"]["pfad"] == str(testvideo)
    assert d[1]["video"] is None


def test_pfad_waehlen_ohne_dialog(client, monkeypatch, testvideo):
    class Antwort:
        stdout = json.dumps([str(testvideo), "C:/gibtsnicht.mp4", str(testvideo.parent.parent / "Valorant" / "notiz.txt")])
    monkeypatch.setattr(dateien.subprocess, "run", lambda *a, **k: Antwort())
    d = client.post("/api/pfad-waehlen").get_json()
    assert [v["pfad"] for v in d["videos"]] == [str(testvideo)]


# ---------------------------------------------------------------- Video + Bild
def test_video_ganz_und_range(client, testvideo):
    groesse = testvideo.stat().st_size
    url = "/api/video?pfad=" + str(testvideo)
    r = client.get(url)
    assert r.status_code == 200 and r.headers["Accept-Ranges"] == "bytes" and len(r.data) == groesse
    assert r.mimetype == "video/mp4"
    r = client.get(url, headers={"Range": "bytes=100-199"})
    assert r.status_code == 206
    assert r.headers["Content-Range"] == f"bytes 100-199/{groesse}"
    assert r.data == testvideo.read_bytes()[100:200]
    r = client.get(url, headers={"Range": f"bytes={groesse - 10}-"})
    assert r.status_code == 206 and len(r.data) == 10
    r = client.get(url, headers={"Range": f"bytes={groesse + 10}-"})
    assert r.status_code == 416


def test_video_nur_videodateien(client, testvideo, tmp_path):
    txt = testvideo.parent.parent / "Valorant" / "notiz.txt"
    assert client.get("/api/video?pfad=" + str(txt)).status_code == 403
    assert client.get("/api/video?pfad=" + str(tmp_path / "fehlt.mp4")).status_code == 404
    assert client.get("/api/video?pfad=relativ.mp4").status_code == 400
    assert client.get("/api/video").status_code == 400
    assert "fehler" in client.get("/api/video?pfad=" + str(txt)).get_json()


def test_bild(client, testvideo):
    r = client.get(f"/api/bild?pfad={testvideo}&t=3")
    assert r.status_code == 200 and r.mimetype == "image/jpeg" and r.data[:2] == b"\xff\xd8"
    assert client.get(f"/api/bild?pfad={testvideo}&t=abc").status_code == 400


# ---------------------------------------------------------------- Einstellungen
def test_einstellungen_speichern_und_laden(client):
    d = client.get("/api/einstellungen").get_json()
    assert d["format"] == "16:9" and d["uebergang"] == 0.3
    r = client.put("/api/einstellungen", json={"format": "9:16", "champion": True, "uebergang": 5, "quatsch": 1})
    assert r.status_code == 200
    d = r.get_json()
    assert d["format"] == "9:16" and d["champion"] is True and d["uebergang"] == 2.0 and "quatsch" not in d
    datei = pipeline.DATEN / "einstellungen.json"
    assert json.loads(datei.read_text(encoding="utf-8"))["format"] == "9:16"
    assert client.get("/api/einstellungen").get_json()["champion"] is True
    # Teil-Update behält den Rest
    client.put("/api/einstellungen", json={"eigene_tode": True})
    d = client.get("/api/einstellungen").get_json()
    assert d["format"] == "9:16" and d["eigene_tode"] is True
    # Unsinn
    assert client.put("/api/einstellungen", json={"format": "4:3"}).get_json()["format"] == "16:9"
    assert client.put("/api/einstellungen", json={"uebergang": "viel"}).status_code == 400


def test_kaputte_einstellungsdatei(client):
    pipeline.DATEN.mkdir(parents=True, exist_ok=True)
    (pipeline.DATEN / "einstellungen.json").write_text("{kaputt", encoding="utf-8")
    assert client.get("/api/einstellungen").get_json()["format"] == "16:9"


# ---------------------------------------------------------------- Aufträge
def test_analyse_mock(client, testvideo):
    r = client.post("/api/analyse", json={"videos": [str(testvideo)], "einstellungen": {"eigene_tode": False}})
    assert r.status_code == 200
    d = warte(client, r.get_json()["id"])
    assert d["status"] == "fertig" and d["mock"] is True and d["anteil"] == 1.0
    clips = d["ergebnis"]["clips"]
    analysen = d["ergebnis"]["analysen"]
    assert clips and len(analysen) == 1
    for c in clips:
        assert Path(c["video"]) == testvideo.resolve()
        assert 0 <= c["start"] < c["ende"] <= analysen[0]["dauer"] + 0.01
        assert c["grund"]


def test_analyse_fehlerhafte_anfragen(client, tmp_path, testvideo):
    assert client.post("/api/analyse", json={"videos": []}).status_code == 400
    r = client.post("/api/analyse", json={"videos": [str(tmp_path / "weg.mp4")]})
    assert r.status_code == 404 and "nicht gefunden" in r.get_json()["fehler"]
    assert client.post("/api/analyse", data="kein json").status_code == 400


def test_auftrag_abbrechen(client, testvideo, monkeypatch):
    monkeypatch.setattr(mock, "PAUSE", 0.2)
    aid = client.post("/api/analyse", json={"videos": [str(testvideo)]}).get_json()["id"]
    time.sleep(0.3)
    assert client.get(f"/api/auftrag/{aid}").get_json()["status"] == "laeuft"
    r = client.post(f"/api/auftrag/{aid}/abbrechen")
    assert r.status_code == 200
    d = warte(client, aid)
    assert d["status"] == "abgebrochen"
    assert client.get("/api/auftrag/gibtsnicht").status_code == 404


def test_auftrag_fehler_menschlich(client, testvideo, monkeypatch):
    monkeypatch.delenv("HC_MOCK")

    def kaputt(*a, **k):
        raise PermissionError(13, "Zugriff verweigert", "C:/x.mp4")
    monkeypatch.setattr(pipeline, "analysiere", kaputt)
    d = warte(client, client.post("/api/analyse", json={"videos": [str(testvideo)]}).get_json()["id"])
    assert d["status"] == "fehler" and "Kein Zugriff" in d["fehler"]


def test_mock_fallback_bei_notimplemented(client, testvideo, monkeypatch):
    monkeypatch.delenv("HC_MOCK")

    def nicht_fertig(*a, **k):
        raise NotImplementedError("Phase 1 noch nicht gebaut")
    monkeypatch.setattr(pipeline, "analysiere", nicht_fertig)
    d = warte(client, client.post("/api/analyse", json={"videos": [str(testvideo)]}).get_json()["id"])
    assert d["status"] == "fertig" and d["mock"] is True and d["ergebnis"]["clips"]


def test_echte_pipeline_wird_aufgerufen(client, testvideo, monkeypatch):
    from cutter.schema import Analyse, Clip, Event
    monkeypatch.delenv("HC_MOCK")
    gesehen = {}

    def echt(videos, e, fortschritt=None, abbrechen=None, **k):
        gesehen["videos"], gesehen["e"] = videos, e
        fortschritt(0.5, "halb")
        return [Analyse(videos[0], 20, "apex", [Event(10, "kill")])], [Clip(videos[0], 4, 13, "Kill", [Event(10, "kill")])]
    monkeypatch.setattr(pipeline, "analysiere", echt)
    d = warte(client, client.post("/api/analyse", json={"videos": [str(testvideo)], "einstellungen": {"champion": True}}).get_json()["id"])
    assert d["status"] == "fertig" and d["mock"] is False
    assert d["ergebnis"]["clips"][0]["grund"] == "Kill" and gesehen["e"].champion is True


@pytest.mark.skipif(not HAT_FFMPEG, reason="FFmpeg fehlt")
def test_export_mock(client, testvideo):
    clips = [{"video": str(testvideo), "start": 2, "ende": 9, "grund": "Kill", "events": [], "aktiv": True},
             {"video": str(testvideo), "start": 12, "ende": 18, "grund": "Doppel-Kill", "events": [], "aktiv": False}]
    r = client.post("/api/export", json={"clips": clips, "einstellungen": {"format": "9:16"}})
    assert r.status_code == 200
    d = warte(client, r.get_json()["id"], 60)
    assert d["status"] == "fertig", d
    p = Path(d["ergebnis"]["pfad"])
    assert p.is_file() and p.stat().st_size < 2_000_000 and pipeline.DATEN in p.parents
    assert not list(p.parent.glob("*.teil.mp4"))
    info = medien.info(p)
    assert (info.breite, info.hoehe) == (360, 640)


def test_export_fehler_und_pruefung(client, testvideo, monkeypatch):
    clip = {"video": str(testvideo), "start": 2, "ende": 9, "grund": "Kill", "events": [], "aktiv": True}
    assert client.post("/api/export", json={"clips": []}).status_code == 400
    r = client.post("/api/export", json={"clips": [{**clip, "aktiv": False}]})
    assert r.status_code == 400 and "mindestens einen" in r.get_json()["fehler"]
    assert client.post("/api/export", json={"clips": [{**clip, "ende": 2.1}]}).status_code == 400
    assert client.post("/api/export", json={"clips": [{**clip, "video": "C:/weg.mp4"}]}).status_code == 404
    ziel_nvidia = str(testvideo.parent / "raus.mp4")
    monkeypatch.setenv("HC_VIDEOS", str(testvideo.parent.parent))
    assert client.post("/api/export", json={"clips": [clip], "ziel": ziel_nvidia}).status_code == 400
    monkeypatch.setenv("HC_MOCK_FEHLER", "export")
    d = warte(client, client.post("/api/export", json={"clips": [clip]}).get_json()["id"])
    assert d["status"] == "fehler" and "Demo-Fehler" in d["fehler"]


def test_export_abbrechen(client, testvideo, monkeypatch):
    monkeypatch.setattr(mock, "PAUSE", 0.2)
    clip = {"video": str(testvideo), "start": 2, "ende": 9, "grund": "Kill", "events": [], "aktiv": True}
    aid = client.post("/api/export", json={"clips": [clip]}).get_json()["id"]
    time.sleep(0.3)
    client.post(f"/api/auftrag/{aid}/abbrechen")
    assert warte(client, aid)["status"] == "abgebrochen"
    assert not list((pipeline.DATEN / "mock-export").glob("*.mp4")) if (pipeline.DATEN / "mock-export").exists() else True


def test_oeffnen(client, testvideo, monkeypatch, tmp_path):
    aufrufe = []
    monkeypatch.setattr(dateien, "zeige_im_ordner", lambda p: aufrufe.append(("zeigen", p)))
    monkeypatch.setattr(dateien, "abspielen", lambda p: aufrufe.append(("abspielen", p)))
    assert client.post("/api/oeffnen", json={"pfad": str(testvideo)}).status_code == 200
    assert client.post("/api/oeffnen", json={"pfad": str(testvideo), "aktion": "abspielen"}).status_code == 200
    assert [a for a, _ in aufrufe] == ["zeigen", "abspielen"]
    txt = testvideo.parent.parent / "Valorant" / "notiz.txt"
    assert client.post("/api/oeffnen", json={"pfad": str(txt), "aktion": "abspielen"}).status_code == 403


def test_menschliche_fehlertexte():
    from cutter.server.auftraege import menschlich
    assert "FFmpeg wurde nicht gefunden" in menschlich(FileNotFoundError(2, "x", "ffmpeg"))
    assert "kein Platz" in menschlich(OSError(28, "No space left on device"))
    e = subprocess.CalledProcessError(1, ["ffmpeg"], stderr="zeile1\nInvalid data found")
    assert "Invalid data found" in menschlich(e)
    assert "Unerwarteter Fehler" in menschlich(KeyError("x"))
