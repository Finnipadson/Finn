# Vier Erdtextur-Varianten zum Auswaehlen (alle 16 x 32 px = 16 x 32 Studs, 1 Stud pro Pixel, kachelbar).
#   A_ruhiger   : fast einfarbige Schichten, nur sehr wenige Kruemel
#   B_schichten : deutlich verschiedene Erdbaender mit dunkler Fuge, kaum Kruemel
#   C_kiesel    : ruhige Erde mit ein paar groesseren eingebetteten Steinen
#   D_flecken   : grobe 2x2-Flecken in drei Brauntoenen (Block-Erde)
# Aufruf: python erde_varianten.py <ausgabeordner>
import sys, os, random, math
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
W, H, SKALA = 16, 32, 32

def hexf(h): h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
BRAUN = hexf("#84522f"); DUNKEL = hexf("#5e371d"); HELL = hexf("#9a6640")

def schichten(rnd, dicke, farben, amp=(0, 1)):
    grenzen, y = [], 0
    while y < H:
        d = rnd.randint(*dicke)
        if y + d > H - dicke[0] // 2: d = H - y
        grenzen.append((y + d, rnd.choice(amp), rnd.random() * math.tau, rnd.choice([1, 2])))
        y += d
    def idx(x, y):
        for i, (g, a, ph, fr) in enumerate(grenzen):
            if y < g + round(a * math.sin(ph + x / W * math.tau * fr)): return i
        return len(grenzen) - 1
    return idx, grenzen

def kruemel(px, rnd, anteil_dunkel, anteil_hell, dunkel=DUNKEL, hell=HELL):
    for y in range(H):
        for x in range(W):
            r = rnd.random()
            if r < anteil_dunkel: px[x, y] = dunkel
            elif r < anteil_dunkel + anteil_hell: px[x, y] = hell

def variante_a(px, rnd):
    farben = [hexf("#86532f"), hexf("#7f4f2d"), hexf("#8a5832")]
    idx, _ = schichten(rnd, (8, 12), farben)
    for y in range(H):
        for x in range(W): px[x, y] = farben[idx(x, y) % len(farben)]
    kruemel(px, rnd, 0.018, 0.012)

def variante_b(px, rnd):
    farben = [hexf("#8f5a33"), hexf("#74452a"), hexf("#9b6a3e"), hexf("#7d4b2b")]
    idx, grenzen = schichten(rnd, (6, 9), farben, amp=(0, 1, 1))
    for y in range(H):
        for x in range(W): px[x, y] = farben[idx(x, y) % len(farben)]
    for y in range(H):  # dunkle Fuge an jeder Schichtgrenze
        for x in range(W):
            if y + 1 < H and idx(x, y) != idx(x, y + 1): px[x, y] = DUNKEL
    kruemel(px, rnd, 0.012, 0.0)

def variante_c(px, rnd):
    farben = [hexf("#85522f"), hexf("#7e4e2c")]
    idx, _ = schichten(rnd, (10, 14), farben)
    for y in range(H):
        for x in range(W): px[x, y] = farben[idx(x, y) % len(farben)]
    kruemel(px, rnd, 0.015, 0.0)
    for k in range(4):  # Steine 3x2 / 2x2 mit heller Oberkante und dunkler Unterkante
        x0, y0 = rnd.randrange(W), rnd.randrange(H)
        w, h = rnd.choice([(3, 2), (2, 2), (3, 3)])
        for dx in range(w):
            for dy in range(h):
                c = hexf("#a39a8f") if dy == 0 else (hexf("#7c746b") if dy == h - 1 else hexf("#8f877d"))
                px[(x0 + dx) % W, (y0 + dy) % H] = c

def variante_d(px, rnd):
    toene = [hexf("#8a5632"), hexf("#7a4a2b"), hexf("#965f37")]
    for by in range(0, H, 2):
        for bx in range(0, W, 2):
            r = rnd.random()
            c = toene[0] if r < 0.55 else (toene[1] if r < 0.8 else toene[2])
            for dx in range(2):
                for dy in range(2): px[bx + dx, by + dy] = c
    kruemel(px, rnd, 0.01, 0.0)

VARIANTEN = {"A_ruhiger": variante_a, "B_schichten": variante_b, "C_kiesel": variante_c, "D_flecken": variante_d}
bilder = []
for name, fn in VARIANTEN.items():
    rnd = random.Random(23)
    img = Image.new("RGB", (W, H)); fn(img.load(), rnd)
    img.resize((W * SKALA, H * SKALA), Image.NEAREST).save(os.path.join(OUT, f"erde_{name}.png"))
    bilder.append(img)
    print("ok", name)
# Vorschau: jede Variante 2x2 gekachelt nebeneinander
v = 6
vor = Image.new("RGB", (len(bilder) * (W * 2 * v + 12), H * 2 * v), (40, 40, 40))
for i, b in enumerate(bilder):
    k = b.resize((W * v, H * v), Image.NEAREST)
    for a in range(2):
        for c in range(2): vor.paste(k, (i * (W * 2 * v + 12) + a * W * v, c * H * v))
vor.save(os.path.join(OUT, "Renders", "erde_varianten_vorschau.png"))
