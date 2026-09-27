"""Print bone positions and body cross-section extents (for fitting gear snugly)."""
import sys
import bpy
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=sys.argv[sys.argv.index("--") + 1])
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = next(o for o in bpy.data.objects if o.name == "Mannequin")
for b in arm.data.bones:
    if any(k in b.name for k in ["upperarm", "lowerarm", "hand_", "thigh", "calf", "pelvis", "spine", "neck", "Head"]):
        h = arm.matrix_world @ b.head_local
        t = arm.matrix_world @ b.tail_local
        print("BONE %-12s head (%.3f %.3f %.3f) tail (%.3f %.3f %.3f)" % (b.name, *h, *t))
verts = [body.matrix_world @ v.co for v in body.data.vertices]
def slab(axis, lo, hi, cond=lambda v: True):
    pts = [v for v in verts if lo <= v[axis] <= hi and cond(v)]
    if not pts:
        return "none"
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return "x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f]" % (mn.x, mx.x, mn.y, mx.y, mn.z, mx.z)
print("TOP of body z=%.3f" % max(v.z for v in verts))
for z in [1.55, 1.62, 1.70, 1.76, 1.80]:
    print("HEAD z=%.2f %s" % (z, slab(2, z - 0.01, z + 0.01, lambda v: abs(v.x) < 0.2)))
for z in [1.25, 1.1, 0.98, 0.92]:
    print("TORSO z=%.2f %s" % (z, slab(2, z - 0.01, z + 0.01, lambda v: abs(v.x) < 0.3)))
for x in [0.3, 0.45, 0.6]:
    print("ARM_L x=%.2f %s" % (x, slab(0, x - 0.01, x + 0.01)))
for z in [0.75, 0.6]:
    print("LEG_R z=%.2f %s" % (z, slab(2, z - 0.01, z + 0.01, lambda v: v.x < -0.02)))
