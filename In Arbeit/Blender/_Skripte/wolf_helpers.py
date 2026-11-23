import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler

C = bpy.context
D = bpy.data


def coll(name):
    c = D.collections.get(name)
    if not c:
        c = D.collections.new(name)
        C.scene.collection.children.link(c)
    return c


def link(ob, cname):
    coll(cname).objects.link(ob)
    return ob


def mat(name):
    return D.materials.get(name)


def frustum(name, p0, p1, w0, h0, w1=None, h1=None, cname="Wolf", m="Stein",
            bevel=0.06, parent=None, up=Vector((0, 0, 1)), shear=0.0):
    """Box from p0 to p1 with cross-section w0 x h0 at start, w1 x h1 at end.
    w = width perpendicular to segment, horizontal; h = vertical-ish."""
    if w1 is None: w1 = w0
    if h1 is None: h1 = h0
    p0 = Vector(p0); p1 = Vector(p1)
    d = p1 - p0
    L = d.length
    fwd = d.normalized()
    side = fwd.cross(up)
    if side.length < 1e-4:
        side = fwd.cross(Vector((1, 0, 0)))
    side.normalize()
    upv = side.cross(fwd).normalized()
    verts = []
    for t, w, h in ((0, w0, h0), (1, w1, h1)):
        c = p0 + d * t + upv * (shear * t)
        for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            verts.append(c + side * (sx * w / 2) + upv * (sz * h / 2))
    faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    me = D.meshes.new(name)
    center = (p0 + p1) / 2
    me.from_pydata([v - center for v in verts], [], faces)
    me.update()
    ob = D.objects.new(name, me)
    ob.location = center
    link(ob, cname)
    if m and mat(m):
        me.materials.append(mat(m))
    if bevel:
        b = ob.modifiers.new("Bevel", 'BEVEL')
        b.width = bevel
        b.segments = 1
        b.limit_method = 'NONE'
    if parent:
        set_parent(ob, parent)
    return ob


def ico(name, loc, scale, sub=1, cname="Wolf", m="Stein", parent=None, rot=(0, 0, 0), seed=0, jitter=0.0):
    me = D.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    if jitter:
        rnd = random.Random(seed)
        for v in bm.verts:
            v.co *= 1 + rnd.uniform(-jitter, jitter)
    bm.to_mesh(me)
    bm.free()
    ob = D.objects.new(name, me)
    ob.location = loc
    ob.scale = scale
    ob.rotation_euler = rot
    link(ob, cname)
    if m and mat(m):
        me.materials.append(mat(m))
    if parent:
        set_parent(ob, parent)
    return ob


def cone(name, base, tip, r, verts=4, cname="Wolf", m="Stein", parent=None, twist=0.0):
    base = Vector(base); tip = Vector(tip)
    d = tip - base
    L = d.length
    me = D.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=0.0, depth=L)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, L / 2))
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(twist, 3, 'Z'))
    bm.to_mesh(me)
    bm.free()
    ob = D.objects.new(name, me)
    ob.location = base
    ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    ob.rotation_mode = 'XYZ'
    link(ob, cname)
    if m and mat(m):
        me.materials.append(mat(m))
    if parent:
        set_parent(ob, parent)
    return ob


def empty(name, loc, cname="Wolf", parent=None, size=0.3):
    ob = D.objects.new(name, None)
    ob.empty_display_size = size
    ob.location = loc
    link(ob, cname)
    if parent:
        set_parent(ob, parent)
    return ob


def set_parent(ob, parent):
    if isinstance(parent, str):
        parent = D.objects[parent]
    C.view_layer.update()
    ob.parent = parent
    ob.matrix_parent_inverse = parent.matrix_world.inverted()


def curve_obj(name, pts, bevel=0.03, cname="FX", m="Gluehen", closed=False, ctype='POLY', parent=None, res=12):
    cu = D.curves.new(name, 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = bevel
    cu.bevel_resolution = 2
    cu.resolution_u = res
    sp = cu.splines.new(ctype)
    if ctype == 'BEZIER':
        sp.bezier_points.add(len(pts) - 1)
        for bp, p in zip(sp.bezier_points, pts):
            bp.co = p
            bp.handle_left_type = bp.handle_right_type = 'AUTO'
    else:
        sp.points.add(len(pts) - 1)
        for pt, p in zip(sp.points, pts):
            pt.co = (p[0], p[1], p[2], 1)
    sp.use_cyclic_u = closed
    ob = D.objects.new(name, cu)
    link(ob, cname)
    if m and mat(m):
        cu.materials.append(mat(m))
    if parent:
        set_parent(ob, parent)
    return ob


def driver(idblock, path, expr, index=-1):
    fc = idblock.driver_add(path, index) if index >= 0 else idblock.driver_add(path)
    fc.driver.type = 'SCRIPTED'
    fc.driver.expression = expr
    return fc
