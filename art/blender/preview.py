"""Render a quick preview of glTF files together: blender -b --python preview.py -- out.png a.glb b.glb ..."""
import math
import sys
import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out, files = args[0], [a for a in args[1:] if not a.startswith("view=")]
bpy.ops.wm.read_factory_settings(use_empty=True)
for f in files:
    bpy.ops.import_scene.gltf(filepath=f)
for o in list(bpy.data.objects):
    if o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o, do_unlink=True)
# Show the mannequin in the in-game suit colors (RunnerAvatar sets these).
SUIT = {"M_Main": (0.03, 0.032, 0.036), "M_Joints": (0.12, 0.13, 0.14)}
for m in bpy.data.materials:
    if m.name in SUIT and m.use_nodes:
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*SUIT[m.name], 1.0)
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.world = bpy.data.worlds.new("W")
scene.world.color = (0.62, 0.66, 0.72)
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
view = [a for a in args if a.startswith("view=")]
mode = view[0][5:] if view else "full"
if mode == "head":
    target, dist, lens = Vector((0, 0, 1.66)), 1.3, 60
elif mode == "prop":
    target, dist, lens = Vector((0, 0.25, 0.05)), 1.4, 50
else:
    target, dist, lens = Vector((0, 0, 1.0)), 4.2, 50
yaw = math.radians(-35)
cam.location = target + Vector((math.sin(yaw) * dist, -math.cos(yaw) * dist, 0.25 * dist))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
cam_data.lens = lens
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out)
