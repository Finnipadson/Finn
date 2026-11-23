# Skorpion-Ei neben dem Skorpion: kantige dunkel-violette Kristall-/Steinschale mit gluehenden Rissen,
# Nest aus Steinen + Kristallen, kleiner Kettenring, schwebende Splitter. (Entwurf; Schluepf-Animation folgt separat)
import bpy, bmesh, math, random
from mathutils import Vector, Matrix
D = bpy.data; C = bpy.context; sc = bpy.context.scene
EI = "Skorpion_Ei"
EI_POS = Vector((-6.2, -4.2, 0.0))
EI_H = 2.8          # Hoehe der Schale
EI_R = 1.05         # Radius an der dicksten Stelle
VIO = (0.62, 0.22, 1.0, 1.0)


def coll(name):
    c = D.collections.get(name)
    if not c: c = D.collections.new(name); sc.collection.children.link(c)
    return c


def link(ob):
    for c in ob.users_collection: c.objects.unlink(ob)
    coll(EI).objects.link(ob); return ob


def clear():
    c = D.collections.get(EI)
    if c:
        for o in list(c.objects): D.objects.remove(o, do_unlink=True)


def egg_point(v):
    """Einheitskugel -> Eiform: unten breit, oben spitzer."""
    z = v.z
    r = EI_R * (1.0 - 0.17 * z) * math.sqrt(max(0.0, 1 - z * z)) / max(1e-6, math.hypot(v.x, v.y)) if abs(z) < 0.9999 else 0
    h = (z + 1) / 2 * EI_H
    return Vector((v.x * r, v.y * r, h))


def shell_material():
    m = D.materials.get("Sk_Ei_Schale")
    if m: return m
    m = D.materials["Sk_Panzer"].copy(); m.name = "Sk_Ei_Schale"
    return m


def build_egg(seed=7):
    clear(); rnd = random.Random(seed)
    root = link(D.objects.new("Ei_Root", None)); root.location = EI_POS; root.empty_display_size = 1.5
    # Schale: Icosphere -> Eiform, Facetten leicht verschoben (kantig wie Kristall/Stein)
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    for v in bm.verts:
        p = egg_point(v.co.normalized())
        n = Vector((p.x, p.y, (p.z - EI_H * 0.45) * 0.6)).normalized()
        v.co = p + n * rnd.uniform(-0.05, 0.07)
    me = D.meshes.new("Ei_Schale"); bm.to_mesh(me); bm.free()
    me.materials.append(shell_material())
    for p in me.polygons: p.use_smooth = False
    sh = link(D.objects.new("Ei_Schale", me)); sh.parent = root
    bv = sh.modifiers.new("Kanten", 'BEVEL'); bv.width = 0.02; bv.segments = 1; bv.limit_method = 'ANGLE'
    # Kristall-Grate auf der Schale (laengs, leicht gebogen) wie Panzerplatten
    for k in range(7):
        a = 2 * math.pi * k / 7 + rnd.uniform(-0.15, 0.15)
        pts = []
        for t in (0.18, 0.42, 0.66, 0.86):
            z = -1 + 2 * t; v = Vector((math.cos(a) * math.sqrt(1 - z * z), math.sin(a) * math.sqrt(1 - z * z), z))
            p = egg_point(v); pts.append(p + Vector((p.x, p.y, 0)).normalized() * 0.03)
        bm = bmesh.new(); prev = None
        verts = []
        for i, p in enumerate(pts):
            w = 0.09 * (1 - 0.15 * i); out = Vector((p.x, p.y, 0)).normalized(); side = Vector((-out.y, out.x, 0))
            verts.append([bm.verts.new(p + side * w), bm.verts.new(p + out * 0.1), bm.verts.new(p - side * w)])
        for i in range(len(verts) - 1):
            for j in range(2):
                bm.faces.new((verts[i][j], verts[i][j + 1], verts[i + 1][j + 1], verts[i + 1][j]))
        me = D.meshes.new(f"Ei_Grat_{k}"); bm.to_mesh(me); bm.free(); me.materials.append(D.materials["Sk_Platte"])
        g = link(D.objects.new(f"Ei_Grat_{k}", me)); g.parent = root
    # Nest: dunkle Steine im Ring
    for i in range(11):
        a = 2 * math.pi * i / 11 + rnd.uniform(-0.2, 0.2); r = EI_R * rnd.uniform(1.05, 1.35); s = rnd.uniform(0.28, 0.5)
        bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
        for v in bm.verts: v.co *= rnd.uniform(0.75, 1.15)
        me = D.meshes.new(f"Ei_Stein_{i}"); bm.to_mesh(me); bm.free(); me.materials.append(D.materials["Sk_Panzer"])
        st = link(D.objects.new(f"Ei_Stein_{i}", me)); st.parent = root
        st.location = (math.cos(a) * r, math.sin(a) * r, s * 0.35); st.scale = (s * 1.3, s, s * 0.8)
        st.rotation_euler = (rnd.uniform(0, 1), rnd.uniform(0, 1), a)
    # Kristalle, die schraeg aus dem Nest ragen
    for i in range(9):
        a = 2 * math.pi * i / 9 + rnd.uniform(-0.25, 0.25); r = EI_R * rnd.uniform(0.95, 1.25); h = rnd.uniform(0.6, 1.4)
        bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.16 * h, radius2=0.0, depth=h)
        bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, h / 2))
        me = D.meshes.new(f"Ei_Kristall_{i}"); bm.to_mesh(me); bm.free(); me.materials.append(D.materials["Sk_Kristall"])
        cr = link(D.objects.new(f"Ei_Kristall_{i}", me)); cr.parent = root
        cr.location = (math.cos(a) * r, math.sin(a) * r, 0.05)
        cr.rotation_euler = (Matrix.Rotation(a, 3, 'Z') @ Matrix.Rotation(rnd.uniform(0.35, 0.7), 3, 'Y')).to_euler()
    # schwebende Splitter um das Ei (langsam kreisend)
    spl = D.meshes.get("Sk_Splitter_Mesh")
    for i in range(5):
        a = 2 * math.pi * i / 5; r = EI_R * 1.9; z = rnd.uniform(1.0, 2.8)
        o = link(D.objects.new(f"Ei_Splitter_{i}", spl)); o.parent = root
        o.location = (math.cos(a) * r, math.sin(a) * r, z); o.scale = (0.14, 0.14, 0.3)
        for ax, expr in ((0, f"{r:.2f}*cos({a:.2f}+frame*2*pi/300)"), (1, f"{r:.2f}*sin({a:.2f}+frame*2*pi/300)"), (2, f"{z:.2f}+0.12*sin(frame*2*pi/150+{i})")):
            fc = o.driver_add("location", ax); fc.driver.expression = expr
    # violettes Licht am Nest
    ld = D.lights.new("Ei_Licht", 'POINT'); ld.color = VIO[:3]; ld.energy = 150; ld.shadow_soft_size = 0.8
    lo = link(D.objects.new("Ei_Licht", ld)); lo.parent = root; lo.location = (1.4, -1.2, 0.6)
    fc = ld.driver_add("energy"); fc.driver.expression = "150*(1+0.3*sin(frame*2*pi/75))"
    return root
