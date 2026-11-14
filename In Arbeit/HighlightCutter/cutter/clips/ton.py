"""Ton-Auswertung für den Kampfbeginn: Schüsse/Treffer finden, Sprache ignorieren.

Gemessen an echten Apex-Aufnahmen (siehe tests/daten/clips_wahrheit.json):
- Schüsse/Treffer/Explosionen sind kurze Spitzen im Hochband (3,4–11,5 kHz) um -16..-9 dBFS,
  die gleichzeitig das Tiefband (60–300 Hz) kräftig anheben (breitbandig, Bass-Wumms).
  Automatikwaffen liefern 5–10 solcher Spitzen pro Sekunde.
- Sprache (Discord, Ansagen) erreicht das Hochband nur mit Zischlauten/Plosiven; drumherum ist
  sie stimmhaft (periodisch 80–400 Hz). Spitzen mit stimmhaftem Umfeld (±0,2 s) werden verworfen.
- Looten/Gegenstände ablegen/Türen erzeugen einzelne oder kurze, leisere Klickfolgen.
Deshalb zählt nur eine *Salve* (≥3 Spitzen in 1 s) oder ein einzelner sehr lauter Knall
(Sniper, Granate) als Kampf. Ab dem Event rückwärts gehören Kampfstellen mit Pausen ≤ 10 s
zum selben Gefecht; der Clip beginnt 1 s vor der frühesten.
"""
from __future__ import annotations

import subprocess
from dataclasses import dataclass

import numpy as np
from scipy.ndimage import maximum_filter1d

from ..medien import FENSTERLOS, FFMPEG

SR = 24000          # Abtastrate für die Auswertung (Nyquist 12 kHz)
N_FFT = 512         # ~21 ms Fenster
HOP = 240           # 10 ms Raster
DT = HOP / SR

# Bänder (Hz): tief, Sprache, hoch-mittel, hoch
BAENDER = ((60, 300), (300, 3400), (3400, 6000), (6000, 11500))

# Pegel in dBFS (Vollaussteuerungs-Sinus im Band = 0 dB). Gemessen an echten Aufnahmen:
# Schüsse: Hochband -16..-9, Tiefband -12..+1; ruhige Stellen/Looten/Sprache: Hochband meist
# unter -18, Tiefband unter -14. Ist die ganze Aufnahme lauter abgemischt (Grundpegel hoch),
# wandern die Schwellen mit (Grundpegel + *_REL).
SPITZE_HOCH = -18.0     # Hochband-Spitze ab hier = Schuss-Kandidat
SPITZE_TIEF = -14.0     # ... und Tiefband gleichzeitig mindestens so laut (breitbandig)
KNALL_HOCH = -10.0      # einzelner Knall zählt allein (Sniper, Granate), wenn so laut ...
KNALL_TIEF = -8.0       # ... und so viel Bass
SPITZE_REL = 22.0       # Sicherheitsnetz: mindestens so weit über dem Grundpegel (20. Perzentil)
TIEF_REL = 8.0
SALVE_N = 3             # so viele Kandidaten ...
SALVE_S = 1.0           # ... innerhalb so vieler Sekunden = Salve
HARMONISCH_MAX = 0.85   # stimmhafter Rahmen (Sprache) wird nicht gezählt
UMFELD_S = 0.2          # Stimmhaftigkeit auch ±so viele s um die Spitze prüfen ...
UMFELD_MEDIAN_MAX = 0.7 # ... Median darüber = Sprache drumherum (Silbe mit Plosiv) → verwerfen
BODEN_PERZENTIL = 20    # Grundpegel = dieses Perzentil des Abschnitts
# Umrechnung |rfft|² mit Hann-Fenster → dBFS
_DBFS = 20 * np.log10(np.hanning(N_FFT).sum() / 2)


def lese_ton(video: str, start: float, dauer: float, sr: int = SR) -> np.ndarray:
    """Liest [start, start+dauer] als Mono-float32 (-1..1) per FFmpeg-Pipe."""
    start = max(0.0, start)
    cmd = [FFMPEG, "-v", "error", "-nostdin", "-ss", f"{start:.3f}", "-t", f"{max(0.05, dauer):.3f}",
           "-i", str(video), "-vn", "-sn", "-dn", "-ac", "1", "-ar", str(sr), "-f", "s16le", "-"]
    p = subprocess.run(cmd, capture_output=True, creationflags=FENSTERLOS, timeout=120)
    if p.returncode != 0 and not p.stdout:
        raise RuntimeError(f"Ton nicht lesbar: {p.stderr.decode(errors='replace')[-300:]}")
    return np.frombuffer(p.stdout, dtype="<i2").astype(np.float32) / 32768.0


@dataclass
class Merkmale:
    zeit: np.ndarray          # Mittelpunkt je Rahmen (s im Video)
    band_db: np.ndarray       # (rahmen, 4) Bandpegel in dB
    hoch_db: np.ndarray       # Pegel 3,4–11,5 kHz
    harmonisch: np.ndarray    # 0..1, Stimmhaftigkeit je Rahmen


def _stft_betrag(x: np.ndarray) -> np.ndarray:
    if len(x) < N_FFT:
        x = np.pad(x, (0, N_FFT - len(x)))
    n = 1 + (len(x) - N_FFT) // HOP
    idx = np.arange(N_FFT)[None, :] + HOP * np.arange(n)[:, None]
    fenster = np.hanning(N_FFT).astype(np.float32)
    return np.abs(np.fft.rfft(x[idx] * fenster, axis=1)).astype(np.float32)


def harmonizitaet(x: np.ndarray, zeiten_idx: np.ndarray) -> np.ndarray:
    """Normierte Autokorrelation im Tonhöhenbereich 80–400 Hz an den Rahmen `zeiten_idx`.

    Hoher Wert = periodisch (Stimme, Musik). Schüsse/Rauschen → niedriger.
    Nur für wenige Rahmen berechnet (Kandidaten), deshalb schnell.
    """
    lang = 960  # 40 ms
    min_lag, max_lag = SR // 400, SR // 80
    if len(zeiten_idx) == 0 or len(x) < lang + max_lag:
        return np.zeros(len(zeiten_idx), np.float32)
    starts = np.clip(zeiten_idx * HOP + N_FFT // 2 - lang // 2, 0, len(x) - lang - max_lag)
    seg = x[starts[:, None] + np.arange(lang + max_lag)[None, :]].astype(np.float64)
    # grob auf 100–3400 Hz begrenzen, damit Rauschen oben die Periodizität nicht verdeckt
    spek = np.fft.rfft(seg, axis=1)
    f = np.fft.rfftfreq(seg.shape[1], 1 / SR)
    spek[:, (f < 100) | (f > 3400)] = 0
    seg = np.fft.irfft(spek, seg.shape[1], axis=1)
    nfft = 1 << int(np.ceil(np.log2(2 * seg.shape[1])))
    F = np.fft.rfft(seg[:, :lang], nfft)
    G = np.fft.rfft(seg, nfft)
    kreuz = np.fft.irfft(np.conj(F) * G, nfft)[:, min_lag:max_lag]
    e0 = (seg[:, :lang] ** 2).sum(axis=1)
    c = np.concatenate([np.zeros((seg.shape[0], 1)), np.cumsum(seg ** 2, axis=1)], axis=1)
    lags = np.arange(min_lag, max_lag)
    e_lag = c[:, lags + lang] - c[:, lags]
    r = kreuz / np.sqrt(e0[:, None] * e_lag + 1e-12)
    return np.clip(r.max(axis=1), 0, 1).astype(np.float32)


def merkmale(x: np.ndarray, t0: float) -> Merkmale:
    S = _stft_betrag(x)
    freq = np.fft.rfftfreq(N_FFT, 1 / SR)
    leistung = S.astype(np.float64) ** 2
    band = np.stack([leistung[:, (freq >= lo) & (freq < hi)].sum(axis=1) for lo, hi in BAENDER], axis=1)
    band_db = 10 * np.log10(band + 1e-10) - _DBFS
    hoch_db = 10 * np.log10(band[:, 2] + band[:, 3] + 1e-10) - _DBFS
    zeit = t0 + (np.arange(S.shape[0]) * HOP + N_FFT / 2) / SR
    return Merkmale(zeit, band_db, hoch_db, np.zeros(S.shape[0], np.float32))


@dataclass
class Spitze:
    t: float        # Zeit im Video (s)
    hoch: float     # Hochband-Pegel (dBFS)
    tief: float     # Tiefband-Pegel um die Spitze (dBFS)


def finde_spitzen(x: np.ndarray, m: Merkmale) -> list[Spitze]:
    """Breitbandige, laute Spitzen im Hochband (Schuss-/Treffer-Kandidaten), Sprache entfernt."""
    n = len(m.zeit)
    if n < 20:
        return []
    hf = m.hoch_db
    tief = m.band_db[:, 0]
    schwelle_h = max(SPITZE_HOCH, float(np.percentile(hf, BODEN_PERZENTIL)) + SPITZE_REL)
    schwelle_t = max(SPITZE_TIEF, float(np.percentile(tief, BODEN_PERZENTIL)) + TIEF_REL)
    lokal_max = maximum_filter1d(hf, 7)          # ±30 ms
    tief_um = maximum_filter1d(tief, 5)          # Bass des Knalls kommt teils minimal später
    kand = np.where((hf == lokal_max) & (hf >= schwelle_h) & (tief_um >= schwelle_t))[0]
    if len(kand) == 0:
        return []
    # Stimmhaftigkeit im Umfeld jeder Spitze (Raster 20 ms), jeden Rahmen nur einmal rechnen
    r = int(round(UMFELD_S / DT))
    umfeld = np.unique(np.concatenate([np.arange(max(0, i - r), min(n, i + r + 1), 2) for i in kand] + [kand]))
    m.harmonisch[umfeld] = harmonizitaet(x, umfeld)
    ergebnis = []
    for i in kand:
        if m.harmonisch[i] >= HARMONISCH_MAX:
            continue
        um = m.harmonisch[max(0, i - r):min(n, i + r + 1):2]
        if np.median(um) > UMFELD_MEDIAN_MAX:
            continue
        ergebnis.append(Spitze(float(m.zeit[i]), float(hf[i]), float(tief_um[i])))
    return ergebnis


def kampf_zeitpunkte(spitzen: list[Spitze], knall_hoch: float = KNALL_HOCH) -> list[float]:
    """Zeitpunkte, die sicher nach Kampf klingen: Teil einer Salve oder ein sehr lauter Knall."""
    ts = np.array([s.t for s in spitzen])
    ergebnis = []
    for i, s in enumerate(spitzen):
        if s.hoch >= knall_hoch and s.tief >= KNALL_TIEF:
            ergebnis.append(s.t)
            continue
        # Salve: SALVE_N Spitzen in einem Fenster der Länge SALVE_S, das s enthält
        lo = np.searchsorted(ts, s.t - SALVE_S)
        hi = np.searchsorted(ts, s.t + SALVE_S, side="right")
        nachbarn = ts[lo:hi]
        for a in nachbarn[nachbarn <= s.t]:
            if np.count_nonzero((nachbarn >= a) & (nachbarn <= a + SALVE_S)) >= SALVE_N:
                ergebnis.append(s.t)
                break
    return ergebnis


@dataclass
class Beginn:
    t: float | None           # gefundener Kampfbeginn (s) oder None = nichts Klares gefunden
    kampf: list[float]        # alle Kampf-Zeitpunkte im gelesenen Abschnitt (für Diagnose/Tests)


LUECKE_S = 10.0      # Pausen bis zu so lange gehören noch zum selben Gefecht
NAEHE_S = 8.0        # so nah vor dem Event muss der letzte Kampflärm liegen
PUFFER_S = 1.0       # Clip startet so viel vor dem ersten Schuss (Kontext)
KONTEXT_S = 40.0     # mindestens so viel Ton lesen (Grundpegel)


def kampfbeginn(video: str, t_event: float, max_vorlauf: float, ende_suche: float | None = None) -> Beginn:
    """Sucht rückwärts ab t_event (höchstens max_vorlauf s) den Anfang des Gefechts.

    ende_suche: bis wohin nach dem Event noch Ton gelesen wird (Kampflärm direkt beim Kill).
    """
    von = max(0.0, t_event - max_vorlauf - 5.0)
    bis = t_event + 1.5 if ende_suche is None else max(t_event + 1.5, ende_suche)
    # Für einen verlässlichen Grundpegel mindestens KONTEXT_S Ton lesen (z. B. am Dateianfang,
    # wo sonst nur Gefechtslärm im Abschnitt wäre und die Schwellen zu hoch lägen)
    bis = max(bis, von + KONTEXT_S)
    x = lese_ton(video, von, bis - von)
    if len(x) < SR:
        return Beginn(None, [])
    m = merkmale(x, von)
    kampf = kampf_zeitpunkte(finde_spitzen(x, m))
    return Beginn(beginn_aus_kampf(kampf, t_event, max_vorlauf), kampf)


def beginn_aus_kampf(kampf: list[float], t_event: float, max_vorlauf: float) -> float | None:
    """Reine Logik: aus Kampf-Zeitpunkten rückwärts ab t_event den Gefechtsanfang bestimmen."""
    vorher = sorted((t for t in kampf if t <= t_event + 1.0), reverse=True)
    if not vorher or vorher[0] < t_event - NAEHE_S:
        return None
    grenze = t_event - max_vorlauf
    frueheste = vorher[0]
    for t in vorher[1:]:
        if frueheste - t > LUECKE_S:
            break
        if t < grenze:              # Gefecht reicht über max_vorlauf hinaus → an der Grenze starten
            return max(0.0, grenze)
        frueheste = t
    return max(0.0, grenze, min(frueheste - PUFFER_S, t_event))
