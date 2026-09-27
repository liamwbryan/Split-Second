"""Rooftops movers: the flat-top tower crane (mast + slewing jib) and the
rotating billboard's frame.

  blender -b --python art/blender/crane_billboard.py

These are visuals only. Collision stays the simple boxes in rooftops.gd, so
every outer dimension here matches those boxes (Godot local coords of each
mover in brackets; Blender +Y = Godot -Z):
  crane_mast   2 x 2 footprint, 6 m tall, origin at its base  [static block]
  crane_jib    origin = slewing pivot (mast top)               [Mover SWING]
    jib         x +-0.7, y 1..37,  z 0..1.08  (the walkable 0.12 m BOOST deck
                plate on top is drawn by LevelBuilder so it keeps the route color)
    counter-jib x +-0.7, y -1..-11, z 0..1.08 (deck plate from LevelBuilder too)
    counterweight x +-1.5, y -8..-11, z 0.9..3.5
    cab         x +-1.3, y +-1.3, z 0.6..3.0
  billboard_frame  origin = rotation pivot; the 14 x 6 x 0.5 RUN panel spans
                x +-7, y +-0.25, z 0..6 and is drawn by LevelBuilder; this is
                its border, light strips and the pivot collar.
A flat-top crane has no cat head or pendant lines, so nothing sticks up out of
the collision where a player could run through it.
"""
import math
import os
import sys

from mathutils import Vector

sys.path.append(os.path.dirname(__file__))
import common as c  # noqa: E402

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")


def mats():
    return {
        "yellow": c.material("CraneYellow", (0.82, 0.52, 0.02), rough=0.45, metal=0.3),
        "chord": c.material("CraneChord", (0.07, 0.075, 0.085), rough=0.4, metal=0.6),
        "white": c.material("Composite", (0.78, 0.79, 0.8), rough=0.35, metal=0.1),
        "glass": c.material("DarkGlass", (0.015, 0.02, 0.028), rough=0.06, metal=0.9),
        "concrete": c.material("Counterweight", (0.5, 0.5, 0.48), rough=0.85),
        "strip": c.material("LightStrip", (0.9, 0.95, 1.0), rough=0.3, emission=(0.85, 0.93, 1.0), strength=4.0),
        "red": c.material("WarningLight", (1.0, 0.08, 0.05), rough=0.3, emission=(1.0, 0.08, 0.05), strength=8.0),
    }


def strut(name, p0, p1, thick, mat):
    """Square member from p0 to p1 (a lattice bar)."""
    p0 = Vector(p0)
    p1 = Vector(p1)
    d = p1 - p0
    obj = c.box(name, (thick, thick, d.length), (p0 + p1) * 0.5, mat, bevel=0)
    obj.rotation_mode = "QUATERNION"
    up = "X" if abs(d.normalized().y) > 0.99 else "Y"  # tracking needs an up axis not parallel to d
    obj.rotation_quaternion = d.to_track_quat("Z", up)
    return obj


def finish(name):
    objs = [o for o in c.bpy.context.scene.objects if o.type == "MESH" and o.visible_get()]
    c.apply_all(objs)
    obj = c.join(objs, name)
    c.export_glb(os.path.join(OUT_DIR, "prop_%s.glb" % name), [obj])
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print("PROP", name, "tris", tris)


def truss(y0, y1, half_w, top, m, panel=1.5, chord=0.12, web=0.07):
    """Box-section Warren truss along +Y: 4 chords, zigzag webs on both sides
    and the bottom. Its top face (z = top) is where the deck plate sits."""
    zb = chord * 0.5
    zt = top - chord * 0.5
    x = half_w - chord * 0.5
    length = y1 - y0
    for sx in (-1, 1):
        for z in (zb, zt):
            c.box("Chord", (chord, length, chord), (sx * x, (y0 + y1) * 0.5, z), m["chord"], bevel=0)
    n = max(1, round(length / panel))
    step = length / n
    for i in range(n):
        ya = y0 + i * step
        yb = ya + step
        up = i % 2 == 0
        for sx in (-1, 1):
            strut("Web", (sx * x, ya, zb if up else zt), (sx * x, yb, zt if up else zb), web, m["yellow"])
        strut("Floor", (-x if up else x, ya, zb), (x if up else -x, yb, zb), web, m["yellow"])
    for y in (y0 + chord * 0.5, y1 - chord * 0.5):  # end frames
        c.box("EndFrame", (half_w * 2.0, chord, chord), (0, y, zb), m["chord"], bevel=0)
        for sx in (-1, 1):
            c.box("EndPost", (chord, chord, top), (sx * x, y, top * 0.5), m["chord"], bevel=0)
    # Light strips along the outside of both top chords.
    for sx in (-1, 1):
        c.box("Strip", (0.02, length, 0.05), (sx * (half_w + 0.01), (y0 + y1) * 0.5, top - 0.1), m["strip"], bevel=0)


def crane_mast():
    """Square lattice tower section: corner chords, K-less zigzag faces."""
    c.reset()
    m = mats()
    h = 6.0
    half = 1.0
    ch = 0.16
    x = half - ch * 0.5
    for sx in (-1, 1):
        for sy in (-1, 1):
            c.box("Leg", (ch, ch, h), (sx * x, sy * x, h * 0.5), m["yellow"], bevel=0.01, segments=1)
    panels = 4
    step = h / panels
    faces = [((-x, -x), (x, -x)), ((x, -x), (x, x)), ((x, x), (-x, x)), ((-x, x), (-x, -x))]
    for (ax, ay), (bx, by) in faces:
        for i in range(panels):
            za = i * step
            zb = za + step
            if i % 2:
                strut("Diag", (ax, ay, za), (bx, by, zb), 0.08, m["yellow"])
            else:
                strut("Diag", (bx, by, za), (ax, ay, zb), 0.08, m["yellow"])
            strut("Girt", (ax, ay, zb), (bx, by, zb), 0.08, m["yellow"])
    c.box("TopPlate", (2.0, 2.0, 0.12), (0, 0, h - 0.06), m["chord"], bevel=0.01, segments=1)
    c.box("BasePlate", (2.0, 2.0, 0.1), (0, 0, 0.05), m["chord"], bevel=0.01, segments=1)
    # A light strip up one corner, facing the city, so the mast reads at night.
    c.box("Strip", (0.03, 0.03, h - 0.3), (x + ch * 0.5 + 0.015, -x - ch * 0.5 - 0.015, h * 0.5), m["strip"], bevel=0)
    finish("crane_mast")


def crane_jib():
    c.reset()
    m = mats()
    deck = 1.08
    truss(1.0, 37.0, 0.7, deck, m)          # jib
    truss(-11.0, -1.0, 0.7, deck, m)        # counter-jib
    # Slewing ring between the mast top and the cab.
    c.cylinder("SlewRing", 0.95, 0.6, (0, 0, 0.3), m["chord"], verts=24, bevel=0.01)
    # Operator pod: white composite shell, dark glass wrapping the front and
    # sides, a light strip around the roof line.
    c.box("CabShell", (2.6, 2.6, 2.4), (0, 0, 1.8), m["white"], bevel=0.12, segments=2)
    c.box("CabGlassFront", (2.3, 0.04, 1.1), (0, 1.3, 2.1), m["glass"], bevel=0)
    for sx in (-1, 1):
        c.box("CabGlassSide", (0.04, 1.8, 1.0), (sx * 1.3, 0.2, 2.15), m["glass"], bevel=0)
    c.box("CabStrip", (2.64, 2.64, 0.05), (0, 0, 2.9), m["strip"], bevel=0)
    # Counterweight: four stacked slabs in a steel cradle.
    for k in range(4):
        z = 0.9 + 0.325 + k * 0.65
        c.box("Slab", (2.96, 2.9, 0.6), (0, -9.5, z), m["concrete"], bevel=0.03, segments=1)
    for sx in (-1, 1):
        c.box("Cradle", (0.1, 3.0, 2.6), (sx * 1.45, -9.5, 2.2), m["chord"], bevel=0)
    c.box("CradleTop", (3.0, 3.0, 0.08), (0, -9.5, 3.46), m["chord"], bevel=0)
    # Aviation lights at both ends, beacon posts under the jib grapple points.
    c.box("TipLight", (0.3, 0.2, 0.2), (0, 37.05, 0.6), m["red"], bevel=0)
    c.box("TailLight", (0.3, 0.2, 0.2), (0, -11.05, 0.6), m["red"], bevel=0)
    for y in (18.0, 36.0):
        c.cylinder("BeaconPost", 0.05, 0.6, (0, y, 1.2 + 0.3), m["chord"], verts=8, bevel=0)
    finish("crane_jib")


def billboard_frame():
    c.reset()
    m = mats()
    w, h = 14.0, 6.0
    rail = 0.3
    depth = 0.6
    hw = w * 0.5
    # Border around the panel (just outside its edges, so wall-runners on the
    # faces never clip it).
    c.box("TopRail", (w + rail * 2.0, depth, rail), (0, 0, h + rail * 0.5), m["white"], bevel=0.04, segments=1)
    c.box("BottomRail", (w + rail * 2.0, depth, 0.2), (0, 0, -0.1), m["white"], bevel=0.04, segments=1)
    for sx in (-1, 1):
        c.box("SideRail", (rail, depth, h + 0.5), (sx * (hw + rail * 0.5), 0, h * 0.5 + 0.05), m["white"], bevel=0.04, segments=1)
    # Light strips inset in the border on both faces.
    for sy in (-1, 1):
        y = sy * (depth * 0.5 + 0.005)
        c.box("StripTop", (w + 0.3, 0.02, 0.06), (0, y, h + rail * 0.5), m["strip"], bevel=0)
        c.box("StripBottom", (w + 0.3, 0.02, 0.05), (0, y, -0.1), m["strip"], bevel=0)
        for sx in (-1, 1):
            c.box("StripSide", (0.06, 0.02, h + 0.3), (sx * (hw + rail * 0.5), y, h * 0.5 + 0.05), m["strip"], bevel=0)
    # Pivot collar: turns with the sign and hides the static stub pole
    # (0.8 m square, 1 m tall, below the pivot).
    c.cylinder("Collar", 0.62, 0.9, (0, 0, -0.45), m["chord"], verts=24, bevel=0.01)
    c.cylinder("CollarRing", 0.7, 0.08, (0, 0, -0.24), m["strip"], verts=24, bevel=0)
    # Warning lights on the top corners.
    for sx in (-1, 1):
        c.box("CornerLight", (0.2, 0.2, 0.12), (sx * (hw + rail * 0.5), 0, h + rail + 0.06), m["red"], bevel=0)
    finish("billboard_frame")


crane_mast()
crane_jib()
billboard_frame()
