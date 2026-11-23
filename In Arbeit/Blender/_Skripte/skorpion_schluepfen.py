# Schluepf-Animation fuer das Skorpion-Ei (braucht skorpion_ei.py -> build_egg() vorher)
# Ablauf (Loop 300 Frames @ 60 fps):
#   60-159  Risse gluehen immer staerker, 80-158 Ei wackelt (immer heftiger)
#   160     Schale platzt: Oberteil in Stuecken weg (ballistisch), Unterteil bleibt als Schale stehen,
#           Lichtblitz + leuchtende Kugel + Funken
#   158-300 kleiner Skorpion (eigene Kopie 'Skorpion_Baby' mit eigener Bewegung): Scheren ueber den Rand,
#           hochziehen, oben balancieren, nach vorne kippen, mit hastigen Beinen weglaufen. Der grosse Skorpion bleibt unveraendert.
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler
D = bpy.data; C = bpy.context; sc = bpy.context.scene
SK = r"C:\Users\finns\OneDrive\Desktop\Claude\Games\In Arbeit\Blender\_Skripte"
exec(open(SK + r"\skorpion_ei.py", encoding="utf-8").read())
BURST = 160
FPS = 60.0
GRAV = 9.81
BABY_DIR = -0.52          # Richtung zum Rauskrabbeln (rad, weg vom grossen Skorpion)
PINK = (1.0, 0.62, 1.0, 1.0)


def keyprop(ob, prop, keys, interp='BEZIER'):
    from bpy_extras import anim_utils
    if prop in ob: del ob[prop]
    ob[prop] = 0.0
    for f, v in keys:
        ob[prop] = float(v); ob.keyframe_insert(f'["{prop}"]', frame=f)
    ob.update_tag()
    set_interp(ob, f'["{prop}"]', interp)


def set_interp(ob, path, interp):
    from bpy_extras import anim_utils
    ad = ob.animation_data
    if not ad or not ad.action: return
    for fc in anim_utils.action_get_channelbag_for_slot(ad.action, ad.action_slot).fcurves:
        if fc.data_path == path or path is None:
            for k in fc.keyframe_points: k.interpolation = interp


def drv(idb, path, idx, expr, vars=()):
    fc = idb.driver_add(path, idx) if idx >= 0 else idb.driver_add(path)
    d = fc.driver; d.type = 'SCRIPTED'
    for v in list(d.variables): d.variables.remove(v)
    for name, tid, dp in vars:
        v = d.variables.new(); v.name = name; v.targets[0].id = tid; v.targets[0].data_path = dp
    d.expression = expr
    return fc


def emissive(name, col, strength, fade_driver=None):
    m = D.materials.get(name) or D.materials.new(name)
    m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial"); em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = col; em.inputs["Strength"].default_value = strength
    if fade_driver:
        tr = nt.nodes.new("ShaderNodeBsdfTransparent"); mix = nt.nodes.new("ShaderNodeMixShader")
        val = nt.nodes.new("ShaderNodeValue"); val.name = "Fade"
        nt.links.new(val.outputs[0], mix.inputs[0]); nt.links.new(tr.outputs[0], mix.inputs[1]); nt.links.new(em.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs["Surface"])
        fc = nt.driver_add('nodes["Fade"].outputs[0].default_value'); d = fc.driver
        for v in list(d.variables): d.variables.remove(v)
        x = d.variables.new(); x.name = fade_driver[0]; x.targets[0].id = fade_driver[1]; x.targets[0].data_path = fade_driver[2]
        d.expression = fade_driver[3]
        try: m.surface_render_method = 'BLENDED'
        except Exception: pass
    else:
        nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def ballistic(ob, p0, v0, w0, rest_z, f0=BURST, step=2, spin_damp=0.6):
    """Flugbahn als Keyframes (lokal zum Parent): bis zur Landung, dann liegen bleiben."""
    rot0 = ob.rotation_euler.copy(); p = p0.copy(); v = v0.copy(); r = Vector(rot0[:]); w = w0.copy()
    for f in (1, f0 - 1):
        ob.location = p0; ob.rotation_euler = rot0
        ob.keyframe_insert("location", frame=f); ob.keyframe_insert("rotation_euler", frame=f)
    f = f0; landed = False; dt = step / FPS
    while f < 300:
        ob.location = p; ob.rotation_euler = Euler(r[:])
        ob.keyframe_insert("location", frame=f); ob.keyframe_insert("rotation_euler", frame=f)
        if landed: break
        v.z -= GRAV * dt; p = p + v * dt; r = r + w * dt
        if p.z <= rest_z:
            p.z = rest_z
            if v.z < -2.5:          # einmal kurz abprallen
                v = Vector((v.x * 0.45, v.y * 0.45, -v.z * 0.25)); w = w * spin_damp
            else:
                landed = True
        f += step
    ob.keyframe_insert("location", frame=300); ob.keyframe_insert("rotation_euler", frame=300)
    set_interp(ob, None, 'LINEAR')


def fracture(sh, wobble, rnd):
    """Schale in Stuecke teilen: Unterteil (gezackter Rand) bleibt, Oberteil -> ~14 Stuecke."""
    me = sh.data; mat = me.materials[0]
    seeds = []
    for i in range(14):
        z = rnd.uniform(-0.25, 0.95); a = rnd.uniform(0, 2 * math.pi)
        seeds.append(egg_point(Vector((math.cos(a) * math.sqrt(1 - z * z), math.sin(a) * math.sqrt(1 - z * z), z))))
    groups = {}
    for poly in me.polygons:
        c = poly.center; ang = math.atan2(c.y, c.x)
        rim = EI_H * (0.42 + 0.05 * math.sin(ang * 5) + 0.03 * math.sin(ang * 11 + 1))   # gezackter Rand
        key = "Unterteil" if c.z < rim else min(range(len(seeds)), key=lambda i: (seeds[i] - c).length)
        groups.setdefault(key, []).append(poly.index)
    pieces = []
    for key, idxs in groups.items():
        bm = bmesh.new(); vmap = {}
        for pi in idxs:
            poly = me.polygons[pi]; vs = []
            for vi in poly.vertices:
                if vi not in vmap: vmap[vi] = bm.verts.new(me.vertices[vi].co)
                vs.append(vmap[vi])
            bm.faces.new(vs)
        cen = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
        if key != "Unterteil":
            for v in bm.verts: v.co -= cen
        nm = "Ei_Unterteil" if key == "Unterteil" else f"Ei_Stueck_{key:02d}"
        m2 = D.meshes.new(nm); bm.to_mesh(m2); bm.free(); m2.materials.append(mat)
        for p in m2.polygons: p.use_smooth = False
        ob = D.objects.new(nm, m2); coll(EI).objects.link(ob); ob.parent = wobble
        ob.location = (0, 0, 0) if key == "Unterteil" else cen
        so = ob.modifiers.new("Dicke", 'SOLIDIFY'); so.thickness = 0.07; so.offset = -1.0
        pieces.append((ob, cen if key != "Unterteil" else None))
    D.objects.remove(sh, do_unlink=True)
    return pieces


BABY = "Skorpion_Baby"
BABY_S = 0.2            # Groesse des Babys (passt hochkant ins Ei)


def copy_scorpion():
    """Eigene Kopie aller Objekte der Sammlung 'Skorpion' (Daten geteilt), alle Bezuege auf die Kopien umgehaengt.
    Skelett + Koerper-Mesh bleiben am Ursprung (sonst doppelte Verschiebung durch CHILD_OF/Armature);
    bewegt wird nur die Root-Kopie."""
    c = D.collections.get(BABY)
    if c:
        for o in list(c.objects): D.objects.remove(o, do_unlink=True)
    else:
        c = D.collections.new(BABY); sc.collection.children.link(c)
    src = list(D.collections["Skorpion"].all_objects); mp = {}
    for o in src:
        n = o.copy(); n.name = "Bb_" + o.name[3:] if o.name.startswith("Sk_") else "Bb_" + o.name
        c.objects.link(n); mp[o] = n
    def m(t): return mp.get(t, t)
    for o, n in mp.items():
        if o.parent: n.parent = m(o.parent); n.matrix_parent_inverse = o.matrix_parent_inverse.copy()
        for md in n.modifiers:
            for attr in ("object", "curve", "target"):
                if getattr(md, attr, None) in mp: setattr(md, attr, mp[getattr(md, attr)])
        for cn in n.constraints:
            if getattr(cn, "target", None) in mp: cn.target = mp[cn.target]
        if n.type == 'ARMATURE':
            for pb in n.pose.bones:
                for cn in pb.constraints:
                    if getattr(cn, "target", None) in mp: cn.target = mp[cn.target]
        if n.animation_data:
            if n.animation_data.action and o.name == "Sk_Root": n.animation_data.action = None   # keine Stich/Schlag-Props
            for fc in n.animation_data.drivers:
                for v in fc.driver.variables:
                    for t in v.targets:
                        if t.id in mp: t.id = mp[t.id]
    return mp


def build_baby(root):
    mp = copy_scorpion(); B = {o.name: n for o, n in mp.items()}
    br = B["Sk_Root"]
    piv = D.objects.new("Ei_Baby", None); coll(EI).objects.link(piv); piv.parent = root; piv.empty_display_size = 0.6
    br.parent = piv; br.matrix_parent_inverse = Matrix.Identity(4); br.location = (0, 0, 0); br.rotation_euler = (0, 0, 0); br.scale = (1, 1, 1)
    keyprop(piv, "klettern", ((1, 0), (BURST, 0), (BURST + 12, 1.0), (BURST + 80, 1.0), (BURST + 105, 0.35), (300, 0.35)))
    keyprop(piv, "greifen", ((1, 0), (BURST + 4, 0), (BURST + 18, 1.0), (BURST + 45, 1.0), (BURST + 62, 0.0), (300, 0)))
    k = ("k", piv, '["klettern"]'); g = ("g", piv, '["greifen"]')
    # eigene Bewegung: hastiges Krabbeln statt Stich/Schlag
    drv(B["Sk_Koerper"], "location", 2, "1.2+0.04*k*sin(frame*2*pi/22)", [k])
    drv(B["Sk_Koerper"], "rotation_euler", 1, "0.05*k*sin(frame*2*pi/44)", [k])
    drv(B["Sk_Koerper"], "rotation_euler", 0, "0.08*k*sin(frame*2*pi/30)", [k])      # seitliches Wackeln beim Klettern
    drv(B["Sk_Koerper"], "rotation_euler", 2, "0.05*sin(frame*2*pi/60)", [])
    wave = [0.05, 0.06, 0.07, 0.08, 0.08, 0.07]; tuck = [0.15, 0.12, 0.1, 0.05, 0.0, 0.0]
    for i in range(6):
        j = B[f"Sk_Schwanz_J{i}"]
        drv(j, "rotation_euler", 1, f"{wave[i]}*sin(frame*2*pi/50-{i * 0.5:.2f})+{tuck[i]}*k", [k])   # beim Klettern Schwanz eingerollt
        drv(j, "rotation_euler", 2, f"0.1*sin(frame*2*pi/40-{i * 0.55:.2f})", [])
    for s, S, ph in ((-1, "L", 0.0), (1, "R", 1.6)):
        drv(B[f"Sk_Finger_{S}"], "rotation_euler", 2, f"{s}*(0.25+0.25*sin(frame*2*pi/26+{ph}))", [])
        drv(B[f"Sk_Schere_{S}0"], "rotation_euler", 1, f"-0.55*g+0.06*sin(frame*2*pi/30+{ph})", [g])     # Arme hoch ueber den Rand
        drv(B[f"Sk_Schere_{S}0"], "rotation_euler", 2, f"{-s}*0.08*sin(frame*2*pi/36+{ph})", [])
        drv(B[f"Sk_Schere_{S}1"], "rotation_euler", 1, f"0.4*g+0.08*sin(frame*2*pi/30+{ph + 0.6:.2f})", [g])  # Haende haken ein
        for i in range(4):
            ph2 = math.pi * ((i + (0 if S == "L" else 1)) % 2)
            leg = B[f"Sk_Bein_{S}{i}"]
            drv(leg, "rotation_euler", 2, f"(0.08+0.08*k)*sin(frame*2*pi/22+{ph2:.2f})", [k])
            drv(leg, "rotation_euler", 0, f"{s}*(0.05+0.07*k)*max(0,sin(frame*2*pi/22+{ph2:.2f}))", [k])
    drv(B["Sk_Kopf"], "rotation_euler", 2, "0.06*sin(frame*2*pi/34)", [])
    # Weg aus dem Ei: Scheren ueber den Rand, hochziehen, oben balancieren, nach vorne kippen, weglaufen
    out = Vector((math.cos(BABY_DIR), math.sin(BABY_DIR), 0)); rim = EI_H * 0.42
    path = [  # frame, Abstand, Hoehe, Neigung (neg = Nase hoch), Drehung
        (BURST - 2, -0.35, 0.05, -1.05, 0.0), (BURST + 14, -0.3, 0.25, -1.0, 0.05),
        (BURST + 30, -0.15, 0.55, -0.85, -0.06), (BURST + 46, 0.15, 0.85, -0.55, 0.05),
        (BURST + 60, 0.55, rim * 0.95, -0.12, -0.04), (BURST + 70, 0.85, rim * 0.95, 0.05, 0.0),
        (BURST + 82, 1.3, rim * 0.6, 0.45, 0.04), (BURST + 94, 1.75, 0.12, 0.22, -0.03),
        (BURST + 104, 2.05, 0.0, 0.0, 0.0), (300, 3.3, 0.0, 0.0, 0.12)]
    for f, d, z, tilt, yaw in path:
        piv.location = out * d + Vector((0, 0, z)); piv.rotation_euler = (0, tilt, BABY_DIR + yaw)
        piv.keyframe_insert("location", frame=f); piv.keyframe_insert("rotation_euler", frame=f)
    # vor dem Schluepfen unsichtbar (Groesse 0), danach fest
    for f, sv in ((1, 0.0), (BURST - 3, 0.0), (BURST - 2, BABY_S), (300, BABY_S * 1.08)):
        piv.scale = (sv, sv, sv); piv.keyframe_insert("scale", frame=f)
    from bpy_extras import anim_utils
    ad = piv.animation_data
    for fc in anim_utils.action_get_channelbag_for_slot(ad.action, ad.action_slot).fcurves:
        if fc.data_path == "scale":
            for kp in fc.keyframe_points: kp.interpolation = 'CONSTANT' if kp.co[0] < BURST - 2 else 'LINEAR'


def build_hatch(seed=11):
    rnd = random.Random(seed)
    root = build_egg()
    for o in list(coll(EI).objects):
        if o.name.startswith("Ei_Grat_"): D.objects.remove(o, do_unlink=True)    # Grate waren im Render kaum sichtbar
    def angdiff(x, y): return abs((x - y + math.pi) % (2 * math.pi) - math.pi)
    for o in list(coll(EI).objects):   # Luecke im Nest, wo das Baby rauslaeuft
        if o.name.startswith(("Ei_Stein_", "Ei_Kristall_")) and angdiff(math.atan2(o.location.y, o.location.x), BABY_DIR) < 0.6:
            D.objects.remove(o, do_unlink=True)
    keyprop(root, "wackel", ((1, 0), (80, 0), (120, 0.3), (150, 1.0), (158, 1.0), (BURST, 0), (300, 0)))
    keyprop(root, "gluehen", ((1, 0), (60, 0), (150, 1.0), (159, 1.8), (BURST + 4, 0.5), (210, 0), (300, 0)))
    keyprop(root, "blitz", ((1, 0), (BURST - 1, 0), (BURST + 1, 1.0), (BURST + 25, 0), (300, 0)))
    keyprop(root, "kugel", ((1, 0), (BURST, 0), (BURST + 18, 1.0), (300, 1.0)), interp='LINEAR')
    # Wackeln: Pivot am Boden, Stoesse werden heftiger
    wob = D.objects.new("Ei_Wackel", None); coll(EI).objects.link(wob); wob.parent = root; wob.empty_display_size = 0.5
    w = ("w", root, '["wackel"]')
    drv(wob, "rotation_euler", 0, "w*(0.07*sin(frame*0.75)+0.05*sin(frame*2.1+1))", [w])
    drv(wob, "rotation_euler", 1, "w*(0.07*sin(frame*0.9+2)+0.05*sin(frame*2.6))", [w])
    drv(wob, "location", 2, "w*0.04*max(0,sin(frame*1.7))", [w])
    # Risse gluehen staerker (Puls-Wert der eigenen Schalen-Material-Kopie)
    nt = D.materials["Sk_Ei_Schale"].node_tree
    fc = next(f for f in nt.animation_data.drivers if 'Puls' in f.data_path); d = fc.driver
    for v in list(d.variables): d.variables.remove(v)
    x = d.variables.new(); x.name = "g"; x.targets[0].id = root; x.targets[0].data_path = '["gluehen"]'
    d.expression = "(1+0.35*sin(frame*2*pi/75))*(1+6*g)"
    # Schale zerteilen + Stuecke wegfliegen lassen
    sh = D.objects["Ei_Schale"]; pieces = fracture(sh, wob, rnd)
    for ob, cen in pieces:
        if cen is None: continue
        out = Vector((cen.x, cen.y, 0)); out = out.normalized() if out.length > 0.05 else Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0)).normalized()
        ang = math.atan2(out.y, out.x); dd = (ang - BABY_DIR + math.pi) % (2 * math.pi) - math.pi
        if abs(dd) < 0.9:   # keine Stuecke auf den Laufweg des Babys
            ang = BABY_DIR + math.copysign(0.9 + rnd.uniform(0, 0.6), dd if dd else 1); out = Vector((math.cos(ang), math.sin(ang), 0))
        hz = cen.z / EI_H
        v0 = out * rnd.uniform(1.6, 3.2) + Vector((0, 0, rnd.uniform(2.5, 4.5) + 2.0 * hz))
        w0 = Vector((rnd.uniform(-8, 8), rnd.uniform(-8, 8), rnd.uniform(-4, 4)))
        ballistic(ob, cen, v0, w0, rest_z=0.12)
    # Blitz: Licht im Ei + leuchtende Kugel, die sich ausbreitet und verblasst
    ld = D.lights.new("Ei_Blitz", 'POINT'); ld.color = (0.75, 0.4, 1.0); ld.shadow_soft_size = 1.0
    lo = D.objects.new("Ei_Blitz", ld); coll(EI).objects.link(lo); lo.parent = root; lo.location = (0, 0, EI_H * 0.6)
    drv(ld, "energy", -1, "6000*b", [("b", root, '["blitz"]')])
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    me = D.meshes.new("Ei_Blitz_Kugel"); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    k = ("k", root, '["kugel"]')
    me.materials.append(emissive("Sk_Ei_Blitz", (0.8, 0.45, 1.0, 1.0), 5.0, ("k", root, '["kugel"]', "0.4*(1-k)**2*min(1,k*40)")))
    kb = D.objects.new("Ei_Blitz_Kugel", me); coll(EI).objects.link(kb); kb.parent = root; kb.location = (0, 0, EI_H * 0.55)
    kb.visible_shadow = False
    for ax in range(3): drv(kb, "scale", ax, "0.05+2.6*k" if ax < 2 else "0.05+2.0*k", [k])
    # Funken (leuchtende Kristall-Spitzen), ballistisch, schrumpfen weg
    m_sp = emissive("Sk_Ei_Funke", PINK, 30.0)
    for i in range(26):
        bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=0.035, radius2=0.0, depth=0.22)
        me = D.meshes.new(f"Ei_Funke_{i:02d}"); bm.to_mesh(me); bm.free(); me.materials.append(m_sp)
        sp = D.objects.new(f"Ei_Funke_{i:02d}", me); coll(EI).objects.link(sp); sp.parent = root
        a = rnd.uniform(0, 2 * math.pi); el = rnd.uniform(0.3, 1.2)
        dirv = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
        sp.rotation_euler = dirv.to_track_quat('Z', 'Y').to_euler()
        p0 = Vector((0, 0, EI_H * 0.6)); v0 = dirv * rnd.uniform(5, 9)
        life = rnd.randint(24, 44)
        sp.scale = (0, 0, 0)
        for f in (1, BURST - 1): sp.location = p0; sp.keyframe_insert("location", frame=f); sp.keyframe_insert("scale", frame=f)
        p, v = p0.copy(), v0.copy()
        for f in range(BURST, BURST + life + 1, 2):
            t = (f - BURST) / life
            sp.location = p; s = 1.4 * (1 - t); sp.scale = (s, s, s * 1.5)
            sp.keyframe_insert("location", frame=f); sp.keyframe_insert("scale", frame=f)
            v.z -= GRAV * 2 / FPS; p = p + v * 2 / FPS
            if p.z < 0.05: p.z = 0.05; v.z = abs(v.z) * 0.3
        sp.scale = (0, 0, 0); sp.keyframe_insert("scale", frame=BURST + life + 2)
        set_interp(sp, None, 'LINEAR')
    build_baby(root)
    sc.frame_set(1)
    return root
