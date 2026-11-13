"""Ton-Pipeline: Drehbuch → Stimme + Geräusche + Musik + Zeitliste.

Aufruf:   npm run ton -- beispiele/pythagoras.json
Erzeugt:  public/ton/<name>.wav            fertiger Ton (Stimme, Geräusche, Musik mit Ducking)
          <ordner>/<name>.timing.json      Wörter, Szenen-Zeiten und „bei“-Zeitpunkte (für das Video)

Stimme „menschlicher“: Satz für Satz vertont (eigene Pause + Tempo je Satz), Wärme-EQ,
leichter Raum, Kompression, Lautheit -16 LUFS. Geräusche werden synthetisch erzeugt.
"""
import asyncio
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import edge_tts

STIMMEN = {
    "ava": "en-US-AvaMultilingualNeural",
    "seraphina": "de-DE-SeraphinaMultilingualNeural",
    "florian": "de-DE-FlorianMultilingualNeural",
    "conrad": "de-DE-ConradNeural",
    "katja": "de-DE-KatjaNeural",
}
SR = 48000
FPS = 60
VORLAUF = 0.6        # Stille vor dem ersten Wort
SZENEN_PAUSE = 0.45  # zusätzliche Pause zwischen Szenen
NACHLAUF = 1.6       # nach dem letzten Wort
ROOT = Path(__file__).resolve().parent.parent
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"


def ff(*args: str) -> None:
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", *args], check=True)


def norm(s: str) -> str:
    return re.sub(r"[^\w]", "", s.lower())


def rate(tempo: float) -> str:
    t = int(round(tempo))
    return f"{'+' if t >= 0 else ''}{t}%"


def ausrichten(text: str, grenzen: list[dict]) -> list[dict]:
    """Wörter des Satzes zeichengenau den Zeitstempeln der Stimme zuordnen
    (die Stimme fasst manchmal Wörter zusammen oder teilt sie auf)."""
    zeiten = []
    for g in grenzen:
        n = len(norm(g["text"]))
        for k in range(n):
            zeiten.append((g["start"] + (g["end"] - g["start"]) * k / n, g["start"] + (g["end"] - g["start"]) * (k + 1) / n))
    tokens = text.split()
    if "".join(norm(t) for t in tokens) != "".join(norm(g["text"]) for g in grenzen):
        sys.exit(f"Text und Sprachausgabe passen nicht zusammen: {text!r} / {[g['text'] for g in grenzen]}")
    out, pos = [], 0
    for t in tokens:
        n = len(norm(t))
        out.append({"text": t, "start": zeiten[pos][0], "end": zeiten[pos + n - 1][1]})
        pos += n
    return out


async def sprechen(text: str, stimme: str, tempo: str, mp3: Path) -> list[dict]:
    letzter = None
    for versuch in range(4):  # der kostenlose Dienst liefert gelegentlich nichts
        try:
            com = edge_tts.Communicate(text, stimme, rate=tempo, boundary="WordBoundary")
            grenzen = []
            with open(mp3, "wb") as f:
                async for c in com.stream():
                    if c["type"] == "audio":
                        f.write(c["data"])
                    elif c["type"] == "WordBoundary":
                        grenzen.append({"text": c["text"], "start": c["offset"] / 1e7, "end": (c["offset"] + c["duration"]) / 1e7})
            if grenzen:
                return grenzen
        except edge_tts.exceptions.NoAudioReceived as e:
            letzter = e
        except Exception as e:  # Netzwerkfehler o. ä.
            letzter = e
        await asyncio.sleep(1.5 * (versuch + 1))
    sys.exit(f"Sprachausgabe für {text!r} fehlgeschlagen (Internet?): {letzter}")


def alle_bei(obj, schluessel=""):
    """Alle „bei“-Angaben einer Szene mit dem Namen des Elternfelds (für die Geräusch-Wahl)."""
    if isinstance(obj, list):
        for x in obj:
            yield from alle_bei(x, schluessel)
    elif isinstance(obj, dict):
        for k, v in obj.items():
            if k == "sprecher":
                continue
            if k == "bei" and isinstance(v, str):
                yield schluessel, v
            else:
                yield from alle_bei(v, k)


def finde(woerter: list[dict], bei: str):
    wort, _, nr = bei.partition("#")
    n = max(1, int(nr) if nr.isdigit() else 1)
    treffer = 0
    for w in woerter:
        if norm(w["text"]) == norm(wort):
            treffer += 1
            if treffer == n:
                return w["start"]
    return None


async def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("Bitte ein Drehbuch angeben, z. B.: npm run ton -- beispiele/pythagoras.json")
    pfad = Path(sys.argv[1]).resolve()
    db = json.loads(pfad.read_text(encoding="utf-8"))
    name = pfad.stem
    stimme = STIMMEN.get(db.get("stimme", "ava"), STIMMEN["ava"])
    grundtempo = float(db.get("tempo", 0))
    arbeit = ROOT / "public" / "ton" / "_work" / name
    arbeit.mkdir(parents=True, exist_ok=True)
    stille = lambda d, p: ff("-f", "lavfi", "-i", f"anullsrc=r={SR}:cl=mono", "-t", f"{d:.3f}", "-c:a", "pcm_s16le", str(p))

    # 1) Stimme satzweise, zugeschnitten, mit Pausen aneinandergereiht
    teile, woerter, szenen, t = [], [], [], VORLAUF
    p0 = arbeit / "vorlauf.wav"
    stille(VORLAUF, p0)
    teile.append(p0)
    nr = 0
    for k, sz in enumerate(db["szenen"]):
        eigene = []
        szenen_start = None
        for s in sz["sprecher"]:
            mp3 = arbeit / f"s{nr}.mp3"
            grenzen = await sprechen(s["satz"], stimme, rate(grundtempo + float(s.get("tempo", 0))), mp3)
            a, b = max(0.0, grenzen[0]["start"] - 0.06), grenzen[-1]["end"] + 0.14
            wav = arbeit / f"s{nr}.wav"
            ff("-i", str(mp3), "-af", f"atrim={a:.3f}:{b:.3f},asetpts=PTS-STARTPTS,afade=t=out:st={b - a - 0.04:.3f}:d=0.04",
               "-ar", str(SR), "-ac", "1", "-c:a", "pcm_s16le", str(wav))
            if szenen_start is None:
                szenen_start = t
            for w in ausrichten(s["satz"], grenzen):
                eigene.append({"text": w["text"], "start": round(t + w["start"] - a, 3), "end": round(t + w["end"] - a, 3), "szene": k})
            teile.append(wav)
            t += b - a
            pause = float(s.get("pause", 0.35))
            if pause > 0:
                pp = arbeit / f"p{nr}.wav"
                stille(pause, pp)
                teile.append(pp)
                t += pause
            nr += 1
            print(f"  Szene {k + 1}: {s['satz'][:50]}")
        if k + 1 < len(db["szenen"]):
            pp = arbeit / f"sz{k}.wav"
            stille(SZENEN_PAUSE, pp)
            teile.append(pp)
            t += SZENEN_PAUSE
        bei = {}
        for _, wert in alle_bei(sz):
            zeit = finde(eigene, wert)
            if zeit is None:
                sys.exit(f"Szene {k + 1}: „bei“: {wert!r} kommt im Sprechertext nicht vor (npm run pruefen hilft).")
            bei[wert] = zeit
        szenen.append({"start": 0.0 if k == 0 else round(max(0.0, szenen_start - 0.4), 3), "ende": 0.0, "bei": bei})
        woerter.extend(eigene)
    dauer = round(woerter[-1]["end"] + NACHLAUF, 3)
    for k, s in enumerate(szenen):
        s["ende"] = szenen[k + 1]["start"] if k + 1 < len(szenen) else dauer

    liste = arbeit / "liste.txt"
    liste.write_text("".join(f"file '{p.as_posix()}'\n" for p in teile), encoding="utf-8")
    roh, stimme_wav = arbeit / "stimme_roh.wav", arbeit / "stimme.wav"
    ff("-f", "concat", "-safe", "0", "-i", str(liste), "-c", "copy", str(roh))
    ff("-i", str(roh), "-af",
       "highpass=f=75,equalizer=f=180:t=q:w=1.0:g=2.5,equalizer=f=6500:t=q:w=1.5:g=-2,"
       "aecho=0.85:0.6:35|62:0.10|0.06,acompressor=threshold=-20dB:ratio=2.5:attack=8:release=120,"
       "loudnorm=I=-16:TP=-1.5:LRA=9", "-ar", str(SR), "-ac", "1", str(stimme_wav))

    # 2) Geräusche: Wusch beim Szenenwechsel, Plopp bei jedem „bei“, Sonder-Töne für Fehler/Erfolg/Merke/Abschluss
    gx = {
        "wusch": ("anoisesrc=d=0.6:c=pink:r=48000:a=0.5", "bandpass=f=900:w=1.5,afade=t=in:d=0.28:curve=qsin,afade=t=out:st=0.28:d=0.32"),
        "plopp": ("aevalsrc='0.6*sin(2*PI*(520*t+900*t*t))*exp(-26*t)':s=48000:d=0.16", "lowpass=f=4000"),
        "fehler": ("aevalsrc='0.35*(sin(2*PI*220*t)+sin(2*PI*233*t))*exp(-4*t)':s=48000:d=0.45", "lowpass=f=2000"),
        "erfolg": ("aevalsrc='0.3*sin(2*PI*880*t)*exp(-3*t)*lt(t,0.12)+0.3*sin(2*PI*1318.5*t)*exp(-3*(t-0.12))*gte(t,0.12)':s=48000:d=1.2", "aecho=0.8:0.6:60:0.2"),
        "ding": ("aevalsrc='0.4*sin(2*PI*1318.5*t)*exp(-2.6*t)+0.15*sin(2*PI*2637*t)*exp(-4.5*t)':s=48000:d=1.6", "aecho=0.8:0.6:60:0.2"),
    }
    dateien = {}
    for n, (quelle, fx) in gx.items():
        p = arbeit / f"{n}.wav"
        ff("-f", "lavfi", "-i", quelle, "-af", fx, "-ac", "1", "-ar", str(SR), str(p))
        dateien[n] = p
    treffer = []
    for k, sz in enumerate(db["szenen"]):
        if k > 0:
            treffer.append(("wusch", szenen[k]["start"], 0.35))
        gesehen = set()
        for feld, wert in alle_bei(sz):
            zeit = szenen[k]["bei"][wert]
            art = "fehler" if feld == "fehler" else "erfolg" if feld == "erfolg" else "ding" if feld == "merke" or sz["typ"] == "abschluss" and feld == "" else "plopp"
            if (art, round(zeit, 2)) in gesehen:
                continue
            gesehen.add((art, round(zeit, 2)))
            treffer.append((art, zeit, 0.5 if art == "plopp" else 0.45))

    # 3) Musik-Teppich (C – Am – F – G, weich überblendet), unter der Stimme automatisch leiser
    akk = {
        "a": "sin(2*PI*130.81*t)+sin(2*PI*164.81*t)+sin(2*PI*196.00*t)+0.5*sin(2*PI*261.63*t)",
        "b": "sin(2*PI*110.00*t)+sin(2*PI*130.81*t)+sin(2*PI*164.81*t)+0.5*sin(2*PI*220.00*t)",
        "c": "sin(2*PI*87.31*t)+sin(2*PI*130.81*t)+sin(2*PI*174.61*t)+0.5*sin(2*PI*220.00*t)",
        "d": "sin(2*PI*98.00*t)+sin(2*PI*146.83*t)+sin(2*PI*196.00*t)+0.5*sin(2*PI*246.94*t)",
    }
    m = "mod(t,16)"
    gew = {"a": f"max(0,1-abs({m}-2)/2.6)+max(0,1-abs({m}-18)/2.6)", "b": f"max(0,1-abs({m}-6)/2.6)",
           "c": f"max(0,1-abs({m}-10)/2.6)", "d": f"max(0,1-abs({m}-14)/2.6)"}
    ausdruck = "0.07*(" + "+".join(f"({gew[x]})*({akk[x]})" for x in "abcd") + ")*(0.85+0.15*sin(2*PI*t/2))"
    musik = arbeit / "musik.wav"
    if db.get("musik", True):
        ff("-f", "lavfi", "-i", f"aevalsrc='{ausdruck}':s={SR}:d={dauer}",
           "-af", f"lowpass=f=1200,aecho=0.8:0.7:120|240:0.35|0.25,afade=t=in:d=1.5,afade=t=out:st={max(0, dauer - 2)}:d=2", str(musik))
    else:
        stille(dauer, musik)

    eingaben = ["-i", str(stimme_wav), "-i", str(musik)]
    ketten, marken = [], []
    for i, (art, zeit, lautst) in enumerate(treffer):
        eingaben += ["-i", str(dateien[art])]
        ms = max(0, int(zeit * 1000))
        ketten.append(f"[{i + 2}:a]adelay={ms}|{ms},volume={lautst}[g{i}]")
        marken.append(f"[g{i}]")
    graph = ";".join([
        "[0:a]asplit=2[v][vk]",
        "[1:a]volume=1.3[mu]",
        "[mu][vk]sidechaincompress=threshold=0.03:ratio=5:attack=25:release=350[duck]",
        *ketten,
        f"[v][duck]{''.join(marken)}amix=inputs={2 + len(marken)}:duration=first:normalize=0,"
        f"apad=whole_dur={dauer},atrim=0:{dauer},alimiter=limit=0.95,aformat=channel_layouts=stereo",
    ])
    gdatei = arbeit / "graph.txt"
    gdatei.write_text(graph, encoding="utf-8")
    ziel = ROOT / "public" / "ton" / f"{name}.wav"
    ff(*eingaben, "-filter_complex_script", str(gdatei), "-ar", str(SR), str(ziel))

    timing = {"fps": FPS, "dauer": dauer, "woerter": woerter, "szenen": szenen}
    tpfad = pfad.with_name(f"{name}.timing.json")
    tpfad.write_text(json.dumps(timing, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Fertig: {len(woerter)} Wörter, {dauer:.1f} s → {ziel.relative_to(ROOT)}, {tpfad.name}")


asyncio.run(main())
