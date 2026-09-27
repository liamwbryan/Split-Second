"""City kit (docs/ART_DIRECTION.md §4): the detailed props that replace the
greybox boxes in the city maps. "Mirror's Edge bones, cyberpunk skin".

  blender -b --python art/blender/city_kit.py [-- name ...]

Every model is authored in GODOT axes through g()/gs() (x right, y up, z
toward the viewer; Godot -Z = Blender +Y), with its origin at the base centre
unless noted, and exported to assets/models/kit_<name>.glb. Outer sizes match
the gameplay colliders in props.gd / the maps, so collision never changes.

Materials (names matter, Props.finalize() looks for them):
  KitPaint  – body paint, tinted per instance (MultiMesh instance colour)
  KitSign   – sign/screen glow, tinted per instance (INSTANCE_CUSTOM)
  KitWhite, KitMetal, KitDark, KitGlass, KitRubber, KitHazard – fixed
  KitGlowWhite/Red/Cyan/Amber – fixed emissive
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import common as c  # noqa: E402
import bpy  # noqa: E402
import bmesh  # noqa: E402

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")


# ----------------------------------------------------------------- axes

def g(x, y, z):
    """Godot position -> Blender location."""
    return (x, -z, y)


def gs(x, y, z):
    """Godot size -> Blender size."""
    return (x, z, y)


def gr(rx=0.0, ry=0.0, rz=0.0):
    """Godot euler (deg) -> Blender euler (deg), for simple single-axis turns."""
    return (rx, -rz, ry)


def mats():
    return {
        "paint": c.material("KitPaint", (0.86, 0.86, 0.87), rough=0.32, metal=0.15),
        "white": c.material("KitWhite", (0.8, 0.8, 0.77), rough=0.45, metal=0.05),
        "metal": c.material("KitMetal", (0.2, 0.215, 0.24), rough=0.35, metal=0.85),
        "dark": c.material("KitDark", (0.05, 0.055, 0.065), rough=0.55, metal=0.2),
        "glass": c.material("KitGlass", (0.015, 0.025, 0.035), rough=0.06, metal=0.9),
        "rubber": c.material("KitRubber", (0.025, 0.025, 0.028), rough=0.85),
        "hazard": c.material("KitHazard", (0.95, 0.72, 0.08), rough=0.5, metal=0.1),
        "gw": c.material("KitGlowWhite", (1.0, 0.95, 0.85), emission=(1.0, 0.93, 0.8), strength=5.0),
        "gr": c.material("KitGlowRed", (1.0, 0.1, 0.08), emission=(1.0, 0.08, 0.05), strength=5.0),
        "gc": c.material("KitGlowCyan", (0.3, 0.9, 1.0), emission=(0.25, 0.85, 1.0), strength=4.0),
        "ga": c.material("KitGlowAmber", (1.0, 0.7, 0.3), emission=(1.0, 0.62, 0.22), strength=4.0),
        "sign": c.material("KitSign", (1.0, 1.0, 1.0), emission=(1.0, 1.0, 1.0), strength=4.0),
        "leaf": c.material("KitLeaf", (0.16, 0.34, 0.14), rough=0.8),
        "soil": c.material("KitSoil", (0.09, 0.07, 0.05), rough=0.95),
    }


# ----------------------------------------------------------------- primitives (Godot space)

def box(name, size, pos, mat, bevel=0.01, seg=1, rot=(0, 0, 0)):
    return c.box(name, gs(*size), g(*pos), mat, bevel=bevel, segments=seg, rot=gr(*rot))


def cyl(name, r, h, pos, mat, axis="y", verts=16, bevel=0.004):
    """Cylinder of radius r and length h along a Godot axis."""
    rot = {"y": (0, 0, 0), "x": (0, 90, 0), "z": (90, 0, 0)}[axis]
    return c.cylinder(name, r, h, g(*pos), mat, rot=rot, verts=verts, bevel=bevel)


def prism(name, profile, length, pos, mat, bevel=0.01, seg=1):
    """Extrude a 2D profile [(z, y) ...] (Godot side view, counter-clockwise)
    along Godot X by `length`, centred on pos."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    half = length * 0.5
    left = [bm.verts.new(g(-half, y, z)) for z, y in profile]
    right = [bm.verts.new(g(half, y, z)) for z, y in profile]
    n = len(profile)
    bm.faces.new(list(reversed(left)))
    bm.faces.new(right)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([left[i], left[j], right[j], right[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = c.link(bpy.data.objects.new(name, mesh))
    obj.location = g(*pos)
    c.assign(obj, mat)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = seg
        mod.limit_method = "ANGLE"
        mod.harden_normals = True
    c.smooth(obj)
    return obj


def loft(name, sections, mat, ch=0.06, cap=True):
    """Loft chamfered cross-sections along Godot Z. Each section is
    (z, half_width_bottom, half_width_top, y_bottom, y_top): tapers in plan
    and profile give real vehicle/body shapes instead of extruded boxes."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    for z, hb, ht, yb, yt in sections:
        k = min(ch, (yt - yb) * 0.3, hb * 0.3, ht * 0.3)
        pts = [(-hb, yb + k), (-hb + k, yb), (hb - k, yb), (hb, yb + k),
               (ht, yt - k), (ht - k, yt), (-ht + k, yt), (-ht, yt - k)]
        rings.append([bm.verts.new(g(x, y, z)) for x, y in pts])
    n = 8
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new([a[i], a[j], b[j], b[i]])
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = c.link(bpy.data.objects.new(name, mesh))
    c.assign(obj, mat)
    c.smooth(obj)
    return obj


def tube(name, points, r, mat, res=6):
    """A round tube through Godot-space points (cables, conduits)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = max(0, res // 4 - 1)
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (*g(*p), 1.0)
    obj = c.link(bpy.data.objects.new(name, cu))
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return obj


def glyphs(prefix, rect, depth_z, mat, rng, count=3, vertical=False, stroke=0.06, face=1.0):
    """Pseudo-kanji glyph strokes laid out in `rect` (x0, y0, w, h) on the
    plane z = depth_z, facing +Z*face. Pure geometry: no fonts."""
    x0, y0, w, h = rect
    cells = []
    for i in range(count):
        if vertical:
            cw = w
            ch = h / count
            cells.append((x0, y0 + h - (i + 1) * ch, cw, ch))
        else:
            cw = w / count
            cells.append((x0 + i * cw, y0, cw, h))
    for k, (cx, cy, cw, ch) in enumerate(cells):
        pad = 0.14
        gx, gy, gw, gh = cx + cw * pad, cy + ch * pad, cw * (1 - 2 * pad), ch * (1 - 2 * pad)
        strokes = rng.randint(3, 5)
        for s in range(strokes):
            if rng.random() < 0.55:  # horizontal stroke
                ly = gy + gh * rng.choice([0.0, 0.25, 0.5, 0.75, 1.0])
                lx0 = gx + gw * rng.choice([0.0, 0.0, 0.2])
                lx1 = gx + gw * rng.choice([0.6, 1.0, 1.0])
                box("%sH%d%d" % (prefix, k, s), (lx1 - lx0, stroke, 0.03), ((lx0 + lx1) * 0.5, ly, depth_z), mat, bevel=0)
            else:  # vertical stroke
                lx = gx + gw * rng.choice([0.0, 0.3, 0.5, 0.7, 1.0])
                ly0 = gy + gh * rng.choice([0.0, 0.0, 0.3])
                ly1 = gy + gh * rng.choice([0.7, 1.0, 1.0])
                box("%sV%d%d" % (prefix, k, s), (stroke, ly1 - ly0, 0.03), (lx, (ly0 + ly1) * 0.5, depth_z), mat, bevel=0)


def finish(name):
    """Apply modifiers, join everything visible, export kit_<name>.glb."""
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.visible_get()]
    c.apply_all(objs)
    obj = c.join(objs, name)
    # Merge coincident verts from joined parts is not needed; keep hard edges.
    path = os.path.join(OUT_DIR, "kit_%s.glb" % name)
    c.export_glb(path, [obj])
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print("KIT", name, "tris", tris)


# ----------------------------------------------------------------- hover car (hero)

def hovercar():
    """Parked hover car, 2.2 wide (x) x 4.6 long (z) x ~1.22 tall, hovering
    0.25 m up. Nose toward -Z. Body is KitPaint (tinted per instance)."""
    c.reset()
    m = mats()
    # Hull: a wedge that tapers to the nose and tail, lofted from sections.
    loft("Hull", [
        (-2.3, 0.62, 0.5, 0.36, 0.5),
        (-2.12, 0.9, 0.78, 0.3, 0.66),
        (-1.6, 1.0, 0.92, 0.28, 0.76),
        (-0.6, 1.04, 0.97, 0.27, 0.8),
        (0.9, 1.05, 0.98, 0.27, 0.82),
        (1.85, 1.0, 0.94, 0.29, 0.84),
        (2.22, 0.88, 0.82, 0.33, 0.8),
        (2.3, 0.78, 0.7, 0.4, 0.74),
    ], m["paint"], ch=0.08)
    # Canopy: a teardrop of dark glass, with a paint spine over it.
    loft("Canopy", [
        (-1.45, 0.78, 0.76, 0.76, 0.8),
        (-0.85, 0.82, 0.66, 0.76, 1.1),
        (-0.2, 0.84, 0.6, 0.76, 1.2),
        (0.55, 0.84, 0.6, 0.76, 1.2),
        (1.15, 0.82, 0.68, 0.76, 1.02),
        (1.6, 0.8, 0.78, 0.76, 0.84),
    ], m["glass"], ch=0.1)
    loft("Spine", [
        (-0.7, 0.2, 0.16, 1.1, 1.2),
        (-0.2, 0.22, 0.18, 1.18, 1.235),
        (0.55, 0.22, 0.18, 1.18, 1.235),
        (1.1, 0.2, 0.16, 1.0, 1.08),
    ], m["paint"], ch=0.02)
    # Dark lower skirts, side intakes with slats, door seams and handles.
    for sx in (-1, 1):
        loft("Skirt%d" % sx, [
            (-1.9, 0.07, 0.07, 0.28, 0.44), (-1.6, 0.08, 0.08, 0.27, 0.46),
            (1.7, 0.08, 0.08, 0.27, 0.46), (2.0, 0.07, 0.07, 0.3, 0.44),
        ], m["dark"], ch=0.02)
        bpy.context.scene.objects["Skirt%d" % sx].location = g(sx * 1.0, 0, 0)
        box("Intake", (0.05, 0.2, 0.9), (sx * 1.02, 0.58, 1.05), m["dark"], bevel=0.02)
        for k in range(4):
            box("Slat", (0.07, 0.018, 0.82), (sx * 1.035, 0.51 + k * 0.045, 1.05), m["metal"], bevel=0)
        box("Seam", (0.01, 0.4, 0.01), (sx * 1.045, 0.56, -0.45), m["dark"], bevel=0)
        box("Seam2", (0.01, 0.01, 1.2), (sx * 1.045, 0.76, 0.15), m["dark"], bevel=0)
        box("Handle", (0.025, 0.03, 0.24), (sx * 1.05, 0.68, 0.0), m["metal"], bevel=0.008)
        box("Sensor", (0.12, 0.05, 0.16), (sx * 0.9, 0.84, -1.15), m["dark"], bevel=0.02)
        # Rear canards.
        box("Canard", (0.3, 0.035, 0.5), (sx * 0.92, 0.9, 1.95), m["dark"], bevel=0.015, rot=(0, 0, sx * 12))
    # Nose: a thin light blade across the front and a recessed grille.
    box("HeadLight", (1.3, 0.035, 0.05), (0, 0.6, -2.27), m["gw"], bevel=0.008)
    box("HeadLightL", (0.3, 0.03, 0.05), (-0.62, 0.56, -2.18), m["gw"], bevel=0.005, rot=(0, -35, 0))
    box("HeadLightR", (0.3, 0.03, 0.05), (0.62, 0.56, -2.18), m["gw"], bevel=0.005, rot=(0, 35, 0))
    box("Grille", (0.9, 0.08, 0.04), (0, 0.44, -2.3), m["dark"], bevel=0.01)
    # Tail: a full-width red blade and a diffuser.
    box("TailLight", (1.45, 0.045, 0.04), (0, 0.66, 2.3), m["gr"], bevel=0.008)
    box("Diffuser", (1.2, 0.1, 0.25), (0, 0.34, 2.12), m["dark"], bevel=0.02)
    for k in range(4):
        box("Fin", (0.02, 0.09, 0.22), (-0.45 + k * 0.3, 0.33, 2.14), m["metal"], bevel=0)
    # Hover nacelles tucked under the corners, with glowing thrust rings.
    for sx in (-1, 1):
        for sz in (-1, 1):
            p = (sx * 0.82, 0.24, sz * 1.5)
            cyl("Pod", 0.3, 0.14, p, m["metal"], verts=20, bevel=0.02)
            cyl("PodRing", 0.25, 0.02, (p[0], 0.16, p[2]), m["gc"], verts=20, bevel=0)
            cyl("PodCore", 0.13, 0.03, (p[0], 0.15, p[2]), m["dark"], verts=12, bevel=0)
    box("Underglow", (1.3, 0.015, 2.8), (0, 0.265, 0.0), m["gc"], bevel=0)
    finish("hovercar")


# ----------------------------------------------------------------- railing

def railing():
    """2 m railing module along x, 1.1 m tall, 0.2 deep: posts, twin rails,
    smoked glass infill, kick plate, and a light strip under the top rail."""
    c.reset()
    m = mats()
    for x in (-0.96, 0.96):
        box("Post", (0.08, 1.06, 0.1), (x, 0.53, 0), m["metal"], bevel=0.012)
        box("Foot", (0.14, 0.04, 0.18), (x, 0.02, 0), m["metal"], bevel=0.01)
    box("TopRail", (2.0, 0.07, 0.16), (0, 1.065, 0), m["white"], bevel=0.02, seg=2)
    box("LightStrip", (1.9, 0.015, 0.05), (0, 1.024, 0.02), m["gc"], bevel=0)
    box("MidRail", (1.84, 0.04, 0.05), (0, 0.55, 0.0), m["metal"], bevel=0.008)
    # Slim balusters (see-through, opaque: no transparency pass).
    for k in range(11):
        x = -0.8 + k * 0.16
        box("Baluster", (0.025, 0.86, 0.025), (x, 0.58, 0.0), m["metal"], bevel=0)
    box("Kick", (2.0, 0.14, 0.12), (0, 0.07, 0), m["dark"], bevel=0.015)
    box("KickGlow", (1.9, 0.02, 0.02), (0, 0.12, 0.062), m["ga"], bevel=0)
    finish("railing")


# ----------------------------------------------------------------- barrier

def barrier():
    """Futuristic jersey barrier: 3.2 x 1.0 x 0.6, tapered profile, hazard
    light bar, lift slots, end caps."""
    c.reset()
    m = mats()
    prof = [(-0.3, 0.0), (0.3, 0.0), (0.3, 0.12), (0.14, 0.34), (0.1, 1.0), (-0.1, 1.0), (-0.14, 0.34), (-0.3, 0.12)]
    prism("Body", prof, 3.1, (0, 0, 0), m["white"], bevel=0.025, seg=2)
    box("CapL", (0.06, 0.96, 0.28), (-1.57, 0.5, 0), m["metal"], bevel=0.015)
    box("CapR", (0.06, 0.96, 0.28), (1.57, 0.5, 0), m["metal"], bevel=0.015)
    for sz in (-1, 1):
        box("Stripe", (2.9, 0.1, 0.02), (0, 0.78, sz * 0.113), m["hazard"], bevel=0)
        box("LightBar", (2.4, 0.03, 0.02), (0, 0.9, sz * 0.106), m["ga"], bevel=0)
        for x in (-0.9, 0.9):
            box("Slot", (0.5, 0.08, 0.03), (x, 0.06, sz * 0.3), m["dark"], bevel=0)
    finish("barrier")


# ----------------------------------------------------------------- crates

def crate():
    """1.2 m cargo crate: panelled faces, corner guards, ribs, handles, a
    stencil plate. Body is KitPaint (tinted per instance)."""
    c.reset()
    m = mats()
    s = 1.2
    box("Body", (s - 0.04, s - 0.04, s - 0.04), (0, s * 0.5, 0), m["paint"], bevel=0.03, seg=2)
    # Corner guards (metal) on all 8 corners.
    for sx in (-1, 1):
        for sy in (0, 1):
            for sz in (-1, 1):
                p = (sx * (s * 0.5 - 0.06), 0.06 + sy * (s - 0.12), sz * (s * 0.5 - 0.06))
                box("Corner", (0.14, 0.14, 0.14), p, m["metal"], bevel=0.02)
    # Ribs on the four sides.
    for sz in (-1, 1):
        for x in (-0.3, 0.3):
            box("RibZ", (0.06, s - 0.3, 0.03), (x, s * 0.5, sz * (s * 0.5 + 0.0)), m["metal"], bevel=0.008)
    for sx in (-1, 1):
        for zz in (-0.3, 0.3):
            box("RibX", (0.03, s - 0.3, 0.06), (sx * (s * 0.5 + 0.0), s * 0.5, zz), m["metal"], bevel=0.008)
    # Handles and stencil plate.
    for sx in (-1, 1):
        box("Handle", (0.04, 0.05, 0.3), (sx * (s * 0.5 + 0.03), s * 0.7, 0), m["dark"], bevel=0.01)
    box("Plate", (0.4, 0.18, 0.02), (0, s * 0.72, s * 0.5 + 0.01), m["white"], bevel=0.005)
    box("Stencil", (0.28, 0.04, 0.02), (0, s * 0.72, s * 0.5 + 0.02), m["dark"], bevel=0)
    box("Led", (0.06, 0.03, 0.02), (0.14, s * 0.3, s * 0.5 + 0.01), m["gc"], bevel=0)
    finish("crate")


# ----------------------------------------------------------------- kiosk / pylon / charger

def kiosk():
    """Holo kiosk / vending unit 2.0 x 2.4 x 1.2: a sculpted cabinet with
    screens on both faces (KitSign), a canopy lip and vents."""
    c.reset()
    m = mats()
    box("Base", (2.0, 0.18, 1.2), (0, 0.09, 0), m["dark"], bevel=0.03)
    box("Cabinet", (1.86, 2.0, 1.02), (0, 1.18, 0), m["white"], bevel=0.05, seg=2)
    box("Canopy", (2.0, 0.14, 1.2), (0, 2.31, 0), m["metal"], bevel=0.03)
    box("CanopyLight", (1.8, 0.03, 1.0), (0, 2.235, 0), m["gw"], bevel=0)
    rng = random.Random(4)
    for sz in (-1, 1):
        box("Bezel", (1.5, 1.3, 0.04), (0, 1.35, sz * 0.52), m["dark"], bevel=0.01)
        box("Screen", (1.36, 1.16, 0.02), (0, 1.35, sz * 0.545), m["sign"], bevel=0)
        glyphs("G%d" % sz, (-0.6, 0.9, 1.2, 0.35), sz * 0.56, m["dark"], rng, count=4, stroke=0.035)
        box("Slot", (0.5, 0.05, 0.03), (0.4, 0.5, sz * 0.52), m["dark"], bevel=0)
        box("Pad", (0.24, 0.3, 0.03), (-0.5, 0.52, sz * 0.52), m["metal"], bevel=0.008)
    for sx in (-1, 1):
        for k in range(6):
            box("Vent", (0.02, 0.03, 0.6), (sx * 0.935, 0.5 + k * 0.08, 0), m["dark"], bevel=0)
    finish("kiosk")


def holo_pylon():
    """Holo pylon 2.4 x 2.6 x 0.6 (SPIRAL deck cover): frame, glowing
    double-sided ad panel (KitSign), feet."""
    c.reset()
    m = mats()
    for x in (-1.12, 1.12):
        box("Upright", (0.16, 2.6, 0.6), (x, 1.3, 0), m["metal"], bevel=0.03, seg=2)
    box("Head", (2.4, 0.18, 0.6), (0, 2.51, 0), m["metal"], bevel=0.03, seg=2)
    box("Foot", (2.4, 0.3, 0.6), (0, 0.15, 0), m["dark"], bevel=0.03)
    box("Core", (2.08, 2.1, 0.28), (0, 1.35, 0), m["dark"], bevel=0.02)
    rng = random.Random(9)
    for sz in (-1, 1):
        box("Panel", (1.96, 1.96, 0.02), (0, 1.35, sz * 0.15), m["sign"], bevel=0)
        glyphs("P%d" % sz, (-0.8, 0.55, 1.6, 0.5), sz * 0.165, m["dark"], rng, count=3, stroke=0.05)
        box("Strip", (2.0, 0.03, 0.02), (0, 2.38, sz * 0.3), m["gw"], bevel=0)
    finish("holo_pylon")


def charger():
    """Car charging pod 1.4 x 1.2 x 1.4: rounded housing, cable coil, status ring."""
    c.reset()
    m = mats()
    box("Plinth", (1.4, 0.12, 1.4), (0, 0.06, 0), m["dark"], bevel=0.03)
    box("Housing", (1.1, 1.0, 1.1), (0, 0.62, 0), m["white"], bevel=0.12, seg=3)
    box("Face", (0.7, 0.5, 0.02), (0, 0.72, 0.56), m["glass"], bevel=0.01)
    box("FaceGlow", (0.5, 0.06, 0.02), (0, 0.9, 0.57), m["gc"], bevel=0)
    cyl("Ring", 0.5, 0.04, (0, 1.14, 0), m["gc"], verts=24, bevel=0)
    cyl("Cap", 0.45, 0.08, (0, 1.17, 0), m["metal"], verts=24, bevel=0.01)
    # Charging cable looping off the side into a holster.
    pts = [(0.55, 0.6, 0.2), (0.7, 0.45, 0.25), (0.72, 0.3, 0.0), (0.66, 0.35, -0.25), (0.56, 0.6, -0.25)]
    tube("Cable", pts, 0.03, m["rubber"])
    box("Holster", (0.1, 0.2, 0.14), (0.57, 0.68, -0.25), m["metal"], bevel=0.01)
    finish("charger")


# ----------------------------------------------------------------- signs

def sign_blade():
    """Vertical blade sign sticking out from a wall: mount at the origin, the
    blade extends along +X (0.9 wide, 3.4 tall, 0.22 thick), glyphs both sides."""
    c.reset()
    m = mats()
    box("Frame", (0.9, 3.4, 0.22), (0.62, 0.0, 0), m["dark"], bevel=0.03)
    for sz in (-1, 1):
        box("Face", (0.78, 3.26, 0.02), (0.62, 0.0, sz * 0.105), m["sign"], bevel=0)
        glyphs("B%d" % sz, (0.28, -1.45, 0.68, 2.9), sz * 0.125, m["dark"], random.Random(3 + sz), count=4, vertical=True, stroke=0.05)
    for y in (-1.2, 1.2):
        box("Arm", (0.2, 0.08, 0.1), (0.08, y, 0), m["metal"], bevel=0.01)
        box("Plate", (0.04, 0.24, 0.24), (-0.02, y, 0), m["metal"], bevel=0.01)
    tube("Feed", [(0.0, -1.5, 0.05), (0.1, -1.8, 0.05), (0.3, -1.75, 0.05)], 0.02, m["rubber"])
    finish("sign_blade")


def sign_banner():
    """Horizontal banner sign on a wall: 4.0 x 1.1, protrudes +Z 0.25 from the
    mount (origin at the back centre), glyphs and a scan line."""
    c.reset()
    m = mats()
    box("Back", (4.0, 1.1, 0.14), (0, 0, 0.07), m["dark"], bevel=0.03)
    box("Face", (3.8, 0.9, 0.02), (0, 0, 0.15), m["sign"], bevel=0)
    glyphs("N", (-1.7, -0.35, 2.4, 0.7), 0.165, m["dark"], random.Random(12), count=4, stroke=0.05)
    box("Tag", (1.0, 0.7, 0.03), (1.25, 0, 0.17), m["dark"], bevel=0.01)
    box("TagGlow", (0.8, 0.08, 0.02), (1.25, 0.15, 0.19), m["gw"], bevel=0)
    box("TagGlow2", (0.5, 0.08, 0.02), (1.1, -0.08, 0.19), m["gw"], bevel=0)
    for x in (-1.7, 1.7):
        box("Standoff", (0.12, 0.12, 0.1), (x, 0.4, 0.0), m["metal"], bevel=0.01)
    finish("sign_banner")


def glyph_panel():
    """Small square glyph sign (1 x 1), origin at the back centre, faces +Z."""
    c.reset()
    m = mats()
    box("Back", (1.0, 1.0, 0.1), (0, 0, 0.05), m["dark"], bevel=0.02)
    box("Face", (0.86, 0.86, 0.02), (0, 0, 0.105), m["sign"], bevel=0)
    glyphs("Q", (-0.35, -0.35, 0.7, 0.7), 0.12, m["dark"], random.Random(21), count=1, stroke=0.07)
    finish("glyph_panel")


# ----------------------------------------------------------------- pipes, ducts, cables

def pipe_run():
    """2 m twin pipe run along x on wall brackets (the wall is at z = -0.35;
    origin on the big pipe's axis)."""
    c.reset()
    m = mats()
    cyl("Pipe", 0.16, 2.0, (0, 0, 0), m["metal"], axis="x", verts=16, bevel=0)
    cyl("Pipe2", 0.08, 2.0, (0, 0.26, -0.08), m["white"], axis="x", verts=12, bevel=0)
    for x in (-0.97, 0.97):
        cyl("Flange", 0.2, 0.06, (x, 0, 0), m["metal"], axis="x", verts=16, bevel=0.005)
    for x in (-0.5, 0.5):
        box("Bracket", (0.08, 0.5, 0.35), (x, 0.08, -0.2), m["dark"], bevel=0.01)
        box("Clamp", (0.06, 0.36, 0.36), (x, 0.0, 0.0), m["dark"], bevel=0.01)
    box("Label", (0.3, 0.06, 0.02), (0.1, 0.0, 0.165), m["hazard"], bevel=0)
    finish("pipe_run")


def duct():
    """2 m rectangular duct along x hanging from a ceiling (origin at the
    duct's top centre; hangers rise 0.4 m to the ceiling)."""
    c.reset()
    m = mats()
    box("Duct", (2.0, 0.45, 0.6), (0, -0.225, 0), m["metal"], bevel=0.02)
    for k in range(5):
        box("Rib", (0.04, 0.5, 0.65), (-0.96 + k * 0.48, -0.225, 0), m["metal"], bevel=0.005)
    for x in (-0.7, 0.7):
        box("Hanger", (0.04, 0.4, 0.04), (x, 0.2, -0.32), m["dark"], bevel=0)
        box("Hanger", (0.04, 0.4, 0.04), (x, 0.2, 0.32), m["dark"], bevel=0)
    box("Grille", (0.5, 0.02, 0.4), (0.4, -0.455, 0), m["dark"], bevel=0)
    finish("duct")


def cable_bundle():
    """Four drooping cables spanning 4 m along x (from x=-2 to 2), sag 0.5,
    origin at the anchor line. Scale x to fit a span."""
    c.reset()
    m = mats()
    offsets = [(0.0, 0.0, 0.0), (0.0, -0.06, 0.07), (0.0, 0.05, -0.06), (0.0, -0.1, -0.02)]
    for k, (ox, oy, oz) in enumerate(offsets):
        sag = 0.45 + k * 0.08
        pts = []
        for i in range(13):
            t = i / 12.0
            x = -2.0 + 4.0 * t
            y = oy - sag * (1.0 - (2.0 * t - 1.0) ** 2)
            pts.append((x, y, oz))
        tube("Cable%d" % k, pts, 0.025 + 0.008 * (k % 2), m["rubber"])
    for x in (-2.0, 2.0):
        box("Clamp", (0.1, 0.2, 0.2), (x, -0.02, 0), m["metal"], bevel=0.01)
    finish("cable_bundle")


# ----------------------------------------------------------------- wall machinery

def vent_grille():
    """Wall vent 1.2 x 0.8, protrudes +Z 0.15 (origin at the back centre)."""
    c.reset()
    m = mats()
    box("Frame", (1.2, 0.8, 0.12), (0, 0, 0.06), m["metal"], bevel=0.02)
    box("Recess", (1.04, 0.64, 0.02), (0, 0, 0.11), m["dark"], bevel=0)
    for k in range(7):
        box("Louver", (1.0, 0.03, 0.08), (0, -0.27 + k * 0.09, 0.12), m["metal"], bevel=0, rot=(-30, 0, 0))
    box("Stain", (0.9, 0.3, 0.005), (0, -0.55, 0.005), m["dark"], bevel=0)
    finish("vent_grille")


def fan():
    """Wall fan housing 1.1 x 1.1 x 0.3 (origin at the back centre, faces +Z)."""
    c.reset()
    m = mats()
    box("Housing", (1.1, 1.1, 0.26), (0, 0, 0.13), m["white"], bevel=0.05, seg=2)
    cyl("Well", 0.45, 0.06, (0, 0, 0.25), m["dark"], axis="z", verts=24, bevel=0)
    for k in range(6):
        a = k * 60.0
        box("Blade", (0.4, 0.1, 0.02), (math.cos(math.radians(a)) * 0.2, math.sin(math.radians(a)) * 0.2, 0.26), m["metal"], bevel=0, rot=(0, 25, a))
    cyl("Hub", 0.1, 0.06, (0, 0, 0.28), m["metal"], axis="z", verts=12, bevel=0.01)
    for k in range(4):
        box("GuardBar", (0.92, 0.02, 0.02), (0, 0, 0.3), m["dark"], bevel=0, rot=(0, 0, 45 * k))
    box("Status", (0.12, 0.03, 0.02), (0.38, -0.46, 0.27), m["ga"], bevel=0)
    finish("fan")


def junction_box():
    """Junction box 0.6 x 0.8 x 0.25 with conduits up and down (origin at the
    back centre, faces +Z)."""
    c.reset()
    m = mats()
    box("Box", (0.6, 0.8, 0.22), (0, 0, 0.11), m["metal"], bevel=0.02)
    box("Door", (0.5, 0.68, 0.02), (0, 0, 0.225), m["white"], bevel=0.008)
    box("Hazard", (0.2, 0.06, 0.01), (0, 0.22, 0.24), m["hazard"], bevel=0)
    box("Led", (0.04, 0.04, 0.01), (0.18, -0.28, 0.24), m["gc"], bevel=0)
    for x in (-0.15, 0.0, 0.15):
        cyl("Conduit", 0.025, 1.2, (x, 1.0, 0.08), m["dark"], verts=8, bevel=0)
    cyl("ConduitDown", 0.035, 0.8, (0.1, -0.8, 0.08), m["dark"], verts=8, bevel=0)
    finish("junction_box")


# ----------------------------------------------------------------- street furniture

def lamp():
    """Futuristic street lamp, 7 m: tapered post, swept arm toward -Z, light
    blade, base plinth with a status ring."""
    c.reset()
    m = mats()
    box("Plinth", (0.5, 0.3, 0.5), (0, 0.15, 0), m["dark"], bevel=0.04)
    cyl("Ring", 0.2, 0.04, (0, 0.32, 0), m["gc"], verts=16, bevel=0)
    prism("Post", [(-0.1, 0.3), (0.1, 0.3), (0.06, 7.0), (-0.06, 7.0)], 0.16, (0, 0, 0), m["white"], bevel=0.02)
    arm = [(0.0, 6.9), (0.0, 7.1), (-1.6, 7.25), (-1.7, 7.15)]
    prism("Arm", arm, 0.14, (0, 0, 0), m["white"], bevel=0.02)
    box("Head", (0.3, 0.1, 0.9), (0, 7.12, -1.35), m["dark"], bevel=0.02)
    box("Blade", (0.2, 0.03, 0.8), (0, 7.06, -1.35), m["gw"], bevel=0)
    box("Sensor", (0.1, 0.1, 0.1), (0, 7.05, 0.05), m["metal"], bevel=0.01)
    finish("lamp")


def bench():
    """Bench 2.0 x 0.9 x 0.7: slatted seat and back on two sculpted frames,
    facing +Z."""
    c.reset()
    m = mats()
    for x in (-0.8, 0.8):
        prism("Frame", [(-0.3, 0.0), (0.3, 0.0), (0.3, 0.06), (0.05, 0.45), (-0.25, 0.9), (-0.32, 0.88), (-0.1, 0.45), (-0.3, 0.06)], 0.08, (x, 0, 0), m["metal"], bevel=0.01)
    for k in range(4):
        box("Seat", (2.0, 0.04, 0.12), (0, 0.46, 0.2 - k * 0.14), m["white"], bevel=0.01)
    for k in range(3):
        box("Back", (2.0, 0.1, 0.035), (0, 0.6 + k * 0.12, -0.26 - k * 0.02), m["white"], bevel=0.01, rot=(-15, 0, 0))
    box("Strip", (1.8, 0.02, 0.02), (0, 0.43, 0.3), m["gc"], bevel=0)
    finish("bench")


def planter():
    """Sculpted planter 2.4 x 0.9 x 1.4 with shrubs and a small tree."""
    c.reset()
    m = mats()
    prism("Tub", [(-0.7, 0.0), (0.7, 0.0), (0.72, 0.1), (0.66, 0.9), (-0.66, 0.9), (-0.72, 0.1)], 2.4, (0, 0, 0), m["white"], bevel=0.03, seg=2)
    box("Lip", (2.44, 0.06, 1.38), (0, 0.9, 0), m["metal"], bevel=0.01)
    box("Soil", (2.3, 0.04, 1.24), (0, 0.89, 0), m["soil"], bevel=0)
    box("Glow", (2.2, 0.03, 0.02), (0, 0.12, 0.72), m["gc"], bevel=0)
    rng = random.Random(5)
    for k in range(7):
        x = -0.95 + k * 0.32 + rng.uniform(-0.08, 0.08)
        z = rng.uniform(-0.35, 0.35)
        r = rng.uniform(0.22, 0.34)
        c.ellipsoid("Shrub", (r, r, r * 0.8), g(x, 0.95 + r * 0.5, z), m["leaf"], segments=8, rings=5)
    cyl("Trunk", 0.06, 1.6, (0.3, 1.7, 0), m["dark"], verts=8, bevel=0)
    for (dx, dy, dz, r) in [(0.3, 2.7, 0, 0.6), (0.0, 2.45, 0.2, 0.42), (0.6, 2.45, -0.15, 0.4), (0.3, 3.05, -0.1, 0.38)]:
        c.ellipsoid("Crown", (r, r, r * 0.85), g(dx, dy, dz), m["leaf"], segments=10, rings=6)
    finish("planter")


def bollard():
    """Bollard 0.9 tall, r 0.14, with a light ring."""
    c.reset()
    m = mats()
    cyl("Body", 0.14, 0.86, (0, 0.43, 0), m["white"], verts=16, bevel=0.02)
    cyl("Ring", 0.145, 0.05, (0, 0.72, 0), m["gc"], verts=16, bevel=0)
    cyl("Cap", 0.12, 0.05, (0, 0.88, 0), m["metal"], verts=16, bevel=0.01)
    finish("bollard")


MODELS = {
    "hovercar": hovercar, "railing": railing, "barrier": barrier, "crate": crate,
    "kiosk": kiosk, "holo_pylon": holo_pylon, "charger": charger,
    "sign_blade": sign_blade, "sign_banner": sign_banner, "glyph_panel": glyph_panel,
    "pipe_run": pipe_run, "duct": duct, "cable_bundle": cable_bundle,
    "vent_grille": vent_grille, "fan": fan, "junction_box": junction_box,
    "lamp": lamp, "bench": bench, "planter": planter, "bollard": bollard,
}

if __name__ == "__main__":
    want = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(MODELS)
    for name in want:
        MODELS[name]()
