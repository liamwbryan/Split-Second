"""Rail sniper: long-range scoped rifle for the agent. Matte black with
gunmetal detail, a long fluted barrel with a rail-coil muzzle, a big scope
whose lens ring and coil bands glow in the player color ("Accent").

Real-world scale (~1.15 m). Points along Blender +Y (Godot -Z). The origin is
the right-hand grip. Empties: "Muzzle", "GripR", "GripL", "SightLine" (the
scope's eyepiece axis: the eye lines up with it when aiming).
"""
import os
import sys

sys.path.append(os.path.dirname(__file__))
import common as c  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "agent_sniper.glb")

c.reset()
black = c.material("GunBlack", (0.026, 0.028, 0.031), rough=0.5, metal=0.25)
metal = c.material("GunMetal", (0.15, 0.16, 0.17), rough=0.28, metal=0.9)
polymer = c.material("Polymer", (0.045, 0.047, 0.05), rough=0.8)
glass = c.material("ScopeGlass", (0.02, 0.05, 0.08), rough=0.05, metal=0.6)
accent = c.material("Accent", (1.0, 0.45, 0.15), rough=0.2, emission=(1.0, 0.45, 0.15), strength=6.0)

RZ = 0.07
# Receiver and chassis.
c.box("Receiver", (0.038, 0.34, 0.056), (0, 0.08, RZ + 0.01), black, bevel=0.005, segments=2)
c.box("Chassis", (0.036, 0.26, 0.03), (0, 0.06, RZ - 0.03), metal, bevel=0.004)
# Long forend (free-floating) with vent cuts, then the barrel and rail coils.
fe = c.box("Forend", (0.046, 0.34, 0.05), (0, 0.42, RZ + 0.0), black, bevel=0.007, segments=2)
for i in range(5):
    slot = c.box("Slot", (0.07, 0.035, 0.014), (0, 0.3 + i * 0.055, RZ), black, bevel=0.004)
    c.cut_with(fe, slot)
c.apply_all([fe])
for o in [o for o in c.bpy.data.objects if o.name.startswith("Slot")]:
    c.delete(o)
c.cylinder("Barrel", 0.011, 0.44, (0, 0.8, RZ + 0.008), metal, rot=(90, 0, 0), verts=16)
for i in range(3):
    c.cylinder("Coil", 0.021, 0.022, (0, 0.72 + i * 0.07, RZ + 0.008), black, rot=(90, 0, 0), verts=20)
    c.cylinder("CoilGlow", 0.0215, 0.006, (0, 0.72 + i * 0.07, RZ + 0.008), accent, rot=(90, 0, 0), verts=20, bevel=0.0)
c.box("Brake", (0.04, 0.05, 0.03), (0, 1.03, RZ + 0.008), black, bevel=0.006)
# Bolt handle (right side) and the bolt shroud.
c.cylinder("BoltShroud", 0.02, 0.06, (0, -0.1, RZ + 0.012), metal, rot=(90, 0, 0), verts=16)
c.cylinder("BoltArm", 0.006, 0.06, (0.035, -0.05, RZ + 0.01), metal, rot=(0, 90, 0), verts=8)
c.ellipsoid("BoltKnob", (0.012, 0.012, 0.012), (0.066, -0.05, RZ + 0.01), black, segments=12, rings=8)
# Magazine, grip, trigger guard.
c.box("Mag", (0.03, 0.08, 0.07), (0, 0.13, RZ - 0.08), polymer, bevel=0.004)
c.box("Grip", (0.03, 0.045, 0.11), (0, -0.005, RZ - 0.085), polymer, bevel=0.008, segments=3, rot=(22, 0, 0))
c.box("TriggerGuard", (0.006, 0.07, 0.006), (0, 0.04, RZ - 0.07), metal, bevel=0.002)
# Skeleton stock (hidden in first person: names start with "Stock").
c.box("StockBeam", (0.02, 0.24, 0.02), (0, -0.25, RZ - 0.005), metal, bevel=0.004)
c.box("StockButt", (0.034, 0.03, 0.14), (0, -0.37, RZ - 0.03), polymer, bevel=0.008, segments=3)
c.box("StockCheek", (0.03, 0.12, 0.022), (0, -0.28, RZ + 0.035), polymer, bevel=0.006)
# Scope: rings, tube, bells, glowing lens rings, turrets.
SZ = RZ + 0.085
for y in (0.0, 0.16):
    c.box("ScopeRing", (0.036, 0.02, 0.05), (0, y, RZ + 0.05), metal, bevel=0.004)
c.cylinder("ScopeTube", 0.017, 0.26, (0, 0.08, SZ), black, rot=(90, 0, 0), verts=24)
c.cylinder("ScopeBellFront", 0.028, 0.08, (0, 0.25, SZ), black, rot=(90, 0, 0), verts=28, bevel=0.004)
c.cylinder("ScopeBellRear", 0.022, 0.06, (0, -0.08, SZ), black, rot=(90, 0, 0), verts=24, bevel=0.004)
c.cylinder("LensFront", 0.024, 0.004, (0, 0.292, SZ), glass, rot=(90, 0, 0), verts=28, bevel=0.0)
c.cylinder("LensRingFront", 0.0285, 0.006, (0, 0.289, SZ), accent, rot=(90, 0, 0), verts=28, bevel=0.0)
c.cylinder("LensRear", 0.018, 0.004, (0, -0.112, SZ), glass, rot=(90, 0, 0), verts=24, bevel=0.0)
c.cylinder("TurretTop", 0.012, 0.022, (0, 0.08, SZ + 0.026), metal, verts=16)
c.cylinder("TurretSide", 0.012, 0.022, (0.026, 0.08, SZ), metal, rot=(0, 90, 0), verts=16)
c.box("SideLight", (0.002, 0.08, 0.004), (0.024, 0.2, RZ + 0.02), accent, bevel=0.0)


def empty(name, loc):
    e = c.bpy.data.objects.new(name, None)
    e.location = loc
    c.link(e)
    return e


empty("Muzzle", (0, 1.06, RZ + 0.008))
empty("GripR", (0, 0.0, RZ - 0.06))
empty("GripL", (0, 0.3, RZ - 0.02))
empty("SightLine", (0, -0.11, SZ))

objs = [o for o in c.bpy.context.scene.objects if o.visible_get() or o.type == "EMPTY"]
c.export_glb(OUT, objs)
