# Tier-Index-Laden (Sternwarte) fuer Bubble Safari. Vorlage: BubbleSafari/Konzepte/shop-tierindex.webp
# Teile: Laden_Haus (fest), Laden_Schild, Laden_Teleskop (dreht sich langsam).
# Das Blasen-Karussell mit Tieren baut Roblox (Map.lua) aus echten Blasen + TierModelle.
# Headless: blender -b --factory-startup --python voxelladen_index.py -- <ausgabeordner>
import os, math
NAME = "laden_index"
PAL = {
    "stein0": "#77736d", "stein1": "#8b8780", "stein2": "#9e9a92", "fuge": "#5a5752",
    "wand0": "#8f86a3", "wand1": "#a198b5", "wand2": "#b2aac4", "moertel": "#6c6480",
    "saeule0": "#bdb3a0", "saeule1": "#9d9381",
    "lila0": "#5a3592", "lila1": "#6f45ad", "lila2": "#8659c7", "lila3": "#9c74d8", "dachkante": "#43266f",
    "holz0": "#4a2c17", "holz1": "#633c20", "holz2": "#7b4c29", "holz3": "#935e34",
    "licht0": "#f5b331", "licht1": "#ffe07a", "dunkel": "#2f2a33",
    "gold0": "#b88a2a", "gold1": "#d9a838", "gold2": "#f0c95a", "linse": "#7fd6ff",
    "banner0": "#7a4bc0", "banner1": "#9a6be0", "weiss": "#f2f4f7",
    "blatt0": "#3e9a35", "blatt1": "#5cbf45", "rosa": "#e66fa3", "gelb": "#ffd84a", "blau": "#5aa6ec", "lila": "#b892ff",
    "buch0": "#c0392b", "buch1": "#2e86c1", "buch2": "#27ae60", "buch3": "#f39c12", "buch4": "#8e44ad",
    "rahmen": "#8b5cd6", "rahmen2": "#b38cf2",
}
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "voxelladen_basis.py"), encoding="utf-8").read())

def ziegel(u, z, farben, moertel, hoch=3, breit=5):
    if z % hoch == 0: return moertel
    if (u + (z // hoch) % 2 * 2) % breit == 0: return moertel
    return farben[int(hsh((u + (z // hoch) % 2 * 2) // breit, z // hoch, 5) * len(farben))]

def dach_r(z):  # Kuppel: Halbellipse ueber z 22..34
    t = (z - 21) / 13
    return 0 if t >= 1 else math.sqrt(1 - t * t)

def baue_haus():
    Z = {}
    box(Z, -17, 17, -9, 11, 0, 2, "stein")
    box(Z, -5, 5, -14, -9, 0, 1, "pfad")
    box(Z, -14, 14, -5, 9, 2, 22, "wand")
    for x0, y0 in ((-15, -6), (12, -6), (-15, 7), (12, 7)):
        box(Z, x0, x0 + 3, y0, y0 + 3, 2, 22, "saeule")
    box(Z, -15, 15, -6, 10, 21, 22, "saeule")  # Gesims
    # Kuppel (lila Ziegel) mit Dachfenster vorne
    for z in range(22, 35):
        f = dach_r(z)
        rx, ry = 15.5 * f, 8.5 * f
        for x in range(-16, 16):
            for y in range(-7, 12):
                if ((x + 0.5) / max(rx, 0.1)) ** 2 + ((y + 0.5 - 2) / max(ry, 0.1)) ** 2 <= 1:
                    Z[(x, y, z)] = "dach"
    box(Z, -3, 3, -6, -3, 26, 31, "wand"); box(Z, -2, 2, -7, -6, 27, 30, "fenster"); box(Z, -4, 4, -7, -2, 31, 32, "dachkante")
    # Teleskop-Sockel oben
    zyl(Z, 0, 2, 2.2, 34, 36, "gold")
    # Tuer mit Bogen (links von der Mitte) und Ring
    box(Z, -9, -2, -6, -5, 2, 13, "tuerrahmen")
    box(Z, -8, -3, -6, -5, 2, 12, "tuer")
    box(Z, -8, -3, -6, -5, 12, 13, "tuerrahmen"); box(Z, -7, -4, -6, -5, 13, 14, "tuerrahmen")
    Z[(-4, -7, 7)] = "gold"
    # rundes Pfoten-Fenster rechts
    scheibe_xz(Z, 6.5, -6, 12.5, 4.2, "fensterrahmen", 3.2)
    scheibe_xz(Z, 6.5, -5, 12.5, 3.2, "fenster")
    for x, z in ((6, 11), (7, 11), (6, 12), (7, 12), (6, 10), (7, 10), (4, 14), (9, 14), (5, 15), (8, 15)):
        Z[(x, -5, z)] = "pfote"
    # Banner mit Pfote
    for x0 in (-13, 11):
        box(Z, x0, x0 + 2, -7, -6, 9, 19, "banner")
        Z[(x0, -8, 14)] = "pfote_w"; Z[(x0 + 1, -8, 14)] = "pfote_w"; Z[(x0, -8, 15)] = "pfote_w"; Z[(x0 + 1, -8, 13)] = "pfote_w"
    # Buecherregal links vorne
    box(Z, -21, -15, -8, -5, 2, 13, "holz")
    for zr in (3, 7):
        for x in range(-20, -16):
            box(Z, x, x + 1, -8, -7, zr, zr + 3, "buch")
    box(Z, -20, -16, -8, -7, 11, 12, "buch")
    # Laternen
    for x0 in (-16, 13):
        box(Z, x0, x0 + 3, -9, -6, 15, 16, "laterne"); box(Z, x0, x0 + 3, -9, -6, 16, 18, "licht"); box(Z, x0, x0 + 3, -9, -6, 18, 19, "laterne")
    # Blumen + Ranken
    for x in range(-16, 16):
        for y in (-9, -8):
            if -6 <= x <= 5: continue
            r = hsh(x, y, 3)
            if r > 0.45: Z[(x, y, 2)] = "blatt"
            if r > 0.75: Z[(x, y, 3)] = ["bl_rosa", "bl_gelb", "bl_lila", "bl_blau"][int(hsh(x, y, 4) * 4)]
    for x0 in (-15, 12):
        for z in range(4, 21):
            for x in range(x0, x0 + 3):
                if hsh(x, z, 7) > 0.75: Z[(x, -7, z)] = "blatt"
    # Treppe vor der Tuer
    box(Z, -9, -2, -8, -6, 2, 3, "stein")
    return Z

def baue_schild():
    Z = {}
    box(Z, -11, 11, -8, -7, 23, 30, "rahmen")
    box(Z, -10, 10, -9, -8, 24, 29, "schild")
    box(Z, -11, 11, -9, -8, 23, 24, "rahmen"); box(Z, -11, 11, -9, -8, 29, 30, "rahmen")
    box(Z, -11, -10, -9, -8, 23, 30, "rahmen"); box(Z, 10, 11, -9, -8, 23, 30, "rahmen")
    return Z

def baue_teleskop():
    Z = {}
    zyl(Z, 0, 2, 1.2, 36, 39, "gold_dunkel")
    kapsel(Z, (-2, 4, 38), (7, -3, 44), 1.7, "messing")
    kapsel(Z, (6, -2, 43), (8, -4, 45), 2.1, "gold")
    kapsel(Z, (7.6, -3.6, 44.6), (8.4, -4.4, 45.4), 1.6, "linse")
    return Z

def farbe(lab, k, n):
    x, y, z = k
    r = hsh(x, y, z, 1)
    u = y if abs(n[0]) > 0 else x
    if lab in ("stein", "pfad"):
        if lab == "stein" and n[2] == 0 and (z + u // 3) % 4 == 0: return "fuge"
        return ["stein0", "stein1", "stein2"][int(hsh(u // 2, z // 2, 3) * 3)]
    if lab == "wand": return "wand1" if n[2] != 0 else ziegel(u, z, ["wand0", "wand1", "wand2"], "moertel")
    if lab == "saeule": return "saeule1" if z % 4 == 0 or r < 0.2 else "saeule0"
    if lab == "dach":
        if n[2] < 0: return "dachkante"
        return ["lila0", "lila1", "lila2", "lila3"][((u // 2) + z) % 4 if r > 0.1 else 3]
    if lab == "dachkante": return "dachkante"
    if lab in ("tuer", "holz"): return ["holz1", "holz2"][(u // 2) % 2]
    if lab == "tuerrahmen": return "holz0"
    if lab == "fenster": return "licht1" if (x + z) % 3 == 0 else "licht0"
    if lab == "fensterrahmen": return "gold1" if r > 0.3 else "gold0"
    if lab == "pfote": return "gold0"
    if lab == "pfote_w": return "weiss"
    if lab == "banner": return "banner1" if r > 0.4 else "banner0"
    if lab == "buch": return ["buch0", "buch1", "buch2", "buch3", "buch4"][int(hsh(x, 0, 0, 2) * 5)]
    if lab == "laterne": return "dunkel"
    if lab == "licht": return "licht0"
    if lab == "blatt": return "blatt1" if r > 0.4 else "blatt0"
    if lab.startswith("bl_"): return {"bl_rosa": "rosa", "bl_gelb": "gelb", "bl_lila": "lila", "bl_blau": "blau"}[lab]
    if lab == "gold": return "gold2" if n[2] > 0 else ("gold1" if r > 0.3 else "gold0")
    if lab == "gold_dunkel": return "gold0"
    if lab == "messing": return "gold1" if r > 0.4 else "gold0"
    if lab == "linse": return "linse"
    if lab == "schild": return "holz2" if (z // 2) % 2 else "holz1"
    if lab == "rahmen": return "rahmen" if r > 0.3 else "rahmen2"
    return "weiss"

if __name__ == "__main__":
    for o in list(D.objects): D.objects.remove(o)
    mat = paletten_material()
    teile = [mesh_aus("Laden_Haus", baue_haus(), mat), mesh_aus("Laden_Schild", baue_schild(), mat),
             mesh_aus("Laden_Teleskop", baue_teleskop(), mat)]
    fertig_machen(teile, [((22, -40, 24), (0, 0, 12), "index_schraeg.png"), ((0, -46, 16), (0, 0, 13), "index_vorne.png"),
                          ((-30, 34, 24), (0, 2, 12), "index_hinten.png")])
