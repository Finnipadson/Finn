# Wurfdeck + Weg-Deko fuer Bubble Safari (Vorlage: BubbleSafari/Konzepte/weg-hauptweg-wurfdeck.webp)
# Eine FBX mit: Deck_Haupt (Holzdeck 28x24 Studs, Treppe Richtung Kessel = -Y, Gelaender, Steinsaeulen mit Laternen,
# blaue Banner), Deck_Ring (zwei gestreifte Stangen + goldener Blasenring an der Schlucht-Seite, +Y),
# Laterne (Wegelaterne), Blumenfass. Leuchtkreis/Wasser kommen in Roblox dazu.
# Headless: blender -b --factory-startup --python voxel_wurfdeck.py -- <ausgabeordner>
import os, math
NAME = "wurfdeck"
PAL = {
    "holz0": "#4a2c17", "holz1": "#633c20", "holz2": "#7b4c29", "holz3": "#935e34", "fuge": "#3a2312",
    "stein0": "#9e9a92", "stein1": "#b3aea4", "stein2": "#c7c1b5", "steinf": "#77736d",
    "dunkel": "#2f2a33", "dach0": "#4a3a33", "licht0": "#f5b331", "licht1": "#ffe07a",
    "gold0": "#b88a2a", "gold1": "#d9a838", "gold2": "#f0c95a",
    "blau0": "#2d5fae", "blau1": "#3f78c9", "weiss": "#f2f4f7", "rosa": "#e66fa3", "rosa2": "#f293bf",
    "blatt0": "#3e9a35", "blatt1": "#5cbf45", "gelb": "#ffd84a", "lila": "#b892ff", "blume_r": "#ff7ab0", "blau_b": "#6ab4ff",
    "fass0": "#6b4224", "fass1": "#85552f", "band": "#3a3a40", "erde": "#5e3a1f",
}
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "voxelladen_basis.py"), encoding="utf-8").read())

def laterne(Z, cx, cy, z0, hoehe=10):
    """Laterne: Steinsockel, Holzpfosten, Laternenkasten mit Dach (Voxel-Indizes, cx/cy = Mitte)."""
    box(Z, cx - 2, cx + 2, cy - 2, cy + 2, z0, z0 + 2, "stein")
    box(Z, cx - 1, cx + 1, cy - 1, cy + 1, z0 + 2, z0 + hoehe, "pfosten")
    k = z0 + hoehe
    box(Z, cx - 2, cx + 2, cy - 2, cy + 2, k, k + 1, "rahmen_d")
    box(Z, cx - 2, cx + 2, cy - 2, cy + 2, k + 1, k + 4, "licht")
    for dx, dy in ((-2, -2), (1, -2), (-2, 1), (1, 1)):
        box(Z, cx + dx, cx + dx + 1, cy + dy, cy + dy + 1, k + 1, k + 4, "rahmen_d")
    box(Z, cx - 3, cx + 3, cy - 3, cy + 3, k + 4, k + 5, "dach")
    box(Z, cx - 2, cx + 2, cy - 2, cy + 2, k + 5, k + 6, "dach")
    box(Z, cx - 1, cx + 1, cy - 1, cy + 1, k + 6, k + 7, "dach")

def baue_deck():
    Z = {}
    T = 5  # Deckoberkante (Voxel) = 2,5 Studs
    # Unterbau: Steinsaeulen an den Ecken + Holzbalken, Plattform
    for x0, y0 in ((-28, -24), (24, -24), (-28, 20), (24, 20)):
        box(Z, x0, x0 + 4, y0, y0 + 4, 0, T, "stein")
    box(Z, -28, 28, -24, 24, 2, T, "holz_unter")
    box(Z, -28, 28, -24, 24, T - 1, T, "planke")
    # Treppe Richtung Kessel (-Y), Breite 12 Studs
    for i in range(3):
        box(Z, -12, 12, -24 - (i + 1) * 3, -24 - i * 3, 0, T - 1 - i * 1 - (1 if i == 2 else 0), "stufe")
    # Gelaender: Pfosten alle 4 Studs + 2 Latten; vorne nur neben der Treppe, hinten neben dem Ring
    def gelaender_x(y, x0, x1):
        for x in range(x0, x1 + 1, 8): box(Z, x, x + 2, y, y + 2, T, T + 8, "pfosten")
        for zl in (T + 3, T + 6): box(Z, x0, x1 + 2, y, y + 2, zl, zl + 1, "latte")
    def gelaender_y(x, y0, y1):
        for y in range(y0, y1 + 1, 8): box(Z, x, x + 2, y, y + 2, T, T + 8, "pfosten")
        for zl in (T + 3, T + 6): box(Z, x, x + 2, y0, y1 + 2, zl, zl + 1, "latte")
    gelaender_y(-28, -24, 20); gelaender_y(26, -24, 20)
    gelaender_x(-24, -28, -14); gelaender_x(-24, 12, 26)
    gelaender_x(22, -28, -10); gelaender_x(22, 8, 26)
    # Laternen auf den vorderen Ecksaeulen + hinteren
    for cx, cy in ((-26, -22), (26, -22), (-26, 22), (26, 22)):
        laterne(Z, cx, cy, T, 8)
    # blaue Banner mit Blase an den Seiten
    for x, y in ((-29, -10), (-29, 6), (28, -10), (28, 6)):
        box(Z, x, x + 1, y, y + 5, T - 6, T + 6, "banner")
        for dz, dy in ((2, 2), (1, 1), (1, 3), (3, 1), (3, 3)):
            Z[(x + (-1 if x < 0 else 1), y + dy, T + dz - 3)] = "banner_symbol"
    # Blumen an der Treppe
    for x in list(range(-16, -12)) + list(range(12, 16)):
        for y in range(-30, -24):
            r = hsh(x, y, 3)
            if r > 0.4: Z[(x, y, 0)] = "blatt"
            if r > 0.75: Z[(x, y, 1)] = ["bl_r", "bl_g", "bl_l", "bl_b"][int(hsh(x, y, 4) * 4)]
    return Z

def baue_ring():
    Z = {}
    T = 5
    ycm = 22  # Ring/Stangen an der Schlucht-Seite (Voxel y)
    for x0 in (-8, 6):
        for z in range(T, 18):
            Z[(x0, ycm, z)] = Z[(x0 + 1, ycm, z)] = "streifen"
            Z[(x0, ycm + 1, z)] = Z[(x0 + 1, ycm + 1, z)] = "streifen"
    # goldener Ring (in der x/z-Ebene), Mitte auf 9 Studs = 18 Voxel
    for x in range(-9, 9):
        for z in range(9, 28):
            d = math.hypot(x + 0.5, z + 0.5 - 18)
            if 5.2 <= d <= 7.2:
                Z[(x, ycm, z)] = "ring"; Z[(x, ycm + 1, z)] = "ring"
    return Z

def baue_laterne():
    Z = {}
    laterne(Z, 0, 0, 0, 10)
    for x in range(-3, 3):
        for y in range(-3, 3):
            if abs(x + 0.5) > 2 or abs(y + 0.5) > 2:
                r = hsh(x, y, 9)
                if r > 0.5: Z[(x, y, 0)] = "blatt"
                if r > 0.8: Z[(x, y, 1)] = ["bl_r", "bl_g", "bl_l", "bl_b"][int(hsh(x, y, 5) * 4)]
    return Z

def baue_fass():
    Z = {}
    zyl(Z, 0, 0, 3.2, 0, 6, "fass")
    zyl(Z, 0, 0, 2.6, 5, 6, "erde")
    for x in range(-3, 3):
        for y in range(-3, 3):
            if math.hypot(x + 0.5, y + 0.5) <= 2.8:
                r = hsh(x, y, 2)
                Z[(x, y, 6)] = "blatt"
                if r > 0.45: Z[(x, y, 7)] = ["bl_r", "bl_g", "bl_l", "bl_b", "blatt"][int(hsh(x, y, 6) * 5)]
                if r > 0.85: Z[(x, y, 8)] = "bl_r"
    return Z

def farbe(lab, k, n):
    x, y, z = k
    r = hsh(x, y, z, 1)
    u = y if abs(n[0]) > 0 else x
    if lab == "stein": return ["stein0", "stein1", "stein2"][int(hsh(u // 2, z // 2, 3) * 3)] if (z % 3) else "steinf"
    if lab == "planke":
        if n[2] > 0: return "fuge" if y % 4 == 0 else ("holz3" if (x // 6 + y // 4) % 3 == 0 else "holz2")
        return "holz1"
    if lab in ("holz_unter", "stufe"): return "holz1" if (u // 2) % 2 else "holz0"
    if lab == "pfosten": return "holz0" if r > 0.3 else "holz1"
    if lab == "latte": return "holz2" if r > 0.3 else "holz1"
    if lab == "rahmen_d": return "dunkel"
    if lab == "licht": return "licht1" if r > 0.6 else "licht0"
    if lab == "dach": return "dach0"
    if lab == "banner": return "blau1" if (z % 3) else "blau0"
    if lab == "banner_symbol": return "weiss"
    if lab == "streifen": return "rosa" if ((z + x) // 2) % 2 == 0 else "weiss"
    if lab == "ring": return "gold2" if r > 0.6 else ("gold1" if r > 0.2 else "gold0")
    if lab == "blatt": return "blatt1" if r > 0.4 else "blatt0"
    if lab.startswith("bl_"): return {"bl_r": "blume_r", "bl_g": "gelb", "bl_l": "lila", "bl_b": "blau_b"}[lab]
    if lab == "fass": return "band" if z in (1, 4) else ("fass1" if (u // 2) % 2 else "fass0")
    if lab == "erde": return "erde"
    return "weiss"

if __name__ == "__main__":
    for o in list(D.objects): D.objects.remove(o)
    mat = paletten_material()
    deck = mesh_aus("Deck_Haupt", baue_deck(), mat)
    ring = mesh_aus("Deck_Ring", baue_ring(), mat)
    lat = mesh_aus("Laterne", baue_laterne(), mat); lat.location = (22, -22, 0)
    fass = mesh_aus("Blumenfass", baue_fass(), mat); fass.location = (-22, -22, 0)
    fertig_machen([deck, ring, lat, fass], [((26, -40, 22), (0, 0, 3), "wurfdeck_schraeg.png"),
                                             ((0, 40, 14), (0, 0, 5), "wurfdeck_hinten.png")])
