# Render quick 3/4 previews of GLBs from the running Blender (MCP). Set NAMES before exec, output .shots/blender/<name>.png
import bpy, os, math
from mathutils import Vector

OUTP = "E:/wowgame/.shots/blender"


def preview(name, yaw=35, el=0.42, dist=1.05):
    os.makedirs(OUTP, exist_ok=True)
    open(os.path.join(OUTP, ".gdignore"), "a").close()
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath="E:/wowgame/assets/models/%s.glb" % name)
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    ctr = (mn + mx) * 0.5
    size = max((mx - mn).length, 0.5)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_shadows = True
    sc.display.shading.show_cavity = True
    sc.render.resolution_x = 700
    sc.render.resolution_y = 700
    cam_data = bpy.data.cameras.new("c")
    cam = bpy.data.objects.new("cam", cam_data)
    sc.collection.objects.link(cam)
    a = math.radians(yaw)
    cam.location = ctr + Vector((math.sin(a) * size * dist, math.cos(a) * size * dist, size * el))
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = 40
    sc.camera = cam
    sc.render.filepath = os.path.join(OUTP, name + ".png")
    bpy.ops.render.render(write_still=True)


for _n in NAMES:
    preview(_n)
print("PREVIEWS", len(NAMES))
