# Skorpion: Gelenk-Empties, glatter Metaball-Körper (direkt, keine Blöcke), Skelett + Bindung
import bpy, math
from mathutils import Vector, Matrix, Quaternion
D = bpy.data; C = bpy.context; sc = C.scene
K = 1.0 / 0.574          # metaball radius -> surface radius
SC = "Skorpion"
V = Vector


def coll(name):
    c = D.collections.get(name)
    if not c:
        c = D.collections.new(name); sc.collection.children.link(c)
    return c


def emp(name, loc, parent=None, size=0.25):
    o = D.objects.get(name)
    if o is None:
        o = D.objects.new(name, None); coll(SC).objects.link(o)
    o.empty_display_size = size; o.parent = None
    o.matrix_world = Matrix.Translation(V(loc))
    if parent:
        p = D.objects[parent] if isinstance(parent, str) else parent
        C.view_layer.update()
        mw = o.matrix_world.copy(); o.parent = p; o.matrix_parent_inverse = Matrix.Identity(4)
        C.view_layer.update(); o.matrix_world = mw
    return o


# ---------------- layout (world coordinates, scorpion faces +X) ----------------
TAIL = [V((-2.55, 0, 1.45)), V((-3.4, 0, 2.05)), V((-3.8, 0, 3.0)), V((-3.6, 0, 3.95)), V((-2.85, 0, 4.7)), V((-1.85, 0, 5.05))]
TAIL_R = [0.56, 0.52, 0.48, 0.45, 0.42]
LEG_X = [1.75, 1.3, 0.85, 0.35]
LEG_DX = [(0.6, 1.0, 1.25), (0.25, 0.45, 0.55), (-0.2, -0.35, -0.45), (-0.55, -0.95, -1.2)]


def claw_pts(s):
    return [V((2.1, s * 0.7, 1.2)), V((2.9, s * 1.75, 1.55)), V((3.6, s * 2.25, 1.15)), V((4.35, s * 2.35, 0.95))]


def leg_pts(s, i):
    hx = LEG_X[i]; dk, da, dt = LEG_DX[i]
    return [V((hx, s * 0.6, 1.0)), V((hx + dk * 0.8, s * 1.6, 2.45)), V((hx + da, s * 2.45, 0.8)), V((hx + dt, s * 2.95, 0.02))]


def build_rig():
    emp("Sk_Root", (0, 0, 0), size=1.0)
    emp("Sk_Koerper", (0, 0, 1.2), "Sk_Root", 0.6)
    emp("Sk_Kopf", (2.3, 0, 1.2), "Sk_Koerper", 0.3)
    prev = "Sk_Koerper"
    for i, p in enumerate(TAIL):
        emp(f"Sk_Schwanz_J{i}", p, prev, 0.3); prev = f"Sk_Schwanz_J{i}"
    for s, S in ((-1, "L"), (1, "R")):
        cp = claw_pts(s)
        emp(f"Sk_Schere_{S}0", cp[0], "Sk_Koerper"); emp(f"Sk_Schere_{S}1", cp[1], f"Sk_Schere_{S}0")
        emp(f"Sk_Schere_{S}2", cp[2], f"Sk_Schere_{S}1")
        for i in range(4):
            emp(f"Sk_Bein_{S}{i}", leg_pts(s, i)[0], "Sk_Root", 0.2)


# ---------------- metaball helpers ----------------
def cap(mb, a, b, r, stiff=2.0):
    a = V(a); b = V(b); d = b - a
    e = mb.elements.new(); e.type = 'CAPSULE'; e.co = (a + b) / 2
    e.rotation = V((1, 0, 0)).rotation_difference(d.normalized()); e.radius = r * K; e.size_x = d.length / 2; e.stiffness = stiff
    return e


def ell(mb, c, size, axis=V((1, 0, 0)), stiff=2.0):
    e = mb.elements.new(); e.type = 'ELLIPSOID'; e.co = V(c); e.radius = 1.0; e.stiffness = stiff
    e.rotation = V((1, 0, 0)).rotation_difference(V(axis).normalized())
    e.size_x, e.size_y, e.size_z = size[0] * K, size[1] * K, size[2] * K
    return e


def W(n):
    return D.objects[n].matrix_world.translation.copy()


def build_body_mesh(res=0.04):
    mb = D.metaballs.new("Sk_Koerper_MB"); mb.resolution = res; mb.render_resolution = res; mb.threshold = 0.6
    # prosoma (head/thorax) + mesosoma segments (overlap -> smooth body with soft segment ridges)
    ell(mb, (1.45, 0, 1.25), (1.2, 1.12, 0.6))
    ell(mb, (2.4, 0, 1.15), (0.45, 0.68, 0.4))           # front of head
    for k in range(7):
        x = 0.55 - k * 0.48; w = 1.25 - k * 0.06; h = 0.64 - k * 0.02
        ell(mb, (x, 0, 1.24 + k * 0.012), (0.34, w, h))
    cap(mb, (1.6, 0, 1.15), (-2.45, 0, 1.33), 0.52)           # continuous core
    # chelicerae
    for s in (-1, 1):
        cap(mb, (2.55, s * 0.2, 1.05), (2.95, s * 0.17, 0.98), 0.1)
    # tail: segment bulges + connecting core
    T = [W(f"Sk_Schwanz_J{i}") for i in range(6)]
    cap(mb, (-2.1, 0, 1.33), T[0], 0.62)
    for i in range(5):
        a, b = T[i], T[i + 1]; d = b - a; r = TAIL_R[i]
        cap(mb, a, b, r * 0.82)
        ell(mb, a.lerp(b, 0.5), (d.length * 0.42, r * 1.05, r * 1.0), axis=d)
    ell(mb, T[5] + (T[5] - T[4]).normalized() * 0.3, (0.6, 0.5, 0.48), axis=(T[5] - T[4]))   # telson bulb
    # pedipalps (claw arms) + hand
    for S in "LR":
        cp = [W(f"Sk_Schere_{S}{i}") for i in range(3)]
        s = -1 if S == "L" else 1
        hand = claw_pts(s)[3]
        cap(mb, cp[0], cp[1], 0.36); cap(mb, cp[1], cp[2], 0.34)
        cap(mb, cp[2], hand, 0.42)
        ell(mb, hand, (0.95, 0.6, 0.72), axis=(hand - cp[2]))
    # legs
    for S in "LR":
        s = -1 if S == "L" else 1
        for i in range(4):
            p = leg_pts(s, i)
            cap(mb, p[0], p[1], 0.2); cap(mb, p[1], p[2], 0.16); cap(mb, p[2], p[3] + V((0, 0, 0.18)), 0.11)
    mo = D.objects.new("Sk_Koerper_MB", mb); coll(SC).objects.link(mo)
    C.view_layer.update(); dg = C.evaluated_depsgraph_get()
    me = D.meshes.new_from_object(mo.evaluated_get(dg)); D.objects.remove(mo); D.metaballs.remove(mb)
    return me


def bones_list():
    bl = [("Koerper_V", V((2.5, 0, 1.15)), V((0.3, 0, 1.2)), "Sk_Koerper"),
          ("Koerper_H", V((0.3, 0, 1.2)), V((-2.4, 0, 1.3)), "Sk_Koerper"),
          ("Kopf", V((2.3, 0, 1.15)), V((3.0, 0, 1.0)), "Sk_Kopf")]
    for i in range(5):
        bl.append((f"Schwanz_{i}", W(f"Sk_Schwanz_J{i}"), W(f"Sk_Schwanz_J{i+1}"), f"Sk_Schwanz_J{i}"))
    t5 = W("Sk_Schwanz_J5"); bl.append(("Telson", t5, t5 + (t5 - W("Sk_Schwanz_J4")).normalized() * 0.7, "Sk_Schwanz_J5"))
    for S in "LR":
        s = -1 if S == "L" else 1
        cp = [W(f"Sk_Schere_{S}{i}") for i in range(3)]; hand = claw_pts(s)[3]
        bl += [(f"Arm_{S}0", cp[0], cp[1], f"Sk_Schere_{S}0"), (f"Arm_{S}1", cp[1], cp[2], f"Sk_Schere_{S}1"),
               (f"Hand_{S}", cp[2], hand + (hand - cp[2]).normalized() * 0.5, f"Sk_Schere_{S}2")]
        for i in range(4):
            p = leg_pts(s, i)
            for k in range(3):
                bl.append((f"Bein_{S}{i}_{k}", p[k], p[k + 1], f"Sk_Bein_{S}{i}"))
    return bl


def build_skeleton():
    old = D.objects.get("Sk_Skelett")
    if old:
        ad = old.data; D.objects.remove(old); D.armatures.remove(ad)
    bl = bones_list()
    ad = D.armatures.new("Sk_Skelett"); ad.display_type = 'STICK'
    arm = D.objects.new("Sk_Skelett", ad); coll(SC).objects.link(arm)
    for o in C.selected_objects: o.select_set(False)
    C.view_layer.objects.active = arm; arm.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for n, h, t, _ in bl:
        b = ad.edit_bones.new(n); b.head = h; b.tail = t
    bpy.ops.object.mode_set(mode='OBJECT')
    C.view_layer.update()
    for n, h, t, tgt in bl:
        con = arm.pose.bones[n].constraints.new('CHILD_OF'); con.target = D.objects[tgt]
    C.view_layer.update()
    for pb in arm.pose.bones:
        con = pb.constraints[0]; con.inverse_matrix = con.target.matrix_world.inverted()
    C.view_layer.update()
    arm.select_set(False)
    return arm


def build_and_bind():
    sc.frame_set(1); C.view_layer.update()
    me = build_body_mesh()
    arm = build_skeleton()
    body = D.objects.get("Sk_Koerper_Mesh")
    if body:
        om = body.data; D.objects.remove(body); D.meshes.remove(om)
    me.name = "Sk_Koerper_Mesh"; body = D.objects.new("Sk_Koerper_Mesh", me); coll(SC).objects.link(body)
    me.materials.append(D.materials["Sk_Panzer"]); me.materials.append(D.materials["Sk_Kristall"]); me.shade_smooth()
    # bake smoothing + stone displacement (static), subdivision render-only
    tex = D.textures.get("Sk_Displace") or D.textures.new("Sk_Displace", 'CLOUDS'); tex.noise_scale = 0.35; tex.noise_depth = 3
    sm = body.modifiers.new("Glaetten", 'SMOOTH'); sm.factor = 0.6; sm.iterations = 4
    dm = body.modifiers.new("Displace", 'DISPLACE'); dm.texture = tex; dm.texture_coords = 'OBJECT'; dm.strength = 0.035
    for nm in ("Glaetten", "Displace"):
        with C.temp_override(object=body, active_object=body, selected_objects=[body]):
            bpy.ops.object.modifier_apply(modifier=nm)
    for o in C.selected_objects: o.select_set(False)
    body.select_set(True); arm.select_set(True); C.view_layer.objects.active = arm
    with C.temp_override(active_object=arm, object=arm, selected_objects=[body, arm], selected_editable_objects=[body, arm]):
        bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    for o in C.selected_objects: o.select_set(False)
    ss = body.modifiers.new("Unterteilen", 'SUBSURF'); ss.levels = 0; ss.render_levels = 1
    # crystal material on the claw hands
    gis = [body.vertex_groups[f"Hand_{S}"].index for S in "LR"]
    w = [0.0] * len(me.vertices)
    for v in me.vertices:
        for g in v.groups:
            if g.group in gis: w[v.index] = max(w[v.index], g.weight)
    for p in me.polygons:
        p.material_index = 1 if sum(w[i] for i in p.vertices) / len(p.vertices) > 0.5 else 0
    return body
