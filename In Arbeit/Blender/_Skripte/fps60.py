import bpy, re
from bpy_extras import anim_utils
D = bpy.data; sc = bpy.context.scene
K = 60 / 24
nd = 0; bad = []
def fix(idb):
    global nd
    ad = getattr(idb, "animation_data", None)
    if ad:
        for fc in ad.drivers:
            e = fc.driver.expression
            if "frame" in e and "frame/2.5" not in e:
                fc.driver.expression = re.sub(r"\bframe\b", "(frame/2.5)", e); nd += 1
                if not fc.driver.is_simple_expression: bad.append(idb.name)
for idb in list(D.objects) + list(D.materials) + list(D.lights) + list(D.worlds):
    fix(idb)
    if getattr(idb, "node_tree", None): fix(idb.node_tree)
nk = 0
for o in D.objects:
    ad = o.animation_data
    if ad and ad.action:
        cb = anim_utils.action_get_channelbag_for_slot(ad.action, ad.action_slot)
        for fc in cb.fcurves:
            for kp in fc.keyframe_points:
                for attr in ("co", "handle_left", "handle_right"):
                    v = getattr(kp, attr); v.x = 1 + (v.x - 1) * K
                nk += 1
            fc.update()
sc.render.fps = 60; sc.render.fps_base = 1.0
sc.frame_start, sc.frame_end = 1, 300
sc.frame_set(1)
bpy.ops.wm.save_mainfile()
print("FPSRESULT", nd, nk, bad, sc.render.fps, sc.frame_end)
