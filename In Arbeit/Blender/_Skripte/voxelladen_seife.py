# Seifenladen fuer Bubble Safari (Vorlage: BubbleSafari/Konzepte/shop-seifenladen.webp).
# Voxel-Bau (0,5-Stud-Wuerfel, 1 Einheit = 1 Stud), mehrere Objekte in EINER FBX, damit Roblox die Lage behaelt:
#   Laden_Haus (fest), Laden_Schild (Holzschild, Text kommt in Roblox als SurfaceGui),
#   Laden_Flasche (rosa Seifenflasche auf dem Dach), Laden_Pumpe (bewegt sich auf/ab), Laden_Seife (dreht sich)
# Farben ueber Paletten-Textur 8x8 (vor dem Upload auf 256 px hochskalieren!), gleiche Flaechen werden zusammengefasst.
# Headless: blender -b --factory-startup --python voxelladen_seife.py -- <ausgabeordner>
import bpy, bmesh, math, sys, os
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else r"C:\Users\finns\OneDrive\Desktop\Claude\Games\In Arbeit\Blender\VoxelBaum"
V = 0.5
D = bpy.data
os.makedirs(os.path.join(OUT, "Renders"), exist_ok=True)

def srgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
def lin(h):
    return tuple((c / 12.92) if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb(h))

PAL = {
    "stein0": "#77736d", "stein1": "#8b8780", "stein2": "#9e9a92", "fuge": "#5a5752",
    "blau0": "#3a6fb8", "blau1": "#4a82c9", "blau2": "#5d93d6", "moertel": "#b9c9dc",
    "saeule0": "#b7ad9a", "saeule1": "#9d9381",
    "holz0": "#4a2c17", "holz1": "#633c20", "holz2": "#7b4c29", "holz3": "#935e34",
    "licht0": "#f5b331", "licht1": "#ffe07a",
    "weiss": "#f2f4f7", "hellgrau": "#c9d0d9", "markblau": "#3d7fe0",
    "dach0": "#2f9466", "dach1": "#3fa977", "dach2": "#58bf8c", "dachkante": "#22724c",
    "ziegel0": "#a9452f", "ziegel1": "#c45a3d",
    "dunkel": "#3a2f2a", "blatt0": "#3e9a35", "blatt1": "#5cbf45",
    "rosa0": "#d4508a", "rosa1": "#e66fa3", "rosa2": "#f293bf",
    "etikett": "#8fd0f2", "etikett2": "#c9ecff",
    "gelb": "#ffd84a", "mint": "#7ee6c0", "lila": "#b892ff", "orange": "#ff9a3c",
    "rahmen": "#3fa6e6", "rahmen2": "#6cc0f2",
}
NAMEN = list(PAL.keys()); IDX = {n: i for i, n in enumerate(NAMEN)}; N_PIX = 8

def hsh(x, y, z, s=0):
    n = math.sin(x * 12.9898 + y * 78.233 + z * 37.719 + s * 4.581) * 43758.5453
    return n - math.floor(n)

# ---------------------------------------------------------------- Bau-Helfer (Voxel-Indizes, halboffen)
def box(Z, x0, x1, y0, y1, z0, z1, lab):
    for x in range(x0, x1):
        for y in range(y0, y1):
            for z in range(z0, z1): Z[(x, y, z)] = lab
def weg(Z, x0, x1, y0, y1, z0, z1):
    for x in range(x0, x1):
        for y in range(y0, y1):
            for z in range(z0, z1): Z.pop((x, y, z), None)
def zyl(Z, cx, cy, r, z0, z1, lab):
    for x in range(int(cx - r) - 1, int(cx + r) + 2):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                for z in range(z0, z1): Z[(x, y, z)] = lab

def dach_z(y):  # Oberkante Satteldach (First bei y=3)
    return int(24 + (10 - abs(y - 3)) * 0.8)

def baue_haus():
    Z = {}
    box(Z, -18, 18, -8, 12, 0, 2, "stein")                     # Sockel
    box(Z, -6, 6, -14, -8, 0, 1, "pfad")                       # Steinweg vorne
    box(Z, -16, 16, -4, 10, 2, 24, "wand")                     # Hauskoerper
    # Laden-Nische mit Regalen
    weg(Z, -1, 13, -4, -1, 7, 19)
    box(Z, -1, 13, -1, 0, 7, 19, "holz_innen")
    for zr in (11, 15):
        box(Z, -1, 13, -3, -1, zr, zr + 1, "holz_hell")
        for i, x in enumerate(range(0, 13, 2)):
            fl = ["b_rosa", "b_gelb", "b_mint", "b_lila"][(i + zr) % 4]
            box(Z, x, x + 1, -3, -2, zr + 1, zr + 3 if i % 2 else zr + 2, fl)
    # Saeulen
    for x0 in (-17, -4, 13):
        box(Z, x0, x0 + 4 if x0 != -4 else x0 + 3, -5, -2, 2, 24, "saeule")
    for x0 in (-17, 13):
        box(Z, x0, x0 + 4, 8, 11, 2, 24, "saeule")
    # Fenster vorne links, Seite, hinten
    box(Z, -13, -6, -5, -4, 9, 18, "holz_dunkel"); box(Z, -12, -7, -5, -4, 10, 17, "fenster")
    box(Z, -10, -9, -5, -4, 10, 17, "holz_dunkel"); box(Z, -12, -7, -5, -4, 13, 14, "holz_dunkel")
    box(Z, -17, -16, 0, 7, 9, 18, "holz_dunkel"); box(Z, -17, -16, 1, 6, 10, 17, "fenster")
    box(Z, -17, -16, 3, 4, 10, 17, "holz_dunkel")
    box(Z, -7, 1, 10, 11, 9, 18, "holz_dunkel"); box(Z, -6, 0, 10, 11, 10, 17, "fenster")
    box(Z, -4, -3, 10, 11, 10, 17, "holz_dunkel")
    box(Z, 3, 11, 10, 11, 9, 18, "holz_dunkel"); box(Z, 4, 10, 10, 11, 10, 17, "fenster")
    # Blumenkasten unter dem Fenster
    box(Z, -14, -5, -7, -5, 7, 9, "holz")
    for x in range(-14, -5):
        for y in (-7, -6):
            r = hsh(x, y, 3)
            if r > 0.35: Z[(x, y, 9)] = "blatt"
            if r > 0.7: Z[(x, y, 10)] = ["bl_rosa", "bl_gelb", "bl_lila", "bl_weiss"][int(hsh(x, y, 4) * 4)]
    # Theke mit Seifen
    box(Z, -2, 13, -9, -5, 2, 8, "theke")
    box(Z, -3, 14, -10, -4, 8, 9, "holz_hell")
    for i, x in enumerate(range(-1, 12, 3)):
        box(Z, x, x + 2, -8, -7, 9, 10, ["b_rosa", "b_gelb", "b_mint", "b_lila", "b_rosa"][i])
        if i % 2 == 0: box(Z, x, x + 2, -8, -7, 10, 11, ["b_mint", "b_lila", "b_gelb"][i // 2 % 3])
    # Markise (schraeg, blau-weiss gestreift, gewellte Vorderkante)
    for y in range(-11, -3):
        zz = 19 - (-4 - y) // 2
        box(Z, -3, 15, y, y + 1, zz, zz + 1, "markise")
    for x in range(-3, 15, 2):
        Z[(x, -11, 15)] = "markise"
    # Pfosten + Laternen
    for x in (-3, 14):
        box(Z, x, x + 1, -11, -10, 2, 15, "holz_dunkel")
    for x0, y0, z0 in ((-5, -12, 12), (14, -12, 12), (-19, -7, 14), (16, -7, 14)):
        box(Z, x0, x0 + 3, y0, y0 + 3, z0, z0 + 1, "laterne")
        box(Z, x0, x0 + 3, y0, y0 + 3, z0 + 1, z0 + 3, "licht")
        box(Z, x0, x0 + 3, y0, y0 + 3, z0 + 3, z0 + 4, "laterne")
        box(Z, x0 + 1, x0 + 2, y0 + 1, y0 + 2, z0 + 4, z0 + 5, "laterne")
    # Dach (Satteldach, Ueberstand) + Giebel
    for y in range(-7, 14):
        zt = dach_z(y)
        for x in range(-19, 19):
            for z in range(zt - 2, zt + 1):
                Z[(x, y, z)] = "dachkante" if y in (-7, 13) or x in (-19, 18) else "dach"
        if -4 <= y < 10:
            box(Z, -16, 16, y, y + 1, 24, zt - 2, "wand")
    for x in range(-19, 19):
        Z[(x, 3, dach_z(3) + 1)] = "dachkante"
    # Dachfenster (Gaube) vorne links
    box(Z, -14, -8, -4, -1, 26, 31, "wand"); box(Z, -13, -9, -5, -4, 27, 30, "fenster")
    box(Z, -15, -7, -5, 0, 31, 32, "dachkante")
    # Schornstein
    box(Z, -13, -9, 5, 9, 26, 38, "ziegel"); box(Z, -14, -8, 4, 10, 38, 39, "stein")
    # Ranken an den Saeulen
    for x0 in (-17, 13):
        for z in range(4, 24):
            for x in range(x0, x0 + 4):
                r = hsh(x, z, 7)
                if r > 0.72: Z[(x, -6, z)] = "blatt"
                if r > 0.95: Z[(x, -7, z)] = "bl_rosa"
    # Faesser rechts mit Pflanze
    zyl(Z, 20.5, -6.5, 2.2, 2, 8, "fass")
    for x in range(19, 23):
        for y in range(-8, -5):
            if hsh(x, y, 9) > 0.3: Z[(x, y, 8)] = "blatt"
            if hsh(x, y, 10) > 0.75: Z[(x, y, 9)] = "bl_gelb"
    zyl(Z, -20.5, -2.5, 1.8, 2, 6, "fass")
    # Pfosten fuer das drehende Seifenschild
    box(Z, 20, 21, -12, -11, 2, 15, "holz_dunkel")
    box(Z, 19, 22, -12, -11, 15, 16, "holz_dunkel")
    return Z

def baue_schild():
    Z = {}
    box(Z, -3, 15, -9, -8, 19, 29, "rahmen")
    box(Z, -2, 14, -10, -9, 20, 28, "schild")
    box(Z, -3, 15, -10, -9, 19, 20, "rahmen"); box(Z, -3, 15, -10, -9, 28, 29, "rahmen")
    box(Z, -3, -2, -10, -9, 19, 29, "rahmen"); box(Z, 14, 15, -10, -9, 19, 29, "rahmen")
    return Z

def baue_flasche():
    Z = {}
    box(Z, 2, 11, -1, 8, 31, 42, "flasche")
    for x, y in ((2, -1), (10, -1), (2, 7), (10, 7)):  # Ecken abrunden
        weg(Z, x, x + 1, y, y + 1, 31, 42)
    box(Z, 3, 10, 0, 7, 42, 43, "flasche"); box(Z, 5, 8, 2, 5, 43, 45, "flasche_hell")
    box(Z, 3, 10, -2, -1, 33, 40, "etikett")
    for x, z in ((5, 37), (6, 37), (5, 36), (6, 36), (8, 35), (7, 34), (4, 34)):
        Z[(x, -2, z)] = "etikett_blase"
    return Z

def baue_pumpe():
    Z = {}
    box(Z, 5, 8, 2, 5, 45, 48, "pumpe")
    box(Z, 4, 9, 1, 6, 48, 50, "pumpe")
    box(Z, 9, 13, 3, 5, 48, 49, "pumpe")
    return Z

def baue_seife():
    Z = {}
    box(Z, 17, 24, -13, -11, 16, 21, "seife")
    for x, z in ((17, 16), (23, 16), (17, 20), (23, 20)): weg(Z, x, x + 1, -13, -11, z, z + 1)
    for x, z in ((19, 18), (20, 18), (21, 18), (20, 19), (20, 17), (19, 19), (21, 17)):
        Z[(x, -14, z)] = "seife_druck"; Z[(x, -11, z)] = "seife_druck"
    return Z

# ---------------------------------------------------------------- Farben
def farbe(lab, k, n):
    x, y, z = k
    r = hsh(x, y, z, 1)
    u = y if abs(n[0]) > 0 else x  # Laufrichtung auf der Flaeche
    if lab == "stein" or lab == "pfad":
        if (z + (u // 3)) % 4 == 0 and lab == "stein" and n[2] == 0: return "fuge"
        return ["stein0", "stein1", "stein2"][int(hsh(u // 2, z // 2, 3) * 3)]
    if lab == "wand":
        if n[2] != 0: return "blau1"
        if z % 3 == 0: return "moertel"
        if (u + (z // 3) % 2 * 2) % 5 == 0: return "moertel"
        return ["blau0", "blau1", "blau2"][int(hsh((u + (z // 3) % 2 * 2) // 5, z // 3, 5) * 3)]
    if lab == "saeule":
        if z % 4 == 0: return "saeule1"
        return "saeule0" if r > 0.2 else "saeule1"
    if lab in ("holz", "theke", "holz_innen"):
        return ["holz1", "holz2"][(u // 2) % 2] if lab != "holz_innen" else ["holz2", "holz3"][(z // 2) % 2]
    if lab == "holz_hell": return "holz3" if r > 0.3 else "holz2"
    if lab in ("holz_dunkel", "fass"):
        if lab == "fass" and z in (3, 6): return "dunkel"
        return "holz0" if r > 0.3 else "holz1"
    if lab == "fenster": return "licht1" if (x + z) % 3 == 0 else "licht0"
    if lab == "licht": return "licht0"
    if lab == "laterne": return "dunkel"
    if lab == "markise": return "markblau" if (x // 2) % 2 == 0 else "weiss"
    if lab == "dach":
        if n[2] <= 0 and n[1] == 0 and n[0] == 0: return "dachkante"
        return ["dach0", "dach1", "dach2"][((u // 2) + z) % 3 if r > 0.15 else 2]
    if lab == "dachkante": return "dachkante"
    if lab == "ziegel":
        if z % 2 == 0 and r > 0.5: return "fuge"
        return "ziegel0" if (u + z) % 3 else "ziegel1"
    if lab == "blatt": return "blatt1" if r > 0.4 else "blatt0"
    if lab.startswith("bl_"): return {"bl_rosa": "rosa1", "bl_gelb": "gelb", "bl_lila": "lila", "bl_weiss": "weiss"}[lab]
    if lab.startswith("b_"): return {"b_rosa": "rosa1", "b_gelb": "gelb", "b_mint": "mint", "b_lila": "lila"}[lab]
    if lab == "flasche": return "rosa2" if n[2] > 0 else ("rosa1" if r > 0.25 else "rosa0")
    if lab == "flasche_hell": return "rosa2"
    if lab == "etikett": return "etikett"
    if lab == "etikett_blase": return "etikett2"
    if lab == "pumpe": return "weiss" if n[2] > 0 or r > 0.3 else "hellgrau"
    if lab == "seife": return "rosa2" if n[2] > 0 else "rosa1"
    if lab == "seife_druck": return "weiss"
    if lab == "schild": return "holz2" if (z // 2) % 2 else "holz1"
    if lab == "rahmen": return "rahmen" if r > 0.3 else "rahmen2"
    return "weiss"

# ---------------------------------------------------------------- Mesh aus Voxeln (gleiche Farbflaechen zusammenfassen)
NB = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
FACES = {(1, 0, 0): [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)], (-1, 0, 0): [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)],
         (0, 1, 0): [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)], (0, -1, 0): [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)],
         (0, 0, 1): [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)], (0, 0, -1): [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]}

def mesh_aus(name, Z, mat):
    bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap"); vmap = {}
    def vert(k):
        if k not in vmap: vmap[k] = bm.verts.new((k[0] * V, k[1] * V, k[2] * V))
        return vmap[k]
    for k, lab in Z.items():
        for n in NB:
            if (k[0] + n[0], k[1] + n[1], k[2] + n[2]) in Z: continue
            fi = IDX[farbe(lab, k, n)]
            u, v = ((fi % N_PIX) + 0.5) / N_PIX, ((fi // N_PIX) + 0.5) / N_PIX
            f = bm.faces.new([vert((k[0] + a, k[1] + b, k[2] + c)) for a, b, c in FACES[n]])
            f.normal_update()
            if f.normal.dot(Vector(n)) < 0: f.normal_flip()
            for lp in f.loops: lp[uv].uv = (u, v)
    vor = len(bm.faces)
    bmesh.ops.dissolve_limit(bm, angle_limit=0.01, use_dissolve_boundaries=False, verts=bm.verts[:], edges=bm.edges[:], delimit={'UV'})
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = D.meshes.new(name); bm.to_mesh(me); bm.free()
    me.materials.append(mat)
    ob = D.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    print(f"MESH {name} flaechen_vorher={vor} dreiecke={len(me.polygons)}")
    return ob

def paletten_material():
    img = D.images.new("Palette_Seifenladen", N_PIX, N_PIX, alpha=False)
    px = [0.0] * (N_PIX * N_PIX * 4)
    for i, n in enumerate(NAMEN):
        r, g, b = srgb(PAL[n]); x, y = i % N_PIX, i // N_PIX; k = (y * N_PIX + x) * 4
        px[k:k + 4] = [r, g, b, 1.0]
    img.pixels = px
    img.filepath_raw = os.path.join(OUT, "palette_seifenladen.png"); img.file_format = "PNG"; img.save()
    m = D.materials.new("Seifenladen"); m.use_nodes = True; nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"]); bsdf.inputs["Roughness"].default_value = 0.85
    return m

def foto(cam, pos, ziel, datei):
    cam.location = pos
    cam.rotation_euler = (Vector(ziel) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = os.path.join(OUT, "Renders", datei)
    bpy.ops.render.render(write_still=True)

if __name__ == "__main__":
    for o in list(D.objects): D.objects.remove(o)
    sc = bpy.context.scene
    mat = paletten_material()
    teile = [mesh_aus("Laden_Haus", baue_haus(), mat), mesh_aus("Laden_Schild", baue_schild(), mat),
             mesh_aus("Laden_Flasche", baue_flasche(), mat), mesh_aus("Laden_Pumpe", baue_pumpe(), mat),
             mesh_aus("Laden_Seife", baue_seife(), mat)]
    bpy.ops.object.select_all(action="DESELECT")
    for o in teile: o.select_set(True)
    bpy.context.view_layer.objects.active = teile[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "laden_seife.fbx"), use_selection=True,
                             apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y", path_mode="COPY", embed_textures=True)
    # Testszene
    bpy.ops.mesh.primitive_cylinder_add(radius=15, depth=0.4, location=(0, -2, -0.2))
    boden = bpy.context.object; mb = D.materials.new("Boden"); mb.use_nodes = True
    next(n for n in mb.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (*lin("#78dc50"), 1)
    boden.data.materials.append(mb)
    sonne = D.lights.new("Sonne", "SUN"); sonne.energy = 3.2
    so = D.objects.new("Sonne", sonne); sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    w = D.worlds.new("Himmel"); sc.world = w; w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (*lin("#9ccaf5"), 1); bg.inputs["Strength"].default_value = 0.8
    try: sc.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError: sc.render.engine = "BLENDER_EEVEE"
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x, sc.render.resolution_y = 1000, 1000
    cam = D.cameras.new("Kamera"); cam.lens = 40
    co = D.objects.new("Kamera", cam); sc.collection.objects.link(co); sc.camera = co
    foto(co, (22, -40, 22), (1, 0, 11), "seifenladen_schraeg.png")
    foto(co, (0, -46, 14), (1, 0, 12), "seifenladen_vorne.png")
    foto(co, (-30, 34, 22), (0, 2, 11), "seifenladen_hinten.png")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "seifenladen.blend"))
    print("FERTIG")
