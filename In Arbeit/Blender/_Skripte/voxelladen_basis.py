# Gemeinsame Helfer fuer die Voxel-Laeden (Bubble Safari). Wird per exec() in die Laden-Skripte geladen:
#   exec(open(os.path.join(os.path.dirname(__file__), "voxelladen_basis.py"), encoding="utf-8").read())
# Erwartet vor dem exec: PAL (Dict Name -> Hexfarbe), farbe(lab, k, n) -> Palettenname, NAME (Dateiname ohne Endung).
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
def hsh(x, y, z, s=0):
    n = math.sin(x * 12.9898 + y * 78.233 + z * 37.719 + s * 4.581) * 43758.5453
    return n - math.floor(n)

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
def kapsel(Z, a, b, r, lab):
    a, b = Vector(a), Vector(b); ab = b - a
    lo = [int(min(a[i], b[i]) - r) - 1 for i in range(3)]; hi = [int(max(a[i], b[i]) + r) + 2 for i in range(3)]
    for x in range(lo[0], hi[0]):
        for y in range(lo[1], hi[1]):
            for z in range(lo[2], hi[2]):
                p = Vector((x + 0.5, y + 0.5, z + 0.5)); t = max(0, min(1, (p - a).dot(ab) / ab.dot(ab)))
                if (p - (a + ab * t)).length <= r: Z[(x, y, z)] = lab
def scheibe_xz(Z, cx, y, cz, r, lab, r_innen=-1):
    """Kreisscheibe in der Vorderebene (x/z) auf Tiefe y."""
    for x in range(int(cx - r) - 1, int(cx + r) + 2):
        for z in range(int(cz - r) - 1, int(cz + r) + 2):
            d = math.hypot(x + 0.5 - cx, z + 0.5 - cz)
            if r_innen < d <= r: Z[(x, y, z)] = lab

NB = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
FACES = {(1, 0, 0): [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)], (-1, 0, 0): [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)],
         (0, 1, 0): [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)], (0, -1, 0): [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)],
         (0, 0, 1): [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)], (0, 0, -1): [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]}

NAMEN = list(PAL.keys()); IDX = {n: i for i, n in enumerate(NAMEN)}; N_PIX = 8
assert len(NAMEN) <= 64, "Palette zu gross"

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
    bmesh.ops.dissolve_limit(bm, angle_limit=0.01, use_dissolve_boundaries=False, verts=bm.verts[:], edges=bm.edges[:], delimit={'UV'})
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = D.meshes.new(name); bm.to_mesh(me); bm.free()
    me.materials.append(mat)
    ob = D.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    zs = [v.co.z for v in me.vertices]; xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]
    print(f"MESH {name} dreiecke={len(me.polygons)} mitte=({(min(xs)+max(xs))/2:.2f},{(min(ys)+max(ys))/2:.2f},{(min(zs)+max(zs))/2:.2f})")
    if len(me.polygons) > 19000: print("WARNUNG: zu viele Dreiecke fuer Roblox", name)
    return ob

def paletten_material():
    img = D.images.new("Palette_" + NAME, N_PIX, N_PIX, alpha=False)
    px = [0.0] * (N_PIX * N_PIX * 4)
    for i, n in enumerate(NAMEN):
        r, g, b = srgb(PAL[n]); x, y = i % N_PIX, i // N_PIX; k = (y * N_PIX + x) * 4
        px[k:k + 4] = [r, g, b, 1.0]
    img.pixels = px
    img.filepath_raw = os.path.join(OUT, f"palette_{NAME}.png"); img.file_format = "PNG"; img.save()
    m = D.materials.new(NAME); m.use_nodes = True; nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"]); bsdf.inputs["Roughness"].default_value = 0.85
    return m

def fertig_machen(teile, fotos):
    """Export (eine FBX), Testszene, Renders, .blend, 256er-Palette."""
    sc = bpy.context.scene
    bpy.ops.object.select_all(action="DESELECT")
    for o in teile: o.select_set(True)
    bpy.context.view_layer.objects.active = teile[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, f"{NAME}.fbx"), use_selection=True,
                             apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y", path_mode="COPY", embed_textures=True)
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
    for pos, ziel, datei in fotos:
        co.location = pos
        co.rotation_euler = (Vector(ziel) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(OUT, "Renders", datei)
        bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"{NAME}.blend"))
    try:
        from PIL import Image  # nicht in Blender vorhanden -> Hochskalieren macht sonst das Aufrufskript
    except ImportError:
        pass
    print("FERTIG")
