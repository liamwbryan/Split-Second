"""Agent carbine: compact suppressed rifle, matte black with gunmetal detail and
a holo sight whose reticle glows in the player color ("Accent").

Real-world scale (~0.78 m). The gun points along Blender +Y, which exports
to Godot -Z (forward). The origin is the right-hand grip. Empties exported as
nodes: "Muzzle" (tracer origin), "GripR" / "GripL" (hand IK targets),
"SightLine" (the point the eye aligns with when aiming down sights).
"""
import os
import sys

sys.path.append(os.path.dirname(__file__))
import common as c  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "agent_rifle.glb")

c.reset()
black = c.material("GunBlack", (0.028, 0.03, 0.033), rough=0.55, metal=0.2)
metal = c.material("GunMetal", (0.16, 0.17, 0.18), rough=0.3, metal=0.85)
polymer = c.material("Polymer", (0.05, 0.052, 0.056), rough=0.8)
accent = c.material("Accent", (1.0, 0.45, 0.15), rough=0.2, emission=(1.0, 0.45, 0.15), strength=6.0)

# Y is forward. Grip (origin) at y=0; receiver spans y -0.08..0.22 at z ~0.06.
RZ = 0.065
upper = c.box("Upper", (0.034, 0.3, 0.05), (0, 0.07, RZ + 0.01), black, bevel=0.004, segments=2)
lower = c.box("Lower", (0.03, 0.2, 0.038), (0, 0.04, RZ - 0.03), metal, bevel=0.004)
# Picatinny rail: a row of small teeth on top.
c.box("RailBase", (0.022, 0.26, 0.008), (0, 0.08, RZ + 0.039), metal, bevel=0.002)
for i in range(12):
    c.box("RailTooth", (0.024, 0.008, 0.005), (0, -0.04 + i * 0.021, RZ + 0.045), metal, bevel=0.001)
# Handguard with side slots (cut out), then the suppressor.
hg = c.box("Handguard", (0.04, 0.24, 0.046), (0, 0.33, RZ + 0.004), black, bevel=0.006, segments=2)
for i in range(4):
    slot = c.box("Slot", (0.06, 0.03, 0.012), (0, 0.25 + i * 0.05, RZ + 0.004), black, bevel=0.004, segments=2)
    c.cut_with(hg, slot)
c.apply_all([hg])
for o in [o for o in c.bpy.data.objects if o.name.startswith("Slot")]:
    c.delete(o)
c.cylinder("Barrel", 0.009, 0.1, (0, 0.49, RZ + 0.006), metal, rot=(90, 0, 0), verts=16)
c.cylinder("Suppressor", 0.019, 0.2, (0, 0.62, RZ + 0.006), black, rot=(90, 0, 0), verts=24, bevel=0.004)
c.cylinder("SuppressorCap", 0.017, 0.012, (0, 0.726, RZ + 0.006), metal, rot=(90, 0, 0), verts=24)
# Magazine (slightly curved: two segments), pistol grip, trigger guard.
c.box("Mag", (0.026, 0.06, 0.12), (0, 0.1, RZ - 0.1), polymer, bevel=0.004, rot=(-8, 0, 0))
c.box("MagBase", (0.03, 0.066, 0.012), (0, 0.108, RZ - 0.162), metal, bevel=0.003, rot=(-8, 0, 0))
c.box("Grip", (0.028, 0.04, 0.1), (0, -0.005, RZ - 0.085), polymer, bevel=0.008, segments=3, rot=(18, 0, 0))
c.box("TriggerGuard", (0.006, 0.06, 0.006), (0, 0.035, RZ - 0.07), metal, bevel=0.002)
# Collapsible stock: a tube and a butt plate.
c.cylinder("StockTube", 0.012, 0.16, (0, -0.16, RZ), metal, rot=(90, 0, 0), verts=16)
c.box("StockButt", (0.03, 0.03, 0.11), (0, -0.25, RZ - 0.02), polymer, bevel=0.008, segments=3)
c.box("StockCheek", (0.028, 0.1, 0.02), (0, -0.2, RZ + 0.03), polymer, bevel=0.006)
# Holo sight: base, hood, glass, glowing reticle dot.
SX = 0.06
c.box("SightBase", (0.03, 0.06, 0.012), (0, SX, RZ + 0.054), metal, bevel=0.003)
hood = c.box("SightHood", (0.036, 0.05, 0.036), (0, SX, RZ + 0.08), black, bevel=0.004)
window = c.box("SightWindow", (0.026, 0.08, 0.026), (0, SX, RZ + 0.082), black, bevel=0.003)
c.cut_with(hood, window)
c.apply_all([hood])
c.delete(window)
# No glass pane: an open window with a floating reticle reads as a clear holo
# sight and avoids a (costlier) transparent material.
c.box("Reticle", (0.0025, 0.001, 0.0025), (0, SX + 0.008, RZ + 0.082), accent, bevel=0.0)
# Status light on the side (reads as the agent's color from third person).
c.box("SideLight", (0.002, 0.05, 0.004), (0.02, 0.12, RZ + 0.02), accent, bevel=0.0)


def empty(name, loc):
    e = c.bpy.data.objects.new(name, None)
    e.location = loc
    c.link(e)
    return e


empty("Muzzle", (0, 0.735, RZ + 0.006))
empty("GripR", (0, 0.0, RZ - 0.06))
empty("GripL", (0, 0.24, RZ - 0.022))  # just ahead of the mag well: reachable in first person
empty("SightLine", (0, SX, RZ + 0.082))

objs = [o for o in c.bpy.context.scene.objects if o.visible_get() or o.type == "EMPTY"]
c.export_glb(OUT, objs)
