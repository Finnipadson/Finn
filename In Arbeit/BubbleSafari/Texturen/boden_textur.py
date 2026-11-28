# Boden-Textur (Vorschlag): helles Graustufen-Pixelgras + Noppen, wird in Roblox per Texture.Color3
# in der Kachelfarbe eingefaerbt (Schachbrett bleibt). 32 x 32 px = 8 x 8 Studs (4 px pro Stud).
# Aufruf: python boden_textur.py <ausgabe.png> [schach]
#   schach: 80 x 80 px = 20 x 20 Studs mit eingebautem Schachbrett (2x2 Felder a 10 Studs, hell/dunkel),
#           damit ein ganzer Boden EIN Teil sein kann (Biom-Farbe per Texture.Color3).
import sys, random
from PIL import Image

SCHACH = len(sys.argv) > 2 and sys.argv[2] == "schach"
W = 80 if SCHACH else 32
SKALA = 8 if SCHACH else 16
OUT = sys.argv[1] if len(sys.argv) > 1 else "boden_gras.png"
rnd = random.Random(5)
img = Image.new("L", (W, W), 236)
px = img.load()
DUNKEL = 22  # Helligkeitsabzug fuer dunkle Schachfelder
def feld_dunkel(x, y): return SCHACH and ((x // 40) + (y // 40)) % 2 == 1
# Pixelgras: hellere/dunklere Einzelpixel und kurze senkrechte Halme
for y in range(W):
    for x in range(W):
        r = rnd.random()
        if r < 0.10: px[x, y] = 214
        elif r < 0.16: px[x, y] = 250
for _ in range(140 if SCHACH else 22):
    x, y = rnd.randrange(W), rnd.randrange(W)
    for k in range(rnd.randint(1, 2)): px[x, (y + k) % W] = 205
# Noppen: je Stud ein 2x2-Punkt mit Licht oben links und Schatten unten rechts
for sy in range(0, W, 4):
    for sx in range(0, W, 4):
        px[sx + 1, sy + 1] = 255
        px[sx + 2, sy + 1] = 248
        px[sx + 1, sy + 2] = 248
        px[sx + 2, sy + 2] = 222
if SCHACH:
    for y in range(W):
        for x in range(W):
            if feld_dunkel(x, y): px[x, y] = max(0, px[x, y] - DUNKEL)
img = img.convert("RGB")
img.resize((W * SKALA, W * SKALA), Image.NEAREST).save(OUT)
print("ok", OUT)
