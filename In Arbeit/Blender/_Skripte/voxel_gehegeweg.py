# Weg-Deko zu den Gehegen (Vorlage: BubbleSafari/Konzepte/weg-gehege.webp)
# Eine FBX mit: Torbogen (Holzbogen mit Ranken, Blumen, Pfoten-Medaillon, leerem Schild, Laternen),
# Wegweiser (Pfosten mit zwei Pfeilen), Bank, Trog (Holztrog mit Wasser). Front jeweils -Y.
# Headless: blender -b --factory-startup --python voxel_gehegeweg.py -- <ausgabeordner>
import os, math
NAME = "gehegeweg"
PAL = {
    "stein0": "#9e9a92", "stein1": "#b3aea4", "stein2": "#c7c1b5", "steinf": "#77736d",
    "holz0": "#4a2c17", "holz1": "#633c20", "holz2": "#7b4c29", "holz3": "#935e34",
    "schild0": "#8a5a33", "schild1": "#a06a3d", "rahmen": "#4a2c17",
    "blatt0": "#2f8f2a", "blatt1": "#3fa832", "blatt2": "#5cbf45",
    "rosa": "#ff7ab0", "gelb": "#ffd84a", "lila": "#b892ff", "weiss": "#f2f4f7", "blau_b": "#6ab4ff",
    "gold0": "#b88a2a", "gold1": "#d9a838", "gold2": "#f0c95a", "pfote": "#7b4c29",
    "dunkel": "#2f2a33", "dach0": "#4a3a33", "licht0": "#f5b331", "licht1": "#ffe07a",
    "wasser0": "#3f9fe0", "wasser1": "#6ec0f2", "pfeil0": "#9c6234", "pfeil1": "#b87a44",
}
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "voxelladen_basis.py"), encoding="utf-8").read())

def ranken(Z, punkte, seed=1):
    for (x, y, z) in punkte:
        r = hsh(x, y, z, seed)
        if r > 0.35: Z.setdefault((x, y, z), "blatt")
        if r > 0.82: Z[(x, y, z)] = ["bl_r", "bl_g", "bl_l", "bl_w"][int(hsh(x, y, z, seed + 1) * 4)]

def laterne_haengend(Z, x0, y0, z0):
    box(Z, x0, x0 + 3, y0, y0 + 3, z0, z0 + 1, "laterne"); box(Z, x0, x0 + 3, y0, y0 + 3, z0 + 1, z0 + 4, "licht")
    box(Z, x0, x0 + 3, y0, y0 + 3, z0 + 4, z0 + 5, "laterne"); Z[(x0 + 1, y0 + 1, z0 + 5)] = "laterne"

def baue_torbogen():
    Z = {}
    # Steinsockel + Pfosten (innen 16 Voxel = 8 Studs breit)
    for x0 in (-12, 8):
        box(Z, x0, x0 + 4, -2, 2, 0, 3, "stein")
        box(Z, x0 + 1, x0 + 3, -1, 1, 3, 20, "holz")
    # Bogen: Balken oben + leichte Rundung
    box(Z, -13, 13, -2, 2, 20, 22, "holz")
    for x in range(-10, 10):
        h = int(2.2 * math.cos((x + 0.5) / 10 * math.pi / 2))
        box(Z, x, x + 1, -1, 1, 20 - h, 20, "holz")
    box(Z, -11, 11, -2, 2, 22, 23, "holz_dunkel")
    # leeres Schild unter dem Balken (Name kommt in Roblox), Rahmen
    box(Z, -8, 8, -3, -2, 14, 19, "rahmen"); box(Z, -7, 7, -4, -3, 15, 18, "schild")
    for x in (-8, 7): box(Z, x, x + 1, -4, -3, 14, 19, "rahmen")
    box(Z, -8, 8, -4, -3, 14, 15, "rahmen"); box(Z, -8, 8, -4, -3, 18, 19, "rahmen")
    # Pfoten-Medaillon oben
    for x in range(-3, 3):
        for z in range(22, 29):
            if math.hypot(x + 0.5, z + 0.5 - 25.5) <= 3: Z[(x, -3, z)] = "medaillon"
    for (x, z) in ((-1, 24), (0, 24), (-1, 25), (0, 25), (-2, 26), (1, 26), (-1, 27), (0, 27)):
        Z[(x, -4, z)] = "pfote"
    # Ranken + Blumen ueber dem Bogen und an den Pfosten
    pts = []
    for x in range(-14, 14):
        for y in (-3, 2):
            for z in (22, 23, 24):
                if abs(x) > 3 or z < 22: pts.append((x, y, z))
    for x in range(-14, 14):
        for y in range(-2, 2): pts.append((x, y, 23))
    for x0 in (-12, 8):
        for z in range(4, 20):
            pts += [(x0, -2, z), (x0 + 3, -2, z), (x0, 1, z)]
    ranken(Z, pts)
    # Laternen haengen aussen an den Pfosten
    box(Z, -15, -12, -1, 1, 17, 18, "holz"); laterne_haengend(Z, -16, -2, 12)
    box(Z, 11, 14, -1, 1, 17, 18, "holz"); laterne_haengend(Z, 13, -2, 12)
    # Blumen am Fuss
    for x in list(range(-15, -11)) + list(range(11, 15)):
        for y in range(-4, 3):
            if (x, y, 0) in Z: continue
            r = hsh(x, y, 9)
            if r > 0.45: Z[(x, y, 0)] = "blatt"
            if r > 0.8: Z[(x, y, 1)] = ["bl_r", "bl_g", "bl_l", "bl_b"][int(hsh(x, y, 8) * 4)]
    return Z

def baue_wegweiser():
    Z = {}
    box(Z, -2, 2, -2, 2, 0, 2, "stein")
    box(Z, -1, 1, -1, 1, 2, 16, "holz")
    box(Z, -1, 1, -1, 1, 16, 17, "holz_dunkel")
    # Pfeil nach rechts (oben) und links (unten), Brett mit Spitze
    for (z0, rich) in ((12, 1), (7, -1)):
        x_start, x_end = (1, 9) if rich > 0 else (-9, -1)
        box(Z, x_start, x_end, -2, -1, z0, z0 + 3, "pfeil")
        spitze = x_end if rich > 0 else x_start - 1
        for dz in range(3): Z[(spitze, -2, z0 + dz)] = "pfeil"
        Z[(spitze + rich, -2, z0 + 1)] = "pfeil"
        for x in range(min(x_start, x_end) + 2, max(x_start, x_end) - 1):
            Z[(x, -3, z0 + 1)] = "pfeil_hell"
    for x in range(-3, 3):
        for y in range(-3, 3):
            if (x, y, 0) not in Z and hsh(x, y, 3) > 0.4: Z[(x, y, 0)] = "blatt"
    return Z

def baue_bank():
    Z = {}
    for x0 in (-7, 5):
        box(Z, x0, x0 + 2, -2, 2, 0, 4, "holz_dunkel")
        box(Z, x0, x0 + 2, 1, 2, 4, 8, "holz_dunkel")
    box(Z, -8, 8, -2, 2, 4, 5, "planke")
    for z in (6, 7): box(Z, -8, 8, 1, 2, z, z + 1, "planke") if z == 6 else None
    box(Z, -8, 8, 1, 2, 7, 8, "planke")
    return Z

def baue_trog():
    Z = {}
    box(Z, -6, 6, -3, 3, 0, 1, "holz_dunkel")
    box(Z, -6, 6, -3, 3, 1, 4, "holz")
    box(Z, -5, 5, -2, 2, 2, 4, "wasser")
    for x in (-6, 5): box(Z, x, x + 1, -3, 3, 0, 4, "holz_dunkel")
    for x in range(-7, 7):
        for y in (-4, 3):
            if hsh(x, y, 5) > 0.6: Z[(x, y, 0)] = "blatt"
    return Z

def farbe(lab, k, n):
    x, y, z = k
    r = hsh(x, y, z, 1)
    u = y if abs(n[0]) > 0 else x
    if lab == "stein": return "steinf" if z % 3 == 0 and n[2] == 0 else ["stein0", "stein1", "stein2"][int(hsh(u // 2, z // 2, 3) * 3)]
    if lab == "holz": return "holz2" if (z // 2 + u) % 3 else "holz1"
    if lab == "holz_dunkel": return "holz0" if r > 0.3 else "holz1"
    if lab == "planke": return "holz3" if (u // 3) % 2 else "holz2"
    if lab == "rahmen": return "rahmen"
    if lab == "schild": return "schild1" if (z % 2) else "schild0"
    if lab == "medaillon": return "gold2" if r > 0.4 else "gold1"
    if lab == "pfote": return "pfote"
    if lab == "blatt": return ["blatt0", "blatt1", "blatt2"][int(r * 3)]
    if lab.startswith("bl_"): return {"bl_r": "rosa", "bl_g": "gelb", "bl_l": "lila", "bl_w": "weiss", "bl_b": "blau_b"}[lab]
    if lab == "laterne": return "dunkel"
    if lab == "licht": return "licht1" if r > 0.6 else "licht0"
    if lab == "pfeil": return "pfeil1" if r > 0.3 else "pfeil0"
    if lab == "pfeil_hell": return "gold2"
    if lab == "wasser": return "wasser1" if n[2] > 0 and r > 0.6 else "wasser0"
    return "weiss"

if __name__ == "__main__":
    for o in list(D.objects): D.objects.remove(o)
    mat = paletten_material()
    teile = [mesh_aus("Torbogen", baue_torbogen(), mat), mesh_aus("Wegweiser", baue_wegweiser(), mat),
             mesh_aus("Bank", baue_bank(), mat), mesh_aus("Trog", baue_trog(), mat)]
    for o, x in zip(teile[1:], (14, 22, 30)): o.location = (x, 0, 0)
    fertig_machen(teile, [((14, -34, 14), (12, 0, 6), "gehegeweg_vorne.png")])
