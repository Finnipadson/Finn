# Verkaufen-Laden (Marktstand mit Waage) fuer Bubble Safari. Vorlage: BubbleSafari/Konzepte/shop-verkaufen.webp
# Teile: Laden_Haus (fest), Laden_Schild, Laden_Balken (Waagebalken, kippt), Laden_SchaleL / Laden_SchaleR
# (Waagschalen mit Ketten, gehen hoch/runter; rechts mit Muenzen), Laden_Glocke (schwingt).
# Die Seifenblase in der linken Schale + springende Muenzen macht Roblox.
# Headless: blender -b --factory-startup --python voxelladen_verkauf.py -- <ausgabeordner>
import os, math
NAME = "laden_verkauf"
PAL = {
    "stein0": "#77736d", "stein1": "#8b8780", "stein2": "#9e9a92", "fuge": "#5a5752",
    "ziegel0": "#8c4a2c", "ziegel1": "#a0573a", "ziegel2": "#7a3f25", "moertel": "#5c3a28",
    "holz0": "#4a2c17", "holz1": "#633c20", "holz2": "#7b4c29", "holz3": "#935e34",
    "rot0": "#b0262b", "rot1": "#d23a3a", "weiss": "#f2f4f7", "dachrot0": "#9c2f2a", "dachrot1": "#b83e33", "dachkante": "#6e1f1c",
    "gold0": "#b88a2a", "gold1": "#d9a838", "gold2": "#f0c95a", "gold3": "#ffe08a",
    "sack0": "#d9c49a", "sack1": "#c2ab7f", "pfote": "#7b4c29",
    "licht0": "#f5b331", "licht1": "#ffe07a", "dunkel": "#2f2a33",
    "blatt0": "#3e9a35", "blatt1": "#5cbf45", "rosa": "#e66fa3", "gelb": "#ffd84a", "lila": "#b892ff",
    "fahne_g": "#4fbf3a", "rahmen": "#d9a838", "rahmen2": "#f0c95a",
}
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "voxelladen_basis.py"), encoding="utf-8").read())

def ziegel(u, z, farben, moertel, hoch=3, breit=5):
    if z % hoch == 0: return moertel
    if (u + (z // hoch) % 2 * 2) % breit == 0: return moertel
    return farben[int(hsh((u + (z // hoch) % 2 * 2) // breit, z // hoch, 5) * len(farben))]

def dach_z(y):  # flaches Satteldach ueber dem Hinterhaus, First bei y=5
    return int(20 + (8 - abs(y - 5)) * 0.6)

def baue_haus():
    Z = {}
    box(Z, -17, 17, -10, 12, 0, 2, "stein")
    box(Z, -5, 5, -14, -10, 0, 1, "pfad")
    # Hinterhaus (Ziegel) + Rueckwand des Standes
    box(Z, -14, 14, 0, 10, 2, 20, "wand")
    for x0, y0 in ((-15, -1), (12, -1), (-15, 8), (12, 8)):
        box(Z, x0, x0 + 3, y0, y0 + 3, 2, 20, "holzbalken")
    for y in range(-3, 14):
        zt = dach_z(y)
        for x in range(-16, 16):
            for z in range(zt - 1, zt + 1):
                Z[(x, y, z)] = "dachkante" if y in (-3, 13) or x in (-16, 15) else "dach"
        if 0 <= y < 10: box(Z, -14, 14, y, y + 1, 20, zt - 1, "wand")
    # Theke + Seitenwangen des Standes
    box(Z, -12, 12, -8, -4, 2, 8, "theke")
    box(Z, -13, 13, -9, -3, 8, 9, "holz_hell")
    # Muenzsaecke mit Pfote + Muenzstapel auf der Theke
    for x0 in (-10, -5):
        box(Z, x0, x0 + 4, -7, -4, 9, 13, "sack"); box(Z, x0 + 1, x0 + 3, -6, -5, 13, 14, "sack")
        Z[(x0 + 1, -8, 11)] = "pfote"; Z[(x0 + 2, -8, 11)] = "pfote"; Z[(x0 + 1, -8, 10)] = "pfote"
    for i, x in enumerate((1, 4, 7)):
        zyl(Z, x + 0.5, -6, 1.3, 9, 10 + i % 3 + 1, "muenze")
    # Pfosten, Markise (rot/weiss, schraeg), Wimpel, Laternen
    for x in (-13, 12):
        box(Z, x, x + 1, -10, -9, 2, 17, "holzbalken")
    for y in range(-11, 0):
        zz = 18 - (-y) // 3
        box(Z, -14, 14, y, y + 1, zz, zz + 1, "markise")
    for x in range(-14, 14, 2): Z[(x, -11, 14)] = "markise"
    for x in range(-11, 11):
        if (x // 2) % 2 == 0: Z[(x, -9, 13 - (x % 2))] = "wimpel"
    for x0 in (-16, 13):
        box(Z, x0, x0 + 3, -11, -8, 12, 13, "laterne"); box(Z, x0, x0 + 3, -11, -8, 13, 15, "licht"); box(Z, x0, x0 + 3, -11, -8, 15, 16, "laterne")
    # Glockenhalter unter der Markise
    box(Z, -1, 1, -6, -5, 15, 17, "gold")
    # Schatztruhe rechts (offen, voller Muenzen)
    box(Z, 13, 20, -9, -4, 2, 6, "truhe")
    for x in (13, 16, 19): box(Z, x, x + 1, -10, -9, 2, 6, "gold")
    box(Z, 14, 19, -8, -5, 6, 7, "muenze")
    for x in range(14, 19):
        for y in range(-8, -5):
            if hsh(x, y, 2) > 0.4: Z[(x, y, 7)] = "muenze"
    box(Z, 13, 20, -4, -3, 6, 11, "truhe")  # aufgeklappter Deckel
    # Kisten mit Pfote links
    box(Z, -21, -15, -9, -4, 2, 7, "kiste"); box(Z, -20, -16, -10, -9, 3, 6, "kiste")
    Z[(-19, -11, 4)] = "pfote"; Z[(-18, -11, 4)] = "pfote"; Z[(-19, -11, 5)] = "pfote"
    box(Z, -20, -16, -8, -5, 7, 10, "kiste")
    # rotes Banner mit Pfote an den Seiten
    for x0 in (-15, 14):
        box(Z, x0, x0 + 1, 2, 6, 8, 17, "banner")
    # Blumen und Ranken
    for x in range(-16, 16):
        for y in (-10, -9):
            if -6 <= x <= 5 or x >= 12: continue
            r = hsh(x, y, 3)
            if r > 0.5: Z[(x, y, 2)] = "blatt"
            if r > 0.8: Z[(x, y, 3)] = ["bl_rosa", "bl_gelb", "bl_lila"][int(hsh(x, y, 4) * 3)]
    for x in range(-16, 16):
        if hsh(x, 1, 7) > 0.55: Z[(x, -4, dach_z(-4) - 0)] = "blatt"
    # Waagen-Saeule auf dem Dach
    box(Z, -1, 1, 4, 6, 24, 33, "gold"); box(Z, -2, 2, 3, 7, 24, 25, "gold")
    return Z

def baue_schild():
    Z = {}
    box(Z, -10, 10, -5, -4, 20, 27, "rahmen")
    box(Z, -9, 9, -6, -5, 21, 26, "schild")
    box(Z, -10, 10, -6, -5, 20, 21, "rahmen"); box(Z, -10, 10, -6, -5, 26, 27, "rahmen")
    box(Z, -10, -9, -6, -5, 20, 27, "rahmen"); box(Z, 9, 10, -6, -5, 20, 27, "rahmen")
    return Z

def baue_balken():
    Z = {}
    box(Z, -12, 12, 4, 6, 33, 34, "gold")
    box(Z, -1, 1, 3, 7, 32, 35, "gold")
    for x in (-12, 11): box(Z, x, x + 1, 4, 6, 32, 34, "gold")
    return Z

def baue_schale(cx, muenzen):
    Z = {}
    for z in range(26, 32): Z[(cx, 5, z)] = "kette"
    zyl(Z, cx + 0.5, 5.5, 3.2, 24, 25, "gold")
    zyl(Z, cx + 0.5, 5.5, 3.6, 25, 26, "gold")
    weg(Z, cx - 2, cx + 3, 3, 8, 25, 26)
    zyl(Z, cx + 0.5, 5.5, 2.6, 25, 26, "gold")
    if muenzen:
        zyl(Z, cx + 0.5, 5.5, 2.4, 26, 27, "muenze"); zyl(Z, cx + 0.5, 5.5, 1.6, 27, 28, "muenze"); zyl(Z, cx + 0.5, 5.5, 0.8, 28, 29, "muenze")
    return Z

def baue_glocke():
    Z = {}
    for z in range(10, 15):
        r = 0.7 + (15 - z) * 0.3
        zyl(Z, 0, -5.5, r, z, z + 1, "gold")
    Z[(0, -6, 9)] = "gold"
    return Z

def farbe(lab, k, n):
    x, y, z = k
    r = hsh(x, y, z, 1)
    u = y if abs(n[0]) > 0 else x
    if lab in ("stein", "pfad"):
        if lab == "stein" and n[2] == 0 and (z + u // 3) % 4 == 0: return "fuge"
        return ["stein0", "stein1", "stein2"][int(hsh(u // 2, z // 2, 3) * 3)]
    if lab == "wand": return "ziegel1" if n[2] != 0 else ziegel(u, z, ["ziegel0", "ziegel1", "ziegel2"], "moertel")
    if lab == "dach":
        if n[2] < 0: return "dachkante"
        return ["dachrot0", "dachrot1"][((u // 2) + z) % 2]
    if lab == "dachkante": return "dachkante"
    if lab == "holzbalken": return "holz0" if r > 0.3 else "holz1"
    if lab in ("theke", "kiste", "truhe"): return ["holz1", "holz2"][(u // 2) % 2] if lab != "truhe" else ("holz1" if z % 3 else "holz0")
    if lab == "holz_hell": return "holz3" if r > 0.3 else "holz2"
    if lab == "sack": return "sack0" if r > 0.3 else "sack1"
    if lab == "pfote": return "pfote"
    if lab == "muenze": return "gold3" if n[2] > 0 and r > 0.5 else ("gold2" if r > 0.3 else "gold1")
    if lab == "gold": return "gold2" if n[2] > 0 else ("gold1" if r > 0.3 else "gold0")
    if lab == "kette": return "gold0"
    if lab == "markise": return "rot1" if (x // 2) % 2 == 0 else "weiss"
    if lab == "wimpel": return ["rot1", "weiss", "fahne_g"][(x // 2) % 3]
    if lab == "laterne": return "dunkel"
    if lab == "licht": return "licht0"
    if lab == "banner": return "rot0" if (z % 4) else "rot1"
    if lab == "blatt": return "blatt1" if r > 0.4 else "blatt0"
    if lab.startswith("bl_"): return {"bl_rosa": "rosa", "bl_gelb": "gelb", "bl_lila": "lila"}[lab]
    if lab == "schild": return "holz2" if (z // 2) % 2 else "holz1"
    if lab == "rahmen": return "rahmen" if r > 0.3 else "rahmen2"
    return "weiss"

if __name__ == "__main__":
    for o in list(D.objects): D.objects.remove(o)
    mat = paletten_material()
    teile = [mesh_aus("Laden_Haus", baue_haus(), mat), mesh_aus("Laden_Schild", baue_schild(), mat),
             mesh_aus("Laden_Balken", baue_balken(), mat), mesh_aus("Laden_SchaleL", baue_schale(-12, False), mat),
             mesh_aus("Laden_SchaleR", baue_schale(11, True), mat), mesh_aus("Laden_Glocke", baue_glocke(), mat)]
    fertig_machen(teile, [((22, -40, 22), (0, 0, 11), "verkauf_schraeg.png"), ((0, -46, 14), (0, 0, 12), "verkauf_vorne.png"),
                          ((-30, 34, 22), (0, 2, 11), "verkauf_hinten.png")])
