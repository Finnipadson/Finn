# Voxel-Baum fuer Bubble Safari (Stil: TVA-Video, runde Wolken-Krone aus kleinen Wuerfeln).
# 1 Blender-Einheit = 1 Roblox-Stud. Ein Mesh, Farben ueber eine kleine Paletten-Textur (8x8 px,
# jede Wuerfelflaeche zeigt auf ein Paletten-Pixel) -> in Roblox als 1 MeshPart + 1 Textur nutzbar.
# Spaeter fuer andere Biome: nur PALETTEN-Eintrag tauschen (Herbst, Schnee, Pilzwald ...).
# Headless: blender -b --factory-startup --python voxelbaum.py -- <ausgabeordner> [biom] [rund|hoch|breit] [fein|grob]
import bpy, bmesh, math, sys, os
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else r"C:\Users\finns\OneDrive\Desktop\Claude\Games\In Arbeit\Blender\VoxelBaum"
BIOM = ARGS[1] if len(ARGS) > 1 else "wiese"
VARIANTE = ARGS[2] if len(ARGS) > 2 else "rund"  # rund | hoch | breit
GROB = len(ARGS) > 3 and ARGS[3] == "grob"  # gröbere Version: 1,5x so große Würfel, ruhigere Farben
V = 0.75 if GROB else 0.5  # Wuerfel-Kantenlaenge in Studs
D = bpy.data
os.makedirs(os.path.join(OUT, "Renders"), exist_ok=True)

def srgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))

# Paletten je Biom: Laub (dunkel->hell, 5 Stufen), Rinde (3), Wurzel/Schatten
PALETTEN = {
    "wiese": {"laub": ["#2f8f2a", "#3ea832", "#4fbf3a", "#66d24a", "#8ce266"],
              "rinde": ["#5e3a1f", "#74482a", "#8a5a36"], "extra": ["#ffffff"]},
    "kirsch": {"laub": ["#cf5a8c", "#e276a6", "#f095bd", "#f8b4d2", "#ffd4e6"],
               "rinde": ["#5e3a1f", "#74482a", "#8a5a36"], "extra": ["#ffffff"]},
    "herbst": {"laub": ["#a8381c", "#d0582a", "#e8823a", "#f2a845", "#f8cf6a"],
               "rinde": ["#4e3220", "#664229", "#7d5434"], "extra": ["#ffffff"]},
    "schnee": {"laub": ["#1f5e3a", "#2a7346", "#368553", "#e6eef7", "#ffffff"],
               "rinde": ["#4a3324", "#5c412e", "#6e5038"], "extra": ["#ffffff"]},
}
PAL = PALETTEN[BIOM]
FARBEN = PAL["laub"] + PAL["rinde"] + PAL["extra"]  # Index 0-4 Laub, 5-7 Rinde, 8 extra
N_PIX = 8

# ---------------------------------------------------------------- Formen (SDF)
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

def smin(a, b, k=1.2):
    h = max(k - abs(a - b), 0.0) / k
    return min(a, b) - h * h * k * 0.25

def wert_rauschen(p, f):
    # glattes Wert-Rauschen (trilinear), fuer Beulen in der Krone
    x, y, z = p.x * f, p.y * f, p.z * f
    xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
    tx, ty, tz = x - xi, y - yi, z - zi
    tx, ty, tz = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty), tz * tz * (3 - 2 * tz)
    def g(a, b, c): return hsh(xi + a, yi + b, zi + c, 7)
    l = lambda a, b, t: a + (b - a) * t
    return l(l(l(g(0,0,0), g(1,0,0), tx), l(g(0,1,0), g(1,1,0), tx), ty),
             l(l(g(0,0,1), g(1,0,1), tx), l(g(0,1,1), g(1,1,1), tx), ty), tz)

def wurzeln(p, d, winkel, r=2.4):
    for ang in winkel:
        a = Vector((math.cos(ang) * r, math.sin(ang) * r, 0))
        d = smin(d, sd_cap(p, (0, 0, 1.2), (a.x, a.y, 0.25), 0.7, 0.35), 0.6)
    return d

# Variante "rund": Wolken-Krone aus Ballen, kleiner Ballen am Seitenast
def stamm_rund(p):
    d = sd_cap(p, (0, 0, 0), (0.2, 0.1, 9.5), 1.25, 0.75)
    d = min(d, sd_cap(p, (0.3, 0.1, 5.2), (4.2, -1.6, 7.4), 0.55, 0.4))      # Seitenast
    d = min(d, sd_cap(p, (0, 0.1, 8.6), (-2.2, -1.2, 10.4), 0.5, 0.35))     # Ast in die Krone
    return wurzeln(p, d, (0.3, 2.4, 4.3))

# Variante "hoch": schlanker Baum, Krone in drei Etagen uebereinander
def stamm_hoch(p):
    d = sd_cap(p, (0, 0, 0), (-0.3, 0.2, 15.5), 1.0, 0.55)
    d = min(d, sd_cap(p, (-0.1, 0.1, 6.5), (-3.0, 1.2, 8.4), 0.45, 0.3))     # tiefer Ast links
    return wurzeln(p, d, (1.0, 3.1, 5.0), 2.0)

# Variante "breit": niedriger Baum, Stamm gabelt sich, flache Schirm-Krone
def stamm_breit(p):
    d = sd_cap(p, (0, 0, 0), (0.8, 0.3, 5.5), 1.4, 1.0)
    d = smin(d, sd_cap(p, (0.8, 0.3, 5.2), (-3.4, -0.6, 8.6), 0.8, 0.5), 0.5)  # Gabel links
    d = smin(d, sd_cap(p, (0.8, 0.3, 5.2), (4.6, 1.4, 8.4), 0.8, 0.5), 0.5)    # Gabel rechts
    return wurzeln(p, d, (0.0, 1.6, 3.3, 4.8), 2.8)

VARIANTEN = {
    "rund": (stamm_rund, [((0, 0, 12.0), (5.2, 5.2, 4.4)),
                          ((3.4, 1.2, 10.4), (3.4, 3.4, 3.0)),
                          ((-3.2, -1.6, 10.8), (3.6, 3.6, 3.1)),
                          ((0.8, -3.4, 11.0), (3.2, 3.2, 2.8)),
                          ((-1.0, 2.8, 13.6), (3.2, 3.2, 2.8)),
                          ((4.6, -1.8, 7.6), (2.2, 2.2, 1.9))]),
    "hoch": (stamm_hoch, [((0.2, 0, 10.6), (4.4, 4.4, 3.2)),
                          ((-0.4, 0.3, 14.6), (3.6, 3.6, 2.9)),
                          ((-0.3, 0.2, 18.2), (2.6, 2.6, 2.4)),
                          ((-0.3, 0.2, 20.4), (1.4, 1.4, 1.4)),
                          ((-3.6, 1.4, 8.6), (2.0, 2.0, 1.7))]),
    "breit": (stamm_breit, [((0.4, 0.3, 10.2), (6.6, 5.8, 2.8)),
                            ((-4.6, -0.8, 9.4), (3.8, 3.6, 2.5)),
                            ((5.4, 1.6, 9.2), (3.8, 3.6, 2.4)),
                            ((0.0, -3.6, 9.6), (3.4, 3.0, 2.3)),
                            ((-0.8, 3.4, 11.0), (3.4, 3.2, 2.4))]),
}
sd_stamm, KRONE = VARIANTEN[VARIANTE]
K_UNTEN = min(c[2] - r[2] for c, r in KRONE)
K_OBEN = max(c[2] + r[2] for c, r in KRONE)

def sd_krone(p):
    d = 1e9
    for c, r in KRONE:
        d = smin(d, sd_ell(p, c, r), 1.4)
    d += (wert_rauschen(p, 0.45) - 0.5) * (1.4 if GROB else 1.6) + (0 if GROB else (wert_rauschen(p, 1.1) - 0.5) * 0.6)
    return d

# ---------------------------------------------------------------- Faerbung
def farbe_laub(p, nrm, idx):
    # oben/aussen hell, unten dunkel, Pixel-Streuung wie im Vorbild
    hell = 0.5 + 0.5 * nrm.z
    hoehe = (p.z - K_UNTEN) / (K_OBEN - K_UNTEN)
    r = hsh(*idx, 1)
    s = hell * 0.65 + hoehe * 0.35 + (r - 0.5) * (0.3 if GROB else 0.55)
    if r > (0.97 if GROB else 0.93): s += 0.35                       # einzelne helle Blatt-Pixel
    return max(0, min(4, int(s * 5)))

def farbe_rinde(p, nrm, idx):
    r = hsh(*idx, 2)
    if (idx[2] + int(r * 2)) % 3 == 0: return 5   # dunkle Rindenstreifen
    return 6 if r < 0.6 else 7

# ---------------------------------------------------------------- Voxelizer mit Paletten-UVs
NB = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
FACES = {(1, 0, 0): [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)], (-1, 0, 0): [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)],
         (0, 1, 0): [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)], (0, -1, 0): [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)],
         (0, 0, 1): [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)], (0, 0, -1): [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]}

def baue_baum(name):
    zellen = {}
    lo, hi = (-11, -11, -1), (11, 11, 23)
    for ix in range(int(lo[0] / V), int(hi[0] / V) + 1):
        for iy in range(int(lo[1] / V), int(hi[1] / V) + 1):
            for iz in range(0, int(hi[2] / V) + 1):
                p = Vector(((ix + 0.5) * V, (iy + 0.5) * V, (iz + 0.5) * V))
                if sd_stamm(p) <= 0: zellen[(ix, iy, iz)] = "r"
                elif sd_krone(p) <= 0: zellen[(ix, iy, iz)] = "l"
    bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap"); vmap = {}
    def vert(k):
        if k not in vmap: vmap[k] = bm.verts.new((k[0] * V, k[1] * V, k[2] * V))
        return vmap[k]
    for (ix, iy, iz), art in zellen.items():
        expo = [n for n in NB if (ix + n[0], iy + n[1], iz + n[2]) not in zellen]
        if not expo: continue
        p = Vector(((ix + 0.5) * V, (iy + 0.5) * V, (iz + 0.5) * V))
        nrm = sum((Vector(n) for n in expo), Vector())
        nrm = nrm.normalized() if nrm.length > 0 else Vector((0, 0, 1))
        basis = farbe_laub(p, nrm, (ix, iy, iz)) if art == "l" else farbe_rinde(p, nrm, (ix, iy, iz))
        for n in expo:
            fi = basis
            if art == "l":  # je Flaeche: Unterseiten dunkel, Oberseiten eine Stufe heller -> Wuerfel lesbar
                if n[2] == -1: fi = 0
                elif n[2] == 1: fi = min(4, basis + 1)
                else: fi = max(1, basis)
            u, v = ((fi % N_PIX) + 0.5) / N_PIX, ((fi // N_PIX) + 0.5) / N_PIX
            f = bm.faces.new([vert((ix + a, iy + b, iz + c)) for a, b, c in FACES[n]])
            f.normal_update()
            if f.normal.dot(Vector(n)) < 0: f.normal_flip()   # Flaeche muss nach aussen zeigen
            for lp in f.loops: lp[uv].uv = (u, v)
    me = D.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = D.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    return ob, len(zellen), len(me.polygons)

def paletten_material():
    img = D.images.new("Palette_" + BIOM, N_PIX, N_PIX, alpha=False)
    px = [0.0] * (N_PIX * N_PIX * 4)
    for i, h in enumerate(FARBEN):
        r, g, b = srgb(h); x, y = i % N_PIX, i // N_PIX; k = (y * N_PIX + x) * 4
        px[k:k + 4] = [r, g, b, 1.0]
    img.pixels = px
    img.filepath_raw = os.path.join(OUT, f"palette_{BIOM}.png"); img.file_format = "PNG"; img.save()
    m = D.materials.new("VoxelBaum_" + BIOM); m.use_nodes = True; nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    return m

# ---------------------------------------------------------------- Szene zum Ansehen (Stufe wie in unserer Karte)
def box(name, size, loc, col):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o = bpy.context.object; o.name = name
    o.scale = size; m = D.materials.new(name); m.use_nodes = True
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (*col, 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9 if "Principled BSDF" in m.node_tree.nodes else 0.9
    o.data.materials.append(m); return o

def lin(h):
    return tuple((c / 12.92) if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb(h))

def szene(baum):
    sc = bpy.context.scene
    for o in list(D.objects):
        if o is not baum: D.objects.remove(o)
    # Terrassenstueck aus der Karte: Erde + Noppen-Gras (Farben aus Map.lua)
    box("Erde", (40, 16, 27), (0, 0, -13.5 - 3), lin("#8c5c37"))
    box("Gras", (40, 18, 3), (0, -1, -1.5), lin("#56c83c"))
    box("Boden", (80, 60, 1), (0, -30, -30.5), lin("#78dc50"))
    # Licht wie Roblox-Mittag
    sonne = D.lights.new("Sonne", "SUN"); sonne.energy = 3.2; sonne.angle = math.radians(2)
    so = D.objects.new("Sonne", sonne); sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    w = D.worlds.new("Himmel"); sc.world = w; w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (*lin("#7cc0ff"), 1); bg.inputs["Strength"].default_value = 0.9
    try: sc.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        try: sc.render.engine = "BLENDER_EEVEE"
        except TypeError as e: print("Engines:", e)
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x, sc.render.resolution_y = 960, 960
    cam = D.cameras.new("Kamera"); cam.lens = 45
    co = D.objects.new("Kamera", cam); sc.collection.objects.link(co); sc.camera = co
    return co

def foto(co, pos, ziel, datei):
    co.location = pos
    co.rotation_euler = (Vector(ziel) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = os.path.join(OUT, "Renders", datei)
    bpy.ops.render.render(write_still=True)

if __name__ == "__main__":
    for o in list(D.objects): D.objects.remove(o)
    NAME = f"{BIOM}_{VARIANTE}" + ("_grob" if GROB else "")
    baum, n, flaechen = baue_baum("VoxelBaum_" + NAME)
    baum.data.materials.append(paletten_material())
    print(f"BAUM voxel={n} flaechen={flaechen} dreiecke={flaechen * 2}")
    co = szene(baum)
    foto(co, (24, -30, 14), (0, 0, 8), f"baum_{NAME}_schraeg.png")
    foto(co, (0, -34, 4), (0, 0, 8.5), f"baum_{NAME}_vorne.png")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"voxelbaum_{NAME}.blend"))
    # FBX fuer Roblox (nur der Baum)
    bpy.ops.object.select_all(action="DESELECT"); baum.select_set(True); bpy.context.view_layer.objects.active = baum
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, f"voxelbaum_{NAME}.fbx"), use_selection=True,
                             apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y", path_mode="COPY", embed_textures=True)
    print("FERTIG")
