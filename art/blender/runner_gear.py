"""Agent gear v2 — sleek stealth operative (Mirror's Edge silhouette, Splinter
Cell tech). Fitted to the Quaternius UAL mannequin using art/blender/measure.py:
head ±0.085 x, -0.10..0.106 y around z 1.72; waist ±0.161 x at z 0.975;
left forearm centered (0.6, 0.058, 1.432); right thigh centered (-0.089, 0, 0.75).

The mannequin's own smooth head, in the matte suit material, *is* the cowl.
Gear is authored in rest-pose model space; each file attaches to one bone
(see RunnerAvatar.GEAR). Materials: "Suit" matte black, "Gunmetal", "Lens"
housing, "Accent" = player color (lenses and small status lights: the only
color on the agent).
"""
import os
import sys

sys.path.append(os.path.dirname(__file__))
import common as c  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")

c.reset()
suit = c.material("Suit", (0.03, 0.032, 0.036), rough=0.6, metal=0.1)
gun = c.material("Gunmetal", (0.12, 0.13, 0.14), rough=0.35, metal=0.7)
housing = c.material("Lens", (0.02, 0.02, 0.025), rough=0.25, metal=0.5)
accent = c.material("Accent", (1.0, 0.45, 0.15), rough=0.2, emission=(1.0, 0.45, 0.15), strength=3.0)


def ring(name, rx, ry, z, height, thickness, mat, center=(0.0, 0.0), segments=40):
    """Flat elliptical band (a strap, belt or goggle band) around a body part."""
    obj = c.cylinder(name, 1.0, height, (center[0], center[1], z), mat, verts=segments, bevel=0.0)
    obj.scale = (rx + thickness, ry + thickness, 1.0)
    inner = c.cylinder(name + "_in", 1.0, height * 1.5, (center[0], center[1], z), mat, verts=segments, bevel=0.0)
    inner.scale = (rx, ry, 1.0)
    c.cut_with(obj, inner)
    c.apply_all([obj])
    c.delete(inner)
    return obj


def new_objects(before):
    return [o for o in c.bpy.context.scene.objects if o.visible_get() and o not in before]


def export(filename, before):
    objs = new_objects(before)
    c.export_glb(os.path.join(OUT, filename), objs)
    for o in objs:
        c.delete(o)


# ---------------------------------------------------------------- goggles (Head)
before = set(c.bpy.context.scene.objects)
EYE_Z = 1.702
ring("GoggleBand", 0.089, 0.108, EYE_Z, 0.022, 0.006, suit)
# Tri-lens module: a center lens and two outer lenses angled slightly outward.
c.box("LensMount", (0.13, 0.034, 0.05), (0.0, -0.108, EYE_Z), housing, bevel=0.012, segments=3)
c.cylinder("LensC", 0.02, 0.04, (0.0, -0.13, EYE_Z + 0.006), housing, rot=(90, 0, 0), verts=24)
c.cylinder("LensC_glass", 0.015, 0.004, (0.0, -0.151, EYE_Z + 0.006), accent, rot=(90, 0, 0), verts=24, bevel=0.0)
for side in (-1, 1):
    x = side * 0.043
    c.cylinder("LensS", 0.016, 0.032, (x, -0.124, EYE_Z - 0.004), housing, rot=(90, 0, side * 14), verts=20)
    c.cylinder("LensS_glass", 0.012, 0.004, (x * 1.1, -0.141, EYE_Z - 0.004), accent, rot=(90, 0, side * 14), verts=20, bevel=0.0)
# Earpiece + mic boom on the right side.
c.box("EarUnit", (0.014, 0.04, 0.034), (-0.094, 0.0, EYE_Z - 0.035), gun, bevel=0.005)
export("agent_goggles.glb", before)

# ---------------------------------------------------------------- belt (pelvis)
before = set(c.bpy.context.scene.objects)
BELT_Z = 0.972
ring("Belt", 0.163, 0.118, BELT_Z, 0.038, 0.008, suit, center=(0.0, 0.006))
c.box("Buckle", (0.05, 0.012, 0.03), (0.0, -0.118, BELT_Z), gun, bevel=0.004)
c.box("BuckleLight", (0.02, 0.004, 0.004), (0.0, -0.125, BELT_Z + 0.004), accent, bevel=0.0)
for x, y, w in [(-0.12, 0.1, 0.05), (0.12, 0.1, 0.05), (0.0, 0.146, 0.08)]:
    c.box("Pouch", (w, 0.035, 0.06), (x, y, BELT_Z - 0.01), suit, bevel=0.008, segments=3)
export("agent_belt.glb", before)

# ---------------------------------------------------------------- thigh holster (thigh_r)
before = set(c.bpy.context.scene.objects)
ring("ThighStrap", 0.068, 0.078, 0.78, 0.025, 0.006, suit, center=(-0.089, 0.0))
c.box("Holster", (0.03, 0.09, 0.17), (-0.168, 0.0, 0.8), suit, bevel=0.01, segments=3)
c.box("PistolGrip", (0.028, 0.035, 0.07), (-0.168, 0.018, 0.9), gun, bevel=0.006, rot=(-10, 0, 0))
export("agent_holster.glb", before)

# ---------------------------------------------------------------- grapple bracer (lowerarm_l)
before = set(c.bpy.context.scene.objects)
FA = (0.6, 0.058, 1.432)
bracer = c.cylinder("Bracer", 1.0, 0.16, FA, gun, rot=(0, 90, 0), verts=24, bevel=0.0)
bracer.scale = (0.064, 0.054, 1.0)  # rotated 90° about Y, so this makes an oval sleeve along X
c.box("Launcher", (0.12, 0.03, 0.026), (FA[0] + 0.01, FA[1], FA[2] + 0.07), suit, bevel=0.006)
c.cylinder("Nozzle", 0.009, 0.03, (FA[0] + 0.085, FA[1], FA[2] + 0.07), housing, rot=(0, 90, 0), verts=12)
c.box("BracerLight", (0.08, 0.004, 0.006), (FA[0], FA[1] - 0.058, FA[2] + 0.01), accent, bevel=0.0)
export("agent_bracer.glb", before)

# ---------------------------------------------------------------- spine unit (spine_02)
before = set(c.bpy.context.scene.objects)
c.box("SpinePlate", (0.11, 0.028, 0.26), (0.0, 0.124, 1.22), suit, bevel=0.01, segments=3)
c.box("SpineRidge", (0.03, 0.012, 0.22), (0.0, 0.14, 1.22), gun, bevel=0.004)
c.box("SpineLight", (0.006, 0.004, 0.16), (0.0, 0.147, 1.22), accent, bevel=0.0)
for side in (-1, 1):
    c.box("Vent", (0.028, 0.02, 0.05), (side * 0.045, 0.132, 1.1), gun, bevel=0.005)
export("agent_spine.glb", before)
