"""Erzeugt die Sprecherstimme + Wort-Zeitstempel für das Pythagoras-Video.

Aufruf (im remotion-Ordner):  python "src/Satz des Pythagoras/voice.py"
Ergebnis:
  public/pythagoras/voice.mp3          – Tonspur
  src/Satz des Pythagoras/words.json   – jedes Wort des Textes mit Start/Ende in Sekunden
Text oder Stimme ändern → Skript neu ausführen → Video passt sich automatisch an.
Hinweis: Keine einzelnen Gedankenstriche als eigenes Wort verwenden.
"""
import asyncio
import json
import re
import sys
from pathlib import Path

import edge_tts

VOICE = "de-DE-ConradNeural"   # Alternativen: de-DE-KatjaNeural, de-DE-FlorianMultilingualNeural
RATE = "+0%"

TEXT = (
    "Der Satz des Pythagoras, einfach erklärt. "
    "Er gilt für jedes rechtwinklige Dreieck. "
    "Die zwei kurzen Seiten am rechten Winkel heißen Katheten. Wir nennen sie a und b. "
    "Die lange Seite gegenüber vom rechten Winkel ist die Hypotenuse, c. "
    "Jetzt kommt der Trick: Baut man auf jede Seite ein Quadrat, "
    "dann sind die zwei kleinen Quadrate zusammen genau so groß wie das große. "
    "Also: a Quadrat plus b Quadrat gleich c Quadrat. "
    "Ein Beispiel: a ist 3 und b ist 4. "
    "3 mal 3 ist 9, 4 mal 4 ist 16. "
    "9 plus 16 ergibt 25. "
    "Die Wurzel aus 25 ist 5, also ist c gleich 5. "
    "Merke: a Quadrat plus b Quadrat gleich c Quadrat."
)

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
AUDIO = ROOT / "public" / "pythagoras" / "voice.mp3"
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

    # Zeichengenaue Zuordnung: Die Stimme fasst manchmal mehrere Wörter zu einem
    # Block zusammen ("3 mal 3") oder teilt eins auf ("Login-Bug"). Jedes Zeichen
    # bekommt eine Zeit (anteilig innerhalb seines Blocks), daraus ergeben sich Wortzeiten.
    char_times = []
    for b in bounds:
        n = len(norm(b["text"]))
        for k in range(n):
            char_times.append((b["start"] + (b["end"] - b["start"]) * k / n,
                               b["start"] + (b["end"] - b["start"]) * (k + 1) / n))
    spoken = "".join(norm(b["text"]) for b in bounds)
    tokens = TEXT.split()
    if "".join(norm(t) for t in tokens) != spoken:
        sys.exit("Text und Sprachausgabe passen nicht zusammen (Zahlen/Abkürzungen anders gesprochen?)")
    words, pos = [], 0
    for token in tokens:
        n = len(norm(token))
        if n == 0:
            sys.exit(f"Token '{token}' enthält keine Buchstaben/Ziffern – bitte aus dem Text entfernen")
        words.append({"text": token,
                      "start": round(char_times[pos][0], 3),
                      "end": round(char_times[pos + n - 1][1], 3)})
        pos += n

    WORDS.write_text(json.dumps(words, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(words)} Wörter, Länge ca. {words[-1]['end']:.1f} s -> {AUDIO.name}, {WORDS.name}")


asyncio.run(main())
