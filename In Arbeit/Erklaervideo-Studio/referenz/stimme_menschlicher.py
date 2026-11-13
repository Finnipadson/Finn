"""Vorher/Nachher-Hörprobe: Ava Multilingual, einmal roh, einmal 'menschlicher'.

Nachher = gesprächiger Text, satzweise vertont, unterschiedliche Pausen, etwas
langsamer, leichter Raumklang + Wärme-EQ, Lautheit normalisiert.
Zusätzlich eine Version mit leisem Musik-Teppich.
"""
import asyncio
import shutil
import subprocess
import sys
from pathlib import Path

import edge_tts

OUT = Path(sys.argv[1])
WORK = Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
WORK.mkdir(parents=True, exist_ok=True)
VOICE = "en-US-AvaMultilingualNeural"
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"

BEFORE = ("Der Satz des Pythagoras, einfach erklärt. Er gilt für jedes rechtwinklige Dreieck. "
          "Baut man auf jede Seite ein Quadrat, dann sind die zwei kleinen Quadrate zusammen "
          "genau so groß wie das große.")

# (Satz, Pause danach in Sekunden, Tempo)
AFTER = [
    ("Okay, pass auf.", 0.35, "-2%"),
    ("Der Satz des Pythagoras.", 0.30, "-6%"),
    ("Klingt kompliziert, ist er aber gar nicht.", 0.60, "+0%"),
    ("Er gilt für jedes Dreieck mit einem rechten Winkel.", 0.55, "-4%"),
    ("Und jetzt kommt der Trick:", 0.35, "-6%"),
    ("Du baust auf jede Seite ein Quadrat.", 0.60, "-4%"),
    ("Die zwei kleinen Quadrate zusammen?", 0.30, "-4%"),
    ("Sind genau so groß wie das große.", 0.70, "-8%"),
    ("Das ist schon alles.", 0.0, "-2%"),
]


def ff(*args: str) -> None:
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", *args], check=True)


async def main() -> None:
    await edge_tts.Communicate(BEFORE, VOICE).save(str(OUT / "A Vorher (Ava roh).mp3"))

    parts = []
    for i, (text, pause, rate) in enumerate(AFTER):
        mp3 = WORK / f"s{i}.mp3"
        await edge_tts.Communicate(text, VOICE, rate=rate).save(str(mp3))
        wav = WORK / f"s{i}.wav"
        # Stille am Anfang/Ende der TTS-Schnipsel entfernen, dann definierte Pause anhängen
        ff("-i", str(mp3), "-af",
           "silenceremove=start_periods=1:start_threshold=-45dB,areverse,"
           "silenceremove=start_periods=1:start_threshold=-45dB,areverse,"
           f"apad=pad_dur={pause}", "-ar", "48000", "-ac", "1", str(wav))
        parts.append(wav)

    lst = WORK / "list.txt"
    lst.write_text("".join(f"file '{p.as_posix()}'\n" for p in parts), encoding="utf-8")
    raw = WORK / "after_raw.wav"
    ff("-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(raw))

    # Wärme + leichter Raum + sanfte Kompression + Lautheit
    voice_fx = (
        "highpass=f=75,"
        "equalizer=f=180:t=q:w=1.0:g=2.5,"
        "equalizer=f=6500:t=q:w=1.5:g=-2,"
        "aecho=0.85:0.6:35|62:0.10|0.06,"
        "acompressor=threshold=-20dB:ratio=2.5:attack=8:release=120,"
        "loudnorm=I=-16:TP=-1.5:LRA=9"
    )
    after = WORK / "after_fx.wav"
    ff("-i", str(raw), "-af", f"adelay=300,{voice_fx}", "-ar", "48000", str(after))
    ff("-i", str(after), "-b:a", "192k", str(OUT / "B Nachher (menschlicher).mp3"))

    # Leiser Musik-Teppich: zwei weiche Akkorde, die sanft ineinander übergehen
    dur = float(subprocess.run(
        [shutil.which("ffprobe") or "ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "csv=p=0", str(after)], capture_output=True, text=True, check=True).stdout.strip()) + 1.5
    chord_a = "sin(2*PI*130.81*t)+sin(2*PI*164.81*t)+sin(2*PI*196.00*t)+0.5*sin(2*PI*261.63*t)"
    chord_b = "sin(2*PI*110.00*t)+sin(2*PI*130.81*t)+sin(2*PI*164.81*t)+0.5*sin(2*PI*220.00*t)"
    w = "(0.5+0.5*cos(2*PI*t/8))"
    expr = f"0.08*({w}*({chord_a})+(1-{w})*({chord_b}))*(0.85+0.15*sin(2*PI*t/3))"
    pad = WORK / "pad.wav"
    ff("-f", "lavfi", "-i", f"aevalsrc='{expr}':s=48000:d={dur}",
       "-af", f"lowpass=f=900,aecho=0.8:0.7:120|240:0.35|0.25,afade=t=in:d=1.5,"
              f"afade=t=out:st={dur - 2}:d=2,volume=-6dB", str(pad))
    ff("-i", str(after), "-i", str(pad), "-filter_complex",
       "[1:a]volume=1.4[m];[0:a][m]amix=inputs=2:duration=longest:normalize=0,alimiter=limit=0.95",
       "-b:a", "192k", str(OUT / "C Nachher + leise Musik.mp3"))
    print("fertig")


asyncio.run(main())
