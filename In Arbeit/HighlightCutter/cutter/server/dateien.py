"""Dateien finden und anzeigen: Aufnahmen-Liste, Drag-&-Drop-Zuordnung, Windows-Dateidialog, Explorer."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

from .. import medien


def nvidia_ordner() -> Path:
    return Path(os.environ.get("HC_VIDEOS", medien.NVIDIA_ORDNER))


def eintrag(pfad: Path, basis: Path | None = None) -> dict:
    st = pfad.stat()
    spiel = "Eigene Dateien"
    if basis is not None:
        try:
            teile = pfad.relative_to(basis).parts
            spiel = teile[0] if len(teile) > 1 else "Sonstige"
        except ValueError:
            pass
    return {"pfad": str(pfad), "name": pfad.name, "spiel": spiel.strip(), "groesse": st.st_size,
            "datum": datetime.fromtimestamp(st.st_mtime).isoformat(timespec="seconds")}


def liste_videos() -> list[dict]:
    """Alle Videos in Videos\\NVIDIA (rekursiv), neueste zuerst."""
    basis = nvidia_ordner()
    if not basis.is_dir():
        return []
    videos = []
    for wurzel, ordner, dateien in os.walk(basis):
        ordner[:] = [o for o in ordner if not o.startswith(".")]
        for d in dateien:
            p = Path(wurzel) / d
            if medien.ist_video(p):
                try:
                    videos.append(eintrag(p, basis))
                except OSError:
                    continue
    videos.sort(key=lambda v: v["datum"], reverse=True)
    return videos


def finde_dateien(gesucht: list[dict], zeitlimit: float = 4.0) -> list[dict]:
    """Ordnet per Drag & Drop abgelegte Dateien (nur Name + Größe bekannt) echten Pfaden zu."""
    offen = {(str(g.get("name", "")).lower(), int(g.get("groesse") or 0)) for g in gesucht}
    gefunden: dict[tuple[str, int], Path] = {}
    home = Path.home()
    wurzeln = [nvidia_ordner(), home / "Videos", home / "Desktop", home / "OneDrive" / "Desktop",
               home / "Downloads", home / "OneDrive" / "Videos"]
    ende = time.monotonic() + zeitlimit
    for w in wurzeln:
        if not offen or not w.is_dir():
            continue
        basistiefe = len(w.parts)
        for wurzel, ordner, dateien in os.walk(w):
            if time.monotonic() > ende or not offen:
                break
            if len(Path(wurzel).parts) - basistiefe >= 4:
                ordner[:] = []
            ordner[:] = [o for o in ordner if not o.startswith((".", "node_modules", "$"))]
            for d in dateien:
                if not medien.ist_video(d):
                    continue
                p = Path(wurzel) / d
                try:
                    schluessel = (d.lower(), p.stat().st_size)
                except OSError:
                    continue
                if schluessel in offen:
                    gefunden[schluessel] = p
                    offen.discard(schluessel)
    ergebnis = []
    for g in gesucht:
        p = gefunden.get((str(g.get("name", "")).lower(), int(g.get("groesse") or 0)))
        ergebnis.append({"name": g.get("name"), "video": eintrag(p, nvidia_ordner()) if p else None})
    return ergebnis


# ---------------------------------------------------------------- Dateidialog
_DIALOG_SKRIPT = r"""
import json, sys, tkinter as tk
from tkinter import filedialog
root = tk.Tk()
root.withdraw()
root.attributes("-topmost", True)
root.lift()
root.focus_force()
pfade = filedialog.askopenfilenames(parent=root, title="Highlight Cutter - Videos auswaehlen",
    initialdir=sys.argv[1], filetypes=[("Videos", "*.mp4 *.mkv *.mov"), ("Alle Dateien", "*.*")])
root.destroy()
print(json.dumps(list(pfade)))
"""
_dialog_lock = threading.Lock()


class DialogBelegt(Exception):
    pass


def waehle_pfade() -> list[dict]:
    """Öffnet den Windows-Dateidialog (tkinter in eigenem Prozess, damit Flask-Threads nicht stören)."""
    if not _dialog_lock.acquire(blocking=False):
        raise DialogBelegt()
    try:
        start = nvidia_ordner() if nvidia_ordner().is_dir() else Path.home() / "Videos"
        python = Path(sys.executable)
        if python.name.lower() == "pythonw.exe":
            python = python.with_name("python.exe")
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        out = subprocess.run([str(python), "-c", _DIALOG_SKRIPT, str(start)], capture_output=True,
                             text=True, encoding="utf-8", timeout=900, env=env,
                             creationflags=medien.FENSTERLOS).stdout.strip()
        pfade = json.loads(out.splitlines()[-1]) if out else []
        return [eintrag(Path(p), nvidia_ordner()) for p in pfade
                if medien.ist_video(p) and Path(p).is_file()]
    finally:
        _dialog_lock.release()


# ---------------------------------------------------------------- Explorer / Player
def zeige_im_ordner(pfad: Path) -> None:
    subprocess.Popen(f'explorer /select,"{pfad}"')


def abspielen(pfad: Path) -> None:
    os.startfile(str(pfad))  # type: ignore[attr-defined]  # nur Windows


def oeffne_browser(url: str) -> None:
    """Edge im App-Modus (eigenes Fenster ohne Adressleiste), sonst Standardbrowser."""
    import shutil
    import webbrowser
    kandidaten = [os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"),
                  os.environ.get("ProgramFiles", r"C:\Program Files")]
    edge = shutil.which("msedge")
    if not edge:
        for k in kandidaten:
            p = Path(k) / "Microsoft" / "Edge" / "Application" / "msedge.exe"
            if p.is_file():
                edge = str(p)
                break
    if edge:
        try:
            subprocess.Popen([edge, f"--app={url}", "--window-size=1480,920"])
            return
        except OSError:
            pass
    webbrowser.open(url)
