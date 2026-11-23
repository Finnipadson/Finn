import bpy
exec(open(r"C:\Users\finns\OneDrive\Desktop\Claude\Games\In Arbeit\Blender\_Skripte\dragon_smooth.py", encoding="utf-8").read())
sc = C.scene; sc.frame_set(1)
legparts = [D.objects[n] for S in "LR" for n in (f"VArm_O_{S}", f"VArm_U_{S}", f"HBein_O_{S}", f"HBein_M_{S}", f"HBein_U_{S}")]
extra_vis = legparts + [D.objects[f"{f}_{S}_Ballen"] for S in "LR" for f in ("VHand", "HFuss")] + [D.objects["Nasenspitze"]]
for o in extra_vis: o.hide_viewport = False
C.view_layer.update(); dg = C.evaluated_depsgraph_get()


def ends(o):
    pts = world_pts(o, dg); c, vecs, proj = pca(pts)
    ax = Vector(vecs[:, 0]); a = Vector(c) + ax * proj[:, 0].min(); b = Vector(c) + ax * proj[:, 0].max()
    return (a, b) if a.z > b.z else (b, a)


W = lambda n: D.objects[n].matrix_world.translation.copy()
bones = [("Koerper_H", Vector((-2.3, 0, 2.4)), Vector((-0.3, 0, 2.3)), "Drache_Koerper"),
         ("Koerper_V", Vector((-0.3, 0, 2.3)), Vector((1.8, 0, 2.6)), "Drache_Koerper")]
for i in range(5):
    a = W(f"Hals_J{i}"); b = W(f"Hals_J{i+1}") if i < 4 else W("Kopf_Pivot") + (W("Kopf_Pivot") - W("Hals_J3")).normalized() * 0.3
    if (b - a).length < 0.2: b = a + (a - W(f"Hals_J{i-1}")).normalized() * 0.4
    bones.append((f"Hals_{i}", a, b, f"Hals_J{i}"))
nose = D.objects["Nasenspitze"]
bones.append(("Kopf", W("Kopf_Pivot"), sum((nose.matrix_world @ Vector(c) for c in nose.bound_box), Vector()) / 8, "Kopf_Pivot"))
for i in range(12):
    a = W(f"Schwanz_J{i}"); b = W(f"Schwanz_J{i+1}") if i < 11 else a + (a - W("Schwanz_J10")) * 0.9
    bones.append((f"Schwanz_{i}", a, b, f"Schwanz_J{i}"))
for o in legparts:
    a, b = ends(o); bones.append(("B_" + o.name, a, b, "Drache_Root"))
for S in "LR":
    for n in (f"VHand_{S}_Ballen", f"HFuss_{S}_Ballen"):
        c = D.objects[n].matrix_world.translation
        bones.append(("B_" + n, c + Vector((-0.4, 0, 0.05)), c + Vector((0.6, 0, 0.0)), "Drache_Root"))
for o in extra_vis: o.hide_viewport = True
body = D.objects["Drachenkoerper"]
mw = body.matrix_world.copy(); body.parent = None; body.matrix_world = mw
for m in [m for m in body.modifiers if m.type == 'ARMATURE']: body.modifiers.remove(m)
olda = D.objects.get("Drache_Skelett")
if olda:
    od = olda.data; D.objects.remove(olda); D.armatures.remove(od)
ad = D.armatures.new("Drache_Skelett"); ad.display_type = 'STICK'
arm = D.objects.new("Drache_Skelett", ad); D.collections["Drache"].objects.link(arm)
for o in C.selected_objects: o.select_set(False)
C.view_layer.objects.active = arm; arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for n, h, t, _ in bones:
    b = ad.edit_bones.new(n); b.head = h; b.tail = t
bpy.ops.object.mode_set(mode='OBJECT')
C.view_layer.update()
for n, h, t, tgt in bones:
    con = arm.pose.bones[n].constraints.new('CHILD_OF'); con.target = D.objects[tgt]
C.view_layer.update()
for pb in arm.pose.bones:
    con = pb.constraints[0]; con.inverse_matrix = con.target.matrix_world.inverted()
C.view_layer.update()
for o in C.selected_objects: o.select_set(False)
err = max((arm.pose.bones[b.name].matrix.translation - b.head_local).length for b in ad.bones)
print("skeleton", len(bones), "err", round(err, 6))
