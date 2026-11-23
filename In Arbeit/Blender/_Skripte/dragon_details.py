import bpy, math
exec(open(r"C:\Users\finns\OneDrive\Desktop\Claude\Games\In Arbeit\Blender\_Skripte\dragon_helpers.py", encoding="utf-8").read())
from mathutils import Vector, Matrix
sc = C.scene; sc.frame_set(1); C.view_layer.update()
body = D.objects["Drachenkoerper"]
dg = C.evaluated_depsgraph_get(); be = body.evaluated_get(dg)
BW = be.matrix_world; BI = BW.inverted()

def cast(origin, direction, dist=8.0):
    hit, loc, nrm, idx = be.ray_cast(BI @ origin, (BI.to_3x3() @ direction).normalized(), distance=dist)
    if not hit: return None, None
    return BW @ loc, (BW.to_3x3() @ nrm).normalized()

JOINTS = [D.objects[f"Hals_J{i}"] for i in range(5)] + [D.objects["Drache_Koerper"]] + [D.objects[f"Schwanz_J{i}"] for i in range(12)]

def nearest_joint(p):
    best = None; bd = 1e9
    for j in JOINTS:
        q = j.matrix_world.translation
        if j.name == "Drache_Koerper":
            if -2.2 < p.x < 1.8: return j
            continue
        d = (p - q).length
        if d < bd: bd = d; best = j
    return best

def remove(prefixes):
    n = 0
    for o in list(D.objects):
        if o.name.startswith(prefixes):
            D.objects.remove(o, do_unlink=True); n += 1
    return n

# ---------- spine path (head -> tail tip) ----------
W = lambda n: D.objects[n].matrix_world.translation.copy()
path = [W(f"Hals_J{i}") for i in (4, 3, 2, 1, 0)] + [Vector((0.6, 0, 2.95)), Vector((-1.0, 0, 2.95))] + [W(f"Schwanz_J{i}") for i in range(12)]
path.append(path[-1] + (path[-1] - path[-2]) * 0.9)
seg = [(path[i + 1] - path[i]).length for i in range(len(path) - 1)]
TOT = sum(seg)

def sample(s):
    s = max(0.0, min(TOT - 1e-4, s))
    for i, L in enumerate(seg):
        if s <= L:
            t = s / L; p = path[i].lerp(path[i + 1], t)
            tan = (path[i + 1] - path[i]).normalized()
            return p, tan
        s -= L
    return path[-1], (path[-1] - path[-2]).normalized()
