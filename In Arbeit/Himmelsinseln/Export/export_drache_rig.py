# Lavadrache -> Roblox: ein Skin-Rig (Skelett + Flügel + Kiefer), 3 Meshes, gebackene Lava-Textur.
# Headless: blender.exe -b lavadrache.blend --python export_drache_rig.py
import bpy, bmesh, os, math
import numpy as np
from mathutils import Matrix, Vector

OUTDIR = r"C:\Users\finns\OneDrive\Desktop\Claude\Games\In Arbeit\Himmelsinseln\Export"
FRAME = 100
MATCH_FRAMES = [100, 60, 150, 200]
BUDGET = {"Vorne": 18500, "Hinten": 18500, "Fluegel": 15000}
TEX = 2048
SKIP_MATS = {"Rauch", "Feuer_Flamme", "Feuer_Kern", "Feuer_Rauch", "Funken", "Blitz", "Brocken",
             "Boden", "Wand", "Gras", "Ring", "Band_Rot"}

sc = bpy.context.scene
vl = bpy.context.view_layer
SKEL = bpy.data.objects["Drache_Skelett"]
WINGS = {"WL_": bpy.data.objects["Fluegel_Rig_L"], "WR_": bpy.data.objects["Fluegel_Rig_R"]}
KIEFER = bpy.data.objects.get("Kiefer_Pivot")

def norm(m):
    loc, rot, _ = m.decompose()
    return Matrix.Translation(loc) @ rot.to_matrix().to_4x4()

# ---------- 1. bone world matrices per frame ----------
def bone_mats():
    out = {}
    for pb in SKEL.pose.bones:
        out[pb.name] = norm(SKEL.matrix_world @ pb.matrix)
    for pre, arm in WINGS.items():
        for pb in arm.pose.bones:
            out[pre + pb.name] = norm(arm.matrix_world @ pb.matrix)
    if KIEFER:
        out["Kiefer"] = norm(KIEFER.matrix_world)
    return out

def descendants(o):
    r = [o]
    for c in o.children:
        r += descendants(c)
    return r

srcs = []
for rn in ("Drache_Root", "Drache_Skelett"):
    srcs += descendants(bpy.data.objects[rn])
srcs = [o for o in dict.fromkeys(srcs) if o.type in ("MESH", "CURVE", "META", "SURFACE") and o.visible_get()]
def mats_of(o):
    return [s.material.name if s.material else "Drachenstein" for s in o.material_slots] or ["Drachenstein"]
srcs = [o for o in srcs if not set(mats_of(o)) <= SKIP_MATS]

per_frame_bones, per_frame_obj = {}, {}
for f in MATCH_FRAMES:
    sc.frame_set(f)
    per_frame_bones[f] = bone_mats()
    per_frame_obj[f] = {o.name: norm(o.matrix_world) for o in srcs}
sc.frame_set(FRAME)
B0 = per_frame_bones[FRAME]

SKINNED = {"Drachenkoerper": "", "Fluegelhaut_L": "WL_", "Fluegelhaut_R": "WR_"}
assign = {}
for o in srcs:
    if o.name in SKINNED:
        continue
    best, bestd = None, 1e9
    for bn in B0:
        ref = per_frame_bones[FRAME][bn].inverted() @ per_frame_obj[FRAME][o.name]
        d = 0.0
        for f in MATCH_FRAMES[1:]:
            rel = per_frame_bones[f][bn].inverted() @ per_frame_obj[f][o.name]
            d += sum(abs(rel[i][j] - ref[i][j]) for i in range(3) for j in range(4))
        if d < bestd:
            best, bestd = bn, d
    assign[o.name] = best
from collections import Counter
print("RIGID_ASSIGN", Counter(assign.values()).most_common(40))

# ---------- 2. combined armature, rest = posed frame ----------
arm_data = bpy.data.armatures.new("Drache_Rig")
rig = bpy.data.objects.new("Drache_Rig", arm_data)
sc.collection.objects.link(rig)
for o in vl.objects:
    o.select_set(False)
vl.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
eb = arm_data.edit_bones
lengths = {}
for pb in SKEL.pose.bones:
    lengths[pb.name] = pb.length * SKEL.matrix_world.to_scale()[0]
for pre, a in WINGS.items():
    for pb in a.pose.bones:
        lengths[pre + pb.name] = pb.length * a.matrix_world.to_scale()[0]
lengths["Kiefer"] = 0.4
for bn, M in B0.items():
    b = eb.new(bn)
    b.head = (0, 0, 0); b.tail = (0, max(lengths.get(bn, 0.3), 0.05), 0)
    b.matrix = M
for pb in SKEL.pose.bones:
    if pb.parent:
        eb[pb.name].parent = eb[pb.parent.name]
for pre, a in WINGS.items():
    for pb in a.pose.bones:
        if pb.parent:
            eb[pre + pb.name].parent = eb[pre + pb.parent.name]
        else:
            eb[pre + pb.name].parent = eb["Koerper_V"]
if "Kiefer" in eb:
    eb["Kiefer"].parent = eb["Kopf"]
bpy.ops.object.mode_set(mode="OBJECT")
BONES = [b.name for b in arm_data.bones]
BIDX = {n: i for i, n in enumerate(BONES)}
print("BONES", len(BONES))

# ---------- 3. merged mesh with weights (posed geometry) ----------
body = bpy.data.objects["Drachenkoerper"]
for m in body.modifiers:
    if m.type == "SUBSURF":
        m.show_viewport = False; m.show_render = False
dg = bpy.context.evaluated_depsgraph_get()
bm = bmesh.new()
dl = bm.verts.layers.deform.verify()
MATLIST = []
def midx(name):
    if name not in MATLIST:
        MATLIST.append(name)
    return MATLIST.index(name)

for o in srcs:
    e = o.evaluated_get(dg)
    try:
        me = e.to_mesh()
    except Exception:
        continue
    if me is None or not me.polygons:
        e.to_mesh_clear(); continue
    mats = mats_of(o)
    pre = SKINNED.get(o.name)
    gnames = [g.name for g in o.vertex_groups]
    mw = e.matrix_world
    vmap = {}
    for p in me.polygons:
        mn = mats[min(p.material_index, len(mats) - 1)]
        if mn in SKIP_MATS:
            continue
        vs = []
        for vi in p.vertices:
            nv = vmap.get(vi)
            if nv is None:
                v = me.vertices[vi]
                nv = bm.verts.new(mw @ v.co)
                if pre is None:
                    nv[dl][BIDX[assign[o.name]]] = 1.0
                else:
                    ws = [(pre + gnames[g.group], g.weight) for g in v.groups if g.group < len(gnames) and g.weight > 0.001 and (pre + gnames[g.group]) in BIDX]
                    if not ws:
                        ws = [("Koerper_V" if pre == "" else pre + "Arm", 1.0)]
                    for n, w in ws:
                        nv[dl][BIDX[n]] = w
                vmap[vi] = nv
            vs.append(nv)
        if len(set(vs)) < 3:
            continue
        try:
            f = bm.faces.new(vs); f.material_index = midx(mn)
        except ValueError:
            pass
    e.to_mesh_clear()
bmesh.ops.triangulate(bm, faces=bm.faces[:])
print("RAW_TRIS", len(bm.faces), "MATS", MATLIST)

# ---------- 4. split into chunks by dominant bone ----------
def chunk_of(face, lay):
    acc = {}
    for v in face.verts:
        for gi, w in v[lay].items():
            acc[gi] = acc.get(gi, 0) + w
    bn = BONES[max(acc, key=acc.get)] if acc else "Koerper_V"
    if bn.startswith("WL_") or bn.startswith("WR_"):
        return "Fluegel"
    if bn in ("Koerper_V", "Kopf", "Kiefer") or bn.startswith("Hals") or bn.startswith("B_VArm") or bn.startswith("B_VHand"):
        return "Vorne"
    return "Hinten"

chunks = {}
for name in BUDGET:
    cb = bm.copy()
    cdl = cb.verts.layers.deform.verify()
    kill = [f for f in cb.faces if chunk_of(f, cdl) != name]
    bmesh.ops.delete(cb, geom=kill, context="FACES")
    me = bpy.data.meshes.new("Drache_" + name)
    cb.to_mesh(me); cb.free()
    for mn in MATLIST:
        me.materials.append(bpy.data.materials.get(mn))
    ob = bpy.data.objects.new("Drache_" + name, me)
    sc.collection.objects.link(ob)
    for bn in BONES:
        ob.vertex_groups.new(name=bn)
    tris = len(me.polygons)
    if tris > BUDGET[name]:
        d = ob.modifiers.new("Dec", "DECIMATE"); d.ratio = BUDGET[name] / tris
    chunks[name] = ob
bm.free()
dg = bpy.context.evaluated_depsgraph_get()
for name, ob in list(chunks.items()):
    e = ob.evaluated_get(dg)
    me2 = bpy.data.meshes.new_from_object(e, preserve_all_data_layers=True, depsgraph=dg)
    ob.modifiers.clear()
    old = ob.data; ob.data = me2; bpy.data.meshes.remove(old)
    print("CHUNK", name, len(me2.polygons))

# ---------- 5. UV unwrap ----------
for name, ob in chunks.items():
    for o in vl.objects:
        o.select_set(False)
    vl.objects.active = ob; ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")

# ---------- 6. bake (selected originals -> chunk) ----------
sc.render.engine = "CYCLES"
sc.cycles.samples = 4
sc.cycles.use_denoising = False
bk = sc.render.bake
bk.use_selected_to_active = True
bk.cage_extrusion = 0.03
bk.max_ray_distance = 0.12
bk.margin = 8
for m in body.modifiers:
    if m.type == "SUBSURF":
        m.show_viewport = True; m.show_render = True

dg = bpy.context.evaluated_depsgraph_get()
bake_srcs = []
for o in srcs:
    if o.type == "MESH":
        bake_srcs.append(o)
    else:
        e = o.evaluated_get(dg)
        try:
            me = bpy.data.meshes.new_from_object(e, depsgraph=dg)
        except Exception:
            continue
        t = bpy.data.objects.new("__bk_" + o.name, me)
        t.matrix_world = o.matrix_world.copy()
        sc.collection.objects.link(t)
        bake_srcs.append(t)
print("BAKE_SOURCES", len(bake_srcs))

def bake_into(ob, img, btype, **kw):
    for o in vl.objects:
        o.select_set(False)
    for o in bake_srcs:
        o.select_set(True)
    vl.objects.active = ob; ob.select_set(True)
    # target material nodes: each material gets an image node selected as bake target
    for mat in set(m for m in ob.data.materials if m):
        nt = mat.node_tree
        n = nt.nodes.get("__bake__") or nt.nodes.new("ShaderNodeTexImage")
        n.name = "__bake__"; n.image = img
        nt.nodes.active = n
    bpy.ops.object.bake(type=btype, **kw)

results = {}
for name, ob in chunks.items():
    col = bpy.data.images.new("col_" + name, TEX, TEX, alpha=False, float_buffer=True)
    emi = bpy.data.images.new("emi_" + name, TEX, TEX, alpha=False, float_buffer=True)
    bake_into(ob, col, "DIFFUSE", pass_filter={"COLOR"})
    bake_into(ob, emi, "EMIT")
    C = np.array(col.pixels[:], dtype=np.float32).reshape(-1, 4)[:, :3]
    E = np.array(emi.pixels[:], dtype=np.float32).reshape(-1, 4)[:, :3]
    lum = E.max(axis=1)
    pos = lum[lum > 0.05]
    ref = float(np.percentile(pos, 90)) if pos.size else 1.0
    mask = np.clip(lum / max(ref, 1e-4), 0, 1)
    ecol = E / np.maximum(lum, 1e-4)[:, None]
    out = C * (1 - mask[:, None]) + ecol * mask[:, None]
    out = np.clip(out, 0, 1) ** (1 / 2.2)  # linear -> sRGB
    for kind, data in (("color", out), ("emissive", np.repeat(mask[:, None] ** 0.8, 3, axis=1))):
        im = bpy.data.images.new(f"{kind}_{name}", TEX, TEX, alpha=False)
        im.colorspace_settings.name = "Non-Color"
        px = np.ones((TEX * TEX, 4), dtype=np.float32); px[:, :3] = data
        im.pixels.foreach_set(px.ravel())
        path = os.path.join(OUTDIR, f"drache_{kind}_{name.lower()}.png")
        im.filepath_raw = path; im.file_format = "PNG"; im.save()
    print("BAKED", name, "emissive_ref", round(ref, 3), "glow_px", int((mask > 0.3).sum()))

# ---------- 7. skin + export ----------
for name, ob in chunks.items():
    ob.parent = rig
    md = ob.modifiers.new("Armature", "ARMATURE"); md.object = rig
for o in vl.objects:
    o.select_set(False)
rig.select_set(True)
for ob in chunks.values():
    ob.select_set(True)
vl.objects.active = rig
bpy.ops.export_scene.gltf(filepath=os.path.join(OUTDIR, "lavadrache_rig.glb"), export_format="GLB",
                          use_selection=True, export_skins=True, export_animations=False,
                          export_materials="NONE", export_yup=True, export_apply=False)
bnds = [rig.matrix_world @ Vector(c) for ob in chunks.values() for c in ob.bound_box]
print("BOUNDS", [round(min(v[i] for v in bnds), 2) for i in range(3)], [round(max(v[i] for v in bnds), 2) for i in range(3)])
print("HEAD", tuple(round(x, 2) for x in B0["Kopf"].translation))
print("DONE")
