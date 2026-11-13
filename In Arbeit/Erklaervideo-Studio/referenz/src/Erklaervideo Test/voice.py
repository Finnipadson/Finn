"""Erzeugt die Sprecherstimme + Wort-Zeitstempel für das Erklärvideo.

Aufruf (im remotion-Ordner):  python "src/Erklaervideo Test/voice.py"
Ergebnis:
  public/erklaervideo-test/voice.mp3    – Tonspur
  src/Erklaervideo Test/words.json      – jedes Wort des Textes mit Start/Ende in Sekunden
Text oder Stimme ändern → Skript neu ausführen → Video passt sich automatisch an.
"""
import asyncio
import json
import re
import sys
from pathlib import Path

import edge_tts

VOICE = "de-DE-ConradNeural"   # Alternativen: de-DE-KatjaNeural, de-DE-FlorianMultilingualNeural
RATE = "+8%"

TEXT = (
    "Ein Login-Bug kommt rein. "
    "Erst mal nicht raten: Stacktrace lesen, Logs checken, "
    "einen Test schreiben, der den Fehler zeigt. "
    "Dann den Aufwand hochdrehen. "
    "Fünf Minuten später: Test grün, und der Fix ist serviert!"
)

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
AUDIO = ROOT / "public" / "erklaervideo-test" / "voice.mp3"
WORDS = HERE / "words.json"


def norm(s: str) -> str:
    return re.sub(r"[^\wäöüß]", "", s.lower())


async def main() -> None:
    AUDIO.parent.mkdir(parents=True, exist_ok=True)
    com = edge_tts.Communicate(TEXT, VOICE, rate=RATE, boundary="WordBoundary")
    bounds = []
    with open(AUDIO, "wb") as f:
        async for chunk in com.stream():
            if chunk["type"] == "audio":
                f.write(chunk["data"])
            elif chunk["type"] == "WordBoundary":
                bounds.append({
                    "text": chunk["text"],
                    "start": chunk["offset"] / 1e7,
                    "end": (chunk["offset"] + chunk["duration"]) / 1e7,
                })

    # Wörter aus dem Text (mit Satzzeichen) den Zeitstempeln der Stimme zuordnen.
    # Die Stimme kann ein Wort aufteilen ("Login-Bug" -> "Login", "Bug").
    words, i = [], 0
    for token in TEXT.split():
        target, acc, start, end = norm(token), "", None, None
        while i < len(bounds) and acc != target:
            acc += norm(bounds[i]["text"])
            start = bounds[i]["start"] if start is None else start
            end = bounds[i]["end"]
            i += 1
            if not target.startswith(acc):
                sys.exit(f"Zuordnung fehlgeschlagen bei '{token}' (Stimme: '{acc}')")
        if acc != target:
            sys.exit(f"Wort '{token}' nicht in der Sprachausgabe gefunden")
        words.append({"text": token, "start": round(start, 3), "end": round(end, 3)})

    WORDS.write_text(json.dumps(words, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(words)} Wörter, Länge ca. {words[-1]['end']:.1f} s -> {AUDIO.name}, {WORDS.name}")


asyncio.run(main())
