# 渲染 sanctum_v2 GLB 的几张检视图（Workbench，无光照贴图，仅看形体）。
# blender -b --factory-startup --python tools/blender/sanctum_v2/preview.py -- <glb> <out_dir> <view1;view2;...>
# view = name:cx,cy,cz:tx,ty,tz:lens   （坐标用「布局坐标」：x 东、y 南、z 上；这里自动转成 Blender 的 glTF 导入坐标）
import bpy, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
GLB, OUTD, VIEWS = argv[0], argv[1], argv[2].split(";")
os.makedirs(OUTD, exist_ok=True)
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=GLB)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light = "STUDIO"
sh.color_type = "MATERIAL"
sh.show_shadows = True
sh.show_cavity = True
sc.render.resolution_x, sc.render.resolution_y = 1280, 800
world = bpy.data.worlds.new("w")
world.color = (0.72, 0.82, 0.92)
sc.world = world


def conv(x, y, z):
    # glTF Y-up 导入后：布局 (x, y, z) 对应 Blender (x, -y, z)
    return Vector((x, -y, z))


for v in VIEWS:
    name, c, t, lens = v.split(":")
    c = conv(*map(float, c.split(",")))
    t = conv(*map(float, t.split(",")))
    cam_data = bpy.data.cameras.new("c")
    cam_data.lens = float(lens)
    cam_data.clip_end = 2000
    cam = bpy.data.objects.new("cam", cam_data)
    sc.collection.objects.link(cam)
    cam.location = c
    cam.rotation_euler = (t - c).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.filepath = os.path.join(OUTD, name + ".png")
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)
    print("RENDERED", name)
