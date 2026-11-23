# Skorpion: Umgebung (Boden mit Runenkreis, Wand, Himmel, Licht, Bloom) + Materialien
import bpy, math
D = bpy.data; C = bpy.context; sc = C.scene
VIO = (0.55, 0.12, 1.0, 1)


def coll(name):
    c = D.collections.get(name)
    if not c:
        c = D.collections.new(name); sc.collection.children.link(c)
    return c


def new_mat(name):
    old = D.materials.get(name)
    if old: D.materials.remove(old)
    m = D.materials.new(name); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_MATERIAL': nt.nodes.remove(n)
    return m, nt, next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')


def pulse(nt, expr):
    v = nt.nodes.new('ShaderNodeValue'); v.name = "Puls"
    fc = v.outputs[0].driver_add("default_value"); fc.driver.type = 'SCRIPTED'; fc.driver.expression = expr
    return v


def glow_mat(name, col, strength, expr="1+0.35*sin(frame*2*pi/75)"):
    m, nt, out = new_mat(name)
    e = nt.nodes.new('ShaderNodeEmission'); e.inputs['Color'].default_value = col
    mul = nt.nodes.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = strength
    nt.links.new(pulse(nt, expr).outputs[0], mul.inputs[0]); nt.links.new(mul.outputs[0], e.inputs['Strength'])
    nt.links.new(e.outputs[0], out.inputs['Surface']); m.diffuse_color = col
    return m


def stone_mat(name, base_col, crack_col=VIO, crack_scale=1.8, mask=(0.47, 0.54), crack_strength=10, dots=40, rough=0.55):
    """Stone with violet glowing cracks (voronoi edges masked by noise), object coords."""
    m, nt, out = new_mat(name); N = nt.nodes.new; L = nt.links.new
    tc = N('ShaderNodeTexCoord')
    b = N('ShaderNodeBsdfPrincipled'); b.inputs['Roughness'].default_value = rough
    noi = N('ShaderNodeTexNoise'); noi.inputs['Scale'].default_value = 3.0; noi.inputs['Detail'].default_value = 6
    L(tc.outputs['Object'], noi.inputs['Vector'])
    ramp = N('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = tuple(c * 0.55 for c in base_col[:3]) + (1,)
    ramp.color_ramp.elements[1].color = tuple(min(1, c * 1.6) for c in base_col[:3]) + (1,)
    L(noi.outputs['Fac'], ramp.inputs['Fac']); L(ramp.outputs['Color'], b.inputs['Base Color'])
    vd = N('ShaderNodeTexVoronoi'); vd.inputs['Scale'].default_value = dots; L(tc.outputs['Object'], vd.inputs['Vector'])
    vchip = N('ShaderNodeTexVoronoi'); vchip.inputs['Scale'].default_value = 6; L(tc.outputs['Object'], vchip.inputs['Vector'])
    hs = N('ShaderNodeMath'); hs.operation = 'MULTIPLY_ADD'; hs.inputs[1].default_value = 0.4
    L(vd.outputs['Distance'], hs.inputs[0]); L(vchip.outputs['Distance'], hs.inputs[2])
    bump = N('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.3; bump.invert = True
    L(hs.outputs[0], bump.inputs['Height']); L(bump.outputs['Normal'], b.inputs['Normal'])
    dn = N('ShaderNodeTexNoise'); dn.inputs['Scale'].default_value = 2.5; dn.inputs['Detail'].default_value = 4
    L(tc.outputs['Object'], dn.inputs['Vector'])
    add = N('ShaderNodeVectorMath'); add.operation = 'MULTIPLY_ADD'; add.inputs[1].default_value = (0.45, 0.45, 0.45)
    L(dn.outputs['Color'], add.inputs[0]); L(tc.outputs['Object'], add.inputs[2])
    vc = N('ShaderNodeTexVoronoi'); vc.feature = 'DISTANCE_TO_EDGE'; vc.inputs['Scale'].default_value = crack_scale
    L(add.outputs[0], vc.inputs['Vector'])
    edge = N('ShaderNodeMapRange'); edge.inputs['From Min'].default_value = 0.008; edge.inputs['From Max'].default_value = 0.028
    edge.inputs['To Min'].default_value = 1.0; edge.inputs['To Max'].default_value = 0.0
    L(vc.outputs['Distance'], edge.inputs['Value'])
    nm = N('ShaderNodeTexNoise'); nm.inputs['Scale'].default_value = 1.1; L(tc.outputs['Object'], nm.inputs['Vector'])
    nmr = N('ShaderNodeMapRange'); nmr.inputs['From Min'].default_value = mask[0]; nmr.inputs['From Max'].default_value = mask[1]
    L(nm.outputs['Fac'], nmr.inputs['Value'])
    msk = N('ShaderNodeMath'); msk.operation = 'MULTIPLY'; L(edge.outputs['Result'], msk.inputs[0]); L(nmr.outputs['Result'], msk.inputs[1])
    em = N('ShaderNodeEmission'); em.inputs['Color'].default_value = crack_col
    mul = N('ShaderNodeMath'); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = crack_strength
    L(pulse(nt, "1+0.35*sin(frame*2*pi/75)").outputs[0], mul.inputs[0]); L(mul.outputs[0], em.inputs['Strength'])
    ms = N('ShaderNodeMixShader'); L(msk.outputs[0], ms.inputs[0]); L(b.outputs[0], ms.inputs[1]); L(em.outputs[0], ms.inputs[2])
    L(ms.outputs[0], out.inputs['Surface']); m.diffuse_color = base_col
    return m


def build_materials():
    stone_mat("Sk_Panzer", (0.045, 0.02, 0.07, 1), crack_scale=1.8, mask=(0.47, 0.54))
    stone_mat("Sk_Platte", (0.06, 0.028, 0.09, 1), crack_scale=3.0, mask=(0.5, 0.56), dots=55)
    stone_mat("Sk_Kristall", (0.55, 0.5, 0.68, 1), crack_scale=2.2, mask=(0.52, 0.58), crack_strength=8, rough=0.35)
    glow_mat("Sk_Gluehen", VIO, 16)
    glow_mat("Sk_Augen", (0.8, 0.4, 1.0, 1), 40, "1+0.5*sin(frame*2*pi/50)")
    # stinger crystal: fresnel bright edges
    m, nt, out = new_mat("Sk_Stachel"); N = nt.nodes.new; L = nt.links.new
    lw = N('ShaderNodeLayerWeight'); lw.inputs['Blend'].default_value = 0.4
    e1 = N('ShaderNodeEmission'); e1.inputs['Color'].default_value = (0.45, 0.08, 1.0, 1); e1.inputs['Strength'].default_value = 7
    e2 = N('ShaderNodeEmission'); e2.inputs['Color'].default_value = (0.85, 0.6, 1.0, 1); e2.inputs['Strength'].default_value = 16
    ms = N('ShaderNodeMixShader'); L(lw.outputs['Fresnel'], ms.inputs[0]); L(e1.outputs[0], ms.inputs[1]); L(e2.outputs[0], ms.inputs[2])
    L(ms.outputs[0], out.inputs['Surface']); m.diffuse_color = (0.6, 0.3, 1, 1)
    # dark crystal shards + chain metal
    m, nt, out = new_mat("Sk_Splitter"); b = nt.nodes.new('ShaderNodeBsdfPrincipled')
    b.inputs['Base Color'].default_value = (0.03, 0.01, 0.05, 1); b.inputs['Roughness'].default_value = 0.2; b.inputs['Metallic'].default_value = 0.3
    nt.links.new(b.outputs[0], out.inputs['Surface']); m.diffuse_color = (0.05, 0.02, 0.08, 1)
    m, nt, out = new_mat("Sk_Kette"); b = nt.nodes.new('ShaderNodeBsdfPrincipled')
    b.inputs['Base Color'].default_value = (0.02, 0.015, 0.025, 1); b.inputs['Roughness'].default_value = 0.4; b.inputs['Metallic'].default_value = 0.9
    nt.links.new(b.outputs[0], out.inputs['Surface']); m.diffuse_color = (0.03, 0.02, 0.04, 1)
    # violet fog volume
    m, nt, out = new_mat("Sk_Nebel"); N = nt.nodes.new; L = nt.links.new
    tc = N('ShaderNodeTexCoord'); noi = N('ShaderNodeTexNoise'); noi.inputs['Scale'].default_value = 1.2; noi.inputs['Detail'].default_value = 4
    L(tc.outputs['Object'], noi.inputs['Vector'])
    gr = N('ShaderNodeMapRange'); gr.inputs['From Min'].default_value = 0.45; gr.inputs['From Max'].default_value = 0.75
    gr.inputs['To Min'].default_value = 0.0; gr.inputs['To Max'].default_value = 0.35
    L(noi.outputs['Fac'], gr.inputs['Value'])
    vol = N('ShaderNodeVolumePrincipled'); vol.inputs['Color'].default_value = (0.6, 0.3, 1.0, 1)
    vol.inputs['Emission Color'].default_value = VIO; vol.inputs['Emission Strength'].default_value = 0.6
    L(gr.outputs['Result'], vol.inputs['Density'])
    L(vol.outputs[0], out.inputs['Volume'])


def build_env():
    env = coll("Umgebung")
    # ground with rune circle mixed into the material (no decal!)
    bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0)); g = C.active_object; g.name = "Boden"
    for c in g.users_collection: c.objects.unlink(g)
    env.objects.link(g)
    m, nt, out = new_mat("Sk_Boden"); N = nt.nodes.new; L = nt.links.new
    tc = N('ShaderNodeTexCoord')
    b = N('ShaderNodeBsdfPrincipled'); b.inputs['Roughness'].default_value = 0.8
    mp = N('ShaderNodeMapping'); mp.vector_type = 'POINT'; mp.inputs['Scale'].default_value = (0.5, 0.5, 0.5)
    L(tc.outputs['Object'], mp.inputs['Vector'])
    ch = N('ShaderNodeTexChecker'); ch.inputs['Scale'].default_value = 1.0
    ch.inputs['Color1'].default_value = (0.13, 0.42, 0.04, 1); ch.inputs['Color2'].default_value = (0.09, 0.32, 0.03, 1)
    L(mp.outputs[0], ch.inputs['Vector'])
    # radial distance + angle around the scorpion (centre at x=-0.3)
    sep = N('ShaderNodeSeparateXYZ'); L(tc.outputs['Object'], sep.inputs[0])
    sx = N('ShaderNodeMath'); sx.operation = 'ADD'; sx.inputs[1].default_value = 0.3; L(sep.outputs['X'], sx.inputs[0])
    comb = N('ShaderNodeCombineXYZ'); L(sx.outputs[0], comb.inputs['X']); L(sep.outputs['Y'], comb.inputs['Y'])
    ln = N('ShaderNodeVectorMath'); ln.operation = 'LENGTH'; L(comb.outputs[0], ln.inputs[0])
    ang = N('ShaderNodeMath'); ang.operation = 'ARCTAN2'; L(sep.outputs['Y'], ang.inputs[0]); L(sx.outputs[0], ang.inputs[1])
    def ring(R, w):
        d = N('ShaderNodeMath'); d.operation = 'SUBTRACT'; d.inputs[1].default_value = R; L(ln.outputs['Value'], d.inputs[0])
        a = N('ShaderNodeMath'); a.operation = 'ABSOLUTE'; L(d.outputs[0], a.inputs[0])
        r = N('ShaderNodeMapRange'); r.inputs['From Min'].default_value = w * 0.4; r.inputs['From Max'].default_value = w
        r.inputs['To Min'].default_value = 1.0; r.inputs['To Max'].default_value = 0.0; L(a.outputs[0], r.inputs['Value'])
        return r.outputs['Result']
    r1 = ring(5.4, 0.07); r2 = ring(4.7, 0.05); r3 = ring(3.2, 0.04)
    # rune band between 4.75 and 5.35: angular cells with voronoi glyph strokes
    band = N('ShaderNodeMapRange'); band.inputs['From Min'].default_value = 4.8; band.inputs['From Max'].default_value = 5.3
    band.interpolation_type = 'STEPPED'; band.inputs['Steps'].default_value = 1.0
    L(ln.outputs['Value'], band.inputs['Value'])
    inb = N('ShaderNodeMath'); inb.operation = 'LESS_THAN'; inb.inputs[1].default_value = 5.3; L(ln.outputs['Value'], inb.inputs[0])
    inb2 = N('ShaderNodeMath'); inb2.operation = 'GREATER_THAN'; inb2.inputs[1].default_value = 4.8; L(ln.outputs['Value'], inb2.inputs[0])
    inband = N('ShaderNodeMath'); inband.operation = 'MULTIPLY'; L(inb.outputs[0], inband.inputs[0]); L(inb2.outputs[0], inband.inputs[1])
    pol = N('ShaderNodeCombineXYZ')
    angs = N('ShaderNodeMath'); angs.operation = 'MULTIPLY'; angs.inputs[1].default_value = 8.0; L(ang.outputs[0], angs.inputs[0])
    rads = N('ShaderNodeMath'); rads.operation = 'MULTIPLY'; rads.inputs[1].default_value = 4.0; L(ln.outputs['Value'], rads.inputs[0])
    L(angs.outputs[0], pol.inputs['X']); L(rads.outputs[0], pol.inputs['Y'])
    vg = N('ShaderNodeTexVoronoi'); vg.feature = 'DISTANCE_TO_EDGE'; vg.inputs['Scale'].default_value = 1.0
    L(pol.outputs[0], vg.inputs['Vector'])
    glyph = N('ShaderNodeMapRange'); glyph.inputs['From Min'].default_value = 0.03; glyph.inputs['From Max'].default_value = 0.08
    glyph.inputs['To Min'].default_value = 1.0; glyph.inputs['To Max'].default_value = 0.0; L(vg.outputs['Distance'], glyph.inputs['Value'])
    gl2 = N('ShaderNodeMath'); gl2.operation = 'MULTIPLY'; L(glyph.outputs['Result'], gl2.inputs[0]); L(inband.outputs[0], gl2.inputs[1])
    s1 = N('ShaderNodeMath'); s1.operation = 'MAXIMUM'; L(r1, s1.inputs[0]); L(r2, s1.inputs[1])
    s2 = N('ShaderNodeMath'); s2.operation = 'MAXIMUM'; L(s1.outputs[0], s2.inputs[0]); L(r3, s2.inputs[1])
    runes = N('ShaderNodeMath'); runes.operation = 'MAXIMUM'; L(s2.outputs[0], runes.inputs[0]); L(gl2.outputs[0], runes.inputs[1])
    # dark shadow disk inside circle
    dk = N('ShaderNodeMapRange'); dk.inputs['From Min'].default_value = 3.5; dk.inputs['From Max'].default_value = 5.8
    dk.inputs['To Min'].default_value = 0.85; dk.inputs['To Max'].default_value = 0.0; L(ln.outputs['Value'], dk.inputs['Value'])
    mixc = N('ShaderNodeMix'); mixc.data_type = 'RGBA'; L(dk.outputs['Result'], mixc.inputs['Factor'])
    L(ch.outputs['Color'], mixc.inputs[6]); mixc.inputs[7].default_value = (0.02, 0.01, 0.03, 1)
    L(mixc.outputs[2], b.inputs['Base Color'])
    em = N('ShaderNodeEmission'); em.inputs['Color'].default_value = VIO
    st = N('ShaderNodeMath'); st.operation = 'MULTIPLY'; st.inputs[1].default_value = 12
    L(pulse(nt, "1+0.4*sin(frame*2*pi/75+1)").outputs[0], st.inputs[0]); L(st.outputs[0], em.inputs['Strength'])
    ms = N('ShaderNodeMixShader'); L(runes.outputs[0], ms.inputs[0]); L(b.outputs[0], ms.inputs[1]); L(em.outputs[0], ms.inputs[2])
    L(ms.outputs[0], out.inputs['Surface'])
    g.data.materials.append(m)
    # wall + grass tops
    mw, nt, out = new_mat("Sk_Wand"); b = nt.nodes.new('ShaderNodeBsdfPrincipled'); br = nt.nodes.new('ShaderNodeTexBrick')
    br.inputs['Scale'].default_value = 0.6; br.inputs['Color1'].default_value = (0.42, 0.26, 0.15, 1); br.inputs['Color2'].default_value = (0.36, 0.22, 0.12, 1)
    br.inputs['Mortar'].default_value = (0.3, 0.19, 0.1, 1); br.inputs['Mortar Size'].default_value = 0.005
    nt.links.new(br.outputs['Color'], b.inputs['Base Color']); b.inputs['Roughness'].default_value = 0.9; nt.links.new(b.outputs[0], out.inputs['Surface'])
    mg, nt, out = new_mat("Sk_Gras"); b = nt.nodes.new('ShaderNodeBsdfPrincipled'); b.inputs['Base Color'].default_value = (0.12, 0.4, 0.04, 1)
    nt.links.new(b.outputs[0], out.inputs['Surface'])
    for name, loc, rz in (("Wand_Hinten", (0, 12, 2.5), 0.0), ("Wand_Links", (-14, 0, 2.5), math.pi / 2)):
        bpy.ops.mesh.primitive_cube_add(location=loc); w = C.active_object; w.name = name
        w.scale = (20, 0.3, 2.5); w.rotation_euler = (0, 0, rz)
        for c in w.users_collection: c.objects.unlink(w)
        env.objects.link(w); w.data.materials.append(mw)
        bpy.ops.mesh.primitive_cube_add(location=(loc[0], loc[1], 5.05)); t = C.active_object; t.name = name + "_Gras"
        t.scale = (20.1, 0.4, 0.06); t.rotation_euler = (0, 0, rz)
        for c in t.users_collection: c.objects.unlink(t)
        env.objects.link(t); t.data.materials.append(mg)
    # sky
    wd = sc.world or D.worlds.new("World"); sc.world = wd; wd.use_nodes = True; nt = wd.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_WORLD': nt.nodes.remove(n)
    out = next(n for n in nt.nodes if n.type == 'OUTPUT_WORLD'); N = nt.nodes.new; L = nt.links.new
    bg = N('ShaderNodeBackground'); tcw = N('ShaderNodeTexCoord'); sep = N('ShaderNodeSeparateXYZ'); L(tcw.outputs['Generated'], sep.inputs[0])
    grad = N('ShaderNodeValToRGB'); grad.color_ramp.elements[0].position = 0.0; grad.color_ramp.elements[0].color = (0.55, 0.7, 0.9, 1)
    grad.color_ramp.elements[1].position = 0.45; grad.color_ramp.elements[1].color = (0.12, 0.35, 0.85, 1); L(sep.outputs['Z'], grad.inputs['Fac'])
    noi = N('ShaderNodeTexNoise'); noi.inputs['Scale'].default_value = 3.0; noi.inputs['Detail'].default_value = 6; L(tcw.outputs['Generated'], noi.inputs['Vector'])
    cr = N('ShaderNodeMapRange'); cr.inputs['From Min'].default_value = 0.56; cr.inputs['From Max'].default_value = 0.72; L(noi.outputs['Fac'], cr.inputs['Value'])
    mix = N('ShaderNodeMix'); mix.data_type = 'RGBA'; L(cr.outputs['Result'], mix.inputs['Factor']); L(grad.outputs['Color'], mix.inputs[6])
    mix.inputs[7].default_value = (0.95, 0.95, 1.0, 1); L(mix.outputs[2], bg.inputs['Color']); L(bg.outputs[0], out.inputs['Surface'])
    # sun
    for o in [o for o in D.objects if o.type == 'LIGHT']: D.objects.remove(o)
    ld = D.lights.new("Sonne", 'SUN'); ld.energy = 3.2; ld.color = (1, 0.95, 0.9); ld.angle = math.radians(3)
    so = D.objects.new("Sonne", ld); env.objects.link(so); so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
    # bloom compositor + colour management + timing
    ng = D.node_groups.get("Sk_Leuchten") or D.node_groups.new("Sk_Leuchten", 'CompositorNodeTree')
    for n in list(ng.nodes): ng.nodes.remove(n)
    if not ng.interface.items_tree:
        ng.interface.new_socket("Image", in_out='OUTPUT', socket_type='NodeSocketColor')
    go = ng.nodes.new('NodeGroupOutput'); rl = ng.nodes.new('CompositorNodeRLayers'); gl = ng.nodes.new('CompositorNodeGlare')
    gl.inputs['Type'].default_value = 'Bloom'; gl.inputs['Strength'].default_value = 0.6; gl.inputs['Size'].default_value = 0.75
    ng.links.new(rl.outputs['Image'], gl.inputs['Image']); ng.links.new(gl.outputs['Image'], go.inputs[0])
    sc.compositing_node_group = ng
    try: sc.view_settings.view_transform = 'Khronos PBR Neutral'
    except TypeError: pass
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    sc.render.fps = 60; sc.frame_start, sc.frame_end = 1, 300
    try: sc.sync_mode = 'FRAME_DROP'
    except Exception: pass
    try:
        sc.eevee.taa_render_samples = 64; sc.eevee.taa_samples = 8
    except Exception: pass
