# Test 34 --nur=boden: zweite zeitliche Ableitung getrennt für Boden (untere 40 %) und Häuser/Himmel (obere 40 %).
# Springt nur der Boden (Boden >> oben), wird die Bodenfläche ungenau gezeichnet.
import sys, re
import numpy as np
from PIL import Image
ordner, log = sys.argv[1], sys.argv[2]
for z in open(log, encoding='utf8', errors='ignore'):
    m = re.search(r'FLIMMER (\S+) (\S+) von=(\d+)', z)
    if not m:
        continue
    f0 = int(m.group(3))
    b = [np.asarray(Image.open(f"{ordner}/b{f - 2:08d}.png").convert('L'), dtype=float) for f in range(f0 + 2, f0 + 16)]
    h = b[0].shape[0]
    g = [x[int(h * 0.6):, :] for x in b]
    o = [x[:int(h * 0.4), :] for x in b]
    d2g = [np.abs(g[i - 1] - 2 * g[i] + g[i + 1]).mean() for i in range(1, len(g) - 1)]
    d2o = [np.abs(o[i - 1] - 2 * o[i] + o[i + 1]).mean() for i in range(1, len(o) - 1)]
    print(f"{m.group(1):10s} {m.group(2):8s} boden max {max(d2g):6.2f} mittel {np.mean(d2g):5.2f} | oben {np.mean(d2o):5.2f}")
