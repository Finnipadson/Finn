"""Erzeugt das App-Icon: assets/icon.ico (Desktop-Verknuepfung) + public/favicon.png (App-Fenster).
Aufruf: python tools/icon.py"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
N = 1024  # gross zeichnen, dann verkleinern (glatte Kanten)

img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
# Leuchten hinter der Kachel
glow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
ImageDraw.Draw(glow).rounded_rectangle((110, 110, N - 110, N - 110), radius=210, fill=(255, 122, 89, 150))
img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(40)))
# Kachel mit Verlauf (Koralle -> Orange)
kachel = Image.new("RGBA", (N, N))
for y in range(N):
    t = y / N
    r, g, b = int(255), int(110 + 50 * t), int(89 - 30 * t)
    ImageDraw.Draw(kachel).line([(0, y), (N, y)], fill=(r, g, b, 255))
maske = Image.new("L", (N, N), 0)
ImageDraw.Draw(maske).rounded_rectangle((90, 90, N - 90, N - 90), radius=200, fill=255)
img.paste(kachel, (0, 0), maske)
d = ImageDraw.Draw(img)
# Play-Dreieck
d.polygon([(400, 290), (400, 640), (690, 465)], fill=(255, 255, 255, 255))
# Untertitel-Balken (wie im Video)
d.rounded_rectangle((250, 730, 520, 790), radius=30, fill=(255, 255, 255, 235))
d.rounded_rectangle((545, 730, 775, 790), radius=30, fill=(255, 211, 77, 255))

(ROOT / "assets").mkdir(exist_ok=True)
img.save(ROOT / "assets" / "icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
img.resize((256, 256), Image.LANCZOS).save(ROOT / "assets" / "icon.png")
img.resize((64, 64), Image.LANCZOS).save(ROOT / "public" / "favicon.png")
print("Icon erstellt: assets/icon.ico, assets/icon.png, public/favicon.png")
