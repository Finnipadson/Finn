import bpy
D = bpy.data
RED = (1.0, 0.04, 0.015, 1)


def new_mat(name):
    old = D.materials.get(name)
    if old:
        D.materials.remove(old)
    m = D.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_MATERIAL':
            nt.nodes.remove(n)
    out = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')
    return m, nt, out


def pulse(nt, expr):
    v = nt.nodes.new('ShaderNodeValue'); v.name = "Puls"
    fc = v.outputs[0].driver_add("default_value")
    fc.driver.type = 'SCRIPTED'; fc.driver.expression = expr
    return v


def emission_mat(name, col, strength, expr="1"):
    m, nt, out = new_mat(name)
    e = nt.nodes.new('ShaderNodeEmission'); e.inputs['Color'].default_value = col
    mul = nt.nodes.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = strength
    nt.links.new(pulse(nt, expr).outputs[0], mul.inputs[0])
    nt.links.new(mul.outputs[0], e.inputs['Strength'])
    nt.links.new(e.outputs[0], out.inputs['Surface'])
    m.diffuse_color = col
    return m


def stone(name, base=0.05, crack=True, crack_scale=2.0, mask_lo=0.5, mask_hi=0.57, crack_strength=12, dots=45):
    m, nt, out = new_mat(name)
    N = nt.nodes.new; L = nt.links.new
    tc = N('ShaderNodeTexCoord')
    bsdf = N('ShaderNodeBsdfPrincipled'); bsdf.inputs['Roughness'].default_value = 0.8
    noi = N('ShaderNodeTexNoise'); noi.inputs['Scale'].default_value = 3.0; noi.inputs['Detail'].default_value = 6
    L(tc.outputs['Object'], noi.inputs['Vector'])
    ramp = N('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (base * 0.5, base * 0.45, base * 0.47, 1)
    ramp.color_ramp.elements[1].color = (base * 1.9, base * 1.8, base * 1.85, 1)
    L(noi.outputs['Fac'], ramp.inputs['Fac'])
    oi = N('ShaderNodeObjectInfo')
    mix = N('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'; mix.inputs['Factor'].default_value = 1.0
    L(ramp.outputs['Color'], mix.inputs[6])
    mr = N('ShaderNodeMapRange'); mr.inputs['To Min'].default_value = 0.75; mr.inputs['To Max'].default_value = 1.25
    L(oi.outputs['Random'], mr.inputs['Value']); L(mr.outputs['Result'], mix.inputs[7])
    L(mix.outputs[2], bsdf.inputs['Base Color'])
    # bump: fine dots + larger chips
    vd = N('ShaderNodeTexVoronoi'); vd.inputs['Scale'].default_value = dots
    L(tc.outputs['Object'], vd.inputs['Vector'])
    vchip = N('ShaderNodeTexVoronoi'); vchip.inputs['Scale'].default_value = 7
    L(tc.outputs['Object'], vchip.inputs['Vector'])
    hsum = N('ShaderNodeMath'); hsum.operation = 'MULTIPLY_ADD'; hsum.inputs[1].default_value = 0.4
    L(vd.outputs['Distance'], hsum.inputs[0]); L(vchip.outputs['Distance'], hsum.inputs[2])
    bump = N('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.35; bump.invert = True
    L(hsum.outputs[0], bump.inputs['Height']); L(bump.outputs['Normal'], bsdf.inputs['Normal'])
    m.diffuse_color = (base * 1.5, base * 1.5, base * 1.5, 1)
    if not crack:
        L(bsdf.outputs[0], out.inputs['Surface']); return m
    dn = N('ShaderNodeTexNoise'); dn.inputs['Scale'].default_value = 2.5; dn.inputs['Detail'].default_value = 4
    L(tc.outputs['Object'], dn.inputs['Vector'])
    add = N('ShaderNodeVectorMath'); add.operation = 'MULTIPLY_ADD'; add.inputs[1].default_value = (0.45, 0.45, 0.45)
    L(dn.outputs['Color'], add.inputs[0]); L(tc.outputs['Object'], add.inputs[2])
    vc = N('ShaderNodeTexVoronoi'); vc.feature = 'DISTANCE_TO_EDGE'; vc.inputs['Scale'].default_value = crack_scale
    L(add.outputs[0], vc.inputs['Vector'])
    edge = N('ShaderNodeMapRange'); edge.inputs['From Min'].default_value = 0.008; edge.inputs['From Max'].default_value = 0.03
    edge.inputs['To Min'].default_value = 1.0; edge.inputs['To Max'].default_value = 0.0
    L(vc.outputs['Distance'], edge.inputs['Value'])
    nm = N('ShaderNodeTexNoise'); nm.inputs['Scale'].default_value = 1.1
    L(tc.outputs['Object'], nm.inputs['Vector'])
    nmr = N('ShaderNodeMapRange'); nmr.inputs['From Min'].default_value = mask_lo; nmr.inputs['From Max'].default_value = mask_hi
    L(nm.outputs['Fac'], nmr.inputs['Value'])
    msk = N('ShaderNodeMath'); msk.operation = 'MULTIPLY'
    L(edge.outputs['Result'], msk.inputs[0]); L(nmr.outputs['Result'], msk.inputs[1])
    # glow halo next to cracks (darker red tint in the stone)
    halo = N('ShaderNodeMapRange'); halo.inputs['From Min'].default_value = 0.02; halo.inputs['From Max'].default_value = 0.09
    halo.inputs['To Min'].default_value = 1.0; halo.inputs['To Max'].default_value = 0.0
    L(vc.outputs['Distance'], halo.inputs['Value'])
    hm = N('ShaderNodeMath'); hm.operation = 'MULTIPLY'
    L(halo.outputs['Result'], hm.inputs[0]); L(nmr.outputs['Result'], hm.inputs[1])
    em = N('ShaderNodeEmission'); em.inputs['Color'].default_value = RED
    mul = N('ShaderNodeMath'); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = crack_strength
    L(pulse(nt, "1+0.35*sin(frame*2*pi/30)").outputs[0], mul.inputs[0]); L(mul.outputs[0], em.inputs['Strength'])
    em2 = N('ShaderNodeEmission'); em2.inputs['Color'].default_value = (0.6, 0.01, 0.0, 1); em2.inputs['Strength'].default_value = 0.6
    mh = N('ShaderNodeMixShader'); L(hm.outputs[0], mh.inputs[0]); L(bsdf.outputs[0], mh.inputs[1]); L(em2.outputs[0], mh.inputs[2])
    ms = N('ShaderNodeMixShader')
    L(msk.outputs[0], ms.inputs[0]); L(mh.outputs[0], ms.inputs[1]); L(em.outputs[0], ms.inputs[2])
    L(ms.outputs[0], out.inputs['Surface'])
    return m


def build_all():
    stone("Drachenstein", 0.045, True, crack_scale=2.0, mask_lo=0.46, mask_hi=0.53)
    stone("Panzer", 0.06, True, crack_scale=3.5, mask_lo=0.5, mask_hi=0.56, dots=60)
    stone("Kopfstein", 0.13, True, crack_scale=2.5, mask_lo=0.56, mask_hi=0.62, dots=55)
    stone("Brocken", 0.035, False)
    emission_mat("Gluehen", RED, 18, "1+0.35*sin(frame*2*pi/30)")
    emission_mat("Augen", (1, 0.12, 0.05, 1), 45, "1+0.5*sin(frame*2*pi/20)")
    emission_mat("Blitz", (1, 0.35, 0.4, 1), 60)
    emission_mat("Maul", (0.7, 0.02, 0.01, 1), 4, "1+0.3*sin(frame*2*pi/30)")
    emission_mat("Ring", (1, 0.15, 0.2, 1), 10)
    # claws: glowing crystal (fresnel brighter edges)
    m, nt, out = new_mat("Kristall")
    N = nt.nodes.new; L = nt.links.new
    lw = N('ShaderNodeLayerWeight'); lw.inputs['Blend'].default_value = 0.4
    e1 = N('ShaderNodeEmission'); e1.inputs['Color'].default_value = (1, 0.05, 0.03, 1); e1.inputs['Strength'].default_value = 8
    e2 = N('ShaderNodeEmission'); e2.inputs['Color'].default_value = (1, 0.45, 0.45, 1); e2.inputs['Strength'].default_value = 25
    ms = N('ShaderNodeMixShader'); L(lw.outputs['Fresnel'], ms.inputs[0]); L(e1.outputs[0], ms.inputs[1]); L(e2.outputs[0], ms.inputs[2])
    L(ms.outputs[0], out.inputs['Surface']); m.diffuse_color = (1, 0.2, 0.2, 1)
    # teeth / horn tips
    m, nt, out = new_mat("Zahn")
    b = nt.nodes.new('ShaderNodeBsdfPrincipled'); b.inputs['Base Color'].default_value = (0.82, 0.78, 0.74, 1); b.inputs['Roughness'].default_value = 0.35
    nt.links.new(b.outputs[0], out.inputs['Surface']); m.diffuse_color = (0.85, 0.8, 0.75, 1)
    m, nt, out = new_mat("Zunge")
    b = nt.nodes.new('ShaderNodeBsdfPrincipled'); b.inputs['Base Color'].default_value = (0.35, 0.02, 0.02, 1); b.inputs['Roughness'].default_value = 0.3
    nt.links.new(b.outputs[0], out.inputs['Surface'])
    # wing membrane: dark red, glowing veins + backlit glow
    m, nt, out = new_mat("Fluegelhaut")
    N = nt.nodes.new; L = nt.links.new
    tc = N('ShaderNodeTexCoord')
    b = N('ShaderNodeBsdfPrincipled'); b.inputs['Base Color'].default_value = (0.12, 0.005, 0.005, 1); b.inputs['Roughness'].default_value = 0.6
    dn = N('ShaderNodeTexNoise'); dn.inputs['Scale'].default_value = 1.5; dn.inputs['Detail'].default_value = 5
    L(tc.outputs['Object'], dn.inputs['Vector'])
    add = N('ShaderNodeVectorMath'); add.operation = 'MULTIPLY_ADD'; add.inputs[1].default_value = (0.6, 0.6, 0.6)
    L(dn.outputs['Color'], add.inputs[0]); L(tc.outputs['Object'], add.inputs[2])
    vc = N('ShaderNodeTexVoronoi'); vc.feature = 'DISTANCE_TO_EDGE'; vc.inputs['Scale'].default_value = 0.9
    L(add.outputs[0], vc.inputs['Vector'])
    ve = N('ShaderNodeMapRange'); ve.inputs['From Min'].default_value = 0.008; ve.inputs['From Max'].default_value = 0.04
    ve.inputs['To Min'].default_value = 1.0; ve.inputs['To Max'].default_value = 0.0
    L(vc.outputs['Distance'], ve.inputs['Value'])
    glow = N('ShaderNodeMapRange'); glow.inputs['From Min'].default_value = 0.3; glow.inputs['From Max'].default_value = 0.75
    glow.inputs['To Min'].default_value = 0.4; glow.inputs['To Max'].default_value = 2.5
    L(dn.outputs['Fac'], glow.inputs['Value'])
    eb = N('ShaderNodeEmission'); eb.inputs['Color'].default_value = (0.8, 0.02, 0.01, 1)
    L(glow.outputs['Result'], eb.inputs['Strength'])
    base = N('ShaderNodeAddShader'); L(b.outputs[0], base.inputs[0]); L(eb.outputs[0], base.inputs[1])
    ev = N('ShaderNodeEmission'); ev.inputs['Color'].default_value = RED
    mul = N('ShaderNodeMath'); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = 14
    L(pulse(nt, "1+0.35*sin(frame*2*pi/30+0.5)").outputs[0], mul.inputs[0]); L(mul.outputs[0], ev.inputs['Strength'])
    ms = N('ShaderNodeMixShader'); L(ve.outputs['Result'], ms.inputs[0]); L(base.outputs[0], ms.inputs[1]); L(ev.outputs[0], ms.inputs[2])
    L(ms.outputs[0], out.inputs['Surface']); m.diffuse_color = (0.4, 0.02, 0.02, 1)
    # energy band materials
    emission_mat("Band_Rot", (0.9, 0.0, 0.0, 1), 3.0)
    m, nt, out = new_mat("Rauch")
    b = nt.nodes.new('ShaderNodeBsdfPrincipled'); b.inputs['Base Color'].default_value = (0.01, 0.005, 0.005, 1); b.inputs['Roughness'].default_value = 0.9
    nt.links.new(b.outputs[0], out.inputs['Surface']); m.diffuse_color = (0.02, 0.01, 0.01, 1)
