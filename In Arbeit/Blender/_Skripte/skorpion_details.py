# Skorpion: Scheren-Klingen, Stachel, Augen, Kopfkrone, Panzerplatten in Reihen, Stacheln (alles auf die Haut gesetzt)
import bpy, math
SK = r"C:\Users\finns\OneDrive\Desktop\Claude\Games\In Arbeit\Blender\_Skripte"
exec(open(SK + r"\dragon_helpers.py", encoding="utf-8").read())
exec(open(SK + r"\skorpion_body.py", encoding="utf-8").read())
from mathutils import Vector, Matrix
DC = "Skorpion"; SC = "Skorpion"
sc.frame_set(1); C.view_layer.update()
body = D.objects["Sk_Koerper_Mesh"]
dg = C.evaluated_depsgraph_get(); be = body.evaluated_get(dg); BW = be.matrix_world; BI = BW.inverted()
UP = Vector((0, 0, 1))


def cast(origin, direction, dist=10.0):
    hit, loc, nrm, idx = be.ray_cast(BI @ origin, (BI.to_3x3() @ direction).normalized(), distance=dist)
    if not hit: return None, None
    return BW @ loc, (BW.to_3x3() @ nrm).normalized()


def remove(prefixes):
    for o in list(D.objects):
        if o.name.startswith(prefixes): D.objects.remove(o, do_unlink=True)


def profile_obj(r):
    # bevel-object profile is used at real size (bevel_depth is ignored), so build one per blade width
    nm = f"Sk_Klingen_Profil_{int(r * 100)}"
    o = D.objects.get(nm)
    if o: return o
    cu = D.curves.new(nm, 'CURVE'); sp = cu.splines.new('NURBS'); pts = []
    for k in range(8):
        a = 2 * math.pi * k / 8; pts.append((math.cos(a) * r, math.sin(a) * r * 0.32, 0, 1))
    sp.points.add(len(pts) - 1)
    for p, c in zip(sp.points, pts): p.co = c
    sp.use_cyclic_u = True; sp.order_u = 3
    o = D.objects.new(nm, cu); coll("Hilfsobjekte").objects.link(o); o.hide_viewport = o.hide_render = True
    return o


def blade(name, pts, r, mat, parent, tilt=0.0):
    ob = curve_obj(name, [tuple(p) for p in pts], bevel=r, cname=SC, m=mat, ctype='BEZIER', res=16)
    ob.data.bevel_mode = 'OBJECT'; ob.data.bevel_object = profile_obj(r); ob.data.use_fill_caps = True
    ob.data.taper_object = taper_obj()
    for bp in ob.data.splines[0].bezier_points: bp.tilt = tilt
    keep_parent(ob, parent)
    return ob


def build_claws_stinger():
    remove(("Sk_Klinge_", "Sk_Finger_", "Sk_Stachel_"))
    for s, S in ((-1, "L"), (1, "R")):
        cp = [W(f"Sk_Schere_{S}{i}") for i in range(3)]; H = claw_pts(s)[3]
        f = (H - cp[2]); f.z = 0; f.normalize()
        sv = UP.cross(f).normalized() * (-s)     # points outward
        # roots start inside the hand (x0.25) so the blades grow out of it
        b0 = H + f * 0.25 + sv * 0.22 + UP * 0.1
        blade(f"Sk_Klinge_Fix_{S}", [b0, b0 + f * 1.0 + sv * 0.42 - UP * 0.05, b0 + f * 2.0 - sv * 0.15 - UP * 0.85], 0.46, "Sk_Kristall", f"Sk_Schere_{S}2", tilt=0.0)
        piv = emp(f"Sk_Finger_{S}", H + f * 0.25 - sv * 0.25, f"Sk_Schere_{S}2", 0.2)
        m0 = H + f * 0.25 - sv * 0.25 + UP * 0.05
        blade(f"Sk_Klinge_Beweg_{S}", [m0, m0 + f * 1.0 - sv * 0.45 - UP * 0.1, m0 + f * 1.9 + sv * 0.12 - UP * 0.8], 0.4, "Sk_Kristall", piv, tilt=0.0)
    # stinger
    t4, t5 = W("Sk_Schwanz_J4"), W("Sk_Schwanz_J5"); d = (t5 - t4).normalized()
    base = t5 + d * 0.45
    s1 = horn("Sk_Stachel_Spitze", [tuple(base), tuple(base + d * 0.75 - UP * 0.15), tuple(base + d * 1.05 - UP * 0.85)], 0.24, m="Sk_Stachel")
    s1.data.resolution_u = 16; s1.data.bevel_resolution = 6
    keep_parent(s1, "Sk_Schwanz_J5")


def shell(name, hit, nrm, t, L, w, th, mat, parent):
    tt = (t - nrm * nrm.dot(t)).normalized()
    p0 = hit - tt * L * 0.4 - nrm * 0.03; p1 = hit + tt * L * 0.6 + nrm * 0.03
    pl = frustum(name, p0, p1, w, th, w * 0.8, th * 0.7, cname=SC, m=mat, bevel=th * 0.45, up=nrm)
    smooth_box(pl, 2); keep_parent(pl, parent)
    return pl


def build_plates_spikes():
    remove(("Sk_Platte_", "Sk_Dorn_", "Sk_Auge_", "Sk_Krone_"))
    n = 0
    back = Vector((-1, 0, 0))
    # carapace (prosoma): 3x3 plates
    for ix, x in enumerate((2.25, 1.75, 1.25, 0.8)):
        for a in (-55, -20, 20, 55):
            th = math.radians(a); d = UP * math.cos(th) + Vector((0, math.sin(th), 0))
            hit, nrm = cast(Vector((x, 0, 1.2)) + d * 3, -d)
            if hit is None: continue
            shell(f"Sk_Platte_{n:03d}", hit, nrm, back, 0.55, 0.5, 0.09, "Sk_Platte", "Sk_Koerper"); n += 1
    # mesosoma tergites: one row of 5 plates per segment, overlapping backwards
    for k in range(7):
        x = 0.55 - k * 0.48
        for a in (-68, -34, 0, 34, 68):
            th = math.radians(a); d = UP * math.cos(th) + Vector((0, math.sin(th), 0))
            hit, nrm = cast(Vector((x, 0, 1.25)) + d * 3, -d)
            if hit is None: continue
            w = 0.62 if a == 0 else 0.52
            shell(f"Sk_Platte_{n:03d}", hit, nrm, back, 0.5, w, 0.1, "Sk_Platte", "Sk_Koerper"); n += 1
    # tail segments: top + 2 side plates, dorsal ridge spike
    T = [W(f"Sk_Schwanz_J{i}") for i in range(6)]
    for i in range(5):
        a, b = T[i], T[i + 1]; c = a.lerp(b, 0.5); t = (b - a).normalized()
        up = (UP - t * t.dot(UP)); up = up.normalized() if up.length > 0.1 else Vector((-1, 0, 0))
        if i >= 3: up = (Vector((-1, 0, 0.6)) - t * t.dot(Vector((-1, 0, 0.6)))).normalized()
        side = t.cross(up).normalized()
        for ang in (-60, 0, 60):
            th = math.radians(ang); d = up * math.cos(th) + side * math.sin(th)
            hit, nrm = cast(c + d * 3, -d)
            if hit is None: continue
            shell(f"Sk_Platte_{n:03d}", hit, nrm, -t, (b - a).length * 0.75, 0.55 if ang == 0 else 0.45, 0.1, "Sk_Platte", f"Sk_Schwanz_J{i}"); n += 1
        hit, nrm = cast(c + up * 3, -up)
        if hit is not None:
            sp = spike(f"Sk_Dorn_S{i}", hit - nrm * 0.05, hit + (nrm * 0.8 - t * 0.6).normalized() * (0.55 - i * 0.05), 0.12, m="Sk_Platte", verts=5)
            keep_parent(sp, f"Sk_Schwanz_J{i}")
    # back spikes: two rows along mesosoma edges + a central small row
    for k in range(7):
        x = 0.55 - k * 0.48
        for a, L, r in ((-72, 0.45, 0.1), (72, 0.45, 0.1), (0, 0.32, 0.09)):
            th = math.radians(a); d = UP * math.cos(th) + Vector((0, math.sin(th), 0))
            hit, nrm = cast(Vector((x, 0, 1.25)) + d * 3, -d)
            if hit is None: continue
            sp = spike(f"Sk_Dorn_R{k}_{a}", hit - nrm * 0.04, hit + (nrm * 0.85 + back * 0.5).normalized() * L, r, m="Sk_Platte", verts=5)
            keep_parent(sp, "Sk_Koerper")
    # head crown: tall spikes rising up/back from the carapace front, V-shaped face plates
    for j, (yy, L) in enumerate(((0, 0.9), (0.28, 0.7), (-0.28, 0.7), (0.55, 0.5), (-0.55, 0.5))):
        hit, nrm = cast(Vector((2.05, yy, 3)), -UP)
        if hit is None: continue
        sp = spike(f"Sk_Krone_{j}", hit - nrm * 0.05, hit + (UP * 0.9 + back * 0.35 + Vector((0, yy * 0.5, 0))).normalized() * L, 0.13, m="Sk_Platte", verts=5)
        keep_parent(sp, "Sk_Kopf")
    # eyes: two median + 3 lateral per side (glowing)
    for nm, (x, y) in (("M_L", (2.15, -0.16)), ("M_R", (2.15, 0.16))):
        hit, nrm = cast(Vector((x, y, 3)), -UP)
        if hit is None: continue
        e = ico(f"Sk_Auge_{nm}", hit + nrm * 0.02, (0.09, 0.07, 0.05), sub=2, cname=SC, m="Sk_Augen"); keep_parent(e, "Sk_Kopf")
    for s, S in ((-1, "L"), (1, "R")):
        for j in range(3):
            d = Vector((0.6, s * 0.8, 0.3)).normalized()
            hit, nrm = cast(Vector((2.45 - j * 0.12, 0, 1.25)) + d * 3, -d)
            if hit is None: continue
            e = ico(f"Sk_Auge_{S}{j}", hit + nrm * 0.015, (0.05, 0.04, 0.035), sub=2, cname=SC, m="Sk_Augen"); keep_parent(e, "Sk_Kopf")
    # leg spikes (knee + tibia) and arm spikes
    for s, S in ((-1, "L"), (1, "R")):
        for i in range(4):
            p = leg_pts(s, i)
            for k, (pa, pb) in enumerate(((p[1], p[2]), (p[0], p[1]))):
                c = pa.lerp(pb, 0.35); t = (pb - pa).normalized(); out = (Vector((0, s, 0.6)) - t * t.dot(Vector((0, s, 0.6)))).normalized()
                hit, nrm = cast(c + out * 2, -out)
                if hit is None: continue
                sp = spike(f"Sk_Dorn_B{S}{i}{k}", hit - nrm * 0.03, hit + (nrm + t * 0.4).normalized() * 0.3, 0.06, m="Sk_Platte", verts=4)
                keep_parent(sp, f"Sk_Bein_{S}{i}")
        cp = [W(f"Sk_Schere_{S}{i}") for i in range(3)]
        for k in range(2):
            c = cp[k].lerp(cp[k + 1], 0.5); t = (cp[k + 1] - cp[k]).normalized()
            out = (UP - t * t.dot(UP)).normalized()
            hit, nrm = cast(c + out * 2, -out)
            if hit is None: continue
            sp = spike(f"Sk_Dorn_A{S}{k}", hit - nrm * 0.04, hit + (nrm - t * 0.3).normalized() * 0.42, 0.1, m="Sk_Platte", verts=5)
            keep_parent(sp, f"Sk_Schere_{S}{k}")
    return n
