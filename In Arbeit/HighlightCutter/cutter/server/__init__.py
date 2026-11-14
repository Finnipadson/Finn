"""Phase 4 – lokaler Server + Web-Oberfläche. Bereich von Agent 4."""
from __future__ import annotations

import json
import logging
import threading
import urllib.request


def _laeuft_schon(port: int) -> bool:
    """Läuft auf dem Port schon ein Highlight Cutter? (z. B. start.bat doppelt geklickt)"""
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/api/info", timeout=1.5) as r:
            return json.loads(r.read().decode("utf-8")).get("app") == "highlight-cutter"
    except Exception:  # noqa: BLE001
        return False


def starte(port: int = 4720, browser_oeffnen: bool = True) -> None:
    """Startet den Server auf 127.0.0.1:port und öffnet optional die Oberfläche."""
    from .app import erstelle_app
    from .dateien import oeffne_browser

    url = f"http://127.0.0.1:{port}"
    if _laeuft_schon(port):
        print(f"Highlight Cutter läuft schon auf {url}.")
        if browser_oeffnen:
            oeffne_browser(url)
        return
    app = erstelle_app()
    logging.getLogger("werkzeug").setLevel(logging.WARNING)   # kein Log für jede Fortschrittsabfrage
    if browser_oeffnen:
        threading.Timer(0.8, oeffne_browser, [url]).start()
    print(f"Highlight Cutter läuft auf {url}\nZum Beenden dieses Fenster schließen (oder Strg+C).")
    app.run(host="127.0.0.1", port=port, threaded=True, use_reloader=False, debug=False)
