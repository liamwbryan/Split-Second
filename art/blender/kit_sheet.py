"""Contact sheet of kit models laid out in a grid (one render):
  blender -b --python art/blender/kit_sheet.py -- out.png a.glb b.glb ...
"""
import math
import sys
import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out, files = args[0], args[1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
cols = max(1, math.ceil(math.sqrt(len(files))))
spacing = 5.5
for i, f in enumerate(files):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f)
    new = [o for o in bpy.data.objects if o not in before]
    col, row = i % cols, i // cols
    for o in new:
        if o.parent is None:
            o.location.x += col * spacing
            o.location.y += row * spacing
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.render.resolution_x = 1400
scene.render.resolution_y = 1000
scene.world = bpy.data.worlds.new("W")
scene.world.color = (0.55, 0.58, 0.64)
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
rows = math.ceil(len(files) / cols)
center = Vector(((cols - 1) * spacing * 0.5, (rows - 1) * spacing * 0.5, 0.8))
dist = max(cols, rows) * spacing * 1.25
cam.location = center + Vector((-0.35 * dist, -0.9 * dist, 0.55 * dist))
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
cam_data.lens = 40
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out)
