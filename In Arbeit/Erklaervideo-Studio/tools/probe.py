"""Kurze Hörprobe einer Stimme. Aufruf: python tools/probe.py <stimmen-id> <tempo z. B. -3> <ziel.mp3>"""
import asyncio
import sys

import edge_tts

TEXT = "Hallo! So klinge ich, wenn ich dein Erklärvideo spreche. Klingt gut, oder?"


async def main() -> None:
    stimme, tempo, ziel = sys.argv[1], int(float(sys.argv[2])), sys.argv[3]
    rate = f"{'+' if tempo >= 0 else ''}{tempo}%"
    for versuch in range(3):
        try:
            await edge_tts.Communicate(TEXT, stimme, rate=rate).save(ziel)
            return
        except Exception as e:  # kostenloser Dienst liefert gelegentlich nichts
            if versuch == 2:
                sys.exit(f"Hörprobe fehlgeschlagen (Internet?): {e}")
            await asyncio.sleep(1.5)


asyncio.run(main())
