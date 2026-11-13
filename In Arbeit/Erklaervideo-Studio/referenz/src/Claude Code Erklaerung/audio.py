"""Ton für das Erklärvideo „Claude Code“ (Querformat).

Aufruf (im remotion-Ordner):  python "src/Claude Code Erklaerung/audio.py"

Erzeugt:
  public/claude-code-erklaerung/mix.wav     – fertiger Ton (Stimme + Geräusche + Musik mit Ducking)
  src/Claude Code Erklaerung/words.json     – jedes gesprochene Wort mit Start/Ende (Sekunden)
  src/Claude Code Erklaerung/events.json    – Zeitpunkte für Animation UND Geräusche
"""
import asyncio
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import edge_tts

VOICE = "en-US-AvaMultilingualNeural"
SR = 48000
LEAD = 0.8

# (Szene, Satz, Pause danach, Tempo)
SEGMENTS = [
    (1, "Was ist eigentlich Claude Code?", 0.45, "-4%"),
    (1, "Kurz gesagt: ein KI-Assistent,", 0.15, "-2%"),
    (1, "der nicht nur Fragen beantwortet,", 0.15, "-2%"),
    (1, "sondern selbst am Projekt arbeitet.", 0.9, "-4%"),
    (2, "Bei einem normalen Chatbot kopiert man Code hin und her.", 0.45, "-2%"),
    (2, "Claude Code dagegen arbeitet direkt im Projektordner.", 0.35, "-3%"),
    (2, "Es liest Dateien, schreibt Änderungen,", 0.15, "-2%"),
    (2, "führt Befehle aus und prüft das Ergebnis selbst.", 0.9, "-3%"),
    (3, "Das Prinzip ist eine Schleife.", 0.4, "-4%"),
    (3, "Aufgabe verstehen, Code lesen, Plan machen, ändern, testen.", 0.5, "-6%"),
    (3, "Und wenn ein Test fehlschlägt?", 0.35, "-3%"),
    (3, "Dann sucht Claude den Fehler und versucht es nochmal.", 0.25, "-2%"),
    (3, "So lange, bis es funktioniert.", 0.9, "-5%"),
    (4, "Wichtig ist: Man behält die Kontrolle.", 0.4, "-4%"),
    (4, "Vor riskanten Aktionen fragt Claude nach.", 0.3, "-2%"),
    (4, "Jede Änderung ist sichtbar, und mit Git lässt sich alles zurückdrehen.", 0.4, "-2%"),
    (4, "In einer Datei namens CLAUDE.md legt man außerdem Regeln fest.", 0.25, "-3%"),
    (4, "Zum Beispiel: Nach jeder Änderung speichern und hochladen.", 0.9, "-4%"),
    (5, "Ein Beispiel aus meinen Projekten:", 0.3, "-3%"),
    (5, "Für mein Denkspiel Kopfsache habe ich nur beschrieben, welche Rätsel es geben soll.", 0.3, "-2%"),
    (5, "Claude hat das Spiel gebaut, im Browser getestet und Fehler selbst behoben.", 0.45, "-2%"),
    (5, "Genauso sind ein Tower-Defense-Spiel entstanden,", 0.1, "-2%"),
    (5, "ein Programm, das den PC aufräumt,", 0.15, "-2%"),
    (5, "und sogar dieses Video.", 0.9, "-5%"),
    (6, "Ganz von allein geht es aber nicht.", 0.35, "-4%"),
    (6, "Man muss klar beschreiben, was man will,", 0.15, "-2%"),
    (6, "Ergebnisse prüfen und Entscheidungen treffen.", 0.45, "-3%"),
    (6, "Claude ist eher ein sehr schneller Kollege als ein Zauberknopf.", 0.9, "-4%"),
    (7, "Und als Nächstes?", 0.4, "-4%"),
    (7, "Steht schon in meiner Ideenliste.", 0.0, "-5%"),
]

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
PUB = ROOT / "public" / "claude-code-erklaerung"
WORK = PUB / "_work"
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"


def ff(*args: str) -> None:
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", *args], check=True)


def norm(s: str) -> str:
    return re.sub(r"[^\wäöüß]", "", s.lower())


def align(text: str, bounds: list[dict]) -> list[dict]:
    times = []
    for b in bounds:
        n = len(norm(b["text"]))
        for k in range(n):
            times.append((b["start"] + (b["end"] - b["start"]) * k / n,
                          b["start"] + (b["end"] - b["start"]) * (k + 1) / n))
    tokens = text.split()
    if "".join(norm(t) for t in tokens) != "".join(norm(b["text"]) for b in bounds):
        sys.exit(f"Text und Sprachausgabe passen nicht zusammen: {text!r} / {[b['text'] for b in bounds]}")
    out, pos = [], 0
    for t in tokens:
        n = len(norm(t))
        out.append({"text": t, "start": times[pos][0], "end": times[pos + n - 1][1]})
        pos += n
    return out


async def tts(text: str, rate: str, mp3: Path) -> list[dict]:
    last = None
    for attempt in range(4):
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
        except edge_tts.exceptions.NoAudioReceived as e:
            last = e
        await asyncio.sleep(1.5 * (attempt + 1))
    sys.exit(f"Sprachausgabe für {text!r} fehlgeschlagen: {last}")


async def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    silence = lambda d, p: ff("-f", "lavfi", "-i", f"anullsrc=r={SR}:cl=mono", "-t", f"{d:.3f}", "-c:a", "pcm_s16le", str(p))
    lead = WORK / "lead.wav"
    silence(LEAD, lead)
    pieces, words, scenes, t = [lead], [], {}, LEAD
    for i, (scene, text, pause, rate) in enumerate(SEGMENTS):
        mp3 = WORK / f"seg{i}.mp3"
        bounds = await tts(text, rate, mp3)
        a, b = max(0.0, bounds[0]["start"] - 0.06), bounds[-1]["end"] + 0.14
        wav = WORK / f"seg{i}.wav"
        ff("-i", str(mp3), "-af", f"atrim={a:.3f}:{b:.3f},asetpts=PTS-STARTPTS,afade=t=out:st={b - a - 0.04:.3f}:d=0.04",
           "-ar", str(SR), "-ac", "1", "-c:a", "pcm_s16le", str(wav))
        scenes.setdefault(scene, round(t - 0.25, 3))
        for w in align(text, bounds):
            words.append({"text": w["text"], "start": round(t + w["start"] - a, 3),
                          "end": round(t + w["end"] - a, 3), "scene": scene})
        pieces.append(wav)
        t += b - a
        if pause > 0:
            p = WORK / f"pause{i}.wav"
            silence(pause, p)
            pieces.append(p)
            t += pause
        print("  ok", i, text[:40])
    lst = WORK / "list.txt"
    lst.write_text("".join(f"file '{p.as_posix()}'\n" for p in pieces), encoding="utf-8")
    voice_raw, voice = WORK / "voice_raw.wav", WORK / "voice.wav"
    ff("-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(voice_raw))
    ff("-i", str(voice_raw), "-af",
       "highpass=f=75,equalizer=f=180:t=q:w=1.0:g=2.5,equalizer=f=6500:t=q:w=1.5:g=-2,"
       "aecho=0.85:0.6:35|62:0.10|0.06,acompressor=threshold=-20dB:ratio=2.5:attack=8:release=120,"
       "loudnorm=I=-16:TP=-1.5:LRA=9", "-ar", str(SR), "-ac", "1", str(voice))

    def at(word: str, nth: int = 0) -> float:
        hits = [w for w in words if re.sub(r"[.,:!?]+$", "", w["text"]) == word]
        if len(hits) <= nth:
            sys.exit(f"Ereignis-Wort fehlt: {word} #{nth}")
        return hits[nth]["start"]

    end = words[-1]["end"]
    ev = {f"scene{k}": v for k, v in scenes.items()}
    ev.update({
        "terminal": at("arbeitet"),
        "chat": at("kopiert"), "cc": at("dagegen"),
        "read": at("liest"), "write": at("schreibt"), "run": at("führt"), "check": at("prüft"),
        "st1": at("verstehen"), "st2": at("lesen"), "st3": at("Plan"), "st4": at("ändern"), "st5": at("testen"),
        "fail": at("fehlschlägt"), "retry": at("sucht"), "success": at("funktioniert"),
        "dialog": at("riskanten"), "diff": at("Änderung"), "git": at("Git"),
        "claudemd": at("Datei"), "rule": at("Nach"),
        "kopfsache": at("Kopfsache"), "built": at("gebaut"), "burgwacht": at("Tower-Defense-Spiel"),
        "pca": at("Programm"), "video": at("Video"),
        "describe": at("beschreiben"), "verify": at("prüfen"), "decide": at("Entscheidungen"), "team": at("Kollege"),
        "ideas": at("Ideenliste"),
        "end": end, "duration": round(end + 2.2, 3),
    })
    (HERE / "events.json").write_text(json.dumps(ev, indent=1), encoding="utf-8")
    (HERE / "words.json").write_text(json.dumps(words, ensure_ascii=False, indent=1), encoding="utf-8")
    dur = ev["duration"]

    sfx = {
        "whoosh": ("anoisesrc=d=0.6:c=pink:r=48000:a=0.5", "bandpass=f=900:w=1.5,afade=t=in:d=0.28:curve=qsin,afade=t=out:st=0.28:d=0.32"),
        "pop": ("aevalsrc='0.6*sin(2*PI*(520*t+900*t*t))*exp(-26*t)':s=48000:d=0.16", "lowpass=f=4000"),
        "tick": ("aevalsrc='0.5*sin(2*PI*1800*t)*exp(-90*t)':s=48000:d=0.06", "highpass=f=600"),
        "type": ("aevalsrc='0.35*(random(0)-0.5)*exp(-160*t)':s=48000:d=0.03", "bandpass=f=3000:w=1"),
        "error": ("aevalsrc='0.35*(sin(2*PI*220*t)+sin(2*PI*233*t))*exp(-4*t)':s=48000:d=0.45", "lowpass=f=2000"),
        "success": ("aevalsrc='0.3*sin(2*PI*880*t)*exp(-3*t)*lt(t,0.12)+0.3*sin(2*PI*1318.5*t)*exp(-3*(t-0.12))*gte(t,0.12)':s=48000:d=1.2", "aecho=0.8:0.6:60:0.2"),
        "ding": ("aevalsrc='0.4*sin(2*PI*1318.5*t)*exp(-2.6*t)+0.15*sin(2*PI*2637*t)*exp(-4.5*t)':s=48000:d=1.6", "aecho=0.8:0.6:60:0.2"),
    }
    files = {}
    for name, (src, fx) in sfx.items():
        p = WORK / f"{name}.wav"
        ff("-f", "lavfi", "-i", src, "-af", fx, "-ac", "1", "-ar", str(SR), str(p))
        files[name] = p
    hits = [("whoosh", ev[f"scene{k}"] - 0.1, 0.35) for k in range(2, 8)]
    hits += [("type", ev["terminal"] + 0.15 + i * 0.09, 0.5) for i in range(10)]
    hits += [("pop", ev[k], 0.55) for k in ("read", "write", "run")]
    hits += [("tick", ev[f"st{i}"], 0.6) for i in range(1, 6)]
    hits += [("error", ev["fail"] + 0.1, 0.5), ("success", ev["success"] + 0.2, 0.5), ("success", ev["check"] + 0.25, 0.35)]
    hits += [("pop", ev[k], 0.55) for k in ("dialog", "diff", "git", "claudemd")]
    hits += [("whoosh", ev[k] - 0.1, 0.3) for k in ("kopfsache", "burgwacht", "pca", "video")]
    hits += [("pop", ev[k], 0.55) for k in ("describe", "verify", "decide")]
    hits += [("ding", ev["team"], 0.45), ("ding", ev["ideas"] + 0.2, 0.4)]

    chord_a = "sin(2*PI*130.81*t)+sin(2*PI*164.81*t)+sin(2*PI*196.00*t)+0.5*sin(2*PI*261.63*t)"
    chord_b = "sin(2*PI*110.00*t)+sin(2*PI*130.81*t)+sin(2*PI*164.81*t)+0.5*sin(2*PI*220.00*t)"
    chord_c = "sin(2*PI*87.31*t)+sin(2*PI*130.81*t)+sin(2*PI*174.61*t)+0.5*sin(2*PI*220.00*t)"
    chord_d = "sin(2*PI*98.00*t)+sin(2*PI*146.83*t)+sin(2*PI*196.00*t)+0.5*sin(2*PI*246.94*t)"
    # vier Akkorde (C – Am – F – G), je 4 s, weich überblendet
    seg = "mod(t,16)"
    wa = f"max(0,1-abs({seg}-2)/2.6)+max(0,1-abs({seg}-18)/2.6)"
    wb = f"max(0,1-abs({seg}-6)/2.6)"
    wc = f"max(0,1-abs({seg}-10)/2.6)"
    wd = f"max(0,1-abs({seg}-14)/2.6)"
    expr = f"0.07*(({wa})*({chord_a})+({wb})*({chord_b})+({wc})*({chord_c})+({wd})*({chord_d}))*(0.85+0.15*sin(2*PI*t/2))"
    pad = WORK / "pad.wav"
    ff("-f", "lavfi", "-i", f"aevalsrc='{expr}':s={SR}:d={dur}",
       "-af", f"lowpass=f=1200,aecho=0.8:0.7:120|240:0.35|0.25,afade=t=in:d=1.5,afade=t=out:st={dur - 2}:d=2", str(pad))

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
    script = WORK / "graph.txt"
    script.write_text(graph, encoding="utf-8")
    ff(*inputs, "-filter_complex_script", str(script), "-ar", str(SR), str(PUB / "mix.wav"))
    print(f"{len(words)} Wörter, Dauer {dur:.1f} s")
    print(json.dumps({k: round(v, 2) for k, v in ev.items()}))


asyncio.run(main())
