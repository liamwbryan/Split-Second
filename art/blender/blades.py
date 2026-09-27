"""Melee blades for the agent.

  agent_knife.glb: a black combat knife (tanto point) whose edge line glows
                   in the player color. Quick melee.
  agent_blade.glb: an "arc blade", a slim futuristic sword. Dark core, with
                   both edges and the guard lit in the player color.

Blades point along Blender +Y (Godot -Z); the origin is the grip (right hand).
Empties: "GripR" (hand), "Base" and "Tip" (the slash trail runs between them).
"""
import os
import sys

sys.path.append(os.path.dirname(__file__))
import common as c  # noqa: E402

DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")


def empty(name, loc):
    e = c.bpy.data.objects.new(name, None)
    e.location = loc
    c.link(e)
    return e


def mats():
    return (
        c.material("BladeBlack", (0.03, 0.032, 0.036), rough=0.35, metal=0.8),
        c.material("GunMetal", (0.16, 0.17, 0.18), rough=0.25, metal=0.9),
        c.material("Polymer", (0.045, 0.047, 0.05), rough=0.85),
        c.material("Accent", (1.0, 0.45, 0.15), rough=0.2, emission=(1.0, 0.45, 0.15), strength=6.0),
    )


def export(name):
    objs = [o for o in c.bpy.context.scene.objects if o.visible_get() or o.type == "EMPTY"]
    c.export_glb(os.path.join(DIR, name), objs)


# --- knife -----------------------------------------------------------------
c.reset()
black, metal, polymer, accent = mats()
c.box("Handle", (0.026, 0.11, 0.03), (0, -0.02, 0), polymer, bevel=0.008, segments=3)
for i in range(4):
    c.box("HandleRib", (0.028, 0.006, 0.032), (0, -0.06 + i * 0.025, 0), black, bevel=0.002)
c.box("Pommel", (0.03, 0.02, 0.034), (0, -0.083, 0), metal, bevel=0.005)
c.box("Guard", (0.034, 0.012, 0.05), (0, 0.04, 0.002), metal, bevel=0.003)
c.box("Blade", (0.005, 0.16, 0.032), (0, 0.125, 0.004), black, bevel=0.0015)
c.box("Point", (0.005, 0.04, 0.022), (0, 0.215, 0.009), black, bevel=0.0015, rot=(-28, 0, 0))
c.box("EdgeGlow", (0.0055, 0.15, 0.003), (0, 0.12, -0.011), accent, bevel=0.0)
empty("GripR", (0, -0.02, 0))
empty("Base", (0, 0.05, 0))
empty("Tip", (0, 0.23, 0.01))
export("agent_knife.glb")

# --- arc blade ---------------------------------------------------------------
c.reset()
black, metal, polymer, accent = mats()
c.cylinder("Hilt", 0.016, 0.2, (0, -0.02, 0), polymer, rot=(90, 0, 0), verts=16)
for i in range(5):
    c.cylinder("Wrap", 0.0175, 0.012, (0, -0.1 + i * 0.04, 0), black, rot=(90, 0, 0), verts=16, bevel=0.0)
c.cylinder("Pommel", 0.021, 0.03, (0, -0.135, 0), metal, rot=(90, 0, 0), verts=16)
c.cylinder("PommelGlow", 0.0215, 0.006, (0, -0.15, 0), accent, rot=(90, 0, 0), verts=16, bevel=0.0)
c.box("Guard", (0.03, 0.03, 0.1), (0, 0.095, 0), metal, bevel=0.006)
c.box("GuardGlow", (0.031, 0.006, 0.09), (0, 0.112, 0), accent, bevel=0.0)
# Blade: a dark core with lit edges, tapering toward the point.
L = 0.78
c.box("BladeCore", (0.007, L, 0.04), (0, 0.11 + L * 0.5, 0), black, bevel=0.002)
c.box("BladeTip", (0.007, 0.08, 0.028), (0, 0.11 + L + 0.02, 0.006), black, bevel=0.002, rot=(-24, 0, 0))
c.box("EdgeA", (0.008, L - 0.02, 0.004), (0, 0.11 + L * 0.5, 0.021), accent, bevel=0.0)
c.box("EdgeB", (0.008, L - 0.02, 0.004), (0, 0.11 + L * 0.5, -0.021), accent, bevel=0.0)
c.box("Fuller", (0.0075, L * 0.7, 0.006), (0, 0.11 + L * 0.42, 0), metal, bevel=0.0)
empty("GripR", (0, -0.02, 0))
empty("Base", (0, 0.14, 0))
empty("Tip", (0, 0.11 + L + 0.05, 0.01))
export("agent_blade.glb")
