exec(open(r"C:\Users\finns\OneDrive\Desktop\Claude\Games\In Arbeit\Blender\_Skripte\wolf_helpers.py", encoding="utf-8").read())

DC = "Drache"
DM = "Drachenstein"


def keep_parent(ob, parent, bone=None):
    if isinstance(parent, str):
        parent = D.objects[parent]
    C.view_layer.update()
    mw = ob.matrix_world.copy()
    ob.parent = parent
    if bone:
        ob.parent_type = 'BONE'
        ob.parent_bone = bone
    ob.matrix_parent_inverse = Matrix.Identity(4)
    C.view_layer.update()
    ob.matrix_world = mw
    return ob


def smooth_box(ob, segs=3, width=None):
    ob.data.shade_smooth()
    b = ob.modifiers.get("Bevel")
    if b:
        b.segments = segs
        if width: b.width = width
        b.harden_normals = True
        b.profile = 0.6
    return ob


def smooth_cone(ob, w=0.012):
    ob.data.shade_smooth()
    b = ob.modifiers.new("Bevel", 'BEVEL'); b.width = w; b.segments = 2; b.limit_method = 'ANGLE'; b.harden_normals = True
    return ob


def disp_tex():
    t = D.textures.get("Stein_Displace")
    if not t:
        t = D.textures.new("Stein_Displace", 'CLOUDS'); t.noise_scale = 0.45; t.noise_depth = 3
    return t


def smooth_blob(ob, strength=0.12, levels=2):
    ob.data.shade_smooth()
    s = ob.modifiers.new("Subsurf", 'SUBSURF'); s.levels = levels; s.render_levels = levels
    d = ob.modifiers.new("Displace", 'DISPLACE'); d.texture = disp_tex(); d.texture_coords = 'OBJECT'; d.strength = strength
    return ob


def box(name, p0, p1, w0, h0, w1=None, h1=None, m=DM, parent=None, bevel=0.06, up=Vector((0, 0, 1)), segs=3):
    ob = frustum(name, p0, p1, w0, h0, w1, h1, cname=DC, m=m, bevel=bevel, parent=None, up=up)
    smooth_box(ob, segs)
    if parent: keep_parent(ob, parent)
    return ob


def blob(name, loc, scale, m=DM, parent=None, seed=0, strength=0.1, rot=(0, 0, 0)):
    ob = ico(name, loc, scale, sub=1, cname=DC, m=m, seed=seed, jitter=0.08, rot=rot)
    smooth_blob(ob, strength)
    if parent: keep_parent(ob, parent)
    return ob


def spike(name, base, tip, r, m=DM, parent=None, verts=5, twist=0.0, bevel=0.012):
    ob = cone(name, base, tip, r, verts=verts, cname=DC, m=m, twist=twist)
    smooth_cone(ob, bevel)
    if parent: keep_parent(ob, parent)
    return ob


def taper_obj():
    t = D.objects.get("Taper_Spitz")
    if t: return t
    cu = D.curves.new("Taper_Spitz", 'CURVE'); sp = cu.splines.new('BEZIER'); sp.bezier_points.add(2)
    for bp, co in zip(sp.bezier_points, ((-1, 1, 0), (0.2, 0.75, 0), (1, 0.0, 0))):
        bp.co = co; bp.handle_left_type = bp.handle_right_type = 'AUTO'
    t = D.objects.new("Taper_Spitz", cu); link(t, "Hilfsobjekte"); t.hide_viewport = True; t.hide_render = True
    return t


def horn(name, pts, r, m=DM, parent=None, res=10):
    ob = curve_obj(name, pts, bevel=r, cname=DC, m=m, ctype='BEZIER', res=res)
    ob.data.taper_object = taper_obj()
    ob.data.bevel_resolution = 3
    ob.data.use_fill_caps = True
    if parent: keep_parent(ob, parent)
    return ob


def jnt(name, loc, parent=None, size=0.25):
    ob = empty(name, loc, cname=DC, size=size)
    if parent: keep_parent(ob, parent)
    return ob
