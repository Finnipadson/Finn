# Voxel-Deko fuer Bubble Safari im Stil der groben Voxel-Baeume (0,75-Stud-Wuerfel, 1 Einheit = 1 Stud).
# Jedes Objekt = 1 Mesh, alle teilen EINE Paletten-Textur (8x8 px) -> in Roblox je 1 MeshPart, 1 Bild.
# Objekte: Pilz_Rot (Fliegenpilz), Pilz_Braun, Sonnenblume, Blumenbusch, Stein
# Headless: blender -b --factory-startup --python voxeldeko.py -- <ausgabeordner>
import bpy, bmesh, math, sys, os
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else r"C:\Users\finns\OneDrive\Desktop\Claude\Games\In Arbeit\Blender\VoxelBaum"  # gleicher Ordner wie die Baeume (in Studio fuer Uploads freigegeben)
V = 0.75
D = bpy.data
os.makedirs(os.path.join(OUT, "Renders"), exist_ok=True)

def srgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
def lin(h):
    return tuple((c / 12.92) if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb(h))

# gemeinsame Palette (Index -> Farbe)
PAL = {
    "gruen0": "#2f8f2a", "gruen1": "#3ea832", "gruen2": "#4fbf3a", "gruen3": "#66d24a", "gruen4": "#8ce266",
    "rinde0": "#5e3a1f", "rinde1": "#74482a", "rinde2": "#8a5a36",
    "weiss": "#ffffff", "rot0": "#a8141c", "rot1": "#d0242a", "rot2": "#ea3b3b",
    "creme0": "#d6b98c", "creme1": "#efdcb4", "braun0": "#7a4a26", "braun1": "#9c6234", "braun2": "#b87a44",
    "gelb0": "#f0a818", "gelb1": "#ffcf2a", "kern": "#5a3416",
    "grau0": "#80786e", "grau1": "#9c948a", "grau2": "#b9b1a6", "moos": "#5fb83a",
    "rosa": "#ff7ab0", "lila": "#b98bff", "blau": "#6ab4ff", "gelbblume": "#ffe14a",
    # ab hier neu (28.11. Kleinkram) - nur anhaengen, damit alte UVs gleich bleiben
    "erde0": "#74452a", "erde1": "#8f5a33", "erde2": "#9b6a3e", "erdeD": "#5e371d", "holzring": "#c99a5e", "orange": "#ff9a3c",
}
NAMEN = list(PAL.keys())
IDX = {n: i for i, n in enumerate(NAMEN)}
N_PIX = 8

# ---------------------------------------------------------------- SDF-Helfer
def hsh(x, y, z, s=0):
    n = math.sin(x * 12.9898 + y * 78.233 + z * 37.719 + s * 4.581) * 43758.5453
    return n - math.floor(n)
def sd_ell(p, c, r):
    q = Vector(((p.x - c[0]) / r[0], (p.y - c[1]) / r[1], (p.z - c[2]) / r[2]))
    return (q.length - 1.0) * min(r)
def sd_cap(p, a, b, ra, rb):
    a = Vector(a); b = Vector(b); pa = p - a; ba = b - a
    h = max(0.0, min(1.0, pa.dot(ba) / ba.dot(ba)))
    return (pa - ba * h).length - (ra + (rb - ra) * h)
def smin(a, b, k=1.0):
    h = max(k - abs(a - b), 0.0) / k
    return min(a, b) - h * h * k * 0.25
def rauschen(p, f, s=7):
    x, y, z = p.x * f, p.y * f, p.z * f
    xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
    tx, ty, tz = x - xi, y - yi, z - zi
    tx, ty, tz = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty), tz * tz * (3 - 2 * tz)
    g = lambda a, b, c: hsh(xi + a, yi + b, zi + c, s)
    l = lambda a, b, t: a + (b - a) * t
    return l(l(l(g(0,0,0), g(1,0,0), tx), l(g(0,1,0), g(1,1,0), tx), ty),
             l(l(g(0,0,1), g(1,0,1), tx), l(g(0,1,1), g(1,1,1), tx), ty), tz)

# ---------------------------------------------------------------- Objekte
# Jedes Objekt: teile(p) -> Label oder None ; farbe(label, p, n, idx) -> Palettenname ; Grenzen
def fliegenpilz(groesse, kappe_farben, punkte=True, ring=True, name="Pilz"):
    H = groesse  # Hoehe Stiel
    R = groesse * 0.8  # Kappenradius
    kz = H * 1.02
    rnd = [(hsh(i, 3, 1) * math.tau, 0.25 + hsh(i, 5, 2) * 0.6) for i in range(9)]
    flecken = []
    for ang, t in rnd:  # Punkte auf der Kappen-Oberflaeche
        el = t * math.pi / 2
        flecken.append(Vector((math.cos(ang) * math.cos(el) * R, math.sin(ang) * math.cos(el) * R, kz + math.sin(el) * R * 0.62)))
    def teile(p):
        d_k = max(sd_ell(p, (0, 0, kz), (R, R, R * 0.62)), (kz - R * 0.12) - p.z)
        if d_k <= 0:
            if punkte and any((p - f).length < R * 0.2 for f in flecken): return "punkt"
            return "kappe"
        d_s = sd_cap(p, (0, 0, 0), (0, 0, kz), H * 0.24, H * 0.17)
        if d_s <= 0: return "stiel"
        if ring and abs(p.z - H * 0.72) < V * 0.6 and (Vector((p.x, p.y, 0)).length < H * 0.3): return "ring"
        return None
    def farbe(lab, p, n, idx):
        r = hsh(*idx, 3)
        if lab == "punkt": return "weiss" if n.z > -0.5 else "creme0"
        if lab == "kappe":
            if n.z < -0.5: return "creme0"  # Unterseite (Lamellen)
            k = kappe_farben
            s = 0.55 + 0.45 * n.z + (r - 0.5) * 0.35
            return k[max(0, min(len(k) - 1, int(s * len(k))))]
        if lab == "ring": return "weiss"
        return "creme1" if r > 0.3 else "creme0"
    return teile, farbe, (-R - 1, -R - 1, 0), (R + 1, R + 1, kz + R)

def sonnenblume():
    H = 8.0
    kopf = Vector((0, -0.6, H))
    def teile(p):
        q = p - kopf
        rr = math.sqrt(q.x ** 2 + q.z ** 2)
        if abs(q.y) < 0.55:
            if rr < 1.45: return "kern"
            ang = math.atan2(q.z, q.x)
            blatt = 2.9 + 0.5 * math.cos(ang * 10)  # 10 Blueten-Zacken
            if rr < blatt: return "bluete"
        if sd_cap(p, (0, 0, 0), (0, -0.3, H - 0.6), 0.75, 0.7) <= 0: return "stiel"
        for s, z in ((1, 3.2), (-1, 5.0)):
            if sd_ell(p, (s * 1.4, 0, z), (1.8, 0.8, 0.7)) <= 0: return "blatt"
        return None
    def farbe(lab, p, n, idx):
        r = hsh(*idx, 4)
        if lab == "kern": return "kern" if r > 0.3 else "braun0"
        if lab == "bluete": return "gelb1" if (r > 0.35 and n.y < 0.5) else "gelb0"
        if lab == "blatt": return "gruen3" if n.z > 0 else "gruen1"
        return "gruen2" if r > 0.4 else "gruen1"
    return teile, farbe, (-4, -2, 0), (4, 2, H + 4)

def blumenbusch():
    farben = ["rosa", "gelbblume", "lila", "weiss", "blau"]
    def busch(p):
        d = sd_ell(p, (0, 0, 0.9), (2.6, 2.3, 1.8)) + (rauschen(p, 0.9) - 0.5) * 1.0
        return smin(d, sd_ell(p, (1.6, 0.8, 0.7), (1.6, 1.5, 1.3)), 0.8) <= 0
    def teile(p):
        if busch(p): return "busch"
        # Blueten stehen einen Wuerfel ueber der Busch-Oberflaeche
        k = (round(p.x / V), round(p.y / V), round(p.z / V))
        if busch(p - Vector((0, 0, V))) and hsh(*k, 9) > 0.72: return "bluete"
        return None
    def farbe(lab, p, n, idx):
        r = hsh(*idx, 5)
        if lab == "bluete":
            return farben[int(hsh(idx[0], idx[1], 0, 6) * len(farben))]
        s = 0.5 + 0.5 * n.z + (r - 0.5) * 0.3
        return ["gruen0", "gruen1", "gruen2", "gruen3"][max(0, min(3, int(s * 4)))]
    return teile, farbe, (-4, -4, 0), (4, 4, 4)

def stein():
    def teile(p):
        d = sd_ell(p, (0, 0, 0.9), (2.8, 2.2, 1.9)) + (rauschen(p, 0.7, 3) - 0.5) * 1.2
        d = smin(d, sd_ell(p, (-1.9, 1.1, 0.5), (1.5, 1.3, 1.1)), 0.6)
        return "stein" if d <= 0 else None
    def farbe(lab, p, n, idx):
        r = hsh(*idx, 7)
        if n.z > 0.6 and rauschen(p, 0.8, 11) > 0.45: return "moos" if r > 0.25 else "gruen2"
        s = 0.5 + 0.4 * n.z + (r - 0.5) * 0.5
        return ["grau0", "grau1", "grau2"][max(0, min(2, int(s * 3)))]
    return teile, farbe, (-5, -4, 0), (4, 4, 4)

def zellen_teile(zellen):
    def teile(p):
        return zellen.get((math.floor(p.x / V), math.floor(p.y / V), math.floor(p.z / V)))
    return teile

def blumen():
    # Bueschel aus 6 kleinen Blumen: Stiel 2-4 Wuerfel, Bluete als Plus-Form mit gelber Mitte
    z = {}
    farben = ["rosa", "lila", "weiss", "gelbblume", "blau", "orange"]
    for k in range(6):
        ang = k / 6 * math.tau + hsh(k, 1, 1) * 0.8
        r = 1.4 + hsh(k, 2, 2) * 1.8
        cx, cy = math.floor(math.cos(ang) * r / V), math.floor(math.sin(ang) * r / V)
        hoch = 2 + int(hsh(k, 3, 3) * 3)
        for iz in range(hoch): z[(cx, cy, iz)] = "stiel"
        fb = farben[int(hsh(k, 4, 4) * len(farben))]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)): z[(cx + dx, cy + dy, hoch)] = fb
        z[(cx, cy, hoch)] = "mitte"
        if hsh(k, 5, 5) > 0.5: z[(cx + 1, cy, 1)] = "blatt"
    def farbe(lab, p, n, idx):
        if lab == "stiel": return "gruen1"
        if lab == "blatt": return "gruen3"
        if lab == "mitte": return "gelb1" if n.z > 0 else "gelb0"
        return lab
    return zellen_teile(z), farbe, (-4, -4, 0), (4, 4, 5)

def baumstamm():
    L, R = 4.2, 1.5
    def teile(p):
        q = math.sqrt(p.y ** 2 + (p.z - R) ** 2)
        if abs(p.x) <= L and q <= R: return "ende" if abs(p.x) > L - V else "holz"
        if abs(p.x) < 2.2 and abs(p.y) < 0.6 and R * 2 <= p.z < R * 2 + V and rauschen(p, 0.9, 5) > 0.45: return "moos"
        return None
    def farbe(lab, p, n, idx):
        r = hsh(*idx, 8)
        if lab == "moos": return "moos" if r > 0.3 else "gruen2"
        if lab == "ende" and abs(n.x) > 0.5:
            q = math.sqrt(p.y ** 2 + (p.z - R) ** 2)
            return "rinde0" if q > R - V else ("holzring" if int(q / V) % 2 == 0 else "creme0")
        return ["rinde0", "rinde1", "rinde2"][(idx[0] + int(r * 2)) % 3]
    return teile, farbe, (-5, -2.5, 0), (5, 2.5, 4)

def insel():
    RAD, TIEF = 6.5, 8.0
    def teile(p):
        r = math.sqrt(p.x ** 2 + p.y ** 2) + (rauschen(p, 0.6, 13) - 0.5) * 1.6
        if r > RAD: return None
        oben = TIEF
        if oben <= p.z < oben + 1.5: return "gras"
        unten = oben - TIEF * (1 - r / RAD) ** 0.75 - (rauschen(p, 0.8, 17) - 0.5) * 1.5
        if unten <= p.z < oben: return "erde"
        return None
    def farbe(lab, p, n, idx):
        r = hsh(*idx, 9)
        if lab == "gras":
            if n.z > 0.5: return ["gruen2", "gruen3", "gruen4"][int(r * 2.4)]
            return "gruen1" if r > 0.3 else "gruen2"
        if r < 0.06: return "erdeD"
        return ["erde1", "erde0", "erde2", "erde0"][int(p.z / 1.5) % 4]
    return teile, farbe, (-8, -8, 0), (8, 8, 10)

OBJEKTE = {
    "Pilz_Rot": fliegenpilz(5.0, ["rot0", "rot1", "rot2"]),
    "Pilz_Braun": fliegenpilz(3.2, ["braun0", "braun1", "braun2"], punkte=False, ring=False),
    "Sonnenblume": sonnenblume(),
    "Blumenbusch": blumenbusch(),
    "Stein": stein(),
    "Blumen": blumen(),
    "Baumstamm": baumstamm(),
    "Insel": insel(),
}

# ---------------------------------------------------------------- Voxelizer
NB = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
FACES = {(1, 0, 0): [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)], (-1, 0, 0): [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)],
         (0, 1, 0): [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)], (0, -1, 0): [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)],
         (0, 0, 1): [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)], (0, 0, -1): [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]}

def baue(name, teile, farbe, lo, hi):
    zellen = {}
    for ix in range(math.floor(lo[0] / V), math.ceil(hi[0] / V) + 1):
        for iy in range(math.floor(lo[1] / V), math.ceil(hi[1] / V) + 1):
            for iz in range(0, math.ceil(hi[2] / V) + 1):
                p = Vector(((ix + 0.5) * V, (iy + 0.5) * V, (iz + 0.5) * V))
                lab = teile(p)
                if lab: zellen[(ix, iy, iz)] = lab
    bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap"); vmap = {}
    def vert(k):
        if k not in vmap: vmap[k] = bm.verts.new((k[0] * V, k[1] * V, k[2] * V))
        return vmap[k]
    for (ix, iy, iz), lab in zellen.items():
        expo = [n for n in NB if (ix + n[0], iy + n[1], iz + n[2]) not in zellen]
        if not expo: continue
        p = Vector(((ix + 0.5) * V, (iy + 0.5) * V, (iz + 0.5) * V))
        nrm = sum((Vector(n) for n in expo), Vector())
        nrm = nrm.normalized() if nrm.length > 0 else Vector((0, 0, 1))
        for n in expo:
            fn = farbe(lab, p, Vector(n) * 0.6 + nrm * 0.4, (ix, iy, iz))
            fi = IDX[fn]
            u, v = ((fi % N_PIX) + 0.5) / N_PIX, ((fi // N_PIX) + 0.5) / N_PIX
            f = bm.faces.new([vert((ix + a, iy + b, iz + c)) for a, b, c in FACES[n]])
            f.normal_update()
            if f.normal.dot(Vector(n)) < 0: f.normal_flip()
            for lp in f.loops: lp[uv].uv = (u, v)
    me = D.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = D.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    return ob, len(me.polygons) * 2

def paletten_material():
    img = D.images.new("Palette_Deko", N_PIX, N_PIX, alpha=False)
    px = [0.0] * (N_PIX * N_PIX * 4)
    for i, n in enumerate(NAMEN):
        r, g, b = srgb(PAL[n]); x, y = i % N_PIX, i // N_PIX; k = (y * N_PIX + x) * 4
        px[k:k + 4] = [r, g, b, 1.0]
    img.pixels = px
    img.filepath_raw = os.path.join(OUT, "palette_deko.png"); img.file_format = "PNG"; img.save()
    m = D.materials.new("VoxelDeko"); m.use_nodes = True; nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    return m

def box(name, size, loc, col):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o = bpy.context.object; o.name = name; o.scale = size
    m = D.materials.new(name); m.use_nodes = True
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (*col, 1)
    o.data.materials.append(m); return o

def foto(cam, pos, ziel, datei):
    cam.location = pos
    cam.rotation_euler = (Vector(ziel) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = os.path.join(OUT, "Renders", datei)
    bpy.ops.render.render(write_still=True)

if __name__ == "__main__":
    for o in list(D.objects): D.objects.remove(o)
    sc = bpy.context.scene
    mat = paletten_material()
    obs = []
    for name, (teile, farbe, lo, hi) in OBJEKTE.items():
        ob, tris = baue("Deko_" + name, teile, farbe, lo, hi)
        ob.data.materials.append(mat); obs.append(ob)
        print(f"DEKO {name} dreiecke={tris}")
    # FBX je Objekt (am Ursprung)
    for ob in obs:
        bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active = ob
        bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, ob.name.lower() + ".fbx"), use_selection=True,
                                 apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y", path_mode="COPY", embed_textures=True)
    # Aufstellung fuer das Testbild: Reihe auf einem Terrassenstueck
    x = -32
    for ob in obs:
        ob.location = (x, 0, 0); x += 9 if ob.name != "Deko_Insel" else 0
        if ob.name == "Deko_Insel": ob.location = (32, 6, 4)
    box("Erde", (48, 14, 20), (0, 0, -13), lin("#8c5c37"))
    box("Gras", (48, 16, 3), (0, -1, -1.5), lin("#56c83c"))
    sonne = D.lights.new("Sonne", "SUN"); sonne.energy = 3.2
    so = D.objects.new("Sonne", sonne); sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    w = D.worlds.new("Himmel"); sc.world = w; w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (*lin("#7cc0ff"), 1); bg.inputs["Strength"].default_value = 0.9
    try: sc.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError: sc.render.engine = "BLENDER_EEVEE"
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x, sc.render.resolution_y = 1600, 700
    cam = D.cameras.new("Kamera"); cam.lens = 40
    co = D.objects.new("Kamera", cam); sc.collection.objects.link(co); sc.camera = co
    foto(co, (0, -56, 16), (0, 0, 4), "deko_reihe.png")
    foto(co, (14, -22, 8), (26, 0, 4), "deko_kleinkram_nah.png")
    foto(co, (-22, -16, 10), (-14, 0, 4), "deko_pilze_nah.png")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "voxeldeko.blend"))
    print("FERTIG")
