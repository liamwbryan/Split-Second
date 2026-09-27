"""First-person mannequin: the UAL mannequin split into two skinned meshes on
the same armature, for the owner-only first-person body:
  FP_Arms  - clavicles, arms, hands, fingers (drawn with the gun's first-person
             FOV + anti-clip depth, so they never look wide-angle distorted)
  FP_Body  - pelvis, spine, legs (drawn at the true projection so feet land on
             the real floor)
Head and neck vertices are removed entirely (the camera is the eyes).
No animations are exported: the game reuses UAL1/UAL2 clips (same skeleton).
"""
import os
import sys

import bmesh
import bpy

sys.path.append(os.path.dirname(__file__))
import common as c  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "assets", "characters", "UAL1_Standard.glb")
OUT = os.path.join(ROOT, "assets", "models", "fp_mannequin.glb")

ARM_KEYS = ("clavicle", "upperarm", "lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky")
DROP_KEYS = ("Head", "neck")

c.reset()
bpy.ops.import_scene.gltf(filepath=SRC)
for o in list(bpy.data.objects):
    if o.name.startswith("Icosphere"):
        c.delete(o)
body = bpy.data.objects["Mannequin"]
groups = {g.index: g.name for g in body.vertex_groups}


def dominant_group(v):
    best, best_w = None, 0.0
    for g in v.groups:
        if g.weight > best_w:
            best, best_w = groups.get(g.group), g.weight
    return best or ""


# Delete head/neck vertices.
bpy.context.view_layer.objects.active = body
bpy.ops.object.mode_set(mode="EDIT")
bm = bmesh.from_edit_mesh(body.data)
deform = bm.verts.layers.deform.active
drop = []
arms = []
for v in bm.verts:
    weights = v[deform]
    best, best_w = "", 0.0
    for gi, w in weights.items():
        if w > best_w:
            best, best_w = groups.get(gi, ""), w
    if best.startswith(DROP_KEYS):
        drop.append(v)
    elif best.startswith(ARM_KEYS):
        arms.append(v)
bmesh.ops.delete(bm, geom=drop, context="VERTS")
for elems in (bm.faces, bm.edges, bm.verts):
    for e in elems:
        e.select = False
for v in arms:
    if v.is_valid:
        v.select = True
bm.select_flush(True)
bmesh.update_edit_mesh(body.data)
bpy.ops.mesh.separate(type="SELECTED")
bpy.ops.object.mode_set(mode="OBJECT")

body.name = "FP_Body"
arm_obj = next(o for o in bpy.data.objects if o.type == "MESH" and o.name != "FP_Body")
arm_obj.name = "FP_Arms"
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", use_selection=True, export_yup=True,
    export_animations=False, export_skins=True, export_materials="EXPORT",
)
print("EXPORTED", OUT, "arms verts", len(arm_obj.data.vertices), "body verts", len(body.data.vertices))
