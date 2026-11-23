import bpy, re, numpy as np
from mathutils import Vector, Matrix
D = bpy.data; C = bpy.context
K = 1.0 / 0.574
PAT = re.compile(r"^(Brust|Bauch|Huefte|Ruecken|Hals_\d|VArm_[OU]_[LR]|Ellbogen_[LR]|HBein_[OMU]_[LR]|Knie_[LR]|VHand_[LR]_(Ballen|Zeh_\d)|HFuss_[LR]_(Ballen|Zeh_\d)|Schaedel|Hinterkopf|Schnauze|Nasenruecken|Nasenspitze|Wange_[LR]|Braue_[LR])$")
HEADBOX = {"Schaedel", "Hinterkopf", "Schnauze", "Nasenspitze", "Nasenruecken", "Unterkiefer"}
BLOBS = ("Brust", "Bauch", "Huefte", "Ruecken", "Hals_", "Ellbogen", "Knie")


def world_pts(o, dg):
    me = D.meshes.new_from_object(o.evaluated_get(dg))
    pts = np.array([o.matrix_world @ v.co for v in me.vertices]); D.meshes.remove(me)
    return pts


def pca(pts):
    c = pts.mean(axis=0); X = pts - c
    w, vecs = np.linalg.eigh(X.T @ X); vecs = vecs[:, np.argsort(w)[::-1]]
    ax0 = Vector(vecs[:, 0]); ax1 = Vector(vecs[:, 1]); ax2 = ax0.cross(ax1).normalized()
    vecs = np.array([ax0, ax1, ax2]).T
    return c, vecs, X @ vecs


def add_elements(mb, o, dg, fit=None):
    pts = world_pts(o, dg)
    c, vecs, proj = pca(pts)
    q = Matrix((Vector(vecs[:, 0]), Vector(vecs[:, 1]), Vector(vecs[:, 2]))).transposed().to_quaternion()
    ext = (proj.max(axis=0) - proj.min(axis=0)) / 2
    name = o.name
    if name in HEADBOX:
        # chain of rounded boxes following the taper
        lo, hi = proj[:, 0].min(), proj[:, 0].max(); L = hi - lo
        endA = proj[proj[:, 0] < lo + 0.25 * L]; endB = proj[proj[:, 0] > hi - 0.25 * L]
        eA = (endA[:, 1:].max(axis=0) - endA[:, 1:].min(axis=0)) / 2
        eB = (endB[:, 1:].max(axis=0) - endB[:, 1:].min(axis=0)) / 2
        mA = (endA[:, 1:].max(axis=0) + endA[:, 1:].min(axis=0)) / 2
        mB = (endB[:, 1:].max(axis=0) + endB[:, 1:].min(axis=0)) / 2
        n = max(2, int(round(L / (min(eA.min(), eB.min()) * 1.2))))
        n = min(n, 8)
        for k in range(n):
            t = (k + 0.5) / n
            e2 = eA * (1 - t) + eB * t; m2 = mA * (1 - t) + mB * t
            rr = min(0.1, e2.min() * 0.45)
            pos = Vector(c) + Vector(vecs[:, 0]) * (lo + L * t) + Vector(vecs[:, 1]) * m2[0] + Vector(vecs[:, 2]) * m2[1]
            e = mb.elements.new(); e.type = 'CUBE'; e.co = pos; e.rotation = q; e.stiffness = 2.0
            e.radius = rr * K
            e.size_x = max(L / n / 2 + 0.02 - rr * 0.5, 0.005)
            e.size_y = max(e2[0] - rr, 0.005); e.size_z = max(e2[1] - rr, 0.005)
        return
    blob = name in ("Brust", "Bauch", "Huefte", "Ruecken") or name.startswith(BLOBS[4:])
    e = mb.elements.new(); e.co = Vector(c); e.rotation = q; e.stiffness = 2.0
    if blob or ext[0] < 1.6 * ext[1]:
        f = 1.0 if blob else 0.88
        e.type = 'ELLIPSOID'; e.radius = 1.0
        e.size_x, e.size_y, e.size_z = ext[0] * K * f, ext[1] * K * f, ext[2] * K * f
    else:
        r = (ext[1] + ext[2]) / 2 * 0.95
        e.type = 'CAPSULE'; e.radius = r * K; e.size_x = max(ext[0] - r * 0.6, 0.01)


def add_capsule(mb, a, b, r):
    a = Vector(a); b = Vector(b); d = b - a
    e = mb.elements.new(); e.type = 'CAPSULE'; e.co = (a + b) / 2
    e.rotation = Vector((1, 0, 0)).rotation_difference(d.normalized())
    e.radius = r * K; e.size_x = d.length / 2; e.stiffness = 2.0


def metaball_mesh(name, objs, extra=None, res=0.045):
    dg = C.evaluated_depsgraph_get()
    mb = D.metaballs.new(name + "_MB"); mb.resolution = res; mb.render_resolution = res; mb.threshold = 0.6
    for o in objs:
        add_elements(mb, o, dg)
    if extra: extra(mb)
    mo = D.objects.new(name + "_MB", mb); D.collections["Drache"].objects.link(mo)
    C.view_layer.update(); dg = C.evaluated_depsgraph_get()
    me = D.meshes.new_from_object(mo.evaluated_get(dg))
    D.objects.remove(mo); D.metaballs.remove(mb)
    return me


def tail_extra(mb):
    js = [D.objects[f"Schwanz_J{i}"] for i in range(12)]
    P = [j.matrix_world.translation.copy() for j in js]
    P.append(P[-1] + (P[-1] - P[-2]) * 0.9)
    R = [j["r"] * 0.62 for j in js] + [0.06]
    add_capsule(mb, Vector((-1.6, 0, 2.4)), P[0], 0.72)
    for i in range(12):
        a, b = P[i], P[i + 1]; m = (a + b) / 2
        add_capsule(mb, a, m, R[i]); add_capsule(mb, m, b, (R[i] + R[i + 1]) / 2)
