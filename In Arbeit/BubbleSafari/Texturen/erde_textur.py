# Pixel-Erdtextur fuer die Terrassenwaende (Stil TVA-Video): waagrechte Erdschichten,
# dunkle/helle Einzelpixel, kleine eingebettete Steine, vereinzelt Moos.
# Kachelbar (links/rechts und oben/unten). 32 x 64 Pixel = 16 x 32 Studs bei 0,5 Stud pro Pixel.
# Ausgabe hochskaliert (Nearest) damit Roblox' Filter die Pixel scharf laesst.
# Aufruf: python erde_textur.py <ausgabe.png> [variante]
import sys, random, math
from PIL import Image

W, H, SKALA = 32, 64, 16
OUT = sys.argv[1] if len(sys.argv) > 1 else "erde_wand.png"
VAR = sys.argv[2] if len(sys.argv) > 2 else "wiese"
rnd = random.Random(11)

def hexf(h): h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
PAL = {
    "wiese": {"schichten": ["#8a5634", "#7b4a2b", "#94603a", "#6f4126"], "dunkel": "#55311b", "hell": "#a87048",
              "stein": ["#8d8379", "#a39a90"], "moos": "#5aa835"},
}[VAR]
schichten = [hexf(c) for c in PAL["schichten"]]
dunkel, hell = hexf(PAL["dunkel"]), hexf(PAL["hell"])

# Schichtgrenzen: wellige Linien (periodisch in x), Schichtdicke 9-16 px
grenzen = []
y = 0
while y < H:
    d = rnd.randint(9, 16)
    if y + d > H - 6: d = H - y
    amp, ph = rnd.choice([1, 1, 2]), rnd.random() * math.tau
    grenzen.append((y + d, amp, ph))
    y += d

def schicht_index(x, y):
    for i, (g, amp, ph) in enumerate(grenzen):
        welle = round(amp * math.sin(ph + x / W * math.tau * rnd_freq[i]))
        if y < g + welle: return i
    return len(grenzen) - 1
rnd_freq = [rnd.choice([1, 2, 3]) for _ in grenzen]

img = Image.new("RGB", (W, H))
px = img.load()
for y in range(H):
    for x in range(W):
        i = schicht_index(x, y)
        c = schichten[i % len(schichten)]
        r = rnd.random()
        if r < 0.10: c = dunkel
        elif r < 0.16: c = hell
        px[x, y] = c
# dunkle Striche (2-3 px waagrecht) wie Wurzeln/Risse
for _ in range(18):
    x, y = rnd.randrange(W), rnd.randrange(H)
    for k in range(rnd.randint(2, 3)): px[(x + k) % W, y] = dunkel
# kleine Steine (2x2 / 3x2) mit heller Kante
for _ in range(5):
    x, y = rnd.randrange(W), rnd.randrange(H)
    w, h = rnd.choice([(2, 2), (3, 2), (2, 1)])
    for dx in range(w):
        for dy in range(h):
            px[(x + dx) % W, (y + dy) % H] = hexf(PAL["stein"][0 if dy else 1])
# vereinzelt Moos-Pixel
for _ in range(6):
    x, y = rnd.randrange(W), rnd.randrange(H)
    px[x, y] = hexf(PAL["moos"])

img.resize((W * SKALA, H * SKALA), Image.NEAREST).save(OUT)
img.resize((W * 8, H * 8), Image.NEAREST).save(OUT.replace(".png", "_vorschau.png"))
print("ok", OUT)
