# Flimmer-Messung: nimmt pro Testort ein paar aufeinanderfolgende Bilder bei langsam bewegter Kamera auf
# und misst, wie stark Bildpunkte von Bild zu Bild "springen" (zweite zeitliche Ableitung).
# Gleichmäßige Bewegung ändert einen Bildpunkt fast linear -> Wert ~0; Flimmern (Aliasing, Z-Fighting,
# Schatten-Akne) springt hin und her -> großer Wert.
#
#   python tools/flimmern.py AUSGABE_ORDNER [--orte=boden_nah,fassade] [--name=vorher] [-- godot-schalter ...]
#
# Ergebnis: Zahlen pro Ort (Mittel x1000, Anteil sichtbar flimmernder Punkte in Promille) und ein kleines
# Sammelbild AUSGABE/NAME.png (oben Bild, unten Flimmerkarte: hell = flimmert).
import os, sys, glob, subprocess, shutil
import numpy as np
from PIL import Image

GODOT = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe")
PROJEKT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# name: (ansicht, kamera "x,y,z,zielx,ziely,zielz" oder None, fahrt "dx,dy,dz" oder None, dreh grad/s)
ORTE = {
    "boden_nah":  (1, "192,1.7,180,190,0,240", "0,0,0.3", 0),          # Straße mit Gehweg, Zebrastreifen
    "platz_nah":  (1, "-45,1.7,60,-80,0,100", "0.3,0,0", 0),           # Platz, Steinringe, Blumenbeete
    "boden_fern": (1, "0,150,190,0,0,650", "0.6,0,0", 0),             # aus Gondelhöhe auf die Stadt
    "boden_flach":(1, "40,25,-300,0,0,-60", "0.2,0,0", 0),              # flach über Straßen + Platz (Gondel unten)
    "turmfuss":   (1, "30,1.7,170,0,40,0", "0.3,0,0", 0),              # Turmfuß + Platz
    "fassade":    (4, None, "tempo", 0),                                 # Gondel-Fahrt an der Turmfassade
    "turm_fern":  (1, "-650,150,300,0,300,0", "0,0,1.5", 0),             # Turm aus der Stadt
    "still":      (1, "0,120,190,0,60,600", None, 0),                  # Kamera steht (zeigt TAA-Zittern)
    "drehen":     (1, "0,120,190,0,60,600", None, 0.3),                  # Gondel dreht sich (Boden + Häuser)
}
WARM = 24     # Bilder zum Einlaufen (Shader kompilieren, Schatten)
ZAHL = 16     # ausgewertete Bilder

def aufnehmen(ort, ziel, extra):
    ansicht, kam, fahrt, dreh = ORTE[ort]
    if os.path.isdir(ziel):
        shutil.rmtree(ziel)
    os.makedirs(ziel)
    args = [GODOT, "--path", PROJEKT, "--write-movie", os.path.join(ziel, "b.png"), "--fixed-fps", "30",
            "--quit-after", str(WARM + ZAHL), "--", "--ansicht=%d" % ansicht]
    if kam: args.append("--kamera=" + kam)
    if fahrt == "tempo": args.append("--tempo=0.05")
    elif fahrt: args.append("--fahrt=" + fahrt)
    if dreh: args.append("--dreh=%g" % dreh)
    args += extra
    subprocess.run(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=600)
    bilder = sorted(glob.glob(os.path.join(ziel, "b*.png")))
    return bilder[-ZAHL:]

def messen(bilder):
    f = np.stack([np.asarray(Image.open(b).convert("L"), dtype=np.float32) / 255.0 for b in bilder])
    d = np.abs(f[1:-1] - 0.5 * (f[:-2] + f[2:]))          # zweite Ableitung in der Zeit
    karte = d.mean(axis=0)
    return karte, float(karte.mean() * 1000.0), float((karte > 0.03).mean() * 1000.0), f[len(f) // 2]

def main():
    aus = sys.argv[1]
    os.makedirs(aus, exist_ok=True)
    orte = list(ORTE)
    name = "messung"
    extra = []
    rest = sys.argv[2:]
    if "--" in rest:
        extra = rest[rest.index("--") + 1:]
        rest = rest[:rest.index("--")]
    for a in rest:
        if a.startswith("--orte="): orte = a.split("=", 1)[1].split(",")
        if a.startswith("--name="): name = a.split("=", 1)[1]
    kacheln = []
    zeilen = []
    for ort in orte:
        bilder = aufnehmen(ort, os.path.join(aus, "roh_" + ort), extra)
        if len(bilder) < 3:
            print("%-11s keine Bilder" % ort)
            continue
        karte, mittel, anteil, bild = messen(bilder)
        zeilen.append("%-11s Flimmern %6.2f   sichtbar %6.1f Promille" % (ort, mittel, anteil))
        print(zeilen[-1], flush=True)
        b = Image.fromarray((bild * 255).astype(np.uint8)).convert("RGB").resize((480, 270), Image.LANCZOS)
        k = Image.fromarray(np.clip(karte * 255 * 8, 0, 255).astype(np.uint8)).resize((480, 270), Image.BOX).convert("RGB")
        kachel = Image.new("RGB", (480, 540))
        kachel.paste(b, (0, 0)); kachel.paste(k, (0, 270))
        kacheln.append(kachel)
    if kacheln:
        sammel = Image.new("RGB", (480 * len(kacheln), 540))
        for i, k in enumerate(kacheln):
            sammel.paste(k, (480 * i, 0))
        sammel.save(os.path.join(aus, name + ".png"))
        with open(os.path.join(aus, name + ".txt"), "w") as t:
            t.write("\n".join(zeilen) + "\n")

if __name__ == "__main__":
    main()
