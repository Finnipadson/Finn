# Voxel-Drache: Drache aus vielen kleinen Wuerfeln (Block-Look), dunkelblau mit tuerkis leuchtenden Streifen/Kanten/Augen.
# Jedes Koerperteil = eigenes Mesh aus Wuerfeln auf seinem lokalen Raster (innere Flaechen entfernt), an Gelenk-Empties
# geparentet -> starre Teile wie bei Roblox, einfach animierbar.
# Headless: blender -b --factory-startup --python voxeldrache.py -- build|anim
import bpy, bmesh, math, random, sys
from mathutils import Vector, Matrix, Euler
D = bpy.data; C = bpy.context; sc = C.scene
V = 0.07                        # Kantenlaenge eines Wuerfels (feiner = mehr Details)
OUT = r"C:\Users\finns\OneDrive\Desktop\Claude\Games\In Arbeit\Blender\VoxelDrache"
CYAN = (0.05, 0.95, 1.0, 1.0)

# ---------------------------------------------------------------- Formen (SDF)
def sd_ell(p, c, r):
    q = Vector(((p.x - c[0]) / r[0], (p.y - c[1]) / r[1], (p.z - c[2]) / r[2]))
    return (q.length - 1.0) * min(r)

def sd_cap(p, a, b, ra, rb):
    a = Vector(a); b = Vector(b); pa = p - a; ba = b - a
    h = max(0.0, min(1.0, pa.dot(ba) / ba.dot(ba)))
    return (pa - ba * h).length - (ra + (rb - ra) * h)

def sd_box(p, c, h):
    q = Vector((abs(p.x - c[0]) - h[0], abs(p.y - c[1]) - h[1], abs(p.z - c[2]) - h[2]))
    return Vector((max(q.x, 0), max(q.y, 0), max(q.z, 0))).length + min(max(q.x, max(q.y, q.z)), 0.0)

def smin(a, b, k=0.12):
    h = max(k - abs(a - b), 0.0) / k
    return min(a, b) - h * h * k * 0.25

# ---------------------------------------------------------------- Materialien
def mat(name, col, emit=0.0, rough=0.55, pulse=False):
    m = D.materials.get(name) or D.materials.new(name)
    m.use_nodes = True; nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs["Base Color"].default_value = col; b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = col; b.inputs["Emission Strength"].default_value = emit
        if pulse:
            fc = nt.driver_add(f'nodes["{b.name}"].inputs["Emission Strength"].default_value')
            fc.driver.expression = f"{emit}*(1+0.35*sin(frame*2*pi/100))"
    m.diffuse_color = col
    return m

def build_materials():
    return [mat("VD_Panzer", (0.006, 0.012, 0.045, 1), rough=0.7),         # 0 dunkelblau-schwarz
            mat("VD_Panzer_Hell", (0.012, 0.024, 0.075, 1), rough=0.7),     # 1 etwas heller (Variation)
            mat("VD_Leuchten", CYAN, 5.0, pulse=True),         # 2 tuerkis leuchtend
            mat("VD_Augen", (0.6, 1.0, 1.0, 1), 25.0, pulse=True),  # 3 Augen
            mat("VD_Horn", (0.02, 0.03, 0.06, 1), rough=0.4),       # 4 Hoerner/Krallen
            mat("VD_Haut", (0.01, 0.025, 0.09, 1), rough=0.8),
            mat("VD_Panzer_Blau", (0.02, 0.06, 0.2, 1), rough=0.5)]                     # 6 mittelblaue Panzerplatten        # 5 Fluegelhaut

# ---------------------------------------------------------------- Voxelizer
NB = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]

def voxel_object(name, sdf, lo, hi, color, parent=None, origin=(0, 0, 0), coll=None):
    """sdf/color arbeiten in Welt-Koordinaten der Ruhepose; Raster ist am Ursprung des Teils ausgerichtet."""
    o = Vector(origin); cells = {}
    i0 = [math.floor((lo[k] - o[k]) / V) for k in range(3)]; i1 = [math.ceil((hi[k] - o[k]) / V) for k in range(3)]
    for ix in range(i0[0], i1[0] + 1):
        for iy in range(i0[1], i1[1] + 1):
            for iz in range(i0[2], i1[2] + 1):
                p = o + Vector(((ix + 0.5) * V, (iy + 0.5) * V, (iz + 0.5) * V))
                if sdf(p) <= 0: cells[(ix, iy, iz)] = p
    bm = bmesh.new(); vmap = {}
    def vert(ix, iy, iz):
        k = (ix, iy, iz)
        if k not in vmap: vmap[k] = bm.verts.new((ix * V, iy * V, iz * V))
        return vmap[k]
    FACES = {(1, 0, 0): [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)], (-1, 0, 0): [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)],
             (0, 1, 0): [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)], (0, -1, 0): [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)],
             (0, 0, 1): [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)], (0, 0, -1): [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]}
    mats = []
    for (ix, iy, iz), p in cells.items():
        expo = [n for n in NB if (ix + n[0], iy + n[1], iz + n[2]) not in cells]
        if not expo: continue
        mi = color(p, Vector(expo[0]) if len(expo) == 1 else sum((Vector(n) for n in expo), Vector()).normalized(), (ix, iy, iz), cells)
        for n in expo:
            f = bm.faces.new([vert(ix + a, iy + b, iz + c) for a, b, c in FACES[n]]); f.material_index = mi
    me = D.meshes.new(name); bm.to_mesh(me); bm.free()
    for m in MATS: me.materials.append(m)
    ob = D.objects.new(name, me); (coll or sc.collection).objects.link(ob)
    if parent:
        ob.parent = parent; ob.matrix_parent_inverse = parent.matrix_world.inverted()
    ob.location = o if not parent else o
    ob.matrix_world = Matrix.Translation(o)
    return ob, len(cells)

# ---------------------------------------------------------------- Geruest (Gelenke)
def emp(name, loc, parent=None, size=0.2):
    e = D.objects.new(name, None); e.empty_display_size = size; e.location = loc
    COL.objects.link(e)
    if parent:
        e.parent = parent; e.matrix_parent_inverse = parent.matrix_world.inverted()
    C.view_layer.update()
    return e

# Masse (Drache schaut nach +X). Koerper Schnauze->Huefte ~4.4 m, Schwanz ~3.3 m (3/4)
TORSO = [((0.55, 0, 1.45), (0.85, 0.72, 0.68)), ((-0.25, 0, 1.4), (0.85, 0.62, 0.6)), ((-0.95, 0, 1.42), (0.6, 0.6, 0.55))]
NECK = ((0.95, 0, 1.75), (1.75, 0, 2.25), 0.42, 0.3)
HEAD = (2.2, 0, 2.3)
TAIL = [(-1.3, 0, 1.45), (-2.05, 0, 1.25), (-2.75, 0.15, 0.95), (-3.35, 0.45, 0.68), (-3.9, 0.85, 0.52), (-4.35, 1.3, 0.48)]
TAIL_R = [0.46, 0.36, 0.27, 0.19, 0.12, 0.07]

def leg_front(s):  # Schulter, Ellbogen, Handgelenk, Fuss
    return [Vector((0.75, s * 0.62, 1.35)), Vector((0.95, s * 0.88, 0.78)), Vector((1.12, s * 0.9, 0.22)), Vector((1.35, s * 0.92, 0.06))]

def leg_hind(s):   # Huefte, Knie, Ferse, Fuss
    return [Vector((-0.95, s * 0.58, 1.35)), Vector((-0.45, s * 0.86, 0.85)), Vector((-0.95, s * 0.86, 0.38)), Vector((-0.65, s * 0.88, 0.06))]

# ---------------------------------------------------------------- Faerbung
# Materialindex: 0 Marine (dunkel), 1 Marine hell, 2 Tuerkis leuchtend, 3 Augen, 4 Horn/Krallen dunkel, 5 Fluegelhaut, 6 Panzer-Blau
def frac(x): return x - math.floor(x)

def hsh(a, b, c=0):
    return frac(math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453)

def scales(p, su=0.3, sw=0.22):
    """Panzerplatten in versetzten Reihen: Fugen dunkel, Platten abwechselnd blau/marine."""
    w = p.z / sw; wi = math.floor(w); u = p.x / su + 0.5 * (wi % 2); ui = math.floor(u)
    if frac(u) < 0.2 or frac(w) < 0.22: return 0
    return 6 if hsh(ui, wi) < 0.62 else 1

def colorer(kind, rnd):
    def f(p, n, idx, cells):
        top = n.z > 0.5; side = abs(n.y) > 0.5; bottom = n.z < -0.5
        if kind == "torso":
            if abs(p.y) < 0.1 and top: return 2                                          # Leuchtlinie auf dem Ruecken
            if side and abs(p.z - (1.42 + 0.12 * math.sin(p.x * 2.2))) < 0.07: return 2   # breites Flankenband (wellig)
            if side and abs(frac((p.x + (p.z - 1.0) * 0.8) / 0.55) - 0.5) < 0.07 and p.z > 1.55 and abs(p.x) < 1.3: return 2  # schraege Rippen
            if bottom or p.z < 1.0: return 6 if frac(p.x / 0.21) > 0.25 else 0           # Bauchplatten
            return scales(p)
        if kind == "neck":
            if abs(p.y) < 0.1 and top: return 2
            if side and abs(frac((p.x - p.z * 0.6) / 0.3) - 0.5) < 0.12: return 2
            return scales(p, 0.22, 0.18)
        if kind == "tail":
            if top and abs(p.y - tail_y(p.x)) < 0.08: return 2
            if side and abs(frac(p.x / 0.4) - 0.5) < 0.1: return 2
            return scales(p, 0.22, 0.16)
        if kind == "leg":
            if side and abs(frac(p.z / 0.42) - 0.5) < 0.08: return 2
            return scales(p, 0.2, 0.2)
        return 0
    return f

def tail_y(x):
    for a, b in zip(TAIL, TAIL[1:]):
        if b[0] <= x <= a[0]:
            t = (x - a[0]) / (b[0] - a[0]); return a[1] + (b[1] - a[1]) * t
    return TAIL[-1][1]

def tri_inside(q, a, b, c, nrm):
    for u, v_, w in ((a, b, c), (b, c, a), (c, a, b)):
        if (v_ - u).cross(q - u).dot(nrm) < 0: return False
    return True

def blade_sdf(a, b, t, th):
    """flache Klinge (Dreieck a-b-t) mit Dicke th."""
    a, b, t = Vector(a), Vector(b), Vector(t); nrm = (b - a).cross(t - a).normalized()
    def f(p):
        d = (p - a).dot(nrm)
        if abs(d) > th: return 1
        return -1 if tri_inside(p - nrm * d, a, b, t, nrm) else 1
    return f

def blade_col(a, b, t, w=0.07):
    """Tuerkiser Mittelstreifen von der Basis zur Spitze, Rand dunkel, Flaeche blau."""
    a, b, t = Vector(a), Vector(b), Vector(t); m = (a + b) / 2; ax = t - m; L = ax.length; ax.normalize()
    def f(p, n, idx, cells):
        u = (p - m).dot(ax); off = ((p - m) - ax * u).length
        if 0.12 * L < u < 0.92 * L and off < w * (1 - u / L) + 0.02: return 2
        filled = sum(1 for nb in NB if (idx[0] + nb[0], idx[1] + nb[1], idx[2] + nb[2]) in cells)
        return 0 if filled <= 3 else 6
    return f

def bbox_of(*pts, pad=0.15):
    return ([min(q[k] for q in pts) - pad for k in range(3)], [max(q[k] for q in pts) + pad for k in range(3)])

def add_blade(name, a, b, t, parent, th=0.07, w=0.07):
    lo, hi = bbox_of(a, b, t)
    return voxel_object(name, blade_sdf(a, b, t, th), lo, hi, blade_col(a, b, t, w), parent, (0, 0, 0), COL)

# ---------------------------------------------------------------- Bau
def build_dragon():
    global COL, MATS
    rnd = random.Random(5)
    MATS = build_materials()
    COL = D.collections.get("VoxelDrache") or D.collections.new("VoxelDrache")
    if COL.name not in sc.collection.children: sc.collection.children.link(COL)
    for o in list(COL.objects): D.objects.remove(o, do_unlink=True)
    root = emp("VD_Root", (0, 0, 0), size=1.0)
    body = emp("VD_Koerper", (-0.2, 0, 1.4), root, 0.6)
    # Rumpf
    def torso(p):
        d = 9
        for c, r in TORSO: d = smin(d, sd_ell(p, c, r), 0.25)
        return d
    voxel_object("VD_Rumpf", torso, (-1.65, -0.9, 0.7), (1.45, 0.9, 2.2), colorer("torso", rnd), body, (0, 0, 0), COL)
    # Hals + Kopf
    neck = emp("VD_Hals", NECK[0], body, 0.4)
    voxel_object("VD_Hals_V", lambda p: sd_cap(p, NECK[0], NECK[1], NECK[2], NECK[3]), (0.5, -0.5, 1.3), (2.1, 0.5, 2.6), colorer("neck", rnd), neck, (0, 0, 0), COL)
    head = emp("VD_Kopf", (1.85, 0, 2.3), neck, 0.4)
    def headf(p):
        d = sd_box(p, (2.15, 0, 2.34), (0.42, 0.36, 0.28))                 # Schaedel (kantig)
        d = min(d, sd_box(p, (2.8, 0, 2.22), (0.4, 0.27, 0.15)))            # Oberkiefer/Schnauze
        d = min(d, sd_box(p, (2.35, 0, 2.62), (0.3, 0.33, 0.07)))           # Brauenplatte
        d = min(d, sd_box(p, (3.12, 0, 2.3), (0.1, 0.2, 0.06)))             # Nasenspitze
        return d
    def headcol(p, n, idx, cells):
        side = abs(n.y) > 0.5; top = n.z > 0.5
        for s in (-1, 1):
            if (p - Vector((2.5, s * 0.36, 2.44))).length < 0.12 and side: return 3   # Augen
        if side and p.x > 2.45 and 2.24 < p.z < 2.33: return 2             # breiter Streifen an der Schnauze
        if side and 2.42 < p.z < 2.48 and 1.9 < p.x < 2.4: return 2       # Streifen hinter dem Auge
        if top and abs(p.y) < 0.08: return 2
        if top and p.z > 2.6 and abs(abs(p.y) - 0.25) < 0.05: return 2     # Brauenkanten
        return scales(p, 0.2, 0.16)
    voxel_object("VD_Kopf_V", headf, (1.6, -0.5, 1.95), (3.3, 0.5, 2.8), headcol, head, (0, 0, 0), COL)
    # Kopf-Kamm: grosse Klingen nach hinten-oben, Wangenklingen, Nasenhorn
    for s, S in ((-1, "L"), (1, "R")):
        add_blade(f"VD_Kamm_{S}", (2.35, s * 0.24, 2.66), (1.85, s * 0.28, 2.6), (1.25, s * 0.62, 3.35), head, w=0.06)
        add_blade(f"VD_Kamm2_{S}", (1.95, s * 0.3, 2.5), (1.75, s * 0.33, 2.4), (1.3, s * 0.85, 2.75), head, w=0.04)
        add_blade(f"VD_Wange_{S}", (2.3, s * 0.37, 2.2), (1.9, s * 0.37, 2.15), (1.5, s * 0.85, 2.05), head, w=0.05)
    add_blade("VD_Nasenhorn", (3.05, 0, 2.36), (2.8, 0, 2.37), (2.85, 0, 2.68), head, w=0.03)
    jaw = emp("VD_Kiefer", (2.0, 0, 2.08), head, 0.3)
    def jawf(p):
        d = sd_box(p, (2.62, 0, 1.99), (0.5, 0.24, 0.08))
        for s in (-1, 1):   # Zaehne
            for k in range(5):
                d = min(d, sd_box(p, (3.0 - k * 0.13, s * 0.2, 2.1), (0.03, 0.03, 0.06)))
        return d
    def jawcol(p, n, i, c):
        if p.z > 2.06: return 2                                             # leuchtende Zaehne
        if abs(n.y) > 0.5: return 2 if p.z > 1.98 else 0
        return 6
    voxel_object("VD_Kiefer_V", jawf, (2.0, -0.4, 1.85), (3.2, 0.4, 2.2), jawcol, jaw, (0, 0, 0), COL)
    # Schwanz (Segmente an einer Gelenkkette)
    prev = body; joints = []
    for i in range(len(TAIL) - 1):
        j = emp(f"VD_Schwanz_J{i}", TAIL[i], prev, 0.3); joints.append(j); prev = j
        a, b = TAIL[i], TAIL[i + 1]; ra, rb = TAIL_R[i], TAIL_R[i + 1]
        lo = [min(a[k], b[k]) - ra - 0.1 for k in range(3)]; hi = [max(a[k], b[k]) + ra + 0.1 for k in range(3)]
        sdf = (lambda a, b, ra, rb: (lambda p: sd_cap(p, a, b, ra, rb)))(a, b, ra, rb)
        voxel_object(f"VD_Schwanz_{i}", sdf, lo, hi, colorer("tail", rnd), j, (0, 0, 0), COL)
    tip = emp("VD_Schwanz_Spitze", TAIL[-1], prev, 0.3)
    d_t = (Vector(TAIL[-1]) - Vector(TAIL[-2])).normalized(); sd_t = Vector((-d_t.y, d_t.x, 0)); T0 = Vector(TAIL[-1])
    for k, (sgn, nm) in enumerate(((1, "A"), (-1, "B"))):   # Pfeilspitze aus zwei flachen Klingen
        add_blade(f"VD_Schwanz_Spitze_{nm}", T0 - d_t * 0.05, T0 + d_t * 0.65, T0 + d_t * 0.05 + sd_t * sgn * 0.38, tip, th=0.05, w=0.04)
    # Rueckenflossen: grosse Klingen mit tuerkisem Mittelstreifen, Groesse graduell
    fins = [  # x_vorne, x_hinten, Hoehe, Elternteil
        (1.5, 1.25, 0.32, "neck"), (1.2, 0.95, 0.42, "neck"),
        (0.75, 0.38, 0.75, "body"), (0.25, -0.15, 0.95, "body"), (-0.28, -0.7, 0.85, "body"), (-0.82, -1.2, 0.62, "body")]
    zt = lambda x: 2.08 if x > -1.3 else 1.9
    for k, (xa, xb, h, par) in enumerate(fins):
        za = (NECK[0][2] + (xa - NECK[0][0]) / (NECK[1][0] - NECK[0][0]) * (NECK[1][2] - NECK[0][2]) + NECK[2] - 0.08) if par == "neck" else zt(xa) - 0.06
        zb = (NECK[0][2] + (xb - NECK[0][0]) / (NECK[1][0] - NECK[0][0]) * (NECK[1][2] - NECK[0][2]) + NECK[2] - 0.08) if par == "neck" else zt(xb) - 0.06
        a = (xa, 0, za); b = (xb, 0, zb); t = (xb - h * 0.45, 0, max(za, zb) + h)
        add_blade(f"VD_Flosse_{k:02d}", a, b, t, neck if par == "neck" else body)
    for i in range(len(TAIL) - 1):   # Schwanzflossen
        A, B = Vector(TAIL[i]), Vector(TAIL[i + 1]); r = TAIL_R[i]
        a = A.lerp(B, 0.15) + Vector((0, 0, r - 0.04)); b = A.lerp(B, 0.75) + Vector((0, 0, TAIL_R[i + 1] + (r - TAIL_R[i + 1]) * 0.25 - 0.04))
        h = 0.5 - i * 0.08; t = b + (B - A).normalized() * h * 0.5 + Vector((0, 0, h))
        add_blade(f"VD_Schwanzflosse_{i}", tuple(a), tuple(b), tuple(t), joints[i], w=0.05)
    # Beine
    for s, S in ((-1, "L"), (1, "R")):
        for kind, pts, rad, nm in (("v", leg_front(s), (0.32, 0.23, 0.18, 0.16), "Vorne"), ("h", leg_hind(s), (0.44, 0.27, 0.18, 0.16), "Hinten")):
            j0 = emp(f"VD_Bein_{nm}_{S}", tuple(pts[0]), root, 0.3)   # an Root: Beine bleiben am Boden, wenn der Koerper atmet
            def legf(p, pts=pts, rad=rad):
                d = 9
                for k in range(3): d = smin(d, sd_cap(p, pts[k], pts[k + 1], rad[k], rad[k + 1]), 0.08)
                foot = pts[3]
                d = min(d, sd_box(p, (foot.x + 0.1, foot.y, 0.09), (0.24, 0.19, 0.09)))
                return d
            lo = [min(q[k] for q in pts) - 0.55 for k in range(3)]; lo[2] = 0.0
            hi = [max(q[k] for q in pts) + 0.55 for k in range(3)]
            voxel_object(f"VD_Bein_{nm}_{S}_V", legf, lo, hi, colorer("leg", rnd), j0, (0, 0, 0), COL)
            foot = pts[3]
            def clawf(p, foot=foot):   # 4 grosse Krallen (3 vorne, 1 hinten), leuchtend
                d = 9
                for k in (-1, 0, 1):
                    d = min(d, sd_cap(p, (foot.x + 0.28, foot.y + k * 0.13, 0.09), (foot.x + 0.62, foot.y + k * 0.17, 0.02), 0.07, 0.025))
                d = min(d, sd_cap(p, (foot.x - 0.1, foot.y, 0.08), (foot.x - 0.32, foot.y, 0.02), 0.05, 0.02))
                return d
            voxel_object(f"VD_Krallen_{nm}_{S}", clawf, (foot.x - 0.5, foot.y - 0.5, 0.0), (foot.x + 0.8, foot.y + 0.5, 0.25),
                         lambda p, n, i, c: 2, j0, (0, 0, 0), COL)
            # Gelenk-Klinge (Ellbogen/Knie) nach hinten
            kn = pts[1]; back = -1 if kind == "v" else 1
            add_blade(f"VD_Gelenkklinge_{nm}_{S}", (kn.x + 0.05 * back, kn.y + s * 0.15, kn.z + 0.12), (kn.x, kn.y + s * 0.18, kn.z - 0.12),
                      (kn.x - 0.5, kn.y + s * 0.3, kn.z + (0.15 if kind == "v" else 0.3)), j0, w=0.04)
    # Fluegel: Arm + Finger als leuchtende Knochen, Haut in Blau mit dunklen Feldern, gezackte Hinterkante, Zacken vorne
    for s, S in ((-1, "L"), (1, "R")):
        sh = Vector((0.35, s * 0.55, 2.0))
        wj = emp(f"VD_Fluegel_{S}", tuple(sh), body, 0.4)
        elbow = Vector((-0.05, s * 1.55, 3.15)); wrist = Vector((-0.45, s * 2.55, 3.75))
        tips = [Vector((-0.6, s * 3.75, 3.35)), Vector((-1.35, s * 3.55, 2.65)), Vector((-1.85, s * 2.85, 2.1)), Vector((-1.8, s * 1.9, 1.95))]
        ww = emp(f"VD_Fluegel_{S}_Aussen", tuple(elbow), wj, 0.3)
        inner_pt = Vector((-1.2, s * 0.65, 1.75))
        def wing_bones(p, part):
            if part == 0: return sd_cap(p, sh, elbow, 0.15, 0.11)
            d = sd_cap(p, elbow, wrist, 0.11, 0.09)
            for t in tips: d = min(d, sd_cap(p, wrist, t, 0.075, 0.03))
            return d
        def membrane(p, part):
            tris = [(sh, elbow, inner_pt)] if part == 0 else \
                   [(wrist, tips[0], tips[1]), (wrist, tips[1], tips[2]), (wrist, tips[2], tips[3]), (wrist, tips[3], elbow), (elbow, tips[3], inner_pt)]
            for a, b, c in tris:
                nrm = (b - a).cross(c - a).normalized(); dist = (p - a).dot(nrm)
                if abs(dist) > V * 0.75: continue
                q = p - nrm * dist
                if tri_inside(q, a, b, c, nrm):
                    if a is wrist and b in tips and c in tips:   # gezackte Hinterkante
                        mid = (b + c) / 2; outw = (mid - wrist).normalized(); R = 0.42 * (c - b).length
                        if (q - (mid + outw * R * 0.55)).length < R: continue
                    return -1
            return 1
        def seg_dist(p, a, b):
            ab = b - a; h = max(0.0, min(1.0, (p - a).dot(ab) / ab.dot(ab))); return (p - a - ab * h).length
        for part, nm, par in ((0, f"VD_Fluegel_{S}_Innen_V", wj), (1, f"VD_Fluegel_{S}_Aussen_V", ww)):
            pts_all = [sh, elbow, wrist] + tips + [inner_pt]
            lo, hi = bbox_of(*pts_all, pad=0.2)
            def wf(p, part=part): return min(wing_bones(p, part), membrane(p, part))
            def wc(p, n, i, c, part=part):
                if wing_bones(p, part) <= 0: return 2
                dmin = min(seg_dist(p, wrist, t) for t in tips) if part == 1 else seg_dist(p, sh, elbow)
                if dmin < 0.16: return 0                       # dunkle Felder entlang der Knochen
                return 6 if hsh(math.floor(p.x / 0.35), math.floor(p.z / 0.35)) < 0.75 else 5
            voxel_object(nm, wf, lo, hi, wc, par, (0, 0, 0), COL)
        # Zacken: Daumenkralle am Handgelenk + Zacken entlang der Vorderkante
        up = Vector((0.15, 0, 1)).normalized()
        add_blade(f"VD_Fluegel_{S}_Kralle", wrist + Vector((0.05, 0, 0.0)), wrist + Vector((-0.12, s * 0.1, 0.05)), wrist + Vector((0.35, s * 0.15, 0.5)), ww, w=0.04)
        for k, t in enumerate((0.3, 0.6, 0.85)):
            pa = elbow.lerp(wrist, t)
            add_blade(f"VD_Fluegel_{S}_Zacke{k}", pa + Vector((0.06, 0, 0.04)), pa + Vector((-0.1, 0, 0.04)), pa + Vector((0.12, s * 0.05, 0.32)), ww, th=0.05, w=0.03)
        for k, t in enumerate((0.35, 0.75)):
            pa = sh.lerp(elbow, t)
            add_blade(f"VD_Fluegel_{S}_ZackeI{k}", pa + Vector((0.06, 0, 0.06)), pa + Vector((-0.1, 0, 0.06)), pa + Vector((0.12, s * 0.05, 0.35)), wj, th=0.05, w=0.03)
    return root



# ---------------------------------------------------------------- Animation (Loop 300 Frames @ 60 fps)
def drv(ob, path, idx, expr):
    fc = ob.driver_add(path, idx); fc.driver.type = 'SCRIPTED'; fc.driver.expression = expr
    return fc

def animate():
    """Atmen, Fluegelschlag (innen + aussen versetzt), Schwanzpendeln, Kopf/Hals, Kiefer; Glühen pulsiert per Material-Driver.
    Perioden 300/150/100/75/50 teilen 300 -> sauberer Loop. Location-Drivers ERSETZEN den Wert: Basis mitgeben!"""
    O = D.objects; W = "frame*2*pi/"
    b = O["VD_Koerper"]
    drv(b, "location", 2, f"{b.location.z:.3f}+0.045*sin({W}100)")          # Atmen: Koerper hebt/senkt sich
    drv(b, "rotation_euler", 1, f"0.025*sin({W}100+0.8)")
    drv(O["VD_Hals"], "rotation_euler", 1, f"0.05*sin({W}100+1.4)")
    drv(O["VD_Hals"], "rotation_euler", 2, f"0.1*sin({W}150)")
    drv(O["VD_Kopf"], "rotation_euler", 1, f"0.06*sin({W}100+2.0)")
    drv(O["VD_Kopf"], "rotation_euler", 2, f"0.06*sin({W}150+0.6)")
    drv(O["VD_Kiefer"], "rotation_euler", 1, f"0.07+0.07*sin({W}75)")       # Maul geht auf und zu
    for i in range(5):
        j = O[f"VD_Schwanz_J{i}"]
        drv(j, "rotation_euler", 2, f"0.1*sin({W}150-{i * 0.6:.2f})")
        drv(j, "rotation_euler", 1, f"0.035*sin({W}100-{i * 0.5:.2f})")
    for s, S in ((-1, "L"), (1, "R")):
        drv(O[f"VD_Fluegel_{S}"], "rotation_euler", 0, f"{s}*(0.05+0.32*sin({W}100))")          # Fluegelschlag
        drv(O[f"VD_Fluegel_{S}"], "rotation_euler", 2, f"{s}*0.06*sin({W}100+1.2)")
        drv(O[f"VD_Fluegel_{S}_Aussen"], "rotation_euler", 0, f"{s}*0.22*sin({W}100-0.9)")      # Aussenteil schwingt nach

# ---------------------------------------------------------------- Umgebung
def build_env():
    for o in list(D.objects):
        if o.type in ('MESH', 'LIGHT', 'CAMERA') and o.name in ("Cube", "Light", "Camera"): D.objects.remove(o, do_unlink=True)
    env = D.collections.get("Umgebung") or D.collections.new("Umgebung")
    if env.name not in sc.collection.children: sc.collection.children.link(env)
    for o in list(env.objects): D.objects.remove(o, do_unlink=True)
    # heller Gitterboden (Roblox-Baseplate-Look)
    me = D.meshes.new("Boden"); bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=60); bm.to_mesh(me); bm.free()
    g = D.objects.new("Boden", me); env.objects.link(g)
    m = D.materials.get("VD_Boden") or D.materials.new("VD_Boden"); m.use_nodes = True; nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'); b.inputs["Roughness"].default_value = 0.8
    tc = nt.nodes.new("ShaderNodeTexCoord"); br = nt.nodes.new("ShaderNodeTexBrick")
    br.inputs["Scale"].default_value = 1.0; br.offset = 0.0; br.squash = 1.0
    br.inputs["Color1"].default_value = (0.42, 0.45, 0.5, 1); br.inputs["Color2"].default_value = (0.4, 0.43, 0.48, 1)
    br.inputs["Mortar"].default_value = (0.3, 0.32, 0.36, 1); br.inputs["Mortar Size"].default_value = 0.012
    br.inputs["Brick Width"].default_value = 1.0; br.inputs["Row Height"].default_value = 1.0
    mp = nt.nodes.new("ShaderNodeMapping"); mp.vector_type = 'POINT'; mp.inputs["Scale"].default_value = (0.5, 0.5, 0.5)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"]); nt.links.new(mp.outputs["Vector"], br.inputs["Vector"])
    nt.links.new(br.outputs["Color"], b.inputs["Base Color"]); me.materials.append(m)
    # Himmel
    wd = sc.world or D.worlds.new("World"); sc.world = wd; wd.use_nodes = True; nt = wd.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_WORLD': nt.nodes.remove(n)
    out = next(n for n in nt.nodes if n.type == 'OUTPUT_WORLD')
    # einfacher Verlauf (Nishita-Sky war in 5.3 extrem ueberbelichtet)
    tcw = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tcw.outputs["Generated"], sep.inputs[0])
    grad = nt.nodes.new("ShaderNodeValToRGB")
    grad.color_ramp.elements[0].position = 0.0; grad.color_ramp.elements[0].color = (0.62, 0.75, 0.92, 1)
    grad.color_ramp.elements[1].position = 0.5; grad.color_ramp.elements[1].color = (0.18, 0.42, 0.85, 1)
    nt.links.new(sep.outputs["Z"], grad.inputs["Fac"])
    bg = nt.nodes.new("ShaderNodeBackground"); bg.inputs["Strength"].default_value = 0.8
    nt.links.new(grad.outputs[0], bg.inputs[0]); nt.links.new(bg.outputs[0], out.inputs[0])
    ld = D.lights.new("Sonne", 'SUN'); ld.energy = 3.0; ld.angle = math.radians(2)
    so = D.objects.new("Sonne", ld); env.objects.link(so); so.rotation_euler = (math.radians(50), 0, math.radians(140))
    cd = D.cameras.new("Kamera"); cd.lens = 40
    cam = D.objects.new("Kamera", cd); env.objects.link(cam); sc.camera = cam
    cam.location = (7.5, -8.5, 3.4); look_at(cam, (-0.4, 0, 1.6))
    # Bloom + Farbmanagement + Timing
    ng = D.node_groups.get("VD_Leuchten") or D.node_groups.new("VD_Leuchten", 'CompositorNodeTree')
    for n in list(ng.nodes): ng.nodes.remove(n)
    if not ng.interface.items_tree: ng.interface.new_socket("Image", in_out='OUTPUT', socket_type='NodeSocketColor')
    go = ng.nodes.new('NodeGroupOutput'); rl = ng.nodes.new('CompositorNodeRLayers'); gl = ng.nodes.new('CompositorNodeGlare')
    gl.inputs['Type'].default_value = 'Bloom'; gl.inputs['Strength'].default_value = 0.3; gl.inputs['Size'].default_value = 0.45
    ng.links.new(rl.outputs['Image'], gl.inputs['Image']); ng.links.new(gl.outputs['Image'], go.inputs[0])
    sc.compositing_node_group = ng
    try: sc.view_settings.view_transform = 'Khronos PBR Neutral'
    except TypeError: pass
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    sc.render.fps = 60; sc.frame_start, sc.frame_end = 1, 300
    try: sc.sync_mode = 'FRAME_DROP'
    except Exception: pass
    sc.eevee.taa_render_samples = 32
    sc.render.filepath = OUT + r"\Renders\Animation\voxeldrache_"


def look_at(ob, tgt):
    ob.rotation_euler = (Vector(tgt) - ob.location).to_track_quat('-Z', 'Y').to_euler()


def shot(path, frame, loc, tgt, lens=40, res=(960, 600), samples=24):
    cam = sc.camera; old = (cam.location.copy(), cam.rotation_euler.copy(), cam.data.lens)
    cam.location = loc; look_at(cam, tgt); cam.data.lens = lens
    r = sc.render; o = (r.resolution_x, r.resolution_y, r.filepath, sc.eevee.taa_render_samples)
    r.resolution_x, r.resolution_y = res; r.filepath = path; sc.eevee.taa_render_samples = samples
    sc.frame_set(frame); bpy.ops.render.render(write_still=True)
    r.resolution_x, r.resolution_y, r.filepath, sc.eevee.taa_render_samples = o
    cam.location, cam.rotation_euler, cam.data.lens = old


def viewport_setup():
    for scr in D.screens:
        for area in scr.areas:
            if area.type == 'VIEW_3D':
                for sp in area.spaces:
                    if sp.type == 'VIEW_3D':
                        sp.shading.type = 'MATERIAL'; sp.shading.use_scene_lights = True; sp.shading.use_scene_world = True
                        try: sp.shading.use_compositor = 'ALWAYS'
                        except Exception: pass
                        sp.overlay.show_relationship_lines = False; sp.overlay.show_extras = False


if __name__ == "__main__" and "--" in sys.argv:
    mode = sys.argv[sys.argv.index("--") + 1]
    SP = sys.argv[sys.argv.index("--") + 2] if len(sys.argv) > sys.argv.index("--") + 2 else OUT
    if mode == "build":
        for o in list(D.objects): D.objects.remove(o, do_unlink=True)
        build_env(); build_dragon(); animate(); viewport_setup()
        import os; os.makedirs(OUT + r"\Renders", exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=OUT + r"\voxeldrache.blend")
        n = sum(len(o.data.polygons) for o in D.objects if o.type == 'MESH')
        print("BUILD_OK faces", n)
        tgt = (-0.4, 0, 1.6)
        for name, loc, lens in (("v_34", (7.5, -8.5, 3.4), 40), ("v_vorne", (11, 0, 2.4), 40), ("v_seite", (0, -12, 2.2), 38), ("v_oben", (-0.4, -0.01, 14), 38)):
            shot(SP + "\\" + name + ".png", 1, loc, tgt, lens)
        for f in (1, 25, 50, 75, 112, 150):
            shot(SP + "\\" + f"a{f:03d}.png", f, (7.5, -8.5, 3.4), tgt, 40, (640, 400), 16)
        print("RENDER_OK")
