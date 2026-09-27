"""Rooftop props: HVAC units (small, big), a vent stack and a water tower.

  blender -b --python art/blender/rooftop_props.py

Each prop is joined into one mesh (a few materials = a few surfaces) with its
origin at the base center, exported to assets/models/prop_*.glb. In-game they
are drawn with one MultiMesh per model (Props.finalize) and keep simple box
collision, so their outer dimensions match the collision boxes in props.gd:
  AC small  2.0 x 1.1 x 1.4 (x, height, depth)    AC big  3.2 x 1.2 x 2.0
  vent      0.9 x 2.4 x 0.9 footprint/height      water tower: legs at +-1.4,
  platform 3.4 at 4.0-4.2, tank r 1.8 from 4.2 to 8.2, roof to 9.4.
Blender: Z up, X right, -Y forward (exports to Godot -Z).
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
import common as c  # noqa: E402

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")


def mats():
    return {
        "paint": c.material("PropPaint", (0.52, 0.53, 0.51), rough=0.5, metal=0.25),
        "steel": c.material("PropSteel", (0.2, 0.21, 0.23), rough=0.45, metal=0.7),
        "grille": c.material("PropGrille", (0.07, 0.075, 0.08), rough=0.6, metal=0.4),
        "wood": c.material("TankWood", (0.46, 0.33, 0.22), rough=0.85),
        "roof": c.material("TankRoof", (0.24, 0.22, 0.21), rough=0.7, metal=0.2),
        "rust": c.material("PropRust", (0.42, 0.24, 0.14), rough=0.8, metal=0.3),
        "galv": c.material("PropGalv", (0.56, 0.58, 0.6), rough=0.4, metal=0.75),
    }


def finish(name):
    objs = [o for o in c.bpy.context.scene.objects if o.type == "MESH" and o.visible_get()]
    c.apply_all(objs)
    obj = c.join(objs, name)
    c.export_glb(os.path.join(OUT_DIR, "prop_%s.glb" % name), [obj])
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print("PROP", name, "tris", tris)


def ac_unit(name, w, h, d, fans):
    """Packaged rooftop HVAC unit on skids, fan grilles on top, louvered sides."""
    c.reset()
    m = mats()
    skid = 0.1
    for y in (-d * 0.35, d * 0.35):
        c.box("Skid", (w + 0.1, 0.12, skid), (0, y, skid * 0.5), m["steel"], bevel=0.01, segments=1)
    body_h = h - skid - 0.06
    c.box("Cabinet", (w, d, body_h), (0, 0, skid + body_h * 0.5), m["paint"], bevel=0.03, segments=2)
    # Top: raised fan shrouds with dark grilles and radial bars.
    top = skid + body_h
    r = min(d * 0.36, w / fans * 0.36)
    for i in range(fans):
        x = (i - (fans - 1) * 0.5) * (w / fans)
        c.cylinder("Shroud", r + 0.05, 0.08, (x, 0, top + 0.04), m["paint"], verts=24, bevel=0.01)
        c.cylinder("Fan", r, 0.02, (x, 0, top + 0.08), m["grille"], verts=24, bevel=0)
        for k in range(4):
            c.box("Bar", (r * 2.0, 0.025, 0.02), (x, 0, top + 0.095), m["steel"], bevel=0, rot=(0, 0, 45 * k))
    # Louvers on both long faces: thin slats slightly proud of the cabinet.
    rows = 6
    for side in (-1, 1):
        for k in range(rows):
            z = skid + 0.15 + k * (body_h - 0.3) / (rows - 1)
            c.box("Louver", (w * 0.8, 0.03, 0.035), (0, side * (d * 0.5 + 0.01), z), m["grille"], bevel=0, rot=(20 * side, 0, 0))
    # End: service panel with a handle and an electrical box.
    c.box("Panel", (0.02, d * 0.6, body_h * 0.6), (w * 0.5 + 0.005, 0, skid + body_h * 0.5), m["paint"], bevel=0.005, segments=1)
    c.box("Handle", (0.04, 0.12, 0.03), (w * 0.5 + 0.03, d * 0.18, skid + body_h * 0.55), m["steel"], bevel=0.005, segments=1)
    c.box("EBox", (0.14, 0.3, 0.36), (-w * 0.5 - 0.07, d * 0.2, skid + body_h * 0.45), m["steel"], bevel=0.01, segments=1)
    # Refrigerant lines running down into the roof.
    for k, y in enumerate((-d * 0.15, -d * 0.28)):
        rr = 0.035 - k * 0.01
        c.cylinder("Line", rr, body_h * 0.5, (-w * 0.5 - 0.06, y, skid + body_h * 0.25), m["steel"], verts=10, bevel=0)
    finish(name)


def vent(name, height):
    """Round duct stack with a rain cap on standoffs, on a square curb."""
    c.reset()
    m = mats()
    c.box("Curb", (0.9, 0.9, 0.25), (0, 0, 0.125), m["paint"], bevel=0.02, segments=1)
    c.box("Flashing", (0.7, 0.7, 0.06), (0, 0, 0.28), m["steel"], bevel=0.01, segments=1)
    pipe_h = height - 0.55
    c.cylinder("Duct", 0.3, pipe_h, (0, 0, 0.25 + pipe_h * 0.5), m["galv"], verts=24, bevel=0.005)
    for k in range(3):  # seam bands
        c.cylinder("Band", 0.315, 0.04, (0, 0, 0.5 + k * pipe_h * 0.33), m["galv"], verts=24, bevel=0)
    top = 0.25 + pipe_h
    for k in range(3):
        a = math.radians(120 * k)
        c.box("Standoff", (0.03, 0.03, 0.22), (math.cos(a) * 0.28, math.sin(a) * 0.28, top + 0.1), m["steel"], bevel=0)
    cap = c.bpy.data.meshes.new("Cap")
    bm = c.bmesh.new()
    c.bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.45, radius2=0.02, depth=0.22)
    bm.to_mesh(cap)
    bm.free()
    obj = c.link(c.bpy.data.objects.new("Cap", cap))
    obj.location = (0, 0, top + 0.3)
    c.assign(obj, m["galv"])
    c.smooth(obj)
    finish(name)


def water_tower(name):
    """Classic timber-stave tank on a braced steel stand, with ladder and walkway."""
    c.reset()
    m = mats()
    leg_h = 4.0
    for x in (-1.4, 1.4):
        for y in (-1.4, 1.4):
            c.box("Leg", (0.25, 0.25, leg_h), (x, y, leg_h * 0.5), m["steel"], bevel=0.015, segments=1)
            c.box("Foot", (0.5, 0.5, 0.12), (x, y, 0.06), m["steel"], bevel=0.01, segments=1)
    # X bracing and a mid girt on each side.
    brace_len = math.hypot(2.8, 2.2)
    brace_ang = math.degrees(math.atan2(2.2, 2.8))
    for side in range(4):
        rotz = 90 * side
        ox = math.cos(math.radians(rotz))
        oy = math.sin(math.radians(rotz))
        cx, cy = ox * 1.4, oy * 1.4
        for tier in (0, 1):
            zc = 0.9 + tier * 2.2
            for sgn in (-1, 1):
                b = c.box("Brace", (brace_len, 0.05, 0.05), (cx, cy, zc), m["steel"], bevel=0,
                          rot=(0, sgn * brace_ang, rotz + 90))
        c.box("Girt", (2.8, 0.1, 0.12), (cx, cy, 2.0), m["steel"], bevel=0.01, segments=1, rot=(0, 0, rotz + 90))
    # Platform deck and a guard rail around it.
    c.box("Deck", (3.4, 3.4, 0.2), (0, 0, leg_h + 0.1), m["steel"], bevel=0.02, segments=1)
    top = leg_h + 0.2
    for side in range(4):
        rotz = 90 * side
        ox = math.cos(math.radians(rotz))
        oy = math.sin(math.radians(rotz))
        c.box("Rail", (3.4, 0.05, 0.05), (ox * 1.68, oy * 1.68, top + 0.95), m["steel"], bevel=0, rot=(0, 0, rotz + 90))
        c.box("MidRail", (3.4, 0.04, 0.04), (ox * 1.68, oy * 1.68, top + 0.5), m["steel"], bevel=0, rot=(0, 0, rotz + 90))
        for k in range(4):
            t = -1.6 + k * (3.2 / 3)
            px = ox * 1.68 - oy * t
            py = oy * 1.68 + ox * t
            c.box("Post", (0.05, 0.05, 1.0), (px, py, top + 0.5), m["steel"], bevel=0)
    # Tank: staves (a many-sided cylinder), steel hoops, conical roof, hatch.
    tank_h = 4.0
    c.cylinder("Tank", 1.8, tank_h, (0, 0, top + tank_h * 0.5), m["wood"], verts=32, bevel=0.01)
    for k in range(5):
        z = top + 0.35 + k * (tank_h - 0.7) / 4
        c.cylinder("Hoop", 1.83, 0.06, (0, 0, z), m["rust"], verts=32, bevel=0)
    roof = c.bpy.data.meshes.new("Roof")
    bm = c.bmesh.new()
    c.bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=2.0, radius2=0.08, depth=1.2)
    bm.to_mesh(roof)
    bm.free()
    obj = c.link(c.bpy.data.objects.new("Roof", roof))
    obj.location = (0, 0, top + tank_h + 0.6)
    c.assign(obj, m["roof"])
    c.smooth(obj)
    c.cylinder("Finial", 0.1, 0.3, (0, 0, top + tank_h + 1.3), m["roof"], verts=12, bevel=0)
    c.box("Hatch", (0.5, 0.05, 0.4), (0, -1.55, top + tank_h + 0.35), m["roof"], bevel=0.01, segments=1, rot=(-60, 0, 0))
    # Ladder up the front leg face to the deck, then up the tank side.
    for x in (-0.22, 0.22):
        c.box("LadderRail", (0.04, 0.04, leg_h), (x, -1.55, leg_h * 0.5), m["steel"], bevel=0)
        c.box("TankLadderRail", (0.04, 0.04, tank_h + 0.4), (x, -1.9, top + (tank_h + 0.4) * 0.5), m["steel"], bevel=0)
    for k in range(int(leg_h / 0.3)):
        c.box("Rung", (0.44, 0.03, 0.03), (0, -1.55, 0.3 + k * 0.3), m["steel"], bevel=0)
    for k in range(int((tank_h + 0.4) / 0.3)):
        c.box("Rung", (0.44, 0.03, 0.03), (0, -1.9, top + 0.3 + k * 0.3), m["steel"], bevel=0)
    finish(name)


ac_unit("ac_small", 2.0, 1.1, 1.4, 1)
ac_unit("ac_big", 3.2, 1.2, 2.0, 2)
vent("vent", 2.4)
water_tower("water_tower")
