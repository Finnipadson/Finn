import bpy
exec(open(r"C:\Users\finns\OneDrive\Desktop\Claude\Games\In Arbeit\Blender\_Skripte\dragon_smooth.py", encoding="utf-8").read())
from mathutils import Matrix
sc = C.scene; sc.frame_set(1)
PANZER = ["Schulterpanzer_L", "Schulterpanzer_R", "Oberschenkelpanzer_L", "Oberschenkelpanzer_R"]
allparts = [o for o in D.objects if o.type == 'MESH' and PAT.match(o.name)] + [D.objects[n] for n in PANZER]
parts = [o for o in allparts if "_Zeh_" not in o.name]
for o in allparts: o.hide_viewport = False
C.view_layer.update(); dg = C.evaluated_depsgraph_get()
_orig_add = add_elements


def add_elements(mb, o, dg, fit=None):
    n0 = len(mb.elements)
    _orig_add(mb, o, dg)
    new = list(mb.elements)[n0:]
    if o.name.startswith(("Knie", "Ellbogen")):
        for e in new: e.size_x *= 0.62; e.size_y *= 0.62; e.size_z *= 0.62
    if o.name.endswith("_Ballen"):
        for e in new:
            if e.type == 'ELLIPSOID':
                e.size_y *= 0.78; e.size_z *= 0.72; e.size_x *= 0.9
            else:
                e.radius *= 0.78
    if o.name in PANZER:
        for e in new:
            e.type = 'ELLIPSOID'; e.radius = 1.0
            # thick muscle pad instead of flat plate
            e.size_x *= 0.85; e.size_y *= 0.85; e.size_z = max(e.size_z, 0.32 * K)


def bottom_end(n):
    pts = world_pts(D.objects[n], dg); c, vecs, proj = pca(pts)
    ax = Vector(vecs[:, 0]); a = Vector(c) + ax * proj[:, 0].min(); b = Vector(c) + ax * proj[:, 0].max()
    return a if a.z < b.z else b


def extra(mb):
    js = [D.objects[f"Schwanz_J{i}"] for i in range(12)]
    P = [j.matrix_world.translation.copy() for j in js]
    P.append(P[-1] + (P[-1] - P[-2]) * 0.9)
    TS = 0.85  # tail thickness factor
    R = [j["r"] * 0.62 * TS for j in js] + [0.05]
    hip = Vector((-1.5, 0, 2.35))
    # smooth funnel from hip into the tail (fills the bend)
    add_capsule(mb, hip, P[0], 0.72 * TS)
    add_capsule(mb, hip.lerp(P[0], 0.5), P[1], 0.55 * TS)
    add_capsule(mb, P[0], P[2], 0.47 * TS)
    for i in range(12):
        a, b = P[i], P[i + 1]; m = (a + b) / 2
        add_capsule(mb, a, m, R[i]); add_capsule(mb, m, b, (R[i] + R[i + 1]) / 2)
    # fill the groove between shoulder/thigh pads, upper legs and the torso
    for pn in PANZER:
        pc = Vector(world_pts(D.objects[pn], dg).mean(axis=0))
        inner = Vector((pc.x, pc.y * 0.35, pc.z + 0.1))
        add_capsule(mb, inner, pc * 0.15 + inner * 0.85 + (pc - inner) * 0.6, 0.5)
        leg = ("VArm_O_" if pn.startswith("Schulter") else "HBein_O_") + pn[-1]
        lp = world_pts(D.objects[leg], dg); top = Vector(lp[lp[:, 2].argmax()])
        add_capsule(mb, pc - Vector((0, pc.y * 0.15, 0)), top.lerp(Vector(lp.mean(axis=0)), 0.6), 0.42)
    import re as _re
    # toes grow out of the foot: each toe = tapered chain from inside the palm to the claw root
    for S in "LR":
        for foot, rt in ((f"VHand_{S}", 0.115), (f"HFuss_{S}", 0.105)):
            pal = D.objects[foot + "_Ballen"]
            pc = sum((pal.matrix_world @ Vector(v) for v in pal.bound_box), Vector()) / 8
            roots = []
            for k in range(4):
                cl = D.objects[f"{foot}_Kralle_{k}"]; bp = cl.data.splines[0].bezier_points
                b0 = cl.matrix_world @ bp[0].co; b1 = cl.matrix_world @ bp[1].co
                roots.append((b0, (b1 - b0).normalized()))
            mean_root = sum((r[0] for r in roots), Vector()) / 4
            # broad metacarpal pad bridging palm and toes
            add_capsule(mb, pc, pc.lerp(mean_root, 0.55), rt * 1.7)
            for b0, d in roots:
                start = pc.lerp(b0, 0.25) + Vector((0, 0, 0.04))
                mid = pc.lerp(b0, 0.65) + Vector((0, 0, 0.03))
                add_capsule(mb, start, mid, rt * 1.35)
                add_capsule(mb, mid, b0 + d * 0.05, rt * 1.05)
    for o in D.objects:
        if _re.match(r"^(VHand|HFuss)_[LR]_Kralle_\d$", o.name):
            bp = o.data.splines[0].bezier_points
            b0 = o.matrix_world @ bp[0].co; b1 = o.matrix_world @ bp[1].co
            d = (b1 - b0).normalized(); r = o.data.bevel_depth
            # sheath: toe flesh tapering over the claw root
            add_capsule(mb, b0 - d * 0.05, b0 + d * 0.2, r * 1.25)
    for S in "LR":
        # thicken the elbow so upper arm and forearm flow together
        elb = D.objects[f"Ellbogen_{S}"].matrix_world.translation.copy()
        uo = world_pts(D.objects[f"VArm_O_{S}"], dg).mean(axis=0); uu = world_pts(D.objects[f"VArm_U_{S}"], dg).mean(axis=0)
        add_capsule(mb, Vector(uo), elb, 0.38)
        add_capsule(mb, elb, Vector(uu), 0.33)
        for leg, foot, r in ((f"VArm_U_{S}", f"VHand_{S}_Ballen", 0.27), (f"HBein_U_{S}", f"HFuss_{S}_Ballen", 0.24)):
            a = bottom_end(leg)
            fo = D.objects[foot]; fc = sum((fo.matrix_world @ Vector(v) for v in fo.bound_box), Vector()) / 8
            add_capsule(mb, a + Vector((0, 0, 0.12)), fc + Vector((-0.05, 0, 0.08)), r)
            add_capsule(mb, a + Vector((0, 0, 0.05)), a + Vector((0.08, 0, -0.05)), r * 1.15)


me = metaball_mesh("Drachenkoerper_neu", parts, extra)
for o in allparts: o.hide_viewport = True; o.hide_render = True
body = D.objects["Drachenkoerper"]; arm = D.objects["Drache_Skelett"]
old = body.data
for m in [m for m in body.modifiers if m.type == 'ARMATURE']: body.modifiers.remove(m)
body.vertex_groups.clear(); body.parent = None; body.matrix_world = Matrix.Identity(4)
me.materials.clear(); me.materials.append(D.materials["Drachenstein"]); me.materials.append(D.materials["Kopfstein"]); me.shade_smooth()
body.data = me; D.meshes.remove(old); me.name = "Drachenkoerper"
# bake smoothing + stone displacement into the mesh (static, before rigging)
for nm, tp in (("Glaetten", 'SMOOTH'), ("Displace", 'DISPLACE')):
    m0 = body.modifiers.get(nm)
    if m0: body.modifiers.remove(m0)
sm = body.modifiers.new("Glaetten", 'SMOOTH'); sm.factor = 0.6; sm.iterations = 4
dm = body.modifiers.new("Displace", 'DISPLACE'); dm.texture = D.textures["Stein_Displace"]; dm.texture_coords = 'OBJECT'; dm.strength = 0.06
for nm in ("Glaetten", "Displace"):
    with C.temp_override(object=body, active_object=body, selected_objects=[body]):
        bpy.ops.object.modifier_move_to_index(modifier=nm, index=0 if nm == "Glaetten" else 1)
        bpy.ops.object.modifier_apply(modifier=nm)
for o in C.selected_objects: o.select_set(False)
body.select_set(True); arm.select_set(True); C.view_layer.objects.active = arm
with C.temp_override(active_object=arm, object=arm, selected_objects=[body, arm], selected_editable_objects=[body, arm]):
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
gi = body.vertex_groups["Kopf"].index
w = [0.0] * len(me.vertices)
for v in me.vertices:
    for g in v.groups:
        if g.group == gi: w[v.index] = g.weight
for p in me.polygons:
    p.material_index = 1 if sum(w[i] for i in p.vertices) / len(p.vertices) > 0.5 else 0
for o in C.selected_objects: o.select_set(False)
ssm = body.modifiers.get("Unterteilen")
if ssm:
    with C.temp_override(object=body, active_object=body):
        bpy.ops.object.modifier_move_to_index(modifier="Unterteilen", index=len(body.modifiers) - 1)
C.view_layer.update()
# (spirals are baked onto the surface separately; no per-frame shrinkwrap)
# armour plates: snap onto new surface
inv = body.matrix_world.inverted(); moved = 0
for o in D.objects:
    if o.name.startswith("Platte_"):
        mw = o.matrix_world.copy(); p = mw.translation
        ok, cp, n, idx = body.closest_point_on_mesh(inv @ p)
        if ok:
            cpw = body.matrix_world @ cp; nw = (body.matrix_world.to_3x3() @ n).normalized()
            loc, rot, scl = mw.decompose(); o.matrix_world = Matrix.LocRotScale(cpw + nw * 0.02, rot, scl); moved += 1
print("verts", len(me.vertices), "plates", moved)
