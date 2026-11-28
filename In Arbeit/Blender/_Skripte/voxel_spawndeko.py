# Blasenstab (Wahrzeichen) + Bestenliste + Krone fuer Bubble Safari.
# Vorlagen: BubbleSafari/Konzepte/blasenstab.webp, bestenliste.webp
# Eine FBX mit: Blasenstab (fest; Seifenfilm + Blasen macht Roblox), Bestenliste (fest; Namen = SurfaceGui),
# Krone (schwebt/dreht sich in Roblox). Front jeweils -Y.
# Headless: blender -b --factory-startup --python voxel_spawndeko.py -- <ausgabeordner>
import os, math
NAME = "spawndeko"
PAL = {
    "stein0": "#9e9a92", "stein1": "#b3aea4", "stein2": "#c7c1b5", "steinf": "#77736d",
    "gras0": "#3fa832", "gras1": "#56c242", "erde": "#6b4224",
    "holz0": "#4a2c17", "holz1": "#633c20", "holz2": "#7b4c29", "holz3": "#935e34",
    "tafel0": "#3a2a20", "tafel1": "#4a372b", "tafelf": "#2a1d15",
    "gold0": "#b88a2a", "gold1": "#d9a838", "gold2": "#f0c95a", "gold3": "#ffe08a",
    "silber0": "#a9b2bd", "silber1": "#dfe6ee", "bronze0": "#9c5b2c", "bronze1": "#c97c45",
    "rosa0": "#d4508a", "rosa1": "#e66fa3", "rosa2": "#f293bf", "weiss": "#f2f4f7",
    "ringblau0": "#6fb6ec", "ringblau1": "#9ad0f5", "ringweiss": "#e6f4ff",
    "dach0": "#2f9466", "dach1": "#3fa977", "dach2": "#58bf8c", "dachkante": "#22724c",
    "dunkel": "#2f2a33", "licht0": "#f5b331", "licht1": "#ffe07a",
    "blau0": "#2d5fae", "blau1": "#3f78c9", "rot": "#c0392b", "edel_b": "#2e86de", "edel_r": "#e84393",
    "blatt0": "#3e9a35", "blatt1": "#5cbf45", "gelb": "#ffd84a", "lila": "#b892ff", "blume_r": "#ff7ab0",
    "pilz_r": "#d0242a", "pilz_s": "#efdcb4", "fass0": "#6b4224", "fass1": "#85552f", "band": "#3a3a40",
}
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "voxelladen_basis.py"), encoding="utf-8").read())

def blumenfeld(Z, x0, x1, y0, y1, z, dichte=0.45, seed=3):
    for x in range(x0, x1):
        for y in range(y0, y1):
            if (x, y, z) in Z or (x, y, z - 1) not in Z: continue
            r = hsh(x, y, seed)
            if r > 1 - dichte: Z[(x, y, z)] = "blatt"
            if r > 1 - dichte * 0.4: Z[(x, y, z + 1)] = ["bl_r", "bl_g", "bl_l", "weiss_b"][int(hsh(x, y, seed + 1) * 4)]

def pilzchen(Z, x, y, z):
    Z[(x, y, z)] = "pilz_s"; Z[(x, y, z + 1)] = "pilz_s"
    box(Z, x - 1, x + 2, y - 1, y + 2, z + 2, z + 3, "pilz_r"); Z[(x, y, z + 3)] = "pilz_r"

def baue_stab():
    Z = {}
    zyl(Z, 0, 0, 11, 0, 1, "gras")
    zyl(Z, 0, 0, 8, 1, 4, "stein")
    zyl(Z, 0, 0, 7, 4, 5, "stein_oben")
    blumenfeld(Z, -11, 12, -11, 12, 1, 0.5)
    for x, y in ((-9, -4), (8, 5), (6, -8)): pilzchen(Z, x, y, 1)
    # Pfoten-Schild vorne am Sockel
    box(Z, -3, 3, -9, -8, 1, 4, "holz")
    for x, z in ((-1, 2), (0, 2), (-1, 3), (0, 3), (-2, 4), (1, 4)):
        if z < 4: Z[(x, -10, z)] = "gold"
    # schraeger Stab (rosa/weiss gestreift), Goldkragen, Schleife mit Pfoten-Medaillon
    kapsel(Z, (0, 0, 4), (5, 0, 31), 1.9, "streifen")
    kapsel(Z, (4.6, 0, 29), (5.4, 0, 33), 2.6, "gold")
    for s in (-1, 1):
        kapsel(Z, (3.2, -1, 22), (3.2 + s * 4.5, -1.5, 24.5), 1.5, "schleife")
        kapsel(Z, (3.2, -1, 21), (3.2 + s * 2.5, -1.5, 17), 1.0, "schleife")
    for x in range(1, 6):
        for z in range(20, 25):
            if math.hypot(x + 0.5 - 3.4, z + 0.5 - 22.4) <= 2.2: Z[(x, -3, z)] = "medaillon"
    Z[(3, -4, 22)] = "pfote"; Z[(4, -4, 22)] = "pfote"; Z[(3, -4, 23)] = "pfote"
    # Ring (x/z-Ebene), Mitte (5.5, 0, 42), aus hellblauen Wuerfeln mit weissen Kacheln + Goldnieten
    cx, cz = 5.5, 42
    for x in range(-6, 18):
        for z in range(30, 55):
            d = math.hypot(x + 0.5 - cx, z + 0.5 - cz)
            if 7 <= d <= 10:
                for y in (-1, 0):
                    Z[(x, y, z)] = "ring"
    return Z

def baue_bestenliste():
    Z = {}
    box(Z, -17, 17, -8, 7, 0, 2, "stein")
    box(Z, -6, 6, -10, -8, 0, 1, "stein")
    for x0 in (-15, 11):
        box(Z, x0, x0 + 4, -2, 2, 2, 26, "pfosten")
        box(Z, x0, x0 + 4, -3, 3, 24, 26, "gold"); box(Z, x0, x0 + 4, -3, 3, 2, 4, "gold")
    box(Z, -11, 11, -1, 1, 5, 25, "rahmen")
    box(Z, -10, 10, -2, -1, 6, 24, "tafel")
    # Medaillen links (Gold, Silber, Bronze) mit Baendern
    for i, (mz, art) in enumerate(((20, "m_gold"), (15, "m_silber"), (10, "m_bronze"))):
        for x in range(-10, -6):
            for z in range(mz - 2, mz + 2):
                if math.hypot(x + 0.5 + 8, z + 0.5 - mz) <= 1.9: Z[(x, -3, z)] = art
        Z[(-9, -3, mz + 2)] = "band_b"; Z[(-8, -3, mz + 2)] = "band_r"
    # Dach (gruene Ziegel, Satteldach quer)
    for k, (y0, y1) in enumerate(((-6, 6), (-5, 5), (-4, 4), (-2, 2))):
        box(Z, -18 + k, 18 - k, y0, y1, 26 + k, 27 + k, "dach")
    # Laternen an Haltern aussen
    for s in (-1, 1):
        xh = 15 if s > 0 else -18
        box(Z, xh, xh + 3, -1, 1, 22, 23, "pfosten")
        xl = 17 if s > 0 else -20
        box(Z, xl, xl + 3, -1, 2, 20, 21, "laterne"); box(Z, xl, xl + 3, -1, 2, 17, 20, "licht"); box(Z, xl, xl + 3, -1, 2, 16, 17, "laterne")
        Z[(xl + 1, 0, 21)] = "laterne"
    # Fass mit Blumen links, Schatztruhe mit Muenzen rechts
    zyl(Z, -13, -5, 2.4, 2, 7, "fass")
    for x in range(-15, -10):
        for y in range(-7, -2):
            if math.hypot(x + 0.5 + 13, y + 0.5 + 5) <= 2.2:
                Z[(x, y, 7)] = "blatt"
                if hsh(x, y, 4) > 0.5: Z[(x, y, 8)] = ["bl_r", "bl_g", "bl_l"][int(hsh(x, y, 5) * 3)]
    box(Z, 8, 15, -8, -3, 2, 6, "truhe"); box(Z, 8, 15, -3, -2, 6, 10, "truhe")
    for x in (8, 11, 14): box(Z, x, x + 1, -9, -8, 2, 6, "gold")
    box(Z, 9, 14, -7, -3, 6, 7, "muenze")
    for x, y in ((6, -9), (7, -8), (16, -7), (6, -7)): Z[(x, y, 2)] = "muenze"
    # Banner mit Pfote auf der Rueckseite
    box(Z, -4, 4, 1, 2, 8, 22, "banner")
    for x, z in ((-1, 12), (0, 12), (-1, 13), (0, 13), (-2, 15), (1, 15), (-1, 16), (0, 16)):
        Z[(x, 2, z)] = "weiss_b"
    blumenfeld(Z, -17, 17, -8, 7, 2, 0.25, 7)
    return Z

def baue_krone():
    Z = {}
    for x in range(-6, 6):
        for y in range(-6, 6):
            d = math.hypot(x + 0.5, y + 0.5)
            if 4 <= d <= 5.6:
                for z in range(0, 3): Z[(x, y, z)] = "gold"
                ang = math.atan2(y + 0.5, x + 0.5)
                if (int((ang + math.pi) / (2 * math.pi) * 5 + 0.5) % 5 == 0) or abs(math.sin(ang * 5 / 2)) < 0.25:
                    for z in range(3, 6): Z[(x, y, z)] = "gold"
    # Edelsteine
    for (x, y, z, lab) in ((0, -6, 1, "edel_b"), (-4, -4, 1, "edel_r"), (3, -5, 1, "edel_r"), (-5, 1, 1, "edel_b"), (5, 1, 1, "edel_b")):
        Z[(x, y, z)] = lab
    return Z

def farbe(lab, k, n):
    x, y, z = k
    r = hsh(x, y, z, 1)
    u = y if abs(n[0]) > 0 else x
    if lab == "gras": return "gras1" if r > 0.4 else "gras0"
    if lab in ("stein", "stein_oben"):
        if lab == "stein" and n[2] == 0 and z % 3 == 0: return "steinf"
        return ["stein0", "stein1", "stein2"][int(hsh(u // 2, z // 2, 3) * 3)]
    if lab in ("holz", "pfosten"): return "holz0" if r > 0.4 else "holz1"
    if lab == "rahmen": return "holz2" if r > 0.3 else "holz1"
    if lab == "tafel": return "tafelf" if z % 3 == 0 else ("tafel1" if r > 0.5 else "tafel0")
    if lab == "streifen": return "rosa1" if ((z + 2 * x) // 3) % 2 == 0 else "weiss"
    if lab == "gold": return "gold3" if n[2] > 0 and r > 0.6 else ("gold2" if r > 0.5 else "gold1")
    if lab == "schleife": return "rosa2" if n[2] > 0 else ("rosa1" if r > 0.3 else "rosa0")
    if lab == "medaillon": return "gold2"
    if lab == "pfote": return "weiss"
    if lab == "ring":
        if (x + z) % 7 == 0: return "gold1"
        return "ringweiss" if ((x // 2) + (z // 2)) % 3 == 0 else ("ringblau1" if r > 0.4 else "ringblau0")
    if lab == "dach": return "dachkante" if n[2] < 0 else ["dach0", "dach1", "dach2"][((u // 2) + z) % 3]
    if lab == "laterne": return "dunkel"
    if lab == "licht": return "licht1" if r > 0.6 else "licht0"
    if lab == "m_gold": return "gold2" if r > 0.3 else "gold3"
    if lab == "m_silber": return "silber1" if r > 0.3 else "silber0"
    if lab == "m_bronze": return "bronze1" if r > 0.3 else "bronze0"
    if lab == "band_b": return "blau1"
    if lab == "band_r": return "rot"
    if lab == "fass": return "band" if z in (3, 5) else ("fass1" if (u // 2) % 2 else "fass0")
    if lab == "truhe": return "holz1" if z % 3 else "holz0"
    if lab == "muenze": return "gold3" if r > 0.5 else "gold2"
    if lab == "banner": return "blau1" if z % 4 else "blau0"
    if lab == "weiss_b": return "weiss"
    if lab == "blatt": return "blatt1" if r > 0.4 else "blatt0"
    if lab.startswith("bl_"): return {"bl_r": "blume_r", "bl_g": "gelb", "bl_l": "lila"}[lab]
    if lab == "pilz_r": return "pilz_r" if (x + y + z) % 3 else "weiss"
    if lab == "pilz_s": return "pilz_s"
    if lab in ("edel_b", "edel_r"): return lab
    return "weiss"

if __name__ == "__main__":
    for o in list(D.objects): D.objects.remove(o)
    mat = paletten_material()
    stab = mesh_aus("Blasenstab", baue_stab(), mat)
    tafel = mesh_aus("Bestenliste", baue_bestenliste(), mat); tafel.location = (30, 0, 0)
    krone = mesh_aus("Krone", baue_krone(), mat); krone.location = (30, 0, 17)
    fertig_machen([stab, tafel, krone], [((22, -46, 22), (15, 0, 12), "spawndeko_vorne.png"),
                                         ((40, 40, 22), (15, 0, 12), "spawndeko_hinten.png")])
