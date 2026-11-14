"""Clips rendern.

Aufbau (skaliert auf beliebig viele Clips, keine riesige Filterkette):

1. Pro Clip EIN FFmpeg-Lauf: `-ss` vor `-i` (Sprung auf echtes IDR, dann bildgenau), GPU-Decode,
   fps + Skalierung (+ Hochkant-Aufbau), dann per `trim` in bis zu drei Stücke geteilt:
     Kopf  (die ersten k Bilder – gehen in die Überblendung mit dem Vorgänger)
     Mitte (Rest – landet unverändert im Ergebnis)
     Ende  (die letzten k Bilder – gehen in die Überblendung mit dem Nachfolger)
   Video als rohes H.264 (Annex B, Parametersätze im Strom), Ton als WAV mit exakt passender
   Sample-Zahl (Bildzahl × 48000/fps) → Bild und Ton können nicht auseinanderlaufen.
   Zwei Clips laufen parallel (NVDEC/NVENC sind mit einem Prozess nicht ausgelastet: ~1,6× schneller).
2. Pro Übergang ein kleiner FFmpeg-Lauf: Ende(i) + Kopf(i+1) → xfade + acrossfade (k Bilder).
3. Zusammenfügen: Die H.264-Stücke (Mitte0, Übergang0, Mitte1, …) sind mit identischen
   Encoder-Einstellungen erzeugt und beginnen je mit IDR → einfach hintereinanderhängen.
   WAV-Stücke ebenso. Ein letzter Lauf kopiert das Video (kein erneutes Kodieren, exakte
   Zeitstempel per setts), kodiert den Ton nach AAC 192k und schreibt mp4 mit +faststart in eine
   Temp-Datei → umbenennen.

Jedes Ergebnis-Bild wird also genau einmal kodiert (Übergangsbilder zweimal, die Zwischenstufe
mit sehr hoher Qualität).
"""
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import threading
import wave
from concurrent.futures import FIRST_EXCEPTION, ThreadPoolExecutor, wait
from dataclasses import dataclass, field
from pathlib import Path

from .. import medien
from ..medien import FENSTERLOS, FFMPEG
from ..schema import Abbruch, Abgebrochen, Clip, Einstellungen, Fortschritt, melde, pruefe_abbruch
from . import layout, quelle
from .ffmpeg_lauf import SchnittFehler, fuehre_aus, loesche_sicher
from .quelle import KURZ_PROBEN

TON_RATE = 48000
MIN_BILDER = 3                 # kürzere Clips (nach Kürzung) werden übersprungen
QUALITAET_CQ = 19              # NVENC-Qualität Ergebnis (kleiner = besser)
QUALITAET_ZWISCHEN_CQ = 12     # Kopf/Ende-Stücke (nur Zwischenstufe für Überblendung)
NVENC_PRESET = "p4"            # p5 kostet ~30 % mehr Zeit bei kaum sichtbarem Unterschied
X264_CRF = 19
PARALLEL = 2                   # gleichzeitige FFmpeg-Läufe

_encoder_cache: dict[str, bool] = {}


# --------------------------------------------------------------------------- Encoder

def nvenc_verfuegbar() -> bool:
    if "nvenc" not in _encoder_cache:
        try:
            r = subprocess.run(
                [FFMPEG, "-hide_banner", "-v", "error", "-f", "lavfi", "-i",
                 "color=c=black:s=256x256:r=30:d=0.2", "-c:v", "h264_nvenc", "-f", "null", "-"],
                capture_output=True, timeout=20, creationflags=FENSTERLOS)
            _encoder_cache["nvenc"] = r.returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            _encoder_cache["nvenc"] = False
    return _encoder_cache["nvenc"]


def _video_encoder(fps: int, nvenc: bool, zwischen: bool) -> list[str]:
    """Für alle Stücke im Ergebnis IDENTISCHE Einstellungen (gleiche SPS/PPS) – wichtig fürs
    Hintereinanderhängen. B-Frames aus: rohes H.264 hat keine Zeitstempel."""
    farbe = ["-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709",
             "-color_trc", "bt709"]
    if nvenc:
        cq = QUALITAET_ZWISCHEN_CQ if zwischen else QUALITAET_CQ
        return ["-c:v", "h264_nvenc", "-preset", NVENC_PRESET, "-tune", "hq", "-rc", "vbr",
                "-cq", str(cq), "-b:v", "0", "-bf", "0", "-g", str(2 * fps), "-profile:v", "high",
                "-spatial-aq", "1", "-forced-idr", "1", *farbe, "-f", "h264"]
    crf = 12 if zwischen else X264_CRF
    return ["-c:v", "libx264", "-preset", "fast", "-crf", str(crf), "-bf", "0", "-g", str(2 * fps),
            "-profile:v", "high", "-pix_fmt", "yuv420p", *farbe, "-f", "h264"]


# --------------------------------------------------------------------------- Planung

@dataclass
class _Teil:
    clip: Clip
    start: float           # tatsächlicher Start (ggf. hinter kaputten Dateianfang verschoben)
    bilder: int            # Bildanzahl im Ausgabe-fps
    info: medien.VideoInfo
    kopf: int = 0          # Überblendbilder mit dem Vorgänger
    ende: int = 0          # Überblendbilder mit dem Nachfolger

    @property
    def mitte(self) -> int:
        return self.bilder - self.kopf - self.ende


@dataclass
class Plan:
    teile: list[_Teil] = field(default_factory=list)
    uebersprungen: list[tuple[Clip, str]] = field(default_factory=list)
    fps: int = 60

    @property
    def bilder_gesamt(self) -> int:
        return sum(t.bilder for t in self.teile) - sum(t.ende for t in self.teile)

    @property
    def dauer(self) -> float:
        return self.bilder_gesamt / self.fps


def plane(clips: list[Clip], einstellungen: Einstellungen) -> Plan:
    """Aktive Clips → bildgenaue Stücke. Kürzt Clips, die in den kaputten DVR-Anfang oder übers
    Dateiende reichen; Übergänge werden bei kurzen Clips verkürzt (höchstens halbe Cliplänge)."""
    fps = int(einstellungen.fps)
    if fps <= 0:
        raise SchnittFehler("Ungültige Bildrate in den Einstellungen.")
    plan = Plan(fps=fps)
    for clip in clips:
        if not clip.aktiv:
            continue
        try:
            info = quelle.info(clip.video)
            sauber = quelle.erster_sauberer_zeitpunkt(clip.video)
        except (OSError, subprocess.CalledProcessError, StopIteration, KeyError, ValueError):
            plan.uebersprungen.append((clip, "Video nicht lesbar"))
            continue
        start = max(float(clip.start), sauber, 0.0)
        ende = min(float(clip.ende), info.dauer - 2.0 / max(info.fps, 1.0))
        bilder = int(round((ende - start) * fps))
        if bilder < MIN_BILDER:
            grund = ("liegt im kaputten Anfang der Aufnahme" if clip.ende <= sauber
                     else "zu kurz oder außerhalb des Videos")
            plan.uebersprungen.append((clip, grund))
            continue
        plan.teile.append(_Teil(clip, start, bilder, info))

    k_soll = int(round(max(0.0, float(einstellungen.uebergang)) * fps))
    for a, b in zip(plan.teile, plan.teile[1:]):
        k = min(k_soll, a.bilder // 2, b.bilder // 2)
        a.ende = b.kopf = k
    return plan


def kapitel_aus_plan(plan: Plan) -> list[dict]:
    """Ein Kapitel je Clip, Zeiten im fertigen Video (s). Ein Kapitel beginnt mit der Überblendung
    in den Clip. `kills` = Zeitpunkte der eigenen Kills im fertigen Video (für Thumbnail-Vorschläge)."""
    out: list[dict] = []
    bild = 0
    for t in plan.teile:
        start = bild / plan.fps
        laenge = t.bilder / plan.fps
        kills = sorted(round(start + (e.t - t.start), 3) for e in t.clip.events
                       if e.typ == "kill" and t.start <= e.t <= t.start + laenge)
        out.append({"start": round(start, 3), "ende": 0.0, "titel": t.clip.grund, "kills": kills,
                    "quelle": t.clip.video, "quelle_start": round(t.start, 3)})
        bild += t.bilder - t.ende
    for i, k in enumerate(out):
        k["ende"] = out[i + 1]["start"] if i + 1 < len(out) else round(plan.dauer, 3)
    return out


def kapitel(clips: list[Clip], einstellungen: Einstellungen) -> list[dict]:
    """Kapitel so, wie `rendere` sie mit denselben Clips und Einstellungen schreibt."""
    return kapitel_aus_plan(plane(clips, einstellungen))


def _ffmetadata(kapitel_liste: list[dict]) -> str:
    def esc(s: str) -> str:
        for z in ("\\", "=", ";", "#", "\n"):
            s = s.replace(z, "\\" + z)
        return s
    zeilen = [";FFMETADATA1", "title=Highlight Cutter"]
    for i, k in enumerate(kapitel_liste, 1):
        zeilen += ["[CHAPTER]", "TIMEBASE=1/1000", f"START={int(round(k['start'] * 1000))}",
                   f"END={int(round(k['ende'] * 1000))}", f"title={esc(f'#{i} ' + str(k['titel']))}"]
    return "\n".join(zeilen) + "\n"


def _samples(bilder: int, fps: int) -> int:
    return int(round(bilder * TON_RATE / fps))


class _Stopp:
    """Abbruch von außen ODER intern (ein paralleler Lauf ist fehlgeschlagen)."""

    def __init__(self, aussen: Abbruch | None):
        self.aussen = aussen
        self.intern = threading.Event()

    def is_set(self) -> bool:
        return self.intern.is_set() or (self.aussen is not None and self.aussen.is_set())


# --------------------------------------------------------------------------- Rendern

class _Lauf:
    def __init__(self, plan: Plan, einstellungen: Einstellungen, ordner: Path,
                 fortschritt: Fortschritt, stopp: _Stopp):
        self.plan = plan
        self.einst = einstellungen
        self.ordner = ordner
        self.fortschritt = fortschritt
        self.stopp = stopp
        self.nvenc = nvenc_verfuegbar()
        self.gpu_decode = self.nvenc      # CUDA-Decode nur zusammen mit NVIDIA-Karte versuchen
        # Arbeitsgewichte für den Gesamtfortschritt (Quell-Decode dominiert)
        self.gesamt = (sum(t.bilder for t in plan.teile) + sum(t.ende for t in plan.teile) * 0.5
                       + max(1.0, sum(t.bilder for t in plan.teile) * 0.04))
        self._stand: dict[str, float] = {}
        self._gemeldet = 0.0
        self._sperre = threading.Lock()
        self.clips_fertig = 0

    def _melde(self, schluessel: str, erledigt: float, text: str) -> None:
        with self._sperre:
            self._stand[schluessel] = erledigt
            anteil = max(self._gemeldet, min(0.999, sum(self._stand.values()) / self.gesamt))
            self._gemeldet = anteil
        melde(self.fortschritt, anteil, text)

    def datei(self, name: str) -> Path:
        return self.ordner / name

    # ---- Schritt 1: Clip normalisieren
    def normalisiere(self, i: int) -> None:
        t = self.plan.teile[i]
        fps = self.plan.fps
        info = t.info
        aufbau = layout.berechne(self.einst.format, int(self.einst.hoehe), info.breite, info.hoehe)
        anzahl = len(self.plan.teile)
        dauer = t.bilder / fps

        stuecke = []   # (name, start_bild, end_bild, zwischenqualitaet)
        if t.kopf:
            stuecke.append((f"k{i:03d}", 0, t.kopf, True))
        if t.mitte:
            stuecke.append((f"m{i:03d}", t.kopf, t.kopf + t.mitte, False))
        if t.ende:
            stuecke.append((f"e{i:03d}", t.bilder - t.ende, t.bilder, True))

        def befehl(gpu: bool) -> list[str]:
            arg: list[str] = []
            if gpu:
                # threads 1: sonst verlangt der Decoder > 32 Surfaces → cuvidCreateDecoder schlägt fehl
                arg += ["-threads", "1", "-hwaccel", "cuda", "-hwaccel_output_format", "cuda"]
            # Eingabe etwas länger lesen als nötig (fps-Filter/Puffer), trim schneidet exakt
            arg += [*KURZ_PROBEN, "-ss", f"{t.start:.6f}", "-t", f"{dauer + 0.5:.6f}",
                    "-i", t.clip.video]
            ton_eingang = "0:a:0"
            if not info.hat_ton:
                arg += ["-f", "lavfi", "-t", f"{dauer + 0.5:.6f}", "-i",
                        f"anullsrc=r={TON_RATE}:cl=stereo"]
                ton_eingang = "1:a"
            n = len(stuecke)
            graph = [layout.video_filter(aufbau, fps, gpu)]
            if n > 1:
                graph.append(f"[bild]split={n}" + "".join(f"[v{j}]" for j in range(n)))
            # async/first_pts: Lücke am Tonanfang mit Stille füllen; apad: Ton nie kürzer als Bild
            ton = (f"[{ton_eingang}]aresample={TON_RATE}:async=1:first_pts=0,"
                   f"aformat=sample_fmts=s16:channel_layouts=stereo,"
                   f"apad=whole_len={_samples(t.bilder, fps)}")
            graph.append(ton + (f",asplit={n}" + "".join(f"[a{j}]" for j in range(n))
                                if n > 1 else "[a0]"))
            ausgaben: list[str] = []
            for j, (name, b0, b1, zw) in enumerate(stuecke):
                v_in = f"[v{j}]" if n > 1 else "[bild]"
                graph.append(f"{v_in}trim=start_frame={b0}:end_frame={b1},setpts=PTS-STARTPTS[vo{j}]")
                s0, s1 = _samples(b0, fps), _samples(b1, fps)
                graph.append(f"[a{j}]atrim=start_sample={s0}:end_sample={s1},"
                             f"asetpts=PTS-STARTPTS[ao{j}]")
                ausgaben += ["-map", f"[vo{j}]", *_video_encoder(fps, self.nvenc, zw),
                             str(self.datei(name + ".h264"))]
                ausgaben += ["-map", f"[ao{j}]", "-c:a", "pcm_s16le", "-f", "wav",
                             str(self.datei(name + ".wav"))]
            return arg + ["-filter_complex", ";".join(graph), *ausgaben]

        def fort(x: float) -> None:
            self._melde(f"c{i}", x * t.bilder,
                        f"Clips werden geschnitten ({self.clips_fertig}/{anzahl} fertig)")

        was = f"Clip {i + 1} ({Path(t.clip.video).name}, {t.start:.1f} s)"
        erledigt = False
        if self.gpu_decode:
            try:
                fuehre_aus(befehl(True), dauer=dauer, fortschritt=fort, abbrechen=self.stopp, was=was)
                self._pruefe_stuecke(stuecke, fps)
                erledigt = True
            except SchnittFehler:
                self.gpu_decode = False   # auf CPU-Decode umschalten (Encoder bleibt gleich)
        if not erledigt:
            fuehre_aus(befehl(False), dauer=dauer, fortschritt=fort, abbrechen=self.stopp, was=was)
            self._pruefe_stuecke(stuecke, fps)
        with self._sperre:
            self.clips_fertig += 1
        fort(1.0)

    def _pruefe_stuecke(self, stuecke, fps: int) -> None:
        for name, b0, b1, _ in stuecke:
            for endung in (".h264", ".wav"):
                p = self.datei(name + endung)
                if not p.exists() or p.stat().st_size == 0:
                    raise SchnittFehler(f"Zwischendatei {p.name} fehlt – die Quelle endet vermutlich "
                                        f"früher als erwartet.")
            with wave.open(str(self.datei(name + ".wav")), "rb") as w:
                soll = _samples(b1, fps) - _samples(b0, fps)
                if w.getnframes() != soll:
                    raise SchnittFehler(f"Ton-Stück {name} hat {w.getnframes()} statt {soll} Samples.")

    # ---- Schritt 2: Übergang
    def ueberblende(self, i: int) -> None:
        a = self.plan.teile[i]
        k = a.ende
        fps = self.plan.fps
        d = k / fps
        ende, kopf = self.datei(f"e{i:03d}"), self.datei(f"k{i + 1:03d}")
        roh = [*KURZ_PROBEN, "-f", "h264", "-framerate", str(fps)]
        arg = [*roh, "-i", f"{ende}.h264", *roh, "-i", f"{kopf}.h264",
               "-i", f"{ende}.wav", "-i", f"{kopf}.wav",
               "-filter_complex",
               f"[0:v][1:v]xfade=transition=fade:duration={d:.6f}:offset=0,"
               f"trim=end_frame={k},format=yuv420p[v];"
               f"[2:a][3:a]acrossfade=ns={_samples(k, fps)}:c1=qsin:c2=qsin[a]",
               "-map", "[v]", *_video_encoder(fps, self.nvenc, False),
               str(self.datei(f"u{i:03d}.h264")),
               "-map", "[a]", "-c:a", "pcm_s16le", "-f", "wav", str(self.datei(f"u{i:03d}.wav"))]
        text = "Überblendungen werden berechnet"
        fuehre_aus(arg, dauer=d, fortschritt=lambda x: self._melde(f"u{i}", x * k * 0.5, text),
                   abbrechen=self.stopp, was=f"Überblendung {i + 1}")
        with wave.open(str(self.datei(f"u{i:03d}.wav")), "rb") as w:
            if w.getnframes() != _samples(k, fps):
                raise SchnittFehler(f"Überblendung {i + 1}: Ton hat {w.getnframes()} statt "
                                    f"{_samples(k, fps)} Samples.")
        for name in (f"e{i:03d}", f"k{i + 1:03d}"):       # Platz sparen
            for endung in (".h264", ".wav"):
                loesche_sicher(self.datei(name + endung))

    # ---- Schritt 3: zusammenfügen
    def reihenfolge(self) -> list[str]:
        namen = []
        for i, t in enumerate(self.plan.teile):
            if t.mitte:
                namen.append(f"m{i:03d}")
            if t.ende:
                namen.append(f"u{i:03d}")
        return namen

    def zusammenfuegen(self, temp_ziel: Path) -> None:
        namen = self.reihenfolge()
        text = "Video wird zusammengefügt"
        gewicht = max(1.0, self.gesamt - sum(self._stand.values()))
        self._melde("z", 0.0, text)
        video = self.datei("alles.h264")
        with open(video, "wb") as aus:
            for name in namen:
                pruefe_abbruch(self.stopp)
                with open(self.datei(name + ".h264"), "rb") as ein:
                    shutil.copyfileobj(ein, aus, 8 * 1024 * 1024)
        ton = self.datei("alles.wav")
        with wave.open(str(ton), "wb") as aus_w:
            aus_w.setnchannels(2)
            aus_w.setsampwidth(2)
            aus_w.setframerate(TON_RATE)
            for name in namen:
                with wave.open(str(self.datei(name + ".wav")), "rb") as ein_w:
                    while daten := ein_w.readframes(1 << 18):
                        aus_w.writeframes(daten)
        fps = self.plan.fps
        # Kapitel (ein Kapitel je Clip) direkt ins MP4 – bleiben beim Kopieren/Umbenennen erhalten
        meta = self.datei("kapitel.txt")
        meta.write_text(_ffmetadata(kapitel_aus_plan(self.plan)), encoding="utf-8")
        arg = ["-f", "h264", "-framerate", str(fps), "-i", str(video), "-i", str(ton),
               "-f", "ffmetadata", "-i", str(meta), "-map_chapters", "2",
               "-map", "0:v", "-map", "1:a", "-c:v", "copy",
               # exakte Zeitstempel (Bild n = n/fps); sonst rundet der Roh-H.264-Leser auf 1/1,2 MHz
               "-bsf:v", f"setts=pts=N/({fps}*TB):dts=N/({fps}*TB):duration=1/({fps}*TB)",
               "-video_track_timescale", str(fps * 1000),
               "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart",
               "-metadata", "comment=Highlight Cutter", "-f", "mp4", str(temp_ziel)]
        fuehre_aus(arg, dauer=self.plan.dauer,
                   fortschritt=lambda x: self._melde("z", x * gewicht, text),
                   abbrechen=self.stopp, was="Zusammenfügen")


def _parallel(aufgaben, stopp: _Stopp) -> None:
    """Führt Aufgaben (Callables) mit PARALLEL Threads aus. Beim ersten Fehler werden die anderen
    FFmpeg-Läufe beendet und der Fehler weitergereicht."""
    if not aufgaben:
        return
    with ThreadPoolExecutor(max_workers=PARALLEL, thread_name_prefix="schnitt") as ex:
        offen = {ex.submit(a) for a in aufgaben}
        fertig, offen = wait(offen, return_when=FIRST_EXCEPTION)
        fehler = next((f.exception() for f in fertig if f.exception() is not None), None)
        if fehler is not None:
            stopp.intern.set()
            for f in offen:
                f.cancel()
            wait(offen)
            raise fehler


def rendere(clips: list[Clip], ziel: str | Path, einstellungen: Einstellungen,
            fortschritt: Fortschritt = None, abbrechen: Abbruch | None = None) -> Path:
    ziel = Path(ziel).resolve()
    if ziel.suffix.lower() != ".mp4":
        ziel = ziel.with_suffix(".mp4")
    ziel.parent.mkdir(parents=True, exist_ok=True)
    melde(fortschritt, 0.0, "Clips werden vorbereitet")
    plan = plane(clips, einstellungen)
    if not plan.teile:
        gruende = "; ".join(f"{Path(c.video).name} {c.start:.1f}–{c.ende:.1f} s: {g}"
                            for c, g in plan.uebersprungen[:5])
        raise SchnittFehler("Keine verwendbaren Clips zum Rendern"
                            + (f" ({gruende})" if gruende else " (keiner ausgewählt)") + ".")
    pruefe_abbruch(abbrechen)

    stopp = _Stopp(abbrechen)
    # Zwischendateien neben dem Ziel (gleiches Laufwerk → os.replace ist atomar)
    ordner = Path(tempfile.mkdtemp(prefix=".hc-schnitt-", dir=ziel.parent))
    temp_ziel = ordner / "ergebnis.teil.mp4"
    try:
        lauf = _Lauf(plan, einstellungen, ordner, fortschritt, stopp)
        n = len(plan.teile)
        _parallel([lambda i=i: lauf.normalisiere(i) for i in range(n)], stopp)
        pruefe_abbruch(stopp)
        _parallel([lambda i=i: lauf.ueberblende(i) for i in range(n - 1) if plan.teile[i].ende],
                  stopp)
        pruefe_abbruch(stopp)
        lauf.zusammenfuegen(temp_ziel)
        pruefe_abbruch(stopp)
        try:
            os.replace(temp_ziel, ziel)
        except PermissionError as e:
            raise SchnittFehler(f"Die Zieldatei {ziel.name} kann nicht überschrieben werden – ist sie "
                                f"noch in einem Videoplayer geöffnet?") from e
    except Abgebrochen:
        if abbrechen is not None and abbrechen.is_set():
            raise
        raise SchnittFehler("Rendern wurde intern abgebrochen.")
    finally:
        _raeume_auf(ordner)
    hinweis = f" ({len(plan.uebersprungen)} Clip(s) übersprungen)" if plan.uebersprungen else ""
    melde(fortschritt, 1.0, f"Fertig: {len(plan.teile)} Clips, {plan.dauer:.1f} s{hinweis}")
    return ziel


def _raeume_auf(ordner: Path) -> None:
    for _ in range(3):
        if not ordner.exists():
            return
        for p in ordner.iterdir():
            loesche_sicher(p)
        try:
            ordner.rmdir()
            return
        except OSError:
            pass
    shutil.rmtree(ordner, ignore_errors=True)
