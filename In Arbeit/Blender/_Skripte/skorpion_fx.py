# Skorpion: Kristallsplitter, kreisende Ketten, violetter Nebel, Lichter + Animations-Drivers (Loop 300 Frames @ 60 fps)
import bpy, bmesh, math, random
from mathutils import Vector, Matrix
D = bpy.data; C = bpy.context; sc = C.scene
FX = "Skorpion_FX"


def coll(name):
    c = D.collections.get(name)
    if not c:
        c = D.collections.new(name); sc.collection.children.link(c)
    return c


def drv(idb, path, idx, expr, var=None):
    fc = idb.driver_add(path, idx) if idx >= 0 else idb.driver_add(path)
    d = fc.driver; d.type = 'SCRIPTED'
    for v in list(d.variables): d.variables.remove(v)
    if var:
        v = d.variables.new(); v.name = var[0]; v.type = 'SINGLE_PROP'; v.targets[0].id = var[1]; v.targets[0].data_path = var[2]
    d.expression = expr
    return fc


def clear_fx():
    c = D.collections.get(FX)
    if c:
        for o in list(c.objects): D.objects.remove(o, do_unlink=True)


def shard_mesh():
    me = D.meshes.get("Sk_Splitter_Mesh")
    if me: return me
    bm = bmesh.new()
    top = bm.verts.new((0, 0, 1)); bot = bm.verts.new((0, 0, -1))
    ring = [bm.verts.new((math.cos(a) * 0.35, math.sin(a) * 0.25, 0.1)) for a in [k * 2 * math.pi / 5 for k in range(5)]]
    for k in range(5):
        bm.faces.new((top, ring[k], ring[(k + 1) % 5])); bm.faces.new((bot, ring[(k + 1) % 5], ring[k]))
    me = D.meshes.new("Sk_Splitter_Mesh"); bm.to_mesh(me); bm.free(); me.materials.append(D.materials["Sk_Splitter"])
    return me


def chain_link_mesh():
    me = D.meshes.get("Sk_Kettenglied")
    if me: return me
    bm = bmesh.new()
    for k, rot in enumerate((0, 90)):
        geom = bmesh.ops.create_circle(bm, cap_ends=False, segments=16, radius=1.0)
        # build a torus manually: sweep small circles along an oval
    bm.free()
    bm = bmesh.new(); R, r, segM, segm = 0.13, 0.032, 16, 6
    def link(off, rotx):
        verts = []
        for i in range(segM):
            a = 2 * math.pi * i / segM
            cx, cy = math.cos(a) * R * 1.55, math.sin(a) * R
            nx, ny = math.cos(a), math.sin(a) * 1.55; nl = math.hypot(nx, ny); nx /= nl; ny /= nl
            row = []
            for j in range(segm):
                b = 2 * math.pi * j / segm
                p = Vector((cx + nx * r * math.cos(b), cy + ny * r * math.cos(b), r * math.sin(b)))
                if rotx: p = Matrix.Rotation(math.pi / 2, 3, 'X') @ p
                row.append(bm.verts.new(p + Vector((off, 0, 0))))
            verts.append(row)
        for i in range(segM):
            for j in range(segm):
                bm.faces.new((verts[i][j], verts[(i + 1) % segM][j], verts[(i + 1) % segM][(j + 1) % segm], verts[i][(j + 1) % segm]))
    link(0.0, False); link(0.33, True)
    me = D.meshes.new("Sk_Kettenglied"); bm.to_mesh(me); bm.free(); me.materials.append(D.materials["Sk_Kette"])
    for p in me.polygons: p.use_smooth = True
    return me


def chain_ring(name, center, rx, ry, tilt, parent=None, spin=1):
    pivot = D.objects.new(name + "_Dreh", None); coll(FX).objects.link(pivot); pivot.empty_display_size = 0.5
    pivot.location = center; pivot.rotation_euler = tilt
    if parent:
        C.view_layer.update(); mw = pivot.matrix_world.copy(); pivot.parent = D.objects[parent]
        pivot.matrix_parent_inverse = Matrix.Identity(4); C.view_layer.update(); pivot.matrix_world = mw
    drv(pivot, "rotation_mode", -1, "0") if False else None
    # spin via a child empty around local Z
    spinner = D.objects.new(name + "_Spin", None); coll(FX).objects.link(spinner); spinner.parent = pivot
    drv(spinner, "rotation_euler", 2, f"{spin}*frame*2*pi/300")
    cu = D.curves.new(name + "_Bahn", 'CURVE'); sp = cu.splines.new('NURBS'); n = 24
    sp.points.add(n - 1)
    for k, p in enumerate(sp.points):
        a = 2 * math.pi * k / n; p.co = (math.cos(a) * rx, math.sin(a) * ry, 0.15 * math.sin(3 * a), 1)
    sp.use_cyclic_u = True; sp.order_u = 4
    path = D.objects.new(name + "_Bahn", cu); coll(FX).objects.link(path); path.parent = spinner; path.hide_render = True
    lk = D.objects.new(name, chain_link_mesh()); coll(FX).objects.link(lk); lk.parent = spinner
    ar = lk.modifiers.new("Reihe", 'ARRAY'); ar.fit_type = 'FIT_CURVE'; ar.curve = path; ar.relative_offset_displace = (1.0, 0, 0)
    cm = lk.modifiers.new("Bahn", 'CURVE'); cm.object = path; cm.deform_axis = 'POS_X'
    return lk


def build_fx():
    clear_fx(); rnd = random.Random(9)
    cam = D.objects["Camera"]; cang = math.atan2(cam.location.y, cam.location.x)
    # floating dark crystal shards
    for i in range(24):
        while True:
            a = rnd.uniform(0, 2 * math.pi); z = rnd.uniform(1.0, 6.0)
            dd = abs((a - cang + math.pi) % (2 * math.pi) - math.pi)
            if dd > math.radians(40) or z > 4.5: break
        r = rnd.uniform(4.5, 7.5); s = rnd.uniform(0.18, 0.4)
        o = D.objects.new(f"Sk_Splitter_{i:02d}", shard_mesh()); coll(FX).objects.link(o)
        o.location = (math.cos(a) * r - 0.3, math.sin(a) * r * 0.85, z); o.scale = (s, s, s * rnd.uniform(1.3, 2.2))
        o.rotation_euler = (rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), rnd.uniform(0, 6))
        drv(o, "location", 2, f"{z:.3f}+0.22*sin(frame*2*pi/150*{rnd.choice((1, 2))}+{rnd.uniform(0, 6.28):.2f})")
        drv(o, "rotation_euler", 2, f"{o.rotation_euler[2]:.3f}+frame*2*pi/300*{rnd.choice((-2, -1, 1, 2))}")
    # chains circling body, tail and stinger
    chain_ring("Sk_Kette_Koerper", (-0.3, 0, 1.9), 3.9, 3.0, (math.radians(8), math.radians(-6), 0), spin=1)
    chain_ring("Sk_Kette_Koerper2", (-0.3, 0, 2.6), 4.4, 3.3, (math.radians(-12), math.radians(10), 0), spin=-1)
    chain_ring("Sk_Kette_Schwanz", (-3.2, 0, 3.6), 1.3, 1.3, (0, math.radians(75), 0), parent="Sk_Schwanz_J3", spin=2)
    chain_ring("Sk_Kette_Stachel", (-1.4, 0, 5.15), 1.0, 1.0, (math.radians(10), 0, 0), parent="Sk_Schwanz_J5", spin=-2)
    # violet fog: flat ground layer + soft cloud around body
    for name, loc, scl in (("Sk_Nebel_Boden", (-0.3, 0, 0.45), (6.0, 5.0, 0.6)), ("Sk_Nebel_Koerper", (0.3, 0, 1.6), (4.0, 3.0, 1.4))):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=loc, segments=24, ring_count=12)
        o = C.active_object; o.name = name; o.scale = scl
        for c in o.users_collection: c.objects.unlink(o)
        coll(FX).objects.link(o); o.data.materials.append(D.materials["Sk_Nebel"]); o.visible_shadow = False
    # violet lights (sparse)
    for name, loc, p in (("Sk_Licht_Boden", (0.5, -1.5, 0.4), 120), ("Sk_Licht_Stachel", (-1.4, -0.6, 5.2), 60), ("Sk_Licht_Scheren", (4.8, -1.2, 1.0), 70)):
        ld = D.lights.new(name, 'POINT'); ld.color = (0.6, 0.25, 1.0); ld.energy = p; ld.shadow_soft_size = 0.5
        lo = D.objects.new(name, ld); coll(FX).objects.link(lo); lo.location = loc
        drv(ld, "energy", -1, f"{p}*(1+0.3*sin(frame*2*pi/75))")
    if name == "Sk_Licht_Stachel": pass
    D.objects["Sk_Licht_Stachel"].parent = None


def animate():
    from bpy_extras import anim_utils
    root = D.objects["Sk_Root"]; body = D.objects["Sk_Koerper"]
    drv(body, "location", 2, "1.2+0.03*sin(frame*2*pi/75)")   # location drivers REPLACE the value: keep the base height!
    drv(body, "rotation_euler", 2, "0.02*sin(frame*2*pi/150)")
    # strike impulse (custom property keyed 0 -> 1 -> 0)
    tail0 = D.objects["Sk_Schwanz_J0"]; tail0["stich"] = 0.0
    for f, v in ((1, 0.0), (170, 0.0), (190, -0.35), (205, 1.0), (222, 1.0), (250, 0.0), (300, 0.0)):
        tail0["stich"] = v; tail0.keyframe_insert('["stich"]', frame=f)
    var = ("s", tail0, '["stich"]')
    wave = [0.03, 0.04, 0.05, 0.06, 0.06, 0.05]
    strike = [-0.05, 0.05, 0.12, 0.22, 0.32, 0.4]
    for i in range(6):
        j = D.objects[f"Sk_Schwanz_J{i}"]
        drv(j, "rotation_euler", 1, f"{wave[i]}*sin(frame*2*pi/150-{i * 0.45:.2f})+{strike[i]}*s", var)
        drv(j, "rotation_euler", 2, f"0.04*sin(frame*2*pi/300*2-{i * 0.5:.2f})")
    # claws open/close + small arm sway
    for s, S, ph in ((-1, "L", 0.0), (1, "R", 1.3)):
        drv(D.objects[f"Sk_Finger_{S}"], "rotation_euler", 2, f"{s}*(0.22+0.22*sin(frame*2*pi/100+{ph}))")
        drv(D.objects[f"Sk_Schere_{S}0"], "rotation_euler", 2, f"{-s}*0.06*sin(frame*2*pi/150+{ph})")
        drv(D.objects[f"Sk_Schere_{S}1"], "rotation_euler", 1, f"0.05*sin(frame*2*pi/100+{ph + 0.6:.2f})")
        # legs tip-tap: alternating tetrapod gait
        for i in range(4):
            ph2 = math.pi * ((i + (0 if S == "L" else 1)) % 2)
            leg = D.objects[f"Sk_Bein_{S}{i}"]
            drv(leg, "rotation_euler", 2, f"0.07*sin(frame*2*pi/50+{ph2:.2f})")
            drv(leg, "rotation_euler", 0, f"{s}*0.05*max(0,sin(frame*2*pi/50+{ph2:.2f}))")
    drv(D.objects["Sk_Kopf"], "rotation_euler", 2, "0.03*sin(frame*2*pi/100)")
