"""Grapple launcher: a compact handgun-style gun held in the free (left) hand.
It fires a claw hook on a cable. Matte black with gunmetal, a cable spool on
the side, and a muzzle ring and status strip that glow in the player color
("Accent").

Real-world scale (~0.2 m long). The gun points along Blender +Y, which exports
to Godot -Z. The origin is the grip (where the palm wraps). Nodes:
  "Muzzle" is where the cable leaves the launcher tube.
  "Grip" is the hand IK target.
  "Hook" is the claw sitting in the muzzle. The game hides it while the real
  hook is out, and its origin is the hook's back end, where the cable ties on.
"""
import os
import sys

sys.path.append(os.path.dirname(__file__))
import common as c  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "grapple_gun.glb")

c.reset()
black = c.material("GunBlack", (0.028, 0.03, 0.033), rough=0.55, metal=0.2)
metal = c.material("GunMetal", (0.16, 0.17, 0.18), rough=0.3, metal=0.85)
polymer = c.material("Polymer", (0.05, 0.052, 0.056), rough=0.8)
cable = c.material("Cable", (0.02, 0.022, 0.025), rough=0.6, metal=0.3)
accent = c.material("Accent", (1.0, 0.45, 0.15), rough=0.2, emission=(1.0, 0.45, 0.15), strength=6.0)

BZ = 0.05  # bore height above the grip origin
# Grip, raked back like a pistol's, with a trigger and a guard.
c.box("Handle", (0.026, 0.036, 0.085), (0, -0.008, BZ - 0.058), polymer, bevel=0.008, segments=3, rot=(16, 0, 0))
c.box("TriggerGuard", (0.006, 0.045, 0.006), (0, 0.03, BZ - 0.048), metal, bevel=0.002)
c.box("GuardPost", (0.006, 0.006, 0.03), (0, 0.05, BZ - 0.035), metal, bevel=0.002)
c.box("Trigger", (0.006, 0.006, 0.02), (0, 0.022, BZ - 0.032), metal, bevel=0.001, rot=(-15, 0, 0))
# Body: a squat receiver, stepped down toward the front.
c.box("Body", (0.034, 0.12, 0.042), (0, 0.03, BZ), black, bevel=0.006, segments=2)
c.box("BodyTop", (0.026, 0.09, 0.012), (0, 0.02, BZ + 0.026), metal, bevel=0.003)
# Launcher tube, wider than a pistol barrel (it holds the hook).
c.cylinder("Tube", 0.021, 0.085, (0, 0.125, BZ), black, rot=(90, 0, 0), verts=24, bevel=0.004)
c.cylinder("TubeRing", 0.0235, 0.008, (0, 0.166, BZ), accent, rot=(90, 0, 0), verts=24, bevel=0.0)
c.cylinder("TubeLip", 0.0225, 0.006, (0, 0.172, BZ), metal, rot=(90, 0, 0), verts=24, bevel=0.001)
# Cable spool on the left side, with a slot of wound cable.
c.cylinder("Spool", 0.02, 0.014, (-0.024, 0.05, BZ - 0.004), metal, rot=(0, 90, 0), verts=24, bevel=0.002)
c.cylinder("SpoolCable", 0.016, 0.016, (-0.024, 0.05, BZ - 0.004), cable, rot=(0, 90, 0), verts=24, bevel=0.0)
c.cylinder("SpoolCap", 0.008, 0.02, (-0.024, 0.05, BZ - 0.004), accent, rot=(0, 90, 0), verts=12, bevel=0.0)
# Status strip on the right side (reads as the agent's color).
c.box("SideLight", (0.002, 0.06, 0.004), (0.018, 0.03, BZ + 0.008), accent, bevel=0.0)
# Rear: a small cocking block.
c.box("Rear", (0.03, 0.02, 0.03), (0, -0.038, BZ + 0.004), metal, bevel=0.004)

# Claw hook: a spike with three folded prongs. The first part sets the origin
# (the back end, where the cable ties on).
HY = 0.155
parts = [c.cylinder("Hook", 0.007, 0.012, (0, HY, BZ), metal, rot=(90, 0, 0), verts=12, bevel=0.0)]
parts.append(c.cylinder("HookShaft", 0.0045, 0.04, (0, HY + 0.026, BZ), metal, rot=(90, 0, 0), verts=10, bevel=0.0))
parts.append(c.cylinder("HookTip", 0.006, 0.01, (0, HY + 0.049, BZ), accent, rot=(90, 0, 0), verts=10, bevel=0.0))
for i, ang in enumerate((0, 120, 240)):
    import math
    a = math.radians(ang)
    ox, oz = math.sin(a) * 0.011, math.cos(a) * 0.011
    parts.append(c.box("Prong%d" % i, (0.004, 0.03, 0.004), (ox, HY + 0.03, BZ + oz), metal, bevel=0.0, rot=(-math.degrees(math.atan2(oz, 0.03)) * 0.5, 0, math.degrees(math.atan2(ox, 0.03)) * 0.5)))
hook = c.join(parts, "Hook")


def empty(name, loc):
    e = c.bpy.data.objects.new(name, None)
    e.location = loc
    c.link(e)
    return e


empty("Muzzle", (0, 0.172, BZ))
empty("Grip", (0, -0.004, BZ - 0.05))

objs = [o for o in c.bpy.context.scene.objects if o.visible_get() or o.type == "EMPTY"]
c.export_glb(OUT, objs)
