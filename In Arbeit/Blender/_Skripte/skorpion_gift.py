# Skorpion: Giftstrahl aus dem Stachel (beim Stich) + Scheren-Schlag mit Schockwelle im Boden
# Ablauf (Loop 300 Frames @ 60 fps):
#   180-200 Ladung glimmt an der Stachelspitze, 205-222 Stich (Schwanz-Bogen nach vorne ueber den Kopf)
#   207-234 Giftstrahl (folgt dem Stachel, Ursprung IN der Spitze), 211-245 Einschlag gluet im Boden
#   232-246 Scheren heben, 254 Schlag auf den Boden, 254-290 Schockwelle (Ring im Bodenmaterial), Runen blitzen, Nebel wird weggedrueckt
import bpy, bmesh, math, random
from mathutils import Vector, Matrix
D = bpy.data; C = bpy.context; sc = bpy.context.scene
FX = "Skorpion_FX"
VIO = (0.62, 0.22, 1.0, 1.0); PINK = (1.0, 0.62, 1.0, 1.0)

# Stich-Bogen: Schwanz wirft sich nach vorne ueber den Ruecken, Stachel zeigt ueber dem Kopf nach vorne-unten
STRIKE = [0.4, 0.25, 0.1, -0.175, -0.45, -0.45]
# Weltrichtung des Strahls in der Stich-Pose (flach genug, um ueber Kopf + Scheren zu gehen)
BEAM_DIR = (0.88, -0.07, -0.47)


def drv(idb, path, idx, expr, vars=()):
    try: idb.driver_remove(path, idx) if idx >= 0 else idb.driver_remove(path)
    except TypeError: pass
    fc = idb.driver_add(path, idx) if idx >= 0 else idb.driver_add(path)
    d = fc.driver; d.type = 'SCRIPTED'
    for v in list(d.variables): d.variables.remove(v)
    for name, tid, dp in vars:
        v = d.variables.new(); v.name = name; v.type = 'SINGLE_PROP'
        if tid.id_type if hasattr(tid, "id_type") else False: pass
        v.targets[0].id = tid; v.targets[0].data_path = dp
    d.expression = expr
    return fc


def keyprop(ob, prop, keys, interp='BEZIER'):
    from bpy_extras import anim_utils
    if prop in ob: del ob[prop]
    ob[prop] = 0.0
    for f, v in keys:   # float() noetig: ob[prop] = 1 macht die Property zum INT (-0.6 -> -1, Zwischenwerte weg)
        ob[prop] = float(v); ob.keyframe_insert(f'["{prop}"]', frame=f)
    ob.update_tag()
    ad = ob.animation_data
    for fc in anim_utils.action_get_channelbag_for_slot(ad.action, ad.action_slot).fcurves:
        if fc.data_path == f'["{prop}"]':
            for k in fc.keyframe_points: k.interpolation = interp


def coll(name):
    c = D.collections.get(name)
    if not c: c = D.collections.new(name); sc.collection.children.link(c)
    return c


def clear():
    for o in list(D.objects):
        if o.name.startswith(("Sk_Gift", "Sk_Welle")): D.objects.remove(o, do_unlink=True)


def cone_mesh(name, r0, r1, seg=24, rings=6):
    me = D.meshes.get(name)
    if me: D.meshes.remove(me)
    bm = bmesh.new(); rows = []
    for k in range(rings + 1):
        f = k / rings; r = r0 + (r1 - r0) * f
        rows.append([bm.verts.new((math.cos(2 * math.pi * i / seg) * r, math.sin(2 * math.pi * i / seg) * r, f)) for i in range(seg)])
    for k in range(rings):
        for i in range(seg):
            bm.faces.new((rows[k][i], rows[k][(i + 1) % seg], rows[k + 1][(i + 1) % seg], rows[k + 1][i]))
    me = D.meshes.new(name); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    return me


def beam_material(name, col, strength, alpha, flow):
    m = D.materials.get(name) or D.materials.new(name)
    m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    noi = nt.nodes.new("ShaderNodeTexNoise"); noi.noise_dimensions = '4D'
    noi.inputs["Scale"].default_value = 3.0; noi.inputs["Detail"].default_value = 4.0
    mp = nt.nodes.new("ShaderNodeMapping"); mp.vector_type = 'POINT'; mp.inputs["Scale"].default_value = (2.5, 2.5, 0.6)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"]); nt.links.new(mp.outputs["Vector"], noi.inputs["Vector"])
    # Fliessen entlang des Strahls: W + Z-Verschiebung laufen mit der Zeit
    fc = nt.driver_add(f'nodes["{noi.name}"].inputs[1].default_value'); fc.driver.expression = f"frame*{flow}"
    fc = nt.driver_add(f'nodes["{mp.name}"].inputs[1].default_value', 2); fc.driver.expression = f"-frame*{flow * 3}"
    rmp = nt.nodes.new("ShaderNodeMapRange"); rmp.inputs[1].default_value = 0.35; rmp.inputs[2].default_value = 0.75
    rmp.inputs[3].default_value = 0.35; rmp.inputs[4].default_value = 1.6
    nt.links.new(noi.outputs["Fac"], rmp.inputs[0])
    sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    # am Ende (z=1) und ganz am Anfang leicht ausblenden
    fade = nt.nodes.new("ShaderNodeMapRange"); fade.inputs[1].default_value = 1.0; fade.inputs[2].default_value = 0.82
    nt.links.new(sep.outputs["Z"], fade.inputs[0])
    em = nt.nodes.new("ShaderNodeEmission"); em.inputs["Color"].default_value = col
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = strength
    nt.links.new(rmp.outputs[0], mul.inputs[0]); nt.links.new(mul.outputs[0], em.inputs["Strength"])
    al = nt.nodes.new("ShaderNodeMath"); al.operation = 'MULTIPLY'; al.inputs[1].default_value = alpha
    al2 = nt.nodes.new("ShaderNodeMath"); al2.operation = 'MULTIPLY'
    nt.links.new(rmp.outputs[0], al.inputs[0]); nt.links.new(al.outputs[0], al2.inputs[0]); nt.links.new(fade.outputs[0], al2.inputs[1])
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(al2.outputs[0], mix.inputs[0]); nt.links.new(tr.outputs[0], mix.inputs[1]); nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    try: m.surface_render_method = 'BLENDED'
    except Exception: pass
    m.use_backface_culling = False
    return m


def glow_material(name, col, strength):
    m = D.materials.get(name) or D.materials.new(name)
    m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial"); em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = col; em.inputs["Strength"].default_value = strength
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def set_strike():
    for i, v in enumerate(STRIKE):
        fc = next(fc for fc in D.objects[f"Sk_Schwanz_J{i}"].animation_data.drivers if fc.data_path == "rotation_euler" and fc.array_index == 1)
        fc.driver.expression = fc.driver.expression.rsplit("+", 1)[0] + f"+{v}*s"


def stinger_tip_local():
    sp = D.objects["Sk_Stachel_Spitze"]; pts = [b.co.copy() for b in sp.data.splines[0].bezier_points]
    return pts[-1], (pts[-1] - pts[-2]).normalized()


def build_poison():
    root = D.objects["Sk_Root"]; sp = D.objects["Sk_Stachel_Spitze"]
    keyprop(root, "ladung", ((1, 0), (180, 0), (200, 1), (210, 1), (216, 0), (300, 0)))
    keyprop(root, "gift", ((1, 0), (207, 0), (212, 1), (226, 1), (234, 0), (300, 0)))
    keyprop(root, "glut", ((1, 0), (211, 0), (215, 1), (230, 1), (246, 0), (300, 0)))
    g = ("g", root, '["gift"]')
    tip, d = stinger_tip_local()
    src = D.objects.new("Sk_Gift_Quelle", None); coll(FX).objects.link(src); src.empty_display_size = 0.3
    src.parent = sp; src.matrix_parent_inverse = Matrix.Identity(4)
    src.matrix_basis = Matrix.Translation(tip - d * 0.12) @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4()   # Ursprung IN der Spitze
    # Strahl NICHT entlang der Stachelspitze (die zeigt steil runter -> traf Kopf/Scheren),
    # sondern flach nach vorne ueber Kopf und Scheren hinweg: Weltrichtung in der Stich-Pose festlegen
    sc.frame_set(216); C.view_layer.update()
    pw = sp.matrix_world.to_3x3().normalized(); want = Vector(BEAM_DIR).normalized()
    loc_dir = (pw.inverted() @ want).normalized()
    src.matrix_basis = Matrix.Translation(tip - d * 0.12) @ loc_dir.to_track_quat('Z', 'Y').to_matrix().to_4x4()
    C.view_layer.update()
    mw = src.matrix_world; o = mw.translation.copy(); dirw = (mw.to_3x3() @ Vector((0, 0, 1))).normalized()
    L = o.z / -dirw.z + 0.15; hit = o + dirw * (L - 0.15); hit.z = 0.0
    m_out = beam_material("Sk_Gift_Strahl", VIO, 7.0, 0.6, 0.06)
    m_in = beam_material("Sk_Gift_Kern", PINK, 10.0, 0.9, 0.09)
    m_drop = glow_material("Sk_Gift_Tropfen", PINK, 25.0)
    for name, me, mat in (("Sk_Gift_Strahl", cone_mesh("Sk_Gift_Strahl", 0.14, 0.8), m_out), ("Sk_Gift_Kern", cone_mesh("Sk_Gift_Kern", 0.04, 0.2), m_in)):
        ob = D.objects.new(name, me); coll(FX).objects.link(ob); ob.parent = src; me.materials.append(mat)
        ob.visible_shadow = False
        drv(ob, "scale", 2, f"{L:.3f}*g", [g])
        for ax in (0, 1): drv(ob, "scale", ax, "0.25+0.75*g", [g])
    # Tropfen, die den Strahl entlang schiessen
    rnd = random.Random(4)
    drop_me = D.meshes.get("Sk_Gift_Tropfen_Mesh")
    if not drop_me:
        bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.07)
        drop_me = D.meshes.new("Sk_Gift_Tropfen_Mesh"); bm.to_mesh(drop_me); bm.free(); drop_me.materials.append(m_drop)
    for i in range(14):
        ob = D.objects.new(f"Sk_Gift_Tropfen_{i:02d}", drop_me); coll(FX).objects.link(ob); ob.parent = src
        a = rnd.uniform(0, 6.28); r = rnd.uniform(0.04, 0.22); off = rnd.uniform(0, 1); sp_ = rnd.uniform(0.04, 0.065)
        ob.location = (math.cos(a) * r, math.sin(a) * r, 0)
        ph = f"(frame*{sp_:.3f}+{off:.2f})"
        drv(ob, "location", 2, f"{L:.3f}*({ph}-floor({ph}))", [])
        s = rnd.uniform(0.6, 1.3)
        for ax in range(3): drv(ob, "scale", ax, f"{s:.2f}*g*(1.2 if ax else 1)" if False else f"{s:.2f}*g", [g])
    # Ladung: gluehende Kugel an der Spitze vor dem Stich
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=3, radius=0.22)
    me = D.meshes.new("Sk_Gift_Ladung"); bm.to_mesh(me); bm.free(); me.materials.append(m_drop)
    for p in me.polygons: p.use_smooth = True
    orb = D.objects.new("Sk_Gift_Ladung", me); coll(FX).objects.link(orb); orb.parent = src; orb.location = (0, 0, 0.05)
    for ax in range(3): drv(orb, "scale", ax, "l*(1+0.15*sin(frame*1.3))", [("l", root, '["ladung"]')])
    # Licht am Stachel + am Einschlag
    ld = D.lights.new("Sk_Gift_Licht", 'POINT'); ld.color = VIO[:3]; ld.shadow_soft_size = 0.3
    lo = D.objects.new("Sk_Gift_Licht", ld); coll(FX).objects.link(lo); lo.parent = src; lo.location = (0, 0, 0.4)
    drv(ld, "energy", -1, "400*g+150*l", [g, ("l", root, '["ladung"]')])
    ein = D.objects.new("Sk_Gift_Einschlag", None); coll(FX).objects.link(ein); ein.location = hit; ein.empty_display_size = 0.6
    ld = D.lights.new("Sk_Gift_Einschlag_Licht", 'POINT'); ld.color = PINK[:3]; ld.shadow_soft_size = 0.6
    lo = D.objects.new("Sk_Gift_Einschlag_Licht", ld); coll(FX).objects.link(lo); lo.location = hit + Vector((0, 0, 0.35))
    drv(ld, "energy", -1, "600*k*(1+0.25*sin(frame*0.9))", [("k", root, '["glut"]')])
    # Kristall-Spritzer am Einschlag (wachsen mit der Glut)
    for i in range(7):
        a = 2 * math.pi * i / 7 + rnd.uniform(-0.3, 0.3); tilt = rnd.uniform(0.35, 0.8); h = rnd.uniform(0.35, 0.7)
        bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=5, radius1=0.06, radius2=0.0, depth=1.0)
        bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.5))
        me = D.meshes.new(f"Sk_Gift_Spritzer_{i}"); bm.to_mesh(me); bm.free(); me.materials.append(m_drop)
        ob = D.objects.new(f"Sk_Gift_Spritzer_{i}", me); coll(FX).objects.link(ob)
        ob.location = hit + Vector((math.cos(a), math.sin(a), 0)) * 0.12
        ob.rotation_euler = (Matrix.Rotation(a, 3, 'Z') @ Matrix.Rotation(tilt, 3, 'Y')).to_euler()
        for ax in range(3): drv(ob, "scale", ax, f"k*{h:.2f}" if ax == 2 else "k", [("k", root, '["glut"]')])
    return hit


def build_slam():
    root = D.objects["Sk_Root"]
    keyprop(root, "schlag", ((1, 0), (232, 0), (246, 0.75), (254, -0.35), (262, -0.35), (284, 0), (300, 0)))
    keyprop(root, "welle", ((1, 0), (254, 0), (292, 1), (300, 1)), interp='LINEAR')
    a = ("a", root, '["schlag"]')
    for s, S, ph in ((-1, "L", 0.0), (1, "R", 1.3)):
        # Arm hebt (negativ um Y) und schlaegt runter (positiv)
        drv(D.objects[f"Sk_Schere_{S}0"], "rotation_euler", 1, "-0.5*a", [a])
        drv(D.objects[f"Sk_Schere_{S}1"], "rotation_euler", 1, f"0.05*sin(frame*2*pi/100+{ph + 0.6:.2f})-0.25*a", [a])
    body = D.objects["Sk_Koerper"]
    drv(body, "location", 2, "1.2+0.03*sin(frame*2*pi/75)+0.06*a", [a])     # Basis-Hoehe 1.2 beibehalten!
    drv(body, "rotation_euler", 1, "-0.05*a", [a])
    # Zentrum der Welle: zwischen den Haenden beim Aufschlag
    sc.frame_set(256); C.view_layer.update()
    hl, hr = D.objects["Sk_Schere_L2"].matrix_world.translation, D.objects["Sk_Schere_R2"].matrix_world.translation
    cen = (hl + hr) / 2; cen.z = 0.0
    wz = D.objects.new("Sk_Welle_Zentrum", None); coll(FX).objects.link(wz); wz.location = cen; wz.empty_display_size = 0.8
    ld = D.lights.new("Sk_Welle_Licht", 'POINT'); ld.color = VIO[:3]; ld.shadow_soft_size = 1.0
    lo = D.objects.new("Sk_Welle_Licht", ld); coll(FX).objects.link(lo); lo.location = cen + Vector((0, 0, 0.6))
    w = ("w", root, '["welle"]')
    drv(ld, "energy", -1, "1500*min(1,w*25)*(1-w)**2", [w])
    # Nebel wird nach aussen gedrueckt
    fog = D.objects["Sk_Nebel_Boden"]; bs = fog.get("basis_scale") or list(fog.scale); fog["basis_scale"] = list(bs)
    for ax in (0, 1): drv(fog, "scale", ax, f"{bs[ax]:.3f}*(1+0.35*sin(pi*w))", [w])
    drv(fog, "scale", 2, f"{bs[2]:.3f}*(1-0.3*sin(pi*w))", [w])
    return cen


def ground_effects():
    """Einschlag-Glut + Schockwellen-Ring + Runen-Blitz direkt im Bodenmaterial (keine Decals)."""
    m = D.materials["Sk_Boden"]; nt = m.node_tree; N = nt.nodes; Lk = nt.links
    for n in list(N):
        if n.name.startswith("FX_"): N.remove(n)
    root = D.objects["Sk_Root"]; out = next(n for n in N if n.type == 'OUTPUT_MATERIAL')
    base = N["Shader mischen"]

    def node(t, name, **kw):
        n = N.new(t); n.name = name; n.label = name
        for k, v in kw.items(): setattr(n, k, v)
        return n

    def val(name, expr, var):
        v = node("ShaderNodeValue", name)
        fc = nt.driver_add(f'nodes["{name}"].outputs[0].default_value'); d = fc.driver; d.type = 'SCRIPTED'
        for vv in list(d.variables): d.variables.remove(vv)
        x = d.variables.new(); x.name = var[0]; x.targets[0].id = var[1]; x.targets[0].data_path = var[2]
        d.expression = expr
        return v

    def dist(name, obj):
        tc = node("ShaderNodeTexCoord", name + "_TC"); tc.object = obj
        sep = node("ShaderNodeSeparateXYZ", name + "_Sep"); Lk.new(tc.outputs["Object"], sep.inputs[0])
        cmb = node("ShaderNodeCombineXYZ", name + "_Cmb"); Lk.new(sep.outputs[0], cmb.inputs[0]); Lk.new(sep.outputs[1], cmb.inputs[1])
        ln = node("ShaderNodeVectorMath", name + "_Len", operation='LENGTH'); Lk.new(cmb.outputs[0], ln.inputs[0])
        return ln.outputs["Value"]

    # Einschlag: weiche Glut + flackernde Risse
    d1 = dist("FX_Ein", D.objects["Sk_Gift_Einschlag"])
    r1 = node("ShaderNodeMapRange", "FX_Ein_Map"); r1.inputs[1].default_value = 0.0; r1.inputs[2].default_value = 1.3
    r1.inputs[3].default_value = 1.0; r1.inputs[4].default_value = 0.0; Lk.new(d1, r1.inputs[0])
    p1 = node("ShaderNodeMath", "FX_Ein_Pow", operation='POWER'); p1.inputs[1].default_value = 2.0; Lk.new(r1.outputs[0], p1.inputs[0])
    k = val("FX_Glut", "k*14", ("k", root, '["glut"]'))
    m1 = node("ShaderNodeMath", "FX_Ein_Mul", operation='MULTIPLY'); Lk.new(p1.outputs[0], m1.inputs[0]); Lk.new(k.outputs[0], m1.inputs[1])
    # Schockwelle: scharfer Ring + weicher Saum
    d2 = dist("FX_Welle", D.objects["Sk_Welle_Zentrum"])
    R = val("FX_Welle_R", "0.4+10*w", ("w", root, '["welle"]'))
    I = val("FX_Welle_I", "18*min(1,w*25)*(1-w)**1.5", ("w", root, '["welle"]'))
    sub = node("ShaderNodeMath", "FX_Welle_Sub", operation='SUBTRACT'); Lk.new(d2, sub.inputs[0]); Lk.new(R.outputs[0], sub.inputs[1])
    ab = node("ShaderNodeMath", "FX_Welle_Abs", operation='ABSOLUTE'); Lk.new(sub.outputs[0], ab.inputs[0])
    ring = node("ShaderNodeMapRange", "FX_Welle_Ring"); ring.inputs[1].default_value = 0.0; ring.inputs[2].default_value = 0.22
    ring.inputs[3].default_value = 1.0; ring.inputs[4].default_value = 0.0; Lk.new(ab.outputs[0], ring.inputs[0])
    saum = node("ShaderNodeMapRange", "FX_Welle_Saum"); saum.inputs[1].default_value = 0.0; saum.inputs[2].default_value = 1.2
    saum.inputs[3].default_value = 0.35; saum.inputs[4].default_value = 0.0; Lk.new(ab.outputs[0], saum.inputs[0])
    ad = node("ShaderNodeMath", "FX_Welle_Add", operation='ADD'); Lk.new(ring.outputs[0], ad.inputs[0]); Lk.new(saum.outputs[0], ad.inputs[1])
    m2 = node("ShaderNodeMath", "FX_Welle_Mul", operation='MULTIPLY'); Lk.new(ad.outputs[0], m2.inputs[0]); Lk.new(I.outputs[0], m2.inputs[1])
    em1 = node("ShaderNodeEmission", "FX_Ein_Em"); em1.inputs["Color"].default_value = PINK; Lk.new(m1.outputs[0], em1.inputs["Strength"])
    em2 = node("ShaderNodeEmission", "FX_Welle_Em"); em2.inputs["Color"].default_value = VIO; Lk.new(m2.outputs[0], em2.inputs["Strength"])
    a1 = node("ShaderNodeAddShader", "FX_Add1"); a2 = node("ShaderNodeAddShader", "FX_Add2")
    Lk.new(base.outputs[0], a1.inputs[0]); Lk.new(em1.outputs[0], a1.inputs[1])
    Lk.new(a1.outputs[0], a2.inputs[0]); Lk.new(em2.outputs[0], a2.inputs[1])
    Lk.new(a2.outputs[0], out.inputs["Surface"])
    # Runen blitzen beim Aufschlag: Staerke der Runen-Emission multiplizieren
    st = N["Mathe.017"]; emr = N["Emission"]
    bl = val("FX_Runen_Blitz", "1+3*min(1,w*25)*(1-w)**2", ("w", root, '["welle"]'))
    mr = node("ShaderNodeMath", "FX_Runen_Mul", operation='MULTIPLY')
    Lk.new(st.outputs[0], mr.inputs[0]); Lk.new(bl.outputs[0], mr.inputs[1]); Lk.new(mr.outputs[0], emr.inputs["Strength"])
    for i, n in enumerate(n for n in N if n.name.startswith("FX_")):
        n.location = (1400 + (i % 6) * 200, -900 - (i // 6) * 220)


def build_all():
    clear(); set_strike()
    hit = build_poison(); cen = build_slam(); ground_effects()
    sc.frame_set(1)
    return hit, cen
