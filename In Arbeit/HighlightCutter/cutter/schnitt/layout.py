"""Bildaufbau: Wie wird ein Quellbild auf die Ausgabefläche gebracht?

16:9-Ausgabe, 16:9-Quelle  → ganzes Bild skaliert (bleibt komplett auf der GPU).
16:9-Ausgabe, andere Quelle → ganzes Bild eingepasst, dahinter unscharfer Hintergrund.
9:16-Ausgabe              → Mitte der Quelle im Seitenverhältnis VORDERGRUND_9_16 (4:5) ausschneiden,
                            auf volle Breite skalieren, mittig platzieren; oben/unten ein
                            unscharfer, abgedunkelter Hintergrund aus demselben Bild.

Warum 4:5 statt einem vollen 9:16-Ausschnitt? Ein 9:16-Ausschnitt aus 16:9 zeigt nur 32 % der
Bildbreite – bei einem Shooter fehlt dann fast alles links/rechts vom Fadenkreuz. 4:5 zeigt 45 %
der Breite bei voller Bildhöhe, das Fadenkreuz bleibt in der Bildmitte, und das Bild füllt mit
1080×1350 trotzdem 70 % des Handy-Bildschirms. (Wie Instagram/TikTok-Gaming-Clips üblich.)
"""
from __future__ import annotations

from dataclasses import dataclass

VORDERGRUND_9_16 = 4 / 5        # Breite/Höhe des Vordergrund-Ausschnitts im Hochformat
HINTERGRUND_VERKLEINERUNG = 4   # Hintergrund wird in 1/4 Größe weichgezeichnet (schnell)
HINTERGRUND_UNSCHAERFE = 14     # gblur-Sigma in der verkleinerten Größe
HINTERGRUND_HELLIGKEIT = 0.45   # Luma-Faktor (abgedunkelt)


def _gerade(x: float) -> int:
    return max(2, int(round(x / 2)) * 2)


@dataclass
class Aufbau:
    breite: int            # Ausgabefläche
    hoehe: int
    zw_breite: int         # Quelle wird zuerst (GPU) auf diese Größe skaliert …
    zw_hoehe: int
    vg_breite: int         # … daraus wird mittig dieser Vordergrund ausgeschnitten
    vg_hoehe: int

    @property
    def nur_skalieren(self) -> bool:
        return (self.vg_breite, self.vg_hoehe) == (self.breite, self.hoehe) == \
            (self.zw_breite, self.zw_hoehe)


def ausgabe_groesse(format: str, hoehe: int) -> tuple[int, int]:
    """16:9 → (hoehe·16/9, hoehe); 9:16 → (hoehe, hoehe·16/9)."""
    lang = _gerade(hoehe * 16 / 9)
    return (lang, _gerade(hoehe)) if format != "9:16" else (_gerade(hoehe), lang)


def berechne(format: str, hoehe: int, src_b: int, src_h: int) -> Aufbau:
    cw, ch = ausgabe_groesse(format, hoehe)
    src_aspekt = src_b / src_h
    if format == "9:16":
        vg_aspekt = min(VORDERGRUND_9_16, src_aspekt)      # schmale Quelle: ganze Breite
        vg_b = cw
        vg_h = min(ch, _gerade(cw / vg_aspekt))
        # Quelle so skalieren, dass ihre Höhe = Vordergrundhöhe (Ausschnitt volle Höhe)
        f = vg_h / src_h
        zw_b, zw_h = _gerade(src_b * f), vg_h
        vg_b = min(vg_b, zw_b)
        return Aufbau(cw, ch, zw_b, zw_h, vg_b, vg_h)
    # 16:9: einpassen
    if abs(src_aspekt - cw / ch) < 0.01:
        return Aufbau(cw, ch, cw, ch, cw, ch)
    f = min(cw / src_b, ch / src_h)
    zw_b, zw_h = _gerade(src_b * f), _gerade(src_h * f)
    return Aufbau(cw, ch, zw_b, zw_h, zw_b, zw_h)


def video_filter(a: Aufbau, fps: int, gpu: bool, eingang: str = "0:v") -> str:
    """Filterkette Quelle → fertiges Bild (Ausgabe-Label [bild]).

    GPU: Decodierte CUDA-Frames werden auf der GPU skaliert (scale_cuda). Beim reinen Skalieren
    bleibt alles auf der GPU (NVENC liest die CUDA-Frames direkt). Mit Hintergrund wird das
    (schon verkleinerte) Bild heruntergeladen und auf der CPU zusammengesetzt.
    """
    teile = [f"[{eingang}]fps={fps}"]
    if gpu:
        teile.append(f"scale_cuda={a.zw_breite}:{a.zw_hoehe}:interp_algo=lanczos:format=nv12")
        if not a.nur_skalieren:
            teile.append("hwdownload,format=nv12")
    else:
        teile.append(f"scale={a.zw_breite}:{a.zw_hoehe}:flags=lanczos,format=yuv420p")
    kette = ",".join(teile)
    if a.nur_skalieren:
        return kette + "[bild]"

    # Hintergrund: größtmöglicher Ausschnitt im Seitenverhältnis der Ausgabe, klein, weich, dunkel
    ziel_aspekt = a.breite / a.hoehe
    hb = min(a.zw_breite, _gerade(a.zw_hoehe * ziel_aspekt))
    hh = min(a.zw_hoehe, _gerade(hb / ziel_aspekt))
    kb, kh = _gerade(a.breite / HINTERGRUND_VERKLEINERUNG), _gerade(a.hoehe / HINTERGRUND_VERKLEINERUNG)
    hg = (f"crop={hb}:{hh}:(iw-{hb})/2:(ih-{hh})/2,scale={kb}:{kh}:flags=bilinear,"
          f"gblur=sigma={HINTERGRUND_UNSCHAERFE},lutyuv=y=val*{HINTERGRUND_HELLIGKEIT},"
          f"scale={a.breite}:{a.hoehe}:flags=bicubic")
    vg = f"crop={a.vg_breite}:{a.vg_hoehe}:(iw-{a.vg_breite})/2:(ih-{a.vg_hoehe})/2"
    return (f"{kette},split=2[vg_roh][hg_roh];[hg_roh]{hg}[hg];[vg_roh]{vg}[vg];"
            f"[hg][vg]overlay=(W-w)/2:(H-h)/2:format=yuv420,format=yuv420p[bild]")
