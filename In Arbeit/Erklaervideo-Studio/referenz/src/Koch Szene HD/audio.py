"""Ton für die Koch-Szene in hoher Qualität.

Aufruf (im remotion-Ordner):  python "src/Koch Szene HD/audio.py"

Erzeugt:
  public/koch-szene-hd/mix.wav        – fertiger Ton (Stimme + Geräusche + Musik mit Ducking)
  src/Koch Szene HD/words.json        – jedes gesprochene Wort mit Start/Ende (Sekunden)
  src/Koch Szene HD/events.json       – Zeitpunkte für Animation UND Geräusche (eine Quelle)
  src/Koch Szene HD/amps.json         – Lautstärke der Stimme pro Video-Bild (60 fps) für den Mund

Stimme menschlicher: Satz für Satz vertont, eigene Pausen + Tempo pro Satz,
Wärme-EQ, leichter Raum, Kompression, Lautheit -16 LUFS.
"""
import asyncio
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import edge_tts
import numpy as np

VOICE = "en-US-AvaMultilingualNeural"
FPS = 60
SR = 48000
LEAD = 0.6  # Sekunden Stille vor dem ersten Wort

# (Satz, Pause danach, Tempo)
SEGMENTS = [
    ("Okay.", 0.25, "-2%"),
    ("Ein Login-Bug kommt rein.", 0.50, "-4%"),
    ("Erst mal nicht raten.", 0.45, "-4%"),
    ("Stacktrace lesen,", 0.20, "+0%"),
    ("Logs checken,", 0.20, "+0%"),
    ("und einen Test schreiben.", 0.60, "-3%"),
    ("Dann: Hitze hoch!", 0.55, "+0%"),
    ("Einmal kräftig schwenken.", 0.60, "-3%"),
    ("Und fertig.", 0.30, "-4%"),
    ("Der Fix ist serviert.", 0.0, "-6%"),
]

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
PUB = ROOT / "public" / "koch-szene-hd"
WORK = PUB / "_work"
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"


def ff(*args: str) -> None:
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", *args], check=True)


def norm(s: str) -> str:
    return re.sub(r"[^\wäöüß]", "", s.lower())


def read_wav(path: Path) -> np.ndarray:
    raw = subprocess.run([FFMPEG, "-loglevel", "error", "-i", str(path), "-f", "f32le", "-ac", "1",
                          "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def align(text: str, bounds: list[dict]) -> list[dict]:
    """Wörter des Satzes zeichengenau den Zeitstempeln der Stimme zuordnen."""
    times = []
    for b in bounds:
        n = len(norm(b["text"]))
        for k in range(n):
            times.append((b["start"] + (b["end"] - b["start"]) * k / n,
                          b["start"] + (b["end"] - b["start"]) * (k + 1) / n))
    tokens = text.split()
    if "".join(norm(t) for t in tokens) != "".join(norm(b["text"]) for b in bounds):
        sys.exit(f"Text und Sprachausgabe passen nicht zusammen: {text!r}")
    out, pos = [], 0
    for t in tokens:
        n = len(norm(t))
        out.append({"text": t, "start": times[pos][0], "end": times[pos + n - 1][1]})
        pos += n
    return out


async def tts(text: str, rate: str, mp3: Path) -> list[dict]:
    last_err = None
    for attempt in range(3):  # der kostenlose Dienst liefert gelegentlich nichts → erneut versuchen
        try:
            com = edge_tts.Communicate(text, VOICE, rate=rate, boundary="WordBoundary")
            bounds = []
            with open(mp3, "wb") as f:
                async for c in com.stream():
                    if c["type"] == "audio":
                        f.write(c["data"])
                    elif c["type"] == "WordBoundary":
                        bounds.append({"text": c["text"], "start": c["offset"] / 1e7,
                                       "end": (c["offset"] + c["duration"]) / 1e7})
            if bounds:
                return bounds
            last_err = RuntimeError("keine Wort-Zeitstempel")
        except edge_tts.exceptions.NoAudioReceived as e:
            last_err = e
        await asyncio.sleep(1.5 * (attempt + 1))
    sys.exit(f"Sprachausgabe für {text!r} fehlgeschlagen: {last_err}")


async def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)

    # 1) Stimme satzweise, sauber zugeschnitten, mit Pausen aneinandergereiht
    pieces, words, t = [], [], LEAD
    silence = lambda d, p: ff("-f", "lavfi", "-i", f"anullsrc=r={SR}:cl=mono", "-t", f"{d:.3f}",
                               "-c:a", "pcm_s16le", str(p))
    lead = WORK / "lead.wav"
    silence(LEAD, lead)
    pieces.append(lead)
    for i, (text, pause, rate) in enumerate(SEGMENTS):
        mp3 = WORK / f"seg{i}.mp3"
        bounds = await tts(text, rate, mp3)
        a, b = max(0.0, bounds[0]["start"] - 0.06), bounds[-1]["end"] + 0.14
        wav = WORK / f"seg{i}.wav"
        ff("-i", str(mp3), "-af", f"atrim={a:.3f}:{b:.3f},asetpts=PTS-STARTPTS,afade=t=out:st={b - a - 0.04:.3f}:d=0.04",
           "-ar", str(SR), "-ac", "1", "-c:a", "pcm_s16le", str(wav))
        for w in align(text, bounds):
            words.append({"text": w["text"], "start": round(t + w["start"] - a, 3), "end": round(t + w["end"] - a, 3)})
        pieces.append(wav)
        t += b - a
        if pause > 0:
            p = WORK / f"pause{i}.wav"
            silence(pause, p)
            pieces.append(p)
            t += pause
    lst = WORK / "list.txt"
    lst.write_text("".join(f"file '{p.as_posix()}'\n" for p in pieces), encoding="utf-8")
    voice_raw = WORK / "voice_raw.wav"
    ff("-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(voice_raw))
    voice = WORK / "voice.wav"
    ff("-i", str(voice_raw), "-af",
       "highpass=f=75,equalizer=f=180:t=q:w=1.0:g=2.5,equalizer=f=6500:t=q:w=1.5:g=-2,"
       "aecho=0.85:0.6:35|62:0.10|0.06,acompressor=threshold=-20dB:ratio=2.5:attack=8:release=120,"
       "loudnorm=I=-16:TP=-1.5:LRA=9", "-ar", str(SR), "-ac", "1", str(voice))

    # 2) Ereignisse – gleiche Zeitpunkte für Bild und Ton
    def at(word: str, nth: int = 0) -> float:
        hits = [w for w in words if re.sub(r"[.,:!?]+$", "", w["text"]) == word]
        return hits[nth]["start"]
    end = words[-1]["end"]
    ev = {
        "ticket": at("Login-Bug") - 0.15,
        "lookTicket": at("Login-Bug"),
        "chip1": at("Stacktrace"),
        "chip2": at("Logs"),
        "chip3": at("Test"),
        "heat": at("Hitze"),
        "toss": at("schwenken") - 0.05,
        "done": at("fertig"),
        "ding": at("serviert") + 0.1,
        "end": end,
        "duration": round(end + 1.6, 3),
    }
    (HERE / "events.json").write_text(json.dumps(ev, indent=1), encoding="utf-8")
    (HERE / "words.json").write_text(json.dumps(words, ensure_ascii=False, indent=1), encoding="utf-8")
    dur = ev["duration"]

    # 3) Mund-Daten: Lautstärke der Stimme pro Bild
    x = read_wav(voice)
    hop = SR // FPS
    n = int(dur * FPS) + 1
    rms = np.array([np.sqrt(np.mean(x[i * hop:(i + 1) * hop] ** 2)) if i * hop < len(x) else 0.0 for i in range(n)])
    ref = np.percentile(rms[rms > 1e-4], 95) if np.any(rms > 1e-4) else 1.0
    amps = np.clip(rms / ref, 0, 1)
    (HERE / "amps.json").write_text(json.dumps([round(float(a), 3) for a in amps]), encoding="utf-8")

    # 4) Geräusche (synthetisch, kostenlos)
    sfx = {
        "plop": ("aevalsrc='0.7*sin(2*PI*(620*t-1700*t*t))*exp(-22*t)':s=48000:d=0.2", "lowpass=f=3000"),
        "click": ("aevalsrc='0.6*(random(0)-0.5)*exp(-250*t)+0.3*sin(2*PI*2400*t)*exp(-180*t)':s=48000:d=0.05", "highpass=f=900"),
        "whoosh": ("anoisesrc=d=0.55:c=pink:r=48000:a=0.5", "bandpass=f=900:w=1.5,afade=t=in:d=0.25:curve=qsin,afade=t=out:st=0.25:d=0.3"),
        "sizzle": (f"anoisesrc=d={max(1.0, end - ev['heat'] + 0.6):.2f}:c=white:r=48000:a=0.35",
                   "highpass=f=2800,lowpass=f=9000,tremolo=f=11:d=0.5,afade=t=in:d=0.5,afade=t=out:st="
                   f"{max(0.5, end - ev['heat'] - 0.4):.2f}:d=1.0"),
        "thud": ("aevalsrc='0.9*sin(2*PI*85*t)*exp(-16*t)+0.35*(random(0)-0.5)*exp(-45*t)':s=48000:d=0.45", "lowpass=f=2500"),
        "ding": ("aevalsrc='0.45*sin(2*PI*1318.5*t)*exp(-2.6*t)+0.18*sin(2*PI*2637*t)*exp(-4.5*t)+0.08*sin(2*PI*3955.5*t)*exp(-7*t)':s=48000:d=1.8", "aecho=0.8:0.6:60:0.2"),
    }
    files = {}
    for name, (src, fx) in sfx.items():
        p = WORK / f"{name}.wav"
        ff("-f", "lavfi", "-i", src, "-af", fx, "-ac", "1", "-ar", str(SR), str(p))
        files[name] = p
    hits = [  # (Geräusch, Zeitpunkt, Lautstärke)
        ("whoosh", ev["ticket"] - 0.1, 0.35),
        ("plop", ev["chip1"] + 0.28, 0.8), ("plop", ev["chip2"] + 0.28, 0.8), ("plop", ev["chip3"] + 0.28, 0.8),
        ("click", ev["heat"] + 0.00, 0.6), ("click", ev["heat"] + 0.10, 0.5), ("click", ev["heat"] + 0.20, 0.6),
        ("whoosh", ev["heat"] - 0.05, 0.45),
        ("sizzle", ev["heat"] + 0.15, 0.55),
        ("whoosh", ev["toss"], 0.5),
        ("thud", ev["done"] + 0.05, 0.8),
        ("ding", ev["ding"], 0.55),
    ]

    # 5) Musik-Teppich (weiche Akkorde) mit Ducking unter der Stimme
    chord_a = "sin(2*PI*130.81*t)+sin(2*PI*164.81*t)+sin(2*PI*196.00*t)+0.5*sin(2*PI*261.63*t)"
    chord_b = "sin(2*PI*110.00*t)+sin(2*PI*130.81*t)+sin(2*PI*164.81*t)+0.5*sin(2*PI*220.00*t)"
    w = "(0.5+0.5*cos(2*PI*t/6))"
    pad = WORK / "pad.wav"
    ff("-f", "lavfi", "-i", f"aevalsrc='0.08*({w}*({chord_a})+(1-{w})*({chord_b}))*(0.85+0.15*sin(2*PI*t/2.5))':s={SR}:d={dur}",
       "-af", f"lowpass=f=1100,aecho=0.8:0.7:120|240:0.35|0.25,afade=t=in:d=1.2,afade=t=out:st={dur - 1.5}:d=1.5",
       str(pad))

    inputs = ["-i", str(voice), "-i", str(pad)]
    chains, labels = [], []
    for k, (name, at_s, vol) in enumerate(hits):
        inputs += ["-i", str(files[name])]
        ms = max(0, int(at_s * 1000))
        chains.append(f"[{k + 2}:a]adelay={ms}|{ms},volume={vol}[s{k}]")
        labels.append(f"[s{k}]")
    graph = ";".join([
        "[0:a]asplit=2[v][vk]",
        "[1:a]volume=1.3[mu]",
        "[mu][vk]sidechaincompress=threshold=0.03:ratio=5:attack=25:release=350[duck]",
        *chains,
        f"[v][duck]{''.join(labels)}amix=inputs={2 + len(labels)}:duration=first:normalize=0,"
        f"apad=whole_dur={dur},atrim=0:{dur},alimiter=limit=0.95,aformat=channel_layouts=stereo",
    ])
    mix = PUB / "mix.wav"
    ff(*inputs, "-filter_complex", graph, "-ar", str(SR), str(mix))
    print(f"{len(words)} Wörter, Dauer {dur:.1f} s, Ereignisse: " + ", ".join(f"{k}={v:.2f}" for k, v in ev.items()))


asyncio.run(main())
