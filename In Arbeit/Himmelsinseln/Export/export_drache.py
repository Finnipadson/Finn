import bpy, bmesh, sys
from mathutils import Vector

OUT = r"C:\Users\finns\OneDrive\Desktop\Claude\Games\In Arbeit\Himmelsinseln\Export\lavadrache.glb"
FRAME = 100
TARGET_TOTAL = 60000
CAP = 19000
SKIP_MATS = {"Rauch", "Feuer_Flamme", "Feuer_Kern", "Feuer_Rauch", "Funken", "Blitz", "Brocken", "Boden", "Wand", "Gras", "Ring", "Band_Rot"}

sc = bpy.context.scene
sc.frame_set(FRAME)
dg = bpy.context.evaluated_depsgraph_get()

def descendants(o):
    out = [o]
    for c in o.children:
        out += descendants(c)
    return out

cands = []
for rn in ("Drache_Root", "Drache_Skelett"):
    r = bpy.data.objects.get(rn)
    if r:
        cands += descendants(r)
cands = [o for o in dict.fromkeys(cands) if o.type in ("MESH", "CURVE", "META", "SURFACE") and o.visible_get()]

# group polygons by material into bmesh buffers (world space, evaluated = posed)
buffers = {}
for o in cands:
    e = o.evaluated_get(dg)
    try:
        me = e.to_mesh()
    except Exception:
        continue
    if me is None or len(me.polygons) == 0:
        e.to_mesh_clear(); continue
    mats = [s.material.name if s.material else "Drachenstein" for s in e.material_slots] or ["Drachenstein"]
    bm_src = bmesh.new(); bm_src.from_mesh(me)
    bm_src.transform(e.matrix_world)
    bmesh.ops.triangulate(bm_src, faces=bm_src.faces[:])
    by_mat = {}
    for f in bm_src.faces:
        mn = mats[min(f.material_index, len(mats) - 1)]
        by_mat.setdefault(mn, []).append(f)
    for mn, faces in by_mat.items():
        if mn in SKIP_MATS:
            continue
        dst = buffers.setdefault(mn, bmesh.new())
        vmap = {}
        for f in faces:
            vs = []
            for v in f.verts:
                nv = vmap.get(v)
                if nv is None:
                    nv = dst.verts.new(v.co); vmap[v] = nv
                vs.append(nv)
            try:
                dst.faces.new(vs)
            except ValueError:
                pass
    bm_src.free()
    e.to_mesh_clear()

# measure
allmin = Vector((1e9, 1e9, 1e9)); allmax = Vector((-1e9, -1e9, -1e9))
total = 0
for mn, bm in buffers.items():
    total += len(bm.faces)
    for v in bm.verts:
        for i in range(3):
            allmin[i] = min(allmin[i], v.co[i]); allmax[i] = max(allmax[i], v.co[i])
print("RAW_TRIS", total)
print("BOUNDS_MIN", tuple(round(x, 3) for x in allmin), "MAX", tuple(round(x, 3) for x in allmax))
kp = bpy.data.objects.get("Kopf_Pivot")
if kp:
    print("HEAD_WORLD", tuple(round(x, 3) for x in kp.matrix_world.translation))
tail = [o for o in bpy.data.objects if o.name.startswith("Schwanz_J")]
if tail:
    last = sorted(tail, key=lambda o: o.name)[-1]
    print("TAIL_WORLD", last.name, tuple(round(x, 3) for x in last.matrix_world.translation))
wl = bpy.data.objects.get("Fluegelhaut_L")
if wl:
    print("WING_L_WORLD", tuple(round(x, 3) for x in wl.matrix_world.translation))

# new scene with one object per material, decimated
ns = sc
for o in list(sc.objects):
    o.select_set(False)
ratio_global = min(1.0, TARGET_TOTAL / max(total, 1))
objs = []
for mn, bm in buffers.items():
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0005)
    me = bpy.data.meshes.new("Drache_" + mn)
    bm.to_mesh(me); bm.free()
    me.materials.append(bpy.data.materials.get(mn))
    ob = bpy.data.objects.new("Drache_" + mn, me)
    ns.collection.objects.link(ob)
    tris = len(me.polygons)
    goal = min(CAP, max(200, int(tris * ratio_global)))
    if tris > goal:
        mod = ob.modifiers.new("Dec", "DECIMATE")
        mod.ratio = goal / tris
    objs.append(ob)

if True:
    bpy.context.view_layer.update()
    dg2 = bpy.context.evaluated_depsgraph_get()
    final = 0
    for ob in objs:
        e = ob.evaluated_get(dg2)
        m = e.to_mesh()
        n = sum(len(p.vertices) - 2 for p in m.polygons)
        final += n
        print("MESH", ob.name, n)
        e.to_mesh_clear()
    print("FINAL_TRIS", final)
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_apply=True, export_animations=False, export_materials="EXPORT",
                              export_yup=True)
print("EXPORTED", OUT)
