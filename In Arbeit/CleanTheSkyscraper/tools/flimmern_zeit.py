# Auswertung zu Test 34 --nur=flimmern: mittlere zweite zeitliche Ableitung (Helligkeit 0..255) je Abschnitt.
# Aufruf: python tools/flimmern_zeit.py ORDNER LOG   (LOG enthält die Zeilen „FLIMMER ort zustand von=f“)
import sys, re
import numpy as np
from PIL import Image
ordner, log = sys.argv[1], sys.argv[2]
for z in open(log, encoding='utf8', errors='ignore'):
    m = re.search(r'FLIMMER (\S+) (\S+) von=(\d+)', z)
    if not m:
        continue
    f0 = int(m.group(3))
    b = [np.asarray(Image.open(f"{ordner}/b{f - 2:08d}.png").convert('L'), dtype=float) for f in range(f0 + 1, f0 + 16)]
    d2 = [np.abs(b[i - 1] - 2 * b[i] + b[i + 1]).mean() for i in range(1, len(b) - 1)]
    print(f"{m.group(1):10s} {m.group(2):7s} {np.mean(d2):.3f}")
