# Texturen fuer Hauptweg + Wurfdeck (Vorlage: Konzepte/weg-hauptweg-wurfdeck.webp)
#   pflaster_gelb.png : Pflastersteine gelb/creme/grau mit dunklen Fugen + Moos (32x32 px = 8x8 Studs)
#   bordstein.png     : helle Steinquader fuer die Wegkante (16x16 px = 4x4 Studs)
#   wurfkreis.png     : goldener Leuchtkreis mit Blasen-Symbol (transparent, als Decal)
#   wasserfall.png    : kachelbarer Wasserfall-Streifen (wird im Client nach unten geschoben)
# Aufruf: python weg_texturen.py <ausgabeordner>
import sys, os, random, math
from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
def hexf(h): h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def pflaster(name, farben, fuge, moos, seed):
    W = 32; rnd = random.Random(seed)
    img = Image.new("RGB", (W, W), hexf(fuge)); px = img.load()
    # Steine in Reihen (versetzt), Groesse 3-5 px, 1 px Fuge
    y = 0
    while y < W:
        h = rnd.choice([4, 4, 5])
        x = rnd.randint(-3, 0)
        while x < W:
            w = rnd.choice([4, 5, 6])
            c = hexf(rnd.choice(farben))
            for dy in range(h - 1):
                for dx in range(w - 1):
                    xx, yy = (x + dx) % W, (y + dy) % W
                    v = rnd.random()
                    cc = c if v > 0.12 else tuple(max(0, k - 18) for k in c)
                    if dy == 0 and v > 0.5: cc = tuple(min(255, k + 14) for k in c)  # Lichtkante oben
                    px[xx, yy] = cc
            x += w
        y += h
    for _ in range(14):  # Moos in den Fugen
        x, y = rnd.randrange(W), rnd.randrange(W)
        if px[x, y] == hexf(fuge): px[x, y] = hexf(moos)
    img.resize((W * 16, W * 16), Image.NEAREST).save(os.path.join(OUT, name))

pflaster("pflaster_gelb.png", ["#e8c46a", "#f0d48a", "#d9b25a", "#c9c3b5", "#e2cf9e"], "#8c7a5c", "#6fae3c", 3)

# Bordstein: grosse helle Quader
W = 16; rnd = random.Random(8)
img = Image.new("RGB", (W, W), hexf("#8f8a80")); px = img.load()
for (x0, y0, w, h) in ((0, 0, 8, 8), (8, 0, 8, 8), (4, 8, 8, 8), (12, 8, 4, 8), (0, 8, 4, 8)):
    c = hexf(rnd.choice(["#d6d0c4", "#c9c2b4", "#ded8cc"]))
    for dy in range(h - 1):
        for dx in range(w - 1):
            v = rnd.random()
            px[(x0 + dx) % W, (y0 + dy) % W] = c if v > 0.15 else tuple(k - 16 for k in c)
for _ in range(4):
    px[rnd.randrange(W), rnd.randrange(W)] = hexf("#6fae3c")
img.resize((W * 32, W * 32), Image.NEAREST).save(os.path.join(OUT, "bordstein.png"))

# Wurfkreis: Pixel-Ring + Blasen-Symbol, transparent
N = 64
img = Image.new("RGBA", (N, N), (0, 0, 0, 0)); px = img.load()
c = N / 2 - 0.5
for y in range(N):
    for x in range(N):
        d = math.hypot(x - c, y - c)
        if 27 <= d <= 30: px[x, y] = (255, 200, 60, 255)
        elif 25 <= d < 27: px[x, y] = (255, 236, 140, 255)
        elif 20 <= d <= 21.5 and (int(math.degrees(math.atan2(y - c, x - c))) // 15) % 2 == 0: px[x, y] = (255, 210, 80, 230)
for (bx, by, br) in ((c - 4, c + 2, 8.5), (c + 8, c - 7, 4.5), (c + 10, c + 8, 2.5)):  # Blasen-Symbol
    for y in range(N):
        for x in range(N):
            d = math.hypot(x - bx, y - by)
            if br - 1.3 <= d <= br: px[x, y] = (255, 245, 200, 255)
    px[int(bx - br * 0.45), int(by - br * 0.45)] = (255, 255, 255, 255)
img.resize((N * 8, N * 8), Image.NEAREST).save(os.path.join(OUT, "wurfkreis.png"))

# Wasserfall-Streifen
W, H = 16, 32; rnd = random.Random(4)
img = Image.new("RGB", (W, H)); px = img.load()
for x in range(W):
    base = rnd.choice(["#4fb7f0", "#5fc4f5", "#45a8e6"])
    for y in range(H):
        px[x, y] = hexf(base)
    for _ in range(3):  # helle Schaumstreifen
        y0 = rnd.randrange(H); l = rnd.randint(2, 6)
        for k in range(l): px[x, (y0 + k) % H] = hexf(rnd.choice(["#bfeaff", "#e8f8ff", "#8fd6fa"]))
img.resize((W * 16, H * 16), Image.NEAREST).save(os.path.join(OUT, "wasserfall.png"))
print("ok")
